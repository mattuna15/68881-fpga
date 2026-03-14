library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_divrem_unit is
  generic (
    enable_modrem_post : boolean := true
  );
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
    flag_inexact   : out std_logic;
    -- Modrem FP multiply passthrough
    modrem_fp_mul_start  : out std_logic;
    modrem_fp_mul_a      : out fp80_t;
    modrem_fp_mul_b      : out fp80_t;
    modrem_fp_mul_done   : in  std_logic;
    modrem_fp_mul_result : in  fp80_t;
    -- Modrem FP add passthrough
    modrem_fp_add_start  : out std_logic;
    modrem_fp_add_a      : out fp80_t;
    modrem_fp_add_b      : out fp80_t;
    modrem_fp_add_sub    : out boolean;
    modrem_fp_add_rm     : out fp_round_mode_t;
    modrem_fp_add_rp     : out fp_round_prec_t;
    modrem_fp_add_done   : in  std_logic;
    modrem_fp_add_result : in  fp80_t;
    -- Save/restore interface for FSAVE/FRESTORE Busy frame.
    save_req     : in  std_logic;
    save_data    : out std_logic_vector(31 downto 0);
    save_addr    : in  natural range 0 to 9;
    restore_req  : in  std_logic;
    restore_data : in  std_logic_vector(31 downto 0);
    restore_addr : in  natural range 0 to 9;
    restore_wr   : in  std_logic
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
    ST_POST_DIV_ROUND,
    ST_SQRT_ITER,
    ST_SQRT_POST,
    ST_MOD_WAIT,
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

  signal post_mant_ext_reg : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
  signal post_exp_reg : integer := 0;
  signal post_inexact_reg : std_logic := '0';
  signal post_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal post_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;

  signal div_result_reg : fp80_t := (others => '0');
  signal result_reg : fp80_t := (others => '0');
  signal quotient_byte_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal quotient_valid_reg : std_logic := '0';
  signal done_reg : std_logic := '0';
  signal modrem_start_reg : std_logic := '0';
  signal modrem_done : std_logic := '0';
  signal modrem_result : fp80_t := (others => '0');
  signal modrem_quotient_byte : std_logic_vector(7 downto 0) := (others => '0');
  signal modrem_quotient_valid : std_logic := '0';

  signal flag_invalid_reg : std_logic := '0';
  signal flag_divzero_reg : std_logic := '0';
  signal flag_overflow_reg : std_logic := '0';
  signal flag_underflow_reg : std_logic := '0';
  signal flag_inexact_reg : std_logic := '0';

  -- Shadow registers for save/restore (6 words for divrem, 4 for modrem_post).
  type save_array_t is array (0 to 5) of std_logic_vector(31 downto 0);
  signal shadow_regs : save_array_t := (others => (others => '0'));

  -- Modrem_post save/restore routing signals.
  signal modrem_save_data    : std_logic_vector(31 downto 0) := (others => '0');
  signal modrem_save_addr    : natural range 0 to 3 := 0;
  signal modrem_restore_addr : natural range 0 to 3 := 0;
  signal modrem_restore_wr   : std_logic := '0';

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

  -- shift_right_with_sticky: uses package-level version from mc68881_pkg.

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
    variable exp_var    : integer := 0;
  begin
    mant_main := mant_ext(FP_MANT_EXT_WIDTH-1 downto FP_GRS_BITS);

    -- Extract guard/round/sticky per precision using constant indices.
    sticky := '0';
    case rnd_prec is
      when FP_PREC_SINGLE =>
        guard := mant_ext(42); round_bit := mant_ext(41);
        if mant_ext(40 downto 0) /= 0 then sticky := '1'; end if;
      when FP_PREC_DOUBLE =>
        guard := mant_ext(13); round_bit := mant_ext(12);
        if mant_ext(11 downto 0) /= 0 then sticky := '1'; end if;
      when others =>
        guard := mant_ext(2); round_bit := mant_ext(1);
        if mant_ext(0) = '1' then sticky := '1'; end if;
    end case;

    any_disc := guard or round_bit or sticky;
    case rnd_mode is
      when FP_RND_NEAREST =>
        case rnd_prec is
          when FP_PREC_SINGLE =>
            if guard = '1' and (round_bit = '1' or sticky = '1' or mant_main(40) = '1') then increment := '1'; end if;
          when FP_PREC_DOUBLE =>
            if guard = '1' and (round_bit = '1' or sticky = '1' or mant_main(11) = '1') then increment := '1'; end if;
          when others =>
            if guard = '1' and (round_bit = '1' or sticky = '1' or mant_main(0) = '1') then increment := '1'; end if;
        end case;
      when FP_RND_ZERO =>
        increment := '0';
      when FP_RND_MINUS_INF =>
        if sign = '1' and any_disc = '1' then increment := '1'; end if;
      when FP_RND_PLUS_INF =>
        if sign = '0' and any_disc = '1' then increment := '1'; end if;
    end case;

    exp_var := exp_in;
    if increment = '1' then
      case rnd_prec is
        when FP_PREC_SINGLE => mant_round := ('0' & mant_main) + (to_unsigned(1, FP_MANT_WIDTH+1) sll 40);
        when FP_PREC_DOUBLE => mant_round := ('0' & mant_main) + (to_unsigned(1, FP_MANT_WIDTH+1) sll 11);
        when others => mant_round := ('0' & mant_main) + 1;
      end case;
      if mant_round(mant_round'left) = '1' then
        mant_main := shift_right_with_sticky(mant_round(mant_round'left-1 downto 0), 1);
        mant_main(mant_main'left) := '1';
        exp_var := exp_var + 1;
      else
        mant_main := mant_round(mant_round'left-1 downto 0);
      end if;
    end if;

    case rnd_prec is
      when FP_PREC_SINGLE => mant_main(39 downto 0) := (others => '0');
      when FP_PREC_DOUBLE => mant_main(10 downto 0) := (others => '0');
      when others => null;
    end case;

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
    variable canonical_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    canonical_mant(FP_MANT_WIDTH-1) := '1';
    return u.exp = FP_EXP_ALL_ONES and
      (u.mant = 0 or u.mant = canonical_mant);
  end function;

  function fp80_is_nan(value : fp80_t) return boolean is
  begin
    return unpack_fp80(value).exp = FP_EXP_ALL_ONES and not fp80_is_inf(value);
  end function;

  -- Canonical QNaN for domain errors (0/0, inf/inf, sqrt(neg), etc.)
  function canonical_qnan return fp80_t is
    variable res : fp_unpacked_t;
  begin
    res.sign := '0';
    res.exp := FP_EXP_ALL_ONES;
    res.mant := (others => '1');
    return pack_fp80(res);
  end function;

  function highest_one_index(value : unsigned(FP_MANT_WIDTH-1 downto 0)) return natural is
  begin
    for idx in value'high downto value'low loop
      if value(idx) = '1' then
        return idx;
      end if;
    end loop;
    return 0;
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
  gen_modpost_on : if enable_modrem_post generate
    modpost_inst : entity work.mc68881_modrem_post_unit
      port map (
        clk     => clk,
        reset_n => reset_n,
        start   => modrem_start_reg,
        op_sel  => op_reg,
        a_in    => a_reg,
        b_in    => b_reg,
        quotient_in => div_result_reg,
        round_mode => rm_reg,
        round_prec => rp_reg,
        busy    => open,
        done    => modrem_done,
        result  => modrem_result,
        quotient_byte  => modrem_quotient_byte,
        quotient_valid => modrem_quotient_valid,
        fp_mul_start   => modrem_fp_mul_start,
        fp_mul_a_out   => modrem_fp_mul_a,
        fp_mul_b_out   => modrem_fp_mul_b,
        fp_mul_done    => modrem_fp_mul_done,
        fp_mul_result  => modrem_fp_mul_result,
        fp_add_start   => modrem_fp_add_start,
        fp_add_a_out   => modrem_fp_add_a,
        fp_add_b_out   => modrem_fp_add_b,
        fp_add_sub_out => modrem_fp_add_sub,
        fp_add_rm_out  => modrem_fp_add_rm,
        fp_add_rp_out  => modrem_fp_add_rp,
        fp_add_done    => modrem_fp_add_done,
        fp_add_result  => modrem_fp_add_result,
        save_req       => save_req,
        save_data      => modrem_save_data,
        save_addr      => modrem_save_addr,
        restore_req    => restore_req,
        restore_data   => restore_data,
        restore_addr   => modrem_restore_addr,
        restore_wr     => modrem_restore_wr
      );
  end generate;

  gen_modpost_off : if not enable_modrem_post generate
  begin
    modrem_done <= '0';
    modrem_result <= (others => '0');
    modrem_quotient_byte <= (others => '0');
    modrem_quotient_valid <= '0';
    modrem_fp_mul_start <= '0';
    modrem_fp_mul_a <= (others => '0');
    modrem_fp_mul_b <= (others => '0');
    modrem_fp_add_start <= '0';
    modrem_fp_add_a <= (others => '0');
    modrem_fp_add_b <= (others => '0');
    modrem_fp_add_sub <= false;
    modrem_fp_add_rm <= FP_RND_NEAREST;
    modrem_fp_add_rp <= FP_PREC_EXTENDED;
    modrem_save_data <= (others => '0');
  end generate;

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
    variable div_mul2 : unsigned(REM_WIDTH-1 downto 0) := (others => '0');
    variable div_mul3 : unsigned(REM_WIDTH-1 downto 0) := (others => '0');
    variable div_final_result : fp80_t := (others => '0');
    variable div_round_mode : fp_round_mode_t := FP_RND_NEAREST;
    variable div_round_prec : fp_round_prec_t := FP_PREC_EXTENDED;
    variable mantissa_even : unsigned(SQRT_MANT_EVEN_WIDTH-1 downto 0) := (others => '0');
    variable sqrt_norm_shift : natural := 0;
    variable nan_prop : std_logic_vector(80 downto 0) := (others => '0');
    variable lz_norm : natural := 0;
    variable a_exp_adj : integer := 0;
    variable b_exp_adj : integer := 0;
    variable a_mant_norm : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable b_mant_norm : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable quot_low_or : std_logic := '0';
    variable quot_or_prefix : unsigned(DIVIDEND_BITS-1 downto 0);
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
      modrem_start_reg <= '0';
    elsif rising_edge(clk) then
      done_reg <= '0';
      quotient_valid_reg <= '0';
      modrem_start_reg <= '0';

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
              nan_prop := fp80_propagate_nan(a_reg, b_reg,
                            fp80_is_nan(a_reg), fp80_is_nan(b_reg));
              result_reg <= nan_prop(79 downto 0);
              flag_invalid_reg <= nan_prop(80);
              state_reg <= ST_DONE;
            elsif b_u.exp = 0 and b_u.mant = 0 then
              if a_u.exp = 0 and a_u.mant = 0 then
                -- 0/0: IEEE-754 invalid operation -> QNaN
                result_reg <= canonical_qnan;
                flag_invalid_reg <= '1';
              else
                -- nonzero/0: divide by zero -> signed infinity
                div_res_u.sign := a_u.sign xor b_u.sign;
                div_res_u.exp := FP_EXP_ALL_ONES;
                div_res_u.mant := (others => '0');
                result_reg <= pack_fp80(div_res_u);
                flag_divzero_reg <= '1';
              end if;
              state_reg <= ST_DONE;
            elsif a_u.exp = 0 and a_u.mant = 0 then
              div_res_u.sign := a_u.sign xor b_u.sign;
              div_res_u.exp := (others => '0');
              div_res_u.mant := (others => '0');
              result_reg <= pack_fp80(div_res_u);
              state_reg <= ST_DONE;
            elsif b_u.exp = FP_EXP_ALL_ONES and a_u.exp /= FP_EXP_ALL_ONES then
              div_res_u.sign := a_u.sign xor b_u.sign;
              div_res_u.exp := (others => '0');
              div_res_u.mant := (others => '0');
              result_reg <= pack_fp80(div_res_u);
              state_reg <= ST_DONE;
            elsif a_u.exp = FP_EXP_ALL_ONES or b_u.exp = FP_EXP_ALL_ONES then
              if a_u.exp = FP_EXP_ALL_ONES and b_u.exp = FP_EXP_ALL_ONES then
                -- inf/inf domain error: canonical QNaN + INVALID
                result_reg <= canonical_qnan;
                flag_invalid_reg <= '1';
              else
                -- inf/finite: result is signed infinity
                div_res_u.sign := a_u.sign xor b_u.sign;
                div_res_u.exp := FP_EXP_ALL_ONES;
                div_res_u.mant := (others => '0');
                result_reg <= pack_fp80(div_res_u);
              end if;
              state_reg <= ST_DONE;
            else
              -- Normalize denormalized operands (MC68881 normalizes before arithmetic).
              a_mant_norm := a_u.mant;
              if a_u.exp = 0 and a_u.mant /= 0 then
                lz_norm := clz(a_u.mant);
                a_mant_norm := shift_left(a_u.mant, lz_norm);
                a_exp_adj := 1 - lz_norm;
              else
                a_exp_adj := to_integer(a_u.exp);
              end if;

              b_mant_norm := b_u.mant;
              if b_u.exp = 0 and b_u.mant /= 0 then
                lz_norm := clz(b_u.mant);
                b_mant_norm := shift_left(b_u.mant, lz_norm);
                b_exp_adj := 1 - lz_norm;
              else
                b_exp_adj := to_integer(b_u.exp);
              end if;

              divisor_reg <= b_mant_norm;
              dividend_reg <= a_mant_norm & to_unsigned(0, DIV_Q_BITS);
              rem_reg <= (others => '0');
              quot_reg <= (others => '0');
              iter_idx_reg <= DIVIDEND_BITS-1;
              div_sign_reg <= a_u.sign xor b_u.sign;
              div_exp_base_reg <= a_exp_adj - b_exp_adj + FP_EXP_BIAS;
              state_reg <= ST_DIV_ITER;
            end if;
          elsif op_reg = FPU_OP_SQRT then
            if fp80_is_nan(a_reg) then
              result_reg <= fp80_quiet_nan(a_reg);
              if fp80_is_snan(a_reg) then
                flag_invalid_reg <= '1';
              end if;
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
                -- Subnormal normalization: replace iterative shift loop with
                -- direct leading-one index decode to shorten this timing cone.
                lead_idx := highest_one_index(a_u.mant);
                sqrt_norm_shift := natural(SQRT_MANT_EVEN_WIDTH - 1 - lead_idx);
                -- Match legacy bounded-loop behavior (max FP_MANT_WIDTH shifts)
                -- so the smallest subnormal does not over-shift to zero.
                if sqrt_norm_shift > FP_MANT_WIDTH then
                  sqrt_norm_shift := FP_MANT_WIDTH;
                end if;
                exp_unbiased := (1 - FP_EXP_BIAS) - integer(sqrt_norm_shift);
                mantissa_even := shift_left(resize(a_u.mant, SQRT_MANT_EVEN_WIDTH), sqrt_norm_shift);
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
            if fp80_is_nan(a_reg) or fp80_is_nan(b_reg) then
              nan_prop := fp80_propagate_nan(a_reg, b_reg,
                            fp80_is_nan(a_reg), fp80_is_nan(b_reg));
              result_reg <= nan_prop(79 downto 0);
              flag_invalid_reg <= nan_prop(80);
              state_reg <= ST_DONE;
            elsif fp80_is_inf(a_reg) or (b_u.exp = 0 and b_u.mant = 0) then
              result_reg <= canonical_qnan;
              flag_invalid_reg <= '1';
              state_reg <= ST_DONE;
            elsif a_u.exp = 0 and a_u.mant = 0 then
              -- Preserve sign of zero dividend (datasheet: FMOD(-0,x) = -0).
              result_reg <= a_reg(FP_WIDTH-1) & FP80_ZERO(FP_WIDTH-2 downto 0);
              quotient_byte_reg <= (others => '0');
              quotient_valid_reg <= '1';
              state_reg <= ST_DONE;
            elsif fp80_is_inf(b_reg) then
              result_reg <= a_reg;
              quotient_byte_reg <= (others => '0');
              quotient_valid_reg <= '1';
              state_reg <= ST_DONE;
            else
              -- Normalize denormalized operands (MC68881 normalizes before arithmetic).
              a_mant_norm := a_u.mant;
              if a_u.exp = 0 and a_u.mant /= 0 then
                lz_norm := clz(a_u.mant);
                a_mant_norm := shift_left(a_u.mant, lz_norm);
                a_exp_adj := 1 - lz_norm;
              else
                a_exp_adj := to_integer(a_u.exp);
              end if;

              b_mant_norm := b_u.mant;
              if b_u.exp = 0 and b_u.mant /= 0 then
                lz_norm := clz(b_u.mant);
                b_mant_norm := shift_left(b_u.mant, lz_norm);
                b_exp_adj := 1 - lz_norm;
              else
                b_exp_adj := to_integer(b_u.exp);
              end if;

              divisor_reg <= b_mant_norm;
              dividend_reg <= a_mant_norm & to_unsigned(0, DIV_Q_BITS);
              rem_reg <= (others => '0');
              quot_reg <= (others => '0');
              iter_idx_reg <= DIVIDEND_BITS-1;
              div_sign_reg <= a_u.sign xor b_u.sign;
              div_exp_base_reg <= a_exp_adj - b_exp_adj + FP_EXP_BIAS;
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
            rem_next(1) := dividend_reg(iter_idx_reg);
            rem_next(0) := dividend_reg(iter_idx_reg-1);
            div_mul2 := shift_left(divisor_ext, 1);
            div_mul3 := divisor_ext + div_mul2;
            if rem_next >= div_mul3 then
              rem_next := rem_next - div_mul3;
              quot_next(iter_idx_reg) := '1';
              quot_next(iter_idx_reg-1) := '1';
            elsif rem_next >= div_mul2 then
              rem_next := rem_next - div_mul2;
              quot_next(iter_idx_reg) := '1';
              quot_next(iter_idx_reg-1) := '0';
            elsif rem_next >= divisor_ext then
              rem_next := rem_next - divisor_ext;
              quot_next(iter_idx_reg) := '0';
              quot_next(iter_idx_reg-1) := '1';
            else
              quot_next(iter_idx_reg) := '0';
              quot_next(iter_idx_reg-1) := '0';
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
          rem_next(1) := sqrt_radicand_reg(pair_hi);
          rem_next(0) := sqrt_radicand_reg(pair_hi-1);
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

          -- Gradual underflow: shift mantissa right to form subnormal
          if exp_res_i <= 0 then
            mant_ext := shift_right_with_sticky(mant_ext, 1 - exp_res_i);
            exp_res_i := 0;
          end if;

          apply_rounding('0', mant_ext, exp_res_i, rm_reg, rp_reg, mant_main, exp_res_i, inexact_local);

          -- Promote to minimum normal if rounding set the integer bit
          if exp_res_i = 0 and mant_main(mant_main'left) = '1' then
            exp_res_i := 1;
          end if;

          div_res_u.sign := '0';
          if mant_main = 0 then
            div_res_u.exp := (others => '0');
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
          elsif exp_res_i <= 0 then
            div_res_u.exp := (others => '0');
            div_res_u.mant := mant_main;
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
          -- Cycle 1: leading-one detection, mantissa extraction, exponent calc
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
            for i in 0 to FP_MANT_EXT_WIDTH-1 loop
              mant_ext(i) := quot_reg(lead_idx - (FP_MANT_EXT_WIDTH-1) + i);
            end loop;
            if lead_idx > FP_MANT_EXT_WIDTH then
              -- OR-prefix scan: single dynamic mux instead of N comparators
              quot_or_prefix(0) := quot_reg(0);
              for i in 1 to quot_reg'high loop
                quot_or_prefix(i) := quot_or_prefix(i-1) or quot_reg(i);
              end loop;
              if quot_or_prefix(lead_idx - FP_MANT_EXT_WIDTH - 1) = '1' then
                mant_ext(0) := '1';
              end if;
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

          -- Gradual underflow: shift mantissa right to form subnormal
          if exp_res_i <= 0 then
            mant_ext := shift_right_with_sticky(mant_ext, 1 - exp_res_i);
            exp_res_i := 0;
          end if;

          -- Register intermediate results for rounding in next cycle
          post_mant_ext_reg <= mant_ext;
          post_exp_reg <= exp_res_i;
          post_inexact_reg <= inexact_local;
          post_rm_reg <= div_round_mode;
          post_rp_reg <= div_round_prec;
          state_reg <= ST_POST_DIV_ROUND;

        when ST_POST_DIV_ROUND =>
          -- Cycle 2: rounding and packing from registered intermediates
          mant_ext := post_mant_ext_reg;
          exp_res_i := post_exp_reg;
          inexact_local := post_inexact_reg;

          apply_rounding(div_sign_reg, mant_ext, exp_res_i, post_rm_reg, post_rp_reg, mant_main, exp_res_i, inexact_local);

          -- Promote to minimum normal if rounding set the integer bit
          if exp_res_i = 0 and mant_main(mant_main'left) = '1' then
            exp_res_i := 1;
          end if;

          div_res_u.sign := div_sign_reg;
          if mant_main = 0 then
            div_res_u.sign := '0';
            div_res_u.exp := (others => '0');
            div_res_u.mant := (others => '0');
            div_final_result := pack_fp80(div_res_u);
          elsif exp_res_i <= 0 then
            div_res_u.exp := (others => '0');
            div_res_u.mant := mant_main;
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

          if op_reg = FPU_OP_DIV or not enable_modrem_post then
            result_reg <= div_final_result;
            state_reg <= ST_DONE;
          else
            modrem_start_reg <= '1';
            state_reg <= ST_MOD_WAIT;
          end if;

        when ST_MOD_WAIT =>
          if modrem_done = '1' then
            result_reg <= modrem_result;
            quotient_byte_reg <= modrem_quotient_byte;
            quotient_valid_reg <= modrem_quotient_valid;
            state_reg <= ST_DONE;
          end if;

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

  -- Save/restore process for Busy frame.
  save_restore_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      shadow_regs <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if save_req = '1' then
        -- Word 0: FSM state + iteration index.
        shadow_regs(0) <= std_logic_vector(to_unsigned(state_t'pos(state_reg), 16)) &
                          std_logic_vector(to_unsigned(iter_idx_reg, 16));
        -- Word 1: divisor_reg lower 32 bits.
        shadow_regs(1) <= std_logic_vector(divisor_reg(31 downto 0));
        -- Word 2: divisor_reg upper 32 bits.
        shadow_regs(2) <= std_logic_vector(divisor_reg(63 downto 32));
        -- Word 3: quot_reg lower 32 bits.
        shadow_regs(3) <= std_logic_vector(quot_reg(31 downto 0));
        -- Word 4: quot_reg upper 32 bits.
        shadow_regs(4) <= std_logic_vector(quot_reg(63 downto 32));
        -- Word 5: exponent + sign + op_reg encoding.
        shadow_regs(5)(15 downto 0) <= std_logic_vector(to_signed(div_exp_base_reg, 16));
        shadow_regs(5)(16) <= div_sign_reg;
        shadow_regs(5)(31 downto 17) <= std_logic_vector(to_unsigned(fpu_op_t'pos(op_reg), 15));
      end if;
      if restore_wr = '1' and restore_addr <= 5 then
        shadow_regs(restore_addr) <= restore_data;
      end if;
    end if;
  end process;

  -- Modrem_post address routing: divrem addr 6-9 → modrem_post addr 0-3.
  modrem_save_addr    <= save_addr - 6    when save_addr >= 6 and save_addr <= 9 else 0;
  modrem_restore_addr <= restore_addr - 6 when restore_addr >= 6 and restore_addr <= 9 else 0;
  modrem_restore_wr   <= restore_wr       when restore_addr >= 6 and restore_addr <= 9 else '0';

  -- Save data mux: 0-5 divrem, 6-9 modrem_post.
  save_data <= shadow_regs(save_addr) when save_addr <= 5 else
               modrem_save_data       when save_addr >= 6 and save_addr <= 9 else
               (others => '0');
end architecture rtl;
