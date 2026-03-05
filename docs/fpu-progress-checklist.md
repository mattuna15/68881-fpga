# FPU Progress Checklist

Master checklist for implementation progress, protocol closure, and known defects.
This consolidates content previously tracked in:
- `docs/mc68881_plan_checklist.txt`
- `docs/defect_checklist.md`
- `docs/section7_coprocessor_interface_checklist.md`

## Implementation Plan

MC68881 VHDL-2008 Implementation Plan (Checklist)
=================================================

Scope: Full 80-bit extended-precision MC68881-compatible FPU for M68000 bus.
Target: Xilinx Artix-7 (100T/200T), DSP-pipelined datapath, cycle counts per datasheet.

Legend:
[ ] Not started
[~] In progress
[x] Done

A) Design Quality Improvements (from review)
--------------------------------------------
[x] A1. Replace magic numbers in mc68881_top with package constants for field widths.
    - Define widths in mc68881_pkg.vhd and use for result_lo/result_hi/result_ex.

[x] A2. Decompose the top-level state machine into focused processes.
    - Split bus handling, ALU control, and status management.
    - Keep cycle-count timing behavior intact.

[x] A3. Normalize signal naming conventions.
    - Choose a consistent convention for registered signals (e.g., _r or _reg).
    - Apply across top-level and ALU interface signals.

[x] A4. Expand opcode encoding space beyond 4-bit OPSEL.
    - Replace fixed 4-bit decode path with an extensible opcode namespace.
    - Keep backward compatibility for existing OPSEL values used by testbenches.

[x] A5. Introduce explicit operation classes for scalability.
    - Split execution/control paths for arithmetic, move, program-control, and system-control ops.
    - Avoid adding new opcode behavior through ad-hoc special-cases in top-level processes.

[x] A6. Centralize opcode metadata in a single descriptor table.
    - Define per-op decode ID, class, ALU latency, cycle model hook, and exception policy.
    - Remove duplicated per-op case logic across pkg/top/ALU/testbench mapping points.

[x] A7. Replace raw move_cfg bitfield usage with typed decode records.
    - Decode move mode/format/control selector/mask/order into named fields once.
    - Keep FMOVE/FMOVEM semantics unchanged while reducing bit-index coupling.

[x] A8. Refactor FPSR/FPCR exception handling to per-op policy.
    - Move exception classification from result heuristics to opcode-aware rules.
    - Prepare for full C4/C5 behavior (condition codes, accrued flags, restart/FPIAR interactions).

B) Functional Completeness (Core Missing Ops)
---------------------------------------------
[x] B1. Implement FSQRT (square root).
    - Target cycle count ~120 (per datasheet guidance).

[x] B2. Implement FMOVE/FMOVEM family per programming guide section 3.3.1.
    - Register transfer (FPR<->FPR).
    - Move to/from memory for single/double/extended precisions.
    - Move to/from control registers (FPCR/FPSR/FPIAR).
    - Done: FMOVE for integer B/W/L source formats.
    - Done: FMOVE packed-decimal (.P) with static/dynamic k-factor.
    - Done: FMOVECR constant ROM fetch (#ccc,FPn).
    - Done: FMOVEM Dn bitmask mode and -(An) bit-order rules.

[x] B3. Complete dyadic operations set (guide section 3.3.2).
    - Done: FADD, FSUB, FMUL, FDIV.
    - Done: FCMP, FMOD, FREM, FSCALE, FSGLDIV, FSGLMUL.

[x] B4. Implement monadic arithmetic/data ops (guide section 3.3.3).
    - FABS, FNEG, FINT, FINTRZ, FGETEXP, FGETMAN, FTST.
    - Keep IEEE-class behavior aligned for zero/inf/nan inputs.

[x] B5. Implement transcendental operations (guide section 3.3.3).
    - FACOS, FASIN, FATAN, FATANH, FCOS, FCOSH.
    - FETOX, FETOXM1, FLOGN, FLOGNP1, FLOG10, FLOG2.
    - FSIN, FSINCOS, FSINH, FTAN, FTANH, FTENTOX, FTWOTOX.
    - Done subset: FSIN, FCOS, FTAN, FSINCOS.
    - Done: FACOS, FASIN, FATAN, FATANH, FCOSH.
    - Done: FETOX, FETOXM1, FLOGN, FLOGNP1, FLOG10, FLOG2.
    - Done: FSINH, FTANH, FTENTOX, FTWOTOX.

[x] B6. Implement program-control instruction set (guide section 3.3.4).
    - FBcc, FDBcc, FScc, FNOP.
    - Ordered/unordered condition-code variants and NaN behavior.
    - FPU condition-code generation from FCMP/FTST results.
    - Done: core-v1 decode/class metadata and conditional execution wiring are in place for
      FScc/FBcc/FDBcc.
      FScc evaluates FPSR CC flags and returns byte true/false in result low byte.
      FBcc now reports condition/branch outcome via `ADDR_CIR_RESPONSE`.
      FDBcc now applies DBcc-style decrement/branch decision and reports updated low-word counter
      plus condition/decrement/branch flags via `ADDR_CIR_RESPONSE`.
      Signaling-condition + unordered (`NAN`) path now reports null response and raises BSUN
      in EXC/AEXC with exception-time FPIAR capture.
      Conditional-response ordering and BSUN trap-gating status are now enforced in the
      register-mapped dialog model (`STATUS`/`CIR_RESPONSE`).

[x] B7. Implement system-control instruction set (guide section 3.3.5).
    - FSAVE, FRESTORE.
    - FTRAPcc (#<data>.W/.L and no-immediate forms).
    - Done: FSAVE/FRESTORE wired through cross-process request/completion handshake
      (sys_ctrl_save_req/restore_req → bus_frame_proc frame countdown → result_ready).
    - Done: FTRAPcc evaluates FPSR CC via shared conditional path (OP_CLASS_PROG_CTRL),
      requests trap when condition true, participates in BSUN/CIR response protocol.

[x] B8. Implement packed-decimal and decimal conversion path.
    - Packed-decimal encode/decode and edge cases.
    - Rounding and k-factor handling per FMOVE .P behavior.
    - Done: FMOVE .P transports a 96-bit packed payload through the existing
      register interface (`OPA_E`/`RES_E` upper 16 bits carry packed bits 95:80;
      lower 80 bits remain in `*_H/*_L/*_E[15:0]`).
    - Done: FMOVE reg->mem packed path emits explicit packed metadata fields
      (SM/SE/YY and exponent nibbles) plus decimal mantissa digits for all
      finite sources (integer and non-integer) with static/dynamic k-factor
      rounding using round-to-nearest-even.
    - Done: FMOVE mem->reg packed path decodes all 17 BCD mantissa digits via
      FP80 arithmetic accumulation with unbounded exponent scaling (+/-9999).
      Distinguishes infinity from NaN (producing canonical QNaN for NaN inputs;
      payload preservation resolved in C2 / DEF-DIVREM-002).
    - Done: OPERR exception raised for invalid BCD nibbles (A-F) in packed
      mem->reg decode via `packed96_has_invalid_bcd` checker and
      `exc_event_force_invalid_reg` signal.
    - Done: INEX1 detection on packed reg->mem (round-trip compare mirrors
      single/double pattern, sets `move_exc_force_inexact`).
    - Done: 17-digit precision-limit inexact detection — residual check
      after digit extraction catches FP80 values with >17 significant
      decimal digits (previously only k-factor truncation was detected).
    - Done: subnormal pre-normalization — leading mantissa zeros are
      counted to correct the exp10 estimate before digit extraction,
      preventing all-zero mantissa output for subnormal inputs.
    - Done: full packed conversion moved into dedicated
      `mc68881_packed_decimal_unit` (single in-flight request, sequential
      micro-state flow, integer/BCD decode accumulation via `fp80_from_u64`,
      and bounded variable-latency completion).
    - Done: top-level default restored to full packed behavior
      (`packed_decimal_full_g=true`) with fallback path retained only for
      debug (`packed_decimal_full_g=false`) synthesis bisect builds.
    - Done: packed testbenches now run against the default configuration
      (no testbench-only generic override required to force full packed mode).
    - Done: `result_ex_hi_reg` explicitly cleared on single/double/extended
      reg->mem paths to prevent stale packed metadata leakage.
    - Done: test coverage for zero, negative (-42), infinity round-trips,
      non-integer (1.25) encode/decode round-trip, invalid BCD OPERR, and
      round-to-nearest-even (banker's rounding for exact-halfway cases).

C) Exception Handling & Edge Cases
----------------------------------
[~] C1. Add denormal handling coverage.
    - Define flush/denormal rules per MC68881 behavior.
    - In progress: subnormal input/output checks exist for sqrt/trig/trans and integer-conversion paths.

[x] C2. Improve NaN propagation details.
    - SNaN vs QNaN discrimination implemented (DEF-DIVREM-002, closed).
    - fp80_is_snan/fp80_is_qnan/fp80_quiet_nan/fp80_propagate_nan added to pkg.
    - INVALID fires only for SNaN inputs; QNaN propagates silently with payload preserved.
    - Two-NaN priority: SNaN over QNaN, destination over source for same type.
    - Divrem, sgl_ops, trig units all use payload-preserving NaN propagation.
    - Domain errors (0/0, inf/inf, sqrt(neg), trig(inf)) still produce canonical QNaN.
    - REVIEW FINDING (critical): NaN payloads destroyed. All units return canonical_qnan()
      with a fixed pattern instead of propagating the input NaN payload. Datasheet
      Section 4.5.4 requires input NaN payload preservation (with SNaN quieted by
      setting fraction MSB). Two-NaN priority (SNaN > QNaN, destination > source)
      is also missing.
    - FIXED: FPCP-generated NaN pattern corrected. canonical_qnan/canonical_nan
      now returns all-ones mantissa (0xFFFFFFFFFFFFFFFF) per datasheet.

[~] C3. Expand exception detection tests.
    - Invalid, divzero, overflow, underflow, inexact for new ops.
    - In progress: invalid/divzero coverage is exercised; overflow/underflow/inexact matrix is still incomplete.
    - REVIEW FINDING (medium): Exception granularity is 5 bits instead of 8.
      Code has INVALID, OVERFLOW, UNDERFLOW, DIVZERO, INEXACT. Datasheet defines
      BSUN, SNAN, OPERR, OVFL, UNFL, DZ, INEX2, INEX1. Missing: BSUN (for B6
      conditional instructions), SNAN vs OPERR distinction (different trap vectors
      54 vs 52), INEX1 vs INEX2 (packed decimal input inexact).
    - REVIEW FINDING (medium): Transcendental divide-by-zero not detected. FLOG(0),
      FLOG2(0), FLOG10(0) should set DZ. FATANH(+/-1) should also set DZ. These
      use EXC_POLICY_ARITH which has divzero disabled.
    - FIXED: FTAN exception policy changed from EXC_POLICY_DIV to EXC_POLICY_ARITH.
    - FIXED: FLOGN(0), FLOG10(0), FLOG2(0) now return -infinity and set DZ exception.
      Added EXC_POLICY_LOG with divzero_on_zero_input flag. Trig unit split
      zero/negative conditions to produce correct result per datasheet.
    - REMAINING: FATANH(+/-1) and FLOGNP1(-1) still return NaN instead of +-infinity
      with DZ. Requires trig unit DZ output port or per-op value comparison.

[~] C4. Complete FPCR/FPSR architectural fields.
    - FPCR exception-enable byte semantics.
    - FPSR condition code, quotient, exception status, accrued exception bytes.
    - In progress: per-op policy flow (A8) and key FPSR behavior are in place; full architectural closure remains.
    - FIXED: FPSR EXC/AEXC byte positions corrected. EXC status byte now at
      bits 15-8, Accrued byte at bits 7-0 per datasheet.
    - FIXED: EXC status byte now cleared then set per operation (Section 2.3.3).
    - FIXED: AEXC combination logic corrected per datasheet:
      AEXC(UNFL) = UNFL AND INEX; AEXC(INEX) = INEX OR OVFL.
    - REVIEW FINDING (medium): FPCR exception enable byte (bits 15-8) stored but
      never consulted. No exception trapping is implemented.
    - FIXED: fpsr_cc_from_result now sets N bit independently from sign, per
      Table 2-1. -Infinity correctly sets N=1,I=1; -Zero sets N=1,Z=1.

[~] C5. Track FPIAR behavior across exceptions and restart points.
    - Verify faulting instruction address capture and restore interactions.
    - In progress: exception-time FPIAR capture checks exist for top-level flows; restart-corner coverage remains.

D) Verification / Testbench Coverage
------------------------------------
[~] D1. Add self-checking testbenches for each newly implemented opcode.
    - Wait on DUT valid signals before checking.
    - Avoid reserved identifiers in signal/procedure arguments.
    - In progress: broad self-checking ALU/top coverage exists, including added sweep and golden-vector spot checks.

[x] D2. Log key transactions in testbenches using report (severity note).
    - Include expected vs observed values.

[x] D3. FP80 value checks must compare encoding fields.
    - Deconstruct sign/exponent/mantissa or recomposition from bus words.
    - Do not compare raw integer literals to FP80 results.

[~] D4. Cycle-count verification for all newly implemented ops.
    - Include EA timing adjustments where applicable.
    - In progress: latency checks exist for key arithmetic/trig/trans paths; full per-op closure remains.

[~] D5. Add opcode matrix coverage from programming guide sections 3.3.1-3.3.5.
    - Explicit per-op test status list to prevent silent gaps.
    - In progress: microseq/dispatch coverage is substantial for implemented classes; B6/B7 matrices remain open.

[~] D6. Add format-specific FMOVE/FMOVEM tests.
    - B/W/L/S/D/X/P data formats.
    - FMOVEM list encoding rules and Dn mask behavior.
    - In progress: major FMOVE/FMOVEM paths are covered; full format/mode closure tracking still needed.

E) Bus Interface & Timing (Confirmations)
-----------------------------------------
[x] E1. DSACK behavior per Table 10.
    - Single-shot encoding tests cover 32-bit (A4=0 and A4=1), 16-bit, 8-bit, and wait-state responses.
    - Multi-beat sequencing tests verify DSACK state machine cycles IDLE→WAIT_ASSERT→ASSERTED→IDLE
      for 2-beat (16-bit) and 4-beat (8-bit) read/write transfers with data integrity readback.
[x] E2. Address decoding for all register spaces.
[x] E3. Access size handling for 8/16/32-bit.
    - Multi-beat write+readback tests confirm correct register capture across repeated narrow bus cycles.
[x] E4. Microsequencer for cycle-accurate timing.

F) Datasheet Conformance (MC68881UM Review Findings)
-----------------------------------------------------
[x] F1. Fix NaN-to-extended conversion destroying NaN (becomes infinity).
    - FIXED: fp80_from_single and fp80_from_double now copy source fraction bits
      into extended mantissa, left-justified, preserving NaN payloads.

[x] F2. Fix format conversion rounding (fp80_to_single / fp80_to_double).
    - FIXED: `fp80_to_single` and `fp80_to_double` now apply guard/round/sticky
      rounding using the active FPCR rounding mode (RN/RZ/RM/RP).
    - FIXED: tie-to-even behavior is implemented for round-to-nearest mode.
    - Regression coverage: `tb/tb_mc68881_fmove_fmovem.vhd` now checks single
      and double halfway cases across rounding modes.

[x] F3. Add exception handling to FMOVE operations.
    - FIXED: FPU_OP_MOVE now routes conversion-complete events through the same
      exception-classification path used by ALU-valid completions.
    - FMOVE conversion paths now drive EXC/AEXC/CC/FPIAR side effects via
      op-policy metadata (`EXC_POLICY_ARITH`) instead of bypassing classification.
    - Regression coverage: `tb/tb_mc68881_fmove_fmovem.vhd` now includes a
      FMOVE single-qNaN mem->reg case that asserts FPSR invalid/AEXC invalid
      and exception-time FPIAR capture.

[x] F4. Fix format conversion overflow/underflow behavior.
    - FIXED: overflow handling in `fp80_to_single/double` now follows rounding
      mode semantics (RN -> infinity; RZ/RM/RP -> directed finite/infinity result).
    - FIXED: underflow conversion path now emits gradual-underflow subnormals
      instead of unconditional zero flush.
    - FIXED: FMOVE reg->mem exception classification preserves destination-format
      range status so directed overflow-to-max-finite and non-zero subnormal
      results still assert FPSR EXC/AEXC overflow/underflow.
    - Regression coverage: `tb/tb_mc68881_fmove_fmovem.vhd` now checks single
      and double minimum-subnormal conversion, single overflow mode behavior,
      and EXC/AEXC overflow/underflow signaling for those conversions.

[x] F5. Fix FGETEXP(infinity) and FGETMAN(infinity).
    - FIXED: Both now return NaN (all-ones mantissa) for infinity input per datasheet.

[x] F6. Fix FSCALE NaN source operand handling.
    - FIXED: FSCALE now checks for NaN source/destination before scaling.
      Returns canonical NaN when either operand is NaN.

[x] F7. Fix FMOD/FREM signed zero preservation.
    - FIXED: Zero-dividend result now preserves sign from input operand.

Notes:
- Priorities from the review: FSQRT, FMOVE/FMOVEM, FCMP/FTST first; refactor top state machine next.
- Checklist expanded using docs/68881-programming.txt (instruction groups + format/control details).
- Section 7 (coprocessor interface) closure plan is tracked in
  this checklist under "Section 7 Coprocessor Interface Closure".
- Maintain VHDL-2008 compatibility and avoid vendor-specific primitives.
- Use scripts/run_tests.ps1 for local verification (set GHDL_EXE if needed).
- For LUT/area regression checks, use non-incremental synthesis only.
- Before comparing utilization between commits, disable run-level incremental reuse:
  AUTO_INCREMENTAL_CHECKPOINT=0 and INCREMENTAL_CHECKPOINT="" on run synth_1.
- Record LUT signoff numbers from report_utilization on a clean run, and use
  report_utilization -hierarchical for hotspot ranking.

## Defect Tracking

# Defect Checklist

Track known functional defects that are intentionally not enforced as hard regressions yet.
Keep this list short, actionable, and updated whenever a defect is fixed or newly discovered.

## Open Defects

(none)

## Closed Defects

### DEF-LUT-002: Further LUT Reduction via FP Unit Sharing
- Status: Closed (2026-03-03)
- Files: `src/mc68881_alu.vhd`, `src/mc68881_divrem_unit.vhd`,
  `src/mc68881_modrem_post_unit.vhd`, `src/mc68881_packed_decimal_unit.vhd`,
  `src/mc68881_top.vhd`, `src/mc68881_trig_unit.vhd`, `src/mc68881_fp80_mul_unit.vhd`,
  `tb/tb_mc68881_alu.vhd`, `tb/tb_mc68881_known_defects.vhd`
- Description: Post-DEF-LUT-001 utilization was ~66K LUTs (49%) with 65 DSPs.
  The ALU, modrem post, and packed decimal units each had their own dedicated
  `mc68881_fp80_mul_unit` and `mc68881_fp80_addsub_unit` instances, but these
  consumers are mutually exclusive (ALU dispatches to exactly one at a time).
- Resolution summary:
  - Removed local FP mul/add instances from `mc68881_modrem_post_unit` and
    `mc68881_packed_decimal_unit`. Added shared FP operation ports instead.
  - Added passthrough FP ports to `mc68881_divrem_unit` for modrem post requests.
  - Added operand mux in `mc68881_alu` to route FP requests from ALU's own ops,
    modrem post, or packed decimal to the single shared mul/add instance pair.
  - Done/result signals broadcast to all consumers (only active consumer checks).
  - Converted `mc68881_fp80_mul_unit` from async to sync reset for DSP48E1
    pipeline register packing (A1/A2, B1/B2, P registers absorbed into DSP).
  - Updated trig unit's divrem instance and testbenches for new port signatures.
  - Result: 60,688 LUTs (45.09%), 33 DSPs (4.46%) — down from ~66K LUTs, 65 DSPs.
  - Savings: ~5,300 LUTs, 32 DSPs freed. All GHDL regression tests pass.

### DEF-LUT-001: Reduce LUT Usage via Sequential FP Unit Reuse
- Status: Closed (2026-03-03)
- Files: `src/mc68881_alu.vhd`, `src/mc68881_modrem_post_unit.vhd`,
  `src/mc68881_packed_decimal_unit.vhd`, `src/mc68881_top.xdc`
- Description: Post-synth utilization after DEF-TIMING-001 was 88,138 LUTs (65.48%).
  Three units besides trig still inlined combinational `mul_fp80` and `add_sub_fp80`,
  each creating massive LUT cones for unpack/multiply/add/normalize/round logic.
- Resolution summary:
  - Instantiated `mc68881_fp80_mul_unit` and `mc68881_fp80_addsub_unit` in ALU,
    modrem post, and packed decimal units, replacing combinational FP calls with
    start/busy/done handshake.
  - ALU: ADD/SUB/MUL now use sequential units; CMP/ABS/NEG/INT/INTRZ/GETEXP/GETMAN/TST
    remain lightweight combinational with reduced 2-cycle MCP (from 5-cycle).
  - Modrem post: ST_FP_ADD and ST_FP_MUL use sequential units; removed `mod_fp_wait_count_reg`
    and `DONT_TOUCH` attributes on result registers.
  - Packed decimal: AR_ST_WAIT mul/add commits use sequential units;
    `fp80_to_int_trunc` kept combinational with reduced 2-cycle MCP.
  - XDC: Removed old 5-cycle MCP constraints for ALU simple ops, packed mul/add,
    and modpost add/mul. Replaced with 2-cycle MCPs for remaining lightweight paths.
  - Result: ~66K LUTs (49%), 65 DSPs — down from 88,138 LUTs (65.48%).

### DEF-TIMING-001: Trig FP Engine Uses MCP-Guarded Combinational FP80 Datapaths
- Status: Closed (2026-03-02)
- Files: `src/mc68881_fp80_mul_unit.vhd` (new), `src/mc68881_fp80_addsub_unit.vhd` (new),
  `src/mc68881_trig_unit.vhd`, `src/mc68881_top.xdc`
- Resolution summary:
  - Created sequential `mc68881_fp80_mul_unit` (4-cycle: IDLE->UNPACK->MULTIPLY->NORM_ROUND)
    and `mc68881_fp80_addsub_unit` (5-cycle: IDLE->UNPACK->ALIGN->ADDSUB->NORM_ROUND)
    with start/busy/done handshake matching the existing `trig_div_inst` pattern.
  - Replaced combinational `mul_fp80` / `add_sub_fp80` calls in trig unit's
    `ST_FP_MUL` and `ST_FP_ADD` case arms with sequential unit delegation.
  - Removed all trig MUL/ADD MCP constraints from XDC (mul_a/b_reg->tmp_reg,
    add_a/b/rm/rp_reg->tmp_reg, a/x_reg->tmp_reg 4-cycle paths).
  - `tmp_reg` is now only written from registered sequential unit outputs
    (trig_mul_result, trig_add_result, trig_div_result) and reset.
  - Removed dead `fp_exec_cycles_left_reg` signal.
  - Latency impact: MUL +2 cycles, ADD +1 cycle per micro-op (~10-15% trig op increase).
  - All trig paths should close timing under single-cycle 100ns constraints.

### DEF-DIVREM-002: DIV NaN Policy Marks All NaN Inputs Invalid
- Status: Closed (2026-03-02)
- Files: `src/mc68881_pkg.vhd`, `src/mc68881_divrem_unit.vhd`, `src/mc68881_sgl_ops_unit.vhd`,
  `src/mc68881_trig_unit.vhd`, `src/mc68881_top.vhd`, `src/mc68881_alu.vhd`
- Resolution summary:
  - Added `fp80_is_snan`, `fp80_is_qnan`, `fp80_quiet_nan`, `fp80_propagate_nan` to pkg.
  - Top-level exception classifier fires INVALID only for SNaN inputs, not all NaN.
  - Divrem, sgl_ops, trig units use payload-preserving NaN propagation.
  - Two-NaN priority: SNaN over QNaN; same type prefers destination operand.
  - Domain errors (0/0, inf/inf, sqrt(neg), trig(inf)) unchanged: canonical QNaN + INVALID.
  - Removed dead `divrem_flag_invalid` signal from ALU.
  - Added 6 NaN discrimination regression tests to `tb/tb_mc68881_alu.vhd`.

### DEF-DIVREM-001: DIV/SQRT Underflow Flushes Tiny Results To Zero
- Status: Closed (2026-03-02)
- File: `src/mc68881_divrem_unit.vhd`
- Resolution summary:
  - Implemented IEEE 754 gradual underflow for DIV and SQRT paths.
  - When `exp_res_i <= 0`, mantissa is right-shifted by `1 - exp_res_i` via
    `shift_right_with_sticky` before rounding, preserving precision in the sticky bit.
  - Post-rounding `exp_res_i <= 0` branch now packs subnormal (exp=0, mant=mant_main)
    instead of flushing to zero.
  - Fixed sign-clearing bug in ST_POST_DIV that discarded the correct sign for
    negative underflow results (`div_res_u.sign := '0'` removed).
  - Added DIV subnormal regression test (min_normal / 2.0 → subnormal).

### DEF-PACKED-002: Full Packed-Decimal Default QoR Still Above Release Gate
- Status: Closed (2026-03-02)
- Files: `src/mc68881_packed_decimal_unit.vhd`, `src/mc68881_top.xdc`,
  `project/fpga68881/fpga68881.runs/impl_1/runme.log`,
  `project/fpga68881/fpga68881.runs/impl_1/mc68881_top_utilization_placed.rpt`,
  `project/fpga68881/fpga68881.runs/impl_1/mc68881_top_timing_summary_routed.rpt`
- Resolution summary:
  - Added dedicated packed arithmetic staging in `mc68881_packed_decimal_unit`
    (`AR_ST_IDLE -> AR_ST_WAIT -> AR_ST_COMMIT`) with registered operand/result
    boundaries for `mul_fp80`, `add_sub_fp80`, and `fp80_to_int_trunc`.
  - Split packed encode digit application into distinct subtract and scale
    micro-states to avoid add+mul combinational chaining in one cycle.
  - Added packed-unit multicycle constraints in `mc68881_top.xdc`
    (setup 5 / hold 4) for staged packed helper paths.
  - Functional regressions pass with default full-packed mode:
    `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`.
- Closure evidence:
  - Implementation run closes timing:
    `WNS=4.751ns`, `TNS=0.000ns`, `WHS=0.009ns`, `THS=0.000ns`
    (`.../impl_1/runme.log`, `.../mc68881_top_timing_summary_routed.rpt`).
  - Post-place implementation utilization reports:
    `Slice LUTs = 85354 / 133800 (63.79%)`
    (`.../impl_1/mc68881_top_utilization_placed.rpt`).

### DEF-PACKED-001: Packed-Decimal Conversion Is Limited To Integer-Centric Subset
- Status: Closed (2026-02-28)
- Files: `src/mc68881_top.vhd`, `tb/tb_mc68881_fmove_fmovem.vhd`
- Resolution summary:
  - Full FP80 digit-extraction encoder replaces integer-only fast path:
    unified multiply-and-truncate loop handles all finite values.
  - Full 17-digit FP80 accumulation decoder replaces 9-digit integer path:
    unbounded exponent scaling handles full MC68881 range (+/-9999).
  - OPERR exception wired for invalid BCD nibbles (A-F) via
    `packed96_has_invalid_bcd` and `exc_event_force_invalid_reg`.
  - Round-to-nearest-even (banker's rounding) replaces half-up.
  - `packed_encode_is_inexact` rewritten to mirror new encoder logic.
  - Test coverage added: 1.25 encode/decode round-trip, invalid BCD OPERR,
    round-to-nearest-even for exact-halfway cases (1500 k=1 odd rounds up,
    2500 k=1 even stays), pi k=17 EXC.INEXACT assertion.
  - 17-digit precision-limit inexact detection added: residual check
    after digit extraction catches FP80 values with >17 significant
    decimal digits.
  - Subnormal pre-normalization added: leading mantissa zeros counted
    to correct exp10 estimate, preventing all-zero mantissa for
    subnormal inputs.
  - Dead `decimal_digit_count` function removed.
- Remaining (tracked elsewhere):
  - NaN payload/SNaN distinction: resolved in C2 / DEF-DIVREM-002.

### DEF-TRIG-001: FCOS(-40.75) Sign Check
- Status: Closed (2026-02-15)
- Resolution summary:
  - The recorded failure was due to an incorrect reference expectation.
  - Correct expected value is negative:
    - `cos(-40.75) = x"BFFEFEF297A986C98000"`.
  - DUT result (`x"BFFEFEF297A2A2085F69"`) is same sign and within configured tolerance.
- Follow-up:
  - Keep `tb/tb_mc68881_known_defects.vhd` as a persistent recheck for this vector.

## TODO: Tighten Torture TB Transcendental Tolerances
- The torture testbench (`tb/tb_mc68881_torture.vhd`) uses wide tolerances in
  `check_fp80_close` for transcendental operations (SIN, COS, TAN, ATAN, etc.).
  Current thresholds are smoke-test level only.
- Once transcendental accuracy is improved (better argument reduction, higher-order
  polynomials, etc.), reduce the tolerance parameters to verify tighter ULP bounds.
- Affected tests: Phase 1 transcendental golden vectors (~123 tests) and Phase 2
  algebraic identities involving trig/exp/log (~10 tests).

## Implementation Snapshot (2026-03-05, Phase 5)
- Milestone:
  - Section 7 CIR Phase 5 complete (timing/cycle tests and regression matrix closure).
  - 19 new tests (T47-T65) added to `tb/tb_mc68881_cir_dialog.vhd`: protocol ordering
    verification, primitive progression, violation scenarios, cycle-overhead bounds,
    and CIR access timing assertions.
  - All S7 exit criteria met. No RTL changes (verification-only phase).
  - Measured cycle overheads: cpGEN FADD=58cy, cpCond=10cy, cpSAVE Idle=27cy,
    cpRESTORE Idle=24cy, CIR DSACK=3cy, save stream=21cy (7 reads), operand turnaround=24cy.
- Run data: No RTL changes; Phase 4 synthesis/timing numbers remain current.
  - Utilization: `Slice LUTs = 52361 / 133800 (39.13%)`
  - Timing: `WNS=16.631ns`, `TNS=0.000ns`

## Implementation Snapshot (2026-03-05, Phase 4)
- Milestone:
  - Section 7 CIR Phase 4 complete (exception dialog paths, FPIAR capture).
  - Tree-based CLZ optimization: replaced all sequential 64-iteration CLZ loops
    (fgetexp_fp80, fgetman_fp80, fgetexp_unbiased_int, packed-decimal encoder/decoder,
    addsub count_leading_zeros) with a shared `clz()` function in mc68881_pkg using
    binary-halving tree structure. Reduces synthesis from ~64-125 cascaded priority
    encoder stages to ~6-11 LUT levels.
  - Critical path moved from trig CLZ (682 logic levels, 399.9ns) to packed-decimal
    scaling path (112 logic levels, 83.3ns) — a fundamentally different bottleneck.
  - LUT usage dropped ~10 percentage points (49% → 39%) due to elimination of
    cascaded mux chains from sequential CLZ synthesis.
  - New worst path: `cir_operand_staging_reg[12]` → `operand_reg_reg[1][76]`
    (packed-decimal-to-FP80 conversion via scale_fp80_by_pow10).
  - Effective Fmax: ~12 MHz (up from ~10 MHz practical limit in Phase 3).
- Run data (non-incremental synthesis + implementation):
  - Utilization (post-place): `Slice LUTs = 52361 / 133800 (39.13%)`
  - DSPs: 33 / 740 (4.46%)
  - Registers: 13131 / 267600 (4.91%)
  - BRAM: 5 tiles / 365 (1.37%)
  - Timing: `WNS=16.631ns`, `TNS=0.000ns`
  - WNS improvement of +7.9 ns from Phase 3 (+8.700 → +16.631); 83% slack margin.

## Implementation Snapshot (2026-03-04, Phase 3)
- Milestone:
  - Section 7 CIR Phase 3 complete (FSAVE/FRESTORE with Null/Idle/Busy frames).
  - Full save/restore hierarchy: ALU (5 words) → trig (11 words) → divrem (6 words) →
    modrem_post (4 words) = 26 sub-unit words, plus 12 header/operand words, 3 packed,
    4 padding = 45 total Busy frame words.
  - Fixed d_out_reg race condition and operand read edge-detection bugs.
  - LUT usage decreased ~200 LUTs from Phase 2 (64,865 → 64,641) despite added logic,
    likely due to dead code removal and signal cleanup.
- Run data (non-incremental synthesis + implementation):
  - Utilization (post-place): `Slice LUTs = 64641 / 133800 (48.31%)`
  - DSPs: 33 / 740 (4.46%)
  - Registers: 13096 / 267600 (4.89%)
  - BRAM: 5 tiles / 365 (1.37%)
  - Timing: `WNS=8.700ns`, `TNS=0.000ns`
  - WNS regression of ~1.2 ns from Phase 2 (+9.875 → +8.700); still 87% slack margin.

## Implementation Snapshot (2026-03-04, Phase 2)
- Milestone:
  - Section 7 CIR Phase 2 complete (conditional dialog paths: FBcc/FDBcc/FScc/FTRAPcc/FNOP).
  - Unified dispatch refactor (eff_op_class/eff_op_sel) reduced LUT count vs Phase 1.
  - Net LUT reduction of ~1,700 LUTs from Phase 1 snapshot (66,572 → 64,865).
- Run data (non-incremental synthesis + implementation):
  - Utilization (post-place): `Slice LUTs = 64865 / 133800 (48.48%)`
  - DSPs: 33 / 740 (4.46%)
  - Registers: 11908 / 267600 (4.45%)
  - BRAM: 5 tiles / 365 (1.37%)
  - Timing: `WNS=9.875ns`, `TNS=0.000ns`
  - WNS regression of ~1.5 ns from Phase 1 (+11.404 → +9.875); still 90% slack margin.

## Implementation Snapshot (2026-03-04, Phase 1)
- Milestone:
  - Section 7 CIR Phase 1 complete (dialog FSM, reg-to-reg, memory transfers).
  - 8-phase LUT reduction applied: divider elimination, fintrz/fgetman de-duplication,
    compare_fp80 consolidation, carry-propagation serialization, selective ALU dispatch,
    format converter sharing.
  - LUT reductions offset CIR additions: net +565 LUTs vs pre-CIR baseline (66,007).
  - Timing dramatically improved: WNS from +0.404 ns to +11.404 ns (+11 ns gain)
    due to carry-propagation serialization breaking worst combinational paths.
  - CIR feature is gatable (`ENABLE_CIR_g => false`) for smaller FPGAs.
- Run data (non-incremental synthesis + implementation):
  - Utilization (post-place): `Slice LUTs = 66572 / 133800 (49.75%)`
  - DSPs: 33 / 740 (4.46%)
  - Registers: 11903 / 267600 (4.45%)
  - BRAM: 5 tiles / 365 (1.37%)
  - Timing: `WNS=11.404ns`, `TNS=0.000ns`, `WHS=0.010ns`, `THS=0.000ns`
  - DRC: 0 errors, warnings only (unconstrained I/O, DSP pipelining — pre-existing)
- LUT reduction breakdown:
  - Phase 1 (packed divider → bit index): ~1,000 LUTs
  - Phase 2 (fintrz de-dup): ~800 LUTs
  - Phase 3 (fgetman de-dup): ~400 LUTs
  - Phase 4 (compare_fp80 consolidation): ~1,500 LUTs
  - Phase 5 (ST_ENC_KROUND serialization): ~2,400 LUTs
  - Phase 6 (ST_ENC_POSTROUND serialization): ~1,200 LUTs
  - Phase 7 (ALU selective dispatch): ~600 LUTs
  - Phase 8 (format converter sharing): ~800 LUTs

## Implementation Snapshot (2026-03-03)
- Milestone:
  - Post-synth LUT usage at 44% after DEF-LUT-001 + DEF-LUT-002 + review fixes
    (NaN/infinity early-exit in sequential FP units allows dead-code pruning).
  - DSP usage reduced from 65 to 33 via FP unit sharing and sync reset DSP packing.
  - Design now fits on smaller FPGAs: Artix-7 100T, Zynq UltraScale+ ZU3EG,
    Cyclone V 5CEBA7.
- Run data (non-incremental synthesis):
  - Utilization (post-synth): `Slice LUTs = 59304 / 134600 (44.06%)`
  - DSPs: 33 / 740 (4.46%)
  - Registers: 11736 / 269200 (4.36%)
  - BRAM: 5 tiles / 365 (1.37%)

## Implementation Snapshot (2026-02-23)
- Milestone:
  - Routed timing met and post-implementation LUT usage is under 50%.
- Run data (non-incremental batch flow via `scripts/run_impl.tcl`):
  - Timing: `WNS=1.356ns`, `TNS=0.000ns`, `WHS=0.026ns`, `THS=0.000ns`
    (`reports/timing_summary.rpt`).
  - Utilization (post-impl): `Slice LUTs = 66523 / 134600 (49.42%)`
    (`reports/post_impl_util.rpt`).
  - Utilization (post-synth): `Slice LUTs = 69364 / 134600 (51.53%)`
    (`reports/post_synth_util.rpt`).
- Reproducibility:
  - Fresh clean run started 2026-02-23 11:27 and completed 12:08
    (`vivado -mode batch -source scripts/run_impl.tcl`).
  - Reproduced the same routed timing/utilization metrics above.
- RTL timing-focused structural changes in this iteration:
  - Added staged exponent metadata path in `src/mc68881_trig_unit.vhd`
    (`log_unbiased_exp_reg`, `log_exp_term_zero_reg`) and moved FP80 exponent
    conversion/scaling to follow-up states (`ST_LOG_GETEXP_POST`,
    `ST_LOGNP1_GETEXP_POST`) to shorten the `log_exp_term_reg` cone.

## Section 7 Coprocessor Interface Closure

# Section 7 Coprocessor Interface Closure Checklist

Reference: `docs/MC68881UM.pdf` Section 7 (Coprocessor Interface), especially 7.5 instruction dialogs.

Purpose: track closure from current memory-mapped host protocol to MC68881-style coprocessor dialog behavior.

Legend:
- `[ ]` Not started
- `[~]` In progress
- `[x]` Done

## Current Baseline (2026-02-15)
- Current top-level host contract is register-mapped (`OPSEL` + operand/result/status regs), not primitive-dialog driven.
- `FNOP`/`FSAVE`/`FRESTORE` decode + class routing exist, but program/system control behavior is placeholder.
- DSACK timing and address-space decode are implemented and tested.

## Mapping to Existing Plan Checklist

### A) Design Quality
- `[x]` S7-A1. Add typed primitive model for CIR transactions.
  - Map: `A6` (central opcode metadata), `A7` (typed decode records).
  - Done: `cir_state_t` FSM enum, `cir_cmd_type_t` command type, CIR address constants,
    and helper functions added to `mc68881_pkg.vhd`.
- `[~]` S7-A2. Add opcode-class metadata hooks for Section 7 dialog kind.
  - Map: `A5` (explicit operation classes), `A6`.
  - Deferred: OpWord[8:6] dispatch is functional; metadata field not required for correctness.

### B) Functional Completeness
- `[x]` S7-B1. Program-control dialog implementation (`FBcc/FDBcc/FScc/FNOP`).
  - Map: `B6`.
  - Done: CIR conditional dialog path for cpCond/cpBcc complete.
  - Done: CIR FSM naturally ignores OpWord writes when not in CIR_IDLE (flags auto-cleared).
  - Verified by Tests 47, 49, 50, 56 in `tb/tb_mc68881_cir_dialog.vhd`.
- `[x]` S7-B2. System-control dialog implementation (`FTRAPcc/FSAVE/FRESTORE`).
  - Map: `B7`.
  - Done: cpSAVE/cpRESTORE dialog with Null/Idle/Busy frame support.
  - Done: 45-word Busy frame with full sub-unit save/restore hierarchy.
  - Done: FRESTORE commit, Null reset, invalid format word exception.
- `[x]` S7-B3. Command/condition/response protocol ordering rules.
  - Map: `B6`, `B7`.
  - Done: Instruction-boundary sequencing verified. CIR FSM gating prevents overlapping
    dialogs (OpWord writes ignored when FSM not in CIR_IDLE). Protocol violation flag
    (STATUS bit 5) and response_pending lifecycle (STATUS bit 4) confirmed.
  - Verified by Tests 47-50 in `tb/tb_mc68881_cir_dialog.vhd`.

### C) Exceptions and Architectural Side Effects
- `[x]` S7-C1. Pre- vs mid-instruction exception dialog behavior.
  - Map: `C3`, `C5`.
  - Done: Pre-instruction exception (BSUN, invalid format word) and post-instruction
    exception (DZ, OVERFLOW, INVALID/SNAN) dialog paths implemented with correct
    response primitive encoding and ack sequencing.
  - Tests: T40 (BSUN trap), T41 (FDIV/0 post-instruction), T42 (DZ without enable),
    T44 (BSUN without enable), T45 (OVERFLOW post-instruction), T46 (exception priority).
- `[x]` S7-C2. BSUN conditional exception behavior in conditional dialogs.
  - Map: `C2`, `C3`, `C4`.
  - Done: BSUN trap delivery with FPCR enable (T40), BSUN without FPCR enable sets
    FPSR but no trap dialog (T44). Full trap-delivery/ack sequencing verified.
- `[x]` S7-C3. FPIAR update semantics tied to dialog phase.
  - Map: `C5`, `C4`.
  - Done: FPIAR capture from CIR_ADDR_INSTADDR verified (T43).
- `[x]` S7-C4. Format exception handling for FSAVE/FRESTORE.
  - Map: `C3`, `C4`.
  - Done: Invalid format word raises Pre-Instruction Exception (vector $0E).
  - Done: Test 36 verifies exception response for invalid format word $DEAD.

### D) Verification and Coverage
- `[x]` S7-D1. Add dedicated coprocessor-dialog protocol TB.
  - Map: `D1`, `D5`.
  - Done: Primitive progression verified for cpGEN reg-to-reg, cpGEN mem-source,
    cpCond, cpBcc-W, cpSAVE/cpRESTORE in Tests 51-55 (`tb/tb_mc68881_cir_dialog.vhd`).
- `[x]` S7-D2. Add protocol-violation TB scenarios.
  - Map: `D1`, `D5`.
  - Done: Protocol violation scenarios verified in Tests 56-58 (double OpWord,
    FRESTORE without format, condition write to cpGEN) in `tb/tb_mc68881_cir_dialog.vhd`.
- `[x]` S7-D3. Add context-switch dialog TB with format-word/state-frame matrix.
  - Map: `D1`, `D5`, `D6`.
  - Done: Tests 32-39 in `tb/tb_mc68881_cir_dialog.vhd` cover Null/Idle/Busy
    FSAVE, FRESTORE Null reset, FRESTORE Idle/Busy round-trip, invalid format
    word exception, and full save→restore→save data integrity verification.
- `[x]` S7-D4. Extend top-level exception-path checks for Section 7 dialogs.
  - Map: `D1`, `C3`, `C5`.
  - Done: Tests 40-46 in `tb/tb_mc68881_cir_dialog.vhd` verify EXC/AEXC/FPIAR side
    effects for BSUN, DZ, OVERFLOW, INVALID exception dialog paths, including
    priority ordering and enable/disable gating.
- `[x]` S7-D5. Add cycle-overhead checks for dialog startup/termination.
  - Map: `D4`, `E4`.
  - Done: Cycle-overhead bounds verified in Tests 59-62 (cpGEN FADD=58cy <=200,
    cpCond=10cy <=50, cpSAVE Idle=27cy <=100, cpRESTORE Idle=24cy <=100)
    in `tb/tb_mc68881_cir_dialog.vhd`.

### E) Bus Interface and Timing
- `[x]` S7-E1. Preserve DSACK/addressing correctness while adding CIR semantics.
  - Map: `E1`, `E2`, `E3`.
  - Done: All existing DSACK tests remain green through Phase 4.
  - Multi-beat DSACK cycling tests (16-bit x2, 8-bit x4) verify repeated handshake
    sequencing and data integrity across narrow bus transfers (`tb/tb_mc68881_top.vhd`).
- `[x]` S7-E2. Add CIR-specific access timing checks.
  - Map: `E1`, `D4`.
  - Done: CIR access timing verified in Tests 63-65 (DSACK latency=3cy <=10,
    save stream=21cy <=50, operand turnaround=24cy <=200) in `tb/tb_mc68881_cir_dialog.vhd`.

## Incremental Implementation Plan (Recommended Order)
- `[x]` Phase 1: Define CIR primitive types + internal dialog state machine skeleton.
  - Done: CIR types/constants/helpers in `mc68881_pkg.vhd`, dialog FSM skeleton
    in `mc68881_top.vhd`, cpGEN reg-to-reg path through ALU, memory-source and
    memory-destination transfers with E2E tests. Edge-detect operand writes,
    command flag re-trigger fix, CMP/TST writeback gating.
- `[x]` Phase 2: Implement conditional dialog path (`FNOP/FScc` first), then `FBcc/FDBcc/FTRAPcc`.
  - Done: CIR conditional dialog path for cpCond (FScc/FDBcc/FTRAPcc) and cpBcc
    (FBcc/FNOP) instruction types. Condition evaluation routed through existing
    `alu_control_proc` OP_CLASS_PROG_CTRL dispatch via unified `eff_op_class`/
    `eff_op_sel` refactor (Option C). CIR_COND_EVAL state with
    `cir_condition_written` flag gates entry until both OpWord and Condition CIR
    writes complete. `cond_selector` variable in OP_CLASS_PROG_CTRL reads
    `cir_condition_reg` directly for CIR path (avoids same-clock-edge timing
    issue with `operand_reg`). Fixed double exc_classification bug where
    `exc_event_valid_reg` from CIR ARITH valid handler overwrote correct FPSR CC.
    E2E tests: FNOP, FBcc taken/not-taken, FScc true/false, BSUN via CIR (6 tests).
- `[x]` Phase 3: Implement FSAVE/FRESTORE format-word and state-frame flow.
  - Done: cpSAVE/cpRESTORE CIR dialog FSM (CIR_SAVE_WAIT/FORMAT/FRAME,
    CIR_RESTORE_FORMAT/FRAME) with Null, Idle, and Busy frame support.
  - Done: 45-word Busy frame layout (6 header + 6 operand + 26 ALU/sub-unit +
    3 packed + 4 padding) with full save/restore hierarchy wiring through
    ALU → trig → divrem → modrem_post.
  - Done: FRESTORE commit restores FPSR and operands from captured frame data;
    Null FRESTORE resets FPU to power-on state; invalid format word raises
    Pre-Instruction Exception.
  - Done: Fixed d_out_reg race condition (sync_read latch gated on DSACK_IDLE,
    extended to CIR_SAVE_FRAME) and added cir_operand_read_prev edge-detect.
  - Tests: 8 new E2E tests (32-39) covering Null/Idle/Busy FSAVE, FRESTORE
    Null reset, FRESTORE Idle/Busy round-trip, invalid format word exception,
    and full save→restore→save data integrity verification.
- `[x]` Phase 4: Wire full exception dialog paths (pre/mid/BSUN/format) and FPIAR capture points.
  - Done: Exception dialog paths (pre-instruction, mid-instruction, BSUN, format error),
    FPIAR capture from CIR_ADDR_INSTADDR, exception priority (INVALID > DIVZERO).
  - Done: Tree-based CLZ optimization — replaced 5 sequential 64-iteration CLZ loops
    with shared `clz()` function using binary-halving tree (O(log N) logic depth).
    Critical path dropped from 682 logic levels to 112; WNS recovered from +0.612ns
    to +16.631ns; LUTs dropped from 49% to 39%.
  - Tests: 46 CIR dialog tests (tb_mc68881_cir_dialog), full ALU regression,
    known defects regression — all passing.
- `[x]` Phase 5: Close timing/cycle tests and regression matrix.
  - Done: 19 new tests (T47-T65) in `tb/tb_mc68881_cir_dialog.vhd`.
  - Protocol ordering (T47-T50), primitive progression (T51-T55),
    violation scenarios (T56-T58), cycle overhead (T59-T62), CIR timing (T63-T65).
  - All 65 CIR dialog tests passing, full GHDL regression green.

## Exit Criteria
- `[x]` All S7-B*, S7-C*, S7-D* items marked done.
  - S7-A2 deferred (OpWord[8:6] dispatch sufficient). All other items closed.
- `[x]` `B7` in this checklist can move to `[x]`.
- `[x]` No open Section 7 protocol-related defects in this checklist.
- `[x]` `scripts/run_tests.ps1` passes with new dialog testbenches enabled in CI/pre-push analyze lists.
