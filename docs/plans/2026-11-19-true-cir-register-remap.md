# Plan: remap the CIR register file to the MC68881 datasheet map

Status: Steps 1-5 implemented behind `datasheet_cir_map_g` (default false, 2026-11-27);
Step 6 done with option (a) (2026-11-27); Step 7 done (2026-11-27); Step 8 open.  Follow-up to issues #72 / #74 and
`DEF-BUS-001` in `docs/archive/fpu-progress-checklist.md`.  Coverage:
`tb/tb_mc68881_cir_datasheet_map.vhd` (core), `tb/tb_mc68881_wrapper_datasheet.vhd` (wrappers).

Implementation notes (Steps 2-5):
- `ds_translate` in `mc68881_top.vhd` maps each Table 9-1 code (A4..A1, per direction) onto
  the internal handler that already implements it; reserved codes (6, 11), wrong-direction
  accesses decode to nothing.  The odd halves of 32-bit CIRs (9, 13, 15) fold onto their
  32-bit CIR on 8- and 16-bit ports (Step 7) and decode to nothing on the 32-bit port.
  `a_in(4)` is ignored, so the 16 codes alias.  Peripheral mode is unchanged.
- Register Select (code 10) is a 16-bit CIR, so `bl_geometry` uses 2 bytes for codes 0..7 and
  10..11 and 4 bytes for 8..9 and 12..15 (Step 5's "8..15 are 32-bit" is corrected here).
- Operand Address (code 14) is a real read/write register.  DSACK A4 is `a_in(3)`.
- The decode mode (`cir_mode_dec`) is frozen for the whole bus cycle.  Without that, the
  mode-switch write changed the map mid-cycle: a write to code 0 issued a legacy OPSEL
  launch, and an 8-bit return write folded onto Instruction Address and overwrote FPIAR.
- Step 3: STATUS cannot be reached in datasheet CIR mode; moving `cir_periph.h` over is Step 8.
- Step 4: no new gate was needed, because `cir_active` already blocks the back-door operand/FPSR
  writes in CIR mode.  The `cir_mode_reg` special cases stay until Step 8 removes the generic.

Implementation notes (Step 6, option (a)):
- Both wrappers take `datasheet_cir_map_g` and pass it to both core instantiations (68881 and
  68882).  The word-stride aperture stays: bus byte address bits [6:2] are the register code.
- No translation is needed in the wrapper.  The bridge already passes the code straight to
  `a_in` and runs 32-bit cycles, and the core does the Table 9-1 decode.  So with the generic on,
  CIR code n is at byte offset n*4: Response $00, Control $04, Save $08, Restore $0C,
  Operation Word $10, Command $14, Condition $1C, Operand $20, Register Select $28,
  Instruction Address $30, Operand Address $38.  Offsets $40-$7C alias $00-$3C in CIR mode.
- Software that moves to the generic changes only its `OFF_CIR_*` codes (Step 8): Response
  13 -> 0, Save 12 -> 2, Restore 28 -> 3, and the mode switch becomes a write to $00.  The
  others keep their codes.  Control (1) and Register Select (10) gain offsets; `cir_periph.h`
  does not define them today.
- Option (b), a datasheet byte aperture ($00-$1E with 16-bit accesses through `wstrb`/`wb_sel`),
  depends on Step 7's data placement and stays open as a later option.
- The wrapper testbenches (`tb_mc68881_axilite`, `tb_mc68881_wishbone`, `tb_mc68881_timeout`)
  were not in the regression lists.  They now run alongside the new one in
  `scripts/run_tests.ps1`, `.githooks/pre-push` and CI.

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

Implementation notes (Step 7):
- The datasheet map uses the same generic for data placement.  With it on, the port adapter in
  `mc68881_top.vhd` (`bl_*`) is active for every port width in CIR mode, not just 8-bit.
  Each beat moves `bl_c` bytes: the whole item on a 32-bit port, 16-bit units on a 16-bit
  port, single bytes on an 8-bit port.  The core keeps its low-aligned convention, so the
  adapter does all the steering and the core strobe still fires only on the item's last beat.
- 32-bit port: 16-bit CIRs and word immediates on D31-D16, byte immediates on D31-D24.  A
  Register Select read drives D15-D0 high (UM 10.1.1).  Other reads replicate the item across
  the unused lanes.
- 16-bit port: D15-D0 when A4=1 and A1=1, else D31-D16.  A 32-bit item takes two beats, A1=0
  (bits 31-16) then A1=1 (bits 15-0), most significant word first, so codes 9/13/15 now fold
  onto Operand / Instruction Address / Operand Address.  The half comes from A1, as the 8-bit
  adapter takes the byte from {A1,A0}.
- Extended operand word 0 carries sign+exponent in bits 31-16 with the low half zero, in both
  directions and for the 68882 pending source.  FSAVE/FRESTORE copy the staging words raw, so
  they stay symmetric.
- Evaluate-and-transfer primitives give byte/word memory-format operands a length of 1/2 bytes
  (the legacy map keeps counting 32-bit words).
- The byte/word item width (`bl_imm_n_reg`) is frozen while a bus access is open.  The dialog
  leaves the transfer state about two clocks after DSACK, and without the freeze a host still
  holding a byte/word destination read saw its lanes change (D31-D16 dropping to zero).  The
  legacy 8-bit path had the same exposure and shares the fix.
- Software changes are deferred to Step 8: nothing in `validation/` runs with the generic on yet.
- The 68882 pending-instruction source path is not adapted for byte/word immediates; see
  `DEF-BUS-001`.

## Other datasheet deviations to fix in the same effort

Step 7 fixes all four with the generic on; they remain with it off.

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
