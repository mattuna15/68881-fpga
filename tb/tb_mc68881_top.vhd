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
  signal rd_lo    : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_hi    : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_ex    : std_logic_vector(31 downto 0) := (others => '0');
  signal rd_res   : fp80_t := (others => '0');
  signal cycle_cnt: natural := 0;

  constant CLK_PERIOD : time := 10 ns;
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);

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

  procedure check_fp80(
    constant got      : fp80_t;
    constant expected : fp80_t;
    constant test_name: string
  ) is
    variable got_sign  : std_logic := '0';
    variable exp_sign  : std_logic := '0';
    variable got_exp   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable exp_exp   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_mant  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    split_fp80(got, got_sign, got_exp, got_mant);
    split_fp80(expected, exp_sign, exp_exp, exp_mant);
    assert got_sign = exp_sign and got_exp = exp_exp and got_mant = exp_mant
      report "Mismatch: " & test_name &
             " expected=" & to_hstring(expected) &
             " got=" & to_hstring(got)
      severity failure;
  end procedure;

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
    signal d_out_s   : in  std_logic_vector(31 downto 0)
  ) is
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    loop
      bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, status_word, ADDR_STATUS);
      report "STATUS poll: valid=" & std_logic'image(status_word(0)) &
             " busy=" & std_logic'image(status_word(1)) &
             " cycle=" & integer'image(cycle_cnt)
        severity note;
      exit when status_word(0) = '1';
    end loop;
  end procedure;

begin
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
    variable op_a : fp80_t := (others => '0');
    variable op_b : fp80_t := (others => '0');
    variable exp_r: fp80_t := (others => '0');
    variable rd_full : fp80_t := (others => '0');
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    -- Write operands and op select (ADD)
    size_n <= "11";
    op_a := fp80_from_int(10);
    op_b := fp80_from_int(5);
    exp_r := add_sub_fp80(op_a, op_b, false);
    report "ADD operands: op_a=" & to_hstring(op_a) & " op_b=" & to_hstring(op_b)
      severity note;
    report "ADD expected: " & to_hstring(exp_r)
      severity note;
    report "ADD cycle start: " & integer'image(cycle_cnt)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000001");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "ADD readback: ex=" & to_hstring(rd_ex) & " hi=" & to_hstring(rd_hi) & " lo=" & to_hstring(rd_lo)
      severity note;
    report "ADD result:  " & to_hstring(rd_full)
      severity note;
    report "ADD cycle end: " & integer'image(cycle_cnt)
      severity note;
    check_fp80(rd_full, exp_r, "ADD result");

    -- MUL
    op_a := fp80_from_int(7);
    op_b := fp80_from_int(9);
    exp_r := mul_fp80(op_a, op_b);
    report "MUL operands: op_a=" & to_hstring(op_a) & " op_b=" & to_hstring(op_b)
      severity note;
    report "MUL expected: " & to_hstring(exp_r)
      severity note;
    report "MUL cycle start: " & integer'image(cycle_cnt)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000003");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "MUL readback: ex=" & to_hstring(rd_ex) & " hi=" & to_hstring(rd_hi) & " lo=" & to_hstring(rd_lo)
      severity note;
    report "MUL result:  " & to_hstring(rd_full)
      severity note;
    report "MUL cycle end: " & integer'image(cycle_cnt)
      severity note;
    check_fp80(rd_full, exp_r, "MUL result");

    -- DIV
    op_a := fp80_from_int(40);
    op_b := fp80_from_int(5);
    exp_r := div_fp80(op_a, op_b);
    report "DIV operands: op_a=" & to_hstring(op_a) & " op_b=" & to_hstring(op_b)
      severity note;
    report "DIV expected: " & to_hstring(exp_r)
      severity note;
    report "DIV cycle start: " & integer'image(cycle_cnt)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "DIV readback: ex=" & to_hstring(rd_ex) & " hi=" & to_hstring(rd_hi) & " lo=" & to_hstring(rd_lo)
      severity note;
    report "DIV result:  " & to_hstring(rd_full)
      severity note;
    report "DIV cycle end: " & integer'image(cycle_cnt)
      severity note;
    check_fp80(rd_full, exp_r, "DIV result");

    -- DSACK behavior coverage
    size_n <= "11";
    a_in   <= "10000";
    cs_n   <= '0';
    as_n   <= '0';
    ds_n   <= '0';
    wait for CLK_PERIOD/2;
    report "DSACK 32-bit A4=1: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '0' and dsack1_n = '0'
      report "DSACK mismatch for 32-bit with A4=1"
      severity failure;

    a_in <= "00000";
    wait for CLK_PERIOD/2;
    report "DSACK 32-bit A4=0: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '1' and dsack1_n = '0'
      report "DSACK mismatch for 32-bit with A4=0"
      severity failure;

    size_n <= "10";
    wait for CLK_PERIOD/2;
    report "DSACK 16-bit: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '1' and dsack1_n = '0'
      report "DSACK mismatch for 16-bit access"
      severity failure;

    size_n <= "01";
    wait for CLK_PERIOD/2;
    report "DSACK 8-bit: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '0' and dsack1_n = '1'
      report "DSACK mismatch for 8-bit access"
      severity failure;

    size_n <= "00";
    wait for CLK_PERIOD/2;
    report "DSACK wait: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '1' and dsack1_n = '1'
      report "DSACK mismatch for wait state insertion"
      severity failure;

    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;

    report "TB SUCCESS: all checks passed"
      severity note;
    wait;
  end process;
end architecture sim;
