-- mc68881_fp80_mul_unit.vhd
-- Sequential FP80 multiply unit with start/busy/done handshake.
-- Replaces combinational mul_fp80 in trig unit's ST_FP_MUL path.
-- Algorithm is bit-exact with the package-body mul_fp80 function.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_fp80_mul_unit is
  port (
    clk        : in  std_logic;
    reset_n    : in  std_logic;
    start      : in  std_logic;
    a_in       : in  fp80_t;
    b_in       : in  fp80_t;
    round_mode : in  fp_round_mode_t;
    round_prec : in  fp_round_prec_t;
    busy       : out std_logic;
    done       : out std_logic;
    result     : out fp80_t
  );
end entity;

architecture rtl of mc68881_fp80_mul_unit is

  -- Local constants matching package body privates.
  constant FP_GRS_BITS       : natural := 3;
  constant FP_MANT_EXT_WIDTH : natural := FP_MANT_WIDTH + FP_GRS_BITS;
  constant FP_EXP_ALL_ONES   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP_EXP_MAX        : integer := (2**FP_EXP_WIDTH) - 1;

  type mul_state_t is (
    ST_IDLE,
    ST_UNPACK,
    ST_MULTIPLY,
    ST_NORM_ROUND
  );

  signal state_reg : mul_state_t := ST_IDLE;

  -- Input latches.
  signal a_reg       : fp80_t := (others => '0');
  signal b_reg       : fp80_t := (others => '0');
  signal rm_reg      : fp_round_mode_t := FP_RND_NEAREST;
  signal rp_reg      : fp_round_prec_t := FP_PREC_EXTENDED;

  -- Unpacked mantissa fields (sign/exp computed inline and not registered).
  signal a_mant_reg  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  signal b_mant_reg  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');

  -- Intermediate results.
  signal res_sign_reg : std_logic := '0';
  signal exp_res_reg  : integer range -65536 to 65536 := 0;
  signal early_exit_reg : std_logic := '0';
  signal early_result_reg : fp80_t := (others => '0');

  -- 128-bit product register.
  signal mant_prod_reg : unsigned((FP_MANT_WIDTH*2)-1 downto 0) := (others => '0');

  -- Output registers.
  signal done_reg    : std_logic := '0';
  signal result_reg  : fp80_t := (others => '0');

  -- Local helper: precision bits for rounding.
  function prec_bits(prec : fp_round_prec_t) return natural is
  begin
    case prec is
      when FP_PREC_SINGLE => return 24;
      when FP_PREC_DOUBLE => return 53;
      when others         => return FP_MANT_WIDTH;
    end case;
  end function;

begin

  -- Synchronous reset: allows Vivado to pack a_mant_reg, b_mant_reg, and
  -- mant_prod_reg into DSP48E1 pipeline registers (A1/A2, B1/B2, P) which
  -- only support synchronous reset.
  process(clk)
    -- Variables for ST_NORM_ROUND combinational work.
    variable mant_ext   : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    variable mant_main  : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable mant_round : unsigned(FP_MANT_WIDTH downto 0);
    variable mant_hi    : integer;
    variable low_hi     : integer;
    variable low_or     : std_logic;
    variable exp_var    : integer;
    variable guard      : std_logic;
    variable round_bit  : std_logic;
    variable sticky     : std_logic;
    variable any_disc   : std_logic;
    variable increment  : std_logic;
    variable prec_w     : natural;
    variable drop_bits  : natural;
    variable lsb_keep   : integer;
    variable exp_res    : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable res_packed : fp80_t;
    variable lz_norm    : natural;
    variable a_exp_adj  : integer;
    variable b_exp_adj  : integer;
    variable a_mant_v   : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable b_mant_v   : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable denorm_shift : natural;
  begin
    if rising_edge(clk) then
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      done_reg <= '0';
      result_reg <= (others => '0');
      a_reg <= (others => '0');
      b_reg <= (others => '0');
      rm_reg <= FP_RND_NEAREST;
      rp_reg <= FP_PREC_EXTENDED;
      a_mant_reg <= (others => '0');
      b_mant_reg <= (others => '0');
      res_sign_reg <= '0';
      exp_res_reg <= 0;
      early_exit_reg <= '0';
      early_result_reg <= (others => '0');
      mant_prod_reg <= (others => '0');
    else
      done_reg <= '0';

      case state_reg is
        when ST_IDLE =>
          if start = '1' then
            a_reg <= a_in;
            b_reg <= b_in;
            rm_reg <= round_mode;
            rp_reg <= round_prec;
            state_reg <= ST_UNPACK;
          end if;

        when ST_UNPACK =>
          -- Unpack mantissas with subnormal normalization.
          a_mant_v := unsigned(a_reg(FP_MANT_WIDTH-1 downto 0));
          b_mant_v := unsigned(b_reg(FP_MANT_WIDTH-1 downto 0));

          -- Normalize denormalized operands (MC68881 normalizes before arithmetic).
          if unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = 0 and a_mant_v /= 0 then
            lz_norm := clz(a_mant_v);
            a_mant_v := shift_left(a_mant_v, lz_norm);
            a_exp_adj := 1 - lz_norm;
          else
            a_exp_adj := to_integer(unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)));
          end if;

          if unsigned(b_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = 0 and b_mant_v /= 0 then
            lz_norm := clz(b_mant_v);
            b_mant_v := shift_left(b_mant_v, lz_norm);
            b_exp_adj := 1 - lz_norm;
          else
            b_exp_adj := to_integer(unsigned(b_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)));
          end if;

          a_mant_reg <= a_mant_v;
          b_mant_reg <= b_mant_v;

          -- Result sign.
          res_sign_reg <= a_reg(FP_WIDTH-1) xor b_reg(FP_WIDTH-1);

          -- Check for early-exit special cases: NaN, infinity, zero.
          -- Order: NaN first, then infinity (checks zero×inf), then zero.
          early_exit_reg <= '0';
          if fp80_is_nan(a_reg) or fp80_is_nan(b_reg) then
            -- NaN propagation (MC68881: dest priority, SNaN quieted).
            early_exit_reg <= '1';
            early_result_reg <= fp80_propagate_nan(
              a_reg, b_reg, fp80_is_nan(a_reg), fp80_is_nan(b_reg))(FP_WIDTH-1 downto 0);
          elsif fp80_is_inf(a_reg) or fp80_is_inf(b_reg) then
            early_exit_reg <= '1';
            if fp80_is_zero(a_reg) or fp80_is_zero(b_reg) then
              -- 0 * inf or inf * 0: canonical QNaN (invalid operation).
              early_result_reg(FP_WIDTH-1) <= '0';
              early_result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '1');
              early_result_reg(FP_MANT_WIDTH-1 downto 0) <= (others => '1');
            else
              -- inf * finite or inf * inf: signed infinity.
              early_result_reg(FP_WIDTH-1) <= a_reg(FP_WIDTH-1) xor b_reg(FP_WIDTH-1);
              early_result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '1');
              early_result_reg(FP_MANT_WIDTH-1 downto 0) <= (others => '0');
            end if;
          elsif fp80_is_zero(a_reg) or fp80_is_zero(b_reg) then
            -- Zero * finite = +0.
            early_exit_reg <= '1';
            early_result_reg <= (others => '0');
          end if;

          -- Biased exponent sum (using normalized exponents).
          exp_res_reg <= a_exp_adj + b_exp_adj - FP_EXP_BIAS;

          state_reg <= ST_MULTIPLY;

        when ST_MULTIPLY =>
          if early_exit_reg = '1' then
            -- Skip multiply, emit early result.
            result_reg <= early_result_reg;
            done_reg <= '1';
            state_reg <= ST_IDLE;
          else
            -- 64x64 -> 128-bit multiply (infers DSP48E1 cascade).
            mant_prod_reg <= a_mant_reg * b_mant_reg;
            state_reg <= ST_NORM_ROUND;
          end if;

        when ST_NORM_ROUND =>
          -- Determine alignment from product MSB.
          exp_var := exp_res_reg;
          if mant_prod_reg(mant_prod_reg'left) = '1' then
            exp_var := exp_var + 1;
            mant_hi := mant_prod_reg'left;  -- 127
          else
            mant_hi := mant_prod_reg'left - 1;  -- 126
          end if;

          -- Extract top 67 bits (mantissa + GRS).
          mant_ext := mant_prod_reg(mant_hi downto mant_hi - (FP_MANT_EXT_WIDTH - 1));

          -- Collect sticky from remaining low bits.
          low_hi := mant_hi - FP_MANT_EXT_WIDTH;
          low_or := '0';
          if low_hi >= 0 then
            for idx in 0 to (FP_MANT_WIDTH*2)-1 loop
              if idx <= low_hi and mant_prod_reg(idx) = '1' then
                low_or := '1';
              end if;
            end loop;
          end if;
          mant_ext(0) := mant_ext(0) or low_or;

          -- Inline apply_rounding.
          mant_main := mant_ext(FP_MANT_EXT_WIDTH-1 downto FP_GRS_BITS);
          prec_w    := prec_bits(rp_reg);
          drop_bits := FP_MANT_WIDTH - prec_w;
          lsb_keep  := FP_GRS_BITS + drop_bits;

          guard     := mant_ext(lsb_keep - 1);
          round_bit := mant_ext(lsb_keep - 2);
          sticky    := '0';
          if lsb_keep > 2 then
            if mant_ext(lsb_keep - 3 downto 0) /= 0 then
              sticky := '1';
            end if;
          end if;

          any_disc  := guard or round_bit or sticky;
          increment := '0';
          case rm_reg is
            when FP_RND_NEAREST =>
              if guard = '1' and (round_bit = '1' or sticky = '1' or mant_main(drop_bits) = '1') then
                increment := '1';
              end if;
            when FP_RND_ZERO =>
              increment := '0';
            when FP_RND_MINUS_INF =>
              if res_sign_reg = '1' and any_disc = '1' then
                increment := '1';
              end if;
            when FP_RND_PLUS_INF =>
              if res_sign_reg = '0' and any_disc = '1' then
                increment := '1';
              end if;
          end case;

          if increment = '1' then
            mant_round := ('0' & mant_main) + (to_unsigned(1, FP_MANT_WIDTH + 1) sll drop_bits);
            if mant_round(mant_round'left) = '1' then
              -- Rounding overflow: shift right with sticky, increment exponent.
              mant_main := shift_right(mant_round(mant_round'left-1 downto 0), 1);
              if mant_round(0) = '1' then
                mant_main(0) := '1';
              end if;
              mant_main(mant_main'left) := '1';
              exp_var := exp_var + 1;
            else
              mant_main := mant_round(mant_round'left-1 downto 0);
            end if;
          end if;

          if drop_bits > 0 then
            mant_main(drop_bits - 1 downto 0) := (others => '0');
          end if;

          -- Underflow: produce subnormal output or flush to zero.
          if exp_var <= 0 then
            denorm_shift := 1 - exp_var;
            if denorm_shift >= FP_MANT_WIDTH or mant_main = 0 then
              result_reg <= (others => '0');
            else
              result_reg(FP_WIDTH-1) <= res_sign_reg;
              result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '0');
              result_reg(FP_MANT_WIDTH-1 downto 0) <= std_logic_vector(shift_right(mant_main, denorm_shift));
            end if;
          -- Overflow check.
          elsif exp_var >= FP_EXP_MAX then
            result_reg(FP_WIDTH-1) <= res_sign_reg;
            result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '1');
            result_reg(FP_MANT_WIDTH-1 downto 0) <= (others => '0');
          else
            -- Normal result: pack.
            exp_res := to_unsigned(exp_var, FP_EXP_WIDTH);
            result_reg(FP_WIDTH-1) <= res_sign_reg;
            result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= std_logic_vector(exp_res);
            result_reg(FP_MANT_WIDTH-1 downto 0) <= std_logic_vector(mant_main);
          end if;

          done_reg <= '1';
          state_reg <= ST_IDLE;
      end case;
    end if;
    end if;
  end process;

  busy   <= '1' when state_reg /= ST_IDLE else '0';
  done   <= done_reg;
  result <= result_reg;

end architecture;
