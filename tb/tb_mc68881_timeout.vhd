-- tb_mc68881_timeout.vhd
-- Verifies DSACK timeout error propagation and SLVERR response.
-- Uses dsack_timeout_g=1 so all FPU transactions timeout before DSACK arrives,
-- exercising the bridge error flag CDC path and wrapper error response logic.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_mc68881_timeout is
end entity tb_mc68881_timeout;

architecture sim of tb_mc68881_timeout is

  constant BUS_CLK_PERIOD : time := 10 ns;
  constant FPU_CLK_PERIOD : time := 30 ns;

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

  signal test_pass_count : natural := 0;

  constant AXI_ADDR_STATUS : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(10 * 4, 7));
  constant AXI_ADDR_OPA_L  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(1 * 4, 7));

begin

  s_axi_aclk <= not s_axi_aclk after BUS_CLK_PERIOD / 2;
  fpu_clk    <= not fpu_clk    after FPU_CLK_PERIOD / 2;

  -- DUT with dsack_timeout_g=1: all FPU transactions will timeout
  dut : entity work.mc68881_axilite_wrapper
    generic map (
      packed_decimal_full_g => true,
      dsack_timeout_g       => 1,
      channel_timeout_g     => 4096
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

  p_stim : process
  begin
    -- Reset
    s_axi_aresetn <= '0';
    wait for 10 * BUS_CLK_PERIOD;
    s_axi_aresetn <= '1';
    wait for 10 * BUS_CLK_PERIOD;

    -- ==================================================================
    report "=== TIMEOUT TEST 1: Read with DSACK timeout -> SLVERR ===" severity note;
    -- ==================================================================
    s_axi_araddr  <= AXI_ADDR_STATUS;
    s_axi_arvalid <= '1';
    wait until rising_edge(s_axi_aclk) and s_axi_arready = '1';
    s_axi_arvalid <= '0';
    s_axi_rready  <= '1';
    wait until rising_edge(s_axi_aclk) and s_axi_rvalid = '1';
    assert s_axi_rresp = "10"
      report "DSACK timeout read should return SLVERR, got: " & to_hstring(s_axi_rresp)
      severity failure;
    report "Read correctly returned SLVERR on DSACK timeout" severity note;
    wait until rising_edge(s_axi_aclk);
    s_axi_rready <= '0';
    test_pass_count <= test_pass_count + 1;

    wait for 5 * BUS_CLK_PERIOD;

    -- ==================================================================
    report "=== TIMEOUT TEST 2: Write with DSACK timeout -> SLVERR ===" severity note;
    -- ==================================================================
    -- Present both AW+W and bready; wait for bvalid with SLVERR
    s_axi_awaddr  <= AXI_ADDR_OPA_L;
    s_axi_awvalid <= '1';
    s_axi_wdata   <= x"DEADBEEF";
    s_axi_wvalid  <= '1';
    s_axi_bready  <= '1';
    wait until rising_edge(s_axi_aclk) and s_axi_bvalid = '1';
    s_axi_awvalid <= '0';
    s_axi_wvalid  <= '0';
    assert s_axi_bresp = "10"
      report "DSACK timeout write should return SLVERR, got: " & to_hstring(s_axi_bresp)
      severity failure;
    report "Write correctly returned SLVERR on DSACK timeout" severity note;
    wait until rising_edge(s_axi_aclk);
    s_axi_bready <= '0';
    test_pass_count <= test_pass_count + 1;

    wait for 5 * BUS_CLK_PERIOD;

    -- ==================================================================
    report "=== TIMEOUT TEST 3: FSM recovery (second read also SLVERR) ===" severity note;
    -- ==================================================================
    s_axi_araddr  <= AXI_ADDR_STATUS;
    s_axi_arvalid <= '1';
    wait until rising_edge(s_axi_aclk) and s_axi_arready = '1';
    s_axi_arvalid <= '0';
    s_axi_rready  <= '1';
    wait until rising_edge(s_axi_aclk) and s_axi_rvalid = '1';
    assert s_axi_rresp = "10"
      report "Second read should also SLVERR, got: " & to_hstring(s_axi_rresp)
      severity failure;
    report "FSM recovered: second read also returned SLVERR as expected" severity note;
    wait until rising_edge(s_axi_aclk);
    s_axi_rready <= '0';
    test_pass_count <= test_pass_count + 1;

    -- ==================================================================
    -- Summary
    -- ==================================================================
    wait for 10 * BUS_CLK_PERIOD;
    report "=== DSACK TIMEOUT TB: " & integer'image(test_pass_count) &
           " tests passed. No failures detected. ===" severity note;
    std.env.finish;
  end process p_stim;

end architecture sim;
