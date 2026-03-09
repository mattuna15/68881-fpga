# mc68881_wrapper.xdc
# Timing constraints for CDC synchronizer flip-flops in the bus bridge.
# Include this file when using mc68881_axilite_wrapper or mc68881_wishbone_wrapper.

# ASYNC_REG on CDC synchronizer flip-flops (also set via VHDL attributes)
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ */u_bridge/req_ff*_reg}]
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ */u_bridge/ack_ff*_reg}]
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ */u_bridge/err_ff*_reg}]
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ */u_bridge/valid_ff*_reg}]
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ */u_bridge/rst_ff*_reg}]

# False paths on CDC toggle signals (bus_clk -> fpu_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/req_toggle_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/req_ff1_reg*}]

# False paths on CDC toggle signals (fpu_clk -> bus_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/ack_toggle_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/ack_ff1_reg*}]

# False path on error flag CDC (fpu_clk -> bus_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/fpu_error_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/err_ff1_reg*}]

# False path on status_valid CDC (fpu_clk -> bus_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_fpu/status_valid_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/valid_ff1_reg*}]

# False path on reset synchronizer (async input -> first sync FF)
set_false_path -to [get_cells -quiet -hier -filter {NAME =~ */u_bridge/rst_ff1_reg*}]

# CDC data paths: request fields are stable before toggle crosses
# (toggle handshake guarantees data is settled before the toggle propagates)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/req_addr_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/fpu_addr_reg* && IS_SEQUENTIAL}]
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/req_wdata_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/fpu_wdata_reg* && IS_SEQUENTIAL}]
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/req_rw_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/fpu_rw_reg* && IS_SEQUENTIAL}]

# Read data path: rdata_fpu_reg (fpu_clk) is stable before ack toggle crosses back.
# bridge_rdata is registered in p_bus_clk, so the CDC crossing is
# rdata_fpu_reg -> bridge_rdata_reg.  Also cover the downstream rdata_reg
# in the wrapper (same bus_clk domain, but belt-and-suspenders).
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/rdata_fpu_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */u_bridge/bridge_rdata_reg* && IS_SEQUENTIAL}]
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ */u_bridge/rdata_fpu_reg* && IS_SEQUENTIAL}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ */rdata_reg_reg* && IS_SEQUENTIAL}]
