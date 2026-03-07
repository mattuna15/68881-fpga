library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_packed_decimal_unit is
  port (
    clk             : in  std_logic;
    reset_n         : in  std_logic;
    req_valid       : in  std_logic;
    req_encode      : in  std_logic;
    req_fp          : in  fp80_t;
    req_word        : in  std_logic_vector(95 downto 0);
    req_fallback_fp : in  fp80_t;
    req_k           : in  integer range -64 to 17;
    busy            : out std_logic;
    rsp_valid       : out std_logic;
    rsp_word        : out std_logic_vector(95 downto 0);
    rsp_fp          : out fp80_t;
    rsp_inexact     : out std_logic;
    rsp_invalid     : out std_logic;
    -- FP multiply interface (shared with ALU)
    fp_mul_start   : out std_logic;
    fp_mul_a_out   : out fp80_t;
    fp_mul_b_out   : out fp80_t;
    fp_mul_done    : in  std_logic;
    fp_mul_result  : in  fp80_t;
    -- FP add/sub interface (shared with ALU)
    fp_add_start   : out std_logic;
    fp_add_a_out   : out fp80_t;
    fp_add_b_out   : out fp80_t;
    fp_add_sub_out : out boolean;
    fp_add_done    : in  std_logic;
    fp_add_result  : in  fp80_t;
    -- Save/restore interface for FSAVE/FRESTORE Busy frame.
    save_req     : in  std_logic;
    save_data    : out std_logic_vector(31 downto 0);
    save_addr    : in  natural range 0 to 2;
    restore_req  : in  std_logic;
    restore_data : in  std_logic_vector(31 downto 0);
    restore_addr : in  natural range 0 to 2;
    restore_wr   : in  std_logic
  );
end entity mc68881_packed_decimal_unit;

architecture rtl of mc68881_packed_decimal_unit is
  subtype packed96_t is std_logic_vector(95 downto 0);
  type packed_digits_t is array (0 to 16) of natural range 0 to 9;
  type packed_state_t is (
    ST_IDLE,
    ST_ENC_CLASSIFY,
    ST_ENC_SCALE_PREP,
    ST_SCALE_CHUNK,
    ST_SCALE_BITS,
    ST_ENC_TUNE,
    ST_ENC_DIGIT_INT,
    ST_ENC_DIGIT_SUB,
    ST_ENC_DIGIT_SCALE,
    ST_ENC_POSTROUND,
    ST_ENC_POSTROUND_PROP,
    ST_ENC_KROUND,
    ST_ENC_KROUND_PROP,
    ST_ENC_PACK,
    ST_DEC_ACCUM_U64,
    ST_DEC_TO_FP,
    ST_DEC_RESPOND
  );

  type arith_commit_t is (
    AR_NONE,
    AR_SCALE_CHUNK,
    AR_SCALE_BITS,
    AR_ENC_TUNE,
    AR_ENC_DIGIT_INT,
    AR_ENC_DIGIT_SUB,
    AR_ENC_DIGIT_SCALE,
    AR_ENC_POSTROUND
  );
  type arith_stage_t is (
    AR_ST_IDLE,
    AR_ST_WAIT,
    AR_ST_COMMIT
  );

  constant FP80_ONE : fp80_t := x"3FFF8000000000000000";

  constant FP80_TEN_POS_1    : fp80_t := x"4002A000000000000000";
  constant FP80_TEN_POS_2    : fp80_t := x"4005C800000000000000";
  constant FP80_TEN_POS_4    : fp80_t := x"400C9C40000000000000";
  constant FP80_TEN_POS_8    : fp80_t := x"4019BEBC200000000000";
  constant FP80_TEN_POS_16   : fp80_t := x"40348E1BC9BF04000000";
  constant FP80_TEN_POS_32   : fp80_t := x"40699DC5ADA82B70B59E";
  constant FP80_TEN_POS_64   : fp80_t := x"40D3C2781F49FFCFA6D5";
  constant FP80_TEN_POS_128  : fp80_t := x"41A893BA47C980E98CE0";
  constant FP80_TEN_POS_256  : fp80_t := x"4351AA7EEBFB9DF9DE8E";
  constant FP80_TEN_POS_512  : fp80_t := x"46A3E319A0AEA60E91C7";
  constant FP80_TEN_POS_1024 : fp80_t := x"4D48C976758681750C17";
  constant FP80_TEN_POS_2048 : fp80_t := x"5A929E8B3B5DC53D5DE5";
  constant FP80_TEN_POS_4096 : fp80_t := x"7525C46052028A20979B";

  constant FP80_TEN_NEG_1    : fp80_t := x"3FFBCCCCCCCCCCCCCCCD";
  constant FP80_TEN_NEG_2    : fp80_t := x"3FF8A3D70A3D70A3D70A";
  constant FP80_TEN_NEG_4    : fp80_t := x"3FF1D1B71758E219652C";
  constant FP80_TEN_NEG_8    : fp80_t := x"3FE4ABCC77118461CEFD";
  constant FP80_TEN_NEG_16   : fp80_t := x"3FC9E69594BEC44DE15B";
  constant FP80_TEN_NEG_32   : fp80_t := x"3F94CFB11EAD453994BA";
  constant FP80_TEN_NEG_64   : fp80_t := x"3F2AA87FEA27A539E9A5";
  constant FP80_TEN_NEG_128  : fp80_t := x"3E55DDD0467C64BCE4A1";
  constant FP80_TEN_NEG_256  : fp80_t := x"3CACC0314325637A193A";
  constant FP80_TEN_NEG_512  : fp80_t := x"395A9049EE32DB23D21C";
  constant FP80_TEN_NEG_1024 : fp80_t := x"32B5A2A682A5DA57C0BE";
  constant FP80_TEN_NEG_2048 : fp80_t := x"256BCEAE534F34362DE4";
  constant FP80_TEN_NEG_4096 : fp80_t := x"0AD8A6DD04C8D2CE9FDE";

  signal state_reg : packed_state_t := ST_IDLE;
  signal scale_return_state_reg : packed_state_t := ST_IDLE;

  signal req_fp_reg : fp80_t := (others => '0');
  signal req_word_reg : packed96_t := (others => '0');
  signal req_k_reg : integer range -64 to 17 := 0;

  signal sign_reg : std_logic := '0';
  signal exp10_reg : integer range -10000 to 10000 := 0;
  signal work_fp_reg : fp80_t := (others => '0');
  signal digits_reg : packed_digits_t := (others => 0);
  signal enc_digit_reg : natural range 0 to 9 := 0;
  signal idx_reg : natural range 0 to 16 := 0;
  signal tune_iter_reg : natural range 0 to 5 := 0;
  signal keep_digits_reg : integer range 1 to 17 := 17;
  signal inexact_reg : std_logic := '0';

  signal scale_abs_exp_reg : natural range 0 to 12000 := 0;
  signal scale_abs_exp_slv : std_logic_vector(11 downto 0);
  signal scale_use_neg_reg : std_logic := '0';
  signal scale_bit_idx_reg : natural range 0 to 12 := 0;

  signal mant_u64_reg : unsigned(63 downto 0) := (others => '0');

  signal kround_carry_reg : std_logic := '0';
  signal kround_idx_reg : natural range 0 to 16 := 0;

  signal rsp_valid_reg : std_logic := '0';
  signal rsp_word_reg : packed96_t := (others => '0');
  signal rsp_fp_reg : fp80_t := (others => '0');
  signal rsp_inexact_reg : std_logic := '0';
  signal rsp_invalid_reg : std_logic := '0';

  signal arith_stage_reg : arith_stage_t := AR_ST_IDLE;
  signal arith_hold_count_reg : natural range 0 to 6 := 0;
  signal arith_commit_reg : arith_commit_t := AR_NONE;
  signal arith_tune_exp_delta_reg : integer range -1 to 1 := 0;
  signal arith_mul_a_reg : fp80_t := (others => '0');
  signal arith_mul_b_reg : fp80_t := (others => '0');
  signal arith_add_a_reg : fp80_t := (others => '0');
  signal arith_add_b_reg : fp80_t := (others => '0');
  signal arith_add_sub_reg : std_logic := '0';
  signal arith_int_arg_reg : fp80_t := (others => '0');
  signal arith_mul_res_reg : fp80_t := (others => '0');
  signal arith_add_res_reg : fp80_t := (others => '0');
  signal arith_int_res_reg : integer range -1 to 15 := 0;

  signal packed_mul_start_reg : std_logic := '0';
  signal packed_add_start_reg : std_logic := '0';

  -- Shadow registers for save/restore.
  signal shadow_word0 : std_logic_vector(31 downto 0) := (others => '0');
  signal shadow_word1 : std_logic_vector(31 downto 0) := (others => '0');
  signal shadow_word2 : std_logic_vector(31 downto 0) := (others => '0');

  function bcd_digit(value : natural) return std_logic_vector is
    variable nibble : std_logic_vector(3 downto 0) := (others => '0');
  begin
    assert value <= 9 report "bcd_digit: value out of range" severity failure;
    nibble := std_logic_vector(to_unsigned(value mod 10, 4));
    return nibble;
  end function;

  function bcd_to_natural(nibble : std_logic_vector(3 downto 0)) return integer is
    variable digit_i : integer := 0;
  begin
    digit_i := to_integer(unsigned(nibble));
    if digit_i >= 0 and digit_i <= 9 then
      return digit_i;
    end if;
    return -1;
  end function;

  function clamp_integer(value : integer; min_value : integer; max_value : integer) return integer is
  begin
    if value < min_value then
      return min_value;
    elsif value > max_value then
      return max_value;
    end if;
    return value;
  end function;

  function pow10_by_pow2(bit_idx : natural; use_neg : boolean) return fp80_t is
  begin
    if use_neg then
      case bit_idx is
        when 0 => return FP80_TEN_NEG_1;
        when 1 => return FP80_TEN_NEG_2;
        when 2 => return FP80_TEN_NEG_4;
        when 3 => return FP80_TEN_NEG_8;
        when 4 => return FP80_TEN_NEG_16;
        when 5 => return FP80_TEN_NEG_32;
        when 6 => return FP80_TEN_NEG_64;
        when 7 => return FP80_TEN_NEG_128;
        when 8 => return FP80_TEN_NEG_256;
        when 9 => return FP80_TEN_NEG_512;
        when 10 => return FP80_TEN_NEG_1024;
        when others => return FP80_TEN_NEG_2048;
      end case;
    end if;

    case bit_idx is
      when 0 => return FP80_TEN_POS_1;
      when 1 => return FP80_TEN_POS_2;
      when 2 => return FP80_TEN_POS_4;
      when 3 => return FP80_TEN_POS_8;
      when 4 => return FP80_TEN_POS_16;
      when 5 => return FP80_TEN_POS_32;
      when 6 => return FP80_TEN_POS_64;
      when 7 => return FP80_TEN_POS_128;
      when 8 => return FP80_TEN_POS_256;
      when 9 => return FP80_TEN_POS_512;
      when 10 => return FP80_TEN_POS_1024;
      when others => return FP80_TEN_POS_2048;
    end case;
  end function;
begin
  -- Convert scale_abs_exp_reg to SLV for bit-indexing (replaces divider chain)
  scale_abs_exp_slv <= std_logic_vector(to_unsigned(scale_abs_exp_reg, 12));

  -- Drive shared FP unit ports
  fp_mul_start <= packed_mul_start_reg;
  fp_mul_a_out <= arith_mul_a_reg;
  fp_mul_b_out <= arith_mul_b_reg;
  fp_add_start <= packed_add_start_reg;
  fp_add_a_out <= arith_add_a_reg;
  fp_add_b_out <= arith_add_b_reg;
  fp_add_sub_out <= (arith_add_sub_reg = '1');

  busy <= '1' when state_reg /= ST_IDLE else '0';
  rsp_valid <= rsp_valid_reg;
  rsp_word <= rsp_word_reg;
  rsp_fp <= rsp_fp_reg;
  rsp_inexact <= rsp_inexact_reg;
  rsp_invalid <= rsp_invalid_reg;

  process(clk, reset_n)
    variable abs_val : fp80_t := (others => '0');
    variable packed_word_v : packed96_t := (others => '0');
    variable digits_v : packed_digits_t := (others => 0);
    variable digit_int : integer := 0;
    variable digit_nat : natural := 0;
    variable bin_exp : integer := 0;
    variable exp10_local : integer := 0;
    variable exp_abs : natural range 0 to 10000 := 0;
    variable exp0 : natural := 0;
    variable exp1 : natural := 0;
    variable exp2 : natural := 0;
    variable exp3 : natural := 0;
    variable keep_digits : integer := 17;
    variable k_clamped : integer := 0;
    variable carry : integer := 0;
    variable round_digit : natural := 0;
    variable has_trailing : boolean := false;
    variable scale_exp_local : integer := 0;
    variable tune_done : boolean := false;
    variable all_zero : boolean := true;
    variable exp0_i : integer := 0;
    variable exp1_i : integer := 0;
    variable exp2_i : integer := 0;
    variable exp3_i : integer := 0;
    variable lead_i : integer := 0;
    variable mant_next : unsigned(63 downto 0) := (others => '0');
    variable do_mul : boolean := false;
    variable do_add : boolean := false;
    variable do_int : boolean := false;
    variable mul_a_v : fp80_t := (others => '0');
    variable mul_b_v : fp80_t := (others => '0');
    variable add_a_v : fp80_t := (others => '0');
    variable add_b_v : fp80_t := (others => '0');
    variable add_sub_v : boolean := false;
    variable int_arg_v : fp80_t := (others => '0');
    variable tune_exp_delta : integer := 0;
    variable arith_commit : arith_commit_t := AR_NONE;
  begin
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      scale_return_state_reg <= ST_IDLE;
      req_fp_reg <= (others => '0');
      req_word_reg <= (others => '0');
      req_k_reg <= 0;
      sign_reg <= '0';
      exp10_reg <= 0;
      work_fp_reg <= (others => '0');
      digits_reg <= (others => 0);
      enc_digit_reg <= 0;
      idx_reg <= 0;
      tune_iter_reg <= 0;
      keep_digits_reg <= 17;
      inexact_reg <= '0';
      scale_abs_exp_reg <= 0;
      scale_use_neg_reg <= '0';
      scale_bit_idx_reg <= 0;
      mant_u64_reg <= (others => '0');
      kround_carry_reg <= '0';
      kround_idx_reg <= 0;
      rsp_valid_reg <= '0';
      rsp_word_reg <= (others => '0');
      rsp_fp_reg <= (others => '0');
      rsp_inexact_reg <= '0';
      rsp_invalid_reg <= '0';
      arith_stage_reg <= AR_ST_IDLE;
      arith_hold_count_reg <= 0;
      arith_commit_reg <= AR_NONE;
      arith_tune_exp_delta_reg <= 0;
      arith_mul_a_reg <= (others => '0');
      arith_mul_b_reg <= (others => '0');
      arith_add_a_reg <= (others => '0');
      arith_add_b_reg <= (others => '0');
      arith_add_sub_reg <= '0';
      arith_int_arg_reg <= (others => '0');
      arith_mul_res_reg <= (others => '0');
      arith_add_res_reg <= (others => '0');
      arith_int_res_reg <= 0;
      packed_mul_start_reg <= '0';
      packed_add_start_reg <= '0';
    elsif rising_edge(clk) then
      rsp_valid_reg <= '0';
      packed_mul_start_reg <= '0';
      packed_add_start_reg <= '0';
      do_mul := false;
      do_add := false;
      do_int := false;
      mul_a_v := FP80_ONE;
      mul_b_v := FP80_ONE;
      add_a_v := FP80_ONE;
      add_b_v := FP80_ONE;
      add_sub_v := false;
      int_arg_v := FP80_ONE;
      tune_exp_delta := 0;
      arith_commit := AR_NONE;

      if arith_stage_reg = AR_ST_WAIT then
        case arith_commit_reg is
          when AR_SCALE_CHUNK | AR_SCALE_BITS | AR_ENC_TUNE | AR_ENC_DIGIT_SCALE =>
            -- Sequential mul unit (shared with ALU)
            if arith_hold_count_reg = 0 then
              packed_mul_start_reg <= '1';
              arith_hold_count_reg <= 1;  -- mark as launched
            elsif fp_mul_done = '1' then
              arith_mul_res_reg <= fp_mul_result;
              arith_stage_reg <= AR_ST_COMMIT;
            end if;
          when AR_ENC_DIGIT_SUB =>
            -- Sequential add/sub unit (shared with ALU)
            if arith_hold_count_reg = 0 then
              packed_add_start_reg <= '1';
              arith_hold_count_reg <= 1;  -- mark as launched
            elsif fp_add_done = '1' then
              arith_add_res_reg <= fp_add_result;
              arith_stage_reg <= AR_ST_COMMIT;
            end if;
          when AR_ENC_DIGIT_INT | AR_ENC_POSTROUND =>
            -- Keep combinational fp80_to_int_trunc (cheap, ~10ns)
            if arith_hold_count_reg /= 0 then
              arith_hold_count_reg <= arith_hold_count_reg - 1;
            else
              arith_int_res_reg <= clamp_integer(fp80_to_int_trunc(arith_int_arg_reg), -1, 15);
              arith_stage_reg <= AR_ST_COMMIT;
            end if;
          when others =>
            arith_stage_reg <= AR_ST_COMMIT;
        end case;
      elsif arith_stage_reg = AR_ST_COMMIT then
        case arith_commit_reg is
          when AR_SCALE_CHUNK =>
            work_fp_reg <= arith_mul_res_reg;
            scale_abs_exp_reg <= scale_abs_exp_reg - 4096;

          when AR_SCALE_BITS =>
            work_fp_reg <= arith_mul_res_reg;
            scale_bit_idx_reg <= scale_bit_idx_reg + 1;

          when AR_ENC_TUNE =>
            work_fp_reg <= arith_mul_res_reg;
            exp10_reg <= exp10_reg + arith_tune_exp_delta_reg;

          when AR_ENC_DIGIT_INT =>
            if arith_int_res_reg < 0 then
              digit_nat := 0;
            elsif arith_int_res_reg > 9 then
              digit_nat := 9;
            else
              digit_nat := natural(arith_int_res_reg);
            end if;
            enc_digit_reg <= digit_nat;
            state_reg <= ST_ENC_DIGIT_SUB;

          when AR_ENC_DIGIT_SUB =>
            work_fp_reg <= arith_add_res_reg;
            state_reg <= ST_ENC_DIGIT_SCALE;

          when AR_ENC_DIGIT_SCALE =>
            digits_reg(idx_reg) <= enc_digit_reg;
            work_fp_reg <= arith_mul_res_reg;
            if idx_reg = 16 then
              state_reg <= ST_ENC_POSTROUND;
            else
              idx_reg <= idx_reg + 1;
              state_reg <= ST_ENC_DIGIT_INT;
            end if;

          when AR_ENC_POSTROUND =>
            digit_int := arith_int_res_reg;
            if digit_int >= 5 then
              -- Start serialized carry propagation from digit 16 down to 0
              kround_carry_reg <= '1';
              kround_idx_reg <= 16;
              state_reg <= ST_ENC_POSTROUND_PROP;
            else
              k_clamped := clamp_integer(req_k_reg, -64, 17);
              if k_clamped > 0 then
                keep_digits := k_clamped;
              else
                keep_digits := exp10_reg + 1 + (-k_clamped);
              end if;

              if keep_digits < 1 then
                keep_digits := 1;
              elsif keep_digits > 17 then
                keep_digits := 17;
              end if;

              keep_digits_reg <= keep_digits;
              state_reg <= ST_ENC_KROUND;
            end if;

          when others =>
            null;
        end case;
        arith_stage_reg <= AR_ST_IDLE;
        arith_commit_reg <= AR_NONE;
      end if;

      if arith_stage_reg = AR_ST_IDLE then
      case state_reg is
        when ST_IDLE =>
          if req_valid = '1' then
            req_fp_reg <= req_fp;
            req_word_reg <= req_word;
            req_k_reg <= req_k;
            inexact_reg <= '0';
            digits_reg <= (others => 0);
            enc_digit_reg <= 0;
            tune_iter_reg <= 0;
            idx_reg <= 0;

            if req_encode = '1' then
              sign_reg <= req_fp(FP_WIDTH-1);
              state_reg <= ST_ENC_CLASSIFY;
            else
              sign_reg <= req_word(95);
              packed_word_v := req_word;

              if packed_word_v(93 downto 92) = "11" then
                abs_val := (others => '0');
                abs_val(FP_WIDTH-1) := packed_word_v(95);
                abs_val(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
                abs_val(FP_MANT_WIDTH-1) := '1';
                if packed_word_v(67 downto 0) /= (67 downto 0 => '0') then
                  abs_val(FP_MANT_WIDTH-2 downto 0) := (others => '1');
                end if;
                rsp_word_reg <= packed_word_v;
                rsp_fp_reg <= abs_val;
                rsp_inexact_reg <= '0';
                rsp_invalid_reg <= '0';
                rsp_valid_reg <= '1';
              else
                exp0_i := bcd_to_natural(packed_word_v(83 downto 80));
                exp1_i := bcd_to_natural(packed_word_v(87 downto 84));
                exp2_i := bcd_to_natural(packed_word_v(91 downto 88));
                exp3_i := bcd_to_natural(packed_word_v(79 downto 76));
                lead_i := bcd_to_natural(packed_word_v(67 downto 64));

                if exp0_i < 0 or exp1_i < 0 or exp2_i < 0 or exp3_i < 0 or lead_i < 0 then
                  rsp_word_reg <= packed_word_v;
                  rsp_fp_reg <= req_fallback_fp;
                  rsp_inexact_reg <= '0';
                  rsp_invalid_reg <= '1';
                  rsp_valid_reg <= '1';
                else
                  exp10_local := exp3_i*1000 + exp2_i*100 + exp1_i*10 + exp0_i;
                  if packed_word_v(94) = '1' then
                    exp10_local := -exp10_local;
                  end if;

                  digits_v := (others => 0);
                  digits_v(0) := natural(lead_i);
                  all_zero := (lead_i = 0);
                  for nib_idx in 0 to 15 loop
                    lead_i := bcd_to_natural(packed_word_v(63 - nib_idx*4 downto 60 - nib_idx*4));
                    if lead_i < 0 then
                      all_zero := false;
                      exit;
                    end if;
                    digits_v(nib_idx+1) := natural(lead_i);
                    if lead_i /= 0 then
                      all_zero := false;
                    end if;
                  end loop;

                  if lead_i < 0 then
                    rsp_word_reg <= packed_word_v;
                    rsp_fp_reg <= req_fallback_fp;
                    rsp_inexact_reg <= '0';
                    rsp_invalid_reg <= '1';
                    rsp_valid_reg <= '1';
                  elsif all_zero then
                    abs_val := (others => '0');
                    abs_val(FP_WIDTH-1) := packed_word_v(95);
                    rsp_word_reg <= packed_word_v;
                    rsp_fp_reg <= abs_val;
                    rsp_inexact_reg <= '0';
                    rsp_invalid_reg <= '0';
                    rsp_valid_reg <= '1';
                  else
                    digits_reg <= digits_v;
                    mant_u64_reg <= to_unsigned(digits_v(0), 64);
                    idx_reg <= 1;
                    exp10_reg <= exp10_local;
                    state_reg <= ST_DEC_ACCUM_U64;
                  end if;
                end if;
              end if;
            end if;
          end if;

        when ST_ENC_CLASSIFY =>
          -- Pipeline stage: classify req_fp_reg (registered copy from ST_IDLE).
          -- Splits heavy combinational logic (exponent extraction, exp10 via DSP
          -- multiply, scale calculation) from the req_fp port input path.
          packed_word_v := (others => '0');
          packed_word_v(95) := sign_reg;

          if fp80_is_zero(req_fp_reg) then
            rsp_word_reg <= packed_word_v;
            rsp_fp_reg <= req_fp_reg;
            rsp_inexact_reg <= '0';
            rsp_invalid_reg <= '0';
            rsp_valid_reg <= '1';
            state_reg <= ST_IDLE;
          elsif fp80_is_inf(req_fp_reg) then
            packed_word_v(93 downto 92) := "11";
            packed_word_v(91 downto 88) := x"F";
            packed_word_v(87 downto 84) := x"F";
            packed_word_v(83 downto 80) := x"F";
            packed_word_v(79 downto 76) := x"F";
            rsp_word_reg <= packed_word_v;
            rsp_fp_reg <= req_fp_reg;
            rsp_inexact_reg <= '0';
            rsp_invalid_reg <= '0';
            rsp_valid_reg <= '1';
            state_reg <= ST_IDLE;
          elsif fp80_is_nan(req_fp_reg) then
            packed_word_v(93 downto 92) := "11";
            packed_word_v(91 downto 88) := x"F";
            packed_word_v(87 downto 84) := x"F";
            packed_word_v(83 downto 80) := x"F";
            packed_word_v(79 downto 76) := x"F";
            packed_word_v(67 downto 64) := x"1";
            packed_word_v(63 downto 0) := (others => '1');
            rsp_word_reg <= packed_word_v;
            rsp_fp_reg <= req_fp_reg;
            rsp_inexact_reg <= '0';
            rsp_invalid_reg <= '0';
            rsp_valid_reg <= '1';
            state_reg <= ST_IDLE;
          else
            abs_val := req_fp_reg;
            abs_val(FP_WIDTH-1) := '0';

            bin_exp := to_integer(unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH))) - FP_EXP_BIAS;
            if unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH)) = 0 then
              bin_exp := 1 - FP_EXP_BIAS;
              for bit_idx in FP_MANT_WIDTH-1 downto 0 loop
                exit when abs_val(bit_idx) = '1';
                bin_exp := bin_exp - 1;
              end loop;
            end if;

            if bin_exp >= 0 then
              exp10_local := (bin_exp * 77) / 256;
            else
              exp10_local := -(((-bin_exp) * 77 + 255) / 256);
            end if;

            exp10_reg <= exp10_local;
            work_fp_reg <= abs_val;
            state_reg <= ST_ENC_SCALE_PREP;
          end if;

        when ST_ENC_SCALE_PREP =>
          -- Second pipeline stage: compute scale parameters from exp10_reg.
          -- Splits the DSP multiply + carry chain path from ST_ENC_CLASSIFY.
          scale_exp_local := -exp10_reg;
          if scale_exp_local = 0 then
            state_reg <= ST_ENC_TUNE;
          else
            if scale_exp_local < 0 then
              scale_use_neg_reg <= '1';
              scale_abs_exp_reg <= natural(-scale_exp_local);
            else
              scale_use_neg_reg <= '0';
              scale_abs_exp_reg <= natural(scale_exp_local);
            end if;
            scale_bit_idx_reg <= 0;
            scale_return_state_reg <= ST_ENC_TUNE;
            state_reg <= ST_SCALE_CHUNK;
          end if;

        when ST_SCALE_CHUNK =>
          if scale_abs_exp_reg >= 4096 then
            do_mul := true;
            mul_a_v := work_fp_reg;
            if scale_use_neg_reg = '1' then
              mul_b_v := FP80_TEN_NEG_4096;
            else
              mul_b_v := FP80_TEN_POS_4096;
            end if;
            arith_commit := AR_SCALE_CHUNK;
          else
            scale_bit_idx_reg <= 0;
            state_reg <= ST_SCALE_BITS;
          end if;

        when ST_SCALE_BITS =>
          if scale_bit_idx_reg = 12 then
            state_reg <= scale_return_state_reg;
          else
            if scale_abs_exp_slv(scale_bit_idx_reg) = '1' then
              do_mul := true;
              mul_a_v := work_fp_reg;
              mul_b_v := pow10_by_pow2(scale_bit_idx_reg, scale_use_neg_reg = '1');
              arith_commit := AR_SCALE_BITS;
            else
              scale_bit_idx_reg <= scale_bit_idx_reg + 1;
            end if;
          end if;

        when ST_ENC_TUNE =>
          tune_done := false;
          if compare_fp80(work_fp_reg, FP80_TEN_POS_1) >= 0 then
            do_mul := true;
            mul_a_v := work_fp_reg;
            mul_b_v := FP80_TEN_NEG_1;
            tune_exp_delta := 1;
            arith_commit := AR_ENC_TUNE;
          elsif compare_fp80(work_fp_reg, FP80_ONE) < 0 then
            do_mul := true;
            mul_a_v := work_fp_reg;
            mul_b_v := FP80_TEN_POS_1;
            tune_exp_delta := -1;
            arith_commit := AR_ENC_TUNE;
          else
            tune_done := true;
          end if;

          if tune_done then
            idx_reg <= 0;
            state_reg <= ST_ENC_DIGIT_INT;
          elsif tune_iter_reg = 5 then
            idx_reg <= 0;
            state_reg <= ST_ENC_DIGIT_INT;
          else
            tune_iter_reg <= tune_iter_reg + 1;
          end if;

        when ST_ENC_DIGIT_INT =>
          do_int := true;
          int_arg_v := work_fp_reg;
          arith_commit := AR_ENC_DIGIT_INT;

        when ST_ENC_DIGIT_SUB =>
          do_add := true;
          add_a_v := work_fp_reg;
          add_b_v := fp80_from_int(enc_digit_reg);
          add_sub_v := true;
          arith_commit := AR_ENC_DIGIT_SUB;

        when ST_ENC_DIGIT_SCALE =>
          do_mul := true;
          mul_a_v := work_fp_reg;
          mul_b_v := FP80_TEN_POS_1;
          arith_commit := AR_ENC_DIGIT_SCALE;

        when ST_ENC_POSTROUND =>
          if not fp80_is_zero(work_fp_reg) then
            inexact_reg <= '1';
          end if;

          do_int := true;
          int_arg_v := work_fp_reg;
          arith_commit := AR_ENC_POSTROUND;

        when ST_ENC_POSTROUND_PROP =>
          -- Per-digit carry propagation (reuses kround registers)
          if digits_reg(kround_idx_reg) = 9 then
            digits_reg(kround_idx_reg) <= 0;
            if kround_idx_reg = 0 then
              -- Carry out: all digits were 9, now all 0.
              digits_reg(0) <= 1;
              exp10_reg <= exp10_reg + 1;
              -- Compute keep_digits and transition to KROUND
              -- Note: exp10_reg increment is deferred (signal), so use old value
              -- to match original behavior where keep_digits was computed
              -- after exp10 signal assignment (also deferred).
              k_clamped := clamp_integer(req_k_reg, -64, 17);
              if k_clamped > 0 then
                keep_digits := k_clamped;
              else
                keep_digits := exp10_reg + 1 + (-k_clamped);
              end if;
              if keep_digits < 1 then
                keep_digits := 1;
              elsif keep_digits > 17 then
                keep_digits := 17;
              end if;
              keep_digits_reg <= keep_digits;
              state_reg <= ST_ENC_KROUND;
            else
              kround_idx_reg <= kround_idx_reg - 1;
            end if;
          else
            digits_reg(kround_idx_reg) <= digits_reg(kround_idx_reg) + 1;
            -- Carry absorbed, compute keep_digits and transition to KROUND
            k_clamped := clamp_integer(req_k_reg, -64, 17);
            if k_clamped > 0 then
              keep_digits := k_clamped;
            else
              keep_digits := exp10_reg + 1 + (-k_clamped);
            end if;
            if keep_digits < 1 then
              keep_digits := 1;
            elsif keep_digits > 17 then
              keep_digits := 17;
            end if;
            keep_digits_reg <= keep_digits;
            state_reg <= ST_ENC_KROUND;
          end if;

        when ST_ENC_KROUND =>
          keep_digits := keep_digits_reg;

          if keep_digits < 17 then
            round_digit := digits_reg(keep_digits);
            carry := 0;

            -- Combinational OR-reduce: check for trailing nonzero digits
            if round_digit > 5 then
              carry := 1;
            elsif round_digit = 5 then
              has_trailing := false;
              for idx in 0 to 16 loop
                if idx > keep_digits and digits_reg(idx) /= 0 then
                  has_trailing := true;
                end if;
              end loop;
              if has_trailing or (digits_reg(keep_digits-1) mod 2 = 1) then
                carry := 1;
              end if;
            end if;

            -- Combinational OR-reduce: set inexact if any discarded digit nonzero
            for idx in 0 to 16 loop
              if idx >= keep_digits and digits_reg(idx) /= 0 then
                inexact_reg <= '1';
              end if;
            end loop;

            -- Zero out discarded digits
            for idx in 0 to 16 loop
              if idx >= keep_digits then
                digits_reg(idx) <= 0;
              end if;
            end loop;

            if carry = 1 then
              -- Start serialized carry propagation from keep_digits-1 down to 0
              kround_carry_reg <= '1';
              kround_idx_reg <= keep_digits - 1;
              state_reg <= ST_ENC_KROUND_PROP;
            else
              state_reg <= ST_ENC_PACK;
            end if;
          else
            state_reg <= ST_ENC_PACK;
          end if;

        when ST_ENC_KROUND_PROP =>
          -- Per-digit carry propagation: one digit per cycle
          if kround_carry_reg = '1' then
            if digits_reg(kround_idx_reg) = 9 then
              digits_reg(kround_idx_reg) <= 0;
              if kround_idx_reg = 0 then
                -- Carry out: all digits were 9, now all 0.
                -- Result is 1.000...0 with exponent incremented.
                digits_reg(0) <= 1;
                exp10_reg <= exp10_reg + 1;
                kround_carry_reg <= '0';
                state_reg <= ST_ENC_PACK;
              else
                kround_idx_reg <= kround_idx_reg - 1;
              end if;
            else
              digits_reg(kround_idx_reg) <= digits_reg(kround_idx_reg) + 1;
              kround_carry_reg <= '0';
              state_reg <= ST_ENC_PACK;
            end if;
          else
            state_reg <= ST_ENC_PACK;
          end if;

        when ST_ENC_PACK =>
          packed_word_v := (others => '0');
          packed_word_v(95) := sign_reg;
          if exp10_reg < 0 then
            packed_word_v(94) := '1';
            exp_abs := natural(-exp10_reg);
          else
            packed_word_v(94) := '0';
            exp_abs := natural(exp10_reg);
          end if;
          exp0 := exp_abs mod 10;
          exp1 := (exp_abs / 10) mod 10;
          exp2 := (exp_abs / 100) mod 10;
          exp3 := (exp_abs / 1000) mod 10;

          packed_word_v(93 downto 92) := "00";
          packed_word_v(91 downto 88) := bcd_digit(exp2);
          packed_word_v(87 downto 84) := bcd_digit(exp1);
          packed_word_v(83 downto 80) := bcd_digit(exp0);
          packed_word_v(79 downto 76) := bcd_digit(exp3);
          packed_word_v(75 downto 68) := (others => '0');
          packed_word_v(67 downto 64) := bcd_digit(digits_reg(0));
          for idx in 0 to 15 loop
            packed_word_v(63 - idx*4 downto 60 - idx*4) := bcd_digit(digits_reg(idx+1));
          end loop;

          rsp_word_reg <= packed_word_v;
          rsp_fp_reg <= req_fp_reg;
          rsp_inexact_reg <= inexact_reg;
          rsp_invalid_reg <= '0';
          rsp_valid_reg <= '1';
          state_reg <= ST_IDLE;

        when ST_DEC_ACCUM_U64 =>
          mant_next := shift_left(mant_u64_reg, 3) + shift_left(mant_u64_reg, 1) +
                       to_unsigned(digits_reg(idx_reg), 64);
          mant_u64_reg <= mant_next;
          if idx_reg = 16 then
            state_reg <= ST_DEC_TO_FP;
          else
            idx_reg <= idx_reg + 1;
          end if;

        when ST_DEC_TO_FP =>
          work_fp_reg <= fp80_from_u64(mant_u64_reg);
          scale_exp_local := exp10_reg - 16;
          if scale_exp_local = 0 then
            state_reg <= ST_DEC_RESPOND;
          else
            if scale_exp_local < 0 then
              scale_use_neg_reg <= '1';
              scale_abs_exp_reg <= natural(-scale_exp_local);
            else
              scale_use_neg_reg <= '0';
              scale_abs_exp_reg <= natural(scale_exp_local);
            end if;
            scale_bit_idx_reg <= 0;
            scale_return_state_reg <= ST_DEC_RESPOND;
            state_reg <= ST_SCALE_CHUNK;
          end if;

        when ST_DEC_RESPOND =>
          abs_val := work_fp_reg;
          abs_val(FP_WIDTH-1) := sign_reg;
          rsp_word_reg <= req_word_reg;
          rsp_fp_reg <= abs_val;
          rsp_inexact_reg <= '0';
          rsp_invalid_reg <= '0';
          rsp_valid_reg <= '1';
          state_reg <= ST_IDLE;

        when others =>
          state_reg <= ST_IDLE;
      end case;
      if arith_commit /= AR_NONE then
        arith_commit_reg <= arith_commit;
        arith_tune_exp_delta_reg <= tune_exp_delta;
        arith_mul_a_reg <= mul_a_v;
        arith_mul_b_reg <= mul_b_v;
        arith_add_a_reg <= add_a_v;
        arith_add_b_reg <= add_b_v;
        if add_sub_v then
          arith_add_sub_reg <= '1';
        else
          arith_add_sub_reg <= '0';
        end if;
        arith_int_arg_reg <= int_arg_v;
        -- For mul/add commits: 0 = not launched (sequential unit starts in AR_ST_WAIT)
        -- For int commits: 3 hold cycles for fp80_to_int_trunc settle (MCP=4 at 33 MHz)
        if arith_commit = AR_ENC_DIGIT_INT or arith_commit = AR_ENC_POSTROUND then
          arith_hold_count_reg <= 3;
        else
          arith_hold_count_reg <= 0;
        end if;
        arith_stage_reg <= AR_ST_WAIT;
      end if;
      end if;
    end if;
  end process;
  -- Save/restore process for Busy frame.
  save_restore_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      shadow_word0 <= (others => '0');
      shadow_word1 <= (others => '0');
      shadow_word2 <= (others => '0');
    elsif rising_edge(clk) then
      if save_req = '1' then
        -- Word 0: main FSM state + arith stage.
        shadow_word0(15 downto 0) <= std_logic_vector(to_unsigned(
          packed_state_t'pos(state_reg), 16));
        shadow_word0(31 downto 16) <= std_logic_vector(to_unsigned(
          arith_stage_t'pos(arith_stage_reg), 16));
        -- Word 1: digit index + encode state.
        shadow_word1 <= std_logic_vector(to_unsigned(idx_reg, 16)) &
                        std_logic_vector(to_unsigned(
                          packed_state_t'pos(scale_return_state_reg), 16));
        -- Word 2: scale_abs_exp + flags.
        shadow_word2 <= std_logic_vector(to_unsigned(scale_abs_exp_reg, 16)) &
                        std_logic_vector(to_unsigned(scale_bit_idx_reg, 8)) &
                        "0000000" & scale_use_neg_reg;
      end if;
      if restore_wr = '1' then
        case restore_addr is
          when 0 => shadow_word0 <= restore_data;
          when 1 => shadow_word1 <= restore_data;
          when 2 => shadow_word2 <= restore_data;
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- Save data mux.
  save_data <= shadow_word0 when save_addr = 0 else
               shadow_word1 when save_addr = 1 else
               shadow_word2 when save_addr = 2 else
               (others => '0');

end architecture rtl;
