library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

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
  signal status_word : std_logic_vector(31 downto 0) := (others => '0');
  signal cycle_cnt: natural := 0;

  constant CLK_PERIOD : time := 10 ns;
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_FPCR   : unsigned(4 downto 0) := to_unsigned(11, 5);
  constant ADDR_FPSR   : unsigned(4 downto 0) := to_unsigned(14, 5);

  constant FPCR_RND_NEAREST : std_logic_vector(31 downto 0) := x"00000000";
  constant FPCR_RND_ZERO    : std_logic_vector(31 downto 0) := x"00000010";
  constant FPCR_RND_PLUS    : std_logic_vector(31 downto 0) := x"00000030";
  constant FPCR_PREC_SINGLE : std_logic_vector(31 downto 0) := x"00000040";
  constant FPCR_PREC_DOUBLE : std_logic_vector(31 downto 0) := x"00000080";
  constant FPSR_EXC_DIVZERO : natural := 3;

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

  function make_fp80(
    constant sign : std_logic;
    constant exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    constant mant : unsigned(FP_MANT_WIDTH-1 downto 0)
  ) return fp80_t is
    variable result : fp80_t := (others => '0');
  begin
    result(FP_WIDTH-1) := sign;
    result(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(exp);
    result(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(mant);
    return result;
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
    signal status_word_s : inout std_logic_vector(31 downto 0)
  ) is
  begin
    loop
      bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, status_word_s, ADDR_STATUS);
      report "STATUS poll: valid=" & std_logic'image(status_word_s(0)) &
             " busy=" & std_logic'image(status_word_s(1)) &
             " cycle=" & integer'image(cycle_cnt)
        severity note;
      exit when status_word_s(0) = '1';
    end loop;
  end procedure;

  procedure wait_for_sense(
    signal sense_n_s : in std_logic;
    constant expected : std_logic;
    constant test_name : string
  ) is
    variable seen : boolean := false;
  begin
    for idx in 0 to 200 loop
      wait for CLK_PERIOD;
      if sense_n_s = expected then
        seen := true;
        exit;
      end if;
    end loop;
    assert seen
      report "SENSE did not reach expected state for " & test_name &
             " expected=" & std_logic'image(expected) &
             " got=" & std_logic'image(sense_n_s)
      severity failure;
    report "SENSE state: " & test_name &
           " value=" & std_logic'image(sense_n_s)
      severity note;
  end procedure;

  procedure assert_idle_outputs(
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal sense_n_s  : in std_logic;
    constant test_name : string
  ) is
  begin
    assert dsack0_n_s = '1' and dsack1_n_s = '1'
      report "DSACK lines should be deasserted during idle for " & test_name &
             " dsack1_n=" & std_logic'image(dsack1_n_s) &
             " dsack0_n=" & std_logic'image(dsack0_n_s)
      severity failure;
    assert sense_n_s = '1'
      report "SENSE should be deasserted during idle for " & test_name &
             " sense_n=" & std_logic'image(sense_n_s)
      severity failure;
    report "Idle output check: " & test_name &
           " dsack1_n=" & std_logic'image(dsack1_n_s) &
           " dsack0_n=" & std_logic'image(dsack0_n_s) &
           " sense_n=" & std_logic'image(sense_n_s)
      severity note;
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
    assert_idle_outputs(dsack0_n, dsack1_n, sense_n, "post-reset idle");

    -- Write operands and op select (ADD)
    size_n <= "11";
    op_a := fp80_from_int(10);
    op_b := fp80_from_int(5);
    exp_r := add_sub_fp80(op_a, op_b, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
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
    wait_for_sense(sense_n, '0', "busy assert after ADD start");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    wait_for_sense(sense_n, '1', "idle deassert after ADD completion");

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
    exp_r := mul_fp80(op_a, op_b, FP_RND_NEAREST, FP_PREC_EXTENDED);
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

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

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
    exp_r := div_fp80(op_a, op_b, FP_RND_NEAREST, FP_PREC_EXTENDED);
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

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

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

    -- DIV fractional rounding (1/15)
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(15);
    exp_r := DIV_1_15_EXPECTED;
    report "DIV 1/15 operands: op_a=" & to_hstring(op_a) & " op_b=" & to_hstring(op_b)
      severity note;
    report "DIV 1/15 expected: " & to_hstring(exp_r)
      severity note;
    report "DIV 1/15 cycle start: " & integer'image(cycle_cnt)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "DIV 1/15 readback: ex=" & to_hstring(rd_ex) & " hi=" & to_hstring(rd_hi) & " lo=" & to_hstring(rd_lo)
      severity note;
    report "DIV 1/15 result:  " & to_hstring(rd_full)
      severity note;
    report "DIV 1/15 cycle end: " & integer'image(cycle_cnt)
      severity note;
    check_fp80(rd_full, exp_r, "DIV 1/15 result");

    -- FPCR rounding mode: round toward zero (1/7)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, FPCR_RND_ZERO);
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(7);
    exp_r := DIV_1_7_RZ_EXPECTED;
    report "DIV 1/7 RZ expected: " & to_hstring(exp_r)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "DIV 1/7 RZ result:  " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "DIV 1/7 RZ result");

    -- FPCR rounding mode: round toward +infinity (1/7)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, FPCR_RND_PLUS);
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(7);
    exp_r := DIV_1_7_RP_EXPECTED;
    report "DIV 1/7 RP expected: " & to_hstring(exp_r)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "DIV 1/7 RP result:  " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "DIV 1/7 RP result");

    -- FPCR precision: single (1/10)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, FPCR_PREC_SINGLE);
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(10);
    exp_r := DIV_1_10_SINGLE_EXPECTED;
    report "DIV 1/10 single expected: " & to_hstring(exp_r)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "DIV 1/10 single result:  " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "DIV 1/10 single result");

    -- FPCR precision: double (1/10)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, FPCR_PREC_DOUBLE);
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(10);
    exp_r := DIV_1_10_DOUBLE_EXPECTED;
    report "DIV 1/10 double expected: " & to_hstring(exp_r)
      severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(8, 5));
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(9, 5));

    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    rd_res  <= rd_full;
    report "DIV 1/10 double result:  " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "DIV 1/10 double result");

    -- FPSR exception flags: DIV by zero
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(0);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), op_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(5, 5), op_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(6, 5), x"0000" & op_b(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after DIV by zero: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_EXC_DIVZERO) = '1'
      report "FPSR DIV-by-zero flag not set"
      severity failure;

    -- DSACK behavior coverage
    size_n <= "11";
    a_in   <= "10000";
    cs_n   <= '0';
    as_n   <= '0';
    ds_n   <= '0';
    wait until (dsack0_n = '0') or (dsack1_n = '0');
    report "DSACK 32-bit A4=1: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '0' and dsack1_n = '0'
      report "DSACK mismatch for 32-bit with A4=1"
      severity failure;

    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;

    a_in <= "00000";
    cs_n <= '0';
    as_n <= '0';
    ds_n <= '0';
    wait until (dsack0_n = '0') or (dsack1_n = '0');
    report "DSACK 32-bit A4=0: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '1' and dsack1_n = '0'
      report "DSACK mismatch for 32-bit with A4=0"
      severity failure;

    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;

    size_n <= "10";
    cs_n <= '0';
    as_n <= '0';
    ds_n <= '0';
    wait until (dsack0_n = '0') or (dsack1_n = '0');
    report "DSACK 16-bit: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '1' and dsack1_n = '0'
      report "DSACK mismatch for 16-bit access"
      severity failure;

    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;

    size_n <= "01";
    cs_n <= '0';
    as_n <= '0';
    ds_n <= '0';
    wait until (dsack0_n = '0') or (dsack1_n = '0');
    report "DSACK 8-bit: dsack1_n=" & std_logic'image(dsack1_n) &
           " dsack0_n=" & std_logic'image(dsack0_n) &
           " cycle=" & integer'image(cycle_cnt)
      severity note;
    assert dsack0_n = '0' and dsack1_n = '1'
      report "DSACK mismatch for 8-bit access"
      severity failure;

    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;

    size_n <= "00";
    cs_n <= '0';
    as_n <= '0';
    ds_n <= '0';
    wait for CLK_PERIOD;
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
    assert_idle_outputs(dsack0_n, dsack1_n, sense_n, "post-DSACK tests idle");

    report "TB SUCCESS: all checks passed"
      severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
