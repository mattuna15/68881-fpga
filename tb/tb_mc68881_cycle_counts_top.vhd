library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_cycle_counts_top is
end entity tb_mc68881_cycle_counts_top;

architecture sim of tb_mc68881_cycle_counts_top is
  signal a_in     : std_logic_vector(4 downto 0) := (others => '0');
  signal d_in     : std_logic_vector(31 downto 0) := (others => '0');
  signal d_out    : std_logic_vector(31 downto 0);
  signal size_n   : std_logic := '1';
  signal a0_in    : std_logic := '1';
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

  constant CLK_PERIOD : time := 10 ns;
  constant ADDR_OPSEL  : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L  : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPA_H  : unsigned(4 downto 0) := to_unsigned(2, 5);
  constant ADDR_OPA_E  : unsigned(4 downto 0) := to_unsigned(3, 5);
  constant ADDR_OPB_L  : unsigned(4 downto 0) := to_unsigned(4, 5);
  constant ADDR_OPB_H  : unsigned(4 downto 0) := to_unsigned(5, 5);
  constant ADDR_OPB_E  : unsigned(4 downto 0) := to_unsigned(6, 5);
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_CIR_RESPONSE : unsigned(4 downto 0) := to_unsigned(13, 5);
  constant ADDR_CYCLE_CFG0 : unsigned(4 downto 0) := to_unsigned(15, 5);
  constant ADDR_CYCLE_CFG1 : unsigned(4 downto 0) := to_unsigned(16, 5);
  constant ADDR_CYCLE_TOTAL: unsigned(4 downto 0) := to_unsigned(22, 5);

  function op_sel_bits(op_sel : fpu_op_t) return std_logic_vector is
  begin
    case op_sel is
      when FPU_OP_ADD => return "0001";
      when FPU_OP_SUB => return "0010";
      when FPU_OP_MUL => return "0011";
      when FPU_OP_DIV => return "0100";
      when FPU_OP_MOVE => return "0101";
      when FPU_OP_MOVEM => return "0110";
      when FPU_OP_CMP => return "0111";
      when FPU_OP_MOD => return "1000";
      when FPU_OP_REM => return "1001";
      when FPU_OP_SCALE => return "1010";
      when FPU_OP_SGLDIV => return "1011";
      when FPU_OP_SGLMUL => return "1100";
      when others     => return "0000";
    end case;
  end function;

  procedure bus_write_simple(
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

  procedure bus_write_opstart(
    signal a_in_s  : out std_logic_vector(4 downto 0);
    signal d_in_s  : out std_logic_vector(31 downto 0);
    signal rw_s    : out std_logic;
    signal cs_n_s  : out std_logic;
    signal as_n_s  : out std_logic;
    signal ds_n_s  : out std_logic;
    constant addr  : unsigned(4 downto 0);
    constant data  : std_logic_vector(31 downto 0);
    variable start_cycle : out natural
  ) is
  begin
    a_in_s <= std_logic_vector(addr);
    d_in_s <= data;
    rw_s   <= '0';
    cs_n_s <= '0';
    as_n_s <= '0';
    ds_n_s <= '0';
    wait until rising_edge(clk);
    wait for 0 ns;
    start_cycle := cycle_cnt;
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
    constant addr    : unsigned(4 downto 0);
    variable data_s  : out std_logic_vector(31 downto 0)
  ) is
  begin
    a_in_s <= std_logic_vector(addr);
    rw_s   <= '1';
    cs_n_s <= '0';
    as_n_s <= '0';
    ds_n_s <= '0';
    wait until (dsack0_n_s = '0') or (dsack1_n_s = '0');
    wait for CLK_PERIOD/4;
    data_s := d_out_s;
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
    variable status_word_s : out std_logic_vector(31 downto 0)
  ) is
  begin
    for poll_idx in 0 to 4095 loop
      bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, ADDR_STATUS, status_word_s);
      report "STATUS poll: valid=" & std_logic'image(status_word_s(0)) &
             " busy=" & std_logic'image(status_word_s(1)) &
             " cycle=" & integer'image(cycle_cnt)
        severity note;
      exit when status_word_s(0) = '1';
      wait for CLK_PERIOD;
    end loop;
    assert status_word_s(0) = '1'
      report "Timeout waiting for STATUS.valid in cycle-count testbench"
      severity error;
  end procedure;

  procedure write_operands(
    signal a_in_s  : out std_logic_vector(4 downto 0);
    signal d_in_s  : out std_logic_vector(31 downto 0);
    signal rw_s    : out std_logic;
    signal cs_n_s  : out std_logic;
    signal as_n_s  : out std_logic;
    signal ds_n_s  : out std_logic;
    constant op_a : fp80_t;
    constant op_b : fp80_t
  ) is
  begin
    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_OPA_L, op_a(31 downto 0));
    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_OPA_H, op_a(63 downto 32));
    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_OPA_E, x"0000" & op_a(79 downto 64));
    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_OPB_L, op_b(31 downto 0));
    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_OPB_H, op_b(63 downto 32));
    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_OPB_E, x"0000" & op_b(79 downto 64));
  end procedure;

  procedure run_case(
    signal a_in_s  : out std_logic_vector(4 downto 0);
    signal d_in_s  : out std_logic_vector(31 downto 0);
    signal rw_s    : out std_logic;
    signal cs_n_s  : out std_logic;
    signal as_n_s  : out std_logic;
    signal ds_n_s  : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s    : in std_logic_vector(31 downto 0);
    constant op_sel : fpu_op_t;
    constant src_kind : fpu_src_kind_t;
    constant ea_mode : ea_mode_t;
    constant cycle_case : ea_cycle_case_t;
    constant mc68020_src : boolean;
    constant mc68020_dst : boolean;
    constant packed_dynamic_k : boolean;
    constant label_text : string
  ) is
    variable expected : natural := 0;
    variable start_cycle : natural := 0;
    variable end_cycle : natural := 0;
    variable measured : natural := 0;
    variable total_reg : std_logic_vector(31 downto 0) := (others => '0');
    variable cfg0 : std_logic_vector(31 downto 0) := (others => '0');
    variable cfg1 : std_logic_vector(31 downto 0) := (others => '0');
    variable op_a : fp80_t := (others => '0');
    variable op_b : fp80_t := (others => '0');
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    expected := op_cycle_count(
      op_sel,
      src_kind,
      ea_mode,
      cycle_case,
      mc68020_src,
      mc68020_dst,
      packed_dynamic_k
    );
    report "Cycle count case " & label_text &
           " expected=" & integer'image(expected)
      severity note;

    cfg0 := (others => '0');
    cfg1 := (others => '0');
    cfg0(2 downto 0) := std_logic_vector(to_unsigned(fpu_src_kind_t'pos(src_kind), 3));
    cfg0(7 downto 3) := std_logic_vector(to_unsigned(ea_mode_t'pos(ea_mode), 5));
    cfg1(1 downto 0) := std_logic_vector(to_unsigned(ea_cycle_case_t'pos(cycle_case), 2));
    if mc68020_src then
      cfg1(2) := '1';
    end if;
    if mc68020_dst then
      cfg1(3) := '1';
    end if;
    if packed_dynamic_k then
      cfg1(4) := '1';
    end if;

    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_CYCLE_CFG0, cfg0);
    bus_write_simple(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, ADDR_CYCLE_CFG1, cfg1);

    op_a := fp80_from_int(12);
    op_b := fp80_from_int(3);
    write_operands(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, op_a, op_b);

    bus_write_opstart(
      a_in_s,
      d_in_s,
      rw_s,
      cs_n_s,
      as_n_s,
      ds_n_s,
      ADDR_OPSEL,
      (31 downto 4 => '0') & op_sel_bits(op_sel),
      start_cycle
    );
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, status_word);
    end_cycle := cycle_cnt;
    measured := end_cycle - start_cycle;

    report "Cycle count measured " & label_text &
           " start=" & integer'image(start_cycle) &
           " end=" & integer'image(end_cycle) &
           " got=" & integer'image(measured)
      severity note;
    assert end_cycle >= start_cycle + expected
      report "Cycle count early completion for " & label_text severity error;
    assert end_cycle <= start_cycle + expected + 4
      report "Cycle count late completion for " & label_text severity error;

    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, ADDR_CYCLE_TOTAL, total_reg);
    report "Cycle total register " & label_text &
           " got=" & integer'image(to_integer(unsigned(total_reg)))
      severity note;
    assert to_integer(unsigned(total_reg)) = expected
      report "Cycle total register mismatch for " & label_text severity error;
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
      a0_in    => a0_in,
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

    -- Disable CIR mode so overlapping addresses route to peripheral decode
    bus_write_simple(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_CIR_RESPONSE, x"00000000");

    run_case(
      a_in,
      d_in,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      d_out,
      FPU_OP_ADD,
      FPU_SRC_MEM_SINGLE,
      EA_MODE_ABS_L,
      EA_CYCLE_BEST,
      true,
      true,
      false,
      "FADD mem single + EA best (xxx).L MC68020 src/dst"
    );

    run_case(
      a_in,
      d_in,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      d_out,
      FPU_OP_SUB,
      FPU_SRC_MEM_DOUBLE,
      EA_MODE_AN_POSTINC,
      EA_CYCLE_CACHE,
      false,
      false,
      false,
      "FSUB mem double + EA cache (An)+"
    );

    run_case(
      a_in,
      d_in,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      d_out,
      FPU_OP_MUL,
      FPU_SRC_MEM_EXTENDED,
      EA_MODE_D16_AN_PC,
      EA_CYCLE_WORST,
      false,
      false,
      false,
      "FMUL mem extended + EA worst (d16,An/PC)"
    );

    run_case(
      a_in,
      d_in,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      d_out,
      FPU_OP_DIV,
      FPU_SRC_MEM_PACKED,
      EA_MODE_D32_B,
      EA_CYCLE_WORST,
      false,
      false,
      true,
      "FDIV mem packed + EA worst (d32,B) dynamic K"
    );

    run_case(
      a_in,
      d_in,
      rw,
      cs_n,
      as_n,
      ds_n,
      dsack0_n,
      dsack1_n,
      d_out,
      FPU_OP_MOD,
      FPU_SRC_MEM_PACKED,
      EA_MODE_ABS_L,
      EA_CYCLE_WORST,
      false,
      false,
      true,
      "FMOD mem packed (.P) + EA worst (xxx).L dynamic K"
    );

    report "TB SUCCESS: cycle count integration checks complete."
      severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
