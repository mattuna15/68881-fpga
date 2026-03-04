# MC68881 FPGA Core

## Overview
A VHDL-2008 implementation of a Motorola MC68881-compatible floating-point
coprocessor targeting Xilinx 7-series FPGAs. The design implements the full
MC68881 instruction set including all arithmetic, transcendental, program-control,
system-control, and packed-decimal operations. It uses DSP-pipelined sequential
FP units for the core arithmetic datapath with multi-cycle path constraints for
timing closure.

The current plan and progress tracking live in `docs/fpu-progress-checklist.md`.

## Features
- **Full instruction set**: FADD, FSUB, FMUL, FDIV, FSQRT, FMOD, FREM, FSCALE,
  FSGLDIV, FSGLMUL, FABS, FNEG, FINT, FINTRZ, FGETEXP, FGETMAN, FTST, FCMP.
- **Transcendental engine**: FSIN, FCOS, FTAN, FSINCOS, FASIN, FACOS, FATAN,
  FATANH, FSINH, FCOSH, FTANH, FETOX, FETOXM1, FTWOTOX, FTENTOX, FLOGN,
  FLOGNP1, FLOG2, FLOG10. BRAM-based seed tables with Taylor/CORDIC iteration.
- **Data movement**: FMOVE (all formats including packed decimal `.P`),
  FMOVEM (register lists and control registers), FMOVECR (ROM constants).
- **Program control**: FScc, FBcc, FDBcc, FTRAPcc, FNOP with BSUN trap gating.
- **System control**: FSAVE/FRESTORE frame handshake.
- **IEEE 754 compliance**: NaN propagation (SNaN/QNaN discrimination, payload
  preservation), infinity handling, signed zero, gradual underflow, all four
  rounding modes (nearest, zero, +inf, -inf), single/double/extended precision.
- **Exception handling**: Per-operation FPSR exception policies, FPCR trap
  enable, accrued exception accumulation.
- **Peripheral interface**: Register-mapped bus interface with DSACK handshake,
  suitable for M68000/M68010 peripheral-mode operation.

## Utilization (Xilinx Artix-7 200T, post-place)

| Resource | Used | Available | Util% |
|----------|------|-----------|-------|
| Slice LUTs | 66,572 | 133,800 | 49.75% |
| Registers | 11,903 | 267,600 | 4.45% |
| Block RAM | 5 tiles | 365 | 1.37% |
| DSP48E1 | 33 | 740 | 4.46% |
| F7 Muxes | 993 | 66,900 | 1.48% |

*Non-incremental synthesis + implementation, Vivado 2025.2, `xc7a200tfbg676-1`. Date: 2026-03-04.
Includes Section 7 CIR coprocessor interface (~7K LUTs); see "CIR feature gating" below.*

### Timing
- Target clock: 10 MHz (100 ns period) — matches MC68881 bus timing.
- Multi-cycle path constraints on sequential FP units (mul: 4 cycles, addsub: 6 cycles,
  div: 6 cycles) and trig engine hold states.
- Post-route physopt WNS: **+11.404 ns** (88% slack margin at 100 ns period).
- WHS (hold): +0.010 ns, no violations.

### Target device compatibility
The design fits on several FPGA families. With CIR disabled (`ENABLE_CIR_g => false`),
the core is ~59K LUTs and fits comfortably on smaller devices:

| Device | LUTs | DSPs | Fit (full)? | Fit (no CIR)? |
|--------|------|------|-------------|---------------|
| Xilinx Artix-7 200T | 134,600 | 740 | Yes (50%) | Yes (44%) |
| Xilinx Artix-7 100T | 63,400 | 240 | No (105%) | Yes (~93%) |
| Xilinx Zynq UltraScale+ ZU3EG | ~71,000 | 360 | Yes (~94%) | Yes (~83%) |
| Intel Cyclone V 5CEBA7 | 150,720 ALMs | 156 | Yes | Yes |

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
- `tb/` — VHDL-2008 self-checking testbenches (13 files, ~8K lines)
- `docs/` — Implementation plan, timing notes, reference documentation
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

## Transcendental architecture guardrails
- The transcendental engine uses BRAM-style synchronous reads via
  `ST_SEED_READ -> ST_SEED_READ_WAIT -> ST_SEED_READ_LATCH`.
- Do **not** replace this with combinational table indexing — it breaks BRAM
  inference and increases LUT usage sharply.
- Validate architecture changes with non-incremental synth utilization reports.

## CIR feature gating
The Section 7 coprocessor interface (CIR dialog FSM) adds ~7K LUTs. For smaller
FPGAs, set `ENABLE_CIR_g => false` on `mc68881_top` to disable the CIR logic and
use only the register-mapped peripheral interface. The CIR generic defaults to
`true`.

## Remaining work
- **Section 7 coprocessor interface (Phase 2+)**: Conditional dialog paths
  (FBcc/FDBcc/FScc/FTRAPcc), FSAVE/FRESTORE format-word and state-frame flow,
  full exception dialog paths, and protocol/cycle testbenches. Phase 1
  (CIR types, dialog FSM, reg-to-reg, memory-source/destination transfers) is
  complete.
- **Test coverage**: Denormal handling (C1), exception detection expansion (C3),
  FPCR/FPSR architectural field completeness (C4), FPIAR tracking (C5),
  per-opcode self-checking testbenches (D1), cycle-count verification (D4),
  opcode matrix coverage (D5), format-specific FMOVE tests (D6).

## Defect tracking
All defects are currently closed. History is maintained in `docs/fpu-progress-checklist.md`:
- `DEF-LUT-002` — FP unit sharing (closed 2026-03-03)
- `DEF-LUT-001` — Sequential FP unit reuse (closed 2026-03-03)
- `DEF-TIMING-001` — MCP-guarded combinational FP80 datapaths (closed 2026-03-02)
- `DEF-DIVREM-002` — DIV NaN policy (closed 2026-03-02)
- `DEF-DIVREM-001` — DIV/SQRT gradual underflow (closed 2026-03-02)
- `DEF-PACKED-002` — Packed-decimal QoR (closed 2026-03-02)
- `DEF-PACKED-001` — Packed-decimal integer subset (closed 2026-02-28)
- `DEF-TRIG-001` — FCOS sign check (closed 2026-02-15)

## Key documentation
- Master checklist: `docs/fpu-progress-checklist.md`
- Programming reference: `docs/68881-programming.txt`
- FMOVECR constant cross-reference: `docs/fmovecr_qemu_summary.md`
- Technical summary: `docs/68881-tech-summary.pdf`
- Motorola references:
  - `docs/MC68881.PDF`
  - `docs/AN-0947_MC68881_Floating-Point_Coprocessor_as_a_Peripheral_in_a_M68000_System_[Motorola_1987_37p].pdf`

## License
See repository for license terms.
