# Primary system clock constraint
# 50 MHz -> 20.000 ns period
create_clock -name sys_clk -period 20.000 [get_ports clk]
