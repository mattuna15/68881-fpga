# Section 7 Coprocessor Interface Design

Date: 2026-03-03
Status: Approved

## Goal

Replace the current custom register-mapped host interface (OPSEL/OPA/OPB/RES/STATUS)
with the standard MC68020 Coprocessor Interface Register (CIR) dialog protocol. This
enables the FPU to work as a true coprocessor on the M68020/M68030 bus and as an
AN-947-style peripheral on the M68000 (software driver performs the same CIR accesses).

## Decisions

- **Approach**: CIR address decoder overlay on the existing internal engine. The ALU,
  trig, divrem, modrem_post, packed_decimal units are unchanged. Only the bus-facing
  protocol changes.
- **Interface mode**: CIR-only. The custom register-mapped interface is removed entirely.
  Testbenches are rewritten to speak the CIR dialog protocol.
- **FSAVE frames**: Full Null (0 bytes), Idle (24 bytes), and Busy (180 bytes) frames.
  Busy frame captures mid-computation micro-state from all sub-units.
- **Concurrency**: Single-instruction-in-flight (MC68881 behavior). MC68882 concurrent
  execution is out of scope but the dialog FSM is designed to allow future extension.
- **Implementation order**: Follow existing S7 checklist phases 1-5.

## CIR Register Map

The M68020 accesses CIR registers at word offsets $00-$1C in CPU space. These map
to the existing 5-bit address bus (a_in = A[4:1]):

| Offset | CIR Register         | Width | R/W | 5-bit Addr |
|--------|----------------------|-------|-----|------------|
| $00    | Response             | 16    | R   | 0          |
| $02    | Control              | 16    | W   | 1          |
| $04    | Save                 | 16    | R/W | 2          |
| $06    | Restore              | 16    | R/W | 3          |
| $08    | Operation Word       | 16    | W   | 4          |
| $0A    | Command              | 16    | W   | 5          |
| $0C    | (reserved)           | --    | --  | 6          |
| $0E    | Condition            | 16    | W   | 7          |
| $10    | Operand              | 32    | R/W | 8          |
| $14    | Register Select      | 16    | R   | 10         |
| $18    | Instruction Address  | 32    | W   | 12         |
| $1C    | Operand Address      | 32    | R   | 14         |

## Dialog State Machine

### Response Primitive Encoding

Bits [15:13] of the Response CIR encode the primitive category:

| Bits 15-13 | Category                       |
|------------|--------------------------------|
| 000        | Busy                           |
| 001        | Null (done)                    |
| 010        | Supervisor Check               |
| 011        | Transfer / Evaluate EA         |
| 100        | Write-back                     |
| 101        | Take Pre-Instruction Exception |
| 110        | Take Mid-Instruction Exception |
| 111        | Take Post-Instruction Exception|

### FSM States

```
cir_dialog_state_t:
  CIR_IDLE             -- No active dialog. Response = Null.
  CIR_DECODE           -- OpWord+Command received, decoding instruction type.
  CIR_XFER_SRC         -- Requesting source operand from host via Operand CIR.
  CIR_XFER_SRC_WAIT    -- Waiting for host to complete operand write(s).
  CIR_EXECUTE          -- ALU/trig/div running. Response = Busy.
  CIR_XFER_DST         -- Requesting host to read result via Operand CIR.
  CIR_XFER_DST_WAIT    -- Waiting for host to complete result read(s).
  CIR_COND_EVAL        -- Conditional instruction evaluated.
  CIR_EXCEPT_PRE       -- Pre-instruction exception pending.
  CIR_EXCEPT_MID       -- Mid-instruction exception pending.
  CIR_EXCEPT_POST      -- Post-instruction exception pending.
  CIR_SAVE_FORMAT      -- FSAVE: format word ready for host read.
  CIR_SAVE_FRAME       -- FSAVE: streaming state frame via Operand CIR.
  CIR_RESTORE_FORMAT   -- FRESTORE: waiting for format word from host.
  CIR_RESTORE_FRAME    -- FRESTORE: receiving state frame via Operand CIR.
```

### Dialog Flows

**cpGEN with memory source** (e.g. FADD.S <ea>,FP0):
1. Host writes OpWord ($08), Command ($0A)
2. FSM decodes: need N-word source operand
3. Response = Transfer Operand primitive ($68xx, byte count)
4. Host writes N longwords to Operand CIR ($10)
5. FSM converts format, launches ALU. Response = Busy ($0000)
6. ALU completes. Response = Null ($2001)

**cpGEN register-to-register** (e.g. FADD FP1,FP0):
1. Host writes OpWord ($08), Command ($0A)
2. FSM decodes: source = FPn, no transfer needed
3. FSM reads source from fp_reg_file, launches ALU. Response = Busy
4. ALU completes. Response = Null

**cpBcc/cpScc/cpDBcc/cpTRAPcc**:
1. Host writes OpWord ($08), Condition ($0E)
2. FSM evaluates FPSR CC bits via eval_fcc_condition
3. Response = Null (condition false) or Post-Instruction Exception (branch/trap)

**cpSAVE**:
1. Host writes to Save CIR ($04)
2. FPU freezes state, determines frame type (Null/Idle/Busy)
3. Host reads Save CIR → gets format word ($0000/$0018/$00B4)
4. Host reads N longwords from Operand CIR ($10) for frame body
5. Response = Null when complete

**cpRESTORE**:
1. Host writes format word to Restore CIR ($06)
2. FPU validates format word
3. If valid: host writes N longwords to Operand CIR for frame body
4. FPU commits restored state. Response = Null.
5. If invalid: Response = Pre-Instruction Exception

## Instruction Decode

### Operation Word ($08) — Type Field [8:6]

| Type | Instruction                  | Dialog Family   |
|------|------------------------------|-----------------|
| 000  | cpGEN (arithmetic/move)      | General         |
| 001  | cpScc, cpDBcc, cpTRAPcc      | Conditional     |
| 010  | cpBcc (.W displacement)      | Conditional     |
| 011  | cpBcc (.L displacement)      | Conditional     |
| 100  | cpSAVE                       | Context Save    |
| 101  | cpRESTORE                    | Context Restore |

### Command Word ($0A) — Source Format [12:10]

| Src | Format         | Operand Words |
|-----|----------------|---------------|
| 000 | Long Integer   | 1             |
| 001 | Single         | 1             |
| 010 | Extended       | 3             |
| 011 | Packed Decimal | 3             |
| 100 | Word Integer   | 1             |
| 101 | Double         | 2             |
| 110 | Byte Integer   | 1             |
| 111 | FPn (register) | 0             |

Command word bits [6:0] map to the existing fpu_op_t enum.
Bits [9:7] = destination FP register. Bit [14] = reg-to-reg vs memory-to-reg.

## Operand Transfer Protocol

Source operand transfer uses the "Evaluate EA and Transfer Data" response primitive:
- Bits [15:13] = 011, bit [12] = 1 (to coprocessor), bits [7:0] = byte count
- Internal xfer_word_index counter auto-increments on each Operand CIR write
- Word packing follows M68020 memory order (MSW first)

Destination operand transfer (FMOVE reg→mem) uses transfer-from-CP primitive:
- Same encoding with bit [12] = 0 (from coprocessor)
- Host reads N longwords from Operand CIR

FMOVEM uses Register Select CIR ($14) to communicate the register list mask,
then multiple 3-word transfers via Operand CIR for each FP register.

## Exception Dialog Paths

### Pre-Instruction (Response $Axxx)
- Invalid OpWord type, unrecognized opcode, privilege violation
- Detected during CIR_DECODE, no internal state modified
- Vector encoded in bits [9:0]

### Mid-Instruction (Response $Cxxx)
- FPCR-enabled arithmetic exception during execution (OVFL, UNFL, DZ, etc.)
- Internal state modified — host must FSAVE before handling
- Detected when exc_status_proc fires and FPCR enable bit is set

### Post-Instruction (Response $Exxx)
- BSUN, FTRAPcc condition true, enabled INEX after completion
- Result committed to FP register file
- Uses existing cir_trap_pending_reg / exc_event_force_bsun_reg paths

### Control CIR ($02)
- Host writes exception-acknowledge bit after processing exception
- Clears exception state, dialog returns to CIR_IDLE

### FPIAR Capture
- Pre-instruction: captured at Instruction Address CIR write
- Mid/Post-instruction: captured at instruction start (fpiar_issue_snapshot_reg)

## FSAVE/FRESTORE State Frames

### Frame Types

| FPU State | Format Word | Frame Size  |
|-----------|-------------|-------------|
| Null      | $0000       | 0 bytes     |
| Idle      | $0018       | 24 bytes    |
| Busy      | $00B4       | 180 bytes   |

### Idle Frame (24 bytes = 6 longwords)
Non-architectural internal state only (FPCR/FPSR/FPIAR are architectural,
saved separately by FMOVEM.CR):
- Frame version + internal flags
- Last operation descriptor
- Pending exception state
- Microsequencer state
- CIR dialog state
- Reserved

### Busy Frame (180 bytes = 45 longwords)
Full mid-computation micro-state:
- Words 0-5: Idle frame fields
- Words 6-7: ALU control state (op_sel, staging)
- Words 8-11: Operand A + B (80-bit each)
- Words 12-20: Trig unit state (FSM enum, working regs, FP sub-unit pipeline)
- Words 21-26: Divrem unit state (FSM enum, iteration, partial quotient, mantissa)
- Words 27-29: Modrem post-unit state
- Words 30-32: Packed decimal unit state
- Words 33-37: Shared FP mul/add unit pipeline state
- Words 38-44: Reserved / padding

### Save/Restore Sub-Unit Interface
Each computation unit gets:
```vhdl
save_req     : in  std_logic;
save_data    : out std_logic_vector(31 downto 0);
save_addr    : in  natural range 0 to N;
save_busy    : out std_logic;
restore_req  : in  std_logic;
restore_data : in  std_logic_vector(31 downto 0);
restore_addr : in  natural range 0 to N;
restore_wr   : in  std_logic;
```

## Files Changed

| File                              | Change Type                        |
|-----------------------------------|------------------------------------|
| src/mc68881_pkg.vhd               | Add CIR types, constants, frames   |
| src/mc68881_top.vhd               | Replace bus interface with CIR FSM |
| src/mc68881_alu.vhd               | Add save/restore ports             |
| src/mc68881_trig_unit.vhd         | Add save/restore ports             |
| src/mc68881_divrem_unit.vhd       | Add save/restore ports             |
| src/mc68881_modrem_post_unit.vhd  | Add save/restore ports             |
| src/mc68881_packed_decimal_unit.vhd | Add save/restore ports           |
| tb/tb_mc68881_top.vhd             | Rewrite for CIR dialog protocol    |
| tb/tb_mc68881_alu.vhd             | No change (direct ALU interface)   |

## What Stays the Same

- ALU entity and all computation sub-units (internal logic unchanged)
- FP register file (8 x 80-bit)
- FPCR/FPSR/FPIAR internal representation
- Exception classification (exc_status_proc)
- Microsequencer (cycle counting)
- DSACK state machine (bus handshake)
- mc68881_pkg.vhd op descriptors, exception policies, FP types
