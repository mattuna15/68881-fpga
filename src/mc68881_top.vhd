library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

-- MC68881 command word note:
-- bits[12:10] are dual-use per Motorola encoding.
--   bit14=0 → memory source → bits[12:10] = source data format
--   bit14=1 → register source → bits[12:10] = FP register index

entity mc68881_top is
  generic (
    -- `true`: full packed-decimal conversion path.
    -- `false`: synthesis-safe packed-decimal fallback for debug/triage builds.
    packed_decimal_full_g : boolean := true
  );
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
  type reg_hi16_array_t is array (0 to 1) of std_logic_vector(15 downto 0);

  signal op_sel_reg    : fpu_op_t := FPU_OP_NOP;
  signal operand_reg   : reg_array_t := (others => (others => '0'));
  signal operand_hi16_reg : reg_hi16_array_t := (others => (others => '0'));
  signal result    : fp80_t := (others => '0');
  signal aux_result : fp80_t := (others => '0');
  signal result_lo_reg : std_logic_vector(FP80_RESULT_LO_WIDTH-1 downto 0) := (others => '0');
  signal result_hi_reg : std_logic_vector(FP80_RESULT_HI_WIDTH-1 downto 0) := (others => '0');
  signal result_ex_reg : std_logic_vector(FP80_RESULT_EX_WIDTH-1 downto 0) := (others => '0');
  signal result_ex_hi_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal aux_result_lo_reg : std_logic_vector(FP80_RESULT_LO_WIDTH-1 downto 0) := (others => '0');
  signal aux_result_hi_reg : std_logic_vector(FP80_RESULT_HI_WIDTH-1 downto 0) := (others => '0');
  signal aux_result_ex_reg : std_logic_vector(FP80_RESULT_EX_WIDTH-1 downto 0) := (others => '0');
  signal aux_result_ex_hi_reg : std_logic_vector(15 downto 0) := (others => '0');
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

  -- Shared format converters (de-duplicated from FMOVE + CIR paths)
  signal conv_fp_src : fp80_t := (others => '0');
  signal conv_single_out : std_logic_vector(31 downto 0);
  signal conv_double_out : std_logic_vector(63 downto 0);
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
  constant ADDR_CIR_RESTORE : unsigned(4 downto 0) := to_unsigned(28, 5);

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
  signal fpu_initialized_reg : std_logic := '0';

  signal sys_ctrl_save_req_reg    : std_logic := '0';
  signal sys_ctrl_restore_req_reg : std_logic := '0';
  signal frame_op_waiting_reg     : std_logic := '0';

  signal op_sel_write_decoded : fpu_op_t := FPU_OP_NOP;
  signal op_class_write_decoded : fpu_op_class_t := OP_CLASS_NONE;
  signal conditional_prog_op_write : std_logic := '0';
  signal op_issue_pulse       : std_logic := '0';
  signal opsel_write_prev_reg : std_logic := '0';
  signal ctrl_move_write_req_reg : std_logic := '0';
  signal ctrl_move_sel_reg : std_logic_vector(1 downto 0) := (others => '0');
  signal ctrl_move_data_reg : std_logic_vector(31 downto 0) := (others => '0');
  -- CIR_RESPONSE register bit layout (conditional dialog response word):
  --   Bit  0 : cond_true       - condition evaluated true
  --   Bit  1 : branch_taken    - branch decision (FBcc/FDBcc)
  --   Bit  2 : decrement_taken - counter decremented (FDBcc only)
  --   Bit  3 : counter_expired - counter reached -1 (FDBcc only)
  --   Bit  4 : bsun_event      - BSUN raised (signaling condition + unordered)
  --   Bit  5 : trap_requested  - BSUN trap enabled via FPCR
  --   Bits 15:6  : reserved
  --   Bits 31:16 : updated loop counter (FDBcc only)
  signal cir_response_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal cir_response_pending_reg : std_logic := '0';
  signal cir_trap_pending_reg : std_logic := '0';
  signal cir_protocol_violation_reg : std_logic := '0';

  -- CIR dialog state machine signals (Section 7 coprocessor interface).
  signal cir_state_reg         : cir_dialog_state_t := CIR_IDLE;
  signal cir_opword_reg        : std_logic_vector(15 downto 0) := (others => '0');
  signal cir_command_reg       : std_logic_vector(15 downto 0) := (others => '0');
  signal cir_condition_reg     : std_logic_vector(5 downto 0) := (others => '0');
  signal cir_instr_type        : std_logic_vector(2 downto 0) := (others => '0');
  signal cir_src_fmt           : std_logic_vector(2 downto 0) := (others => '0');
  signal cir_dst_reg_idx       : natural range 0 to 7 := 0;
  signal cir_src_reg_idx       : natural range 0 to 7 := 0;
  signal cir_reg_to_reg        : std_logic := '0';
  signal cir_direction         : std_logic := '0';  -- Bit 13: 0=mem→reg, 1=reg→mem
  signal cir_xfer_word_idx     : natural range 0 to 44 := 0;
  signal cir_xfer_word_count   : natural range 0 to 45 := 0;
  signal cir_response_prim     : std_logic_vector(15 downto 0) := CIR_PRIM_NULL;
  signal cir_opword_written    : std_logic := '0';
  signal cir_command_written   : std_logic := '0';
  signal cir_condition_written : std_logic := '0';
  signal cir_exc_vector        : std_logic_vector(9 downto 0) := (others => '0');
  signal cir_control_ack       : std_logic := '0';
  signal frame_format_word_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal cir_operand_read_data : std_logic_vector(31 downto 0) := (others => '0');
  signal cir_regselect_word    : std_logic_vector(15 downto 0) := (others => '0');
  signal cir_operand_addr_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal cir_instaddr_reg      : std_logic_vector(31 downto 0) := (others => '0');

  -- CIR ALU launch handshake signals.
  signal cir_launch_alu        : std_logic := '0';           -- One-cycle pulse from cir_dialog_proc
  signal cir_flags_consumed    : std_logic := '0';           -- One-cycle pulse: dialog_proc consumed written flags
  signal cir_decoded_op        : fpu_op_t := FPU_OP_NOP;     -- Combinational decode of command word
  signal cir_arith_active_reg  : std_logic := '0';           -- Tracks CIR-launched arith op in alu_control_proc
  signal cir_move_pending_reg  : std_logic := '0';           -- One-cycle deferred FMOVE copy

  -- CIR operand staging for memory-source/destination transfers (up to 3 x 32-bit words).
  signal cir_operand_staging     : std_logic_vector(95 downto 0) := (others => '0');
  signal cir_operand_word_arrived : std_logic := '0';        -- Pulse from bus write → dialog proc
  signal cir_operand_read_done   : std_logic := '0';         -- Pulse from bus read → dialog proc
  signal cir_operand_read_prev   : std_logic := '0';         -- Edge-detect for operand reads
  signal cir_operand_write_prev  : std_logic := '0';         -- Edge-detect for operand writes

  -- CIR cpSAVE/cpRESTORE handshake signals (driven by cir_dialog_proc, read by bus_frame_proc).
  signal cir_save_req          : std_logic := '0';
  signal cir_save_word_idx     : natural range 0 to 63 := 0;
  signal cir_restore_word_idx  : natural range 0 to 63 := 0;
  signal cir_restore_fw_reg    : std_logic_vector(31 downto 0) := (others => '0');
  signal cir_restore_trigger   : std_logic := '0';
  signal cir_restore_null_req  : std_logic := '0';  -- Dialog FSM → bus_frame_proc: reset FPU (null restore)
  signal cir_restore_commit_req: std_logic := '0';  -- Dialog FSM → bus_frame_proc: commit idle frame
  signal cir_save_read_done    : std_logic := '0';  -- Pulse: host read Save CIR (format word)
  signal cir_save_read_prev    : std_logic := '0';  -- Edge-detect for Save CIR reads
  -- Restore staging for header words (Idle: 0-5, Busy: 0-11).
  type cir_frame_data_t is array (0 to CIR_FRAME_BUSY_HDR-1) of std_logic_vector(31 downto 0);
  signal cir_frame_data_reg    : cir_frame_data_t := (others => (others => '0'));

  -- ALU save/restore signals for Busy FSAVE/FRESTORE.
  signal alu_save_req_reg    : std_logic := '0';
  signal alu_save_data       : std_logic_vector(31 downto 0) := (others => '0');
  signal alu_save_addr       : natural range 0 to 25 := 0;
  signal alu_restore_req_reg : std_logic := '0';
  signal alu_restore_data    : std_logic_vector(31 downto 0) := (others => '0');
  signal alu_restore_addr    : natural range 0 to 25 := 0;
  signal alu_restore_wr_reg  : std_logic := '0';
  -- Packed decimal save/restore signals.
  signal packed_save_data    : std_logic_vector(31 downto 0) := (others => '0');
  signal packed_save_addr    : natural range 0 to 2 := 0;
  signal packed_restore_addr : natural range 0 to 2 := 0;
  signal packed_restore_wr   : std_logic := '0';
  -- Staging register for incoming restore data word (captured in cir_write_proc).
  signal cir_restore_word_data : std_logic_vector(31 downto 0) := (others => '0');

  signal exc_event_valid_reg : std_logic := '0';
  signal exc_event_result_reg : fp80_t := (others => '0');
  signal exc_event_opa_reg : fp80_t := (others => '0');
  signal exc_event_opb_reg : fp80_t := x"3FFF8000000000000000";
  signal exc_event_divzero_reg : std_logic := '0';
  signal exc_event_force_overflow_reg : std_logic := '0';
  signal exc_event_force_underflow_reg : std_logic := '0';
  signal exc_event_force_inexact_reg : std_logic := '0';
  signal exc_event_force_invalid_reg : std_logic := '0';
  signal exc_event_force_bsun_reg : std_logic := '0';

  type packed_req_mode_t is (PACKED_REQ_NONE, PACKED_REQ_ENCODE, PACKED_REQ_DECODE);

  signal packed_pending_reg : std_logic := '0';
  signal packed_req_start_reg : std_logic := '0';
  signal packed_req_mode_reg : packed_req_mode_t := PACKED_REQ_NONE;
  signal packed_req_fp_reg : fp80_t := (others => '0');
  signal packed_req_word_reg : std_logic_vector(95 downto 0) := (others => '0');
  signal packed_req_fallback_reg : fp80_t := (others => '0');
  signal packed_req_k_reg : integer range -64 to 17 := 0;
  signal packed_req_dst_idx_reg : natural range 0 to 7 := 0;
  signal packed_req_is_encode : std_logic := '0';
  signal packed_unit_busy : std_logic := '0';

  signal packed_result_valid_reg : std_logic := '0';
  signal packed_result_word_reg : std_logic_vector(95 downto 0) := (others => '0');
  signal packed_result_fp_reg : fp80_t := (others => '0');
  signal packed_result_inexact_reg : std_logic := '0';
  signal packed_result_invalid_reg : std_logic := '0';

  -- Packed decimal <-> ALU shared FP unit routing
  signal packed_fp_mul_start  : std_logic;
  signal packed_fp_mul_a      : fp80_t;
  signal packed_fp_mul_b      : fp80_t;
  signal packed_fp_mul_done   : std_logic;
  signal packed_fp_mul_result : fp80_t;
  signal packed_fp_add_start  : std_logic;
  signal packed_fp_add_a      : fp80_t;
  signal packed_fp_add_b      : fp80_t;
  signal packed_fp_add_sub    : boolean;
  signal packed_fp_add_done   : std_logic;
  signal packed_fp_add_result : fp80_t;

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
  constant FPCR_EXC_EN_INEXACT  : natural := 8;
  constant FPCR_EXC_EN_UNDERFLOW: natural := 9;
  constant FPCR_EXC_EN_OVERFLOW : natural := 10;
  constant FPCR_EXC_EN_DIVZERO  : natural := 11;
  constant FPCR_EXC_EN_INVALID  : natural := 12;
  constant FPCR_EXC_EN_BSUN    : natural := 15;

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

  subtype packed96_t is std_logic_vector(95 downto 0);
  type dec_digits_t is array (0 to 16) of natural range 0 to 9;
  type natural12_t is array (0 to 11) of natural;

  constant POW2_SMALL : natural12_t := (
    1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048
  );
  constant FP80_ONE : fp80_t := x"3FFF8000000000000000";
  constant FP80_TEN_POW_1 : fp80_t := x"4002A000000000000000";
  constant FP80_TEN_POW_2 : fp80_t := x"4005C800000000000000";
  constant FP80_TEN_POW_4 : fp80_t := x"400C9C40000000000000";
  constant FP80_TEN_POW_8 : fp80_t := x"4019BEBC200000000000";
  constant FP80_TEN_POW_16 : fp80_t := x"40348E1BC9BF04000000";
  constant FP80_TEN_POW_32 : fp80_t := x"40699DC5ADA82B70B59E";
  constant FP80_TEN_POW_64 : fp80_t := x"40D3C2781F49FFCFA6D5";
  constant FP80_TEN_POW_128 : fp80_t := x"41A893BA47C980E98CE0";
  constant FP80_TEN_POW_256 : fp80_t := x"4351AA7EEBFB9DF9DE8E";
  constant FP80_TEN_POW_512 : fp80_t := x"46A3E319A0AEA60E91C7";
  constant FP80_TEN_POW_1024 : fp80_t := x"4D48C976758681750C17";
  constant FP80_TEN_POW_2048 : fp80_t := x"5A929E8B3B5DC53D5DE5";
  constant FP80_TEN_POW_4096 : fp80_t := x"7525C46052028A20979B";

  function bcd_digit(value : natural) return std_logic_vector is
    variable nibble : std_logic_vector(3 downto 0) := (others => '0');
  begin
    assert value <= 9 report "bcd_digit: value out of range" severity failure;
    nibble := std_logic_vector(to_unsigned(value mod 10, 4));
    return nibble;
  end function;

  -- Returns 0..9 for valid BCD, -1 for invalid (non-decimal nibble A-F).
  function bcd_to_natural(nibble : std_logic_vector(3 downto 0)) return integer is
    variable digit_i : integer := 0;
  begin
    digit_i := to_integer(unsigned(nibble));
    if digit_i >= 0 and digit_i <= 9 then
      return digit_i;
    end if;
    return -1;
  end function;

  function fp80_pow10_pow2(bit_idx : natural) return fp80_t is
  begin
    case bit_idx is
      when 0 => return FP80_TEN_POW_1;
      when 1 => return FP80_TEN_POW_2;
      when 2 => return FP80_TEN_POW_4;
      when 3 => return FP80_TEN_POW_8;
      when 4 => return FP80_TEN_POW_16;
      when 5 => return FP80_TEN_POW_32;
      when 6 => return FP80_TEN_POW_64;
      when 7 => return FP80_TEN_POW_128;
      when 8 => return FP80_TEN_POW_256;
      when 9 => return FP80_TEN_POW_512;
      when 10 => return FP80_TEN_POW_1024;
      when others => return FP80_TEN_POW_2048;
    end case;
  end function;

  -- Scale by 10^exp10 using bounded chunking/decomposition to avoid
  -- synthesis-unfriendly long linear loops.
  function scale_fp80_by_pow10(value : fp80_t; exp10 : integer) return fp80_t is
    variable scaled : fp80_t := value;
    variable abs_exp : natural := 0;
    variable bit_value : natural := 0;
  begin
    if exp10 = 0 or fp80_is_zero(value) then
      return value;
    end if;

    if exp10 > 0 then
      abs_exp := natural(exp10);
      for chunk_idx in 0 to 3 loop
        exit when abs_exp < 4096;
        scaled := mul_fp80(scaled, FP80_TEN_POW_4096, FP_RND_NEAREST, FP_PREC_EXTENDED);
        abs_exp := abs_exp - 4096;
      end loop;
      for bit_idx in 0 to 11 loop
        bit_value := (abs_exp / POW2_SMALL(bit_idx)) mod 2;
        if bit_value = 1 then
          scaled := mul_fp80(scaled, fp80_pow10_pow2(bit_idx), FP_RND_NEAREST, FP_PREC_EXTENDED);
        end if;
      end loop;
    else
      abs_exp := natural(-exp10);
      for chunk_idx in 0 to 3 loop
        exit when abs_exp < 4096;
        scaled := div_fp80(scaled, FP80_TEN_POW_4096, FP_RND_NEAREST, FP_PREC_EXTENDED);
        abs_exp := abs_exp - 4096;
      end loop;
      for bit_idx in 0 to 11 loop
        bit_value := (abs_exp / POW2_SMALL(bit_idx)) mod 2;
        if bit_value = 1 then
          scaled := div_fp80(scaled, fp80_pow10_pow2(bit_idx), FP_RND_NEAREST, FP_PREC_EXTENDED);
        end if;
      end loop;
    end if;

    return scaled;
  end function;

  -- Lightweight packed encoder used when packed_decimal_full_g = false.
  -- Encodes special classes exactly; finite values keep only MSD/exponent from
  -- the truncated integer magnitude as a synthesis-safe fallback.
  function fp80_to_packed96_fast(value : fp80_t) return packed96_t is
    variable packed : packed96_t := (others => '0');
    variable abs_val : fp80_t := (others => '0');
    variable int_mag : integer := 0;
    variable mag_n : natural := 0;
    variable exp10 : natural range 0 to 9 := 0;
    variable exp0 : natural := 0;
    variable exp1 : natural := 0;
    variable exp2 : natural := 0;
    variable exp3 : natural := 0;
  begin
    packed(95) := value(FP_WIDTH-1);

    if fp80_is_zero(value) then
      return packed;
    end if;

    if fp80_is_inf(value) then
      packed(93 downto 92) := "11";
      packed(91 downto 88) := x"F";
      packed(87 downto 84) := x"F";
      packed(83 downto 80) := x"F";
      packed(79 downto 76) := x"F";
      return packed;
    end if;

    if fp80_is_nan(value) then
      packed(93 downto 92) := "11";
      packed(91 downto 88) := x"F";
      packed(87 downto 84) := x"F";
      packed(83 downto 80) := x"F";
      packed(79 downto 76) := x"F";
      packed(67 downto 64) := x"1";
      packed(63 downto 0) := (others => '1');
      return packed;
    end if;

    abs_val := value;
    abs_val(FP_WIDTH-1) := '0';
    int_mag := fp80_to_int_trunc(abs_val);
    if int_mag < 0 then
      int_mag := integer'high;
    end if;
    mag_n := natural(int_mag);

    if mag_n = 0 then
      return packed;
    end if;

    for idx in 0 to 8 loop
      exit when mag_n < 10;
      mag_n := mag_n / 10;
      exp10 := exp10 + 1;
    end loop;

    exp0 := exp10 mod 10;
    exp1 := (exp10 / 10) mod 10;
    exp2 := (exp10 / 100) mod 10;
    exp3 := (exp10 / 1000) mod 10;

    packed(94) := '0';
    packed(93 downto 92) := "00";
    packed(91 downto 88) := bcd_digit(exp2);
    packed(87 downto 84) := bcd_digit(exp1);
    packed(83 downto 80) := bcd_digit(exp0);
    packed(79 downto 76) := bcd_digit(exp3);
    packed(75 downto 68) := (others => '0');
    packed(67 downto 64) := bcd_digit(mag_n mod 10);

    return packed;
  end function;

  -- Lightweight packed decoder used when packed_decimal_full_g = false.
  -- Decodes only leading digit + exponent into an integer-magnitude result.
  function packed96_to_fp80_fast(packed : packed96_t; fallback : fp80_t) return fp80_t is
    variable decoded_value : fp80_t := (others => '0');
    variable sign_m : std_logic := '0';
    variable exp0_i : integer := 0;
    variable exp1_i : integer := 0;
    variable exp2_i : integer := 0;
    variable exp3_i : integer := 0;
    variable exp10 : integer := 0;
    variable lead_digit : integer := 0;
    variable value_n : natural := 0;
    variable pos_scale : natural := 0;
  begin
    sign_m := packed(95);

    if packed(93 downto 92) = "11" then
      decoded_value(FP_WIDTH-1) := sign_m;
      decoded_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
      decoded_value(FP_MANT_WIDTH-1) := '1';
      if packed(67 downto 0) /= (67 downto 0 => '0') then
        decoded_value(FP_MANT_WIDTH-2 downto 0) := (others => '1');
      end if;
      return decoded_value;
    end if;

    exp0_i := bcd_to_natural(packed(83 downto 80));
    exp1_i := bcd_to_natural(packed(87 downto 84));
    exp2_i := bcd_to_natural(packed(91 downto 88));
    exp3_i := bcd_to_natural(packed(79 downto 76));
    lead_digit := bcd_to_natural(packed(67 downto 64));
    if exp0_i < 0 or exp1_i < 0 or exp2_i < 0 or exp3_i < 0 or lead_digit < 0 then
      return fallback;
    end if;

    exp10 := exp3_i*1000 + exp2_i*100 + exp1_i*10 + exp0_i;
    if packed(94) = '1' then
      exp10 := -exp10;
    end if;

    value_n := natural(lead_digit);
    if exp10 > 0 then
      pos_scale := natural(exp10);
      for idx in 1 to 9 loop
        exit when idx > pos_scale;
        if value_n > natural(integer'high / 10) then
          value_n := natural(integer'high);
          exit;
        end if;
        value_n := value_n * 10;
      end loop;
      if pos_scale > 9 then
        value_n := natural(integer'high);
      end if;
    elsif exp10 < 0 then
      value_n := 0;
    end if;

    decoded_value := fp80_from_int(integer(value_n));
    decoded_value(FP_WIDTH-1) := sign_m;
    return decoded_value;
  end function;

  -- Encode fp80 to MC68881 96-bit packed-decimal format.
  -- Layout: SM(95) SE(94) YY(93:92) exp2(91:88) exp1(87:84) exp0(83:80)
  --         exp3(79:76) reserved(75:68) int_digit(67:64) frac_digits(63:0)
  -- Handles zero, infinity (YY=11, 0xF exponent nibbles), and NaN (YY=11
  -- plus non-zero mantissa). Finite values use a unified FP80
  -- multiply-and-truncate digit-extraction loop.
  -- Applies round-to-nearest-even when truncating to k significant digits.
  function fp80_to_packed96(value : fp80_t; k_factor : integer) return packed96_t is
    variable packed : packed96_t := (others => '0');
    variable digits : dec_digits_t := (others => 0);
    variable k_clamped : integer := 0;
    variable keep_digits : integer := 17;
    variable carry : integer := 0;
    variable exp10 : integer := 0;
    variable exp_abs : natural := 0;
    variable exp0 : natural := 0;
    variable exp1 : natural := 0;
    variable exp2 : natural := 0;
    variable exp3 : natural := 0;
    variable abs_val : fp80_t := (others => '0');
    variable scaled : fp80_t := (others => '0');
    variable ten : fp80_t := fp80_from_int(10);
    variable digit_int : integer := 0;
    variable digit_fp : fp80_t := (others => '0');
    variable bin_exp : integer := 0;
    variable has_trailing : boolean := false;
    variable round_digit : natural := 0;
  begin
    packed(95) := value(FP_WIDTH-1);

    if fp80_is_zero(value) then
      return packed;
    end if;

    if fp80_is_inf(value) then
      packed(93 downto 92) := "11";
      packed(91 downto 88) := x"F";
      packed(87 downto 84) := x"F";
      packed(83 downto 80) := x"F";
      packed(79 downto 76) := x"F";
      return packed;
    end if;

    if fp80_is_nan(value) then
      packed(93 downto 92) := "11";
      packed(91 downto 88) := x"F";
      packed(87 downto 84) := x"F";
      packed(83 downto 80) := x"F";
      packed(79 downto 76) := x"F";
      packed(67 downto 64) := x"1";
      packed(63 downto 0) := (others => '1');
      return packed;
    end if;

    -- Take absolute value
    abs_val := value;
    abs_val(FP_WIDTH-1) := '0';

    -- Estimate decimal exponent from binary exponent
    -- log10(2) ~= 77/256 = 0.30078 (close enough for initial estimate)
    bin_exp := to_integer(unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH))) - FP_EXP_BIAS;
    -- For subnormals (biased exponent = 0), adjust bin_exp by counting
    -- leading mantissa zeros so the exp10 estimate is accurate.
    if unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH)) = 0 then
      bin_exp := 1 - FP_EXP_BIAS;
      for bit_idx in FP_MANT_WIDTH-1 downto 0 loop
        exit when abs_val(bit_idx) = '1';
        bin_exp := bin_exp - 1;
      end loop;
    end if;
    if bin_exp >= 0 then
      exp10 := (bin_exp * 77) / 256;
    else
      exp10 := -(((-bin_exp) * 77 + 255) / 256);
    end if;

    -- Scale into [1.0, 10.0) from estimated decimal exponent.
    scaled := scale_fp80_by_pow10(abs_val, -exp10);

    -- Fine-tune: ensure scaled is in [1.0, 10.0)
    for i in 0 to 5 loop
      if compare_fp80(scaled, ten) >= 0 then
        scaled := div_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 + 1;
      elsif compare_fp80(scaled, FP80_ONE) < 0 then
        scaled := mul_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 - 1;
      else
        exit;
      end if;
    end loop;

    -- Extract 17 decimal digits via multiply-and-truncate.
    -- After extraction, propagate any trailing 9999... overflow caused
    -- by FP rounding errors in the scaling step.
    for d in 0 to 16 loop
      digit_int := fp80_to_int_trunc(scaled);
      if digit_int < 0 then digit_int := 0; end if;
      if digit_int > 9 then digit_int := 9; end if;
      digits(d) := digit_int;
      digit_fp := fp80_from_int(digit_int);
      scaled := mul_fp80(
        add_sub_fp80(scaled, digit_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
        ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end loop;
    -- Fix trailing 9-overflow: if the last digit position would have
    -- rounded up (residual scaled >= 5), propagate a carry through
    -- trailing 9s.  This corrects e.g. 4.1999999... -> 4.2000000...
    digit_int := fp80_to_int_trunc(scaled);
    if digit_int >= 5 then
      carry := 1;
      for idx in 16 downto 0 loop
        if carry = 0 then
          exit;
        end if;
        if digits(idx) = 9 then
          digits(idx) := 0;
        else
          digits(idx) := digits(idx) + 1;
          carry := 0;
        end if;
      end loop;
      if carry = 1 then
        -- Overflow from MSD: shift digits right, set MSD=1, bump exp
        for idx in 16 downto 1 loop
          digits(idx) := digits(idx-1);
        end loop;
        digits(0) := 1;
        exp10 := exp10 + 1;
      end if;
    end if;
    carry := 0; -- reset for k-factor rounding below

    -- Apply k-factor rounding (round-to-nearest-even)
    k_clamped := clamp_integer(k_factor, -64, 17);
    if k_clamped > 0 then
      keep_digits := k_clamped;
    elsif k_clamped <= 0 then
      keep_digits := exp10 + 1 + (-k_clamped);
    end if;
    if keep_digits < 1 then
      keep_digits := 1;
    elsif keep_digits > 17 then
      keep_digits := 17;
    end if;

    if keep_digits < 17 then
      round_digit := digits(keep_digits);
      carry := 0;
      if round_digit > 5 then
        carry := 1;
      elsif round_digit = 5 then
        -- Check for trailing non-zero digits (above halfway)
        has_trailing := false;
        for idx in 1 to 16 loop
          if idx > keep_digits then
            if digits(idx) /= 0 then
              has_trailing := true;
              exit;
            end if;
          end if;
        end loop;
        if has_trailing then
          carry := 1;
        elsif digits(keep_digits - 1) mod 2 = 1 then
          carry := 1; -- exact halfway: round to even
        end if;
      end if;
      for idx in 16 downto 0 loop
        if idx < keep_digits then
          if carry = 1 then
            if digits(idx) = 9 then
              digits(idx) := 0;
            else
              digits(idx) := digits(idx) + 1;
              carry := 0;
            end if;
          end if;
        else
          digits(idx) := 0;
        end if;
      end loop;
      if carry = 1 then
        for idx in 16 downto 1 loop
          digits(idx) := digits(idx-1);
        end loop;
        digits(0) := 1;
        exp10 := exp10 + 1;
      end if;
    end if;

    -- Encode exponent
    if exp10 < 0 then
      packed(94) := '1';
      exp_abs := natural(-exp10);
    else
      packed(94) := '0';
      exp_abs := natural(exp10);
    end if;

    exp0 := exp_abs mod 10;
    exp1 := (exp_abs / 10) mod 10;
    exp2 := (exp_abs / 100) mod 10;
    exp3 := (exp_abs / 1000) mod 10;

    packed(93 downto 92) := "00";
    packed(91 downto 88) := bcd_digit(exp2);
    packed(87 downto 84) := bcd_digit(exp1);
    packed(83 downto 80) := bcd_digit(exp0);
    packed(79 downto 76) := bcd_digit(exp3);
    packed(75 downto 68) := (others => '0');
    packed(67 downto 64) := bcd_digit(digits(0));
    for idx in 0 to 15 loop
      packed(63 - idx*4 downto 60 - idx*4) := bcd_digit(digits(idx+1));
    end loop;
    return packed;
  end function;

  -- Check whether fp80_to_packed96 would lose precision for the given value
  -- and k-factor. Avoids the lossy packed96_to_fp80 decoder: checks the
  -- digit array directly to determine if any non-zero digit is truncated.
  function packed_encode_is_inexact(value : fp80_t; k_factor : integer) return boolean is
    variable digits : dec_digits_t := (others => 0);
    variable k_clamped : integer := 0;
    variable keep_digits : integer := 17;
    variable exp10 : integer := 0;
    variable abs_val : fp80_t := (others => '0');
    variable scaled : fp80_t := (others => '0');
    variable ten : fp80_t := fp80_from_int(10);
    variable digit_int : integer := 0;
    variable digit_fp : fp80_t := (others => '0');
    variable bin_exp : integer := 0;
  begin
    if fp80_is_zero(value) or fp80_is_inf(value) or fp80_is_nan(value) then
      return false;
    end if;

    abs_val := value;
    abs_val(FP_WIDTH-1) := '0';

    -- Estimate decimal exponent (mirrors encoder)
    bin_exp := to_integer(unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH))) - FP_EXP_BIAS;
    -- For subnormals (biased exponent = 0), adjust bin_exp by counting
    -- leading mantissa zeros so the exp10 estimate is accurate.
    if unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH)) = 0 then
      bin_exp := 1 - FP_EXP_BIAS;
      for bit_idx in FP_MANT_WIDTH-1 downto 0 loop
        exit when abs_val(bit_idx) = '1';
        bin_exp := bin_exp - 1;
      end loop;
    end if;
    if bin_exp >= 0 then
      exp10 := (bin_exp * 77) / 256;
    else
      exp10 := -(((-bin_exp) * 77 + 255) / 256);
    end if;

    scaled := scale_fp80_by_pow10(abs_val, -exp10);

    for i in 0 to 5 loop
      if compare_fp80(scaled, ten) >= 0 then
        scaled := div_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 + 1;
      elsif compare_fp80(scaled, FP80_ONE) < 0 then
        scaled := mul_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 - 1;
      else
        exit;
      end if;
    end loop;

    -- Extract 17 digits (mirrors encoder)
    for d in 0 to 16 loop
      digit_int := fp80_to_int_trunc(scaled);
      if digit_int < 0 then digit_int := 0; end if;
      if digit_int > 9 then digit_int := 9; end if;
      digits(d) := digit_int;
      digit_fp := fp80_from_int(digit_int);
      scaled := mul_fp80(
        add_sub_fp80(scaled, digit_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
        ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end loop;

    -- FP80 has ~18.96 significant decimal digits.  If the residual after
    -- extracting 17 digits is non-zero, the packed format inherently rounds.
    if not fp80_is_zero(scaled) then
      return true;
    end if;

    -- Check if k-factor truncation loses non-zero digits
    k_clamped := clamp_integer(k_factor, -64, 17);
    if k_clamped > 0 then
      keep_digits := k_clamped;
    elsif k_clamped <= 0 then
      keep_digits := exp10 + 1 + (-k_clamped);
    end if;
    if keep_digits < 1 then
      keep_digits := 1;
    elsif keep_digits > 17 then
      keep_digits := 17;
    end if;

    if keep_digits < 17 then
      for idx in 0 to 16 loop
        if idx >= keep_digits then
          if digits(idx) /= 0 then
            return true;
          end if;
        end if;
      end loop;
    end if;

    return false;
  end function;

  -- Decode MC68881 96-bit packed-decimal to fp80.
  -- Detects infinity/NaN via YY=11 (produces canonical QNaN for NaN;
  -- payload preservation not yet implemented). Accumulates all 17 BCD
  -- mantissa digits via FP80 arithmetic and scales by 10^(exp10-16).
  -- Returns fallback for invalid BCD nibbles.
  function packed96_to_fp80(packed : packed96_t; fallback : fp80_t) return fp80_t is
    variable decoded_value : fp80_t := fallback;
    variable mant_digits : dec_digits_t := (others => 0);
    variable exp0_i : integer := 0;
    variable exp1_i : integer := 0;
    variable exp2_i : integer := 0;
    variable exp3_i : integer := 0;
    variable exp10 : integer := 0;
    variable scale_exp : integer := 0;
    variable ten_fp80 : fp80_t := fp80_from_int(10);
    variable digit_fp : fp80_t := (others => '0');
    variable sign_m : std_logic := '0';
    variable idx : integer := 0;
    variable all_zero : boolean := true;
  begin
    sign_m := packed(95);

    -- Infinity/NaN: YY=11
    if packed(93 downto 92) = "11" then
      decoded_value := (others => '0');
      decoded_value(FP_WIDTH-1) := sign_m;
      decoded_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
      decoded_value(FP_MANT_WIDTH-1) := '1';
      if packed(67 downto 0) /= (67 downto 0 => '0') then
        decoded_value(FP_MANT_WIDTH-2 downto 0) := (others => '1');
      end if;
      return decoded_value;
    end if;

    -- Extract and validate exponent BCD nibbles
    exp0_i := bcd_to_natural(packed(83 downto 80));
    exp1_i := bcd_to_natural(packed(87 downto 84));
    exp2_i := bcd_to_natural(packed(91 downto 88));
    exp3_i := bcd_to_natural(packed(79 downto 76));
    if exp0_i < 0 or exp1_i < 0 or exp2_i < 0 or exp3_i < 0 then
      return fallback;
    end if;
    exp10 := exp3_i*1000 + exp2_i*100 + exp1_i*10 + exp0_i;
    if packed(94) = '1' then
      exp10 := -exp10;
    end if;

    -- Extract and validate all 17 mantissa digits
    idx := bcd_to_natural(packed(67 downto 64));
    if idx < 0 then
      return fallback;
    end if;
    mant_digits(0) := natural(idx);
    for nib_idx in 0 to 15 loop
      idx := bcd_to_natural(packed(63 - nib_idx*4 downto 60 - nib_idx*4));
      if idx < 0 then
        return fallback;
      end if;
      mant_digits(nib_idx+1) := natural(idx);
    end loop;

    -- Check for all-zero mantissa (packed zero)
    all_zero := true;
    for d in 0 to 16 loop
      if mant_digits(d) /= 0 then
        all_zero := false;
        exit;
      end if;
    end loop;
    if all_zero then
      decoded_value := (others => '0');
      decoded_value(FP_WIDTH-1) := sign_m;
      return decoded_value;
    end if;

    -- Accumulate all 17 digits via FP80 arithmetic
    decoded_value := fp80_from_int(mant_digits(0));
    for d in 1 to 16 loop
      digit_fp := fp80_from_int(mant_digits(d));
      decoded_value := add_sub_fp80(
        mul_fp80(decoded_value, ten_fp80, FP_RND_NEAREST, FP_PREC_EXTENDED),
        digit_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end loop;

    -- Scale by 10^(exp10 - 16) to position the decimal point
    scale_exp := exp10 - 16;
    decoded_value := scale_fp80_by_pow10(decoded_value, scale_exp);

    decoded_value(FP_WIDTH-1) := sign_m;
    return decoded_value;
  end function;

  -- Check if a packed-96 word contains invalid BCD nibbles (A-F).
  -- Skips check for YY=11 (infinity/NaN use non-BCD nibble encoding).
  function packed96_has_invalid_bcd(packed : packed96_t) return boolean is
  begin
    if packed(93 downto 92) = "11" then
      return false;
    end if;
    -- Check 4 exponent nibbles
    if bcd_to_natural(packed(91 downto 88)) < 0 then return true; end if;
    if bcd_to_natural(packed(87 downto 84)) < 0 then return true; end if;
    if bcd_to_natural(packed(83 downto 80)) < 0 then return true; end if;
    if bcd_to_natural(packed(79 downto 76)) < 0 then return true; end if;
    -- Check 17 mantissa nibbles
    if bcd_to_natural(packed(67 downto 64)) < 0 then return true; end if;
    for nib_idx in 0 to 15 loop
      if bcd_to_natural(packed(63 - nib_idx*4 downto 60 - nib_idx*4)) < 0 then
        return true;
      end if;
    end loop;
    return false;
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
        for idx in 0 to FP_MANT_WIDTH-1 loop
          if idx <= sticky_hi then
            if mant80(idx) = '1' then
              sticky_bit := '1';
            end if;
          end if;
        end loop;

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
        for idx in 0 to FP_MANT_WIDTH-1 loop
          if idx <= sticky_hi then
            if mant80(idx) = '1' then
              sticky_bit := '1';
            end if;
          end if;
        end loop;

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
    -- Fold upper 32 condition codes (0x20-0x3F) to lower 32 (0x00-0x1F)
    -- per MC68881 architecture; bit 5 has no effect on condition semantics.
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
    return op_sel = FPU_OP_FSCC or op_sel = FPU_OP_FBCC or op_sel = FPU_OP_FDBCC or op_sel = FPU_OP_FTRAPCC;
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
  -- Shared format converters — single instance each, driven by conv_fp_src.
  -- Source mux: CIR path uses cir_dst_reg_idx, FMOVE path uses move_cfg src_idx.
  conv_fp_src <= fp_reg_file_reg(cir_dst_reg_idx)
                 when cir_state_reg = CIR_XFER_DST
                 else fp_reg_file_reg(move_cfg_decoded_reg.src_idx);
  conv_single_out <= fp80_to_single(conv_fp_src, round_mode);
  conv_double_out <= fp80_to_double(conv_fp_src, round_mode);

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
      when ADDR_CIR_SAVE | ADDR_CIR_RESPONSE | ADDR_CIR_RESTORE =>
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

  sync_read <= '1' when (bus_read = '1' and
                         (access_class = ACCESS_CIR or cir_state_reg = CIR_SAVE_FRAME)) else '0';
  -- FPCR mode control: bits 7-6 precision, 5-4 rounding mode.
  round_mode <= decode_round_mode(fpcr_reg(5 downto 4));
  round_prec <= decode_round_prec(fpcr_reg(7 downto 6));
  op_sel_write_decoded <= decode_op_sel_word(d_in);
  op_class_write_decoded <= op_class(op_sel_write_decoded);
  conditional_prog_op_write <= '1' when is_conditional_prog_op(op_sel_write_decoded) else '0';
  -- CIR: combinational decode of command word opcode bits [6:0] to fpu_op_t.
  cir_decoded_op <= cir_decode_cpgen_opcode(cir_command_reg);

  -- Busy frame save/restore address routing (concurrent).
  -- Layout: 0-5 header, 6-11 operands, 12-37 ALU (26 words), 38-40 packed (3), 41-44 pad.
  -- FSAVE: map cir_save_word_idx to sub-unit save_addr.
  alu_save_addr    <= cir_save_word_idx - 12 when cir_save_word_idx >= 12 and cir_save_word_idx <= 37 else 0;
  packed_save_addr <= cir_save_word_idx - 38 when cir_save_word_idx >= 38 and cir_save_word_idx <= 40 else 0;
  -- FRESTORE: map cir_restore_word_idx to sub-unit restore_addr.
  alu_restore_addr    <= cir_restore_word_idx - 12 when cir_restore_word_idx >= 12 and cir_restore_word_idx <= 37 else 0;
  packed_restore_addr <= cir_restore_word_idx - 38 when cir_restore_word_idx >= 38 and cir_restore_word_idx <= 40 else 0;
  -- Restore data bus: shared between ALU and packed (only one writes at a time).
  alu_restore_data <= cir_restore_word_data;

  -- One-cycle launch pulse on the rising edge of an OPSEL write when engines
  -- are idle.  The opsel_write_prev_reg guard ensures sustained bus_write
  -- levels do not re-fire the pulse on subsequent clocks.
  op_issue_pulse <= '1' when (
    (bus_write = '1' and
     addr = ADDR_OPSEL and
     opsel_write_prev_reg = '0' and
     op_class_write_decoded /= OP_CLASS_NONE and
     micro_active_reg = '0' and
     frame_busy_reg = '0' and
     busy = '0' and
     not (conditional_prog_op_write = '1' and cir_response_pending_reg = '1'))
    or
    (cir_launch_alu = '1')
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
      flag_divzero => alu_flag_divzero,
      packed_fp_mul_start  => packed_fp_mul_start,
      packed_fp_mul_a      => packed_fp_mul_a,
      packed_fp_mul_b      => packed_fp_mul_b,
      packed_fp_mul_done   => packed_fp_mul_done,
      packed_fp_mul_result => packed_fp_mul_result,
      packed_fp_add_start  => packed_fp_add_start,
      packed_fp_add_a      => packed_fp_add_a,
      packed_fp_add_b      => packed_fp_add_b,
      packed_fp_add_sub    => packed_fp_add_sub,
      packed_fp_add_done   => packed_fp_add_done,
      packed_fp_add_result => packed_fp_add_result,
      save_req       => alu_save_req_reg,
      save_data      => alu_save_data,
      save_addr      => alu_save_addr,
      restore_req    => alu_restore_req_reg,
      restore_data   => alu_restore_data,
      restore_addr   => alu_restore_addr,
      restore_wr     => alu_restore_wr_reg
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
    variable class_force_invalid : std_logic := '0';
    variable class_force_bsun : std_logic := '0';
  begin
    if reset_n = '0' then
      op_sel_reg <= FPU_OP_NOP;
      operand_reg <= (others => (others => '0'));
      operand_hi16_reg <= (others => (others => '0'));
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
      fpu_initialized_reg <= '0';
      opsel_write_prev_reg <= '0';
      cir_restore_trigger <= '0';
    elsif rising_edge(clk) then
      frame_start_save_reg <= '0';
      frame_start_restore_reg <= '0';
      cir_restore_trigger <= '0';  -- One-shot: cleared each cycle, set by ADDR_CIR_RESTORE write
      -- Track OPSEL write level for edge detection in protocol violation check.
      if bus_write = '1' and addr = ADDR_OPSEL then
        opsel_write_prev_reg <= '1';
      else
        opsel_write_prev_reg <= '0';
      end if;

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
            operand_hi16_reg(0) <= d_in(31 downto 16);
          when ADDR_OPB_L =>
            operand_reg(1)(FP80_RESULT_LO_WIDTH-1 downto 0) <= d_in;
          when ADDR_OPB_H =>
            operand_reg(1)(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH) <= d_in;
          when ADDR_OPB_E =>
            operand_reg(1)(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH) <= d_in(FP80_RESULT_EX_WIDTH-1 downto 0);
            operand_hi16_reg(1) <= d_in(31 downto 16);
          when ADDR_FPCR =>
            fpcr_reg(15 downto 0) <= d_in(15 downto 0);
            fpcr_reg(31 downto 16) <= (others => '0');
          when ADDR_FPSR =>
            fpsr_reg <= d_in;
          when ADDR_FPIAR =>
            fpiar_reg <= d_in;
          when ADDR_CIR_SAVE =>
            fpiar_reg <= d_in;
          when ADDR_CIR_RESTORE =>
            -- Capture format word for FRESTORE dialog.
            cir_restore_fw_reg <= d_in;
            cir_restore_trigger <= '1';
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

      -- CIR launch: load operands (and op_sel for cpGEN) into ALU inputs.
      if cir_launch_alu = '1' then
        if cir_instr_type = CIR_TYPE_CPCOND or
           cir_instr_type = CIR_TYPE_CPBCC_W or
           cir_instr_type = CIR_TYPE_CPBCC_L then
          -- CIR conditional: load condition selector into operand A.
          operand_reg(0) <= (others => '0');
          operand_reg(0)(5 downto 0) <= cir_condition_reg;
        else
          -- cpGEN: load destination FP register as operand A.
          op_sel_reg <= cir_decoded_op;
          operand_reg(0) <= fp_reg_file_reg(cir_dst_reg_idx);
        end if;
        if cir_reg_to_reg = '1' then
          -- Register-to-register: source from FP register file.
          operand_reg(1) <= fp_reg_file_reg(cir_src_reg_idx);
        else
          -- Memory source: convert staged operand words to FP80.
          case cir_src_fmt is
            when CIR_SRC_LONG =>
              operand_reg(1) <= fp80_from_int(
                signed32_to_integer(cir_operand_staging(31 downto 0)));
            when CIR_SRC_SINGLE =>
              operand_reg(1) <= fp80_from_single(
                cir_operand_staging(31 downto 0));
            when CIR_SRC_EXTENDED =>
              -- Word 0 bits[15:0] = sign+exp, word 1 = mant_hi, word 2 = mant_lo.
              operand_reg(1) <= cir_operand_staging(15 downto 0) &
                                cir_operand_staging(63 downto 32) &
                                cir_operand_staging(95 downto 64);
            when CIR_SRC_WORD =>
              operand_reg(1) <= fp80_from_int(
                signed16_to_integer(cir_operand_staging(15 downto 0)));
            when CIR_SRC_DOUBLE =>
              -- Word 0 = upper 32, word 1 = lower 32.
              operand_reg(1) <= fp80_from_double(
                cir_operand_staging(31 downto 0) &
                cir_operand_staging(63 downto 32));
            when CIR_SRC_BYTE =>
              operand_reg(1) <= fp80_from_int(
                signed8_to_integer(cir_operand_staging(7 downto 0)));
            when CIR_SRC_PACKED =>
              -- Word 0 (staging[31:0]) = packed[95:64], word 1 = [63:32], word 2 = [31:0].
              operand_reg(1) <= packed96_to_fp80_fast(
                cir_operand_staging(31 downto 0) &
                cir_operand_staging(63 downto 32) &
                cir_operand_staging(95 downto 64),
                fp_reg_file_reg(cir_dst_reg_idx));
            when others =>
              operand_reg(1) <= (others => '0');
          end case;
        end if;
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
          class_force_invalid := '0';
          class_force_bsun := '0';
        else
          class_opa := exc_event_opa_reg;
          class_opb := exc_event_opb_reg;
          class_result := exc_event_result_reg;
          class_divzero := exc_event_divzero_reg;
          class_force_overflow := exc_event_force_overflow_reg;
          class_force_underflow := exc_event_force_underflow_reg;
          class_force_inexact := exc_event_force_inexact_reg;
          class_force_invalid := exc_event_force_invalid_reg;
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

        if exc_policy.invalid_on_nan_inputs and
           (fp80_is_snan(class_opa) or fp80_is_snan(class_opb)) then
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

        if class_force_invalid = '1' then
          exc_flags(FPSR_EXC_INVALID) := '1';
        end if;

        if class_force_bsun = '1' then
          exc_flags(FPSR_EXC_BSUN) := '1';
        end if;

        if exc_policy.update_exc_status then
          -- Datasheet Section 2.3.3: EXC byte is cleared then set per operation.
          exc_status_byte := (others => '0');
          exc_status_byte(FPSR_EXC_INVALID downto FPSR_EXC_INEXACT) := exc_flags(FPSR_EXC_INVALID downto FPSR_EXC_INEXACT);
          exc_status_byte(FPSR_EXC_BSUN) := exc_flags(FPSR_EXC_BSUN);
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
          aexc_combined(FPSR_EXC_BSUN)     := exc_flags(FPSR_EXC_BSUN);
          accrued_exc_byte := fpsr_reg(FPSR_AEXC_MSB downto FPSR_AEXC_LSB);
          accrued_exc_byte(FPSR_EXC_INVALID downto FPSR_EXC_INEXACT) :=
            accrued_exc_byte(FPSR_EXC_INVALID downto FPSR_EXC_INEXACT) or aexc_combined(FPSR_EXC_INVALID downto FPSR_EXC_INEXACT);
          accrued_exc_byte(FPSR_EXC_BSUN) :=
            accrued_exc_byte(FPSR_EXC_BSUN) or aexc_combined(FPSR_EXC_BSUN);
          fpsr_reg(FPSR_AEXC_MSB downto FPSR_AEXC_LSB) <= accrued_exc_byte;
        end if;

        -- BSUN updates FPSR EXC byte unconditionally (not gated by exception
        -- policy, since BSUN applies to program-control ops which use
        -- EXC_POLICY_NONE).
        if class_force_bsun = '1' then
          fpsr_reg(FPSR_EXC_LSB + FPSR_EXC_BSUN) <= '1';
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

      if op_issue_pulse = '1' then
        fpu_initialized_reg <= '1';
      end if;

      if frame_busy_reg = '1' then
        if frame_remaining_reg = 0 then
          frame_busy_reg <= '0';
          if frame_restore_pending_reg = '1' then
            if frame_mem_reg(0) = x"00000000" then
              -- Null frame: reset FPU state
              fpcr_reg <= (others => '0');
              fpsr_reg <= (others => '0');
              fpiar_reg <= (others => '0');
              fpu_initialized_reg <= '0';
            else
              -- Idle frame ($18): restore from W1/W2
              fpcr_reg <= frame_mem_reg(1);
              fpsr_reg <= frame_mem_reg(2);
              fpu_initialized_reg <= '1';
            end if;
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
        if fpu_initialized_reg = '0' then
          frame_mem_reg(0) <= x"00000000";  -- null frame format
          frame_mem_reg(1) <= (others => '0');
          frame_mem_reg(2) <= (others => '0');
          frame_mem_reg(3) <= (others => '0');
        else
          frame_mem_reg(0) <= x"00000018";  -- idle frame format
          frame_mem_reg(1) <= fpcr_reg;
          frame_mem_reg(2) <= fpsr_reg;
          frame_mem_reg(3) <= status_frame_word;
        end if;
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_valid_reg <= '0';
        frame_restore_pending_reg <= '0';
      elsif sys_ctrl_save_req_reg = '1' and frame_busy_reg = '0' then
        -- FSAVE opcode path: same capture logic as external FRAME_CMD save
        status_frame_word := (others => '0');
        status_frame_word(0) := status_valid_reg;
        status_frame_word(1) := status_busy_reg;
        status_frame_word(2) := frame_valid_reg;
        status_frame_word(3) := frame_busy_reg;
        if fpu_initialized_reg = '0' then
          frame_mem_reg(0) <= x"00000000";  -- null frame format
          frame_mem_reg(1) <= (others => '0');
          frame_mem_reg(2) <= (others => '0');
          frame_mem_reg(3) <= (others => '0');
        else
          frame_mem_reg(0) <= x"00000018";  -- idle frame format
          frame_mem_reg(1) <= fpcr_reg;
          frame_mem_reg(2) <= fpsr_reg;
          frame_mem_reg(3) <= status_frame_word;
        end if;
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_valid_reg <= '0';
        frame_restore_pending_reg <= '0';
      elsif frame_start_restore_reg = '1' and frame_busy_reg = '0' and micro_active_reg = '0' then
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_restore_pending_reg <= '1';
      elsif sys_ctrl_restore_req_reg = '1' and frame_busy_reg = '0' then
        -- FRESTORE opcode path
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_restore_pending_reg <= '1';
      end if;

      -- CIR FRESTORE null: reset FPU to power-on state.
      if cir_restore_null_req = '1' then
        fpu_initialized_reg <= '0';
      end if;

      -- CIR FRESTORE commit: mark FPU initialized and restore staged header data.
      if cir_restore_commit_req = '1' then
        fpu_initialized_reg <= '1';
        -- Busy frame: restore operands and FPSR from staged header words.
        -- Save layout: word 6=opA(31:0), 7=opA(79:64)&opA(63:48),
        --   8=opB(31:0), 9=opB(79:64)&opB(63:48), 10=opA(63:32), 11=opB(63:32).
        if cir_xfer_word_count = CIR_FRAME_BUSY_WORDS then
          fpsr_reg <= cir_frame_data_reg(2);
          operand_reg(0)(31 downto 0)  <= cir_frame_data_reg(6);
          operand_reg(0)(63 downto 32) <= cir_frame_data_reg(10);
          operand_reg(0)(79 downto 64) <= cir_frame_data_reg(7)(31 downto 16);
          operand_reg(1)(31 downto 0)  <= cir_frame_data_reg(8);
          operand_reg(1)(63 downto 32) <= cir_frame_data_reg(11);
          operand_reg(1)(79 downto 64) <= cir_frame_data_reg(9)(31 downto 16);
        end if;
      end if;
    end if;
  end process;

  packed_req_is_encode <= '1' when packed_req_mode_reg = PACKED_REQ_ENCODE else '0';

  packed_engine_full_g : if packed_decimal_full_g generate
  begin
    packed_unit_inst : entity work.mc68881_packed_decimal_unit
      port map (
        clk             => clk,
        reset_n         => reset_n,
        req_valid       => packed_req_start_reg,
        req_encode      => packed_req_is_encode,
        req_fp          => packed_req_fp_reg,
        req_word        => packed_req_word_reg,
        req_fallback_fp => packed_req_fallback_reg,
        req_k           => packed_req_k_reg,
        busy            => packed_unit_busy,
        rsp_valid       => packed_result_valid_reg,
        rsp_word        => packed_result_word_reg,
        rsp_fp          => packed_result_fp_reg,
        rsp_inexact     => packed_result_inexact_reg,
        rsp_invalid     => packed_result_invalid_reg,
        fp_mul_start    => packed_fp_mul_start,
        fp_mul_a_out    => packed_fp_mul_a,
        fp_mul_b_out    => packed_fp_mul_b,
        fp_mul_done     => packed_fp_mul_done,
        fp_mul_result   => packed_fp_mul_result,
        fp_add_start    => packed_fp_add_start,
        fp_add_a_out    => packed_fp_add_a,
        fp_add_b_out    => packed_fp_add_b,
        fp_add_sub_out  => packed_fp_add_sub,
        fp_add_done     => packed_fp_add_done,
        fp_add_result   => packed_fp_add_result,
        save_req       => alu_save_req_reg,
        save_data      => packed_save_data,
        save_addr      => packed_save_addr,
        restore_req    => alu_restore_req_reg,
        restore_data   => alu_restore_data,
        restore_addr   => packed_restore_addr,
        restore_wr     => packed_restore_wr
      );
  end generate;

  packed_engine_bypass_g : if not packed_decimal_full_g generate
  begin
    packed_unit_busy <= '0';
    packed_result_valid_reg <= '0';
    packed_result_word_reg <= (others => '0');
    packed_result_fp_reg <= (others => '0');
    packed_result_inexact_reg <= '0';
    packed_result_invalid_reg <= '0';
    packed_fp_mul_start <= '0';
    packed_fp_mul_a <= (others => '0');
    packed_fp_mul_b <= (others => '0');
    packed_fp_add_start <= '0';
    packed_fp_add_a <= (others => '0');
    packed_fp_add_b <= (others => '0');
    packed_fp_add_sub <= false;
    packed_save_data <= (others => '0');
  end generate;

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
    variable packed_word : packed96_t := (others => '0');
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
    variable move_exc_force_invalid : std_logic := '0';
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
    variable move_deferred : std_logic := '0';
    variable eff_op_class : fpu_op_class_t := OP_CLASS_NONE;
    variable eff_op_sel   : fpu_op_t := FPU_OP_NOP;
    variable cond_selector : std_logic_vector(5 downto 0) := (others => '0');
  begin
    if reset_n = '0' then
      result_lo_reg <= (others => '0');
      result_hi_reg <= (others => '0');
      result_ex_reg <= (others => '0');
      result_ex_hi_reg <= (others => '0');
      aux_result_lo_reg <= (others => '0');
      aux_result_hi_reg <= (others => '0');
      aux_result_ex_reg <= (others => '0');
      aux_result_ex_hi_reg <= (others => '0');
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
      exc_event_force_inexact_reg <= '0';
      exc_event_force_invalid_reg <= '0';
      exc_event_force_bsun_reg <= '0';
      cir_arith_active_reg <= '0';
      cir_move_pending_reg <= '0';
      sys_ctrl_save_req_reg <= '0';
      sys_ctrl_restore_req_reg <= '0';
      frame_op_waiting_reg <= '0';
      packed_pending_reg <= '0';
      packed_req_start_reg <= '0';
      packed_req_mode_reg <= PACKED_REQ_NONE;
      packed_req_fp_reg <= (others => '0');
      packed_req_word_reg <= (others => '0');
      packed_req_fallback_reg <= (others => '0');
      packed_req_k_reg <= 0;
      packed_req_dst_idx_reg <= 0;
    elsif rising_edge(clk) then
      op_start_reg <= '0';
      ctrl_move_write_req_reg <= '0';
      packed_req_start_reg <= '0';
      packed_req_mode_reg <= packed_req_mode_reg;
      packed_req_fp_reg <= packed_req_fp_reg;
      packed_req_word_reg <= packed_req_word_reg;
      packed_req_fallback_reg <= packed_req_fallback_reg;
      packed_req_k_reg <= packed_req_k_reg;
      packed_req_dst_idx_reg <= packed_req_dst_idx_reg;
      exc_event_valid_reg <= '0';
      exc_event_divzero_reg <= '0';
      exc_event_force_overflow_reg <= '0';
      exc_event_force_underflow_reg <= '0';
      exc_event_force_inexact_reg <= '0';
      exc_event_force_invalid_reg <= '0';
      exc_event_force_bsun_reg <= '0';
      sys_ctrl_save_req_reg <= '0';
      sys_ctrl_restore_req_reg <= '0';

      -- Keep cir_response_reg tracking FSM-based primitives when no
      -- conditional dialog result is pending.
      if cir_response_pending_reg = '0' then
        cir_response_reg <= x"0000" & cir_response_prim;
      end if;

      if packed_result_valid_reg = '1' and packed_pending_reg = '1' then
        if packed_req_mode_reg = PACKED_REQ_DECODE then
          fp_reg_file_reg(packed_req_dst_idx_reg) <= packed_result_fp_reg;
          result_lo_reg <= packed_result_fp_reg(FP80_RESULT_LO_WIDTH-1 downto 0);
          result_hi_reg <= packed_result_fp_reg(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
          result_ex_reg <= packed_result_fp_reg(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
          result_ex_hi_reg <= (others => '0');
          exc_event_valid_reg <= '1';
          exc_event_result_reg <= packed_result_fp_reg;
          exc_event_opa_reg <= packed_result_fp_reg;
          exc_event_opb_reg <= FP80_CLASSIFY_ONE;
          exc_event_force_invalid_reg <= packed_result_invalid_reg;
          result_ready_reg <= '1';
        else
          result_lo_reg <= packed_result_word_reg(31 downto 0);
          result_hi_reg <= packed_result_word_reg(63 downto 32);
          result_ex_reg <= packed_result_word_reg(79 downto 64);
          result_ex_hi_reg <= packed_result_word_reg(95 downto 80);
          exc_event_valid_reg <= '1';
          exc_event_result_reg <= packed_result_fp_reg;
          exc_event_opa_reg <= packed_req_fp_reg;
          exc_event_opb_reg <= FP80_CLASSIFY_ONE;
          exc_event_force_inexact_reg <= packed_result_inexact_reg;
          result_ready_reg <= '1';
        end if;
        packed_pending_reg <= '0';
      end if;

      if bus_read = '1' and addr = ADDR_CIR_RESPONSE then
        cir_response_pending_reg <= '0';
        -- Only clear trap_pending when NOT in the condition-eval pipeline,
        -- otherwise the CIR response read between CIR_COND_EVAL and
        -- CIR_COND_CHECK would race-clear the flag before it is sampled.
        if cir_state_reg /= CIR_COND_WAIT and cir_state_reg /= CIR_COND_CHECK then
          cir_trap_pending_reg <= '0';
        end if;
        cir_protocol_violation_reg <= '0';
      end if;

      -- Detect protocol violation only on the rising edge of an OPSEL write
      -- (opsel_write_prev_reg = '0') to avoid false positives when the host
      -- holds bus_write asserted across multiple clocks.
      if bus_write = '1' and addr = ADDR_OPSEL and
         opsel_write_prev_reg = '0' and
         conditional_prog_op_write = '1' and
         cir_response_pending_reg = '1' then
        cir_protocol_violation_reg <= '1';
      end if;

      if op_issue_pulse = '1' then
        result_ready_reg <= '0';
        result_ex_hi_reg <= (others => '0');
        aux_result_ex_hi_reg <= (others => '0');
        -- Use instruction address from CIR protocol when available.
        if cir_launch_alu = '1' then
          fpiar_issue_snapshot_reg <= cir_instaddr_reg;
        else
          fpiar_issue_snapshot_reg <= fpiar_reg;
        end if;
        micro_active_reg <= '1';

        -- Determine effective op and class for unified dispatch.
        if cir_launch_alu = '1' then
          if cir_instr_type = CIR_TYPE_CPCOND then
            eff_op_sel := FPU_OP_FSCC;
            eff_op_class := OP_CLASS_PROG_CTRL;
          elsif cir_instr_type = CIR_TYPE_CPBCC_W or
                cir_instr_type = CIR_TYPE_CPBCC_L then
            eff_op_sel := FPU_OP_FBCC;
            eff_op_class := OP_CLASS_PROG_CTRL;
          else
            eff_op_sel := cir_decoded_op;
            eff_op_class := op_class(cir_decoded_op);
          end if;
        else
          eff_op_sel := op_sel_write_decoded;
          eff_op_class := op_class_write_decoded;
        end if;

        -- Set last_op_sel_reg, operands, cycle count.
        if cir_launch_alu = '1' then
          last_op_sel_reg <= eff_op_sel;
          if eff_op_class = OP_CLASS_PROG_CTRL then
            -- CIR conditional: condition selector is loaded into operand_reg(0)
            -- by the bus_frame_proc CIR launch block (not here, to avoid
            -- multi-driver conflict on operand_reg).
            total_cycles := 0;
          else
            -- CIR cpGEN: existing cycle count.
            total_cycles := op_cycle_count(
              eff_op_sel,
              FPU_SRC_FPM,
              EA_MODE_DN_AN,
              EA_CYCLE_BEST,
              false,
              false,
              false
            );
            if eff_op_class /= OP_CLASS_MOVE then
              cir_arith_active_reg <= '1';
            end if;
          end if;
        else
          last_op_sel_reg <= eff_op_sel;
          total_cycles := op_cycle_count(
            eff_op_sel,
            src_kind_reg,
            ea_mode_reg,
            cycle_case_reg,
            mc68020_src_reg = '1',
            mc68020_dst_reg = '1',
            packed_dynamic_k_reg = '1'
          );
        end if;

        micro_total_reg <= std_logic_vector(to_unsigned(total_cycles, 32));
        if total_cycles = 0 then
          micro_remaining_reg <= 0;
        else
          micro_remaining_reg <= total_cycles - 1;
        end if;

        -- Dispatch uses operation classes to keep execution paths scalable.
        if cir_launch_alu = '1' and eff_op_class /= OP_CLASS_PROG_CTRL then
          -- CIR cpGEN path: MOVE or ARITH only.
          -- MOVE ops bypass the ALU; defer register file copy via flag.
          if eff_op_class = OP_CLASS_MOVE then
            cir_move_pending_reg <= '1';
          else
            op_start_reg <= '1';
          end if;
        else
        -- Both legacy and CIR conditional paths use unified class dispatch.
        case eff_op_class is
          when OP_CLASS_ARITH =>
            op_start_reg <= '1';
          when OP_CLASS_MOVE =>
            if eff_op_sel = FPU_OP_MOVE then
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
              move_exc_force_invalid := '0';
              move_deferred := '0';

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
                        when "11" =>
                          packed_word := operand_hi16_reg(0) & operand_reg(0);
                          if packed_decimal_full_g then
                            packed_req_mode_reg <= PACKED_REQ_DECODE;
                            packed_req_word_reg <= packed_word;
                            packed_req_fallback_reg <= operand_reg(0);
                            packed_req_dst_idx_reg <= dst_idx;
                            packed_req_start_reg <= '1';
                            packed_pending_reg <= '1';
                            move_deferred := '1';
                          else
                            if packed96_has_invalid_bcd(packed_word) then
                              move_exc_force_invalid := '1';
                            end if;
                            move_result := packed96_to_fp80_fast(packed_word, operand_reg(0));
                            move_exc_enable := '1';
                            move_exc_result := move_result;
                            move_exc_opa := move_result;
                          end if;
                        when others =>
                          move_result := operand_reg(0);
                          move_exc_enable := '1';
                          move_exc_result := move_result;
                          move_exc_opa := move_result;
                      end case;
                    end if;
                    if move_deferred = '0' then
                      fp_reg_file_reg(dst_idx) <= move_result;
                    end if;
                  when MOVE_CFG_MODE_REG_TO_MEM =>
                    move_result := fp_reg_file_reg(src_idx);
                    move_exc_opa := move_result;
                    if move_cfg.reg_to_mem_packed = '1' then
                      if packed_decimal_full_g then
                        if move_cfg.packed_k_from_opa = '1' then
                          packed_k := signed8_to_integer(operand_reg(0)(7 downto 0));
                        else
                          packed_k := signed8_to_integer(operand_reg(1)(7 downto 0));
                        end if;
                        packed_req_mode_reg <= PACKED_REQ_ENCODE;
                        packed_req_fp_reg <= move_result;
                        packed_req_k_reg <= clamp_integer(packed_k, -64, 17);
                        packed_req_start_reg <= '1';
                        packed_pending_reg <= '1';
                        move_deferred := '1';
                      else
                        packed_word := fp80_to_packed96_fast(move_result);
                        move_exc_enable := '0';
                      end if;
                      if move_deferred = '0' then
                        result_lo_reg <= packed_word(31 downto 0);
                        result_hi_reg <= packed_word(63 downto 32);
                        result_ex_reg <= packed_word(79 downto 64);
                        result_ex_hi_reg <= packed_word(95 downto 80);
                      end if;
                    else
                      case mem_fmt is
                        when "01" =>
                          single_bits := conv_single_out;
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
                          result_ex_hi_reg <= (others => '0');
                        when "10" =>
                          double_bits := conv_double_out;
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
                          result_ex_hi_reg <= (others => '0');
                        when others =>
                          result_lo_reg <= move_result(FP80_RESULT_LO_WIDTH-1 downto 0);
                          result_hi_reg <= move_result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
                          result_ex_reg <= move_result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
                          result_ex_hi_reg <= (others => '0');
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

              if mode /= MOVE_CFG_MODE_REG_TO_MEM and move_deferred = '0' then
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
                exc_event_force_invalid_reg <= move_exc_force_invalid;
              end if;
              if move_deferred = '0' then
                result_ready_reg <= '1';
              end if;
            elsif eff_op_sel = FPU_OP_MOVEM then
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
            bsun_event := '0';
            trap_requested := '0';
            branch_taken := '0';
            decrement_taken := '0';
            counter_expired := '0';

            -- CIR conditional path: read condition from cir_condition_reg
            -- (already stable). Legacy path: read from operand_reg(0).
            -- This avoids a signal scheduling issue where bus_frame_proc
            -- assigns operand_reg(0) on this same rising_edge, but the
            -- new value is not visible until the next delta cycle (so
            -- alu_control_proc would read the stale pre-assignment value).
            if cir_launch_alu = '1' then
              cond_selector := cir_condition_reg;
            else
              cond_selector := operand_reg(0)(5 downto 0);
            end if;

            if eff_op_sel = FPU_OP_FSCC then
              cc_field := fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN);
              signaling_cond := is_signaling_fcc_condition(cond_selector);
              cond_true := eval_fcc_condition(cond_selector, cc_field);
              if signaling_cond and cc_field(0) = '1' then
                bsun_event := '1';
                cond_true := '0';
              end if;
              if cond_true = '1' and bsun_event = '0' then
                prog_result(7 downto 0) := x"FF";
              end if;
              cir_response_word(0) := cond_true;
              cir_response_word(4) := bsun_event;
            elsif eff_op_sel = FPU_OP_FBCC then
              cc_field := fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN);
              signaling_cond := is_signaling_fcc_condition(cond_selector);
              cond_true := eval_fcc_condition(cond_selector, cc_field);
              if signaling_cond and cc_field(0) = '1' then
                bsun_event := '1';
                cond_true := '0';
              end if;
              branch_taken := cond_true;
              cir_response_word(0) := cond_true;
              cir_response_word(1) := branch_taken;
              cir_response_word(4) := bsun_event;
              prog_result := cir_response_word;
            elsif eff_op_sel = FPU_OP_FDBCC then
              cc_field := fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN);
              signaling_cond := is_signaling_fcc_condition(cond_selector);
              cond_true := eval_fcc_condition(cond_selector, cc_field);
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
            elsif eff_op_sel = FPU_OP_FTRAPCC then
              cc_field := fpsr_reg(FPSR_CC_NEG downto FPSR_CC_NAN);
              signaling_cond := is_signaling_fcc_condition(cond_selector);
              cond_true := eval_fcc_condition(cond_selector, cc_field);
              if signaling_cond and cc_field(0) = '1' then
                bsun_event := '1';
                cond_true := '0';
              end if;
              -- FTRAPcc: trap when condition is true (primary action)
              if cond_true = '1' then
                trap_requested := '1';
              end if;
              cir_response_word(0) := cond_true;
              cir_response_word(4) := bsun_event;
            end if;

            if eff_op_sel = FPU_OP_FSCC or
               eff_op_sel = FPU_OP_FBCC or
               eff_op_sel = FPU_OP_FDBCC or
               eff_op_sel = FPU_OP_FTRAPCC then
              if bsun_event = '1' and fpcr_reg(FPCR_EXC_EN_BSUN) = '1' then
                trap_requested := '1';
              end if;
              cir_response_word(5) := trap_requested;
              if eff_op_sel /= FPU_OP_FSCC then
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
              cir_response_reg <= cir_response_word;
            end if;

            result_lo_reg <= prog_result;
            result_ready_reg <= '1';
          when OP_CLASS_SYS_CTRL =>
            if eff_op_sel = FPU_OP_FSAVE then
              sys_ctrl_save_req_reg <= '1';
              frame_op_waiting_reg <= '1';
            elsif eff_op_sel = FPU_OP_FRESTORE then
              sys_ctrl_restore_req_reg <= '1';
              frame_op_waiting_reg <= '1';
            else
              result_ready_reg <= '1';
            end if;
          when others =>
            result_ready_reg <= '1';
        end case;
        end if;  -- cir_launch_alu / unified dispatch
      end if;

      if valid = '1' then
        result_lo_reg <= result(FP80_RESULT_LO_WIDTH-1 downto 0);
        result_hi_reg <= result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
        result_ex_reg <= result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
        -- CIR: write ALU result to destination FP register.
        -- Gate writeback for compare/test ops that only update condition codes.
        if cir_arith_active_reg = '1' then
          if last_op_sel_reg /= FPU_OP_CMP and last_op_sel_reg /= FPU_OP_TST then
            fp_reg_file_reg(cir_dst_reg_idx) <= result;
          end if;
          cir_arith_active_reg <= '0';
          -- No exc_event needed: the ALU valid path in bus_frame_proc
          -- already runs exc_classification with the correct operands
          -- (operand_reg(0/1)) and result on this same clock edge.
        end if;
        if aux_valid = '1' then
          aux_result_lo_reg <= aux_result(FP80_RESULT_LO_WIDTH-1 downto 0);
          aux_result_hi_reg <= aux_result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
          aux_result_ex_reg <= aux_result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
        end if;
        result_ready_reg <= '1';
      end if;

      -- CIR FMOVE deferred copy: operand_reg(1) now holds the converted
      -- source value (set by bus_frame_proc on the previous edge).  Copy it
      -- to the destination FP register and mark result ready.
      if cir_move_pending_reg = '1' then
        fp_reg_file_reg(cir_dst_reg_idx) <= operand_reg(1);
        result_lo_reg <= operand_reg(1)(FP80_RESULT_LO_WIDTH-1 downto 0);
        result_hi_reg <= operand_reg(1)(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1
                                        downto FP80_RESULT_LO_WIDTH);
        result_ex_reg <= operand_reg(1)(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
        result_ready_reg <= '1';
        -- Trigger exception classification for the moved value.
        exc_event_valid_reg <= '1';
        exc_event_result_reg <= operand_reg(1);
        exc_event_opa_reg <= operand_reg(1);
        exc_event_opb_reg <= FP80_CLASSIFY_ONE;
        cir_move_pending_reg <= '0';
      end if;

      -- Frame-op completion: wait for frame_busy to go high then return low.
      -- The sys_ctrl_*_req guard prevents false completion before bus_frame_proc
      -- has started the frame op (see timing proof in plan).
      if frame_op_waiting_reg = '1'
         and frame_busy_reg = '0'
         and sys_ctrl_save_req_reg = '0'
         and sys_ctrl_restore_req_reg = '0' then
        result_ready_reg <= '1';
        frame_op_waiting_reg <= '0';
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
    result_ex_hi_reg,
    aux_result_lo_reg,
    aux_result_hi_reg,
    aux_result_ex_reg,
    aux_result_ex_hi_reg,
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
    cir_protocol_violation_reg,
    cir_state_reg,
    cir_xfer_word_idx,
    cir_operand_staging,
    frame_format_word_reg,
    cir_save_word_idx,
    op_sel_reg,
    operand_reg,
    alu_save_data,
    packed_save_data
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
        when ADDR_RES_H =>
          if cir_state_reg = CIR_XFER_DST or cir_state_reg = CIR_XFER_DST_WAIT then
            -- CIR Operand read: return current word from staging.
            case cir_xfer_word_idx is
              when 0 => d_out_comb <= cir_operand_staging(31 downto 0);
              when 1 => d_out_comb <= cir_operand_staging(63 downto 32);
              when 2 => d_out_comb <= cir_operand_staging(95 downto 64);
              when others => d_out_comb <= (others => '0');
            end case;
          elsif cir_state_reg = CIR_SAVE_FRAME then
            -- FSAVE frame data read: return idle frame word by index.
            case cir_save_word_idx is
              when 0 =>
                -- Frame version tag (upper 16) + internal flags (lower 16).
                d_out_comb <= x"0001" & x"0000";  -- Version 1, no flags
              when 1 =>
                -- Last operation selector + class encoding.
                d_out_comb(15 downto 0) <= std_logic_vector(to_unsigned(
                  fpu_op_t'pos(op_sel_reg), 16));
                d_out_comb(31 downto 16) <= std_logic_vector(to_unsigned(
                  fpu_op_class_t'pos(op_class(op_sel_reg)), 16));
              when 2 =>
                -- Exception event state (packed FPSR EXC + AEXC).
                d_out_comb <= fpsr_reg;
              when 3 =>
                -- Microsequencer state (cycle counter).
                d_out_comb <= micro_total_reg;
              when 4 =>
                -- CIR dialog flags.
                d_out_comb <= (others => '0');
              when 5 =>
                -- Reserved.
                d_out_comb <= (others => '0');
              -- Busy frame words 6-44 (only present for Busy format).
              when 6 =>
                -- Operand A lower 32 bits.
                d_out_comb <= std_logic_vector(operand_reg(0)(31 downto 0));
              when 7 =>
                -- Operand A upper 48 bits (packed: [47:32] in [15:0], [79:64] in [31:16]).
                d_out_comb <= std_logic_vector(operand_reg(0)(79 downto 64)) &
                              std_logic_vector(operand_reg(0)(63 downto 48));
              when 8 =>
                -- Operand B lower 32 bits.
                d_out_comb <= std_logic_vector(operand_reg(1)(31 downto 0));
              when 9 =>
                -- Operand B upper 48 bits.
                d_out_comb <= std_logic_vector(operand_reg(1)(79 downto 64)) &
                              std_logic_vector(operand_reg(1)(63 downto 48));
              when 10 =>
                -- Operand A middle 32 bits.
                d_out_comb <= std_logic_vector(operand_reg(0)(63 downto 32));
              when 11 =>
                -- Operand B middle 32 bits.
                d_out_comb <= std_logic_vector(operand_reg(1)(63 downto 32));
              when 12 to 37 =>
                -- ALU + sub-unit save data (26 words: ALU 0-4, trig 5-15, divrem 16-25).
                d_out_comb <= alu_save_data;
              when 38 to 40 =>
                -- Packed decimal save data (words 0..2).
                d_out_comb <= packed_save_data;
              when others =>
                -- Padding (words 41-44).
                d_out_comb <= (others => '0');
            end case;
          else
            d_out_comb <= result_hi_reg;
          end if;
        when ADDR_RES_E =>
          d_out_comb(FP80_RESULT_EX_WIDTH-1 downto 0) <= result_ex_reg;
          d_out_comb(31 downto 16) <= result_ex_hi_reg;
        when ADDR_AUX_RES_L => d_out_comb <= aux_result_lo_reg;
        when ADDR_AUX_RES_H => d_out_comb <= aux_result_hi_reg;
        when ADDR_AUX_RES_E =>
          d_out_comb(FP80_RESULT_EX_WIDTH-1 downto 0) <= aux_result_ex_reg;
          d_out_comb(31 downto 16) <= aux_result_ex_hi_reg;
        when ADDR_STATUS =>
          -- STATUS register layout:
          --   Bit 0: valid (result ready)
          --   Bit 1: busy (engine active)
          --   Bit 2: frame_valid (save frame ready)
          --   Bit 3: frame_busy (save/restore in progress)
          --   Bit 4: cir_response_pending
          --   Bit 5: cir_protocol_violation
          --   Bit 6: cir_trap_pending
          d_out_comb(0) <= status_valid_reg;
          d_out_comb(1) <= status_busy_reg;
          d_out_comb(2) <= status_frame_valid_reg;
          d_out_comb(3) <= status_frame_busy_reg;
          d_out_comb(4) <= cir_response_pending_reg;
          d_out_comb(5) <= cir_protocol_violation_reg;
          d_out_comb(6) <= cir_trap_pending_reg;
        when ADDR_CIR_SAVE =>
          -- FSAVE format word (16-bit in lower half).
          d_out_comb <= x"0000" & frame_format_word_reg;
        when ADDR_CIR_RESPONSE =>
          d_out_comb <= cir_response_reg;
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
      if sync_read = '1' and start_access = '1' and dsack_state = DSACK_IDLE then
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

  -- =====================================================================
  -- Section 7 CIR Dialog Processes
  -- =====================================================================

  -- CIR register write handler — latches OpWord, Command, Condition, etc.
  cir_write_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      cir_opword_reg <= (others => '0');
      cir_command_reg <= (others => '0');
      cir_condition_reg <= (others => '0');
      cir_instr_type <= (others => '0');
      cir_src_fmt <= (others => '0');
      cir_dst_reg_idx <= 0;
      cir_src_reg_idx <= 0;
      cir_reg_to_reg <= '0';
      cir_direction <= '0';
      cir_opword_written <= '0';
      cir_command_written <= '0';
      cir_condition_written <= '0';
      cir_control_ack <= '0';
      cir_operand_staging <= (others => '0');
      cir_operand_word_arrived <= '0';
      cir_operand_read_done <= '0';
      cir_operand_read_prev <= '0';
      cir_operand_write_prev <= '0';
      cir_save_read_done <= '0';
      cir_save_read_prev <= '0';
      cir_instaddr_reg <= (others => '0');
      cir_frame_data_reg <= (others => (others => '0'));
    elsif rising_edge(clk) then
      -- Clear one-shot flags
      cir_control_ack <= '0';
      cir_operand_word_arrived <= '0';
      cir_operand_read_done <= '0';
      cir_save_read_done <= '0';

      -- Clear written flags when FSM consumes them (BEFORE bus_write handling
      -- so a fresh write in the same cycle takes priority over the clear).
      if cir_state_reg /= CIR_IDLE or cir_flags_consumed = '1' then
        cir_opword_written <= '0';
        cir_command_written <= '0';
        cir_condition_written <= '0';
      end if;

      -- Edge-detect register for operand writes (prevents multi-pulse from
      -- a single bus transaction that holds strobes active across clocks).
      if bus_write = '1' and addr = CIR_ADDR_OPERAND then
        cir_operand_write_prev <= '1';
      else
        cir_operand_write_prev <= '0';
      end if;

      -- Edge-detect for Save CIR reads (format word read during cpSAVE).
      if bus_read = '1' and addr = ADDR_CIR_SAVE then
        cir_save_read_prev <= '1';
      else
        cir_save_read_prev <= '0';
      end if;

      -- Detect host read of Save CIR during FSAVE format-word phase.
      if bus_read = '1' and addr = ADDR_CIR_SAVE
         and cir_save_read_prev = '0'
         and cir_state_reg = CIR_SAVE_FORMAT then
        cir_save_read_done <= '1';
      end if;

      -- Edge-detect for Operand CIR reads (prevents multi-pulse from sustained bus strobe).
      if bus_read = '1' and addr = CIR_ADDR_OPERAND then
        cir_operand_read_prev <= '1';
      else
        cir_operand_read_prev <= '0';
      end if;

      -- Detect host read of Operand CIR during destination transfer or FSAVE frame.
      if bus_read = '1' and addr = CIR_ADDR_OPERAND
         and cir_operand_read_prev = '0'
         and (cir_state_reg = CIR_XFER_DST or cir_state_reg = CIR_SAVE_FRAME) then
        cir_operand_read_done <= '1';
      end if;

      if bus_write = '1' then
        case addr is
          when CIR_ADDR_OPWORD =>
            cir_opword_reg <= d_in(15 downto 0);
            cir_instr_type <= d_in(8 downto 6);
            cir_opword_written <= '1';

          when CIR_ADDR_COMMAND =>
            cir_command_reg <= d_in(15 downto 0);
            cir_src_fmt <= d_in(12 downto 10);
            cir_dst_reg_idx <= to_integer(unsigned(d_in(9 downto 7)));
            cir_src_reg_idx <= to_integer(unsigned(d_in(12 downto 10)));
            cir_reg_to_reg <= d_in(14);
            cir_direction <= d_in(13);
            cir_command_written <= '1';

          when CIR_ADDR_CONDITION =>
            cir_condition_reg <= d_in(5 downto 0);
            cir_condition_written <= '1';

          when CIR_ADDR_OPERAND =>
            -- Store operand word during source transfer.
            -- Edge-detect: only pulse on rising edge of bus_write to this addr
            -- to prevent multi-pulse from a sustained bus strobe.
            if cir_state_reg = CIR_XFER_SRC and cir_operand_write_prev = '0' then
              case cir_xfer_word_idx is
                when 0 => cir_operand_staging(31 downto 0) <= d_in;
                when 1 => cir_operand_staging(63 downto 32) <= d_in;
                when 2 => cir_operand_staging(95 downto 64) <= d_in;
                when others => null;
              end case;
              cir_operand_word_arrived <= '1';
            end if;
            -- Store frame data word during FRESTORE frame transfer.
            if cir_state_reg = CIR_RESTORE_FRAME and cir_operand_write_prev = '0' then
              if cir_restore_word_idx < CIR_FRAME_BUSY_HDR then
                cir_frame_data_reg(cir_restore_word_idx) <= d_in;
              end if;
              -- Capture incoming word for sub-unit restore routing.
              cir_restore_word_data <= d_in;
              cir_operand_word_arrived <= '1';
            end if;

          when CIR_ADDR_INSTADDR =>
            -- Capture CPU's instruction PC for FPIAR.
            cir_instaddr_reg <= d_in;

          when CIR_ADDR_CONTROL =>
            cir_control_ack <= d_in(0);

          when others =>
            null;
        end case;
      end if;

      -- (Flag clearing moved above bus_write handling for cpSAVE preemption.)

      -- Fill operand staging for reg→mem transfer when FSM enters CIR_XFER_DST.
      -- The dialog proc transitions to CIR_XFER_DST from CIR_DECODE; we detect
      -- that transition on the next edge (CIR_XFER_DST with word_idx=0).
      if cir_state_reg = CIR_XFER_DST and cir_xfer_word_idx = 0
         and cir_operand_read_done = '0' then
        -- Convert FP register to destination format and pack into staging.
        -- cir_dst_reg_idx = source FP register (bits[9:7] of command word).
        -- cir_src_fmt = destination memory format (bits[12:10]).
        case cir_src_fmt is
          when CIR_SRC_SINGLE =>
            cir_operand_staging(31 downto 0) <= conv_single_out;
          when CIR_SRC_LONG =>
            cir_operand_staging(31 downto 0) <=
              std_logic_vector(to_signed(
                fp80_to_int_trunc(fp_reg_file_reg(cir_dst_reg_idx)), 32));
          when CIR_SRC_WORD =>
            cir_operand_staging(31 downto 0) <= x"0000" &
              std_logic_vector(to_signed(
                fp80_to_int_trunc(fp_reg_file_reg(cir_dst_reg_idx)), 16));
          when CIR_SRC_BYTE =>
            cir_operand_staging(31 downto 0) <= x"000000" &
              std_logic_vector(to_signed(
                fp80_to_int_trunc(fp_reg_file_reg(cir_dst_reg_idx)), 8));
          when CIR_SRC_DOUBLE =>
            -- Double: word 0 = upper 32, word 1 = lower 32
            cir_operand_staging(63 downto 0) <= conv_double_out;
          when CIR_SRC_EXTENDED =>
            -- Extended: word 0[15:0]=sign+exp, word 1=mant_hi, word 2=mant_lo
            cir_operand_staging(15 downto 0) <=
              fp_reg_file_reg(cir_dst_reg_idx)(79 downto 64);
            cir_operand_staging(63 downto 32) <=
              fp_reg_file_reg(cir_dst_reg_idx)(63 downto 32);
            cir_operand_staging(95 downto 64) <=
              fp_reg_file_reg(cir_dst_reg_idx)(31 downto 0);
          when others =>
            cir_operand_staging <= (others => '0');
        end case;
      end if;
    end if;
  end process;

  -- CIR dialog state machine — drives FSM state transitions.
  cir_dialog_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      cir_state_reg <= CIR_IDLE;
      cir_xfer_word_idx <= 0;
      cir_xfer_word_count <= 0;
      cir_launch_alu <= '0';
      cir_flags_consumed <= '0';
      cir_restore_null_req <= '0';
      cir_restore_commit_req <= '0';
      alu_save_req_reg <= '0';
      alu_restore_req_reg <= '0';
      alu_restore_wr_reg <= '0';
      packed_restore_wr <= '0';
      cir_exc_vector <= (others => '0');
    elsif rising_edge(clk) then
      cir_launch_alu <= '0';  -- default: clear one-shot pulse
      cir_flags_consumed <= '0';
      cir_restore_null_req <= '0';
      cir_restore_commit_req <= '0';
      alu_save_req_reg <= '0';
      alu_restore_wr_reg <= '0';
      packed_restore_wr <= '0';

      case cir_state_reg is

        when CIR_IDLE =>
          -- cpGEN: wait for both OpWord + Command
          if cir_opword_written = '1' and cir_command_written = '1' and
             (cir_instr_type = CIR_TYPE_CPGEN) then
            cir_state_reg <= CIR_DECODE;
          end if;
          -- cpBcc/cpScc: wait for OpWord + Condition write
          if cir_opword_written = '1' and cir_condition_written = '1' and
             (cir_instr_type = CIR_TYPE_CPCOND or
              cir_instr_type = CIR_TYPE_CPBCC_W or
              cir_instr_type = CIR_TYPE_CPBCC_L) then
            cir_state_reg <= CIR_COND_EVAL;
          end if;
          -- cpSAVE: trigger frame capture via handshake
          if cir_opword_written = '1' and cir_instr_type = CIR_TYPE_CPSAVE then
            cir_save_req <= '1';
            cir_state_reg <= CIR_SAVE_WAIT;
          end if;
          -- cpRESTORE: request format word from CPU
          if cir_opword_written = '1' and cir_instr_type = CIR_TYPE_CPRESTORE then
            cir_restore_word_idx <= 0;
            cir_state_reg <= CIR_RESTORE_FORMAT;
          end if;
          -- Catch-all: clear stale flags for undefined instruction types
          -- ("110"/"111") to prevent them from blocking future operations.
          if cir_opword_written = '1' and
             cir_instr_type /= CIR_TYPE_CPGEN and
             cir_instr_type /= CIR_TYPE_CPCOND and
             cir_instr_type /= CIR_TYPE_CPBCC_W and
             cir_instr_type /= CIR_TYPE_CPBCC_L and
             cir_instr_type /= CIR_TYPE_CPSAVE and
             cir_instr_type /= CIR_TYPE_CPRESTORE then
            cir_flags_consumed <= '1';
          end if;

        when CIR_DECODE =>
          if cir_reg_to_reg = '1' then
            -- Register-to-register: launch ALU and go to execute.
            -- MOVE ops bypass the ALU, so go directly to IDLE.
            cir_launch_alu <= '1';
            if op_class(cir_decoded_op) = OP_CLASS_MOVE then
              cir_state_reg <= CIR_IDLE;
            else
              cir_state_reg <= CIR_EXECUTE;
            end if;
          elsif cir_direction = '1' then
            -- Register→memory (FMOVE FPn,<ea>): convert and present data.
            -- cir_dst_reg_idx holds the source FP register (bits[9:7]).
            -- cir_src_fmt holds the destination memory format (bits[12:10]).
            cir_xfer_word_count <= cir_src_word_count(cir_src_fmt);
            cir_xfer_word_idx <= 0;
            cir_state_reg <= CIR_XFER_DST;
          else
            -- Memory→register: request operand transfer from host.
            cir_xfer_word_count <= cir_src_word_count(cir_src_fmt);
            cir_xfer_word_idx <= 0;
            cir_state_reg <= CIR_XFER_SRC;
          end if;

        when CIR_XFER_SRC =>
          -- Wait for host to write operand words via Operand CIR.
          -- cir_operand_word_arrived is pulsed by the bus write process.
          if cir_operand_word_arrived = '1' then
            if cir_xfer_word_idx + 1 >= cir_xfer_word_count then
              -- All words received: launch ALU with converted operand.
              -- MOVE ops bypass the ALU, so go directly to IDLE.
              cir_launch_alu <= '1';
              cir_xfer_word_idx <= cir_xfer_word_idx + 1;
              if op_class(cir_decoded_op) = OP_CLASS_MOVE then
                cir_state_reg <= CIR_IDLE;
              else
                cir_state_reg <= CIR_EXECUTE;
              end if;
            else
              cir_xfer_word_idx <= cir_xfer_word_idx + 1;
            end if;
          end if;

        when CIR_XFER_SRC_WAIT =>
          null;  -- Reserved for multi-cycle format conversion

        when CIR_EXECUTE =>
          -- Wait for ALU completion. Go to CIR_EXECUTE_DONE so that
          -- bus_frame_proc has time to update fpsr_reg with exception flags
          -- (VHDL signal semantics: same-edge write not visible until next cycle).
          if valid = '1' then
            cir_state_reg <= CIR_EXECUTE_DONE;
          end if;
          -- cpSAVE preemption: allow FSAVE to suspend an in-progress computation.
          if cir_opword_written = '1' and cir_instr_type = CIR_TYPE_CPSAVE then
            cir_save_req <= '1';
            cir_state_reg <= CIR_SAVE_WAIT;
          end if;

        when CIR_EXECUTE_DONE =>
          -- FPSR EXC byte is now stable. Check FPCR exception enables.
          -- Priority (highest first): INVALID > OVERFLOW > UNDERFLOW > DIVZERO > INEXACT.
          -- NOTE: INVALID always maps to CIR_VEC_SNAN (vector 54). The real MC68881
          -- distinguishes SNAN (vector 54) from OPERR (vector 52) based on whether
          -- the invalid was from an SNaN input vs a domain error. This is a known
          -- deviation; a future refinement could inspect operand signaling bits.
          if fpsr_reg(FPSR_EXC_LSB + FPSR_EXC_INVALID) = '1' and
             fpcr_reg(FPCR_EXC_EN_INVALID) = '1' then
            cir_exc_vector <= CIR_VEC_SNAN;
            cir_state_reg <= CIR_EXCEPT_POST;
          elsif fpsr_reg(FPSR_EXC_LSB + FPSR_EXC_OVERFLOW) = '1' and
                fpcr_reg(FPCR_EXC_EN_OVERFLOW) = '1' then
            cir_exc_vector <= CIR_VEC_OVERFL;
            cir_state_reg <= CIR_EXCEPT_POST;
          elsif fpsr_reg(FPSR_EXC_LSB + FPSR_EXC_UNDERFLOW) = '1' and
                fpcr_reg(FPCR_EXC_EN_UNDERFLOW) = '1' then
            cir_exc_vector <= CIR_VEC_UNDERFL;
            cir_state_reg <= CIR_EXCEPT_POST;
          elsif fpsr_reg(FPSR_EXC_LSB + FPSR_EXC_DIVZERO) = '1' and
                fpcr_reg(FPCR_EXC_EN_DIVZERO) = '1' then
            cir_exc_vector <= CIR_VEC_DIVZERO;
            cir_state_reg <= CIR_EXCEPT_POST;
          elsif fpsr_reg(FPSR_EXC_LSB + FPSR_EXC_INEXACT) = '1' and
                fpcr_reg(FPCR_EXC_EN_INEXACT) = '1' then
            cir_exc_vector <= CIR_VEC_INEXACT;
            cir_state_reg <= CIR_EXCEPT_POST;
          else
            cir_state_reg <= CIR_IDLE;
          end if;

        when CIR_XFER_DST =>
          -- Host reads operand words via CIR_ADDR_OPERAND.
          if cir_operand_read_done = '1' then
            if cir_xfer_word_idx + 1 >= cir_xfer_word_count then
              -- Hold state one extra cycle so d_out_comb returns staging
              -- data through the dsack assertion window.  Don't increment
              -- word_idx so the mux continues returning the correct word.
              cir_state_reg <= CIR_XFER_DST_WAIT;
            else
              cir_xfer_word_idx <= cir_xfer_word_idx + 1;
            end if;
          end if;

        when CIR_XFER_DST_WAIT =>
          cir_state_reg <= CIR_IDLE;

        when CIR_COND_EVAL =>
          -- Launch condition evaluation through alu_control_proc.
          -- PROG_CTRL ops complete combinationally within op_issue_pulse.
          -- Go to CIR_COND_WAIT so cir_trap_pending_reg (set by alu_control_proc
          -- on this same edge) is visible on the next cycle.
          cir_launch_alu <= '1';
          cir_state_reg <= CIR_COND_WAIT;

        when CIR_COND_WAIT =>
          -- alu_control_proc processes the launch on this cycle and sets
          -- cir_trap_pending_reg. The new value isn't visible until next cycle.
          cir_state_reg <= CIR_COND_CHECK;

        when CIR_COND_CHECK =>
          -- Now cir_trap_pending_reg from alu_control_proc is stable.
          -- FTRAPcc traps are handled by the CPU in CIR mode — the FPU just
          -- reports cond_true in the response word.
          if cir_trap_pending_reg = '1' then
            cir_exc_vector <= CIR_VEC_BSUN;
            cir_state_reg <= CIR_EXCEPT_PRE;
          else
            cir_state_reg <= CIR_IDLE;
          end if;

        when CIR_EXCEPT_PRE =>
          if cir_control_ack = '1' then
            cir_state_reg <= CIR_IDLE;
          end if;

        when CIR_EXCEPT_MID =>
          if cir_control_ack = '1' then
            cir_state_reg <= CIR_IDLE;
          end if;

        when CIR_EXCEPT_POST =>
          if cir_control_ack = '1' then
            cir_state_reg <= CIR_IDLE;
          end if;

        when CIR_SAVE_WAIT =>
          -- Wait one cycle for frame type determination, then present format word.
          -- Determine frame type from fpu_initialized_reg and ALU busy state.
          if fpu_initialized_reg = '0' then
            frame_format_word_reg <= CIR_FRAME_NULL_FW;
            cir_save_word_idx <= 0;
            cir_xfer_word_count <= 0;  -- Null: 0 data words
          elsif busy = '1' then
            frame_format_word_reg <= CIR_FRAME_BUSY_FW;
            cir_save_word_idx <= 0;
            cir_xfer_word_count <= CIR_FRAME_BUSY_WORDS;  -- Busy: 45 data words
            alu_save_req_reg <= '1';  -- Trigger sub-unit state snapshot
          else
            frame_format_word_reg <= CIR_FRAME_IDLE_FW;
            cir_save_word_idx <= 0;
            cir_xfer_word_count <= CIR_FRAME_IDLE_WORDS;  -- Idle: 6 data words
          end if;
          cir_save_req <= '0';
          cir_state_reg <= CIR_SAVE_FORMAT;

        when CIR_SAVE_FORMAT =>
          -- Format word ready in frame_format_word_reg. Wait for host to read
          -- Save CIR (ADDR_CIR_SAVE). On read: advance to frame or complete.
          if cir_save_read_done = '1' then
            if cir_xfer_word_count = 0 then
              -- Null frame: no data words to transfer.
              cir_state_reg <= CIR_IDLE;
            else
              cir_state_reg <= CIR_SAVE_FRAME;
            end if;
          end if;

        when CIR_SAVE_FRAME =>
          -- Host reads Operand CIR (ADDR_RES_H / CIR_ADDR_OPERAND) word by word.
          -- cir_operand_read_done pulses on each read.
          if cir_operand_read_done = '1' then
            if cir_save_word_idx + 1 >= cir_xfer_word_count then
              -- All frame words transferred. Hold one extra cycle for read window.
              cir_state_reg <= CIR_XFER_DST_WAIT;
            else
              cir_save_word_idx <= cir_save_word_idx + 1;
            end if;
          end if;

        when CIR_RESTORE_FORMAT =>
          -- Wait for host to write format word to Restore CIR (ADDR_CIR_RESTORE).
          -- cir_restore_trigger pulses on write.
          if cir_restore_trigger = '1' then
            if cir_restore_fw_reg(15 downto 0) = CIR_FRAME_NULL_FW then
              -- Null frame: reset FPU to power-on state, no data follows.
              cir_restore_null_req <= '1';
              cir_state_reg <= CIR_IDLE;
            elsif cir_restore_fw_reg(15 downto 0) = CIR_FRAME_IDLE_FW then
              -- Idle frame: expect 6 data words.
              cir_restore_word_idx <= 0;
              cir_xfer_word_count <= CIR_FRAME_IDLE_WORDS;
              cir_state_reg <= CIR_RESTORE_FRAME;
            elsif cir_restore_fw_reg(15 downto 0) = CIR_FRAME_BUSY_FW then
              -- Busy frame: expect 45 data words (Task 15).
              cir_restore_word_idx <= 0;
              cir_xfer_word_count <= CIR_FRAME_BUSY_WORDS;
              alu_restore_req_reg <= '1';  -- Hold high for sub-unit restore gating
              cir_state_reg <= CIR_RESTORE_FRAME;
            else
              -- Invalid format word: Pre-Instruction Exception.
              cir_exc_vector <= CIR_VEC_FORMAT;  -- Format error vector ($0E = 14)
              cir_state_reg <= CIR_EXCEPT_PRE;
            end if;
          end if;

        when CIR_RESTORE_FRAME =>
          -- Host writes frame data words to Operand CIR.
          if cir_operand_word_arrived = '1' then
            -- Route incoming word to appropriate sub-unit restore port.
            if cir_restore_word_idx >= 12 and cir_restore_word_idx <= 37 then
              alu_restore_wr_reg <= '1';  -- ALU + trig + divrem + modrem_post (26 words)
            elsif cir_restore_word_idx >= 38 and cir_restore_word_idx <= 40 then
              packed_restore_wr <= '1';   -- Packed decimal (3 words)
            end if;
            if cir_restore_word_idx + 1 >= cir_xfer_word_count then
              -- All frame words received. Request commit via bus_frame_proc.
              cir_restore_commit_req <= '1';
              alu_restore_req_reg <= '0';
              cir_state_reg <= CIR_IDLE;
            else
              cir_restore_word_idx <= cir_restore_word_idx + 1;
            end if;
          end if;

      end case;
    end if;
  end process;

  -- Combinational response primitive generation from FSM state.
  cir_response_gen : process(cir_state_reg, cir_xfer_word_count, cir_exc_vector)
  begin
    case cir_state_reg is
      when CIR_IDLE =>
        cir_response_prim <= CIR_PRIM_NULL;
      when CIR_DECODE =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_EXECUTE =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_EXECUTE_DONE =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_XFER_SRC =>
        -- Transfer Operand to-CP: [15:13]=011, [12]=1, [7:0]=byte count
        cir_response_prim <= "0111" & "0000" &
          std_logic_vector(to_unsigned(cir_xfer_word_count * 4, 8));
      when CIR_XFER_SRC_WAIT =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_XFER_DST =>
        -- Transfer Operand from-CP: [15:13]=011, [12]=0, [7:0]=byte count
        cir_response_prim <= "0110" & "0000" &
          std_logic_vector(to_unsigned(cir_xfer_word_count * 4, 8));
      when CIR_XFER_DST_WAIT =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_COND_EVAL =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_COND_WAIT =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_COND_CHECK =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_EXCEPT_PRE =>
        cir_response_prim <= CIR_RESP_EXCEPT_PRE & "0" & "00" & cir_exc_vector;
      when CIR_EXCEPT_MID =>
        cir_response_prim <= CIR_RESP_EXCEPT_MID & "0" & "00" & cir_exc_vector;
      when CIR_EXCEPT_POST =>
        cir_response_prim <= CIR_RESP_EXCEPT_POST & "0" & "00" & cir_exc_vector;
      when CIR_SAVE_WAIT =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_SAVE_FORMAT | CIR_SAVE_FRAME =>
        cir_response_prim <= CIR_PRIM_BUSY;
      when CIR_RESTORE_FORMAT | CIR_RESTORE_FRAME =>
        cir_response_prim <= CIR_PRIM_BUSY;
    end case;
  end process;

  -- CIR reads use a registered data path; other reads are combinational.
  d_out <= d_out_reg when sync_read = '1' else d_out_comb;
  dsack0_n <= dsack0_i;
  dsack1_n <= dsack1_i;
  sense_drive <= '0' when status_busy_reg = '1' else '1';
  sense_n  <= sense_drive;
end architecture rtl;
