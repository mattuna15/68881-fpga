# Defect Checklist

Track known functional defects that are intentionally not enforced as hard regressions yet.
Keep this list short, actionable, and updated whenever a defect is fixed or newly discovered.

## Open Defects
- None currently tracked.

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
