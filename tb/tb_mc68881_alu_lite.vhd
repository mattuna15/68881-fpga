library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

-- Lite-mode ALU testbench: verifies kept ops work and removed ops return zero.
entity tb_mc68881_alu_lite is
end entity tb_mc68881_alu_lite;

architecture sim of tb_mc68881_alu_lite is
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
  constant TIMEOUT    : time := 1 us;

  -- Helper: split fp80 for assertions
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

  procedure check_result_exact(
    signal   res       : in fp80_t;
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
    split_fp80(res, got_sign, got_exp, got_mant);
    split_fp80(expected, exp_sign, exp_exp, exp_mant);
    assert got_sign = exp_sign and got_exp = exp_exp and got_mant = exp_mant
      report "FAIL: " & test_name &
             " expected=" & to_hstring(expected) &
             " got=" & to_hstring(res)
      severity failure;
  end procedure;

  procedure check_result_zero(
    signal   res       : in fp80_t;
    constant test_name : string
  ) is
    constant ZERO80 : fp80_t := (others => '0');
  begin
    assert res = ZERO80
      report "FAIL: " & test_name &
             " expected zero got=" & to_hstring(res)
      severity failure;
  end procedure;

  -- Wait for valid with timeout protection
  procedure wait_valid(constant test_name : string) is
  begin
    wait until valid = '1' for TIMEOUT;
    assert valid = '1'
      report "TIMEOUT: " & test_name & " did not complete within " &
             time'image(TIMEOUT)
      severity failure;
    wait for 0 ns;
  end procedure;

begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.mc68881_alu
    generic map (
      fpu_lite => true
    )
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
    -- FP80 constants
    constant FP80_ONE : fp80_t := x"3FFF" & x"8000000000000000";
    constant FP80_TWO : fp80_t := x"4000" & x"8000000000000000";
    constant FP80_THREE : fp80_t := x"4000" & x"C000000000000000";
    constant FP80_NEG_ONE : fp80_t := x"BFFF" & x"8000000000000000";
    constant FP80_HALF : fp80_t := x"3FFE" & x"8000000000000000";  -- 0.5
    constant ZERO80 : fp80_t := (others => '0');
  begin
    -- Reset
    reset_n <= '0';
    wait for CLK_PERIOD * 3;
    reset_n <= '1';
    wait for CLK_PERIOD * 2;

    -- ================================================================
    -- Kept ops (11 ALU operations)
    -- ================================================================

    -- Test 1: FADD 1.0 + 2.0 = 3.0
    report "LITE: Testing FADD 1.0 + 2.0";
    a_in <= FP80_ONE;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_ADD;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FADD");
    check_result_exact(result, FP80_THREE, "FADD 1.0+2.0=3.0");
    report "LITE: FADD passed";

    wait for CLK_PERIOD * 2;

    -- Test 2: FSUB 2.0 - 1.0 = 1.0
    report "LITE: Testing FSUB 2.0 - 1.0";
    a_in <= FP80_TWO;
    b_in <= FP80_ONE;
    op_sel <= FPU_OP_SUB;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSUB");
    check_result_exact(result, FP80_ONE, "FSUB 2.0-1.0=1.0");
    report "LITE: FSUB passed";

    wait for CLK_PERIOD * 2;

    -- Test 3: FMUL 1.0 * 2.0 = 2.0
    report "LITE: Testing FMUL 1.0 * 2.0";
    a_in <= FP80_ONE;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_MUL;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FMUL");
    check_result_exact(result, FP80_TWO, "FMUL 1.0*2.0=2.0");
    report "LITE: FMUL passed";

    wait for CLK_PERIOD * 2;

    -- Test 4: FDIV 2.0 / 2.0 = 1.0
    report "LITE: Testing FDIV 2.0 / 2.0";
    a_in <= FP80_TWO;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_DIV;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FDIV");
    check_result_exact(result, FP80_ONE, "FDIV 2.0/2.0=1.0");
    report "LITE: FDIV passed";

    wait for CLK_PERIOD * 2;

    -- Test 5: FABS(-1.0) = 1.0
    report "LITE: Testing FABS -1.0";
    a_in <= FP80_NEG_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_ABS;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FABS");
    check_result_exact(result, FP80_ONE, "FABS(-1.0)=1.0");
    report "LITE: FABS passed";

    wait for CLK_PERIOD * 2;

    -- Test 6: FNEG(1.0) = -1.0
    report "LITE: Testing FNEG 1.0";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_NEG;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FNEG");
    check_result_exact(result, FP80_NEG_ONE, "FNEG(1.0)=-1.0");
    report "LITE: FNEG passed";

    wait for CLK_PERIOD * 2;

    -- Test 7: FINTRZ(2.0) = 2.0
    report "LITE: Testing FINTRZ 2.0";
    a_in <= FP80_TWO;
    b_in <= ZERO80;
    op_sel <= FPU_OP_INTRZ;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FINTRZ");
    check_result_exact(result, FP80_TWO, "FINTRZ(2.0)=2.0");
    report "LITE: FINTRZ passed";

    wait for CLK_PERIOD * 2;

    -- Test 8: FSQRT(1.0) = 1.0
    report "LITE: Testing FSQRT 1.0";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_SQRT;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSQRT");
    check_result_exact(result, FP80_ONE, "FSQRT(1.0)=1.0");
    report "LITE: FSQRT passed";

    wait for CLK_PERIOD * 2;

    -- Test 9: FCMP(2.0, 1.0) => positive
    report "LITE: Testing FCMP 2.0 vs 1.0";
    a_in <= FP80_TWO;
    b_in <= FP80_ONE;
    op_sel <= FPU_OP_CMP;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FCMP");
    check_result_exact(result, FP80_ONE, "FCMP(2.0,1.0)=+1");
    report "LITE: FCMP passed";

    wait for CLK_PERIOD * 2;

    -- Test 10: FINT(2.0, nearest) = 2.0
    report "LITE: Testing FINT 2.0";
    a_in <= FP80_TWO;
    b_in <= ZERO80;
    op_sel <= FPU_OP_INT;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FINT");
    check_result_exact(result, FP80_TWO, "FINT(2.0)=2.0");
    report "LITE: FINT passed";

    wait for CLK_PERIOD * 2;

    -- Test 11: FTST(1.0) passthrough = 1.0
    report "LITE: Testing FTST 1.0";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_TST;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FTST");
    check_result_exact(result, FP80_ONE, "FTST(1.0)=1.0");
    report "LITE: FTST passed";

    wait for CLK_PERIOD * 2;

    -- ================================================================
    -- Removed ops: verify they return zero and don't hang
    -- ================================================================

    -- FSIN (trig -- removed)
    report "LITE: Testing FSIN (removed op, expect zero)";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_SIN;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSIN removed");
    check_result_zero(result, "FSIN (removed) returns zero");
    report "LITE: FSIN (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FCOS (trig -- removed)
    report "LITE: Testing FCOS (removed op, expect zero)";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_COS;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FCOS removed");
    check_result_zero(result, "FCOS (removed) returns zero");
    report "LITE: FCOS (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FETOX (trig -- removed)
    report "LITE: Testing FETOX (removed op, expect zero)";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_ETOX;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FETOX removed");
    check_result_zero(result, "FETOX (removed) returns zero");
    report "LITE: FETOX (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FATAN (inverse trig -- removed)
    report "LITE: Testing FATAN (removed op, expect zero)";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_ATAN;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FATAN removed");
    check_result_zero(result, "FATAN (removed) returns zero");
    report "LITE: FATAN (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FLOGN (logarithmic -- removed)
    report "LITE: Testing FLOGN (removed op, expect zero)";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_LOGN;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FLOGN removed");
    check_result_zero(result, "FLOGN (removed) returns zero");
    report "LITE: FLOGN (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FSCALE (sglops -- removed)
    report "LITE: Testing FSCALE (removed op, expect zero)";
    a_in <= FP80_ONE;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_SCALE;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSCALE removed");
    check_result_zero(result, "FSCALE (removed) returns zero");
    report "LITE: FSCALE (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FSGLDIV (sglops -- removed)
    report "LITE: Testing FSGLDIV (removed op, expect zero)";
    a_in <= FP80_TWO;
    b_in <= FP80_ONE;
    op_sel <= FPU_OP_SGLDIV;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSGLDIV removed");
    check_result_zero(result, "FSGLDIV (removed) returns zero");
    report "LITE: FSGLDIV (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FSGLMUL (sglops -- removed)
    report "LITE: Testing FSGLMUL (removed op, expect zero)";
    a_in <= FP80_TWO;
    b_in <= FP80_THREE;
    op_sel <= FPU_OP_SGLMUL;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSGLMUL removed");
    check_result_zero(result, "FSGLMUL (removed) returns zero");
    report "LITE: FSGLMUL (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FMOD (modrem -- removed)
    report "LITE: Testing FMOD (removed op, expect zero)";
    a_in <= FP80_THREE;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_MOD;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FMOD removed");
    check_result_zero(result, "FMOD (removed) returns zero");
    report "LITE: FMOD (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FREM (modrem -- removed)
    report "LITE: Testing FREM (removed op, expect zero)";
    a_in <= FP80_THREE;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_REM;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FREM removed");
    check_result_zero(result, "FREM (removed) returns zero");
    report "LITE: FREM (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FGETEXP (removed in lite)
    report "LITE: Testing FGETEXP (removed op, expect zero)";
    a_in <= FP80_TWO;
    b_in <= ZERO80;
    op_sel <= FPU_OP_GETEXP;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FGETEXP removed");
    check_result_zero(result, "FGETEXP (removed) returns zero");
    report "LITE: FGETEXP (removed) passed";

    wait for CLK_PERIOD * 2;

    -- FGETMAN (removed in lite)
    report "LITE: Testing FGETMAN (removed op, expect zero)";
    a_in <= FP80_TWO;
    b_in <= ZERO80;
    op_sel <= FPU_OP_GETMAN;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FGETMAN removed");
    check_result_zero(result, "FGETMAN (removed) returns zero");
    report "LITE: FGETMAN (removed) passed";

    wait for CLK_PERIOD * 2;

    -- ================================================================
    -- Pipeline integrity: FADD after removed ops
    -- ================================================================
    report "LITE: Testing FADD after removed ops (pipeline integrity)";
    a_in <= FP80_ONE;
    b_in <= FP80_ONE;
    op_sel <= FPU_OP_ADD;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FADD after removed ops");
    check_result_exact(result, FP80_TWO, "FADD 1.0+1.0=2.0 after removed ops");
    report "LITE: Post-removed-ops FADD passed";

    wait for CLK_PERIOD * 2;

    -- ================================================================
    -- Back-to-back: removed op then kept op with no gap
    -- Verifies busy/valid handshake works without idle cycles
    -- ================================================================
    report "LITE: Testing back-to-back: FSIN(removed) then FADD(kept), no gap";
    -- Issue FSIN (removed)
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_SIN;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSIN back-to-back");
    check_result_zero(result, "FSIN back-to-back returns zero");
    -- Immediately issue FADD with no gap (start on next clock)
    a_in <= FP80_ONE;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_ADD;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FADD back-to-back after FSIN");
    check_result_exact(result, FP80_THREE, "FADD 1+2=3 back-to-back after removed op");
    report "LITE: Back-to-back (removed then kept) passed";

    wait for CLK_PERIOD * 2;

    -- Back-to-back: kept op then removed op
    report "LITE: Testing back-to-back: FNEG(kept) then FSCALE(removed), no gap";
    a_in <= FP80_ONE;
    b_in <= ZERO80;
    op_sel <= FPU_OP_NEG;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FNEG back-to-back");
    check_result_exact(result, FP80_NEG_ONE, "FNEG(1.0) back-to-back");
    -- Immediately issue FSCALE (removed)
    a_in <= FP80_ONE;
    b_in <= FP80_TWO;
    op_sel <= FPU_OP_SCALE;
    wait until rising_edge(clk);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait_valid("FSCALE back-to-back after FNEG");
    check_result_zero(result, "FSCALE back-to-back returns zero");
    report "LITE: Back-to-back (kept then removed) passed";

    report "LITE: All lite-mode tests passed";
    std.env.stop;
    wait;
  end process;
end architecture sim;
