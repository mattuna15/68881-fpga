-- mc68881_bus_bridge.vhd
-- CDC bridge between a generic bus clock domain and the MC68881 FPU (fpu_clk).
-- Uses toggle-handshake for clock domain crossing and generates M68K-style
-- bus cycles (CS/AS/DS/DSACK) to the FPU core.
-- Includes DSACK timeout to prevent bus deadlock if FPU is unresponsive.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mc68881_bus_bridge is
  generic (
    -- DSACK timeout in fpu_clk cycles. 0 disables timeout.
    -- Default 1024 cycles = ~31 us at 33 MHz.
    dsack_timeout_g : natural := 1024
  );
  port (
    -- Bus-side (bus_clk domain)
    bus_clk      : in  std_logic;
    bus_reset_n  : in  std_logic;
    bridge_req   : in  std_logic;                     -- pulse to start txn
    bridge_rw    : in  std_logic;                     -- 1=read, 0=write
    bridge_addr  : in  std_logic_vector(4 downto 0);  -- register address
    bridge_wdata : in  std_logic_vector(31 downto 0);
    bridge_rdata : out std_logic_vector(31 downto 0); -- valid when bridge_done='1'
    bridge_done  : out std_logic;                     -- 1-cycle pulse
    bridge_error : out std_logic;                     -- 1-cycle pulse, coincides with bridge_done on timeout
    bridge_busy  : out std_logic;                     -- high during transaction
    -- FPU-side (directly wired to mc68881_top ports)
    fpu_clk      : in  std_logic;
    fpu_reset_n  : out std_logic;
    fpu_a_in     : out std_logic_vector(4 downto 0);
    fpu_d_in     : out std_logic_vector(31 downto 0);
    fpu_d_out    : in  std_logic_vector(31 downto 0);
    fpu_size_n   : out std_logic;
    fpu_a0_in    : out std_logic;
    fpu_as_n     : out std_logic;
    fpu_cs_n     : out std_logic;
    fpu_rw       : out std_logic;
    fpu_ds_n     : out std_logic;
    fpu_dsack0_n : in  std_logic;
    fpu_dsack1_n : in  std_logic;
    -- Interrupt (fpu_clk domain input, synchronized to bus_clk internally)
    fpu_status_valid : in  std_logic;  -- from mc68881_top.status_valid
    irq_out          : out std_logic   -- active-high, level-sensitive
  );
end entity mc68881_bus_bridge;

architecture rtl of mc68881_bus_bridge is

  -- ========================================================================
  -- Bus-clk domain signals
  -- ========================================================================
  type bus_state_t is (BUS_IDLE, BUS_WAIT_ACK);
  signal bus_state_reg : bus_state_t := BUS_IDLE;

  signal req_toggle_reg : std_logic := '0';
  signal req_addr_reg   : std_logic_vector(4 downto 0)  := (others => '0');
  signal req_wdata_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal req_rw_reg     : std_logic := '1';

  -- Bus-side timeout: last-resort guard if fpu_clk stops or FPU-side FSM sticks.
  -- Default 8192 bus_clk cycles (~82 us at 100 MHz). Cannot be disabled.
  constant BUS_TIMEOUT_C : natural := 8192;
  signal bus_timeout_cnt : natural range 0 to BUS_TIMEOUT_C := 0;

  -- Synchronizer for ack_toggle into bus_clk domain
  signal ack_ff1 : std_logic := '0';
  signal ack_ff2 : std_logic := '0';
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of ack_ff1 : signal is "TRUE";
  attribute ASYNC_REG of ack_ff2 : signal is "TRUE";

  -- Synchronizer for error flag into bus_clk domain
  signal err_ff1 : std_logic := '0';
  signal err_ff2 : std_logic := '0';
  attribute ASYNC_REG of err_ff1 : signal is "TRUE";
  attribute ASYNC_REG of err_ff2 : signal is "TRUE";

  -- Synchronizer for status_valid into bus_clk domain
  signal valid_ff1 : std_logic := '0';
  signal valid_ff2 : std_logic := '0';
  attribute ASYNC_REG of valid_ff1 : signal is "TRUE";
  attribute ASYNC_REG of valid_ff2 : signal is "TRUE";

  -- ========================================================================
  -- FPU-clk domain signals
  -- ========================================================================
  type fpu_state_t is (FPU_IDLE, FPU_SETUP, FPU_STROBE,
                        FPU_WAIT_DSACK, FPU_CAPTURE,
                        FPU_DEASSERT, FPU_ACK);
  signal fpu_state_reg : fpu_state_t := FPU_IDLE;

  signal ack_toggle_reg : std_logic := '0';
  signal fpu_error_reg  : std_logic := '0';  -- set on DSACK timeout

  -- Synchronizer for req_toggle into fpu_clk domain
  signal req_ff1 : std_logic := '0';
  signal req_ff2 : std_logic := '0';
  attribute ASYNC_REG of req_ff1 : signal is "TRUE";
  attribute ASYNC_REG of req_ff2 : signal is "TRUE";

  -- Latched request fields in fpu_clk domain
  signal fpu_addr_reg  : std_logic_vector(4 downto 0)  := (others => '0');
  signal fpu_wdata_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal fpu_rw_reg    : std_logic := '1';

  -- Read data captured in fpu_clk domain
  -- (stable before ack_toggle crosses back to bus_clk; bus-side read is safe
  -- because the 2-FF ack synchronizer guarantees data is settled)
  signal rdata_fpu_reg : std_logic_vector(31 downto 0) := (others => '0');

  -- DSACK timeout counter
  signal timeout_cnt_reg : natural range 0 to dsack_timeout_g := 0;

  -- Reset synchronizer (bus_reset_n → fpu_clk domain)
  signal rst_ff1 : std_logic := '0';
  signal rst_ff2 : std_logic := '0';
  attribute ASYNC_REG of rst_ff1 : signal is "TRUE";
  attribute ASYNC_REG of rst_ff2 : signal is "TRUE";

begin

  -- ========================================================================
  -- Bus-clock domain process
  -- ========================================================================
  p_bus_clk : process(bus_clk)
  begin
    if rising_edge(bus_clk) then
      -- Synchronize ack toggle
      ack_ff1 <= ack_toggle_reg;
      ack_ff2 <= ack_ff1;

      -- Synchronize error flag
      err_ff1 <= fpu_error_reg;
      err_ff2 <= err_ff1;

      -- Synchronize status_valid for IRQ
      valid_ff1 <= fpu_status_valid;
      valid_ff2 <= valid_ff1;

      bridge_done  <= '0';  -- default: no pulse
      bridge_error <= '0';

      if bus_reset_n = '0' then
        bus_state_reg   <= BUS_IDLE;
        req_toggle_reg  <= '0';
        bridge_done     <= '0';
        bridge_error    <= '0';
        bus_timeout_cnt <= 0;
      else
        case bus_state_reg is
          when BUS_IDLE =>
            bus_timeout_cnt <= 0;
            if bridge_req = '1' then
              req_addr_reg   <= bridge_addr;
              req_wdata_reg  <= bridge_wdata;
              req_rw_reg     <= bridge_rw;
              req_toggle_reg <= not req_toggle_reg;
              bus_state_reg  <= BUS_WAIT_ACK;
            end if;

          when BUS_WAIT_ACK =>
            if ack_ff2 = req_toggle_reg then
              bridge_rdata  <= rdata_fpu_reg;
              bridge_done   <= '1';
              bridge_error  <= err_ff2;
              bus_state_reg <= BUS_IDLE;
            elsif bus_timeout_cnt = BUS_TIMEOUT_C - 1 then
              -- Last-resort timeout: fpu_clk stopped or FPU-side stuck
              bridge_done   <= '1';
              bridge_error  <= '1';
              bus_state_reg <= BUS_IDLE;
            else
              bus_timeout_cnt <= bus_timeout_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process p_bus_clk;

  bridge_busy <= '1' when bus_state_reg = BUS_WAIT_ACK else '0';
  irq_out     <= valid_ff2;

  -- ========================================================================
  -- Reset synchronizer (bus_reset_n → fpu_clk)
  -- ========================================================================
  p_rst_sync : process(fpu_clk)
  begin
    if rising_edge(fpu_clk) then
      rst_ff1 <= bus_reset_n;
      rst_ff2 <= rst_ff1;
    end if;
  end process p_rst_sync;

  fpu_reset_n <= rst_ff2;

  -- ========================================================================
  -- FPU-clock domain process: M68K bus cycle generation
  -- ========================================================================
  -- SIZE and A0 both high select a 32-bit port (Table 9-2). Since this
  -- bridge always transfers full longwords and bridge_done only ORs
  -- dsack0_n/dsack1_n, the exact width encoding doesn't otherwise matter.
  fpu_size_n <= '1';
  fpu_a0_in  <= '1';

  p_fpu_clk : process(fpu_clk)
  begin
    if rising_edge(fpu_clk) then
      -- Synchronize req toggle
      req_ff1 <= req_toggle_reg;
      req_ff2 <= req_ff1;

      if rst_ff2 = '0' then
        fpu_state_reg   <= FPU_IDLE;
        ack_toggle_reg  <= '0';
        fpu_error_reg   <= '0';
        fpu_cs_n        <= '1';
        fpu_as_n        <= '1';
        fpu_ds_n        <= '1';
        fpu_rw          <= '1';
        fpu_a_in        <= (others => '0');
        fpu_d_in        <= (others => '0');
        timeout_cnt_reg <= 0;
      else
        case fpu_state_reg is
          when FPU_IDLE =>
            fpu_cs_n      <= '1';
            fpu_as_n      <= '1';
            fpu_ds_n      <= '1';
            fpu_rw        <= '1';
            -- Note: fpu_error_reg is NOT cleared here; it must remain stable
            -- until the bus side has sampled it via err_ff1/err_ff2 synchronizer.
            -- Clear only when a new request arrives (toggle handshake guarantees
            -- the bus side has already completed its BUS_WAIT_ACK sampling).
            if req_ff2 /= ack_toggle_reg then
              -- New request detected: latch fields from bus_clk domain.
              -- Safe because toggle handshake guarantees req_*_reg are stable
              -- (bus side is in BUS_WAIT_ACK and cannot modify them until ack returns).
              fpu_error_reg <= '0';
              fpu_addr_reg  <= req_addr_reg;
              fpu_wdata_reg <= req_wdata_reg;
              fpu_rw_reg    <= req_rw_reg;
              fpu_state_reg <= FPU_SETUP;
            end if;

          when FPU_SETUP =>
            fpu_a_in <= fpu_addr_reg;
            fpu_rw   <= fpu_rw_reg;
            if fpu_rw_reg = '0' then
              fpu_d_in <= fpu_wdata_reg;
            end if;
            fpu_cs_n        <= '0';
            fpu_as_n        <= '0';
            timeout_cnt_reg <= 0;
            fpu_state_reg   <= FPU_STROBE;

          when FPU_STROBE =>
            fpu_ds_n      <= '0';
            fpu_state_reg <= FPU_WAIT_DSACK;

          when FPU_WAIT_DSACK =>
            if fpu_dsack0_n = '0' or fpu_dsack1_n = '0' then
              fpu_state_reg <= FPU_CAPTURE;
            elsif dsack_timeout_g > 0 and timeout_cnt_reg = dsack_timeout_g - 1 then
              -- Timeout: abort bus cycle with error
              fpu_error_reg <= '1';
              fpu_ds_n      <= '1';
              fpu_state_reg <= FPU_DEASSERT;
            else
              timeout_cnt_reg <= timeout_cnt_reg + 1;
            end if;

          when FPU_CAPTURE =>
            if fpu_rw_reg = '1' then
              rdata_fpu_reg <= fpu_d_out;
            end if;
            fpu_ds_n <= '1';
            fpu_state_reg <= FPU_DEASSERT;

          when FPU_DEASSERT =>
            fpu_cs_n <= '1';
            fpu_as_n <= '1';
            fpu_state_reg <= FPU_ACK;

          when FPU_ACK =>
            ack_toggle_reg <= not ack_toggle_reg;
            fpu_state_reg  <= FPU_IDLE;
        end case;
      end if;
    end if;
  end process p_fpu_clk;

end architecture rtl;
