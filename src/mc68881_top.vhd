library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_top is
  port (
    -- Bus interface
    a_in    : in  std_logic_vector(4 downto 0);
    d_in    : in  std_logic_vector(31 downto 0);
    d_out   : out std_logic_vector(31 downto 0);
    size_n  : in  std_logic_vector(1 downto 0); -- active low
    as_n    : in  std_logic; -- active low
    cs_n    : in  std_logic; -- active low
    rw      : in  std_logic; -- high=read, low=write
    ds_n    : in  std_logic; -- active low
    dsack0_n: out std_logic;
    dsack1_n: out std_logic;
    reset_n : in  std_logic;
    clk     : in  std_logic;
    sense_n : inout std_logic
  );
end entity mc68881_top;

architecture rtl of mc68881_top is
  -- Two-slot operand buffer (A/B) used by bus writes before ALU launch.
  type reg_array_t is array (0 to 1) of fp80_t;

  signal op_sel_reg    : fpu_op_t := FPU_OP_NOP;
  signal operand_reg   : reg_array_t := (others => (others => '0'));
  signal result    : fp80_t := (others => '0');
  signal aux_result : fp80_t := (others => '0');
  signal result_lo_reg : std_logic_vector(FP80_RESULT_LO_WIDTH-1 downto 0) := (others => '0');
  signal result_hi_reg : std_logic_vector(FP80_RESULT_HI_WIDTH-1 downto 0) := (others => '0');
  signal result_ex_reg : std_logic_vector(FP80_RESULT_EX_WIDTH-1 downto 0) := (others => '0');
  signal aux_result_lo_reg : std_logic_vector(FP80_RESULT_LO_WIDTH-1 downto 0) := (others => '0');
  signal aux_result_hi_reg : std_logic_vector(FP80_RESULT_HI_WIDTH-1 downto 0) := (others => '0');
  signal aux_result_ex_reg : std_logic_vector(FP80_RESULT_EX_WIDTH-1 downto 0) := (others => '0');
  signal valid     : std_logic := '0';
  signal aux_valid : std_logic := '0';
  signal quotient_valid : std_logic := '0';
  signal quotient_byte : std_logic_vector(7 downto 0) := (others => '0');
  signal busy      : std_logic := '0';
  signal alu_flag_divzero : std_logic := '0';
  signal sense_drive : std_logic := '1';
  signal op_start_reg  : std_logic := '0';
  signal status_valid_reg : std_logic := '0';
  signal status_busy_reg  : std_logic := '0';
  signal status_frame_valid_reg : std_logic := '0';
  signal status_frame_busy_reg  : std_logic := '0';
  signal fpcr_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal fpsr_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal fpiar_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal move_cfg_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal move_cfg_decoded_reg : move_cfg_t := move_cfg_default;
  signal round_mode : fp_round_mode_t := FP_RND_NEAREST;
  signal round_prec : fp_round_prec_t := FP_PREC_EXTENDED;
  signal src_kind_reg : fpu_src_kind_t := FPU_SRC_FPM;
  signal ea_mode_reg  : ea_mode_t := EA_MODE_DN_AN;
  signal cycle_case_reg : ea_cycle_case_t := EA_CYCLE_BEST;
  signal mc68020_src_reg : std_logic := '0';
  signal mc68020_dst_reg : std_logic := '0';
  signal packed_dynamic_k_reg : std_logic := '0';

  signal dsack0_i  : std_logic := '1';
  signal dsack1_i  : std_logic := '1';

  signal bus_write : std_logic;
  signal bus_read  : std_logic;
  signal start_access : std_logic;
  signal addr      : unsigned(4 downto 0);

  -- Memory-mapped register offsets used by host-side command/data protocol.
  constant ADDR_OPSEL  : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L  : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPA_H  : unsigned(4 downto 0) := to_unsigned(2, 5);
  constant ADDR_OPA_E  : unsigned(4 downto 0) := to_unsigned(3, 5);
  constant ADDR_OPB_L  : unsigned(4 downto 0) := to_unsigned(4, 5);
  constant ADDR_OPB_H  : unsigned(4 downto 0) := to_unsigned(5, 5);
  constant ADDR_OPB_E  : unsigned(4 downto 0) := to_unsigned(6, 5);
  constant ADDR_RES_L  : unsigned(4 downto 0) := to_unsigned(7, 5);
  constant ADDR_RES_H  : unsigned(4 downto 0) := to_unsigned(8, 5);
  constant ADDR_RES_E  : unsigned(4 downto 0) := to_unsigned(9, 5);
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_FPCR   : unsigned(4 downto 0) := to_unsigned(11, 5);
  constant ADDR_CIR_SAVE    : unsigned(4 downto 0) := to_unsigned(12, 5);
  constant ADDR_CIR_RESPONSE: unsigned(4 downto 0) := to_unsigned(13, 5);
  constant ADDR_FPSR   : unsigned(4 downto 0) := to_unsigned(14, 5);
  constant ADDR_CYCLE_CFG0 : unsigned(4 downto 0) := to_unsigned(15, 5);
  constant ADDR_CYCLE_CFG1 : unsigned(4 downto 0) := to_unsigned(16, 5);
  constant ADDR_FRAME_CMD  : unsigned(4 downto 0) := to_unsigned(17, 5);
  constant ADDR_FRAME_W0   : unsigned(4 downto 0) := to_unsigned(18, 5);
  constant ADDR_FRAME_W1   : unsigned(4 downto 0) := to_unsigned(19, 5);
  constant ADDR_FRAME_W2   : unsigned(4 downto 0) := to_unsigned(20, 5);
  constant ADDR_FRAME_W3   : unsigned(4 downto 0) := to_unsigned(21, 5);
  constant ADDR_CYCLE_TOTAL: unsigned(4 downto 0) := to_unsigned(22, 5);
  constant ADDR_MOVE_CFG   : unsigned(4 downto 0) := to_unsigned(23, 5);
  constant ADDR_FPIAR      : unsigned(4 downto 0) := to_unsigned(24, 5);
  constant ADDR_AUX_RES_L  : unsigned(4 downto 0) := to_unsigned(25, 5);
  constant ADDR_AUX_RES_H  : unsigned(4 downto 0) := to_unsigned(26, 5);
  constant ADDR_AUX_RES_E  : unsigned(4 downto 0) := to_unsigned(27, 5);

  type dsack_state_t is (DSACK_IDLE, DSACK_WAIT_ASSERT, DSACK_ASSERTED);
  signal dsack_state  : dsack_state_t := DSACK_IDLE;
  signal dsack_count  : natural range 0 to 3 := 0;
  signal dsack_active : std_logic := '0';
  signal latched_size : std_logic_vector(1 downto 0) := (others => '0');
  signal latched_a4   : std_logic := '0';
  signal sync_read    : std_logic := '0';
  signal d_out_reg    : std_logic_vector(31 downto 0) := (others => '0');
  signal d_out_comb   : std_logic_vector(31 downto 0) := (others => '0');
  constant DSACK_ASSERT_CYCLES_READ  : natural := 1;
  constant DSACK_ASSERT_CYCLES_WRITE : natural := 1;

  signal micro_active_reg    : std_logic := '0';
  signal micro_remaining_reg : natural := 0;
  signal micro_total_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal result_ready_reg    : std_logic := '0';
  signal last_op_sel_reg     : fpu_op_t := FPU_OP_NOP;
  signal fpiar_issue_snapshot_reg : std_logic_vector(31 downto 0) := (others => '0');
  type fp_reg_file_t is array (0 to 7) of fp80_t;
  signal fp_reg_file_reg : fp_reg_file_t := (others => (others => '0'));
  signal fp_movem_shadow_reg : fp_reg_file_t := (others => (others => '0'));

  type frame_mem_t is array (0 to 3) of std_logic_vector(31 downto 0);
  signal frame_mem_reg : frame_mem_t := (others => (others => '0'));
  signal frame_busy_reg : std_logic := '0';
  signal frame_remaining_reg : natural := 0;
  signal frame_valid_reg : std_logic := '0';
  signal frame_restore_pending_reg : std_logic := '0';
  signal frame_start_save_reg : std_logic := '0';
  signal frame_start_restore_reg : std_logic := '0';

  signal op_sel_write_decoded : fpu_op_t := FPU_OP_NOP;
  signal op_class_write_decoded : fpu_op_class_t := OP_CLASS_NONE;
  signal conditional_prog_op_write : std_logic := '0';
  signal op_issue_pulse       : std_logic := '0';
  signal ctrl_move_write_req_reg : std_logic := '0';
  signal ctrl_move_sel_reg : std_logic_vector(1 downto 0) := (others => '0');
  signal ctrl_move_data_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal cir_response_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal cir_response_pending_reg : std_logic := '0';
  signal cir_trap_pending_reg : std_logic := '0';
  signal cir_protocol_violation_reg : std_logic := '0';
  signal exc_event_valid_reg : std_logic := '0';
  signal exc_event_result_reg : fp80_t := (others => '0');
  signal exc_event_opa_reg : fp80_t := (others => '0');
  signal exc_event_opb_reg : fp80_t := x"3FFF8000000000000000";
  signal exc_event_divzero_reg : std_logic := '0';
  signal exc_event_force_overflow_reg : std_logic := '0';
  signal exc_event_force_underflow_reg : std_logic := '0';
  signal exc_event_force_inexact_reg : std_logic := '0';
  signal exc_event_force_bsun_reg : std_logic := '0';

  constant FRAME_LATENCY : natural := 6;
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP80_CLASSIFY_ONE : fp80_t := x"3FFF8000000000000000";

  constant FPSR_CC_NAN      : natural := 24;
  constant FPSR_CC_INF      : natural := 25;
  constant FPSR_CC_ZERO     : natural := 26;
  constant FPSR_CC_NEG      : natural := 27;
  constant FPSR_QUOT_LSB    : natural := 16;
  constant FPSR_QUOT_MSB    : natural := 23;
  constant FPSR_AEXC_LSB    : natural := 0;
  constant FPSR_AEXC_MSB    : natural := 7;
  constant FPSR_EXC_LSB     : natural := 8;
  constant FPSR_EXC_MSB     : natural := 15;
  constant FPSR_EXC_INEXACT  : natural := 0;
  constant FPSR_EXC_UNDERFLOW: natural := 1;
  constant FPSR_EXC_OVERFLOW : natural := 2;
  constant FPSR_EXC_DIVZERO  : natural := 3;
  constant FPSR_EXC_INVALID  : natural := 4;
  constant FPSR_EXC_BSUN     : natural := 7;
  constant FPCR_EXC_EN_BSUN  : natural := 15;

  type access_class_t is (
    ACCESS_NONE,
    ACCESS_OPERAND,
    ACCESS_RESULT,
    ACCESS_STATUS,
    ACCESS_FPCR,
    ACCESS_FPSR,
    ACCESS_FPIAR,
    ACCESS_CIR,
    ACCESS_FRAME,
    ACCESS_MOVE,
    ACCESS_CFG
  );
  signal access_class : access_class_t := ACCESS_NONE;

  function signed8_to_integer(bits : std_logic_vector(7 downto 0)) return integer is
  begin
    return to_integer(signed(bits));
  end function;

  function signed16_to_integer(bits : std_logic_vector(15 downto 0)) return integer is
    variable magnitude : unsigned(14 downto 0);
  begin
    if bits(15) = '0' then
      return to_integer(unsigned(bits(14 downto 0)));
    elsif bits = x"8000" then
      return -32768;
    else
      magnitude := unsigned(not bits(14 downto 0)) + 1;
      return -to_integer(magnitude);
    end if;
  end function;

  function signed32_to_integer(bits : std_logic_vector(31 downto 0)) return integer is
    variable magnitude : unsigned(30 downto 0);
  begin
    if bits(31) = '0' then
      return to_integer(unsigned(bits(30 downto 0)));
    elsif bits = x"80000000" then
      return integer'low;
    else
      magnitude := unsigned(not bits(30 downto 0)) + 1;
      return -to_integer(magnitude);
    end if;
  end function;

  function clamp_integer(value : integer; min_value : integer; max_value : integer) return integer is
  begin
    if value < min_value then
      return min_value;
    elsif value > max_value then
      return max_value;
    else
      return value;
    end if;
  end function;

  type fmovecr_rom_t is array (0 to 127) of fp80_t;
  constant FMOVECR_ROM : fmovecr_rom_t := (
    16#00# => x"4000C90FDAA22168C235", -- pi
    16#0B# => x"3FFD9A209A84FBCFF798", -- log10(2)
    16#0C# => x"4000ADF85458A2BB4A9A", -- e
    16#0D# => x"3FFFB8AA3B295C17F0BC", -- log2(e)
    16#0E# => x"3FFDDE5BD8A937287195", -- log10(e)
    16#0F# => x"00000000000000000000", -- 0.0
    16#30# => x"3FFEB17217F7D1CF79AC", -- ln(2)
    16#31# => x"4000935D8DDDAAA8AC17", -- ln(10)
    16#32# => x"3FFF8000000000000000", -- 10^0
    16#33# => x"4002A000000000000000", -- 10^1
    16#34# => x"4005C800000000000000", -- 10^2
    16#35# => x"400C9C40000000000000", -- 10^4
    16#36# => x"4019BEBC200000000000", -- 10^8
    16#37# => x"40348E1BC9BF04000000", -- 10^16
    16#38# => x"40699DC5ADA82B70B59E", -- 10^32
    16#39# => x"40D3C2781F49FFCFA6D5", -- 10^64
    16#3A# => x"41A893BA47C980E98CE0", -- 10^128
    16#3B# => x"4351AA7EEBFB9DF9DE8E", -- 10^256
    16#3C# => x"46A3E319A0AEA60E91C7", -- 10^512
    16#3D# => x"4D48C976758681750C17", -- 10^1024
    16#3E# => x"5A929E8B3B5DC53D5DE5", -- 10^2048
    16#3F# => x"7525C46052028A20979B", -- 10^4096
    others => (others => '0')
  );

  function fmovecr_constant(ccc : std_logic_vector(6 downto 0)) return fp80_t is
    variable ccc_index : natural range 0 to 127 := 0;
  begin
    ccc_index := to_integer(unsigned(ccc));
    return FMOVECR_ROM(ccc_index);
  end function;

  function apply_packed_k_factor(value : fp80_t; k_factor : integer) return fp80_t is
    variable adjusted : fp80_t := value;
    variable k_clamped : integer := 0;
    variable fractional_bits : integer := 0;
    variable bit_count : natural := 0;
  begin
    -- Placeholder packed-decimal shaping using k-factor; full decimal encode/decode is tracked by B8.
    k_clamped := clamp_integer(k_factor, -64, 17);
    if k_clamped <= 0 then
      fractional_bits := 63 - (-k_clamped / 2);
    else
      fractional_bits := (k_clamped * 3) + 6;
    end if;
    fractional_bits := clamp_integer(fractional_bits, 0, 63);
    bit_count := natural(63 - fractional_bits);
    if bit_count > 0 then
      adjusted(bit_count-1 downto 0) := (others => '0');
    end if;
    return adjusted;
  end function;

  function fp80_from_single(bits : std_logic_vector(31 downto 0)) return fp80_t is
    variable fp_value : fp80_t := (others => '0');
    variable exp_s : unsigned(7 downto 0) := unsigned(bits(30 downto 23));
    variable frac_s : unsigned(22 downto 0) := unsigned(bits(22 downto 0));
    variable frac_norm_s : unsigned(22 downto 0) := (others => '0');
    variable exp80 : integer := 0;
    variable lz_s : integer range 0 to 22 := 0;
  begin
    fp_value(FP_WIDTH-1) := bits(31);
    if exp_s = 0 then
      if frac_s = 0 then
        return fp_value;
      end if;
      for idx in 22 downto 0 loop
        if frac_s(idx) = '1' then
          lz_s := 22 - idx;
          exit;
        end if;
      end loop;
      exp80 := FP_EXP_BIAS - 127 - lz_s;
      fp_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(to_unsigned(exp80, FP_EXP_WIDTH));
      frac_norm_s := shift_left(frac_s, lz_s);
      fp_value(FP_MANT_WIDTH-1) := '1';
      fp_value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-23) := std_logic_vector(frac_norm_s(21 downto 0));
      return fp_value;
    elsif exp_s = to_unsigned(255, 8) then
      fp_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
      if frac_s /= 0 then
        fp_value(FP_MANT_WIDTH-1) := '1';
        fp_value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-24) := std_logic_vector(frac_s);
      end if;
      return fp_value;
    else
      exp80 := to_integer(exp_s) - 127 + FP_EXP_BIAS;
      fp_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(to_unsigned(exp80, FP_EXP_WIDTH));
      fp_value(FP_MANT_WIDTH-1) := '1';
      fp_value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-24) := std_logic_vector(frac_s);
      return fp_value;
    end if;
  end function;

  function fp80_from_double(bits : std_logic_vector(63 downto 0)) return fp80_t is
    variable fp_value : fp80_t := (others => '0');
    variable exp_d : unsigned(10 downto 0) := unsigned(bits(62 downto 52));
    variable frac_d : unsigned(51 downto 0) := unsigned(bits(51 downto 0));
    variable frac_norm_d : unsigned(51 downto 0) := (others => '0');
    variable exp80 : integer := 0;
    variable lz_d : integer range 0 to 51 := 0;
  begin
    fp_value(FP_WIDTH-1) := bits(63);
    if exp_d = 0 then
      if frac_d = 0 then
        return fp_value;
      end if;
      for idx in 51 downto 0 loop
        if frac_d(idx) = '1' then
          lz_d := 51 - idx;
          exit;
        end if;
      end loop;
      exp80 := FP_EXP_BIAS - 1023 - lz_d;
      fp_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(to_unsigned(exp80, FP_EXP_WIDTH));
      frac_norm_d := shift_left(frac_d, lz_d);
      fp_value(FP_MANT_WIDTH-1) := '1';
      fp_value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-52) := std_logic_vector(frac_norm_d(50 downto 0));
      return fp_value;
    elsif exp_d = to_unsigned(2047, 11) then
      fp_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
      if frac_d /= 0 then
        fp_value(FP_MANT_WIDTH-1) := '1';
        fp_value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-53) := std_logic_vector(frac_d);
      end if;
      return fp_value;
    else
      exp80 := to_integer(exp_d) - 1023 + FP_EXP_BIAS;
      fp_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(to_unsigned(exp80, FP_EXP_WIDTH));
      fp_value(FP_MANT_WIDTH-1) := '1';
      fp_value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-53) := std_logic_vector(frac_d);
      return fp_value;
    end if;
  end function;

  function should_round_up(
    sign_bit : std_logic;
    lsb_bit : std_logic;
    guard_bit : std_logic;
    sticky_bit : std_logic;
    mode : fp_round_mode_t
  ) return std_logic is
    variable remainder_nonzero : std_logic := '0';
  begin
    remainder_nonzero := guard_bit or sticky_bit;
    case mode is
      when FP_RND_NEAREST =>
        if guard_bit = '1' and (sticky_bit = '1' or lsb_bit = '1') then
          return '1';
        end if;
      when FP_RND_ZERO =>
        null;
      when FP_RND_MINUS_INF =>
        if sign_bit = '1' and remainder_nonzero = '1' then
          return '1';
        end if;
      when FP_RND_PLUS_INF =>
        if sign_bit = '0' and remainder_nonzero = '1' then
          return '1';
        end if;
    end case;
    return '0';
  end function;

  function fp80_to_single(value : fp80_t; mode : fp_round_mode_t) return std_logic_vector is
    variable bits32 : std_logic_vector(31 downto 0) := (others => '0');
    variable exp80_u : unsigned(FP_EXP_WIDTH-1 downto 0) := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    variable frac80 : unsigned(FP_MANT_WIDTH-2 downto 0) := unsigned(value(FP_MANT_WIDTH-2 downto 0));
    variable mant80 : unsigned(FP_MANT_WIDTH-1 downto 0) := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    variable exp80_i : integer := 0;
    variable exp32 : integer := 0;
    variable sig_base : unsigned(23 downto 0) := (others => '0');
    variable sig_round : unsigned(24 downto 0) := (others => '0');
    variable guard_bit : std_logic := '0';
    variable sticky_bit : std_logic := '0';
    variable round_up : std_logic := '0';
    variable shift_total : integer := 0;
    variable sticky_hi : integer := -1;
  begin
    bits32(31) := value(FP_WIDTH-1);
    exp80_i := to_integer(exp80_u);

    if exp80_u = 0 then
      -- fp80 subnormal: magnitude far below single range.
      -- Directed rounding away from zero produces minimum subnormal.
      if mant80 /= 0 then
        if (mode = FP_RND_PLUS_INF and value(FP_WIDTH-1) = '0') or
           (mode = FP_RND_MINUS_INF and value(FP_WIDTH-1) = '1') then
          bits32(0) := '1';
        end if;
      end if;
      return bits32;
    elsif exp80_u = FP_EXP_ALL_ONES then
      bits32(30 downto 23) := (others => '1');
      if frac80 /= 0 then
        bits32(22 downto 0) := value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-24);
        if bits32(22 downto 0) = std_logic_vector(to_unsigned(0, 23)) then
          bits32(22) := '1';
        end if;
      end if;
      return bits32;
    else
      exp32 := exp80_i - FP_EXP_BIAS + 127;
      if exp32 > 0 then
        sig_base := mant80(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-24);
        guard_bit := mant80(FP_MANT_WIDTH-25);
        sticky_bit := '0';
        for idx in 0 to FP_MANT_WIDTH-26 loop
          if mant80(idx) = '1' then
            sticky_bit := '1';
          end if;
        end loop;
        round_up := should_round_up(value(FP_WIDTH-1), sig_base(0), guard_bit, sticky_bit, mode);
        sig_round := resize(sig_base, sig_round'length);
        if round_up = '1' then
          sig_round := sig_round + 1;
        end if;
        if sig_round(sig_round'left) = '1' then
          exp32 := exp32 + 1;
          sig_base := sig_round(sig_round'left downto 1);
        else
          sig_base := sig_round(sig_base'range);
        end if;

        if exp32 >= 255 then
          case mode is
            when FP_RND_NEAREST =>
              bits32(30 downto 23) := (others => '1');
              bits32(22 downto 0) := (others => '0');
            when FP_RND_ZERO =>
              bits32(30 downto 23) := std_logic_vector(to_unsigned(254, 8));
              bits32(22 downto 0) := (others => '1');
            when FP_RND_MINUS_INF =>
              if value(FP_WIDTH-1) = '1' then
                bits32(30 downto 23) := (others => '1');
                bits32(22 downto 0) := (others => '0');
              else
                bits32(30 downto 23) := std_logic_vector(to_unsigned(254, 8));
                bits32(22 downto 0) := (others => '1');
              end if;
            when FP_RND_PLUS_INF =>
              if value(FP_WIDTH-1) = '0' then
                bits32(30 downto 23) := (others => '1');
                bits32(22 downto 0) := (others => '0');
              else
                bits32(30 downto 23) := std_logic_vector(to_unsigned(254, 8));
                bits32(22 downto 0) := (others => '1');
              end if;
          end case;
          return bits32;
        end if;

        bits32(30 downto 23) := std_logic_vector(to_unsigned(exp32, 8));
        bits32(22 downto 0) := std_logic_vector(sig_base(22 downto 0));
        return bits32;
      else
        -- Gradual underflow: right-shift significand into subnormal range.
        shift_total := 40 + (1 - exp32);
        sig_base := (others => '0');
        guard_bit := '0';
        sticky_bit := '0';
        if shift_total < FP_MANT_WIDTH then
          sig_base := shift_right(mant80, shift_total)(23 downto 0);
        end if;

        if shift_total > 0 and shift_total - 1 < FP_MANT_WIDTH then
          guard_bit := mant80(shift_total - 1);
        end if;
        sticky_hi := shift_total - 2;
        if sticky_hi > FP_MANT_WIDTH-1 then
          sticky_hi := FP_MANT_WIDTH-1;
        end if;
        if sticky_hi >= 0 then
          for idx in 0 to sticky_hi loop
            if mant80(idx) = '1' then
              sticky_bit := '1';
            end if;
          end loop;
        end if;

        round_up := should_round_up(value(FP_WIDTH-1), sig_base(0), guard_bit, sticky_bit, mode);
        sig_round := resize(sig_base, sig_round'length);
        if round_up = '1' then
          sig_round := sig_round + 1;
        end if;

        if sig_round(23) = '1' then
          bits32(30 downto 23) := std_logic_vector(to_unsigned(1, 8));
          bits32(22 downto 0) := (others => '0');
        else
          bits32(30 downto 23) := (others => '0');
          bits32(22 downto 0) := std_logic_vector(sig_round(22 downto 0));
        end if;
        return bits32;
      end if;
    end if;
  end function;

  function fp80_to_double(value : fp80_t; mode : fp_round_mode_t) return std_logic_vector is
    variable bits64 : std_logic_vector(63 downto 0) := (others => '0');
    variable exp80_u : unsigned(FP_EXP_WIDTH-1 downto 0) := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    variable frac80 : unsigned(FP_MANT_WIDTH-2 downto 0) := unsigned(value(FP_MANT_WIDTH-2 downto 0));
    variable mant80 : unsigned(FP_MANT_WIDTH-1 downto 0) := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    variable exp80_i : integer := 0;
    variable exp64 : integer := 0;
    variable sig_base : unsigned(52 downto 0) := (others => '0');
    variable sig_round : unsigned(53 downto 0) := (others => '0');
    variable guard_bit : std_logic := '0';
    variable sticky_bit : std_logic := '0';
    variable round_up : std_logic := '0';
    variable shift_total : integer := 0;
    variable sticky_hi : integer := -1;
  begin
    bits64(63) := value(FP_WIDTH-1);
    exp80_i := to_integer(exp80_u);

    if exp80_u = 0 then
      -- fp80 subnormal: magnitude far below double range.
      -- Directed rounding away from zero produces minimum subnormal.
      if mant80 /= 0 then
        if (mode = FP_RND_PLUS_INF and value(FP_WIDTH-1) = '0') or
           (mode = FP_RND_MINUS_INF and value(FP_WIDTH-1) = '1') then
          bits64(0) := '1';
        end if;
      end if;
      return bits64;
    elsif exp80_u = FP_EXP_ALL_ONES then
      bits64(62 downto 52) := (others => '1');
      if frac80 /= 0 then
        bits64(51 downto 0) := value(FP_MANT_WIDTH-2 downto FP_MANT_WIDTH-53);
        if bits64(51 downto 0) = std_logic_vector(to_unsigned(0, 52)) then
          bits64(51) := '1';
        end if;
      end if;
      return bits64;
    else
      exp64 := exp80_i - FP_EXP_BIAS + 1023;
      if exp64 > 0 then
        sig_base := mant80(FP_MANT_WIDTH-1 downto FP_MANT_WIDTH-53);
        guard_bit := mant80(FP_MANT_WIDTH-54);
        sticky_bit := '0';
        for idx in 0 to FP_MANT_WIDTH-55 loop
          if mant80(idx) = '1' then
            sticky_bit := '1';
          end if;
        end loop;
        round_up := should_round_up(value(FP_WIDTH-1), sig_base(0), guard_bit, sticky_bit, mode);
        sig_round := resize(sig_base, sig_round'length);
        if round_up = '1' then
          sig_round := sig_round + 1;
        end if;
        if sig_round(sig_round'left) = '1' then
          exp64 := exp64 + 1;
          sig_base := sig_round(sig_round'left downto 1);
        else
          sig_base := sig_round(sig_base'range);
        end if;

        if exp64 >= 2047 then
          case mode is
            when FP_RND_NEAREST =>
              bits64(62 downto 52) := (others => '1');
              bits64(51 downto 0) := (others => '0');
            when FP_RND_ZERO =>
              bits64(62 downto 52) := std_logic_vector(to_unsigned(2046, 11));
              bits64(51 downto 0) := (others => '1');
            when FP_RND_MINUS_INF =>
              if value(FP_WIDTH-1) = '1' then
                bits64(62 downto 52) := (others => '1');
                bits64(51 downto 0) := (others => '0');
              else
                bits64(62 downto 52) := std_logic_vector(to_unsigned(2046, 11));
                bits64(51 downto 0) := (others => '1');
              end if;
            when FP_RND_PLUS_INF =>
              if value(FP_WIDTH-1) = '0' then
                bits64(62 downto 52) := (others => '1');
                bits64(51 downto 0) := (others => '0');
              else
                bits64(62 downto 52) := std_logic_vector(to_unsigned(2046, 11));
                bits64(51 downto 0) := (others => '1');
              end if;
          end case;
          return bits64;
        end if;

        bits64(62 downto 52) := std_logic_vector(to_unsigned(exp64, 11));
        bits64(51 downto 0) := std_logic_vector(sig_base(51 downto 0));
        return bits64;
      else
        shift_total := 11 + (1 - exp64);
        sig_base := (others => '0');
        guard_bit := '0';
        sticky_bit := '0';
        if shift_total < FP_MANT_WIDTH then
          sig_base := shift_right(mant80, shift_total)(52 downto 0);
        end if;

        if shift_total > 0 and shift_total - 1 < FP_MANT_WIDTH then
          guard_bit := mant80(shift_total - 1);
        end if;
        sticky_hi := shift_total - 2;
        if sticky_hi > FP_MANT_WIDTH-1 then
          sticky_hi := FP_MANT_WIDTH-1;
        end if;
        if sticky_hi >= 0 then
          for idx in 0 to sticky_hi loop
            if mant80(idx) = '1' then
              sticky_bit := '1';
            end if;
          end loop;
        end if;

        round_up := should_round_up(value(FP_WIDTH-1), sig_base(0), guard_bit, sticky_bit, mode);
        sig_round := resize(sig_base, sig_round'length);
        if round_up = '1' then
          sig_round := sig_round + 1;
        end if;

        if sig_round(52) = '1' then
          bits64(62 downto 52) := std_logic_vector(to_unsigned(1, 11));
          bits64(51 downto 0) := (others => '0');
        else
          bits64(62 downto 52) := (others => '0');
          bits64(51 downto 0) := std_logic_vector(sig_round(51 downto 0));
        end if;
        return bits64;
      end if;
    end if;
  end function;

  function decode_src_kind(bits : std_logic_vector(2 downto 0)) return fpu_src_kind_t is
  begin
    case bits is
      when "000" => return FPU_SRC_FPM;
      when "001" => return FPU_SRC_MEM_INTEGER;
      when "010" => return FPU_SRC_MEM_SINGLE;
      when "011" => return FPU_SRC_MEM_DOUBLE;
      when "100" => return FPU_SRC_MEM_EXTENDED;
      when others => return FPU_SRC_MEM_PACKED;
    end case;
  end function;

  function decode_ea_mode(bits : std_logic_vector(4 downto 0)) return ea_mode_t is
  begin
    case bits is
      when "00000" => return EA_MODE_DN_AN;
      when "00001" => return EA_MODE_AN_INDIRECT;
      when "00010" => return EA_MODE_AN_POSTINC;
      when "00011" => return EA_MODE_AN_PREDEC;
      when "00100" => return EA_MODE_D16_AN_PC;
      when "00101" => return EA_MODE_ABS_W;
      when "00110" => return EA_MODE_ABS_L;
      when "00111" => return EA_MODE_IMMEDIATE;
      when "01000" => return EA_MODE_D8_AN_PC_XN;
      when "01001" => return EA_MODE_D16_AN_PC_XN;
      when "01010" => return EA_MODE_B;
      when "01011" => return EA_MODE_D16_B;
      when "01100" => return EA_MODE_D32_B;
      when "01101" => return EA_MODE_B_INDIRECT_I;
      when "01110" => return EA_MODE_B_INDIRECT_I_D16;
      when "01111" => return EA_MODE_B_INDIRECT_I_D32;
      when "10000" => return EA_MODE_D16_B_INDIRECT_I;
      when "10001" => return EA_MODE_D16_B_INDIRECT_I_D16;
      when "10010" => return EA_MODE_D16_B_INDIRECT_I_D32;
      when "10011" => return EA_MODE_D32_B_INDIRECT_I;
      when "10100" => return EA_MODE_D32_B_INDIRECT_I_D16;
      when others  => return EA_MODE_D32_B_INDIRECT_I_D32;
    end case;
  end function;

  function decode_cycle_case(bits : std_logic_vector(1 downto 0)) return ea_cycle_case_t is
  begin
    case bits is
      when "00" => return EA_CYCLE_BEST;
      when "01" => return EA_CYCLE_CACHE;
      when others => return EA_CYCLE_WORST;
    end case;
  end function;

  function compare_fp80_ordered(a : fp80_t; b : fp80_t) return integer is
    variable a_sign : std_logic := a(FP_WIDTH-1);
    variable b_sign : std_logic := b(FP_WIDTH-1);
    variable a_exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable b_exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable a_mant : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable b_mant : unsigned(FP_MANT_WIDTH-1 downto 0);
    variable mag_cmp : integer := 0;
  begin
    a_exp := unsigned(a(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    b_exp := unsigned(b(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    a_mant := unsigned(a(FP_MANT_WIDTH-1 downto 0));
    b_mant := unsigned(b(FP_MANT_WIDTH-1 downto 0));

    if fp80_is_zero(a) and fp80_is_zero(b) then
      return 0;
    end if;

    if a_sign /= b_sign then
      if a_sign = '1' then
        return -1;
      end if;
      return 1;
    end if;

    if a_exp > b_exp then
      mag_cmp := 1;
    elsif a_exp < b_exp then
      mag_cmp := -1;
    elsif a_mant > b_mant then
      mag_cmp := 1;
    elsif a_mant < b_mant then
      mag_cmp := -1;
    else
      mag_cmp := 0;
    end if;

    if a_sign = '1' then
      return -mag_cmp;
    end if;
    return mag_cmp;
  end function;

  function fpsr_cc_from_result(value : fp80_t) return std_logic_vector is
    variable cc_bits : std_logic_vector(3 downto 0) := (others => '0');
  begin
    -- Data-type classification bits (mutually exclusive).
    if fp80_is_nan(value) then
      cc_bits(0) := '1';
    elsif fp80_is_inf(value) then
      cc_bits(1) := '1';
    elsif fp80_is_zero(value) then
      cc_bits(2) := '1';
    end if;
    -- N bit always reflects sign independently (datasheet Table 2-1).
    cc_bits(3) := value(FP_WIDTH-1);
    return cc_bits;
  end function;

  function fp80_exp_is_zero_nonzero_mant(value : fp80_t) return boolean is
    variable exp_bits : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable mant_bits : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    exp_bits := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    mant_bits := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return exp_bits = 0 and mant_bits /= 0;
  end function;

  function fpsr_cc_from_compare(a : fp80_t; b : fp80_t) return std_logic_vector is
    variable cc_bits : std_logic_vector(3 downto 0) := (others => '0');
    variable cmp : integer := 0;
  begin
    if fp80_is_nan(a) or fp80_is_nan(b) then
      cc_bits(0) := '1';
      return cc_bits;
    end if;

    cmp := compare_fp80_ordered(a, b);
    if cmp = 0 then
      cc_bits(2) := '1';
    elsif cmp < 0 then
      cc_bits(3) := '1';
    end if;
    return cc_bits;
  end function;

  function normalize_fcc_condition(condition_sel : std_logic_vector(5 downto 0)) return std_logic_vector is
    variable sel : std_logic_vector(5 downto 0) := (others => '0');
  begin
    -- Mirror upper 32 condition codes to lower 32 per MC68881 architecture.
    sel := '0' & condition_sel(4 downto 0);
    return sel;
  end function;

  function is_signaling_fcc_condition(condition_sel : std_logic_vector(5 downto 0)) return boolean is
    variable sel : std_logic_vector(5 downto 0) := (others => '0');
  begin
    sel := normalize_fcc_condition(condition_sel);
    -- 0x10..0x1F are the "with NAN exception" signaling condition variants.
    return sel(4) = '1';
  end function;

  function is_conditional_prog_op(op_sel : fpu_op_t) return boolean is
  begin
    return op_sel = FPU_OP_FSCC or op_sel = FPU_OP_FBCC or op_sel = FPU_OP_FDBCC;
  end function;

  function eval_fcc_condition(
    condition_sel : std_logic_vector(5 downto 0);
    cc_bits : std_logic_vector(3 downto 0)
  ) return std_logic is
    variable nan_set : boolean := false;
    variable inf_set : boolean := false;
    variable zero_set : boolean := false;
    variable neg_set : boolean := false;
    variable unordered : boolean := false;
    variable ordered : boolean := false;
    variable greater_than : boolean := false;
    variable less_than : boolean := false;
    variable equal_to : boolean := false;
    variable sel : std_logic_vector(5 downto 0);
  begin
    nan_set := cc_bits(0) = '1';
    inf_set := cc_bits(1) = '1';
    zero_set := cc_bits(2) = '1';
    neg_set := cc_bits(3) = '1';
    unordered := nan_set;
    ordered := not unordered;
    equal_to := ordered and zero_set;
    greater_than := ordered and (not zero_set) and (not neg_set);
    less_than := ordered and neg_set and (not zero_set);

    sel := normalize_fcc_condition(condition_sel);
    case sel is
      when "000000" => return '0'; -- F
      when "000001" => if equal_to then return '1'; else return '0'; end if; -- EQ
      when "000010" => if greater_than then return '1'; else return '0'; end if; -- OGT
      when "000011" => if greater_than or equal_to then return '1'; else return '0'; end if; -- OGE
      when "000100" => if less_than then return '1'; else return '0'; end if; -- OLT
      when "000101" => if less_than or equal_to then return '1'; else return '0'; end if; -- OLE
      when "000110" => if greater_than or less_than then return '1'; else return '0'; end if; -- OGL
      when "000111" => if ordered then return '1'; else return '0'; end if; -- OR
      when "001000" => if unordered then return '1'; else return '0'; end if; -- UN
      when "001001" => if unordered or equal_to then return '1'; else return '0'; end if; -- UEQ
      when "001010" => if unordered or greater_than then return '1'; else return '0'; end if; -- UGT
      when "001011" => if unordered or greater_than or equal_to then return '1'; else return '0'; end if; -- UGE
      when "001100" => if unordered or less_than then return '1'; else return '0'; end if; -- ULT
      when "001101" => if unordered or less_than or equal_to then return '1'; else return '0'; end if; -- ULE
      when "001110" => if not equal_to then return '1'; else return '0'; end if; -- NE
      when "001111" => return '1'; -- T
      when "010000" => return '0'; -- SF
      when "010001" => if equal_to then return '1'; else return '0'; end if; -- SEQ
      when "010010" => if greater_than then return '1'; else return '0'; end if; -- GT
      when "010011" => if greater_than or equal_to then return '1'; else return '0'; end if; -- GE
      when "010100" => if less_than then return '1'; else return '0'; end if; -- LT
      when "010101" => if less_than or equal_to then return '1'; else return '0'; end if; -- LE
      when "010110" => if greater_than or less_than then return '1'; else return '0'; end if; -- GL
      when "010111" => if greater_than or less_than or equal_to then return '1'; else return '0'; end if; -- GLE
      when "011000" => if unordered then return '1'; else return '0'; end if; -- NGLE
      when "011001" => if unordered or equal_to then return '1'; else return '0'; end if; -- NGL
      when "011010" => if unordered or greater_than then return '1'; else return '0'; end if; -- NLE
      when "011011" => if unordered or greater_than or equal_to then return '1'; else return '0'; end if; -- NLT
      when "011100" => if unordered or less_than then return '1'; else return '0'; end if; -- NGE
      when "011101" => if unordered or less_than or equal_to then return '1'; else return '0'; end if; -- NGT
      when "011110" => if not equal_to then return '1'; else return '0'; end if; -- SNE
      when others   => return '1'; -- ST
    end case;
  end function;

begin
  addr      <= unsigned(a_in);
  bus_write <= '1' when (cs_n = '0' and as_n = '0' and ds_n = '0' and rw = '0') else '0';
  bus_read  <= '1' when (cs_n = '0' and as_n = '0' and ds_n = '0' and rw = '1') else '0';
  -- START = CS + AS + (R/W · DS) (active low signals except R/W).
  start_access <= '1' when (cs_n = '0' and as_n = '0' and ((rw = '1' and ds_n = '0') or rw = '0')) else '0';

  -- Address classification is reused by bus read timing and decode logic.
  process(addr)
  begin
    access_class <= ACCESS_NONE;
    case addr is
      when ADDR_OPSEL | ADDR_OPA_L | ADDR_OPA_H | ADDR_OPA_E | ADDR_OPB_L | ADDR_OPB_H | ADDR_OPB_E =>
        access_class <= ACCESS_OPERAND;
      when ADDR_RES_L | ADDR_RES_H | ADDR_RES_E | ADDR_AUX_RES_L | ADDR_AUX_RES_H | ADDR_AUX_RES_E =>
        access_class <= ACCESS_RESULT;
      when ADDR_STATUS =>
        access_class <= ACCESS_STATUS;
      when ADDR_FPCR =>
        access_class <= ACCESS_FPCR;
      when ADDR_FPSR =>
        access_class <= ACCESS_FPSR;
      when ADDR_FPIAR =>
        access_class <= ACCESS_FPIAR;
      when ADDR_CIR_SAVE | ADDR_CIR_RESPONSE =>
        access_class <= ACCESS_CIR;
      when ADDR_FRAME_CMD | ADDR_FRAME_W0 | ADDR_FRAME_W1 | ADDR_FRAME_W2 | ADDR_FRAME_W3 =>
        access_class <= ACCESS_FRAME;
      when ADDR_MOVE_CFG =>
        access_class <= ACCESS_MOVE;
      when ADDR_CYCLE_CFG0 | ADDR_CYCLE_CFG1 | ADDR_CYCLE_TOTAL =>
        access_class <= ACCESS_CFG;
      when others =>
        access_class <= ACCESS_NONE;
    end case;
  end process;

  sync_read <= '1' when (bus_read = '1' and access_class = ACCESS_CIR) else '0';
  -- FPCR mode control: bits 7-6 precision, 5-4 rounding mode.
  round_mode <= decode_round_mode(fpcr_reg(5 downto 4));
  round_prec <= decode_round_prec(fpcr_reg(7 downto 6));
  op_sel_write_decoded <= decode_op_sel_word(d_in);
  op_class_write_decoded <= op_class(op_sel_write_decoded);
  conditional_prog_op_write <= '1' when is_conditional_prog_op(op_sel_write_decoded) else '0';
  -- One-cycle launch pulse when OPSEL write is legal and engines are idle.
  op_issue_pulse <= '1' when (
    bus_write = '1' and
    addr = ADDR_OPSEL and
    op_class_write_decoded /= OP_CLASS_NONE and
    micro_active_reg = '0' and
    frame_busy_reg = '0' and
    busy = '0' and
    not (conditional_prog_op_write = '1' and cir_response_pending_reg = '1')
  ) else '0';

  alu_inst : entity work.mc68881_alu
    port map (
      clk    => clk,
      reset_n => reset_n,
      start  => op_start_reg,
      op_sel => op_sel_reg,
      round_mode => round_mode,
      round_prec => round_prec,
      a_in   => operand_reg(0),
      b_in   => operand_reg(1),
      result => result,
      valid  => valid,
      busy   => busy,
      quotient_byte  => quotient_byte,
      quotient_valid => quotient_valid,
      aux_result => aux_result,
      aux_valid  => aux_valid,
      flag_divzero => alu_flag_divzero
    );

  -- Bus/register process:
  -- 1) latches operand/control writes
  -- 2) updates FPSR exception bits from completed results
  -- 3) services frame save/restore state.
  bus_frame_proc : process(clk, reset_n)
    variable status_frame_word : std_logic_vector(31 downto 0);
    variable exc_flags : std_logic_vector(7 downto 0);
    variable exc_status_byte : std_logic_vector(7 downto 0);
    variable accrued_exc_byte : std_logic_vector(7 downto 0);
    variable cc_bits : std_logic_vector(3 downto 0);
    variable exc_policy : op_exception_policy_t;
    variable a_zero : boolean;
    variable b_zero : boolean;
    variable a_inf  : boolean;
    variable b_inf  : boolean;
    variable a_nan  : boolean;
    variable b_nan  : boolean;
    variable res_zero : boolean;
    variable res_inf  : boolean;
    variable res_nan  : boolean;
    variable res_subnormal : boolean;
    variable aexc_combined : std_logic_vector(7 downto 0);
    variable class_opa : fp80_t := (others => '0');
    variable class_opb : fp80_t := FP80_CLASSIFY_ONE;
    variable class_result : fp80_t := (others => '0');
    variable class_divzero : std_logic := '0';
    variable class_force_overflow : std_logic := '0';
    variable class_force_underflow : std_logic := '0';
    variable class_force_inexact : std_logic := '0';
    variable class_force_bsun : std_logic := '0';
  begin
    if reset_n = '0' then
      op_sel_reg <= FPU_OP_NOP;
      operand_reg <= (others => (others => '0'));
      fpcr_reg <= (others => '0');
      fpsr_reg <= (others => '0');
      fpiar_reg <= (others => '0');
      move_cfg_reg <= (others => '0');
      move_cfg_decoded_reg <= move_cfg_default;
      src_kind_reg <= FPU_SRC_FPM;
      ea_mode_reg <= EA_MODE_DN_AN;
      cycle_case_reg <= EA_CYCLE_BEST;
      mc68020_src_reg <= '0';
      mc68020_dst_reg <= '0';
      packed_dynamic_k_reg <= '0';
      frame_mem_reg <= (others => (others => '0'));
      frame_busy_reg <= '0';
      frame_remaining_reg <= 0;
      frame_valid_reg <= '0';
      frame_restore_pending_reg <= '0';
      frame_start_save_reg <= '0';
      frame_start_restore_reg <= '0';
    elsif rising_edge(clk) then
      frame_start_save_reg <= '0';
      frame_start_restore_reg <= '0';

      if bus_write = '1' then
        case addr is
          when ADDR_OPSEL =>
            op_sel_reg <= op_sel_write_decoded;
          when ADDR_OPA_L =>
            operand_reg(0)(FP80_RESULT_LO_WIDTH-1 downto 0) <= d_in;
          when ADDR_OPA_H =>
            operand_reg(0)(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH) <= d_in;
          when ADDR_OPA_E =>
            operand_reg(0)(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH) <= d_in(FP80_RESULT_EX_WIDTH-1 downto 0);
          when ADDR_OPB_L =>
            operand_reg(1)(FP80_RESULT_LO_WIDTH-1 downto 0) <= d_in;
          when ADDR_OPB_H =>
            operand_reg(1)(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH) <= d_in;
          when ADDR_OPB_E =>
            operand_reg(1)(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH) <= d_in(FP80_RESULT_EX_WIDTH-1 downto 0);
          when ADDR_FPCR =>
            fpcr_reg(15 downto 0) <= d_in(15 downto 0);
            fpcr_reg(31 downto 16) <= (others => '0');
          when ADDR_FPSR =>
            fpsr_reg <= d_in;
          when ADDR_FPIAR =>
            fpiar_reg <= d_in;
          when ADDR_CIR_SAVE =>
            fpiar_reg <= d_in;
          when ADDR_MOVE_CFG =>
            move_cfg_reg <= d_in;
            move_cfg_decoded_reg <= decode_move_cfg(d_in);
          when ADDR_CYCLE_CFG0 =>
            src_kind_reg <= decode_src_kind(d_in(2 downto 0));
            ea_mode_reg <= decode_ea_mode(d_in(7 downto 3));
          when ADDR_CYCLE_CFG1 =>
            cycle_case_reg <= decode_cycle_case(d_in(1 downto 0));
            mc68020_src_reg <= d_in(2);
            mc68020_dst_reg <= d_in(3);
            packed_dynamic_k_reg <= d_in(4);
          when ADDR_FRAME_CMD =>
            if d_in(0) = '1' then
              frame_start_save_reg <= '1';
            end if;
            if d_in(1) = '1' then
              frame_start_restore_reg <= '1';
            end if;
          when ADDR_FRAME_W0 =>
            frame_mem_reg(0) <= d_in;
            frame_valid_reg <= '1';
          when ADDR_FRAME_W1 =>
            frame_mem_reg(1) <= d_in;
            frame_valid_reg <= '1';
          when ADDR_FRAME_W2 =>
            frame_mem_reg(2) <= d_in;
            frame_valid_reg <= '1';
          when ADDR_FRAME_W3 =>
            frame_mem_reg(3) <= d_in;
            frame_valid_reg <= '1';
          when others =>
            null;
        end case;
      end if;

      if ctrl_move_write_req_reg = '1' then
        case ctrl_move_sel_reg is
          when "00" =>
            fpcr_reg(15 downto 0) <= ctrl_move_data_reg(15 downto 0);
            fpcr_reg(31 downto 16) <= (others => '0');
          when "01" =>
            fpsr_reg <= ctrl_move_data_reg;
          when others =>
            fpiar_reg <= ctrl_move_data_reg;
        end case;
      end if;

      -- Exception classification is performed at operation-complete boundary
      -- (ALU valid or FMOVE conversion completion event).
      if valid = '1' or exc_event_valid_reg = '1' then
        exc_flags := (others => '0');
        exc_policy := op_exception_policy(last_op_sel_reg);
        if valid = '1' then
          class_opa := operand_reg(0);
          class_opb := operand_reg(1);
          class_result := result;
          class_divzero := alu_flag_divzero;
          class_force_overflow := '0';
          class_force_underflow := '0';
          class_force_inexact := '0';
          class_force_bsun := '0';
        else
          class_opa := exc_event_opa_reg;
          class_opb := exc_event_opb_reg;
          class_result := exc_event_result_reg;
          class_divzero := exc_event_divzero_reg;
          class_force_overflow := exc_event_force_overflow_reg;
          class_force_underflow := exc_event_force_underflow_reg;
          class_force_inexact := exc_event_force_inexact_reg;
          class_force_bsun := exc_event_force_bsun_reg;
        end if;
        a_zero := fp80_is_zero(class_opa);
        b_zero := fp80_is_zero(class_opb);
        a_inf := fp80_is_inf(class_opa);
        b_inf := fp80_is_inf(class_opb);
        a_nan := fp80_is_nan(class_opa);
        b_nan := fp80_is_nan(class_opb);
        res_zero := fp80_is_zero(class_result);
        res_inf := fp80_is_inf(class_result);
        res_nan := fp80_is_nan(class_result);
        res_subnormal := fp80_exp_is_zero_nonzero_mant(class_result);

        if exc_policy.invalid_on_nan_inputs and (a_nan or b_nan) then
          exc_flags(FPSR_EXC_INVALID) := '1';
        end if;

        if exc_policy.invalid_on_nan_result and res_nan then
          exc_flags(FPSR_EXC_INVALID) := '1';
        end if;

        if exc_policy.divzero_on_zero_divisor_nonzero_dividend then
          if b_zero and not a_zero then
            exc_flags(FPSR_EXC_DIVZERO) := '1';
          end if;
        end if;

        -- Transcendental singularity: log(0) = -infinity is DZ, not OVERFLOW.
        if exc_policy.divzero_on_zero_input and a_zero then
          exc_flags(FPSR_EXC_DIVZERO) := '1';
        end if;

        -- Trig/divrem unit explicit DZ flag (FLOGNP1(-1), FATANH(±1), etc.)
        if class_divzero = '1' then
          exc_flags(FPSR_EXC_DIVZERO) := '1';
        end if;

        if exc_policy.invalid_zero_over_zero and a_zero and b_zero then
          exc_flags(FPSR_EXC_INVALID) := '1';
        end if;

        if exc_policy.invalid_inf_over_inf and a_inf and b_inf then
          exc_flags(FPSR_EXC_INVALID) := '1';
        end if;

        if exc_policy.invalid_divisor_zero then
          if b_zero then
            exc_flags(FPSR_EXC_INVALID) := '1';
          end if;
        end if;

        if exc_policy.classify_overflow_underflow then
          if class_force_overflow = '1' then
            exc_flags(FPSR_EXC_OVERFLOW) := '1';
          end if;

          if class_force_underflow = '1' then
            exc_flags(FPSR_EXC_UNDERFLOW) := '1';
          end if;

          if res_inf and not a_inf and not b_inf and not res_nan and
             exc_flags(FPSR_EXC_DIVZERO) = '0' then
            exc_flags(FPSR_EXC_OVERFLOW) := '1';
          end if;

          if (res_zero or res_subnormal) and not a_zero and not b_zero and not res_nan and not res_inf then
            exc_flags(FPSR_EXC_UNDERFLOW) := '1';
          end if;

          if exc_flags(FPSR_EXC_OVERFLOW) = '1' or exc_flags(FPSR_EXC_UNDERFLOW) = '1'
             or class_force_inexact = '1' then
            exc_flags(FPSR_EXC_INEXACT) := '1';
          end if;
        end if;

        if class_force_bsun = '1' then
          exc_flags(FPSR_EXC_BSUN) := '1';
        end if;

        if exc_policy.update_exc_status then
          -- Datasheet Section 2.3.3: EXC byte is cleared then set per operation.
          exc_status_byte := (others => '0');
          exc_status_byte := exc_flags;
          fpsr_reg(FPSR_EXC_MSB downto FPSR_EXC_LSB) <= exc_status_byte;
        end if;

        if exc_policy.update_accumulated_exc then
          -- Datasheet AEXC combination rules:
          -- AEXC(UNFL) |= UNFL AND INEX; AEXC(INEX) |= INEX OR OVFL.
          aexc_combined := (others => '0');
          aexc_combined(FPSR_EXC_INVALID)   := exc_flags(FPSR_EXC_INVALID);
          aexc_combined(FPSR_EXC_OVERFLOW)  := exc_flags(FPSR_EXC_OVERFLOW);
          aexc_combined(FPSR_EXC_UNDERFLOW) := exc_flags(FPSR_EXC_UNDERFLOW) and exc_flags(FPSR_EXC_INEXACT);
          aexc_combined(FPSR_EXC_DIVZERO)   := exc_flags(FPSR_EXC_DIVZERO);
          aexc_combined(FPSR_EXC_INEXACT)   := exc_flags(FPSR_EXC_INEXACT) or exc_flags(FPSR_EXC_OVERFLOW);
          aexc_combined(FPSR_EXC_BSUN)      := exc_flags(FPSR_EXC_BSUN);
          accrued_exc_byte := fpsr_reg(FPSR_AEXC_MSB downto FPSR_AEXC_LSB);
          accrued_exc_byte := accrued_exc_byte or aexc_combined;
          fpsr_reg(FPSR_AEXC_MSB downto FPSR_AEXC_LSB) <= accrued_exc_byte;
        end if;

        if exc_policy.update_cc_from_compare then
          cc_bits := fpsr_cc_from_compare(class_opa, class_opb);
          fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN) <= cc_bits;
        elsif exc_policy.update_cc_from_result then
          if exc_flags(FPSR_EXC_INVALID) = '1' then
            cc_bits := (others => '0');
            cc_bits(0) := '1';
          else
            cc_bits := fpsr_cc_from_result(class_result);
          end if;
          fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN) <= cc_bits;
        end if;

        if exc_policy.capture_fpiar_on_exception and exc_flags /= x"00" then
          fpiar_reg <= fpiar_issue_snapshot_reg;
        end if;

        if valid = '1' and quotient_valid = '1' then
          fpsr_reg(FPSR_QUOT_MSB downto FPSR_QUOT_LSB) <= quotient_byte;
        end if;
      end if;

      if frame_busy_reg = '1' then
        if frame_remaining_reg = 0 then
          frame_busy_reg <= '0';
          if frame_restore_pending_reg = '1' then
            fpcr_reg <= frame_mem_reg(0);
            fpsr_reg <= frame_mem_reg(1);
            frame_restore_pending_reg <= '0';
            frame_valid_reg <= '0';
          else
            frame_valid_reg <= '1';
          end if;
        else
          frame_remaining_reg <= frame_remaining_reg - 1;
        end if;
      end if;

      if frame_start_save_reg = '1' and frame_busy_reg = '0' and micro_active_reg = '0' then
        status_frame_word := (others => '0');
        status_frame_word(0) := status_valid_reg;
        status_frame_word(1) := status_busy_reg;
        status_frame_word(2) := frame_valid_reg;
        status_frame_word(3) := frame_busy_reg;
        frame_mem_reg(0) <= fpcr_reg;
        frame_mem_reg(1) <= fpsr_reg;
        frame_mem_reg(2) <= status_frame_word;
        frame_mem_reg(3) <= (others => '0');
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_valid_reg <= '0';
        frame_restore_pending_reg <= '0';
      elsif frame_start_restore_reg = '1' and frame_busy_reg = '0' and micro_active_reg = '0' then
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_restore_pending_reg <= '1';
      end if;
    end if;
  end process;

  -- Operation scheduler and MOVE/MOVEM datapath handling.
  -- For ALU ops it starts the ALU and tracks modeled microcycle latency.
  alu_control_proc : process(clk, reset_n)
    variable total_cycles : natural := 0;
    variable src_idx : natural range 0 to 7 := 0;
    variable dst_idx : natural range 0 to 7 := 0;
    variable move_result : fp80_t := (others => '0');
    variable mode : move_cfg_mode_t := MOVE_CFG_MODE_REG_TO_REG;
    variable mem_fmt : std_logic_vector(1 downto 0) := (others => '0');
    variable ctrl_sel : std_logic_vector(1 downto 0) := (others => '0');
    variable mask : std_logic_vector(7 downto 0) := (others => '0');
    variable first_idx : integer := -1;
    variable mask_bit_idx : integer range 0 to 7 := 0;
    variable single_bits : std_logic_vector(31 downto 0) := (others => '0');
    variable double_bits : std_logic_vector(63 downto 0) := (others => '0');
    variable ctrl_value : std_logic_vector(31 downto 0) := (others => '0');
    variable int_value : integer := 0;
    variable packed_k : integer := 0;
    variable move_cfg : move_cfg_t := move_cfg_default;
    variable move_exc_result : fp80_t := (others => '0');
    variable move_exc_opa : fp80_t := (others => '0');
    variable move_exc_opb : fp80_t := FP80_CLASSIFY_ONE;
    variable move_exc_enable : std_logic := '0';
    variable move_exc_force_overflow : std_logic := '0';
    variable move_exc_force_underflow : std_logic := '0';
    variable move_exc_force_inexact : std_logic := '0';
    variable move_src_abs : fp80_t := (others => '0');
    variable single_max_abs : fp80_t := (others => '0');
    variable double_max_abs : fp80_t := (others => '0');
    variable prog_result : std_logic_vector(31 downto 0) := (others => '0');
    variable cir_response_word : std_logic_vector(31 downto 0) := (others => '0');
    variable cc_field : std_logic_vector(3 downto 0) := (others => '0');
    variable cond_true : std_logic := '0';
    variable signaling_cond : boolean := false;
    variable bsun_event : std_logic := '0';
    variable trap_requested : std_logic := '0';
    variable branch_taken : std_logic := '0';
    variable decrement_taken : std_logic := '0';
    variable counter_expired : std_logic := '0';
    variable fdb_count_before : unsigned(15 downto 0) := (others => '0');
    variable fdb_count_after : unsigned(15 downto 0) := (others => '0');
  begin
    if reset_n = '0' then
      result_lo_reg <= (others => '0');
      result_hi_reg <= (others => '0');
      result_ex_reg <= (others => '0');
      aux_result_lo_reg <= (others => '0');
      aux_result_hi_reg <= (others => '0');
      aux_result_ex_reg <= (others => '0');
      op_start_reg <= '0';
      micro_active_reg <= '0';
      micro_remaining_reg <= 0;
      micro_total_reg <= (others => '0');
      result_ready_reg <= '0';
      last_op_sel_reg <= FPU_OP_NOP;
      fpiar_issue_snapshot_reg <= (others => '0');
      fp_reg_file_reg <= (others => (others => '0'));
      fp_movem_shadow_reg <= (others => (others => '0'));
      ctrl_move_write_req_reg <= '0';
      ctrl_move_sel_reg <= (others => '0');
      ctrl_move_data_reg <= (others => '0');
      cir_response_reg <= (others => '0');
      cir_response_pending_reg <= '0';
      cir_trap_pending_reg <= '0';
      cir_protocol_violation_reg <= '0';
      exc_event_valid_reg <= '0';
      exc_event_result_reg <= (others => '0');
      exc_event_opa_reg <= (others => '0');
      exc_event_opb_reg <= FP80_CLASSIFY_ONE;
      exc_event_divzero_reg <= '0';
      exc_event_force_overflow_reg <= '0';
      exc_event_force_underflow_reg <= '0';
      exc_event_force_bsun_reg <= '0';
    elsif rising_edge(clk) then
      op_start_reg <= '0';
      ctrl_move_write_req_reg <= '0';
      exc_event_valid_reg <= '0';
      exc_event_divzero_reg <= '0';
      exc_event_force_overflow_reg <= '0';
      exc_event_force_underflow_reg <= '0';
      exc_event_force_bsun_reg <= '0';

      if bus_read = '1' and addr = ADDR_CIR_RESPONSE then
        cir_response_pending_reg <= '0';
        cir_trap_pending_reg <= '0';
        cir_protocol_violation_reg <= '0';
      end if;

      if bus_write = '1' and addr = ADDR_OPSEL and
         conditional_prog_op_write = '1' and
         cir_response_pending_reg = '1' then
        cir_protocol_violation_reg <= '1';
      end if;

      if op_issue_pulse = '1' then
        result_ready_reg <= '0';
        last_op_sel_reg <= op_sel_write_decoded;
        fpiar_issue_snapshot_reg <= fpiar_reg;
        micro_active_reg <= '1';
        total_cycles := op_cycle_count(
          op_sel_write_decoded,
          src_kind_reg,
          ea_mode_reg,
          cycle_case_reg,
          mc68020_src_reg = '1',
          mc68020_dst_reg = '1',
          packed_dynamic_k_reg = '1'
        );
        micro_total_reg <= std_logic_vector(to_unsigned(total_cycles, 32));
        if total_cycles = 0 then
          micro_remaining_reg <= 0;
        else
          micro_remaining_reg <= total_cycles - 1;
        end if;

        -- Dispatch uses operation classes to keep execution paths scalable.
        case op_class_write_decoded is
          when OP_CLASS_ARITH =>
            op_start_reg <= '1';
          when OP_CLASS_MOVE =>
            if op_sel_write_decoded = FPU_OP_MOVE then
              move_cfg := move_cfg_decoded_reg;
              src_idx := move_cfg.src_idx;
              mem_fmt := move_cfg.mem_fmt;
              mode := move_cfg.mode;
              dst_idx := move_cfg.dst_idx;
              ctrl_sel := move_cfg.ctrl_sel;
              move_result := (others => '0');
              move_exc_result := (others => '0');
              move_exc_opa := (others => '0');
              move_exc_opb := FP80_CLASSIFY_ONE;
              move_exc_enable := '0';
              move_exc_force_overflow := '0';
              move_exc_force_underflow := '0';
              move_exc_force_inexact := '0';

              if move_cfg.fmovecr_enable = '1' then
                move_result := fmovecr_constant(operand_reg(0)(6 downto 0));
                move_exc_enable := '1';
                move_exc_result := move_result;
                move_exc_opa := move_result;
                fp_reg_file_reg(dst_idx) <= move_result;
              else
                case mode is
                  when MOVE_CFG_MODE_REG_TO_REG =>
                    move_result := fp_reg_file_reg(src_idx);
                    move_exc_enable := '1';
                    move_exc_result := move_result;
                    move_exc_opa := move_result;
                    fp_reg_file_reg(dst_idx) <= move_result;
                  when MOVE_CFG_MODE_MEM_TO_REG =>
                    if move_cfg.mem_to_reg_integer = '1' then
                      case mem_fmt is
                        when "00" =>
                          int_value := signed8_to_integer(operand_reg(0)(7 downto 0));
                        when "01" =>
                          int_value := signed16_to_integer(operand_reg(0)(15 downto 0));
                        when others =>
                          int_value := signed32_to_integer(operand_reg(0)(31 downto 0));
                      end case;
                      move_result := fp80_from_int(int_value);
                      move_exc_enable := '1';
                      move_exc_result := move_result;
                      move_exc_opa := move_result;
                    else
                      case mem_fmt is
                        when "01" =>
                          move_result := fp80_from_single(operand_reg(0)(31 downto 0));
                          move_exc_enable := '1';
                          move_exc_result := move_result;
                          move_exc_opa := move_result;
                        when "10" =>
                          move_result := fp80_from_double(operand_reg(0)(63 downto 0));
                          move_exc_enable := '1';
                          move_exc_result := move_result;
                          move_exc_opa := move_result;
                        when others =>
                          move_result := operand_reg(0);
                          move_exc_enable := '1';
                          move_exc_result := move_result;
                          move_exc_opa := move_result;
                      end case;
                    end if;
                    fp_reg_file_reg(dst_idx) <= move_result;
                  when MOVE_CFG_MODE_REG_TO_MEM =>
                    move_result := fp_reg_file_reg(src_idx);
                    move_exc_opa := move_result;
                    if move_cfg.reg_to_mem_packed = '1' then
                      if move_cfg.packed_k_from_opa = '1' then
                        packed_k := signed8_to_integer(operand_reg(0)(7 downto 0));
                      else
                        packed_k := signed8_to_integer(operand_reg(1)(7 downto 0));
                      end if;
                      move_result := apply_packed_k_factor(move_result, packed_k);
                      move_exc_enable := '1';
                      move_exc_result := move_result;
                      result_lo_reg <= move_result(FP80_RESULT_LO_WIDTH-1 downto 0);
                      result_hi_reg <= move_result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
                      result_ex_reg <= move_result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
                    else
                      case mem_fmt is
                        when "01" =>
                          single_bits := fp80_to_single(move_result, round_mode);
                          move_exc_enable := '1';
                          move_exc_result := fp80_from_single(single_bits);
                          if not fp80_is_nan(move_result) and not fp80_is_inf(move_result) and not fp80_is_zero(move_result) then
                            if move_exc_result /= move_result then
                              move_exc_force_inexact := '1';
                            end if;
                            if single_bits(30 downto 23) = x"00" then
                              move_exc_force_underflow := '1';
                            end if;
                            move_src_abs := move_result;
                            move_src_abs(FP_WIDTH-1) := '0';
                            single_max_abs := fp80_from_single(x"7F7FFFFF");
                            if compare_fp80_ordered(move_src_abs, single_max_abs) > 0 then
                              move_exc_force_overflow := '1';
                            end if;
                          end if;
                          result_lo_reg <= single_bits;
                          result_hi_reg <= (others => '0');
                          result_ex_reg <= (others => '0');
                        when "10" =>
                          double_bits := fp80_to_double(move_result, round_mode);
                          move_exc_enable := '1';
                          move_exc_result := fp80_from_double(double_bits);
                          if not fp80_is_nan(move_result) and not fp80_is_inf(move_result) and not fp80_is_zero(move_result) then
                            if move_exc_result /= move_result then
                              move_exc_force_inexact := '1';
                            end if;
                            if double_bits(62 downto 52) = std_logic_vector(to_unsigned(0, 11)) then
                              move_exc_force_underflow := '1';
                            end if;
                            move_src_abs := move_result;
                            move_src_abs(FP_WIDTH-1) := '0';
                            double_max_abs := fp80_from_double(x"7FEFFFFFFFFFFFFF");
                            if compare_fp80_ordered(move_src_abs, double_max_abs) > 0 then
                              move_exc_force_overflow := '1';
                            end if;
                          end if;
                          result_lo_reg <= double_bits(31 downto 0);
                          result_hi_reg <= double_bits(63 downto 32);
                          result_ex_reg <= (others => '0');
                        when others =>
                          result_lo_reg <= move_result(FP80_RESULT_LO_WIDTH-1 downto 0);
                          result_hi_reg <= move_result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
                          result_ex_reg <= move_result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
                      end case;
                    end if;
                  when MOVE_CFG_MODE_CONTROL =>
                    if move_cfg.ctrl_to_reg = '1' then
                      case ctrl_sel is
                        when "00" => ctrl_value := fpcr_reg;
                        when "01" => ctrl_value := fpsr_reg;
                        when others => ctrl_value := fpiar_reg;
                      end case;
                      move_result := (others => '0');
                      move_result(31 downto 0) := ctrl_value;
                      fp_reg_file_reg(dst_idx) <= move_result;
                    else
                      ctrl_move_write_req_reg <= '1';
                      ctrl_move_sel_reg <= ctrl_sel;
                      ctrl_move_data_reg <= fp_reg_file_reg(src_idx)(31 downto 0);
                      move_result := fp_reg_file_reg(src_idx);
                    end if;
                end case;
              end if;

              if mode /= MOVE_CFG_MODE_REG_TO_MEM then
                result_lo_reg <= move_result(FP80_RESULT_LO_WIDTH-1 downto 0);
                result_hi_reg <= move_result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
                result_ex_reg <= move_result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
              end if;
              if move_exc_enable = '1' then
                exc_event_valid_reg <= '1';
                exc_event_result_reg <= move_exc_result;
                exc_event_opa_reg <= move_exc_opa;
                exc_event_opb_reg <= move_exc_opb;
                exc_event_force_overflow_reg <= move_exc_force_overflow;
                exc_event_force_underflow_reg <= move_exc_force_underflow;
                exc_event_force_inexact_reg <= move_exc_force_inexact;
              end if;
              result_ready_reg <= '1';
            elsif op_sel_write_decoded = FPU_OP_MOVEM then
              move_cfg := move_cfg_decoded_reg;
              if move_cfg.movem_mask_from_dn = '1' then
                mask := operand_reg(0)(7 downto 0);
              else
                mask := move_cfg.movem_mask;
              end if;
              first_idx := -1;
              for idx in 0 to 7 loop
                if move_cfg.movem_predec_order = '1' then
                  mask_bit_idx := idx;
                else
                  mask_bit_idx := 7 - idx;
                end if;
                if mask(mask_bit_idx) = '1' then
                  if first_idx = -1 then
                    first_idx := idx;
                  end if;
                  if move_cfg.movem_dir_to_reg = '1' then
                    fp_reg_file_reg(idx) <= fp_movem_shadow_reg(idx);
                  else
                    fp_movem_shadow_reg(idx) <= fp_reg_file_reg(idx);
                  end if;
                end if;
              end loop;

              move_result := (others => '0');
              if first_idx >= 0 then
                if move_cfg.movem_dir_to_reg = '1' then
                  move_result := fp_movem_shadow_reg(first_idx);
                else
                  move_result := fp_reg_file_reg(first_idx);
                end if;
              end if;
              result_lo_reg <= move_result(FP80_RESULT_LO_WIDTH-1 downto 0);
              result_hi_reg <= move_result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
              result_ex_reg <= move_result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
              result_ready_reg <= '1';
            else
              result_ready_reg <= '1';
            end if;
          when OP_CLASS_PROG_CTRL =>
            -- Program-control opcodes complete without ALU launch. The
            -- condition dialog response is published through CIR_RESPONSE.
            result_lo_reg <= (others => '0');
            result_hi_reg <= (others => '0');
            result_ex_reg <= (others => '0');
            prog_result := (others => '0');
            cir_response_word := (others => '0');
            branch_taken := '0';
            decrement_taken := '0';
            counter_expired := '0';
            bsun_event := '0';
            trap_requested := '0';

            if op_sel_write_decoded = FPU_OP_FSCC then
              cc_field := fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN);
              signaling_cond := is_signaling_fcc_condition(operand_reg(0)(5 downto 0));
              cond_true := eval_fcc_condition(operand_reg(0)(5 downto 0), cc_field);
              if signaling_cond and cc_field(0) = '1' then
                bsun_event := '1';
                cond_true := '0';
              end if;
              if cond_true = '1' and bsun_event = '0' then
                prog_result(7 downto 0) := x"FF";
              end if;
              cir_response_word(0) := cond_true;
              cir_response_word(4) := bsun_event;
            elsif op_sel_write_decoded = FPU_OP_FBCC then
              cc_field := fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN);
              signaling_cond := is_signaling_fcc_condition(operand_reg(0)(5 downto 0));
              cond_true := eval_fcc_condition(operand_reg(0)(5 downto 0), cc_field);
              if signaling_cond and cc_field(0) = '1' then
                bsun_event := '1';
                cond_true := '0';
              end if;
              branch_taken := cond_true;
              cir_response_word(0) := cond_true;
              cir_response_word(1) := branch_taken;
              cir_response_word(4) := bsun_event;
              prog_result := cir_response_word;
            elsif op_sel_write_decoded = FPU_OP_FDBCC then
              cc_field := fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN);
              signaling_cond := is_signaling_fcc_condition(operand_reg(0)(5 downto 0));
              cond_true := eval_fcc_condition(operand_reg(0)(5 downto 0), cc_field);
              if signaling_cond and cc_field(0) = '1' then
                bsun_event := '1';
                cond_true := '0';
              end if;
              fdb_count_before := unsigned(operand_reg(1)(15 downto 0));
              fdb_count_after := fdb_count_before;

              if cond_true = '0' and bsun_event = '0' then
                decrement_taken := '1';
                fdb_count_after := fdb_count_before - 1;
                if fdb_count_after /= to_unsigned(16#FFFF#, 16) then
                  branch_taken := '1';
                else
                  branch_taken := '0';
                  counter_expired := '1';
                end if;
              end if;

              cir_response_word(0) := cond_true;
              cir_response_word(1) := branch_taken;
              cir_response_word(2) := decrement_taken;
              cir_response_word(3) := counter_expired;
              cir_response_word(4) := bsun_event;
              cir_response_word(31 downto 16) := std_logic_vector(fdb_count_after);
              prog_result := cir_response_word;
            end if;

            if op_sel_write_decoded = FPU_OP_FSCC or
               op_sel_write_decoded = FPU_OP_FBCC or
               op_sel_write_decoded = FPU_OP_FDBCC then
              if bsun_event = '1' and fpcr_reg(FPCR_EXC_EN_BSUN) = '1' then
                trap_requested := '1';
              end if;
              cir_response_word(5) := trap_requested;
              if op_sel_write_decoded /= FPU_OP_FSCC then
                prog_result := cir_response_word;
              end if;

              -- Route conditional-dialog exceptions through the shared FPSR/FPIAR
              -- classification path (BSUN for signaling conditions on unordered CC).
              exc_event_valid_reg <= '1';
              exc_event_result_reg <= (others => '0');
              exc_event_opa_reg <= (others => '0');
              exc_event_opb_reg <= FP80_CLASSIFY_ONE;
              exc_event_force_bsun_reg <= bsun_event;
              cir_response_pending_reg <= '1';
              cir_trap_pending_reg <= trap_requested;
              cir_protocol_violation_reg <= '0';
            end if;

            result_lo_reg <= prog_result;
            cir_response_reg <= cir_response_word;
            result_ready_reg <= '1';
          when OP_CLASS_SYS_CTRL =>
            -- System-control opcodes are class-routed here for future FSAVE/FRESTORE plumbing.
            result_ready_reg <= '1';
          when others =>
            result_ready_reg <= '1';
        end case;
      end if;

      if valid = '1' then
        result_lo_reg <= result(FP80_RESULT_LO_WIDTH-1 downto 0);
        result_hi_reg <= result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
        result_ex_reg <= result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
        if aux_valid = '1' then
          aux_result_lo_reg <= aux_result(FP80_RESULT_LO_WIDTH-1 downto 0);
          aux_result_hi_reg <= aux_result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
          aux_result_ex_reg <= aux_result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
        end if;
        result_ready_reg <= '1';
      end if;

      if micro_active_reg = '1' then
        if micro_remaining_reg = 0 then
          if result_ready_reg = '1' then
            micro_active_reg <= '0';
          end if;
        else
          micro_remaining_reg <= micro_remaining_reg - 1;
        end if;
      end if;
    end if;
  end process;

  -- STATUS register mirrors completion/busy state for host polling.
  status_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      status_valid_reg <= '0';
      status_busy_reg <= '0';
      status_frame_valid_reg <= '0';
      status_frame_busy_reg <= '0';
    elsif rising_edge(clk) then
      if op_issue_pulse = '1' then
        status_valid_reg <= '0';
      elsif micro_active_reg = '1' and micro_remaining_reg = 0 and result_ready_reg = '1' then
        status_valid_reg <= '1';
      end if;

      status_busy_reg <= micro_active_reg or frame_busy_reg;
      status_frame_valid_reg <= frame_valid_reg;
      status_frame_busy_reg <= frame_busy_reg;
    end if;
  end process;

  -- Read-data mux for memory-mapped register space.
  process(
    addr,
    bus_read,
    result_lo_reg,
    result_hi_reg,
    result_ex_reg,
    aux_result_lo_reg,
    aux_result_hi_reg,
    aux_result_ex_reg,
    status_valid_reg,
    status_busy_reg,
    status_frame_valid_reg,
    status_frame_busy_reg,
    fpcr_reg,
    fpsr_reg,
    fpiar_reg,
    move_cfg_reg,
    src_kind_reg,
    ea_mode_reg,
    cycle_case_reg,
    mc68020_src_reg,
    mc68020_dst_reg,
    packed_dynamic_k_reg,
    frame_mem_reg,
    micro_total_reg,
    cir_response_reg,
    cir_response_pending_reg,
    cir_trap_pending_reg,
    cir_protocol_violation_reg
  )
    variable cfg0 : std_logic_vector(31 downto 0);
    variable cfg1 : std_logic_vector(31 downto 0);
  begin
    cfg0 := (others => '0');
    cfg1 := (others => '0');
    cfg0(2 downto 0) := std_logic_vector(to_unsigned(fpu_src_kind_t'pos(src_kind_reg), 3));
    cfg0(7 downto 3) := std_logic_vector(to_unsigned(ea_mode_t'pos(ea_mode_reg), 5));
    cfg1(1 downto 0) := std_logic_vector(to_unsigned(ea_cycle_case_t'pos(cycle_case_reg), 2));
    cfg1(2) := mc68020_src_reg;
    cfg1(3) := mc68020_dst_reg;
    cfg1(4) := packed_dynamic_k_reg;

    d_out_comb <= (others => '0');
    if bus_read = '1' then
      case addr is
        when ADDR_RES_L => d_out_comb <= result_lo_reg;
        when ADDR_RES_H => d_out_comb <= result_hi_reg;
        when ADDR_RES_E => d_out_comb(FP80_RESULT_EX_WIDTH-1 downto 0) <= result_ex_reg;
        when ADDR_AUX_RES_L => d_out_comb <= aux_result_lo_reg;
        when ADDR_AUX_RES_H => d_out_comb <= aux_result_hi_reg;
        when ADDR_AUX_RES_E => d_out_comb(FP80_RESULT_EX_WIDTH-1 downto 0) <= aux_result_ex_reg;
        when ADDR_STATUS =>
          d_out_comb(0) <= status_valid_reg;
          d_out_comb(1) <= status_busy_reg;
          d_out_comb(2) <= status_frame_valid_reg;
          d_out_comb(3) <= status_frame_busy_reg;
          d_out_comb(4) <= cir_response_pending_reg;
          d_out_comb(5) <= cir_protocol_violation_reg;
          d_out_comb(6) <= cir_trap_pending_reg;
        when ADDR_FPCR =>
          d_out_comb <= fpcr_reg;
        when ADDR_FPSR =>
          d_out_comb <= fpsr_reg;
        when ADDR_FPIAR =>
          d_out_comb <= fpiar_reg;
        when ADDR_MOVE_CFG =>
          d_out_comb <= move_cfg_reg;
        when ADDR_CYCLE_CFG0 =>
          d_out_comb <= cfg0;
        when ADDR_CYCLE_CFG1 =>
          d_out_comb <= cfg1;
        when ADDR_CYCLE_TOTAL =>
          d_out_comb <= micro_total_reg;
        when ADDR_CIR_RESPONSE =>
          d_out_comb <= cir_response_reg;
        when ADDR_FRAME_W0 =>
          d_out_comb <= frame_mem_reg(0);
        when ADDR_FRAME_W1 =>
          d_out_comb <= frame_mem_reg(1);
        when ADDR_FRAME_W2 =>
          d_out_comb <= frame_mem_reg(2);
        when ADDR_FRAME_W3 =>
          d_out_comb <= frame_mem_reg(3);
        when others => d_out_comb <= (others => '0');
      end case;
    end if;
  end process;

  -- DSACK timing/handshake state machine.
  process(clk, reset_n)
    variable size_code : std_logic_vector(1 downto 0);
    variable dsack_wait : boolean;
    variable assert_cycles : natural;
  begin
    if reset_n = '0' then
      dsack_state  <= DSACK_IDLE;
      dsack_count  <= 0;
      dsack_active <= '0';
      latched_size <= (others => '0');
      latched_a4   <= '0';
      d_out_reg    <= (others => '0');
    elsif rising_edge(clk) then
      if sync_read = '1' and start_access = '1' then
        d_out_reg <= d_out_comb;
      end if;

      case dsack_state is
        when DSACK_IDLE =>
          dsack_active <= '0';
          if start_access = '1' then
            size_code := not size_n;
            latched_size <= size_code;
            latched_a4   <= a_in(4);
            dsack_wait := (size_code = "11");
            if bus_read = '1' then
              assert_cycles := DSACK_ASSERT_CYCLES_READ;
            else
              assert_cycles := DSACK_ASSERT_CYCLES_WRITE;
            end if;
            if dsack_wait then
              dsack_state <= DSACK_IDLE;
            elsif assert_cycles = 0 then
              dsack_active <= '1';
              dsack_state <= DSACK_ASSERTED;
            else
              dsack_count <= assert_cycles - 1;
              dsack_state <= DSACK_WAIT_ASSERT;
            end if;
          end if;
        when DSACK_WAIT_ASSERT =>
          if start_access = '0' then
            dsack_state <= DSACK_IDLE;
            dsack_active <= '0';
          elsif dsack_count = 0 then
            dsack_active <= '1';
            dsack_state <= DSACK_ASSERTED;
          else
            dsack_count <= dsack_count - 1;
          end if;
        when DSACK_ASSERTED =>
          dsack_active <= '1';
          if start_access = '0' then
            dsack_active <= '0';
            dsack_state <= DSACK_IDLE;
          end if;
      end case;
    end if;
  end process;

  -- DSACK line encoding from transfer size (and A4 for longword lane select).
  process(latched_size, latched_a4, dsack_active)
  begin
    dsack0_i <= '1';
    dsack1_i <= '1';
    if dsack_active = '1' then
      case latched_size is
        when "00" =>
          if latched_a4 = '1' then
            dsack1_i <= '0';
            dsack0_i <= '0';
          else
            dsack1_i <= '0';
            dsack0_i <= '1';
          end if;
        when "01" =>
          dsack1_i <= '0';
          dsack0_i <= '1';
        when "10" =>
          dsack1_i <= '1';
          dsack0_i <= '0';
        when others =>
          dsack1_i <= '1';
          dsack0_i <= '1';
      end case;
    end if;
  end process;

  -- CIR reads use a registered data path; other reads are combinational.
  d_out <= d_out_reg when sync_read = '1' else d_out_comb;
  dsack0_n <= dsack0_i;
  dsack1_n <= dsack1_i;
  sense_drive <= '0' when status_busy_reg = '1' else '1';
  sense_n  <= sense_drive;
end architecture rtl;
