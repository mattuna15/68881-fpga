-- CIR register map per MC68881UM Table 9-1 (datasheet_cir_map_g = true).
--
-- In CIR mode the DUT must decode exactly the Table 9-1 registers on
-- a_in(3 downto 0) = A4..A1 (a_in(4) is not a CIR address bit):
--   0 Response (R)      1 Control (W)     2 Save (R)        3 Restore (R/W)
--   4 Operation word(W) 5 Command (W)     7 Condition (W)   8 Operand (R/W)
--  10 Register select(R) 12 Instruction address (W)  14 Operand address (R/W)
-- and nothing else: no legacy peripheral register may be reachable.  A write
-- to the Response CIR (reserved on silicon) switches to peripheral mode, where
-- the legacy register map is decoded as before.
--
-- Dialogs are run the way a CPU runs them: write Operation word and Command,
-- then poll the Response CIR and service transfer primitives until it reads
-- null with CA=0.  No STATUS polling and no legacy back-door reads in CIR mode.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_cir_datasheet_map is
end entity tb_mc68881_cir_datasheet_map;

architecture sim of tb_mc68881_cir_datasheet_map is
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

  -- Table 9-1 register codes (A4..A1).
  constant DS_RESPONSE  : natural := 0;
  constant DS_CONTROL   : natural := 1;
  constant DS_SAVE      : natural := 2;
  constant DS_RESTORE   : natural := 3;
  constant DS_OPWORD    : natural := 4;
  constant DS_COMMAND   : natural := 5;
  constant DS_CONDITION : natural := 7;
  constant DS_OPERAND   : natural := 8;
  constant DS_REGSELECT : natural := 10;
  constant DS_INSTADDR  : natural := 12;
  constant DS_OPADDR    : natural := 14;

  -- Legacy peripheral-mode codes used to prove the mode switch.
  constant LEG_FPCR     : natural := 11;
  constant LEG_RESPONSE : natural := 13;
  constant LEG_FPIAR    : natural := 24;
  constant LEG_STATUS   : natural := 10;

  -- Port widths.
  constant P32 : natural := 32;
  constant P16 : natural := 16;
  constant P8  : natural := 8;

  constant OPC_FMOVE : std_logic_vector(6 downto 0) := "0000000";
  constant OPC_FADD  : std_logic_vector(6 downto 0) := "0100010";
  constant OPC_FMUL  : std_logic_vector(6 downto 0) := "0100011";
  constant OPC_FCMP  : std_logic_vector(6 downto 0) := "0111000";

  constant CPBCC_W_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPBCC_W & "000000";
  constant FCC_EQ : std_logic_vector(5 downto 0) := "000001";
  constant FCC_NE : std_logic_vector(5 downto 0) := "001110";

  -- Spurious-launch monitor: counts op_issue_pulse while mon_en is true.
  signal mon_en       : boolean := false;
  signal spurious_cnt : natural := 0;

  constant CPGEN_OPWORD : std_logic_vector(31 downto 0) := x"00000000";
  constant CPSAVE_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPSAVE & "000000";
  constant CPRESTORE_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPRESTORE & "000000";

  type word_array_t is array (natural range <>) of std_logic_vector(31 downto 0);

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

begin
  clk <= not clk after CLK_PERIOD/2;

  -- Watches the DUT's ALU launch strobe (VHDL-2008 external name) so the
  -- mode-switch tests can prove no operation is issued by the switch itself.
  issue_mon : process(clk)
    alias op_issue is << signal .tb_mc68881_cir_datasheet_map.dut.op_issue_pulse : std_logic >>;
  begin
    if rising_edge(clk) then
      if mon_en and op_issue = '1' then
        spurious_cnt <= spurious_cnt + 1;
        report "issue_mon: op_issue_pulse during mode-switch window" severity note;
      end if;
    end if;
  end process;

  dut : entity work.mc68881_top
    generic map (
      datasheet_cir_map_g => true
    )
    port map (
      a_in     => a_in,
      d_in     => d_in,
      d_out    => d_out,
      size_n   => size_n,
      a0_in    => a0_in,
      as_n     => as_n,
      cs_n     => cs_n,
      rw       => rw,
      ds_n     => ds_n,
      dsack0_n => dsack0_n,
      dsack1_n => dsack1_n,
      reset_n  => reset_n,
      clk      => clk,
      sense_n  => sense_n
    );

  process
    variable rd    : std_logic_vector(31 downto 0);
    variable outw  : word_array_t(0 to 2);
    variable frame : word_array_t(0 to CIR_FRAME_IDLE_WORDS - 1);
    variable nout  : natural;

    -- One bus beat; returns the sampled d_out on reads.
    procedure beat(code : std_logic_vector(4 downto 0); a0 : std_logic;
                   szn : std_logic; wr : boolean;
                   data : std_logic_vector(31 downto 0);
                   variable q : out std_logic_vector(31 downto 0)) is
    begin
      a_in   <= code;
      a0_in  <= a0;
      size_n <= szn;
      d_in   <= data;
      if wr then rw <= '0'; else rw <= '1'; end if;
      cs_n <= '0'; as_n <= '0'; ds_n <= '0';
      wait until (dsack0_n = '0' or dsack1_n = '0') for 2 us;
      assert dsack0_n = '0' or dsack1_n = '0'
        report "DSACK timeout at code " & to_hstring(code) severity failure;
      wait for CLK_PERIOD/4;
      q := d_out;
      cs_n <= '1'; as_n <= '1'; ds_n <= '1'; rw <= '1';
      wait for CLK_PERIOD;
    end procedure;

    -- Access one item of nbytes (2 = 16-bit CIR, 4 = 32-bit CIR) through a
    -- port of width p.  Items are low-aligned in data/q (core convention).
    --   32-bit port: one beat.
    --   16-bit port: two beats repeating the item (current 16-bit convention).
    --   8-bit port : per MC68881UM Fig 10-2, byte k on lane k, A0 (and A1
    --                for 32-bit CIRs) select the byte; read bytes appear on
    --                every lane.
    procedure acc(code : natural; wr : boolean; p : natural; nbytes : natural;
                  data : std_logic_vector(31 downto 0);
                  variable q : out std_logic_vector(31 downto 0)) is
      variable c    : std_logic_vector(4 downto 0);
      variable dw   : std_logic_vector(31 downto 0);
      variable b    : std_logic_vector(31 downto 0);
      variable item : std_logic_vector(31 downto 0) := (others => '0');
      variable a0   : std_logic;
    begin
      c := std_logic_vector(to_unsigned(code, 5));
      if p = P32 then
        beat(c, '1', '1', wr, data, q);
      elsif p = P16 then
        beat(c, '0', '1', wr, data, b);
        q := b;
        beat(c, '0', '1', wr, data, b);
      else
        for k in 0 to nbytes - 1 loop
          c := std_logic_vector(to_unsigned(code, 5));
          if nbytes = 4 and k >= 2 then c(0) := '1'; end if;
          if k mod 2 = 1 then a0 := '1'; else a0 := '0'; end if;
          dw := x"A5A5A5A5";
          dw(31 - 8*k downto 24 - 8*k) :=
            data(8*nbytes - 1 - 8*k downto 8*nbytes - 8 - 8*k);
          beat(c, a0, '0', wr, dw, b);
          if not wr then
            assert b(31 downto 24) = b(23 downto 16) and b(31 downto 24) = b(7 downto 0)
              report "8-bit read byte not on every lane: " & to_hstring(b)
              severity failure;
            item(8*nbytes - 1 - 8*k downto 8*nbytes - 8 - 8*k) := b(31 downto 24);
          end if;
        end loop;
        q := item;
      end if;
    end procedure;

    procedure wr16(code : natural; p : natural; data : std_logic_vector(31 downto 0)) is
      variable dummy : std_logic_vector(31 downto 0);
    begin
      acc(code, true, p, 2, data, dummy);
    end procedure;

    procedure wr32(code : natural; p : natural; data : std_logic_vector(31 downto 0)) is
      variable dummy : std_logic_vector(31 downto 0);
    begin
      acc(code, true, p, 4, data, dummy);
    end procedure;

    procedure rd16(code : natural; p : natural; variable q : out std_logic_vector(31 downto 0)) is
    begin
      acc(code, false, p, 2, x"00000000", q);
    end procedure;

    procedure rd32(code : natural; p : natural; variable q : out std_logic_vector(31 downto 0)) is
    begin
      acc(code, false, p, 4, x"00000000", q);
    end procedure;

    -- CPU-style cpGEN dialog over port p.
    procedure dialog(p : natural; cmd : std_logic_vector(31 downto 0);
                     src : word_array_t; nsrc : natural;
                     variable dst : out word_array_t; variable ndst : out natural) is
      variable r    : std_logic_vector(31 downto 0);
      variable si   : natural := 0;
      variable di   : natural := 0;
      variable done : boolean := false;
      variable len  : natural;
    begin
      wr16(DS_OPWORD, p, CPGEN_OPWORD);
      wr16(DS_COMMAND, p, cmd);
      wait for 2 * CLK_PERIOD;
      for poll in 0 to 2000 loop
        rd16(DS_RESPONSE, p, r);
        len := to_integer(unsigned(r(7 downto 0))) / 4;
        if r(15 downto 0) = CIR_PRIM_NULL then
          done := true;
          exit;
        elsif r(15 downto 8) = x"96" then
          for i in 1 to len loop
            assert si < nsrc report "dialog: DUT asked for more source words" severity failure;
            wr32(DS_OPERAND, p, src(si));
            si := si + 1;
          end loop;
          wait for 2 * CLK_PERIOD;
        elsif r(15 downto 8) = x"B2" then
          for i in 1 to len loop
            rd32(DS_OPERAND, p, r);
            dst(di) := r;
            di := di + 1;
          end loop;
          wait for 2 * CLK_PERIOD;
        else
          assert r(15 downto 0) = CIR_PRIM_BUSY
            report "dialog: unexpected Response " & to_hstring(r(15 downto 0))
            severity failure;
        end if;
      end loop;
      assert done report "dialog: Response never returned null (CA=0)" severity failure;
      assert si = nsrc report "dialog: source words not all consumed" severity failure;
      ndst := di;
    end procedure;

    -- FMOVE.S #val,FPn ; returns nothing.
    procedure load_s(p : natural; fpn : natural; val : std_logic_vector(31 downto 0)) is
      variable w : word_array_t(0 to 2) := (val, x"00000000", x"00000000");
      variable o : word_array_t(0 to 2);
      variable n : natural;
    begin
      dialog(p, cmd_mem_to_reg(CIR_SRC_SINGLE, fpn, OPC_FMOVE), w, 1, o, n);
      assert n = 0 report "load_s: unexpected destination transfer" severity failure;
    end procedure;

    procedure op_s(p : natural; fpn : natural; opc : std_logic_vector(6 downto 0);
                   val : std_logic_vector(31 downto 0)) is
      variable w : word_array_t(0 to 2) := (val, x"00000000", x"00000000");
      variable o : word_array_t(0 to 2);
      variable n : natural;
    begin
      dialog(p, cmd_mem_to_reg(CIR_SRC_SINGLE, fpn, opc), w, 1, o, n);
    end procedure;

    -- FMOVE.S FPn,<ea>; returns the single.
    procedure store_s(p : natural; fpn : natural; variable q : out std_logic_vector(31 downto 0)) is
      variable w : word_array_t(0 to 2) := (others => x"00000000");
      variable o : word_array_t(0 to 2) := (others => x"00000000");
      variable n : natural;
    begin
      dialog(p, cmd_reg_to_mem(CIR_SRC_SINGLE, fpn), w, 0, o, n);
      assert n = 1 report "store_s: expected one destination word, got " &
        integer'image(n) severity failure;
      q := o(0);
    end procedure;

    procedure check(name : string; got, exp : std_logic_vector(31 downto 0)) is
    begin
      report name & ": expected=" & to_hstring(exp) & " observed=" & to_hstring(got)
        severity note;
      assert got = exp report "FAIL " & name & ": expected=" & to_hstring(exp) &
        " got=" & to_hstring(got) severity failure;
    end procedure;

    -- 32-bit port DSACK check for one code (read cycle).
    procedure check_dsack(name : string; code : natural; want32 : boolean) is
    begin
      a_in <= std_logic_vector(to_unsigned(code, 5));
      a0_in <= '1'; size_n <= '1'; rw <= '1';
      cs_n <= '0'; as_n <= '0'; ds_n <= '0';
      wait until (dsack0_n = '0' or dsack1_n = '0') for 2 us;
      if want32 then
        assert dsack0_n = '0' and dsack1_n = '0'
          report "FAIL " & name & ": expected 32-bit DSACK" severity failure;
      else
        assert dsack0_n = '1' and dsack1_n = '0'
          report "FAIL " & name & ": expected 16-bit DSACK" severity failure;
      end if;
      report name & ": dsack0_n=" & std_logic'image(dsack0_n) &
        " dsack1_n=" & std_logic'image(dsack1_n) severity note;
      cs_n <= '1'; as_n <= '1'; ds_n <= '1';
      wait for CLK_PERIOD;
    end procedure;
  begin
    reset_n <= '0';
    wait for 3 * CLK_PERIOD;
    reset_n <= '1';
    wait for 3 * CLK_PERIOD;

    -- ==============================================================
    -- DS1: 32-bit host dialogs on Table 9-1 codes only.
    --   FMOVE.S #3.0,FP1 ; FADD.S #2.0,FP1 ; FMOVE.S FP1 -> 5.0
    -- ==============================================================
    report "DS1: 32-bit dialogs on datasheet codes" severity note;
    rd16(DS_RESPONSE, P32, rd);
    check("DS1 idle Response", x"0000" & rd(15 downto 0), x"0000" & CIR_PRIM_NULL);
    load_s(P32, 1, x"40400000");
    op_s(P32, 1, OPC_FADD, x"40000000");
    store_s(P32, 1, rd);
    check("DS1 FADD 3+2", rd, x"40A00000");

    -- ==============================================================
    -- DS2: 8-bit host dialog (byte lanes) on datasheet codes.
    -- ==============================================================
    report "DS2: 8-bit dialogs on datasheet codes" severity note;
    load_s(P8, 2, x"40490FDB");
    store_s(P8, 2, rd);
    check("DS2 8-bit FMOVE.S round trip", rd, x"40490FDB");
    store_s(P32, 2, rd);
    check("DS2 8-bit load read via 32-bit", rd, x"40490FDB");

    -- ==============================================================
    -- DS3: 16-bit host dialog on datasheet codes.  10.0 * 0.5 = 5.0
    -- ==============================================================
    report "DS3: 16-bit dialogs on datasheet codes" severity note;
    load_s(P16, 3, x"41200000");
    op_s(P16, 3, OPC_FMUL, x"3F000000");
    store_s(P16, 3, rd);
    check("DS3 16-bit FMUL 10*0.5", rd, x"40A00000");

    -- ==============================================================
    -- DS4: no legacy register is reachable in CIR mode, and no CIR
    -- aliases another.
    -- ==============================================================
    report "DS4: legacy map not decoded in CIR mode" severity note;
    rd16(DS_REGSELECT, P32, rd);
    check("DS4 code 10 is Register Select, not STATUS", rd, x"00000000");
    rd32(LEG_RESPONSE, P32, rd);
    check("DS4 code 13 (legacy Response) reads nothing", rd, x"00000000");
    rd32(DS_INSTADDR, P32, rd);
    check("DS4 code 12 (Instruction Address, W) does not read Save", rd, x"00000000");
    rd16(DS_CONDITION, P32, rd);
    check("DS4 code 7 (Condition, W) does not read a result", rd, x"00000000");
    rd16(16, P32, rd);
    check("DS4 a_in(4) is not a CIR address bit (16 = Response)",
          x"0000" & rd(15 downto 0), x"0000" & CIR_PRIM_NULL);
    -- A write to legacy code 13 is Instruction Address low half, not the
    -- mode back door: CIR mode must survive it.
    wr16(LEG_RESPONSE, P32, x"00000000");
    rd16(DS_RESPONSE, P32, rd);
    check("DS4 legacy code-13 write keeps CIR mode",
          x"0000" & rd(15 downto 0), x"0000" & CIR_PRIM_NULL);
    -- A write to legacy FPCR (code 11) in CIR mode must be ignored (checked
    -- from peripheral mode in DS5).
    wr32(LEG_FPCR, P32, x"00000030");
    -- Operand Address CIR is read/write at code 14 (not FPSR).
    wr32(DS_OPADDR, P32, x"12345678");
    rd32(DS_OPADDR, P32, rd);
    check("DS4 Operand Address read back", rd, x"12345678");
    -- The dialog still works after all of that.
    store_s(P32, 1, rd);
    check("DS4 FP1 intact", rd, x"40A00000");

    -- ==============================================================
    -- DS5: write to the Response CIR selects peripheral mode; the legacy
    -- map is decoded there and the legacy back door returns to CIR mode.
    -- ==============================================================
    report "DS5: Response write -> peripheral mode and back" severity note;
    wr16(DS_RESPONSE, P32, x"00000000");
    rd32(LEG_FPCR, P32, rd);
    check("DS5 FPCR untouched by CIR-mode write to code 11", rd, x"00000000");
    wr32(LEG_FPCR, P32, x"00000010");
    rd32(LEG_FPCR, P32, rd);
    check("DS5 FPCR writable in peripheral mode", rd, x"00000010");
    wr32(LEG_FPCR, P32, x"00000000");
    wr32(LEG_RESPONSE, P32, x"00000001");
    rd16(DS_RESPONSE, P32, rd);
    check("DS5 back in CIR mode", x"0000" & rd(15 downto 0), x"0000" & CIR_PRIM_NULL);
    rd32(LEG_FPCR, P32, rd);
    check("DS5 FPCR not decoded in CIR mode", rd, x"00000000");

    -- ==============================================================
    -- DS6: 8-bit host writes Instruction Address and Operand Address.
    -- ==============================================================
    report "DS6: 8-bit Instruction/Operand Address" severity note;
    wr32(DS_INSTADDR, P8, x"00ABCDEF");
    wr32(DS_OPADDR, P8, x"CAFEF00D");
    rd32(DS_OPADDR, P8, rd);
    check("DS6 8-bit Operand Address round trip", rd, x"CAFEF00D");
    wr16(DS_RESPONSE, P32, x"00000000");          -- peripheral mode
    rd32(LEG_FPIAR, P32, rd);
    check("DS6 8-bit Instruction Address reached FPIAR", rd, x"00ABCDEF");
    wr32(LEG_RESPONSE, P32, x"00000001");         -- back to CIR mode

    report "DS6b: 16-bit Instruction/Operand Address" severity note;
    wr32(DS_INSTADDR, P16, x"00123456");
    wr32(DS_OPADDR, P16, x"89ABCDEF");
    rd32(DS_OPADDR, P16, rd);
    check("DS6b 16-bit Operand Address round trip", rd, x"89ABCDEF");
    wr16(DS_RESPONSE, P32, x"00000000");
    rd32(LEG_FPIAR, P32, rd);
    check("DS6b 16-bit Instruction Address reached FPIAR", rd, x"00123456");
    wr32(LEG_RESPONSE, P32, x"00000001");

    report "DS6c: 32-bit Instruction/Operand Address" severity note;
    wr32(DS_INSTADDR, P32, x"00FEDCBA");
    wr32(DS_OPADDR, P32, x"0BADBEEF");
    rd32(DS_OPADDR, P32, rd);
    check("DS6c 32-bit Operand Address round trip", rd, x"0BADBEEF");
    wr16(DS_RESPONSE, P32, x"00000000");
    rd32(LEG_FPIAR, P32, rd);
    check("DS6c 32-bit Instruction Address reached FPIAR", rd, x"00FEDCBA");
    wr32(LEG_RESPONSE, P32, x"00000001");

    -- ==============================================================
    -- DS7: DSACK uses A4 = a_in(3) only.
    -- ==============================================================
    report "DS7: 32-bit port DSACK from A4" severity note;
    check_dsack("DS7 Operand (A4=1)", DS_OPERAND, true);
    check_dsack("DS7 Operation word (A4=0)", DS_OPWORD, false);
    check_dsack("DS7 code 20 aliases 4 (A4=0)", 20, false);

    -- ==============================================================
    -- DS8: FSAVE / FRESTORE through Save (2) and Restore (3).
    -- ==============================================================
    report "DS8: FSAVE/FRESTORE on codes 2/3" severity note;
    wr16(DS_OPWORD, P32, CPSAVE_OPWORD);
    wait for 4 * CLK_PERIOD;
    rd16(DS_SAVE, P32, rd);
    check("DS8 Save format word (idle)", x"0000" & rd(15 downto 0), x"0000" & CIR_FRAME_IDLE_FW);
    for i in 0 to CIR_FRAME_IDLE_WORDS - 1 loop
      rd32(DS_OPERAND, P32, frame(i));
    end loop;
    wait for 4 * CLK_PERIOD;
    wr16(DS_OPWORD, P32, CPRESTORE_OPWORD);
    wr16(DS_RESTORE, P32, x"0000" & CIR_FRAME_IDLE_FW);
    wait for 3 * CLK_PERIOD;
    for i in 0 to CIR_FRAME_IDLE_WORDS - 1 loop
      wr32(DS_OPERAND, P32, frame(i));
    end loop;
    wait for 6 * CLK_PERIOD;
    rd16(DS_RESPONSE, P32, rd);
    check("DS8 idle after FRESTORE", x"0000" & rd(15 downto 0), x"0000" & CIR_PRIM_NULL);
    store_s(P32, 1, rd);
    check("DS8 FP1 after save/restore", rd, x"40A00000");

    -- ==============================================================
    -- DS9: mode switch must not leak into the legacy decode mid-cycle.
    --   (a) 32-bit write of non-zero data to Response (code 0) leaves CIR
    --       mode without issuing an operation via the legacy OPSEL (0).
    --   (b) 8-bit host returning to CIR mode (legacy code 13, A0=1) must not
    --       fold into an Instruction Address write that clobbers FPIAR.
    --   (c) 8-bit host leaving CIR mode with non-zero data.
    -- ==============================================================
    report "DS9a: 32-bit Response write x00000002 -> peripheral, no launch" severity note;
    wait until rising_edge(clk);
    mon_en <= true;
    wr16(DS_RESPONSE, P32, x"00000002");
    wait for 4 * CLK_PERIOD;
    mon_en <= false;
    wait for 0 ns;
    check("DS9a op_issue_pulse count during 32-bit mode switch",
          std_logic_vector(to_unsigned(spurious_cnt, 32)), x"00000000");
    wr32(LEG_FPCR, P32, x"00000010");
    rd32(LEG_FPCR, P32, rd);
    check("DS9a peripheral mode reached (FPCR writable)", rd, x"00000010");
    wr32(LEG_FPCR, P32, x"00000000");

    report "DS9b: 8-bit return to CIR mode keeps FPIAR" severity note;
    wr32(LEG_FPIAR, P32, x"11111111");
    beat("01101", '1', '0', true, x"00000001", rd);   -- 8-bit, A0=1, code 13
    rd16(DS_RESPONSE, P32, rd);
    check("DS9b back in CIR mode", x"0000" & rd(15 downto 0), x"0000" & CIR_PRIM_NULL);
    wr16(DS_RESPONSE, P32, x"00000000");
    rd32(LEG_FPIAR, P32, rd);
    check("DS9b FPIAR survives 8-bit return to CIR mode", rd, x"11111111");
    wr32(LEG_RESPONSE, P32, x"00000001");

    report "DS9c: 8-bit Response write x0002 -> peripheral, no launch" severity note;
    wait until rising_edge(clk);
    mon_en <= true;
    wr16(DS_RESPONSE, P8, x"00000002");
    wait for 4 * CLK_PERIOD;
    mon_en <= false;
    wait for 0 ns;
    check("DS9c op_issue_pulse count during 8-bit mode switch",
          std_logic_vector(to_unsigned(spurious_cnt, 32)), x"00000000");
    wr32(LEG_FPCR, P32, x"00000010");
    rd32(LEG_FPCR, P32, rd);
    check("DS9c peripheral mode reached (FPCR writable)", rd, x"00000010");
    wr32(LEG_FPCR, P32, x"00000000");
    wr32(LEG_RESPONSE, P32, x"00000001");

    -- ==============================================================
    -- DS10: Condition CIR (code 7) via cpBcc, and Response-read clears
    -- cir_response_pending (STATUS bit 4, checked from peripheral mode).
    -- ==============================================================
    report "DS10: cpBcc via Condition CIR" severity note;
    load_s(P32, 4, x"3F800000");                       -- FP4 = 1.0
    op_s(P32, 4, OPC_FCMP, x"3F800000");               -- FCMP.S #1.0,FP4 -> Z
    wr16(DS_OPWORD, P32, CPBCC_W_OPWORD);
    wr16(DS_CONDITION, P32, x"000000" & "00" & FCC_EQ);
    wait for 40 * CLK_PERIOD;                          -- let evaluation finish
    wr16(DS_RESPONSE, P32, x"00000000");               -- peripheral (no read)
    rd32(LEG_STATUS, P32, rd);
    check("DS10 response pending before Response read (STATUS bit 4)",
          x"0000000" & "000" & rd(4), x"00000001");
    wr32(LEG_RESPONSE, P32, x"00000001");
    rd16(DS_RESPONSE, P32, rd);
    check("DS10 FBEQ cond_true/branch_taken", x"0000000" & "00" & rd(1 downto 0), x"00000003");
    check("DS10 FBEQ response done (CA=0)", x"0000000" & "000" & rd(15), x"00000000");
    wr16(DS_RESPONSE, P32, x"00000000");
    rd32(LEG_STATUS, P32, rd);
    check("DS10 Response read cleared pending (STATUS bit 4)",
          x"0000000" & "000" & rd(4), x"00000000");
    wr32(LEG_RESPONSE, P32, x"00000001");
    wr16(DS_OPWORD, P32, CPBCC_W_OPWORD);
    wr16(DS_CONDITION, P32, x"000000" & "00" & FCC_NE);
    wait for 40 * CLK_PERIOD;
    rd16(DS_RESPONSE, P32, rd);
    check("DS10 FBNE cond_true/branch_taken", x"0000000" & "00" & rd(1 downto 0), x"00000000");

    -- ==============================================================
    -- DS11: Control CIR (code 1) abort of a dialog waiting for an operand.
    -- ==============================================================
    report "DS11: Control abort mid-dialog" severity note;
    wr16(DS_OPWORD, P32, CPGEN_OPWORD);
    wr16(DS_COMMAND, P32, cmd_mem_to_reg(CIR_SRC_SINGLE, 5, OPC_FMOVE));
    wait for 4 * CLK_PERIOD;
    rd16(DS_RESPONSE, P32, rd);
    check("DS11 dialog requests a source operand", x"000000" & rd(15 downto 8), x"00000096");
    wr16(DS_CONTROL, P32, x"00000002");               -- abort
    wait for 6 * CLK_PERIOD;
    rd16(DS_RESPONSE, P32, rd);
    check("DS11 idle after Control abort", x"0000" & rd(15 downto 0), x"0000" & CIR_PRIM_NULL);
    op_s(P32, 1, OPC_FADD, x"00000000");               -- FP1 += 0 still works
    store_s(P32, 1, rd);
    check("DS11 dialog works after abort (FP1)", rd, x"40A00000");

    report "TB SUCCESS: datasheet CIR map checks passed" severity note;
    std.env.stop;
    wait;
  end process;
end architecture sim;
