-- mc68881_wishbone_wrapper.vhd
-- Wishbone B4 pipelined slave wrapper for the MC68881 FPU.
-- Instantiates the bus bridge and FPU core as a self-contained peripheral.
-- Address mapping: Wishbone byte address bits [6:2] map to MC68881 register address [4:0].

library ieee;
use ieee.std_logic_1164.all;

entity mc68881_wishbone_wrapper is
  generic (
    packed_decimal_full_g : boolean := true
  );
  port (
    -- Wishbone B4 Slave Interface
    wb_clk_i   : in  std_logic;  -- bus clock (e.g. 100 MHz)
    wb_rst_i   : in  std_logic;  -- active-high reset
    wb_adr_i   : in  std_logic_vector(6 downto 0);  -- byte address
    wb_dat_i   : in  std_logic_vector(31 downto 0);
    wb_dat_o   : out std_logic_vector(31 downto 0);
    wb_we_i    : in  std_logic;
    wb_sel_i   : in  std_logic_vector(3 downto 0);
    wb_stb_i   : in  std_logic;
    wb_cyc_i   : in  std_logic;
    wb_ack_o   : out std_logic;
    wb_stall_o : out std_logic;
    wb_err_o   : out std_logic;
    -- FPU clock
    fpu_clk    : in  std_logic;  -- 33 MHz
    -- Interrupt
    irq        : out std_logic
  );
end entity mc68881_wishbone_wrapper;

architecture rtl of mc68881_wishbone_wrapper is

  -- Bridge signals
  signal bridge_req   : std_logic := '0';
  signal bridge_rw    : std_logic := '1';
  signal bridge_addr  : std_logic_vector(4 downto 0)  := (others => '0');
  signal bridge_wdata : std_logic_vector(31 downto 0) := (others => '0');
  signal bridge_rdata : std_logic_vector(31 downto 0);
  signal bridge_done  : std_logic;
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

  signal bus_reset_n : std_logic;

  -- WB FSM
  type wb_state_t is (WB_IDLE, WB_WAIT, WB_ACK);
  signal wb_state_reg : wb_state_t := WB_IDLE;

  signal rdata_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal we_reg    : std_logic := '0';

begin

  bus_reset_n <= not wb_rst_i;
  wb_err_o    <= '0';

  -- ========================================================================
  -- Bus Bridge
  -- ========================================================================
  u_bridge : entity work.mc68881_bus_bridge
    port map (
      bus_clk          => wb_clk_i,
      bus_reset_n      => bus_reset_n,
      bridge_req       => bridge_req,
      bridge_rw        => bridge_rw,
      bridge_addr      => bridge_addr,
      bridge_wdata     => bridge_wdata,
      bridge_rdata     => bridge_rdata,
      bridge_done      => bridge_done,
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
  -- Wishbone FSM
  -- ========================================================================
  p_wb : process(wb_clk_i)
  begin
    if rising_edge(wb_clk_i) then
      bridge_req <= '0';  -- default: no pulse
      wb_ack_o   <= '0';

      if wb_rst_i = '1' then
        wb_state_reg <= WB_IDLE;
        wb_stall_o   <= '0';
      else
        case wb_state_reg is
          when WB_IDLE =>
            wb_stall_o <= '0';
            if wb_stb_i = '1' and wb_cyc_i = '1' then
              bridge_addr  <= wb_adr_i(6 downto 2);
              bridge_wdata <= wb_dat_i;
              bridge_rw    <= not wb_we_i;  -- WB: we=1 is write; bridge: rw=0 is write
              we_reg       <= wb_we_i;
              bridge_req   <= '1';
              wb_stall_o   <= '1';
              wb_state_reg <= WB_WAIT;
            end if;

          when WB_WAIT =>
            wb_stall_o <= '1';
            if bridge_done = '1' then
              if we_reg = '0' then
                rdata_reg <= bridge_rdata;
              end if;
              wb_state_reg <= WB_ACK;
            end if;

          when WB_ACK =>
            wb_ack_o     <= '1';
            wb_stall_o   <= '0';
            wb_state_reg <= WB_IDLE;
        end case;
      end if;
    end if;
  end process p_wb;

  wb_dat_o <= rdata_reg;

end architecture rtl;
