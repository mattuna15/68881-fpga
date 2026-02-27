library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_mc68881_op_class_dispatch is
end entity tb_mc68881_op_class_dispatch;

architecture sim of tb_mc68881_op_class_dispatch is
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

  signal status_word : std_logic_vector(31 downto 0) := (others => '0');
  signal cycle_total_word : std_logic_vector(31 downto 0) := (others => '0');

  constant CLK_PERIOD : time := 10 ns;
  constant ADDR_OPSEL : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPB_L : unsigned(4 downto 0) := to_unsigned(4, 5);
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_CIR_RESPONSE : unsigned(4 downto 0) := to_unsigned(13, 5);
  constant ADDR_FPSR : unsigned(4 downto 0) := to_unsigned(14, 5);
  constant ADDR_CYCLE_TOTAL : unsigned(4 downto 0) := to_unsigned(22, 5);

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

  procedure wait_for_valid(
    signal a_in_s    : out std_logic_vector(4 downto 0);
    signal rw_s      : out std_logic;
    signal cs_n_s    : out std_logic;
    signal as_n_s    : out std_logic;
    signal ds_n_s    : out std_logic;
    signal dsack0_n_s: in  std_logic;
    signal dsack1_n_s: in  std_logic;
    signal d_out_s   : in  std_logic_vector(31 downto 0);
    signal status_word_s : inout std_logic_vector(31 downto 0);
    constant test_name : string
  ) is
  begin
    loop
      bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, status_word_s, ADDR_STATUS);
      report "STATUS poll " & test_name &
             " valid=" & std_logic'image(status_word_s(0)) &
             " busy=" & std_logic'image(status_word_s(1))
        severity note;
      exit when status_word_s(0) = '1';
    end loop;
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

    -- Arithmetic class dispatch (FSQRT).
    report "Issuing FSQRT opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000011");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FSQRT");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FSQRT cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 120
      report "FSQRT should execute through arithmetic class with expected modeled cycles."
      severity failure;

    -- Arithmetic class dispatch (FTST).
    report "Issuing FTST opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000018");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FTST");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FTST cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 49
      report "FTST should execute through arithmetic class with expected modeled cycles."
      severity failure;

    -- Arithmetic class dispatch (FETOX).
    report "Issuing FETOX opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000045");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FETOX");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FETOX cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 132
      report "FETOX should execute through arithmetic class with expected modeled cycles."
      severity failure;

    -- Program-control class dispatch (FNOP).
    report "Issuing FNOP opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000020");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FNOP");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FNOP cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 0
      report "FNOP should execute through program-control class with zero modeled cycles."
      severity failure;

    -- Program-control class dispatch (FScc).
    report "Issuing FScc opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000021");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FScc");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FScc cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 0
      report "FScc should execute through program-control class with zero modeled cycles."
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CIR_RESPONSE);

    -- Program-control class dispatch (FBcc).
    report "Issuing FBcc opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000022");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FBcc");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FBcc cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 0
      report "FBcc should execute through program-control class with zero modeled cycles."
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CIR_RESPONSE);

    -- Program-control class dispatch (FDBcc).
    report "Issuing FDBcc opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"08000000"); -- Z clear
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPB_L, x"00000003"); -- loop counter
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000023");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FDBcc");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FDBcc cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 0
      report "FDBcc should execute through program-control class with zero modeled cycles."
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CIR_RESPONSE);

    -- System-control class dispatch (FSAVE placeholder opcode).
    report "Issuing FSAVE opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000030");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FSAVE");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FSAVE cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 0
      report "FSAVE should execute through system-control class with zero modeled cycles."
      severity failure;

    -- System-control class dispatch (FRESTORE placeholder opcode).
    report "Issuing FRESTORE opcode through OPSEL." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000031");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FRESTORE");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FRESTORE cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 0
      report "FRESTORE should execute through system-control class with zero modeled cycles."
      severity failure;

    -- Clear CIR response pending from previous FScc before issuing next conditional op.
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CIR_RESPONSE);

    -- Program-control class dispatch (FTRAPcc condition evaluation).
    report "Issuing FTRAPcc opcode through OPSEL (EQ with Z=1)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, x"01000024"); -- FTRAPcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, "FTRAPcc");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CYCLE_TOTAL);
    report "FTRAPcc cycle_total=" & integer'image(to_integer(unsigned(cycle_total_word))) severity note;
    assert to_integer(unsigned(cycle_total_word)) = 0
      report "FTRAPcc should execute through program-control class with zero modeled cycles."
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, cycle_total_word, ADDR_CIR_RESPONSE);
    report "FTRAPcc CIR_RESPONSE=" & to_hstring(cycle_total_word) severity note;
    assert cycle_total_word(0) = '1'
      report "FTRAPcc EQ with Z=1 should report cond_true=1"
      severity failure;
    assert cycle_total_word(5) = '1'
      report "FTRAPcc EQ with Z=1 should report trap_requested=1"
      severity failure;

    report "TB SUCCESS: opcode class dispatch checks passed." severity note;
    stop;
    wait;
  end process;
end architecture sim;
