# MC68881 FPGA Core

## Overview
This repository contains a VHDL-2008 implementation of an MC68881-compatible
floating-point unit targeting Xilinx Artix-7 devices. The focus is on cycle-accurate
external behavior (bus timing, DSACK sequencing) while using DSP-friendly pipelines
for the core arithmetic datapath. The current plan and progress tracking live in
`docs/fpu-progress-checklist.md`.

## Repository layout
- `src/`: RTL sources for the MC68881-compatible core.
- `tb/`: VHDL-2008 self-checking testbenches.
- `docs/`: Implementation plan, timing notes, and related documentation.
- `mc68881_codex_exports/`: Datasheet-derived CSV/JSON reference material used by the plan.
- `AN-0947_MC68881_Floating-Point_Coprocessor_as_a_Peripheral_in_a_M68000_System_[Motorola_1987_37p].pdf`
  and `MC68881.PDF`: Reference documentation.

## Progress snapshot
Based on `docs/fpu-progress-checklist.md`:
- Completed highlights:
  - Top-level cleanup/refactor items A1-A8, including explicit operation-class
    dispatch, centralized opcode descriptors, typed MOVE decode records, and
    per-op FPSR/FPCR exception-policy handling.
  - FMOVE/FMOVEM family implementation (including packed-decimal `.P` and `FMOVECR`).
  - Dyadic arithmetic set: `FADD`, `FSUB`, `FMUL`, `FDIV`, `FCMP`, `FMOD`, `FREM`,
    `FSCALE`, `FSGLDIV`, `FSGLMUL`.
  - Monadic arithmetic/data ops: `FSQRT`, `FABS`, `FNEG`, `FINT`, `FINTRZ`, `FGETEXP`, `FGETMAN`, `FTST`.
  - B5 transcendental set implemented (`FSIN/FCOS/FTAN/FSINCOS`, inverse trig, exp/log families,
    hyperbolic families, `FTENTOX/FTWOTOX`).
  - Bus/timing confirmations E1-E4.

## Implementation baseline (2026-02-23)
- Clean non-incremental batch flow (`scripts/run_impl.tcl`) meets routed timing:
  - `WNS = 1.356 ns`
  - `TNS = 0.000 ns`
  - `WHS = 0.026 ns`
  - `THS = 0.000 ns`
- Post-implementation LUT utilization:
  - `Slice LUTs = 66523 / 134600 (49.42%)`
- Reproducibility:
  - A second clean non-incremental run reproduced the same signoff metrics.

## Transcendental architecture guardrails
- The B5 implementation uses a shared serialized transcendental engine (`src/mc68881_trig_unit.vhd`)
  and is dispatched from ALU via `table_impl => TABLE_IMPL_BRAM` (`src/mc68881_alu.vhd`).
- Trig seed tables are intentionally synchronous BRAM-style reads using the
  `ST_SEED_READ -> ST_SEED_READ_WAIT -> ST_SEED_READ_LATCH` path.
- Avoid replacing this with combinational table indexing for trig seeds in BRAM mode; that can
  break BRAM inference and increase LUT usage sharply.
- Validate architecture changes with non-incremental synth utilization reports, including
  hierarchical reports (`trig_inst` focus).

## Plan and milestones
The implementation plan is tracked as a checklist in `docs/fpu-progress-checklist.md`,
covering:
- External interface and bus timing behavior.
- Instruction cycle accounting and effective address additions.
- Core microarchitecture and datapath pipelines for ADD/SUB/MUL/DIV.
- Verification goals for arithmetic, bus behavior, and cycle counts.
- Exception-path behavior for FPSR condition codes/accrued flags and FPIAR capture hooks.

## Key documentation
- Master checklist: `docs/fpu-progress-checklist.md`
- Programming reference: `docs/68881-programming.txt`
- FMOVECR constant cross-reference: `docs/fmovecr_qemu_summary.md`
- Defect tracking: `docs/fpu-progress-checklist.md`
- Technical summary: `docs/68881-tech-summary.pdf`
- Motorola references:
  - `docs/MC68881.PDF`
  - `docs/AN-0947_MC68881_Floating-Point_Coprocessor_as_a_Peripheral_in_a_M68000_System_[Motorola_1987_37p].pdf`

## Known defects
- Open defect tracking is maintained in `docs/fpu-progress-checklist.md`.
- Current status:
  - Open:
    - `DEF-TIMING-001`
    - `DEF-DIVREM-001`
    - `DEF-DIVREM-002`
  - `DEF-TRIG-001` is closed; see `docs/fpu-progress-checklist.md` for closure notes.

## Running simulations
Use a VHDL-2008 capable simulator (such as GHDL or ModelSim). The repo includes a test
script that runs the regression suite (ALU/top/cycle-count/FPCR-FPSR/FMOVE-FMOVEM/FMOVECR/
timing plus opcode decode/class and class-dispatch benches):

```powershell
scripts/run_tests.ps1
```

The script uses `GHDL_EXE` if set, otherwise it defaults to
`C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe` and finally `ghdl` on PATH.

Golden vectors:
- Generator: `scripts/gen_golden_vectors.py` (mpmath-based FP80 rounded constants).
- Checked-in package: `tb/mc68881_golden_vectors_pkg.vhd`.
- Keep compile order correct in CI/hooks/scripts:
  `tb/mc68881_golden_vectors_pkg.vhd` must be analyzed before `tb/tb_mc68881_alu.vhd`.

Known-defect status checks (non-gating, currently includes `DEF-TRIG-001`) can be run with:

```powershell
scripts/run_known_defects.ps1
```

The pre-push hook in `.githooks/pre-push` runs the same tests. To enable hooks locally:

```sh
git config core.hooksPath .githooks
```

Example direct GHDL usage:

```sh
ghdl -a --std=08 src/mc68881_pkg.vhd src/mc68881_alu.vhd tb/tb_mc68881_alu.vhd
ghdl -e --std=08 tb_mc68881_alu
ghdl -r --std=08 tb_mc68881_alu
```

Adjust the compilation list as new RTL/testbench files are added.

## Synthesis And LUT Reporting
Use non-incremental synthesis for area/LUT comparisons. Incremental reuse can mask RTL
changes and produce stale utilization numbers.

- In Vivado Tcl console, disable incremental synthesis for `synth_1`:

```tcl
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]
reset_run synth_1
launch_runs synth_1
```

- Confirm in Project Summary that `Incremental synthesis` is `None`.
- Treat LUT regression numbers as valid only when derived from a non-incremental run.
- For hotspot analysis, generate hierarchical utilization from the synthesized checkpoint:

```tcl
open_checkpoint mc68881_top.dcp
report_utilization -hierarchical -hierarchical_depth 10 -file mc68881_top_util_hier.rpt
```
