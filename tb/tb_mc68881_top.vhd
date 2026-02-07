library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity tb_mc68881_top is
end entity tb_mc68881_top;

architecture sim of tb_mc68881_top is
  signal a_in     : std_logic_vector(4 downto 0) := (others => '0');
  signal d_in     : std_logic_vector(31 downto 0) := (others => '0');
  signal d_out    : std_logic_vector(31 downto 0);
  signal size_n   : std_logic := '1';
  signal as_n     : std_logic := '1';
  signal cs_n     : std_logic := '1';
  signal rw       : std_logic := '1';
  signal ds_n     : std_logic := '1';
  signal dsack0_n : std_logic;
  signal dsack1_n : std_logic;
  signal reset_n  : std_logic := '0';
  signal clk      : std_logic := '0';
  signal sense_n  : std_logic;

  constant CLK_PERIOD : time := 10 ns;

  procedure bus_write(
    constant addr : unsigned(4 downto 0);
    constant data : std_logic_vector(31 downto 0)
  ) is
  begin
    a_in <= std_logic_vector(addr);
    d_in <= data;
    rw   <= '0';
    cs_n <= '0';
    as_n <= '0';
    ds_n <= '0';
    wait for CLK_PERIOD;
    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    rw   <= '1';
    wait for CLK_PERIOD;
  end procedure;

  procedure bus_read(
    constant addr : unsigned(4 downto 0)
  ) is
  begin
    a_in <= std_logic_vector(addr);
    rw   <= '1';
    cs_n <= '0';
    as_n <= '0';
    ds_n <= '0';
    wait for CLK_PERIOD;
    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;
  end procedure;

begin
  clk <= not clk after CLK_PERIOD/2;

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

    -- Write operands and op select (ADD)
    bus_write(to_unsigned(0, 5), x"00000001");
    bus_write(to_unsigned(1, 5), x"0000000A");
    bus_write(to_unsigned(2, 5), x"00000000");
    bus_write(to_unsigned(3, 5), x"00000000");
    bus_write(to_unsigned(4, 5), x"00000005");
    bus_write(to_unsigned(5, 5), x"00000000");
    bus_write(to_unsigned(6, 5), x"00000000");

    bus_read(to_unsigned(7, 5));
    assert d_out = x"0000000F"
      report "ADD result lower word mismatch"
      severity failure;

    -- DSACK should not be both high during active cycle
    assert not (dsack0_n = '1' and dsack1_n = '1')
      report "DSACK should acknowledge immediate response in stub"
      severity note;

    wait;
  end process;
end architecture sim;
