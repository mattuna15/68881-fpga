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

[ ] B6. Implement program-control instruction set (guide section 3.3.4).
    - FBcc, FDBcc, FScc, FNOP.
    - Ordered/unordered condition-code variants and NaN behavior.
    - FPU condition-code generation from FCMP/FTST results.

[ ] B7. Implement system-control instruction set (guide section 3.3.5).
    - FSAVE, FRESTORE.
    - FTRAPcc (#<data>.W/.L and no-immediate forms).

[ ] B8. Implement packed-decimal and decimal conversion path.
    - Packed-decimal encode/decode and edge cases.
    - Rounding and k-factor handling per FMOVE .P behavior.

C) Exception Handling & Edge Cases
----------------------------------
[~] C1. Add denormal handling coverage.
    - Define flush/denormal rules per MC68881 behavior.
    - In progress: subnormal input/output checks exist for sqrt/trig/trans and integer-conversion paths.

[~] C2. Improve NaN propagation details.
    - Ensure quiet/signaling NaN behavior is correct for each op.
    - In progress: broad NaN-class propagation checks exist for monadic/trig/trans ops.
    - REVIEW FINDING (critical): No SNaN vs QNaN discrimination anywhere in codebase.
      No fp80_is_snan/fp80_is_qnan function exists. invalid_on_nan_inputs fires
      for ALL NaN inputs; per datasheet only SNaN should set SNAN exception, QNaN
      should propagate silently with no exception.
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
[x] E2. Address decoding for all register spaces.
[x] E3. Access size handling for 8/16/32-bit.
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
    - Regression coverage: `tb/tb_mc68881_fmove_fmovem.vhd` now checks single
      and double minimum-subnormal conversion and single overflow mode behavior.

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

### DEF-TIMING-001: Trig FP Engine Uses MCP-Guarded Combinational FP80 Datapaths
- Status: Open
- Files: `src/mc68881_trig_unit.vhd`, `src/mc68881_top.xdc`
- Evidence:
  - Routed timing report showed extreme setup path depth in trig `div_fp80` launch/capture cone
    without matching MCP (`div_b_reg -> tmp_reg`, >2000 logic levels in latest failing run).
  - Trig FP micro-ops now run through explicit `fp_exec_start/busy/done` hooks and
    cycle contracts. `ST_FP_DIV` now routes through sequential `mc68881_divrem_unit`;
    remaining heavy combinational paths are `mul_fp80` and `add_sub_fp80`.
  - Latest routed implementation now closes timing at 10 MHz with margin:
    `WNS=1.356ns`, `TNS=0.000ns`, `WHS=0.026ns`, `THS=0.000ns`
    (`reports/timing_summary.rpt`, run completed 2026-02-23).
  - Post-implementation LUT utilization is below 50%:
    `Slice LUTs = 66523 / 134600 (49.42%)`
    (`reports/post_impl_util.rpt`, 2026-02-23).
- Current mitigation:
  - MCP constraints are applied for trig FP launch/capture contracts:
    - MUL: 2-cycle setup / 1-cycle hold
    - ADD: 4-cycle setup / 3-cycle hold
- Fix-exit criteria:
  - Replace combinational FP80 datapaths behind trig FP engine with true pipelined or
    iterative arithmetic stages, remove remaining trig MCP dependence, and close routed setup timing
    on those paths with single-cycle constraints at target frequency.

### DEF-DIVREM-001: DIV/SQRT Underflow Flushes Tiny Results To Zero
- Status: Open
- File: `src/mc68881_divrem_unit.vhd`
- Evidence:
  - Underflow paths in post-round stages force zero when `exp_res_i <= 0`:
    - `ST_SQRT_POST` (`src/mc68881_divrem_unit.vhd:604` vicinity)
    - `ST_POST_DIV` (`src/mc68881_divrem_unit.vhd:670` vicinity)
- Impact:
  - Tiny finite results are flushed instead of emitting gradual-underflow subnormals.
- Planned fix:
  - Implement subnormal packing/rounding path for `exp_res_i <= 0` rather than hard zero.

### DEF-DIVREM-002: DIV NaN Policy Marks All NaN Inputs Invalid
- Status: Open
- File: `src/mc68881_divrem_unit.vhd`
- Evidence:
  - DIV classify sets `flag_invalid_reg <= '1'` for any NaN input.
- Impact:
  - Quiet-NaN propagation behavior may be over-signaled versus 68881/QEMU-compatible policy.
- Planned fix:
  - Distinguish signaling-NaN vs quiet-NaN handling and raise invalid only where required by policy.

## Closed Defects

### DEF-TRIG-001: FCOS(-40.75) Sign Check
- Status: Closed (2026-02-15)
- Resolution summary:
  - The recorded failure was due to an incorrect reference expectation.
  - Correct expected value is negative:
    - `cos(-40.75) = x"BFFEFEF297A986C98000"`.
  - DUT result (`x"BFFEFEF297A2A2085F69"`) is same sign and within configured tolerance.
- Follow-up:
  - Keep `tb/tb_mc68881_known_defects.vhd` as a persistent recheck for this vector.

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
- `[ ]` S7-A1. Add typed primitive model for CIR transactions.
  - Map: `A6` (central opcode metadata), `A7` (typed decode records).
  - Add an internal `cir_primitive_t` record and explicit primitive-type enum.
- `[ ]` S7-A2. Add opcode-class metadata hooks for Section 7 dialog kind.
  - Map: `A5` (explicit operation classes), `A6`.
  - Define dialog kind per op: register-register, ext-register, register-ext, control-move, movem, conditional, context-switch.

### B) Functional Completeness
- `[ ]` S7-B1. Program-control dialog implementation (`FBcc/FDBcc/FScc/FNOP`).
  - Map: `B6`.
  - Implement condition-CIR style sequencing and response behavior (true/false/null + BSUN path).
- `[ ]` S7-B2. System-control dialog implementation (`FTRAPcc/FSAVE/FRESTORE`).
  - Map: `B7`.
  - Implement save/restore CIR format-word flow and state-frame transfer contract.
- `[ ]` S7-B3. Command/condition/response protocol ordering rules.
  - Map: `B6`, `B7`.
  - Enforce legal initiation/completion ordering and instruction-boundary sequencing.

### C) Exceptions and Architectural Side Effects
- `[ ]` S7-C1. Pre- vs mid-instruction exception dialog behavior.
  - Map: `C3`, `C5`.
  - Distinguish timing/path of exception reporting for startup vs in-flight operations.
- `[ ]` S7-C2. BSUN conditional exception behavior in conditional dialogs.
  - Map: `C2`, `C3`, `C4`.
  - Ensure NAN-condition interactions set EXC/AEXC fields and trap gating correctly.
- `[ ]` S7-C3. FPIAR update semantics tied to dialog phase.
  - Map: `C5`, `C4`.
  - Verify capture points for exceptions and non-updating moves/control operations.
- `[ ]` S7-C4. Format exception handling for FSAVE/FRESTORE.
  - Map: `C3`, `C4`.
  - Add invalid format-word and nested save/restore behavior checks.

### D) Verification and Coverage
- `[ ]` S7-D1. Add dedicated coprocessor-dialog protocol TB.
  - Map: `D1`, `D5`.
  - New TB: `tb/tb_mc68881_coprocessor_dialogs.vhd`.
  - Cover primitive request/ack progression for major Section 7 dialog families.
- `[ ]` S7-D2. Add protocol-violation TB scenarios.
  - Map: `D1`, `D5`.
  - New TB: `tb/tb_mc68881_protocol_violations.vhd`.
  - Cover early next-instruction initiation and illegal sequencing.
- `[ ]` S7-D3. Add context-switch dialog TB with format-word/state-frame matrix.
  - Map: `D1`, `D5`, `D6`.
  - New TB: `tb/tb_mc68881_context_switch_dialogs.vhd`.
  - Cover null/idle/busy/not-ready/invalid format paths and restore validation.
- `[ ]` S7-D4. Extend top-level exception-path checks for Section 7 dialogs.
  - Map: `D1`, `C3`, `C5`.
  - Extend `tb/tb_mc68881_top.vhd` to assert EXC/AEXC/FPIAR side effects for dialog-triggered exceptions.
- `[ ]` S7-D5. Add cycle-overhead checks for dialog startup/termination.
  - Map: `D4`, `E4`.
  - Validate per-dialog handshake overhead assumptions using status/cycle counters.

### E) Bus Interface and Timing
- `[~]` S7-E1. Preserve DSACK/addressing correctness while adding CIR semantics.
  - Map: `E1`, `E2`, `E3`.
  - Keep existing DSACK tests green while introducing dialog behavior.
- `[ ]` S7-E2. Add CIR-specific access timing checks.
  - Map: `E1`, `D4`.
  - Extend `tb/tb_mc68881_ac_timing.vhd` with explicit save/response-CIR access timing assertions.

## Incremental Implementation Plan (Recommended Order)
- `[ ]` Phase 1: Define CIR primitive types + internal dialog state machine skeleton.
- `[ ]` Phase 2: Implement conditional dialog path (`FNOP/FScc` first), then `FBcc/FDBcc/FTRAPcc`.
- `[ ]` Phase 3: Implement FSAVE/FRESTORE format-word and state-frame flow.
- `[ ]` Phase 4: Wire full exception dialog paths (pre/mid/BSUN/format) and FPIAR capture points.
- `[ ]` Phase 5: Close timing/cycle tests and regression matrix.

## Exit Criteria
- `[ ]` All S7-B*, S7-C*, S7-D* items marked done.
- `[ ]` `B6` and `B7` in this checklist can move to `[x]`.
- `[ ]` No open Section 7 protocol-related defects in this checklist.
- `[ ]` `scripts/run_tests.ps1` passes with new dialog testbenches enabled in CI/pre-push analyze lists.
