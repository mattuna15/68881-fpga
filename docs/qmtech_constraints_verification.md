# Verification review: proposed `constraints.xdc` for QMTECH XC7A200T Core + DB-FPGA

## Scope
This review checks the user-supplied full constraints block against:

- QMTECH XC7A200T Core Board manual (hardware V01)
- DB-FPGA V5 board PDF

The review focuses on **pin consistency, overlap conflicts, and practical Vivado validity** for a single synthesized top-level.

## Result
**Status: NOT VALID as a single active `.xdc` file.**

The current file enables several connector/peripheral groups simultaneously that reuse the same physical FPGA pins. Vivado will report multiple `PACKAGE_PIN` assignments to different ports.

## Confirmed issues

### 1) Direct duplicate package-pin assignments in active constraints
These are hard conflicts (cannot coexist in one design):

- `T3`: `ddr_a[12]` and `ddr_ck_n`.
- `P4`: `btn_center` and `eth_rstn`.
- `C2`: `ddr_dq[8]` and `eth_tx_en`.
- `D1`: `eth_txd[1]` and `vga_blue3`.
- `E3`: `ddr_dq[0]`, `eth_txd[2]`, and `vga_green0`.
- `F2`: `ddr_dq[2]`, `eth_txd[5]`, and `vga_blue1`.
- `H3`: `ddr_dq[4]` and `eth_txd[6]`.
- `G1`: `ddr_dq[13]` and `eth_rx_dv`.
- `L2`: `ddr_cke` and `eth_rxd[5]`.
- `M1`: `ddr_dm[0]` and `eth_rxd[3]`.
- `N2`: `ddr_a[3]` and `eth_rxd[7]`.
- `N3`: `ddr_a[0]` and `eth_rxd[6]`.
- `P3`: `ddr_a[2]` and `eth_crs`.
- `R3`: `ddr_a[9]` and `eth_col`.
- `R2`: `ddr_a[7]` and `sd_dat0`.
- `T4`: `ddr_ck_p` and `sd_cd_dat3`.
- `T3`: `ddr_a[12]` / `ddr_ck_n` / `sd_cmd`.
- `B1`: `eth_tx_er` and `vga_vsync`.
- `D3`: `eth_txd[0]` and `vga_green3`.
- `E1`: `ddr_dq[15]` and `vga_blue0`.
- `E2`: `eth_txd[3]` and `vga_blue2`.
- `F3`: `eth_txd[4]` and `vga_green1`.
- `J25`: `rp_gpio12` and `pmod2_pin1`.
- `J26`: `rp_gpio13` and `pmod2_pin5`.
- `G20`: `rp_gpio14` and `pmod2_pin2`.
- `G21`: `rp_gpio15` and `pmod2_pin6`.
- `K22`: `rp_gpio20` and (`u2_bank_25` if uncommented).
- `K23`: `rp_gpio21` and (`u2_bank_26` if uncommented).
- `U21`: `rp_gpio23` and `pmod1_pin5`.
- `V21`: `rp_gpio22` and `pmod1_pin6`.
- `Y22`: `cam_p15` and `pmod1_pin1`.
- `Y23`: `cam_p16`, `pmod1_pin3`, `pmod1_pin8`.
- `Y25`: `rp_key`, `cam_p13`, `pmod1_pin7`.
- `AC24`: `rp_led` and `cam_p12`.

> Note: some overlaps are expected electrically because board connectors expose the same nets; however they still must not be constrained as **different HDL ports simultaneously**.

### 2) Constraint-structure issue: mutually exclusive interfaces are enabled together
The file comments mention conflicts (JTAG/SWD/ADC), but other conflict domains are still all active together:

- DDR + DB-FPGA Ethernet/VGA/SD mappings on overlapping U4 pins.
- RP2040 GPIO mappings + PMOD + Camera mappings where these are the same shared header nets.

This must be split into selectable profiles or one port-name namespace per physical net.

### 3) DDR `VREF` modeled as user port
`ddr_vref` is constrained as if it were a normal external top-level port. In normal Artix-7 DDR3 flows, VREF is a bank reference setting (board/pin requirement), not an RTL data/control net exported at top level.

## What matches documentation intent
- Core-board basics (50 MHz clock, LEDs, PROGRAM_B, DDR3 presence) are directionally aligned with manual content.
- DB-FPGA documents indicate shared J2/J3 header-net fanout across RP2040, Ethernet, VGA, SD, PMOD, and camera; this explains why many net names converge to the same FPGA package pins.

## Recommended fix strategy
1. Keep exactly one **logical port per physical FPGA pin** (canonical net naming such as `u4_bank_XX` / `u2_bank_XX`).
2. Map peripheral aliases in RTL (or wrapper) rather than duplicating XDC pin assignments.
3. Split constraints into profile files, e.g.:
   - `constraints_core_ddr.xdc`
   - `constraints_db_eth.xdc`
   - `constraints_db_vga.xdc`
   - `constraints_db_sd.xdc`
   - `constraints_db_rp2040_gpio.xdc`
   and include only compatible sets per build.
4. Keep JTAG/SWD/ADC and PMOD/Camera/RP2040 groups mutually exclusive by default (commented profiles).
5. Remove or rework `ddr_vref` as a non-port board requirement.

## Bottom line
The supplied file is useful as a **pin reference catalog**, but it is not directly synthesizable as a single active Vivado constraints set. It must be refactored into non-overlapping, build-selectable constraint profiles.
