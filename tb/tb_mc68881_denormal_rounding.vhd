-- Follow-up to GitHub issue #73: the FMUL unit and the package's combinational
-- add_sub_fp80 / mul_fp80 / div_fp80 had the same double-rounding bug as the
-- add/sub unit (round at the normal-precision position, then plain-shift the
-- rounded mantissa into the denormal range).  A denormal result must be
-- denormalized (with sticky) first and rounded exactly once.
--
-- Notation: den(m) is a positive denormal, exponent field 0, mantissa field m.
-- Operand notation: x"EEEE" & mant, i.e. biased exponent field + 64-bit
-- mantissa with explicit integer bit.  Pairs below are chosen so the biased
-- product exponent is 0, i.e. the result must be shifted right by 1 (or 2 for
-- the divide case) to be denormalized.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_denormal_rounding is
end entity tb_mc68881_denormal_rounding;

architecture sim of tb_mc68881_denormal_rounding is
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

  function den(m : std_logic_vector(63 downto 0)) return fp80_t is
  begin
    return x"0000" & m;
  end function;

  constant MIN_NORMAL : fp80_t := x"0001" & x"8000000000000000";
  constant ZERO       : fp80_t := x"0000" & x"0000000000000000";

  -- Operands whose product has biased exponent 0 (EEEE_a + EEEE_b = 0x3FFF).
  constant ONE_E1FFF   : fp80_t := x"1FFF" & x"8000000000000000";  -- 1.0
  constant A_1P25      : fp80_t := x"1FFF" & x"A000000000000000";  -- 1.25
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

    procedure check(
      constant got      : in fp80_t;
      constant expected : in fp80_t;
      constant name     : in string
    ) is
    begin
      report name & ": expected=" & to_hstring(expected) & " got=" & to_hstring(got)
        severity note;
      if got /= expected then
        report "MISMATCH " & name & " expected=" & to_hstring(expected) &
               " got=" & to_hstring(got)
          severity error;
        failures := failures + 1;
      end if;
    end procedure;

    -- Hardware FMUL unit (through the ALU).
    procedure run_mul(
      constant prec     : in fp_round_prec_t;
      constant mode     : in fp_round_mode_t;
      constant a        : in fp80_t;
      constant b        : in fp80_t;
      constant expected : in fp80_t;
      constant name     : in string
    ) is
    begin
      op_sel     <= FPU_OP_MUL;
      round_prec <= prec;
      round_mode <= mode;
      a_in       <= a;
      b_in       <= b;
      start      <= '1';
      wait until rising_edge(clk);
      start      <= '0';
      wait until valid = '1';
      wait for 0 ns;
      check(result, expected, "FMUL unit " & name);
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;
  begin
    reset_n <= '0';
    wait for 4 * CLK_PERIOD;
    reset_n <= '1';
    wait for 4 * CLK_PERIOD;

    -- ================= FMUL unit and mul_fp80 (same vectors) =================
    -- 1.25 * (1 + 2^-63) = M + 0.25 ulp with M = 0xA000000000000001 (odd).
    -- Shifted right by 1 the remainder is 0.625 ulp -> round up to ...0001.
    -- (Old code: no round at the normal position, then truncated to ...0000.)
    run_mul(FP_PREC_EXTENDED, FP_RND_NEAREST,
            A_1P25, x"2000" & x"8000000000000001",
            den(x"5000000000000001"), "extended RN round up");
    check(mul_fp80(A_1P25, x"2000" & x"8000000000000001", FP_RND_NEAREST, FP_PREC_EXTENDED),
          den(x"5000000000000001"), "mul_fp80 extended RN round up");

    -- Exact product with odd M == 3 (mod 4): shifted by 1 it is an exact tie
    -- with odd kept LSB -> ties to even (up).  Old code truncated.
    run_mul(FP_PREC_EXTENDED, FP_RND_NEAREST,
            ONE_E1FFF, x"2000" & x"8000000000000003",
            den(x"4000000000000002"), "extended RN tie to even");
    check(mul_fp80(ONE_E1FFF, x"2000" & x"8000000000000003", FP_RND_NEAREST, FP_PREC_EXTENDED),
          den(x"4000000000000002"), "mul_fp80 extended RN tie to even");

    -- Single precision: shifted value has bits 62,40,39 -> tie, odd LSB -> up.
    run_mul(FP_PREC_SINGLE, FP_RND_NEAREST,
            ONE_E1FFF, x"2000" & x"8000030000000000",
            den(x"4000020000000000"), "single RN tie to even");
    check(mul_fp80(ONE_E1FFF, x"2000" & x"8000030000000000", FP_RND_NEAREST, FP_PREC_SINGLE),
          den(x"4000020000000000"), "mul_fp80 single RN tie to even");

    -- Double precision: shifted value has bits 62,11,10 -> tie, odd LSB -> up.
    run_mul(FP_PREC_DOUBLE, FP_RND_NEAREST,
            ONE_E1FFF, x"2000" & x"8000000000001800",
            den(x"4000000000001000"), "double RN tie to even");
    check(mul_fp80(ONE_E1FFF, x"2000" & x"8000000000001800", FP_RND_NEAREST, FP_PREC_DOUBLE),
          den(x"4000000000001000"), "mul_fp80 double RN tie to even");

    -- (2^64 - 1)/2 = 0x7FFF...F + 0.5: tie, odd LSB -> rounds up out of the
    -- denormal range to the smallest normal.
    run_mul(FP_PREC_EXTENDED, FP_RND_NEAREST,
            ONE_E1FFF, x"2000" & x"FFFFFFFFFFFFFFFF",
            MIN_NORMAL, "extended RN carry into smallest normal");
    check(mul_fp80(ONE_E1FFF, x"2000" & x"FFFFFFFFFFFFFFFF", FP_RND_NEAREST, FP_PREC_EXTENDED),
          MIN_NORMAL, "mul_fp80 extended RN carry into smallest normal");

    -- Far below the denormal range: RN/RZ give zero, RP the smallest denormal.
    run_mul(FP_PREC_EXTENDED, FP_RND_NEAREST,
            MIN_NORMAL, MIN_NORMAL, ZERO, "extended RN deep underflow");
    run_mul(FP_PREC_EXTENDED, FP_RND_PLUS_INF,
            MIN_NORMAL, MIN_NORMAL, den(x"0000000000000001"),
            "extended RP deep underflow -> smallest denormal");
    check(mul_fp80(MIN_NORMAL, MIN_NORMAL, FP_RND_PLUS_INF, FP_PREC_EXTENDED),
          den(x"0000000000000001"), "mul_fp80 extended RP deep underflow");

    -- ================= package add_sub_fp80 =================
    check(add_sub_fp80(den(x"0000028000000000"), den(x"0000000000000001"), false,
                       FP_RND_NEAREST, FP_PREC_SINGLE),
          den(x"0000030000000000"), "add_sub_fp80 single RN guard+sticky");
    check(add_sub_fp80(den(x"0000020000000400"), den(x"0000000000000001"), false,
                       FP_RND_NEAREST, FP_PREC_DOUBLE),
          den(x"0000020000000800"), "add_sub_fp80 double RN guard+sticky");
    check(add_sub_fp80(den(x"0000020000000001"), den(x"0000000000000001"), false,
                       FP_RND_PLUS_INF, FP_PREC_SINGLE),
          den(x"0000030000000000"), "add_sub_fp80 single RP sticky");
    check(add_sub_fp80(den(x"7FFFFF4000000000"), den(x"0000004000000000"), false,
                       FP_RND_NEAREST, FP_PREC_SINGLE),
          MIN_NORMAL, "add_sub_fp80 single RN carry into smallest normal");

    -- ================= package div_fp80 =================
    -- (1.0 * 2^-16382) / (1.5 * 2^1) = 4/3 * 2^-16384: shift by 2.
    -- 4/3 = 0xAAAA...AA + 2/3 ulp; /4 -> 0x2AAA...AA + 0.667 ulp -> round up.
    -- (Old code rounded at the normal position to ...AB, then truncated to ...AA.)
    check(div_fp80(x"0001" & x"8000000000000000", x"4000" & x"C000000000000000",
                   FP_RND_NEAREST, FP_PREC_EXTENDED),
          den(x"2AAAAAAAAAAAAAAB"), "div_fp80 extended RN round up");

    if failures = 0 then
      report "TB SUCCESS: FMUL / package denormal rounding checks complete."
        severity note;
    else
      report "TB FAILURE: " & integer'image(failures) &
             " denormal rounding check(s) failed."
        severity failure;
    end if;
    std.env.stop;
    wait;
  end process;
end architecture sim;
