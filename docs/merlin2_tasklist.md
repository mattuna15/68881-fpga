# Merlin 2 — Task Checklist

## Assembler Bugs

- [x] **Fix cvtCase** — converts operand characters it shouldn't (e.g., string literals, comments)
- [x] **Fix M4324 FPU .S suffix** — clobbers D0 index for TBLKEYS lookup
- [x] **Fix .S TLENGTH override** — M350 sets TLENGTH=$0040 (.W) but MC68881 single needs 4 bytes; MFPU_EA/EA2 now override to $0080
- [x] **Fix MCMMD2 D3 upper bytes** — `MOVE.B TNB(A1),D3` left upper D3 bytes from command word building; added `CLR.L D3` before load
- [ ] **Fix LINK/UNLK** — ER path corrupts stack on nested BSRs
- [ ] **Fix FADD FP0,FP2 (R2R without suffix)** — OPC match or MFPU handler failing silently; debug markers added, awaiting test

## Disassembler Bugs

- [x] **Fix IFLINE BTST #15→#14** — R/M bit check was testing wrong bit (15 instead of 14), causing wrong disassembly path
- [x] **Fix IFLINE alignment** — FMCRSTR string left IFLINE at odd address ($FE2AB5); added `EVEN` before `LONG` macro
- [x] **Fix KI/TBL alignment** — GETNDATA string left KI at odd address; added `EVEN` before KI
- [x] **Fix FOPTBL D7 upper bytes** — `MOVE.B (A0,D0.W),D7` left upper D7 bytes as garbage; added `CLR.L D7`
- [x] **Fix FPU immediate sizes in EEA** — EEA only handled .B/.W/.L; added .S (4B), .D (8B), .X/.P (12B) handlers

## Assembler Testing

- [ ] **Test F-line FPU instruction assembly** — EA-to-FP works; R2R (no suffix) broken; FP-to-FP, FMOVE variants, FBcc still to verify

## Assembler Features

- [x] **FP literal support (.S)** — parse decimal (e.g., `#2.35`) → IEEE 754 single via FPARSLIT
- [x] **FP literal support (.D/.X)** — promote single → double (FSGL2DBL) or extended (FSGL2EXT); TDATA expanded to 18 bytes
- [ ] **FP literal support for .P (packed BCD)** — FPARSLIT currently converts decimal → single → double/extended; .P needs a dedicated decimal → packed BCD converter
- [ ] **Delete character support in line input** — handle backspace/delete in the assembler input loop
- [ ] **Option R — register dump** — print current registers (D0–D7, A0–A7, FP0–FP7, SP, PC, SR, etc.)
- [ ] **Debug/trace/breakpoint support** — add interactive debugging commands to the monitor/assembler

## ROM / BIOS

- [x] **Merlin 2 FPU banner** — add startup banner to ROM boot sequence
- [ ] **Add build number in banner** — display a build/version number in the startup banner
- [ ] **Remove debug traces** — clean up debug markers in `emu_memory.c` and `bios.s` after all fixes are done

## Hardware

- [ ] **KiCad hardware validation board** — PCB design for real-hardware validation of the MC68881 FPU (MC68000 + FPGA + support circuitry)

## Benchmarks & Demos

- [ ] **M68K FLOPS benchmark** — floating-point operations per second benchmark exercising the MC68881 FPU via F-line trapping
- [ ] **Coloured pixel graphics mode** — pixel-addressable colour mode (ARGB8888) for visual FP demos, integrated with existing DP video output (1280x720)
- [ ] **Mandelbrot set renderer** — FPU demo using pixel graphics mode
- [ ] **3D trig point/surface graphs** — FPU demo plotting trigonometric 3D surfaces
