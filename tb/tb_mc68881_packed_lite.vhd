library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_packed_lite is
end entity tb_mc68881_packed_lite;

-- Self-checking coverage for the lightweight packed-decimal engine
-- (mc68881_top packed_decimal_full_g = false, issue #70): FMOVE.P encode and
-- decode go through the deferred packed request path and the fixed-latency
-- packed_fast_proc capture.

architecture sim of tb_mc68881_packed_lite is
  subtype packed96_t is std_logic_vector(95 downto 0);
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

  constant CLK_PERIOD : time := 10 ns;
  constant ADDR_OPSEL : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPA_H : unsigned(4 downto 0) := to_unsigned(2, 5);
  constant ADDR_OPA_E : unsigned(4 downto 0) := to_unsigned(3, 5);
  constant ADDR_OPB_L : unsigned(4 downto 0) := to_unsigned(4, 5);
  constant ADDR_RES_L : unsigned(4 downto 0) := to_unsigned(7, 5);
  constant ADDR_RES_H : unsigned(4 downto 0) := to_unsigned(8, 5);
  constant ADDR_RES_E : unsigned(4 downto 0) := to_unsigned(9, 5);
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_FPCR : unsigned(4 downto 0) := to_unsigned(11, 5);
  constant ADDR_FPSR : unsigned(4 downto 0) := to_unsigned(14, 5);
  constant ADDR_CIR_RESPONSE : unsigned(4 downto 0) := to_unsigned(13, 5);
  constant ADDR_MOVE_CFG : unsigned(4 downto 0) := to_unsigned(23, 5);
  constant ADDR_FPIAR : unsigned(4 downto 0) := to_unsigned(24, 5);
  constant FPSR_AEXC_BASE : natural := 0;
  constant FPSR_EXC_BASE : natural := 8;
  -- MC68881 EXC byte bit positions:
  constant FPSR_EXC_INEX1  : natural := 0;
  constant FPSR_EXC_INEX2  : natural := 1;
  constant FPSR_EXC_DZ     : natural := 2;
  constant FPSR_EXC_UNFL   : natural := 3;
  constant FPSR_EXC_OVFL   : natural := 4;
  constant FPSR_EXC_OPERR  : natural := 5;
  constant FPSR_EXC_SNAN   : natural := 6;
  -- MC68881 AEXC byte bit positions:
  constant FPSR_AEXC_INEX  : natural := 0;
  constant FPSR_AEXC_DZ    : natural := 1;
  constant FPSR_AEXC_UNFL  : natural := 2;
  constant FPSR_AEXC_OVFL  : natural := 3;
  constant FPSR_AEXC_IOP   : natural := 4;

  constant OP_FMOVE : std_logic_vector(31 downto 0) := x"00000005";
  constant OP_FMOVEM : std_logic_vector(31 downto 0) := x"00000006";
  constant FMOVECR_PI : fp80_t := x"4000C90FDAA22168C235";
  constant FMOVE_SINGLE_SUBMIN_NEG : std_logic_vector(31 downto 0) := x"80000001";
  constant FMOVE_SINGLE_SUBMAX_POS : std_logic_vector(31 downto 0) := x"007FFFFF";
  constant FMOVE_SINGLE_QNAN : std_logic_vector(31 downto 0) := x"7FC12345";
  constant FMOVE_DOUBLE_SUBMIN_POS_LO : std_logic_vector(31 downto 0) := x"00000001";
  constant FMOVE_DOUBLE_SUBMIN_POS_HI : std_logic_vector(31 downto 0) := x"00000000";
  constant FMOVE_DOUBLE_SUBMAX_POS_LO : std_logic_vector(31 downto 0) := x"FFFFFFFF";
  constant FMOVE_DOUBLE_SUBMAX_POS_HI : std_logic_vector(31 downto 0) := x"000FFFFF";
  constant FMOVE_SINGLE_SUBMIN_NEG_FP80 : fp80_t := x"BF6A8000000000000000";
  constant FMOVE_SINGLE_SUBMAX_POS_FP80 : fp80_t := x"3F80FFFFFE0000000000";
  constant FMOVE_DOUBLE_SUBMIN_POS_FP80 : fp80_t := x"3BCD8000000000000000";
  constant FMOVE_DOUBLE_SUBMAX_POS_FP80 : fp80_t := x"3C00FFFFFFFFFFFFF000";
  constant FP80_SINGLE_HALF_ULP : fp80_t := x"3FFF8000008000000000";
  constant FP80_SINGLE_MIN_SUBNORMAL : fp80_t := x"3F6A8000000000000000";
  constant FP80_SINGLE_OVERFLOW : fp80_t := x"407F8000000000000000";
  constant FP80_DOUBLE_HALF_ULP : fp80_t := x"3FFF8000000000000400";
  constant FP80_DOUBLE_MIN_SUBNORMAL : fp80_t := x"3BCD8000000000000000";
  constant FP80_DOUBLE_OVERFLOW : fp80_t := x"43FF8000000000000000";
  constant FP80_SINGLE_OVERFLOW_NEG : fp80_t := x"C07F8000000000000000";
  constant FP80_SINGLE_HALF_ULP_NEG : fp80_t := x"BFFF8000008000000000";
  constant FPSR_CC_NAN : natural := 24;

  procedure split_fp80(
    constant value : fp80_t;
    variable sign  : out std_logic;
    variable exp   : out unsigned(FP_EXP_WIDTH-1 downto 0);
    variable mant  : out unsigned(FP_MANT_WIDTH-1 downto 0)
  ) is
  begin
    sign := value(FP_WIDTH-1);
    exp := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
  end procedure;

  procedure check_fp80(
    constant got : fp80_t;
    constant expected : fp80_t;
    constant test_name : string
  ) is
    variable got_sign : std_logic := '0';
    variable exp_sign : std_logic := '0';
    variable got_exp : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable exp_exp : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
  begin
    split_fp80(got, got_sign, got_exp, got_mant);
    split_fp80(expected, exp_sign, exp_exp, exp_mant);
    assert got_sign = exp_sign and got_exp = exp_exp and got_mant = exp_mant
      report "FP80 mismatch: " & test_name &
             " expected=" & to_hstring(expected) &
             " got=" & to_hstring(got)
      severity failure;
  end procedure;

  procedure bus_write(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    constant addr : unsigned(4 downto 0);
    constant data : std_logic_vector(31 downto 0)
  ) is
  begin
    a_in_s <= std_logic_vector(addr);
    d_in_s <= data;
    rw_s <= '0';
    cs_n_s <= '0';
    as_n_s <= '0';
    ds_n_s <= '0';
    wait for CLK_PERIOD;
    cs_n_s <= '1';
    as_n_s <= '1';
    ds_n_s <= '1';
    rw_s <= '1';
    wait for CLK_PERIOD;
  end procedure;

  procedure bus_read(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    variable data_s : out std_logic_vector(31 downto 0);
    constant addr : unsigned(4 downto 0)
  ) is
  begin
    a_in_s <= std_logic_vector(addr);
    rw_s <= '1';
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
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    variable status_s : out std_logic_vector(31 downto 0)
  ) is
  begin
    for poll_idx in 0 to 4095 loop
      bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, status_s, ADDR_STATUS);
      report "FMOVE status poll valid=" & std_logic'image(status_s(0)) &
             " busy=" & std_logic'image(status_s(1))
        severity note;
      exit when status_s(0) = '1';
    end loop;
    assert status_s(0) = '1'
      report "Timeout waiting for STATUS.valid in FMOVE testbench"
      severity error;
  end procedure;

  function make_move_cfg(
    mode : std_logic_vector(1 downto 0);
    src_idx : natural;
    dst_idx : natural;
    mem_fmt : std_logic_vector(1 downto 0);
    ctrl_to_reg : std_logic;
    ctrl_sel : std_logic_vector(1 downto 0);
    movem_mask : std_logic_vector(7 downto 0);
    movem_dir : std_logic;
    packed_k_from_opa : std_logic := '0';
    mem_to_reg_integer : std_logic := '0';
    reg_to_mem_packed : std_logic := '0';
    fmovecr_enable : std_logic := '0';
    movem_mask_from_dn : std_logic := '0';
    movem_predec_order : std_logic := '0'
  ) return std_logic_vector is
    variable cfg : move_cfg_t := move_cfg_default;
  begin
    cfg.src_idx := src_idx;
    cfg.mem_fmt := mem_fmt;
    cfg.mode := decode_move_cfg_mode(mode);
    cfg.ctrl_to_reg := ctrl_to_reg;
    cfg.dst_idx := dst_idx;
    cfg.ctrl_sel := ctrl_sel;
    cfg.movem_mask := movem_mask;
    cfg.movem_dir_to_reg := movem_dir;
    cfg.packed_k_from_opa := packed_k_from_opa;
    cfg.mem_to_reg_integer := mem_to_reg_integer;
    cfg.reg_to_mem_packed := reg_to_mem_packed;
    cfg.fmovecr_enable := fmovecr_enable;
    cfg.movem_mask_from_dn := movem_mask_from_dn;
    cfg.movem_predec_order := movem_predec_order;
    return encode_move_cfg(cfg);
  end function;

  function make_packed96(
    ex_word : std_logic_vector(31 downto 0);
    hi_word : std_logic_vector(31 downto 0);
    lo_word : std_logic_vector(31 downto 0)
  ) return packed96_t is
    variable packed : packed96_t := (others => '0');
  begin
    packed := ex_word(31 downto 16) & ex_word(15 downto 0) & hi_word & lo_word;
    return packed;
  end function;

begin
  clk <= not clk after CLK_PERIOD/2;

  dut : entity work.mc68881_top
    generic map (
      packed_decimal_full_g => false
    )
    port map (
      a_in => a_in,
      d_in => d_in,
      d_out => d_out,
      size_n => size_n,
      a0_in => a0_in,
      as_n => as_n,
      cs_n => cs_n,
      rw => rw,
      ds_n => ds_n,
      dsack0_n => dsack0_n,
      dsack1_n => dsack1_n,
      reset_n => reset_n,
      clk => clk,
      sense_n => sense_n
    );

  process
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
    variable rd_lo : std_logic_vector(31 downto 0) := (others => '0');
    variable rd_hi : std_logic_vector(31 downto 0) := (others => '0');
    variable rd_ex : std_logic_vector(31 downto 0) := (others => '0');
    variable rd_full : fp80_t := (others => '0');
    variable fp_val_a : fp80_t := (others => '0');
    variable cfg_word : std_logic_vector(31 downto 0) := (others => '0');
    variable got96 : packed96_t := (others => '0');

    -- FMOVE.X value -> FP<idx>, then FMOVE.P FP<idx> -> result, compare 96 bits.
    procedure check_encode(value : fp80_t; idx : natural; expected : packed96_t; name : string) is
    begin
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, value(31 downto 0));
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, value(63 downto 32));
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & value(79 downto 64));
      cfg_word := make_move_cfg("01", 0, idx, "00", '0', "00", (others => '0'), '0');
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
      wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
      cfg_word := make_move_cfg(
        "10", idx, 0, "00", '0', "00", (others => '0'), '0',
        packed_k_from_opa => '0',
        reg_to_mem_packed => '1'
      );
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
      wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
      got96 := make_packed96(rd_ex, rd_hi, rd_lo);
      report name & ": expected=" & to_hstring(expected) & " observed=" & to_hstring(got96)
        severity note;
      assert got96(95) = expected(95)
        report name & ": packed sign mismatch" severity failure;
      assert got96(94 downto 92) = expected(94 downto 92)
        report name & ": packed SE/YY mismatch" severity failure;
      assert got96(91 downto 76) = expected(91 downto 76)
        report name & ": packed exponent digits mismatch" severity failure;
      assert got96(67 downto 0) = expected(67 downto 0)
        report name & ": packed mantissa digits mismatch" severity failure;
    end procedure;

    -- FMOVE.P memory -> FP<idx>; compare the decoded FP80 result.
    procedure check_decode(word : packed96_t; idx : natural; expected : fp80_t; name : string) is
    begin
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, word(31 downto 0));
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, word(63 downto 32));
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, word(95 downto 64));
      cfg_word := make_move_cfg("01", 0, idx, "11", '0', "00", (others => '0'), '0');
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
      wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
      rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
      check_fp80(rd_full, expected, name);
    end procedure;
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    -- Peripheral (legacy register map) mode.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_CIR_RESPONSE, x"00000000");

    report "packed_decimal_full_g=false: lightweight FMOVE.P encode checks" severity note;
    -- 100.0 -> lead digit 1, exponent +002 (fast engine keeps MSD + exponent).
    check_encode(fp80_from_int(100), 1,
                 x"00020001" & x"00000000" & x"00000000", "FMOVE.P lite encode 100");
    -- -7.0 -> SM=1, lead digit 7, exponent 0.
    fp_val_a := fp80_from_int(7);
    fp_val_a(79) := '1';
    check_encode(fp_val_a, 2,
                 x"80000007" & x"00000000" & x"00000000", "FMOVE.P lite encode -7");
    -- 1234567 -> lead digit 1, exponent +006.
    check_encode(fp80_from_int(1234567), 3,
                 x"00060001" & x"00000000" & x"00000000", "FMOVE.P lite encode 1234567");
    -- +infinity -> YY=11, exponent digits FFF/F, zero mantissa.
    check_encode(x"7FFF8000000000000000", 4,
                 x"3FFFF000" & x"00000000" & x"00000000", "FMOVE.P lite encode +inf");
    -- +0.0 -> all-zero packed word.
    check_encode((others => '0'), 5,
                 (95 downto 0 => '0'), "FMOVE.P lite encode +0");

    report "packed_decimal_full_g=false: lightweight FMOVE.P decode checks" severity note;
    check_decode(x"00020001" & x"00000000" & x"00000000", 6,
                 fp80_from_int(100), "FMOVE.P lite decode 1E+2");
    fp_val_a := fp80_from_int(3);
    fp_val_a(79) := '1';
    check_decode(x"80000003" & x"00000000" & x"00000000", 7,
                 fp_val_a, "FMOVE.P lite decode -3E+0");
    check_decode(x"00050009" & x"00000000" & x"00000000", 0,
                 fp80_from_int(900000), "FMOVE.P lite decode 9E+5");

    report "packed_decimal_full_g=false: invalid BCD raises OPERR" severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000000A");
    cfg_word := make_move_cfg("01", 0, 3, "11", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FMOVE.P lite invalid BCD FPSR=" & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_OPERR) = '1'
      report "FMOVE.P lite invalid BCD should set EXC.OPERR, FPSR=" & to_hstring(rd_lo)
      severity failure;

    report "TB SUCCESS: packed_decimal_full_g=false FMOVE.P checks passed" severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
