-- mc68881_axilite_wrapper.vhd
-- AXI4-Lite slave wrapper for the MC68881 FPU.
-- Instantiates the bus bridge and FPU core as a self-contained peripheral.
-- Address mapping: AXI byte address bits [6:2] map to MC68881 register address [4:0].

library ieee;
use ieee.std_logic_1164.all;

entity mc68881_axilite_wrapper is
  generic (
    packed_decimal_full_g : boolean := true;
    -- DSACK timeout passed to bridge (fpu_clk cycles; 0 disables)
    dsack_timeout_g      : natural := 1024;
    -- AXI channel pairing timeout in bus_clk cycles (0 disables).
    -- If AW arrives without W (or vice versa), abort after this many cycles.
    channel_timeout_g    : natural := 4096
  );
  port (
    -- AXI4-Lite Slave Interface
    s_axi_aclk    : in  std_logic;  -- bus clock (e.g. 100 MHz)
    s_axi_aresetn : in  std_logic;
    -- Write address channel
    s_axi_awaddr  : in  std_logic_vector(6 downto 0);
    s_axi_awprot  : in  std_logic_vector(2 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    -- Write data channel
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    -- Write response channel
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    -- Read address channel
    s_axi_araddr  : in  std_logic_vector(6 downto 0);
    s_axi_arprot  : in  std_logic_vector(2 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    -- Read data channel
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;
    -- FPU clock
    fpu_clk       : in  std_logic;  -- 33 MHz
    -- Interrupt
    irq           : out std_logic
  );
end entity mc68881_axilite_wrapper;

architecture rtl of mc68881_axilite_wrapper is

  -- Bridge signals
  signal bridge_req   : std_logic := '0';
  signal bridge_rw    : std_logic := '1';
  signal bridge_addr  : std_logic_vector(4 downto 0)  := (others => '0');
  signal bridge_wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal bridge_rdata : std_logic_vector(31 downto 0);
  signal bridge_done  : std_logic;
  signal bridge_error : std_logic;
  signal bridge_busy  : std_logic;

  -- FPU wiring
  signal fpu_reset_n    : std_logic;
  signal fpu_a_in       : std_logic_vector(4 downto 0);
  signal fpu_d_in       : std_logic_vector(31 downto 0);
  signal fpu_d_out      : std_logic_vector(31 downto 0);
  signal fpu_size_n     : std_logic_vector(1 downto 0);
  signal fpu_as_n       : std_logic;
  signal fpu_cs_n       : std_logic;
  signal fpu_rw         : std_logic;
  signal fpu_ds_n       : std_logic;
  signal fpu_dsack0_n   : std_logic;
  signal fpu_dsack1_n   : std_logic;
  signal fpu_sense_n    : std_logic := 'H';
  signal fpu_status_valid : std_logic;

  -- AXI FSM
  type axi_state_t is (AXI_IDLE,
                        AXI_WRITE_BRIDGE, AXI_WRITE_RESP,
                        AXI_READ_BRIDGE, AXI_READ_RESP);
  signal axi_state_reg : axi_state_t := AXI_IDLE;

  -- Latched AXI channels
  signal aw_latched  : std_logic := '0';
  signal w_latched   : std_logic := '0';
  signal req_sent    : std_logic := '0';  -- bridge_req already issued this transaction
  signal aw_addr_reg : std_logic_vector(4 downto 0) := (others => '0');
  signal w_data_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal ar_addr_reg : std_logic_vector(4 downto 0) := (others => '0');
  signal rdata_reg   : std_logic_vector(31 downto 0) := (others => '0');
  signal resp_reg    : std_logic_vector(1 downto 0) := "00";

  -- Internal mirrors of valid outputs (needed to read registered value for
  -- handshake completion check without violating VRFC "never read out" rule)
  signal bvalid_reg  : std_logic := '0';
  signal rvalid_reg  : std_logic := '0';

  -- Channel pairing timeout counter
  signal chan_timeout_cnt : natural range 0 to channel_timeout_g := 0;

begin

  -- ========================================================================
  -- Bus Bridge
  -- ========================================================================
  u_bridge : entity work.mc68881_bus_bridge
    generic map (
      dsack_timeout_g => dsack_timeout_g
    )
    port map (
      bus_clk          => s_axi_aclk,
      bus_reset_n      => s_axi_aresetn,
      bridge_req       => bridge_req,
      bridge_rw        => bridge_rw,
      bridge_addr      => bridge_addr,
      bridge_wdata     => bridge_wdata,
      bridge_rdata     => bridge_rdata,
      bridge_done      => bridge_done,
      bridge_error     => bridge_error,
      bridge_busy      => bridge_busy,
      fpu_clk          => fpu_clk,
      fpu_reset_n      => fpu_reset_n,
      fpu_a_in         => fpu_a_in,
      fpu_d_in         => fpu_d_in,
      fpu_d_out        => fpu_d_out,
      fpu_size_n       => fpu_size_n,
      fpu_as_n         => fpu_as_n,
      fpu_cs_n         => fpu_cs_n,
      fpu_rw           => fpu_rw,
      fpu_ds_n         => fpu_ds_n,
      fpu_dsack0_n     => fpu_dsack0_n,
      fpu_dsack1_n     => fpu_dsack1_n,
      fpu_status_valid => fpu_status_valid,
      irq_out          => irq
    );

  -- ========================================================================
  -- FPU Core
  -- ========================================================================
  u_fpu : entity work.mc68881_top
    generic map (
      packed_decimal_full_g => packed_decimal_full_g
    )
    port map (
      a_in         => fpu_a_in,
      d_in         => fpu_d_in,
      d_out        => fpu_d_out,
      size_n       => fpu_size_n,
      as_n         => fpu_as_n,
      cs_n         => fpu_cs_n,
      rw           => fpu_rw,
      ds_n         => fpu_ds_n,
      dsack0_n     => fpu_dsack0_n,
      dsack1_n     => fpu_dsack1_n,
      reset_n      => fpu_reset_n,
      clk          => fpu_clk,
      sense_n      => fpu_sense_n,
      status_valid => fpu_status_valid
    );

  -- ========================================================================
  -- AXI4-Lite FSM
  -- ========================================================================
  s_axi_bvalid <= bvalid_reg;
  s_axi_rvalid <= rvalid_reg;

  p_axi : process(s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      bridge_req    <= '0';  -- default: no pulse
      s_axi_awready <= '0';
      s_axi_wready  <= '0';
      s_axi_arready <= '0';

      if s_axi_aresetn = '0' then
        axi_state_reg <= AXI_IDLE;
        bvalid_reg    <= '0';
        rvalid_reg    <= '0';
        s_axi_bresp   <= "00";
        s_axi_rresp   <= "00";
        aw_latched    <= '0';
        w_latched     <= '0';
        req_sent      <= '0';
        chan_timeout_cnt <= 0;
      else
        case axi_state_reg is
          when AXI_IDLE =>
            bvalid_reg <= '0';
            rvalid_reg <= '0';
            aw_latched <= '0';
            w_latched  <= '0';
            req_sent   <= '0';
            chan_timeout_cnt <= 0;

            -- Read has priority if both arrive simultaneously
            if s_axi_arvalid = '1' then
              ar_addr_reg   <= s_axi_araddr(6 downto 2);
              s_axi_arready <= '1';
              axi_state_reg <= AXI_READ_BRIDGE;
            elsif s_axi_awvalid = '1' and s_axi_wvalid = '1' then
              -- Both AW and W available
              aw_addr_reg   <= s_axi_awaddr(6 downto 2);
              w_data_reg    <= s_axi_wdata;
              s_axi_awready <= '1';
              s_axi_wready  <= '1';
              aw_latched    <= '1';
              w_latched     <= '1';
              axi_state_reg <= AXI_WRITE_BRIDGE;
            elsif s_axi_awvalid = '1' then
              aw_addr_reg   <= s_axi_awaddr(6 downto 2);
              s_axi_awready <= '1';
              aw_latched    <= '1';
              axi_state_reg <= AXI_WRITE_BRIDGE;
            elsif s_axi_wvalid = '1' then
              w_data_reg    <= s_axi_wdata;
              s_axi_wready  <= '1';
              w_latched     <= '1';
              axi_state_reg <= AXI_WRITE_BRIDGE;
            end if;

          when AXI_WRITE_BRIDGE =>
            -- Accept the missing channel if not yet latched
            if aw_latched = '0' and s_axi_awvalid = '1' then
              aw_addr_reg   <= s_axi_awaddr(6 downto 2);
              s_axi_awready <= '1';
              aw_latched    <= '1';
            end if;
            if w_latched = '0' and s_axi_wvalid = '1' then
              w_data_reg    <= s_axi_wdata;
              s_axi_wready  <= '1';
              w_latched     <= '1';
            end if;

            -- Prioritize bridge_done over issuing new request
            if bridge_done = '1' then
              resp_reg      <= "00" when bridge_error = '0' else "10";  -- OKAY or SLVERR
              axi_state_reg <= AXI_WRITE_RESP;
            elsif aw_latched = '1' and w_latched = '1' and req_sent = '0' then
              bridge_addr  <= aw_addr_reg;
              bridge_wdata <= w_data_reg;
              bridge_rw    <= '0';  -- write
              bridge_req   <= '1';
              req_sent     <= '1';
            end if;

            -- Channel pairing timeout: abort if one channel never arrives
            if channel_timeout_g > 0 and (aw_latched = '0' or w_latched = '0') then
              if chan_timeout_cnt = channel_timeout_g - 1 then
                aw_latched <= '1';
                w_latched  <= '1';
                resp_reg   <= "10";  -- SLVERR
                axi_state_reg <= AXI_WRITE_RESP;
              else
                chan_timeout_cnt <= chan_timeout_cnt + 1;
              end if;
            end if;

          when AXI_WRITE_RESP =>
            bvalid_reg  <= '1';
            s_axi_bresp <= resp_reg;
            -- Complete handshake only when bvalid was already registered high
            if bvalid_reg = '1' and s_axi_bready = '1' then
              bvalid_reg    <= '0';
              axi_state_reg <= AXI_IDLE;
            end if;

          when AXI_READ_BRIDGE =>
            -- Prioritize bridge_done over issuing new request
            if bridge_done = '1' then
              rdata_reg     <= bridge_rdata;
              resp_reg      <= "00" when bridge_error = '0' else "10";
              axi_state_reg <= AXI_READ_RESP;
            elsif req_sent = '0' then
              bridge_addr <= ar_addr_reg;
              bridge_rw   <= '1';  -- read
              bridge_req  <= '1';
              req_sent    <= '1';
            end if;

          when AXI_READ_RESP =>
            rvalid_reg  <= '1';
            s_axi_rdata <= rdata_reg;
            s_axi_rresp <= resp_reg;
            -- Complete handshake only when rvalid was already registered high
            if rvalid_reg = '1' and s_axi_rready = '1' then
              rvalid_reg    <= '0';
              axi_state_reg <= AXI_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process p_axi;

end architecture rtl;
