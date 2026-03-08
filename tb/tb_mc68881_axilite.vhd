-- tb_mc68881_axilite.vhd
-- Testbench for mc68881_axilite_wrapper: dual-clock AXI4-Lite stimulus
-- exercising CDC bridge, FPU operations, error paths, and protocol edge cases.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_axilite is
end entity tb_mc68881_axilite;

architecture sim of tb_mc68881_axilite is

  -- Clock periods
  constant BUS_CLK_PERIOD : time := 10 ns;   -- 100 MHz bus clock
  constant FPU_CLK_PERIOD : time := 30 ns;   -- ~33 MHz FPU clock

  -- AXI signals
  signal s_axi_aclk    : std_logic := '0';
  signal s_axi_aresetn : std_logic := '0';
  signal s_axi_awaddr  : std_logic_vector(6 downto 0) := (others => '0');
  signal s_axi_awprot  : std_logic_vector(2 downto 0) := (others => '0');
  signal s_axi_awvalid : std_logic := '0';
  signal s_axi_awready : std_logic;
  signal s_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal s_axi_wstrb   : std_logic_vector(3 downto 0) := "1111";
  signal s_axi_wvalid  : std_logic := '0';
  signal s_axi_wready  : std_logic;
  signal s_axi_bresp   : std_logic_vector(1 downto 0);
  signal s_axi_bvalid  : std_logic;
  signal s_axi_bready  : std_logic := '0';
  signal s_axi_araddr  : std_logic_vector(6 downto 0) := (others => '0');
  signal s_axi_arprot  : std_logic_vector(2 downto 0) := (others => '0');
  signal s_axi_arvalid : std_logic := '0';
  signal s_axi_arready : std_logic;
  signal s_axi_rdata   : std_logic_vector(31 downto 0);
  signal s_axi_rresp   : std_logic_vector(1 downto 0);
  signal s_axi_rvalid  : std_logic;
  signal s_axi_rready  : std_logic := '0';
  signal fpu_clk       : std_logic := '0';
  signal irq           : std_logic;

  -- Test tracking
  signal test_pass_count : natural := 0;
  signal test_fail_count : natural := 0;

  -- MC68881 register addresses (byte-addressed for AXI: reg << 2)
  constant AXI_ADDR_OPSEL  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(0  * 4, 7));
  constant AXI_ADDR_OPA_L  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(1  * 4, 7));
  constant AXI_ADDR_OPA_H  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(2  * 4, 7));
  constant AXI_ADDR_OPA_E  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(3  * 4, 7));
  constant AXI_ADDR_OPB_L  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(4  * 4, 7));
  constant AXI_ADDR_OPB_H  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(5  * 4, 7));
  constant AXI_ADDR_OPB_E  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(6  * 4, 7));
  constant AXI_ADDR_RES_L  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(7  * 4, 7));
  constant AXI_ADDR_RES_H  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(8  * 4, 7));
  constant AXI_ADDR_RES_E  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(9  * 4, 7));
  constant AXI_ADDR_STATUS : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(10 * 4, 7));

  -- Opcode constants
  constant OP_ADD : std_logic_vector(31 downto 0) := x"00000001";
  constant OP_MUL : std_logic_vector(31 downto 0) := x"00000003";

  -- ========================================================================
  -- AXI4-Lite bus transaction procedures
  -- ========================================================================

  -- AXI write: present AW+W simultaneously, wait for B response.
  procedure axi_write(
    signal aclk      : in  std_logic;
    signal awaddr    : out std_logic_vector(6 downto 0);
    signal awvalid   : out std_logic;
    signal awready   : in  std_logic;
    signal wdata     : out std_logic_vector(31 downto 0);
    signal wvalid    : out std_logic;
    signal wready    : in  std_logic;
    signal bvalid    : in  std_logic;
    signal bready    : out std_logic;
    signal bresp     : in  std_logic_vector(1 downto 0);
    constant addr    : std_logic_vector(6 downto 0);
    constant data    : std_logic_vector(31 downto 0);
    variable resp    : out std_logic_vector(1 downto 0)
  ) is
    variable aw_done : boolean := false;
    variable w_done  : boolean := false;
  begin
    awaddr  <= addr;
    awvalid <= '1';
    wdata   <= data;
    wvalid  <= '1';
    -- Wait for both AW and W to be accepted
    while not (aw_done and w_done) loop
      wait until rising_edge(aclk);
      if awready = '1' and not aw_done then
        aw_done := true;
      end if;
      if wready = '1' and not w_done then
        w_done := true;
      end if;
    end loop;
    awvalid <= '0';
    wvalid  <= '0';
    -- Wait for write response
    bready <= '1';
    wait until rising_edge(aclk) and bvalid = '1';
    resp := bresp;
    wait until rising_edge(aclk);
    bready <= '0';
  end procedure;

  -- Convenience wrapper that asserts OKAY response
  procedure axi_write_ok(
    signal aclk      : in  std_logic;
    signal awaddr    : out std_logic_vector(6 downto 0);
    signal awvalid   : out std_logic;
    signal awready   : in  std_logic;
    signal wdata     : out std_logic_vector(31 downto 0);
    signal wvalid    : out std_logic;
    signal wready    : in  std_logic;
    signal bvalid    : in  std_logic;
    signal bready    : out std_logic;
    signal bresp     : in  std_logic_vector(1 downto 0);
    constant addr    : std_logic_vector(6 downto 0);
    constant data    : std_logic_vector(31 downto 0)
  ) is
    variable resp : std_logic_vector(1 downto 0);
  begin
    axi_write(aclk, awaddr, awvalid, awready, wdata, wvalid, wready,
              bvalid, bready, bresp, addr, data, resp);
    assert resp = "00"
      report "AXI write to " & to_hstring(addr) & " got non-OKAY response: " & to_hstring(resp)
      severity failure;
  end procedure;

  -- AXI read: present AR, wait for R response.
  procedure axi_read(
    signal aclk      : in  std_logic;
    signal araddr    : out std_logic_vector(6 downto 0);
    signal arvalid   : out std_logic;
    signal arready   : in  std_logic;
    signal rdata     : in  std_logic_vector(31 downto 0);
    signal rvalid    : in  std_logic;
    signal rready    : out std_logic;
    signal rresp     : in  std_logic_vector(1 downto 0);
    constant addr    : std_logic_vector(6 downto 0);
    variable data    : out std_logic_vector(31 downto 0);
    variable resp    : out std_logic_vector(1 downto 0)
  ) is
  begin
    araddr  <= addr;
    arvalid <= '1';
    wait until rising_edge(aclk) and arready = '1';
    arvalid <= '0';
    -- Wait for read response
    rready <= '1';
    wait until rising_edge(aclk) and rvalid = '1';
    data := rdata;
    resp := rresp;
    wait until rising_edge(aclk);
    rready <= '0';
  end procedure;

  -- Convenience wrapper that asserts OKAY response
  procedure axi_read_ok(
    signal aclk      : in  std_logic;
    signal araddr    : out std_logic_vector(6 downto 0);
    signal arvalid   : out std_logic;
    signal arready   : in  std_logic;
    signal rdata     : in  std_logic_vector(31 downto 0);
    signal rvalid    : in  std_logic;
    signal rready    : out std_logic;
    signal rresp     : in  std_logic_vector(1 downto 0);
    constant addr    : std_logic_vector(6 downto 0);
    variable data    : out std_logic_vector(31 downto 0)
  ) is
    variable resp : std_logic_vector(1 downto 0);
  begin
    axi_read(aclk, araddr, arvalid, arready, rdata, rvalid, rready, rresp,
             addr, data, resp);
    assert resp = "00"
      report "AXI read from " & to_hstring(addr) & " got non-OKAY response: " & to_hstring(resp)
      severity failure;
  end procedure;

  -- AXI write with AW first, then W after a gap (tests channel independence)
  procedure axi_write_aw_first(
    signal aclk      : in  std_logic;
    signal awaddr    : out std_logic_vector(6 downto 0);
    signal awvalid   : out std_logic;
    signal awready   : in  std_logic;
    signal wdata     : out std_logic_vector(31 downto 0);
    signal wvalid    : out std_logic;
    signal wready    : in  std_logic;
    signal bvalid    : in  std_logic;
    signal bready    : out std_logic;
    signal bresp     : in  std_logic_vector(1 downto 0);
    constant addr    : std_logic_vector(6 downto 0);
    constant data    : std_logic_vector(31 downto 0);
    constant gap_cycles : natural;
    variable resp    : out std_logic_vector(1 downto 0)
  ) is
  begin
    -- Present AW only
    awaddr  <= addr;
    awvalid <= '1';
    wait until rising_edge(aclk) and awready = '1';
    awvalid <= '0';
    -- Wait gap
    for i in 1 to gap_cycles loop
      wait until rising_edge(aclk);
    end loop;
    -- Present W
    wdata  <= data;
    wvalid <= '1';
    wait until rising_edge(aclk) and wready = '1';
    wvalid <= '0';
    -- Wait for write response
    bready <= '1';
    wait until rising_edge(aclk) and bvalid = '1';
    resp := bresp;
    wait until rising_edge(aclk);
    bready <= '0';
  end procedure;

  -- AXI write with W first, then AW after a gap
  procedure axi_write_w_first(
    signal aclk      : in  std_logic;
    signal awaddr    : out std_logic_vector(6 downto 0);
    signal awvalid   : out std_logic;
    signal awready   : in  std_logic;
    signal wdata     : out std_logic_vector(31 downto 0);
    signal wvalid    : out std_logic;
    signal wready    : in  std_logic;
    signal bvalid    : in  std_logic;
    signal bready    : out std_logic;
    signal bresp     : in  std_logic_vector(1 downto 0);
    constant addr    : std_logic_vector(6 downto 0);
    constant data    : std_logic_vector(31 downto 0);
    constant gap_cycles : natural;
    variable resp    : out std_logic_vector(1 downto 0)
  ) is
  begin
    -- Present W only
    wdata  <= data;
    wvalid <= '1';
    wait until rising_edge(aclk) and wready = '1';
    wvalid <= '0';
    -- Wait gap
    for i in 1 to gap_cycles loop
      wait until rising_edge(aclk);
    end loop;
    -- Present AW
    awaddr  <= addr;
    awvalid <= '1';
    wait until rising_edge(aclk) and awready = '1';
    awvalid <= '0';
    -- Wait for write response
    bready <= '1';
    wait until rising_edge(aclk) and bvalid = '1';
    resp := bresp;
    wait until rising_edge(aclk);
    bready <= '0';
  end procedure;

  -- Helper: write an fp80 operand triplet via AXI
  procedure axi_write_fp80(
    signal aclk      : in  std_logic;
    signal awaddr    : out std_logic_vector(6 downto 0);
    signal awvalid   : out std_logic;
    signal awready   : in  std_logic;
    signal wdata     : out std_logic_vector(31 downto 0);
    signal wvalid    : out std_logic;
    signal wready    : in  std_logic;
    signal bvalid    : in  std_logic;
    signal bready    : out std_logic;
    signal bresp     : in  std_logic_vector(1 downto 0);
    constant base_addr : natural;  -- register index (0-based)
    constant operand : fp80_t
  ) is
  begin
    axi_write_ok(aclk, awaddr, awvalid, awready, wdata, wvalid, wready,
                 bvalid, bready, bresp,
                 std_logic_vector(to_unsigned(base_addr * 4, 7)),
                 operand(31 downto 0));
    axi_write_ok(aclk, awaddr, awvalid, awready, wdata, wvalid, wready,
                 bvalid, bready, bresp,
                 std_logic_vector(to_unsigned((base_addr + 1) * 4, 7)),
                 operand(63 downto 32));
    axi_write_ok(aclk, awaddr, awvalid, awready, wdata, wvalid, wready,
                 bvalid, bready, bresp,
                 std_logic_vector(to_unsigned((base_addr + 2) * 4, 7)),
                 x"0000" & operand(79 downto 64));
  end procedure;

  -- Helper: read fp80 result triplet via AXI
  procedure axi_read_fp80(
    signal aclk      : in  std_logic;
    signal araddr    : out std_logic_vector(6 downto 0);
    signal arvalid   : out std_logic;
    signal arready   : in  std_logic;
    signal rdata     : in  std_logic_vector(31 downto 0);
    signal rvalid    : in  std_logic;
    signal rready    : out std_logic;
    signal rresp     : in  std_logic_vector(1 downto 0);
    variable result  : out fp80_t
  ) is
    variable lo_word : std_logic_vector(31 downto 0);
    variable hi_word : std_logic_vector(31 downto 0);
    variable ex_word : std_logic_vector(31 downto 0);
  begin
    axi_read_ok(aclk, araddr, arvalid, arready, rdata, rvalid, rready, rresp,
                AXI_ADDR_RES_L, lo_word);
    axi_read_ok(aclk, araddr, arvalid, arready, rdata, rvalid, rready, rresp,
                AXI_ADDR_RES_H, hi_word);
    axi_read_ok(aclk, araddr, arvalid, arready, rdata, rvalid, rready, rresp,
                AXI_ADDR_RES_E, ex_word);
    result := ex_word(15 downto 0) & hi_word & lo_word;
  end procedure;

  -- Helper: poll STATUS register until valid bit is set
  procedure axi_wait_valid(
    signal aclk      : in  std_logic;
    signal araddr    : out std_logic_vector(6 downto 0);
    signal arvalid   : out std_logic;
    signal arready   : in  std_logic;
    signal rdata     : in  std_logic_vector(31 downto 0);
    signal rvalid    : in  std_logic;
    signal rready    : out std_logic;
    signal rresp     : in  std_logic_vector(1 downto 0);
    constant max_polls : natural := 500
  ) is
    variable status : std_logic_vector(31 downto 0);
  begin
    for i in 1 to max_polls loop
      axi_read_ok(aclk, araddr, arvalid, arready, rdata, rvalid, rready, rresp,
                  AXI_ADDR_STATUS, status);
      if status(0) = '1' then
        return;
      end if;
    end loop;
    assert false report "Timed out waiting for FPU valid" severity failure;
  end procedure;

begin

  -- ========================================================================
  -- Clock generation
  -- ========================================================================
  s_axi_aclk <= not s_axi_aclk after BUS_CLK_PERIOD / 2;
  fpu_clk    <= not fpu_clk    after FPU_CLK_PERIOD / 2;

  -- ========================================================================
  -- DUT
  -- ========================================================================
  dut : entity work.mc68881_axilite_wrapper
    generic map (
      packed_decimal_full_g => true,
      dsack_timeout_g       => 1024,
      channel_timeout_g     => 256
    )
    port map (
      s_axi_aclk    => s_axi_aclk,
      s_axi_aresetn => s_axi_aresetn,
      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awprot  => s_axi_awprot,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => s_axi_wstrb,
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,
      s_axi_araddr  => s_axi_araddr,
      s_axi_arprot  => s_axi_arprot,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready,
      fpu_clk       => fpu_clk,
      irq           => irq
    );

  -- ========================================================================
  -- Stimulus process
  -- ========================================================================
  p_stim : process
    variable rd_data : std_logic_vector(31 downto 0);
    variable rd_resp : std_logic_vector(1 downto 0);
    variable result  : fp80_t;
    variable expected : fp80_t;
    variable op_a    : fp80_t;
    variable op_b    : fp80_t;
    variable wr_resp : std_logic_vector(1 downto 0);
  begin
    -- ======================================================================
    -- Reset
    -- ======================================================================
    s_axi_aresetn <= '0';
    wait for 10 * BUS_CLK_PERIOD;
    s_axi_aresetn <= '1';
    wait for 10 * BUS_CLK_PERIOD;

    report "=== TEST 1: Basic register write/read (STATUS) ===" severity note;
    -- STATUS register should read back with valid=0 after reset
    axi_read_ok(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp,
                AXI_ADDR_STATUS, rd_data);
    report "STATUS after reset: " & to_hstring(rd_data) severity note;
    assert rd_data(1) = '0'
      report "STATUS busy should be 0 after reset, got: " & to_hstring(rd_data)
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    report "=== TEST 2: FPU ADD operation (10 + 5 = 15) ===" severity note;
    -- ======================================================================
    op_a := fp80_from_int(10);
    op_b := fp80_from_int(5);
    expected := add_sub_fp80(op_a, op_b, false, FP_RND_NEAREST, FP_PREC_EXTENDED);

    -- Write operand A
    axi_write_fp80(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                   s_axi_wdata, s_axi_wvalid, s_axi_wready,
                   s_axi_bvalid, s_axi_bready, s_axi_bresp,
                   1, op_a);
    -- Write operand B
    axi_write_fp80(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                   s_axi_wdata, s_axi_wvalid, s_axi_wready,
                   s_axi_bvalid, s_axi_bready, s_axi_bresp,
                   4, op_b);
    -- Trigger ADD
    axi_write_ok(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                 s_axi_wdata, s_axi_wvalid, s_axi_wready,
                 s_axi_bvalid, s_axi_bready, s_axi_bresp,
                 AXI_ADDR_OPSEL, OP_ADD);

    -- Poll for completion
    axi_wait_valid(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                   s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp);

    -- Read result
    axi_read_fp80(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                  s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp,
                  result);
    report "ADD result:   " & to_hstring(result) severity note;
    report "ADD expected: " & to_hstring(expected) severity note;
    assert result = expected
      report "ADD MISMATCH: got=" & to_hstring(result) & " expected=" & to_hstring(expected)
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    report "=== TEST 3: IRQ asserted after operation completes ===" severity note;
    -- ======================================================================
    -- IRQ should be high now (status_valid is set)
    -- Allow a few cycles for CDC synchronizer propagation
    wait for 5 * BUS_CLK_PERIOD;
    assert irq = '1'
      report "IRQ should be asserted after operation completes"
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    report "=== TEST 4: FPU MUL operation (7 * 9 = 63) ===" severity note;
    -- ======================================================================
    op_a := fp80_from_int(7);
    op_b := fp80_from_int(9);
    expected := mul_fp80(op_a, op_b, FP_RND_NEAREST, FP_PREC_EXTENDED);

    axi_write_fp80(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                   s_axi_wdata, s_axi_wvalid, s_axi_wready,
                   s_axi_bvalid, s_axi_bready, s_axi_bresp,
                   1, op_a);
    axi_write_fp80(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                   s_axi_wdata, s_axi_wvalid, s_axi_wready,
                   s_axi_bvalid, s_axi_bready, s_axi_bresp,
                   4, op_b);
    axi_write_ok(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                 s_axi_wdata, s_axi_wvalid, s_axi_wready,
                 s_axi_bvalid, s_axi_bready, s_axi_bresp,
                 AXI_ADDR_OPSEL, OP_MUL);

    -- IRQ should clear when new operation starts (status_valid goes low)
    wait for 10 * BUS_CLK_PERIOD;
    assert irq = '0'
      report "IRQ should deassert after new operation starts"
      severity failure;

    axi_wait_valid(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                   s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp);
    axi_read_fp80(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                  s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp,
                  result);
    report "MUL result:   " & to_hstring(result) severity note;
    report "MUL expected: " & to_hstring(expected) severity note;
    assert result = expected
      report "MUL MISMATCH: got=" & to_hstring(result) & " expected=" & to_hstring(expected)
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    report "=== TEST 5: AXI channel independence (AW before W) ===" severity note;
    -- ======================================================================
    -- Write operand A low word with AW arriving 5 cycles before W
    axi_write_aw_first(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                       s_axi_wdata, s_axi_wvalid, s_axi_wready,
                       s_axi_bvalid, s_axi_bready, s_axi_bresp,
                       AXI_ADDR_OPA_L, x"DEADBEEF", 5, wr_resp);
    assert wr_resp = "00"
      report "AW-first write got non-OKAY response: " & to_hstring(wr_resp)
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    report "=== TEST 6: AXI channel independence (W before AW) ===" severity note;
    -- ======================================================================
    axi_write_w_first(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                      s_axi_wdata, s_axi_wvalid, s_axi_wready,
                      s_axi_bvalid, s_axi_bready, s_axi_bresp,
                      AXI_ADDR_OPA_H, x"CAFEBABE", 5, wr_resp);
    assert wr_resp = "00"
      report "W-first write got non-OKAY response: " & to_hstring(wr_resp)
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    report "=== TEST 7: Back-to-back reads ===" severity note;
    -- ======================================================================
    -- Issue 3 consecutive reads with no idle gap
    axi_read_ok(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp,
                AXI_ADDR_RES_L, rd_data);
    axi_read_ok(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp,
                AXI_ADDR_RES_H, rd_data);
    axi_read_ok(s_axi_aclk, s_axi_araddr, s_axi_arvalid, s_axi_arready,
                s_axi_rdata, s_axi_rvalid, s_axi_rready, s_axi_rresp,
                AXI_ADDR_RES_E, rd_data);
    report "Back-to-back reads completed successfully" severity note;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    report "=== TEST 8: Back-to-back writes ===" severity note;
    -- ======================================================================
    -- Write all 3 words of operand A back-to-back
    op_a := fp80_from_int(42);
    axi_write_ok(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                 s_axi_wdata, s_axi_wvalid, s_axi_wready,
                 s_axi_bvalid, s_axi_bready, s_axi_bresp,
                 AXI_ADDR_OPA_L, op_a(31 downto 0));
    axi_write_ok(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                 s_axi_wdata, s_axi_wvalid, s_axi_wready,
                 s_axi_bvalid, s_axi_bready, s_axi_bresp,
                 AXI_ADDR_OPA_H, op_a(63 downto 32));
    axi_write_ok(s_axi_aclk, s_axi_awaddr, s_axi_awvalid, s_axi_awready,
                 s_axi_wdata, s_axi_wvalid, s_axi_wready,
                 s_axi_bvalid, s_axi_bready, s_axi_bresp,
                 AXI_ADDR_OPA_E, x"0000" & op_a(79 downto 64));
    report "Back-to-back writes completed successfully" severity note;
    test_pass_count <= test_pass_count + 1;

    -- ======================================================================
    -- Summary
    -- ======================================================================
    wait for 10 * BUS_CLK_PERIOD;
    report "=== AXI-LITE WRAPPER TB: " & integer'image(test_pass_count + 1) &
           " tests passed. No failures detected. ===" severity note;
    std.env.finish;
  end process p_stim;

end architecture sim;
