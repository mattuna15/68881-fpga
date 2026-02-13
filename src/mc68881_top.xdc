#set_property IOSTANDARD LVCMOS33 [get_ports {led_1}]
#set_property PACKAGE_PIN T23 [get_ports {led_1}]
#set_property IOSTANDARD LVCMOS33 [get_ports {led_2}]
#set_property PACKAGE_PIN R23 [get_ports {led_2}]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PACKAGE_PIN P4 [get_ports sys_rst_n]

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]


### Auto-generated from tmp/core-db-pr2.xdc
### Profile: core_ddr

## ddr_a[0]
#set_property PACKAGE_PIN N3   [get_ports {ddr_a[0]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[0]}]

## ddr_a[1]
#set_property PACKAGE_PIN P7   [get_ports {ddr_a[1]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[1]}]

## ddr_a[10]
#set_property PACKAGE_PIN L7   [get_ports {ddr_a[10]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[10]}]

## ddr_a[11]
#set_property PACKAGE_PIN R7   [get_ports {ddr_a[11]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[11]}]

## ddr_a[12]
#set_property PACKAGE_PIN N7   [get_ports {ddr_a[12]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[12]}]

## ddr_a[13]
#set_property PACKAGE_PIN T3   [get_ports {ddr_a[13]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[13]}]

## ddr_a[2]
#set_property PACKAGE_PIN P3   [get_ports {ddr_a[2]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[2]}]

## ddr_a[3]
#set_property PACKAGE_PIN N2   [get_ports {ddr_a[3]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[3]}]

## ddr_a[4]
#set_property PACKAGE_PIN P8   [get_ports {ddr_a[4]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[4]}]

## ddr_a[5]
#set_property PACKAGE_PIN P2   [get_ports {ddr_a[5]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[5]}]

## ddr_a[6]
#set_property PACKAGE_PIN R8   [get_ports {ddr_a[6]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[6]}]

## ddr_a[7]
#set_property PACKAGE_PIN R2   [get_ports {ddr_a[7]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[7]}]

## ddr_a[8]
#set_property PACKAGE_PIN T8   [get_ports {ddr_a[8]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[8]}]

## ddr_a[9]
#set_property PACKAGE_PIN R3   [get_ports {ddr_a[9]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_a[9]}]

## ddr_ba[0]
#set_property PACKAGE_PIN M2   [get_ports {ddr_ba[0]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_ba[0]}]

## ddr_ba[1]
#set_property PACKAGE_PIN N8   [get_ports {ddr_ba[1]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_ba[1]}]

## ddr_ba[2]
#set_property PACKAGE_PIN M3   [get_ports {ddr_ba[2]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_ba[2]}]

## ddr_cas_n
#set_property PACKAGE_PIN K3   [get_ports {ddr_cas_n}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_cas_n}]

## ddr_ck_n
#set_property PACKAGE_PIN K7   [get_ports {ddr_ck_n}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr_ck_n}]

## ddr_ck_p
#set_property PACKAGE_PIN J7   [get_ports {ddr_ck_p}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr_ck_p}]

## ddr_cke
#set_property PACKAGE_PIN K9   [get_ports {ddr_cke}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_cke}]

## ddr_cs_n
#set_property PACKAGE_PIN L2   [get_ports {ddr_cs_n}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_cs_n}]

## ddr_dm[0]
#set_property PACKAGE_PIN E7   [get_ports {ddr_dm[0]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dm[0]}]

## ddr_dm[1]
#set_property PACKAGE_PIN D3   [get_ports {ddr_dm[1]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dm[1]}]

## ddr_dq[0]
#set_property PACKAGE_PIN E3   [get_ports {ddr_dq[0]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[0]}]

## ddr_dq[1]
#set_property PACKAGE_PIN F7   [get_ports {ddr_dq[1]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[1]}]

## ddr_dq[10]
#set_property PACKAGE_PIN C8   [get_ports {ddr_dq[10]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[10]}]

## ddr_dq[11]
#set_property PACKAGE_PIN C2   [get_ports {ddr_dq[11]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[11]}]

## ddr_dq[12]
#set_property PACKAGE_PIN A7   [get_ports {ddr_dq[12]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[12]}]

## ddr_dq[13]
#set_property PACKAGE_PIN A2   [get_ports {ddr_dq[13]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[13]}]

## ddr_dq[14]
#set_property PACKAGE_PIN B8   [get_ports {ddr_dq[14]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[14]}]

## ddr_dq[15]
#set_property PACKAGE_PIN A3   [get_ports {ddr_dq[15]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[15]}]

## ddr_dq[2]
#set_property PACKAGE_PIN F2   [get_ports {ddr_dq[2]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[2]}]

## ddr_dq[3]
#set_property PACKAGE_PIN F8   [get_ports {ddr_dq[3]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[3]}]

## ddr_dq[4]
#set_property PACKAGE_PIN H3   [get_ports {ddr_dq[4]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[4]}]

## ddr_dq[5]
#set_property PACKAGE_PIN H8   [get_ports {ddr_dq[5]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[5]}]

## ddr_dq[6]
#set_property PACKAGE_PIN G2   [get_ports {ddr_dq[6]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[6]}]

## ddr_dq[7]
#set_property PACKAGE_PIN H7   [get_ports {ddr_dq[7]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[7]}]

## ddr_dq[8]
#set_property PACKAGE_PIN D7   [get_ports {ddr_dq[8]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[8]}]

## ddr_dq[9]
#set_property PACKAGE_PIN C3   [get_ports {ddr_dq[9]}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_dq[9]}]

## ddr_dqs_n[0]
#set_property PACKAGE_PIN G3  [get_ports {ddr_dqs_n[0]}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr_dqs_n[0]}]

## ddr_dqs_n[1]
#set_property PACKAGE_PIN B7  [get_ports {ddr_dqs_n[1]}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr_dqs_n[1]}]

## ddr_dqs_p[0]
#set_property PACKAGE_PIN F3  [get_ports {ddr_dqs_p[0]}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr_dqs_p[0]}]

## ddr_dqs_p[1]
#set_property PACKAGE_PIN C7  [get_ports {ddr_dqs_p[1]}]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr_dqs_p[1]}]

## ddr_odt
#set_property PACKAGE_PIN K1   [get_ports {ddr_odt}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_odt}]

## ddr_ras_n
#set_property PACKAGE_PIN J3   [get_ports {ddr_ras_n}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_ras_n}]

## ddr_reset_n
#set_property PACKAGE_PIN T2   [get_ports {ddr_reset_n}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_reset_n}]

## ddr_we_n
#set_property PACKAGE_PIN L3   [get_ports {ddr_we_n}]
#set_property IOSTANDARD SSTL15 [get_ports {ddr_we_n}]
