# Packed-Decimal Default Re-Enable Status (2026-03-02)

## Objective
Restore full packed-decimal (`.P`) behavior as the default configuration while avoiding the prior full-path synthesis explosion.

## Final Architecture
1. Added dedicated packed engine: `src/mc68881_packed_decimal_unit.vhd`.
2. Integrated engine in top-level (`src/mc68881_top.vhd`) with default `packed_decimal_full_g=true`.
3. Kept fallback path only for debug/bisect builds (`packed_decimal_full_g=false`).
4. Added helper conversion API `fp80_from_u64` in `src/mc68881_pkg.vhd` for integer decode accumulation.
5. Added packed-unit timing architecture hardening:
   - split encode digit flow into `ST_ENC_DIGIT_SUB` and `ST_ENC_DIGIT_SCALE`
   - staged arithmetic scheduler (`AR_ST_IDLE`, `AR_ST_WAIT`, `AR_ST_COMMIT`)
   - registered helper operand/result boundaries for `mul_fp80`, `add_sub_fp80`, `fp80_to_int_trunc`
6. Added packed-unit MCP constraints in `src/mc68881_top.xdc` (`setup 5`, `hold 4`) for staged helper paths.
7. Updated compile order in:
   - `scripts/run_tests.ps1`
   - `.githooks/pre-push`
   - `project/fpga68881/fpga68881.xpr`

## Verification Evidence
Date: 2026-03-02

1. Functional regression
   - Command: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
   - Result: PASS

2. Historical non-project synth context (before timing hardening)
   - `Slice LUTs`: `88295 / 134600 (65.60%)`
   - `DSPs`: `65`
   - Reports: `build/vivado_synth/util.rpt`, `build/vivado_synth/util_full.rpt`

3. Final implementation closure evidence (`project/fpga68881/fpga68881.runs/impl_1`)
   - Timing: `WNS=4.751ns`, `TNS=0.000ns`, `WHS=0.009ns`, `THS=0.000ns`
     (`runme.log`, `mc68881_top_timing_summary_routed.rpt`)
   - Utilization: `Slice LUTs = 85354 / 133800 (63.79%)`
     (`mc68881_top_utilization_placed.rpt`)

## Historical Comparison
- Prior full-path snapshot before compact-unit refactor:
  `LUT1-6 total 371654`, `DSP48E1 555`.
- Interim full/default packed synth:
  `88295 LUTs`, `65 DSPs`.
- Final implementation result:
  `63.79%` Slice LUT and positive setup slack (`WNS=4.751ns`).

## Acceptance Status
1. Functional regressions: PASS.
2. Default full-packed behavior restored: DONE.
3. QoR and timing closure for default full-packed implementation: DONE.
4. Defect closure (`DEF-PACKED-002`): CLOSED (2026-03-02).

## Notes
The temporary fallback-default rationale (`packed_decimal_full_g=false`) is retired.
Full packed-decimal behavior remains the default build configuration.
