# Verification Review: QMTECH `core-db.xdc` (PR #2)

Reviewed target:
- `XC7A200T/Software_XC7A200T/core-db.xdc` from PR `ChinaQMTECH/QMTECH_XC7A75T-100T-200T_Core_Board#2`.
- Local working constraints file: `constraints/mc68881_top.xdc`.

Primary references:
- Core board manual (pin and DDR mapping):
  https://github.com/ChinaQMTECH/QMTECH_XC7A75T-100T-200T_Core_Board/blob/main/XC7A200T/QMTECH_Artix-7_XC7A200T_Core_Board_User_Manual(Hardware)_V01.pdf
- DB-FPGA board schematic PDF (J2/J3 shared-net fanout):
  https://github.com/ChinaQMTECH/DB_FPGA_with_RP2040/blob/main/DB_FPGA_V5-20221108.pdf
- Core board hardware schematic PDF:
  https://github.com/ChinaQMTECH/QMTECH_XC7A75T-100T-200T_Core_Board/blob/main/XC7A200T/Hardware/QMTECH_XC7A200T-CORE-BOARD-V01-20240109.pdf

Supplemental official samples used as authoritative:
- `Test01_led_key.zip`
- `Test04_DDR3_mig_7series_0_1_ex.zip`

Review date:
- February 12, 2026.

## Scope
This review checks:
- Active `PACKAGE_PIN` uniqueness (single-top Vivado legality).
- DDR3 mapping consistency against official QMTECH DDR sample constraints.
- Peripheral remap consistency for Ethernet, RP2040 GPIO, VGA, SD, PMOD J10/J11, and Camera JP1.

## Result
**Status: NOT VALID as one simultaneously active `.xdc` profile.**

Current status:
1. DDR mapping is aligned to official QMTECH MIG sample (`ddr_*` profile basis).
2. Peripheral remaps have been updated and verified in `constraints/mc68881_top.xdc`.
3. There are still active shared-pin conflicts when all peripherals are enabled together.

## Confirmed overlap behavior from board docs
The overlap pattern is real at board level:
- Core board FPGA IO is fanned out through U2/U4.
- DB board routes alternate peripheral functions onto overlapping J2/J3 nets.

So overlap is electrically expected, but **cannot be represented as independent active ports in one build profile**.

## Active duplicate pin assignments (hard Vivado conflicts)
Detected from active (non-commented) `PACKAGE_PIN` lines in `constraints/mc68881_top.xdc`.

Current duplicate-pin count: `28`.

- `A2`: `ddr_dq[13]` and `sd_cmd`
- `A3`: `ddr_dq[15]` and `sd_clk`
- `B5`: `rp_gpio0` and `vga_r[4]`
- `C2`: `ddr_dq[11]` and `eth_mdio`
- `F2`: `ddr_dq[2]` and `eth_txd[3]`
- `G1`: `eth_tx_en` and `rp_gpio22`
- `G2`: `ddr_dq[6]`, `eth_txd[0]`, and `rp_gpio23`
- `G9`: `eth_rxd[6]` and `rp_gpio12`
- `H1`: `eth_rx_er` and `rp_gpio14`
- `H2`: `eth_col` and `rp_gpio15`
- `H4`: `eth_crs` and `rp_gpio20`
- `H9`: `eth_rxd[7]` and `rp_gpio13`
- `K1`: `ddr_odt` and `vga_b[1]`
- `K5`: `eth_rxd[3]` and `rp_gpio8`
- `L2`: `ddr_cs_n`, `eth_rxd[4]`, and `rp_gpio10`
- `L4`: `eth_rxd[1]` and `rp_gpio6`
- `L5`: `eth_rx_clk` and `rp_gpio9`
- `M2`: `ddr_ba[0]`, `eth_rxd[5]`, and `rp_gpio11`
- `M4`: `eth_rxd[2]` and `rp_gpio7`
- `M5`: `rp_gpio2` and `vga_hsync`
- `M6`: `rp_gpio3` and `vga_vsync`
- `N2`: `ddr_a[3]`, `eth_rx_dv`, and `rp_gpio4`
- `N3`: `ddr_a[0]`, `eth_rxd[0]`, and `rp_gpio5`
- `P3`: `ddr_a[2]` and `vga_b[2]`
- `R2`: `ddr_a[7]` and `vga_r[3]`
- `R3`: `ddr_a[9]` and `vga_b[3]`
- `T2`: `ddr_reset_n` and `vga_r[0]`
- `T3`: `ddr_a[13]` and `vga_g[1]`

## DDR alignment status
Authoritative source:
- `Test04_DDR3_mig_7series_0_1_ex.zip` MIG/UCF mapping.

Status:
- DDR mismatches vs official MIG profile: `0`.
- `ddr_vref` user-port constraint: disabled/commented.
- Normalized official profile file retained: `tmp/core-ddr-official-mig-profile.xdc`.

Note:
- `ddr_cs_n` is not present in the user-supplied MIG-compatible UCF text block, but exists in this mixed board XDC context.

## Confirmed peripheral mappings in current local XDC

### Ethernet
- `eth_mdc -> B2`
- `eth_mdio -> C2`
- `eth_rstn -> F4`
- `eth_tx_clk -> D1`
- `eth_tx_en -> G1`
- `eth_tx_er -> E5`
- `eth_txd[0..7] -> G2, G4, E4, F2, E1, B1, C1, D5`
- `eth_rx_clk -> L5`
- `eth_rx_dv -> N2`
- `eth_rx_er -> H1`
- `eth_rxd[0..7] -> N3, L4, M4, K5, L2, M2, G9, H9`
- `eth_col -> H2`
- `eth_crs -> H4`
- `eth_intb`: not connected to FPGA (kept disabled)

### RP2040 GPIO (connected subset)
- `rp_gpio0..3 -> B5, A5, M5, M6`
- `rp_gpio4..9 -> N2, N3, L4, M4, K5, L5`
- `rp_gpio10..15 -> L2, M2, G9, H9, H1, H2`
- `rp_gpio20..23 -> H4, J4, G1, G2`
- `rp_gpio24` (RP2040 key) and `rp_gpio25` (RP2040 LED): non-FPGA, disabled

### VGA (5:6:5 + sync)
- `vga_r[0..4] -> T2, P1, U2, R2, B5`
- `vga_g[0..5] -> P6, T3, N1, P5, M1, R1`
- `vga_b[0..4] -> J1, K1, P3, R3, T4`
- `vga_hsync -> M5`
- `vga_vsync -> M6`

### SD Card
- `sd_dat2 -> C4`
- `sd_cd_dat3 -> D4`
- `sd_cmd -> A2`
- `sd_clk -> A3`
- `sd_dat0 -> A4`
- `sd_dat1 -> B4`

### PMOD J11
- `pmod1_pin1..8 -> D26, E26, D25, E25, G26, H26, E23, F23`

### PMOD J10
- `pmod2_pin1..8 -> J26, J25, G21, G20, H22, H21, J21, K21`

### Camera JP1 (pins 3..18)
- `cam_p1..16 -> AB26, AC26, W25, Y26, W21, Y21, AB24, AC24, Y25, AA25, V22, Y23, V23, W23, U21, V21`

## Generated split profiles
Generated from current active lines in `constraints/mc68881_top.xdc`:

- `constraints/xdc_profiles/core_common.xdc`
- `constraints/xdc_profiles/core_ddr.xdc`
- `constraints/xdc_profiles/core_ethernet.xdc`
- `constraints/xdc_profiles/core_rp2040_gpio.xdc`
- `constraints/xdc_profiles/core_vga.xdc`
- `constraints/xdc_profiles/core_sd.xdc`
- `constraints/xdc_profiles/core_pmod_j11.xdc`
- `constraints/xdc_profiles/core_pmod_j10.xdc`
- `constraints/xdc_profiles/core_camera_jp1.xdc`

Validation:
- Each individual profile has `0` internal duplicate `PACKAGE_PIN` conflicts.
- Cross-profile conflicts still exist for overlapping peripherals (expected by board wiring), so only include compatible profile combinations in a single build.

## Practical use strategy
To make constraints Vivado-clean per build target:
1. Use the generated profile files under `constraints/xdc_profiles/` as building blocks.
2. Include only non-conflicting profile combinations in each top-level build.
3. Keep one net namespace per physical pin in each active build profile.

## Bottom line
`constraints/mc68881_top.xdc` is now a significantly corrected pin catalog with confirmed remaps, but it remains a mixed-function superset. It is not valid as one simultaneous active constraint profile because of intentional shared-pin overlap across peripherals.
