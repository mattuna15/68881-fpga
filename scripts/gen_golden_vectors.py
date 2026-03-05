#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime, timezone
import mpmath as mp

mp.mp.dps = 200

FP80_EXP_BIAS = 16383

ROUND_NEAREST = "RN"
ROUND_ZERO = "RZ"
ROUND_PLUS_INF = "RP"
ROUND_MINUS_INF = "RM"


def round_ties_even(v: mp.mpf) -> int:
    base = int(mp.floor(v))
    frac = v - base
    if frac > mp.mpf("0.5"):
        return base + 1
    if frac < mp.mpf("0.5"):
        return base
    return base if (base % 2 == 0) else (base + 1)


def fp80_hex(x: mp.mpf, rnd: str = ROUND_NEAREST) -> str:
    if mp.isnan(x):
        return "7FFFC000000000000001"
    if mp.isinf(x):
        return ("7FFF" if x > 0 else "FFFF") + "8000000000000000"
    if x == 0:
        # Preserve negative zero sign
        if mp.sign(x) < 0:
            return "80000000000000000000"
        return "00000000000000000000"

    sign = 1 if x < 0 else 0
    a = -x if x < 0 else x
    e = int(mp.floor(mp.log(a, 2)))
    m = a / mp.power(2, e)
    q = m * mp.power(2, 63)
    if rnd == ROUND_NEAREST:
        mant = round_ties_even(q)
    elif rnd == ROUND_ZERO:
        mant = int(mp.floor(q))
    elif rnd == ROUND_PLUS_INF:
        mant = int(mp.ceil(q)) if sign == 0 else int(mp.floor(q))
    elif rnd == ROUND_MINUS_INF:
        mant = int(mp.floor(q)) if sign == 0 else int(mp.ceil(q))
    else:
        raise ValueError(f"Unknown rounding mode: {rnd}")
    if mant == (1 << 64):
        mant >>= 1
        e += 1

    exp_field = e + FP80_EXP_BIAS
    if exp_field <= 0:
        raise ValueError("Subnormal/underflow not supported by this generator")
    if exp_field >= 0x7FFF:
        return ("7FFF" if sign == 0 else "FFFF") + "8000000000000000"

    bits = (sign << 79) | (exp_field << 64) | mant
    return f"{bits:020X}"


def fp80_hex_safe(x: mp.mpf, rnd: str = ROUND_NEAREST) -> str:
    """Like fp80_hex but returns zero hex for subnormal/underflow results."""
    try:
        return fp80_hex(x, rnd)
    except ValueError as e:
        if "Subnormal" in str(e):
            return "00000000000000000000"
        raise  # Re-raise unknown rounding mode errors etc.


def generate_torture_vectors() -> dict[str, str]:
    """Generate systematic edge-case vectors for the torture testbench.

    Returns a dict mapping constant names (TV_ prefix) to 20-char hex strings.
    """
    tv: dict[str, str] = {}

    # ----------------------------------------------------------------
    # Argument constants
    # ----------------------------------------------------------------
    one    = mp.mpf("1")
    two    = mp.mpf("2")
    three  = mp.mpf("3")
    half   = mp.mpf("0.5")
    third  = one / three
    seventh = one / mp.mpf("7")
    tiny   = mp.power(2, -16382)          # min positive normal
    huge   = mp.power(2, 16383)           # near-max exponent
    small  = mp.power(2, -40)
    pi_val = mp.pi
    e_val  = mp.e
    # largest finite: 2^16383 * (2 - 2^-63)
    near_max = mp.power(2, 16383) * (two - mp.power(2, -63))
    cancel_a = one + mp.power(2, -63)     # 1.0000000000000001 (approx)
    cancel_b = one

    args = {
        "TV_ARG_ONE":       one,
        "TV_ARG_TWO":       two,
        "TV_ARG_THREE":     three,
        "TV_ARG_HALF":      half,
        "TV_ARG_THIRD":     third,
        "TV_ARG_SEVENTH":   seventh,
        "TV_ARG_TINY":      tiny,
        "TV_ARG_HUGE":      huge,
        "TV_ARG_SMALL":     small,
        "TV_ARG_PI":        pi_val,
        "TV_ARG_E":         e_val,
        "TV_ARG_NEAR_MAX":  near_max,
        "TV_ARG_CANCEL_A":  cancel_a,
        "TV_ARG_CANCEL_B":  cancel_b,
    }
    for name, val in args.items():
        tv[name] = fp80_hex(val)

    # Helper: emit result for all 4 rounding modes
    rnd_modes = [ROUND_NEAREST, ROUND_ZERO, ROUND_PLUS_INF, ROUND_MINUS_INF]
    rnd_suffixes = ["_RN", "_RZ", "_RP", "_RM"]

    def emit_4rm(prefix: str, result: mp.mpf) -> None:
        for mode, sfx in zip(rnd_modes, rnd_suffixes):
            tv[prefix + sfx] = fp80_hex_safe(result, mode)

    # ----------------------------------------------------------------
    # ADD (a + b), all 4 rounding modes
    # ----------------------------------------------------------------
    emit_4rm("TV_ADD_TINY_TINY",      tiny + tiny)
    emit_4rm("TV_ADD_HUGE_ONE",       huge + one)
    emit_4rm("TV_ADD_CANCEL",         cancel_a + (-cancel_b))
    emit_4rm("TV_ADD_THIRD_SEVENTH",  third + seventh)
    emit_4rm("TV_ADD_ONE_HALF",       one + half)
    emit_4rm("TV_ADD_NEG_NEG",        (-three) + (-two))

    # ----------------------------------------------------------------
    # SUB (a - b), all 4 rounding modes
    # ----------------------------------------------------------------
    emit_4rm("TV_SUB_CANCEL_NEAR",    cancel_a - cancel_b)
    emit_4rm("TV_SUB_HUGE_HUGE",      huge - huge)
    emit_4rm("TV_SUB_ONE_THIRD",      one - third)
    emit_4rm("TV_SUB_TINY_SMALL",     tiny - small)
    emit_4rm("TV_SUB_THREE_TWO",      three - two)

    # ----------------------------------------------------------------
    # MUL (a * b), all 4 rounding modes
    # ----------------------------------------------------------------
    emit_4rm("TV_MUL_THIRD_THREE",    third * three)
    emit_4rm("TV_MUL_SEVENTH_SEVEN",  seventh * mp.mpf("7"))
    emit_4rm("TV_MUL_TINY_HALF",      tiny * half)
    emit_4rm("TV_MUL_HUGE_TWO",       huge * two)
    emit_4rm("TV_MUL_PI_E",           pi_val * e_val)
    emit_4rm("TV_MUL_NEG_POS",        (-three) * two)

    # ----------------------------------------------------------------
    # DIV (a / b), all 4 rounding modes
    # ----------------------------------------------------------------
    emit_4rm("TV_DIV_ONE_THREE",      one / three)
    emit_4rm("TV_DIV_ONE_SEVEN",      one / mp.mpf("7"))
    emit_4rm("TV_DIV_ONE_TEN",        one / mp.mpf("10"))
    emit_4rm("TV_DIV_PI_E",           pi_val / e_val)
    emit_4rm("TV_DIV_TINY_TWO",       tiny / two)
    emit_4rm("TV_DIV_NEG_POS",        (-one) / three)

    # ----------------------------------------------------------------
    # SQRT (monadic), all 4 rounding modes
    # ----------------------------------------------------------------
    emit_4rm("TV_SQRT_TWO",           mp.sqrt(two))
    emit_4rm("TV_SQRT_THREE",         mp.sqrt(three))
    emit_4rm("TV_SQRT_HALF",          mp.sqrt(half))
    emit_4rm("TV_SQRT_PI",            mp.sqrt(pi_val))
    emit_4rm("TV_SQRT_TINY",          mp.sqrt(tiny))
    emit_4rm("TV_SQRT_HUGE",          mp.sqrt(huge))
    emit_4rm("TV_SQRT_NEAR_MAX",      mp.sqrt(near_max))

    # ----------------------------------------------------------------
    # Trig argument constants (used by VHDL TB)
    # ----------------------------------------------------------------
    trig_args = {
        "TV_TRIG_ARG_0":          mp.mpf("0"),
        "TV_TRIG_ARG_TINY":       mp.power(2, -60),
        "TV_TRIG_ARG_0P1":        mp.mpf("0.1"),
        "TV_TRIG_ARG_0P5":        half,
        "TV_TRIG_ARG_1":          one,
        "TV_TRIG_ARG_1P5":        mp.mpf("1.5"),
        "TV_TRIG_ARG_PI_4":       pi_val / 4,
        "TV_TRIG_ARG_PI_2_NEAR":  pi_val / 2 - mp.power(2, -40),
        "TV_TRIG_ARG_PI":         pi_val,
        "TV_TRIG_ARG_2PI":        two * pi_val,
        "TV_TRIG_ARG_10":         mp.mpf("10"),
        "TV_TRIG_ARG_100":        mp.mpf("100"),
        "TV_TRIG_ARG_1234567":    mp.mpf("1234567"),
        "TV_TRIG_ARG_NEG_0P7":    mp.mpf("-0.7"),
        "TV_TRIG_ARG_NEG_2P3":    mp.mpf("-2.3"),
    }
    for name, val in trig_args.items():
        tv[name] = fp80_hex(val)

    # Helper: emit round-to-nearest only
    def emit_rn(prefix: str, result: mp.mpf) -> None:
        tv[prefix] = fp80_hex_safe(result)

    # ----------------------------------------------------------------
    # SIN -- trig arg set
    # ----------------------------------------------------------------
    sin_cases = {
        "0": mp.mpf("0"), "TINY": mp.power(2, -60), "0P1": mp.mpf("0.1"),
        "0P5": half, "1": one, "1P5": mp.mpf("1.5"),
        "PI_4": pi_val / 4, "PI_2_NEAR": pi_val / 2 - mp.power(2, -40),
        "PI": pi_val, "2PI": two * pi_val, "10": mp.mpf("10"),
        "100": mp.mpf("100"), "1234567": mp.mpf("1234567"),
        "NEG_0P7": mp.mpf("-0.7"), "NEG_2P3": mp.mpf("-2.3"),
    }
    for sfx, arg in sin_cases.items():
        emit_rn(f"TV_SIN_{sfx}", mp.sin(arg))

    # ----------------------------------------------------------------
    # COS -- trig arg set
    # ----------------------------------------------------------------
    for sfx, arg in sin_cases.items():
        emit_rn(f"TV_COS_{sfx}", mp.cos(arg))

    # ----------------------------------------------------------------
    # TAN -- trig arg set
    # ----------------------------------------------------------------
    for sfx, arg in sin_cases.items():
        emit_rn(f"TV_TAN_{sfx}", mp.tan(arg))

    # ----------------------------------------------------------------
    # ATAN
    # ----------------------------------------------------------------
    atan_cases = {
        "0": mp.mpf("0"), "0P5": half, "1": one, "2": two,
        "10": mp.mpf("10"), "100": mp.mpf("100"),
        "NEG_1": mp.mpf("-1"), "NEG_2": mp.mpf("-2"),
    }
    for sfx, arg in atan_cases.items():
        emit_rn(f"TV_ATAN_{sfx}", mp.atan(arg))

    # ----------------------------------------------------------------
    # ETOX (e^x)
    # ----------------------------------------------------------------
    etox_cases = {
        "0": mp.mpf("0"), "0P5": half, "1": one, "2": two,
        "NEG_1": mp.mpf("-1"), "NEG_10": mp.mpf("-10"),
        "10": mp.mpf("10"), "0P01": mp.mpf("0.01"),
    }
    for sfx, arg in etox_cases.items():
        emit_rn(f"TV_ETOX_{sfx}", mp.exp(arg))

    # ----------------------------------------------------------------
    # ETOXM1 (e^x - 1)
    # ----------------------------------------------------------------
    etoxm1_cases = {
        "0": mp.mpf("0"), "TINY": mp.power(2, -60),
        "0P01": mp.mpf("0.01"), "0P5": half, "1": one,
    }
    for sfx, arg in etoxm1_cases.items():
        emit_rn(f"TV_ETOXM1_{sfx}", mp.expm1(arg))

    # ----------------------------------------------------------------
    # LOGN (ln)
    # ----------------------------------------------------------------
    logn_cases = {
        "1": one, "2": two, "E": e_val, "10": mp.mpf("10"),
        "0P5": half, "1P01": mp.mpf("1.01"), "HUGE": huge, "TINY": tiny,
    }
    for sfx, arg in logn_cases.items():
        emit_rn(f"TV_LOGN_{sfx}", mp.log(arg))

    # ----------------------------------------------------------------
    # LOGNP1 (ln(1+x))
    # ----------------------------------------------------------------
    lognp1_cases = {
        "0": mp.mpf("0"), "TINY": mp.power(2, -60),
        "0P01": mp.mpf("0.01"), "0P5": half, "1": one,
    }
    for sfx, arg in lognp1_cases.items():
        emit_rn(f"TV_LOGNP1_{sfx}", mp.log1p(arg))

    # ----------------------------------------------------------------
    # LOG10
    # ----------------------------------------------------------------
    log10_cases = {
        "1": one, "10": mp.mpf("10"), "100": mp.mpf("100"),
        "0P5": half, "E": e_val,
    }
    for sfx, arg in log10_cases.items():
        emit_rn(f"TV_LOG10_{sfx}", mp.log10(arg))

    # ----------------------------------------------------------------
    # LOG2
    # ----------------------------------------------------------------
    log2_cases = {
        "1": one, "2": two, "4": mp.mpf("4"), "0P5": half,
        "E": e_val, "10": mp.mpf("10"),
    }
    ln2 = mp.log(two)
    for sfx, arg in log2_cases.items():
        emit_rn(f"TV_LOG2_{sfx}", mp.log(arg) / ln2)

    # ----------------------------------------------------------------
    # TWOTOX (2^x)
    # ----------------------------------------------------------------
    twotox_cases = {
        "0": mp.mpf("0"), "1": one, "0P5": half,
        "NEG_1": mp.mpf("-1"), "10": mp.mpf("10"),
        "0P25": mp.mpf("0.25"),
    }
    for sfx, arg in twotox_cases.items():
        emit_rn(f"TV_TWOTOX_{sfx}", mp.power(2, arg))

    # ----------------------------------------------------------------
    # TENTOX (10^x)
    # ----------------------------------------------------------------
    tentox_cases = {
        "0": mp.mpf("0"), "1": one, "0P5": half,
        "NEG_1": mp.mpf("-1"), "2": two, "NEG_2": mp.mpf("-2"),
    }
    for sfx, arg in tentox_cases.items():
        emit_rn(f"TV_TENTOX_{sfx}", mp.power(10, arg))

    # ----------------------------------------------------------------
    # ASIN
    # ----------------------------------------------------------------
    asin_cases = {
        "0": mp.mpf("0"), "0P5": half, "NEG_0P5": -half,
        "0P9": mp.mpf("0.9"), "TINY": mp.power(2, -60),
    }
    for sfx, arg in asin_cases.items():
        emit_rn(f"TV_ASIN_{sfx}", mp.asin(arg))

    # ----------------------------------------------------------------
    # ACOS
    # ----------------------------------------------------------------
    acos_cases = {
        "0": mp.mpf("0"), "0P5": half, "NEG_0P5": -half,
        "1": one, "NEG_1": mp.mpf("-1"),
    }
    for sfx, arg in acos_cases.items():
        emit_rn(f"TV_ACOS_{sfx}", mp.acos(arg))

    # ----------------------------------------------------------------
    # SINH
    # ----------------------------------------------------------------
    sinh_cases = {
        "0": mp.mpf("0"), "0P5": half, "1": one,
        "NEG_1": mp.mpf("-1"), "3": three,
    }
    for sfx, arg in sinh_cases.items():
        emit_rn(f"TV_SINH_{sfx}", mp.sinh(arg))

    # ----------------------------------------------------------------
    # COSH
    # ----------------------------------------------------------------
    cosh_cases = {
        "0": mp.mpf("0"), "0P5": half, "1": one,
        "NEG_1": mp.mpf("-1"), "3": three,
    }
    for sfx, arg in cosh_cases.items():
        emit_rn(f"TV_COSH_{sfx}", mp.cosh(arg))

    # ----------------------------------------------------------------
    # TANH
    # ----------------------------------------------------------------
    tanh_cases = {
        "0": mp.mpf("0"), "0P5": half, "1": one,
        "NEG_1": mp.mpf("-1"), "3": three,
    }
    for sfx, arg in tanh_cases.items():
        emit_rn(f"TV_TANH_{sfx}", mp.tanh(arg))

    # ----------------------------------------------------------------
    # ATANH
    # ----------------------------------------------------------------
    atanh_cases = {
        "0": mp.mpf("0"), "0P5": half, "NEG_0P5": -half,
        "0P9": mp.mpf("0.9"), "TINY": mp.power(2, -60),
    }
    for sfx, arg in atanh_cases.items():
        emit_rn(f"TV_ATANH_{sfx}", mp.atanh(arg))

    return tv


def fint_nearest_even(x: mp.mpf) -> mp.mpf:
    sign = -1 if x < 0 else 1
    a = -x if x < 0 else x
    n = int(mp.floor(a))
    frac = a - n
    if frac > mp.mpf("0.5"):
        n += 1
    elif frac == mp.mpf("0.5") and (n % 2 == 1):
        n += 1
    return mp.mpf(sign * n)


def fintrz(x: mp.mpf) -> mp.mpf:
    return mp.floor(x) if x >= 0 else mp.ceil(x)


def main() -> None:
    c = {
        "P0_5": mp.mpf("0.5"),
        "P0_6": mp.mpf("0.6"),
        "P0_75": mp.mpf("0.75"),
        "P0_9": mp.mpf("0.9"),
        "P1_1": mp.mpf("1.1"),
        "P1_25": mp.mpf("1.25"),
        "P1_7": mp.mpf("1.7"),
        "P2_4": mp.mpf("2.4"),
        "P3_7": mp.mpf("3.7"),
        "P9": mp.mpf("9.0"),
        "P12_5": mp.mpf("12.5"),
        "M0_7": mp.mpf("-0.7"),
        "M2_3": mp.mpf("-2.3"),
    }

    vals = {
        "GV_ARG_M2P3": c["M2_3"],
        "GV_ARG_M0P7": c["M0_7"],
        "GV_ARG_0P5": c["P0_5"],
        "GV_ARG_0P6": c["P0_6"],
        "GV_ARG_0P75": c["P0_75"],
        "GV_ARG_0P9": c["P0_9"],
        "GV_ARG_1P1": c["P1_1"],
        "GV_ARG_1P25": c["P1_25"],
        "GV_ARG_1P7": c["P1_7"],
        "GV_ARG_2": mp.mpf("2.0"),
        "GV_ARG_2P4": c["P2_4"],
        "GV_ARG_3P7": c["P3_7"],
        "GV_ARG_12P5": c["P12_5"],
        "GV_ARG_1234567": mp.mpf("1234567.0"),
        "GV_ARG_M2": mp.mpf("-2.0"),
        "GV_ADD_3P7_2P4": c["P3_7"] + c["P2_4"],
        "GV_SUB_M2P3_0P6": c["M2_3"] - c["P0_6"],
        "GV_MUL_3P7_2P4": c["P3_7"] * c["P2_4"],
        "GV_DIV_12P5_M0P7": c["P12_5"] / c["M0_7"],
        "GV_SQRT_9": mp.sqrt(c["P9"]),
        "GV_ABS_M2P3": mp.fabs(c["M2_3"]),
        "GV_NEG_1P1": -c["P1_1"],
        "GV_INTRZ_M2P3": fintrz(c["M2_3"]),
        "GV_INT_1P7": fint_nearest_even(c["P1_7"]),
        "GV_SIN_1P1": mp.sin(c["P1_1"]),
        "GV_COS_M2P3": mp.cos(c["M2_3"]),
        "GV_TAN_0P9": mp.tan(c["P0_9"]),
        "GV_ETOX_0P75": mp.e ** c["P0_75"],
        "GV_LOGN_1P25": mp.log(c["P1_25"]),
        "GV_TWOTOX_0P75": mp.power(2, c["P0_75"]),
        "GV_TENTOX_0P5": mp.power(10, c["P0_5"]),
        "GV_ATAN_2": mp.atan(mp.mpf("2.0")),
        "GV_ATAN_M2": mp.atan(mp.mpf("-2.0")),
        "GV_TANH_0P75": mp.tanh(c["P0_75"]),
        "GV_SIN_1234567": mp.sin(mp.mpf("1234567.0")),
        "GV_COS_1234567": mp.cos(mp.mpf("1234567.0")),
        "GV_TAN_1234567": mp.tan(mp.mpf("1234567.0")),
    }

    # Convert mpf values to hex strings
    hex_vals: dict[str, str] = {}
    for name, value in vals.items():
        hex_vals[name] = fp80_hex(value)

    # Merge torture vectors (already hex strings)
    tv = generate_torture_vectors()
    hex_vals.update(tv)

    lines = []
    lines.append("library ieee;")
    lines.append("use ieee.std_logic_1164.all;")
    lines.append("use ieee.numeric_std.all;")
    lines.append("")
    lines.append("use work.mc68881_pkg.all;")
    lines.append("")
    lines.append("package mc68881_golden_vectors_pkg is")
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    lines.append(f"  -- Generated by scripts/gen_golden_vectors.py at {ts}.")
    lines.append("  -- Source: high-precision mpmath, rounded to IEEE-754 80-bit extended.")
    for name, hx in hex_vals.items():
        lines.append(f'  constant {name} : fp80_t := x"{hx}";')
    lines.append("end package mc68881_golden_vectors_pkg;")
    lines.append("")

    out_path = "tb/mc68881_golden_vectors_pkg.vhd"
    with open(out_path, "w", encoding="ascii", newline="\n") as f:
        f.write("\n".join(lines))

    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
