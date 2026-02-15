# Defect Checklist

Track known functional defects that are intentionally not enforced as hard regressions yet.
Keep this list short, actionable, and updated whenever a defect is fixed or newly discovered.

## Open Defects

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
