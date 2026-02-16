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
# FP combinational functions (div_fp80, mul_fp80, add_sub_fp80) take longer
# than one 100ns clock period to settle.  The RTL holds inputs stable for
# N cycles via hold counters, so these MCP constraints are safe.

# --- Trig unit: div_fp80 (6 cycle MCP) ---
set_multicycle_path -setup 6 -from [get_cells alu_inst/trig_inst/div_a_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  5 -from [get_cells alu_inst/trig_inst/div_a_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 6 -from [get_cells alu_inst/trig_inst/div_b_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  5 -from [get_cells alu_inst/trig_inst/div_b_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 6 -from [get_cells alu_inst/trig_inst/div_rm_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  5 -from [get_cells alu_inst/trig_inst/div_rm_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 6 -from [get_cells alu_inst/trig_inst/div_rp_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  5 -from [get_cells alu_inst/trig_inst/div_rp_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]

# --- Trig unit: mul_fp80 (2 cycle MCP) ---
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/mul_a_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/mul_a_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/mul_b_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/mul_b_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/mul_rm_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/mul_rm_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/mul_rp_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/mul_rp_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]

# --- Trig unit: add_sub_fp80 (2 cycle MCP) ---
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/add_a_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/add_a_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/add_b_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/add_b_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/add_sub_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/add_sub_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/add_rm_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/add_rm_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/trig_inst/add_rp_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/trig_inst/add_rp_reg_reg*] \
                              -to   [get_cells alu_inst/trig_inst/tmp_reg_reg*]

# --- ALU: simple ops add_sub_fp80 / mul_fp80 (2 cycle MCP) ---
set_multicycle_path -setup 2 -from [get_cells alu_inst/simple_a_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/simple_a_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/simple_b_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/simple_b_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/simple_op_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/simple_op_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/simple_rm_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/simple_rm_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/simple_rp_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/simple_rp_reg_reg*] \
                              -to   [get_cells alu_inst/result_reg_reg*]

# --- Divrem unit: mod FP engines (2 cycle MCP) ---
# add_sub_fp80 paths
set_multicycle_path -setup 2 -from [get_cells alu_inst/divrem_inst/mod_fp_add_a_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/divrem_inst/mod_fp_add_a_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/divrem_inst/mod_fp_add_b_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/divrem_inst/mod_fp_add_b_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/divrem_inst/mod_fp_add_is_sub_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/divrem_inst/mod_fp_add_is_sub_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/divrem_inst/mod_fp_add_rm_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/divrem_inst/mod_fp_add_rm_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/divrem_inst/mod_fp_add_rp_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/divrem_inst/mod_fp_add_rp_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
# mul_fp80 paths
set_multicycle_path -setup 2 -from [get_cells alu_inst/divrem_inst/mod_fp_mul_a_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/divrem_inst/mod_fp_mul_a_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -setup 2 -from [get_cells alu_inst/divrem_inst/mod_fp_mul_b_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
set_multicycle_path -hold  1 -from [get_cells alu_inst/divrem_inst/mod_fp_mul_b_reg*] \
                              -to   [get_cells alu_inst/divrem_inst/*_reg*]
