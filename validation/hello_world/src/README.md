# M68K Emulator -- Hardware FPU Validation (Register-Mapped Mode)

Runs a Musashi M68000 emulator bare-metal on the ARM Cortex-A53 (AXU3EG / ZU3EG).
M68K floating-point instructions (F-line opcodes) are trapped and executed on the
real mc68881 FPGA core using the **direct register-mapped interface** over AXI-Lite.

## Why No CIR?

The real MC68881 communicates with the host CPU via the **Coprocessor Interface
Registers (CIR)** -- a stateful command/response/operand dialog protocol described
in Motorola AN-947. The host writes a command word, polls the response register,
transfers operands through a data register, and polls again until released.

This FPGA implementation exposes the FPU core through **two** interfaces:

1. **CIR dialog** -- faithful to the original 68881 protocol (for real 68K hardware)
2. **Register-mapped** -- direct access to operand/result/control registers via AXI-Lite

This example uses **only the register-mapped interface**. The CIR state machine
is not involved at all. This means:

- **No command/response polling loop** -- just write operands, trigger, poll status, read result
- **No coprocessor protocol overhead** -- one OPSEL write starts execution
- **The CIR can be removed** from the design and the FPU core remains fully usable
  as a standalone compute engine via AXI-Lite
- **Any host CPU** (ARM, RISC-V, soft-core, etc.) can drive the FPU -- not just 68K

## Architecture

```
ARM Cortex-A53 (bare-metal Vitis BSP)
|
+-- Musashi M68K emulator (M68000 mode)
|   +-- 16 MB emulated RAM (emu_ram[] in DDR)
|   +-- m68k_read/write callbacks -> emu_ram[]
|   +-- F-line exception -> fline_illg_callback()
|
+-- F-line handler (fline_handler.c)
|   +-- Decodes 68881 command word (op-class, format, opcode)
|   +-- Reads source operand from M68K memory or FP register
|   +-- Converts format (single/double/long/word/byte -> FP80)
|   +-- Software FP register file: fp_regs[8] + FPCR/FPSR/FPIAR
|
+-- FPU peripheral driver (fpu_periph.c)
|   +-- Writes OPA/OPB registers (FP80 operands)
|   +-- Writes OPSEL to trigger execution
|   +-- Polls STATUS register for completion
|   +-- Reads RES registers (FP80 result)
|
+-- AXI-Lite @ 0x80000000
         |
    mc68881_axilite_wrapper -> FPU core
    (no CIR involvement)
```

## Register-Mapped FPU Protocol

The protocol is simple -- no state machine, no handshaking:

```c
// 1. Load operands (FP80: sign+exponent, significand high, significand low)
fpu_wr(OFF_OPA_L, op_a.l);  fpu_wr(OFF_OPA_H, op_a.h);  fpu_wr(OFF_OPA_E, op_a.e);
fpu_wr(OFF_OPB_L, op_b.l);  fpu_wr(OFF_OPB_H, op_b.h);  fpu_wr(OFF_OPB_E, op_b.e);

// 2. Trigger operation (OPSEL write starts execution immediately)
fpu_wr(OFF_OPSEL, 0x01000001);  // CORE_V1 namespace | ADD opcode

// 3. Poll for completion
while (!(fpu_rd(OFF_STATUS) & 0x01)) { /* spin */ }

// 4. Read result
result.l = fpu_rd(OFF_RES_L);
result.h = fpu_rd(OFF_RES_H);
result.e = fpu_rd(OFF_RES_E);
```

For unary operations (SIN, SQRT, etc.), only OPA is loaded. For FMOVECR,
the constant ROM offset goes in OPA_L and MOVE_CFG selects the mode.

### Key Registers

| Register | Offset | Access | Purpose |
|----------|--------|--------|---------|
| OPSEL    | 0x00   | W      | Operation select (write triggers execution) |
| OPA_L/H/E| 0x04-0x0C | W  | Operand A (FP80) |
| OPB_L/H/E| 0x10-0x18 | W  | Operand B (FP80) |
| RES_L/H/E| 0x1C-0x24 | R  | Result (FP80) |
| STATUS   | 0x28   | R      | bit 0=valid, bit 1=busy |
| FPCR     | 0x2C   | R/W    | FP control (rounding mode, precision) |
| FPSR     | 0x38   | R      | FP status (condition codes, exceptions) |
| MOVE_CFG | 0x5C   | W      | FMOVECR/FMOVE/FMOVEM configuration |

### OPSEL Encoding

`namespace[31:24] | opcode_id[7:0]` -- CORE_V1 namespace = 0x01.

## How the F-line Handler Works

When M68K code executes an F-line instruction (`$Fxxx`), Musashi calls our
`fline_illg_callback()`. The handler:

1. **Reads the command word** from M68K memory at the current PC
2. **Classifies by Op-Class** (bits 15:13 of the command word):
   - 000 = register-to-register arithmetic
   - 010 = memory/immediate-to-register (with format conversion)
   - 011 = register-to-memory (FMOVE out with format conversion)
   - 100/101 = move to/from control registers (FPCR/FPSR/FPIAR)
3. **Fetches the source operand**: from the software register file or from
   M68K memory (converting byte/word/long/single/double/extended to FP80)
4. **For arithmetic**: loads OPA (+ OPB for dyadic ops) and writes OPSEL
5. **For FMOVE**: stores directly to the software register file (the hardware
   register file is for the CIR path -- we bypass it entirely)
6. **Polls STATUS**, reads result, stores to `fp_regs[dst]`
7. **Advances M68K PC** past the variable-length instruction

### 68881 Command Word Format

```
Bits 15:13  Op-Class
Bits 12:10  Source specifier (FP reg if reg-to-reg, format if mem-to-reg)
Bits  9:7   Destination FP register
Bits  6:0   Opcode (FADD=0x22, FMUL=0x23, FSIN=0x0E, FSQRT=0x04, etc.)
```

## Test Results

```
--- Peripheral smoke test ---
PASS ADD 3.7+2.4
PASS SUB -2.3-0.6
PASS MUL 3.7*2.4
PASS DIV 12.5/-0.7
PASS SQRT(9)
PASS SIN(1.0)
PASS FMOVECR(pi)
--- 7 passed, 0 failed ---

--- Basic FPU integration test (Musashi + F-line) ---
PASS FMOVECR(pi)->FP0
PASS FADD pi+1->FP1
PASS FMUL 3.7*2.4->FP3
PASS FSIN(1.0)->FP1
PASS FSQRT(9)->FP5
--- 5 passed, 0 failed ---

ALL TESTS PASSED
```

## Building (Vitis 2025.2)

The project is a standard Vitis embedded application targeting the ZU3EG platform.

**Source files compiled** (configured in `UserConfig.cmake`):

| File | Purpose |
|------|---------|
| `main.c` | Entry point |
| `fpu_periph.c` | FPU register-mapped driver |
| `fp_regfile.c` | Software FP80 register file |
| `fline_handler.c` | F-line instruction decode |
| `emu_memory.c` | 16 MB emulated M68K RAM |
| `musashi/m68kcpu.c` | Musashi M68000 core |
| `musashi/m68kops.c` | Generated opcode handlers |
| `musashi/softfloat/softfloat.c` | SoftFloat (required by Musashi types) |
| `tests/periph_smoke.c` | Direct FPU driver test |
| `tests/basic_fpu.c` | Musashi + F-line integration test |
| `platform.c` | Vitis BSP platform init |

**Do NOT compile:** `m68kfpu.c` (Musashi's software FPU -- `#include`d by
m68kcpu.c but its functions are dead code with all higher CPUs disabled),
`m68kmake.c` (code generator), `m68k_in.c` (generator input),
`m68kdasm.c` (disassembler, optional).

**Link with** `-lm` (required by m68kfpu.c's math calls, even though
the functions are never executed).

## Supported Instructions

- **Arithmetic:** FADD, FSUB, FMUL, FDIV, FMOD, FREM, FSCALE, FSGLDIV, FSGLMUL
- **Transcendental:** FSIN, FCOS, FTAN, FSINCOS, FASIN, FACOS, FATAN, FATANH,
  FSINH, FCOSH, FTANH, FETOX, FETOXM1, FLOGN, FLOGNP1, FLOG10, FLOG2,
  FTENTOX, FTWOTOX
- **Unary:** FABS, FNEG, FSQRT, FINT, FINTRZ, FGETEXP, FGETMAN
- **Data transfer:** FMOVE (reg-to-reg, mem-to-reg, reg-to-mem), FMOVECR,
  FMOVE to/from FPCR/FPSR/FPIAR
- **Compare/test:** FCMP, FTST
- **Branch:** FBcc (16-bit and 32-bit displacement, all 32 condition codes)

**Source formats:** Byte, Word, Long, Single, Double, Extended (12-byte).
