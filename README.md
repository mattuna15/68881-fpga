# MC68881/2 FPGA Core

## Overview
A VHDL implementation of a Motorola MC68881/MC68882-compatible floating-point
coprocessor targeting Xilinx 7-series and UltraScale+ FPGAs. The design implements
the full MC68881 instruction set including all arithmetic, transcendental,
program-control, system-control, and packed-decimal operations. It uses
DSP-pipelined sequential FP units for the core arithmetic datapath with
multi-cycle path constraints for timing closure at 50 MHz.

Hardware-verified on an Alinx AXU3EG board (Zynq UltraScale+ ZU3EG) via the
AXI4-Lite wrapper at 100 MHz bus / 50 MHz FPU, with end-to-end tests covering
arithmetic, transcendental, exponential, and logarithmic operations.

## Features
- **Full instruction set**: FADD, FSUB, FMUL, FDIV, FSQRT, FMOD, FREM, FSCALE,
  FSGLDIV, FSGLMUL, FABS, FNEG, FINT, FINTRZ, FGETEXP, FGETMAN, FTST, FCMP.
- **Lite mode** (`fpu_lite_g => true`): MC68040 hardware subset -- keeps 11 ALU
  ops (ADD/SUB/MUL/DIV/SQRT/CMP/ABS/NEG/INT/INTRZ/TST) plus control/move ops.
  Removes trig engine, sglops unit, and modrem post-processing via VHDL generate
  blocks; stubs out GETEXP/GETMAN inline. Estimated ~57-60% LUT savings (pending
  synthesis verification). Unsupported ops return zero in 1 cycle.
- **Transcendental engine**: FSIN, FCOS, FTAN, FSINCOS, FASIN, FACOS, FATAN,
  FATANH, FSINH, FCOSH, FTANH, FETOX, FETOXM1, FTWOTOX, FTENTOX, FLOGN,
  FLOGNP1, FLOG2, FLOG10. BRAM coefficient ROM with Horner polynomial
  evaluation, table-assisted range reduction (ATAN, LOG), Cody-Waite
  argument reduction (trig), and FPSP-derived 2^(J/64) EXP decomposition
  with minimax degree-6 polynomial.
- **Data movement**: FMOVE (all formats including packed decimal `.P`),
  FMOVEM (register lists and control registers), FMOVECR (ROM constants).
- **Program control**: FScc, FBcc, FDBcc, FTRAPcc, FNOP with BSUN trap gating.
- **MC68882 mode** (`fpu_version_g => FPU_68882`): Pin-compatible 68882 variant
  with larger FSAVE frames (idle $0038/14W, busy $00D4/53W), pending instruction
  pipeline (accepts a second cpGEN while the first is executing; auto-launches on
  completion), and NULL response during CIR_EXECUTE for reduced CPU stalls.
  FRESTORE accepts both 68881 and 68882 format words for migration compatibility.
  Default is FPU_68881 for backward compatibility.
- **System control**: FSAVE/FRESTORE with Null/Idle/Busy frame support (45-word
  68881 / 53-word 68882 Busy frame with full sub-unit save/restore hierarchy).
- **IEEE 754 compliance**: NaN propagation (SNaN/QNaN discrimination, payload
  preservation), infinity handling, signed zero, gradual underflow, all four
  rounding modes (nearest, zero, +inf, -inf), single/double/extended precision.
- **Exception handling**: Per-operation FPSR exception policies, FPCR trap
  enable, accrued exception accumulation.
- **Dual host interface**: Two operating modes over the same 5-bit address space:
  - **CIR dialog** -- authentic AN-947 coprocessor protocol with internal FP register
    file, hardware format conversion, and command/response/operand dialog (for M68020/030)
  - **Peripheral (register-mapped)** -- direct OPA/OPB/OPSEL/RES register access for
    any host CPU (ARM, RISC-V, soft-core) as a standalone FPU compute engine
  - Mode selected by writing bit 0 of address 13 (1=CIR, 0=peripheral); CIR is
    default on reset, matching real MC68881 behaviour
- **SoC wrappers**: AXI4-Lite and Wishbone B4 slave wrappers with clock domain
  crossing (toggle handshake CDC), DSACK timeout protection, and interrupt output.
  Enable direct integration into Xilinx AXI or RISC-V Wishbone SoC interconnects.

## Utilization (Xilinx Artix-7 200T, post-place)

| Resource | Full | Lite (`fpu_lite_g`) | Available | Full % | Lite % |
|----------|------|---------------------|-----------|--------|--------|
| Slice LUTs | 59,919 | 37,380 | 133,800 | 44.78% | 27.94% |
| Registers | 14,087 | 7,030 | 267,600 | 5.26% | 2.63% |
| Block RAM | 10.5 tiles | 0 | 365 | 2.88% | 0% |
| DSP48E1 | 34 | 18 | 740 | 4.59% | 2.43% |

*Non-incremental synthesis + implementation, Vivado 2025.2, `xc7a200tfbg676-1`. Date: 2026-03-27.
50 MHz target clock. MC68882 mode enabled (`fpu_version_g => FPU_68882`). Includes
FPSP-derived EXP 2^(J/64) decomposition with minimax degree-6 polynomial (EXPTBL
64-entry BRAM), LOG reciprocal table (avoids FP division), TWOTOX/TENTOX direct
reduction, table-assisted ATAN/LOG, Cody-Waite trig, CIR coprocessor interface,
full exception dialog paths, undocumented FMOVECR ROM constants, pending instruction
pipeline, and graphics framebuffer support. Lite figures are from 2026-03-21 (pre-
efficiency changes, trig engine excluded by generate block).*

### Timing
- Target clock: **50 MHz** (20.0 ns period) — 2× the original MC68881 max (25 MHz).
- Multi-cycle path constraints on sequential FP units, trig engine hold states,
  format conversion paths (operand staging, MOVE dispatch, LOG exponent conversion,
  FP register file to exception destinations).
- Packed decimal encode pipeline: 3-stage split (exponent extraction → DSP multiply
  → scale computation) with pipelined DSP48E1 input.
- Post-route WNS: **+0.272 ns** at 50 MHz (timing met). No hold violations.

### Target device compatibility
The design fits on several FPGA families. With `fpu_lite_g => true` (MC68040
hardware subset: 11 ALU ops, no trig/sglops/modrem), the core uses 37,380 LUTs
/ 18 DSPs / 0 BRAM:

| Device | LUTs | DSPs | Full fit? | Lite fit? |
|--------|------|------|-----------|-----------|
| Xilinx Artix-7 200T | 133,800 | 740 | Yes (45%) | Yes (28%) |
| Xilinx Artix-7 100T | 63,400 | 240 | Tight (95%) | Yes (59%) |
| Xilinx Zynq UltraScale+ ZU3EG | ~71,000 | 360 | Yes (~84%) | Yes (~53%) |
| Intel Cyclone V 5CEBA7 | 150,720 ALMs | 156 | Yes | Yes |
| Intel Cyclone V SE 5CSEBA6 (MiSTer DE10-Nano) | 41,910 ALMs | 112 | No (~75%) | Yes (~45%) |

All RTL is VHDL-93 compatible and vendor-portable (inferred DSP/BRAM, no Xilinx
IP cores). The source is VHDL-93 compatible (verified via `ghdl --std=93`) and
should synthesize directly in Quartus 17+ (as used by MiSTer). Verify with `scripts/check_vhdl93.sh`.
Porting requires XDC-to-SDC constraint conversion and minor DSP inference
adjustments.

**MiSTer note:** The DE10-Nano's Cyclone V SE has 41,910 ALMs (each ALM roughly
maps to 2 Xilinx LUTs, giving ~84K LUT-equivalent). The full FPU (60K LUTs /
34 DSPs) exceeds ALM capacity but fits within the 112 DSP budget. Lite mode
(37K LUTs ≈ ~19K ALMs, 18 DSPs, 0 BRAM) should fit comfortably. These are rough
estimates; actual Quartus ALM counts may differ from Xilinx LUT counts due to
architectural differences.

## Architecture

```
mc68881_top                     Bus interface, format converters, FMOVECR ROM
├── alu_inst (mc68881_alu)      Opcode dispatch, shared FP unit mux
│   ├── trig_inst               Transcendental engine (generate: not fpu_lite)
│   ├── divrem_inst             Radix-4 SRT division, FSQRT
│   │   └── modrem_post         FMOD/FREM post-processing (generic: enable_modrem_post)
│   ├── sglops_inst             FSCALE, FSGLDIV, FSGLMUL (generate: not fpu_lite)
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
- `validation/NeXT-68040/` — NeXT 68040LC system emulator (Turbo ROM boot, interactive `NeXT>` monitor, hardware FPU via FSAVE/FRESTORE frame translation, DisplayPort output)
- `validation/hello_world/` — M68K emulator + hardware FPU validation (Musashi, F-line trapping, ROM boot, USB keyboard)
- `validation/kicad/` — Validation PCB: MC68SEC000 + QMTECH Artix-7 + original MC68881FN (KiCad 8, Gerbers in `output/`)
- `src/vitis/roms/` — 68000 BIOS ROM source (assembler, disassembler, monitor with FPU support)
- `tb/` — VHDL-2008 self-checking testbenches (14 files, ~8.5K lines)
- `docs/` — Implementation plan, timing notes, reference documentation
- `verilog/` — Auto-generated Verilog conversion; `verilog/fpu_lite/` has the lite-mode variant (see [verilog/README.md](verilog/README.md))
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
- `tb_mc68881_alu_lite` — Lite-mode (`fpu_lite => true`): kept ops + removed ops return zero
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
The transcendental engine achieves 30–64 bits of accuracy across operations,
verified by the torture testbench (357 self-checking tests):

| Operation | Typical accuracy | Method |
|-----------|-----------------|--------|
| SIN, COS, TAN | 30–40 bits | Cody-Waite argument reduction, table-assisted seed refinement |
| ASIN, ACOS, ATAN | 55–62 bits | Table-assisted polynomial (64 BRAM entries) |
| EXP, ETOXM1 | ~40–54 bits | FPSP 2^(J/64) decomposition, minimax degree-6 Horner |
| TWOTOX, TENTOX | ~47 bits | Direct k=nint(x) reduction, degree-9 Taylor |
| LOG, LOG2, LOG10 | ~54 bits | Table-assisted range reduction, reciprocal multiply |
| SINH, COSH | 30–50 bits | Dedicated odd/even Taylor polynomials |
| TANH | ~32–42 bits | Via EXP64 pipeline |

## Transcendental architecture guardrails
- The transcendental engine uses BRAM-style synchronous reads via
  `ST_SEED_READ -> ST_SEED_READ_WAIT -> ST_SEED_READ_LATCH`.
- Coefficient BRAM ROM stores 6 sets × 10 coefficients (EXP/LOG/ATAN/SINH/COSH/EXP64);
  requires 2-cycle read latency: `POLY_INIT` → `INIT_WAIT` → `MUL_PREP`.
- EXP64 BRAM (64 entries of 2^(J/64)) uses same synchronous read pattern:
  `ST_EXP64_N_POST` → `ST_EXP64_TABLE_WAIT` → `ST_EXP64_TABLE_LATCH`.
- LOG reciprocal table (64 entries of 1/c_i) reads alongside c_i and ln(c_i)
  on the same BRAM address — no extra read cycle needed.
- Do **not** replace synchronous reads with combinational table indexing — it
  breaks BRAM inference and increases LUT usage sharply.
- Validate architecture changes with non-incremental synth utilization reports.

## Verilog conversion
The VHDL sources can be converted to Verilog via `ghdl --synth` for use with
Verilator or other Verilog-only toolchains. The pre-push hook regenerates these
automatically. To convert manually:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/convert_to_verilog.ps1
```

Output goes to [`verilog/`](verilog/). A lite-mode variant (`fpu_lite_g => true`)
is also generated into `verilog/fpu_lite/`. **These files are supplied as-is for
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

Verified on Xilinx Zynq UltraScale+ ZU3EG (AXU3EG board) with Vivado 2025.2:
post-route WNS **+1.186 ns** at 100 MHz AXI / 50 MHz FPU (MC68882 mode).
Board design utilization: 64,014 LUTs (91%), 15,206 registers, 8 BRAM tiles,
34 DSPs. All timing constraints met with no hold violations.

### Vitis hardware test apps

The `src/vitis/` directory contains standalone C test applications for
validating the FPU over AXI-Lite. These target the Xilinx Vitis bare-metal BSP.

| Test | What it checks |
|------|----------------|
| `mc68881_smoke_test.c` | Bus connectivity: write/readback of FPCR and FPIAR |
| `mc68881_fsin_test.c` | FPU operation: sin(1.0) and sin(0.0) with result printout |
| `mc68881_e2e_test.c` | 17 test vectors: ADD, SUB, MUL, DIV, SQRT, SIN, COS, TAN, ETOX, LOGN, FMOVECR, pi/3 |

All tests include `0xFFFFFFFF` bus fault detection, timeout handling with status
reporting, and non-zero exit on failure for use in automated test flows.

Set `MC68881_BASE` to match your address map (default `0x80000000`).

### M68K emulator validation (CIR + peripheral modes)

The [`validation/hello_world/src/README.md`](validation/hello_world/src/README.md) project runs a full
M68K emulator (Musashi) on the ARM core, trapping F-line FPU instructions and
executing them on the hardware FPU over AXI-Lite. The test suite validates
**both** operating modes:

**Peripheral mode** (7 + 5 tests) -- the FPU as a standalone compute engine.
The emulator's F-line handler converts operands to FP80 in software, writes them
to the OPA/OPB registers, triggers execution via OPSEL, and reads results from
RES. No CIR involvement:

```c
fpu_wr(OFF_CIR_MODE, 0);              // ensure peripheral mode
fpu_load_opa(a);                       // write FP80 operand A
fpu_load_opb(b);                       // write FP80 operand B
fpu_wr(OFF_OPSEL, OPSEL(FPOP_ADD));   // trigger FADD
while (!(fpu_rd(OFF_STATUS) & 1)) {}  // poll for completion
result = fpu_read_res();               // read FP80 result
```

**CIR dialog mode** (7 tests) -- the authentic AN-947 coprocessor protocol.
The host writes a Command + OpWord to start a dialog, the FPU responds with
transfer primitives, the host feeds operand words through the CIR Operand
register, and the FPU stores results in its internal FP register file (FP0-FP7):

```c
cir_wr(OFF_CIR_RESPONSE, 1);           // ensure CIR mode
cir_wr(OFF_CIR_COMMAND, cmd);          // operation + format + register
cir_wr(OFF_CIR_OPWORD,  CIR_OPWORD_CPGEN);  // triggers FSM
resp = cir_poll_response();            // → 0x9604 (AN-947: transfer CPU→FPU, 4 bytes)
cir_wr(OFF_CIR_OPERAND, 42);          // write source operand
cir_wait_null();                       // dialog complete; result in FP register
```

The two modes share a 5-bit address space with overlapping registers (addresses
1, 4, 5, 7, 8, 14). A mode flag at address 13 gates the decode: CIR mode is
default on reset. See the [validation README](validation/hello_world/src/README.md)
for the full address map, protocol details, and code examples.

19/19 tests pass: 7 peripheral smoke + 7 CIR dialog + 5 Musashi integration.

### BIOS ROM boot mode

The default build boots a 68000 BIOS ROM with an interactive monitor, built-in
assembler (CODE68K), and disassembler (DCODE68K). Character I/O is routed through
MC68901 MFP emulation (ARM UART ↔ emulated MFP USART) and rendered to a text
framebuffer displayed on the PS DisplayPort output (1280×720@60Hz).

USB keyboards and mice are supported via the ZynqMP DWC3 xHCI host controller:
- **Keyboard**: HID boot-protocol, Caps Lock/Num Lock with LED feedback, feeds
  ASCII into the MFP RX buffer alongside ARM UART input
- **Mouse**: HID boot-protocol, buttons + relative/absolute position tracking,
  accessible via memory-mapped I/O at `$FD0050` and TRAP #15 (D0=26/27/28)
- Automatic hub traversal (up to 3 levels) — works with keyboards and mice
  behind USB hubs, including combo devices with built-in hubs

The assembler and disassembler support all MC68881 FPU instructions:
- **39 FPU mnemonics**: FMOVE through FMOVECR (all arithmetic, transcendental,
  data movement, and compare/test operations)
- **32 FBcc conditions**: FBEQ, FBGT, FBGE, FBLT, FBLE, FBGL, FBGLE, FBOGT,
  FBOGE, FBOLT, FBOLE, FBOGL, FBOR, FBUN, FBUEQ, FBUGT, FBUGE, FBULT,
  FBULE, FBNE, FBT, FBSF, FBST, FBSEQ, FBSNE, and negated variants
- **All format suffixes**: `.B`, `.W`, `.L`, `.S`, `.D`, `.X`, `.P`
- **Floating-point literals**: Decimal FP constants (e.g., `FADD.S #2.35,FP0`)
  with IEEE 754 conversion for `.S` (single), `.D` (double), and `.X` (extended)
- **FMOVE variants**: reg↔reg, mem↔reg, reg→mem, FMOVECR, FMOVE to/from
  FPCR/FPSR/FPIAR

The monitor supports Go (execute), single-step Trace, software Breakpoints
(up to 8), register dump (CPU + FPU), and memory inspect/modify. See the
[BIOS User Guide](docs/merlin2_bios.md) for full command reference and build
instructions.

The BIOS ROM source is in `validation/hello_world/src/roms/bios.s`. Build with:

```bash
vasmm68k_mot -Fbin -m68000 -o bios.bin bios.s
# Extract ROM section and convert to C header (see docs/merlin2_bios.md)
```

### Hardware validation output

E2e test run on AXU3EG (Zynq UltraScale+ ZU3EG), Vitis 2025.2:

```
Zynq MP First Stage Boot Loader
Release 2025.2   Mar  9 2026  -  17:13:45
PMU-FW is not running, certain applications may not be supported.
PMU Firmware 2025.2     Mar  9 2026   17:13:51
PMU_ROM Version: xpbr-v8.1.0-0

mc68881 e2e test (vectors from GHDL tb)
========================================
PASS ADD 3.7+2.4
PASS SUB -2.3-0.6
PASS MUL 3.7*2.4
PASS DIV 12.5/-0.7
PASS SQRT(9)
PASS SIN(1.0)
PASS SIN(1.1)
PASS SIN(-0.7)
PASS COS(-2.3)
PASS COS(0.3)
PASS TAN(0.9)
PASS ETOX(0.75)
PASS LOGN(1.25)
PASS SIN(0)
PASS SQRT(1)
PASS FMOVECR(pi)
PASS DIV(pi/3)
========================================
17 passed, 0 failed, 17 total
ALL TESTS PASSED
```

### FPU benchmarks

Standard floating-point benchmarks run on the M68K emulator with hardware FPU
(F-line trapping to FPGA), measured on AXU3EG at 100 MHz AXI / 50 MHz FPU:

**Whetstone** (NLOOP=10, exercises ADD/SUB/MUL/DIV/SQRT/SIN/COS/ATAN/LOG/EXP):
```
=== Whetstone Benchmark ===
M2 (array)... OK
M3 (proc array)... OK
M4 (conditionals)... OK
M6 (log/exp/sqrt)... OK
M7 (proc calls)... OK
M8 (trig)... OK

Passes: 10
Elapsed: 2191 ms
KWIPS: 4564
Whetstone complete.
```

**Savage** (2500 iterations of x = tan(atan(exp(ln(sqrt(x*x)))))), result should be 1.0):
```
=== Savage Benchmark ===
Result: 3FFE0000 FFFFFFFF FFFE54C8
Expect: 3FFF0000 80000000 00000000  (1.0)
Iterations: 2500
Elapsed: 210 ms
Done.
```

The Savage result (~0.999999999999994) shows ~6×10⁻¹⁵ accumulated rounding error
over 2500 iterations of 6 chained transcendental operations — reasonable for
64-bit extended precision.

Benchmark sources are in `validation/hello_world/src/roms/` (`savage.s`, `whetstone.s`).

### GCC example programs

The `toolchain/examples/` directory contains C programs compiled with the m68k-elf-gcc
cross-compiler and loaded via S-record transfer. Build with `.\build.ps1` (requires
Cygwin with m68k-elf-gcc).

| Program | Description | FPU? |
|---------|-------------|------|
| `hello.c` | Hello world (printf, TRAP I/O) | No |
| `fputest.c` | FPU arithmetic test (sin, cos, sqrt) | Yes |
| `fireworks.c` | Animated fireworks demo (physics + graphics) | Yes |
| `rtctest.c` | RTC date/time read/set, Timer C tick monitor | No |
| `mousetest.c` | USB mouse demo (crosshair cursor, click markers) | No |

**Mouse demo** (`mousetest.c`): Switches to 1280×720 graphics mode and renders a
green crosshair cursor that tracks the USB mouse. Left/right/middle clicks leave
coloured dot markers on the screen. A banner at the top displays the current X/Y
position and active buttons. Press any keyboard key to exit. Reads mouse state
directly from memory-mapped I/O at `$FD0050` (buttons, delta, absolute position).

## Validation PCB

The `validation/kicad/` directory contains a KiCad 8 project ("NextCuboid") for a
physical validation board that connects a real MC68SEC000 CPU to the QMTECH
Artix-7 200T core board running the FPGA FPU core, alongside an original 5V
MC68881FN for comparison testing. This is the first physical hardware validation
of the coprocessor interface — exercising real bus timing, level shifting, and
the CIR dialog protocol over actual copper.

### Board architecture

```
MC68SEC000FU20 (3.3V, 20 MHz)
    │
    ├── Coprocessor bus ──► SN74LVC8T245 level shifters (3.3V ↔ 5V)
    │                           │
    │                           ├──► MC68881FN (original 5V DIP/PLCC)
    │                           │
    │                           └──► QMTECH Artix-7 200T (mc68881_top)
    │
    └── Active-low control ──► 74LVC1G125 single-gate buffers
```

### Key components

| Component | Part | Role |
|-----------|------|------|
| CPU | MC68SEC000FU20 | 3.3V 68000-compatible bus master |
| FPGA FPU | QMTECH XC7A200T core board | Runs `mc68881_top` with bus bridge |
| Reference FPU | MC68881FN (original Motorola) | 5V DIP/PLCC, golden reference |
| Level shifters | SN74LVC8T245 (×5) | Bidirectional 3.3V ↔ 5V translation |
| Control buffers | 74LVC1G125 (×2) | Single-gate active-low signal translation |

The board uses dual QMTECH connectors (active main + active secondary headers)
and includes 4.7K pull-up resistors on open-drain/open-collector signals plus
100nF decoupling capacitors on all ICs. Gerber outputs are in
`validation/kicad/output/`.

PCB production sponsored by [PCBWay](https://www.pcbway.com) — thanks to them
for supporting this project.

## Status
All checklist items complete. See `docs/fpu-progress-checklist.md` for history.

## Documentation index

### Project documentation
| File | Description |
|------|-------------|
| [`docs/history.md`](docs/history.md) | Development history and changelog |
| [`docs/merlin2_bios.md`](docs/merlin2_bios.md) | Merlin2 BIOS monitor user guide |
| [`docs/trig_design.md`](docs/trig_design.md) | Transcendental engine architecture and algorithm design |
| [`docs/fpsp_comparison_checklist.md`](docs/fpsp_comparison_checklist.md) | FPSP (68040 FP software package) comparison checklist |
| [`docs/next68040_defect_checklist.md`](docs/next68040_defect_checklist.md) | NeXT 68040LC emulator defect/TODO tracker |
| [`docs/nextmach_boot_checklist.md`](docs/nextmach_boot_checklist.md) | NeXTMach kernel boot checklist |
| [`docs/merlin2_tasklist.md`](docs/merlin2_tasklist.md) | Merlin2 BIOS task list |
| [`docs/archive/fpu-progress-checklist.md`](docs/archive/fpu-progress-checklist.md) | Master checklist: implementation status (archived) |
| [`docs/archive/fmovecr_qemu_summary.md`](docs/archive/fmovecr_qemu_summary.md) | FMOVECR ROM constant cross-reference (archived) |
| [`docs/archive/qmtech_constraints_verification.md`](docs/archive/qmtech_constraints_verification.md) | XDC constraints verification for QMTECH board (archived) |

### Motorola / Atari reference manuals
| File | Description |
|------|-------------|
| `docs/datasheets/MC68881UM.pdf` | MC68881/MC68882 User Manual (Motorola) |
| `docs/datasheets/MC68881.PDF` | MC68881 datasheet |
| `docs/datasheets/MC68040UM.pdf` | MC68040 User Manual (Motorola) |
| `docs/datasheets/68881-tech-summary.pdf` | MC68881 Technical Summary |
| `docs/datasheets/AN-0947_MC68881...pdf` | AN-947: MC68881 as Peripheral in M68000 System |
| `docs/datasheets/68881-programming.txt` | MC68881 programming reference notes |
| `docs/datasheets/atari_sfp_en.pdf` | Atari SFP-004 programming by example |
| `docs/datasheets/atari_68881_co-processor.pdf` | Atari MC68881 coprocessor board reference |

### Hardware reference
| File | Description |
|------|-------------|
| `docs/datasheets/AXU3EG_User_Manual.pdf` | Alinx AXU3EG (Zynq UltraScale+ ZU3EG) board manual |
| `docs/datasheets/QMTECH_XC7A200T-CORE-BOARD-V01-*.pdf` | QMTECH Artix-7 200T core board manual |
| `docs/datasheets/MecbManual.pdf` | MECB 68000 educational board manual |

### Design plans
| File | Description |
|------|-------------|
| [`docs/plans/2026-03-22-68040-emutos-variant.md`](docs/plans/2026-03-22-68040-emutos-variant.md) | MC68040 EmuTOS variant plan |
| [`docs/plans/2026-03-19-68882-upgrade.md`](docs/plans/2026-03-19-68882-upgrade.md) | MC68882 upgrade plan (pending pipeline, frame formats) |
| [`docs/plans/2026-03-03-s7-coprocessor-interface.md`](docs/plans/2026-03-03-s7-coprocessor-interface.md) | CIR coprocessor interface implementation plan |
| [`docs/plans/2026-02-28-packed-decimal-completion.md`](docs/plans/2026-02-28-packed-decimal-completion.md) | Packed decimal conversion completion plan |

### READMEs
| File | Description |
|------|-------------|
| [`validation/NeXT-68040/README.md`](validation/NeXT-68040/README.md) | NeXT 68040LC emulator: Turbo ROM boot, interactive monitor, hardware FPU on ZynqMP |
| [`validation/hello_world/src/README.md`](validation/hello_world/src/README.md) | Validation firmware: peripheral + CIR protocol, SFP004 benchmark |
| [`toolchain/README.md`](toolchain/README.md) | M68K GCC cross-compilation toolchain |
| [`toolchain/merlin-68k-toolchain/README.md`](toolchain/merlin-68k-toolchain/README.md) | Merlin2 68K toolchain (newlib, BSP) |

## License
See repository for license terms.
