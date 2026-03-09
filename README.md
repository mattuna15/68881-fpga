# MC68881 FPGA Core

## Overview
A VHDL-2008 implementation of a Motorola MC68881-compatible floating-point
coprocessor targeting Xilinx 7-series FPGAs. The design implements the full
MC68881 instruction set including all arithmetic, transcendental, program-control,
system-control, and packed-decimal operations. It uses DSP-pipelined sequential
FP units for the core arithmetic datapath with multi-cycle path constraints for
timing closure at 33 MHz.

The current plan and progress tracking live in `docs/fpu-progress-checklist.md`.

## Features
- **Full instruction set**: FADD, FSUB, FMUL, FDIV, FSQRT, FMOD, FREM, FSCALE,
  FSGLDIV, FSGLMUL, FABS, FNEG, FINT, FINTRZ, FGETEXP, FGETMAN, FTST, FCMP.
- **Transcendental engine**: FSIN, FCOS, FTAN, FSINCOS, FASIN, FACOS, FATAN,
  FATANH, FSINH, FCOSH, FTANH, FETOX, FETOXM1, FTWOTOX, FTENTOX, FLOGN,
  FLOGNP1, FLOG2, FLOG10. BRAM coefficient ROM with degree-9 Horner polynomial
  evaluation, table-assisted range reduction (ATAN, LOG), and Cody-Waite
  argument reduction (trig, EXP).
- **Data movement**: FMOVE (all formats including packed decimal `.P`),
  FMOVEM (register lists and control registers), FMOVECR (ROM constants).
- **Program control**: FScc, FBcc, FDBcc, FTRAPcc, FNOP with BSUN trap gating.
- **System control**: FSAVE/FRESTORE with Null/Idle/Busy frame support (45-word
  Busy frame with full sub-unit save/restore hierarchy).
- **IEEE 754 compliance**: NaN propagation (SNaN/QNaN discrimination, payload
  preservation), infinity handling, signed zero, gradual underflow, all four
  rounding modes (nearest, zero, +inf, -inf), single/double/extended precision.
- **Exception handling**: Per-operation FPSR exception policies, FPCR trap
  enable, accrued exception accumulation.
- **Peripheral interface**: Register-mapped bus interface with DSACK handshake,
  suitable for M68000/M68010 peripheral-mode operation.
- **SoC wrappers**: AXI4-Lite and Wishbone B4 slave wrappers with clock domain
  crossing (toggle handshake CDC), DSACK timeout protection, and interrupt output.
  Enable direct integration into Xilinx AXI or RISC-V Wishbone SoC interconnects.

## Utilization (Xilinx Artix-7 200T, post-place)

| Resource | Used | Available | Util% |
|----------|------|-----------|-------|
| Slice LUTs | 62,784 | 133,800 | 46.92% |
| Registers | 13,629 | 267,600 | 5.09% |
| Block RAM | 8 tiles | 365 | 2.19% |
| DSP48E1 | 34 | 740 | 4.59% |

*Non-incremental synthesis + implementation, Vivado 2025.2, `xc7a200tfbg676-1`. Date: 2026-03-08.
33 MHz target clock. Includes transcendental accuracy improvements (BRAM coefficient ROM,
table-assisted ATAN/LOG, Cody-Waite trig/EXP), GHDL synth-compatible RTL,
CIR coprocessor interface, and full exception dialog paths.*

### Timing
- Target clock: **33 MHz** (30.303 ns period) — 3.3× faster than original MC68881.
- Multi-cycle path constraints on sequential FP units, trig engine hold states,
  format conversion paths (operand staging, MOVE dispatch, LOG exponent conversion,
  FP register file to exception destinations).
- Packed decimal encode pipeline: 3-stage split (exponent extraction → DSP multiply
  → scale computation) with pipelined DSP48E1 input.
- Post-route WNS: **+0.405 ns** (timing met). WHS: **+0.022 ns** (no hold violations).

### Target device compatibility
The design fits on several FPGA families. With CIR disabled (`ENABLE_CIR_g => false`),
the core is ~56K LUTs:

| Device | LUTs | DSPs | Fit? |
|--------|------|------|------|
| Xilinx Artix-7 200T | 133,800 | 740 | Yes (47%) |
| Xilinx Artix-7 100T | 63,400 | 240 | No (99%); Yes with CIR disabled (~88%) |
| Xilinx Zynq UltraScale+ ZU3EG | ~71,000 | 360 | Yes (~88%) |
| Intel Cyclone V 5CEBA7 | 150,720 ALMs | 156 | Yes |

All RTL is vendor-portable (inferred DSP/BRAM, no Xilinx IP cores). Porting to
Intel/Quartus requires XDC-to-SDC constraint conversion and minor DSP inference
adjustments.

## Architecture

```
mc68881_top                     Bus interface, format converters, FMOVECR ROM
├── alu_inst (mc68881_alu)      Opcode dispatch, shared FP unit mux
│   ├── trig_inst               Transcendental engine (own mul/add/div — runs concurrently)
│   ├── divrem_inst             Radix-4 SRT division, FSQRT, FMOD/FREM
│   │   └── modrem_post         Post-processing (uses shared mul/add)
│   ├── sglops_inst             FSCALE, FSGLDIV, FSGLMUL
│   ├── alu_mul_inst            Shared 64×64 sequential multiplier (DSP48E1 cascade)
│   └── alu_add_inst            Shared 67-bit sequential adder/subtractor
└── packed_unit_inst            Packed-decimal BCD encode/decode (uses shared mul/add)
```

The ALU dispatches to **exactly one** consumer at a time. The trig unit runs
concurrently and has its own dedicated FP units. The ALU's mul and add instances
are **shared** between the ALU's own FADD/FSUB/FMUL path, the modrem post-processing
path, and the packed-decimal unit — saving ~5,300 LUTs and 32 DSPs vs. dedicated
instances per consumer.

## Repository layout
- `src/` — RTL sources (10 files, ~11.4K lines)
  - `mc68881_pkg.vhd` — Types, constants, FP80 utility functions
  - `mc68881_top.vhd` — Top-level bus interface, format converters
  - `mc68881_alu.vhd` — ALU dispatcher, shared FP unit routing
  - `mc68881_trig_unit.vhd` — Transcendental engine (BRAM seed tables)
  - `mc68881_divrem_unit.vhd` — Division, square root, mod/rem
  - `mc68881_modrem_post_unit.vhd` — FMOD/FREM post-processing
  - `mc68881_fp80_mul_unit.vhd` — Sequential 64×64-bit FP80 multiplier
  - `mc68881_fp80_addsub_unit.vhd` — Sequential 67-bit FP80 adder/subtractor
  - `mc68881_sgl_ops_unit.vhd` — FSCALE, FSGLDIV, FSGLMUL
  - `mc68881_packed_decimal_unit.vhd` — Packed-decimal BCD conversion
- `wrappers/` — SoC bus wrappers
  - `mc68881_bus_bridge.vhd` — CDC toggle-handshake bridge + M68K bus cycle FSM
  - `mc68881_axilite_wrapper.vhd` — AXI4-Lite slave (instantiates bridge + FPU)
  - `mc68881_wishbone_wrapper.vhd` — Wishbone B4 slave (instantiates bridge + FPU)
  - `mc68881_wrapper.xdc` — ASYNC_REG + false path timing constraints for CDC bridge
  - `mc68881_ooc_timing.xdc` — Multicycle path constraints for OOC block design synthesis
- `src/vitis/` — Bare-metal C test apps for Xilinx Vitis (AXI-Lite hardware validation)
  - `mc68881_smoke_test.c` — Register read/write connectivity test (FPCR, FPIAR)
  - `mc68881_fsin_test.c` — FSIN computation test (sin(1.0), sin(0.0))
  - `mc68881_e2e_test.c` — End-to-end test with 15 vectors from GHDL testbench
- `tb/` — VHDL-2008 self-checking testbenches (14 files, ~8.5K lines)
- `docs/` — Implementation plan, timing notes, reference documentation
- `verilog/` — Auto-generated Verilog conversion (see [verilog/README.md](verilog/README.md))
- `scripts/` — Test runner, golden vector generator, implementation TCL
- `.github/workflows/ghdl.yml` — CI: GHDL analysis + 4 testbench runs
- `.githooks/pre-push` — Pre-push GHDL regression gate

## Running simulations
Use a VHDL-2008 capable simulator (GHDL 5.1.1+ recommended). The repo includes
a test script that runs the full regression suite:

```powershell
scripts/run_tests.ps1
```

The script uses `GHDL_EXE` if set, otherwise defaults to
`C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe` and finally `ghdl` on PATH.

### CI testbenches
The GitHub Actions workflow runs these testbenches on every push:
- `tb_mc68881_alu` — Arithmetic, NaN/infinity, transcendental, special values
- `tb_mc68881_top` — Bus interface, format conversions, FPSR/exception checks
- `tb_mc68881_ea_cycles` — Effective address cycle count tables
- `tb_mc68881_cycle_counts` — Instruction cycle timing verification

### Golden vectors
- Generator: `scripts/gen_golden_vectors.py` (mpmath-based FP80 rounded constants).
- Checked-in package: `tb/mc68881_golden_vectors_pkg.vhd`.
- Compile order: `mc68881_golden_vectors_pkg.vhd` must be analyzed before `tb_mc68881_alu.vhd`.

### Pre-push hook
The pre-push hook in `.githooks/pre-push` runs GHDL analysis and the ALU/top
testbenches. To enable hooks locally:

```sh
git config core.hooksPath .githooks
```

## Synthesis and LUT reporting
Use non-incremental synthesis for area/LUT comparisons. Incremental reuse can mask
RTL changes and produce stale utilization numbers.

```tcl
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
reset_run synth_1
launch_runs synth_1
```

For hotspot analysis, generate hierarchical utilization from the synthesized checkpoint:

```tcl
open_checkpoint mc68881_top.dcp
report_utilization -hierarchical -hierarchical_depth 10 -file mc68881_top_util_hier.rpt
```

### Transcendental accuracy
The transcendental engine achieves 30–55 bits of accuracy across operations,
verified by the torture testbench (349 self-checking tests):

| Operation | Typical accuracy | Method |
|-----------|-----------------|--------|
| SIN, COS, TAN | 30–40 bits | Cody-Waite argument reduction, degree-9 Horner |
| ASIN, ACOS, ATAN | 55–62 bits | Table-assisted polynomial (8 BRAM entries) |
| EXP, ETOXM1 | 40–50 bits | Cody-Waite ln(2) splitting, degree-9 Horner |
| LOG, LOG2, LOG10 | 56+ bits | Table-assisted range reduction (16 BRAM entries) |
| SINH, COSH | 30–50 bits | Via EXP pipeline |
| TANH | ~30 bits | Via EXP pipeline (replaces Padé approximant) |

## Transcendental architecture guardrails
- The transcendental engine uses BRAM-style synchronous reads via
  `ST_SEED_READ -> ST_SEED_READ_WAIT -> ST_SEED_READ_LATCH`.
- Coefficient BRAM ROM stores 5 sets × 10 coefficients (EXP/LOG/ATAN/SINH/COSH);
  requires 2-cycle read latency: `POLY_INIT` → `INIT_WAIT` → `MUL_PREP`.
- Do **not** replace synchronous reads with combinational table indexing — it
  breaks BRAM inference and increases LUT usage sharply.
- Validate architecture changes with non-incremental synth utilization reports.

## CIR feature gating
The CIR coprocessor interface (dialog FSM) adds ~7K LUTs. For smaller
FPGAs, set `ENABLE_CIR_g => false` on `mc68881_top` to disable the CIR logic and
use only the register-mapped peripheral interface. The CIR generic defaults to
`true`.

## Verilog conversion
The VHDL sources can be converted to Verilog via `ghdl --synth` for use with
Verilator or other Verilog-only toolchains. The pre-push hook regenerates these
automatically. To convert manually:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/convert_to_verilog.ps1
```

Output goes to [`verilog/`](verilog/). **These files are supplied as-is for
information only — no guarantee of correctness is made and no tests are run on
the converted code.** The VHDL sources remain the authoritative implementation.

## Block design integration (Xilinx Vivado)

The AXI-Lite wrapper can be added to a Vivado block design as a custom RTL module.
Both XDC constraint files must be included with the IP:

- `mc68881_wrapper.xdc` — CDC false paths for the toggle-handshake bridge
- `mc68881_ooc_timing.xdc` — Multicycle path constraints scoped to `*/u_fpu/`

The OOC timing constraints are adapted from `mc68881_top.xdc` for the wrapper
hierarchy. Key differences from standalone synthesis:
- All `get_pins` patterns use `*/u_fpu/` prefix
- `move_cfg_decoded_reg` (record type) is optimized away in OOC synthesis;
  constraints target `move_cfg_reg_reg` instead
- `packed_unit_inst` is inside generate block `packed_engine_full_g`
- CDC `get_cells` filters include `&& IS_SEQUENTIAL` to avoid matching LUT cells

Verified on Xilinx Zynq UltraScale+ ZU3EG (AXU3EG board) with Vivado 2024.2:
post-route WNS **+5.911 ns** at 100 MHz AXI / 33 MHz FPU.

### Vitis hardware test apps

The `src/vitis/` directory contains standalone C test applications for
validating the FPU over AXI-Lite. These target the Xilinx Vitis bare-metal BSP.

| Test | What it checks |
|------|----------------|
| `mc68881_smoke_test.c` | Bus connectivity: write/readback of FPCR and FPIAR |
| `mc68881_fsin_test.c` | FPU operation: sin(1.0) and sin(0.0) with result printout |
| `mc68881_e2e_test.c` | 15 test vectors: ADD, SUB, MUL, DIV, SQRT, SIN, COS, TAN, ETOX, LOGN |

All tests include `0xFFFFFFFF` bus fault detection, timeout handling with status
reporting, and non-zero exit on failure for use in automated test flows.

Set `MC68881_BASE` to match your address map (default `0x80000000`).

## Status
All checklist items complete. See `docs/fpu-progress-checklist.md` for history.

## Key documentation
- Master checklist: `docs/fpu-progress-checklist.md`
- GHDL test results (349 tests): `docs/tests.txt`
- Programming reference: `docs/68881-programming.txt`
- FMOVECR constant cross-reference: `docs/fmovecr_qemu_summary.md`
- Technical summary: `docs/68881-tech-summary.pdf`

## License
See repository for license terms.
