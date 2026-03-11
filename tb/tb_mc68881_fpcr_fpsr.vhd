library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_mc68881_fpcr_fpsr is
end entity tb_mc68881_fpcr_fpsr;

architecture sim of tb_mc68881_fpcr_fpsr is
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
  signal rd_data  : std_logic_vector(31 downto 0) := (others => '0');

  constant CLK_PERIOD : time := 10 ns;
  constant ADDR_FPCR   : unsigned(4 downto 0) := to_unsigned(11, 5);
  constant ADDR_FPSR   : unsigned(4 downto 0) := to_unsigned(14, 5);

  procedure bus_write(
    signal a_in_s  : out std_logic_vector(4 downto 0);
    signal d_in_s  : out std_logic_vector(31 downto 0);
    signal rw_s    : out std_logic;
    signal cs_n_s  : out std_logic;
    signal as_n_s  : out std_logic;
    signal ds_n_s  : out std_logic;
    constant addr  : unsigned(4 downto 0);
    constant data  : std_logic_vector(31 downto 0)
  ) is
  begin
    a_in_s <= std_logic_vector(addr);
    d_in_s <= data;
    rw_s   <= '0';
    cs_n_s <= '0';
    as_n_s <= '0';
    ds_n_s <= '0';
    wait for CLK_PERIOD;
    cs_n_s <= '1';
    as_n_s <= '1';
    ds_n_s <= '1';
    rw_s   <= '1';
    wait for CLK_PERIOD;
  end procedure;

  procedure bus_read(
    signal a_in_s    : out std_logic_vector(4 downto 0);
    signal rw_s      : out std_logic;
    signal cs_n_s    : out std_logic;
    signal as_n_s    : out std_logic;
    signal ds_n_s    : out std_logic;
    signal dsack0_n_s: in  std_logic;
    signal dsack1_n_s: in  std_logic;
    signal d_out_s   : in  std_logic_vector(31 downto 0);
    signal data_s    : out std_logic_vector(31 downto 0);
    constant addr    : unsigned(4 downto 0)
  ) is
  begin
    a_in_s <= std_logic_vector(addr);
    rw_s   <= '1';
    cs_n_s <= '0';
    as_n_s <= '0';
    ds_n_s <= '0';
    wait until (dsack0_n_s = '0') or (dsack1_n_s = '0');
    wait for CLK_PERIOD/4;
    data_s <= d_out_s;
    wait for CLK_PERIOD/4;
    cs_n_s <= '1';
    as_n_s <= '1';
    ds_n_s <= '1';
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
    variable fpcr_write : std_logic_vector(31 downto 0) := (others => '0');
    variable fpsr_write : std_logic_vector(31 downto 0) := (others => '0');
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;
    -- Disable CIR mode so FPSR (addr 14) routes to peripheral decode.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              to_unsigned(13, 5), x"00000000");

    fpcr_write := x"ABCD1234";
    report "FPCR write: " & to_hstring(fpcr_write) severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, fpcr_write);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_data, ADDR_FPCR);
    report "FPCR read:  " & to_hstring(rd_data) severity note;
    assert rd_data(15 downto 0) = fpcr_write(15 downto 0)
      report "FPCR lower 16 bits mismatch" severity failure;
    assert rd_data(31 downto 16) = std_logic_vector(to_unsigned(0, 16))
      report "FPCR upper 16 bits should be zero" severity failure;

    fpsr_write := x"CAFEBABE";
    report "FPSR write: " & to_hstring(fpsr_write) severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, fpsr_write);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_data, ADDR_FPSR);
    report "FPSR read:  " & to_hstring(rd_data) severity note;
    assert rd_data = fpsr_write
      report "FPSR readback mismatch" severity failure;

    report "TB SUCCESS: FPCR/FPSR checks passed" severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
