library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_fmovecr is
end entity tb_mc68881_fmovecr;

architecture sim of tb_mc68881_fmovecr is
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
  constant ADDR_RES_L : unsigned(4 downto 0) := to_unsigned(7, 5);
  constant ADDR_RES_H : unsigned(4 downto 0) := to_unsigned(8, 5);
  constant ADDR_RES_E : unsigned(4 downto 0) := to_unsigned(9, 5);
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_MOVE_CFG : unsigned(4 downto 0) := to_unsigned(23, 5);

  constant OP_FMOVE : std_logic_vector(31 downto 0) := x"00000005";

  type natural_array_t is array (natural range <>) of natural;
  type fp80_array_t is array (natural range <>) of fp80_t;

  constant FMOVECR_CODES : natural_array_t := (
    16#0B#, 16#0C#, 16#0D#, 16#0E#,
    16#36#, 16#37#, 16#38#, 16#39#,
    16#3A#, 16#3B#, 16#3C#, 16#3D#,
    16#3E#, 16#3F#
  );

  constant FMOVECR_EXPECTED : fp80_array_t := (
    x"3FFD9A209A84FBCFF798",
    x"4000ADF85458A2BB4A9A",
    x"3FFFB8AA3B295C17F0BC",
    x"3FFDDE5BD8A937287195",
    x"4019BEBC200000000000",
    x"40348E1BC9BF04000000",
    x"40699DC5ADA82B70B59E",
    x"40D3C2781F49FFCFA6D5",
    x"41A893BA47C980E98CE0",
    x"4351AA7EEBFB9DF9DE8E",
    x"46A3E319A0AEA60E91C7",
    x"4D48C976758681750C17",
    x"5A929E8B3B5DC53D5DE5",
    x"7525C46052028A20979B"
  );

  procedure split_fp80(
    constant value : fp80_t;
    variable sign_val : out std_logic;
    variable exp_val  : out unsigned(FP_EXP_WIDTH-1 downto 0);
    variable mant_val : out unsigned(FP_MANT_WIDTH-1 downto 0)
  ) is
  begin
    sign_val := value(FP_WIDTH-1);
    exp_val := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    mant_val := unsigned(value(FP_MANT_WIDTH-1 downto 0));
  end procedure;

  procedure check_fp80_fields(
    constant got : fp80_t;
    constant expected : fp80_t;
    constant ccc_code : natural
  ) is
    variable got_sign : std_logic := '0';
    variable exp_sign : std_logic := '0';
    variable got_exp : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable exp_exp : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable got_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_mant : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable ccc_byte : std_logic_vector(7 downto 0) := (others => '0');
  begin
    split_fp80(got, got_sign, got_exp, got_mant);
    split_fp80(expected, exp_sign, exp_exp, exp_mant);
    ccc_byte := std_logic_vector(to_unsigned(ccc_code, 8));
    assert got_sign = exp_sign and got_exp = exp_exp and got_mant = exp_mant
      report "FMOVECR #" & to_hstring(ccc_byte) &
             " mismatch expected=" & to_hstring(expected) &
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
      report "FMOVECR status poll valid=" & std_logic'image(status_s(0)) &
             " busy=" & std_logic'image(status_s(1))
        severity note;
      exit when status_s(0) = '1';
    end loop;
  end procedure;

  function make_move_cfg(
    mode : std_logic_vector(1 downto 0);
    src_idx : natural;
    dst_idx : natural;
    enable_fmovecr : std_logic
  ) return std_logic_vector is
    variable cfg : move_cfg_t := move_cfg_default;
  begin
    cfg.src_idx := src_idx;
    cfg.mode := decode_move_cfg_mode(mode);
    cfg.dst_idx := dst_idx;
    cfg.fmovecr_enable := enable_fmovecr;
    return encode_move_cfg(cfg);
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
    variable observed : fp80_t := (others => '0');
    variable cfg_word : std_logic_vector(31 downto 0) := (others => '0');
    variable ccc_word : std_logic_vector(31 downto 0) := (others => '0');
    variable ccc_byte : std_logic_vector(7 downto 0) := (others => '0');
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    report "FMOVECR extended constant ROM checks" severity note;

    for idx in FMOVECR_CODES'range loop
      ccc_word := std_logic_vector(to_unsigned(FMOVECR_CODES(idx), 32));
      ccc_byte := std_logic_vector(to_unsigned(FMOVECR_CODES(idx), 8));
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPA_L, ccc_word);

      cfg_word := make_move_cfg("00", 0, 6, '1');
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
      wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

      cfg_word := make_move_cfg("10", 6, 0, '0');
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_MOVE_CFG, cfg_word);
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n, ADDR_OPSEL, OP_FMOVE);
      wait_for_valid(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, status_word);

      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_lo, ADDR_RES_L);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_hi, ADDR_RES_H);
      bus_read(a_in, rw, cs_n, as_n, ds_n, dsack0_n, dsack1_n, d_out, rd_ex, ADDR_RES_E);
      observed := rd_ex(15 downto 0) & rd_hi & rd_lo;

      report "FMOVECR #" & to_hstring(ccc_byte) &
             " expected=" & to_hstring(FMOVECR_EXPECTED(idx)) &
             " observed=" & to_hstring(observed)
        severity note;
      check_fp80_fields(observed, FMOVECR_EXPECTED(idx), FMOVECR_CODES(idx));
    end loop;

    report "tb_mc68881_fmovecr passed" severity note;
    stop;
  end process;
end architecture sim;
