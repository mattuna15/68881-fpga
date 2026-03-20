# mc68881_ooc_timing.xdc
# Multi-cycle path constraints for mc68881 inside the AXI-Lite wrapper.
# Adapted from mc68881_top.xdc for the OOC (out-of-context) synthesis context
# where the wrapper is the hierarchy root and record types are decomposed
# into field-level registers.
#
# All patterns use */u_fpu/ prefix to scope within the wrapper hierarchy.
# Uses -quiet on get_pins to avoid warnings for legitimately optimized-away registers.

# ======================================================
# Multi-Cycle Path Constraints
# ======================================================

# --- Operand staging -> operand_reg (4-cycle MCP) ---
# Format conversion (fp80_from_int/single/double, packed96_to_fp80_fast) path.
# RTL ensures 4-cycle separation via CIR_XFER_SRC_WAIT + CIR_XFER_SRC_WAIT2.
set_multicycle_path -setup 4 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/cir_operand_staging_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/operand_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/cir_operand_staging_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/operand_reg_reg*/D}]

# --- Trig a_reg -> log_exp_term / log_unbiased_exp / log_exp_term_zero (7-cycle MCP) ---
set_multicycle_path -setup 7 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -setup 7 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_unbiased_exp_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_unbiased_exp_reg_reg*/D}]
set_multicycle_path -setup 7 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_exp_term_zero_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_exp_term_zero_reg_reg*/D}]

# --- Trig a_reg -> x_reg (7-cycle) ---
set_multicycle_path -setup 7 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/x_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/x_reg_reg*/D}]

# --- Lightweight simple ALU ops -> result (3-cycle MCP = 60ns @ 50 MHz) ---
# Remaining lightweight ops (FINT, CMP, ABS, NEG, etc.) need 3-cycle MCP for 50 MHz.
# (Was 2-cycle at 33 MHz; 45ns data path needs >40ns budget.)
set_multicycle_path -setup 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/simple_a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/simple_a_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]
set_multicycle_path -setup 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/simple_b_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/simple_b_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]
set_multicycle_path -setup 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/simple_op_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/simple_op_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]

# --- Packed decimal fp80_to_int_trunc (4-cycle MCP) ---
# packed_unit_inst is inside generate block packed_engine_full_g in mc68881_top
set_multicycle_path -setup 4 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/packed_engine_full_g.packed_unit_inst/arith_int_arg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/packed_engine_full_g.packed_unit_inst/arith_int_res_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/packed_engine_full_g.packed_unit_inst/arith_int_arg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/packed_engine_full_g.packed_unit_inst/arith_int_res_reg_reg*/D}]

# --- operand_reg -> result (14-cycle MCP) ---
set_multicycle_path -setup 14 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]
set_multicycle_path -hold 13 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/result_reg_reg*/D}]

# --- operand_reg -> MOVE handler destinations ---
# fp_reg_file and result_ex paths have 64+ logic levels requiring MCP=3 at 50 MHz.
# Operand is loaded during CIR transfer, 3+ cycles before MOVE completion.
set_multicycle_path -setup 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/fp_reg_file_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/fp_reg_file_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_opa_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_opa_reg_reg*/D}]

# Bumped to MCP=3: operand format conversion path to exc_event_result has 69
# logic levels (41.5ns at -1 speed grade).
set_multicycle_path -setup 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_result_reg_reg*/D}]

set_multicycle_path -setup 3 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_ex_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_ex_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_lo_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_lo_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_hi_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/operand_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_hi_reg_reg*/D}]

# --- fp_reg_file_reg -> MOVE REG_TO_MEM destinations (2-cycle MCP) ---
set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_force_inexact_reg_reg/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_force_inexact_reg_reg/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_force_overflow_reg_reg/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_force_overflow_reg_reg/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_force_underflow_reg_reg/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_force_underflow_reg_reg/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_result_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_opa_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_opa_reg_reg*/D}]

# fp_reg_file_reg -> result_hi_reg / result_lo_reg (2-cycle MCP)
# MOVE REG_TO_MEM reads fp_reg_file(src), does fp80_to_single/double rounding,
# writes result_hi/lo.  Same timing guarantee as exc_event paths above.
set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_hi_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_hi_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_lo_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_lo_reg_reg*/D}]

# --- move_cfg_reg -> MOVE handler destinations (2-cycle MCP) ---
# The VHDL signal move_cfg_decoded_reg (record type move_cfg_t) was optimized away
# by synthesis; the decode logic was absorbed into combinational paths from
# move_cfg_reg (std_logic_vector(31 downto 0)) which synthesizes as move_cfg_reg_reg[31:0].
# The MCP rationale is the same: move_cfg_reg is written via bus write, and the MOVE
# handler only reads it several bus cycles later when cir_launch_alu fires.
set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/fp_reg_file_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/fp_reg_file_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_opa_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_opa_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/exc_event_result_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_ex_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_ex_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_lo_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_lo_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_hi_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/move_cfg_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/result_hi_reg_reg*/D}]

# --- cir_dst_reg_idx -> result_hi/lo_reg (2-cycle MCP) ---
# Destination register index decoded during CIR dispatch, stable through MOVE.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/result_lo_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/result_lo_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/result_hi_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/result_hi_reg_reg*}]

# --- fp_reg_file_reg -> cir_operand_staging (2-cycle MCP) ---
# FMOVE REG_TO_MEM format conversion path. Register file stable from prior op.
set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/cir_operand_staging_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/fp_reg_file_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/cir_operand_staging_reg*/D}]

# --- fpcr_reg -> exc_event_force_* (2-cycle MCP) ---
# FPCR written by host bus write, stable before MOVE dispatch evaluates exceptions.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/fpcr_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/exc_event_force_*_reg}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/fpcr_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ */u_fpu/exc_event_force_*_reg}]

# --- Trig log_unbiased_exp_reg -> mul_a_reg / log_exp_term_reg (2-cycle MCP) ---
set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/mul_a_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/mul_a_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -quiet -hier -filter {REF_PIN_NAME == C && NAME =~ */u_fpu/alu_inst/trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -quiet -hier -filter {REF_PIN_NAME == D && NAME =~ */u_fpu/alu_inst/trig_inst/log_exp_term_reg_reg*/D}]
