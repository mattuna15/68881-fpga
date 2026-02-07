# MC68881 FPGA Core

## Overview
This repository contains a VHDL-2008 implementation of an MC68881-compatible
floating-point unit targeting Xilinx Artix-7 devices. The focus is on cycle-accurate
external behavior (bus timing, DSACK sequencing) while using DSP-friendly pipelines
for the core arithmetic datapath. The current plan and progress tracking live in
`docs/mc68881_plan_checklist.txt`. 

## Repository layout
- `src/`: RTL sources for the MC68881-compatible core.
- `tb/`: VHDL-2008 self-checking testbenches.
- `docs/`: Implementation plan, timing notes, and related documentation.
- `mc68881_codex_exports/`: Datasheet-derived CSV/JSON reference material used by the plan.
- `AN-0947_MC68881_Floating-Point_Coprocessor_as_a_Peripheral_in_a_M68000_System_[Motorola_1987_37p].pdf`
  and `MC68881.PDF`: Reference documentation.

## Plan and milestones
The implementation plan is tracked as a checklist in `docs/mc68881_plan_checklist.txt`,
covering:
- External interface and bus timing behavior.
- Instruction cycle accounting and effective address additions.
- Core microarchitecture and datapath pipelines for ADD/SUB/MUL/DIV.
- Verification goals for arithmetic, bus behavior, and cycle counts.

## Running simulations
Use a VHDL-2008 capable simulator (such as GHDL or ModelSim). The repo includes a test
script that runs both testbenches:

```powershell
scripts/run_tests.ps1
```

The script uses `GHDL_EXE` if set, otherwise it defaults to
`C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe` and finally `ghdl` on PATH.

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
