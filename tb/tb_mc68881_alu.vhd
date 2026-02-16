library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;
use work.mc68881_golden_vectors_pkg.all;

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
  signal quotient_valid : std_logic;
  signal quotient_byte : std_logic_vector(7 downto 0);
  signal busy   : std_logic;
  signal cycle_cnt : natural := 0;

  constant CLK_PERIOD : time := 10 ns;
  constant ADD_LATENCY : natural := 1;
  constant SUB_LATENCY : natural := 1;
  constant MUL_LATENCY : natural := 4;
  constant DIV_LATENCY : natural := op_alu_latency(FPU_OP_DIV);
  constant SQRT_LATENCY : natural := op_alu_latency(FPU_OP_SQRT);
  constant CMP_LATENCY : natural := 1;
  constant MOD_LATENCY : natural := op_alu_latency(FPU_OP_MOD);
  constant REM_LATENCY : natural := op_alu_latency(FPU_OP_REM);
  constant SCALE_MIN_LATENCY : natural := 2;
  constant SGLDIV_MIN_LATENCY : natural := 8;
  constant SGLMUL_MIN_LATENCY : natural := 4;
  constant SIN_LATENCY : natural := op_alu_latency(FPU_OP_SIN) - 1;
  constant COS_LATENCY : natural := op_alu_latency(FPU_OP_COS) - 1;
  constant TAN_LATENCY : natural := op_alu_latency(FPU_OP_TAN) - 1;
  constant SINCOS_LATENCY : natural := op_alu_latency(FPU_OP_SINCOS) - 1;

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
  begin
    diff := abs_fp80(add_sub_fp80(got, expected, true, FP_RND_NEAREST, FP_PREC_EXTENDED));
    scale := abs_fp80(expected);
    if compare_fp80(scale, FP80_ONE_LOCAL) < 0 then
      rel_tol := tolerance;
    else
      rel_tol := mul_fp80(scale, tolerance, FP_RND_NEAREST, FP_PREC_EXTENDED);
    end if;
    assert compare_fp80(diff, rel_tol) <= 0
      report "Mismatch(tol): " & test_name &
             " expected=" & to_hstring(expected) &
             " got=" & to_hstring(got) &
             " abs_diff=" & to_hstring(diff) &
             " tol=" & to_hstring(rel_tol)
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
  constant FREM_BOUNDARY_A : fp80_t := x"401DFFFFFFFF80000000"; -- (integer'high + 0.75) for 32-bit integer
  constant FREM_BOUNDARY_B : fp80_t := x"3FFF8000000000000000"; -- 1
  constant FREM_BOUNDARY_EXPECTED : fp80_t := x"BFFD8000000000000000"; -- -0.25 (round-to-nearest-even quotient)
  constant FP80_ZERO : fp80_t := x"00000000000000000000";
  constant FP80_ONE : fp80_t := x"3FFF8000000000000000";
  constant FP80_TEN : fp80_t := x"4002A000000000000000";
  constant FP80_HALF : fp80_t := x"3FFE8000000000000000";
  constant FP80_QUARTER : fp80_t := x"3FFD8000000000000000";
  constant FP80_LN2 : fp80_t := x"3FFEB17217F7D1CF79AC";
  constant FP80_LN10 : fp80_t := x"4000935D8DDDAAA8AC17";
  constant FP80_HALF_PI : fp80_t := x"3FFFC90FDAA22168C235";
  constant FP80_PI : fp80_t := x"4000C90FDAA22168C235";
  constant SMALL_FASTPATH_ARG : fp80_t := x"3FD78000000000000001";
  constant FP80_NEG_ONE : fp80_t := x"BFFF8000000000000000";
  constant FP80_POS_INF : fp80_t := x"7FFF8000000000000000";
  constant FP80_NEG_INF : fp80_t := x"FFFF8000000000000000";
  constant FP80_QNAN : fp80_t := x"7FFFC000000000000001";
  constant SUBNORMAL_POS : fp80_t := make_fp80('0', (others => '0'), to_unsigned(1, FP_MANT_WIDTH));
  constant SUBNORMAL_NEG : fp80_t := make_fp80('1', (others => '0'), to_unsigned(1, FP_MANT_WIDTH));
  constant FP80_TOL_1E3 : fp80_t := x"3FF583126E978D4FE000"; -- 1e-3
  constant FP80_TOL_5E3 : fp80_t := x"3FF7A3D70A3D70A3D800"; -- 5e-3
  constant FP80_TOL_1E2 : fp80_t := x"3FF8A3D70A3D70A3D800"; -- 1e-2
  constant FP80_TOL_2E2 : fp80_t := x"3FF9A3D70A3D70A3D800"; -- 2e-2
  constant FP80_TOL_5E2 : fp80_t := x"3FFACCCCCCCCCCCCD000"; -- 5e-2
  constant FP80_TOL_2E1 : fp80_t := x"3FFCCCCCCCCCCCCCD000"; -- 2e-1
  constant FP80_TOL_3E1 : fp80_t := x"3FFD9999999999999800"; -- 3e-1

  constant FP80_ARG_0P1  : fp80_t := x"3FFBCCCCCCCCCCCCD000";
  constant FP80_ARG_M0P7 : fp80_t := x"BFFEB333333333333000";
  constant FP80_ARG_0P3  : fp80_t := x"3FFD9999999999999800";
  constant FP80_ARG_0P2  : fp80_t := x"3FFCCCCCCCCCCCCCD000";
  constant FP80_ARG_M0P8 : fp80_t := x"BFFECCCCCCCCCCCCD000";
  constant FP80_ARG_0P75 : fp80_t := x"3FFEC000000000000000";
  constant FP80_ARG_M0P5 : fp80_t := x"BFFE8000000000000000";
  constant FP80_ARG_0P25 : fp80_t := x"3FFD8000000000000000";
  constant FP80_ARG_0P4  : fp80_t := x"3FFECCCCCCCCCCCCD000";
  constant FP80_ARG_1P25 : fp80_t := x"3FFFA000000000000000";
  constant FP80_ARG_1P7  : fp80_t := x"3FFFD999999999999800";
  constant FP80_ARG_0P6  : fp80_t := x"3FFE9999999999999800";
  constant FP80_ARG_0P5  : fp80_t := x"3FFE8000000000000000";
  constant FP80_ARG_1P1  : fp80_t := x"3FFF8CCCCCCCCCCCD000";
  constant FP80_ARG_M2P3 : fp80_t := x"C0009333333333333000";
  constant FP80_ARG_3P7  : fp80_t := x"4000ECCCCCCCCCCCD000";
  constant FP80_ARG_M6P2 : fp80_t := x"C001C666666666666800";
  constant FP80_ARG_12P5 : fp80_t := x"4002C800000000000000";
  constant FP80_ARG_M12P5 : fp80_t := x"C002C800000000000000";
  constant FP80_ARG_25P3 : fp80_t := x"4003CA66666666666800";
  constant FP80_ARG_0P9  : fp80_t := x"3FFEE666666666666800";
  constant FP80_ARG_M1P1 : fp80_t := x"BFFF8CCCCCCCCCCCD000";
  constant FP80_ARG_2P4  : fp80_t := x"40009999999999999800";
  constant FP80_ARG_M2P8 : fp80_t := x"C000B333333333333000";
  constant FP80_ARG_6P0  : fp80_t := x"4001C000000000000000";
  constant FP80_ARG_9P2  : fp80_t := x"40029333333333333000";
  constant FP80_ARG_M13P4 : fp80_t := x"C002D666666666666800";

  constant FP80_EXP_SIN_0P1    : fp80_t := x"3FFBCC75765C5E596000";
  constant FP80_EXP_SIN_M0P7   : fp80_t := x"BFFEA4EB734A30CDC000";
  constant FP80_EXP_COS_0P3    : fp80_t := x"3FFEF490EEA1784DD000";
  constant FP80_EXP_TAN_0P2    : fp80_t := x"3FFCCF93383452AF6000";
  constant FP80_EXP_TAN_M0P8   : fp80_t := x"BFFF83CB323C9DB05800";
  constant FP80_EXP_ETOX_0P75  : fp80_t := x"4000877CEDA33EE7C000";
  constant FP80_EXP_ETOX_M0P5  : fp80_t := x"3FFE9B4597E37CB05000";
  constant FP80_EXP_ETOXM1_0P1 : fp80_t := x"3FFBD763D9AD0069D000";
  constant FP80_EXP_LOGN_1P25  : fp80_t := x"3FFCE47FBE3CD4D11000";
  constant FP80_EXP_LOG2_1P25  : fp80_t := x"3FFDA4D3C25E68DC5800";
  constant FP80_EXP_LOG10_1P25 : fp80_t := x"3FFBC678C1C432406800";
  constant FP80_EXP_ATAN_0P75  : fp80_t := x"3FFEA4BC7D1934F70800";
  constant FP80_EXP_ASIN_0P6   : fp80_t := x"3FFEA4BC7D1934F70800";
  constant FP80_EXP_ACOS_0P6   : fp80_t := x"3FFEED63382B0DDA8000";
  constant FP80_EXP_ATANH_0P5  : fp80_t := x"3FFE8C9F53D568185800";
  constant FP80_EXP_SINH_0P75  : fp80_t := x"3FFED283596E9E348000";
  constant FP80_EXP_COSH_0P75  : fp80_t := x"3FFFA5B82E8F2EB54000";
  constant FP80_EXP_TANH_0P75  : fp80_t := x"3FFEA2991F2A97914000";
  constant FP80_EXP_TWOTOX_0P75: fp80_t := x"3FFFD744FCCAD69D6800";
  constant FP80_EXP_TENTOX_0P5 : fp80_t := x"4000CA62C1D6D2DA9800";
  constant FP80_EXP_ETOX_10    : fp80_t := x"400DAC14EE7CA82AFCF8";
  constant FP80_EXP_SIN_1P1    : fp80_t := x"3FFEE4262A616B19C000";
  constant FP80_EXP_SIN_M2P3   : fp80_t := x"BFFEBEE6896AC1792000";
  constant FP80_EXP_SIN_3P7    : fp80_t := x"BFFE87A3576170DA0800";
  constant FP80_EXP_SIN_M6P2   : fp80_t := x"3FFBAA2AC6DDF668E800";
  constant FP80_EXP_SIN_12P5   : fp80_t := x"BFFB87D3C6610E7DD800";
  constant FP80_EXP_SIN_25P3   : fp80_t := x"3FFCAA79BBEA852F5000";
  constant FP80_EXP_COS_1P1    : fp80_t := x"3FFDE83DC0363B088800";
  constant FP80_EXP_COS_M2P3   : fp80_t := x"BFFEAA9110B9817F0000";
  constant FP80_EXP_COS_3P7    : fp80_t := x"BFFED91D156BEEC9B800";
  constant FP80_EXP_COS_M6P2   : fp80_t := x"3FFEFF1D6203CD4E7000";
  constant FP80_EXP_COS_12P5   : fp80_t := x"3FFEFF6FB54113BBA000";
  constant FP80_EXP_COS_25P3   : fp80_t := x"3FFEFC6D6F1CD6C27000";
  constant FP80_EXP_TAN_0P9    : fp80_t := x"3FFFA14CDD4E1509C000";
  constant FP80_EXP_TAN_M1P1   : fp80_t := x"BFFFFB7D3E94310A7000";
  constant FP80_EXP_TAN_2P4    : fp80_t := x"BFFEEA7FE998D0E36000";
  constant FP80_EXP_TAN_M2P8   : fp80_t := x"3FFDB608018F636C7800";
  constant FP80_EXP_TAN_6P0    : fp80_t := x"BFFD94FEC375DCADF000";
  constant FP80_EXP_TAN_9P2    : fp80_t := x"BFFCEA210D8697061800";
  constant FP80_EXP_TAN_M13P4  : fp80_t := x"BFFF8CFBC4BCB697F000";

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
      quotient_byte => quotient_byte,
      quotient_valid => quotient_valid,
      aux_result => aux_result,
      aux_valid => aux_valid
    );

  process
    variable start_cycle : natural := 0;
    variable expected_small : fp80_t := (others => '0');
    variable busy_cycles : natural := 0;
    variable got_sign  : std_logic := '0';
    variable got_exp   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable sweep_v0 : fp80_t := (others => '0');
    variable sweep_v1 : fp80_t := (others => '0');
    variable sweep_v2 : fp80_t := (others => '0');
    variable sweep_ref : fp80_t := (others => '0');
    procedure run_monadic_close(
      constant op_val : fpu_op_t;
      constant arg_val : fp80_t;
      constant exp_val : fp80_t;
      constant tol_val : fp80_t;
      constant test_name : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1';
      wait for 0 ns;
      report "Trig sweep " & test_name &
             " arg=" & to_hstring(arg_val) &
             " got=" & to_hstring(result) &
             " expected=" & to_hstring(exp_val)
        severity note;
      check_result_close(exp_val, tol_val, test_name);
    end procedure;
    procedure run_monadic_capture(
      constant op_val : fpu_op_t;
      constant arg_val : fp80_t;
      constant test_name : string;
      variable got_val : out fp80_t
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1';
      wait for 0 ns;
      got_val := result;
      report "Trans sweep " & test_name &
             " arg=" & to_hstring(arg_val) &
             " got=" & to_hstring(result)
        severity note;
    end procedure;
    procedure run_binary_close(
      constant op_val : fpu_op_t;
      constant a_val : fp80_t;
      constant b_val : fp80_t;
      constant expected_val : fp80_t;
      constant tol_val : fp80_t;
      constant test_name : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= a_val;
      b_in   <= b_val;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1';
      wait for 0 ns;
      report "Arith sweep " & test_name &
             " a=" & to_hstring(a_val) &
             " b=" & to_hstring(b_val) &
             " got=" & to_hstring(result) &
             " expected=" & to_hstring(expected_val)
        severity note;
      check_fp80_close(result, expected_val, tol_val, test_name);
    end procedure;
    procedure run_monadic_exact(
      constant op_val : fpu_op_t;
      constant arg_val : fp80_t;
      constant expected_val : fp80_t;
      constant test_name : string
    ) is
    begin
      op_sel <= op_val;
      a_in   <= arg_val;
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait for 0 ns;
      wait until valid = '1';
      wait for 0 ns;
      report "Monadic sweep " & test_name &
             " arg=" & to_hstring(arg_val) &
             " got=" & to_hstring(result) &
             " expected=" & to_hstring(expected_val)
        severity note;
      check_result(expected_val, test_name);
    end procedure;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
    report "DIV 1/10 double latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV 1/10 double latency mismatch"
      severity failure;
    report "DIV 1/10 double result: " & to_hstring(result)
      severity note;
    check_result(DIV_1_10_DOUBLE_EXPECTED, "DIV 1/10 double");

    -- Arithmetic sweeps across non-trivial operands.
    run_binary_close(
      FPU_OP_ADD, FP80_ARG_1P1, FP80_ARG_M0P7,
      add_sub_fp80(FP80_ARG_1P1, FP80_ARG_M0P7, false, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "ADD 1.1 + (-0.7)"
    );
    run_binary_close(
      FPU_OP_ADD, FP80_ARG_3P7, FP80_ARG_2P4,
      add_sub_fp80(FP80_ARG_3P7, FP80_ARG_2P4, false, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "ADD 3.7 + 2.4"
    );
    run_binary_close(
      FPU_OP_ADD, FP80_ARG_M2P3, FP80_ARG_0P6,
      add_sub_fp80(FP80_ARG_M2P3, FP80_ARG_0P6, false, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "ADD -2.3 + 0.6"
    );
    run_binary_close(
      FPU_OP_ADD, FP80_ARG_12P5, FP80_ARG_M6P2,
      add_sub_fp80(FP80_ARG_12P5, FP80_ARG_M6P2, false, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "ADD 12.5 + (-6.2)"
    );

    run_binary_close(
      FPU_OP_SUB, FP80_ARG_1P1, FP80_ARG_M0P7,
      add_sub_fp80(FP80_ARG_1P1, FP80_ARG_M0P7, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "SUB 1.1 - (-0.7)"
    );
    run_binary_close(
      FPU_OP_SUB, FP80_ARG_3P7, FP80_ARG_2P4,
      add_sub_fp80(FP80_ARG_3P7, FP80_ARG_2P4, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "SUB 3.7 - 2.4"
    );
    run_binary_close(
      FPU_OP_SUB, FP80_ARG_M2P3, FP80_ARG_0P6,
      add_sub_fp80(FP80_ARG_M2P3, FP80_ARG_0P6, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "SUB -2.3 - 0.6"
    );
    run_binary_close(
      FPU_OP_SUB, FP80_ARG_12P5, FP80_ARG_M6P2,
      add_sub_fp80(FP80_ARG_12P5, FP80_ARG_M6P2, true, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "SUB 12.5 - (-6.2)"
    );

    run_binary_close(
      FPU_OP_MUL, FP80_ARG_1P1, FP80_ARG_M0P7,
      mul_fp80(FP80_ARG_1P1, FP80_ARG_M0P7, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "MUL 1.1 * (-0.7)"
    );
    run_binary_close(
      FPU_OP_MUL, FP80_ARG_3P7, FP80_ARG_2P4,
      mul_fp80(FP80_ARG_3P7, FP80_ARG_2P4, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "MUL 3.7 * 2.4"
    );
    run_binary_close(
      FPU_OP_MUL, FP80_ARG_M2P3, FP80_ARG_0P6,
      mul_fp80(FP80_ARG_M2P3, FP80_ARG_0P6, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "MUL -2.3 * 0.6"
    );
    run_binary_close(
      FPU_OP_MUL, FP80_ARG_12P5, FP80_ARG_M0P5,
      mul_fp80(FP80_ARG_12P5, FP80_ARG_M0P5, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "MUL 12.5 * (-0.5)"
    );

    run_binary_close(
      FPU_OP_DIV, FP80_ARG_3P7, FP80_ARG_1P1,
      div_fp80(FP80_ARG_3P7, FP80_ARG_1P1, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "DIV 3.7 / 1.1"
    );
    run_binary_close(
      FPU_OP_DIV, FP80_ARG_M2P3, FP80_ARG_0P6,
      div_fp80(FP80_ARG_M2P3, FP80_ARG_0P6, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "DIV -2.3 / 0.6"
    );
    run_binary_close(
      FPU_OP_DIV, FP80_ARG_12P5, FP80_ARG_M0P7,
      div_fp80(FP80_ARG_12P5, FP80_ARG_M0P7, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "DIV 12.5 / (-0.7)"
    );
    run_binary_close(
      FPU_OP_DIV, FP80_ARG_1P7, FP80_ARG_0P25,
      div_fp80(FP80_ARG_1P7, FP80_ARG_0P25, FP_RND_NEAREST, FP_PREC_EXTENDED),
      FP80_TOL_1E3, "DIV 1.7 / 0.25"
    );

    -- External golden-vector spot checks (independent mpmath-generated FP80 constants).
    run_binary_close(FPU_OP_ADD, GV_ARG_3P7, GV_ARG_2P4, GV_ADD_3P7_2P4, FP80_TOL_1E3, "GV ADD");
    run_binary_close(FPU_OP_SUB, GV_ARG_M2P3, GV_ARG_0P6, GV_SUB_M2P3_0P6, FP80_TOL_1E3, "GV SUB");
    run_binary_close(FPU_OP_MUL, GV_ARG_3P7, GV_ARG_2P4, GV_MUL_3P7_2P4, FP80_TOL_1E3, "GV MUL");
    run_binary_close(FPU_OP_DIV, GV_ARG_12P5, GV_ARG_M0P7, GV_DIV_12P5_M0P7, FP80_TOL_1E3, "GV DIV");

    run_monadic_exact(FPU_OP_SQRT, fp80_from_int(9), GV_SQRT_9, "GV SQRT 9");
    run_monadic_exact(FPU_OP_ABS, GV_ARG_M2P3, GV_ABS_M2P3, "GV ABS");
    run_monadic_exact(FPU_OP_NEG, GV_ARG_1P1, GV_NEG_1P1, "GV NEG");
    run_monadic_exact(FPU_OP_INTRZ, GV_ARG_M2P3, GV_INTRZ_M2P3, "GV INTRZ");
    run_monadic_exact(FPU_OP_INT, GV_ARG_1P7, GV_INT_1P7, "GV INT nearest");

    run_monadic_close(FPU_OP_SIN, GV_ARG_1P1, GV_SIN_1P1, FP80_TOL_2E2, "GV SIN");
    run_monadic_close(FPU_OP_COS, GV_ARG_M2P3, GV_COS_M2P3, FP80_TOL_2E2, "GV COS");
    run_monadic_close(FPU_OP_TAN, GV_ARG_0P9, GV_TAN_0P9, FP80_TOL_5E2, "GV TAN");
    run_monadic_close(FPU_OP_ETOX, GV_ARG_0P75, GV_ETOX_0P75, FP80_TOL_1E3, "GV ETOX");
    run_monadic_close(FPU_OP_LOGN, GV_ARG_1P25, GV_LOGN_1P25, FP80_TOL_1E3, "GV LOGN");
    run_monadic_close(FPU_OP_TWOTOX, GV_ARG_0P75, GV_TWOTOX_0P75, FP80_TOL_1E3, "GV TWOTOX");
    run_monadic_close(FPU_OP_TENTOX, GV_ARG_0P5, GV_TENTOX_0P5, FP80_TOL_1E2, "GV TENTOX");
    run_monadic_close(FPU_OP_ATAN, GV_ARG_2, GV_ATAN_2, FP80_TOL_2E2, "GV ATAN 2");
    run_monadic_close(FPU_OP_ATAN, GV_ARG_M2, GV_ATAN_M2, FP80_TOL_2E2, "GV ATAN -2");
    run_monadic_close(FPU_OP_TANH, GV_ARG_0P75, GV_TANH_0P75, FP80_TOL_2E2, "GV TANH");
    -- Large-angle regression (forces ST_TRIG_REDUCE modulo 2*pi path).
    run_monadic_close(FPU_OP_SIN, GV_ARG_1234567, GV_SIN_1234567, FP80_TOL_2E2, "GV SIN 1234567");
    run_monadic_close(FPU_OP_COS, GV_ARG_1234567, GV_COS_1234567, FP80_TOL_2E2, "GV COS 1234567");
    run_monadic_close(FPU_OP_TAN, GV_ARG_1234567, GV_TAN_1234567, FP80_TOL_5E2, "GV TAN 1234567");

    -- SQRT
    op_sel <= FPU_OP_SQRT;
    a_in   <= fp80_from_int(4);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    start_cycle := cycle_cnt;
    wait until valid = '1';
    wait for 0 ns;
    report "SQRT latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = SQRT_LATENCY
      report "SQRT latency mismatch"
      severity failure;
    check_result(fp80_from_int(2), "SQRT 4");
    run_monadic_exact(FPU_OP_SQRT, FP80_ONE, FP80_ONE, "SQRT 1");
    run_monadic_exact(FPU_OP_SQRT, fp80_from_int(9), fp80_from_int(3), "SQRT 9");

    -- SQRT fractional exact (0.25 -> 0.5)
    op_sel <= FPU_OP_SQRT;
    a_in   <= FP80_QUARTER;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_HALF, "SQRT 0.25");

    -- SQRT negative returns NaN
    op_sel <= FPU_OP_SQRT;
    a_in   <= fp80_from_int(-9);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("SQRT -9");

    -- SQRT positive subnormal should not flush to zero
    op_sel <= FPU_OP_SQRT;
    a_in   <= SUBNORMAL_POS;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    split_fp80(result, got_sign, got_exp, got_mant);
    assert got_sign = '0'
      report "SQRT subnormal should produce positive result"
      severity failure;
    assert not (got_exp = (got_exp'range => '1') and got_mant /= 0)
      report "SQRT subnormal should not produce NaN"
      severity failure;
    assert not (got_exp = 0 and got_mant = 0)
      report "SQRT subnormal should not flush to zero"
      severity failure;

    -- SQRT negative subnormal returns NaN
    op_sel <= FPU_OP_SQRT;
    a_in   <= SUBNORMAL_NEG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("SQRT subnormal negative");

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
    wait for 0 ns;
    report "CMP latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = CMP_LATENCY
      report "CMP latency mismatch"
      severity failure;
    check_result(fp80_from_int(1), "CMP relation 9 vs 4");

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
    wait for 0 ns;
    report "MOD latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = MOD_LATENCY
      report "MOD latency mismatch"
      severity failure;
    check_result(fp80_from_int(2), "MOD 17 mod 5");

    -- MOD quotient selection must ignore FPCR rounding mode/precision.
    -- 7/4 = 1.75, FMOD must pick n = trunc(1.75) = 1 => remainder 3.
    round_mode <= FP_RND_PLUS_INF;
    round_prec <= FP_PREC_SINGLE;
    op_sel <= FPU_OP_MOD;
    a_in   <= fp80_from_int(7);
    b_in   <= fp80_from_int(4);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(3), "MOD 7 mod 4 ignores FPCR mode");
    round_mode <= FP_RND_NEAREST;
    round_prec <= FP_PREC_EXTENDED;

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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
    report "REM latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = REM_LATENCY
      report "REM latency mismatch"
      severity failure;
    check_result(fp80_from_int(-1), "REM 7 rem 4");

    -- REM integer fast-path boundary: this quotient needs +1 rounding at
    -- integer'high and must not overflow VHDL integer arithmetic.
    op_sel <= FPU_OP_REM;
    a_in   <= FREM_BOUNDARY_A;
    b_in   <= FREM_BOUNDARY_B;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    assert unsigned(result(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH)) /=
           to_unsigned((2**FP_EXP_WIDTH)-1, FP_EXP_WIDTH)
      report "REM boundary produced non-finite result"
      severity failure;
    check_result(FREM_BOUNDARY_EXPECTED, "REM boundary rounds quotient without integer overflow");

    -- REM quotient selection must ignore FPCR rounding mode/precision.
    -- 7/4 = 1.75, FREM must pick nearest-even n = 2 => remainder -1.
    round_mode <= FP_RND_ZERO;
    round_prec <= FP_PREC_SINGLE;
    op_sel <= FPU_OP_REM;
    a_in   <= fp80_from_int(7);
    b_in   <= fp80_from_int(4);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(-1), "REM 7 rem 4 ignores FPCR mode");
    round_mode <= FP_RND_NEAREST;
    round_prec <= FP_PREC_EXTENDED;

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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
    report "SCALE latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle >= SCALE_MIN_LATENCY
      report "SCALE latency below minimum model"
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
    wait for 0 ns;
    report "SGLDIV latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle >= SGLDIV_MIN_LATENCY
      report "SGLDIV latency below minimum model"
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
    wait for 0 ns;
    report "SGLMUL latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle >= SGLMUL_MIN_LATENCY
      report "SGLMUL latency below minimum model"
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
    loop
      wait until rising_edge(clk);
      wait for 0 ns;
      if busy = '1' then
        busy_cycles := busy_cycles + 1;
      end if;
      exit when valid = '1';
    end loop;
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
    check_result_nan("COS +INF -> NaN");

    -- FCOS(QNaN) propagates NaN class
    op_sel <= FPU_OP_COS;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("COS QNaN -> NaN");

    -- FSIN(+INF) -> NaN
    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_POS_INF;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("SIN +INF -> NaN");

    -- FSIN(QNaN) propagates NaN class
    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("SIN QNaN -> NaN");

    -- FTAN(+INF) -> NaN
    op_sel <= FPU_OP_TAN;
    a_in   <= FP80_POS_INF;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("TAN +INF -> NaN");

    -- FTAN(QNaN) propagates NaN class
    op_sel <= FPU_OP_TAN;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
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
    wait for 0 ns;
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
    wait for 0 ns;
    check_result(FP80_ONE, "SIN PI/2");

    -- COS(PI) = -1
    op_sel <= FPU_OP_COS;
    a_in   <= FP80_PI;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
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
    loop
      wait until rising_edge(clk);
      wait for 0 ns;
      if busy = '1' then
        busy_cycles := busy_cycles + 1;
      end if;
      exit when valid = '1';
    end loop;
    report "SINCOS latency cycles: " & integer'image(cycle_cnt - start_cycle) severity note;
    assert cycle_cnt - start_cycle = SINCOS_LATENCY report "SINCOS latency mismatch" severity failure;
    assert busy_cycles > 1 report "SINCOS must be multi-cycle busy" severity failure;
    check_result(FP80_ZERO, "SINCOS sine lane");
    assert aux_valid = '1' report "SINCOS aux lane missing" severity failure;
    assert aux_result = FP80_ONE report "SINCOS cosine lane mismatch" severity failure;

    -- FETOX/ETOXM1 family.
    op_sel <= FPU_OP_ETOX;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ONE, "FETOX 0");

    op_sel <= FPU_OP_ETOXM1;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FETOXM1 0");

    op_sel <= FPU_OP_TWOTOX;
    a_in   <= fp80_from_int(1);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(2), "FTWOTOX 1");

    op_sel <= FPU_OP_TENTOX;
    a_in   <= fp80_from_int(2);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(fp80_from_int(100), FP80_TOL_5E2, "FTENTOX 2");

    op_sel <= FPU_OP_ETOX;
    a_in   <= FP80_TEN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ETOX_10, FP80_TOL_2E2, "FETOX 10 reduced");

    op_sel <= FPU_OP_TWOTOX;
    a_in   <= FP80_TEN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(1024), "FTWOTOX 10");

    -- LOG family.
    op_sel <= FPU_OP_LOGN;
    a_in   <= FP80_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FLOGN 1");

    op_sel <= FPU_OP_LOGNP1;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FLOGNP1 0");

    op_sel <= FPU_OP_LOGNP1;
    a_in   <= FP80_NEG_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_NEG_INF, "FLOGNP1 -1 -> -inf (DZ)");

    op_sel <= FPU_OP_LOG2;
    a_in   <= FP80_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FLOG2 1");

    op_sel <= FPU_OP_LOG10;
    a_in   <= FP80_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FLOG10 1");

    op_sel <= FPU_OP_LOGN;
    a_in   <= FP80_TEN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_LN10, FP80_TOL_2E2, "FLOGN 10 normalized");

    op_sel <= FPU_OP_LOGNP1;
    a_in   <= fp80_from_int(9);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_LN10, FP80_TOL_2E2, "FLOGNP1 9 normalized");

    op_sel <= FPU_OP_LOG2;
    a_in   <= FP80_TEN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    sweep_v1 := result;

    op_sel <= FPU_OP_LOG10;
    a_in   <= FP80_TEN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_ONE, FP80_TOL_2E2, "FLOG10 10 normalized");

    sweep_ref := mul_fp80(sweep_v1, FP80_LN2, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_ref, FP80_LN10, FP80_TOL_2E2, "FLOG2 10 consistency");

    op_sel <= FPU_OP_LOGN;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_NEG_INF, "FLOGN 0 -> -inf (DZ)");

    -- Inverse trig/hyperbolic.
    op_sel <= FPU_OP_ATAN;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FATAN 0");

    op_sel <= FPU_OP_ASIN;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FASIN 0");

    op_sel <= FPU_OP_ACOS;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_HALF_PI, "FACOS 0");

    op_sel <= FPU_OP_ASIN;
    a_in   <= FP80_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_HALF_PI, "FASIN +1");

    op_sel <= FPU_OP_ASIN;
    a_in   <= x"BFFF8000000000000000";
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"BFFFC90FDAA22168C235", "FASIN -1");

    op_sel <= FPU_OP_ACOS;
    a_in   <= FP80_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FACOS +1");

    op_sel <= FPU_OP_ACOS;
    a_in   <= x"BFFF8000000000000000";
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_PI, "FACOS -1");

    op_sel <= FPU_OP_ATANH;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FATANH 0");

    op_sel <= FPU_OP_ASIN;
    a_in   <= fp80_from_int(2);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("FASIN |x|>1 -> NaN");

    op_sel <= FPU_OP_ACOS;
    a_in   <= fp80_from_int(2);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_nan("FACOS |x|>1 -> NaN");

    op_sel <= FPU_OP_ATANH;
    a_in   <= FP80_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_POS_INF, "FATANH +1 -> +inf (DZ)");

    op_sel <= FPU_OP_ATANH;
    a_in   <= FP80_NEG_ONE;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_NEG_INF, "FATANH -1 -> -inf (DZ)");

    op_sel <= FPU_OP_SINH;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FSINH 0");

    op_sel <= FPU_OP_COSH;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ONE, "FCOSH 0");

    op_sel <= FPU_OP_TANH;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FTANH 0");

    -- Extended transcendental/trig accuracy vectors (realistic non-trivial operands).
    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_ARG_0P1;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_SIN_0P1, FP80_TOL_5E3, "SIN 0.1");

    op_sel <= FPU_OP_SIN;
    a_in   <= FP80_ARG_M0P7;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_SIN_M0P7, FP80_TOL_2E2, "SIN -0.7");

    op_sel <= FPU_OP_COS;
    a_in   <= FP80_ARG_0P3;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_COS_0P3, FP80_TOL_5E3, "COS 0.3");

    op_sel <= FPU_OP_TAN;
    a_in   <= FP80_ARG_0P2;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_TAN_0P2, FP80_TOL_2E2, "TAN 0.2");

    op_sel <= FPU_OP_TAN;
    a_in   <= FP80_ARG_M0P8;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_TAN_M0P8, FP80_TOL_2E2, "TAN -0.8");

    -- Dense trig sweep for non-trivial operands and range-reduction coverage.
    run_monadic_close(FPU_OP_SIN, FP80_ARG_1P1, FP80_EXP_SIN_1P1, FP80_TOL_2E2, "SIN 1.1");
    run_monadic_close(FPU_OP_SIN, FP80_ARG_M2P3, FP80_EXP_SIN_M2P3, FP80_TOL_2E2, "SIN -2.3");
    run_monadic_close(FPU_OP_SIN, FP80_ARG_3P7, FP80_EXP_SIN_3P7, FP80_TOL_2E2, "SIN 3.7");
    run_monadic_close(FPU_OP_SIN, FP80_ARG_M6P2, FP80_EXP_SIN_M6P2, FP80_TOL_2E2, "SIN -6.2");
    run_monadic_close(FPU_OP_SIN, FP80_ARG_12P5, FP80_EXP_SIN_12P5, FP80_TOL_5E2, "SIN 12.5");
    run_monadic_close(FPU_OP_SIN, FP80_ARG_25P3, FP80_EXP_SIN_25P3, FP80_TOL_5E2, "SIN 25.3");

    run_monadic_close(FPU_OP_COS, FP80_ARG_1P1, FP80_EXP_COS_1P1, FP80_TOL_2E2, "COS 1.1");
    run_monadic_close(FPU_OP_COS, FP80_ARG_M2P3, FP80_EXP_COS_M2P3, FP80_TOL_2E2, "COS -2.3");
    run_monadic_close(FPU_OP_COS, FP80_ARG_3P7, FP80_EXP_COS_3P7, FP80_TOL_2E2, "COS 3.7");
    run_monadic_close(FPU_OP_COS, FP80_ARG_M6P2, FP80_EXP_COS_M6P2, FP80_TOL_2E2, "COS -6.2");
    run_monadic_close(FPU_OP_COS, FP80_ARG_12P5, FP80_EXP_COS_12P5, FP80_TOL_5E2, "COS 12.5");
    run_monadic_close(FPU_OP_COS, FP80_ARG_25P3, FP80_EXP_COS_25P3, FP80_TOL_5E2, "COS 25.3");

    run_monadic_close(FPU_OP_TAN, FP80_ARG_0P9, FP80_EXP_TAN_0P9, FP80_TOL_5E2, "TAN 0.9");
    run_monadic_close(FPU_OP_TAN, FP80_ARG_M1P1, FP80_EXP_TAN_M1P1, FP80_TOL_5E2, "TAN -1.1");
    run_monadic_close(FPU_OP_TAN, FP80_ARG_2P4, FP80_EXP_TAN_2P4, FP80_TOL_5E2, "TAN 2.4");
    run_monadic_close(FPU_OP_TAN, FP80_ARG_M2P8, FP80_EXP_TAN_M2P8, FP80_TOL_5E2, "TAN -2.8");
    run_monadic_close(FPU_OP_TAN, FP80_ARG_6P0, FP80_EXP_TAN_6P0, FP80_TOL_5E2, "TAN 6.0");
    run_monadic_close(FPU_OP_TAN, FP80_ARG_9P2, FP80_EXP_TAN_9P2, FP80_TOL_5E2, "TAN 9.2");
    run_monadic_close(FPU_OP_TAN, FP80_ARG_M13P4, FP80_EXP_TAN_M13P4, FP80_TOL_5E2, "TAN -13.4");

    op_sel <= FPU_OP_ETOX;
    a_in   <= FP80_ARG_0P75;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ETOX_0P75, FP80_TOL_1E3, "FETOX 0.75");

    op_sel <= FPU_OP_ETOX;
    a_in   <= FP80_ARG_M0P5;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ETOX_M0P5, FP80_TOL_1E3, "FETOX -0.5");

    op_sel <= FPU_OP_ETOXM1;
    a_in   <= FP80_ARG_0P1;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ETOXM1_0P1, FP80_TOL_1E3, "FETOXM1 0.1");

    op_sel <= FPU_OP_LOGN;
    a_in   <= FP80_ARG_1P25;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_LOGN_1P25, FP80_TOL_1E3, "FLOGN 1.25");

    op_sel <= FPU_OP_LOGNP1;
    a_in   <= FP80_ARG_0P25;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_LOGN_1P25, FP80_TOL_1E3, "FLOGNP1 0.25");

    op_sel <= FPU_OP_LOG2;
    a_in   <= FP80_ARG_1P25;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_LOG2_1P25, FP80_TOL_1E3, "FLOG2 1.25");

    op_sel <= FPU_OP_LOG10;
    a_in   <= FP80_ARG_1P25;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_LOG10_1P25, FP80_TOL_1E3, "FLOG10 1.25");

    op_sel <= FPU_OP_ATAN;
    a_in   <= FP80_ARG_0P75;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ATAN_0P75, FP80_TOL_2E2, "FATAN 0.75");

    op_sel <= FPU_OP_ASIN;
    a_in   <= FP80_ARG_0P6;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ASIN_0P6, FP80_TOL_1E2, "FASIN 0.6");

    op_sel <= FPU_OP_ACOS;
    a_in   <= FP80_ARG_0P6;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ACOS_0P6, FP80_TOL_1E2, "FACOS 0.6");

    op_sel <= FPU_OP_ATANH;
    a_in   <= FP80_ARG_0P5;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_ATANH_0P5, FP80_TOL_1E2, "FATANH 0.5");

    op_sel <= FPU_OP_SINH;
    a_in   <= FP80_ARG_0P75;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_SINH_0P75, FP80_TOL_1E3, "FSINH 0.75");

    op_sel <= FPU_OP_COSH;
    a_in   <= FP80_ARG_0P75;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_COSH_0P75, FP80_TOL_1E3, "FCOSH 0.75");

    op_sel <= FPU_OP_TANH;
    a_in   <= FP80_ARG_0P75;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_TANH_0P75, FP80_TOL_2E2, "FTANH 0.75");

    op_sel <= FPU_OP_TANH;
    a_in   <= FP80_ARG_12P5;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ONE, "FTANH 12.5 clamp");

    op_sel <= FPU_OP_TANH;
    a_in   <= FP80_ARG_M12P5;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"BFFF8000000000000000", "FTANH -12.5 clamp");

    op_sel <= FPU_OP_TWOTOX;
    a_in   <= FP80_ARG_0P75;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_TWOTOX_0P75, FP80_TOL_1E3, "FTWOTOX 0.75");

    op_sel <= FPU_OP_TENTOX;
    a_in   <= FP80_ARG_0P5;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result_close(FP80_EXP_TENTOX_0P5, FP80_TOL_1E2, "FTENTOX 0.5");

    -- Broader transcendental sweep (non-trivial operands).
    -- Identity: log(exp(x)) ~= x
    run_monadic_capture(FPU_OP_ETOX, FP80_ARG_M0P5, "FETOX -0.5", sweep_v0);
    run_monadic_capture(FPU_OP_LOGN, sweep_v0, "FLOGN(FETOX(-0.5))", sweep_v1);
    check_fp80_close(sweep_v1, FP80_ARG_M0P5, FP80_TOL_2E1, "FLOGN(FETOX(-0.5))");

    run_monadic_capture(FPU_OP_ETOX, FP80_ARG_0P25, "FETOX 0.25", sweep_v0);
    run_monadic_capture(FPU_OP_LOGN, sweep_v0, "FLOGN(FETOX(0.25))", sweep_v1);
    check_fp80_close(sweep_v1, FP80_ARG_0P25, FP80_TOL_2E1, "FLOGN(FETOX(0.25))");

    run_monadic_capture(FPU_OP_ETOX, FP80_ARG_0P75, "FETOX 0.75", sweep_v0);
    run_monadic_capture(FPU_OP_LOGN, sweep_v0, "FLOGN(FETOX(0.75))", sweep_v1);
    check_fp80_close(sweep_v1, FP80_ARG_0P75, FP80_TOL_2E1, "FLOGN(FETOX(0.75))");

    -- Identity: exp(log(y)) ~= y
    run_monadic_capture(FPU_OP_LOGN, FP80_ARG_0P6, "FLOGN 0.6", sweep_v0);
    run_monadic_capture(FPU_OP_ETOX, sweep_v0, "FETOX(FLOGN(0.6))", sweep_v1);
    check_fp80_close(sweep_v1, FP80_ARG_0P6, FP80_TOL_2E1, "FETOX(FLOGN(0.6))");

    run_monadic_capture(FPU_OP_LOGN, FP80_ARG_1P25, "FLOGN 1.25", sweep_v0);
    run_monadic_capture(FPU_OP_ETOX, sweep_v0, "FETOX(FLOGN(1.25))", sweep_v1);
    check_fp80_close(sweep_v1, FP80_ARG_1P25, FP80_TOL_2E1, "FETOX(FLOGN(1.25))");

    -- Twotox and tentox cross-check against etox scaling.
    sweep_ref := mul_fp80(FP80_ARG_M1P1, FP80_LN2, FP_RND_NEAREST, FP_PREC_EXTENDED);
    run_monadic_capture(FPU_OP_ETOX, sweep_ref, "FETOX(-1.1*ln2)", sweep_v0);
    run_monadic_capture(FPU_OP_TWOTOX, FP80_ARG_M1P1, "FTWOTOX -1.1", sweep_v1);
    check_fp80_close(sweep_v1, sweep_v0, FP80_TOL_2E1, "FTWOTOX vs FETOX scaled (-1.1)");

    sweep_ref := mul_fp80(FP80_ARG_0P75, FP80_LN2, FP_RND_NEAREST, FP_PREC_EXTENDED);
    run_monadic_capture(FPU_OP_ETOX, sweep_ref, "FETOX(0.75*ln2)", sweep_v0);
    run_monadic_capture(FPU_OP_TWOTOX, FP80_ARG_0P75, "FTWOTOX 0.75", sweep_v1);
    check_fp80_close(sweep_v1, sweep_v0, FP80_TOL_2E1, "FTWOTOX vs FETOX scaled (0.75)");

    sweep_ref := mul_fp80(FP80_ARG_1P7, FP80_LN2, FP_RND_NEAREST, FP_PREC_EXTENDED);
    run_monadic_capture(FPU_OP_ETOX, sweep_ref, "FETOX(1.7*ln2)", sweep_v0);
    run_monadic_capture(FPU_OP_TWOTOX, FP80_ARG_1P7, "FTWOTOX 1.7", sweep_v1);
    check_fp80_close(sweep_v1, sweep_v0, FP80_TOL_2E1, "FTWOTOX vs FETOX scaled (1.7)");

    sweep_ref := mul_fp80(FP80_ARG_M0P7, FP80_LN10, FP_RND_NEAREST, FP_PREC_EXTENDED);
    run_monadic_capture(FPU_OP_ETOX, sweep_ref, "FETOX(-0.7*ln10)", sweep_v0);
    run_monadic_capture(FPU_OP_TENTOX, FP80_ARG_M0P7, "FTENTOX -0.7", sweep_v1);
    check_fp80_close(sweep_v1, sweep_v0, FP80_TOL_3E1, "FTENTOX vs FETOX scaled (-0.7)");

    sweep_ref := mul_fp80(FP80_ARG_0P25, FP80_LN10, FP_RND_NEAREST, FP_PREC_EXTENDED);
    run_monadic_capture(FPU_OP_ETOX, sweep_ref, "FETOX(0.25*ln10)", sweep_v0);
    run_monadic_capture(FPU_OP_TENTOX, FP80_ARG_0P25, "FTENTOX 0.25", sweep_v1);
    check_fp80_close(sweep_v1, sweep_v0, FP80_TOL_3E1, "FTENTOX vs FETOX scaled (0.25)");

    sweep_ref := mul_fp80(FP80_ARG_1P1, FP80_LN10, FP_RND_NEAREST, FP_PREC_EXTENDED);
    run_monadic_capture(FPU_OP_ETOX, sweep_ref, "FETOX(1.1*ln10)", sweep_v0);
    run_monadic_capture(FPU_OP_TENTOX, FP80_ARG_1P1, "FTENTOX 1.1", sweep_v1);
    check_fp80_close(sweep_v1, sweep_v0, FP80_TOL_3E1, "FTENTOX vs FETOX scaled (1.1)");

    -- Log base consistency: ln(x) ~= log2(x)*ln2 ~= log10(x)*ln10.
    run_monadic_capture(FPU_OP_LOGN, FP80_ARG_0P6, "FLOGN 0.6", sweep_v0);
    run_monadic_capture(FPU_OP_LOG2, FP80_ARG_0P6, "FLOG2 0.6", sweep_v1);
    run_monadic_capture(FPU_OP_LOG10, FP80_ARG_0P6, "FLOG10 0.6", sweep_v2);
    sweep_ref := mul_fp80(sweep_v1, FP80_LN2, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_ref, sweep_v0, FP80_TOL_3E1, "FLOG2*ln2 vs FLOGN (0.6)");
    sweep_ref := mul_fp80(sweep_v2, FP80_LN10, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_ref, sweep_v0, FP80_TOL_3E1, "FLOG10*ln10 vs FLOGN (0.6)");

    run_monadic_capture(FPU_OP_LOGN, FP80_ARG_1P25, "FLOGN 1.25", sweep_v0);
    run_monadic_capture(FPU_OP_LOG2, FP80_ARG_1P25, "FLOG2 1.25", sweep_v1);
    run_monadic_capture(FPU_OP_LOG10, FP80_ARG_1P25, "FLOG10 1.25", sweep_v2);
    sweep_ref := mul_fp80(sweep_v1, FP80_LN2, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_ref, sweep_v0, FP80_TOL_3E1, "FLOG2*ln2 vs FLOGN (1.25)");
    sweep_ref := mul_fp80(sweep_v2, FP80_LN10, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_ref, sweep_v0, FP80_TOL_3E1, "FLOG10*ln10 vs FLOGN (1.25)");

    -- Hyperbolic consistency: tanh(x) ~= sinh(x)/cosh(x).
    run_monadic_capture(FPU_OP_SINH, FP80_ARG_M0P5, "FSINH -0.5", sweep_v0);
    run_monadic_capture(FPU_OP_COSH, FP80_ARG_M0P5, "FCOSH -0.5", sweep_v1);
    run_monadic_capture(FPU_OP_TANH, FP80_ARG_M0P5, "FTANH -0.5", sweep_v2);
    sweep_ref := div_fp80(sweep_v0, sweep_v1, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_v2, sweep_ref, FP80_TOL_2E1, "FTANH vs FSINH/FCOSH (-0.5)");

    run_monadic_capture(FPU_OP_SINH, FP80_ARG_0P4, "FSINH 0.4", sweep_v0);
    run_monadic_capture(FPU_OP_COSH, FP80_ARG_0P4, "FCOSH 0.4", sweep_v1);
    run_monadic_capture(FPU_OP_TANH, FP80_ARG_0P4, "FTANH 0.4", sweep_v2);
    sweep_ref := div_fp80(sweep_v0, sweep_v1, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_v2, sweep_ref, FP80_TOL_2E1, "FTANH vs FSINH/FCOSH (0.4)");

    run_monadic_capture(FPU_OP_SINH, FP80_ARG_1P7, "FSINH 1.7", sweep_v0);
    run_monadic_capture(FPU_OP_COSH, FP80_ARG_1P7, "FCOSH 1.7", sweep_v1);
    run_monadic_capture(FPU_OP_TANH, FP80_ARG_1P7, "FTANH 1.7", sweep_v2);
    sweep_ref := div_fp80(sweep_v0, sweep_v1, FP_RND_NEAREST, FP_PREC_EXTENDED);
    check_fp80_close(sweep_v2, sweep_ref, FP80_TOL_2E1, "FTANH vs FSINH/FCOSH (1.7)");

    -- Subnormal coverage for new transcendentals: finite, non-NaN behavior.
    op_sel <= FPU_OP_ETOX;
    a_in   <= SUBNORMAL_POS;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    split_fp80(result, got_sign, got_exp, got_mant);
    assert not (got_exp = (got_exp'range => '1') and got_mant /= 0)
      report "FETOX subnormal input should stay finite"
      severity failure;

    op_sel <= FPU_OP_LOGNP1;
    a_in   <= SUBNORMAL_POS;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    split_fp80(result, got_sign, got_exp, got_mant);
    assert not (got_exp = (got_exp'range => '1') and got_mant /= 0)
      report "FLOGNP1 subnormal input should stay finite"
      severity failure;

    -- FABS clears sign and preserves class payloads.
    op_sel <= FPU_OP_ABS;
    a_in   <= fp80_from_int(-9);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(9), "FABS -9");

    op_sel <= FPU_OP_ABS;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_QNAN, "FABS NaN payload preserved");

    op_sel <= FPU_OP_ABS;
    a_in   <= SUBNORMAL_NEG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(SUBNORMAL_POS, "FABS subnormal sign clear");
    run_monadic_exact(FPU_OP_ABS, FP80_ARG_M2P3, abs_fp80(FP80_ARG_M2P3), "FABS -2.3");
    run_monadic_exact(FPU_OP_ABS, FP80_ARG_M0P7, abs_fp80(FP80_ARG_M0P7), "FABS -0.7");
    run_monadic_exact(FPU_OP_ABS, FP80_ARG_12P5, abs_fp80(FP80_ARG_12P5), "FABS 12.5");

    -- FNEG toggles sign, including signed zero.
    op_sel <= FPU_OP_NEG;
    a_in   <= fp80_from_int(4);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(-4), "FNEG 4");

    op_sel <= FPU_OP_NEG;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"80000000000000000000", "FNEG +0 -> -0");

    op_sel <= FPU_OP_NEG;
    a_in   <= SUBNORMAL_POS;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(SUBNORMAL_NEG, "FNEG subnormal sign toggle");
    run_monadic_exact(FPU_OP_NEG, FP80_ARG_1P1, neg_fp80(FP80_ARG_1P1), "FNEG 1.1");
    run_monadic_exact(FPU_OP_NEG, FP80_ARG_M2P3, neg_fp80(FP80_ARG_M2P3), "FNEG -2.3");
    run_monadic_exact(FPU_OP_NEG, FP80_ARG_12P5, neg_fp80(FP80_ARG_12P5), "FNEG 12.5");

    -- FINTRZ truncates toward zero for positive and negative values.
    op_sel <= FPU_OP_INTRZ;
    a_in   <= x"4000B000000000000000"; -- 2.75
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(2), "FINTRZ +2.75");

    op_sel <= FPU_OP_INTRZ;
    a_in   <= x"C000B000000000000000"; -- -2.75
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(-2), "FINTRZ -2.75");

    op_sel <= FPU_OP_INTRZ;
    a_in   <= SUBNORMAL_POS;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FINTRZ +subnormal -> +0");

    op_sel <= FPU_OP_INTRZ;
    a_in   <= SUBNORMAL_NEG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"80000000000000000000", "FINTRZ -subnormal -> -0");
    run_monadic_exact(FPU_OP_INTRZ, FP80_ARG_1P7, fintrz_fp80(FP80_ARG_1P7), "FINTRZ 1.7");
    run_monadic_exact(FPU_OP_INTRZ, FP80_ARG_M2P3, fintrz_fp80(FP80_ARG_M2P3), "FINTRZ -2.3");
    run_monadic_exact(FPU_OP_INTRZ, FP80_ARG_12P5, fintrz_fp80(FP80_ARG_12P5), "FINTRZ 12.5");

    -- FINT uses FPCR round mode.
    op_sel <= FPU_OP_INT;
    round_mode <= FP_RND_NEAREST;
    a_in   <= x"4000A000000000000000"; -- 2.5
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(2), "FINT nearest tie-to-even +2.5");

    op_sel <= FPU_OP_INT;
    round_mode <= FP_RND_NEAREST;
    a_in   <= x"3FFFC000000000000000"; -- 1.5
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(2), "FINT nearest +1.5");

    op_sel <= FPU_OP_INT;
    round_mode <= FP_RND_PLUS_INF;
    a_in   <= x"40009000000000000000"; -- 2.25
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(3), "FINT +inf mode +2.25");

    op_sel <= FPU_OP_INT;
    round_mode <= FP_RND_MINUS_INF;
    a_in   <= x"C0009000000000000000"; -- -2.25
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(-3), "FINT -inf mode -2.25");

    op_sel <= FPU_OP_INT;
    round_mode <= FP_RND_NEAREST;
    a_in   <= SUBNORMAL_NEG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"80000000000000000000", "FINT nearest -subnormal -> -0");

    op_sel <= FPU_OP_INT;
    round_mode <= FP_RND_PLUS_INF;
    a_in   <= SUBNORMAL_POS;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ONE, "FINT +inf +subnormal -> +1");

    op_sel <= FPU_OP_INT;
    round_mode <= FP_RND_MINUS_INF;
    a_in   <= SUBNORMAL_NEG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(-1), "FINT -inf -subnormal -> -1");
    round_mode <= FP_RND_NEAREST;
    run_monadic_exact(FPU_OP_INT, FP80_ARG_1P7, fint_fp80(FP80_ARG_1P7, FP_RND_NEAREST), "FINT nearest 1.7");
    run_monadic_exact(FPU_OP_INT, FP80_ARG_M2P3, fint_fp80(FP80_ARG_M2P3, FP_RND_NEAREST), "FINT nearest -2.3");
    run_monadic_exact(FPU_OP_INT, FP80_ARG_12P5, fint_fp80(FP80_ARG_12P5, FP_RND_NEAREST), "FINT nearest 12.5");

    -- FGETEXP class behavior and finite exponent extraction.
    op_sel <= FPU_OP_GETEXP;
    a_in   <= fp80_from_int(8);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(3), "FGETEXP 8 -> 3");

    op_sel <= FPU_OP_GETEXP;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"FFFF0000000000000000", "FGETEXP 0 -> -inf");

    op_sel <= FPU_OP_GETEXP;
    a_in   <= FP80_POS_INF;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"7FFFFFFFFFFFFFFFFFFF", "FGETEXP inf -> NaN (OPERR)");

    op_sel <= FPU_OP_GETEXP;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_QNAN, "FGETEXP NaN propagate");

    op_sel <= FPU_OP_GETEXP;
    a_in   <= x"00000000000000000001"; -- smallest positive subnormal
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(fp80_from_int(1 - FP_EXP_BIAS - (FP_MANT_WIDTH - 1)), "FGETEXP min subnormal");
    run_monadic_exact(FPU_OP_GETEXP, FP80_ARG_1P1, fgetexp_fp80(FP80_ARG_1P1), "FGETEXP 1.1");
    run_monadic_exact(FPU_OP_GETEXP, FP80_ARG_M2P3, fgetexp_fp80(FP80_ARG_M2P3), "FGETEXP -2.3");
    run_monadic_exact(FPU_OP_GETEXP, FP80_ARG_12P5, fgetexp_fp80(FP80_ARG_12P5), "FGETEXP 12.5");

    -- FGETMAN normalizes finite values and passes through zero/inf/nan.
    op_sel <= FPU_OP_GETMAN;
    a_in   <= x"C001D000000000000000"; -- -6.5
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"BFFFD000000000000000", "FGETMAN -6.5 -> -1.625");

    op_sel <= FPU_OP_GETMAN;
    a_in   <= x"00000000000000000001"; -- smallest positive subnormal
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"3FFF8000000000000000", "FGETMAN min subnormal -> +1.0");

    op_sel <= FPU_OP_GETMAN;
    a_in   <= FP80_ZERO;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_ZERO, "FGETMAN zero passthrough");

    op_sel <= FPU_OP_GETMAN;
    a_in   <= FP80_POS_INF;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"7FFFFFFFFFFFFFFFFFFF", "FGETMAN inf -> NaN (OPERR)");

    op_sel <= FPU_OP_GETMAN;
    a_in   <= FP80_QNAN;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(FP80_QNAN, "FGETMAN NaN passthrough");
    run_monadic_exact(FPU_OP_GETMAN, FP80_ARG_1P1, fgetman_fp80(FP80_ARG_1P1), "FGETMAN 1.1");
    run_monadic_exact(FPU_OP_GETMAN, FP80_ARG_M2P3, fgetman_fp80(FP80_ARG_M2P3), "FGETMAN -2.3");
    run_monadic_exact(FPU_OP_GETMAN, FP80_ARG_12P5, fgetman_fp80(FP80_ARG_12P5), "FGETMAN 12.5");

    -- FTST result pass-through.
    op_sel <= FPU_OP_TST;
    a_in   <= x"BFFF8000000000000000"; -- -1
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(x"BFFF8000000000000000", "FTST passthrough");

    op_sel <= FPU_OP_TST;
    a_in   <= SUBNORMAL_NEG;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;
    check_result(SUBNORMAL_NEG, "FTST subnormal passthrough");
    run_monadic_exact(FPU_OP_TST, FP80_ARG_1P1, FP80_ARG_1P1, "FTST 1.1 passthrough");
    run_monadic_exact(FPU_OP_TST, FP80_ARG_M2P3, FP80_ARG_M2P3, "FTST -2.3 passthrough");
    run_monadic_exact(FPU_OP_TST, FP80_ARG_12P5, FP80_ARG_12P5, "FTST 12.5 passthrough");

    std.env.stop;
    wait;
  end process;
end architecture sim;

