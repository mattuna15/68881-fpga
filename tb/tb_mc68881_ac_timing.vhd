library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_mc68881_ac_timing is
end entity tb_mc68881_ac_timing;

architecture sim of tb_mc68881_ac_timing is
  signal a_in     : std_logic_vector(4 downto 0) := (others => '0');
  signal d_in     : std_logic_vector(31 downto 0) := (others => '0');
  signal d_out    : std_logic_vector(31 downto 0);
  signal size_n   : std_logic_vector(1 downto 0) := "11";
  signal as_n     : std_logic := '1';
  signal cs_n     : std_logic := '1';
  signal rw       : std_logic := '1';
  signal ds_n     : std_logic := '1';
  signal dsack0_n : std_logic;
  signal dsack1_n : std_logic;
  signal reset_n  : std_logic := '0';
  signal clk      : std_logic := '0';
  signal sense_n  : std_logic;
  signal cycle_cnt : natural := 0;
  signal start_access_tb : std_logic := '0';

  constant CLK_PERIOD : time := 10 ns;

  procedure start_access(
    signal a_in_s  : out std_logic_vector(4 downto 0);
    signal size_n_s: out std_logic_vector(1 downto 0);
    signal rw_s    : out std_logic;
    signal cs_n_s  : out std_logic;
    signal as_n_s  : out std_logic;
    signal ds_n_s  : out std_logic;
    constant is_read : boolean;
    constant size_val : std_logic_vector(1 downto 0);
    constant addr_val : std_logic_vector(4 downto 0);
    variable start_cycle : out natural
  ) is
  begin
    wait until falling_edge(clk);
    size_n_s <= size_val;
    a_in_s   <= addr_val;
    rw_s     <= '1' when is_read else '0';
    cs_n_s   <= '0';
    as_n_s   <= '0';
    ds_n_s   <= '0';
    wait until rising_edge(clk);
    wait for 0 ns;
    start_cycle := cycle_cnt;
  end procedure;

  procedure end_access(
    signal rw_s      : out std_logic;
    signal cs_n_s    : out std_logic;
    signal as_n_s    : out std_logic;
    signal ds_n_s    : out std_logic;
    signal dsack0_n_s: in  std_logic;
    signal dsack1_n_s: in  std_logic;
    constant label_text : string
  ) is
  begin
    wait until falling_edge(clk);
    cs_n_s <= '1';
    as_n_s <= '1';
    ds_n_s <= '1';
    rw_s   <= '1';
    wait until rising_edge(clk);
    wait for 0 ns;
    wait until rising_edge(clk);
    wait for 0 ns;
    assert dsack0_n_s = '1' and dsack1_n_s = '1'
      report "DSACK not deasserted after end_access for " & label_text
      severity error;
    wait for CLK_PERIOD;
  end procedure;

  procedure assert_dsack_latency(
    signal a_in_s    : out std_logic_vector(4 downto 0);
    signal size_n_s  : out std_logic_vector(1 downto 0);
    signal rw_s      : out std_logic;
    signal cs_n_s    : out std_logic;
    signal as_n_s    : out std_logic;
    signal ds_n_s    : out std_logic;
    signal dsack0_n_s: in  std_logic;
    signal dsack1_n_s: in  std_logic;
    constant is_read : boolean;
    constant size_val : std_logic_vector(1 downto 0);
    constant addr_val : std_logic_vector(4 downto 0);
    constant expected_cycles : natural;
    constant label_text : string
  ) is
    variable start_cycle : natural := 0;
    variable cycles_waited : natural := 0;
  begin
    start_access(a_in_s, size_n_s, rw_s, cs_n_s, as_n_s, ds_n_s, is_read, size_val, addr_val, start_cycle);
    loop
      wait until rising_edge(clk);
      wait for 0 ns;
      exit when start_access_tb = '1';
    end loop;
    cycles_waited := 0;
    loop
      wait until rising_edge(clk);
      wait for 0 ns;
      cycles_waited := cycles_waited + 1;
      exit when (dsack0_n_s = '0') or (dsack1_n_s = '0');
    end loop;
    report "DSACK latency " & label_text &
           " expected=" & integer'image(expected_cycles) &
           " got=" & integer'image(cycles_waited)
      severity note;
    assert cycles_waited = expected_cycles
      report "DSACK latency mismatch for " & label_text
      severity error;
    end_access(rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, label_text);
  end procedure;

  procedure assert_dsack_wait_state(
    signal a_in_s    : out std_logic_vector(4 downto 0);
    signal size_n_s  : out std_logic_vector(1 downto 0);
    signal rw_s      : out std_logic;
    signal cs_n_s    : out std_logic;
    signal as_n_s    : out std_logic;
    signal ds_n_s    : out std_logic;
    signal dsack0_n_s: in  std_logic;
    signal dsack1_n_s: in  std_logic;
    constant size_val : std_logic_vector(1 downto 0);
    constant addr_val : std_logic_vector(4 downto 0);
    constant hold_cycles : natural;
    constant label_text : string
  ) is
    variable start_cycle : natural := 0;
  begin
    start_access(a_in_s, size_n_s, rw_s, cs_n_s, as_n_s, ds_n_s, true, size_val, addr_val, start_cycle);
    for loop_idx in 0 to hold_cycles-1 loop
      report "DSACK wait-state hold " & label_text &
             " cycle=" & integer'image(cycle_cnt)
        severity note;
      assert dsack0_n_s = '1' and dsack1_n_s = '1'
        report "DSACK asserted during wait-state for " & label_text
        severity error;
      wait until rising_edge(clk);
    end loop;
    end_access(rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, label_text);
  end procedure;
begin
  start_access_tb <= '1' when (cs_n = '0' and as_n = '0' and ((rw = '1' and ds_n = '0') or rw = '0')) else '0';

  clk <= not clk after CLK_PERIOD/2;

  cycle_counter : process(clk)
  begin
    if rising_edge(clk) then
      cycle_cnt <= cycle_cnt + 1;
    end if;
  end process;

  dut : entity work.mc68881_top
    port map (
      a_in     => a_in,
      d_in     => d_in,
      d_out    => d_out,
      size_n   => size_n,
      as_n     => as_n,
      cs_n     => cs_n,
      rw       => rw,
      ds_n     => ds_n,
      dsack0_n => dsack0_n,
      dsack1_n => dsack1_n,
      reset_n  => reset_n,
      clk      => clk,
      sense_n  => sense_n
    );

  process
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    assert_dsack_latency(
      a_in,
      size_n,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      true,
      "11",
      "10000",
      1,
      "read 32-bit A4=1"
    );

    assert_dsack_latency(
      a_in,
      size_n,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      false,
      "11",
      "10000",
      1,
      "write 32-bit A4=1"
    );

    assert_dsack_wait_state(
      a_in,
      size_n,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      "00",
      "00000",
      3,
      "wait-state size"
    );

    report "TB SUCCESS: AC timing checks complete."
      severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
