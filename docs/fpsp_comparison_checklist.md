# VHDL vs Motorola FPSP Algorithm Comparison Checklist

Comparison of the MC68881 VHDL implementation against the Motorola 68040 FPSP
reference (`NeXTMach/mk-108.1/fpsp/`). The FPSP is Motorola's official software
emulation of unimplemented 68040 FPU instructions — the same algorithms the
68881/68882 implement in hardware.

---

## Key Files

| Area | VHDL | FPSP Reference |
|------|------|----------------|
| Sin/Cos/SinCos | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/ssin.sa` |
| Tan | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/stan.sa` |
| Atan | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/satan.sa` |
| Asin | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/sasin.sa` |
| Acos | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/sacos.sa` |
| Sinh | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/ssinh.sa` |
| Cosh | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/scosh.sa` |
| Tanh | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/stanh.sa` |
| Atanh | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/satanh.sa` |
| Exp/Etoxm1 | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/setox.sa` |
| 2^x / 10^x | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/stwotox.sa` |
| Logn/Lognp1 | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/slogn.sa` |
| Log2 / Log10 | `src/mc68881_trig_unit.vhd` | `NeXTMach/mk-108.1/fpsp/slog2.sa` |
| FREM/FMOD | `src/mc68881_divrem_unit.vhd` | `NeXTMach/mk-108.1/fpsp/srem_mod.sa` |
| FINT/FINTRZ | `src/mc68881_alu.vhd` | `NeXTMach/mk-108.1/fpsp/sint.sa` |
| Packed BCD | `src/mc68881_top.vhd` | `NeXTMach/mk-108.1/fpsp/bindec.sa`, `decbin.sa` |

---

## 1. SIN / COS / SINCOS

### Polynomial Form & Degree

| Aspect | FPSP (Motorola) | VHDL |
|--------|----------------|------|
| SIN polynomial | Odd, degree 7 (SINA1..A7), minimax | Horner degree 9, Taylor (1/n!) |
| COS polynomial | Even, degree 8 (COSB1..B8), minimax | Same Horner degree 9 via quadrant mapping |
| Coefficient type | Minimax (min-max error optimized) | Taylor series (1, 1/2!, 1/3!, ... 1/9!) |
| Separate sin/cos coeffs | Yes — distinct SINA and COSB sets | No — single shared EXP coefficient set |

- [ ] **1.1** VHDL uses Taylor coefficients (1/n!); FPSP uses minimax-optimized SINA1-7 / COSB1-8. Minimax minimizes worst-case error across the interval.
- [ ] **1.2** VHDL uses a single shared coefficient ROM for both sin and cos. FPSP has separate, independently optimized sets for sin (odd, 7 terms) and cos (even, 8 terms).

### Argument Reduction

| Aspect | FPSP | VHDL |
|--------|------|------|
| Method | N*(pi/2) table, 64 entries (N=-32..32), 69-bit | 3-term Cody-Waite (~131-bit pi/2) |
| Small threshold | \|X\| < 2^(-40) | exp < bias-32 (~2^(-32)) |
| Large threshold | \|X\| >= 15*pi -> X rem 2*pi | exp > bias+20 -> full reduction |
| Table seed | N*(pi/2) table (extended+single trailing) | 64 quarter-pi-spaced seed points |

- [ ] **1.3** Reduction method differs: FPSP precomputed N*(pi/2) table vs VHDL Cody-Waite. VHDL may be more precise but verify table-seed refinement error.
- [ ] **1.4** Small-argument threshold: FPSP 2^(-40) vs VHDL ~2^(-32). FPSP returns argument earlier.
- [ ] **1.5** VHDL has 64 seed points (center, sin, cos) for table-assisted refinement. FPSP evaluates polynomial on full reduced argument directly.

### Accuracy

- [ ] **1.6** FPSP guarantees 1 ulp and monotonicity in double precision. VHDL has no documented monotonicity guarantee.

---

## 2. TAN

| Aspect | FPSP | VHDL |
|--------|------|------|
| Approximation | Rational U/V (P degree 3, Q degree 4) | sin/cos pipeline then division |
| Odd quadrant | -V/U (negated cotangent) | cos/sin via quadrant |
| Accuracy | 3 ulp in 64-bit | Inherits sin/cos + division error |

<<<<<<< HEAD
- [ ] **2.1** `[E]` FPSP uses a dedicated rational approximation for tan (3 ulp). VHDL computes sin(r)/cos(r) — two polynomial evals plus a division. ~60-70% fewer cycles with rational form.
- [ ] **2.2** `[E]` FPSP's -cot(r) = -V/U for odd quadrants is a single rational eval. VHDL needs two polynomials + division.
=======
- [ ] **2.1** `[E]` FPSP uses a dedicated rational approximation for tan (3 ulp). VHDL computes sin(r)/cos(r) — two polynomial evals plus a division. ~60-70% fewer cycles with rational form. **Analysis: cycle-neutral with VHDL's table-assisted sin/cos (~17 vs ~17 FP ops). Skipped.**
- [ ] **2.2** `[E]` FPSP's -cot(r) = -V/U for odd quadrants is a single rational eval. VHDL needs two polynomials + division. **Skipped (see 2.1).**
>>>>>>> main

---

## 3. ATAN

| Aspect | FPSP | VHDL |
|--------|------|------|
| Small range (\|X\| < 1/16) | Polynomial degree 6 (B1..B6) | Horner degree 9 (ATAN coeff set) |
| Medium range (1/16..16) | 128 entries for atan(F), multiply by 1/F (no division) | 64 entries, FP division for u |
| Large range (\|X\| >= 16) | Polynomial degree 5 (C1..C5) on -1/X | Reciprocal -> same pipeline |
| Division avoidance | Tabulated 1/F values, uses multiplication | FP division |

<<<<<<< HEAD
- [ ] **3.1** `[E]` FPSP avoids division by tabulating 1/F values. VHDL performs FP division for u = (x-c)/(1+cx). Eliminates one FP division (~6+ cycles).
=======
- [ ] **3.1** `[E]` FPSP avoids division by tabulating 1/F values. VHDL performs FP division for u = (x-c)/(1+cx). Eliminates one FP division (~6+ cycles). **Skipped: ATAN denominator (1+c_i*x) is input-dependent, cannot precompute.**
>>>>>>> main
- [ ] **3.2** FPSP has 3 separate polynomial sets for 3 ranges. VHDL uses a single degree-9 set.
- [ ] **3.3** FPSP table has 128 entries; VHDL has 64. Coarser table = larger residuals.

---

## 4. ASIN / ACOS

| Aspect | FPSP | VHDL |
|--------|------|------|
| ACOS | 2*atan(sqrt((1-X)/(1+X))) | atan(x/sqrt(1-x^2)) |
| ASIN | atan(X/sqrt((1-X)(1+X))) | atan(x/sqrt(1-x^2)) |

- [ ] **4.1** FPSP ACOS uses identity that avoids near-singularity at X=+/-1 better than VHDL's form (division by near-zero when |X| -> 1).
- [ ] **4.2** FPSP ASIN computes (1-X)(1+X) as two factors to preserve precision. Verify VHDL avoids catastrophic cancellation in 1-X^2.

---

## 5. EXP / ETOX / ETOXM1

| Aspect | FPSP | VHDL |
|--------|------|------|
| Reduction | 2^(J/64) table, N = round(X*64/ln2) -> \|R\| <= 0.0054 | Cody-Waite, k = floor(X*INV_LN2) -> \|r\| <= 0.347 |
| Table | 64-entry EXPTBL at 62-bit precision | 64-entry EXP_SEED_PRE_MUL |
| Polynomial (exp) | Degree 5, minimax, error < 2^(-68.8) | Degree 9, Taylor (1/n!) |
| Polynomial (expm1) | Degree 12, minimax, error < \|X\|*2^(-70.6) | Same exp pipeline, subtract 1 at end |
| Accuracy | 0.85 ulp (64-bit), monotonic | ~60-80 bits from Taylor |

<<<<<<< HEAD
- [ ] **5.1** `[E]` FPSP reduces to |R| <= 0.0054 (via 2^(J/64)); VHDL to |r| <= 0.347. The 64x tighter reduction allows FPSP degree-5 to beat VHDL degree-9. Saves ~4 Horner iterations (~8 FP mul/add cycles).
- [ ] **5.2** `[E]` Minimax degree-5 (error < 2^(-68.8)) outperforms Taylor degree-9 over VHDL's wider interval.
=======
- [x] **5.1** `[E]` FPSP reduces to |R| <= 0.0054 (via 2^(J/64)); VHDL to |r| <= 0.347. The 64x tighter reduction allows FPSP degree-5 to beat VHDL degree-9. Saves ~4 Horner iterations (~8 FP mul/add cycles). **DONE: Added 64-entry EXPTBL, 2^(J/64) decomposition for ETOX/ETOXM1/TANH.**
- [x] **5.2** `[E]` Minimax degree-5 (error < 2^(-68.8)) outperforms Taylor degree-9 over VHDL's wider interval. **DONE: COEFF_SET_EXP64 with FPSP A1-A5 minimax, degree 6 Horner.**
>>>>>>> main
- [ ] **5.3** ETOXM1: FPSP has dedicated degree-12 minimax for |X| < 0.25. VHDL uses EXP then subtracts 1 — catastrophic cancellation for small X. Significant accuracy gap.
- [ ] **5.4** Verify FPSP's L1+L2 (88-bit ln2/64) vs VHDL's 131-bit Cody-Waite ln2 net precision.

---

## 6. TWOTOX / TENTOX

| Aspect | FPSP | VHDL |
|--------|------|------|
| TWOTOX | Direct 64ths decomposition, dedicated | Converts via X*ln(2) then EXP pipeline |
| TENTOX | Direct via log2(10), dedicated | Converts via X*ln(10) then EXP pipeline |

<<<<<<< HEAD
- [ ] **6.1** `[E]` FPSP avoids intermediate multiply by ln(2) for 2^X. VHDL's extra multiply introduces rounding. Saves 1 FP multiply cycle.
- [ ] **6.2** `[E]` Same for 10^X. Saves 1 FP multiply cycle.
=======
- [x] **6.1** `[E]` FPSP avoids intermediate multiply by ln(2) for 2^X. VHDL's extra multiply introduces rounding. Saves 1 FP multiply cycle. **DONE: TWOTOX uses k=nint(x), r=x-k, exp(r*ln2). Saves ~4 FP ops.**
- [x] **6.2** `[E]` Same for 10^X. Saves 1 FP multiply cycle. **DONE: TENTOX uses y=x*log2(10), k=nint(y), r=y-k, exp(r*ln2). Saves ~3 FP ops.**
>>>>>>> main

---

## 7. LOG / LOGN / LOGNP1

| Aspect | FPSP | VHDL |
|--------|------|------|
| Near-1 path | Odd poly in u = 2(X-1)/(X+1), dedicated | (verify) |
| General path | F = 1.xxxxxx1 (7 bits), 64 log(F) + 1/F entries | 64 centers c_i, ln(c_i) table, coeff0 override |
| Division | Multiply by 1/F (tabulated) | FP division (x-c)/c |
| Polynomial | Degree 6 (LOGA1-6), minimax, split parallel eval | Degree 9, alternating Taylor (1, -1/2, 1/3...) |
| LOGNP1 | u = 2X/(2+X) for small X, careful Y-F | z = a+1, then LOG pipeline |
| Accuracy | 2 ulp (64-bit), monotonic | ~56+ bits |

<<<<<<< HEAD
- [ ] **7.1** `[E]` FPSP uses tabulated 1/F to avoid division. VHDL divides. Eliminates one FP division (~6+ cycles).
- [ ] **7.2** `[E]` Minimax degree-6 vs Taylor degree-9. Saves ~3 Horner iterations (~6 FP mul/add cycles).
=======
- [x] **7.1** `[E]` FPSP uses tabulated 1/F to avoid division. VHDL divides. Eliminates one FP division (~6+ cycles). **DONE: Added LOG_RECIP_CENTER table (64 entries of 1/c_i). LOG u=(m-c_i)*(1/c_i) via MUL instead of DIV. Saves ~50 cycles.**
- [ ] **7.2** `[E]` Minimax degree-6 vs Taylor degree-9. Saves ~3 Horner iterations (~6 FP mul/add cycles). **Not implemented: Taylor adequate with table-assisted reduction (|u|<1/128).**
>>>>>>> main
- [ ] **7.3** LOGNP1: FPSP uses u = 2X/(2+X) preserving precision for small X. VHDL computes z = 1+X then routes through LOG (loses bits via cancellation).
- [ ] **7.4** Verify VHDL handles Y-F precision when 1/2 <= X < 3/2.
- [ ] **7.5** LOG2: FPSP extracts integer exponent directly. VHDL computes ln then multiplies by INV_LN2.

---

## 8. SINH / COSH / TANH

| Aspect | FPSP | VHDL |
|--------|------|------|
| SINH | sign(X)*(1/2)*(z + z/(1+z)), z = expm1(\|X\|) | Dedicated SINH odd-Taylor coefficients |
| COSH | (1/2)*(exp + 1/exp) | Dedicated COSH even-Taylor coefficients |
| TANH | 3 ranges: expm1-based / exp-based / +/-1-tiny | Via EXP pipeline |
| Overflow | Scaled exp to avoid intermediate infinity | (verify) |

- [ ] **8.1** FPSP SINH uses expm1 to avoid cancellation. VHDL uses direct odd-Taylor polynomial.
- [ ] **8.2** FPSP TANH has 3 dedicated ranges. VHDL routes through EXP.
- [ ] **8.3** Verify VHDL overflow prevention for large sinh/cosh arguments.

---

## 9. ATANH

- [ ] **9.1** FPSP uses log1p (LOGNP1) for precision. Verify VHDL LOG-based routing is equivalent.

---

## 10. FREM / FMOD

| Aspect | FPSP | VHDL |
|--------|------|------|
| Mantissa width | 96-bit normalized integers | 128-bit dividend |
| REM tie-break | R = Y/2 and Q odd -> increment Q | modrem_post_unit |

- [ ] **10.1** Verify edge cases with 128-bit vs 96-bit width.
- [ ] **10.2** Verify FREM tie-break (R = Y/2, Q odd -> increment Q) matches IEEE 754.
- [ ] **10.3** Verify post-multiply rounding in VHDL's separated div + post-multiply approach.

---

## 11. Packed BCD Conversion

- [ ] **11.1** Verify VHDL packed decimal conversion exists and matches FPSP algorithm (bindec.sa / decbin.sa).
- [ ] **11.2** FPSP has 3 power-of-10 tables (RN/RM/RP) for rounding-mode-aware conversion. Verify VHDL equivalence.

---

## 12. Exception Handling

- [ ] **12.1** Verify exception priority: BSUN > SNAN > OPERR > OVFL > UNFL > DZ > INEX2 > INEX1.
- [ ] **12.2** Verify overflow/underflow exponent biasing (+/-0x6000) when traps enabled.
- [ ] **12.3** Verify all OPERR conditions match (infinity to trig, log of negative, etc.).

---

## 13. Coefficient Source — Systematic Issue (Highest Impact)

| Function | FPSP Coefficients | VHDL Coefficients |
|----------|-------------------|-------------------|
| SIN | Minimax SINA1-7 | Taylor 1/n! |
| COS | Minimax COSB1-8 | Taylor 1/n! |
| TAN | Minimax P1-3, Q1-4 (rational) | No dedicated (uses sin/cos) |
| ATAN | Minimax ATANA1-3, ATANB1-6, ATANC1-5 | Taylor 1, -1/3, 1/5... |
| EXP | Minimax A1-5 | Taylor 1/n! |
| EXPM1 | Minimax B1-12 | Taylor 1/n! (no dedicated) |
| LOG | Minimax LOGA1-6 | Taylor alternating harmonic |

<<<<<<< HEAD
- [ ] **13.1** `[E]` Replace Taylor with minimax coefficients for each function. Highest-impact single change — enables lower polynomial degrees (fewer Horner iterations) across all functions.
=======
- [x] **13.1** `[E]` Replace Taylor with minimax coefficients for each function. Highest-impact single change — enables lower polynomial degrees (fewer Horner iterations) across all functions. **DONE for EXP: COEFF_SET_EXP64 uses FPSP A1-A5 minimax with degree 6 (was degree 9 Taylor). LOG/ATAN keep Taylor — their table-assisted reduction already provides tight ranges.**
>>>>>>> main
- [ ] **13.2** Consider extracting exact FPSP coefficient values from .sa files (hex extended-precision) or computing fresh minimax via Remez algorithm.

---

## 14. Table Structure Differences

| Aspect | FPSP | VHDL |
|--------|------|------|
| Reciprocal tables | 1/F tabulated (atan, log) | No reciprocals — uses FP division |
| Atan table size | 128 entries | 64 entries |

<<<<<<< HEAD
- [ ] **14.1** `[E]` Add reciprocal tables (1/F) for ATAN and LOG to eliminate FP division rounding. +1-2 BRAMs but frees divrem unit.
=======
- [x] **14.1** `[E]` Add reciprocal tables (1/F) for ATAN and LOG to eliminate FP division rounding. +1-2 BRAMs but frees divrem unit. **DONE for LOG (1/c_i table). ATAN skipped — its denominator (1+c_i*x) is input-dependent and cannot be precomputed.**
>>>>>>> main
- [ ] **14.2** Consider doubling ATAN table to 128 entries.

---

## 15. Denormal / Unnormal Input Handling

- [ ] **15.1** FPSP has dedicated denormal entry points for all transcendentals. Verify VHDL equivalence.
- [ ] **15.2** Verify FINT/FINTRZ two-step denormalize-then-renormalize matches FPSP sint.sa.
- [ ] **15.3** Verify VHDL accepts unnormalized extended inputs (68881 feature).

---

## Priority Summary

`[E]` = Improves efficiency (fewer cycles) or reduces resource usage

### Efficiency (cycle/resource impact)
<<<<<<< HEAD
1. **13.1** `[E]` Minimax coefficients — enables lower degree across ALL functions (saves 2-4 Horner iterations each)
2. **5.1/5.2** `[E]` EXP 2^(J/64) decomposition — degree 5 vs 9, saves ~8 FP mul/add cycles
3. **2.1/2.2** `[E]` Rational TAN — one eval vs two polynomials + division (~60-70% fewer cycles)
4. **14.1/3.1/7.1** `[E]` Reciprocal tables — eliminates FP division in ATAN and LOG (+1-2 BRAM, saves ~6+ cycles each)
5. **7.2** `[E]` LOG minimax degree 6 vs Taylor degree 9 — saves ~3 Horner iterations
6. **6.1/6.2** `[E]` TWOTOX/TENTOX skip pre-multiply — saves 1 FP multiply each
=======
1. **13.1** `[E]` ~~Minimax coefficients~~ **DONE** for EXP (COEFF_SET_EXP64, degree 6)
2. **5.1/5.2** `[E]` ~~EXP 2^(J/64) decomposition~~ **DONE** — 64-entry EXPTBL, FPSP minimax degree 6, ETOX GV exact match
3. **2.1/2.2** `[E]` Rational TAN — analysis showed cycle-neutral with table-assisted sin/cos. **SKIPPED.**
4. **14.1/3.1/7.1** `[E]` ~~Reciprocal tables~~ **DONE** for LOG (1/c_i table, ~50 cycle savings). ATAN skipped (input-dependent denominator).
5. **7.2** `[E]` LOG minimax degree 6 — not implemented (Taylor adequate with table-assisted reduction)
6. **6.1/6.2** `[E]` ~~TWOTOX/TENTOX skip pre-multiply~~ **DONE** — saves ~4 FP ops per TWOTOX, ~3 per TENTOX

### Accuracy regressions from efficiency changes (recoverable)
- **LOGN** lost ~3 bits (~54 vs ~57): reciprocal MUL vs exact DIV. Fix: Newton-Raphson refinement `u' = u + u*(1 - c_i*u)` after reciprocal multiply (+1 MUL +1 ADD).
- **TWOTOX/TENTOX** lost ~7 bits (47 vs 54): single `r*ln(2)` multiply vs 3-term CW. Fix: 2-term CW split of ln(2) for the `r*ln(2)` multiply (+1 MUL +1 ADD, recovers ~10 bits).
>>>>>>> main

### Accuracy-only (no efficiency impact)
7. **5.3** Dedicated ETOXM1 polynomial (catastrophic cancellation)
8. **7.3** LOGNP1 precision for small X
9. **4.1** ACOS identity near X=+/-1
10. **8.1** SINH via expm1 for large X
11. **1.2** Separate sin/cos coefficient sets

### Verification / Minor
12. **1.4** Align small-argument thresholds
13. **10.2** FREM tie-break verification
14. **12.2** Overflow/underflow bias verification
15. **11.1** Packed decimal completeness
<<<<<<< HEAD
16. **15.1-15.3** Denormal/unnormal input paths
=======
16. **15.1-15.3** Denormal/unnormal input paths
>>>>>>> main
