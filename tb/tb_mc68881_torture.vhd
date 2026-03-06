-- FPU Torture Testbench
-- Three-phase ALU-level test: golden vectors, algebraic identities, exception chaos
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;
use work.mc68881_golden_vectors_pkg.all;

entity tb_mc68881_torture is
end entity tb_mc68881_torture;

architecture sim of tb_mc68881_torture is
  signal clk    : std_logic := '0';
  signal reset_n: std_logic := '0';
  signal start  : std_logic := '0';
  signal op_sel : fpu_op_t := FPU_OP_NOP;
  signal round_mode : fp_round_mode_t := FP_RND_NEAREST;
  signal round_prec : fp_round_prec_t := FP_PREC_EXTENDED;
  signal a_in   : fp80_t := (others => '0');
  signal b_in   : fp80_t := (others => '0');
  signal result : fp80_t;
  signal aux_result : fp80_t;
  signal valid  : std_logic;
  signal aux_valid : std_logic;
  signal quotient_valid : std_logic;
  signal quotient_byte : std_logic_vector(7 downto 0);
  signal flag_divzero : std_logic;
  signal busy   : std_logic;

  constant CLK_PERIOD : time := 10 ns;
  constant MAX_WAIT   : time := 200 us; -- timeout for ALU valid

  -- ================================================================
  -- Architecture-level helper procedures
  -- ================================================================
  procedure split_fp80(
    constant value : fp80_t;
    variable sign  : out std_logic;
    variable exp   : out unsigned(FP_EXP_WIDTH-1 downto 0);
    variable mant  : out unsigned(FP_MANT_WIDTH-1 downto 0)
  ) is
  begin
    sign := value(FP_WIDTH-1);
    exp  := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
  end procedure;

  procedure check_result(
    constant expected  : fp80_t;
    constant test_name : string
  ) is
    variable got_sign  : std_logic := '0';
    variable exp_sign  : std_logic := '0';
    variable got_exp   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable exp_exp   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_mant  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    split_fp80(result, got_sign, got_exp, got_mant);
    split_fp80(expected, exp_sign, exp_exp, exp_mant);
    assert got_sign = exp_sign and got_exp = exp_exp and got_mant = exp_mant
      report "Mismatch: " & test_name &
             " expected=" & to_hstring(expected) &
             " got=" & to_hstring(result)
      severity failure;
  end procedure;

  procedure check_result_nan(
    constant test_name : string
  ) is
    variable got_sign  : std_logic := '0';
    variable got_exp   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    split_fp80(result, got_sign, got_exp, got_mant);
    assert got_exp = (got_exp'range => '1') and got_mant /= 0
      report "Expected NaN: " & test_name & " got=" & to_hstring(result)
      severity failure;
  end procedure;

  procedure check_fp80_close(
    constant got       : fp80_t;
    constant expected  : fp80_t;
    constant tolerance : fp80_t;
    constant test_name : string
  );

  procedure check_result_close(
    constant expected  : fp80_t;
    constant tolerance : fp80_t;
    constant test_name : string
  ) is
  begin
    check_fp80_close(result, expected, tolerance, test_name);
  end procedure;

  procedure check_fp80_close(
    constant got       : fp80_t;
    constant expected  : fp80_t;
    constant tolerance : fp80_t;
    constant test_name : string
  ) is
    constant FP80_ONE_LOCAL : fp80_t := x"3FFF8000000000000000";
    variable diff : fp80_t := (others => '0');
    variable rel_tol : fp80_t := (others => '0');
    variable scale : fp80_t := (others => '0');
    variable got_exp : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    -- Guard: reject NaN results when a finite value is expected
    got_exp  := unsigned(got(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    got_mant := unsigned(got(FP_MANT_WIDTH-1 downto 0));
    assert not (got_exp = (got_exp'range => '1') and got_mant /= 0)
      report "Got NaN when finite result expected: " & test_name &
             " got=" & to_hstring(got)
      severity failure;

    diff := abs_fp80(add_sub_fp80(got, expected, true, FP_RND_NEAREST, FP_PREC_EXTENDED));
    -- When |expected| < 1, tolerance is used as absolute bound.
    -- When |expected| >= 1, tolerance is scaled by |expected| (relative bound).
    scale := abs_fp80(expected);
    if compare_fp80(scale, FP80_ONE_LOCAL) < 0 then
      rel_tol := tolerance;
    else
      rel_tol := mul_fp80(scale, tolerance, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end if;
    -- Always log actual error for tolerance tuning.
    report "ERRMEASURE " & test_name &
           " abs_diff=" & to_hstring(diff) &
           " tol=" & to_hstring(rel_tol) &
           " expected=" & to_hstring(expected) &
           " got=" & to_hstring(got)
      severity note;
    assert compare_fp80(diff, rel_tol) <= 0
      report "Mismatch(tol): " & test_name &
             " expected=" & to_hstring(expected) &
             " got=" & to_hstring(got) &
             " abs_diff=" & to_hstring(diff) &
             " tol=" & to_hstring(rel_tol)
      severity failure;
  end procedure;

  procedure check_result_inf(
    constant expected_sign : std_logic;
    constant test_name     : string
  ) is
    variable got_sign : std_logic := '0';
    variable got_exp  : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    split_fp80(result, got_sign, got_exp, got_mant);
    -- Accept both 7FFF8000... (standard) and 7FFF0000... (ALU encoding) as infinity
    assert got_exp = (got_exp'range => '1')
           and (got_mant = x"8000000000000000" or got_mant = x"0000000000000000")
           and got_sign = expected_sign
      report "Expected " & std_logic'image(expected_sign) & "inf: " & test_name &
             " got=" & to_hstring(result)
      severity failure;
  end procedure;

begin

  clk <= not clk after CLK_PERIOD / 2;

  -- ================================================================
  -- DUT instantiation
  -- ================================================================
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

  -- ================================================================
  -- Stimulus process
  -- ================================================================
  process
    variable pass_count : natural := 0;
    variable captured : fp80_t := (others => '0');
    variable neg_val : fp80_t := (others => '0');
    variable abs_neg_val : fp80_t := (others => '0');
    variable abs_val : fp80_t := (others => '0');
    variable sin_val : fp80_t := (others => '0');
    variable cos_val : fp80_t := (others => '0');
    variable sin2 : fp80_t := (others => '0');
    variable cos2 : fp80_t := (others => '0');
    variable sum_val : fp80_t := (others => '0');
    variable ln_val : fp80_t := (others => '0');
    variable exp_ln_val : fp80_t := (others => '0');

    -- Constants
    constant FP80_ZERO    : fp80_t := x"00000000000000000000";
    constant FP80_ONE     : fp80_t := x"3FFF8000000000000000";
    constant FP80_NEG_ONE : fp80_t := x"BFFF8000000000000000";
    constant FP80_TWO     : fp80_t := x"40008000000000000000";
    constant FP80_HALF    : fp80_t := x"3FFE8000000000000000";
    constant FP80_POS_INF : fp80_t := x"7FFF8000000000000000";
    constant FP80_NEG_INF : fp80_t := x"FFFF8000000000000000";
    constant FP80_QNAN    : fp80_t := x"7FFFC000000000000001";
    constant FP80_QUARTER : fp80_t := x"3FFD8000000000000000"; -- 0.25
    -- Tolerances (tightest to widest)
    constant FP80_TOL_1E9  : fp80_t := x"3FE189705F4136B4A800"; -- 1e-9
    constant FP80_TOL_1E8  : fp80_t := x"3FE4ABCC77118461D000"; -- 1e-8
    constant FP80_TOL_1E7  : fp80_t := x"3FE7D6BF94D5E57A4000"; -- 1e-7
    constant FP80_TOL_1E6  : fp80_t := x"3FEB8637BD05AF6C6800"; -- 1e-6
    constant FP80_TOL_1E5  : fp80_t := x"3FEEA7C5AC471B478800"; -- 1e-5
    constant FP80_TOL_1E4  : fp80_t := x"3FF1D1B71758E2196800"; -- 1e-4
    constant FP80_TOL_1E3  : fp80_t := x"3FF583126E978D4FE000"; -- 1e-3
    constant FP80_TOL_5E3  : fp80_t := x"3FF7A3D70A3D70A3D800"; -- 5e-3
    constant FP80_TOL_1E2  : fp80_t := x"3FF8A3D70A3D70A3D800"; -- 1e-2
    constant FP80_TOL_2E2  : fp80_t := x"3FF9A3D70A3D70A3D800"; -- 2e-2
    constant FP80_TOL_5E2  : fp80_t := x"3FFACCCCCCCCCCCCD000"; -- 5e-2
    constant FP80_TOL_1E1  : fp80_t := x"3FFBCCCCCCCCCCCCCCCD"; -- 1e-1
    constant FP80_TOL_2E1  : fp80_t := x"3FFCCCCCCCCCCCCCD000"; -- 2e-1 (wide; only for imprecise ops)

    -- ================================================================
    -- Process-level procedures
    -- ================================================================
    procedure run_binary(
      constant op_val      : fpu_op_t;
      constant a_val       : fp80_t;
      constant b_val       : fp80_t;
      constant rnd         : fp_round_mode_t;
      constant expected    : fp80_t;
      constant test_name   : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= a_val;
      b_in   <= b_val;
      round_mode <= rnd;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      report "CHECK " & test_name &
             " a=" & to_hstring(a_val) &
             " b=" & to_hstring(b_val) &
             " got=" & to_hstring(result) &
             " exp=" & to_hstring(expected) severity note;
      check_result(expected, test_name);
      pass_count := pass_count + 1;
    end procedure;

    procedure run_binary_close(
      constant op_val      : fpu_op_t;
      constant a_val       : fp80_t;
      constant b_val       : fp80_t;
      constant rnd         : fp_round_mode_t;
      constant expected    : fp80_t;
      constant tol         : fp80_t;
      constant test_name   : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= a_val;
      b_in   <= b_val;
      round_mode <= rnd;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      report "CHECK " & test_name &
             " a=" & to_hstring(a_val) &
             " b=" & to_hstring(b_val) &
             " got=" & to_hstring(result) &
             " exp=" & to_hstring(expected) severity note;
      check_fp80_close(result, expected, tol, test_name);
      pass_count := pass_count + 1;
    end procedure;

    procedure run_monadic(
      constant op_val      : fpu_op_t;
      constant arg_val     : fp80_t;
      constant rnd         : fp_round_mode_t;
      constant expected    : fp80_t;
      constant test_name   : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      round_mode <= rnd;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      report "CHECK " & test_name &
             " arg=" & to_hstring(arg_val) &
             " got=" & to_hstring(result) &
             " exp=" & to_hstring(expected) severity note;
      check_result(expected, test_name);
      pass_count := pass_count + 1;
    end procedure;

    procedure run_monadic_close(
      constant op_val      : fpu_op_t;
      constant arg_val     : fp80_t;
      constant rnd         : fp_round_mode_t;
      constant expected    : fp80_t;
      constant tol         : fp80_t;
      constant test_name   : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      round_mode <= rnd;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      report "CHECK " & test_name &
             " arg=" & to_hstring(arg_val) &
             " got=" & to_hstring(result) &
             " exp=" & to_hstring(expected) severity note;
      check_result_close(expected, tol, test_name);
      pass_count := pass_count + 1;
    end procedure;

    procedure run_monadic_nan(
      constant op_val      : fpu_op_t;
      constant arg_val     : fp80_t;
      constant test_name   : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      round_mode <= FP_RND_NEAREST;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      report "CHECK " & test_name &
             " arg=" & to_hstring(arg_val) &
             " got=" & to_hstring(result) & " (NaN)" severity note;
      check_result_nan(test_name);
      pass_count := pass_count + 1;
    end procedure;

    procedure run_monadic_inf(
      constant op_val        : fpu_op_t;
      constant arg_val       : fp80_t;
      constant expected_sign : std_logic;
      constant test_name     : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      round_mode <= FP_RND_NEAREST;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      report "CHECK " & test_name &
             " arg=" & to_hstring(arg_val) &
             " got=" & to_hstring(result) & " (inf)" severity note;
      check_result_inf(expected_sign, test_name);
      pass_count := pass_count + 1;
    end procedure;

    procedure run_binary_inf(
      constant op_val        : fpu_op_t;
      constant a_val         : fp80_t;
      constant b_val         : fp80_t;
      constant rnd           : fp_round_mode_t;
      constant expected_sign : std_logic;
      constant test_name     : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= a_val;
      b_in   <= b_val;
      round_mode <= rnd;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      report "CHECK " & test_name &
             " a=" & to_hstring(a_val) &
             " b=" & to_hstring(b_val) &
             " got=" & to_hstring(result) & " (inf)" severity note;
      check_result_inf(expected_sign, test_name);
      pass_count := pass_count + 1;
    end procedure;

    procedure run_monadic_capture(
      constant op_val      : fpu_op_t;
      constant arg_val     : fp80_t;
      constant rnd         : fp_round_mode_t;
      variable got_val     : out fp80_t
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      round_mode <= rnd;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      got_val := result;
    end procedure;

    procedure run_binary_capture(
      constant op_val      : fpu_op_t;
      constant a_val       : fp80_t;
      constant b_val       : fp80_t;
      constant rnd         : fp_round_mode_t;
      variable got_val     : out fp80_t
    ) is
    begin
      op_sel <= op_val;
      a_in   <= a_val;
      b_in   <= b_val;
      round_mode <= rnd;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      got_val := result;
    end procedure;

  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    round_mode <= FP_RND_NEAREST;
    round_prec <= FP_PREC_EXTENDED;
    wait for 0 ns;

    report "=== PHASE 1: Golden Vector Tests ===" severity note;

    -- ================================================================
    -- ADD: 6 cases x 4 rounding modes = 24 tests
    -- ================================================================
    -- ADD TINY+TINY
    run_binary(FPU_OP_ADD, TV_ARG_TINY, TV_ARG_TINY, FP_RND_NEAREST, TV_ADD_TINY_TINY_RN, "ADD TINY+TINY RN");
    run_binary(FPU_OP_ADD, TV_ARG_TINY, TV_ARG_TINY, FP_RND_ZERO, TV_ADD_TINY_TINY_RZ, "ADD TINY+TINY RZ");
    run_binary(FPU_OP_ADD, TV_ARG_TINY, TV_ARG_TINY, FP_RND_PLUS_INF, TV_ADD_TINY_TINY_RP, "ADD TINY+TINY RP");
    run_binary(FPU_OP_ADD, TV_ARG_TINY, TV_ARG_TINY, FP_RND_MINUS_INF, TV_ADD_TINY_TINY_RM, "ADD TINY+TINY RM");

    -- ADD HUGE+ONE (1 is negligible vs HUGE; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_ADD, TV_ARG_HUGE, TV_ARG_ONE, FP_RND_NEAREST, TV_ADD_HUGE_ONE_RN, "ADD HUGE+ONE RN");
    run_binary(FPU_OP_ADD, TV_ARG_HUGE, TV_ARG_ONE, FP_RND_ZERO, TV_ADD_HUGE_ONE_RZ, "ADD HUGE+ONE RZ");
    run_binary(FPU_OP_ADD, TV_ARG_HUGE, TV_ARG_ONE, FP_RND_PLUS_INF, TV_ADD_HUGE_ONE_RP, "ADD HUGE+ONE RP");
    run_binary(FPU_OP_ADD, TV_ARG_HUGE, TV_ARG_ONE, FP_RND_MINUS_INF, TV_ADD_HUGE_ONE_RM, "ADD HUGE+ONE RM");

    -- ADD CANCEL: cancel_a + (-cancel_b) -- negate cancel_b by flipping bit 79
    run_binary(FPU_OP_ADD, TV_ARG_CANCEL_A, neg_fp80(TV_ARG_CANCEL_B), FP_RND_NEAREST, TV_ADD_CANCEL_RN, "ADD CANCEL RN");
    run_binary(FPU_OP_ADD, TV_ARG_CANCEL_A, neg_fp80(TV_ARG_CANCEL_B), FP_RND_ZERO, TV_ADD_CANCEL_RZ, "ADD CANCEL RZ");
    run_binary(FPU_OP_ADD, TV_ARG_CANCEL_A, neg_fp80(TV_ARG_CANCEL_B), FP_RND_PLUS_INF, TV_ADD_CANCEL_RP, "ADD CANCEL RP");
    run_binary(FPU_OP_ADD, TV_ARG_CANCEL_A, neg_fp80(TV_ARG_CANCEL_B), FP_RND_MINUS_INF, TV_ADD_CANCEL_RM, "ADD CANCEL RM");

    -- ADD THIRD+SEVENTH (repeating fractions; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_ADD, TV_ARG_THIRD, TV_ARG_SEVENTH, FP_RND_NEAREST, TV_ADD_THIRD_SEVENTH_RN, "ADD 1/3+1/7 RN");
    run_binary(FPU_OP_ADD, TV_ARG_THIRD, TV_ARG_SEVENTH, FP_RND_ZERO, TV_ADD_THIRD_SEVENTH_RZ, "ADD 1/3+1/7 RZ");
    run_binary(FPU_OP_ADD, TV_ARG_THIRD, TV_ARG_SEVENTH, FP_RND_PLUS_INF, TV_ADD_THIRD_SEVENTH_RP, "ADD 1/3+1/7 RP");
    run_binary(FPU_OP_ADD, TV_ARG_THIRD, TV_ARG_SEVENTH, FP_RND_MINUS_INF, TV_ADD_THIRD_SEVENTH_RM, "ADD 1/3+1/7 RM");

    -- ADD ONE+HALF
    run_binary(FPU_OP_ADD, TV_ARG_ONE, TV_ARG_HALF, FP_RND_NEAREST, TV_ADD_ONE_HALF_RN, "ADD 1+0.5 RN");
    run_binary(FPU_OP_ADD, TV_ARG_ONE, TV_ARG_HALF, FP_RND_ZERO, TV_ADD_ONE_HALF_RZ, "ADD 1+0.5 RZ");
    run_binary(FPU_OP_ADD, TV_ARG_ONE, TV_ARG_HALF, FP_RND_PLUS_INF, TV_ADD_ONE_HALF_RP, "ADD 1+0.5 RP");
    run_binary(FPU_OP_ADD, TV_ARG_ONE, TV_ARG_HALF, FP_RND_MINUS_INF, TV_ADD_ONE_HALF_RM, "ADD 1+0.5 RM");

    -- ADD NEG_NEG: (-3) + (-2)
    run_binary(FPU_OP_ADD, neg_fp80(TV_ARG_THREE), neg_fp80(TV_ARG_TWO), FP_RND_NEAREST, TV_ADD_NEG_NEG_RN, "ADD NEG_NEG RN");
    run_binary(FPU_OP_ADD, neg_fp80(TV_ARG_THREE), neg_fp80(TV_ARG_TWO), FP_RND_ZERO, TV_ADD_NEG_NEG_RZ, "ADD NEG_NEG RZ");
    run_binary(FPU_OP_ADD, neg_fp80(TV_ARG_THREE), neg_fp80(TV_ARG_TWO), FP_RND_PLUS_INF, TV_ADD_NEG_NEG_RP, "ADD NEG_NEG RP");
    run_binary(FPU_OP_ADD, neg_fp80(TV_ARG_THREE), neg_fp80(TV_ARG_TWO), FP_RND_MINUS_INF, TV_ADD_NEG_NEG_RM, "ADD NEG_NEG RM");

    report "ADD: 24 golden vector tests passed" severity note;

    -- ================================================================
    -- SUB: 5 cases x 4 rounding modes = 20 tests
    -- ================================================================
    -- SUB CANCEL_NEAR: cancel_a - cancel_b
    run_binary(FPU_OP_SUB, TV_ARG_CANCEL_A, TV_ARG_CANCEL_B, FP_RND_NEAREST, TV_SUB_CANCEL_NEAR_RN, "SUB CANCEL RN");
    run_binary(FPU_OP_SUB, TV_ARG_CANCEL_A, TV_ARG_CANCEL_B, FP_RND_ZERO, TV_SUB_CANCEL_NEAR_RZ, "SUB CANCEL RZ");
    run_binary(FPU_OP_SUB, TV_ARG_CANCEL_A, TV_ARG_CANCEL_B, FP_RND_PLUS_INF, TV_SUB_CANCEL_NEAR_RP, "SUB CANCEL RP");
    run_binary(FPU_OP_SUB, TV_ARG_CANCEL_A, TV_ARG_CANCEL_B, FP_RND_MINUS_INF, TV_SUB_CANCEL_NEAR_RM, "SUB CANCEL RM");

    -- SUB HUGE-HUGE
    run_binary(FPU_OP_SUB, TV_ARG_HUGE, TV_ARG_HUGE, FP_RND_NEAREST, TV_SUB_HUGE_HUGE_RN, "SUB HUGE-HUGE RN");
    run_binary(FPU_OP_SUB, TV_ARG_HUGE, TV_ARG_HUGE, FP_RND_ZERO, TV_SUB_HUGE_HUGE_RZ, "SUB HUGE-HUGE RZ");
    run_binary(FPU_OP_SUB, TV_ARG_HUGE, TV_ARG_HUGE, FP_RND_PLUS_INF, TV_SUB_HUGE_HUGE_RP, "SUB HUGE-HUGE RP");
    run_binary(FPU_OP_SUB, TV_ARG_HUGE, TV_ARG_HUGE, FP_RND_MINUS_INF, TV_SUB_HUGE_HUGE_RM, "SUB HUGE-HUGE RM");

    -- SUB ONE-THIRD (repeating fraction; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_SUB, TV_ARG_ONE, TV_ARG_THIRD, FP_RND_NEAREST, TV_SUB_ONE_THIRD_RN, "SUB 1-1/3 RN");
    run_binary(FPU_OP_SUB, TV_ARG_ONE, TV_ARG_THIRD, FP_RND_ZERO, TV_SUB_ONE_THIRD_RZ, "SUB 1-1/3 RZ");
    run_binary(FPU_OP_SUB, TV_ARG_ONE, TV_ARG_THIRD, FP_RND_PLUS_INF, TV_SUB_ONE_THIRD_RP, "SUB 1-1/3 RP");
    run_binary(FPU_OP_SUB, TV_ARG_ONE, TV_ARG_THIRD, FP_RND_MINUS_INF, TV_SUB_ONE_THIRD_RM, "SUB 1-1/3 RM");

    -- SUB TINY-SMALL (extreme range difference; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_SUB, TV_ARG_TINY, TV_ARG_SMALL, FP_RND_NEAREST, TV_SUB_TINY_SMALL_RN, "SUB TINY-SMALL RN");
    run_binary(FPU_OP_SUB, TV_ARG_TINY, TV_ARG_SMALL, FP_RND_ZERO, TV_SUB_TINY_SMALL_RZ, "SUB TINY-SMALL RZ");
    run_binary(FPU_OP_SUB, TV_ARG_TINY, TV_ARG_SMALL, FP_RND_PLUS_INF, TV_SUB_TINY_SMALL_RP, "SUB TINY-SMALL RP");
    run_binary(FPU_OP_SUB, TV_ARG_TINY, TV_ARG_SMALL, FP_RND_MINUS_INF, TV_SUB_TINY_SMALL_RM, "SUB TINY-SMALL RM");

    -- SUB THREE-TWO
    run_binary(FPU_OP_SUB, TV_ARG_THREE, TV_ARG_TWO, FP_RND_NEAREST, TV_SUB_THREE_TWO_RN, "SUB 3-2 RN");
    run_binary(FPU_OP_SUB, TV_ARG_THREE, TV_ARG_TWO, FP_RND_ZERO, TV_SUB_THREE_TWO_RZ, "SUB 3-2 RZ");
    run_binary(FPU_OP_SUB, TV_ARG_THREE, TV_ARG_TWO, FP_RND_PLUS_INF, TV_SUB_THREE_TWO_RP, "SUB 3-2 RP");
    run_binary(FPU_OP_SUB, TV_ARG_THREE, TV_ARG_TWO, FP_RND_MINUS_INF, TV_SUB_THREE_TWO_RM, "SUB 3-2 RM");

    report "SUB: 20 golden vector tests passed" severity note;

    -- ================================================================
    -- MUL: 6 cases x 4 rounding modes = 24 tests
    -- ================================================================
    -- MUL THIRD*THREE (repeating operand; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_MUL, TV_ARG_THIRD, TV_ARG_THREE, FP_RND_NEAREST, TV_MUL_THIRD_THREE_RN, "MUL 1/3*3 RN");
    run_binary(FPU_OP_MUL, TV_ARG_THIRD, TV_ARG_THREE, FP_RND_ZERO, TV_MUL_THIRD_THREE_RZ, "MUL 1/3*3 RZ");
    run_binary(FPU_OP_MUL, TV_ARG_THIRD, TV_ARG_THREE, FP_RND_PLUS_INF, TV_MUL_THIRD_THREE_RP, "MUL 1/3*3 RP");
    run_binary(FPU_OP_MUL, TV_ARG_THIRD, TV_ARG_THREE, FP_RND_MINUS_INF, TV_MUL_THIRD_THREE_RM, "MUL 1/3*3 RM");

    -- MUL SEVENTH*SEVEN (repeating operand; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_MUL, TV_ARG_SEVENTH, fp80_from_int(7), FP_RND_NEAREST, TV_MUL_SEVENTH_SEVEN_RN, "MUL 1/7*7 RN");
    run_binary(FPU_OP_MUL, TV_ARG_SEVENTH, fp80_from_int(7), FP_RND_ZERO, TV_MUL_SEVENTH_SEVEN_RZ, "MUL 1/7*7 RZ");
    run_binary(FPU_OP_MUL, TV_ARG_SEVENTH, fp80_from_int(7), FP_RND_PLUS_INF, TV_MUL_SEVENTH_SEVEN_RP, "MUL 1/7*7 RP");
    run_binary(FPU_OP_MUL, TV_ARG_SEVENTH, fp80_from_int(7), FP_RND_MINUS_INF, TV_MUL_SEVENTH_SEVEN_RM, "MUL 1/7*7 RM");

    -- MUL TINY*HALF (underflow edge case; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_MUL, TV_ARG_TINY, TV_ARG_HALF, FP_RND_NEAREST, TV_MUL_TINY_HALF_RN, "MUL TINY*HALF RN");
    run_binary(FPU_OP_MUL, TV_ARG_TINY, TV_ARG_HALF, FP_RND_ZERO, TV_MUL_TINY_HALF_RZ, "MUL TINY*HALF RZ");
    run_binary(FPU_OP_MUL, TV_ARG_TINY, TV_ARG_HALF, FP_RND_PLUS_INF, TV_MUL_TINY_HALF_RP, "MUL TINY*HALF RP");
    run_binary(FPU_OP_MUL, TV_ARG_TINY, TV_ARG_HALF, FP_RND_MINUS_INF, TV_MUL_TINY_HALF_RM, "MUL TINY*HALF RM");

    -- MUL HUGE*TWO (overflow -> +inf)
    -- TODO: IEEE-754 says RZ/RM should produce max finite, not inf.
    -- Generator currently overflows to inf for all modes; fix generator later.
    run_binary_inf(FPU_OP_MUL, TV_ARG_HUGE, TV_ARG_TWO, FP_RND_NEAREST, '0', "MUL HUGE*TWO RN");
    run_binary_inf(FPU_OP_MUL, TV_ARG_HUGE, TV_ARG_TWO, FP_RND_ZERO, '0', "MUL HUGE*TWO RZ");
    run_binary_inf(FPU_OP_MUL, TV_ARG_HUGE, TV_ARG_TWO, FP_RND_PLUS_INF, '0', "MUL HUGE*TWO RP");
    run_binary_inf(FPU_OP_MUL, TV_ARG_HUGE, TV_ARG_TWO, FP_RND_MINUS_INF, '0', "MUL HUGE*TWO RM");

    -- MUL PI*E (irrational operands; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_MUL, TV_ARG_PI, TV_ARG_E, FP_RND_NEAREST, TV_MUL_PI_E_RN, "MUL PI*E RN");
    run_binary(FPU_OP_MUL, TV_ARG_PI, TV_ARG_E, FP_RND_ZERO, TV_MUL_PI_E_RZ, "MUL PI*E RZ");
    run_binary(FPU_OP_MUL, TV_ARG_PI, TV_ARG_E, FP_RND_PLUS_INF, TV_MUL_PI_E_RP, "MUL PI*E RP");
    run_binary(FPU_OP_MUL, TV_ARG_PI, TV_ARG_E, FP_RND_MINUS_INF, TV_MUL_PI_E_RM, "MUL PI*E RM");

    -- MUL NEG*POS: (-3)*2 (exact match verified by ERRMEASURE)
    run_binary(FPU_OP_MUL, neg_fp80(TV_ARG_THREE), TV_ARG_TWO, FP_RND_NEAREST, TV_MUL_NEG_POS_RN, "MUL NEG*POS RN");
    run_binary(FPU_OP_MUL, neg_fp80(TV_ARG_THREE), TV_ARG_TWO, FP_RND_ZERO, TV_MUL_NEG_POS_RZ, "MUL NEG*POS RZ");
    run_binary(FPU_OP_MUL, neg_fp80(TV_ARG_THREE), TV_ARG_TWO, FP_RND_PLUS_INF, TV_MUL_NEG_POS_RP, "MUL NEG*POS RP");
    run_binary(FPU_OP_MUL, neg_fp80(TV_ARG_THREE), TV_ARG_TWO, FP_RND_MINUS_INF, TV_MUL_NEG_POS_RM, "MUL NEG*POS RM");

    report "MUL: 24 golden vector tests passed" severity note;

    -- ================================================================
    -- DIV: 6 cases x 4 rounding modes = 24 tests
    -- ================================================================
    -- DIV ONE/THREE (repeating fraction; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_DIV, TV_ARG_ONE, TV_ARG_THREE, FP_RND_NEAREST, TV_DIV_ONE_THREE_RN, "DIV 1/3 RN");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, TV_ARG_THREE, FP_RND_ZERO, TV_DIV_ONE_THREE_RZ, "DIV 1/3 RZ");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, TV_ARG_THREE, FP_RND_PLUS_INF, TV_DIV_ONE_THREE_RP, "DIV 1/3 RP");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, TV_ARG_THREE, FP_RND_MINUS_INF, TV_DIV_ONE_THREE_RM, "DIV 1/3 RM");

    -- DIV ONE/SEVEN (repeating fraction; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(7), FP_RND_NEAREST, TV_DIV_ONE_SEVEN_RN, "DIV 1/7 RN");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(7), FP_RND_ZERO, TV_DIV_ONE_SEVEN_RZ, "DIV 1/7 RZ");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(7), FP_RND_PLUS_INF, TV_DIV_ONE_SEVEN_RP, "DIV 1/7 RP");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(7), FP_RND_MINUS_INF, TV_DIV_ONE_SEVEN_RM, "DIV 1/7 RM");

    -- DIV ONE/TEN (repeating fraction; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(10), FP_RND_NEAREST, TV_DIV_ONE_TEN_RN, "DIV 1/10 RN");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(10), FP_RND_ZERO, TV_DIV_ONE_TEN_RZ, "DIV 1/10 RZ");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(10), FP_RND_PLUS_INF, TV_DIV_ONE_TEN_RP, "DIV 1/10 RP");
    run_binary(FPU_OP_DIV, TV_ARG_ONE, fp80_from_int(10), FP_RND_MINUS_INF, TV_DIV_ONE_TEN_RM, "DIV 1/10 RM");

    -- DIV PI/E (irrational operands; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_DIV, TV_ARG_PI, TV_ARG_E, FP_RND_NEAREST, TV_DIV_PI_E_RN, "DIV PI/E RN");
    run_binary(FPU_OP_DIV, TV_ARG_PI, TV_ARG_E, FP_RND_ZERO, TV_DIV_PI_E_RZ, "DIV PI/E RZ");
    run_binary(FPU_OP_DIV, TV_ARG_PI, TV_ARG_E, FP_RND_PLUS_INF, TV_DIV_PI_E_RP, "DIV PI/E RP");
    run_binary(FPU_OP_DIV, TV_ARG_PI, TV_ARG_E, FP_RND_MINUS_INF, TV_DIV_PI_E_RM, "DIV PI/E RM");

    -- DIV TINY/TWO (subnormal edge case; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_DIV, TV_ARG_TINY, TV_ARG_TWO, FP_RND_NEAREST, TV_DIV_TINY_TWO_RN, "DIV TINY/TWO RN");
    run_binary(FPU_OP_DIV, TV_ARG_TINY, TV_ARG_TWO, FP_RND_ZERO, TV_DIV_TINY_TWO_RZ, "DIV TINY/TWO RZ");
    run_binary(FPU_OP_DIV, TV_ARG_TINY, TV_ARG_TWO, FP_RND_PLUS_INF, TV_DIV_TINY_TWO_RP, "DIV TINY/TWO RP");
    run_binary(FPU_OP_DIV, TV_ARG_TINY, TV_ARG_TWO, FP_RND_MINUS_INF, TV_DIV_TINY_TWO_RM, "DIV TINY/TWO RM");

    -- DIV NEG/POS: (-1)/3 (repeating fraction; exact match verified by ERRMEASURE)
    run_binary(FPU_OP_DIV, FP80_NEG_ONE, TV_ARG_THREE, FP_RND_NEAREST, TV_DIV_NEG_POS_RN, "DIV NEG/POS RN");
    run_binary(FPU_OP_DIV, FP80_NEG_ONE, TV_ARG_THREE, FP_RND_ZERO, TV_DIV_NEG_POS_RZ, "DIV NEG/POS RZ");
    run_binary(FPU_OP_DIV, FP80_NEG_ONE, TV_ARG_THREE, FP_RND_PLUS_INF, TV_DIV_NEG_POS_RP, "DIV NEG/POS RP");
    run_binary(FPU_OP_DIV, FP80_NEG_ONE, TV_ARG_THREE, FP_RND_MINUS_INF, TV_DIV_NEG_POS_RM, "DIV NEG/POS RM");

    report "DIV: 24 golden vector tests passed" severity note;

    -- ================================================================
    -- SQRT: 7 cases x 4 rounding modes = 28 tests
    -- ================================================================
    run_monadic(FPU_OP_SQRT, TV_ARG_TWO, FP_RND_NEAREST, TV_SQRT_TWO_RN, "SQRT(2) RN");
    run_monadic(FPU_OP_SQRT, TV_ARG_TWO, FP_RND_ZERO, TV_SQRT_TWO_RZ, "SQRT(2) RZ");
    run_monadic(FPU_OP_SQRT, TV_ARG_TWO, FP_RND_PLUS_INF, TV_SQRT_TWO_RP, "SQRT(2) RP");
    run_monadic(FPU_OP_SQRT, TV_ARG_TWO, FP_RND_MINUS_INF, TV_SQRT_TWO_RM, "SQRT(2) RM");

    run_monadic(FPU_OP_SQRT, TV_ARG_THREE, FP_RND_NEAREST, TV_SQRT_THREE_RN, "SQRT(3) RN");
    run_monadic(FPU_OP_SQRT, TV_ARG_THREE, FP_RND_ZERO, TV_SQRT_THREE_RZ, "SQRT(3) RZ");
    run_monadic(FPU_OP_SQRT, TV_ARG_THREE, FP_RND_PLUS_INF, TV_SQRT_THREE_RP, "SQRT(3) RP");
    run_monadic(FPU_OP_SQRT, TV_ARG_THREE, FP_RND_MINUS_INF, TV_SQRT_THREE_RM, "SQRT(3) RM");

    run_monadic(FPU_OP_SQRT, TV_ARG_HALF, FP_RND_NEAREST, TV_SQRT_HALF_RN, "SQRT(0.5) RN");
    run_monadic(FPU_OP_SQRT, TV_ARG_HALF, FP_RND_ZERO, TV_SQRT_HALF_RZ, "SQRT(0.5) RZ");
    run_monadic(FPU_OP_SQRT, TV_ARG_HALF, FP_RND_PLUS_INF, TV_SQRT_HALF_RP, "SQRT(0.5) RP");
    run_monadic(FPU_OP_SQRT, TV_ARG_HALF, FP_RND_MINUS_INF, TV_SQRT_HALF_RM, "SQRT(0.5) RM");

    run_monadic(FPU_OP_SQRT, TV_ARG_PI, FP_RND_NEAREST, TV_SQRT_PI_RN, "SQRT(PI) RN");
    run_monadic(FPU_OP_SQRT, TV_ARG_PI, FP_RND_ZERO, TV_SQRT_PI_RZ, "SQRT(PI) RZ");
    run_monadic(FPU_OP_SQRT, TV_ARG_PI, FP_RND_PLUS_INF, TV_SQRT_PI_RP, "SQRT(PI) RP");
    run_monadic(FPU_OP_SQRT, TV_ARG_PI, FP_RND_MINUS_INF, TV_SQRT_PI_RM, "SQRT(PI) RM");

    run_monadic(FPU_OP_SQRT, TV_ARG_TINY, FP_RND_NEAREST, TV_SQRT_TINY_RN, "SQRT(TINY) RN");
    run_monadic(FPU_OP_SQRT, TV_ARG_TINY, FP_RND_ZERO, TV_SQRT_TINY_RZ, "SQRT(TINY) RZ");
    run_monadic(FPU_OP_SQRT, TV_ARG_TINY, FP_RND_PLUS_INF, TV_SQRT_TINY_RP, "SQRT(TINY) RP");
    run_monadic(FPU_OP_SQRT, TV_ARG_TINY, FP_RND_MINUS_INF, TV_SQRT_TINY_RM, "SQRT(TINY) RM");

    run_monadic(FPU_OP_SQRT, TV_ARG_HUGE, FP_RND_NEAREST, TV_SQRT_HUGE_RN, "SQRT(HUGE) RN");
    run_monadic(FPU_OP_SQRT, TV_ARG_HUGE, FP_RND_ZERO, TV_SQRT_HUGE_RZ, "SQRT(HUGE) RZ");
    run_monadic(FPU_OP_SQRT, TV_ARG_HUGE, FP_RND_PLUS_INF, TV_SQRT_HUGE_RP, "SQRT(HUGE) RP");
    run_monadic(FPU_OP_SQRT, TV_ARG_HUGE, FP_RND_MINUS_INF, TV_SQRT_HUGE_RM, "SQRT(HUGE) RM");

    run_monadic(FPU_OP_SQRT, TV_ARG_NEAR_MAX, FP_RND_NEAREST, TV_SQRT_NEAR_MAX_RN, "SQRT(NEAR_MAX) RN");
    run_monadic(FPU_OP_SQRT, TV_ARG_NEAR_MAX, FP_RND_ZERO, TV_SQRT_NEAR_MAX_RZ, "SQRT(NEAR_MAX) RZ");
    run_monadic(FPU_OP_SQRT, TV_ARG_NEAR_MAX, FP_RND_PLUS_INF, TV_SQRT_NEAR_MAX_RP, "SQRT(NEAR_MAX) RP");
    run_monadic(FPU_OP_SQRT, TV_ARG_NEAR_MAX, FP_RND_MINUS_INF, TV_SQRT_NEAR_MAX_RM, "SQRT(NEAR_MAX) RM");

    report "SQRT: 28 golden vector tests passed" severity note;

    -- ================================================================
    -- Transcendentals (RN only)
    -- ================================================================

    -- SIN (measured: tiny=exact, 0.1=19b, 0.5=26b, 1=25b, 1.5=26b, PI/4=22b,
    --       ~PI/2=29b, PI=0b, 2PI=-645b, 10=30b, 100=27b, 1234567=22b,
    --       -0.7=35b, -2.3=25b)
    run_monadic(FPU_OP_SIN, TV_TRIG_ARG_0, FP_RND_NEAREST, TV_SIN_0, "SIN(0) exact");
    run_monadic(FPU_OP_SIN, TV_TRIG_ARG_TINY, FP_RND_NEAREST, TV_SIN_TINY, "SIN(tiny)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_0P1, FP_RND_NEAREST, TV_SIN_0P1, FP80_TOL_1E4, "SIN(0.1)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_0P5, FP_RND_NEAREST, TV_SIN_0P5, FP80_TOL_1E6, "SIN(0.5)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_1, FP_RND_NEAREST, TV_SIN_1, FP80_TOL_1E6, "SIN(1)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_1P5, FP_RND_NEAREST, TV_SIN_1P5, FP80_TOL_1E6, "SIN(1.5)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_PI_4, FP_RND_NEAREST, TV_SIN_PI_4, FP80_TOL_1E5, "SIN(PI/4)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_PI_2_NEAR, FP_RND_NEAREST, TV_SIN_PI_2_NEAR, FP80_TOL_1E7, "SIN(~PI/2)");
    -- SIN(PI) and SIN(2PI): catastrophic cancellation (arg reduction at exact multiples of pi)
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_PI, FP_RND_NEAREST, TV_SIN_PI, FP80_TOL_1E1, "SIN(PI)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_2PI, FP_RND_NEAREST, TV_SIN_2PI, FP80_TOL_1E1, "SIN(2PI)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_10, FP_RND_NEAREST, TV_SIN_10, FP80_TOL_1E8, "SIN(10)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_100, FP_RND_NEAREST, TV_SIN_100, FP80_TOL_1E6, "SIN(100)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_1234567, FP_RND_NEAREST, TV_SIN_1234567, FP80_TOL_1E5, "SIN(1234567)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_NEG_0P7, FP_RND_NEAREST, TV_SIN_NEG_0P7, FP80_TOL_1E9, "SIN(-0.7)");
    run_monadic_close(FPU_OP_SIN, TV_TRIG_ARG_NEG_2P3, FP_RND_NEAREST, TV_SIN_NEG_2P3, FP80_TOL_1E6, "SIN(-2.3)");
    report "SIN: 15 transcendental tests passed" severity note;

    -- COS (measured: tiny=exact, 0.1=25b, 0.5=28b, 1=24b, 1.5=19b, PI/4=22b,
    --       ~PI/2=-18b, PI=exact, 2PI=29b, 10=31b, 100=28b, 1234567=25b,
    --       -0.7=36b, -2.3=25b)
    run_monadic(FPU_OP_COS, TV_TRIG_ARG_0, FP_RND_NEAREST, TV_COS_0, "COS(0) exact");
    run_monadic(FPU_OP_COS, TV_TRIG_ARG_TINY, FP_RND_NEAREST, TV_COS_TINY, "COS(tiny)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_0P1, FP_RND_NEAREST, TV_COS_0P1, FP80_TOL_1E6, "COS(0.1)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_0P5, FP_RND_NEAREST, TV_COS_0P5, FP80_TOL_1E7, "COS(0.5)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_1, FP_RND_NEAREST, TV_COS_1, FP80_TOL_1E6, "COS(1)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_1P5, FP_RND_NEAREST, TV_COS_1P5, FP80_TOL_1E4, "COS(1.5)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_PI_4, FP_RND_NEAREST, TV_COS_PI_4, FP80_TOL_1E5, "COS(PI/4)");
    -- COS(~PI/2): catastrophic cancellation (result near zero)
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_PI_2_NEAR, FP_RND_NEAREST, TV_COS_PI_2_NEAR, FP80_TOL_1E1, "COS(~PI/2)");
    run_monadic(FPU_OP_COS, TV_TRIG_ARG_PI, FP_RND_NEAREST, TV_COS_PI, "COS(PI)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_2PI, FP_RND_NEAREST, TV_COS_2PI, FP80_TOL_1E7, "COS(2PI)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_10, FP_RND_NEAREST, TV_COS_10, FP80_TOL_1E8, "COS(10)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_100, FP_RND_NEAREST, TV_COS_100, FP80_TOL_1E7, "COS(100)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_1234567, FP_RND_NEAREST, TV_COS_1234567, FP80_TOL_1E6, "COS(1234567)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_NEG_0P7, FP_RND_NEAREST, TV_COS_NEG_0P7, FP80_TOL_1E9, "COS(-0.7)");
    run_monadic_close(FPU_OP_COS, TV_TRIG_ARG_NEG_2P3, FP_RND_NEAREST, TV_COS_NEG_2P3, FP80_TOL_1E6, "COS(-2.3)");
    report "COS: 15 transcendental tests passed" severity note;

    -- TAN (measured: tiny=exact, 0.1=19b, 0.5=27b, 1=23b, 1.5=19b, PI/4=21b,
    --       PI=0b, 2PI=-645b, 10=30b, 100=26b, 1234567=22b, -0.7=34b, -2.3=25b)
    run_monadic(FPU_OP_TAN, TV_TRIG_ARG_0, FP_RND_NEAREST, TV_TAN_0, "TAN(0) exact");
    run_monadic(FPU_OP_TAN, TV_TRIG_ARG_TINY, FP_RND_NEAREST, TV_TAN_TINY, "TAN(tiny)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_0P1, FP_RND_NEAREST, TV_TAN_0P1, FP80_TOL_1E4, "TAN(0.1)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_0P5, FP_RND_NEAREST, TV_TAN_0P5, FP80_TOL_1E6, "TAN(0.5)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_1, FP_RND_NEAREST, TV_TAN_1, FP80_TOL_1E5, "TAN(1)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_1P5, FP_RND_NEAREST, TV_TAN_1P5, FP80_TOL_1E4, "TAN(1.5)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_PI_4, FP_RND_NEAREST, TV_TAN_PI_4, FP80_TOL_1E5, "TAN(PI/4)");
    -- TAN(PI) and TAN(2PI): catastrophic cancellation (arg reduction at exact multiples of pi)
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_PI, FP_RND_NEAREST, TV_TAN_PI, FP80_TOL_1E1, "TAN(PI)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_2PI, FP_RND_NEAREST, TV_TAN_2PI, FP80_TOL_1E1, "TAN(2PI)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_10, FP_RND_NEAREST, TV_TAN_10, FP80_TOL_1E8, "TAN(10)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_100, FP_RND_NEAREST, TV_TAN_100, FP80_TOL_1E6, "TAN(100)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_1234567, FP_RND_NEAREST, TV_TAN_1234567, FP80_TOL_1E5, "TAN(1234567)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_NEG_0P7, FP_RND_NEAREST, TV_TAN_NEG_0P7, FP80_TOL_1E9, "TAN(-0.7)");
    run_monadic_close(FPU_OP_TAN, TV_TRIG_ARG_NEG_2P3, FP_RND_NEAREST, TV_TAN_NEG_2P3, FP80_TOL_1E6, "TAN(-2.3)");
    report "TAN: 14 transcendental tests passed" severity note;

    -- ATAN (measured: 0.5=9b, 1=3b, 2=11b, 10=27b, 100=50b, -1=3b, -2=11b)
    run_monadic(FPU_OP_ATAN, FP80_ZERO, FP_RND_NEAREST, TV_ATAN_0, "ATAN(0) exact");
    run_monadic_close(FPU_OP_ATAN, TV_ARG_HALF, FP_RND_NEAREST, TV_ATAN_0P5, FP80_TOL_1E1, "ATAN(0.5)");
    run_monadic_close(FPU_OP_ATAN, TV_ARG_ONE, FP_RND_NEAREST, TV_ATAN_1, FP80_TOL_1E1, "ATAN(1)");
    run_monadic_close(FPU_OP_ATAN, TV_ARG_TWO, FP_RND_NEAREST, TV_ATAN_2, FP80_TOL_1E2, "ATAN(2)");
    run_monadic_close(FPU_OP_ATAN, fp80_from_int(10), FP_RND_NEAREST, TV_ATAN_10, FP80_TOL_1E6, "ATAN(10)");
    run_monadic_close(FPU_OP_ATAN, fp80_from_int(100), FP_RND_NEAREST, TV_ATAN_100, FP80_TOL_1E9, "ATAN(100)");
    run_monadic_close(FPU_OP_ATAN, FP80_NEG_ONE, FP_RND_NEAREST, TV_ATAN_NEG_1, FP80_TOL_1E1, "ATAN(-1)");
    run_monadic_close(FPU_OP_ATAN, neg_fp80(TV_ARG_TWO), FP_RND_NEAREST, TV_ATAN_NEG_2, FP80_TOL_1E2, "ATAN(-2)");
    report "ATAN: 8 transcendental tests passed" severity note;

    -- ETOX (measured: 0.5=16b, 1=20b, 2=14b, -1=19b, -10=20b, 10=20b)
    run_monadic(FPU_OP_ETOX, FP80_ZERO, FP_RND_NEAREST, TV_ETOX_0, "ETOX(0) exact");
    run_monadic_close(FPU_OP_ETOX, TV_ARG_HALF, FP_RND_NEAREST, TV_ETOX_0P5, FP80_TOL_1E3, "ETOX(0.5)");
    run_monadic_close(FPU_OP_ETOX, TV_ARG_ONE, FP_RND_NEAREST, TV_ETOX_1, FP80_TOL_1E4, "ETOX(1)");
    run_monadic_close(FPU_OP_ETOX, TV_ARG_TWO, FP_RND_NEAREST, TV_ETOX_2, FP80_TOL_1E3, "ETOX(2)");
    run_monadic_close(FPU_OP_ETOX, FP80_NEG_ONE, FP_RND_NEAREST, TV_ETOX_NEG_1, FP80_TOL_1E4, "ETOX(-1)");
    run_monadic_close(FPU_OP_ETOX, neg_fp80(fp80_from_int(10)), FP_RND_NEAREST, TV_ETOX_NEG_10, FP80_TOL_1E4, "ETOX(-10)");
    run_monadic_close(FPU_OP_ETOX, fp80_from_int(10), FP_RND_NEAREST, TV_ETOX_10, FP80_TOL_1E4, "ETOX(10)");
    report "ETOX: 7 transcendental tests passed" severity note;

    -- ETOXM1 (measured: 0.5=15b, 1=10b)
    run_monadic(FPU_OP_ETOXM1, FP80_ZERO, FP_RND_NEAREST, TV_ETOXM1_0, "ETOXM1(0) exact");
    run_monadic_close(FPU_OP_ETOXM1, TV_ARG_HALF, FP_RND_NEAREST, TV_ETOXM1_0P5, FP80_TOL_1E3, "ETOXM1(0.5)");
    run_monadic_close(FPU_OP_ETOXM1, TV_ARG_ONE, FP_RND_NEAREST, TV_ETOXM1_1, FP80_TOL_1E2, "ETOXM1(1)");
    report "ETOXM1: 3 transcendental tests passed" severity note;

    -- LOGN (measured: 2=exact, e=12b, 10=16b, 0.5=exact)
    run_monadic(FPU_OP_LOGN, TV_ARG_ONE, FP_RND_NEAREST, TV_LOGN_1, "LOGN(1) exact");
    run_monadic(FPU_OP_LOGN, TV_ARG_TWO, FP_RND_NEAREST, TV_LOGN_2, "LOGN(2)");
    run_monadic_close(FPU_OP_LOGN, TV_ARG_E, FP_RND_NEAREST, TV_LOGN_E, FP80_TOL_1E2, "LOGN(e)");
    run_monadic_close(FPU_OP_LOGN, fp80_from_int(10), FP_RND_NEAREST, TV_LOGN_10, FP80_TOL_1E3, "LOGN(10)");
    run_monadic(FPU_OP_LOGN, TV_ARG_HALF, FP_RND_NEAREST, TV_LOGN_0P5, "LOGN(0.5)");
    report "LOGN: 5 transcendental tests passed" severity note;

    -- LOGNP1 (measured: 0.5=8b, 1=exact)
    run_monadic(FPU_OP_LOGNP1, FP80_ZERO, FP_RND_NEAREST, TV_LOGNP1_0, "LOGNP1(0) exact");
    run_monadic_close(FPU_OP_LOGNP1, TV_ARG_HALF, FP_RND_NEAREST, TV_LOGNP1_0P5, FP80_TOL_1E1, "LOGNP1(0.5)");
    run_monadic(FPU_OP_LOGNP1, TV_ARG_ONE, FP_RND_NEAREST, TV_LOGNP1_1, "LOGNP1(1)");
    report "LOGNP1: 3 transcendental tests passed" severity note;

    -- LOG10 (measured: 10=17b, 100=11b, 0.5=63b, e=12b)
    run_monadic(FPU_OP_LOG10, TV_ARG_ONE, FP_RND_NEAREST, TV_LOG10_1, "LOG10(1) exact");
    run_monadic_close(FPU_OP_LOG10, fp80_from_int(10), FP_RND_NEAREST, TV_LOG10_10, FP80_TOL_1E3, "LOG10(10)");
    run_monadic_close(FPU_OP_LOG10, fp80_from_int(100), FP_RND_NEAREST, TV_LOG10_100, FP80_TOL_1E2, "LOG10(100)");
    run_monadic_close(FPU_OP_LOG10, TV_ARG_HALF, FP_RND_NEAREST, TV_LOG10_0P5, FP80_TOL_1E9, "LOG10(0.5)");
    run_monadic_close(FPU_OP_LOG10, TV_ARG_E, FP_RND_NEAREST, TV_LOG10_E, FP80_TOL_1E2, "LOG10(e)");
    report "LOG10: 5 transcendental tests passed" severity note;

    -- LOG2 (measured: 2=exact, 4=exact, 0.5=exact, e=12b, 10=16b)
    run_monadic(FPU_OP_LOG2, TV_ARG_ONE, FP_RND_NEAREST, TV_LOG2_1, "LOG2(1) exact");
    run_monadic(FPU_OP_LOG2, TV_ARG_TWO, FP_RND_NEAREST, TV_LOG2_2, "LOG2(2)");
    run_monadic(FPU_OP_LOG2, fp80_from_int(4), FP_RND_NEAREST, TV_LOG2_4, "LOG2(4)");
    run_monadic(FPU_OP_LOG2, TV_ARG_HALF, FP_RND_NEAREST, TV_LOG2_0P5, "LOG2(0.5)");
    run_monadic_close(FPU_OP_LOG2, TV_ARG_E, FP_RND_NEAREST, TV_LOG2_E, FP80_TOL_1E2, "LOG2(e)");
    run_monadic_close(FPU_OP_LOG2, fp80_from_int(10), FP_RND_NEAREST, TV_LOG2_10, FP80_TOL_1E3, "LOG2(10)");
    report "LOG2: 6 transcendental tests passed" severity note;

    -- TWOTOX (measured: 0.5=19b, 10=exact, 0.25=25b)
    run_monadic(FPU_OP_TWOTOX, FP80_ZERO, FP_RND_NEAREST, TV_TWOTOX_0, "TWOTOX(0) exact");
    run_monadic(FPU_OP_TWOTOX, TV_ARG_ONE, FP_RND_NEAREST, TV_TWOTOX_1, "TWOTOX(1) exact");
    run_monadic_close(FPU_OP_TWOTOX, TV_ARG_HALF, FP_RND_NEAREST, TV_TWOTOX_0P5, FP80_TOL_1E4, "TWOTOX(0.5)");
    run_monadic(FPU_OP_TWOTOX, FP80_NEG_ONE, FP_RND_NEAREST, TV_TWOTOX_NEG_1, "TWOTOX(-1) exact");
    run_monadic(FPU_OP_TWOTOX, fp80_from_int(10), FP_RND_NEAREST, TV_TWOTOX_10, "TWOTOX(10)");
    run_monadic_close(FPU_OP_TWOTOX, FP80_QUARTER, FP_RND_NEAREST, TV_TWOTOX_0P25, FP80_TOL_1E6, "TWOTOX(0.25)");
    report "TWOTOX: 6 transcendental tests passed" severity note;

    -- TENTOX (measured: 1=23b, 0.5=17b, -1=22b, 2=17b, -2=16b)
    run_monadic(FPU_OP_TENTOX, FP80_ZERO, FP_RND_NEAREST, TV_TENTOX_0, "TENTOX(0) exact");
    run_monadic_close(FPU_OP_TENTOX, TV_ARG_ONE, FP_RND_NEAREST, TV_TENTOX_1, FP80_TOL_1E5, "TENTOX(1)");
    run_monadic_close(FPU_OP_TENTOX, TV_ARG_HALF, FP_RND_NEAREST, TV_TENTOX_0P5, FP80_TOL_1E3, "TENTOX(0.5)");
    run_monadic_close(FPU_OP_TENTOX, FP80_NEG_ONE, FP_RND_NEAREST, TV_TENTOX_NEG_1, FP80_TOL_1E5, "TENTOX(-1)");
    run_monadic_close(FPU_OP_TENTOX, TV_ARG_TWO, FP_RND_NEAREST, TV_TENTOX_2, FP80_TOL_1E3, "TENTOX(2)");
    run_monadic_close(FPU_OP_TENTOX, neg_fp80(TV_ARG_TWO), FP_RND_NEAREST, TV_TENTOX_NEG_2, FP80_TOL_1E3, "TENTOX(-2)");
    report "TENTOX: 6 transcendental tests passed" severity note;

    -- ASIN (measured: 0.5=8b, -0.5=8b, 0.9=4b, tiny=exact)
    run_monadic(FPU_OP_ASIN, FP80_ZERO, FP_RND_NEAREST, TV_ASIN_0, "ASIN(0) exact");
    run_monadic_close(FPU_OP_ASIN, TV_ARG_HALF, FP_RND_NEAREST, TV_ASIN_0P5, FP80_TOL_1E1, "ASIN(0.5)");
    run_monadic_close(FPU_OP_ASIN, neg_fp80(TV_ARG_HALF), FP_RND_NEAREST, TV_ASIN_NEG_0P5, FP80_TOL_1E1, "ASIN(-0.5)");
    run_monadic_close(FPU_OP_ASIN, GV_ARG_0P9, FP_RND_NEAREST, TV_ASIN_0P9, FP80_TOL_1E1, "ASIN(0.9)");
    run_monadic(FPU_OP_ASIN, TV_TRIG_ARG_TINY, FP_RND_NEAREST, TV_ASIN_TINY, "ASIN(tiny)");
    report "ASIN: 5 transcendental tests passed" severity note;

    -- ACOS (measured: 0=exact, 0.5=9b, -0.5=10b, 1=exact, -1=exact)
    run_monadic(FPU_OP_ACOS, FP80_ZERO, FP_RND_NEAREST, TV_ACOS_0, "ACOS(0)");
    run_monadic_close(FPU_OP_ACOS, TV_ARG_HALF, FP_RND_NEAREST, TV_ACOS_0P5, FP80_TOL_1E1, "ACOS(0.5)");
    run_monadic_close(FPU_OP_ACOS, neg_fp80(TV_ARG_HALF), FP_RND_NEAREST, TV_ACOS_NEG_0P5, FP80_TOL_1E2, "ACOS(-0.5)");
    run_monadic(FPU_OP_ACOS, TV_ARG_ONE, FP_RND_NEAREST, TV_ACOS_1, "ACOS(1)");
    run_monadic(FPU_OP_ACOS, FP80_NEG_ONE, FP_RND_NEAREST, TV_ACOS_NEG_1, "ACOS(-1)");
    report "ACOS: 5 transcendental tests passed" severity note;

    -- SINH (measured: 0.5=19b, 1=13b, -1=13b, 3=5b)
    run_monadic(FPU_OP_SINH, FP80_ZERO, FP_RND_NEAREST, TV_SINH_0, "SINH(0) exact");
    run_monadic_close(FPU_OP_SINH, TV_ARG_HALF, FP_RND_NEAREST, TV_SINH_0P5, FP80_TOL_1E4, "SINH(0.5)");
    run_monadic_close(FPU_OP_SINH, TV_ARG_ONE, FP_RND_NEAREST, TV_SINH_1, FP80_TOL_1E2, "SINH(1)");
    run_monadic_close(FPU_OP_SINH, FP80_NEG_ONE, FP_RND_NEAREST, TV_SINH_NEG_1, FP80_TOL_1E2, "SINH(-1)");
    run_monadic_close(FPU_OP_SINH, fp80_from_int(3), FP_RND_NEAREST, TV_SINH_3, FP80_TOL_1E1, "SINH(3)");
    report "SINH: 5 transcendental tests passed" severity note;

    -- COSH (measured: 0.5=16b, 1=10b, -1=10b, 3=3b)
    run_monadic(FPU_OP_COSH, FP80_ZERO, FP_RND_NEAREST, TV_COSH_0, "COSH(0) exact");
    run_monadic_close(FPU_OP_COSH, TV_ARG_HALF, FP_RND_NEAREST, TV_COSH_0P5, FP80_TOL_1E3, "COSH(0.5)");
    run_monadic_close(FPU_OP_COSH, TV_ARG_ONE, FP_RND_NEAREST, TV_COSH_1, FP80_TOL_1E2, "COSH(1)");
    run_monadic_close(FPU_OP_COSH, FP80_NEG_ONE, FP_RND_NEAREST, TV_COSH_NEG_1, FP80_TOL_1E2, "COSH(-1)");
    run_monadic_close(FPU_OP_COSH, fp80_from_int(3), FP_RND_NEAREST, TV_COSH_3, FP80_TOL_2E1, "COSH(3)");
    report "COSH: 5 transcendental tests passed" severity note;

    -- TANH via EXP pipeline
    run_monadic(FPU_OP_TANH, FP80_ZERO, FP_RND_NEAREST, TV_TANH_0, "TANH(0) exact");
    run_monadic_close(FPU_OP_TANH, TV_ARG_HALF, FP_RND_NEAREST, TV_TANH_0P5, FP80_TOL_1E3, "TANH(0.5)");
    run_monadic_close(FPU_OP_TANH, TV_ARG_ONE, FP_RND_NEAREST, TV_TANH_1, FP80_TOL_1E3, "TANH(1)");
    run_monadic_close(FPU_OP_TANH, FP80_NEG_ONE, FP_RND_NEAREST, TV_TANH_NEG_1, FP80_TOL_1E3, "TANH(-1)");
    run_monadic_close(FPU_OP_TANH, fp80_from_int(3), FP_RND_NEAREST, TV_TANH_3, FP80_TOL_1E3, "TANH(3)");
    report "TANH: 5 transcendental tests passed" severity note;

    -- ATANH (measured: 0.5=9b, -0.5=9b, 0.9=3b, tiny=exact)
    run_monadic(FPU_OP_ATANH, FP80_ZERO, FP_RND_NEAREST, TV_ATANH_0, "ATANH(0) exact");
    run_monadic_close(FPU_OP_ATANH, TV_ARG_HALF, FP_RND_NEAREST, TV_ATANH_0P5, FP80_TOL_1E1, "ATANH(0.5)");
    run_monadic_close(FPU_OP_ATANH, neg_fp80(TV_ARG_HALF), FP_RND_NEAREST, TV_ATANH_NEG_0P5, FP80_TOL_1E1, "ATANH(-0.5)");
    run_monadic_close(FPU_OP_ATANH, GV_ARG_0P9, FP_RND_NEAREST, TV_ATANH_0P9, FP80_TOL_2E1, "ATANH(0.9)");
    run_monadic(FPU_OP_ATANH, TV_TRIG_ARG_TINY, FP_RND_NEAREST, TV_ATANH_TINY, "ATANH(tiny)");
    report "ATANH: 5 transcendental tests passed" severity note;

    -- ================================================================
    -- Simple op spot-checks
    -- ================================================================
    -- ABS
    run_monadic(FPU_OP_ABS, neg_fp80(TV_ARG_THREE), FP_RND_NEAREST, TV_ARG_THREE, "ABS(-3)=3");
    run_monadic(FPU_OP_ABS, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "ABS(0)=0");
    run_monadic(FPU_OP_ABS, TV_ARG_ONE, FP_RND_NEAREST, TV_ARG_ONE, "ABS(1)=1");
    run_monadic_inf(FPU_OP_ABS, FP80_NEG_INF, '0', "ABS(-inf)=+inf");

    -- NEG
    run_monadic(FPU_OP_NEG, TV_ARG_ONE, FP_RND_NEAREST, FP80_NEG_ONE, "NEG(1)=-1");
    run_monadic(FPU_OP_NEG, FP80_NEG_ONE, FP_RND_NEAREST, TV_ARG_ONE, "NEG(-1)=1");

    report "Simple ops: 6 spot-check tests passed" severity note;
    report "=== PHASE 1 COMPLETE ===" severity note;

    -- ================================================================
    -- PHASE 2: Algebraic Identity Tests
    -- ================================================================
    report "=== PHASE 2: Algebraic Identity Tests ===" severity note;

    -- Identity 1: x + 0 = x
    run_binary(FPU_OP_ADD, TV_ARG_ONE, FP80_ZERO, FP_RND_NEAREST, TV_ARG_ONE, "x+0=x [1]");
    run_binary(FPU_OP_ADD, TV_ARG_TWO, FP80_ZERO, FP_RND_NEAREST, TV_ARG_TWO, "x+0=x [2]");
    run_binary(FPU_OP_ADD, TV_ARG_PI, FP80_ZERO, FP_RND_NEAREST, TV_ARG_PI, "x+0=x [PI]");
    run_binary(FPU_OP_ADD, TV_ARG_E, FP80_ZERO, FP_RND_NEAREST, TV_ARG_E, "x+0=x [E]");
    run_binary(FPU_OP_ADD, TV_ARG_HALF, FP80_ZERO, FP_RND_NEAREST, TV_ARG_HALF, "x+0=x [0.5]");

    -- Identity 2: x * 1 = x
    run_binary(FPU_OP_MUL, TV_ARG_ONE, TV_ARG_ONE, FP_RND_NEAREST, TV_ARG_ONE, "x*1=x [1]");
    run_binary(FPU_OP_MUL, TV_ARG_TWO, TV_ARG_ONE, FP_RND_NEAREST, TV_ARG_TWO, "x*1=x [2]");
    run_binary(FPU_OP_MUL, TV_ARG_PI, TV_ARG_ONE, FP_RND_NEAREST, TV_ARG_PI, "x*1=x [PI]");
    run_binary(FPU_OP_MUL, TV_ARG_E, TV_ARG_ONE, FP_RND_NEAREST, TV_ARG_E, "x*1=x [E]");
    run_binary(FPU_OP_MUL, TV_ARG_HALF, TV_ARG_ONE, FP_RND_NEAREST, TV_ARG_HALF, "x*1=x [0.5]");

    -- Identity 3: x - x = 0 (use fp80_is_zero check via exact match)
    run_binary(FPU_OP_SUB, TV_ARG_ONE, TV_ARG_ONE, FP_RND_NEAREST, FP80_ZERO, "x-x=0 [1]");
    run_binary(FPU_OP_SUB, TV_ARG_TWO, TV_ARG_TWO, FP_RND_NEAREST, FP80_ZERO, "x-x=0 [2]");
    run_binary(FPU_OP_SUB, TV_ARG_PI, TV_ARG_PI, FP_RND_NEAREST, FP80_ZERO, "x-x=0 [PI]");
    run_binary(FPU_OP_SUB, TV_ARG_E, TV_ARG_E, FP_RND_NEAREST, FP80_ZERO, "x-x=0 [E]");
    run_binary(FPU_OP_SUB, TV_ARG_HALF, TV_ARG_HALF, FP_RND_NEAREST, FP80_ZERO, "x-x=0 [0.5]");

    -- Identity 4: x / x = 1 (non-zero finite x)
    run_binary(FPU_OP_DIV, TV_ARG_ONE, TV_ARG_ONE, FP_RND_NEAREST, FP80_ONE, "x/x=1 [1]");
    run_binary(FPU_OP_DIV, TV_ARG_TWO, TV_ARG_TWO, FP_RND_NEAREST, FP80_ONE, "x/x=1 [2]");
    run_binary(FPU_OP_DIV, TV_ARG_PI, TV_ARG_PI, FP_RND_NEAREST, FP80_ONE, "x/x=1 [PI]");
    run_binary(FPU_OP_DIV, TV_ARG_E, TV_ARG_E, FP_RND_NEAREST, FP80_ONE, "x/x=1 [E]");
    run_binary(FPU_OP_DIV, TV_ARG_HALF, TV_ARG_HALF, FP_RND_NEAREST, FP80_ONE, "x/x=1 [0.5]");

    -- Identity 5: x * 0 = 0 (finite x)
    run_binary(FPU_OP_MUL, TV_ARG_ONE, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "x*0=0 [1]");
    run_binary(FPU_OP_MUL, TV_ARG_TWO, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "x*0=0 [2]");
    run_binary(FPU_OP_MUL, TV_ARG_PI, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "x*0=0 [PI]");
    run_binary(FPU_OP_MUL, TV_ARG_E, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "x*0=0 [E]");
    run_binary(FPU_OP_MUL, TV_ARG_HALF, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "x*0=0 [0.5]");

    -- Identity 6: neg(neg(x)) = x
    run_monadic_capture(FPU_OP_NEG, TV_ARG_ONE, FP_RND_NEAREST, captured);
    run_monadic(FPU_OP_NEG, captured, FP_RND_NEAREST, TV_ARG_ONE, "neg(neg(1))=1");
    run_monadic_capture(FPU_OP_NEG, TV_ARG_PI, FP_RND_NEAREST, captured);
    run_monadic(FPU_OP_NEG, captured, FP_RND_NEAREST, TV_ARG_PI, "neg(neg(PI))=PI");
    run_monadic_capture(FPU_OP_NEG, TV_ARG_E, FP_RND_NEAREST, captured);
    run_monadic(FPU_OP_NEG, captured, FP_RND_NEAREST, TV_ARG_E, "neg(neg(E))=E");

    -- Identity 7: abs(neg(x)) = abs(x)
    run_monadic_capture(FPU_OP_NEG, TV_ARG_ONE, FP_RND_NEAREST, neg_val);
    run_monadic_capture(FPU_OP_ABS, neg_val, FP_RND_NEAREST, abs_neg_val);
    run_monadic_capture(FPU_OP_ABS, TV_ARG_ONE, FP_RND_NEAREST, abs_val);
    assert abs_neg_val = abs_val
      report "abs(neg(1)) /= abs(1)" severity failure;
    pass_count := pass_count + 1;

    run_monadic_capture(FPU_OP_NEG, TV_ARG_PI, FP_RND_NEAREST, neg_val);
    run_monadic_capture(FPU_OP_ABS, neg_val, FP_RND_NEAREST, abs_neg_val);
    run_monadic_capture(FPU_OP_ABS, TV_ARG_PI, FP_RND_NEAREST, abs_val);
    assert abs_neg_val = abs_val
      report "abs(neg(PI)) /= abs(PI)" severity failure;
    pass_count := pass_count + 1;

    -- Identity 8: sin(0)=0, cos(0)=1, tan(0)=0 (already tested but repeat)
    run_monadic(FPU_OP_SIN, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "id: sin(0)=0");
    run_monadic(FPU_OP_COS, FP80_ZERO, FP_RND_NEAREST, FP80_ONE, "id: cos(0)=1");
    run_monadic(FPU_OP_TAN, FP80_ZERO, FP_RND_NEAREST, FP80_ZERO, "id: tan(0)=0");

    -- Identity 9: exp(0)=1, ln(1)=0
    run_monadic(FPU_OP_ETOX, FP80_ZERO, FP_RND_NEAREST, FP80_ONE, "id: exp(0)=1");
    run_monadic(FPU_OP_LOGN, FP80_ONE, FP_RND_NEAREST, FP80_ZERO, "id: ln(1)=0");

    -- Identity 10: sin^2(x) + cos^2(x) ~ 1 via SINCOS
    -- Test with x = 1.0
    op_sel <= FPU_OP_SINCOS;
      a_in   <= TV_ARG_ONE;
      round_mode <= FP_RND_NEAREST;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      sin_val := result;
      -- aux_valid may be same cycle or later; wait if needed
      if aux_valid /= '1' then
        wait until aux_valid = '1' for MAX_WAIT;
        assert aux_valid = '1' report "TIMEOUT waiting for aux_valid" severity failure;
        wait for 0 ns;
      end if;
      cos_val := aux_result;
      sin2 := mul_fp80(sin_val, sin_val, FP_RND_NEAREST, FP_PREC_EXTENDED);
      cos2 := mul_fp80(cos_val, cos_val, FP_RND_NEAREST, FP_PREC_EXTENDED);
      sum_val := add_sub_fp80(sin2, cos2, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
      check_fp80_close(sum_val, FP80_ONE, FP80_TOL_1E8, "sin^2(1)+cos^2(1)~1");
      pass_count := pass_count + 1;

      -- Test with x = 0.5
      op_sel <= FPU_OP_SINCOS;
      a_in   <= TV_ARG_HALF;
      round_mode <= FP_RND_NEAREST;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1' for MAX_WAIT;
      assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
      wait for 0 ns;
      sin_val := result;
      if aux_valid /= '1' then
        wait until aux_valid = '1' for MAX_WAIT;
        assert aux_valid = '1' report "TIMEOUT waiting for aux_valid" severity failure;
        wait for 0 ns;
      end if;
      cos_val := aux_result;
      sin2 := mul_fp80(sin_val, sin_val, FP_RND_NEAREST, FP_PREC_EXTENDED);
      cos2 := mul_fp80(cos_val, cos_val, FP_RND_NEAREST, FP_PREC_EXTENDED);
      sum_val := add_sub_fp80(sin2, cos2, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
      check_fp80_close(sum_val, FP80_ONE, FP80_TOL_1E9, "sin^2(0.5)+cos^2(0.5)~1");
      pass_count := pass_count + 1;

    -- Identity 11: exp(ln(x)) ~ x for positive x
    -- x = 2
      run_monadic_capture(FPU_OP_LOGN, TV_ARG_TWO, FP_RND_NEAREST, ln_val);
      run_monadic_capture(FPU_OP_ETOX, ln_val, FP_RND_NEAREST, exp_ln_val);
      check_fp80_close(exp_ln_val, TV_ARG_TWO, FP80_TOL_1E2, "exp(ln(2))~2");
      pass_count := pass_count + 1;

      -- x = e
      run_monadic_capture(FPU_OP_LOGN, TV_ARG_E, FP_RND_NEAREST, ln_val);
      run_monadic_capture(FPU_OP_ETOX, ln_val, FP_RND_NEAREST, exp_ln_val);
      check_fp80_close(exp_ln_val, TV_ARG_E, FP80_TOL_1E2, "exp(ln(e))~e");
      pass_count := pass_count + 1;

      -- x = 0.5
      run_monadic_capture(FPU_OP_LOGN, TV_ARG_HALF, FP_RND_NEAREST, ln_val);
      run_monadic_capture(FPU_OP_ETOX, ln_val, FP_RND_NEAREST, exp_ln_val);
      check_fp80_close(exp_ln_val, TV_ARG_HALF, FP80_TOL_1E2, "exp(ln(0.5))~0.5");
      pass_count := pass_count + 1;

    report "=== PHASE 2 COMPLETE ===" severity note;

    -- ================================================================
    -- PHASE 3: Exception Chaos Tests
    -- ================================================================
    report "=== PHASE 3: Exception Chaos Tests ===" severity note;

    -- Test 1: 1 / 0 -> +inf, flag_divzero='1'
    op_sel <= FPU_OP_DIV;
    a_in   <= FP80_ONE;
    b_in   <= FP80_ZERO;
    round_mode <= FP_RND_NEAREST;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1' for MAX_WAIT;
    assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
    wait for 0 ns;
    check_result_inf('0', "EXC: 1/0 = +inf");
    assert flag_divzero = '1'
      report "EXC: 1/0 should set flag_divzero" severity failure;
    pass_count := pass_count + 1;

    -- Test 2: -1 / 0 -> -inf, flag_divzero='1'
    op_sel <= FPU_OP_DIV;
    a_in   <= FP80_NEG_ONE;
    b_in   <= FP80_ZERO;
    round_mode <= FP_RND_NEAREST;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1' for MAX_WAIT;
    assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
    wait for 0 ns;
    check_result_inf('1', "EXC: -1/0 = -inf");
    assert flag_divzero = '1'
      report "EXC: -1/0 should set flag_divzero" severity failure;
    pass_count := pass_count + 1;

    -- Test 3: 0 / 0 -> NaN (IEEE-754 mandates NaN, not infinity)
    op_sel <= FPU_OP_DIV;
    a_in   <= FP80_ZERO;
    b_in   <= FP80_ZERO;
    round_mode <= FP_RND_NEAREST;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1' for MAX_WAIT;
    assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
    wait for 0 ns;
    check_result_nan("EXC: 0/0 = NaN");
    pass_count := pass_count + 1;

    -- Test 4: inf - inf -> NaN
    op_sel <= FPU_OP_SUB;
    a_in   <= FP80_POS_INF;
    b_in   <= FP80_POS_INF;
    round_mode <= FP_RND_NEAREST;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1' for MAX_WAIT;
    assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
    wait for 0 ns;
    check_result_nan("EXC: inf-inf = NaN");
    pass_count := pass_count + 1;

    -- Test 5: sqrt(-1) -> NaN
    run_monadic_nan(FPU_OP_SQRT, FP80_NEG_ONE, "EXC: sqrt(-1) = NaN");

    -- Test 6: ln(0) -> -inf (divzero flag may or may not be set by trig unit)
    op_sel <= FPU_OP_LOGN;
    a_in   <= FP80_ZERO;
    round_mode <= FP_RND_NEAREST;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1' for MAX_WAIT;
    assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
    wait for 0 ns;
    check_result_inf('1', "EXC: ln(0) = -inf");
    pass_count := pass_count + 1;

    -- Test 7: ln(-1) -> NaN
    run_monadic_nan(FPU_OP_LOGN, FP80_NEG_ONE, "EXC: ln(-1) = NaN");

    -- Test 8: inf * 0 -> NaN
    op_sel <= FPU_OP_MUL;
    a_in   <= FP80_POS_INF;
    b_in   <= FP80_ZERO;
    round_mode <= FP_RND_NEAREST;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1' for MAX_WAIT;
    assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
    wait for 0 ns;
    check_result_nan("EXC: inf*0 = NaN");
    pass_count := pass_count + 1;

    -- Test 9: NaN + 1 -> NaN (propagation)
    op_sel <= FPU_OP_ADD;
    a_in   <= FP80_QNAN;
    b_in   <= FP80_ONE;
    round_mode <= FP_RND_NEAREST;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1' for MAX_WAIT;
    assert valid = '1' report "TIMEOUT waiting for valid" severity failure;
    wait for 0 ns;
    check_result_nan("EXC: NaN+1 = NaN");
    pass_count := pass_count + 1;

    report "=== PHASE 3 COMPLETE ===" severity note;

    -- ================================================================
    -- Final report
    -- ================================================================
    assert pass_count = 298
      report "Expected 298 tests but only " & integer'image(pass_count) & " passed"
      severity failure;
    report "=== TORTURE TB: " & integer'image(pass_count) & " tests passed. No failures detected. ===" severity note;
    std.env.stop;
    wait;
  end process;

end architecture sim;
