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
  constant ADDR_CIR_RESPONSE : unsigned(4 downto 0) := to_unsigned(13, 5);
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
  constant FPSR_EXC_LSB     : natural := 8;
  constant FPSR_EXC_BSUN    : natural := 7;
  constant FPSR_EXC_BASE    : natural := 8;
  constant FPSR_ACCR_BASE   : natural := 0;
  -- MC68881 EXC byte bit positions (within byte):
  constant FPSR_EXC_INEX2   : natural := 1;
  constant FPSR_EXC_DZ      : natural := 2;
  constant FPSR_EXC_UNFL    : natural := 3;
  constant FPSR_EXC_OVFL    : natural := 4;
  constant FPSR_EXC_OPERR   : natural := 5;
  constant FPSR_EXC_SNAN    : natural := 6;
  -- MC68881 AEXC byte bit positions:
  constant FPSR_AEXC_INEX   : natural := 0;
  constant FPSR_AEXC_DZ     : natural := 1;
  constant FPSR_AEXC_UNFL   : natural := 2;
  constant FPSR_AEXC_OVFL   : natural := 3;
  constant FPSR_AEXC_IOP    : natural := 4;
  constant STATUS_CIR_RESPONSE_PENDING : natural := 4;
  constant STATUS_CIR_PROTOCOL_ERROR   : natural := 5;
  constant STATUS_CIR_TRAP_PENDING     : natural := 6;

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

  -- Sanity-check idle outputs before/after major stimulus sequences.
  -- SENSE is a presence-detect strap (grounded on-die on real MC6888x parts,
  -- pulled up by the host) and does not track busy/idle status, so it is
  -- checked here as a constant low rather than an idle-specific state.
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
    assert sense_n_s = '0'
      report "SENSE should be held low (presence detect) for " & test_name &
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

    -- Disable CIR mode so overlapping addresses route to peripheral decode.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              to_unsigned(13, 5), x"00000000");

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
    assert sense_n = '0'
      report "SENSE should be held low (presence detect) during ADD execution"
      severity failure;
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    assert sense_n = '0'
      report "SENSE should be held low (presence detect) after ADD completion"
      severity failure;
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
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000004");

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
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_DZ) = '1'
      report "FPSR DIV-by-zero flag not set"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_AEXC_DZ) = '1'
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
    assert rd_exp = (rd_exp'range => '1') and rd_mant /= 0
      report "DIV inf/inf should produce NaN (domain error)"
      severity failure;

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after DIV inf/inf: " & to_hstring(rd_lo)
      severity note;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_OPERR) = '1'
      report "FPSR OPERR flag not set for DIV inf/inf"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_AEXC_IOP) = '1'
      report "FPSR accrued IOP flag not set for DIV inf/inf"
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
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000004");

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
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_OPERR) = '1'
      report "FPSR OPERR flag not set for FSQRT negative"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_AEXC_IOP) = '1'
      report "FPSR accrued IOP flag not set for FSQRT negative"
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
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_OPERR) = '1'
      report "FPSR OPERR flag not set for FMOD divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_DZ) = '0'
      report "FPSR DZ should not be set for FMOD divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_AEXC_IOP) = '1'
      report "FPSR accrued IOP flag not set for FMOD divide-by-zero"
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
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_OPERR) = '1'
      report "FPSR OPERR flag not set for FREM divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_DZ) = '0'
      report "FPSR DZ should not be set for FREM divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_AEXC_IOP) = '1'
      report "FPSR accrued IOP flag not set for FREM divide-by-zero"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FPSR CC NAN flag not set for FREM divide-by-zero result"
      severity failure;

    -- B4: FABS/FNEG/FTST end-to-end behavior and FPSR CC updates.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(-5);
    op_b := FP80_ZERO;
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000018"); -- FABS
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
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0100001A"); -- FNEG
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
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0100003A"); -- FTST
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
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0100003A"); -- FTST
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
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0100003A"); -- FTST
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_CC_INF) = '1' and rd_lo(FPSR_CC_NAN) = '0'
      report "FTST +INF should set INF class bit"
      severity failure;

    -- FTST QNaN should set CC NAN but NOT raise SNAN or OPERR (NaN passthrough).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := x"7FFFC000000000000001";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0100003A"); -- FTST
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FTST QNaN should set CC NAN"
      severity failure;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_SNAN) = '0'
      report "FTST QNaN should NOT raise SNAN"
      severity failure;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_OPERR) = '0'
      report "FTST QNaN should NOT raise OPERR (NaN passthrough, not domain error)"
      severity failure;

    -- B5: FTWOTOX functional smoke test (finite and positive for x=1).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(1);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000011"); -- FTWOTOX
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    split_fp80(rd_full, rd_sign, rd_exp, rd_mant);
    assert rd_sign = '0' and not (rd_exp = (rd_exp'range => '1') and rd_mant /= 0)
      report "FTWOTOX 1 should return finite positive result"
      severity failure;

    -- B5 exception policy: FLOGN(0) should raise DZ, return -inf, set CC N+I, and capture FPIAR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    fpiar_seed := x"0BADF00D";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    op_a := FP80_ZERO;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000014"); -- FLOGN
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    assert rd_full = x"FFFF8000000000000000"
      report "FLOGN(0) should return -infinity, got=" & to_hstring(rd_full)
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_DZ) = '1'
      report "FLOGN(0) should raise DZ"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_AEXC_DZ) = '1'
      report "FLOGN(0) should accrue DZ"
      severity failure;
    assert rd_lo(FPSR_CC_NEG) = '1' and rd_lo(FPSR_CC_INF) = '1'
      report "FLOGN(0) should set CC N+I (negative infinity)"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    assert rd_hi = fpiar_seed
      report "FLOGN(0) exception should capture FPIAR"
      severity failure;

    -- P1 regression: DZ from transcendental/divrem units must not leak into
    -- unrelated operations that do not use those subunits.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(2);
    op_b := fp80_from_int(3);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000001"); -- FADD
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    check_fp80(rd_full, fp80_from_int(5), "FADD result after FLOGN(0)");
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_DZ) = '0'
      report "Stale DZ leaked into non-trig/non-divrem operation"
      severity failure;

    -- B5 exception policy: FASIN(|x|>1) invalid + NaN class.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(2);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), op_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(2, 5), op_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(3, 5), x"0000" & op_a(79 downto 64));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"0100000C"); -- FASIN
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, rd_hi, rd_ex, rd_full);
    split_fp80(rd_full, rd_sign, rd_exp, rd_mant);
    assert rd_exp = (rd_exp'range => '1') and rd_mant /= 0
      report "FASIN(|x|>1) should return NaN"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_OPERR) = '1'
      report "FASIN(|x|>1) should raise OPERR"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FASIN(|x|>1) should set CC NAN"
      severity failure;

    -- B6 slice: FScc uses FPSR condition code bits and writes byte result.
    report "FScc EQ test with Z=1." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    assert rd_lo(7 downto 0) = x"FF"
      report "FScc EQ should return 0xFF when Z=1"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '1' and rd_lo(4) = '0'
      report "FScc EQ should report cond_true=1 without BSUN"
      severity failure;

    -- Clear CIR response pending from previous FScc before issuing next conditional op.
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);

    report "FScc EQ test with N=1 and Z=0." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"08000000"); -- N set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    assert rd_lo(7 downto 0) = x"00"
      report "FScc EQ should return 0x00 when Z=0"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '0' and rd_lo(4) = '0'
      report "FScc EQ should report cond_true=0 without BSUN"
      severity failure;

    -- Clear CIR response pending from previous FScc.
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);

    report "FScc UN test with NAN=1." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000008"); -- condition: UN
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    assert rd_lo(7 downto 0) = x"FF"
      report "FScc UN should return 0xFF when NAN=1"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '1' and rd_lo(4) = '0'
      report "FScc UN should report cond_true=1 without BSUN"
      severity failure;

    -- Conditional-dialog trap-gating tests start from a masked FPCR state.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000000");

    -- B6 slice: FBcc dialog response reports branch decision.
    report "FBcc EQ test with Z=1 (branch taken)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000043"); -- FBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '1' and rd_lo(1) = '1'
      report "FBcc EQ should report cond_true=1 and branch_taken=1 when Z=1"
      severity failure;

    report "FBcc EQ test with Z=0 (branch not taken)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"08000000"); -- N set, Z clear
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000043"); -- FBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '0' and rd_lo(1) = '0'
      report "FBcc EQ should report cond_true=0 and branch_taken=0 when Z=0"
      severity failure;

    -- B6 slice: FDBcc dialog response reports decrement/branch behavior and
    -- returns the updated loop counter in CIR_RESPONSE[31:16].
    report "FDBcc EQ test with Z=1 (no decrement)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), x"00000003"); -- Dn.w counter
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000044"); -- FDBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '1' and rd_lo(1) = '0' and rd_lo(2) = '0' and rd_lo(3) = '0'
      report "FDBcc cond_true path should skip decrement/branch"
      severity failure;
    assert rd_lo(31 downto 16) = x"0003"
      report "FDBcc cond_true path should preserve loop counter"
      severity failure;

    report "FDBcc EQ test with Z=0 and counter=3 (decrement and branch)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"08000000"); -- N set, Z clear
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), x"00000003"); -- Dn.w counter
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000044"); -- FDBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '0' and rd_lo(1) = '1' and rd_lo(2) = '1' and rd_lo(3) = '0'
      report "FDBcc cond_false path should decrement and branch when counter != -1"
      severity failure;
    assert rd_lo(31 downto 16) = x"0002"
      report "FDBcc cond_false path should decrement counter to 0x0002"
      severity failure;

    report "FDBcc EQ test with Z=0 and counter=0 (terminal count, no branch)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"08000000"); -- N set, Z clear
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), x"00000000"); -- Dn.w counter
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000044"); -- FDBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '0' and rd_lo(1) = '0' and rd_lo(2) = '1' and rd_lo(3) = '1'
      report "FDBcc terminal path should decrement but suppress branch at counter=-1"
      severity failure;
    assert rd_lo(31 downto 16) = x"FFFF"
      report "FDBcc terminal path should return 0xFFFF counter"
      severity failure;

    -- S7-B3 slice: response ordering. A second conditional command before
    -- response consumption should be blocked and flagged as protocol violation.
    report "Conditional dialog ordering: block issue before CIR_RESPONSE read." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000043"); -- FBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '1'
      report "Conditional response should be marked pending until CIR_RESPONSE is read"
      severity failure;

    -- Attempt a second conditional command without consuming the response.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_PROTOCOL_ERROR) = '1'
      report "Second conditional command before response read should set protocol error"
      severity failure;
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '1'
      report "Blocked conditional command must not consume existing response"
      severity failure;

    -- Read response to clear pending/protocol bits.
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '0' and
           status_word(STATUS_CIR_PROTOCOL_ERROR) = '0'
      report "CIR response read should clear pending/protocol status bits"
      severity failure;

    -- B6 signaling-condition BSUN path: unordered NAN + signaling condition
    -- must produce a null response and raise BSUN in EXC/AEXC with FPIAR capture.
    report "FScc SEQ with NAN=1 should raise BSUN and return null." severity note;
    fpiar_seed := x"0000B6A1";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000011"); -- condition: SEQ (signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '1' and
           status_word(STATUS_CIR_TRAP_PENDING) = '0'
      report "Masked BSUN should set response pending but not trap pending"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    assert rd_lo(7 downto 0) = x"00"
      report "FScc signaling unordered path should return null (0x00)"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(5) = '0' and rd_lo(4) = '1' and rd_lo(0) = '0'
      report "FScc signaling unordered path should set CIR null/BSUN flag"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_BSUN) = '1'
      report "FScc signaling unordered path should set EXC.BSUN"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    assert rd_hi = fpiar_seed
      report "FScc signaling unordered exception should capture FPIAR"
      severity failure;

    report "FBcc ST with NAN=1 should raise BSUN and suppress branch." severity note;
    fpiar_seed := x"0000B6A2";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"0000001F"); -- condition: ST (signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000043"); -- FBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '1' and
           status_word(STATUS_CIR_TRAP_PENDING) = '0'
      report "Masked BSUN FBcc should not set trap pending"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(5) = '0' and rd_lo(4) = '1' and rd_lo(1) = '0'
      report "FBcc signaling unordered path should set null/BSUN and suppress branch"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_BSUN) = '1'
      report "FBcc signaling unordered path should set EXC.BSUN"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    assert rd_hi = fpiar_seed
      report "FBcc signaling unordered exception should capture FPIAR"
      severity failure;

    report "FDBcc ST with NAN=1 should raise BSUN and skip decrement/branch." severity note;
    fpiar_seed := x"0000B6A3";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"0000001F"); -- condition: ST (signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(4, 5), x"00000003"); -- Dn.w counter
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000044"); -- FDBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '1' and
           status_word(STATUS_CIR_TRAP_PENDING) = '0'
      report "Masked BSUN FDBcc should not set trap pending"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(5) = '0' and rd_lo(4) = '1' and rd_lo(1) = '0' and rd_lo(2) = '0'
      report "FDBcc signaling unordered path should set null/BSUN and skip decrement/branch"
      severity failure;
    assert rd_lo(31 downto 16) = x"0003"
      report "FDBcc signaling unordered path should preserve loop counter"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_BSUN) = '1'
      report "FDBcc signaling unordered path should set EXC.BSUN"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    assert rd_hi = fpiar_seed
      report "FDBcc signaling unordered exception should capture FPIAR"
      severity failure;

    -- Trap gating: enabling FPCR.BSUN should request a trap on signaling
    -- unordered conditions and mark trap-pending until response consumption.
    report "FBcc ST with NAN=1 and FPCR.BSUN enabled should request trap." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00008000"); -- enable BSUN trap
    fpiar_seed := x"0000B6A4";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"0000001F"); -- condition: ST (signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000043"); -- FBcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '1' and
           status_word(STATUS_CIR_TRAP_PENDING) = '1'
      report "Enabled BSUN should set response pending and trap pending status bits"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(5) = '1' and rd_lo(4) = '1'
      report "Enabled BSUN should set CIR trap-request and null/BSUN flags"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '0' and
           status_word(STATUS_CIR_TRAP_PENDING) = '0'
      report "Reading CIR response should clear trap-pending/status bits"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    assert rd_hi = fpiar_seed
      report "Enabled BSUN path should capture FPIAR"
      severity failure;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000000");

    -- Negative test: non-signaling condition + NAN must NOT set FPSR.EXC.BSUN.
    -- UN (0x08) is non-signaling; with NAN=1 cond_true=1 but BSUN must stay clear.
    report "FScc UN with NAN=1 should NOT set EXC.BSUN (non-signaling guard)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000008"); -- condition: UN (non-signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '1' and rd_lo(4) = '0'
      report "FScc UN+NAN should report cond_true=1 without BSUN"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_BSUN) = '0'
      report "Non-signaling condition must not set EXC.BSUN even when NAN=1"
      severity failure;

    -- Negative test: signaling condition + ordered CC must NOT produce BSUN.
    -- SEQ (0x11) is signaling, but with NAN=0 the cc_field(0) guard blocks BSUN.
    report "FScc SEQ with NAN=0 should NOT raise BSUN (ordered CC guard)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set, NAN clear
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000011"); -- condition: SEQ (signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '1' and rd_lo(4) = '0'
      report "FScc SEQ+ordered should report cond_true=1 without BSUN"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_BSUN) = '0'
      report "Signaling condition with ordered CC must not set EXC.BSUN"
      severity failure;

    -- EXC byte clear-then-set: conditional op should clear stale EXC flags.
    -- Pre-set EXC.INVALID via FPSR write, then issue a non-exceptional FScc.
    report "Conditional op should clear stale EXC byte from prior ops." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04004000"); -- Z set + EXC.SNAN
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_SNAN) = '0'
      report "Non-exceptional conditional op should clear stale EXC.SNAN"
      severity failure;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_BSUN) = '0'
      report "Non-exceptional conditional op should not set EXC.BSUN"
      severity failure;

    -- FScc trap gating: enabling FPCR.BSUN with FScc SEQ + NAN should request
    -- trap, set CIR_RESPONSE(5)=1, and result byte should remain 0x00.
    report "FScc SEQ with NAN=1 and FPCR.BSUN enabled should request trap." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00008000"); -- enable BSUN trap
    fpiar_seed := x"0000B6A5";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, fpiar_seed);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000011"); -- condition: SEQ (signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000042"); -- FScc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word, ADDR_STATUS);
    assert status_word(STATUS_CIR_RESPONSE_PENDING) = '1' and
           status_word(STATUS_CIR_TRAP_PENDING) = '1'
      report "FScc enabled BSUN should set response pending and trap pending"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(7, 5));
    assert rd_lo(7 downto 0) = x"00"
      report "FScc with enabled BSUN trap should still return 0x00 result byte"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(5) = '1' and rd_lo(4) = '1' and rd_lo(0) = '0'
      report "FScc enabled BSUN should set CIR trap-request/BSUN flags with cond_true=0"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPIAR);
    assert rd_hi = fpiar_seed
      report "FScc enabled BSUN should capture FPIAR"
      severity failure;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000000");

    -- Clear CIR response pending from previous FScc.
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);

    -- B7 slice: FSAVE round-trip via opcode dispatch.
    report "FSAVE round-trip: write known FPCR/FPSR, issue FSAVE, check frame format + words." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000030"); -- RN, double
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"DEADBEEF");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000046"); -- FSAVE
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, to_unsigned(18, 5)); -- FRAME_W0
    report "FSAVE FRAME_W0 (format)=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"00000018"
      report "FSAVE FRAME_W0 should be idle format $18"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, to_unsigned(19, 5)); -- FRAME_W1
    report "FSAVE FRAME_W1 (FPCR)=" & to_hstring(rd_hi) severity note;
    assert rd_hi = x"00000030"
      report "FSAVE FRAME_W1 should match written FPCR"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, to_unsigned(20, 5)); -- FRAME_W2
    report "FSAVE FRAME_W2 (FPSR)=" & to_hstring(rd_ex) severity note;
    assert rd_ex = x"DEADBEEF"
      report "FSAVE FRAME_W2 should match written FPSR"
      severity failure;

    -- B7 slice: FRESTORE idle-frame round-trip via opcode dispatch.
    report "FRESTORE idle-frame round-trip: write frame words, issue FRESTORE, check FPCR/FPSR." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(18, 5), x"00000018"); -- FRAME_W0 = idle format
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(19, 5), x"0000007F"); -- FRAME_W1 = new FPCR
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(20, 5), x"12345678"); -- FRAME_W2 = new FPSR
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000047"); -- FRESTORE
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPCR);
    report "FRESTORE FPCR=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"0000007F"
      report "FRESTORE should restore FPCR from FRAME_W1"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPSR);
    report "FRESTORE FPSR=" & to_hstring(rd_hi) severity note;
    assert rd_hi = x"12345678"
      report "FRESTORE should restore FPSR from FRAME_W2"
      severity failure;

    -- B7 slice: FRESTORE null-frame resets FPU.
    report "FRESTORE null-frame: write null format, issue FRESTORE, verify FPCR/FPSR zeroed." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(18, 5), x"00000000"); -- FRAME_W0 = null format
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000047"); -- FRESTORE
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPCR);
    report "FRESTORE null FPCR=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"00000000"
      report "FRESTORE null-frame should zero FPCR"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPSR);
    report "FRESTORE null FPSR=" & to_hstring(rd_hi) severity note;
    assert rd_hi = x"00000000"
      report "FRESTORE null-frame should zero FPSR"
      severity failure;

    -- B7 slice: FTRAPcc condition true (EQ with Z=1).
    report "FTRAPcc EQ with Z=1 (condition true, trap requested)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"04000000"); -- Z set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000000"); -- clear FPCR
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000045"); -- FTRAPcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '1'
      report "FTRAPcc EQ with Z=1 should report cond_true=1"
      severity failure;
    assert rd_lo(5) = '1'
      report "FTRAPcc EQ with Z=1 should report trap_requested=1"
      severity failure;
    assert rd_lo(4) = '0'
      report "FTRAPcc EQ with Z=1 should not report BSUN"
      severity failure;

    -- B7 slice: FTRAPcc condition false (EQ with Z=0).
    report "FTRAPcc EQ with Z=0 (condition false, no trap)." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000"); -- all CC clear
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000001"); -- condition: EQ
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000045"); -- FTRAPcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(0) = '0'
      report "FTRAPcc EQ with Z=0 should report cond_true=0"
      severity failure;
    assert rd_lo(5) = '0'
      report "FTRAPcc EQ with Z=0 should report trap_requested=0"
      severity failure;

    -- B7 slice: FTRAPcc BSUN (signaling condition SEQ + NAN=1 + FPCR.BSUN enabled).
    report "FTRAPcc SEQ with NAN=1 and FPCR.BSUN enabled should request trap." severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"01000000"); -- NAN set
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00008000"); -- enable BSUN
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(1, 5), x"00000011"); -- condition: SEQ (signaling)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"01000045"); -- FTRAPcc
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_CIR_RESPONSE);
    assert rd_lo(4) = '1'
      report "FTRAPcc SEQ+NAN should report bsun_event=1"
      severity failure;
    assert rd_lo(5) = '1'
      report "FTRAPcc SEQ+NAN+BSUN_EN should report trap_requested=1"
      severity failure;
    assert rd_lo(0) = '0'
      report "FTRAPcc SEQ+NAN should report cond_true=0 (BSUN overrides)"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPSR);
    assert rd_hi(FPSR_EXC_LSB + FPSR_EXC_BSUN) = '1'
      report "FTRAPcc BSUN path should set EXC.BSUN"
      severity failure;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000000");

    -- =========================================================
    -- DSACK behavior coverage: single-shot encoding + multi-beat
    -- =========================================================
    report "DSACK single-shot encoding tests" severity note;

    -- Single-shot: 32-bit A4=1 → dsack0='0', dsack1='0'
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

    -- Single-shot: 32-bit A4=0 → dsack0='1', dsack1='0'
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

    -- =========================================================
    -- Multi-beat DSACK transfer tests (uses FPIAR: addr 24, A4=1)
    -- =========================================================
    report "Multi-beat DSACK transfer tests" severity note;

    -- Seed FPIAR with known value for read-back tests
    size_n <= "11";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, x"DEADBEEF");

    -- Test 1: 32-bit read — 1 beat
    -- FPIAR A4=1, size_n="11" → dsack0='0', dsack1='0' (32-bit port)
    report "DSACK multi-beat test 1: 32-bit read, 1 beat" severity note;
    size_n <= "11";
    a_in   <= std_logic_vector(ADDR_FPIAR);
    rw     <= '1';
    cs_n   <= '0';
    as_n   <= '0';
    ds_n   <= '0';
    wait until (dsack0_n = '0') or (dsack1_n = '0');
    assert dsack0_n = '0' and dsack1_n = '0'
      report "DSACK mismatch for 32-bit read (A4=1): dsack0_n=" &
             std_logic'image(dsack0_n) & " dsack1_n=" & std_logic'image(dsack1_n)
      severity failure;
    assert d_out = x"DEADBEEF"
      report "Data mismatch on 32-bit read: expected DEADBEEF got " & to_hstring(d_out)
      severity failure;
    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;

    -- Test 2: 16-bit read — 2 consecutive beats
    -- size_n="10" → dsack0='1', dsack1='0' (16-bit port)
    -- Confirms state machine returns to IDLE and re-responds on each beat.
    report "DSACK multi-beat test 2: 16-bit read, 2 beats" severity note;
    for beat in 0 to 1 loop
      size_n <= "10";
      a_in   <= std_logic_vector(ADDR_FPIAR);
      rw     <= '1';
      cs_n   <= '0';
      as_n   <= '0';
      ds_n   <= '0';
      wait until (dsack0_n = '0') or (dsack1_n = '0');
      assert dsack0_n = '1' and dsack1_n = '0'
        report "DSACK mismatch for 16-bit read beat " & integer'image(beat) &
               ": dsack0_n=" & std_logic'image(dsack0_n) &
               " dsack1_n=" & std_logic'image(dsack1_n)
        severity failure;
      assert d_out = x"DEADBEEF"
        report "Data mismatch on 16-bit read beat " & integer'image(beat) &
               ": expected DEADBEEF got " & to_hstring(d_out)
        severity failure;
      cs_n <= '1';
      as_n <= '1';
      ds_n <= '1';
      wait for CLK_PERIOD;
    end loop;

    -- Test 3: 8-bit read — 4 consecutive beats
    -- size_n="01" → dsack0='0', dsack1='1' (8-bit port)
    -- Confirms 4 independent DSACK handshakes complete without stalling.
    report "DSACK multi-beat test 3: 8-bit read, 4 beats" severity note;
    for beat in 0 to 3 loop
      size_n <= "01";
      a_in   <= std_logic_vector(ADDR_FPIAR);
      rw     <= '1';
      cs_n   <= '0';
      as_n   <= '0';
      ds_n   <= '0';
      wait until (dsack0_n = '0') or (dsack1_n = '0');
      assert dsack0_n = '0' and dsack1_n = '1'
        report "DSACK mismatch for 8-bit read beat " & integer'image(beat) &
               ": dsack0_n=" & std_logic'image(dsack0_n) &
               " dsack1_n=" & std_logic'image(dsack1_n)
        severity failure;
      assert d_out = x"DEADBEEF"
        report "Data mismatch on 8-bit read beat " & integer'image(beat) &
               ": expected DEADBEEF got " & to_hstring(d_out)
        severity failure;
      cs_n <= '1';
      as_n <= '1';
      ds_n <= '1';
      wait for CLK_PERIOD;
    end loop;

    -- Test 4: 16-bit write — 2 beats + 32-bit readback
    -- FPU captures full 32-bit d_in each cycle; last write wins.
    report "DSACK multi-beat test 4: 16-bit write, 2 beats + readback" severity note;
    for beat in 0 to 1 loop
      size_n <= "10";
      a_in   <= std_logic_vector(ADDR_FPIAR);
      d_in   <= x"CAFEBABE";
      rw     <= '0';
      cs_n   <= '0';
      as_n   <= '0';
      ds_n   <= '0';
      wait until (dsack0_n = '0') or (dsack1_n = '0');
      assert dsack0_n = '1' and dsack1_n = '0'
        report "DSACK mismatch for 16-bit write beat " & integer'image(beat) &
               ": dsack0_n=" & std_logic'image(dsack0_n) &
               " dsack1_n=" & std_logic'image(dsack1_n)
        severity failure;
      cs_n <= '1';
      as_n <= '1';
      ds_n <= '1';
      rw   <= '1';
      wait for CLK_PERIOD;
    end loop;
    size_n <= "11";
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPIAR);
    assert rd_lo = x"CAFEBABE"
      report "Readback mismatch after 16-bit writes: expected CAFEBABE got " & to_hstring(rd_lo)
      severity failure;

    -- Test 5: 8-bit write — 4 beats + 32-bit readback
    report "DSACK multi-beat test 5: 8-bit write, 4 beats + readback" severity note;
    for beat in 0 to 3 loop
      size_n <= "01";
      a_in   <= std_logic_vector(ADDR_FPIAR);
      d_in   <= x"12345678";
      rw     <= '0';
      cs_n   <= '0';
      as_n   <= '0';
      ds_n   <= '0';
      wait until (dsack0_n = '0') or (dsack1_n = '0');
      assert dsack0_n = '0' and dsack1_n = '1'
        report "DSACK mismatch for 8-bit write beat " & integer'image(beat) &
               ": dsack0_n=" & std_logic'image(dsack0_n) &
               " dsack1_n=" & std_logic'image(dsack1_n)
        severity failure;
      cs_n <= '1';
      as_n <= '1';
      ds_n <= '1';
      rw   <= '1';
      wait for CLK_PERIOD;
    end loop;
    size_n <= "11";
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPIAR);
    assert rd_lo = x"12345678"
      report "Readback mismatch after 8-bit writes: expected 12345678 got " & to_hstring(rd_lo)
      severity failure;

    -- Test 6: Wait-state (size_n="00") — no DSACK
    report "DSACK multi-beat test 6: wait-state, no DSACK" severity note;
    size_n <= "00";
    cs_n   <= '0';
    as_n   <= '0';
    ds_n   <= '0';
    wait for CLK_PERIOD;
    assert dsack0_n = '1' and dsack1_n = '1'
      report "DSACK mismatch for wait state insertion: dsack0_n=" &
             std_logic'image(dsack0_n) & " dsack1_n=" & std_logic'image(dsack1_n)
      severity failure;
    cs_n <= '1';
    as_n <= '1';
    ds_n <= '1';
    wait for CLK_PERIOD;

    -- Restore default size and verify idle
    size_n <= "11";
    assert_idle_outputs(dsack0_n, dsack1_n, sense_n, "post-DSACK multi-beat tests idle");

    -- ===== DEF-DIVREM-002: SNaN vs QNaN FPSR INVALID discrimination =====
    -- Use FCMP which has invalid_on_nan_inputs=true, invalid_on_nan_result=false.
    -- This isolates the SNaN vs QNaN check from the result-is-NaN path.

    -- FCMP with QNaN: should NOT raise INVALID (QNaN propagates silently)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := x"7FFF8000000000000123";  -- QNaN, payload=0x123
    op_b := fp80_from_int(1);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000007"); -- FCMP
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FCMP QNaN,1: " & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FCMP QNaN should set CC NAN"
      severity failure;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_SNAN) = '0'
      report "FCMP QNaN should NOT raise SNAN (only SNaN does)"
      severity failure;

    -- FCMP with SNaN: SHOULD raise INVALID
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := x"7FFF0000000000000456";  -- SNaN, payload=0x456
    op_b := fp80_from_int(1);
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000007"); -- FCMP
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FCMP SNaN,1: " & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FCMP SNaN should set CC NAN"
      severity failure;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_SNAN) = '1'
      report "FCMP SNaN should raise SNAN"
      severity failure;
    assert rd_lo(FPSR_ACCR_BASE + FPSR_AEXC_IOP) = '1'
      report "FCMP SNaN should accrue IOP"
      severity failure;

    -- FCMP with SNaN in source (b operand): also raises INVALID
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    op_a := fp80_from_int(1);
    op_b := x"7FFF0000000000000789";  -- SNaN, payload=0x789
    write_binary_operands(a_in, d_in, rw, cs_n, as_n, ds_n, op_a, op_b);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, to_unsigned(0, 5), x"00000007"); -- FCMP
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR after FCMP 1,SNaN: " & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_SNAN) = '1'
      report "FCMP with SNaN in source should raise SNAN"
      severity failure;

    report "TB SUCCESS: all checks passed"
      severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;

