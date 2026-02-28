# DEF-PACKED-001 Completion Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the packed-decimal encode/decode paths to full MC68881 datasheet parity — handling all finite FP80 values, all 17 BCD digits, exponents up to +/-9999, OPERR for invalid BCD, and round-to-nearest-even.

**Architecture:** Replace the integer-only encoder and 9-digit decoder with unified FP80-arithmetic digit-extraction (encode) and FP80-accumulation (decode) paths. Wire OPERR through a new `force_invalid` exception signal. Fix rounding from half-up to banker's rounding.

**Tech Stack:** VHDL-2008, GHDL simulation, existing FP80 arithmetic functions (`mul_fp80`, `div_fp80`, `add_sub_fp80`, `fp80_to_int_trunc`, `fp80_from_int`).

**Test command:** `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`

**Key types and constants:**
- `packed96_t` = `std_logic_vector(95 downto 0)` — declared at `src/mc68881_top.vhd:288`
- `dec_digits_t` = `array(0 to 16) of natural range 0 to 9` — declared at `src/mc68881_top.vhd:289`
- `FP_EXP_BIAS` = 16383 — declared at `src/mc68881_pkg.vhd:10`
- FP80 10.0: use `fp80_from_int(10)` inline (no predefined constant)

---

### Task 1: Rewrite `fp80_to_packed96` — Unified FP80 Digit Extraction

**Files:**
- Modify: `src/mc68881_top.vhd:349-502` (replace entire function body)
- Delete: `src/mc68881_top.vhd:321-340` (`apply_packed_k_factor_fallback` — becomes dead code)

**Step 1: Delete `apply_packed_k_factor_fallback`**

Remove lines 321-340 entirely. This function is only called from the old `fp80_to_packed96` fallback path which will no longer exist.

**Step 2: Rewrite `fp80_to_packed96`**

Replace lines 349-502 with the following. The function signature stays the same. Special-case handling for zero/inf/NaN is preserved. The integer fast-path and fallback are replaced by a unified FP80 digit-extraction loop.

```vhdl
  function fp80_to_packed96(value : fp80_t; k_factor : integer) return packed96_t is
    variable packed : packed96_t := (others => '0');
    variable digits : dec_digits_t := (others => 0);
    variable k_clamped : integer := 0;
    variable keep_digits : integer := 17;
    variable carry : integer := 0;
    variable exp10 : integer := 0;
    variable exp_abs : natural := 0;
    variable exp0 : natural := 0;
    variable exp1 : natural := 0;
    variable exp2 : natural := 0;
    variable exp3 : natural := 0;
    variable abs_val : fp80_t := (others => '0');
    variable scaled : fp80_t := (others => '0');
    variable ten : fp80_t := fp80_from_int(10);
    variable digit_int : integer := 0;
    variable digit_fp : fp80_t := (others => '0');
    variable bin_exp : integer := 0;
    variable has_trailing : boolean := false;
    variable round_digit : natural := 0;
  begin
    packed(95) := value(FP_WIDTH-1);

    if fp80_is_zero(value) then
      return packed;
    end if;

    if fp80_is_inf(value) then
      packed(93 downto 92) := "11";
      packed(91 downto 88) := x"F";
      packed(87 downto 84) := x"F";
      packed(83 downto 80) := x"F";
      packed(79 downto 76) := x"F";
      return packed;
    end if;

    if fp80_is_nan(value) then
      packed(93 downto 92) := "11";
      packed(91 downto 88) := x"F";
      packed(87 downto 84) := x"F";
      packed(83 downto 80) := x"F";
      packed(79 downto 76) := x"F";
      packed(67 downto 64) := x"1";
      packed(63 downto 0) := (others => '1');
      return packed;
    end if;

    -- Take absolute value
    abs_val := value;
    abs_val(FP_WIDTH-1) := '0';

    -- Estimate decimal exponent from binary exponent
    -- log10(2) ~= 77/256 = 0.30078 (close enough for initial estimate)
    bin_exp := to_integer(unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH))) - FP_EXP_BIAS;
    if bin_exp >= 0 then
      exp10 := (bin_exp * 77) / 256;
    else
      exp10 := -(((-bin_exp) * 77 + 255) / 256);
    end if;

    -- Scale into [1.0, 10.0) by dividing/multiplying by 10
    scaled := abs_val;
    if exp10 > 0 then
      for i in 1 to 5000 loop
        exit when i > exp10;
        scaled := div_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
      end loop;
    elsif exp10 < 0 then
      for i in 1 to 5000 loop
        exit when i > -exp10;
        scaled := mul_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
      end loop;
    end if;

    -- Fine-tune: ensure scaled is in [1.0, 10.0)
    for i in 0 to 2 loop
      if compare_fp80(scaled, ten) >= 0 then
        scaled := div_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 + 1;
      elsif compare_fp80(scaled, FP80_ONE) < 0 then
        scaled := mul_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 - 1;
      else
        exit;
      end if;
    end loop;

    -- Extract 17 decimal digits via multiply-and-truncate
    for d in 0 to 16 loop
      digit_int := fp80_to_int_trunc(scaled);
      if digit_int < 0 then digit_int := 0; end if;
      if digit_int > 9 then digit_int := 9; end if;
      digits(d) := digit_int;
      digit_fp := fp80_from_int(digit_int);
      scaled := mul_fp80(
        add_sub_fp80(scaled, digit_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
        ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end loop;

    -- Apply k-factor rounding (round-to-nearest-even)
    k_clamped := clamp_integer(k_factor, -64, 17);
    if k_clamped > 0 then
      keep_digits := k_clamped;
    elsif k_clamped <= 0 then
      keep_digits := exp10 + 1 + (-k_clamped);
    end if;
    if keep_digits < 1 then
      keep_digits := 1;
    elsif keep_digits > 17 then
      keep_digits := 17;
    end if;

    if keep_digits < 17 then
      round_digit := digits(keep_digits);
      carry := 0;
      if round_digit > 5 then
        carry := 1;
      elsif round_digit = 5 then
        -- Check for trailing non-zero digits (above halfway)
        has_trailing := false;
        for idx in keep_digits + 1 to 16 loop
          if digits(idx) /= 0 then
            has_trailing := true;
          end if;
        end loop;
        if has_trailing then
          carry := 1;
        elsif digits(keep_digits - 1) mod 2 = 1 then
          carry := 1; -- exact halfway: round to even
        end if;
      end if;
      for idx in 16 downto 0 loop
        if idx < keep_digits then
          if carry = 1 then
            if digits(idx) = 9 then
              digits(idx) := 0;
            else
              digits(idx) := digits(idx) + 1;
              carry := 0;
            end if;
          end if;
        else
          digits(idx) := 0;
        end if;
      end loop;
      if carry = 1 then
        for idx in 16 downto 1 loop
          digits(idx) := digits(idx-1);
        end loop;
        digits(0) := 1;
        exp10 := exp10 + 1;
      end if;
    end if;

    -- Encode exponent
    if exp10 < 0 then
      packed(94) := '1';
      exp_abs := natural(-exp10);
    else
      packed(94) := '0';
      exp_abs := natural(exp10);
    end if;

    exp0 := exp_abs mod 10;
    exp1 := (exp_abs / 10) mod 10;
    exp2 := (exp_abs / 100) mod 10;
    exp3 := (exp_abs / 1000) mod 10;

    packed(93 downto 92) := "00";
    packed(91 downto 88) := bcd_digit(exp2);
    packed(87 downto 84) := bcd_digit(exp1);
    packed(83 downto 80) := bcd_digit(exp0);
    packed(79 downto 76) := bcd_digit(exp3);
    packed(75 downto 68) := (others => '0');
    packed(67 downto 64) := bcd_digit(digits(0));
    for idx in 0 to 15 loop
      packed(63 - idx*4 downto 60 - idx*4) := bcd_digit(digits(idx+1));
    end loop;
    return packed;
  end function;
```

**Step 3: Run tests — verify no regression**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: All tests PASS (existing integer encode tests should produce identical results).

**Step 4: Commit**

```
git add src/mc68881_top.vhd
git commit -m "Rewrite fp80_to_packed96 with unified FP80 digit extraction

Replace integer-only fast path and legacy fallback with a single FP80
multiply-and-truncate loop that handles all finite values. Implements
round-to-nearest-even for k-factor rounding. Delete dead
apply_packed_k_factor_fallback function."
```

---

### Task 2: Rewrite `packed_encode_is_inexact` to Match New Encoder

**Files:**
- Modify: `src/mc68881_top.vhd:507-570` (replace function body)

**Step 1: Rewrite `packed_encode_is_inexact`**

This function must mirror the new encoder's digit-extraction and rounding logic. Replace lines 507-570:

```vhdl
  function packed_encode_is_inexact(value : fp80_t; k_factor : integer) return boolean is
    variable digits : dec_digits_t := (others => 0);
    variable k_clamped : integer := 0;
    variable keep_digits : integer := 17;
    variable exp10 : integer := 0;
    variable abs_val : fp80_t := (others => '0');
    variable scaled : fp80_t := (others => '0');
    variable ten : fp80_t := fp80_from_int(10);
    variable digit_int : integer := 0;
    variable digit_fp : fp80_t := (others => '0');
    variable bin_exp : integer := 0;
  begin
    if fp80_is_zero(value) or fp80_is_inf(value) or fp80_is_nan(value) then
      return false;
    end if;

    abs_val := value;
    abs_val(FP_WIDTH-1) := '0';

    -- Estimate decimal exponent (mirrors encoder)
    bin_exp := to_integer(unsigned(abs_val(FP_WIDTH-2 downto FP_MANT_WIDTH))) - FP_EXP_BIAS;
    if bin_exp >= 0 then
      exp10 := (bin_exp * 77) / 256;
    else
      exp10 := -(((-bin_exp) * 77 + 255) / 256);
    end if;

    scaled := abs_val;
    if exp10 > 0 then
      for i in 1 to 5000 loop
        exit when i > exp10;
        scaled := div_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
      end loop;
    elsif exp10 < 0 then
      for i in 1 to 5000 loop
        exit when i > -exp10;
        scaled := mul_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
      end loop;
    end if;

    for i in 0 to 2 loop
      if compare_fp80(scaled, ten) >= 0 then
        scaled := div_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 + 1;
      elsif compare_fp80(scaled, FP80_ONE) < 0 then
        scaled := mul_fp80(scaled, ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
        exp10 := exp10 - 1;
      else
        exit;
      end if;
    end loop;

    -- Extract 17 digits (mirrors encoder)
    for d in 0 to 16 loop
      digit_int := fp80_to_int_trunc(scaled);
      if digit_int < 0 then digit_int := 0; end if;
      if digit_int > 9 then digit_int := 9; end if;
      digits(d) := digit_int;
      digit_fp := fp80_from_int(digit_int);
      scaled := mul_fp80(
        add_sub_fp80(scaled, digit_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
        ten, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end loop;

    -- Check if k-factor truncation loses non-zero digits
    k_clamped := clamp_integer(k_factor, -64, 17);
    if k_clamped > 0 then
      keep_digits := k_clamped;
    elsif k_clamped <= 0 then
      keep_digits := exp10 + 1 + (-k_clamped);
    end if;
    if keep_digits < 1 then
      keep_digits := 1;
    elsif keep_digits > 17 then
      keep_digits := 17;
    end if;

    if keep_digits < 17 then
      for idx in keep_digits to 16 loop
        if digits(idx) /= 0 then
          return true;
        end if;
      end loop;
    end if;

    return false;
  end function;
```

**Step 2: Run tests**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: All tests PASS.

**Step 3: Commit**

```
git add src/mc68881_top.vhd
git commit -m "Rewrite packed_encode_is_inexact to mirror new FP80 encoder"
```

---

### Task 3: Rewrite `packed96_to_fp80` — Full 17-Digit Decode

**Files:**
- Modify: `src/mc68881_top.vhd:579-666` (replace function body)

**Step 1: Rewrite `packed96_to_fp80`**

Replace lines 579-666. The function accumulates all 17 digits via FP80 arithmetic and scales with an unbounded exponent loop. Invalid BCD nibbles still return fallback (OPERR signaling is wired separately in Task 4).

```vhdl
  function packed96_to_fp80(packed : packed96_t; fallback : fp80_t) return fp80_t is
    variable decoded_value : fp80_t := fallback;
    variable mant_digits : dec_digits_t := (others => 0);
    variable exp0_i : integer := 0;
    variable exp1_i : integer := 0;
    variable exp2_i : integer := 0;
    variable exp3_i : integer := 0;
    variable exp10 : integer := 0;
    variable scale_exp : integer := 0;
    variable ten_fp80 : fp80_t := fp80_from_int(10);
    variable digit_fp : fp80_t := (others => '0');
    variable sign_m : std_logic := '0';
    variable idx : integer := 0;
    variable all_zero : boolean := true;
  begin
    sign_m := packed(95);

    -- Infinity/NaN: YY=11
    if packed(93 downto 92) = "11" then
      decoded_value := (others => '0');
      decoded_value(FP_WIDTH-1) := sign_m;
      decoded_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
      decoded_value(FP_MANT_WIDTH-1) := '1';
      if packed(67 downto 0) /= (67 downto 0 => '0') then
        decoded_value(FP_MANT_WIDTH-2 downto 0) := (others => '1');
      end if;
      return decoded_value;
    end if;

    -- Extract and validate exponent BCD nibbles
    exp0_i := bcd_to_natural(packed(83 downto 80));
    exp1_i := bcd_to_natural(packed(87 downto 84));
    exp2_i := bcd_to_natural(packed(91 downto 88));
    exp3_i := bcd_to_natural(packed(79 downto 76));
    if exp0_i < 0 or exp1_i < 0 or exp2_i < 0 or exp3_i < 0 then
      return fallback;
    end if;
    exp10 := exp3_i*1000 + exp2_i*100 + exp1_i*10 + exp0_i;
    if packed(94) = '1' then
      exp10 := -exp10;
    end if;

    -- Extract and validate all 17 mantissa digits
    idx := bcd_to_natural(packed(67 downto 64));
    if idx < 0 then
      return fallback;
    end if;
    mant_digits(0) := natural(idx);
    for nib_idx in 0 to 15 loop
      idx := bcd_to_natural(packed(63 - nib_idx*4 downto 60 - nib_idx*4));
      if idx < 0 then
        return fallback;
      end if;
      mant_digits(nib_idx+1) := natural(idx);
    end loop;

    -- Check for all-zero mantissa (packed zero)
    all_zero := true;
    for d in 0 to 16 loop
      if mant_digits(d) /= 0 then
        all_zero := false;
      end if;
    end loop;
    if all_zero then
      decoded_value := (others => '0');
      decoded_value(FP_WIDTH-1) := sign_m;
      return decoded_value;
    end if;

    -- Accumulate all 17 digits via FP80 arithmetic
    decoded_value := fp80_from_int(mant_digits(0));
    for d in 1 to 16 loop
      digit_fp := fp80_from_int(mant_digits(d));
      decoded_value := add_sub_fp80(
        mul_fp80(decoded_value, ten_fp80, FP_RND_NEAREST, FP_PREC_EXTENDED),
        digit_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end loop;

    -- Scale by 10^(exp10 - 16) to position the decimal point
    -- After accumulating 17 digits, the value is digit0*10^16 + ... + digit16.
    -- The packed representation means value = mantissa * 10^exp10 where
    -- mantissa = digit0.digit1...digit16, so we need to divide by 10^16
    -- then multiply by 10^exp10, net scale = exp10 - 16.
    scale_exp := exp10 - 16;
    if scale_exp > 0 then
      for step in 1 to 10000 loop
        exit when step > scale_exp;
        decoded_value := mul_fp80(decoded_value, ten_fp80, FP_RND_NEAREST, FP_PREC_EXTENDED);
      end loop;
    elsif scale_exp < 0 then
      for step in 1 to 10000 loop
        exit when step > -scale_exp;
        decoded_value := div_fp80(decoded_value, ten_fp80, FP_RND_NEAREST, FP_PREC_EXTENDED);
      end loop;
    end if;

    decoded_value(FP_WIDTH-1) := sign_m;
    return decoded_value;
  end function;
```

**Step 2: Run tests**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: All tests PASS. The existing decode test (line 885: `check_fp80(rd_full, fp80_from_int(1200000), ...)`) should still pass since 1200000 is within 17-digit/exponent range.

**Step 3: Commit**

```
git add src/mc68881_top.vhd
git commit -m "Rewrite packed96_to_fp80 with full 17-digit FP80 accumulation

Accumulate all 17 BCD mantissa digits via FP80 arithmetic instead of
9-digit integer path. Remove [-9,+9] scale exponent limit; now handles
full MC68881 exponent range (+/-9999)."
```

---

### Task 4: Wire OPERR Exception for Invalid BCD

**Files:**
- Modify: `src/mc68881_top.vhd` — add function, signal, variable, and wiring

**Step 1: Add `packed96_has_invalid_bcd` function**

Insert after the `packed96_to_fp80` function (after the `end function;` at what was line 666, now shifted). Add:

```vhdl
  -- Check if a packed-96 word contains invalid BCD nibbles (A-F).
  -- Skips check for YY=11 (infinity/NaN use non-BCD nibble encoding).
  function packed96_has_invalid_bcd(packed : packed96_t) return boolean is
  begin
    if packed(93 downto 92) = "11" then
      return false;
    end if;
    -- Check 4 exponent nibbles
    if bcd_to_natural(packed(91 downto 88)) < 0 then return true; end if;
    if bcd_to_natural(packed(87 downto 84)) < 0 then return true; end if;
    if bcd_to_natural(packed(83 downto 80)) < 0 then return true; end if;
    if bcd_to_natural(packed(79 downto 76)) < 0 then return true; end if;
    -- Check 17 mantissa nibbles
    if bcd_to_natural(packed(67 downto 64)) < 0 then return true; end if;
    for nib_idx in 0 to 15 loop
      if bcd_to_natural(packed(63 - nib_idx*4 downto 60 - nib_idx*4)) < 0 then
        return true;
      end if;
    end loop;
    return false;
  end function;
```

**Step 2: Add `exc_event_force_invalid_reg` signal**

At `src/mc68881_top.vhd:172` (after `exc_event_force_inexact_reg`), add:

```vhdl
  signal exc_event_force_invalid_reg : std_logic := '0';
```

**Step 3: Add signal to reset blocks**

At `src/mc68881_top.vhd:1796-1799` (reset block), add alongside the other force resets:

```vhdl
      exc_event_force_invalid_reg <= '0';
```

At `src/mc68881_top.vhd:1807-1810` (clock-edge reset block), add the same.

**Step 4: Add `move_exc_force_invalid` variable**

At `src/mc68881_top.vhd:1750` (after `move_exc_force_inexact`), add:

```vhdl
    variable move_exc_force_invalid : std_logic := '0';
```

And initialize it to '0' alongside the other force variables in the move path reset (search for `move_exc_force_inexact := '0'` around line 1872).

**Step 5: Wire into mem-to-reg packed decode path**

At `src/mc68881_top.vhd:1915-1919` (the `when "11" =>` packed decode case), add OPERR check:

```vhdl
                        when "11" =>
                          packed_word := operand_hi16_reg(0) & operand_reg(0);
                          if packed96_has_invalid_bcd(packed_word) then
                            move_exc_force_invalid := '1';
                          end if;
                          move_result := packed96_to_fp80(packed_word, operand_reg(0));
                          move_exc_enable := '1';
                          move_exc_result := move_result;
                          move_exc_opa := move_result;
```

**Step 6: Wire `move_exc_force_invalid` to register**

At `src/mc68881_top.vhd:2031-2033` (after `exc_event_force_inexact_reg` assignment), add:

```vhdl
                exc_event_force_invalid_reg <= move_exc_force_invalid;
```

**Step 7: Add `class_force_invalid` to exception classification**

At `src/mc68881_top.vhd:1372` (variable declarations), add:

```vhdl
    variable class_force_invalid : std_logic := '0';
```

At line ~1495 (reset alongside other class_force vars), add:

```vhdl
          class_force_invalid := '0';
```

At line ~1504 (assignment from registers), add:

```vhdl
          class_force_invalid := exc_event_force_invalid_reg;
```

At line ~1576 (after `class_force_inexact` usage, before BSUN), add:

```vhdl
        if class_force_invalid = '1' then
          exc_flags(FPSR_EXC_INVALID) := '1';
        end if;
```

**Step 8: Run tests**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: All tests PASS (no existing test uses invalid BCD nibbles).

**Step 9: Commit**

```
git add src/mc68881_top.vhd
git commit -m "Wire OPERR exception for invalid BCD nibbles in packed decode

Add packed96_has_invalid_bcd checker, exc_event_force_invalid_reg signal,
and route through exception classification to set FPSR EXC.INVALID when
a packed-decimal mem-to-reg decode encounters BCD nibbles A-F."
```

---

### Task 5: Add Non-Integer Encode/Decode Test Vectors

**Files:**
- Modify: `tb/tb_mc68881_fmove_fmovem.vhd` — insert tests after line 1017 (before FMOVECR tests)

**Step 1: Add non-integer encode test (1.25)**

Insert after line 1017 (`check_fp80(rd_full, x"7FFF8000000000000000", "FMOVE.P infinity round-trip");`):

```vhdl
    -- Non-integer packed encode: 1.25 with k=4
    report "FMOVE.P non-integer 1.25 encode" severity note;
    fp_val_a := x"3FFFA000000000000000"; -- FP80 1.25
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, fp_val_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, fp_val_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & fp_val_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPB_L, x"00000004"); -- static k=4
    cfg_word := make_move_cfg("10", 0, 0, "11", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    packed_src96 := make_packed96(rd_ex, rd_hi, rd_lo);
    report "FMOVE.P 1.25 packed=" & to_hstring(packed_src96) severity note;
    -- Expect: exp=0, digits 1.250 (k=4 keeps 4 digits)
    assert packed_src96(93 downto 92) = "00"
      report "FMOVE.P 1.25 should be finite (YY=00)"
      severity failure;
    assert packed_src96(67 downto 64) = x"1"
      report "FMOVE.P 1.25 int digit should be 1, got " &
             to_hstring(packed_src96(67 downto 64))
      severity failure;
    assert packed_src96(63 downto 60) = x"2" and
           packed_src96(59 downto 56) = x"5" and
           packed_src96(55 downto 52) = x"0"
      report "FMOVE.P 1.25 k=4 should produce digits 1.250"
      severity failure;
```

**Step 2: Add non-integer round-trip decode test**

Continuing after the encode test, decode the packed 1.25 back:

```vhdl
    -- Non-integer packed decode round-trip: decode 1.25 packed result
    report "FMOVE.P 1.25 decode round-trip" severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, rd_lo);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, rd_hi);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, rd_ex);
    cfg_word := make_move_cfg("00", 0, 0, "11", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.P 1.25 decoded=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, x"3FFFA000000000000000", "FMOVE.P 1.25 round-trip");
```

**Step 3: Add invalid BCD OPERR test**

```vhdl
    -- Invalid BCD OPERR test: nibble=0xA in mantissa
    report "FMOVE.P invalid BCD OPERR test" severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000"); -- clear FPSR
    -- Construct packed word with invalid nibble: int_digit=0xA
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & x"000A"); -- exp nibbles=0, int_digit=A (invalid)
    cfg_word := make_move_cfg("00", 0, 0, "11", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FMOVE.P invalid BCD FPSR=" & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_EXC_BASE + 4) = '1'
      report "FMOVE.P invalid BCD should set EXC.INVALID, FPSR=" & to_hstring(rd_lo)
      severity failure;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000"); -- clean up
```

**Step 4: Add round-to-nearest-even test**

```vhdl
    -- Round-to-nearest-even: 1500 with k=1 (halfway, even kept digit=2 -> no round)
    -- 1500 encoded with k=1: digit0=1, round_digit=5, trailing=00 -> kept=1 is odd -> round up to 2
    -- Actually: keep 1 digit, exp10=3, digit0=1, digit1=5, digits 2-3=00
    -- kept digit is digits(0)=1, which is ODD, so banker's rounds UP -> digits(0)=2, exp10=3
    -- Result: 2.000e3 = 2000
    report "FMOVE.P round-to-nearest-even test" severity note;
    fp_val_a := fp80_from_int(1500);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, fp_val_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, fp_val_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & fp_val_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPB_L, x"00000001"); -- static k=1
    cfg_word := make_move_cfg("10", 0, 0, "11", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    packed_src96 := make_packed96(rd_ex, rd_hi, rd_lo);
    report "FMOVE.P 1500 k=1 packed=" & to_hstring(packed_src96) severity note;
    -- 1500 k=1: keep 1 digit, halfway. digit0=1 (odd) -> round up to 2, exp=3
    assert packed_src96(67 downto 64) = x"2"
      report "FMOVE.P 1500 k=1 RTE: odd digit should round up to 2, got " &
             to_hstring(packed_src96(67 downto 64))
      severity failure;

    -- 2500 with k=1: digit0=2 (even), halfway -> no round
    fp_val_a := fp80_from_int(2500);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, fp_val_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, fp_val_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & fp_val_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPB_L, x"00000001"); -- static k=1
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    packed_src96 := make_packed96(rd_ex, rd_hi, rd_lo);
    report "FMOVE.P 2500 k=1 packed=" & to_hstring(packed_src96) severity note;
    -- 2500 k=1: keep 1 digit, halfway. digit0=2 (even) -> no round, stays 2, exp=3
    assert packed_src96(67 downto 64) = x"2"
      report "FMOVE.P 2500 k=1 RTE: even digit should stay 2, got " &
             to_hstring(packed_src96(67 downto 64))
      severity failure;
```

**Step 5: Run tests**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: All tests PASS including new non-integer, OPERR, and RTE tests.

**Step 6: Commit**

```
git add tb/tb_mc68881_fmove_fmovem.vhd
git commit -m "Add packed-decimal tests: non-integer, OPERR, round-to-nearest-even

Test 1.25 encode/decode round-trip, invalid BCD OPERR exception,
and banker's rounding for exact-halfway cases (odd rounds up, even
stays)."
```

---

### Task 6: Update Documentation and Close DEF-PACKED-001

**Files:**
- Modify: `docs/fpu-progress-checklist.md`

**Step 1: Update B8 status**

Change `[~] B8` description to mark the decimal conversion items as done. Update the "Remaining" line to remove the completed items. If all items are done, change `[~]` to `[x]`.

**Step 2: Close DEF-PACKED-001**

Move DEF-PACKED-001 from "Open Defects" to "Closed Defects" with resolution summary noting:
- Full FP80 digit-extraction encoder replaces integer-only path
- Full 17-digit FP80 accumulation decoder replaces 9-digit integer path
- OPERR exception wired for invalid BCD nibbles
- Round-to-nearest-even replaces half-up

**Step 3: Update README Known defects section**

Remove `DEF-PACKED-001` from the open defects list in `README.md`.

**Step 4: Run tests one final time**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: All tests PASS.

**Step 5: Commit**

```
git add docs/fpu-progress-checklist.md README.md
git commit -m "Close DEF-PACKED-001: full packed-decimal conversion complete"
```

---
