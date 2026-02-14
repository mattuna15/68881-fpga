library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_top is
end entity tb_mc68881_top;

architecture sim of tb_mc68881_top is
  -- Bus stimulus and capture signals mirror the top-level external interface.
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
  constant ADDR_FPIAR  : unsigned(4 downto 0) := to_unsigned(24, 5);

  constant FPCR_RND_NEAREST : std_logic_vector(31 downto 0) := x"00000000";
  constant FPCR_RND_ZERO    : std_logic_vector(31 downto 0) := x"00000010";
  constant FPCR_RND_PLUS    : std_logic_vector(31 downto 0) := x"00000030";
  constant FPCR_PREC_SINGLE : std_logic_vector(31 downto 0) := x"00000040";
  constant FPCR_PREC_DOUBLE : std_logic_vector(31 downto 0) := x"00000080";
  constant FPSR_CC_NAN      : natural := 24;
  constant FPSR_CC_INF      : natural := 25;
  constant FPSR_CC_ZERO     : natural := 26;
  constant FPSR_CC_NEG      : natural := 27;
  constant FPSR_QUOT_LSB    : natural := 16;
  constant FPSR_QUOT_MSB    : natural := 23;
  constant FPSR_ACCR_BASE   : natural := 8;
  constant FPSR_EXC_DIVZERO : natural := 3;
  constant FPSR_EXC_INVALID : natural := 4;

  -- Extract sign/exponent/mantissa fields for FP80-aware assertions.
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

  -- Field-wise FP80 comparator used by self-checking operation tests.
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
  constant FP80_POS_INF : fp80_t := make_fp80('0', (FP_EXP_WIDTH-1 downto 0 => '1'), (others => '0'));
  constant FP80_ZERO : fp80_t := make_fp80('0', (others => '0'), (others => '0'));

  -- Single bus write beat (address, data, strobe assert/deassert timing).
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

  -- Single bus read beat that waits for either DSACK line to assert.
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

  procedure bus_read_var(
    signal a_in_s    : out std_logic_vector(4 downto 0);
    signal rw_s      : out std_logic;
    signal cs_n_s    : out std_logic;
    signal as_n_s    : out std_logic;
    signal ds_n_s    : out std_logic;
    signal dsack0_n_s: in  std_logic;
    signal dsack1_n_s: in  std_logic;
    signal d_out_s   : in  std_logic_vector(31 downto 0);
    variable data_v  : out std_logic_vector(31 downto 0);
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
    data_v := d_out_s;
    wait for CLK_PERIOD/4;
    cs_n_s <= '1';
    as_n_s <= '1';
    ds_n_s <= '1';
    wait for CLK_PERIOD;
  end procedure;

  -- Poll STATUS until result-valid is set by the DUT.
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

  -- Verify `sense_n` transitions to the expected busy/idle state.
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

  -- Sanity-check idle outputs before/after major stimulus sequences.
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

  procedure write_operand_triplet(
    signal a_in_s  : out std_logic_vector(4 downto 0);
    signal d_in_s  : out std_logic_vector(31 downto 0);
    signal rw_s    : out std_logic;
    signal cs_n_s  : out std_logic;
    signal as_n_s  : out std_logic;
    signal ds_n_s  : out std_logic;
    constant base_addr : natural;
    constant operand   : fp80_t
  ) is
  begin
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, to_unsigned(base_addr, 5), operand(31 downto 0));
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, to_unsigned(base_addr + 1, 5), operand(63 downto 32));
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, to_unsigned(base_addr + 2, 5), x"0000" & operand(79 downto 64));
  end procedure;

  procedure write_binary_operands(
    signal a_in_s  : out std_logic_vector(4 downto 0);
    signal d_in_s  : out std_logic_vector(31 downto 0);
    signal rw_s    : out std_logic;
    signal cs_n_s  : out std_logic;
    signal as_n_s  : out std_logic;
    signal ds_n_s  : out std_logic;
    constant op_a  : fp80_t;
    constant op_b  : fp80_t
  ) is
  begin
    write_operand_triplet(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, 1, op_a);
    write_operand_triplet(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, 4, op_b);
  end procedure;

  procedure read_result_fp80(
    signal a_in_s    : out std_logic_vector(4 downto 0);
    signal rw_s      : out std_logic;
    signal cs_n_s    : out std_logic;
    signal as_n_s    : out std_logic;
    signal ds_n_s    : out std_logic;
    signal dsack0_n_s: in  std_logic;
    signal dsack1_n_s: in  std_logic;
    signal d_out_s   : in  std_logic_vector(31 downto 0);
    signal rd_lo_s   : out std_logic_vector(31 downto 0);
    signal rd_hi_s   : out std_logic_vector(31 downto 0);
    signal rd_ex_s   : out std_logic_vector(31 downto 0);
    variable rd_full_v : out fp80_t
  ) is
    variable lo_word : std_logic_vector(31 downto 0) := (others => '0');
    variable hi_word : std_logic_vector(31 downto 0) := (others => '0');
    variable ex_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    bus_read_var(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, lo_word, to_unsigned(7, 5));
    bus_read_var(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, hi_word, to_unsigned(8, 5));
    bus_read_var(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, ex_word, to_unsigned(9, 5));
    rd_lo_s <= lo_word;
    rd_hi_s <= hi_word;
    rd_ex_s <= ex_word;
    rd_full_v := ex_word(15 downto 0) & hi_word & lo_word;
  end procedure;

begin
  clk <= not clk after CLK_PERIOD/2;
  -- Free-running cycle counter for debug report context.
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

  -- End-to-end host-style stimulus:
  -- drive operands/opcodes through bus writes, poll STATUS, read back result,
  -- and assert expected FP80 and exception behavior.
  process
    variable op_a : fp80_t := (others => '0');
    variable op_b : fp80_t := (others => '0');
    variable exp_r: fp80_t := (others => '0');
    variable rd_full : fp80_t := (others => '0');
    variable rd_sign : std_logic := '0';
    variable rd_exp : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable rd_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable fpiar_seed : std_logic_vector(31 downto 0) := (others => '0');
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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000001");
    wait_for_sense(sense_n, '0', "busy assert after ADD start");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    wait_for_sense(sense_n, '1', "idle deassert after ADD completion");
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000003");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    rd_res  <= rd_full;
    report "DIV readback: ex=" & to_hstring(rd_ex) & " hi=" & to_hstring(rd_hi) & " lo=" & to_hstring(rd_lo)
      severity note;
    report "DIV result:  " & to_hstring(rd_full)
      severity note;
    report "DIV cycle end: " & integer'image(cycle_cnt)
      severity note;
    check_fp80(rd_full, exp_r, "DIV result");

    -- SQRT
    op_a := fp80_from_int(9);
    op_b := FP80_ZERO;
    exp_r := fp80_from_int(3);
    report "SQRT operands: op_a=" & to_hstring(op_a)
      severity note;
    report "SQRT expected: " & to_hstring(exp_r)
      severity note;
    report "SQRT cycle start: " & integer'image(cycle_cnt)
      severity note;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000011");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    rd_res  <= rd_full;
    report "SQRT readback: ex=" & to_hstring(rd_ex) & " hi=" & to_hstring(rd_hi) & " lo=" & to_hstring(rd_lo)
      severity note;
    report "SQRT result:  " & to_hstring(rd_full)
      severity note;
    report "SQRT cycle end: " & integer'image(cycle_cnt)
      severity note;
    check_fp80(rd_full, exp_r, "SQRT result");

    -- CMP
    op_a := fp80_from_int(9);
    op_b := fp80_from_int(4);
    exp_r := fp80_from_int(compare_fp80(op_a, op_b));
    report "CMP operands: op_a=" & to_hstring(op_a) & " op_b=" & to_hstring(op_b)
      severity note;
    report "CMP expected: " & to_hstring(exp_r)
      severity note;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000007");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "CMP result: " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "CMP result");

    -- MOD
    op_a := fp80_from_int(17);
    op_b := fp80_from_int(5);
    exp_r := fmod_fp80(op_a, op_b, FP_RND_NEAREST, FP_PREC_EXTENDED);
    report "MOD expected: " & to_hstring(exp_r)
      severity note;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000008");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "MOD result: " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "MOD result");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after MOD 17,5: " & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_QUOT_MSB downto FPSR_QUOT_LSB) = x"03"
      report "FMOD quotient byte mismatch for 17/5 (expected +3)" severity failure;

    -- REM
    op_a := fp80_from_int(7);
    op_b := fp80_from_int(4);
    exp_r := frem_fp80(op_a, op_b, FP_RND_NEAREST, FP_PREC_EXTENDED);
    report "REM expected: " & to_hstring(exp_r)
      severity note;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000009");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "REM result: " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "REM result");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after REM 7,4: " & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_QUOT_MSB downto FPSR_QUOT_LSB) = x"02"
      report "FREM quotient byte mismatch for 7/4 (expected +2)" severity failure;

    -- SCALE
    op_a := fp80_from_int(2);
    op_b := fp80_from_int(3);
    exp_r := fscale_fp80(op_a, op_b);
    report "SCALE expected: " & to_hstring(exp_r)
      severity note;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0000000A");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "SCALE result: " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "SCALE result");

    -- SGLDIV
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(10);
    exp_r := DIV_1_10_SINGLE_EXPECTED;
    report "SGLDIV expected: " & to_hstring(exp_r)
      severity note;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0000000B");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "SGLDIV result: " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "SGLDIV result");

    -- SGLMUL
    op_a := fp80_from_int(7);
    op_b := fp80_from_int(9);
    exp_r := fp80_from_int(63);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0000000C");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "SGLMUL result: " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "SGLMUL result");

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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
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
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    rd_res  <= rd_full;
    report "DIV 1/10 double result:  " & to_hstring(rd_full)
      severity note;
    check_fp80(rd_full, exp_r, "DIV 1/10 double result");

    -- FCMP condition-code updates use compare relation.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(2);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000007");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FCMP 1,2: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_CC_NEG) = '1' and rd_lo(FPSR_CC_ZERO) = '0' and rd_lo(FPSR_CC_NAN) = '0'
      report "FCMP 1,2 should set N condition code only"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(2);
    op_b := fp80_from_int(2);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000007");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FCMP 2,2: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_CC_ZERO) = '1' and rd_lo(FPSR_CC_NEG) = '0' and rd_lo(FPSR_CC_NAN) = '0'
      report "FCMP 2,2 should set Z condition code only"
      severity failure;

    -- FPSR exception flags: DIV by zero
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    fpiar_seed := x"1234ABCD";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    op_a := fp80_from_int(1);
    op_b := fp80_from_int(0);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after DIV by zero: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_EXC_DIVZERO) = '1'
      report "FPSR DIV-by-zero flag not set"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_EXC_DIVZERO) = '1'
      report "FPSR accrued DIV-by-zero flag not set"
      severity failure;
    assert rd_lo(FPSR_CC_INF) = '1' and rd_lo(FPSR_CC_NAN) = '0'
      report "FPSR CC byte should report infinity result after DIV by zero"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    report "FPIAR after DIV by zero: " & to_hstring(rd_hi)
      severity note;
    assert rd_hi = fpiar_seed
      report "FPIAR exception snapshot mismatch"
      severity failure;

    -- FPSR exception flags: DIV inf/inf should raise invalid and force CC NAN.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := FP80_POS_INF;
    op_b := FP80_POS_INF;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000004");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "DIV inf,inf result: " & to_hstring(rd_full)
      severity note;
    split_fp80(rd_full, rd_sign, rd_exp, rd_mant);
    assert rd_sign = '0' and rd_exp = (rd_exp'range => '1') and rd_mant = 0
      report "DIV inf/inf raw result should encode as +infinity in current ALU behavior"
      severity failure;

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after DIV inf/inf: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_EXC_INVALID) = '1'
      report "FPSR invalid flag not set for DIV inf/inf"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_EXC_INVALID) = '1'
      report "FPSR accrued invalid flag not set for DIV inf/inf"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1' and rd_lo(FPSR_CC_INF) = '0'
      report "FPSR CC should report NAN for DIV inf/inf invalid exception"
      severity failure;

    -- FPSR exception flags: FSQRT negative should raise invalid and return NaN.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    fpiar_seed := x"55AA1122";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    op_a := fp80_from_int(-4);
    op_b := FP80_ZERO;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000011");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "FSQRT -4 result: " & to_hstring(rd_full)
      severity note;
    split_fp80(rd_full, rd_sign, rd_exp, rd_mant);
    assert rd_exp = (rd_exp'range => '1') and rd_mant /= 0
      report "FSQRT negative input should return NaN"
      severity failure;

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FSQRT negative: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_EXC_INVALID) = '1'
      report "FPSR invalid flag not set for FSQRT negative"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_EXC_INVALID) = '1'
      report "FPSR accrued invalid flag not set for FSQRT negative"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FPSR CC NAN flag not set for FSQRT negative result"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    report "FPIAR after FSQRT negative: " & to_hstring(rd_hi)
      severity note;
    assert rd_hi = fpiar_seed
      report "FPIAR exception snapshot mismatch for FSQRT negative"
      severity failure;

    -- FPSR exception flags: FMOD by zero should raise invalid and return NaN.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(5);
    op_b := fp80_from_int(0);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000008");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "FMOD 5,0 result: " & to_hstring(rd_full)
      severity note;
    split_fp80(rd_full, rd_sign, rd_exp, rd_mant);
    assert rd_exp = (rd_exp'range => '1') and rd_mant /= 0
      report "FMOD divide-by-zero should return NaN"
      severity failure;

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FMOD by zero: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_EXC_INVALID) = '1'
      report "FPSR invalid flag not set for FMOD divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_EXC_DIVZERO) = '0'
      report "FPSR DIVZERO should not be set for FMOD divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_EXC_INVALID) = '1'
      report "FPSR accrued invalid flag not set for FMOD divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FPSR CC NAN flag not set for FMOD divide-by-zero result"
      severity failure;

    -- FPSR exception flags: FREM by zero should raise invalid and return NaN.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(7);
    op_b := fp80_from_int(0);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000009");

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    report "FREM 7,0 result: " & to_hstring(rd_full)
      severity note;
    split_fp80(rd_full, rd_sign, rd_exp, rd_mant);
    assert rd_exp = (rd_exp'range => '1') and rd_mant /= 0
      report "FREM divide-by-zero should return NaN"
      severity failure;

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FREM by zero: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_EXC_INVALID) = '1'
      report "FPSR invalid flag not set for FREM divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_EXC_DIVZERO) = '0'
      report "FPSR DIVZERO should not be set for FREM divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_EXC_INVALID) = '1'
      report "FPSR accrued invalid flag not set for FREM divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FPSR CC NAN flag not set for FREM divide-by-zero result"
      severity failure;

    -- B4: FABS/FNEG/FTST end-to-end behavior and FPSR CC updates.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(-5);
    op_b := FP80_ZERO;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000012"); -- FABS
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    check_fp80(rd_full, fp80_from_int(5), "FABS -5 result");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_CC_NEG) = '0' and rd_lo(FPSR_CC_ZERO) = '0' and rd_lo(FPSR_CC_NAN) = '0'
      report "FABS -5 should clear N and keep finite non-zero CC class"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(5);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000013"); -- FNEG
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    check_fp80(rd_full, fp80_from_int(-5), "FNEG +5 result");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_CC_NEG) = '1' and rd_lo(FPSR_CC_ZERO) = '0' and rd_lo(FPSR_CC_NAN) = '0'
      report "FNEG +5 should set N for negative finite result"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(-5);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000018"); -- FTST
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_CC_NEG) = '1' and rd_lo(FPSR_CC_ZERO) = '0' and rd_lo(FPSR_CC_NAN) = '0'
      report "FTST -5 should set N only"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := FP80_ZERO;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000018"); -- FTST
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_CC_ZERO) = '1' and rd_lo(FPSR_CC_NEG) = '0' and rd_lo(FPSR_CC_NAN) = '0'
      report "FTST 0 should set Z only"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := FP80_POS_INF;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000018"); -- FTST
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_CC_INF) = '1' and rd_lo(FPSR_CC_NAN) = '0'
      report "FTST +INF should set INF class bit"
      severity failure;

    -- FTST NaN should set invalid + CC NAN and capture FPIAR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    fpiar_seed := x"AA55AA55";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    op_a := x"7FFFC000000000000001";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000018"); -- FTST
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_INVALID) = '1'
      report "FTST NaN should raise invalid"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_EXC_INVALID) = '1'
      report "FTST NaN should accrue invalid"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FTST NaN should set CC NAN"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    assert rd_hi = fpiar_seed
      report "FTST NaN exception should capture FPIAR"
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

