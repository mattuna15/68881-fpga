library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_fmove_fmovem is
end entity tb_mc68881_fmove_fmovem;

architecture sim of tb_mc68881_fmove_fmovem is
  subtype packed96_t is std_logic_vector(95 downto 0);
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
  constant ADDR_MOVE_CFG : unsigned(4 downto 0) := to_unsigned(23, 5);
  constant ADDR_FPIAR : unsigned(4 downto 0) := to_unsigned(24, 5);
  constant FPSR_AEXC_BASE : natural := 0;
  constant FPSR_EXC_BASE : natural := 8;
  constant FPSR_EXC_INVALID : natural := 4;
  constant FPSR_EXC_OVERFLOW : natural := 2;
  constant FPSR_EXC_UNDERFLOW : natural := 1;
  constant FPSR_EXC_INEXACT : natural := 0;

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
    loop
      bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, dsack0_n_s, dsack1_n_s, d_out_s, status_s, ADDR_STATUS);
      report "FMOVE status poll valid=" & std_logic'image(status_s(0)) &
             " busy=" & std_logic'image(status_s(1))
        severity note;
      exit when status_s(0) = '1';
    end loop;
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
    port map (
      a_in => a_in,
      d_in => d_in,
      d_out => d_out,
      size_n => size_n,
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
    variable fp_val_b : fp80_t := (others => '0');
    variable cfg_word : std_logic_vector(31 downto 0) := (others => '0');
    variable fpcr_word : std_logic_vector(31 downto 0) := (others => '0');
    variable fpiar_word : std_logic_vector(31 downto 0) := (others => '0');
    variable static_packed : fp80_t := (others => '0');
    variable dynamic_packed : fp80_t := (others => '0');
    variable static_packed96 : packed96_t := (others => '0');
    variable dynamic_packed96 : packed96_t := (others => '0');
    variable packed_src96 : packed96_t := (others => '0');
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    fp_val_a := fp80_from_int(42);
    report "FMOVE mem->reg setup value=" & to_hstring(fp_val_a) severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, fp_val_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, fp_val_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & fp_val_a(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 1, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE mem->reg observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp_val_a, "FMOVE mem->reg");

    cfg_word := make_move_cfg("00", 1, 2, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    cfg_word := make_move_cfg("10", 2, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE reg->reg->mem observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp_val_a, "FMOVE reg->reg");

    cfg_word := make_move_cfg("10", 2, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE reg->mem(single) word=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"42280000"
      report "FMOVE single conversion mismatch expected=42280000 got=" & to_hstring(rd_lo)
      severity failure;

    report "FMOVE single/double rounding and range conversion checks" severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_SINGLE_HALF_ULP(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_SINGLE_HALF_ULP(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_SINGLE_HALF_ULP(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000000");
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single tie-nearest observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"3F800000"
      report "FMOVE single tie-nearest should round to even (1.0)"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000030");
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single tie-plus-inf observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"3F800001"
      report "FMOVE single tie-plus-inf should round upward"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_SINGLE_MIN_SUBNORMAL(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_SINGLE_MIN_SUBNORMAL(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_SINGLE_MIN_SUBNORMAL(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000010");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, (others => '0'));
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single min-subnormal observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"00000001"
      report "FMOVE single gradual underflow should keep min subnormal"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPSR);
    report "FMOVE single min-subnormal FPSR=" & to_hstring(rd_hi) severity note;
    assert rd_hi(FPSR_EXC_BASE + FPSR_EXC_UNDERFLOW) = '1'
      report "FMOVE single gradual underflow should set FPSR EXC underflow"
      severity failure;
    assert rd_hi(FPSR_AEXC_BASE + FPSR_EXC_UNDERFLOW) = '1'
      report "FMOVE single gradual underflow should set FPSR AEXC underflow"
      severity failure;
    assert rd_hi(FPSR_EXC_BASE + FPSR_EXC_INEXACT) = '1'
      report "FMOVE single gradual underflow should set FPSR EXC inexact"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_SINGLE_OVERFLOW(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_SINGLE_OVERFLOW(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_SINGLE_OVERFLOW(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000010");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, (others => '0'));
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single overflow RZ observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"7F7FFFFF"
      report "FMOVE single overflow in RZ should saturate to max finite"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPSR);
    report "FMOVE single overflow RZ FPSR=" & to_hstring(rd_hi) severity note;
    assert rd_hi(FPSR_EXC_BASE + FPSR_EXC_OVERFLOW) = '1'
      report "FMOVE single overflow in RZ should set FPSR EXC overflow"
      severity failure;
    assert rd_hi(FPSR_AEXC_BASE + FPSR_EXC_OVERFLOW) = '1'
      report "FMOVE single overflow in RZ should set FPSR AEXC overflow"
      severity failure;
    assert rd_hi(FPSR_EXC_BASE + FPSR_EXC_INEXACT) = '1'
      report "FMOVE single overflow in RZ should set FPSR EXC inexact"
      severity failure;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000030");
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single overflow RP observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"7F800000"
      report "FMOVE single overflow in RP should produce +infinity"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_DOUBLE_HALF_ULP(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_DOUBLE_HALF_ULP(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_DOUBLE_HALF_ULP(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000000");
    cfg_word := make_move_cfg("10", 7, 0, "10", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    report "FMOVE double tie-nearest observed hi=" & to_hstring(rd_hi) &
           " lo=" & to_hstring(rd_lo) severity note;
    assert rd_hi = x"3FF00000" and rd_lo = x"00000000"
      report "FMOVE double tie-nearest should round to even (1.0)"
      severity failure;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000030");
    cfg_word := make_move_cfg("10", 7, 0, "10", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    report "FMOVE double tie-plus-inf observed hi=" & to_hstring(rd_hi) &
           " lo=" & to_hstring(rd_lo) severity note;
    assert rd_hi = x"3FF00000" and rd_lo = x"00000001"
      report "FMOVE double tie-plus-inf should round upward"
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_DOUBLE_MIN_SUBNORMAL(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_DOUBLE_MIN_SUBNORMAL(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_DOUBLE_MIN_SUBNORMAL(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000010");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, (others => '0'));
    cfg_word := make_move_cfg("10", 7, 0, "10", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    report "FMOVE double min-subnormal observed hi=" & to_hstring(rd_hi) &
           " lo=" & to_hstring(rd_lo) severity note;
    assert rd_hi = x"00000000" and rd_lo = x"00000001"
      report "FMOVE double gradual underflow should keep min subnormal"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_FPSR);
    report "FMOVE double min-subnormal FPSR=" & to_hstring(rd_ex) severity note;
    assert rd_ex(FPSR_EXC_BASE + FPSR_EXC_UNDERFLOW) = '1'
      report "FMOVE double gradual underflow should set FPSR EXC underflow"
      severity failure;
    assert rd_ex(FPSR_AEXC_BASE + FPSR_EXC_UNDERFLOW) = '1'
      report "FMOVE double gradual underflow should set FPSR AEXC underflow"
      severity failure;
    assert rd_ex(FPSR_EXC_BASE + FPSR_EXC_INEXACT) = '1'
      report "FMOVE double gradual underflow should set FPSR EXC inexact"
      severity failure;

    report "FMOVE double overflow checks" severity note;
    -- Load double-overflow source (2^1024, above double max ~1.8e308)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_DOUBLE_OVERFLOW(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_DOUBLE_OVERFLOW(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_DOUBLE_OVERFLOW(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    -- Double overflow RZ: should saturate to max finite (7FEFFFFF_FFFFFFFF)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000010");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, (others => '0'));
    cfg_word := make_move_cfg("10", 7, 0, "10", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    report "FMOVE double overflow RZ observed hi=" & to_hstring(rd_hi) &
           " lo=" & to_hstring(rd_lo) severity note;
    assert rd_hi = x"7FEFFFFF" and rd_lo = x"FFFFFFFF"
      report "FMOVE double overflow in RZ should saturate to max finite"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_FPSR);
    report "FMOVE double overflow RZ FPSR=" & to_hstring(rd_ex) severity note;
    assert rd_ex(FPSR_EXC_BASE + FPSR_EXC_OVERFLOW) = '1'
      report "FMOVE double overflow in RZ should set FPSR EXC overflow"
      severity failure;
    assert rd_ex(FPSR_EXC_BASE + FPSR_EXC_INEXACT) = '1'
      report "FMOVE double overflow in RZ should set FPSR EXC inexact"
      severity failure;
    -- Double overflow RP: should produce +infinity (7FF00000_00000000)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000030");
    cfg_word := make_move_cfg("10", 7, 0, "10", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    report "FMOVE double overflow RP observed hi=" & to_hstring(rd_hi) &
           " lo=" & to_hstring(rd_lo) severity note;
    assert rd_hi = x"7FF00000" and rd_lo = x"00000000"
      report "FMOVE double overflow in RP should produce +infinity"
      severity failure;

    report "FMOVE negative overflow and RM rounding checks" severity note;
    -- Load negative single overflow source
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_SINGLE_OVERFLOW_NEG(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_SINGLE_OVERFLOW_NEG(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_SINGLE_OVERFLOW_NEG(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    -- Negative overflow RP: negative rounds toward +inf = truncate = -max-finite (FF7FFFFF)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000030");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, (others => '0'));
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single neg overflow RP observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"FF7FFFFF"
      report "FMOVE single neg overflow in RP should saturate to -max-finite"
      severity failure;
    -- Negative overflow RM: negative rounds toward -inf = away from zero = -inf (FF800000)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000020");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, (others => '0'));
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single neg overflow RM observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"FF800000"
      report "FMOVE single neg overflow in RM should produce -infinity"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_FPSR);
    report "FMOVE single neg overflow RM FPSR=" & to_hstring(rd_hi) severity note;
    assert rd_hi(FPSR_EXC_BASE + FPSR_EXC_OVERFLOW) = '1'
      report "FMOVE single neg overflow in RM should set FPSR EXC overflow"
      severity failure;

    -- RM rounding: negative half-ULP tie should round away from zero
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FP80_SINGLE_HALF_ULP_NEG(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FP80_SINGLE_HALF_ULP_NEG(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & FP80_SINGLE_HALF_ULP_NEG(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 7, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, x"00000020");
    cfg_word := make_move_cfg("10", 7, 0, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE single neg tie RM observed=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"BF800001"
      report "FMOVE single neg tie in RM should round away from zero (-1.0 - 1ULP)"
      severity failure;

    report "FMOVE subnormal single/double source checks" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FMOVE_SINGLE_SUBMIN_NEG);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"00000000");
    cfg_word := make_move_cfg("01", 0, 4, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE mem(single submin neg)->reg observed=" & to_hstring(rd_full) &
           " expected=" & to_hstring(FMOVE_SINGLE_SUBMIN_NEG_FP80)
      severity note;
    check_fp80(rd_full, FMOVE_SINGLE_SUBMIN_NEG_FP80, "FMOVE mem(single submin neg)->reg");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FMOVE_SINGLE_SUBMAX_POS);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"00000000");
    cfg_word := make_move_cfg("01", 0, 4, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE mem(single submax pos)->reg observed=" & to_hstring(rd_full) &
           " expected=" & to_hstring(FMOVE_SINGLE_SUBMAX_POS_FP80)
      severity note;
    check_fp80(rd_full, FMOVE_SINGLE_SUBMAX_POS_FP80, "FMOVE mem(single submax pos)->reg");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FMOVE_DOUBLE_SUBMIN_POS_LO);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FMOVE_DOUBLE_SUBMIN_POS_HI);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"00000000");
    cfg_word := make_move_cfg("01", 0, 4, "10", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE mem(double submin pos)->reg observed=" & to_hstring(rd_full) &
           " expected=" & to_hstring(FMOVE_DOUBLE_SUBMIN_POS_FP80)
      severity note;
    check_fp80(rd_full, FMOVE_DOUBLE_SUBMIN_POS_FP80, "FMOVE mem(double submin pos)->reg");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FMOVE_DOUBLE_SUBMAX_POS_LO);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, FMOVE_DOUBLE_SUBMAX_POS_HI);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"00000000");
    cfg_word := make_move_cfg("01", 0, 4, "10", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE mem(double submax pos)->reg observed=" & to_hstring(rd_full) &
           " expected=" & to_hstring(FMOVE_DOUBLE_SUBMAX_POS_FP80)
      severity note;
    check_fp80(rd_full, FMOVE_DOUBLE_SUBMAX_POS_FP80, "FMOVE mem(double submax pos)->reg");

    fpcr_word := x"12345678";
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPCR, fpcr_word);
    cfg_word := make_move_cfg("11", 0, 3, "00", '1', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    cfg_word := make_move_cfg("10", 3, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    report "FMOVE control->reg->mem observed low=" & to_hstring(rd_lo) severity note;
    assert rd_lo = x"00005678"
      report "FMOVE control->reg mismatch expected=00005678 got=" & to_hstring(rd_lo)
      severity failure;

    cfg_word := make_move_cfg("11", 3, 0, "00", '0', "10", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, fpiar_word, ADDR_FPIAR);
    report "FMOVE reg->control FPIAR=" & to_hstring(fpiar_word) severity note;
    assert fpiar_word = x"00005678"
      report "FMOVE reg->control mismatch expected=00005678 got=" & to_hstring(fpiar_word)
      severity failure;

    fp_val_b := fp80_from_int(7);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, fp_val_b(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, fp_val_b(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & fp_val_b(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 4, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    cfg_word := make_move_cfg("00", 0, 0, "00", '0', "00", "00010000", '0', movem_predec_order => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVEM);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, (others => '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, (others => '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, (others => '0'));
    cfg_word := make_move_cfg("01", 0, 4, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    cfg_word := make_move_cfg("00", 0, 0, "00", '0', "00", "00010000", '1', movem_predec_order => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVEM);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    cfg_word := make_move_cfg("10", 4, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVEM restore observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp_val_b, "FMOVEM restore");

    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FPSR read during FMOVE/FMOVEM test=" & to_hstring(rd_lo) severity note;

    report "FMOVE integer-source B/W/L checks" severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"000000FE");
    cfg_word := make_move_cfg("01", 0, 0, "00", '0', "00", (others => '0'), '0', mem_to_reg_integer => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.B source observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(-2), "FMOVE.B source");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000080");
    cfg_word := make_move_cfg("01", 0, 0, "00", '0', "00", (others => '0'), '0', mem_to_reg_integer => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.B min source observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(-128), "FMOVE.B min source");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"0000FF9C");
    cfg_word := make_move_cfg("01", 0, 1, "01", '0', "00", (others => '0'), '0', mem_to_reg_integer => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.W source observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(-100), "FMOVE.W source");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00008000");
    cfg_word := make_move_cfg("01", 0, 1, "01", '0', "00", (others => '0'), '0', mem_to_reg_integer => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.W min source observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(-32768), "FMOVE.W min source");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00003039");
    cfg_word := make_move_cfg("01", 0, 2, "10", '0', "00", (others => '0'), '0', mem_to_reg_integer => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.L source observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(12345), "FMOVE.L source");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"80000001");
    cfg_word := make_move_cfg("01", 0, 2, "10", '0', "00", (others => '0'), '0', mem_to_reg_integer => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.L min source observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(-2147483647), "FMOVE.L min source");

    report "FMOVE conversion exception path check (single qNaN mem->reg)" severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPSR, (others => '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_FPIAR, x"CAFEBABE");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, FMOVE_SINGLE_QNAN);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, x"00000000");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"00000000");
    cfg_word := make_move_cfg("01", 0, 7, "01", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_FPSR);
    report "FMOVE qNaN FPSR=" & to_hstring(rd_lo) severity note;
    assert rd_lo(FPSR_EXC_BASE + FPSR_EXC_INVALID) = '1'
      report "FMOVE qNaN should set FPSR EXC invalid"
      severity failure;
    assert rd_lo(FPSR_AEXC_BASE + FPSR_EXC_INVALID) = '1'
      report "FMOVE qNaN should set FPSR AEXC invalid"
      severity failure;
    assert rd_lo(FPSR_CC_NAN) = '1'
      report "FMOVE qNaN should set FPSR CC NAN bit"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, fpiar_word, ADDR_FPIAR);
    report "FMOVE qNaN FPIAR=" & to_hstring(fpiar_word) severity note;
    assert fpiar_word = x"CAFEBABE"
      report "FMOVE qNaN should capture FPIAR snapshot"
      severity failure;

    report "FMOVE .P static/dynamic k-factor checks" severity note;
    fp_val_a := fp80_from_int(1234567);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, fp_val_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, fp_val_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & fp_val_a(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 5, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPB_L, x"00000002");
    cfg_word := make_move_cfg(
      "10", 5, 0, "00", '0', "00", (others => '0'), '0',
      packed_k_from_opa => '0',
      reg_to_mem_packed => '1'
    );
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    static_packed96 := make_packed96(rd_ex, rd_hi, rd_lo);
    static_packed := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.P static k observed=" & to_hstring(static_packed) severity note;
    assert static_packed96(93 downto 92) = "00"
      report "FMOVE.P static packed result should be finite (yy=00)"
      severity failure;
    assert static_packed96(67 downto 64) = x"1" and
           static_packed96(63 downto 60) = x"2" and
           static_packed96(59 downto 56) = x"0"
      report "FMOVE.P static k should round 1234567 to leading digits 1.20..."
      severity failure;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"0000000A");
    cfg_word := make_move_cfg(
      "10", 5, 0, "00", '0', "00", (others => '0'), '0',
      packed_k_from_opa => '1',
      reg_to_mem_packed => '1'
    );
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    dynamic_packed96 := make_packed96(rd_ex, rd_hi, rd_lo);
    dynamic_packed := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.P dynamic k observed=" & to_hstring(dynamic_packed) severity note;
    assert static_packed /= dynamic_packed
      report "FMOVE.P static and dynamic k-factor should produce distinct packed output"
      severity failure;

    report "FMOVE.P mem->reg packed decode check" severity note;
    packed_src96 := static_packed96;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, packed_src96(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, packed_src96(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, packed_src96(95 downto 80) & packed_src96(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 3, "11", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVE.P mem->reg observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(1200000), "FMOVE.P mem->reg decode");

    report "FMOVECR constant ROM checks" severity note;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"0000000F");
    cfg_word := make_move_cfg("00", 0, 6, "00", '0', "00", (others => '0'), '0', fmovecr_enable => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    cfg_word := make_move_cfg("10", 6, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVECR #0F observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, (others => '0'), "FMOVECR #0F");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000000");
    cfg_word := make_move_cfg("00", 0, 6, "00", '0', "00", (others => '0'), '0', fmovecr_enable => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    cfg_word := make_move_cfg("10", 6, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVECR #00 observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, FMOVECR_PI, "FMOVECR #00");

    report "FMOVEM Dn bitmask and -(An) bit-order checks" severity note;
    fp_val_a := fp80_from_int(11);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, fp_val_a(31 downto 0));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, fp_val_a(63 downto 32));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, x"0000" & fp_val_a(79 downto 64));
    cfg_word := make_move_cfg("01", 0, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000080");
    cfg_word := make_move_cfg("00", 0, 0, "00", '0', "00", (others => '0'), '0', movem_mask_from_dn => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVEM);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, (others => '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, (others => '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, (others => '0'));
    cfg_word := make_move_cfg("01", 0, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000080");
    cfg_word := make_move_cfg("00", 0, 0, "00", '0', "00", (others => '0'), '1', movem_mask_from_dn => '1');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVEM);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    cfg_word := make_move_cfg("10", 0, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVEM Dn mask other-mode observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(11), "FMOVEM Dn mask other-mode");

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000001");
    cfg_word := make_move_cfg(
      "00", 0, 0, "00", '0', "00", (others => '0'), '0',
      movem_mask_from_dn => '1',
      movem_predec_order => '1'
    );
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVEM);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, (others => '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_H, (others => '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_E, (others => '0'));
    cfg_word := make_move_cfg("01", 0, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, x"00000001");
    cfg_word := make_move_cfg(
      "00", 0, 0, "00", '0', "00", (others => '0'), '1',
      movem_mask_from_dn => '1',
      movem_predec_order => '1'
    );
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVEM);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

    cfg_word := make_move_cfg("10", 0, 0, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
    bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
    rd_full := rd_ex(15 downto 0) & rd_hi & rd_lo;
    report "FMOVEM Dn mask predec observed=" & to_hstring(rd_full) severity note;
    check_fp80(rd_full, fp80_from_int(11), "FMOVEM Dn mask predec");

    report "TB SUCCESS: FMOVE/FMOVEM checks passed" severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
