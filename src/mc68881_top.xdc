# MC68881 FPGA - Timing and I/O Constraints for xc7a200t
# ======================================================

# Configuration voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# Clock: 50 MHz target (20.0ns period)
create_clock -period 20.0 -name sys_clk [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN U22 [get_ports clk]

# Reset
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]
set_property PACKAGE_PIN P4 [get_ports reset_n]

# Bus interface - IOSTANDARD (PACKAGE_PIN assignments are board-specific)
set_property IOSTANDARD LVCMOS33 [get_ports {a_in[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d_in[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d_out[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports size_n]
set_property IOSTANDARD LVCMOS33 [get_ports a0_in]
set_property IOSTANDARD LVCMOS33 [get_ports as_n]
set_property IOSTANDARD LVCMOS33 [get_ports cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports rw]
set_property IOSTANDARD LVCMOS33 [get_ports ds_n]
set_property IOSTANDARD LVCMOS33 [get_ports dsack0_n]
set_property IOSTANDARD LVCMOS33 [get_ports dsack1_n]
set_property IOSTANDARD LVCMOS33 [get_ports sense_n]

# ======================================================
# Multi-Cycle Path Constraints
# ======================================================

# --- Operand staging -> operand_reg (4-cycle MCP = 80ns @ 50MHz) ---
# Format conversion (fp80_from_int/single/double, packed96_to_fp80_fast) path.
# RTL ensures 4-cycle separation via CIR_XFER_SRC_WAIT + CIR_XFER_SRC_WAIT2.
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ cir_operand_staging_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ operand_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ cir_operand_staging_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ operand_reg_reg*/D}]

# --- MC68882 pending operand staging -> operand_reg (5-cycle MCP = 100ns @ 50MHz) ---
# Same format conversion path as above, but for 68882 concurrent instruction launch.
# RTL ensures 5-cycle separation via CIR_PENDING_XFER_SRC_WAIT/WAIT2/WAIT3.
set_multicycle_path -setup 5 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ pending_operand_staging_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ operand_reg_reg*/D}]
set_multicycle_path -hold 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ pending_operand_staging_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ operand_reg_reg*/D}]

# --- Trig a_reg -> log_exp_term / log_unbiased_exp / log_exp_term_zero (7-cycle MCP = 212ns) ---
set_multicycle_path -setup 7 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -setup 7 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/D}]
set_multicycle_path -setup 7 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_zero_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_zero_reg_reg*/D}]

# --- Trig a_reg -> x_reg (7-cycle) ---
set_multicycle_path -setup 7 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/x_reg_reg*/D}]
set_multicycle_path -hold 6 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/x_reg_reg*/D}]

# ST_FP_MUL and ST_FP_ADD now use sequential mc68881_fp80_mul_unit and
# mc68881_fp80_addsub_unit in trig_inst, so no mul/add MCP constraints
# are required here. tmp_reg is only written from registered outputs.

# ST_FP_DIV now uses sequential mc68881_divrem_unit in trig_inst,
# so no direct div_*_reg -> tmp_reg MCP is required here.

# --- Lightweight simple ALU ops -> result (3-cycle MCP = 60ns @ 50 MHz) ---
# ADD/SUB/MUL now use sequential mc68881_fp80_mul_unit / mc68881_fp80_addsub_unit.
# Remaining lightweight ops (FINT, CMP, ABS, NEG, etc.) need 3-cycle MCP for 50 MHz.
# (Was 2-cycle at 33 MHz; 45ns data path needs >40ns budget.)
set_multicycle_path -setup 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -setup 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -setup 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_op_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_op_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]

# --- Packed decimal fp80_to_int_trunc (4-cycle MCP = 121ns) ---
# MUL/ADD paths now use sequential units; only int_trunc remains combinational.
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *packed_unit_inst/arith_int_arg_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *packed_unit_inst/arith_int_res_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *packed_unit_inst/arith_int_arg_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *packed_unit_inst/arith_int_res_reg_reg*/D}]

# --- operand_reg -> result (14-cycle MCP = 424ns) ---
set_multicycle_path -setup 14 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 13 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]

# --- operand_reg -> MOVE handler destinations (3-cycle MCP for fp_reg_file, 2 for others) ---
# Format conversion path (fp80_from_int/single/double, packed96_to_fp80_fast)
# in alu_control_proc MOVE dispatch.  operand_reg loaded same edge as MOVE
# fires, but VHDL delta semantics mean ALU reads OLD value; next cir_launch_alu
# is >=3 cycles later. fp_reg_file path has 64 logic levels requiring MCP=3.
set_multicycle_path -setup 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *fp_reg_file_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *fp_reg_file_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]

# Bumped to MCP=3: operand format conversion path to exc_event_result has 69
# logic levels (41.5ns at -1 speed grade).  Operand is loaded during CIR transfer,
# 3+ cycles before MOVE completion evaluates exception events.
set_multicycle_path -setup 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]
set_multicycle_path -hold 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_ex_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_ex_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]

# --- CIR state -> MOVE exception + result destinations (2-cycle MCP) ---
# CIR FSM state decode feeds into MOVE dispatch and format conversion
# (fp80_to_single/double rounding). State is stable through MOVE execution.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_result_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_result_reg_reg*}]

# CIR state -> result_lo/hi/ex (2-cycle MCP)
# CIR FSM state feeds into MOVE dispatch format conversion and register file
# write mux. State is stable through MOVE execution.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_lo_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_lo_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_hi_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_hi_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_ex_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_state_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_ex_reg_reg*}]

# --- cir_dst_reg_idx -> MOVE result + exception destinations (2-cycle MCP) ---
# Destination register index is decoded during CIR cpGEN dispatch, stable
# through the entire MOVE/ALU execution pipeline. Feeds into fp_reg_file_reg
# write mux, exc_event_result format conversion, and exc_event_force_* comparison.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_result_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_result_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fp_reg_file_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fp_reg_file_reg_reg*}]

# --- operand_reg -> fp_reg_file_reg (3-cycle MCP) ---
# Operand data feeds through format conversion (unpack + fp80_to_single/double
# rounding + register file write mux). At 50 MHz, the 64 logic levels exceed
# MCP=2 (40ns). Operand is loaded during CIR transfer, 3+ cycles before
# MOVE completion writes the register file.
set_multicycle_path -setup 3 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *operand_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fp_reg_file_reg_reg*}]
set_multicycle_path -hold 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *operand_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fp_reg_file_reg_reg*}]

# --- operand_reg -> result_ex_reg (3-cycle MCP) ---
# Operand format conversion path to result exponent register. Same reasoning.
set_multicycle_path -setup 3 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *operand_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_ex_reg_reg*}]
set_multicycle_path -hold 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *operand_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_ex_reg_reg*}]

# --- fp_reg_file_reg -> MOVE REG_TO_MEM destinations (2-cycle MCP) ---
# MOVE REG_TO_MEM reads fp_reg_file_reg(src_idx), does format conversion
# (fp80_to_single/double rounding + inexact comparison), writes exc_event_force_*.
# fp_reg_file_reg is written by prior ALU/MOVE completion, >=3 CIR pipeline
# cycles before next MOVE dispatch.
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_force_inexact_reg_reg/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_force_inexact_reg_reg/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_force_overflow_reg_reg/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_force_overflow_reg_reg/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_force_underflow_reg_reg/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_force_underflow_reg_reg/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]

# fp_reg_file_reg -> result_hi_reg / result_lo_reg (2-cycle MCP)
# MOVE REG_TO_MEM reads fp_reg_file(src), does fp80_to_single/double rounding,
# writes result_hi/lo.  Same timing guarantee as exc_event paths above.
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]

# --- move_cfg register -> MOVE handler destinations (2-cycle MCP = 40ns @ 50MHz) ---
# move_cfg loaded via ADDR_MOVE_CFG bus write, at least 4+ bus cycles before
# MOVE dispatch fires via cir_launch_alu.
# Note: Vivado may synthesize the record as either move_cfg_decoded_reg_reg or
# move_cfg_reg_reg depending on optimization. Both patterns are constrained.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fp_reg_file_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fp_reg_file_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_opa_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_opa_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_result_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_result_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_ex_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_ex_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_lo_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_lo_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_hi_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_hi_reg_reg*}]

# move_cfg -> exc_event_force_* (2-cycle MCP)
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *move_cfg*reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]

# --- cir_dst_reg_idx -> result_hi/lo_reg (2-cycle MCP) ---
# Destination register index is decoded during CIR cpGEN dispatch, stable
# through the entire MOVE/ALU execution pipeline.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_lo_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_lo_reg_reg*}]

set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_hi_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *cir_dst_reg_idx_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *result_hi_reg_reg*}]

# --- fp_reg_file_reg -> cir_operand_staging (2-cycle MCP) ---
# FMOVE REG_TO_MEM reads fp_reg_file(src), does format conversion,
# writes to cir_operand_staging for transfer back to host.
# Register file is stable (written by prior op), MOVE dispatch takes 2+ CIR cycles.
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *cir_operand_staging_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *fp_reg_file_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *cir_operand_staging_reg*/D}]

# --- fpcr_reg -> exc_event_force_* (2-cycle MCP) ---
# FPCR is written by host bus write, well before MOVE dispatch evaluates
# exception conditions.  Rounding mode and precision are stable during MOVE.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fpcr_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *fpcr_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *exc_event_force_*_reg}]

# --- Trig log_unbiased_exp_reg -> mul_a_reg / log_exp_term_reg (2-cycle MCP = 60.6ns) ---
# fp80_from_int(log_unbiased_exp_reg) conversion path.  ST_LOG_GETEXP_HOLD
# provides the extra cycle (2-cycle separation).  LOGNP1 variant has
# ST_LOGNP1_META_POST as intermediate (also 2-cycle).
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/mul_a_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/mul_a_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]

# --- Trig exp_k_reg -> result_reg (2-cycle MCP) ---
# exp_k_reg loaded at ST_EXP_REDUCE_K_POST, consumed at ST_TRANS_POST_ADD_POST
# via fscale_fp80(). Separated by multiple FP MUL/ADD pipeline stages (many cycles).
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *trig_inst/exp_k_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *trig_inst/result_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *trig_inst/exp_k_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *trig_inst/result_reg_reg*}]

# --- Divrem sqrt_exp_out_reg -> result_reg (2-cycle MCP) ---
# sqrt_exp_out_reg loaded at ST_SQRT_INIT, consumed at ST_SQRT_POST after the
# entire SQRT iteration loop (67+ cycles separation). Covers both ALU and trig
# divrem instances.
set_multicycle_path -setup 2 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *sqrt_exp_out_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *divrem_inst/result_reg_reg*}]
set_multicycle_path -hold 1 -quiet -from [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *sqrt_exp_out_reg_reg*}] -to [get_cells -quiet -hier -filter {REF_NAME =~ FD* && NAME =~ *divrem_inst/result_reg_reg*}]

# Modpost add/mul paths now use sequential units — no combinational FP MCP needed.
