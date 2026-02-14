library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_divrem_unit is
  port (
    clk     : in  std_logic;
    reset_n : in  std_logic;
    start   : in  std_logic;
    op_sel  : in  fpu_op_t;
    a_in    : in  fp80_t;
    b_in    : in  fp80_t;
    round_mode : in fp_round_mode_t;
    round_prec : in fp_round_prec_t;
    busy    : out std_logic;
    done    : out std_logic;
    result  : out fp80_t;
    quotient_byte  : out std_logic_vector(7 downto 0);
    quotient_valid : out std_logic;
    flag_invalid   : out std_logic;
    flag_divzero   : out std_logic;
    flag_overflow  : out std_logic;
    flag_underflow : out std_logic;
    flag_inexact   : out std_logic
  );
end entity mc68881_divrem_unit;

architecture rtl of mc68881_divrem_unit is
  constant FP_GRS_BITS : natural := 3;
  constant FP_MANT_EXT_WIDTH : natural := FP_MANT_WIDTH + FP_GRS_BITS;
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP_EXP_MAX : integer := (2**FP_EXP_WIDTH) - 1;
  constant DIV_Q_BITS : natural := FP_MANT_WIDTH + FP_GRS_BITS;
  constant DIVIDEND_BITS : natural := FP_MANT_WIDTH + DIV_Q_BITS;
  constant REM_WIDTH : natural := FP_MANT_EXT_WIDTH + 2;
  constant SQRT_SCALE_SHIFT : natural := FP_MANT_WIDTH - 1 + FP_GRS_BITS - 32;
  constant SQRT_MANT_EVEN_WIDTH : natural := FP_MANT_WIDTH + 2;
  constant SQRT_RADICAND_BITS : natural := SQRT_MANT_EVEN_WIDTH + (2 * SQRT_SCALE_SHIFT);
  constant FP80_ZERO : fp80_t := x"00000000000000000000";
  constant FP80_ONE  : fp80_t := x"3FFF8000000000000000";
  constant FP80_HALF : fp80_t := x"3FFE8000000000000000";

  type fp_unpacked_t is record
    sign : std_logic;
    exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  end record;

  type state_t is (
    ST_IDLE,
    ST_CLASSIFY,
    ST_DIV_ITER,
    ST_POST_DIV,
    ST_SQRT_ITER,
    ST_SQRT_POST,
    ST_MOD_ROUND,
    ST_MOD_PRODUCT,
    ST_MOD_SUB,
    ST_DONE
  );

  signal state_reg : state_t := ST_IDLE;
  signal op_reg : fpu_op_t := FPU_OP_NOP;
  signal a_reg : fp80_t := (others => '0');
  signal b_reg : fp80_t := (others => '0');
  signal rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;

  signal divisor_reg : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  signal dividend_reg : unsigned(DIVIDEND_BITS-1 downto 0) := (others => '0');
  signal rem_reg : unsigned(REM_WIDTH-1 downto 0) := (others => '0');
  signal quot_reg : unsigned(DIVIDEND_BITS-1 downto 0) := (others => '0');
  signal iter_idx_reg : integer range 0 to DIVIDEND_BITS-1 := 0;
  signal div_sign_reg : std_logic := '0';
  signal div_exp_base_reg : integer := 0;
  signal sqrt_radicand_reg : unsigned(SQRT_RADICAND_BITS-1 downto 0) := (others => '0');
  signal sqrt_root_reg : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
  signal sqrt_iter_idx_reg : integer range 0 to FP_MANT_EXT_WIDTH-1 := 0;
  signal sqrt_exp_out_reg : integer := 0;

  signal div_result_reg : fp80_t := (others => '0');
  signal n_fp_reg : fp80_t := (others => '0');
  signal result_reg : fp80_t := (others => '0');
  signal quotient_byte_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal quotient_valid_reg : std_logic := '0';
  signal done_reg : std_logic := '0';

  signal flag_invalid_reg : std_logic := '0';
  signal flag_divzero_reg : std_logic := '0';
  signal flag_overflow_reg : std_logic := '0';
  signal flag_underflow_reg : std_logic := '0';
  signal flag_inexact_reg : std_logic := '0';

  function prec_bits(prec : fp_round_prec_t) return natural is
  begin
    case prec is
      when FP_PREC_SINGLE => return 24;
      when FP_PREC_DOUBLE => return 53;
      when others => return FP_MANT_WIDTH;
    end case;
  end function;

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

  function shift_right_with_sticky(value : unsigned; shift : natural) return unsigned is
    variable shifted : unsigned(value'length-1 downto 0) := (others => '0');
    variable sticky : std_logic := '0';
  begin
    if shift = 0 then
      return value;
    end if;

    if shift >= value'length then
      if value /= 0 then
        sticky := '1';
      end if;
      shifted(0) := sticky;
      return shifted;
    end if;

    if value(shift-1 downto 0) /= 0 then
      sticky := '1';
    end if;

    shifted := shift_right(value, shift);
    if sticky = '1' then
      shifted(0) := '1';
    end if;
    return shifted;
  end function;

  procedure apply_rounding(
    sign       : in  std_logic;
    mant_ext   : in  unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    exp_in     : in  integer;
    rnd_mode   : in  fp_round_mode_t;
    rnd_prec   : in  fp_round_prec_t;
    mant_out   : out unsigned(FP_MANT_WIDTH-1 downto 0);
    exp_out    : out integer;
    inexact_out : out std_logic
  ) is
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable mant_round : unsigned(FP_MANT_WIDTH downto 0) := (others => '0');
    variable guard      : std_logic := '0';
    variable round_bit  : std_logic := '0';
    variable sticky     : std_logic := '0';
    variable increment  : std_logic := '0';
    variable any_disc   : std_logic := '0';
    variable prec_w     : natural := FP_MANT_WIDTH;
    variable drop_bits  : natural := 0;
    variable lsb_keep   : integer := FP_GRS_BITS;
    variable exp_var    : integer := 0;
  begin
    mant_main := mant_ext(FP_MANT_EXT_WIDTH-1 downto FP_GRS_BITS);
    prec_w := prec_bits(rnd_prec);
    drop_bits := FP_MANT_WIDTH - prec_w;
    lsb_keep := FP_GRS_BITS + integer(drop_bits);

    guard := mant_ext(lsb_keep-1);
    round_bit := mant_ext(lsb_keep-2);
    if lsb_keep > 2 then
      if mant_ext(lsb_keep-3 downto 0) /= 0 then
        sticky := '1';
      end if;
    end if;

    any_disc := guard or round_bit or sticky;
    case rnd_mode is
      when FP_RND_NEAREST =>
        if guard = '1' and (round_bit = '1' or sticky = '1' or mant_main(drop_bits) = '1') then
          increment := '1';
        end if;
      when FP_RND_ZERO =>
        increment := '0';
      when FP_RND_MINUS_INF =>
        if sign = '1' and any_disc = '1' then
          increment := '1';
        end if;
      when FP_RND_PLUS_INF =>
        if sign = '0' and any_disc = '1' then
          increment := '1';
        end if;
    end case;

    exp_var := exp_in;
    if increment = '1' then
      mant_round := ('0' & mant_main) + (to_unsigned(1, FP_MANT_WIDTH+1) sll drop_bits);
      if mant_round(mant_round'left) = '1' then
        mant_main := shift_right_with_sticky(mant_round(mant_round'left-1 downto 0), 1);
        mant_main(mant_main'left) := '1';
        exp_var := exp_var + 1;
      else
        mant_main := mant_round(mant_round'left-1 downto 0);
      end if;
    end if;

    if drop_bits > 0 then
      mant_main(drop_bits-1 downto 0) := (others => '0');
    end if;

    mant_out := mant_main;
    exp_out := exp_var;
    inexact_out := any_disc;
  end procedure;

  function fp80_is_zero(value : fp80_t) return boolean is
    variable u : fp_unpacked_t := unpack_fp80(value);
  begin
    return u.exp = 0 and u.mant = 0;
  end function;

  function fp80_is_inf(value : fp80_t) return boolean is
    variable u : fp_unpacked_t := unpack_fp80(value);
  begin
    return u.exp = FP_EXP_ALL_ONES and u.mant = 0;
  end function;

  function fp80_is_nan(value : fp80_t) return boolean is
    variable u : fp_unpacked_t := unpack_fp80(value);
  begin
    return u.exp = FP_EXP_ALL_ONES and u.mant /= 0;
  end function;

  function canonical_qnan return fp80_t is
    variable res : fp_unpacked_t;
  begin
    res.sign := '0';
    res.exp := FP_EXP_ALL_ONES;
    res.mant := (others => '0');
    res.mant(FP_MANT_WIDTH-1) := '1';
    res.mant(FP_MANT_WIDTH-2) := '1';
    return pack_fp80(res);
  end function;

  function fp80_trunc_toward_zero_local(value : fp80_t) return fp80_t is
    variable value_u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable frac_bits : integer := 0;
    variable result_u : fp_unpacked_t := value_u;
  begin
    if value_u.exp = 0 or value_u.exp = FP_EXP_ALL_ONES then
      return value;
    end if;

    exp_i := to_integer(value_u.exp) - FP_EXP_BIAS;
    if exp_i < 0 then
      result_u.exp := (others => '0');
      result_u.mant := (others => '0');
      return pack_fp80(result_u);
    end if;

    if exp_i >= integer(FP_MANT_WIDTH - 1) then
      return value;
    end if;

    frac_bits := integer(FP_MANT_WIDTH - 1) - exp_i;
    for bit_idx in 0 to FP_MANT_WIDTH-1 loop
      if bit_idx < frac_bits then
        result_u.mant(bit_idx) := '0';
      end if;
    end loop;
    return pack_fp80(result_u);
  end function;

  function fp80_is_odd_integer_local(value : fp80_t) return boolean is
    variable value_u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable lsb_idx : integer := 0;
  begin
    if value_u.exp = 0 or value_u.exp = FP_EXP_ALL_ONES then
      return false;
    end if;

    exp_i := to_integer(value_u.exp) - FP_EXP_BIAS;
    if exp_i < 0 then
      return false;
    end if;

    if exp_i > integer(FP_MANT_WIDTH - 1) then
      return false;
    end if;

    lsb_idx := integer(FP_MANT_WIDTH - 1) - exp_i;
    return value_u.mant(lsb_idx) = '1';
  end function;

  function quotient_byte_from_fp_integer(value : fp80_t) return std_logic_vector is
    variable u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable shift_amt : integer := 0;
    variable bits : unsigned(6 downto 0) := (others => '0');
    variable sign_bit : std_logic := '0';
    variable qbyte : std_logic_vector(7 downto 0) := (others => '0');
  begin
    if u.exp = 0 or u.exp = FP_EXP_ALL_ONES or u.mant = 0 then
      return (7 downto 0 => '0');
    end if;

    sign_bit := u.sign;
    exp_i := to_integer(u.exp) - FP_EXP_BIAS;
    if exp_i < 0 then
      return (7 downto 0 => '0');
    end if;

    if exp_i >= integer(FP_MANT_WIDTH - 1) then
      shift_amt := exp_i - integer(FP_MANT_WIDTH - 1);
      if shift_amt >= 7 then
        bits := (others => '0');
      else
        -- Avoid variable-range slicing that can create null-range warnings.
        bits := resize(shift_left(u.mant, shift_amt), 7);
      end if;
    else
      shift_amt := integer(FP_MANT_WIDTH - 1) - exp_i;
      bits := resize(shift_right(u.mant, shift_amt), 7);
    end if;

    qbyte(7) := sign_bit;
    qbyte(6 downto 0) := std_logic_vector(bits);
    return qbyte;
  end function;

begin
  process(clk, reset_n)
    variable a_u : fp_unpacked_t;
    variable b_u : fp_unpacked_t;
    variable rem_next : unsigned(REM_WIDTH-1 downto 0);
    variable quot_next : unsigned(DIVIDEND_BITS-1 downto 0);
    variable root_next : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    variable trial : unsigned(REM_WIDTH-1 downto 0);
    variable divisor_ext : unsigned(REM_WIDTH-1 downto 0);
    variable mant_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable exp_res_i : integer := 0;
    variable exp_unbiased : integer := 0;
    variable top_idx : integer := 0;
    variable lead_idx : integer := 0;
    variable pair_hi : integer := 0;
    variable div_res_u : fp_unpacked_t;
    variable inexact_local : std_logic := '0';
    variable quotient_fp : fp80_t := (others => '0');
    variable quotient_trunc : fp80_t := (others => '0');
    variable nearest_q : fp80_t := (others => '0');
    variable frac : fp80_t := (others => '0');
    variable frac_abs : fp80_t := (others => '0');
    variable half_cmp : integer := 0;
    variable one_fp : fp80_t := FP80_ONE;
    variable product_fp : fp80_t := (others => '0');
    variable remainder_fp : fp80_t := (others => '0');
    variable div_mul2 : unsigned(REM_WIDTH-1 downto 0) := (others => '0');
    variable div_mul3 : unsigned(REM_WIDTH-1 downto 0) := (others => '0');
    variable div_final_result : fp80_t := (others => '0');
    variable div_round_mode : fp_round_mode_t := FP_RND_NEAREST;
    variable div_round_prec : fp_round_prec_t := FP_PREC_EXTENDED;
    variable mantissa_even : unsigned(SQRT_MANT_EVEN_WIDTH-1 downto 0) := (others => '0');
  begin
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      result_reg <= (others => '0');
      quotient_byte_reg <= (others => '0');
      quotient_valid_reg <= '0';
      done_reg <= '0';
      flag_invalid_reg <= '0';
      flag_divzero_reg <= '0';
      flag_overflow_reg <= '0';
      flag_underflow_reg <= '0';
      flag_inexact_reg <= '0';
    elsif rising_edge(clk) then
      done_reg <= '0';
      quotient_valid_reg <= '0';

      case state_reg is
        when ST_IDLE =>
          if start = '1' then
            op_reg <= op_sel;
            a_reg <= a_in;
            b_reg <= b_in;
            rm_reg <= round_mode;
            rp_reg <= round_prec;
            flag_invalid_reg <= '0';
            flag_divzero_reg <= '0';
            flag_overflow_reg <= '0';
            flag_underflow_reg <= '0';
            flag_inexact_reg <= '0';
            quotient_byte_reg <= (others => '0');
            state_reg <= ST_CLASSIFY;
          end if;

        when ST_CLASSIFY =>
          a_u := unpack_fp80(a_reg);
          b_u := unpack_fp80(b_reg);

          if op_reg = FPU_OP_DIV then
            if fp80_is_nan(a_reg) or fp80_is_nan(b_reg) then
              result_reg <= canonical_qnan;
              flag_invalid_reg <= '1';
              state_reg <= ST_DONE;
            elsif b_u.exp = 0 and b_u.mant = 0 then
              div_res_u.sign := a_u.sign xor b_u.sign;
              div_res_u.exp := FP_EXP_ALL_ONES;
              div_res_u.mant := (others => '0');
              result_reg <= pack_fp80(div_res_u);
              if a_u.exp = 0 and a_u.mant = 0 then
                flag_invalid_reg <= '1';
              else
                flag_divzero_reg <= '1';
              end if;
              state_reg <= ST_DONE;
            elsif a_u.exp = 0 and a_u.mant = 0 then
              result_reg <= FP80_ZERO;
              state_reg <= ST_DONE;
            elsif a_u.exp = FP_EXP_ALL_ONES or b_u.exp = FP_EXP_ALL_ONES then
              div_res_u.sign := a_u.sign xor b_u.sign;
              div_res_u.exp := FP_EXP_ALL_ONES;
              div_res_u.mant := (others => '0');
              result_reg <= pack_fp80(div_res_u);
              if a_u.exp = FP_EXP_ALL_ONES and b_u.exp = FP_EXP_ALL_ONES then
                flag_invalid_reg <= '1';
              end if;
              state_reg <= ST_DONE;
            else
              divisor_reg <= b_u.mant;
              dividend_reg <= a_u.mant & to_unsigned(0, DIV_Q_BITS);
              rem_reg <= (others => '0');
              quot_reg <= (others => '0');
              iter_idx_reg <= DIVIDEND_BITS-1;
              div_sign_reg <= a_u.sign xor b_u.sign;
              div_exp_base_reg <= to_integer(a_u.exp) - to_integer(b_u.exp) + FP_EXP_BIAS;
              state_reg <= ST_DIV_ITER;
            end if;
          elsif op_reg = FPU_OP_SQRT then
            if fp80_is_nan(a_reg) then
              result_reg <= canonical_qnan;
              flag_invalid_reg <= '1';
              state_reg <= ST_DONE;
            elsif fp80_is_inf(a_reg) then
              if a_u.sign = '1' then
                result_reg <= canonical_qnan;
                flag_invalid_reg <= '1';
              else
                result_reg <= a_reg;
              end if;
              state_reg <= ST_DONE;
            elsif a_u.exp = 0 and a_u.mant = 0 then
              -- Preserve signed zero for sqrt(+-0).
              result_reg <= a_reg;
              state_reg <= ST_DONE;
            elsif a_u.sign = '1' then
              result_reg <= canonical_qnan;
              flag_invalid_reg <= '1';
              state_reg <= ST_DONE;
            else
              if a_u.exp = 0 then
                exp_unbiased := 1 - FP_EXP_BIAS;
                mantissa_even := resize(a_u.mant, SQRT_MANT_EVEN_WIDTH);
                for idx in 0 to FP_MANT_WIDTH-1 loop
                  exit when mantissa_even(mantissa_even'left) = '1';
                  mantissa_even := shift_left(mantissa_even, 1);
                  exp_unbiased := exp_unbiased - 1;
                end loop;
              else
                exp_unbiased := to_integer(a_u.exp) - FP_EXP_BIAS;
                mantissa_even := resize(a_u.mant, SQRT_MANT_EVEN_WIDTH);
              end if;

              if (exp_unbiased mod 2) /= 0 then
                exp_unbiased := exp_unbiased - 1;
                mantissa_even := shift_left(mantissa_even, 2);
              else
                mantissa_even := shift_left(mantissa_even, 1);
              end if;

              sqrt_exp_out_reg <= exp_unbiased / 2 + FP_EXP_BIAS;
              sqrt_radicand_reg <= shift_left(resize(mantissa_even, SQRT_RADICAND_BITS), 2 * SQRT_SCALE_SHIFT);
              sqrt_root_reg <= (others => '0');
              rem_reg <= (others => '0');
              sqrt_iter_idx_reg <= 0;
              state_reg <= ST_SQRT_ITER;
            end if;
          else
            if fp80_is_nan(a_reg) or fp80_is_nan(b_reg) or fp80_is_inf(a_reg) or (b_u.exp = 0 and b_u.mant = 0) then
              result_reg <= canonical_qnan;
              flag_invalid_reg <= '1';
              state_reg <= ST_DONE;
            elsif a_u.exp = 0 and a_u.mant = 0 then
              result_reg <= FP80_ZERO;
              quotient_byte_reg <= (others => '0');
              quotient_valid_reg <= '1';
              state_reg <= ST_DONE;
            elsif fp80_is_inf(b_reg) then
              result_reg <= a_reg;
              quotient_byte_reg <= (others => '0');
              quotient_valid_reg <= '1';
              state_reg <= ST_DONE;
            else
              divisor_reg <= b_u.mant;
              dividend_reg <= a_u.mant & to_unsigned(0, DIV_Q_BITS);
              rem_reg <= (others => '0');
              quot_reg <= (others => '0');
              iter_idx_reg <= DIVIDEND_BITS-1;
              div_sign_reg <= a_u.sign xor b_u.sign;
              div_exp_base_reg <= to_integer(a_u.exp) - to_integer(b_u.exp) + FP_EXP_BIAS;
              state_reg <= ST_DIV_ITER;
            end if;
          end if;

        when ST_DIV_ITER =>
          quot_next := quot_reg;
          divisor_ext := resize("00" & divisor_reg, REM_WIDTH);
          if iter_idx_reg = DIVIDEND_BITS-1 then
            rem_next := shift_left(rem_reg, 1);
            rem_next(0) := dividend_reg(iter_idx_reg);
            if rem_next >= divisor_ext then
              rem_next := rem_next - divisor_ext;
              quot_next(iter_idx_reg) := '1';
            else
              quot_next(iter_idx_reg) := '0';
            end if;
            rem_reg <= rem_next;
            quot_reg <= quot_next;
            iter_idx_reg <= iter_idx_reg - 1;
          else
            rem_next := shift_left(rem_reg, 2);
            rem_next(1 downto 0) := dividend_reg(iter_idx_reg downto iter_idx_reg-1);
            div_mul2 := shift_left(divisor_ext, 1);
            div_mul3 := divisor_ext + div_mul2;
            if rem_next >= div_mul3 then
              rem_next := rem_next - div_mul3;
              quot_next(iter_idx_reg downto iter_idx_reg-1) := "11";
            elsif rem_next >= div_mul2 then
              rem_next := rem_next - div_mul2;
              quot_next(iter_idx_reg downto iter_idx_reg-1) := "10";
            elsif rem_next >= divisor_ext then
              rem_next := rem_next - divisor_ext;
              quot_next(iter_idx_reg downto iter_idx_reg-1) := "01";
            else
              quot_next(iter_idx_reg downto iter_idx_reg-1) := "00";
            end if;
            rem_reg <= rem_next;
            quot_reg <= quot_next;

            if iter_idx_reg <= 1 then
              state_reg <= ST_POST_DIV;
            else
              iter_idx_reg <= iter_idx_reg - 2;
            end if;
          end if;

        when ST_SQRT_ITER =>
          pair_hi := SQRT_RADICAND_BITS-1 - (sqrt_iter_idx_reg * 2);
          rem_next := shift_left(rem_reg, 2);
          rem_next(1 downto 0) := sqrt_radicand_reg(pair_hi downto pair_hi-1);
          trial := shift_left(resize(sqrt_root_reg, REM_WIDTH), 2) + to_unsigned(1, REM_WIDTH);
          root_next := shift_left(sqrt_root_reg, 1);
          if rem_next >= trial then
            rem_next := rem_next - trial;
            root_next(0) := '1';
          end if;
          rem_reg <= rem_next;
          sqrt_root_reg <= root_next;
          if sqrt_iter_idx_reg = FP_MANT_EXT_WIDTH-1 then
            state_reg <= ST_SQRT_POST;
          else
            sqrt_iter_idx_reg <= sqrt_iter_idx_reg + 1;
          end if;

        when ST_SQRT_POST =>
          mant_ext := sqrt_root_reg;
          exp_res_i := sqrt_exp_out_reg;
          inexact_local := '0';
          if rem_reg /= 0 then
            mant_ext(0) := '1';
            inexact_local := '1';
          end if;

          apply_rounding('0', mant_ext, exp_res_i, rm_reg, rp_reg, mant_main, exp_res_i, inexact_local);

          div_res_u.sign := '0';
          if mant_main = 0 then
            div_res_u.exp := (others => '0');
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
          elsif exp_res_i <= 0 then
            div_res_u.exp := (others => '0');
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
            flag_underflow_reg <= '1';
          elsif exp_res_i >= FP_EXP_MAX then
            div_res_u.exp := FP_EXP_ALL_ONES;
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
            flag_overflow_reg <= '1';
          else
            div_res_u.exp := to_unsigned(exp_res_i, FP_EXP_WIDTH);
            div_res_u.mant := mant_main;
            div_final_result := pack_fp80(div_res_u);
          end if;

          result_reg <= div_final_result;
          flag_inexact_reg <= inexact_local;
          state_reg <= ST_DONE;

        when ST_POST_DIV =>
          top_idx := integer(DIV_Q_BITS);
          inexact_local := '0';
          if rem_reg /= 0 then
            inexact_local := '1';
          end if;

          lead_idx := 0;
          for idx in quot_reg'high downto 0 loop
            if quot_reg(idx) = '1' then
              lead_idx := idx;
              exit;
            end if;
          end loop;

          exp_res_i := div_exp_base_reg + (lead_idx - top_idx);
          if lead_idx >= FP_MANT_EXT_WIDTH-1 then
            mant_ext := quot_reg(lead_idx downto lead_idx-(FP_MANT_EXT_WIDTH-1));
            if lead_idx > FP_MANT_EXT_WIDTH and quot_reg(lead_idx-FP_MANT_EXT_WIDTH-1 downto 0) /= 0 then
              mant_ext(0) := '1';
            end if;
          else
            mant_ext := resize(shift_left(quot_reg, (FP_MANT_EXT_WIDTH-1)-lead_idx), FP_MANT_EXT_WIDTH);
          end if;
          if rem_reg /= 0 then
            mant_ext(0) := '1';
          end if;

          -- FMOD/FREM must derive quotient selection from an extended-precision
          -- quotient independent of caller FPCR rounding/precision.
          if op_reg = FPU_OP_DIV then
            div_round_mode := rm_reg;
            div_round_prec := rp_reg;
          else
            div_round_mode := FP_RND_NEAREST;
            div_round_prec := FP_PREC_EXTENDED;
          end if;

          apply_rounding(div_sign_reg, mant_ext, exp_res_i, div_round_mode, div_round_prec, mant_main, exp_res_i, inexact_local);

          div_res_u.sign := div_sign_reg;
          if mant_main = 0 then
            div_res_u.sign := '0';
            div_res_u.exp := (others => '0');
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
          elsif exp_res_i <= 0 then
            div_res_u.sign := '0';
            div_res_u.exp := (others => '0');
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
            flag_underflow_reg <= '1';
          elsif exp_res_i >= FP_EXP_MAX then
            div_res_u.exp := FP_EXP_ALL_ONES;
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
            flag_overflow_reg <= '1';
          else
            div_res_u.exp := to_unsigned(exp_res_i, FP_EXP_WIDTH);
            div_res_u.mant := mant_main;
            div_final_result := pack_fp80(div_res_u);
          end if;
          div_result_reg <= div_final_result;
          flag_inexact_reg <= inexact_local;

          if op_reg = FPU_OP_DIV then
            result_reg <= div_final_result;
            state_reg <= ST_DONE;
          else
            state_reg <= ST_MOD_ROUND;
          end if;

        when ST_MOD_ROUND =>
          quotient_fp := div_result_reg;
          if op_reg = FPU_OP_MOD then
            quotient_trunc := fp80_trunc_toward_zero_local(quotient_fp);
            n_fp_reg <= quotient_trunc;
            quotient_byte_reg <= quotient_byte_from_fp_integer(quotient_trunc);
          else
            quotient_trunc := fp80_trunc_toward_zero_local(quotient_fp);
            nearest_q := quotient_trunc;
            frac := add_sub_fp80(quotient_fp, quotient_trunc, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
            frac_abs := abs_fp80(frac);
            half_cmp := compare_fp80(frac_abs, FP80_HALF);
            if half_cmp > 0 then
              if quotient_fp(FP_WIDTH-1) = '1' then
                nearest_q := add_sub_fp80(nearest_q, one_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
              else
                nearest_q := add_sub_fp80(nearest_q, one_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
              end if;
            elsif half_cmp = 0 and fp80_is_odd_integer_local(quotient_trunc) then
              if quotient_fp(FP_WIDTH-1) = '1' then
                nearest_q := add_sub_fp80(nearest_q, one_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
              else
                nearest_q := add_sub_fp80(nearest_q, one_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
              end if;
            end if;

            n_fp_reg <= nearest_q;
            quotient_byte_reg <= quotient_byte_from_fp_integer(nearest_q);
          end if;
          quotient_valid_reg <= '1';
          state_reg <= ST_MOD_PRODUCT;

        when ST_MOD_PRODUCT =>
          product_fp := mul_fp80(b_reg, n_fp_reg, FP_RND_NEAREST, FP_PREC_EXTENDED);
          div_result_reg <= product_fp;
          state_reg <= ST_MOD_SUB;

        when ST_MOD_SUB =>
          remainder_fp := add_sub_fp80(a_reg, div_result_reg, true, rm_reg, rp_reg);
          result_reg <= remainder_fp;
          state_reg <= ST_DONE;

        when ST_DONE =>
          done_reg <= '1';
          state_reg <= ST_IDLE;
      end case;
    end if;
  end process;

  busy <= '1' when state_reg /= ST_IDLE else '0';
  done <= done_reg;
  result <= result_reg;
  quotient_byte <= quotient_byte_reg;
  quotient_valid <= quotient_valid_reg;
  flag_invalid <= flag_invalid_reg;
  flag_divzero <= flag_divzero_reg;
  flag_overflow <= flag_overflow_reg;
  flag_underflow <= flag_underflow_reg;
  flag_inexact <= flag_inexact_reg;
end architecture rtl;
