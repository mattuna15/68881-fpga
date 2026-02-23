# MC68881 FPGA - Timing and I/O Constraints for xc7a200t
# ======================================================

# Configuration voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# Clock: 10 MHz initial target (100ns period)
create_clock -period 100.000 -name sys_clk [get_ports clk]
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

# --- Trig a_reg -> log_exp_term (2-cycle MCP = 200ns) ---
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_term_reg_reg*/D}]
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/log_exp_reg_reg*/D}]

# --- Trig a_reg -> x_reg (2-cycle) ---
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/x_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/x_reg_reg*/D}]

# --- Trig tmp_reg (4-cycle = 400ns) ---
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/x_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/x_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]

# --- Trig FP engine -> tmp_reg MCPs (match ST_FP_* hold scheduling) ---
# ST_FP_MUL: launch to capture in 2 cycles.
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/mul_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/mul_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -setup 2 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/mul_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 1 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/mul_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]

# ST_FP_ADD: launch to capture in 4 cycles.
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_rm_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_rm_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_rp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *trig_inst/add_rp_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *trig_inst/tmp_reg_reg*/D}]

# ST_FP_DIV now uses sequential mc68881_divrem_unit in trig_inst,
# so no direct div_*_reg -> tmp_reg MCP is required here.

# --- Simple ALU ops -> result (4-cycle MCP = 400ns) ---
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_a_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_b_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_op_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *simple_op_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]

# --- operand_reg -> result (4-cycle MCP = 400ns) ---
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *operand_reg_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *result_reg_reg*/D}]

# --- Modpost paths (4-cycle MCP = 400ns) ---
# Scope only the ALU divrem modpost instance. Avoid constraining similarly named
# internals in other units (e.g. trig-local divider helpers).
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_fp_add_a_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_add_result_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_fp_add_a_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_add_result_reg_reg*/D}]
set_multicycle_path -setup 4 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_fp_add_b_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_add_result_reg_reg*/D}]
set_multicycle_path -hold 3 -from [get_pins -hier -filter {REF_PIN_NAME == C && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_fp_add_b_reg*/C}] -to [get_pins -hier -filter {REF_PIN_NAME == D && NAME =~ *alu_inst/divrem_inst/gen_modpost_on.modpost_inst/mod_add_result_reg_reg*/D}]
