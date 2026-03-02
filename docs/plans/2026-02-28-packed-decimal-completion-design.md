# DEF-PACKED-001 Completion: Full Packed-Decimal Conversion

Date: 2026-02-28
Status: Approved
Branch: b8-fix

## Problem

The packed-decimal encode/decode paths in `src/mc68881_top.vhd` have four
limitations tracked by DEF-PACKED-001:

1. **Encode** only handles exact 32-bit integers. Non-integer FP80 values
   (e.g. 1.25, pi) fall through to a heuristic bit-shaping fallback that
   does not produce correct BCD output.
2. **Decode** accumulates only 9 of 17 mantissa digits (32-bit integer
   overflow boundary) and restricts the scale exponent to [-9, +9].
3. **Invalid BCD** nibbles (A-F) silently return the fallback value with
   no OPERR exception.
4. **Rounding** uses half-up instead of the MC68881-specified
   round-to-nearest-even (banker's rounding).

## Design

### 1. Unified FP80 Digit-Extraction Encoder

Replace `fp80_to_packed96`'s integer fast-path and legacy fallback with a
single path that works for all finite values.

Algorithm:
1. Handle zero/inf/NaN (existing special-case code, unchanged).
2. Take absolute value, save sign.
3. Find decimal exponent via binary exponent estimate:
   - `exp10_est = floor(unbiased_binary_exp * 77 / 256)` (approximates
     log10(2)).
   - Scale value into [1.0, 10.0) with at most 2 correction
     multiplies/divides by 10.
4. Extract 17 BCD digits via multiply-and-truncate loop:
   - `digit[0] = fp80_to_int_trunc(scaled)`
   - `scaled = (scaled - fp80_from_int(digit[0])) * 10`
   - Repeat for all 17 digits.
5. Apply k-factor rounding with round-to-nearest-even (Section 4).
6. Pack into 96-bit format (existing packing code).

Delete `apply_packed_k_factor_fallback` (dead code after this change).

### 2. Full 17-Digit FP80 Accumulation Decoder

Replace `packed96_to_fp80`'s 9-digit integer accumulation and [-9, +9]
scale limit with FP80 arithmetic.

Algorithm:
1. Extract all 17 BCD digits (extraction code already exists).
2. Validate all nibbles; return OPERR if any is invalid (Section 3).
3. Accumulate into FP80:
   - `accum = fp80_from_int(digit[0])`
   - For digits 1-16: `accum = add_sub_fp80(mul_fp80(accum, 10), fp80_from_int(digit[i]))`
   - 17 decimal digits ~ 56.5 binary bits; exact within FP80's 64-bit
     mantissa.
4. Scale by 10^(exp10 - 16) via loop:
   - Positive: multiply by 10 repeatedly.
   - Negative: divide by 10 repeatedly.
   - MC68881 exponent range is +/-9999; ~10K iterations max, acceptable
     for simulation.
5. Apply sign and return.

### 3. OPERR Exception for Invalid BCD

Add `packed96_has_invalid_bcd(packed : packed96_t) return boolean`:
- Check all 21 BCD nibbles (4 exponent + 17 mantissa) for values A-F.
- Skip check when YY=11 (infinity/NaN use non-BCD encoding).

Wire into exception path:
- Add `move_exc_force_invalid : std_logic` variable in bus process
  (alongside existing `move_exc_force_inexact`).
- Add `exc_event_force_invalid_reg` signal; wire through exception
  classification to set `exc_flags(FPSR_EXC_INVALID)`.
- In mem-to-reg packed decode: if `packed96_has_invalid_bcd` is true, set
  the force flag. Decode still produces the fallback value.

### 4. Round-to-Nearest-Even (Banker's Rounding)

Modify the k-factor rounding in `fp80_to_packed96` and its mirror in
`packed_encode_is_inexact`:

Current logic:
```
if round_digit >= 5 then carry := 1
```

New logic:
```
if round_digit > 5 then
  carry := 1
elsif round_digit = 5 then
  -- Check if any trailing digit is non-zero (above halfway)
  has_trailing := false
  for idx in (keep_digits+1) to 16 loop
    if digits(idx) /= 0 then has_trailing := true; end if
  end loop
  if has_trailing then
    carry := 1   -- above halfway, round up
  elsif digits(keep_digits-1) mod 2 = 1 then
    carry := 1   -- exact halfway, round to even (odd kept digit -> round up)
  end if
end if
```

### 5. Test Vectors

Add to `tb/tb_mc68881_fmove_fmovem.vhd`:

| Test | Input | K | Checks |
|------|-------|---|--------|
| Non-integer 1.25 | fp80 1.25 | 4 | digits 1.250, exp=0 |
| Non-integer pi | fp80 ~3.14159... | 17 | 17-digit mantissa, exp=0 |
| Large exponent | fp80 1.0e+100 | 5 | digits 1.0000, exp=100 |
| Small value | fp80 1.0e-50 | 5 | digits 1.0000, exp=-50 |
| 17-digit decode | packed pi | -- | round-trip matches |
| Wide exp decode | packed 1.0e+999 | -- | correct FP80 value |
| Invalid BCD | nibble=0xA | -- | fallback + FPSR INVALID set |
| RTE: even kept, digit=5 | value where d=5, even | 3 | no carry |
| RTE: odd kept, digit=5 | value where d=5, odd | 3 | carry |
| Regression | all existing vectors | -- | no change |

### 6. Files Modified

- `src/mc68881_top.vhd`: encode/decode functions, OPERR wiring, exception signals
- `tb/tb_mc68881_fmove_fmovem.vhd`: new test vectors
- `docs/fpu-progress-checklist.md`: close DEF-PACKED-001, update B8

### 7. Exit Criteria

- All existing tests pass (no regression).
- Non-integer FP80 values encode to correct packed BCD.
- All 17 mantissa digits decoded; exponents up to +/-9999 handled.
- Invalid BCD nibbles raise FPSR EXC.INVALID.
- K-factor rounding uses round-to-nearest-even.
- DEF-PACKED-001 closed in checklist.
