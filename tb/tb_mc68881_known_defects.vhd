library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_known_defects is
end entity tb_mc68881_known_defects;

architecture sim of tb_mc68881_known_defects is
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

  constant CLK_PERIOD : time := 10 ns;
  constant ARG_M40P75 : fp80_t := x"C004A300000000000000";
  constant EXP_COS_M40P75 : fp80_t := x"BFFEFEF297A986C98000";
  constant FP80_TOL_5E2 : fp80_t := x"3FFACCCCCCCCCCCCD000"; -- 5e-2
begin
  clk <= not clk after CLK_PERIOD/2;

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
      packed_fp_add_result => open
    );

  process
    variable diff : fp80_t := (others => '0');
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    op_sel <= FPU_OP_COS;
    a_in   <= ARG_M40P75;
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
    wait for 0 ns;
    wait until valid = '1';
    wait for 0 ns;

    assert valid = '1'
      report "Known-defect bench did not observe valid completion."
      severity failure;

    diff := abs_fp80(add_sub_fp80(result, EXP_COS_M40P75, true, FP_RND_NEAREST, FP_PREC_EXTENDED));

    if compare_fp80(diff, FP80_TOL_5E2) <= 0 then
      report "DEF-TRIG-001 CLOSED: FCOS(-40.75) matches expected sign/magnitude. got="
             & to_hstring(result) & " expected=" & to_hstring(EXP_COS_M40P75)
        severity note;
    else
      report "DEF-TRIG-001 RECHECK: FCOS(-40.75) differs from expected. got="
             & to_hstring(result) & " expected=" & to_hstring(EXP_COS_M40P75)
        severity note;
    end if;

    stop;
    wait;
  end process;
end architecture sim;
