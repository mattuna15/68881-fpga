# Merlin 2 BIOS — User Guide

Interactive monitor, assembler, and debugger for the MC68000 + MC68881 FPGA system.

## Overview

The Merlin 2 BIOS is a ROM-resident monitor for a 68000 system with MC68901 MFP
(UART I/O) and MC68881 FPU. It provides:

- Interactive command-line monitor
- Built-in one-line assembler (CODE68K) with full MC68881 FPU support
- Built-in one-line disassembler (DCODE68K) with F-line decode
- Register dump (CPU + FPU)
- Software breakpoints and single-step trace
- Go (execute) with debug-aware RTE mode

The BIOS runs on real hardware (MC68000 + FPGA FPU) and under the Musashi emulator
on the AXU3EG validation platform.

## Memory Map

| Address | Size | Description |
|---------|------|-------------|
| `$000000-$00FFFF` | 64K | RAM (workspace, vectors, stack) |
| `$FD0000-$FD002F` | 48 bytes | MC68901 MFP (USART, timers, GPIO) |
| `$FE0000-$FFFFFF` | 128K | ROM (BIOS image) |

Stack pointer initializes to `$1000`. System stack (SYSTACK) is at `$5AE`.

## Monitor Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| **A** | `A <addr>` | Assemble — enter interactive assembler at address |
| **D** | `D <addr> <data>` | Deposit — write bytes to memory at address |
| **E** | `E <addr>` | Examine — display memory contents in hex |
| **H** | `H` | Help — display available commands |
| **L** | `L` | Load — receive Motorola S-record via UART |
| **G** | `G <addr>` | Go — execute code at address |
| **R** | `R` | Registers — display saved CPU and FPU registers |
| **T** | `T [count]` | Trace — single-step (default 1 instruction) |
| **B** | `B [addr[;count]]` | Breakpoint — set, or list all if no argument |
| **N** | `N [addr]` | No breakpoint — clear one or all breakpoints |

### G (Go) Command

Executes code at the specified address. Two modes:

- **No breakpoints set**: Uses JSR — the target routine must end with RTS to
  return to the monitor. Registers are saved on return.
- **Breakpoints active**: Uses RTE-based debug mode. The monitor single-steps
  past the first instruction (to handle breakpoint-at-PC), then installs all
  breakpoints and runs at full speed until a breakpoint is hit or the program
  completes.

After G returns, use **R** to view saved registers (D0-D7, A0-A6, SP, PC, SR,
FP0-FP7).

### T (Trace) Command

Single-steps through code from the current saved PC. Requires a previous **G**
command to establish saved registers.

```
>G 1000        (run program, sets up saved regs)
>T             (trace 1 instruction from saved PC)
>T 5           (trace 5 instructions)
```

Each traced instruction displays the register state and disassembles the next
instruction to execute.

### B (Breakpoint) Command

Set up to 8 software breakpoints. Breakpoints use the `$4AFB` illegal opcode.

```
>B 100C        (set breakpoint at $100C)
>B 100C;3      (set breakpoint with pass count 3 — skips 3 hits, breaks on 4th)
>B             (list all breakpoints)
```

When a breakpoint is hit, the monitor displays the address, register dump, and
disassembled instruction at the break point.

### N (No Breakpoint) Command

```
>N 100C        (clear breakpoint at $100C)
>N             (clear all breakpoints)
```

## Assembler (CODE68K)

The **A** command enters the one-line assembler. Each line shows the current
address, existing hex/disassembly, then prompts for input. Type an instruction
to assemble it at that address, or press Enter to skip, or type **X** to exit.
Backspace and Delete keys work for correcting typos during input.

```
>A 1000
001000    00000000             OR.B    #0,D0  >FADD.L #1,FP0
001000    F23C402200000001     FADD.L  #1,FP0
001008    00000000             OR.B    #0,D0  >RTS
001008    4E75                 RTS
00100A    00000000             OR.B    #0,D0  >X
```

### Supported Instructions

All standard MC68000 instructions plus:

- **39 FPU mnemonics**: FADD, FSUB, FMUL, FDIV, FMOD, FREM, FSQRT, FABS,
  FNEG, FINT, FINTRZ, FGETEXP, FGETMAN, FSCALE, FSGLDIV, FSGLMUL, FSIN,
  FCOS, FTAN, FSINCOS, FASIN, FACOS, FATAN, FATANH, FSINH, FCOSH, FTANH,
  FETOX, FETOXM1, FTWOTOX, FTENTOX, FLOGN, FLOGNP1, FLOG2, FLOG10, FMOVE,
  FMOVECR, FCMP, FTST
- **32 FBcc conditions**: FBEQ, FBNE, FBGT, FBGE, FBLT, FBLE, FBGL, FBGLE,
  FBOGT, FBOGE, FBOLT, FBOLE, FBOGL, FBOR, FBUN, FBUEQ, FBUGT, FBUGE,
  FBULT, FBULE, FBT, FBSF, FBST, FBSEQ, FBSNE, and negated variants
- **All format suffixes**: `.B`, `.W`, `.L`, `.S`, `.D`, `.X`, `.P`
- **Floating-point literals**: `FADD.S #2.35,FP0` with IEEE 754 conversion
  for `.S` (single), `.D` (double), and `.X` (extended)

### Assembler Usage Examples

```
>A 1000
001000  >MOVE.L #5,D0          Move immediate
001006  >FADD.L #1,FP0         FPU add long integer to FP0
00100E  >FADD.S #2.35,FP1      FPU add single-precision float literal
001016  >FADD FP0,FP1           FPU register-to-register add
00101A  >FSIN FP1,FP2           FPU sine
00101E  >RTS                    Return
001020  >X                      Exit assembler
```

## Building the BIOS

### Prerequisites

- **vasm** (m68k, Motorola syntax): cross-assembler for 68000
  - Binary: `C:\code\vasm68k\vasmm68k_mot.exe` (or `vasmm68k_mot` on PATH)
- **Python 3**: for ROM header generation

### Step 1: Assemble

```bash
cd validation/hello_world/src/roms
vasmm68k_mot -Fbin -m68000 -o bios.bin bios.s
```

This produces a flat binary spanning the full 68000 address space. The file
starts at address `$402` (first `ORG RAMBAS+2` in bios.s). Warnings about
`DC.B` are expected from legacy disassembler tables.

### Step 2: Extract ROM and Generate C Header

The ROM lives at `$FE0000` in the 68000 address space. Since the binary starts
at `$402`, the ROM is at file offset `$FE0000 - $402 = $FDFBFE`.

```bash
python -c "
data = open('bios.bin','rb').read()
rom = data[0xFE0000 - 0x402:]
# Trim trailing zeros
while rom and rom[-1] == 0:
    rom = rom[:-1]
# Sanity check: first bytes must be ORI.W #$0700,SR
assert rom[:4] == bytes([0x00,0x7C,0x07,0x00]), f'Bad ROM header: {rom[:4].hex()}'
lines = ['/* Auto-generated from bios.bin -- do not edit */']
lines.append('static const unsigned char rom_image_data[] = {')
for i in range(0, len(rom), 16):
    chunk = rom[i:i+16]
    lines.append('  ' + ', '.join(f'0x{b:02x}' for b in chunk) + ',')
lines.append('};')
lines.append(f'static const unsigned int rom_image_size = {len(rom)};')
with open('../rom_image.h', 'w') as f:
    f.write('\n'.join(lines) + '\n')
print(f'Generated rom_image.h: {len(rom)} bytes')
"
```

### Step 3: Rebuild the Emulator/Hardware Image

After regenerating `rom_image.h`, rebuild the Vitis application (or reflash the
hardware image). The emulator loads the ROM as a compiled-in C array
(`rom_image_data[]`) at address `$FE0000`.

### Important

After **any** edit to `bios.s`, both steps must be run. Forgetting the header
generation will leave the hardware/emulator running the old BIOS version.

## Easy68K Compatibility

The BIOS supports conditional assembly for the Easy68K simulator:

```asm
EASY68K_SIM  EQU 0    ; 0 = real hardware (MFP UART)
EASY68K_SIM  EQU 1    ; 1 = Easy68K simulator I/O
```

When `EASY68K_SIM=1`:
- TRAP #15 uses Easy68K's built-in I/O functions
- FPU register save/restore (hand-encoded F-line opcodes) is skipped
- Echo is disabled (Easy68K provides its own echo)

## Source File

The canonical BIOS source is:

```
validation/hello_world/src/roms/bios.s
```

## Architecture Notes

### Exception Vectors

| Vector | Address | Handler |
|--------|---------|---------|
| 4 (Illegal instruction) | `$0010` | `illegalHandler` — debug breakpoint or fault |
| 9 (Trace) | `$0024` | `traceHandler` — single-step debug |
| 2-7 (Bus/Address/etc) | `$0008-$001C` | `excFault` — displays fault address |
| 32+1 (TRAP #1) | | GPIO control |
| 32+15 (TRAP #15) | | I/O services (Easy68K-compatible API) |

### TRAP #15 I/O Services

| D0 | Function |
|----|----------|
| 0 | Display string at (A1), D1.W bytes, with CR+LF |
| 1 | Display string at (A1), D1.W bytes, no CR+LF |
| 2 | Read string into (A1), null-terminated; D1.W = length. Supports backspace/delete editing |
| 3 | Display signed number D1.L in decimal |
| 5 | Read single character into D1.B |
| 6 | Display character D1.B |
| 7 | Check UART RX buffer (D1.B = 1 if data available) |
| 12 | Set echo on/off (D1.B) |
| 13 | Print null-terminated string at (A1) with CR+LF |
| 14 | Print null-terminated string at (A1) without CR+LF |
| 15 | Print unsigned D1.L in base D2.B |

### Debug Internals

- **Breakpoints**: 8 regular + 1 temporary slot. Uses `$4AFB` illegal opcode.
- **TRACECNT**: Word counter. >0 = instructions remaining, 0 = stopped,
  -1 = single-step-then-resume (for stepping past breakpoints).
- **swapIn/swapOut**: Plant and remove breakpoint opcodes in user code.
- **saveRegs/unstack**: Save all CPU+FPU registers from exception context /
  restore and RTE to user code.

## First Hardware FPU Validation (2026-03-13)

The assembler was used to perform the first interactive validation of the MC68881
FPGA on real hardware. FPU instructions were assembled, executed, and verified:

```
>A 1000
001000  >FADD.L #1,FP0
001008  >FADD.S #2.35,FP1
001010  >FADD FP0,FP1
001014  >RTS
>G 1000
>R
 FP0=3FFF0000 80000000 00000000    (= 1.0)
 FP1=40000000 D6666600 00000000    (= 3.35 = 1.0 + 2.35)
```

All results correct, confirming the FPU VHDL implementation produces accurate
IEEE 754 extended-precision results when driven by real 68000 assembled code.
