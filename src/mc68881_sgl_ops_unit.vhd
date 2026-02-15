library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_sgl_ops_unit is
  port (
    clk        : in  std_logic;
    reset_n    : in  std_logic;
    start      : in  std_logic;
    op_sel     : in  fpu_op_t;
    a_in       : in  fp80_t;
    b_in       : in  fp80_t;
    round_mode : in  fp_round_mode_t;
    busy       : out std_logic;
    done       : out std_logic;
    result     : out fp80_t
  );
end entity mc68881_sgl_ops_unit;

architecture rtl of mc68881_sgl_ops_unit is
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP_EXP_MAX : integer := (2**FP_EXP_WIDTH) - 1;
  constant FP80_ZERO : fp80_t := x"00000000000000000000";

  type fp_unpacked_t is record
    sign : std_logic;
    exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  end record;

  type state_t is (
    ST_IDLE,
    ST_CLASSIFY,
    ST_SCALE_EXEC,
    ST_MUL_ITER,
    ST_DIV_ITER,
    ST_PACK_MUL,
    ST_PACK_DIV,
    ST_DONE
  );

  signal state_reg : state_t := ST_IDLE;
  signal op_reg : fpu_op_t := FPU_OP_NOP;
  signal a_reg : fp80_t := (others => '0');
  signal b_reg : fp80_t := (others => '0');
  signal rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal done_reg : std_logic := '0';
  signal result_reg : fp80_t := (others => '0');

  signal mul_a_reg : unsigned(23 downto 0) := (others => '0');
  signal mul_b_reg : unsigned(23 downto 0) := (others => '0');
  signal mul_acc_reg : unsigned(47 downto 0) := (others => '0');
  signal mul_idx_reg : integer range 0 to 24 := 0;
  signal mul_sign_reg : std_logic := '0';
  signal mul_exp_base_reg : integer := 0;

  signal div_divisor_reg : unsigned(23 downto 0) := (others => '0');
  signal div_rem_reg : unsigned(24 downto 0) := (others => '0');
  signal div_quot_reg : unsigned(23 downto 0) := (others => '0');
  signal div_idx_reg : integer range 0 to 22 := 22;
  signal div_sign_reg : std_logic := '0';
  signal div_exp_base_reg : integer := 0;

  function unpack_fp80(value : fp80_t) return fp_unpacked_t is
    variable unpacked : fp_unpacked_t;
  begin
    unpacked.sign := value(FP_WIDTH-1);
    unpacked.exp := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    unpacked.mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return unpacked;
  end function;

  function pack_fp80(value : fp_unpacked_t) return fp80_t is
    variable packed : fp80_t := (others => '0');
  begin
    packed(FP_WIDTH-1) := value.sign;
    packed(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(value.exp);
    packed(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(value.mant);
    return packed;
  end function;

  function fp80_is_zero_local(value : fp80_t) return boolean is
    variable u : fp_unpacked_t := unpack_fp80(value);
  begin
    return u.exp = 0 and u.mant = 0;
  end function;

  function fp80_is_inf_local(value : fp80_t) return boolean is
    variable u : fp_unpacked_t := unpack_fp80(value);
  begin
    return u.exp = FP_EXP_ALL_ONES and u.mant = 0;
  end function;

  function fp80_is_nan_local(value : fp80_t) return boolean is
    variable u : fp_unpacked_t := unpack_fp80(value);
  begin
    return u.exp = FP_EXP_ALL_ONES and u.mant /= 0;
  end function;

  function canonical_qnan return fp80_t is
    variable res : fp_unpacked_t;
  begin
    res.sign := '0';
    res.exp := FP_EXP_ALL_ONES;
    res.mant := (others => '1');
    return pack_fp80(res);
  end function;

  function should_round_up(
    sign_val : std_logic;
    mode     : fp_round_mode_t;
    guard    : std_logic;
    sticky   : std_logic;
    lsb      : std_logic
  ) return boolean is
    variable increment : boolean := false;
  begin
    case mode is
      when FP_RND_NEAREST =>
        if guard = '1' and (sticky = '1' or lsb = '1') then
          increment := true;
        end if;
      when FP_RND_ZERO =>
        increment := false;
      when FP_RND_MINUS_INF =>
        if sign_val = '1' and (guard = '1' or sticky = '1') then
          increment := true;
        end if;
      when FP_RND_PLUS_INF =>
        if sign_val = '0' and (guard = '1' or sticky = '1') then
          increment := true;
        end if;
    end case;
    return increment;
  end function;
begin
  process(clk, reset_n)
    variable a_u : fp_unpacked_t;
    variable b_u : fp_unpacked_t;
    variable res_u : fp_unpacked_t;
    variable rem_next : unsigned(24 downto 0);
    variable quot_next : unsigned(23 downto 0);
    variable mul_add : unsigned(47 downto 0);
    variable sig24 : unsigned(23 downto 0);
    variable sig25 : unsigned(24 downto 0);
    variable mant64 : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable exp_i : integer := 0;
    variable guard_bit : std_logic := '0';
    variable sticky_bit : std_logic := '0';
    variable scale_i : integer := 0;
    variable div_next_guard : std_logic := '0';
    variable div_next_rem : unsigned(24 downto 0);
    variable div_next_rem2 : unsigned(24 downto 0);
    variable div_is_zero : boolean := false;
  begin
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      done_reg <= '0';
      result_reg <= (others => '0');
      op_reg <= FPU_OP_NOP;
      a_reg <= (others => '0');
      b_reg <= (others => '0');
      rm_reg <= FP_RND_NEAREST;
      mul_a_reg <= (others => '0');
      mul_b_reg <= (others => '0');
      mul_acc_reg <= (others => '0');
      mul_idx_reg <= 0;
      mul_sign_reg <= '0';
      mul_exp_base_reg <= 0;
      div_divisor_reg <= (others => '0');
      div_rem_reg <= (others => '0');
      div_quot_reg <= (others => '0');
      div_idx_reg <= 22;
      div_sign_reg <= '0';
      div_exp_base_reg <= 0;
    elsif rising_edge(clk) then
      done_reg <= '0';
      case state_reg is
        when ST_IDLE =>
          if start = '1' then
            op_reg <= op_sel;
            a_reg <= a_in;
            b_reg <= b_in;
            rm_reg <= round_mode;
            state_reg <= ST_CLASSIFY;
          end if;

        when ST_CLASSIFY =>
          a_u := unpack_fp80(a_reg);
          b_u := unpack_fp80(b_reg);

          if op_reg = FPU_OP_SCALE then
            state_reg <= ST_SCALE_EXEC;
          elsif op_reg = FPU_OP_SGLMUL then
            if fp80_is_nan_local(a_reg) or fp80_is_nan_local(b_reg) then
              result_reg <= canonical_qnan;
              state_reg <= ST_DONE;
            elsif fp80_is_inf_local(a_reg) or fp80_is_inf_local(b_reg) then
              if fp80_is_zero_local(a_reg) or fp80_is_zero_local(b_reg) then
                result_reg <= canonical_qnan;
              else
                res_u.sign := a_u.sign xor b_u.sign;
                res_u.exp := FP_EXP_ALL_ONES;
                res_u.mant := (others => '0');
                result_reg <= pack_fp80(res_u);
              end if;
              state_reg <= ST_DONE;
            elsif fp80_is_zero_local(a_reg) or fp80_is_zero_local(b_reg) then
              result_reg <= FP80_ZERO;
              state_reg <= ST_DONE;
            else
              mul_a_reg <= a_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24);
              mul_b_reg <= b_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24);
              mul_acc_reg <= (others => '0');
              mul_idx_reg <= 0;
              mul_sign_reg <= a_u.sign xor b_u.sign;
              mul_exp_base_reg <= to_integer(a_u.exp) + to_integer(b_u.exp) - FP_EXP_BIAS;
              state_reg <= ST_MUL_ITER;
            end if;
          elsif op_reg = FPU_OP_SGLDIV then
            if fp80_is_nan_local(a_reg) or fp80_is_nan_local(b_reg) then
              result_reg <= canonical_qnan;
              state_reg <= ST_DONE;
            elsif fp80_is_zero_local(b_reg) then
              if fp80_is_zero_local(a_reg) then
                result_reg <= canonical_qnan;
              else
                res_u.sign := a_u.sign xor b_u.sign;
                res_u.exp := FP_EXP_ALL_ONES;
                res_u.mant := (others => '0');
                result_reg <= pack_fp80(res_u);
              end if;
              state_reg <= ST_DONE;
            elsif fp80_is_zero_local(a_reg) then
              result_reg <= FP80_ZERO;
              state_reg <= ST_DONE;
            elsif fp80_is_inf_local(a_reg) and fp80_is_inf_local(b_reg) then
              result_reg <= canonical_qnan;
              state_reg <= ST_DONE;
            elsif fp80_is_inf_local(a_reg) then
              res_u.sign := a_u.sign xor b_u.sign;
              res_u.exp := FP_EXP_ALL_ONES;
              res_u.mant := (others => '0');
              result_reg <= pack_fp80(res_u);
              state_reg <= ST_DONE;
            elsif fp80_is_inf_local(b_reg) then
              result_reg <= FP80_ZERO;
              state_reg <= ST_DONE;
            else
              div_divisor_reg <= b_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24);
              if a_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24) >= b_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24) then
                div_quot_reg <= (others => '0');
                div_quot_reg(23) <= '1';
                div_rem_reg <= resize(
                  a_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24) - b_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24),
                  25
                );
              else
                div_quot_reg <= (others => '0');
                div_rem_reg <= resize(a_u.mant(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24), 25);
              end if;
              div_idx_reg <= 22;
              div_sign_reg <= a_u.sign xor b_u.sign;
              div_exp_base_reg <= to_integer(a_u.exp) - to_integer(b_u.exp) + FP_EXP_BIAS;
              state_reg <= ST_DIV_ITER;
            end if;
          else
            result_reg <= FP80_ZERO;
            state_reg <= ST_DONE;
          end if;

        when ST_SCALE_EXEC =>
          a_u := unpack_fp80(a_reg);
          b_u := unpack_fp80(b_reg);
          if fp80_is_nan_local(a_reg) or fp80_is_nan_local(b_reg) then
            result_reg <= canonical_qnan;
          elsif b_u.exp = 0 or fp80_is_inf_local(b_reg) then
            result_reg <= b_reg;
          else
            scale_i := fp80_to_int_trunc(a_reg);
            exp_i := to_integer(b_u.exp) + scale_i;
            res_u.sign := b_u.sign;
            if exp_i <= 0 then
              res_u.exp := (others => '0');
              res_u.mant := (others => '0');
            elsif exp_i >= FP_EXP_MAX then
              res_u.exp := FP_EXP_ALL_ONES;
              res_u.mant := (others => '0');
            else
              res_u.exp := to_unsigned(exp_i, FP_EXP_WIDTH);
              res_u.mant := b_u.mant;
            end if;
            result_reg <= pack_fp80(res_u);
          end if;
          state_reg <= ST_DONE;

        when ST_MUL_ITER =>
          mul_add := mul_acc_reg;
          if mul_b_reg(0) = '1' then
            mul_add := mul_add + shift_left(resize(mul_a_reg, 48), mul_idx_reg);
          end if;
          mul_acc_reg <= mul_add;
          mul_b_reg <= shift_right(mul_b_reg, 1);
          if mul_idx_reg = 23 then
            state_reg <= ST_PACK_MUL;
          else
            mul_idx_reg <= mul_idx_reg + 1;
          end if;

        when ST_DIV_ITER =>
          rem_next := shift_left(div_rem_reg, 1);
          quot_next := div_quot_reg;
          if rem_next >= ('0' & div_divisor_reg) then
            rem_next := rem_next - ('0' & div_divisor_reg);
            quot_next(div_idx_reg) := '1';
          else
            quot_next(div_idx_reg) := '0';
          end if;
          div_rem_reg <= rem_next;
          div_quot_reg <= quot_next;
          if div_idx_reg = 0 then
            state_reg <= ST_PACK_DIV;
          else
            div_idx_reg <= div_idx_reg - 1;
          end if;

        when ST_PACK_MUL =>
          res_u.sign := mul_sign_reg;
          mant64 := (others => '0');
          if mul_acc_reg = 0 then
            result_reg <= FP80_ZERO;
            state_reg <= ST_DONE;
          else
            exp_i := mul_exp_base_reg;
            if mul_acc_reg(47) = '1' then
              sig24 := mul_acc_reg(47 downto 24);
              guard_bit := mul_acc_reg(23);
              if mul_acc_reg(22 downto 0) /= 0 then
                sticky_bit := '1';
              else
                sticky_bit := '0';
              end if;
              exp_i := exp_i + 1;
            else
              sig24 := mul_acc_reg(46 downto 23);
              guard_bit := mul_acc_reg(22);
              if mul_acc_reg(21 downto 0) /= 0 then
                sticky_bit := '1';
              else
                sticky_bit := '0';
              end if;
            end if;

            if should_round_up(mul_sign_reg, rm_reg, guard_bit, sticky_bit, sig24(0)) then
              sig25 := ('0' & sig24) + 1;
              if sig25(24) = '1' then
                sig24 := sig25(24 downto 1);
                exp_i := exp_i + 1;
              else
                sig24 := sig25(23 downto 0);
              end if;
            end if;

            if exp_i <= 0 then
              result_reg <= FP80_ZERO;
            elsif exp_i >= FP_EXP_MAX then
              res_u.exp := FP_EXP_ALL_ONES;
              res_u.mant := (others => '0');
              result_reg <= pack_fp80(res_u);
            else
              res_u.exp := to_unsigned(exp_i, FP_EXP_WIDTH);
              mant64(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24) := sig24;
              res_u.mant := mant64;
              result_reg <= pack_fp80(res_u);
            end if;
            state_reg <= ST_DONE;
          end if;

        when ST_PACK_DIV =>
          res_u.sign := div_sign_reg;
          mant64 := (others => '0');
          div_is_zero := div_quot_reg = 0;
          if div_is_zero then
            result_reg <= FP80_ZERO;
            state_reg <= ST_DONE;
          else
            exp_i := div_exp_base_reg;
            sig24 := div_quot_reg;

            div_next_rem := shift_left(div_rem_reg, 1);
            if div_next_rem >= ('0' & div_divisor_reg) then
              div_next_guard := '1';
              div_next_rem := div_next_rem - ('0' & div_divisor_reg);
            else
              div_next_guard := '0';
            end if;

            if div_next_rem /= 0 then
              sticky_bit := '1';
            else
              sticky_bit := '0';
            end if;
            guard_bit := div_next_guard;

            if sig24(23) = '0' then
              sig24 := sig24(22 downto 0) & guard_bit;
              div_next_rem2 := shift_left(div_next_rem, 1);
              if div_next_rem2 >= ('0' & div_divisor_reg) then
                guard_bit := '1';
                div_next_rem2 := div_next_rem2 - ('0' & div_divisor_reg);
              else
                guard_bit := '0';
              end if;
              if div_next_rem2 /= 0 then
                sticky_bit := '1';
              end if;
              exp_i := exp_i - 1;
            end if;

            if should_round_up(div_sign_reg, rm_reg, guard_bit, sticky_bit, sig24(0)) then
              sig25 := ('0' & sig24) + 1;
              if sig25(24) = '1' then
                sig24 := sig25(24 downto 1);
                exp_i := exp_i + 1;
              else
                sig24 := sig25(23 downto 0);
              end if;
            end if;

            if exp_i <= 0 then
              result_reg <= FP80_ZERO;
            elsif exp_i >= FP_EXP_MAX then
              res_u.exp := FP_EXP_ALL_ONES;
              res_u.mant := (others => '0');
              result_reg <= pack_fp80(res_u);
            else
              res_u.exp := to_unsigned(exp_i, FP_EXP_WIDTH);
              mant64(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24) := sig24;
              res_u.mant := mant64;
              result_reg <= pack_fp80(res_u);
            end if;
            state_reg <= ST_DONE;
          end if;

        when ST_DONE =>
          done_reg <= '1';
          state_reg <= ST_IDLE;
      end case;
    end if;
  end process;

  busy <= '0' when state_reg = ST_IDLE else '1';
  done <= done_reg;
  result <= result_reg;
end architecture rtl;
