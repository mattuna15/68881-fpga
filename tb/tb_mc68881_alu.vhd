library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity tb_mc68881_alu is
end entity tb_mc68881_alu;

architecture sim of tb_mc68881_alu is
  signal clk    : std_logic := '0';
  signal reset_n: std_logic := '0';
  signal start  : std_logic := '0';
  signal op_sel : fpu_op_t := FPU_OP_NOP;
  signal a_in   : fp80_t := (others => '0');
  signal b_in   : fp80_t := (others => '0');
  signal result : fp80_t;
  signal valid  : std_logic;
  signal busy   : std_logic;
  signal cycle_cnt : natural := 0;

  constant CLK_PERIOD : time := 10 ns;
  constant ADD_LATENCY : natural := 1;
  constant SUB_LATENCY : natural := 1;
  constant MUL_LATENCY : natural := 4;
  constant DIV_LATENCY : natural := 8;

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

  function fp80_from_int(value : integer) return fp80_t is
  begin
    return work.mc68881_pkg.fp80_from_int(value);
  end function;

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
      a_in   => a_in,
      b_in   => b_in,
      result => result,
      valid  => valid,
      busy   => busy
    );

  process
    variable start_cycle : natural := 0;
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    -- ADD
    op_sel <= FPU_OP_ADD;
    a_in   <= fp80_from_int(10);
    b_in   <= fp80_from_int(5);
    start <= '1';
    wait until rising_edge(clk);
    start <= '0';
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
    start_cycle := cycle_cnt;
    wait until valid = '1';
    report "DIV latency cycles: " & integer'image(cycle_cnt - start_cycle)
      severity note;
    assert cycle_cnt - start_cycle = DIV_LATENCY
      report "DIV latency mismatch"
      severity failure;
    check_result(fp80_from_int(8), "DIV 40/5");

    wait;
  end process;
end architecture sim;
