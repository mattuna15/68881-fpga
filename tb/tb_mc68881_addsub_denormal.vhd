-- Regression for GitHub issue #73: FADD/FSUB denormal results must be rounded
-- exactly once, at the denormal bit position.
--
-- Background: in extended precision an add/sub result in the denormal range is
-- always exact (every operand is a multiple of the smallest denormal), so the
-- double rounding only becomes visible when FPCR precision is single/double.
-- ST_NORM_ROUND used to round at the normal-precision position and then
-- plain-shift the rounded mantissa right, discarding the bits that fell off.
--
-- Notation: den(m) is a positive denormal with exponent field 0 and mantissa
-- field m (value m * 2^-16445).  Single precision keeps field bits 63..40
-- (guard = bit 39); double precision keeps bits 63..11 (guard = bit 10).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_addsub_denormal is
end entity tb_mc68881_addsub_denormal;

architecture sim of tb_mc68881_addsub_denormal is
  signal clk        : std_logic := '0';
  signal reset_n    : std_logic := '0';
  signal start      : std_logic := '0';
  signal op_sel     : fpu_op_t := FPU_OP_NOP;
  signal round_mode : fp_round_mode_t := FP_RND_NEAREST;
  signal round_prec : fp_round_prec_t := FP_PREC_EXTENDED;
  signal a_in       : fp80_t := (others => '0');
  signal b_in       : fp80_t := (others => '0');
  signal result     : fp80_t;
  signal aux_result : fp80_t;
  signal valid      : std_logic;
  signal aux_valid  : std_logic;
  signal quotient_valid : std_logic;
  signal quotient_byte  : std_logic_vector(7 downto 0);
  signal flag_divzero   : std_logic;
  signal busy       : std_logic;

  constant CLK_PERIOD : time := 10 ns;

  -- Positive denormal: exp field 0, given 64-bit mantissa field.
  function den(m : std_logic_vector(63 downto 0)) return fp80_t is
  begin
    return x"0000" & m;
  end function;

  -- Smallest normal: exp field 1, mantissa 1.000...0.
  constant MIN_NORMAL : fp80_t := x"0001" & x"8000000000000000";
begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.mc68881_alu
    port map (
      clk    => clk,
      reset_n => reset_n,
      start  => start,
      op_sel => op_sel,
      round_mode => round_mode,
      round_prec => round_prec,
      a_in   => a_in,
      b_in   => b_in,
      result => result,
      valid  => valid,
      busy   => busy,
      quotient_byte => quotient_byte,
      quotient_valid => quotient_valid,
      aux_result => aux_result,
      aux_valid => aux_valid,
      flag_divzero => flag_divzero,
      packed_fp_mul_start  => '0',
      packed_fp_mul_a      => (others => '0'),
      packed_fp_mul_b      => (others => '0'),
      packed_fp_mul_done   => open,
      packed_fp_mul_result => open,
      packed_fp_add_start  => '0',
      packed_fp_add_a      => (others => '0'),
      packed_fp_add_b      => (others => '0'),
      packed_fp_add_sub    => false,
      packed_fp_add_done   => open,
      packed_fp_add_result => open,
      save_req       => '0',
      save_data      => open,
      save_addr      => 0,
      restore_req    => '0',
      restore_data   => (others => '0'),
      restore_addr   => 0,
      restore_wr     => '0'
    );

  process
    variable failures : natural := 0;

    procedure run_case(
      constant op       : in fpu_op_t;
      constant prec     : in fp_round_prec_t;
      constant mode     : in fp_round_mode_t;
      constant a        : in fp80_t;
      constant b        : in fp80_t;
      constant expected : in fp80_t;
      constant name     : in string
    ) is
    begin
      op_sel     <= op;
      round_prec <= prec;
      round_mode <= mode;
      a_in       <= a;
      b_in       <= b;
      start      <= '1';
      wait until rising_edge(clk);
      start      <= '0';
      wait until valid = '1';
      wait for 0 ns;
      report name & ": a=" & to_hstring(a) & " b=" & to_hstring(b) &
             " expected=" & to_hstring(expected) & " got=" & to_hstring(result)
        severity note;
      if result /= expected then
        report "MISMATCH " & name & " expected=" & to_hstring(expected) &
               " got=" & to_hstring(result)
          severity error;
        failures := failures + 1;
      end if;
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;
  begin
    reset_n <= '0';
    wait for 4 * CLK_PERIOD;
    reset_n <= '1';
    wait for 4 * CLK_PERIOD;

    -- ===================== single precision =====================
    -- Sum = 2^41 + 2^39 + 1: guard=1 and sticky=1 at the denormal position,
    -- so round-to-nearest must round up to 2^41 + 2^40.  The old code left
    -- 2^41 + 2^39 (a value that is not even representable in single).
    run_case(FPU_OP_ADD, FP_PREC_SINGLE, FP_RND_NEAREST,
             den(x"0000028000000000"), den(x"0000000000000001"),
             den(x"0000030000000000"), "single RN guard+sticky rounds up");

    -- Sum = 2^41 + 2^39: exact tie, kept LSB (bit 40) is 0 -> ties to even.
    run_case(FPU_OP_ADD, FP_PREC_SINGLE, FP_RND_NEAREST,
             den(x"0000024000000000"), den(x"0000004000000000"),
             den(x"0000020000000000"), "single RN tie to even (down)");

    -- Sum = 2^41 + 2^40 + 2^39: exact tie, kept LSB is 1 -> rounds up.
    run_case(FPU_OP_ADD, FP_PREC_SINGLE, FP_RND_NEAREST,
             den(x"0000034000000000"), den(x"0000004000000000"),
             den(x"0000040000000000"), "single RN tie to even (up)");

    -- Round toward +inf with only sticky bits set below the kept position.
    run_case(FPU_OP_ADD, FP_PREC_SINGLE, FP_RND_PLUS_INF,
             den(x"0000020000000001"), den(x"0000000000000001"),
             den(x"0000030000000000"), "single RP sticky rounds up");

    -- Round toward zero must truncate to the single-precision position.
    run_case(FPU_OP_ADD, FP_PREC_SINGLE, FP_RND_ZERO,
             den(x"0000028000000000"), den(x"0000000000000001"),
             den(x"0000020000000000"), "single RZ truncates");

    -- Rounding up carries out of the denormal range: result is the smallest
    -- normal, not an out-of-range denormal mantissa.
    -- Sum = 2^63 - 2^40 + 2^39 (tie, kept LSB 1) -> 2^63 -> MIN_NORMAL.
    run_case(FPU_OP_ADD, FP_PREC_SINGLE, FP_RND_NEAREST,
             den(x"7FFFFF4000000000"), den(x"0000004000000000"),
             MIN_NORMAL, "single RN carry into smallest normal");

    -- ===================== double precision =====================
    -- Sum = 2^41 + 2^10 + 1: guard=1, sticky=1 -> up to 2^41 + 2^11.
    run_case(FPU_OP_ADD, FP_PREC_DOUBLE, FP_RND_NEAREST,
             den(x"0000020000000400"), den(x"0000000000000001"),
             den(x"0000020000000800"), "double RN guard+sticky rounds up");

    -- Sum = 2^41 + 2^10: tie, kept LSB (bit 11) is 0 -> even (down).
    run_case(FPU_OP_ADD, FP_PREC_DOUBLE, FP_RND_NEAREST,
             den(x"0000020000000200"), den(x"0000000000000200"),
             den(x"0000020000000000"), "double RN tie to even (down)");

    -- Sum = 2^41 + 2^11 + 2^10: tie, kept LSB is 1 -> up to 2^41 + 2^12.
    run_case(FPU_OP_ADD, FP_PREC_DOUBLE, FP_RND_NEAREST,
             den(x"0000020000000A00"), den(x"0000000000000200"),
             den(x"0000020000001000"), "double RN tie to even (up)");

    -- ===================== extended precision =====================
    -- Denormal results are exact in extended precision; these guard the
    -- behaviour the fix must preserve.
    run_case(FPU_OP_ADD, FP_PREC_EXTENDED, FP_RND_NEAREST,
             den(x"0000000000000003"), den(x"0000000000000005"),
             den(x"0000000000000008"), "extended denormal + denormal exact");

    run_case(FPU_OP_ADD, FP_PREC_EXTENDED, FP_RND_NEAREST,
             den(x"7FFFFFFFFFFFFFFF"), den(x"0000000000000001"),
             MIN_NORMAL, "extended max denormal + 1ulp = smallest normal");

    -- MIN_NORMAL - (2^63 - 1) ulp = 1 ulp (cancellation into denormal range).
    run_case(FPU_OP_SUB, FP_PREC_EXTENDED, FP_RND_NEAREST,
             MIN_NORMAL, den(x"7FFFFFFFFFFFFFFF"),
             den(x"0000000000000001"), "extended min normal - denormal");

    if failures = 0 then
      report "TB SUCCESS: addsub denormal rounding checks complete."
        severity note;
    else
      report "TB FAILURE: " & integer'image(failures) &
             " addsub denormal rounding check(s) failed."
        severity failure;
    end if;
    std.env.stop;
    wait;
  end process;
end architecture sim;
