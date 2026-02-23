library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_modrem_post_unit is
  port (
    clk     : in  std_logic;
    reset_n : in  std_logic;
    start   : in  std_logic;
    op_sel  : in  fpu_op_t;
    a_in    : in  fp80_t;
    b_in    : in  fp80_t;
    quotient_in : in fp80_t;
    round_mode : in fp_round_mode_t;
    round_prec : in fp_round_prec_t;
    busy    : out std_logic;
    done    : out std_logic;
    result  : out fp80_t;
    quotient_byte  : out std_logic_vector(7 downto 0);
    quotient_valid : out std_logic
  );
end entity mc68881_modrem_post_unit;

architecture rtl of mc68881_modrem_post_unit is
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP80_ONE  : fp80_t := x"3FFF8000000000000000";
  constant FP80_HALF : fp80_t := x"3FFE8000000000000000";

  type fp_unpacked_t is record
    sign : std_logic;
    exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  end record;

  type state_t is (
    ST_IDLE,
    ST_ROUND,
    ST_FP_ADD,
    ST_FP_MUL,
    ST_FRAC,
    ST_ADJUST,
    ST_PRODUCT,
    ST_SUB,
    ST_DONE
  );

  signal state_reg : state_t := ST_IDLE;
  signal op_reg : fpu_op_t := FPU_OP_NOP;
  signal a_reg : fp80_t := (others => '0');
  signal b_reg : fp80_t := (others => '0');
  signal quotient_reg : fp80_t := (others => '0');
  signal rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;
  signal n_fp_reg : fp80_t := (others => '0');

  signal result_reg : fp80_t := (others => '0');
  signal quotient_byte_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal quotient_valid_reg : std_logic := '0';
  signal done_reg : std_logic := '0';

  signal mod_fp_add_a      : fp80_t := (others => '0');
  signal mod_fp_add_b      : fp80_t := (others => '0');
  signal mod_fp_add_is_sub : boolean := false;
  signal mod_fp_add_rm     : fp_round_mode_t := FP_RND_NEAREST;
  signal mod_fp_add_rp     : fp_round_prec_t := FP_PREC_EXTENDED;
  signal mod_fp_mul_a      : fp80_t := (others => '0');
  signal mod_fp_mul_b      : fp80_t := (others => '0');
  signal mod_add_result_reg : fp80_t := (others => '0');
  signal mod_mul_result_reg : fp80_t := (others => '0');

  -- Prevent Vivado from folding add/mul result registers into result_reg,
  -- which pulls the add_sub_fp80/mul_fp80 carry-chain logic into the
  -- result_reg data cone and creates synthesis combinational loops (TIMING-23).
  attribute DONT_TOUCH : string;
  attribute DONT_TOUCH of mod_add_result_reg : signal is "TRUE";
  attribute DONT_TOUCH of mod_mul_result_reg : signal is "TRUE";

  signal mod_fp_cont_state_reg : state_t := ST_IDLE;
  signal mod_fp_wait_count_reg : integer range 0 to 3 := 0;
  signal fp_hold_loaded_reg    : std_logic := '0';

  function unpack_fp80(value : fp80_t) return fp_unpacked_t is
    variable unpacked : fp_unpacked_t;
  begin
    unpacked.sign := value(FP_WIDTH-1);
    unpacked.exp := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    unpacked.mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return unpacked;
  end function;

  function fp80_trunc_toward_zero_local(value : fp80_t) return fp80_t is
    variable value_u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable frac_bits : integer := 0;
    variable result_u : fp_unpacked_t := value_u;
    variable packed : fp80_t := value;
  begin
    if value_u.exp = 0 or value_u.exp = FP_EXP_ALL_ONES then
      return value;
    end if;

    exp_i := to_integer(value_u.exp) - FP_EXP_BIAS;
    if exp_i < 0 then
      result_u.exp := (others => '0');
      result_u.mant := (others => '0');
      packed(FP_WIDTH-1) := result_u.sign;
      packed(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(result_u.exp);
      packed(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(result_u.mant);
      return packed;
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
    packed(FP_WIDTH-1) := result_u.sign;
    packed(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(result_u.exp);
    packed(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(result_u.mant);
    return packed;
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
    variable quotient_fp : fp80_t := (others => '0');
    variable quotient_trunc : fp80_t := (others => '0');
    variable frac : fp80_t := (others => '0');
    variable frac_abs : fp80_t := (others => '0');
    variable half_cmp : integer := 0;
  begin
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      op_reg <= FPU_OP_NOP;
      a_reg <= (others => '0');
      b_reg <= (others => '0');
      quotient_reg <= (others => '0');
      rm_reg <= FP_RND_NEAREST;
      rp_reg <= FP_PREC_EXTENDED;
      n_fp_reg <= (others => '0');
      result_reg <= (others => '0');
      quotient_byte_reg <= (others => '0');
      quotient_valid_reg <= '0';
      done_reg <= '0';
      mod_fp_cont_state_reg <= ST_IDLE;
      mod_fp_wait_count_reg <= 0;
      fp_hold_loaded_reg <= '0';
      mod_add_result_reg <= (others => '0');
      mod_mul_result_reg <= (others => '0');
    elsif rising_edge(clk) then
      done_reg <= '0';

      case state_reg is
        when ST_IDLE =>
          if start = '1' then
            op_reg <= op_sel;
            a_reg <= a_in;
            b_reg <= b_in;
            quotient_reg <= quotient_in;
            rm_reg <= round_mode;
            rp_reg <= round_prec;
            quotient_byte_reg <= (others => '0');
            quotient_valid_reg <= '0';
            state_reg <= ST_ROUND;
          end if;

        when ST_ROUND =>
          quotient_fp := quotient_reg;
          quotient_trunc := fp80_trunc_toward_zero_local(quotient_fp);
          n_fp_reg <= quotient_trunc;
          if op_reg = FPU_OP_MOD then
            quotient_byte_reg <= quotient_byte_from_fp_integer(quotient_trunc);
            quotient_valid_reg <= '1';
            mod_fp_mul_a <= b_reg;
            mod_fp_mul_b <= quotient_trunc;
            mod_fp_cont_state_reg <= ST_PRODUCT;
            state_reg <= ST_FP_MUL;
          else
            mod_fp_add_a <= quotient_fp;
            mod_fp_add_b <= quotient_trunc;
            mod_fp_add_is_sub <= true;
            mod_fp_add_rm <= FP_RND_NEAREST;
            mod_fp_add_rp <= FP_PREC_EXTENDED;
            mod_fp_cont_state_reg <= ST_FRAC;
            state_reg <= ST_FP_ADD;
          end if;

        -- Registered FP add: 1 load + 2 hold + 1 compute = MCP 4 (400ns budget)
        when ST_FP_ADD =>
          if fp_hold_loaded_reg = '0' then
            fp_hold_loaded_reg <= '1';
            mod_fp_wait_count_reg <= 2;
          elsif mod_fp_wait_count_reg = 0 then
            mod_add_result_reg <= add_sub_fp80(mod_fp_add_a, mod_fp_add_b,
                                               mod_fp_add_is_sub, mod_fp_add_rm, mod_fp_add_rp);
            state_reg <= mod_fp_cont_state_reg;
            fp_hold_loaded_reg <= '0';
          else
            mod_fp_wait_count_reg <= mod_fp_wait_count_reg - 1;
          end if;

        -- Registered FP mul: 1 load + 0 hold + 1 compute = MCP 2 (200ns budget)
        when ST_FP_MUL =>
          if fp_hold_loaded_reg = '0' then
            fp_hold_loaded_reg <= '1';
            mod_fp_wait_count_reg <= 0;
          elsif mod_fp_wait_count_reg = 0 then
            mod_mul_result_reg <= mul_fp80(mod_fp_mul_a, mod_fp_mul_b,
                                           FP_RND_NEAREST, FP_PREC_EXTENDED);
            state_reg <= mod_fp_cont_state_reg;
            fp_hold_loaded_reg <= '0';
          else
            mod_fp_wait_count_reg <= mod_fp_wait_count_reg - 1;
          end if;

        when ST_FRAC =>
          frac := mod_add_result_reg;
          frac_abs := abs_fp80(frac);
          half_cmp := compare_fp80(frac_abs, FP80_HALF);
          if (half_cmp > 0) or (half_cmp = 0 and fp80_is_odd_integer_local(n_fp_reg)) then
            mod_fp_add_a <= n_fp_reg;
            mod_fp_add_b <= FP80_ONE;
            mod_fp_add_is_sub <= quotient_reg(FP_WIDTH-1) = '1';
            mod_fp_add_rm <= FP_RND_NEAREST;
            mod_fp_add_rp <= FP_PREC_EXTENDED;
            mod_fp_cont_state_reg <= ST_ADJUST;
            state_reg <= ST_FP_ADD;
          else
            quotient_byte_reg <= quotient_byte_from_fp_integer(n_fp_reg);
            quotient_valid_reg <= '1';
            mod_fp_mul_a <= b_reg;
            mod_fp_mul_b <= n_fp_reg;
            mod_fp_cont_state_reg <= ST_PRODUCT;
            state_reg <= ST_FP_MUL;
          end if;

        when ST_ADJUST =>
          n_fp_reg <= mod_add_result_reg;
          quotient_byte_reg <= quotient_byte_from_fp_integer(mod_add_result_reg);
          quotient_valid_reg <= '1';
          mod_fp_mul_a <= b_reg;
          mod_fp_mul_b <= mod_add_result_reg;
          mod_fp_cont_state_reg <= ST_PRODUCT;
          state_reg <= ST_FP_MUL;

        when ST_PRODUCT =>
          mod_fp_add_a <= a_reg;
          mod_fp_add_b <= mod_mul_result_reg;
          mod_fp_add_is_sub <= true;
          mod_fp_add_rm <= rm_reg;
          mod_fp_add_rp <= rp_reg;
          mod_fp_cont_state_reg <= ST_SUB;
          state_reg <= ST_FP_ADD;

        when ST_SUB =>
          result_reg <= mod_add_result_reg;
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
end architecture rtl;
