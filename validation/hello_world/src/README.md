# M68K Emulator -- Hardware FPU Validation

Runs a Musashi M68000 emulator bare-metal on the ARM Cortex-A53 (AXU3EG / ZU3EG).
M68K floating-point instructions (F-line opcodes) are trapped and executed on the
real mc68881 FPGA core over AXI-Lite. The validation suite exercises **both**
operating modes of the FPU:

- **CIR dialog protocol** -- the authentic MC68881 coprocessor interface (AN-947)
- **Peripheral (register-mapped)** -- direct register access for any host CPU

## Two Operating Modes

The FPGA FPU exposes a single 5-bit address space (32 registers) that serves two
overlapping purposes. A mode flag (`cir_mode_reg`, address 13, bit 0) selects
which decode path handles the overlapping addresses:

```
Address   CIR mode (cir_mode=1)     Peripheral mode (cir_mode=0)
-------   ----------------------     ----------------------------
  0       OPSEL                      OPSEL
  1       CIR Control/Ack            OPA_L  (operand A low)
  2       --                         OPA_H  (operand A high)
  3       --                         OPA_E  (operand A exponent)
  4       CIR OpWord                 OPB_L  (operand B low)
  5       CIR Command                OPB_H  (operand B high)
  6       --                         OPB_E  (operand B exponent)
  7       CIR Condition              RES_L  (result low)
  8       CIR Operand                RES_H  (result high)
  9       --                         RES_E  (result exponent)
 10       STATUS                     STATUS
 11       FPCR                       FPCR
 12       CIR Instruction Addr       --
 13       CIR Response / Mode        CIR Mode control
 14       CIR Operand Addr / FPSR    FPSR
```

**Important:** addresses 1, 4, 5, 7, 8, and 14 overlap between the two modes.
Writing to address 4 (OPB_L) while CIR mode is active will write the CIR OpWord
register instead of the operand register, and vice versa. Software must explicitly
switch modes before using the other interface.

### Mode Switching

```c
/* Switch to peripheral mode */
fpu_wr(OFF_CIR_MODE, 0);     // write 0 to address 13

/* Switch to CIR mode */
cir_wr(OFF_CIR_RESPONSE, 1); // write 1 to address 13
```

The FPU defaults to **CIR mode on reset**, matching real MC68881 behaviour. The
`fpu_probe()` function and `fpu_exec()`/`fpu_exec_unary()` automatically disable
CIR mode before accessing peripheral registers. The `cir_cpgen_*()` functions
automatically re-enable CIR mode before starting a dialog.

## Peripheral Mode

Peripheral mode provides direct register access -- no state machine, no handshaking.
Any host CPU (ARM, RISC-V, soft-core) can drive the FPU as a simple compute
accelerator over AXI-Lite.

### Protocol

```c
#include "fpu_periph.h"

// Ensure peripheral mode
fpu_wr(OFF_CIR_MODE, 0);

// --- Binary operation: FADD 3.7 + 2.4 ---

// 1. Load operands (FP80: exponent, significand high, significand low)
fp80_t a = FP80(0x4000, 0xECCCCCCC, 0xCCCCCCCD);  // 3.7
fp80_t b = FP80(0x4000, 0x99999999, 0x9999999A);  // 2.4
fpu_load_opa(a);
fpu_load_opb(b);

// 2. Trigger operation (OPSEL write starts execution immediately)
fpu_wr(OFF_OPSEL, OPSEL(FPOP_ADD));

// 3. Poll for completion
while (!(fpu_rd(OFF_STATUS) & STATUS_VALID)) { /* spin */ }

// 4. Read result
fp80_t result = fpu_read_res();
// result ≈ 6.1 = FP80(0x4001, 0xC3333333, 0x33333334)


// --- Unary operation: FSQRT(9) ---

fp80_t nine = FP80(0x4002, 0x90000000, 0x00000000);
fpu_load_opa(nine);                     // only OPA needed for unary ops
fpu_wr(OFF_OPSEL, OPSEL(FPOP_SQRT));
while (!(fpu_rd(OFF_STATUS) & STATUS_VALID)) { }
fp80_t root = fpu_read_res();
// root = 3.0 = FP80(0x4000, 0xC0000000, 0x00000000)
```

### Key Characteristics
- **No command/response polling loop** -- just write operands, trigger, poll status, read result
- **No coprocessor protocol overhead** -- one OPSEL write starts execution
- **Any host CPU** can drive the FPU -- not just 68K
- **CIR is optional** -- the CIR logic can be removed and the FPU core remains fully
  usable as a peripheral-mode compute engine (controlled by `cir_mode_reg`, address 13)
- Operand A (`a_in`) goes to OPA registers; Operand B (`b_in`) goes to OPB registers
- For unary/monadic ops (SQRT, SIN, ABS, NEG, etc.), only OPA is used
- For FMOVECR, the constant ROM offset goes in OPA_L and MOVE_CFG selects the mode

## CIR Dialog Protocol (AN-947)

CIR mode implements the authentic MC68881 coprocessor interface. A real M68020/M68030
CPU communicates with the MC68881 through exactly this command/response/operand
dialog. The protocol is a stateful exchange:

1. Host writes **Command** word (operation, source format, destination register)
2. Host writes **OpWord** (instruction type -- cpGEN, cpBcc, cpScc, etc.)
3. FPU responds with a **Response primitive** (transfer request, null release, exception)
4. Host follows the response (write operand data, read result data, acknowledge)
5. FPU issues **Null** response when the dialog is complete

### Protocol Example: FMOVE.L #42, FP0

```c
#include "cir_periph.h"

// CIR mode is default-on after reset; re-enable if peripheral ops ran
cir_wr(OFF_CIR_RESPONSE, 1);

// Build command word: mem-to-reg, Long format, dst=FP0, opcode=MOVE
u16 cmd = CIR_CMD_MEM2REG(CIR_FMT_LONG, /*dst=*/0, FPOP_MOVE);

// Step 1-2: Write Command then OpWord (OpWord write triggers FSM)
cir_wr(OFF_CIR_COMMAND, (u32)cmd);
cir_wr(OFF_CIR_OPWORD,  CIR_OPWORD_CPGEN);

// Step 3: Poll for XFER_TO_CP response (FPU wants operand data)
u16 resp = cir_poll_response();
// resp = 0x7004 → "Transfer to coprocessor, 4 bytes"

// Step 4: Write the operand (integer 42)
cir_wr(OFF_CIR_OPERAND, 42);

// Step 5: Poll for NULL release (operation complete)
cir_wait_null();
// FP0 now contains 42.0
```

### Protocol Example: FSQRT.L #9, FP3

```c
// Command: mem-to-reg, Long format, dst=FP3, opcode=SQRT
u16 cmd = CIR_CMD_MEM2REG(CIR_FMT_LONG, /*dst=*/3, FPOP_SQRT);

cir_wr(OFF_CIR_RESPONSE, 1);   // ensure CIR mode
cir_wr(OFF_CIR_COMMAND, (u32)cmd);
cir_wr(OFF_CIR_OPWORD,  CIR_OPWORD_CPGEN);

u16 resp = cir_poll_response(); // → 0x7004 (XFER_TO_CP, 4 bytes)
cir_wr(OFF_CIR_OPERAND, 9);    // write source operand

cir_wait_null();                // FP3 = 3.0
```

### Protocol Example: Read back FP3 as extended

```c
// Command: reg-to-mem, Extended format, src=FP3
u16 cmd = CIR_CMD_REG2MEM(CIR_FMT_EXTENDED, /*src=*/3, FPOP_MOVE);

cir_wr(OFF_CIR_RESPONSE, 1);
cir_wr(OFF_CIR_COMMAND, (u32)cmd);
cir_wr(OFF_CIR_OPWORD,  CIR_OPWORD_CPGEN);

u16 resp = cir_poll_response(); // → 0x600C (XFER_FROM_CP, 12 bytes)

u32 words[3];
words[0] = cir_rd(OFF_CIR_OPERAND);  // sign + exponent
words[1] = cir_rd(OFF_CIR_OPERAND);  // significand high
words[2] = cir_rd(OFF_CIR_OPERAND);  // significand low
// words = {0x4000, 0xC0000000, 0x00000000} = 3.0

cir_wait_null();
```

### CIR Response Primitives

| Code     | Meaning | Action |
|----------|---------|--------|
| `0x0000` | Busy    | Keep polling |
| `0x2001` | Null    | Dialog complete, release bus |
| `0x7004` | Transfer to CP, 4 bytes  | Write 1 long word to CIR Operand |
| `0x7008` | Transfer to CP, 8 bytes  | Write 2 long words |
| `0x700C` | Transfer to CP, 12 bytes | Write 3 long words (extended) |
| `0x6004` | Transfer from CP, 4 bytes  | Read 1 long word from CIR Operand |
| `0x6008` | Transfer from CP, 8 bytes  | Read 2 long words |
| `0x600C` | Transfer from CP, 12 bytes | Read 3 long words (extended) |

### Key Characteristics
- **Faithful AN-947 protocol** -- same dialog a real M68020 uses with a real MC68881
- **Internal FP register file** -- the FPU maintains FP0-FP7 internally; the host
  never sees raw FP80 values unless it explicitly reads them back via FMOVE
- **Format conversion in hardware** -- single, double, long, word, byte, extended,
  and packed decimal are all converted by the FPU, not the host
- **Multi-instruction sessions** -- CIR mode persists; consecutive dialogs reuse
  results in FP registers without readback

## Comparison: When to Use Which Mode

| | Peripheral Mode | CIR Dialog Mode |
|---|---|---|
| **Use case** | Any host CPU as FPU accelerator | Real M68K coprocessor protocol |
| **Host CPU** | ARM, RISC-V, soft-core, anything | M68020/030 (or emulator) |
| **Format conversion** | Host converts to FP80 in software | FPU converts all formats in hardware |
| **FP register file** | Not used; host manages results | FPU maintains FP0-FP7 internally |
| **Operand transfer** | 3 AXI writes per operand (L/H/E) | 1-3 words via CIR Operand register |
| **Triggering** | OPSEL write starts immediately | OpWord write triggers FSM dialog |
| **Completion** | Poll STATUS bit 0 | Poll CIR Response for Null |
| **Complexity** | Simple | Stateful protocol |
| **Mode switch** | `fpu_wr(OFF_CIR_MODE, 0)` | `cir_wr(OFF_CIR_RESPONSE, 1)` |

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
+-- CIR dialog driver (cir_periph.c)
|   +-- Writes Command + OpWord to start dialog
|   +-- Polls CIR Response for transfer/null primitives
|   +-- Transfers operand words via CIR Operand register
|   +-- Uses FPU's internal FP register file (FP0-FP7)
|
+-- AXI-Lite @ 0x80000000
         |
    mc68881_axilite_wrapper -> FPU core
    (peripheral mode or CIR mode, selected by addr 13)
```

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

--- CIR dialog protocol test ---
PASS CIR.1 FMOVE.L round-trip (42)
PASS CIR.2 FADD.S mem (42+3.7)
PASS CIR.3 FADD reg-to-reg (FP1+FP0=46)
PASS CIR.4 FMUL.S (3.7f*2.4f~8.88)
PASS CIR.5 FSQRT(9)=3 exact
PASS CIR.6 FSIN(1)
PASS CIR.7 FMOVE.X extended round-trip (pi)
--- CIR: 7 passed, 0 failed ---

--- Basic FPU integration test (Musashi + F-line) ---
PASS FMOVECR(pi)->FP0
PASS FADD pi+1->FP1
PASS FMUL 3.7*2.4->FP3
PASS FSIN(1.0)->FP1
PASS FSQRT(9)->FP5
--- 5 passed, 0 failed ---

ALL TESTS PASSED (19/19)
```

## ROM Boot Mode

The default build (`ROM_BOOT_MODE`, no defines needed) boots a 68000 BIOS ROM under
Musashi emulation with DisplayPort text output and MFP serial emulation. The BIOS
provides an interactive monitor with a built-in assembler (CODE68K) and disassembler
(DCODE68K) that support the full MC68881 FPU instruction set.

### BIOS Features

- **Interactive monitor** -- command prompt with memory inspect/modify, register
  display, up to 8 software breakpoints with pass counts, single-step trace,
  and debug-aware Go with RTE-based execution.
  See the [BIOS User Guide](../../../docs/merlin2_bios.md) for full details
- **68000 assembler (CODE68K)** -- table-driven, handles all standard 68000
  instructions plus 39 FPU arithmetic/transcendental mnemonics and 32 FBcc
  branch conditions. Supports all format suffixes: `.B`, `.W`, `.L`, `.S`,
  `.D`, `.X`, `.P`
- **68000 disassembler (DCODE68K)** -- decodes F-line opcodes including FPU
  arithmetic, FMOVECR, FMOVE to/from control registers, FMOVE to memory,
  and FBcc branches with all 32 condition codes
- **MFP emulation** -- MC68901 USART emulation maps ARM UART RX/TX to the
  BIOS character I/O, enabling keyboard input and serial output
- **DisplayPort text output** -- 80x30 character text framebuffer rendered
  to 1280x720@60Hz ARGB8888 via PS DisplayPort TX + DPDMA

### Memory Map

| Address | Size | Description |
|---------|------|-------------|
| `$000000-$00FFFF` | 64K | RAM (workspace, stack) |
| `$FD0000-$FD003F` | 64 bytes | MC68901 MFP (emulated) |
| `$FE0000-$FFFFFF` | 128K | ROM (BIOS image) |

### Building the ROM

The BIOS source is in `src/roms/bios.s` (68000 assembly, Motorola syntax).
Assemble with vasm and convert to a C header:

```bash
cd src/vitis/roms
vasmm68k_mot -Fbin -o bios.bin bios.s
```

The binary output spans the full address range (0x402 to ROM end). Extract just the
ROM section and generate the C header:

```python
python -c "
data = open('bios.bin','rb').read()
rom = data[0xFE0000 - 0x402:]  # ROM at address 0xFE0000, file starts at 0x402
open('bios_rom.bin','wb').write(rom)
"
xxd -i bios_rom.bin > rom_image_raw.h
```

Then adapt the output to match `rom_image.h` format (`rom_image_data[]` /
`rom_image_size` naming, `uint8_t` type).

### FPU Instruction Flow (ROM Boot)

When M68K code assembled by CODE68K executes an FPU instruction:

1. CODE68K encodes the F-line opword (`$F200` + EA) and command word
2. Musashi encounters the `$Fxxx` opcode and calls `fline_illg_callback()`
3. The F-line handler decodes the command word, fetches operands from
   emulated memory, and drives the hardware FPU via AXI-Lite
4. Results are stored in the software FP register file (`fp_regs[0-7]`)

### Build Mode Selection

- **ROM boot** (default): Define `ROM_BOOT_MODE` or leave undefined
- **Test suite**: Define `TEST_MODE` to run the original validation tests

## Building (Vitis 2025.2)

The project is a standard Vitis embedded application targeting the ZU3EG platform.

**Source files compiled** (configured in `UserConfig.cmake`):

| File | Purpose |
|------|---------|
| `main.c` | Entry point |
| `fpu_periph.c` | FPU peripheral-mode driver |
| `cir_periph.c` | CIR dialog protocol driver |
| `fp_regfile.c` | Software FP80 register file |
| `fline_handler.c` | F-line instruction decode |
| `emu_memory.c` | 16 MB emulated M68K RAM |
| `musashi/m68kcpu.c` | Musashi M68000 core |
| `musashi/m68kops.c` | Generated opcode handlers |
| `musashi/softfloat/softfloat.c` | SoftFloat (required by Musashi types) |
| `tests/periph_smoke.c` | Direct FPU peripheral driver test |
| `tests/basic_fpu.c` | Musashi + F-line integration test |
| `tests/cir_dialog.c` | CIR dialog protocol test |
| `platform.c` | Vitis BSP platform init |
| `dp_video.c` | PS DisplayPort TX + DPDMA output driver |
| `text_fb.c` | 80x30 text framebuffer (8x16 font, ARGB8888) |
| `mfp_emu.c` | MC68901 MFP USART emulation |

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
