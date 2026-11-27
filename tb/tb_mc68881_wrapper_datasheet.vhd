-- tb_mc68881_wrapper_datasheet.vhd
-- Plan step 6 (docs/plans/2026-11-19-true-cir-register-remap.md): the
-- AXI4-Lite and Wishbone wrappers with datasheet_cir_map_g => true.
--
-- The wrappers keep the word-stride aperture: bus byte address bits [6:2]
-- are the register code, so in CIR mode the MC68881UM Table 9-1 CIR with
-- code n sits at byte offset n*4 (Response $00, Control $04, Save $08,
-- Restore $0C, Operation Word $10, Command $14, Condition $1C, Operand $20,
-- Register Select $28, Instruction Address $30, Operand Address $38).
-- Offsets $40..$7C alias $00..$3C in CIR mode (A5 is not a CIR address bit).
--
-- Both buses run the same checks.  The Wishbone instance also uses the
-- MC68882 core (fpu_68882_g) so both wrapper instantiation branches carry
-- the generic.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_wrapper_datasheet is
end entity tb_mc68881_wrapper_datasheet;

architecture sim of tb_mc68881_wrapper_datasheet is

  constant BUS_CLK_PERIOD : time := 10 ns;   -- 100 MHz bus clock
  constant FPU_CLK_PERIOD : time := 30 ns;   -- ~33 MHz FPU clock

  signal bus_clk : std_logic := '0';
  signal fpu_clk : std_logic := '0';
  signal rst_n   : std_logic := '0';
  signal rst     : std_logic := '1';

  -- AXI4-Lite
  signal s_axi_awaddr  : std_logic_vector(6 downto 0) := (others => '0');
  signal s_axi_awvalid : std_logic := '0';
  signal s_axi_awready : std_logic;
  signal s_axi_wdata   : std_logic_vector(31 downto 0) := (others => '0');
  signal s_axi_wvalid  : std_logic := '0';
  signal s_axi_wready  : std_logic;
  signal s_axi_bresp   : std_logic_vector(1 downto 0);
  signal s_axi_bvalid  : std_logic;
  signal s_axi_bready  : std_logic := '0';
  signal s_axi_araddr  : std_logic_vector(6 downto 0) := (others => '0');
  signal s_axi_arvalid : std_logic := '0';
  signal s_axi_arready : std_logic;
  signal s_axi_rdata   : std_logic_vector(31 downto 0);
  signal s_axi_rresp   : std_logic_vector(1 downto 0);
  signal s_axi_rvalid  : std_logic;
  signal s_axi_rready  : std_logic := '0';
  signal axi_irq       : std_logic;

  -- Wishbone
  signal wb_adr   : std_logic_vector(6 downto 0) := (others => '0');
  signal wb_dat_i : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_dat_o : std_logic_vector(31 downto 0);
  signal wb_we    : std_logic := '0';
  signal wb_stb   : std_logic := '0';
  signal wb_cyc   : std_logic := '0';
  signal wb_ack   : std_logic;
  signal wb_stall : std_logic;
  signal wb_err   : std_logic;
  signal wb_irq   : std_logic;

  -- Bus selectors.
  constant BUS_AXI : natural := 0;
  constant BUS_WB  : natural := 1;

  -- Word-stride offsets (code * 4).
  constant OFF_RESPONSE  : natural := 0  * 4;
  constant OFF_OPWORD    : natural := 4  * 4;
  constant OFF_COMMAND   : natural := 5  * 4;
  constant OFF_OPERAND   : natural := 8  * 4;
  constant OFF_REGSELECT : natural := 10 * 4;
  constant OFF_OPADDR    : natural := 14 * 4;
  constant OFF_A5_OPADDR : natural := 30 * 4;    -- code 14 with A5 set
  -- Legacy peripheral-mode offsets.
  constant OFF_LEG_FPCR     : natural := 11 * 4;
  constant OFF_LEG_RESPONSE : natural := 13 * 4;

  constant OPC_FMOVE : std_logic_vector(6 downto 0) := "0000000";
  constant OPC_FADD  : std_logic_vector(6 downto 0) := "0100010";
  constant CPGEN_OPWORD : std_logic_vector(31 downto 0) := x"00000000";

  -- Memory-source cpGEN command (R/M=1): <ea>.fmt,FPn.
  function cmd_mem_to_reg(fmt : std_logic_vector(2 downto 0); dst : natural;
                          opc : std_logic_vector(6 downto 0))
    return std_logic_vector is
    variable c : std_logic_vector(31 downto 0) := (others => '0');
  begin
    c(14) := '1';
    c(12 downto 10) := fmt;
    c(9 downto 7) := std_logic_vector(to_unsigned(dst, 3));
    c(6 downto 0) := opc;
    return c;
  end function;

  -- FMOVE.fmt FPn,<ea> (R/M=1, direction=1).
  function cmd_reg_to_mem(fmt : std_logic_vector(2 downto 0); src : natural)
    return std_logic_vector is
    variable c : std_logic_vector(31 downto 0) := (others => '0');
  begin
    c(14) := '1';
    c(13) := '1';
    c(12 downto 10) := fmt;
    c(9 downto 7) := std_logic_vector(to_unsigned(src, 3));
    c(6 downto 0) := OPC_FMOVE;
    return c;
  end function;

  function bus_name(b : natural) return string is
  begin
    if b = BUS_AXI then return "AXI"; else return "WB"; end if;
  end function;

begin

  bus_clk <= not bus_clk after BUS_CLK_PERIOD / 2;
  fpu_clk <= not fpu_clk after FPU_CLK_PERIOD / 2;
  rst     <= not rst_n;

  dut_axi : entity work.mc68881_axilite_wrapper
    generic map (
      datasheet_cir_map_g => true
    )
    port map (
      s_axi_aclk    => bus_clk,
      s_axi_aresetn => rst_n,
      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awprot  => "000",
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => "1111",
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,
      s_axi_araddr  => s_axi_araddr,
      s_axi_arprot  => "000",
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready,
      fpu_clk       => fpu_clk,
      irq           => axi_irq
    );

  dut_wb : entity work.mc68881_wishbone_wrapper
    generic map (
      fpu_68882_g         => true,
      datasheet_cir_map_g => true
    )
    port map (
      wb_clk_i   => bus_clk,
      wb_rst_i   => rst,
      wb_adr_i   => wb_adr,
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_we_i    => wb_we,
      wb_sel_i   => "1111",
      wb_stb_i   => wb_stb,
      wb_cyc_i   => wb_cyc,
      wb_ack_o   => wb_ack,
      wb_stall_o => wb_stall,
      wb_err_o   => wb_err,
      fpu_clk    => fpu_clk,
      irq        => wb_irq
    );

  p_stim : process
    variable rd  : std_logic_vector(31 downto 0);
    variable st  : std_logic_vector(31 downto 0);
    variable fails : natural := 0;

    procedure check(name : string; got, exp : std_logic_vector(31 downto 0)) is
    begin
      report name & ": expected=" & to_hstring(exp) & " observed=" & to_hstring(got)
        severity note;
      assert got = exp
        report "FAIL " & name & ": expected=" & to_hstring(exp) & " got=" & to_hstring(got)
        severity failure;
    end procedure;

    procedure axi_wr(off : natural; data : std_logic_vector(31 downto 0)) is
      variable aw_done : boolean := false;
      variable w_done  : boolean := false;
    begin
      s_axi_awaddr  <= std_logic_vector(to_unsigned(off, 7));
      s_axi_awvalid <= '1';
      s_axi_wdata   <= data;
      s_axi_wvalid  <= '1';
      while not (aw_done and w_done) loop
        wait until rising_edge(bus_clk);
        if s_axi_awready = '1' then aw_done := true; end if;
        if s_axi_wready = '1' then w_done := true; end if;
      end loop;
      s_axi_awvalid <= '0';
      s_axi_wvalid  <= '0';
      s_axi_bready  <= '1';
      wait until rising_edge(bus_clk) and s_axi_bvalid = '1';
      assert s_axi_bresp = "00"
        report "FAIL AXI write @" & integer'image(off) & " bresp=" & to_hstring(s_axi_bresp)
        severity failure;
      wait until rising_edge(bus_clk);
      s_axi_bready <= '0';
    end procedure;

    procedure axi_rd(off : natural; variable q : out std_logic_vector(31 downto 0)) is
    begin
      s_axi_araddr  <= std_logic_vector(to_unsigned(off, 7));
      s_axi_arvalid <= '1';
      wait until rising_edge(bus_clk) and s_axi_arready = '1';
      s_axi_arvalid <= '0';
      s_axi_rready  <= '1';
      wait until rising_edge(bus_clk) and s_axi_rvalid = '1';
      q := s_axi_rdata;
      assert s_axi_rresp = "00"
        report "FAIL AXI read @" & integer'image(off) & " rresp=" & to_hstring(s_axi_rresp)
        severity failure;
      wait until rising_edge(bus_clk);
      s_axi_rready <= '0';
    end procedure;

    procedure wb_wr(off : natural; data : std_logic_vector(31 downto 0)) is
    begin
      wb_adr   <= std_logic_vector(to_unsigned(off, 7));
      wb_dat_i <= data;
      wb_we    <= '1';
      wb_stb   <= '1';
      wb_cyc   <= '1';
      wait until rising_edge(bus_clk) and (wb_ack = '1' or wb_err = '1');
      assert wb_err = '0'
        report "FAIL WB write @" & integer'image(off) & " got err" severity failure;
      wb_stb <= '0';
      wb_cyc <= '0';
      wb_we  <= '0';
      wait until rising_edge(bus_clk);
    end procedure;

    procedure wb_rd(off : natural; variable q : out std_logic_vector(31 downto 0)) is
    begin
      wb_adr <= std_logic_vector(to_unsigned(off, 7));
      wb_we  <= '0';
      wb_stb <= '1';
      wb_cyc <= '1';
      wait until rising_edge(bus_clk) and (wb_ack = '1' or wb_err = '1');
      q := wb_dat_o;
      assert wb_err = '0'
        report "FAIL WB read @" & integer'image(off) & " got err" severity failure;
      wb_stb <= '0';
      wb_cyc <= '0';
      wait until rising_edge(bus_clk);
    end procedure;

    procedure bwr(b : natural; off : natural; data : std_logic_vector(31 downto 0)) is
    begin
      if b = BUS_AXI then axi_wr(off, data); else wb_wr(off, data); end if;
    end procedure;

    procedure brd(b : natural; off : natural; variable q : out std_logic_vector(31 downto 0)) is
    begin
      if b = BUS_AXI then axi_rd(off, q); else wb_rd(off, q); end if;
    end procedure;

    -- One cpGEN dialog: OpWord, Command, then service Response primitives.
    -- src is the single-precision source (if requested); returns the first
    -- destination word (if any).
    procedure dialog(b : natural; cmd : std_logic_vector(31 downto 0);
                     src : std_logic_vector(31 downto 0);
                     variable dst : out std_logic_vector(31 downto 0)) is
      variable r    : std_logic_vector(31 downto 0);
      variable len  : natural;
      variable done : boolean := false;
      variable got  : std_logic_vector(31 downto 0) := (others => '0');
    begin
      bwr(b, OFF_OPWORD, CPGEN_OPWORD);
      bwr(b, OFF_COMMAND, cmd);
      for poll in 0 to 500 loop
        brd(b, OFF_RESPONSE, r);
        len := to_integer(unsigned(r(7 downto 0))) / 4;
        if r(15 downto 0) = CIR_PRIM_NULL then
          done := true;
          exit;
        elsif r(15 downto 8) = x"96" then
          for i in 1 to len loop
            if i = 1 then bwr(b, OFF_OPERAND, src); else bwr(b, OFF_OPERAND, x"00000000"); end if;
          end loop;
        elsif r(15 downto 8) = x"B2" then
          for i in 1 to len loop
            brd(b, OFF_OPERAND, r);
            if i = 1 then got := r; end if;
          end loop;
        else
          assert r(15 downto 0) = CIR_PRIM_BUSY
            report "FAIL " & bus_name(b) & " dialog: unexpected Response " & to_hstring(r(15 downto 0))
            severity failure;
        end if;
      end loop;
      assert done
        report "FAIL " & bus_name(b) & " dialog: Response never returned null" severity failure;
      dst := got;
    end procedure;

    procedure run_bus(b : natural) is
      variable q : std_logic_vector(31 downto 0);
      constant N : string := bus_name(b);
    begin
      report "=== " & N & " W1: idle Response at offset $00 ===" severity note;
      brd(b, OFF_RESPONSE, q);
      check(N & " W1 idle Response", x"0000" & q(15 downto 0), x"0000" & CIR_PRIM_NULL);

      report "=== " & N & " W2: CIR dialog 3.0 + 2.0 through word-stride CIRs ===" severity note;
      dialog(b, cmd_mem_to_reg(CIR_SRC_SINGLE, 1, OPC_FMOVE), x"40400000", q);
      dialog(b, cmd_mem_to_reg(CIR_SRC_SINGLE, 1, OPC_FADD),  x"40000000", q);
      dialog(b, cmd_reg_to_mem(CIR_SRC_SINGLE, 1), x"00000000", q);
      check(N & " W2 FMOVE.S FP1 after 3+2", q, x"40A00000");

      report "=== " & N & " W3: Operand Address round trip and A5 alias ===" severity note;
      bwr(b, OFF_OPADDR, x"CAFEF00D");
      brd(b, OFF_OPADDR, q);
      check(N & " W3 Operand Address at $38", q, x"CAFEF00D");
      brd(b, OFF_A5_OPADDR, q);
      check(N & " W3 offset $78 aliases Operand Address", q, x"CAFEF00D");

      report "=== " & N & " W4: no legacy decode in CIR mode ===" severity note;
      brd(b, OFF_REGSELECT, q);
      check(N & " W4 $28 is Register Select (reads 0), not STATUS", q, x"00000000");
      bwr(b, OFF_LEG_FPCR, x"00000010");          -- reserved code 11: ignored

      report "=== " & N & " W5: mode switch via $00, return via legacy $34 ===" severity note;
      bwr(b, OFF_RESPONSE, x"00000000");           -- leave CIR mode
      brd(b, OFF_LEG_FPCR, q);
      check(N & " W5 FPCR untouched by CIR-mode write to $2C", q, x"00000000");
      bwr(b, OFF_LEG_FPCR, x"00000020");
      brd(b, OFF_LEG_FPCR, q);
      check(N & " W5 FPCR writable in peripheral mode", q, x"00000020");
      bwr(b, OFF_LEG_FPCR, x"00000000");
      bwr(b, OFF_LEG_RESPONSE, x"00000001");       -- back to CIR mode
      brd(b, OFF_RESPONSE, q);
      check(N & " W5 back in CIR mode (Response idle)", x"0000" & q(15 downto 0), x"0000" & CIR_PRIM_NULL);
      dialog(b, cmd_reg_to_mem(CIR_SRC_SINGLE, 1), x"00000000", q);
      check(N & " W5 FP1 preserved across mode switches", q, x"40A00000");
    end procedure;

  begin
    rst_n <= '0';
    wait for 20 * BUS_CLK_PERIOD;
    rst_n <= '1';
    wait for 20 * FPU_CLK_PERIOD;

    run_bus(BUS_AXI);
    run_bus(BUS_WB);

    report "TB SUCCESS: wrapper datasheet CIR map checks passed" severity note;
    std.env.finish;
    wait;
  end process;

end architecture sim;
