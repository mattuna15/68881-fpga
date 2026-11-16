-- CIR dialog interruption testbench.
--
-- Covers what a main processor does when a coprocessor dialog is cut short:
-- a bus error in the middle of an operand transfer, after which the handler
-- either saves/restores the FPU (FSAVE/FRESTORE) or aborts the dialog with a
-- Control CIR write (MC68881 UM 7.2.2: any control write aborts).
--
-- Reference scenarios (found by cross-checking the RD68884 design's race list):
--   A. FSAVE while the FPU waits for a source operand (CIR_XFER_SRC).
--   B. FSAVE while the FPU waits for the host to read a result (CIR_XFER_DST).
--   C. Control CIR write in CIR_XFER_SRC: the instruction must not execute.
--   D. Control CIR write in CIR_XFER_DST.
--   E. FRESTORE (null frame) while in CIR_XFER_SRC.
-- After each one the dialog must be back at Null and an ordinary
-- FMOVE.L in / FMOVE.L out must still work.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_cir_interrupt is
end entity tb_mc68881_cir_interrupt;

architecture sim of tb_mc68881_cir_interrupt is
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

  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_RES_H  : unsigned(4 downto 0) := to_unsigned(8, 5);

  constant CIR_OPWORD    : unsigned(4 downto 0) := CIR_ADDR_OPWORD;
  constant CIR_COMMAND   : unsigned(4 downto 0) := CIR_ADDR_COMMAND;
  constant CIR_OPERAND   : unsigned(4 downto 0) := CIR_ADDR_OPERAND;
  constant CIR_MODE_RESP : unsigned(4 downto 0) := to_unsigned(13, 5);
  constant CIR_SAVE_ADDR    : unsigned(4 downto 0) := to_unsigned(12, 5);
  constant CIR_RESTORE_ADDR : unsigned(4 downto 0) := to_unsigned(28, 5);
  constant CIR_CONTROL_ADDR : unsigned(4 downto 0) := CIR_ADDR_CONTROL;

  constant RESP_NULL          : std_logic_vector(15 downto 0) := CIR_PRIM_NULL;
  constant RESP_XFER_TO_CP_4  : std_logic_vector(15 downto 0) := x"9604";
  constant RESP_XFER_FROM_CP_4: std_logic_vector(15 downto 0) := x"B204";

  constant CPGEN_OPWORD : std_logic_vector(31 downto 0) := x"00000000";
  constant CPSAVE_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPSAVE & "000000";
  constant CPRESTORE_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPRESTORE & "000000";

  constant OPCODE_FMOVE : std_logic_vector(6 downto 0) := "0000000";
  constant OPCODE_FADD  : std_logic_vector(6 downto 0) := "0100010";

begin
  clk <= not clk after CLK_PERIOD / 2;

  dut : entity work.mc68881_top
    port map (
      a_in => a_in, d_in => d_in, d_out => d_out, size_n => size_n,
      a0_in => a0_in, as_n => as_n, cs_n => cs_n, rw => rw, ds_n => ds_n,
      dsack0_n => dsack0_n, dsack1_n => dsack1_n, reset_n => reset_n,
      clk => clk, sense_n => sense_n
    );

  process
    variable rd_val : std_logic_vector(31 downto 0) := (others => '0');
    variable fw     : std_logic_vector(15 downto 0) := (others => '0');
    variable resp   : std_logic_vector(15 downto 0) := (others => '0');
    variable nwords : natural := 0;
    variable cmd    : std_logic_vector(15 downto 0) := (others => '0');

    procedure wr(constant addr_c : in unsigned(4 downto 0);
                 constant data   : in std_logic_vector(31 downto 0)) is
    begin
      a_in <= std_logic_vector(addr_c);
      d_in <= data;
      rw <= '0'; cs_n <= '0'; as_n <= '0'; ds_n <= '0';
      wait for CLK_PERIOD;
      cs_n <= '1'; as_n <= '1'; ds_n <= '1'; rw <= '1';
      wait for CLK_PERIOD;
    end procedure;

    procedure rd(constant addr_c : in unsigned(4 downto 0);
                 variable data   : out std_logic_vector(31 downto 0)) is
    begin
      a_in <= std_logic_vector(addr_c);
      rw <= '1'; cs_n <= '0'; as_n <= '0'; ds_n <= '0';
      -- Bounded wait: a dead DSACK is itself a failure of the interruption.
      for i in 0 to 255 loop
        wait for CLK_PERIOD / 4;
        exit when dsack0_n = '0' or dsack1_n = '0';
      end loop;
      assert dsack0_n = '0' or dsack1_n = '0'
        report "FAIL: no DSACK on read of CIR address " &
               integer'image(to_integer(addr_c))
        severity failure;
      wait for CLK_PERIOD / 4;
      data := d_out;
      wait for CLK_PERIOD / 4;
      cs_n <= '1'; as_n <= '1'; ds_n <= '1';
      wait for CLK_PERIOD;
    end procedure;

    procedure read_resp(variable r : out std_logic_vector(15 downto 0)) is
      variable v : std_logic_vector(31 downto 0);
    begin
      rd(CIR_MODE_RESP, v);
      r := v(15 downto 0);
    end procedure;

    -- Poll the response until Null; fail if it never gets there.
    procedure expect_null_soon(constant what : in string) is
      variable r : std_logic_vector(15 downto 0);
    begin
      for i in 0 to 200 loop
        read_resp(r);
        exit when r = RESP_NULL;
      end loop;
      report what & ": response after interruption = $" & to_hstring(r)
        severity note;
      assert r = RESP_NULL
        report "FAIL " & what & ": response never returned to Null, last=$" &
               to_hstring(r)
        severity failure;
    end procedure;

    procedure wait_valid is
      variable s : std_logic_vector(31 downto 0);
    begin
      for i in 0 to 2047 loop
        rd(ADDR_STATUS, s);
        exit when s(0) = '1';
      end loop;
      assert s(0) = '1' report "FAIL: STATUS.valid timeout" severity failure;
    end procedure;

    procedure cir_mode_on is
    begin
      wr(CIR_MODE_RESP, x"00000001");
    end procedure;

    -- FMOVE.L #val,FPn (memory source).
    procedure fmove_l_in(constant dst : natural; constant val : std_logic_vector(31 downto 0)) is
      variable c : std_logic_vector(15 downto 0) := (others => '0');
    begin
      cir_mode_on;
      wr(CIR_OPWORD, CPGEN_OPWORD);
      c(14) := '1';
      c(12 downto 10) := CIR_SRC_LONG;
      c(9 downto 7) := std_logic_vector(to_unsigned(dst, 3));
      c(6 downto 0) := OPCODE_FMOVE;
      wr(CIR_COMMAND, x"0000" & c);
      wait for CLK_PERIOD * 2;
      wr(CIR_OPERAND, val);
      wait_valid;
    end procedure;

    -- FMOVE.L FPn,<ea>: returns the long result.
    procedure fmove_l_out(constant src : natural; variable val : out std_logic_vector(31 downto 0)) is
      variable c : std_logic_vector(15 downto 0) := (others => '0');
    begin
      cir_mode_on;
      wr(CIR_OPWORD, CPGEN_OPWORD);
      c(14) := '1'; c(13) := '1';
      c(12 downto 10) := CIR_SRC_LONG;
      c(9 downto 7) := std_logic_vector(to_unsigned(src, 3));
      c(6 downto 0) := OPCODE_FMOVE;
      wr(CIR_COMMAND, x"0000" & c);
      wait for CLK_PERIOD * 3;
      rd(CIR_OPERAND, val);
    end procedure;

    -- Start FADD.S <ea>,FPn and stop at the operand-transfer primitive.
    procedure start_fadd_s_waiting(constant dst : natural) is
      variable c : std_logic_vector(15 downto 0) := (others => '0');
      variable r : std_logic_vector(15 downto 0);
    begin
      cir_mode_on;
      wr(CIR_OPWORD, CPGEN_OPWORD);
      c(14) := '1';
      c(12 downto 10) := CIR_SRC_SINGLE;
      c(9 downto 7) := std_logic_vector(to_unsigned(dst, 3));
      c(6 downto 0) := OPCODE_FADD;
      wr(CIR_COMMAND, x"0000" & c);
      wait for CLK_PERIOD * 3;
      read_resp(r);
      assert r = RESP_XFER_TO_CP_4
        report "FAIL setup: expected transfer-to-CP primitive $9604, got $" &
               to_hstring(r)
        severity failure;
    end procedure;

    -- Start FMOVE.L FPn,<ea> and stop at the transfer-from-CP primitive.
    procedure start_fmove_l_out_waiting(constant src : natural) is
      variable c : std_logic_vector(15 downto 0) := (others => '0');
      variable r : std_logic_vector(15 downto 0);
    begin
      cir_mode_on;
      wr(CIR_OPWORD, CPGEN_OPWORD);
      c(14) := '1'; c(13) := '1';
      c(12 downto 10) := CIR_SRC_LONG;
      c(9 downto 7) := std_logic_vector(to_unsigned(src, 3));
      c(6 downto 0) := OPCODE_FMOVE;
      wr(CIR_COMMAND, x"0000" & c);
      wait for CLK_PERIOD * 3;
      read_resp(r);
      assert r = RESP_XFER_FROM_CP_4
        report "FAIL setup: expected transfer-from-CP primitive $B204, got $" &
               to_hstring(r)
        severity failure;
    end procedure;

    -- The handler's FSAVE: must produce a valid frame and drain it.
    procedure cpsave_and_drain(constant what : in string) is
      variable f : std_logic_vector(15 downto 0);
      variable v : std_logic_vector(31 downto 0);
      variable n : natural;
    begin
      wr(CIR_OPWORD, CPSAVE_OPWORD);
      wait for CLK_PERIOD * 6;
      rd(CIR_SAVE_ADDR, v);
      f := v(15 downto 0);
      report what & ": FSAVE format word = $" & to_hstring(f) severity note;
      assert f = CIR_FRAME_NULL_FW or is_valid_idle_fw(f) or is_valid_busy_fw(f)
        report "FAIL " & what & ": FSAVE gave no valid frame, format word $" &
               to_hstring(f)
        severity failure;
      assert f /= CIR_FRAME_NULL_FW
        report "FAIL " & what & ": FPU was initialised, FSAVE returned Null frame"
        severity failure;
      if is_valid_idle_fw(f) then
        n := idle_words_for_fw(f);
      else
        n := busy_words_for_fw(f);
      end if;
      for i in 0 to n - 1 loop
        rd(ADDR_RES_H, v);
      end loop;
    end procedure;

    procedure check_still_works(constant what : in string) is
      variable v : std_logic_vector(31 downto 0);
    begin
      fmove_l_in(1, x"00000007");
      fmove_l_out(1, v);
      assert v = x"00000007"
        report "FAIL " & what & ": FMOVE.L round trip after interruption gave $" &
               to_hstring(v)
        severity failure;
    end procedure;

    procedure check_fp0_is_5(constant what : in string) is
      variable v : std_logic_vector(31 downto 0);
    begin
      fmove_l_out(0, v);
      assert v = x"00000005"
        report "FAIL " & what & ": FP0 changed by an aborted/interrupted instruction, got $" &
               to_hstring(v)
        severity failure;
    end procedure;
  begin
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    -- Initialise the FPU and give FP0 a known value.
    fmove_l_in(0, x"00000005");

    -- ================================================================
    report "TEST A: FSAVE while waiting for a source operand" severity note;
    start_fadd_s_waiting(0);
    cpsave_and_drain("TEST A");
    expect_null_soon("TEST A");
    check_fp0_is_5("TEST A");
    check_still_works("TEST A");
    report "TEST A PASSED" severity note;

    -- ================================================================
    report "TEST B: FSAVE while waiting for the host to read a result" severity note;
    start_fmove_l_out_waiting(0);
    cpsave_and_drain("TEST B");
    expect_null_soon("TEST B");
    check_still_works("TEST B");
    report "TEST B PASSED" severity note;

    -- ================================================================
    report "TEST C: Control CIR write while waiting for a source operand" severity note;
    start_fadd_s_waiting(0);
    wr(CIR_CONTROL_ADDR, x"00000001");
    expect_null_soon("TEST C");
    check_fp0_is_5("TEST C");
    check_still_works("TEST C");
    report "TEST C PASSED" severity note;

    -- ================================================================
    report "TEST D: Control CIR write while waiting for a result read" severity note;
    start_fmove_l_out_waiting(0);
    wr(CIR_CONTROL_ADDR, x"00000001");
    expect_null_soon("TEST D");
    check_fp0_is_5("TEST D");
    check_still_works("TEST D");
    report "TEST D PASSED" severity note;

    -- ================================================================
    report "TEST E: FRESTORE (null) while waiting for a source operand" severity note;
    start_fadd_s_waiting(0);
    wr(CIR_OPWORD, CPRESTORE_OPWORD);
    wr(CIR_RESTORE_ADDR, x"00000000");
    expect_null_soon("TEST E");
    check_still_works("TEST E");
    report "TEST E PASSED" severity note;

    report "All CIR interruption tests PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
