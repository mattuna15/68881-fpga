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
- `[ ]` `B6` and `B7` in `docs/mc68881_plan_checklist.txt` can move to `[x]`.
- `[ ]` No open Section 7 protocol-related defects in `docs/defect_checklist.md`.
- `[ ]` `scripts/run_tests.ps1` passes with new dialog testbenches enabled in CI/pre-push analyze lists.
