-- mc68881_fp80_addsub_unit.vhd
-- Sequential FP80 add/subtract unit with start/busy/done handshake.
-- Replaces combinational add_sub_fp80 in trig unit's ST_FP_ADD path.
-- Algorithm is bit-exact with the package-body add_sub_fp80 function.
--
-- Pipeline: ST_IDLE -> ST_UNPACK -> ST_ALIGN -> ST_ADDSUB -> ST_NORMALIZE -> ST_NORM_ROUND
-- ST_ADDSUB does the add/subtract only.
-- ST_NORMALIZE uses LZD + barrel shift (replaces iterative normalize_left loop).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_fp80_addsub_unit is
  port (
    clk        : in  std_logic;
    reset_n    : in  std_logic;
    start      : in  std_logic;
    a_in       : in  fp80_t;
    b_in       : in  fp80_t;
    subtract   : in  boolean;
    round_mode : in  fp_round_mode_t;
    round_prec : in  fp_round_prec_t;
    busy       : out std_logic;
    done       : out std_logic;
    result     : out fp80_t
  );
end entity;

architecture rtl of mc68881_fp80_addsub_unit is

  -- Local constants matching package body privates.
  constant FP_GRS_BITS       : natural := 3;
  constant FP_MANT_EXT_WIDTH : natural := FP_MANT_WIDTH + FP_GRS_BITS;
  constant FP_EXP_ALL_ONES   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP_EXP_MAX        : integer := (2**FP_EXP_WIDTH) - 1;

  type addsub_state_t is (
    ST_IDLE,
    ST_UNPACK,
    ST_ALIGN,
    ST_ADDSUB,
    ST_NORMALIZE,
    ST_NORM_ROUND
  );

  signal state_reg : addsub_state_t := ST_IDLE;

  -- Input latches.
  signal a_reg       : fp80_t := (others => '0');
  signal b_reg       : fp80_t := (others => '0');
  signal sub_reg     : boolean := false;
  signal rm_reg      : fp_round_mode_t := FP_RND_NEAREST;
  signal rp_reg      : fp_round_prec_t := FP_PREC_EXTENDED;

  -- Unpacked fields (b_sign not registered — sign_b_reg captures effective sign).
  signal a_sign_reg  : std_logic := '0';
  signal a_exp_reg   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
  signal b_exp_reg   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
  signal sign_b_reg  : std_logic := '0';  -- effective sign of b

  -- Extended mantissas (67 bits = 64 + 3 GRS).
  signal mant_a_ext_reg : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
  signal mant_b_ext_reg : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');

  -- Result exponent after alignment.
  signal exp_res_reg : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');

  -- Early exit.
  signal early_exit_reg    : std_logic := '0';
  signal early_result_reg  : fp80_t := (others => '0');

  -- Sum register (68 bits = 67 + carry).
  signal mant_sum_reg : unsigned(FP_MANT_EXT_WIDTH downto 0) := (others => '0');
  signal res_sign_reg : std_logic := '0';
  signal same_sign_reg : boolean := false;
  -- Flag: subtraction path needs normalization.
  signal need_normalize_reg : std_logic := '0';

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

  -- Local helper: shift right with sticky bit preservation.
  function shift_right_sticky(value : unsigned; shift : natural) return unsigned is
    variable res    : unsigned(value'length-1 downto 0) := (others => '0');
    variable sticky : std_logic := '0';
  begin
    if shift = 0 then
      return value;
    end if;
    if shift >= value'length then
      if value /= 0 then
        sticky := '1';
      end if;
      res(0) := sticky;
      return res;
    end if;
    if value(shift-1 downto 0) /= 0 then
      sticky := '1';
    end if;
    res := shift_right(value, shift);
    if sticky = '1' then
      res(0) := '1';
    end if;
    return res;
  end function;

  -- Leading zero detector: returns count of leading zeros in a 67-bit value.
  -- Uses a tree structure for O(log N) logic depth instead of iterative loop.
  function count_leading_zeros(value : unsigned) return natural is
    variable cnt : natural := 0;
    variable v   : unsigned(value'length-1 downto 0) := value;
  begin
    -- For 67-bit input, check power-of-2 chunks from MSB.
    -- 64, 32, 16, 8, 4, 2, 1
    if value'length > 64 then
      if v(v'left downto v'left - 63) = 0 then
        cnt := cnt + 64;
        v := v(v'left - 64 downto 0) & (63 downto 0 => '0');
      end if;
    end if;
    if v(v'left downto v'left - 31) = 0 then
      cnt := cnt + 32;
      v := v(v'left - 32 downto 0) & (31 downto 0 => '0');
    end if;
    if v(v'left downto v'left - 15) = 0 then
      cnt := cnt + 16;
      v := v(v'left - 16 downto 0) & (15 downto 0 => '0');
    end if;
    if v(v'left downto v'left - 7) = 0 then
      cnt := cnt + 8;
      v := v(v'left - 8 downto 0) & (7 downto 0 => '0');
    end if;
    if v(v'left downto v'left - 3) = 0 then
      cnt := cnt + 4;
      v := v(v'left - 4 downto 0) & (3 downto 0 => '0');
    end if;
    if v(v'left downto v'left - 1) = 0 then
      cnt := cnt + 2;
      v := v(v'left - 2 downto 0) & "00";
    end if;
    if v(v'left) = '0' then
      cnt := cnt + 1;
    end if;
    return cnt;
  end function;

begin

  -- Synchronous reset: consistent with mc68881_fp80_mul_unit and allows
  -- Vivado to pack extended mantissa registers into DSP48E1 pipeline stages.
  process(clk)
    -- Variables for ST_ALIGN.
    variable a_ext_v    : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    variable b_ext_v    : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    variable exp_v      : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable diff_v     : natural;
    -- Variables for ST_ADDSUB.
    variable sum_v      : unsigned(FP_MANT_EXT_WIDTH downto 0);
    variable carry_mant : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    -- Variables for ST_NORMALIZE.
    variable lzc        : natural;
    variable shift_amt  : natural;
    variable norm_mant  : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    variable norm_exp   : unsigned(FP_EXP_WIDTH-1 downto 0);
    -- Variables for ST_NORM_ROUND.
    variable mant_ext   : unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    variable mant_main  : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable mant_round : unsigned(FP_MANT_WIDTH downto 0);
    variable exp_var    : integer;
    variable guard      : std_logic;
    variable round_bit  : std_logic;
    variable sticky     : std_logic;
    variable any_disc   : std_logic;
    variable increment  : std_logic;
    variable prec_w     : natural;
    variable drop_bits  : natural;
    variable lsb_keep   : integer;
    variable exp_out    : unsigned(FP_EXP_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      done_reg <= '0';
      result_reg <= (others => '0');
      a_reg <= (others => '0');
      b_reg <= (others => '0');
      sub_reg <= false;
      rm_reg <= FP_RND_NEAREST;
      rp_reg <= FP_PREC_EXTENDED;
      a_sign_reg <= '0';
      a_exp_reg <= (others => '0');
      b_exp_reg <= (others => '0');
      sign_b_reg <= '0';
      mant_a_ext_reg <= (others => '0');
      mant_b_ext_reg <= (others => '0');
      exp_res_reg <= (others => '0');
      early_exit_reg <= '0';
      early_result_reg <= (others => '0');
      mant_sum_reg <= (others => '0');
      res_sign_reg <= '0';
      same_sign_reg <= false;
      need_normalize_reg <= '0';
    else
      done_reg <= '0';

      case state_reg is
        when ST_IDLE =>
          if start = '1' then
            a_reg <= a_in;
            b_reg <= b_in;
            sub_reg <= subtract;
            rm_reg <= round_mode;
            rp_reg <= round_prec;
            state_reg <= ST_UNPACK;
          end if;

        when ST_UNPACK =>
          -- Unpack operands.
          a_sign_reg <= a_reg(FP_WIDTH-1);
          a_exp_reg  <= unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
          b_exp_reg  <= unsigned(b_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));

          -- Effective sign of b.
          if sub_reg then
            sign_b_reg <= not b_reg(FP_WIDTH-1);
          else
            sign_b_reg <= b_reg(FP_WIDTH-1);
          end if;

          -- Extend mantissas with GRS bits.
          mant_a_ext_reg <= unsigned(a_reg(FP_MANT_WIDTH-1 downto 0)) & (FP_GRS_BITS-1 downto 0 => '0');
          mant_b_ext_reg <= unsigned(b_reg(FP_MANT_WIDTH-1 downto 0)) & (FP_GRS_BITS-1 downto 0 => '0');

          -- Check for early-exit special cases: NaN, infinity, zero.
          -- Order: NaN first (propagate), then infinity, then zero.
          early_exit_reg <= '0';
          if fp80_is_nan(a_reg) or fp80_is_nan(b_reg) then
            -- NaN propagation (MC68881: dest priority, SNaN quieted).
            early_exit_reg <= '1';
            early_result_reg <= fp80_propagate_nan(
              a_reg, b_reg, fp80_is_nan(a_reg), fp80_is_nan(b_reg))(FP_WIDTH-1 downto 0);
          elsif fp80_is_inf(a_reg) or fp80_is_inf(b_reg) then
            early_exit_reg <= '1';
            if fp80_is_inf(a_reg) and fp80_is_inf(b_reg) then
              -- Both infinity: check effective signs (compute inline,
              -- sign_b_reg is not yet updated this cycle).
              if (not sub_reg and a_reg(FP_WIDTH-1) = b_reg(FP_WIDTH-1)) or
                 (sub_reg and a_reg(FP_WIDTH-1) /= b_reg(FP_WIDTH-1)) then
                -- Same effective sign: result is infinity with that sign.
                early_result_reg(FP_WIDTH-1) <= a_reg(FP_WIDTH-1);
                early_result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '1');
                early_result_reg(FP_MANT_WIDTH-1 downto 0) <= (others => '0');
              else
                -- Opposite effective signs (inf - inf): canonical QNaN.
                early_result_reg(FP_WIDTH-1) <= '0';
                early_result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '1');
                early_result_reg(FP_MANT_WIDTH-1 downto 0) <= (others => '1');
              end if;
            elsif fp80_is_inf(a_reg) then
              -- a is inf, b is finite: return a.
              early_result_reg <= a_reg;
            else
              -- b is inf, a is finite: return b (negate if subtract).
              if sub_reg then
                early_result_reg(FP_WIDTH-1) <= not b_reg(FP_WIDTH-1);
                early_result_reg(FP_WIDTH-2 downto 0) <= b_reg(FP_WIDTH-2 downto 0);
              else
                early_result_reg <= b_reg;
              end if;
            end if;
          elsif unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = 0 and
                unsigned(a_reg(FP_MANT_WIDTH-1 downto 0)) = 0 then
            -- a is zero: return b (negate if subtract).
            early_exit_reg <= '1';
            if sub_reg then
              early_result_reg(FP_WIDTH-1) <= not b_reg(FP_WIDTH-1);
              early_result_reg(FP_WIDTH-2 downto 0) <= b_reg(FP_WIDTH-2 downto 0);
            else
              early_result_reg <= b_reg;
            end if;
          elsif unsigned(b_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) = 0 and
                unsigned(b_reg(FP_MANT_WIDTH-1 downto 0)) = 0 then
            -- b is zero: return a.
            early_exit_reg <= '1';
            early_result_reg <= a_reg;
          end if;

          state_reg <= ST_ALIGN;

        when ST_ALIGN =>
          if early_exit_reg = '1' then
            result_reg <= early_result_reg;
            done_reg <= '1';
            state_reg <= ST_IDLE;
          else
            -- Align exponents: shift smaller mantissa right.
            a_ext_v := mant_a_ext_reg;
            b_ext_v := mant_b_ext_reg;
            if a_exp_reg > b_exp_reg then
              diff_v  := to_integer(a_exp_reg - b_exp_reg);
              b_ext_v := shift_right_sticky(b_ext_v, diff_v);
              exp_v   := a_exp_reg;
            elsif b_exp_reg > a_exp_reg then
              diff_v  := to_integer(b_exp_reg - a_exp_reg);
              a_ext_v := shift_right_sticky(a_ext_v, diff_v);
              exp_v   := b_exp_reg;
            else
              exp_v := a_exp_reg;
            end if;

            mant_a_ext_reg <= a_ext_v;
            mant_b_ext_reg <= b_ext_v;
            exp_res_reg    <= exp_v;

            -- Precompute same-sign flag.
            same_sign_reg <= (a_sign_reg = sign_b_reg);

            state_reg <= ST_ADDSUB;
          end if;

        when ST_ADDSUB =>
          -- Pure add/subtract — no normalization here.
          need_normalize_reg <= '0';

          if same_sign_reg then
            -- Same effective sign: addition.
            sum_v := ('0' & mant_a_ext_reg) + ('0' & mant_b_ext_reg);
            res_sign_reg <= a_sign_reg;

            -- Carry overflow: shift right, adjust exponent.
            if sum_v(sum_v'left) = '1' then
              carry_mant := shift_right_sticky(sum_v(sum_v'left-1 downto 0), 1);
              carry_mant(carry_mant'left) := '1';
              sum_v(sum_v'left) := '0';
              sum_v(sum_v'left-1 downto 0) := carry_mant;
              if exp_res_reg /= FP_EXP_ALL_ONES then
                exp_res_reg <= exp_res_reg + 1;
              end if;
            end if;

            mant_sum_reg <= sum_v;
          else
            -- Different effective sign: subtraction.
            if mant_a_ext_reg >= mant_b_ext_reg then
              sum_v := ('0' & mant_a_ext_reg) - ('0' & mant_b_ext_reg);
              res_sign_reg <= a_sign_reg;
            else
              sum_v := ('0' & mant_b_ext_reg) - ('0' & mant_a_ext_reg);
              res_sign_reg <= sign_b_reg;
            end if;

            mant_sum_reg <= sum_v;
            -- Flag that normalization is needed for subtraction results.
            need_normalize_reg <= '1';
          end if;

          state_reg <= ST_NORMALIZE;

        when ST_NORMALIZE =>
          -- LZD-based left normalization (replaces iterative loop).
          if need_normalize_reg = '1' then
            norm_mant := mant_sum_reg(mant_sum_reg'left-1 downto 0);
            norm_exp  := exp_res_reg;

            if norm_mant = 0 then
              -- Zero result — leave as-is.
              null;
            elsif norm_mant(norm_mant'left) = '0' then
              -- Need to normalize: find shift amount via LZD.
              lzc := count_leading_zeros(norm_mant);
              -- Clamp shift to exponent (don't go below exp=0).
              if lzc > to_integer(norm_exp) then
                shift_amt := to_integer(norm_exp);
              else
                shift_amt := lzc;
              end if;
              norm_mant := shift_left(norm_mant, shift_amt);
              norm_exp  := norm_exp - to_unsigned(shift_amt, FP_EXP_WIDTH);
            end if;

            mant_sum_reg(mant_sum_reg'left) <= '0';
            mant_sum_reg(mant_sum_reg'left-1 downto 0) <= norm_mant;
            exp_res_reg <= norm_exp;
          end if;

          state_reg <= ST_NORM_ROUND;

        when ST_NORM_ROUND =>
          -- Extract mantissa + GRS bits.
          mant_ext := mant_sum_reg(mant_sum_reg'left-1 downto 0);
          exp_var  := to_integer(exp_res_reg);

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
              -- Rounding overflow.
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

          -- Zero result.
          if mant_main = 0 then
            result_reg <= (others => '0');
          -- Overflow.
          elsif exp_var >= FP_EXP_MAX then
            result_reg(FP_WIDTH-1) <= res_sign_reg;
            result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= (others => '1');
            result_reg(FP_MANT_WIDTH-1 downto 0) <= (others => '0');
          -- Underflow.
          elsif exp_var <= 0 then
            result_reg <= (others => '0');
          else
            -- Normal result: pack.
            exp_out := to_unsigned(exp_var, FP_EXP_WIDTH);
            result_reg(FP_WIDTH-1) <= res_sign_reg;
            result_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) <= std_logic_vector(exp_out);
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
