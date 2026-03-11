-- tb_mc68881_wishbone.vhd
-- Testbench for mc68881_wishbone_wrapper: dual-clock Wishbone B4 stimulus
-- exercising CDC bridge, FPU operations, cyc abort recovery, and IRQ.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_wishbone is
end entity tb_mc68881_wishbone;

architecture sim of tb_mc68881_wishbone is

  constant BUS_CLK_PERIOD : time := 10 ns;   -- 100 MHz
  constant FPU_CLK_PERIOD : time := 30 ns;   -- ~33 MHz

  -- Wishbone signals
  signal wb_clk   : std_logic := '0';
  signal wb_rst   : std_logic := '1';
  signal wb_adr   : std_logic_vector(6 downto 0) := (others => '0');
  signal wb_dat_i : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_dat_o : std_logic_vector(31 downto 0);
  signal wb_we    : std_logic := '0';
  signal wb_sel   : std_logic_vector(3 downto 0) := "1111";
  signal wb_stb   : std_logic := '0';
  signal wb_cyc   : std_logic := '0';
  signal wb_ack   : std_logic;
  signal wb_stall : std_logic;
  signal wb_err   : std_logic;
  signal fpu_clk  : std_logic := '0';
  signal irq      : std_logic;

  signal test_pass_count : natural := 0;

  -- Register byte addresses (reg_index * 4)
  constant WB_ADDR_OPSEL  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(0  * 4, 7));
  constant WB_ADDR_OPA_L  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(1  * 4, 7));
  constant WB_ADDR_OPA_H  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(2  * 4, 7));
  constant WB_ADDR_OPA_E  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(3  * 4, 7));
  constant WB_ADDR_OPB_L  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(4  * 4, 7));
  constant WB_ADDR_OPB_H  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(5  * 4, 7));
  constant WB_ADDR_OPB_E  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(6  * 4, 7));
  constant WB_ADDR_RES_L  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(7  * 4, 7));
  constant WB_ADDR_RES_H  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(8  * 4, 7));
  constant WB_ADDR_RES_E  : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(9  * 4, 7));
  constant WB_ADDR_STATUS       : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(10 * 4, 7));
  constant WB_ADDR_CIR_RESPONSE : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(13 * 4, 7));

  constant OP_ADD : std_logic_vector(31 downto 0) := x"00000001";

  -- ========================================================================
  -- Wishbone transaction procedures
  -- ========================================================================

  procedure wb_write_txn(
    signal clk     : in  std_logic;
    signal adr     : out std_logic_vector(6 downto 0);
    signal dat_o   : out std_logic_vector(31 downto 0);
    signal we_o    : out std_logic;
    signal stb_o   : out std_logic;
    signal cyc_o   : out std_logic;
    signal ack_i   : in  std_logic;
    signal err_i   : in  std_logic;
    signal stall_i : in  std_logic;
    constant addr  : std_logic_vector(6 downto 0);
    constant data  : std_logic_vector(31 downto 0);
    variable is_err : out boolean
  ) is
  begin
    adr   <= addr;
    dat_o <= data;
    we_o  <= '1';
    stb_o <= '1';
    cyc_o <= '1';
    wait until rising_edge(clk) and (ack_i = '1' or err_i = '1');
    is_err := (err_i = '1');
    stb_o <= '0';
    cyc_o <= '0';
    we_o  <= '0';
    wait until rising_edge(clk);
  end procedure;

  procedure wb_write_ok(
    signal clk     : in  std_logic;
    signal adr     : out std_logic_vector(6 downto 0);
    signal dat_o   : out std_logic_vector(31 downto 0);
    signal we_o    : out std_logic;
    signal stb_o   : out std_logic;
    signal cyc_o   : out std_logic;
    signal ack_i   : in  std_logic;
    signal err_i   : in  std_logic;
    signal stall_i : in  std_logic;
    constant addr  : std_logic_vector(6 downto 0);
    constant data  : std_logic_vector(31 downto 0)
  ) is
    variable err : boolean;
  begin
    wb_write_txn(clk, adr, dat_o, we_o, stb_o, cyc_o, ack_i, err_i, stall_i,
                 addr, data, err);
    assert not err
      report "WB write to " & to_hstring(addr) & " got ERR"
      severity failure;
  end procedure;

  procedure wb_read_txn(
    signal clk     : in  std_logic;
    signal adr     : out std_logic_vector(6 downto 0);
    signal we_o    : out std_logic;
    signal stb_o   : out std_logic;
    signal cyc_o   : out std_logic;
    signal dat_i   : in  std_logic_vector(31 downto 0);
    signal ack_i   : in  std_logic;
    signal err_i   : in  std_logic;
    signal stall_i : in  std_logic;
    constant addr  : std_logic_vector(6 downto 0);
    variable data  : out std_logic_vector(31 downto 0);
    variable is_err : out boolean
  ) is
  begin
    adr   <= addr;
    we_o  <= '0';
    stb_o <= '1';
    cyc_o <= '1';
    wait until rising_edge(clk) and (ack_i = '1' or err_i = '1');
    data   := dat_i;
    is_err := (err_i = '1');
    stb_o <= '0';
    cyc_o <= '0';
    wait until rising_edge(clk);
  end procedure;

  procedure wb_read_ok(
    signal clk     : in  std_logic;
    signal adr     : out std_logic_vector(6 downto 0);
    signal we_o    : out std_logic;
    signal stb_o   : out std_logic;
    signal cyc_o   : out std_logic;
    signal dat_i   : in  std_logic_vector(31 downto 0);
    signal ack_i   : in  std_logic;
    signal err_i   : in  std_logic;
    signal stall_i : in  std_logic;
    constant addr  : std_logic_vector(6 downto 0);
    variable data  : out std_logic_vector(31 downto 0)
  ) is
    variable err : boolean;
  begin
    wb_read_txn(clk, adr, we_o, stb_o, cyc_o, dat_i, ack_i, err_i, stall_i,
                addr, data, err);
    assert not err
      report "WB read from " & to_hstring(addr) & " got ERR"
      severity failure;
  end procedure;

  procedure wb_write_fp80(
    signal clk     : in  std_logic;
    signal adr     : out std_logic_vector(6 downto 0);
    signal dat_o   : out std_logic_vector(31 downto 0);
    signal we_o    : out std_logic;
    signal stb_o   : out std_logic;
    signal cyc_o   : out std_logic;
    signal ack_i   : in  std_logic;
    signal err_i   : in  std_logic;
    signal stall_i : in  std_logic;
    constant base_reg : natural;
    constant operand  : fp80_t
  ) is
  begin
    wb_write_ok(clk, adr, dat_o, we_o, stb_o, cyc_o, ack_i, err_i, stall_i,
                std_logic_vector(to_unsigned(base_reg * 4, 7)),
                operand(31 downto 0));
    wb_write_ok(clk, adr, dat_o, we_o, stb_o, cyc_o, ack_i, err_i, stall_i,
                std_logic_vector(to_unsigned((base_reg + 1) * 4, 7)),
                operand(63 downto 32));
    wb_write_ok(clk, adr, dat_o, we_o, stb_o, cyc_o, ack_i, err_i, stall_i,
                std_logic_vector(to_unsigned((base_reg + 2) * 4, 7)),
                x"0000" & operand(79 downto 64));
  end procedure;

  procedure wb_read_fp80(
    signal clk     : in  std_logic;
    signal adr     : out std_logic_vector(6 downto 0);
    signal we_o    : out std_logic;
    signal stb_o   : out std_logic;
    signal cyc_o   : out std_logic;
    signal dat_i   : in  std_logic_vector(31 downto 0);
    signal ack_i   : in  std_logic;
    signal err_i   : in  std_logic;
    signal stall_i : in  std_logic;
    variable result : out fp80_t
  ) is
    variable lo, hi, ex : std_logic_vector(31 downto 0);
  begin
    wb_read_ok(clk, adr, we_o, stb_o, cyc_o, dat_i, ack_i, err_i, stall_i,
               WB_ADDR_RES_L, lo);
    wb_read_ok(clk, adr, we_o, stb_o, cyc_o, dat_i, ack_i, err_i, stall_i,
               WB_ADDR_RES_H, hi);
    wb_read_ok(clk, adr, we_o, stb_o, cyc_o, dat_i, ack_i, err_i, stall_i,
               WB_ADDR_RES_E, ex);
    result := ex(15 downto 0) & hi & lo;
  end procedure;

  procedure wb_wait_valid(
    signal clk     : in  std_logic;
    signal adr     : out std_logic_vector(6 downto 0);
    signal we_o    : out std_logic;
    signal stb_o   : out std_logic;
    signal cyc_o   : out std_logic;
    signal dat_i   : in  std_logic_vector(31 downto 0);
    signal ack_i   : in  std_logic;
    signal err_i   : in  std_logic;
    signal stall_i : in  std_logic;
    constant max_polls : natural := 500
  ) is
    variable status : std_logic_vector(31 downto 0);
  begin
    for i in 1 to max_polls loop
      wb_read_ok(clk, adr, we_o, stb_o, cyc_o, dat_i, ack_i, err_i, stall_i,
                 WB_ADDR_STATUS, status);
      if status(0) = '1' then
        return;
      end if;
    end loop;
    assert false report "WB: timed out waiting for FPU valid" severity failure;
  end procedure;

begin

  -- Clock generation
  wb_clk  <= not wb_clk  after BUS_CLK_PERIOD / 2;
  fpu_clk <= not fpu_clk after FPU_CLK_PERIOD / 2;

  -- DUT
  dut : entity work.mc68881_wishbone_wrapper
    generic map (
      packed_decimal_full_g => true,
      dsack_timeout_g       => 1024
    )
    port map (
      wb_clk_i   => wb_clk,
      wb_rst_i   => wb_rst,
      wb_adr_i   => wb_adr,
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_we_i    => wb_we,
      wb_sel_i   => wb_sel,
      wb_stb_i   => wb_stb,
      wb_cyc_i   => wb_cyc,
      wb_ack_o   => wb_ack,
      wb_stall_o => wb_stall,
      wb_err_o   => wb_err,
      fpu_clk    => fpu_clk,
      irq        => irq
    );

  -- Stimulus
  p_stim : process
    variable rd_data  : std_logic_vector(31 downto 0);
    variable result   : fp80_t;
    variable expected : fp80_t;
    variable op_a     : fp80_t;
    variable op_b     : fp80_t;
  begin
    -- Reset
    wb_rst <= '1';
    wait for 10 * BUS_CLK_PERIOD;
    wb_rst <= '0';
    wait for 10 * BUS_CLK_PERIOD;

    -- Disable CIR mode so overlapping addresses route to peripheral decode
    wb_write_ok(wb_clk, wb_adr, wb_dat_i, wb_we, wb_stb, wb_cyc,
                wb_ack, wb_err, wb_stall,
                WB_ADDR_CIR_RESPONSE, x"00000000");

    -- ==================================================================
    report "=== WB TEST 1: STATUS read after reset ===" severity note;
    -- ==================================================================
    wb_read_ok(wb_clk, wb_adr, wb_we, wb_stb, wb_cyc,
               wb_dat_o, wb_ack, wb_err, wb_stall,
               WB_ADDR_STATUS, rd_data);
    report "STATUS after reset: " & to_hstring(rd_data) severity note;
    assert rd_data(1) = '0'
      report "STATUS busy should be 0 after reset"
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ==================================================================
    report "=== WB TEST 2: FPU ADD (10 + 5 = 15) ===" severity note;
    -- ==================================================================
    op_a := fp80_from_int(10);
    op_b := fp80_from_int(5);
    expected := add_sub_fp80(op_a, op_b, false, FP_RND_NEAREST, FP_PREC_EXTENDED);

    wb_write_fp80(wb_clk, wb_adr, wb_dat_i, wb_we, wb_stb, wb_cyc,
                  wb_ack, wb_err, wb_stall, 1, op_a);
    wb_write_fp80(wb_clk, wb_adr, wb_dat_i, wb_we, wb_stb, wb_cyc,
                  wb_ack, wb_err, wb_stall, 4, op_b);
    wb_write_ok(wb_clk, wb_adr, wb_dat_i, wb_we, wb_stb, wb_cyc,
                wb_ack, wb_err, wb_stall,
                WB_ADDR_OPSEL, OP_ADD);

    wb_wait_valid(wb_clk, wb_adr, wb_we, wb_stb, wb_cyc,
                  wb_dat_o, wb_ack, wb_err, wb_stall);

    wb_read_fp80(wb_clk, wb_adr, wb_we, wb_stb, wb_cyc,
                 wb_dat_o, wb_ack, wb_err, wb_stall, result);
    report "ADD result:   " & to_hstring(result) severity note;
    report "ADD expected: " & to_hstring(expected) severity note;
    assert result = expected
      report "ADD MISMATCH" severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ==================================================================
    report "=== WB TEST 3: IRQ asserted after operation ===" severity note;
    -- ==================================================================
    wait for 5 * BUS_CLK_PERIOD;
    assert irq = '1'
      report "IRQ should be asserted after operation completes"
      severity failure;
    test_pass_count <= test_pass_count + 1;

    -- ==================================================================
    report "=== WB TEST 4: cyc abort + recovery ===" severity note;
    -- ==================================================================
    -- Start a write, then abort by deasserting cyc mid-transaction
    wb_adr   <= WB_ADDR_OPA_L;
    wb_dat_i <= x"12345678";
    wb_we    <= '1';
    wb_stb   <= '1';
    wb_cyc   <= '1';
    -- Wait 3 cycles (bridge should be processing by now)
    wait until rising_edge(wb_clk);
    wait until rising_edge(wb_clk);
    wait until rising_edge(wb_clk);
    -- Abort: deassert cyc
    wb_cyc <= '0';
    wb_stb <= '0';
    wb_we  <= '0';
    wait until rising_edge(wb_clk);
    -- Wait for stall to drop (bridge finishes draining the aborted transaction)
    for i in 1 to 500 loop
      wait until rising_edge(wb_clk);
      exit when wb_stall = '0';
    end loop;
    assert wb_stall = '0'
      report "Stall should drop after bridge drains aborted transaction"
      severity failure;
    report "Bridge drained after cyc abort, stall released" severity note;

    -- Verify recovery: do a normal STATUS read
    wb_read_ok(wb_clk, wb_adr, wb_we, wb_stb, wb_cyc,
               wb_dat_o, wb_ack, wb_err, wb_stall,
               WB_ADDR_STATUS, rd_data);
    report "Post-abort STATUS read OK: " & to_hstring(rd_data) severity note;
    test_pass_count <= test_pass_count + 1;

    -- ==================================================================
    report "=== WB TEST 5: Back-to-back reads ===" severity note;
    -- ==================================================================
    wb_read_ok(wb_clk, wb_adr, wb_we, wb_stb, wb_cyc,
               wb_dat_o, wb_ack, wb_err, wb_stall,
               WB_ADDR_RES_L, rd_data);
    wb_read_ok(wb_clk, wb_adr, wb_we, wb_stb, wb_cyc,
               wb_dat_o, wb_ack, wb_err, wb_stall,
               WB_ADDR_RES_H, rd_data);
    wb_read_ok(wb_clk, wb_adr, wb_we, wb_stb, wb_cyc,
               wb_dat_o, wb_ack, wb_err, wb_stall,
               WB_ADDR_RES_E, rd_data);
    report "Back-to-back reads completed successfully" severity note;
    test_pass_count <= test_pass_count + 1;

    -- ==================================================================
    -- Summary
    -- ==================================================================
    wait for 10 * BUS_CLK_PERIOD;
    report "=== WISHBONE WRAPPER TB: " & integer'image(test_pass_count) &
           " tests passed. No failures detected. ===" severity note;
    std.env.finish;
  end process p_stim;

end architecture sim;
