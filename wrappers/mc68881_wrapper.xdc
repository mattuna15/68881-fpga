# mc68881_wrapper.xdc
# Timing constraints for CDC synchronizer flip-flops in the bus bridge.
# Include this file when using mc68881_axilite_wrapper or mc68881_wishbone_wrapper.

# ASYNC_REG on CDC synchronizer flip-flops (also set via VHDL attributes)
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/req_ff*_reg}]
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/ack_ff*_reg}]
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/valid_ff*_reg}]
set_property ASYNC_REG true [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/rst_ff*_reg}]

# False paths on CDC toggle signals (bus_clk → fpu_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/req_toggle_reg*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/req_ff1_reg*}]

# False paths on CDC toggle signals (fpu_clk → bus_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/ack_toggle_reg*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/ack_ff1_reg*}]

# False path on status_valid CDC (fpu_clk → bus_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *fpu_inst*/status_valid*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/valid_ff1_reg*}]

# False path on reset synchronizer (bus_clk → fpu_clk)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/bus_reset_n*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/rst_ff1_reg*}]

# CDC data paths: request fields are stable before toggle crosses
# (covered by toggle handshake protocol, but max_delay is good practice)
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/req_addr_reg*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/fpu_addr_reg*}]
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/req_wdata_reg*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/fpu_wdata_reg*}]
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/req_rw_reg*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/fpu_rw_reg*}]

# Read data path: stable before ack toggle crosses back
set_false_path -from [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/rdata_fpu_reg*}] \
               -to   [get_cells -quiet -hier -filter {NAME =~ *bus_bridge*/bridge_rdata*}]
