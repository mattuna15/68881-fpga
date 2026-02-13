library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mc68881_pkg is
  constant FP_WIDTH : natural := 80;
  constant FP_EXP_WIDTH : natural := 15;
  constant FP_FRAC_WIDTH : natural := 63;
  constant FP_MANT_WIDTH : natural := 1 + FP_FRAC_WIDTH;
  constant FP_EXP_BIAS : natural := 16383;
  constant FP_BUS_WORD_WIDTH : natural := 32;
  constant FP80_RESULT_LO_WIDTH : natural := FP_BUS_WORD_WIDTH;
  constant FP80_RESULT_HI_WIDTH : natural := FP_BUS_WORD_WIDTH;
  constant FP80_RESULT_EX_WIDTH : natural := FP_WIDTH - FP80_RESULT_LO_WIDTH - FP80_RESULT_HI_WIDTH;
  constant OPSEL_NAMESPACE_WIDTH : natural := 8;
  constant OPSEL_OPCODE_ID_WIDTH : natural := 8;

  subtype fp80_t is std_logic_vector(FP_WIDTH-1 downto 0);
  subtype op_namespace_t is std_logic_vector(OPSEL_NAMESPACE_WIDTH-1 downto 0);
  subtype op_code_id_t is std_logic_vector(OPSEL_OPCODE_ID_WIDTH-1 downto 0);

  type op_key_t is record
    namespace : op_namespace_t;
    opcode_id : op_code_id_t;
  end record;

  constant OP_NS_LEGACY : op_namespace_t := x"00";
  constant OP_NS_CORE_V1 : op_namespace_t := x"01";

  type fpu_op_t is (
    FPU_OP_NOP,
    FPU_OP_ADD,
    FPU_OP_SUB,
    FPU_OP_MUL,
    FPU_OP_DIV,
    FPU_OP_SQRT,
    FPU_OP_CMP,
    FPU_OP_MOD,
    FPU_OP_REM,
    FPU_OP_SCALE,
    FPU_OP_SGLDIV,
    FPU_OP_SGLMUL,
    FPU_OP_SIN,
    FPU_OP_COS,
    FPU_OP_TAN,
    FPU_OP_SINCOS,
    FPU_OP_MOVE,
    FPU_OP_MOVEM,
    FPU_OP_FNOP,
    FPU_OP_FSAVE,
    FPU_OP_FRESTORE
  );

  type fpu_op_class_t is (
    OP_CLASS_NONE,
    OP_CLASS_ARITH,
    OP_CLASS_MOVE,
    OP_CLASS_PROG_CTRL,
    OP_CLASS_SYS_CTRL
  );

  type fp_round_mode_t is (
    FP_RND_NEAREST,
    FP_RND_ZERO,
    FP_RND_MINUS_INF,
    FP_RND_PLUS_INF
  );

  type fp_round_prec_t is (
    FP_PREC_EXTENDED,
    FP_PREC_SINGLE,
    FP_PREC_DOUBLE,
    FP_PREC_RESERVED
  );

  type ea_cycle_case_t is (
    EA_CYCLE_BEST,
    EA_CYCLE_CACHE,
    EA_CYCLE_WORST
  );

  type ea_mode_t is (
    EA_MODE_DN_AN,
    EA_MODE_AN_INDIRECT,
    EA_MODE_AN_POSTINC,
    EA_MODE_AN_PREDEC,
    EA_MODE_D16_AN_PC,
    EA_MODE_ABS_W,
    EA_MODE_ABS_L,
    EA_MODE_IMMEDIATE,
    EA_MODE_D8_AN_PC_XN,
    EA_MODE_D16_AN_PC_XN,
    EA_MODE_B,
    EA_MODE_D16_B,
    EA_MODE_D32_B,
    EA_MODE_B_INDIRECT_I,
    EA_MODE_B_INDIRECT_I_D16,
    EA_MODE_B_INDIRECT_I_D32,
    EA_MODE_D16_B_INDIRECT_I,
    EA_MODE_D16_B_INDIRECT_I_D16,
    EA_MODE_D16_B_INDIRECT_I_D32,
    EA_MODE_D32_B_INDIRECT_I,
    EA_MODE_D32_B_INDIRECT_I_D16,
    EA_MODE_D32_B_INDIRECT_I_D32
  );

  type fpu_src_kind_t is (
    FPU_SRC_FPM,
    FPU_SRC_MEM_INTEGER,
    FPU_SRC_MEM_SINGLE,
    FPU_SRC_MEM_DOUBLE,
    FPU_SRC_MEM_EXTENDED,
    FPU_SRC_MEM_PACKED
  );

  type op_cycle_model_t is (
    OP_CYCLE_NONE,
    OP_CYCLE_ARITH,
    OP_CYCLE_MOVE,
    OP_CYCLE_ZERO
  );

  type op_exception_policy_t is record
    divzero_on_zero_divisor_nonzero_dividend : boolean;
    invalid_zero_over_zero : boolean;
    invalid_inf_over_inf : boolean;
    invalid_divisor_zero : boolean;
    invalid_on_nan_inputs : boolean;
    invalid_on_nan_result : boolean;
    update_exc_status : boolean;
    update_accumulated_exc : boolean;
    update_cc_from_result : boolean;
    update_cc_from_compare : boolean;
    classify_overflow_underflow : boolean;
    capture_fpiar_on_exception : boolean;
  end record;

  type move_cfg_mode_t is (
    MOVE_CFG_MODE_REG_TO_REG,
    MOVE_CFG_MODE_MEM_TO_REG,
    MOVE_CFG_MODE_REG_TO_MEM,
    MOVE_CFG_MODE_CONTROL
  );

  type move_cfg_t is record
    src_idx : natural range 0 to 7;
    mem_fmt : std_logic_vector(1 downto 0);
    mode : move_cfg_mode_t;
    ctrl_to_reg : std_logic;
    dst_idx : natural range 0 to 7;
    ctrl_sel : std_logic_vector(1 downto 0);
    movem_mask : std_logic_vector(7 downto 0);
    movem_dir_to_reg : std_logic;
    packed_k_from_opa : std_logic;
    mem_to_reg_integer : std_logic;
    reg_to_mem_packed : std_logic;
    fmovecr_enable : std_logic;
    movem_mask_from_dn : std_logic;
    movem_predec_order : std_logic;
  end record;

  function move_cfg_default return move_cfg_t;
  function move_cfg_mode_to_bits(mode : move_cfg_mode_t) return std_logic_vector;
  function decode_move_cfg_mode(bits : std_logic_vector(1 downto 0)) return move_cfg_mode_t;
  function decode_move_cfg(word : std_logic_vector(31 downto 0)) return move_cfg_t;
  function encode_move_cfg(cfg : move_cfg_t) return std_logic_vector;

  function decode_round_mode(bits : std_logic_vector(1 downto 0)) return fp_round_mode_t;
  function decode_round_prec(bits : std_logic_vector(1 downto 0)) return fp_round_prec_t;
  function decode_op_key(opsel_word : std_logic_vector(31 downto 0)) return op_key_t;
  function decode_op_sel_word(opsel_word : std_logic_vector(31 downto 0)) return fpu_op_t;
  function decode_op_sel(bits : std_logic_vector) return fpu_op_t;
  function op_class(op_sel : fpu_op_t) return fpu_op_class_t;
  function op_alu_latency(op_sel : fpu_op_t) return natural;
  function op_cycle_model(op_sel : fpu_op_t) return op_cycle_model_t;
  function op_exception_policy(op_sel : fpu_op_t) return op_exception_policy_t;
  function ea_cycles(mode : ea_mode_t; cycle_case : ea_cycle_case_t) return natural;
  function base_arith_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural;
  function base_move_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural;
  function total_arith_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural;
  function op_cycle_count(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural;

  function to_fp80(value : unsigned) return fp80_t;
  function fp80_from_int(value : integer) return fp80_t;
  function abs_fp80(value : fp80_t) return fp80_t;
  function compare_fp80(a : fp80_t; b : fp80_t) return integer;
  function fp80_to_int_trunc(value : fp80_t) return integer;
  function add_sub_fp80(
    a        : fp80_t;
    b        : fp80_t;
    subtract : boolean;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function mul_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function div_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function sqrt_fp80(
    a : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function fmod_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function frem_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function fscale_fp80(a : fp80_t; b : fp80_t) return fp80_t;
  function sgldiv_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t;
  function sglmul_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t;
end package mc68881_pkg;

package body mc68881_pkg is
  constant FP_GRS_BITS : natural := 3;
  constant FP_MANT_EXT_WIDTH : natural := FP_MANT_WIDTH + FP_GRS_BITS;
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP80_ZERO : fp80_t := x"00000000000000000000";
  constant FP80_ONE : fp80_t := x"3FFF8000000000000000";
  constant FP80_HALF : fp80_t := x"3FFE8000000000000000";
  constant FP80_PI : fp80_t := x"4000C90FDAA22168C235";
  constant FP80_HALF_PI : fp80_t := x"3FFFC90FDAA22168C235";
  constant FP80_TWO_PI : fp80_t := x"4001C90FDAA22168C235";
  constant FP80_TWO_OVER_PI : fp80_t := x"3FFEA2F9836E4E44152A";
  constant FP_EXP_MAX : integer := (2**FP_EXP_WIDTH) - 1;
  type src_cycle_lut_t is array (fpu_src_kind_t) of natural;
  type op_descriptor_t is record
    legacy_decode_id_valid : boolean;
    legacy_decode_id : natural range 0 to 15;
    core_v1_decode_id_valid : boolean;
    core_v1_decode_id : op_code_id_t;
    op_class : fpu_op_class_t;
    alu_latency : natural;
    cycle_model : op_cycle_model_t;
    exception_policy : op_exception_policy_t;
    arith_cycles : src_cycle_lut_t;
    move_cycles : src_cycle_lut_t;
  end record;
  type op_descriptor_table_t is array (fpu_op_t) of op_descriptor_t;

  constant SRC_CYCLES_ZERO : src_cycle_lut_t := (
    FPU_SRC_FPM => 0,
    FPU_SRC_MEM_INTEGER => 0,
    FPU_SRC_MEM_SINGLE => 0,
    FPU_SRC_MEM_DOUBLE => 0,
    FPU_SRC_MEM_EXTENDED => 0,
    FPU_SRC_MEM_PACKED => 0
  );

  constant EXC_POLICY_NONE : op_exception_policy_t := (
    divzero_on_zero_divisor_nonzero_dividend => false,
    invalid_zero_over_zero => false,
    invalid_inf_over_inf => false,
    invalid_divisor_zero => false,
    invalid_on_nan_inputs => false,
    invalid_on_nan_result => false,
    update_exc_status => false,
    update_accumulated_exc => false,
    update_cc_from_result => false,
    update_cc_from_compare => false,
    classify_overflow_underflow => false,
    capture_fpiar_on_exception => false
  );

  constant EXC_POLICY_ARITH : op_exception_policy_t := (
    divzero_on_zero_divisor_nonzero_dividend => false,
    invalid_zero_over_zero => false,
    invalid_inf_over_inf => false,
    invalid_divisor_zero => false,
    invalid_on_nan_inputs => true,
    invalid_on_nan_result => true,
    update_exc_status => true,
    update_accumulated_exc => true,
    update_cc_from_result => true,
    update_cc_from_compare => false,
    classify_overflow_underflow => true,
    capture_fpiar_on_exception => true
  );

  constant EXC_POLICY_DIV : op_exception_policy_t := (
    divzero_on_zero_divisor_nonzero_dividend => true,
    invalid_zero_over_zero => true,
    invalid_inf_over_inf => true,
    invalid_divisor_zero => false,
    invalid_on_nan_inputs => true,
    invalid_on_nan_result => true,
    update_exc_status => true,
    update_accumulated_exc => true,
    update_cc_from_result => true,
    update_cc_from_compare => false,
    classify_overflow_underflow => true,
    capture_fpiar_on_exception => true
  );

  constant EXC_POLICY_MOD_REM : op_exception_policy_t := (
    divzero_on_zero_divisor_nonzero_dividend => false,
    invalid_zero_over_zero => false,
    invalid_inf_over_inf => false,
    invalid_divisor_zero => true,
    invalid_on_nan_inputs => true,
    invalid_on_nan_result => true,
    update_exc_status => true,
    update_accumulated_exc => true,
    update_cc_from_result => true,
    update_cc_from_compare => false,
    classify_overflow_underflow => true,
    capture_fpiar_on_exception => true
  );

  constant EXC_POLICY_CMP : op_exception_policy_t := (
    divzero_on_zero_divisor_nonzero_dividend => false,
    invalid_zero_over_zero => false,
    invalid_inf_over_inf => false,
    invalid_divisor_zero => false,
    invalid_on_nan_inputs => true,
    invalid_on_nan_result => false,
    update_exc_status => true,
    update_accumulated_exc => true,
    update_cc_from_result => false,
    update_cc_from_compare => true,
    classify_overflow_underflow => false,
    capture_fpiar_on_exception => true
  );

  constant OP_DESCRIPTORS : op_descriptor_table_t := (
    FPU_OP_NOP => (
      legacy_decode_id_valid => true,
      legacy_decode_id => 0,
      core_v1_decode_id_valid => false,
      core_v1_decode_id => x"00",
      op_class => OP_CLASS_NONE,
      alu_latency => 0,
      cycle_model => OP_CYCLE_NONE,
      exception_policy => EXC_POLICY_NONE,
      arith_cycles => SRC_CYCLES_ZERO,
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_ADD => (
      legacy_decode_id_valid => true, legacy_decode_id => 1,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"01",
      op_class => OP_CLASS_ARITH, alu_latency => 1, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 51, FPU_SRC_MEM_INTEGER => 80, FPU_SRC_MEM_SINGLE => 72,
        FPU_SRC_MEM_DOUBLE => 78, FPU_SRC_MEM_EXTENDED => 76, FPU_SRC_MEM_PACKED => 888
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_SUB => (
      legacy_decode_id_valid => true, legacy_decode_id => 2,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"02",
      op_class => OP_CLASS_ARITH, alu_latency => 1, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 51, FPU_SRC_MEM_INTEGER => 80, FPU_SRC_MEM_SINGLE => 72,
        FPU_SRC_MEM_DOUBLE => 78, FPU_SRC_MEM_EXTENDED => 76, FPU_SRC_MEM_PACKED => 888
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_MUL => (
      legacy_decode_id_valid => true, legacy_decode_id => 3,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"03",
      op_class => OP_CLASS_ARITH, alu_latency => 4, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 71, FPU_SRC_MEM_INTEGER => 100, FPU_SRC_MEM_SINGLE => 92,
        FPU_SRC_MEM_DOUBLE => 98, FPU_SRC_MEM_EXTENDED => 96, FPU_SRC_MEM_PACKED => 908
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_DIV => (
      legacy_decode_id_valid => true, legacy_decode_id => 4,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"04",
      op_class => OP_CLASS_ARITH, alu_latency => 73, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_DIV,
      arith_cycles => (
        FPU_SRC_FPM => 103, FPU_SRC_MEM_INTEGER => 132, FPU_SRC_MEM_SINGLE => 124,
        FPU_SRC_MEM_DOUBLE => 130, FPU_SRC_MEM_EXTENDED => 128, FPU_SRC_MEM_PACKED => 940
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_SQRT => (
      legacy_decode_id_valid => false, legacy_decode_id => 0,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"11",
      op_class => OP_CLASS_ARITH, alu_latency => 12, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 120, FPU_SRC_MEM_INTEGER => 149, FPU_SRC_MEM_SINGLE => 141,
        FPU_SRC_MEM_DOUBLE => 147, FPU_SRC_MEM_EXTENDED => 145, FPU_SRC_MEM_PACKED => 960
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_CMP => (
      legacy_decode_id_valid => true, legacy_decode_id => 7,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"07",
      op_class => OP_CLASS_ARITH, alu_latency => 1, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_CMP,
      arith_cycles => (
        FPU_SRC_FPM => 49, FPU_SRC_MEM_INTEGER => 78, FPU_SRC_MEM_SINGLE => 70,
        FPU_SRC_MEM_DOUBLE => 76, FPU_SRC_MEM_EXTENDED => 74, FPU_SRC_MEM_PACKED => 886
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_MOD => (
      legacy_decode_id_valid => true, legacy_decode_id => 8,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"08",
      op_class => OP_CLASS_ARITH, alu_latency => 84, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_MOD_REM,
      arith_cycles => (
        FPU_SRC_FPM => 109, FPU_SRC_MEM_INTEGER => 138, FPU_SRC_MEM_SINGLE => 130,
        FPU_SRC_MEM_DOUBLE => 136, FPU_SRC_MEM_EXTENDED => 134, FPU_SRC_MEM_PACKED => 946
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_REM => (
      legacy_decode_id_valid => true, legacy_decode_id => 9,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"09",
      op_class => OP_CLASS_ARITH, alu_latency => 84, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_MOD_REM,
      arith_cycles => (
        FPU_SRC_FPM => 109, FPU_SRC_MEM_INTEGER => 138, FPU_SRC_MEM_SINGLE => 130,
        FPU_SRC_MEM_DOUBLE => 136, FPU_SRC_MEM_EXTENDED => 134, FPU_SRC_MEM_PACKED => 946
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_SCALE => (
      legacy_decode_id_valid => true, legacy_decode_id => 10,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"0A",
      op_class => OP_CLASS_ARITH, alu_latency => 2, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 55, FPU_SRC_MEM_INTEGER => 84, FPU_SRC_MEM_SINGLE => 76,
        FPU_SRC_MEM_DOUBLE => 82, FPU_SRC_MEM_EXTENDED => 80, FPU_SRC_MEM_PACKED => 892
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_SGLDIV => (
      legacy_decode_id_valid => true, legacy_decode_id => 11,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"0B",
      op_class => OP_CLASS_ARITH, alu_latency => 8, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_DIV,
      arith_cycles => (
        FPU_SRC_FPM => 95, FPU_SRC_MEM_INTEGER => 124, FPU_SRC_MEM_SINGLE => 116,
        FPU_SRC_MEM_DOUBLE => 122, FPU_SRC_MEM_EXTENDED => 120, FPU_SRC_MEM_PACKED => 932
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_SGLMUL => (
      legacy_decode_id_valid => true, legacy_decode_id => 12,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"0C",
      op_class => OP_CLASS_ARITH, alu_latency => 4, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 63, FPU_SRC_MEM_INTEGER => 92, FPU_SRC_MEM_SINGLE => 84,
        FPU_SRC_MEM_DOUBLE => 90, FPU_SRC_MEM_EXTENDED => 88, FPU_SRC_MEM_PACKED => 900
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_SIN => (
      legacy_decode_id_valid => true, legacy_decode_id => 13,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"0D",
      op_class => OP_CLASS_ARITH, alu_latency => 12, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 120, FPU_SRC_MEM_INTEGER => 149, FPU_SRC_MEM_SINGLE => 141,
        FPU_SRC_MEM_DOUBLE => 147, FPU_SRC_MEM_EXTENDED => 145, FPU_SRC_MEM_PACKED => 960
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_COS => (
      legacy_decode_id_valid => true, legacy_decode_id => 14,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"0E",
      op_class => OP_CLASS_ARITH, alu_latency => 12, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 120, FPU_SRC_MEM_INTEGER => 149, FPU_SRC_MEM_SINGLE => 141,
        FPU_SRC_MEM_DOUBLE => 147, FPU_SRC_MEM_EXTENDED => 145, FPU_SRC_MEM_PACKED => 960
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_TAN => (
      legacy_decode_id_valid => true, legacy_decode_id => 15,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"0F",
      op_class => OP_CLASS_ARITH, alu_latency => 13, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_DIV,
      arith_cycles => (
        FPU_SRC_FPM => 156, FPU_SRC_MEM_INTEGER => 185, FPU_SRC_MEM_SINGLE => 177,
        FPU_SRC_MEM_DOUBLE => 183, FPU_SRC_MEM_EXTENDED => 181, FPU_SRC_MEM_PACKED => 996
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_SINCOS => (
      legacy_decode_id_valid => false, legacy_decode_id => 0,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"10",
      op_class => OP_CLASS_ARITH, alu_latency => 12, cycle_model => OP_CYCLE_ARITH,
      exception_policy => EXC_POLICY_ARITH,
      arith_cycles => (
        FPU_SRC_FPM => 124, FPU_SRC_MEM_INTEGER => 153, FPU_SRC_MEM_SINGLE => 145,
        FPU_SRC_MEM_DOUBLE => 151, FPU_SRC_MEM_EXTENDED => 149, FPU_SRC_MEM_PACKED => 964
      ),
      move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_MOVE => (
      legacy_decode_id_valid => true, legacy_decode_id => 5,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"05",
      op_class => OP_CLASS_MOVE, alu_latency => 0, cycle_model => OP_CYCLE_MOVE,
      exception_policy => EXC_POLICY_NONE,
      arith_cycles => SRC_CYCLES_ZERO,
      move_cycles => (
        FPU_SRC_FPM => 4, FPU_SRC_MEM_INTEGER => 10, FPU_SRC_MEM_SINGLE => 8,
        FPU_SRC_MEM_DOUBLE => 10, FPU_SRC_MEM_EXTENDED => 12, FPU_SRC_MEM_PACKED => 10
      )
    ),
    FPU_OP_MOVEM => (
      legacy_decode_id_valid => true, legacy_decode_id => 6,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"06",
      op_class => OP_CLASS_MOVE, alu_latency => 0, cycle_model => OP_CYCLE_MOVE,
      exception_policy => EXC_POLICY_NONE,
      arith_cycles => SRC_CYCLES_ZERO,
      move_cycles => (
        FPU_SRC_FPM => 16, FPU_SRC_MEM_INTEGER => 20, FPU_SRC_MEM_SINGLE => 20,
        FPU_SRC_MEM_DOUBLE => 22, FPU_SRC_MEM_EXTENDED => 24, FPU_SRC_MEM_PACKED => 20
      )
    ),
    FPU_OP_FNOP => (
      legacy_decode_id_valid => false, legacy_decode_id => 0,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"20",
      op_class => OP_CLASS_PROG_CTRL, alu_latency => 0, cycle_model => OP_CYCLE_ZERO,
      exception_policy => EXC_POLICY_NONE,
      arith_cycles => SRC_CYCLES_ZERO, move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_FSAVE => (
      legacy_decode_id_valid => false, legacy_decode_id => 0,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"30",
      op_class => OP_CLASS_SYS_CTRL, alu_latency => 0, cycle_model => OP_CYCLE_ZERO,
      exception_policy => EXC_POLICY_NONE,
      arith_cycles => SRC_CYCLES_ZERO, move_cycles => SRC_CYCLES_ZERO
    ),
    FPU_OP_FRESTORE => (
      legacy_decode_id_valid => false, legacy_decode_id => 0,
      core_v1_decode_id_valid => true, core_v1_decode_id => x"31",
      op_class => OP_CLASS_SYS_CTRL, alu_latency => 0, cycle_model => OP_CYCLE_ZERO,
      exception_policy => EXC_POLICY_NONE,
      arith_cycles => SRC_CYCLES_ZERO, move_cycles => SRC_CYCLES_ZERO
    )
  );

  type fp_unpacked_t is record
    sign : std_logic;
    exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  end record;

  function move_cfg_default return move_cfg_t is
    variable cfg : move_cfg_t;
  begin
    cfg.src_idx := 0;
    cfg.mem_fmt := (others => '0');
    cfg.mode := MOVE_CFG_MODE_REG_TO_REG;
    cfg.ctrl_to_reg := '0';
    cfg.dst_idx := 0;
    cfg.ctrl_sel := (others => '0');
    cfg.movem_mask := (others => '0');
    cfg.movem_dir_to_reg := '0';
    cfg.packed_k_from_opa := '0';
    cfg.mem_to_reg_integer := '0';
    cfg.reg_to_mem_packed := '0';
    cfg.fmovecr_enable := '0';
    cfg.movem_mask_from_dn := '0';
    cfg.movem_predec_order := '0';
    return cfg;
  end function;

  function move_cfg_mode_to_bits(mode : move_cfg_mode_t) return std_logic_vector is
    variable bits : std_logic_vector(1 downto 0) := (others => '0');
  begin
    case mode is
      when MOVE_CFG_MODE_REG_TO_REG => bits := "00";
      when MOVE_CFG_MODE_MEM_TO_REG => bits := "01";
      when MOVE_CFG_MODE_REG_TO_MEM => bits := "10";
      when others => bits := "11";
    end case;
    return bits;
  end function;

  function decode_move_cfg_mode(bits : std_logic_vector(1 downto 0)) return move_cfg_mode_t is
  begin
    case bits is
      when "00" => return MOVE_CFG_MODE_REG_TO_REG;
      when "01" => return MOVE_CFG_MODE_MEM_TO_REG;
      when "10" => return MOVE_CFG_MODE_REG_TO_MEM;
      when others => return MOVE_CFG_MODE_CONTROL;
    end case;
  end function;

  function decode_move_cfg(word : std_logic_vector(31 downto 0)) return move_cfg_t is
    variable cfg : move_cfg_t := move_cfg_default;
  begin
    if is_x(word) then
      return cfg;
    end if;

    cfg.src_idx := to_integer(unsigned(word(2 downto 0)));
    cfg.mem_fmt := word(5 downto 4);
    cfg.mode := decode_move_cfg_mode(word(7 downto 6));
    cfg.ctrl_to_reg := word(8);
    cfg.dst_idx := to_integer(unsigned(word(11 downto 9)));
    cfg.ctrl_sel := word(13 downto 12);
    cfg.movem_mask := word(21 downto 14);
    cfg.movem_dir_to_reg := word(22);
    cfg.packed_k_from_opa := word(23);
    cfg.mem_to_reg_integer := word(24);
    cfg.reg_to_mem_packed := word(25);
    cfg.fmovecr_enable := word(26);
    cfg.movem_mask_from_dn := word(27);
    cfg.movem_predec_order := word(28);
    return cfg;
  end function;

  function encode_move_cfg(cfg : move_cfg_t) return std_logic_vector is
    variable word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    word(2 downto 0) := std_logic_vector(to_unsigned(cfg.src_idx, 3));
    word(5 downto 4) := cfg.mem_fmt;
    word(7 downto 6) := move_cfg_mode_to_bits(cfg.mode);
    word(8) := cfg.ctrl_to_reg;
    word(11 downto 9) := std_logic_vector(to_unsigned(cfg.dst_idx, 3));
    word(13 downto 12) := cfg.ctrl_sel;
    word(21 downto 14) := cfg.movem_mask;
    word(22) := cfg.movem_dir_to_reg;
    word(23) := cfg.packed_k_from_opa;
    word(24) := cfg.mem_to_reg_integer;
    word(25) := cfg.reg_to_mem_packed;
    word(26) := cfg.fmovecr_enable;
    word(27) := cfg.movem_mask_from_dn;
    word(28) := cfg.movem_predec_order;
    return word;
  end function;

  function decode_round_mode(bits : std_logic_vector(1 downto 0)) return fp_round_mode_t is
  begin
    case bits is
      when "00" => return FP_RND_NEAREST;
      when "01" => return FP_RND_ZERO;
      when "10" => return FP_RND_MINUS_INF;
      when others => return FP_RND_PLUS_INF;
    end case;
  end function;

  function decode_round_prec(bits : std_logic_vector(1 downto 0)) return fp_round_prec_t is
  begin
    case bits is
      when "00" => return FP_PREC_EXTENDED;
      when "01" => return FP_PREC_SINGLE;
      when "10" => return FP_PREC_DOUBLE;
      when others => return FP_PREC_RESERVED;
    end case;
  end function;

  function decode_op_key(opsel_word : std_logic_vector(31 downto 0)) return op_key_t is
    variable key : op_key_t;
  begin
    key.namespace := (others => '0');
    key.opcode_id := (others => '0');

    if is_x(opsel_word) then
      return key;
    end if;

    key.namespace := opsel_word(31 downto 24);
    key.opcode_id := opsel_word(7 downto 0);
    return key;
  end function;

  function decode_op_sel_word(opsel_word : std_logic_vector(31 downto 0)) return fpu_op_t is
    variable key : op_key_t;
    variable idx : natural := 0;
  begin
    key := decode_op_key(opsel_word);

    for op_sel in fpu_op_t loop
      if key.namespace = OP_NS_LEGACY and
         OP_DESCRIPTORS(op_sel).legacy_decode_id_valid and
         key.opcode_id = std_logic_vector(to_unsigned(OP_DESCRIPTORS(op_sel).legacy_decode_id, OPSEL_OPCODE_ID_WIDTH)) then
        return op_sel;
      end if;
      if key.namespace = OP_NS_CORE_V1 and
         OP_DESCRIPTORS(op_sel).core_v1_decode_id_valid and
         OP_DESCRIPTORS(op_sel).core_v1_decode_id = key.opcode_id then
        return op_sel;
      end if;
    end loop;

    -- Legacy compatibility: preserve historical low-nibble OPSEL values.
    if key.namespace = OP_NS_LEGACY and key.opcode_id(7 downto 4) = "0000" then
      idx := to_integer(unsigned(key.opcode_id(3 downto 0)));
      for op_sel in fpu_op_t loop
        if OP_DESCRIPTORS(op_sel).legacy_decode_id_valid and
           OP_DESCRIPTORS(op_sel).legacy_decode_id = idx then
          return op_sel;
        end if;
      end loop;
    end if;

    return FPU_OP_NOP;
  end function;

  function decode_op_sel(bits : std_logic_vector) return fpu_op_t is
    variable idx : natural := 0;
  begin
    if bits'length = 0 or is_x(bits) then
      return FPU_OP_NOP;
    end if;

    idx := to_integer(unsigned(bits));

    if bits'length = 3 and idx > 6 then
      return FPU_OP_NOP;
    end if;

    for op_sel in fpu_op_t loop
      if OP_DESCRIPTORS(op_sel).legacy_decode_id_valid and
         OP_DESCRIPTORS(op_sel).legacy_decode_id = idx then
        return op_sel;
      end if;
    end loop;
    if bits'length = 3 then
      -- Legacy 3-bit decode kept for existing tests.
      return FPU_OP_NOP;
    end if;

    return FPU_OP_NOP;
  end function;

  function op_class(op_sel : fpu_op_t) return fpu_op_class_t is
  begin
    return OP_DESCRIPTORS(op_sel).op_class;
  end function;

  function op_alu_latency(op_sel : fpu_op_t) return natural is
  begin
    return OP_DESCRIPTORS(op_sel).alu_latency;
  end function;

  function op_cycle_model(op_sel : fpu_op_t) return op_cycle_model_t is
  begin
    return OP_DESCRIPTORS(op_sel).cycle_model;
  end function;

  function op_exception_policy(op_sel : fpu_op_t) return op_exception_policy_t is
  begin
    return OP_DESCRIPTORS(op_sel).exception_policy;
  end function;

  function ea_cycles(mode : ea_mode_t; cycle_case : ea_cycle_case_t) return natural is
    function pick(best_case : natural; cache_case : natural; worst_case : natural) return natural is
    begin
      case cycle_case is
        when EA_CYCLE_BEST => return best_case;
        when EA_CYCLE_CACHE => return cache_case;
        when others => return worst_case;
      end case;
    end function;
  begin
    case mode is
      when EA_MODE_DN_AN => return pick(0, 0, 0);
      when EA_MODE_AN_INDIRECT => return pick(0, 2, 2);
      when EA_MODE_AN_POSTINC => return pick(3, 6, 6);
      when EA_MODE_AN_PREDEC => return pick(3, 6, 6);
      when EA_MODE_D16_AN_PC => return pick(0, 2, 3);
      when EA_MODE_ABS_W => return pick(0, 2, 3);
      when EA_MODE_ABS_L => return pick(1, 4, 5);
      when EA_MODE_IMMEDIATE => return pick(0, 0, 0);
      when EA_MODE_D8_AN_PC_XN => return pick(1, 4, 5);
      when EA_MODE_D16_AN_PC_XN => return pick(3, 6, 7);
      when EA_MODE_B => return pick(3, 6, 7);
      when EA_MODE_D16_B => return pick(5, 8, 9);
      when EA_MODE_D32_B => return pick(11, 14, 16);
      when EA_MODE_B_INDIRECT_I => return pick(8, 11, 12);
      when EA_MODE_B_INDIRECT_I_D16 => return pick(8, 11, 12);
      when EA_MODE_B_INDIRECT_I_D32 => return pick(10, 13, 15);
      when EA_MODE_D16_B_INDIRECT_I => return pick(10, 13, 14);
      when EA_MODE_D16_B_INDIRECT_I_D16 => return pick(10, 13, 15);
      when EA_MODE_D16_B_INDIRECT_I_D32 => return pick(12, 15, 17);
      when EA_MODE_D32_B_INDIRECT_I => return pick(16, 19, 21);
      when EA_MODE_D32_B_INDIRECT_I_D16 => return pick(16, 19, 21);
      when EA_MODE_D32_B_INDIRECT_I_D32 => return pick(18, 21, 24);
    end case;
  end function;

  function base_arith_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural is
  begin
    return OP_DESCRIPTORS(op_sel).arith_cycles(src_kind);
  end function;

  function base_move_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural is
  begin
    return OP_DESCRIPTORS(op_sel).move_cycles(src_kind);
  end function;

  function total_arith_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural is
    variable total_cycles : integer := 0;
    variable ea_add : natural := 0;
    variable k_add : natural := 0;
  begin
    ea_add := ea_cycles(ea_mode, cycle_case);
    total_cycles := integer(base_arith_cycles(op_sel, src_kind)) + integer(ea_add);

    if mc68020_src then
      total_cycles := total_cycles - 5;
    end if;

    if mc68020_dst then
      total_cycles := total_cycles - 2;
    end if;

    if packed_dynamic_k and src_kind = FPU_SRC_MEM_PACKED then
      k_add := 14;
      total_cycles := total_cycles + integer(k_add);
    end if;

    if total_cycles < 0 then
      total_cycles := 0;
    end if;
    return natural(total_cycles);
  end function;

  function op_cycle_count(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural is
  begin
    case op_cycle_model(op_sel) is
      when OP_CYCLE_ARITH =>
        return total_arith_cycles(
          op_sel,
          src_kind,
          ea_mode,
          cycle_case,
          mc68020_src,
          mc68020_dst,
          packed_dynamic_k
        );
      when OP_CYCLE_MOVE =>
        return base_move_cycles(op_sel, src_kind) + ea_cycles(ea_mode, cycle_case);
      when OP_CYCLE_ZERO | OP_CYCLE_NONE =>
        return 0;
    end case;
  end function;

  function prec_bits(prec : fp_round_prec_t) return natural is
  begin
    case prec is
      when FP_PREC_SINGLE => return 24;
      when FP_PREC_DOUBLE => return 53;
      when others => return FP_MANT_WIDTH;
    end case;
  end function;

  function shift_right_with_sticky(
    value : unsigned;
    shift : natural
  ) return unsigned;

  procedure apply_rounding(
    sign       : in  std_logic;
    mant_ext   : in  unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    exp_in     : in  integer;
    round_mode : in  fp_round_mode_t;
    round_prec : in  fp_round_prec_t;
    mant_out   : out unsigned(FP_MANT_WIDTH-1 downto 0);
    exp_out    : out integer
  ) is
    -- Keep intermediate exponent state in a local variable: Vivado/VRFC does
    -- not allow reading from an `out` parameter inside the subprogram body.
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
    prec_w := prec_bits(round_prec);
    drop_bits := FP_MANT_WIDTH - prec_w;
    lsb_keep := FP_GRS_BITS + drop_bits;


    guard := mant_ext(lsb_keep-1);
    round_bit := mant_ext(lsb_keep-2);
    if lsb_keep > 2 then
      if mant_ext(lsb_keep-3 downto 0) /= 0 then
        sticky := '1';
      end if;
    end if;

    any_disc := guard or round_bit or sticky;
    case round_mode is
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
  end procedure;

  procedure int_sqrt_with_rem(
    radicand : in unsigned;
    root     : out unsigned;
    rem_out  : out unsigned
  ) is
    constant RAD_W : integer := radicand'length;
    constant EVEN_W : integer := (RAD_W + 1) / 2 * 2;
    variable rad_even : unsigned(EVEN_W-1 downto 0) := (others => '0');
    variable root_var : unsigned(root'length-1 downto 0) := (others => '0');
    variable rem_var  : unsigned(EVEN_W-1 downto 0) := (others => '0');
    variable trial    : unsigned(EVEN_W-1 downto 0) := (others => '0');
    variable pair_hi  : integer := 0;
  begin
    rad_even(EVEN_W-1 downto EVEN_W-RAD_W) := radicand;

    for idx in 0 to (EVEN_W/2 - 1) loop
      pair_hi := EVEN_W-1 - idx * 2;
      rem_var := shift_left(rem_var, 2);
      rem_var(1 downto 0) := rad_even(pair_hi downto pair_hi-1);
      trial := shift_left(resize(root_var, EVEN_W), 2) + 1;
      if rem_var >= trial then
        rem_var := rem_var - trial;
        root_var := shift_left(root_var, 1);
        root_var(0) := '1';
      else
        root_var := shift_left(root_var, 1);
      end if;
    end loop;

    root := root_var;
    rem_out := resize(rem_var, rem_out'length);
  end procedure;

  function unpack_fp80(value : fp80_t) return fp_unpacked_t is
    variable result : fp_unpacked_t;
  begin
    result.sign := value(FP_WIDTH-1);
    result.exp  := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    result.mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return result;
  end function;

  function pack_fp80(value : fp_unpacked_t) return fp80_t is
    variable result : fp80_t := (others => '0');
  begin
    result(FP_WIDTH-1) := value.sign;
    result(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(value.exp);
    result(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(value.mant);
    return result;
  end function;

  function shift_right_with_sticky(
    value : unsigned;
    shift : natural
  ) return unsigned is
    variable result : unsigned(value'length-1 downto 0) := (others => '0');
    variable sticky : std_logic := '0';
  begin
    if shift = 0 then
      return value;
    end if;

    if shift >= value'length then
      if value /= 0 then
        sticky := '1';
      end if;
      result(0) := sticky;
      return result;
    end if;

    if value(shift-1 downto 0) /= 0 then
      sticky := '1';
    end if;

    result := shift_right(value, shift);
    if sticky = '1' then
      result(0) := '1';
    end if;
    return result;
  end function;

  procedure normalize_left(
    value   : in  unsigned;
    exp_in  : in  unsigned;
    value_o : out unsigned;
    exp_o   : out unsigned
  ) is
    variable result : unsigned(value'range) := value;
    variable exp_var : unsigned(exp_in'range) := exp_in;
  begin
    -- Bound the iteration count for synthesis convergence.
    for i in 0 to value'length-1 loop
      exit when not (result(result'left) = '0' and exp_var /= 0 and result /= 0);
      result := result(result'left-1 downto 0) & '0';
      exp_var := exp_var - 1;
    end loop;
    value_o := result;
    exp_o := exp_var;
  end procedure;

  function to_fp80(value : unsigned) return fp80_t is
    variable result : fp80_t := (others => '0');
    variable width  : natural := value'length;
    variable copy_w : natural := 0;
  begin
    if width >= FP_WIDTH then
      copy_w := FP_WIDTH;
      result := std_logic_vector(value(copy_w-1 downto 0));
    else
      copy_w := width;
      result(copy_w-1 downto 0) := std_logic_vector(value);
    end if;
    return result;
  end function;

  function fp80_from_int(value : integer) return fp80_t is
    variable result : fp80_t := (others => '0');
    variable abs_val : natural := 0;
    variable sign    : std_logic := '0';
    variable exp     : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable mant    : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable msb_pos : integer := 0;
    variable tmp     : natural := 0;
  begin
    if value = 0 then
      return result;
    end if;

    if value < 0 then
      sign := '1';
      abs_val := natural(-value);
    else
      abs_val := natural(value);
    end if;

    tmp := abs_val;
    msb_pos := 0;
    -- Keep bounded iteration for synthesis: integer input magnitude is <= 31 bits.
    for i in 0 to 30 loop
      exit when tmp <= 1;
      tmp := tmp / 2;
      msb_pos := msb_pos + 1;
    end loop;

    exp := to_unsigned(FP_EXP_BIAS + msb_pos, FP_EXP_WIDTH);
    mant := resize(to_unsigned(abs_val, FP_MANT_WIDTH), FP_MANT_WIDTH) sll (FP_MANT_WIDTH-1-msb_pos);

    result(FP_WIDTH-1) := sign;
    result(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(exp);
    result(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(mant);
    return result;
  end function;

  function add_sub_fp80(
    a        : fp80_t;
    b        : fp80_t;
    subtract : boolean;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable res_u : fp_unpacked_t;
    variable mant_a_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_b_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_sum   : unsigned(FP_MANT_EXT_WIDTH downto 0) := (others => '0');
    variable mant_main  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable mant_ext   : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable exp_diff   : natural := 0;
    variable exp_res    : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable exp_res_i  : integer := 0;
    variable sign_b     : std_logic := '0';
  begin
    res_u.sign := '0';
    res_u.exp  := (others => '0');
    res_u.mant := (others => '0');

    if a_u.exp = 0 and a_u.mant = 0 then
      if subtract then
        b_u.sign := not b_u.sign;
      end if;
      return pack_fp80(b_u);
    end if;

    if b_u.exp = 0 and b_u.mant = 0 then
      return pack_fp80(a_u);
    end if;

    sign_b := b_u.sign;
    if subtract then
      sign_b := not sign_b;
    end if;

    mant_a_ext := a_u.mant & (FP_GRS_BITS-1 downto 0 => '0');
    mant_b_ext := b_u.mant & (FP_GRS_BITS-1 downto 0 => '0');

    if a_u.exp > b_u.exp then
      exp_diff := to_integer(a_u.exp - b_u.exp);
      mant_b_ext := shift_right_with_sticky(mant_b_ext, exp_diff);
      exp_res := a_u.exp;
    elsif b_u.exp > a_u.exp then
      exp_diff := to_integer(b_u.exp - a_u.exp);
      mant_a_ext := shift_right_with_sticky(mant_a_ext, exp_diff);
      exp_res := b_u.exp;
    else
      exp_res := a_u.exp;
    end if;

    if a_u.sign = sign_b then
      mant_sum := ('0' & mant_a_ext) + ('0' & mant_b_ext);
      res_u.sign := a_u.sign;

      if mant_sum(mant_sum'left) = '1' then
        mant_sum(mant_sum'left-1 downto 0) := shift_right_with_sticky(mant_sum(mant_sum'left-1 downto 0), 1);
        mant_sum(mant_sum'left-1) := '1';
        mant_sum(mant_sum'left) := '0';
        if exp_res /= FP_EXP_ALL_ONES then
          exp_res := exp_res + 1;
        end if;
      end if;
    else
      if mant_a_ext >= mant_b_ext then
        mant_sum := ('0' & mant_a_ext) - ('0' & mant_b_ext);
        res_u.sign := a_u.sign;
      else
        mant_sum := ('0' & mant_b_ext) - ('0' & mant_a_ext);
        res_u.sign := sign_b;
      end if;

      normalize_left(
        mant_sum(mant_sum'left-1 downto 0),
        exp_res,
        mant_sum(mant_sum'left-1 downto 0),
        exp_res
      );
    end if;

    mant_ext := mant_sum(mant_sum'left-1 downto 0);
    exp_res_i := to_integer(exp_res);
    apply_rounding(res_u.sign, mant_ext, exp_res_i, round_mode, round_prec, mant_main, exp_res_i);

    if mant_main = 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i >= FP_EXP_MAX then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i <= 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res := to_unsigned(exp_res_i, FP_EXP_WIDTH);
    res_u.exp := exp_res;
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;

  function mul_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable res_u : fp_unpacked_t;
    variable mant_prod : unsigned((FP_MANT_WIDTH*2)-1 downto 0) := (others => '0');
    variable mant_ext  : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_res_i : integer := 0;
    variable exp_res   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable low_or : std_logic := '0';
  begin
    res_u.sign := a_u.sign xor b_u.sign;
    res_u.exp  := (others => '0');
    res_u.mant := (others => '0');

    if (a_u.exp = 0 and a_u.mant = 0) or (b_u.exp = 0 and b_u.mant = 0) then
      res_u.sign := '0';
      return pack_fp80(res_u);
    end if;

    if a_u.exp = FP_EXP_ALL_ONES or b_u.exp = FP_EXP_ALL_ONES then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res_i := to_integer(a_u.exp) + to_integer(b_u.exp) - FP_EXP_BIAS;
    mant_prod := a_u.mant * b_u.mant;

    if mant_prod(mant_prod'left) = '1' then
      exp_res_i := exp_res_i + 1;
    end if;

    mant_ext := mant_prod(mant_prod'left-1 downto mant_prod'left-1-(FP_MANT_EXT_WIDTH-1));
    if (mant_prod'left-1-(FP_MANT_EXT_WIDTH) >= 0) then
      for idx in 0 to mant_prod'left-1-FP_MANT_EXT_WIDTH loop
        if mant_prod(idx) = '1' then
          low_or := '1';
        end if;
      end loop;
    end if;

    if low_or = '1' then
      mant_ext(0) := mant_ext(0) or low_or;
    end if;

    apply_rounding(res_u.sign, mant_ext, exp_res_i, round_mode, round_prec, mant_main, exp_res_i);

    if exp_res_i <= 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i >= FP_EXP_MAX then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res := to_unsigned(exp_res_i, FP_EXP_WIDTH);
    res_u.exp := exp_res;
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;

  function div_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable res_u : fp_unpacked_t;
    variable num : unsigned((FP_MANT_WIDTH*2)+FP_GRS_BITS-1 downto 0) := (others => '0');
    variable quot : unsigned((FP_MANT_WIDTH*2)+FP_GRS_BITS-1 downto 0) := (others => '0');
    variable rem_val  : unsigned((FP_MANT_WIDTH*2)+FP_GRS_BITS-1 downto 0) := (others => '0');
    variable mant_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_res_i : integer := 0;
    variable exp_res   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable shift     : integer := 0;
    variable low_or : std_logic := '0';
    variable top_index : integer := FP_MANT_WIDTH + FP_GRS_BITS;
  begin
    res_u.sign := a_u.sign xor b_u.sign;
    res_u.exp  := (others => '0');
    res_u.mant := (others => '0');

    if b_u.exp = 0 and b_u.mant = 0 then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if a_u.exp = 0 and a_u.mant = 0 then
      res_u.sign := '0';
      return pack_fp80(res_u);
    end if;

    if a_u.exp = FP_EXP_ALL_ONES or b_u.exp = FP_EXP_ALL_ONES then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res_i := to_integer(a_u.exp) - to_integer(b_u.exp) + FP_EXP_BIAS;

    num := a_u.mant & (FP_MANT_WIDTH+FP_GRS_BITS-1 downto 0 => '0');
    quot := num / b_u.mant;
    rem_val  := num mod resize(b_u.mant, num'length);

    if quot(top_index+1) = '1' then
      shift := 1;
      exp_res_i := exp_res_i + 1;
    elsif quot(top_index) = '0' then
      shift := -1;
      exp_res_i := exp_res_i - 1;
    else
      shift := 0;
    end if;

    if shift = 1 then
      mant_ext := quot(top_index+1 downto top_index+1-(FP_MANT_EXT_WIDTH-1));
      if top_index+1-FP_MANT_EXT_WIDTH >= 0 then
        for idx in 0 to top_index+1-FP_MANT_EXT_WIDTH loop
          if quot(idx) = '1' then
            low_or := '1';
          end if;
        end loop;
      end if;
    elsif shift = -1 then
      mant_ext := quot(top_index-1 downto top_index-1-(FP_MANT_EXT_WIDTH-1));
      if top_index-1-FP_MANT_EXT_WIDTH >= 0 then
        for idx in 0 to top_index-1-FP_MANT_EXT_WIDTH loop
          if quot(idx) = '1' then
            low_or := '1';
          end if;
        end loop;
      end if;
    else
      mant_ext := quot(top_index downto top_index-(FP_MANT_EXT_WIDTH-1));
      if top_index-FP_MANT_EXT_WIDTH >= 0 then
        for idx in 0 to top_index-FP_MANT_EXT_WIDTH loop
          if quot(idx) = '1' then
            low_or := '1';
          end if;
        end loop;
      end if;
    end if;

    if rem_val /= 0 then
      low_or := '1';
    end if;

    if low_or = '1' then
      mant_ext(0) := mant_ext(0) or low_or;
    end if;

    apply_rounding(res_u.sign, mant_ext, exp_res_i, round_mode, round_prec, mant_main, exp_res_i);

    if exp_res_i <= 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i >= FP_EXP_MAX then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res := to_unsigned(exp_res_i, FP_EXP_WIDTH);
    res_u.exp := exp_res;
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;

  function sqrt_fp80(
    a : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    constant SQRT_SCALE_SHIFT : natural := FP_MANT_WIDTH - 1 + FP_GRS_BITS - 32;
    constant MANT_EVEN_WIDTH : natural := FP_MANT_WIDTH + 2;
    constant RADICAND_WIDTH : natural := MANT_EVEN_WIDTH + (2 * SQRT_SCALE_SHIFT);
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable res_u : fp_unpacked_t;
    variable mantissa_even : unsigned(MANT_EVEN_WIDTH-1 downto 0) := (others => '0');
    variable radicand : unsigned(RADICAND_WIDTH-1 downto 0) := (others => '0');
    variable root : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable rem_val : unsigned(RADICAND_WIDTH-1 downto 0) := (others => '0');
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_unbiased : integer := 0;
    variable exp_out_i : integer := 0;
    variable nan_result : fp_unpacked_t;
  begin
    res_u.sign := '0';
    res_u.exp := (others => '0');
    res_u.mant := (others => '0');

    if a_u.exp = 0 then
      res_u.sign := a_u.sign;
      return pack_fp80(res_u);
    end if;

    if a_u.exp = FP_EXP_ALL_ONES then
      if a_u.mant = 0 and a_u.sign = '0' then
        return a;
      end if;
      nan_result.sign := '0';
      nan_result.exp := FP_EXP_ALL_ONES;
      nan_result.mant := (others => '0');
      nan_result.mant(FP_MANT_WIDTH-1) := '1';
      nan_result.mant(FP_MANT_WIDTH-2) := '1';
      return pack_fp80(nan_result);
    end if;

    if a_u.sign = '1' then
      nan_result.sign := '0';
      nan_result.exp := FP_EXP_ALL_ONES;
      nan_result.mant := (others => '0');
      nan_result.mant(FP_MANT_WIDTH-1) := '1';
      nan_result.mant(FP_MANT_WIDTH-2) := '1';
      return pack_fp80(nan_result);
    end if;

    exp_unbiased := to_integer(a_u.exp) - FP_EXP_BIAS;
    if (exp_unbiased mod 2) /= 0 then
      exp_unbiased := exp_unbiased - 1;
      mantissa_even := shift_left(resize(a_u.mant, mantissa_even'length), 2);
    else
      mantissa_even := shift_left(resize(a_u.mant, mantissa_even'length), 1);
    end if;

    exp_out_i := exp_unbiased / 2 + FP_EXP_BIAS;

    radicand := shift_left(resize(mantissa_even, radicand'length), 2 * SQRT_SCALE_SHIFT);
    int_sqrt_with_rem(radicand, root, rem_val);
    if rem_val /= 0 then
      root(0) := '1';
    end if;

    apply_rounding('0', root, exp_out_i, round_mode, round_prec, mant_main, exp_out_i);

    if mant_main = 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_out_i <= 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_out_i >= FP_EXP_MAX then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    res_u.exp := to_unsigned(exp_out_i, FP_EXP_WIDTH);
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;

  function abs_fp80(value : fp80_t) return fp80_t is
    variable result : fp80_t := value;
  begin
    result(FP_WIDTH-1) := '0';
    return result;
  end function;

  function compare_magnitude(a : fp80_t; b : fp80_t) return integer is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
  begin
    if a_u.exp > b_u.exp then
      return 1;
    elsif a_u.exp < b_u.exp then
      return -1;
    elsif a_u.mant > b_u.mant then
      return 1;
    elsif a_u.mant < b_u.mant then
      return -1;
    else
      return 0;
    end if;
  end function;

  function compare_fp80(a : fp80_t; b : fp80_t) return integer is
    variable cmp_mag : integer := 0;
    variable a_abs : fp80_t := abs_fp80(a);
    variable b_abs : fp80_t := abs_fp80(b);
  begin
    if a_abs = (a_abs'range => '0') and b_abs = (b_abs'range => '0') then
      return 0;
    end if;

    if a(FP_WIDTH-1) /= b(FP_WIDTH-1) then
      if a(FP_WIDTH-1) = '1' then
        return -1;
      end if;
      return 1;
    end if;

    cmp_mag := compare_magnitude(a_abs, b_abs);
    if a(FP_WIDTH-1) = '1' then
      return -cmp_mag;
    end if;
    return cmp_mag;
  end function;

  function fp80_to_int_trunc(value : fp80_t) return integer is
    variable value_u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable shift : integer := 0;
    variable magnitude_u : unsigned(63 downto 0) := (others => '0');
    constant INT_HIGH_U64 : unsigned(63 downto 0) := to_unsigned(integer'high, 64);
    variable abs_int : integer := 0;
  begin
    if value_u.exp = 0 or value_u.exp = FP_EXP_ALL_ONES then
      return 0;
    end if;

    exp_i := to_integer(value_u.exp);
    shift := exp_i - FP_EXP_BIAS;
    if shift < 0 then
      return 0;
    end if;

    if shift > 30 then
      if value_u.sign = '1' then
        return integer'low;
      end if;
      return integer'high;
    end if;

    magnitude_u := resize(shift_right(value_u.mant, FP_MANT_WIDTH-1-shift), 64);
    if magnitude_u > INT_HIGH_U64 then
      if value_u.sign = '1' then
        return integer'low;
      end if;
      return integer'high;
    end if;

    -- `shift > 30` is already saturated above, so only 31 magnitude bits are valid.
    abs_int := to_integer(magnitude_u(30 downto 0));
    if value_u.sign = '1' then
      return -abs_int;
    end if;
    return abs_int;
  end function;

  function fp80_trunc_toward_zero(value : fp80_t) return fp80_t is
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
    -- Avoid dynamic-width slices for synthesis; clear fractional bits with a fixed loop.
    for bit_idx in 0 to FP_MANT_WIDTH-1 loop
      if bit_idx < frac_bits then
        result_u.mant(bit_idx) := '0';
      end if;
    end loop;
    return pack_fp80(result_u);
  end function;

  function fp80_is_odd_integer(value : fp80_t) return boolean is
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
      -- ULP > 1, all representable integers at this magnitude are even.
      return false;
    end if;

    lsb_idx := integer(FP_MANT_WIDTH - 1) - exp_i;
    return value_u.mant(lsb_idx) = '1';
  end function;

  function fmod_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable quotient : fp80_t := (others => '0');
    variable quotient_u : fp_unpacked_t;
    variable quotient_trunc : fp80_t := (others => '0');
    variable quotient_i : integer := 0;
    variable product : fp80_t := (others => '0');
    variable result : fp80_t := (others => '0');
    variable nan_result : fp_unpacked_t;
  begin
    if b_u.exp = 0 and b_u.mant = 0 then
      nan_result.sign := '0';
      nan_result.exp := FP_EXP_ALL_ONES;
      nan_result.mant := (others => '0');
      nan_result.mant(FP_MANT_WIDTH-1) := '1';
      return pack_fp80(nan_result);
    end if;

    quotient := div_fp80(a, b, FP_RND_ZERO, FP_PREC_EXTENDED);
    quotient_u := unpack_fp80(quotient);
    if quotient_u.exp /= 0 and quotient_u.exp /= FP_EXP_ALL_ONES and
       (to_integer(quotient_u.exp) - FP_EXP_BIAS) <= 30 then
      quotient_i := fp80_to_int_trunc(quotient);
      quotient_trunc := fp80_from_int(quotient_i);
    else
      quotient_trunc := fp80_trunc_toward_zero(quotient);
    end if;
    product := mul_fp80(b, quotient_trunc, FP_RND_NEAREST, FP_PREC_EXTENDED);
    result := add_sub_fp80(a, product, true, round_mode, round_prec);
    return result;
  end function;

  function frem_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable quotient : fp80_t := (others => '0');
    variable quotient_u : fp_unpacked_t;
    variable quotient_trunc : fp80_t := (others => '0');
    variable nearest_q : fp80_t := (others => '0');
    variable quotient_i : integer := 0;
    variable nearest_i : integer := 0;
    variable step_i : integer := 0;
    variable use_integer_path : boolean := false;
    variable frac : fp80_t := (others => '0');
    variable frac_abs : fp80_t := (others => '0');
    variable half_fp : fp80_t := x"3FFE8000000000000000";
    variable one_fp : fp80_t := x"3FFF8000000000000000";
    variable half_cmp : integer := 0;
    variable product : fp80_t := (others => '0');
    variable result : fp80_t := (others => '0');
    variable nan_result : fp_unpacked_t;
  begin
    if b_u.exp = 0 and b_u.mant = 0 then
      nan_result.sign := '0';
      nan_result.exp := FP_EXP_ALL_ONES;
      nan_result.mant := (others => '0');
      nan_result.mant(FP_MANT_WIDTH-1) := '1';
      return pack_fp80(nan_result);
    end if;

    quotient := div_fp80(a, b, FP_RND_NEAREST, FP_PREC_EXTENDED);
    quotient_u := unpack_fp80(quotient);
    use_integer_path := quotient_u.exp /= 0 and quotient_u.exp /= FP_EXP_ALL_ONES and
      (to_integer(quotient_u.exp) - FP_EXP_BIAS) <= 30;

    if use_integer_path then
      quotient_i := fp80_to_int_trunc(quotient);
      nearest_i := quotient_i;
      quotient_trunc := fp80_from_int(quotient_i);
      frac := add_sub_fp80(quotient, quotient_trunc, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
      frac_abs := abs_fp80(frac);
      half_cmp := compare_fp80(frac_abs, half_fp);
      if quotient(FP_WIDTH-1) = '1' then
        step_i := -1;
      else
        step_i := 1;
      end if;
      if half_cmp > 0 then
        if not ((step_i > 0 and nearest_i = integer'high) or
                (step_i < 0 and nearest_i = integer'low)) then
          nearest_i := nearest_i + step_i;
        end if;
      elsif half_cmp = 0 and (quotient_i rem 2) /= 0 then
        if not ((step_i > 0 and nearest_i = integer'high) or
                (step_i < 0 and nearest_i = integer'low)) then
          nearest_i := nearest_i + step_i;
        end if;
      end if;
      nearest_q := fp80_from_int(nearest_i);
    else
      quotient_trunc := fp80_trunc_toward_zero(quotient);
      nearest_q := quotient_trunc;
      frac := add_sub_fp80(quotient, quotient_trunc, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
      frac_abs := abs_fp80(frac);
      half_cmp := compare_fp80(frac_abs, half_fp);
      if half_cmp > 0 then
        if quotient(FP_WIDTH-1) = '1' then
          nearest_q := add_sub_fp80(nearest_q, one_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
        else
          nearest_q := add_sub_fp80(nearest_q, one_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
        end if;
      elsif half_cmp = 0 and fp80_is_odd_integer(quotient_trunc) then
        if quotient(FP_WIDTH-1) = '1' then
          nearest_q := add_sub_fp80(nearest_q, one_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
        else
          nearest_q := add_sub_fp80(nearest_q, one_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
        end if;
      end if;
    end if;

    product := mul_fp80(b, nearest_q, FP_RND_NEAREST, FP_PREC_EXTENDED);
    result := add_sub_fp80(a, product, true, round_mode, round_prec);
    return result;
  end function;

  function fscale_fp80(a : fp80_t; b : fp80_t) return fp80_t is
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable scale_i : integer := fp80_to_int_trunc(a);
    variable exp_i : integer := 0;
    variable result_u : fp_unpacked_t := b_u;
  begin
    if b_u.exp = 0 or b_u.exp = FP_EXP_ALL_ONES then
      return b;
    end if;

    exp_i := to_integer(b_u.exp) + scale_i;
    if exp_i <= 0 then
      result_u.exp := (others => '0');
      result_u.mant := (others => '0');
      return pack_fp80(result_u);
    end if;

    if exp_i >= FP_EXP_MAX then
      result_u.exp := FP_EXP_ALL_ONES;
      result_u.mant := (others => '0');
      return pack_fp80(result_u);
    end if;

    result_u.exp := to_unsigned(exp_i, FP_EXP_WIDTH);
    return pack_fp80(result_u);
  end function;

  function sgldiv_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t is
  begin
    return div_fp80(a, b, round_mode, FP_PREC_SINGLE);
  end function;

  function sglmul_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t is
  begin
    return mul_fp80(a, b, round_mode, FP_PREC_SINGLE);
  end function;
end package body mc68881_pkg;
