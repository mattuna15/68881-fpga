# MC68881 FPGA - Timing and I/O Constraints for xc7a200t
# ======================================================

# Configuration voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# Clock: 33 MHz target (30.303ns period)
create_clock -period 30.303 -name sys_clk [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN U22 [get_ports clk]

# Reset
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]
set_property PACKAGE_PIN P4 [get_ports reset_n]

# Bus interface - IOSTANDARD (PACKAGE_PIN assignments are board-specific)
set_property IOSTANDARD LVCMOS33 [get_ports {a_in[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d_in[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {d_out[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {size_n[*]}]
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

# --- Operand staging -> operand_reg (4-cycle MCP = 121.2ns) ---
# Format conversion (fp80_from_int/single/double, packed96_to_fp80_fast) path.
# RTL ensures 4-cycle separation via CIR_XFER_SRC_WAIT + CIR_XFER_SRC_WAIT2.
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ cir_operand_staging_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ operand_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ cir_operand_staging_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ operand_reg_reg*/D}]

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

# --- Lightweight simple ALU ops -> result (2-cycle MCP = 200ns) ---
# ADD/SUB/MUL now use sequential mc68881_fp80_mul_unit / mc68881_fp80_addsub_unit.
# Remaining lightweight ops (FINT, CMP, ABS, NEG, etc.) need 2-cycle MCP.
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_op_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_op_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]

# --- Packed decimal fp80_to_int_trunc (4-cycle MCP = 121ns) ---
# MUL/ADD paths now use sequential units; only int_trunc remains combinational.
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *packed_unit_inst/arith_int_arg_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *packed_unit_inst/arith_int_res_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *packed_unit_inst/arith_int_arg_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *packed_unit_inst/arith_int_res_reg_reg*/D}]

# --- operand_reg -> result (14-cycle MCP = 424ns) ---
set_multicycle_path -setup 14 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 13 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]

# --- operand_reg -> MOVE handler destinations (2-cycle MCP = 60.6ns) ---
# Format conversion path (fp80_from_int/single/double, packed96_to_fp80_fast)
# in alu_control_proc MOVE dispatch.  operand_reg loaded same edge as MOVE
# fires, but VHDL delta semantics mean ALU reads OLD value; next cir_launch_alu
# is >=3 cycles later.
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *fp_reg_file_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *fp_reg_file_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_ex_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_ex_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]

# --- move_cfg_decoded_reg -> MOVE handler destinations (2-cycle MCP = 60.6ns) ---
# move_cfg_decoded_reg loaded via ADDR_MOVE_CFG bus write, at least 4+ bus
# cycles before MOVE dispatch fires via cir_launch_alu.
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *fp_reg_file_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *fp_reg_file_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_opa_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *exc_event_result_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_ex_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_ex_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_lo_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *move_cfg_decoded_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_hi_reg_reg*/D}]

# --- Trig log_unbiased_exp_reg -> mul_a_reg / log_exp_term_reg (2-cycle MCP = 60.6ns) ---
# fp80_from_int(log_unbiased_exp_reg) conversion path.  ST_LOG_GETEXP_HOLD
# provides the extra cycle (2-cycle separation).  LOGNP1 variant has
# ST_LOGNP1_META_POST as intermediate (also 2-cycle).
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/mul_a_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/mul_a_reg_reg*/D}]

set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/log_unbiased_exp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]

# Modpost add/mul paths now use sequential units — no combinational FP MCP needed.
