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
          -- Unpack mantissas (sign/exp computed inline, not registered).
          a_mant_reg <= unsigned(a_reg(FP_MANT_WIDTH-1 downto 0));
          b_mant_reg <= unsigned(b_reg(FP_MANT_WIDTH-1 downto 0));

          -- Result sign.
          res_sign_reg <= a_reg(FP_WIDTH-1) xor b_reg(FP_WIDTH-1);

          -- Check for early-exit cases (zero, infinity/NaN).
          early_exit_reg <= '0';
          if (unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = 0 and
              unsigned(a_reg(FP_MANT_WIDTH-1 downto 0)) = 0) or
             (unsigned(b_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = 0 and
              unsigned(b_reg(FP_MANT_WIDTH-1 downto 0)) = 0) then
            -- Zero * anything = +0.
            early_exit_reg <= '1';
            early_result_reg <= (others => '0');
          elsif unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = FP_EXP_ALL_ONES or
                unsigned(b_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = FP_EXP_ALL_ONES then
            -- Infinity/NaN passthrough: return infinity with computed sign.
            early_exit_reg <= '1';
            early_result_reg(FP_WIDTH-1) <= a_reg(FP_WIDTH-1) xor b_reg(FP_WIDTH-1);
            early_result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '1');
            early_result_reg(FP_MANT_WIDTH-1 downto 0) <= (others => '0');
          end if;

          -- Biased exponent sum.
          exp_res_reg <= to_integer(unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH))) +
                         to_integer(unsigned(b_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH))) -
                         FP_EXP_BIAS;

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
              -- Rounding overflow: shift right, increment exponent.
              mant_main := unsigned(std_logic_vector(mant_round(mant_round'left-1 downto 1))) & (mant_round(0));
              -- Manual shift_right_with_sticky for 1-bit shift on mant_round lower bits.
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

          -- Underflow check.
          if exp_var <= 0 then
            result_reg <= (others => '0');
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
