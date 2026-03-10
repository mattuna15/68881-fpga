# M68K Emulator — Hardware FPU Validation

Runs a Musashi M68000 emulator bare-metal on the ARM Cortex-A53 (AXU3EG / ZU3EG).
M68K floating-point instructions (F-line opcodes) are trapped and executed on the
real mc68881 FPGA core via the AXI-Lite peripheral interface.

## Architecture

```
ARM Cortex-A53 (bare-metal Vitis BSP)
├── Musashi M68K emulator (M68000 mode)
│   ├── 16 MB emulated RAM (emu_ram[] in DDR)
│   ├── m68k_read/write callbacks → emu_ram[]
│   └── F-line exception → fline_handler → fpu_periph driver
├── FPU Peripheral Driver (fpu_periph.c)
│   ├── Converts FP operands to/from FP80 format
│   ├── Writes OPSEL/OPA/OPB registers via AXI-Lite
│   ├── Polls STATUS for completion
│   └── Reads RES registers, writes back to software FP register file
└── AXI-Lite @ 0x80000000
         │
    mc68881_axilite_wrapper → bus_bridge → FPU core
```

## File Layout

```
m68k_emu/
├── main.c               Entry point — runs all tests
├── fpu_periph.h/c       FPU peripheral driver (AXI-Lite register access)
├── fp_regfile.h/c       Software FP80 register file (FP0–FP7 + control regs)
├── fline_handler.h/c    F-line instruction decode → fpu_periph calls
├── emu_memory.h/c       16 MB flat RAM + Musashi memory callbacks
├── musashi/             Vendored Musashi v4.60 (MIT license)
│   ├── m68kconf.h       Our config: M68000-only, FPU disabled, F-line callback
│   ├── m68kcpu.c/h      Core emulator
│   ├── m68kops.c/h      Generated opcode handlers (from m68kmake + m68k_in.c)
│   ├── m68kmake.c       Code generator (run once to regenerate m68kops.*)
│   ├── m68k_in.c        Opcode definitions (input to m68kmake)
│   ├── m68kdasm.c       Disassembler (optional, useful for debugging)
│   ├── m68kfpu.c        Musashi's software FPU (NOT compiled — we use hardware)
│   ├── m68kmmu.h        MMU support (not used)
│   └── softfloat/       SoftFloat library (required by m68kcpu.h typedefs)
│       ├── mamesf.h     Our minimal type shim (replaces MAME dependency)
│       ├── milieu.h     SoftFloat platform config
│       ├── softfloat.h/c  SoftFloat implementation
│       ├── softfloat-macros
│       └── softfloat-specialize
├── tests/
│   ├── periph_smoke.h/c  Phase 1: direct peripheral driver test (no Musashi)
│   └── basic_fpu.h/c     Phase 3: Musashi + F-line + hardware FPU integration
└── README.md
```

## How It Works

1. **Musashi** decodes M68000 instructions from `emu_ram[]`.
2. When it hits an F-line opcode (`$Fxxx`), it calls `fline_illg_callback()`.
3. The **F-line handler** reads the command word from M68K memory, decodes:
   - Operation (FADD, FMUL, FSIN, etc.)
   - Source operand (FP register or memory, with format conversion)
   - Destination FP register
4. The **FPU peripheral driver** writes operands to OPA/OPB registers,
   triggers execution via OPSEL, polls STATUS, and reads the result from RES.
5. The result is written back to the **software register file** (`fp_regs[8]`).
6. The M68K PC is advanced past the variable-length instruction.

## Supported Instructions

- **Arithmetic:** FADD, FSUB, FMUL, FDIV, FMOD, FREM, FSCALE, FSGLDIV, FSGLMUL
- **Transcendental:** FSIN, FCOS, FTAN, FSINCOS, FASIN, FACOS, FATAN, FATANH,
  FSINH, FCOSH, FTANH, FETOX, FETOXM1, FLOGN, FLOGNP1, FLOG10, FLOG2,
  FTENTOX, FTWOTOX
- **Unary:** FABS, FNEG, FSQRT, FINT, FINTRZ, FGETEXP, FGETMAN
- **Data transfer:** FMOVE (reg↔reg, mem→reg, reg→mem), FMOVECR (constant ROM),
  FMOVE to/from FPCR/FPSR/FPIAR
- **Compare/test:** FCMP, FTST
- **Branch:** FBcc (16-bit and 32-bit displacement, all 32 condition codes)

**Source formats:** Byte, Word, Long, Single, Double, Extended (12-byte).
Packed BCD is not yet supported.

## Building (Vitis)

1. Create a new Vitis application project targeting the ZU3EG platform.
2. Add all `.c` files from this directory and `musashi/` to the project
   (exclude `m68kfpu.c`, `m68kmake.c`, `m68k_in.c`, and `m68kdasm.c`).
3. Add include paths: this directory and `musashi/`.
4. Build and run on the AXU3EG board with the mc68881 bitstream loaded.

**Source files to compile:**

| File | Purpose |
|------|---------|
| `main.c` | Entry point |
| `fpu_periph.c` | FPU hardware driver |
| `fp_regfile.c` | Software register file |
| `fline_handler.c` | F-line instruction decode |
| `emu_memory.c` | Emulated M68K RAM |
| `musashi/m68kcpu.c` | Musashi core |
| `musashi/m68kops.c` | Generated opcode handlers |
| `musashi/softfloat/softfloat.c` | SoftFloat (required by Musashi types) |
| `tests/periph_smoke.c` | Peripheral smoke test |
| `tests/basic_fpu.c` | Integration test |

**Do NOT compile:** `m68kfpu.c` (Musashi's software FPU — conflicts with our
hardware approach), `m68kmake.c` (code generator, not runtime), `m68k_in.c`
(input to m68kmake), `m68kdasm.c` (optional disassembler).

## Regenerating Musashi Opcode Tables

If you modify `m68k_in.c` or `m68kconf.h`, regenerate the opcode handlers:

```bash
cd musashi
gcc -o m68kmake m68kmake.c
./m68kmake . m68k_in.c
```

This overwrites `m68kops.c` and `m68kops.h`.

## Adding Test Programs

### Hand-assembled (no toolchain needed)

Write M68K opcodes as hex words directly in C. See `tests/basic_fpu.c` for
examples. The F-line instruction format:

```
Opword:   1111 001 000 EEEEEE     (CpID=1, type=000, EA mode/reg)
Command:  R 0 SSS DDD OOOOOOO     (R/M, source, dest FP reg, opcode)

R/M=0: register-to-register, SSS = source FP reg
R/M=1: memory-to-register,   SSS = format (0=L,1=S,2=X,4=W,5=D,6=B)
```

### vasm (recommended for real programs)

Assemble with vasm targeting M68000:

```bash
vasmm68k_mot -m68000 -Fbin -o test.bin test.s
xxd -i test.bin > test_rom.h
```

Then load the binary into `emu_ram[]` via `emu_mem_load()`.

### m68k-elf-gcc (for compiled C)

Cross-compile with soft-float (F-line instructions will trap to our handler):

```bash
m68k-elf-gcc -m68000 -msoft-float -nostdlib -Ttext=0x1000 -o test.elf test.c
m68k-elf-objcopy -O binary test.elf test.bin
```

Note: `-msoft-float` generates software FP calls, not F-line instructions.
For hardware FPU testing, use inline asm with `DC.W` or vasm.
