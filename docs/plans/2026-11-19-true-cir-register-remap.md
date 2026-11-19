# Plan: remap the CIR register file to the MC68881 datasheet map

Status: proposed (not started). Follow-up to issues #72 / #74 and `DEF-BUS-001` in
`docs/archive/fpu-progress-checklist.md`.

## Why

The 8-bit byte-lane adapter added for #74 (`bl_geometry` in `src/mc68881_top.vhd`) can only be
datasheet-exact for the CIR registers that already sit at their Table 9-1 codes.  Three
registers do not, and the legacy map shares the same 5-bit `a_in` space:

| Register          | Datasheet offset | Datasheet code (A4..A1) | Current code | Status |
|-------------------|------------------|-------------------------|--------------|--------|
| Response (R)      | `$00`            | 0                       | 13 (`ADDR_CIR_RESPONSE`) | wrong |
| Control (W)       | `$02`            | 1                       | 1            | ok |
| Save (R)          | `$04`            | 2                       | 12 (`ADDR_CIR_SAVE`)     | wrong |
| Restore (R/W)     | `$06`            | 3                       | 28 (`ADDR_CIR_RESTORE`)  | wrong |
| Operation word (W)| `$08`            | 4                       | 4            | ok |
| Command (W)       | `$0A`            | 5                       | 5            | ok |
| Condition (W)     | `$0E`            | 7                       | 7            | ok |
| Operand (R/W)     | `$10`            | 8                       | 8            | ok |
| Register select   | `$14`            | 10                      | 10 (also `ADDR_STATUS`) | ok, aliased |
| Instruction addr  | `$18`            | 12                      | 12 (also Save)  | collides |
| Operand addr      | `$1C`            | 14                      | 14 (also FPSR)  | ok, aliased |

Consequences today:

- Instruction Address and Save share code 12, and Response (13) aliases the upper half of
  Instruction Address.  An 8-bit host cannot write Instruction Address.
- Code 10 is both Register Select and the legacy `ADDR_STATUS` poll register.
- The mode-switch back door (write to code 13) means a real host that writes bytes `$1A/$1B`
  of Instruction Address would flip `cir_mode_reg`.
- DSACK A4 had to be derived as `a_in(3) or a_in(4)` to cover both maps.

## Other datasheet deviations to fix in the same effort

These are data-placement conventions inside the core, separate from the register codes:

- 16-bit CIRs (Response, Command, Condition, ...) are low-aligned in `d_in`/`d_out` bits 15:0;
  the datasheet puts them on D31-D16 (UM 10.1.1 / 10.1.2).
- Extended operand word 0 carries sign+exponent in bits 15:0; the datasheet transfers bits
  95:64 on D31:D0 with the exponent in the upper half.
- Byte/word immediates and destinations are low-aligned in the core; the datasheet
  left-aligns them (D31-D24 / D31-D16).  The 8-bit adapter already presents them as single
  left-lane beats, so only the 16/32-bit port paths are affected.
- 16-bit port: the core repeats the whole 32-bit value per beat; the datasheet steers D31-D16
  or D15-D0 by A4 and A1.

## Target

CIR mode (`cir_mode_reg = '1'`) decodes exactly Table 9-1 on `a_in(3 downto 0) = A4..A1`
(plus `a0_in` for byte lanes).  The legacy memory-mapped map stays available only in
peripheral mode (`cir_mode_reg = '0'`) and is not decoded at all in CIR mode.

## Steps

1. Audit.  List every consumer of the current codes: `tb/` (cir_dialog, cir_interrupt, top,
   fmovecr, fmove_fmovem, fsave, op_class_dispatch, cycle_counts_top, timeout, axilite,
   wishbone), `wrappers/`, `validation/hello_world/src` and `validation/NeXT-68040/src`
   (`cir_periph.h` `OFF_CIR_*`, `fline_handler.c`, `emu_memory.c`), `toolchain/examples/cirtest.c`,
   `README.md`, `verilog/`.
2. Land the remap behind a generic `datasheet_cir_map_g : boolean := false` so each consumer
   can migrate independently.  When true: Response read at code 0, Save read at code 2,
   Restore at code 3, Instruction Address at 12 with no Save alias, and the mode-switch back
   door becomes a write to code 0 (a write to the Response CIR is reserved on real silicon, so
   it cannot collide with a real access).
3. Replace the `ADDR_STATUS` poll in CIR mode.  Software that polls code 10 for `STATUS`
   (`STATUS_CIR_PENDING` in `cir_periph.h`) moves to polling Response (code 0), which is what
   a real host does.
4. Gate all legacy decodes on `cir_mode_reg = '0'` and delete the aliasing special cases
   (`Gate on cir_mode_reg` comments in `cir_write_proc`).
5. Collapse `bl_geometry` to the pure Table 9-1 geometry: 16-bit CIRs for codes 0..7, 32-bit
   CIRs for 8..15, no state/direction special cases for codes 12/13/28.  Drop the
   "Instruction Address unsupported in 8-bit mode" limitation.
6. Wrappers: the AXI-Lite/Wishbone wrappers map byte address bits [6:2] to `a_in`, so software
   uses word-stride offsets (`OFF_CIR_COMMAND = 5*4`).  Decide between (a) keeping that
   word-stride aperture for CIR mode and translating in the wrapper, or (b) a datasheet byte
   aperture using `wstrb` for 16-bit/byte accesses.  (a) is the lower-risk first step.
7. Data placement (separate PR): high-aligned 16-bit CIRs, extended word 0, and D31-D16 /
   D15-D0 steering for the 16-bit port, with matching changes in the software above.
8. Set the generic default to true, migrate `validation/` software, then remove the generic.

## Tests

- `tb_mc68881_cir_dialog`: run the whole dialog suite with the generic on, for the 8-, 16-
  and 32-bit ports, with distinct bytes per beat (TESTS 15-16D already do this for 8/16 bit).
- New: Instruction Address and Operand Address host writes through 8-bit, 16-bit and 32-bit
  ports (currently impossible for Instruction Address on the 8-bit port).
- New: a write to code 0 flips `cir_mode_reg`; a read at code 0 returns the Response and
  clears `cir_response_pending`.
- Existing legacy-mode tests keep passing unchanged with `cir_mode_reg = '0'`.
- Vivado (non-incremental, 50 MHz): WNS/TNS no worse than the current baseline in `agents.md`.

## Risks

- Every software consumer in `validation/` hard-codes the current offsets; those are the
  NeXT emulator's FPU path, so migrate behind the generic and test on the emulator before
  flipping the default.
- Peripheral-mode applications (Atari SFP004 style, `DEF-CIR-002`) depend on the legacy map
  and on the code-13 mode switch; keep them working with the generic off.
- Vivado timing: the lane steering already sits in front of `d_in_i` and `d_out`, so a
  re-run is needed once the decode changes.

## Exit criteria

- All CIR registers decode at their Table 9-1 codes in CIR mode; no register aliases another.
- 8-bit host can read and write every CIR, including Instruction Address, byte by byte.
- `DEF-BUS-001` open items closed; the checklist entry updated with the Vivado numbers.
