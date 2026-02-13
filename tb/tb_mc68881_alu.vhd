library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_alu is
end entity tb_mc68881_alu;

architecture sim of tb_mc68881_alu is
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
  signal busy   : std_logic;
  signal cycle_cnt : natural := 0;

  constant CLK_PERIOD : time := 10 ns;
  constant ADD_LATENCY : natural := 1;
  constant SUB_LATENCY : natural := 1;
  constant MUL_LATENCY : natural := 4;
  constant DIV_LATENCY : natural := 8;
  constant CMP_LATENCY : natural := 1;
  constant MOD_LATENCY : natural := 8;
  constant REM_LATENCY : natural := 8;
  constant SCALE_LATENCY : natural := 2;
  constant SGLDIV_LATENCY : natural := 8;
  constant SGLMUL_LATENCY : natural := 4;
  constant SIN_LATENCY : natural := 14;
  constant COS_LATENCY : natural := 14;
  constant TAN_LATENCY : natural := 15;
  constant SINCOS_LATENCY : natural := 14;

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

  function fp80_from_int(value : integer) return fp80_t is
  begin
    return work.mc68881_pkg.fp80_from_int(value);
  end function;

  function make_fp80(
    constant sign : std_logic;
    constant exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    constant mant : unsigned(FP_MANT_WIDTH-1 downto 0)
  ) return fp80_t is
    variable fp_value : fp80_t := (others => '0');
  begin
    fp_value(FP_WIDTH-1) := sign;
    fp_value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(exp);
    fp_value(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(mant);
    return fp_value;
  end function;

  constant DIV_1_15_EXP : unsigned(FP_EXP_WIDTH-1 downto 0) := to_unsigned(16#3FFB#, FP_EXP_WIDTH);
  constant DIV_1_15_MANT : unsigned(FP_MANT_WIDTH-1 downto 0) := x"8888888888888889";
  constant DIV_1_15_EXPECTED : fp80_t := make_fp80('0', DIV_1_15_EXP, DIV_1_15_MANT);
  constant DIV_1_7_EXP : unsigned(FP_EXP_WIDTH-1 downto 0) := to_unsigned(16#3FFC#, FP_EXP_WIDTH);
  constant DIV_1_7_MANT_DOWN : unsigned(FP_MANT_WIDTH-1 downto 0) := x"9249249249249249";
  constant DIV_1_7_MANT_UP : unsigned(FP_MANT_WIDTH-1 downto 0) := x"924924924924924A";
  constant DIV_1_7_RZ_EXPECTED : fp80_t := make_fp80('0', DIV_1_7_EXP, DIV_1_7_MANT_DOWN);
  constant DIV_1_7_RP_EXPECTED : fp80_t := make_fp80('0', DIV_1_7_EXP, DIV_1_7_MANT_UP);
  constant DIV_1_10_EXP : unsigned(FP_EXP_WIDTH-1 downto 0) := to_unsigned(16#3FFB#, FP_EXP_WIDTH);
  constant DIV_1_10_MANT_SINGLE : unsigned(FP_MANT_WIDTH-1 downto 0) := x"CCCCCD0000000000";
  constant DIV_1_10_MANT_DOUBLE : unsigned(FP_MANT_WIDTH-1 downto 0) := x"CCCCCCCCCCCCD000";
  constant DIV_1_10_SINGLE_EXPECTED : fp80_t := make_fp80('0', DIV_1_10_EXP, DIV_1_10_MANT_SINGLE);
  constant DIV_1_10_DOUBLE_EXPECTED : fp80_t := make_fp80('0', DIV_1_10_EXP, DIV_1_10_MANT_DOUBLE);
  constant LARGE_MOD_A : fp80_t := x"40278000000001800000"; -- 2^40 + 3
  constant LARGE_MOD_B : fp80_t := x"40008000000000000000"; -- 2
  constant FP80_ZERO : fp80_t := x"00000000000000000000";
  constant FP80_ONE : fp80_t := x"3FFF8000000000000000";
  constant FP80_HALF_PI : fp80_t := x"3FFFC90FDAA22168C235";
  constant FP80_PI : fp80_t := x"4000C90FDAA22168C235";
  constant SMALL_FASTPATH_ARG : fp80_t := x"3FD78000000000000001";
  constant FP80_POS_INF : fp80_t := x"7FFF8000000000000000";
  constant FP80_QNAN : fp80_t := x"7FFFC000000000000001";

begin
  clk <= not clk after CLK_PERIOD/2;
  cycle_counter : process(clk)
  begin
    if rising_edge(clk) then
      cycle_cnt <= cycle_cnt + 1;
    end if;
  end process;

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
      aux_result => aux_result,
      aux_valid => aux_valid
    );

  process
    variable start_cycle : natural := 0;
    variable expected_small : fp80_t := (others => '0');
    variable busy_cycles : natural := 0;
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    round_mode <= FP_RND_NEAREST;
    round_prec <= FP_PREC_EXTENDED;
    wait for 0 ns;

    -- ADD
    op_sel <= FPU_OP_ADD;
    a_in   <= fp80_from_int(10);
    b_in   <= fp80_from_int(5);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "ADD latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = ADD_LATENCY
      report "ADD latency mismatch"
      severity failure;
    check_result(fp80_from_int(15), "ADD 10+5");

    -- SUB
    op_sel <= FPU_OP_SUB;
    a_in   <= fp80_from_int(10);
    b_in   <= fp80_from_int(3);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "SUB latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = SUB_LATENCY
      report "SUB latency mismatch"
      severity failure;
    check_result(fp80_from_int(7), "SUB 10-3");

    -- SUB negative result
    op_sel <= FPU_OP_SUB;
    a_in   <= fp80_from_int(3);
    b_in   <= fp80_from_int(10);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "SUB neg latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = SUB_LATENCY
      report "SUB negative latency mismatch"
      severity failure;
    check_result(fp80_from_int(-7), "SUB 3-10");

    -- MUL
    op_sel <= FPU_OP_MUL;
    a_in   <= fp80_from_int(7);
    b_in   <= fp80_from_int(9);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "MUL latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = MUL_LATENCY
      report "MUL latency mismatch"
      severity failure;
    check_result(fp80_from_int(63), "MUL 7*9");

    -- DIV
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_from_int(40);
    b_in   <= fp80_from_int(5);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "DIV latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV latency mismatch"
      severity failure;
    check_result(fp80_from_int(8), "DIV 40/5");

    -- DIV fractional rounding (1/15)
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_from_int(1);
    b_in   <= fp80_from_int(15);
    report "DIV 1/15 expected: " & to_hstring(DIV_1_15_EXPECTED)
      severity note;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "DIV 1/15 latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV 1/15 latency mismatch"
      severity failure;
    report "DIV 1/15 result: " & to_hstring(result)
      severity note;
    check_result(DIV_1_15_EXPECTED, "DIV 1/15");

    -- DIV rounding mode (1/7)
    round_prec <= FP_PREC_EXTENDED;
    round_mode <= FP_RND_ZERO;
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_from_int(1);
    b_in   <= fp80_from_int(7);
    report "DIV 1/7 RZ expected: " & to_hstring(DIV_1_7_RZ_EXPECTED)
      severity note;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "DIV 1/7 RZ latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV 1/7 RZ latency mismatch"
      severity failure;
    report "DIV 1/7 RZ result: " & to_hstring(result)
      severity note;
    check_result(DIV_1_7_RZ_EXPECTED, "DIV 1/7 RZ");

    round_mode <= FP_RND_PLUS_INF;
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_from_int(1);
    b_in   <= fp80_from_int(7);
    report "DIV 1/7 RP expected: " & to_hstring(DIV_1_7_RP_EXPECTED)
      severity note;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "DIV 1/7 RP latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV 1/7 RP latency mismatch"
      severity failure;
    report "DIV 1/7 RP result: " & to_hstring(result)
      severity note;
    check_result(DIV_1_7_RP_EXPECTED, "DIV 1/7 RP");

    -- DIV precision control (1/10)
    round_mode <= FP_RND_NEAREST;
    round_prec <= FP_PREC_SINGLE;
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_from_int(1);
    b_in   <= fp80_from_int(10);
    report "DIV 1/10 single expected: " & to_hstring(DIV_1_10_SINGLE_EXPECTED)
      severity note;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "DIV 1/10 single latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV 1/10 single latency mismatch"
      severity failure;
    report "DIV 1/10 single result: " & to_hstring(result)
      severity note;
    check_result(DIV_1_10_SINGLE_EXPECTED, "DIV 1/10 single");

    round_prec <= FP_PREC_DOUBLE;
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_from_int(1);
    b_in   <= fp80_from_int(10);
    report "DIV 1/10 double expected: " & to_hstring(DIV_1_10_DOUBLE_EXPECTED)
      severity note;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "DIV 1/10 double latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV 1/10 double latency mismatch"
      severity failure;
    report "DIV 1/10 double result: " & to_hstring(result)
      severity note;
    check_result(DIV_1_10_DOUBLE_EXPECTED, "DIV 1/10 double");

    -- CMP
    op_sel <= FPU_OP_CMP;
    a_in   <= fp80_from_int(9);
    b_in   <= fp80_from_int(4);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "CMP latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = CMP_LATENCY
      report "CMP latency mismatch"
      severity failure;
    check_result(fp80_from_int(5), "CMP 9-4");

    -- MOD
    op_sel <= FPU_OP_MOD;
    a_in   <= fp80_from_int(17);
    b_in   <= fp80_from_int(5);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "MOD latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = MOD_LATENCY
      report "MOD latency mismatch"
      severity failure;
    check_result(fp80_from_int(2), "MOD 17 mod 5");

    -- MOD zero divisor should return NaN.
    op_sel <= FPU_OP_MOD;
    a_in   <= fp80_from_int(5);
    b_in   <= fp80_from_int(0);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "MOD divide-by-zero latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = MOD_LATENCY
      report "MOD divide-by-zero latency mismatch"
      severity failure;
    check_result_nan("MOD 5 mod 0");

    -- MOD large quotient regression (|a/b| >= 2^31)
    op_sel <= FPU_OP_MOD;
    a_in   <= LARGE_MOD_A;
    b_in   <= LARGE_MOD_B;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "MOD large-quotient latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = MOD_LATENCY
      report "MOD large-quotient latency mismatch"
      severity failure;
    check_result(fp80_from_int(1), "MOD (2^40+3) mod 2");

    -- REM (nearest integer quotient)
    op_sel <= FPU_OP_REM;
    a_in   <= fp80_from_int(7);
    b_in   <= fp80_from_int(4);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "REM latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = REM_LATENCY
      report "REM latency mismatch"
      severity failure;
    check_result(fp80_from_int(-1), "REM 7 rem 4");

    -- REM zero divisor should return NaN.
    op_sel <= FPU_OP_REM;
    a_in   <= fp80_from_int(7);
    b_in   <= fp80_from_int(0);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "REM divide-by-zero latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = REM_LATENCY
      report "REM divide-by-zero latency mismatch"
      severity failure;
    check_result_nan("REM 7 rem 0");

    -- REM large quotient regression (ties-to-even path at large magnitude)
    op_sel <= FPU_OP_REM;
    a_in   <= LARGE_MOD_A;
    b_in   <= LARGE_MOD_B;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "REM large-quotient latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = REM_LATENCY
      report "REM large-quotient latency mismatch"
      severity failure;
    check_result(fp80_from_int(-1), "REM (2^40+3) rem 2");

    -- SCALE
    op_sel <= FPU_OP_SCALE;
    a_in   <= fp80_from_int(2);
    b_in   <= fp80_from_int(3);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "SCALE latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = SCALE_LATENCY
      report "SCALE latency mismatch"
      severity failure;
    check_result(fp80_from_int(12), "SCALE 3 by +2");

    -- SGLDIV
    op_sel <= FPU_OP_SGLDIV;
    a_in   <= fp80_from_int(1);
    b_in   <= fp80_from_int(10);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "SGLDIV latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = SGLDIV_LATENCY
      report "SGLDIV latency mismatch"
      severity failure;
    check_result(DIV_1_10_SINGLE_EXPECTED, "SGLDIV 1/10 single");

    -- SGLMUL
    op_sel <= FPU_OP_SGLMUL;
    a_in   <= fp80_from_int(7);
    b_in   <= fp80_from_int(9);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "SGLMUL latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = SGLMUL_LATENCY
      report "SGLMUL latency mismatch"
      severity failure;
    check_result(fp80_from_int(63), "SGLMUL 7*9");

    -- SIN(0) = +0
    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_ZERO;
    b_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    busy_cycles := 0;
    while valid = '0' loop
      if busy = '1' then
        busy_cycles := busy_cycles + 1;
      end if;
      wait until rising_edge(clk);
      wait for 0 ns;
    end loop;
    wait until valid = '1';
    report "SIN latency cycles: " & integer'image(cycle_cnt - start_cycle) severity note;
    assert cycle_cnt - start_cycle = SIN_LATENCY report "SIN latency mismatch" severity failure;
    assert busy_cycles > 1 report "SIN must be multi-cycle busy" severity failure;
    check_result(FP80_ZERO, "SIN 0");

    -- SIN small-angle fast path must honor FPCR precision control (single)
    round_mode <= FP_RND_NEAREST;
    round_prec <= FP_PREC_SINGLE;
    expected_small := add_sub_fp80(SMALL_FASTPATH_ARG, FP80_ZERO, false, FP_RND_NEAREST, FP_PREC_SINGLE);
    op_sel <= FPU_OP_SIN;
    a_in   <= SMALL_FASTPATH_ARG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result(expected_small, "SIN small-angle FP_PREC_SINGLE");

    -- SIN small-angle fast path must honor FPCR precision control (double)
    round_prec <= FP_PREC_DOUBLE;
    expected_small := add_sub_fp80(SMALL_FASTPATH_ARG, FP80_ZERO, false, FP_RND_NEAREST, FP_PREC_DOUBLE);
    op_sel <= FPU_OP_SIN;
    a_in   <= SMALL_FASTPATH_ARG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result(expected_small, "SIN small-angle FP_PREC_DOUBLE");
    round_prec <= FP_PREC_EXTENDED;

    -- COS(0) = 1
    op_sel <= FPU_OP_COS;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "COS latency cycles: " & integer'image(cycle_cnt - start_cycle) severity note;
    assert cycle_cnt - start_cycle = COS_LATENCY report "COS latency mismatch" severity failure;
    check_result(FP80_ONE, "COS 0");

    -- FCOS(+INF) -> NaN
    op_sel <= FPU_OP_COS;
    a_in   <= FP80_POS_INF;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result_nan("COS +INF -> NaN");

    -- FCOS(QNaN) propagates NaN class
    op_sel <= FPU_OP_COS;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result_nan("COS QNaN -> NaN");

    -- FSIN(+INF) -> NaN
    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_POS_INF;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result_nan("SIN +INF -> NaN");

    -- FSIN(QNaN) propagates NaN class
    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result_nan("SIN QNaN -> NaN");

    -- FTAN(+INF) -> NaN
    op_sel <= FPU_OP_TAN;
    a_in   <= FP80_POS_INF;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result_nan("TAN +INF -> NaN");

    -- FTAN(QNaN) propagates NaN class
    op_sel <= FPU_OP_TAN;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result_nan("TAN QNaN -> NaN");

    -- TAN(0) = 0
    op_sel <= FPU_OP_TAN;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "TAN latency cycles: " & integer'image(cycle_cnt - start_cycle) severity note;
    assert cycle_cnt - start_cycle = TAN_LATENCY report "TAN latency mismatch" severity failure;
    check_result(FP80_ZERO, "TAN 0");

    -- SIN(PI/2) = 1
    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_HALF_PI;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result(FP80_ONE, "SIN PI/2");

    -- COS(PI) = -1
    op_sel <= FPU_OP_COS;
    a_in   <= FP80_PI;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    check_result(x"BFFF8000000000000000", "COS PI");

    -- SINCOS returns sine path result in ALU datapath model
    op_sel <= FPU_OP_SINCOS;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    busy_cycles := 0;
    while valid = '0' loop
      if busy = '1' then
        busy_cycles := busy_cycles + 1;
      end if;
      wait until rising_edge(clk);
      wait for 0 ns;
    end loop;
    wait until valid = '1';
    report "SINCOS latency cycles: " & integer'image(cycle_cnt - start_cycle) severity note;
    assert cycle_cnt - start_cycle = SINCOS_LATENCY report "SINCOS latency mismatch" severity failure;
    assert busy_cycles > 1 report "SINCOS must be multi-cycle busy" severity failure;
    check_result(FP80_ZERO, "SINCOS sine lane");
    assert aux_valid = '1' report "SINCOS aux lane missing" severity failure;
    assert aux_result = FP80_ONE report "SINCOS cosine lane mismatch" severity failure;

    std.env.stop;
    wait;
  end process;
end architecture sim;
