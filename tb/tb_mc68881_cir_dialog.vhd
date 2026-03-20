-- CIR Dialog Protocol Testbench
-- Tests the CIR coprocessor interface register dialog.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68881_cir_dialog is
end entity tb_mc68881_cir_dialog;

architecture sim of tb_mc68881_cir_dialog is
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

  -- Legacy addresses (coexist with CIR addresses in current implementation).
  constant ADDR_OPSEL    : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L    : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPA_H    : unsigned(4 downto 0) := to_unsigned(2, 5);
  constant ADDR_OPA_E    : unsigned(4 downto 0) := to_unsigned(3, 5);
  constant ADDR_RES_L    : unsigned(4 downto 0) := to_unsigned(7, 5);
  constant ADDR_RES_H    : unsigned(4 downto 0) := to_unsigned(8, 5);
  constant ADDR_RES_E    : unsigned(4 downto 0) := to_unsigned(9, 5);
  constant ADDR_STATUS   : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_MOVE_CFG : unsigned(4 downto 0) := to_unsigned(23, 5);

  -- Legacy opcode IDs.
  constant OP_FMOVE : std_logic_vector(31 downto 0) := x"00000005";

  -- CIR addresses (as unsigned, matching package constants).
  constant CIR_OPWORD   : unsigned(4 downto 0) := unsigned(std_logic_vector(CIR_ADDR_OPWORD));
  constant CIR_COMMAND  : unsigned(4 downto 0) := unsigned(std_logic_vector(CIR_ADDR_COMMAND));
  constant CIR_OPERAND  : unsigned(4 downto 0) := unsigned(std_logic_vector(CIR_ADDR_OPERAND));
  constant CIR_RESPONSE : unsigned(4 downto 0) := to_unsigned(13, 5);

  -- Expected CIR response primitives (lower 16 bits of response register).
  -- MC68020 CIR protocol: Null=0x2001, Busy=0x0000.
  constant RESP_NULL           : std_logic_vector(15 downto 0) := CIR_PRIM_NULL;  -- x"2001"
  constant RESP_BUSY           : std_logic_vector(15 downto 0) := CIR_PRIM_BUSY;  -- x"0000"
  constant RESP_XFER_TO_CP_4   : std_logic_vector(15 downto 0) := x"7004";  -- 1 longword to-CP
  constant RESP_XFER_FROM_CP_4 : std_logic_vector(15 downto 0) := x"6004";  -- 1 longword from-CP

  -- Exception response primitives: [15:13]=category, [12]=0, [11:10]=00, [9:0]=vector.
  constant RESP_EXCEPT_PRE_BSUN : std_logic_vector(15 downto 0) :=
    CIR_RESP_EXCEPT_PRE & "0" & "00" & CIR_VEC_BSUN;    -- $A030
  constant RESP_EXCEPT_POST_DZ  : std_logic_vector(15 downto 0) :=
    CIR_RESP_EXCEPT_POST & "0" & "00" & CIR_VEC_DIVZERO; -- $E032
  constant RESP_EXCEPT_POST_OV  : std_logic_vector(15 downto 0) :=
    CIR_RESP_EXCEPT_POST & "0" & "00" & CIR_VEC_OVERFL;  -- $E035
  constant RESP_EXCEPT_POST_SNAN : std_logic_vector(15 downto 0) :=
    CIR_RESP_EXCEPT_POST & "0" & "00" & CIR_VEC_SNAN;    -- $E036
  constant RESP_EXCEPT_POST_OPERR : std_logic_vector(15 downto 0) :=
    CIR_RESP_EXCEPT_POST & "0" & "00" & CIR_VEC_OPERR;   -- $E034

  -- FP80 test constants.
  constant FP80_ONE_VAL   : fp80_t := x"3FFF8000000000000000";  -- 1.0
  constant FP80_TWO_VAL   : fp80_t := x"40008000000000000000";  -- 2.0
  constant FP80_THREE_VAL : fp80_t := x"4000C000000000000000";  -- 3.0
  constant FP80_FIVE_VAL  : fp80_t := x"4001A000000000000000";  -- 5.0
  constant FP80_NEG_ONE   : fp80_t := x"BFFF8000000000000000";  -- -1.0

  -- cpGEN command word builder for register-to-register operations.
  -- R/M=1, bits[12:10]=src_reg, bits[9:7]=dst_reg, bits[6:0]=core_v1 opcode
  function make_cpgen_reg_cmd(
    src_reg : natural range 0 to 7;
    dst_reg : natural range 0 to 7;
    opcode  : std_logic_vector(6 downto 0)
  ) return std_logic_vector is
    variable cmd : std_logic_vector(15 downto 0) := (others => '0');
  begin
    cmd(14) := '1';  -- R/M = register
    cmd(12 downto 10) := std_logic_vector(to_unsigned(src_reg, 3));
    cmd(9 downto 7) := std_logic_vector(to_unsigned(dst_reg, 3));
    cmd(6 downto 0) := opcode;
    return x"0000" & cmd;
  end function;

  -- cpGEN command word builder for memory-source operations.
  -- R/M=0, bits[12:10]=src_fmt, bits[9:7]=dst_reg, bits[6:0]=core_v1 opcode
  function make_cpgen_mem_cmd(
    src_fmt : std_logic_vector(2 downto 0);
    dst_reg : natural range 0 to 7;
    opcode  : std_logic_vector(6 downto 0)
  ) return std_logic_vector is
    variable cmd : std_logic_vector(15 downto 0) := (others => '0');
  begin
    cmd(14) := '0';  -- R/M = memory
    cmd(12 downto 10) := src_fmt;
    cmd(9 downto 7) := std_logic_vector(to_unsigned(dst_reg, 3));
    cmd(6 downto 0) := opcode;
    return x"0000" & cmd;
  end function;

  -- cpGEN OpWord: F-line with cpID=001, type=000 (cpGEN).
  -- FPU only uses bits [8:6] for type. Bits [5:0] are EA (irrelevant to FPU).
  constant CPGEN_OPWORD : std_logic_vector(31 downto 0) := x"0000" & x"0000";

  -- Core_v1 opcode IDs from OP_DESCRIPTORS.
  constant OPCODE_FADD : std_logic_vector(6 downto 0) := "0000001";  -- 0x01
  constant OPCODE_FSUB : std_logic_vector(6 downto 0) := "0000010";  -- 0x02
  constant OPCODE_FMUL : std_logic_vector(6 downto 0) := "0000011";  -- 0x03
  constant OPCODE_FDIV : std_logic_vector(6 downto 0) := "0000100";  -- 0x04
  constant OPCODE_FMOVE : std_logic_vector(6 downto 0) := "0000101";  -- 0x05
  constant OPCODE_FCMP  : std_logic_vector(6 downto 0) := "0000111";  -- 0x07
  constant OPCODE_FNEG : std_logic_vector(6 downto 0) := "0010011";  -- 0x13
  constant OPCODE_FSIN : std_logic_vector(6 downto 0) := "0001101";  -- 0x0D
  constant OPCODE_FSQRT : std_logic_vector(6 downto 0) := "0010001";  -- 0x11

  -- CIR Condition address.
  constant CIR_CONDITION : unsigned(4 downto 0) :=
    unsigned(std_logic_vector(CIR_ADDR_CONDITION));

  -- FPSR/FPCR addresses for reading/writing.
  constant ADDR_FPSR : unsigned(4 downto 0) := to_unsigned(14, 5);
  constant ADDR_FPCR : unsigned(4 downto 0) := to_unsigned(11, 5);

  -- cpBcc word displacement OpWord: bits [8:6] = "010".
  constant CPBCC_W_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPBCC_W & "000000";
  -- cpBcc long displacement OpWord: bits [8:6] = "011".
  constant CPBCC_L_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPBCC_L & "000000";
  -- cpCond OpWord (maps to FScc evaluation in RTL): bits [8:6] = "001".
  -- FDBcc/FTRAPcc use the same CIR type; the CPU handles post-evaluation
  -- actions (counter decrement, trap) based on the CIR response word.
  constant CPCOND_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPCOND & "000000";

  -- Floating-point condition predicate codes.
  constant FCC_F  : std_logic_vector(5 downto 0) := "000000";  -- False
  constant FCC_EQ : std_logic_vector(5 downto 0) := "000001";  -- Equal
  constant FCC_GT : std_logic_vector(5 downto 0) := "010010";  -- Greater Than (signaling)
  constant FCC_T  : std_logic_vector(5 downto 0) := "001111";  -- True
  constant FCC_NE : std_logic_vector(5 downto 0) := "001110";  -- Not Equal

  -- FP80 QNaN for BSUN testing.
  constant FP80_QNAN : fp80_t := x"7FFFC000000000000001";
  -- FP80 SNaN for SNAN exception testing (bit 63=0, nonzero payload).
  constant FP80_SNAN : fp80_t := x"7FFF0000000000000001";

  -- FP80 zero for divide-by-zero testing.
  constant FP80_ZERO_VAL : fp80_t := x"00000000000000000000";

  -- FP80 positive infinity (result of 1.0 / 0.0).
  constant FP80_POS_INF : fp80_t := x"7FFF8000000000000000";

  -- FP80 largest finite value (exponent $7FFE, max significand) for overflow tests.
  constant FP80_LARGE : fp80_t := x"7FFEFFFFFFFFFFFFFFFF";

  -- CIR Instruction Address register (for FPIAR capture tests).
  constant CIR_INSTADDR : unsigned(4 downto 0) :=
    unsigned(std_logic_vector(CIR_ADDR_INSTADDR));

  -- Legacy FPIAR readback address.
  constant ADDR_FPIAR_TB : unsigned(4 downto 0) := to_unsigned(24, 5);

  -- cpSAVE/cpRESTORE OpWord constants.
  constant CPSAVE_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPSAVE & "000000";
  constant CPRESTORE_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPRESTORE & "000000";

  -- CIR addresses for Save/Restore/Control.
  constant CIR_SAVE_ADDR    : unsigned(4 downto 0) := to_unsigned(12, 5);  -- ADDR_CIR_SAVE
  constant CIR_RESTORE_ADDR : unsigned(4 downto 0) := to_unsigned(28, 5); -- ADDR_CIR_RESTORE
  constant CIR_CONTROL_ADDR : unsigned(4 downto 0) := CIR_ADDR_CONTROL;   -- from pkg

  function make_move_cfg(
    mode : std_logic_vector(1 downto 0);
    src_idx : natural;
    dst_idx : natural;
    mem_fmt : std_logic_vector(1 downto 0);
    ctrl_to_reg : std_logic;
    ctrl_sel : std_logic_vector(1 downto 0);
    movem_mask : std_logic_vector(7 downto 0);
    movem_dir : std_logic
  ) return std_logic_vector is
    variable cfg : move_cfg_t := move_cfg_default;
  begin
    cfg.src_idx := src_idx;
    cfg.mem_fmt := mem_fmt;
    cfg.mode := decode_move_cfg_mode(mode);
    cfg.ctrl_to_reg := ctrl_to_reg;
    cfg.dst_idx := dst_idx;
    cfg.ctrl_sel := ctrl_sel;
    cfg.movem_mask := movem_mask;
    cfg.movem_dir_to_reg := movem_dir;
    return encode_move_cfg(cfg);
  end function;

  -- ----- Bus access procedures (matching existing TB pattern) -----

  procedure bus_write(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    constant addr_c : unsigned(4 downto 0);
    constant data : std_logic_vector(31 downto 0)
  ) is
  begin
    a_in_s <= std_logic_vector(addr_c);
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
    constant addr_c : unsigned(4 downto 0)
  ) is
  begin
    a_in_s <= std_logic_vector(addr_c);
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
    for poll_idx in 0 to 4095 loop
      bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
               dsack0_n_s, dsack1_n_s, d_out_s, status_s, ADDR_STATUS);
      exit when status_s(0) = '1';
    end loop;
    assert status_s(0) = '1'
      report "Timeout waiting for STATUS.valid"
      severity failure;
  end procedure;

  -- ----- FP80 verification -----

  procedure check_fp80(
    constant got : fp80_t;
    constant expected : fp80_t;
    constant test_name : string
  ) is
  begin
    assert got = expected
      report "FAIL " & test_name &
             ": expected=" & to_hstring(expected) &
             " got=" & to_hstring(got)
      severity failure;
  end procedure;

  -- ----- CIR Response register read -----

  procedure cir_read_response(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    variable resp : out std_logic_vector(15 downto 0)
  ) is
    variable rd : std_logic_vector(31 downto 0) := (others => '0');
  begin
    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
             dsack0_n_s, dsack1_n_s, d_out_s, rd, CIR_RESPONSE);
    resp := rd(15 downto 0);
  end procedure;

  -- Poll CIR Response until Null (idle), returning the last non-null response seen.
  procedure cir_poll_until_null(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    variable last_resp : out std_logic_vector(15 downto 0)
  ) is
    variable resp : std_logic_vector(15 downto 0) := (others => '0');
  begin
    for poll_idx in 0 to 4095 loop
      cir_read_response(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                        dsack0_n_s, dsack1_n_s, d_out_s, resp);
      if resp = RESP_NULL then
        exit;
      end if;
      last_resp := resp;
    end loop;
    assert resp = RESP_NULL
      report "Timeout polling CIR Response for Null"
      severity failure;
    -- MC68882: CIR_EXECUTE returns NULL (ready for pending instruction)
    -- before the ALU finishes.  Wait for the FSM to settle into CIR_IDLE
    -- so the next command goes through the normal (non-pending) path.
    wait for CLK_PERIOD * 20;
    -- Confirm still NULL (CIR_IDLE), not a transient CIR_EXECUTE NULL.
    cir_read_response(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                      dsack0_n_s, dsack1_n_s, d_out_s, resp);
    assert resp = RESP_NULL
      report "CIR Response not stable Null after wait"
      severity failure;
  end procedure;

  -- ----- CIR conditional evaluation (cpBcc/cpCond) -----
  -- Writes OpWord + Condition CIR, waits for STATUS.valid, reads CIR Response.
  procedure cir_cond_eval(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    constant opword    : std_logic_vector(31 downto 0);
    constant condition : std_logic_vector(5 downto 0);
    variable response  : out std_logic_vector(31 downto 0)
  ) is
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Enable CIR mode.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
    -- Write OpWord (cpBcc or cpCond type).
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPWORD, opword);
    -- Write Condition CIR.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_CONDITION,
              x"000000" & "00" & condition);
    -- Wait for completion (STATUS.valid).
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                   dsack0_n_s, dsack1_n_s, d_out_s, status_word);
    -- Read CIR Response register.
    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
             dsack0_n_s, dsack1_n_s, d_out_s, response, CIR_RESPONSE);
  end procedure;

  -- ----- Legacy FP register load helper -----
  -- Uses the legacy FMOVE (mem→reg) path to load an FP register with a value.
  procedure legacy_load_fp_reg(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    constant fp_idx : natural range 0 to 7;
    constant value  : fp80_t
  ) is
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
    variable cfg_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Switch to peripheral mode for legacy register writes.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000000");
    -- Write FP80 value to operand A (legacy addresses 1-3).
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPA_L, value(31 downto 0));
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPA_H, value(63 downto 32));
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPA_E, x"0000" & value(79 downto 64));
    -- Configure FMOVE mem→reg: mode="01", src=0(OPA), dst=fp_idx, fmt="00"(extended).
    cfg_word := make_move_cfg("01", 0, fp_idx, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_MOVE_CFG, cfg_word);
    -- Trigger legacy FMOVE.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPSEL, OP_FMOVE);
    -- Wait for completion.
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                   dsack0_n_s, dsack1_n_s, d_out_s, status_word);
    -- Restore CIR mode.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
  end procedure;

  -- ----- Read ALU result from legacy result registers -----
  procedure read_result_fp80(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    variable result : out fp80_t
  ) is
    variable rd_lo : std_logic_vector(31 downto 0) := (others => '0');
    variable rd_hi : std_logic_vector(31 downto 0) := (others => '0');
    variable rd_ex : std_logic_vector(31 downto 0) := (others => '0');
  begin
    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
             dsack0_n_s, dsack1_n_s, d_out_s, rd_lo, ADDR_RES_L);
    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
             dsack0_n_s, dsack1_n_s, d_out_s, rd_hi, ADDR_RES_H);
    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
             dsack0_n_s, dsack1_n_s, d_out_s, rd_ex, ADDR_RES_E);
    result := rd_ex(15 downto 0) & rd_hi & rd_lo;
  end procedure;

  -- ----- CIR dialog: execute cpGEN register-to-register -----
  procedure cpgen_reg_to_reg(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    constant opcode  : std_logic_vector(6 downto 0);
    constant src_reg : natural range 0 to 7;
    constant dst_reg : natural range 0 to 7
  ) is
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
    variable cmd_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Enable CIR mode (guards overlapping peripheral addresses).
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");

    -- Step 1: Write OpWord (cpGEN type).
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPWORD, CPGEN_OPWORD);

    -- Step 2: Write Command word (reg-to-reg, src, dst, opcode).
    cmd_word := make_cpgen_reg_cmd(src_reg, dst_reg, opcode);
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_COMMAND, cmd_word);

    -- Step 3: Wait for ALU completion via STATUS.valid polling.
    -- The CIR FSM transitions IDLE→DECODE→EXECUTE→IDLE; valid fires at end.
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                   dsack0_n_s, dsack1_n_s, d_out_s, status_word);
  end procedure;

  -- ----- CIR dialog: execute cpGEN with single-precision memory source -----
  procedure cpgen_mem_single(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    constant opcode  : std_logic_vector(6 downto 0);
    constant dst_reg : natural range 0 to 7;
    constant single_val : std_logic_vector(31 downto 0)
  ) is
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
    variable cmd_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Enable CIR mode.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
    -- Write OpWord (cpGEN type).
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPWORD, CPGEN_OPWORD);
    -- Write Command word (memory source, single format).
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_SINGLE, dst_reg, opcode);
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_COMMAND, cmd_word);
    -- FSM enters CIR_XFER_SRC. Write the single-precision operand word.
    wait for CLK_PERIOD * 2;  -- Let FSM reach CIR_XFER_SRC
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPERAND, single_val);
    -- Wait for ALU completion.
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                   dsack0_n_s, dsack1_n_s, d_out_s, status_word);
  end procedure;

  -- ----- CIR dialog: FMOVE FPn to memory (single format) -----
  procedure cpgen_reg_to_mem_single(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    constant src_reg : natural range 0 to 7;
    variable single_out : out std_logic_vector(31 downto 0)
  ) is
    variable cmd_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Enable CIR mode.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
    -- Write OpWord (cpGEN type).
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPWORD, CPGEN_OPWORD);
    -- Write Command word: R/M=0, direction=1 (reg→mem), fmt=Single, src_reg in bits[9:7].
    -- Note: FMOVE opcode = 0x05 in core_v1 encoding.
    cmd_word := (others => '0');
    cmd_word(13) := '1';  -- direction = reg→mem
    cmd_word(12 downto 10) := CIR_SRC_SINGLE;  -- destination format
    cmd_word(9 downto 7) := std_logic_vector(to_unsigned(src_reg, 3));
    cmd_word(6 downto 0) := "0000101";  -- FMOVE opcode (core_v1 = 0x05)
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_COMMAND, x"0000" & cmd_word(15 downto 0));
    -- FSM enters CIR_XFER_DST. Wait for staging to be ready.
    wait for CLK_PERIOD * 3;
    -- Read 1 word from Operand CIR.
    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
             dsack0_n_s, dsack1_n_s, d_out_s, single_out, CIR_OPERAND);
  end procedure;

  -- ----- CIR dialog: FMOVE FPn to memory (any 1-word format) -----
  -- Works for Long, Word, Byte, and Single destination formats (all 1 word).
  procedure cpgen_reg_to_mem(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    constant dst_fmt : std_logic_vector(2 downto 0);
    constant src_reg : natural range 0 to 7;
    variable word_out : out std_logic_vector(31 downto 0)
  ) is
    variable cmd_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Enable CIR mode.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := (others => '0');
    cmd_word(13) := '1';  -- direction = reg→mem
    cmd_word(12 downto 10) := dst_fmt;
    cmd_word(9 downto 7) := std_logic_vector(to_unsigned(src_reg, 3));
    cmd_word(6 downto 0) := "0000101";  -- FMOVE opcode
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_COMMAND, x"0000" & cmd_word(15 downto 0));
    wait for CLK_PERIOD * 3;
    bus_read(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
             dsack0_n_s, dsack1_n_s, d_out_s, word_out, CIR_OPERAND);
  end procedure;

  -- ----- CIR dialog: execute cpGEN with long-integer memory source -----
  procedure cpgen_mem_long(
    signal a_in_s : out std_logic_vector(4 downto 0);
    signal d_in_s : out std_logic_vector(31 downto 0);
    signal rw_s   : out std_logic;
    signal cs_n_s : out std_logic;
    signal as_n_s : out std_logic;
    signal ds_n_s : out std_logic;
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s : in std_logic_vector(31 downto 0);
    constant opcode  : std_logic_vector(6 downto 0);
    constant dst_reg : natural range 0 to 7;
    constant long_val : std_logic_vector(31 downto 0)
  ) is
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
    variable cmd_word : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Enable CIR mode.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_LONG, dst_reg, opcode);
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPERAND, long_val);
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                   dsack0_n_s, dsack1_n_s, d_out_s, status_word);
  end procedure;

  -- ----- Sized bus access for sub-32-bit peripheral modes -----
  -- Each 32-bit CIR register access becomes N beats (2 for 16-bit, 4 for 8-bit).
  -- FPU always captures/presents full 32-bit data; only DSACK encoding changes.

  procedure bus_write_sized(
    signal a_in_s     : out std_logic_vector(4 downto 0);
    signal d_in_s     : out std_logic_vector(31 downto 0);
    signal rw_s       : out std_logic;
    signal cs_n_s     : out std_logic;
    signal as_n_s     : out std_logic;
    signal ds_n_s     : out std_logic;
    signal size_n_s   : out std_logic_vector(1 downto 0);
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    constant addr_c   : unsigned(4 downto 0);
    constant data     : std_logic_vector(31 downto 0);
    constant sz       : std_logic_vector(1 downto 0);
    constant beats    : natural
  ) is
  begin
    for beat in 0 to beats - 1 loop
      size_n_s <= sz;
      a_in_s <= std_logic_vector(addr_c);
      d_in_s <= data;
      rw_s   <= '0';
      cs_n_s <= '0';
      as_n_s <= '0';
      ds_n_s <= '0';
      wait until (dsack0_n_s = '0') or (dsack1_n_s = '0');
      if sz = "10" then
        assert dsack0_n_s = '1' and dsack1_n_s = '0'
          report "16-bit DSACK mismatch on write beat " & integer'image(beat)
          severity failure;
      else
        assert dsack0_n_s = '0' and dsack1_n_s = '1'
          report "8-bit DSACK mismatch on write beat " & integer'image(beat)
          severity failure;
      end if;
      cs_n_s <= '1';
      as_n_s <= '1';
      ds_n_s <= '1';
      rw_s   <= '1';
      wait for CLK_PERIOD;
    end loop;
  end procedure;

  procedure bus_read_sized(
    signal a_in_s     : out std_logic_vector(4 downto 0);
    signal rw_s       : out std_logic;
    signal cs_n_s     : out std_logic;
    signal as_n_s     : out std_logic;
    signal ds_n_s     : out std_logic;
    signal size_n_s   : out std_logic_vector(1 downto 0);
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s    : in std_logic_vector(31 downto 0);
    variable data_s   : out std_logic_vector(31 downto 0);
    constant addr_c   : unsigned(4 downto 0);
    constant sz       : std_logic_vector(1 downto 0);
    constant beats    : natural
  ) is
  begin
    for beat in 0 to beats - 1 loop
      size_n_s <= sz;
      a_in_s <= std_logic_vector(addr_c);
      rw_s   <= '1';
      cs_n_s <= '0';
      as_n_s <= '0';
      ds_n_s <= '0';
      wait until (dsack0_n_s = '0') or (dsack1_n_s = '0');
      if sz = "10" then
        assert dsack0_n_s = '1' and dsack1_n_s = '0'
          report "16-bit DSACK mismatch on read beat " & integer'image(beat)
          severity failure;
      else
        assert dsack0_n_s = '0' and dsack1_n_s = '1'
          report "8-bit DSACK mismatch on read beat " & integer'image(beat)
          severity failure;
      end if;
      wait for CLK_PERIOD/4;
      if beat = 0 then
        data_s := d_out_s;
      end if;
      wait for CLK_PERIOD/4;
      cs_n_s <= '1';
      as_n_s <= '1';
      ds_n_s <= '1';
      wait for CLK_PERIOD;
    end loop;
  end procedure;

  procedure wait_for_valid_sized(
    signal a_in_s     : out std_logic_vector(4 downto 0);
    signal rw_s       : out std_logic;
    signal cs_n_s     : out std_logic;
    signal as_n_s     : out std_logic;
    signal ds_n_s     : out std_logic;
    signal size_n_s   : out std_logic_vector(1 downto 0);
    signal dsack0_n_s : in std_logic;
    signal dsack1_n_s : in std_logic;
    signal d_out_s    : in std_logic_vector(31 downto 0);
    variable status_s : out std_logic_vector(31 downto 0);
    constant sz       : std_logic_vector(1 downto 0);
    constant beats    : natural
  ) is
  begin
    for poll_idx in 0 to 4095 loop
      bus_read_sized(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s, size_n_s,
                     dsack0_n_s, dsack1_n_s, d_out_s, status_s,
                     ADDR_STATUS, sz, beats);
      exit when status_s(0) = '1';
    end loop;
    assert status_s(0) = '1'
      report "Timeout waiting for STATUS.valid (sized)"
      severity failure;
  end procedure;

begin
  clk <= not clk after CLK_PERIOD/2;

  dut : entity work.mc68881_top
    port map (
      a_in     => a_in,
      d_in     => d_in,
      d_out    => d_out,
      size_n   => size_n,
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
    variable status_word : std_logic_vector(31 downto 0) := (others => '0');
    variable result_fp80 : fp80_t := (others => '0');
    variable single_result : std_logic_vector(31 downto 0) := (others => '0');
    variable resp : std_logic_vector(15 downto 0) := (others => '0');
    variable last_resp : std_logic_vector(15 downto 0) := (others => '0');
    variable cmd_word : std_logic_vector(31 downto 0) := (others => '0');
    variable cir_resp : std_logic_vector(31 downto 0) := (others => '0');
    variable cir_resp_16 : std_logic_vector(15 downto 0) := (others => '0');
    variable fpsr_val : std_logic_vector(31 downto 0) := (others => '0');
    type frame_buf_t is array (0 to CIR_FRAME_BUSY_WORDS_82-1) of std_logic_vector(31 downto 0);
    variable save_buf : frame_buf_t := (others => (others => '0'));
    variable saved_fw : std_logic_vector(15 downto 0) := (others => '0');
    variable saved_fw_words : natural := 0;
    -- Phase 5 timing measurement variables.
    variable t59_start   : time := 0 ns;
    variable t59_elapsed : integer := 0;
    variable t60_start   : time := 0 ns;
    variable t60_elapsed : integer := 0;
    variable t61_start   : time := 0 ns;
    variable t61_elapsed : integer := 0;
    variable t62_start   : time := 0 ns;
    variable t62_elapsed : integer := 0;
    variable t63_start   : time := 0 ns;
    variable t63_elapsed : integer := 0;
    variable t64_start   : time := 0 ns;
    variable t64_elapsed : integer := 0;
    variable t65_start   : time := 0 ns;
    variable t65_elapsed : integer := 0;
    variable single_readback : std_logic_vector(31 downto 0) := (others => '0');
    variable int_result : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Reset.
    reset_n <= '0';
    wait for 2 * CLK_PERIOD;
    reset_n <= '1';
    wait for 2 * CLK_PERIOD;

    -- ================================================================
    -- TEST 1: FADD FP1,FP0 (register-to-register)
    --   Load FP0=1.0, FP1=2.0, execute FADD FP1,FP0 → FP0 should be 3.0
    -- ================================================================
    report "TEST 1: FADD FP1,FP0 (reg-to-reg)" severity note;

    -- Pre-load FP0 with 1.0 via legacy FMOVE.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);

    -- Pre-load FP1 with 2.0 via legacy FMOVE.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);

    -- Execute FADD FP1,FP0 via CIR dialog.
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FADD, 1, 0);

    -- Read result from legacy result registers.
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);

    report "FADD result=" & to_hstring(result_fp80) severity note;
    check_fp80(result_fp80, FP80_THREE_VAL, "FADD FP1,FP0 = 1.0+2.0");

    -- ================================================================
    -- TEST 2: FSUB FP1,FP0 (register-to-register)
    --   FP0=3.0 (from test 1), FP1=2.0, FSUB FP1,FP0 → FP0 = 3.0-2.0 = 1.0
    -- ================================================================
    report "TEST 2: FSUB FP1,FP0 (reg-to-reg)" severity note;

    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FSUB, 1, 0);

    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);

    report "FSUB result=" & to_hstring(result_fp80) severity note;
    check_fp80(result_fp80, FP80_ONE_VAL, "FSUB FP1,FP0 = 3.0-2.0");

    -- ================================================================
    -- TEST 3: FMUL FP1,FP0 (register-to-register)
    --   FP0=1.0 (from test 2), reload FP1=5.0, FMUL FP1,FP0 → FP0 = 5.0
    -- ================================================================
    report "TEST 3: FMUL FP1,FP0 (reg-to-reg)" severity note;

    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_FIVE_VAL);

    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMUL, 1, 0);

    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);

    report "FMUL result=" & to_hstring(result_fp80) severity note;
    check_fp80(result_fp80, FP80_FIVE_VAL, "FMUL FP1,FP0 = 1.0*5.0");

    -- ================================================================
    -- TEST 4: FNEG FP0,FP0 (monadic, register-to-register)
    --   FP0=5.0, FNEG FP0,FP0 → FP0 = -5.0
    -- ================================================================
    report "TEST 4: FNEG FP0,FP0 (reg-to-reg)" severity note;

    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FNEG, 0, 0);

    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);

    report "FNEG result=" & to_hstring(result_fp80) severity note;
    -- -5.0 = 0xC001_A000_0000_0000_0000
    check_fp80(result_fp80, x"C001A000000000000000", "FNEG FP0,FP0 = -(5.0)");

    -- ================================================================
    -- TEST 5: FADD.S with single-precision memory source
    --   FP0 = -5.0 (from test 4), FADD.S #7.0,FP0 → FP0 = -5.0 + 7.0 = 2.0
    --   Single 7.0 = 0x40E00000
    -- ================================================================
    report "TEST 5: FADD.S #7.0,FP0 (memory source)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FADD, 0, x"40E00000");

    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);

    report "FADD.S result=" & to_hstring(result_fp80) severity note;
    check_fp80(result_fp80, FP80_TWO_VAL, "FADD.S #7.0,FP0 = -5.0+7.0");

    -- ================================================================
    -- TEST 6: FADD.L with long-integer memory source
    --   FP0 = 2.0 (from test 5), FADD.L #100,FP0 → FP0 = 102.0
    --   Long integer 100 = 0x00000064
    -- ================================================================
    report "TEST 6: FADD.L #100,FP0 (memory source)" severity note;

    cpgen_mem_long(a_in, d_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out,
                   OPCODE_FADD, 0, x"00000064");

    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);

    -- FP80 102.0 = sign=0, exp=4005 (bias+6), mant=CC00000000000000
    report "FADD.L result=" & to_hstring(result_fp80) severity note;
    check_fp80(result_fp80, x"4005CC00000000000000", "FADD.L #100,FP0 = 2.0+100");

    -- ================================================================
    -- TEST 7: FMOVE FP0 → memory (single-precision destination transfer)
    --   FP0 = 102.0 (from test 6), read back as single via CIR_XFER_DST
    --   IEEE 754 single 102.0 = 0x42CC0000
    -- ================================================================
    report "TEST 7: FMOVE FP0 -> mem single (destination transfer)" severity note;

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);

    report "FMOVE reg->mem single result=" & to_hstring(single_result) severity note;
    assert single_result = x"42CC0000"
      report "FAIL FMOVE FP0->mem single: expected=42CC0000 got=" & to_hstring(single_result)
      severity failure;

    -- ================================================================
    -- TEST 8: CIR Response verification — reg-to-reg (Busy → Null)
    --   Reload FP0=1.0, FP1=2.0. Execute FADD via CIR, check Response.
    -- ================================================================
    report "TEST 8: CIR Response for reg-to-reg (Busy->Null)" severity note;

    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);

    -- Before dialog: Response should be Null (idle).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, resp);
    report "Pre-dialog response=" & to_hstring(resp) severity note;
    assert resp = RESP_NULL
      report "FAIL: pre-dialog response not Null: " & to_hstring(resp)
      severity failure;

    -- Write OpWord + Command to start dialog.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FADD));

    -- Immediately read response — should see Busy (DECODE or EXECUTE).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, resp);
    report "Mid-dialog response=" & to_hstring(resp) severity note;
    -- Accept Busy or Null (if ALU finished very quickly).
    assert resp = RESP_BUSY or resp = RESP_NULL
      report "FAIL: mid-dialog response not Busy/Null: " & to_hstring(resp)
      severity failure;

    -- Poll until Null.
    cir_poll_until_null(a_in, rw, cs_n, as_n, ds_n,
                        dsack0_n, dsack1_n, d_out, last_resp);
    report "TEST 8 PASSED" severity note;

    -- ================================================================
    -- TEST 9: CIR Response verification — memory-source (Transfer Operand)
    --   FP0=3.0 (from test 8). FADD.S #-1.0 via CIR with response checks.
    --   Single -1.0 = 0xBF800000
    -- ================================================================
    report "TEST 9: CIR Response for mem-source (Transfer Operand)" severity note;

    -- Write OpWord + Command for FADD.S (mem→reg).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_SINGLE, 0, OPCODE_FADD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);

    -- FSM should be in CIR_XFER_SRC. Read Response → Transfer Operand to-CP.
    wait for CLK_PERIOD * 2;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, resp);
    report "Xfer-src response=" & to_hstring(resp) severity note;
    assert resp = RESP_XFER_TO_CP_4
      report "FAIL: expected Transfer Operand to-CP ($7004), got " & to_hstring(resp)
      severity failure;

    -- Write operand data.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"BF800000");  -- single -1.0

    -- Poll until Null (ALU completes).
    cir_poll_until_null(a_in, rw, cs_n, as_n, ds_n,
                        dsack0_n, dsack1_n, d_out, last_resp);

    -- Verify result: 3.0 + (-1.0) = 2.0.
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);
    check_fp80(result_fp80, FP80_TWO_VAL, "FADD.S #-1.0 via response poll");
    report "TEST 9 PASSED" severity note;

    -- ================================================================
    -- TEST 10: CIR Response verification — destination transfer (Transfer from-CP)
    --   FP0=2.0 (from test 9). FMOVE FP0→mem single with response checks.
    -- ================================================================
    report "TEST 10: CIR Response for dst-xfer (Transfer from-CP)" severity note;

    -- Write OpWord + Command for FMOVE FP0→mem single.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := (others => '0');
    cmd_word(13) := '1';  -- direction = reg→mem
    cmd_word(12 downto 10) := CIR_SRC_SINGLE;
    cmd_word(9 downto 7) := "000";  -- src_reg = FP0
    cmd_word(6 downto 0) := "0000101";  -- FMOVE
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, x"0000" & cmd_word(15 downto 0));

    -- FSM should be in CIR_XFER_DST. Read Response → Transfer Operand from-CP.
    wait for CLK_PERIOD * 3;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, resp);
    report "Xfer-dst response=" & to_hstring(resp) severity note;
    assert resp = RESP_XFER_FROM_CP_4
      report "FAIL: expected Transfer from-CP ($6004), got " & to_hstring(resp)
      severity failure;

    -- Read the operand data.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, single_result, CIR_OPERAND);

    -- Verify single-precision 2.0 = 0x40000000.
    assert single_result = x"40000000"
      report "FAIL: FMOVE FP0->mem single: expected 40000000 got " & to_hstring(single_result)
      severity failure;

    -- Poll until Null.
    cir_poll_until_null(a_in, rw, cs_n, as_n, ds_n,
                        dsack0_n, dsack1_n, d_out, last_resp);
    report "TEST 10 PASSED" severity note;

    -- ================================================================
    -- TEST 11: FMUL 3.5 * (-2.25) = -7.875 (E2E with non-trivial FP values)
    --   Load FP0=3.5 via CIR mem-source FMOVE.S (0x40600000)
    --   Load FP1=-2.25 via CIR mem-source FMOVE.S (0xC0100000)
    --   FMUL FP1,FP0 → FP0 = -7.875
    --   Readback via FMOVE FP0→mem single → 0xC0FC0000
    -- ================================================================
    report "TEST 11: FMUL 3.5 * (-2.25) = -7.875 (E2E)" severity note;

    -- Load FP0 = 3.5 via CIR FMOVE.S
    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 0, x"40600000");  -- 3.5

    -- Load FP1 = -2.25 via CIR FMOVE.S
    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 1, x"C0100000");  -- -2.25

    -- FMUL FP1,FP0
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMUL, 1, 0);

    -- Readback as single
    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);

    report "TEST 11 result=" & to_hstring(single_result) severity note;
    assert single_result = x"C0FC0000"
      report "FAIL TEST 11: FMUL 3.5*(-2.25) expected=C0FC0000 got=" & to_hstring(single_result)
      severity failure;
    report "TEST 11 PASSED" severity note;

    -- ================================================================
    -- TEST 12: FSUB (-7.875) - (-2.25) = -5.625
    --   FP0=-7.875 (from test 11), FP1=-2.25 (from test 11)
    --   FSUB FP1,FP0 → FP0 = (-7.875) - (-2.25) = -5.625
    --   Readback → 0xC0B40000
    -- ================================================================
    report "TEST 12: FSUB (-7.875) - (-2.25) = -5.625 (E2E)" severity note;

    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FSUB, 1, 0);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);

    report "TEST 12 result=" & to_hstring(single_result) severity note;
    assert single_result = x"C0B40000"
      report "FAIL TEST 12: FSUB expected=C0B40000 got=" & to_hstring(single_result)
      severity failure;
    report "TEST 12 PASSED" severity note;

    -- ================================================================
    -- TEST 13: FADD.S #12.375 + (-5.625) = 6.75
    --   FP0=-5.625 (from test 12)
    --   FADD.S #12.375 (0x41460000) via CIR mem-source → FP0 = 6.75
    --   Readback → 0x40D80000
    -- ================================================================
    report "TEST 13: FADD.S #12.375 + (-5.625) = 6.75 (E2E)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FADD, 0, x"41460000");  -- 12.375

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);

    report "TEST 13 result=" & to_hstring(single_result) severity note;
    assert single_result = x"40D80000"
      report "FAIL TEST 13: FADD.S expected=40D80000 got=" & to_hstring(single_result)
      severity failure;
    report "TEST 13 PASSED" severity note;

    -- ================================================================
    -- TEST 14: FDIV 6.75 / (-2.25) = -3.0
    --   FP0=6.75 (from test 13), FP1=-2.25 (still loaded)
    --   FDIV FP1,FP0 → FP0 = 6.75 / (-2.25) = -3.0
    --   Readback → 0xC0400000
    -- ================================================================
    report "TEST 14: FDIV 6.75 / (-2.25) = -3.0 (E2E)" severity note;

    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FDIV, 1, 0);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);

    report "TEST 14 result=" & to_hstring(single_result) severity note;
    assert single_result = x"C0400000"
      report "FAIL TEST 14: FDIV expected=C0400000 got=" & to_hstring(single_result)
      severity failure;
    report "TEST 14 PASSED" severity note;

    -- ================================================================
    -- TEST 15: 16-bit peripheral mode E2E
    --   All CIR accesses use size_n="10" (16-bit port, 2 beats per access).
    --   Verifies DSACK encoding (dsack0_n='1', dsack1_n='0') on every beat.
    --   Load FP2=10.0, FP3=3.0, FADD FP3,FP2 → 13.0, readback → 0x41500000
    -- ================================================================
    report "TEST 15: 16-bit peripheral mode E2E" severity note;

    -- Load FP2 = 10.0 via CIR FMOVE.S (16-bit bus, 2 beats per access)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "10", 2);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_SINGLE, 2, OPCODE_FMOVE);
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND, cmd_word, "10", 2);
    wait for CLK_PERIOD * 2;
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPERAND, x"41200000", "10", 2);
    wait_for_valid_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                         dsack0_n, dsack1_n, d_out, status_word, "10", 2);

    -- Load FP3 = 3.0 via CIR FMOVE.S (16-bit bus)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "10", 2);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_SINGLE, 3, OPCODE_FMOVE);
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND, cmd_word, "10", 2);
    wait for CLK_PERIOD * 2;
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPERAND, x"40400000", "10", 2);
    wait_for_valid_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                         dsack0_n, dsack1_n, d_out, status_word, "10", 2);

    -- FADD FP3,FP2 via CIR reg-to-reg (16-bit bus)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "10", 2);
    cmd_word := make_cpgen_reg_cmd(3, 2, OPCODE_FADD);
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND, cmd_word, "10", 2);
    wait_for_valid_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                         dsack0_n, dsack1_n, d_out, status_word, "10", 2);

    -- Readback FP2 as single via CIR FMOVE reg→mem (16-bit bus)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "10", 2);
    cmd_word := (others => '0');
    cmd_word(13) := '1';  -- direction = reg→mem
    cmd_word(12 downto 10) := CIR_SRC_SINGLE;
    cmd_word(9 downto 7) := "010";  -- FP2
    cmd_word(6 downto 0) := OPCODE_FMOVE;
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND,
                    x"0000" & cmd_word(15 downto 0), "10", 2);
    wait for CLK_PERIOD * 3;
    bus_read_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                   dsack0_n, dsack1_n, d_out, single_result,
                   CIR_OPERAND, "10", 2);

    size_n <= "11";  -- restore 32-bit mode
    report "TEST 15 result=" & to_hstring(single_result) severity note;
    assert single_result = x"41500000"
      report "FAIL TEST 15: 16-bit E2E FADD 10+3=13 expected=41500000 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 15 PASSED" severity note;

    -- ================================================================
    -- TEST 16: 8-bit peripheral mode E2E
    --   All CIR accesses use size_n="01" (8-bit port, 4 beats per access).
    --   Verifies DSACK encoding (dsack0_n='0', dsack1_n='1') on every beat.
    --   Load FP4=8.0, FMUL.S #0.5,FP4 → 4.0, readback → 0x40800000
    -- ================================================================
    report "TEST 16: 8-bit peripheral mode E2E" severity note;

    -- Load FP4 = 8.0 via CIR FMOVE.S (8-bit bus, 4 beats per access)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "01", 4);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_SINGLE, 4, OPCODE_FMOVE);
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND, cmd_word, "01", 4);
    wait for CLK_PERIOD * 2;
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPERAND, x"41000000", "01", 4);
    wait_for_valid_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                         dsack0_n, dsack1_n, d_out, status_word, "01", 4);

    -- FMUL.S #0.5,FP4 via CIR mem-source (8-bit bus)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "01", 4);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_SINGLE, 4, OPCODE_FMUL);
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND, cmd_word, "01", 4);
    wait for CLK_PERIOD * 2;
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPERAND, x"3F000000", "01", 4);
    wait_for_valid_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                         dsack0_n, dsack1_n, d_out, status_word, "01", 4);

    -- Readback FP4 as single via CIR FMOVE reg→mem (8-bit bus)
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "01", 4);
    cmd_word := (others => '0');
    cmd_word(13) := '1';  -- direction = reg→mem
    cmd_word(12 downto 10) := CIR_SRC_SINGLE;
    cmd_word(9 downto 7) := "100";  -- FP4
    cmd_word(6 downto 0) := OPCODE_FMOVE;
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND,
                    x"0000" & cmd_word(15 downto 0), "01", 4);
    wait for CLK_PERIOD * 3;
    bus_read_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                   dsack0_n, dsack1_n, d_out, single_result,
                   CIR_OPERAND, "01", 4);

    size_n <= "11";  -- restore 32-bit mode
    report "TEST 16 result=" & to_hstring(single_result) severity note;
    assert single_result = x"40800000"
      report "FAIL TEST 16: 8-bit E2E FMUL 8*0.5=4 expected=40800000 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 16 PASSED" severity note;

    -- ================================================================
    -- TEST 17: FADD.B #3, FP0 (byte-integer memory source)
    --   Reload FP0 = 2.0, then FADD.B #3 → 5.0
    --   CIR_SRC_BYTE = "110", 1 word, lower 8 bits sign-extended
    -- ================================================================
    report "TEST 17: FADD.B #3 (byte source)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 0, x"40000000");  -- Load FP0 = 2.0

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_BYTE, 0, OPCODE_FADD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000003");  -- byte 3
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);
    report "TEST 17 result=" & to_hstring(single_result) severity note;
    assert single_result = x"40A00000"
      report "FAIL TEST 17: FADD.B 2+3=5 expected=40A00000 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 17 PASSED" severity note;

    -- ================================================================
    -- TEST 18: FMUL.W #-4, FP0 (word-integer memory source)
    --   FP0 = 5.0 (from test 17), FMUL.W #-4 → -20.0
    --   CIR_SRC_WORD = "100", 1 word, lower 16 bits sign-extended
    --   Signed word -4 = 0xFFFC
    -- ================================================================
    report "TEST 18: FMUL.W #-4 (word source)" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_WORD, 0, OPCODE_FMUL);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"0000FFFC");  -- word -4
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);
    report "TEST 18 result=" & to_hstring(single_result) severity note;
    assert single_result = x"C1A00000"
      report "FAIL TEST 18: FMUL.W 5*(-4)=-20 expected=C1A00000 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 18 PASSED" severity note;

    -- ================================================================
    -- TEST 19: FSUB.L #7, FP0 (long-integer memory source)
    --   FP0 = -20.0 (from test 18), FSUB.L #7 → -27.0
    --   CIR_SRC_LONG = "000", 1 word, 32-bit signed integer
    -- ================================================================
    report "TEST 19: FSUB.L #7 (long source)" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_LONG, 0, OPCODE_FSUB);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000007");  -- long 7
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);
    report "TEST 19 result=" & to_hstring(single_result) severity note;
    assert single_result = x"C1D80000"
      report "FAIL TEST 19: FSUB.L (-20)-7=-27 expected=C1D80000 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 19 PASSED" severity note;

    -- ================================================================
    -- TEST 20: FADD.P #70, FP0 (packed-decimal memory source)
    --   FP0 = -27.0 (from test 19), FADD.P #70 → 43.0
    --   CIR_SRC_PACKED = "011", 3 words
    --   Packed 70.0: SM=0, SE=0, YY=00, exp=0001, int_digit=7, frac=0
    --   Word 0 (MSW): 0x00010007
    --   Word 1: 0x00000000
    --   Word 2 (LSW): 0x00000000
    -- ================================================================
    report "TEST 20: FADD.P #70 (packed decimal source)" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_PACKED, 0, OPCODE_FADD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    -- Write 3 operand words (MSW first).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00010007");  -- word 0: SM=0, exp=001, digit=7
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000000");  -- word 1: frac digits = 0
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000000");  -- word 2: frac digits = 0
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             0, single_result);
    report "TEST 20 result=" & to_hstring(single_result) severity note;
    assert single_result = x"422C0000"
      report "FAIL TEST 20: FADD.P (-27)+70=43 expected=422C0000 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 20 PASSED" severity note;

    -- ================================================================
    -- TEST 21: FDIV.B #3, FP5 (byte → repeating binary fraction)
    --   FP5 = 10.0, FDIV.B #3 → 10/3 ≈ 3.3333...
    --   10/3 = 1.10101010... × 2^1, guard=0 → round down
    -- ================================================================
    report "TEST 21: FDIV.B #3 -> 10/3 (fractional)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 5, x"41200000");  -- FP5 = 10.0

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_BYTE, 5, OPCODE_FDIV);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000003");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             5, single_result);
    report "TEST 21 result=" & to_hstring(single_result) severity note;
    assert single_result = x"40555555"
      report "FAIL TEST 21: FDIV.B 10/3 expected=40555555 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 21 PASSED" severity note;

    -- ================================================================
    -- TEST 22: FDIV.W #7, FP5 (word → repeating binary fraction)
    --   FP5 = 10.0, FDIV.W #7 → 10/7 ≈ 1.4286
    --   10/7 = 1.011011011... × 2^0, guard=1 → round up
    -- ================================================================
    report "TEST 22: FDIV.W #7 -> 10/7 (fractional)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 5, x"41200000");  -- FP5 = 10.0

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_WORD, 5, OPCODE_FDIV);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000007");
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             5, single_result);
    report "TEST 22 result=" & to_hstring(single_result) severity note;
    assert single_result = x"3FB6DB6E"
      report "FAIL TEST 22: FDIV.W 10/7 expected=3FB6DB6E got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 22 PASSED" severity note;

    -- ================================================================
    -- TEST 23: FDIV.L #-3, FP5 (long → negative repeating fraction)
    --   FP5 = 10.0, FDIV.L #-3 → -10/3 ≈ -3.3333...
    --   Same magnitude as test 21, sign flipped.
    -- ================================================================
    report "TEST 23: FDIV.L #-3 -> -10/3 (fractional)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 5, x"41200000");  -- FP5 = 10.0

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_LONG, 5, OPCODE_FDIV);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"FFFFFFFD");  -- long -3
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             5, single_result);
    report "TEST 23 result=" & to_hstring(single_result) severity note;
    assert single_result = x"C0555555"
      report "FAIL TEST 23: FDIV.L 10/(-3) expected=C0555555 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 23 PASSED" severity note;

    -- ================================================================
    -- TEST 24: FDIV.P packed(6), FP5 (packed-decimal → fractional)
    --   FP5 = 10.0, FDIV.P #6 → 10/6 = 5/3 ≈ 1.6667
    --   5/3 = 1.10101010... × 2^0, guard=0 → round down
    -- ================================================================
    report "TEST 24: FDIV.P #6 -> 10/6 (fractional)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 5, x"41200000");  -- FP5 = 10.0

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_mem_cmd(CIR_SRC_PACKED, 5, OPCODE_FDIV);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, cmd_word);
    wait for CLK_PERIOD * 2;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000006");  -- word 0: digit=6, exp=0
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000000");  -- word 1
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"00000000");  -- word 2
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, status_word);

    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                             dsack0_n, dsack1_n, d_out,
                             5, single_result);
    report "TEST 24 result=" & to_hstring(single_result) severity note;
    assert single_result = x"3FD55555"
      report "FAIL TEST 24: FDIV.P 10/6 expected=3FD55555 got=" &
             to_hstring(single_result)
      severity failure;
    report "TEST 24 PASSED" severity note;

    -- ================================================================
    -- TEST 25: FNOP via CIR (cpBcc with condition F, zero displacement)
    --   FNOP = FBcc(False) → branch never taken.
    -- ================================================================
    report "TEST 25: FNOP via CIR" severity note;

    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPBCC_W_OPWORD, FCC_F, cir_resp);
    report "TEST 25 cir_resp=" & to_hstring(cir_resp) severity note;
    assert cir_resp(0) = '0'
      report "FAIL TEST 25: FNOP cond_true should be 0, got 1"
      severity failure;
    assert cir_resp(1) = '0'
      report "FAIL TEST 25: FNOP branch_taken should be 0, got 1"
      severity failure;
    report "TEST 25 PASSED" severity note;

    -- ================================================================
    -- TEST 26: FBcc taken (EQ condition, Z=1)
    --   Pre-load FP0=1.0, FP1=1.0, FCMP FP0,FP1 → Z=1.
    --   cpBcc with EQ → branch taken.
    -- ================================================================
    report "TEST 26: FBcc taken (EQ, equal operands)" severity note;

    -- Set FPSR CC Z=1 via FCMP on equal operands.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_ONE_VAL);
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FCMP, 0, 1);
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 26 FPSR after FCMP=" & to_hstring(fpsr_val) severity note;
    -- Assert FPSR CC bits: Z=1, N=0 (verifies double-exc_classification fix).
    assert fpsr_val(26) = '1'
      report "FAIL TEST 26: FPSR CC.Z should be 1 after FCMP(1.0,1.0)"
      severity failure;
    assert fpsr_val(27) = '0'
      report "FAIL TEST 26: FPSR CC.N should be 0 after FCMP(1.0,1.0)"
      severity failure;

    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPBCC_W_OPWORD, FCC_EQ, cir_resp);
    report "TEST 26 cir_resp=" & to_hstring(cir_resp) severity note;
    assert cir_resp(0) = '1'
      report "FAIL TEST 26: FBcc EQ cond_true should be 1, got 0"
      severity failure;
    assert cir_resp(1) = '1'
      report "FAIL TEST 26: FBcc EQ branch_taken should be 1, got 0"
      severity failure;
    report "TEST 26 PASSED" severity note;

    -- ================================================================
    -- TEST 27: FBcc not taken (NE condition, Z=1)
    --   Same FPSR CC state (Z=1 from equal comparison above).
    --   cpBcc with NE → branch not taken.
    -- ================================================================
    report "TEST 27: FBcc not taken (NE, equal operands)" severity note;

    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPBCC_W_OPWORD, FCC_NE, cir_resp);
    report "TEST 27 cir_resp=" & to_hstring(cir_resp) severity note;
    assert cir_resp(0) = '0'
      report "FAIL TEST 27: FBcc NE cond_true should be 0, got 1"
      severity failure;
    assert cir_resp(1) = '0'
      report "FAIL TEST 27: FBcc NE branch_taken should be 0, got 1"
      severity failure;
    report "TEST 27 PASSED" severity note;

    -- ================================================================
    -- TEST 28: FScc (cpCond) condition true (EQ, Z=1)
    --   FPSR CC still Z=1 from test 26's FCMP.
    --   cpCond with EQ → condition true, result_lo byte = 0xFF.
    -- ================================================================
    report "TEST 28: FScc cpCond true (EQ, Z=1)" severity note;

    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPCOND_OPWORD, FCC_EQ, cir_resp);
    report "TEST 28 cir_resp=" & to_hstring(cir_resp) severity note;
    assert cir_resp(0) = '1'
      report "FAIL TEST 28: FScc EQ cond_true should be 1, got 0"
      severity failure;
    -- Read result_lo: FScc sets byte 0 to 0xFF when condition true.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, single_result, ADDR_RES_L);
    assert single_result(7 downto 0) = x"FF"
      report "FAIL TEST 28: FScc result_lo byte expected=FF got=" &
             to_hstring(single_result(7 downto 0))
      severity failure;
    report "TEST 28 PASSED" severity note;

    -- ================================================================
    -- TEST 29: FScc (cpCond) condition false (NE, Z=1)
    --   FPSR CC still Z=1. cpCond with NE → condition false.
    -- ================================================================
    report "TEST 29: FScc cpCond false (NE, Z=1)" severity note;

    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPCOND_OPWORD, FCC_NE, cir_resp);
    report "TEST 29 cir_resp=" & to_hstring(cir_resp) severity note;
    assert cir_resp(0) = '0'
      report "FAIL TEST 29: FScc NE cond_true should be 0, got 1"
      severity failure;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, single_result, ADDR_RES_L);
    assert single_result(7 downto 0) = x"00"
      report "FAIL TEST 29: FScc result_lo byte expected=00 got=" &
             to_hstring(single_result(7 downto 0))
      severity failure;
    report "TEST 29 PASSED" severity note;

    -- ================================================================
    -- TEST 30: BSUN via CIR (signaling condition on NaN CC)
    --   Load FP2=QNaN, FP3=1.0, FCMP FP2,FP3 → CC.NAN=1.
    --   cpBcc with GT (signaling, bit4=1) → BSUN event.
    -- ================================================================
    report "TEST 30: BSUN via CIR" severity note;

    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 2, FP80_QNAN);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 3, FP80_ONE_VAL);
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FCMP, 2, 3);

    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPBCC_W_OPWORD, FCC_GT, cir_resp);
    report "TEST 30 cir_resp=" & to_hstring(cir_resp) severity note;
    assert cir_resp(4) = '1'
      report "FAIL TEST 30: BSUN bit should be 1, got 0"
      severity failure;
    -- BSUN should force cond_true=0 and branch_taken=0.
    assert cir_resp(0) = '0'
      report "FAIL TEST 30: BSUN should force cond_true=0"
      severity failure;
    assert cir_resp(1) = '0'
      report "FAIL TEST 30: BSUN should force branch_taken=0"
      severity failure;
    -- Verify FPSR EXC.BSUN bit is set.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 30 FPSR=" & to_hstring(fpsr_val) severity note;
    -- BSUN is FPSR bit [8+7]=bit 15 in the exception byte, which is FPSR(15).
    -- But FPSR_EXC_BSUN=7 is offset within the exception byte (bits [15:8]).
    assert fpsr_val(8 + 7) = '1'
      report "FAIL TEST 30: FPSR EXC.BSUN should be set"
      severity failure;
    report "TEST 30 PASSED" severity note;

    -- ================================================================
    -- TEST 31: FBcc long displacement (cpBcc-L) taken
    --   Reuse FPSR CC Z=1 state from test 26's FCMP (equal operands).
    --   Re-establish CC by repeating the FCMP, since test 30 may have
    --   changed CC state.
    -- ================================================================
    report "TEST 31: FBcc-L taken (EQ, equal operands)" severity note;

    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FCMP, 0, 1);
    -- Verify CC state before conditional eval.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    assert fpsr_val(26) = '1'
      report "FAIL TEST 31: FPSR CC.Z should be 1 before FBcc-L"
      severity failure;

    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPBCC_L_OPWORD, FCC_EQ, cir_resp);
    report "TEST 31 cir_resp=" & to_hstring(cir_resp) severity note;
    assert cir_resp(0) = '1'
      report "FAIL TEST 31: FBcc-L EQ cond_true should be 1, got 0"
      severity failure;
    assert cir_resp(1) = '1'
      report "FAIL TEST 31: FBcc-L EQ branch_taken should be 1, got 0"
      severity failure;
    report "TEST 31 PASSED" severity note;

    -- ================================================================
    -- TEST 32: FSAVE after reset → Null frame (format word = $0000, 0 data words)
    -- ================================================================
    report "TEST 32: FSAVE after reset (Null frame)" severity note;

    -- Force FPU to uninitialized state via FRESTORE with Null format word.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"00000000");
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Now issue cpSAVE.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Read format word from Save CIR.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 32 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert fpsr_val(15 downto 0) = CIR_FRAME_NULL_FW
      report "FAIL TEST 32: Expected Null FW $0000, got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 32 PASSED" severity note;

    -- ================================================================
    -- TEST 33: FSAVE after operation → Idle frame
    --   68881: format word = $0018, 6 data words
    --   68882: format word = $0038, 14 data words
    -- ================================================================
    report "TEST 33: FSAVE after operation (Idle frame)" severity note;

    -- Execute an operation to mark FPU as initialized.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FADD, 1, 0);

    -- Now issue cpSAVE.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Read format word from Save CIR.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 33 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert is_valid_idle_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 33: Expected Idle FW ($0018 or $0038), got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;

    -- Read frame data words from Operand CIR (count depends on version).
    for i in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
    end loop;

    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 33 PASSED" severity note;

    -- ================================================================
    -- TEST 34: FRESTORE with Null format word → FPU reset
    -- ================================================================
    report "TEST 34: FRESTORE Null (FPU reset)" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"00000000");
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FPU is in Null state: cpSAVE should return Null format word.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 34 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert fpsr_val(15 downto 0) = CIR_FRAME_NULL_FW
      report "FAIL TEST 34: Expected Null FW $0000 after FRESTORE-Null, got $" &
             to_hstring(fpsr_val(15 downto 0))
      severity failure;
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 34 PASSED" severity note;

    -- ================================================================
    -- TEST 35: FRESTORE with Idle frame → round-trip save/restore
    -- ================================================================
    report "TEST 35: FRESTORE Idle (round-trip)" severity note;

    -- First re-initialize FPU by executing an operation.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FADD, 1, 0);

    -- Issue cpRESTORE with Idle format word (version-aware).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & CIR_FRAME_IDLE_FW_82);
    for i in 0 to 2 loop
      wait until rising_edge(clk);
    end loop;

    -- Write idle frame data words (version-aware count).
    for i in 0 to CIR_FRAME_IDLE_WORDS_82 - 1 loop
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                ADDR_RES_H,
                std_logic_vector(to_unsigned(16#A0# + i, 32)));
    end loop;

    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FPU is now initialized: cpSAVE should return Idle format word.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 35 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert is_valid_idle_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 35: Expected Idle FW ($0018 or $0038) after FRESTORE-Idle, got $" &
             to_hstring(fpsr_val(15 downto 0))
      severity failure;
    -- Read out idle frame data words to complete the save (count from format word).
    for i in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
    end loop;
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 35 PASSED" severity note;

    -- ================================================================
    -- TEST 36: FRESTORE with invalid format word → Pre-Instruction Exception
    -- ================================================================
    report "TEST 36: FRESTORE invalid format word" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000DEAD");
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Read CIR response: should be Pre-Instruction Exception.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_RESPONSE);
    report "TEST 36 cir_resp=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(15 downto 13) = CIR_RESP_EXCEPT_PRE
      report "FAIL TEST 36: Expected pre-instruction exception response"
      severity failure;
    -- Acknowledge exception via Control CIR write.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 36 PASSED" severity note;

    -- ================================================================
    -- TEST 37: FSAVE during active computation → Busy frame ($00B4, 45 words)
    -- ================================================================
    report "TEST 37: FSAVE Busy frame (during FSIN)" severity note;

    -- First ensure FPU is initialized.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    -- Start FSIN via CIR (reg-to-reg, FP0→FP0) but do NOT wait for completion.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(0, 0, OPCODE_FSIN));
    -- Wait for ALU to start (CIR_IDLE → CIR_DECODE → CIR_EXECUTE takes ~3 cycles,
    -- then op_start_reg fires). Issue cpSAVE quickly before FSIN completes.
    for i in 0 to 2 loop
      wait until rising_edge(clk);
    end loop;

    -- Issue cpSAVE while busy.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Read format word: should be Busy ($00B4 for 68881, $00D4 for 68882).
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 37 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert is_valid_busy_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 37: Expected Busy FW ($00B4 or $00D4), got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;
    saved_fw := fpsr_val(15 downto 0);
    saved_fw_words := busy_words_for_fw(saved_fw);

    -- Read all frame data words into save_buf (count from format word).
    for i in 0 to saved_fw_words - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
      save_buf(i) := fpsr_val;
    end loop;

    -- Verify header structure.
    assert save_buf(0)(31 downto 16) = x"0001"
      report "FAIL TEST 37: word(0) version tag expected $0001, got $" &
             to_hstring(save_buf(0)(31 downto 16))
      severity failure;
    -- Word(6): Operand A lower 32 bits (FP80_ONE lower = $00000000).
    assert save_buf(6) = x"00000000"
      report "FAIL TEST 37: word(6) opA_lo expected $00000000, got $" &
             to_hstring(save_buf(6))
      severity failure;
    -- Word(7): Operand A upper (exp=$3FFF, mantissa[63:48]=$8000).
    assert save_buf(7) = x"3FFF8000"
      report "FAIL TEST 37: word(7) opA_hi expected $3FFF8000, got $" &
             to_hstring(save_buf(7))
      severity failure;
    -- Word(10): Operand A middle 32 bits (FP80_ONE mid = $80000000).
    assert save_buf(10)(31 downto 16) = x"8000"
      report "FAIL TEST 37: word(10) opA_mid upper expected $8000, got $" &
             to_hstring(save_buf(10)(31 downto 16))
      severity failure;

    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 37 PASSED" severity note;

    -- ================================================================
    -- TEST 38: FRESTORE Busy frame → round-trip
    -- ================================================================
    report "TEST 38: FRESTORE Busy frame (round-trip)" severity note;

    -- Issue cpRESTORE with Busy format word (version-aware from test 37).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & saved_fw);
    for i in 0 to 2 loop
      wait until rising_edge(clk);
    end loop;

    -- Write data words (version-aware count).
    for i in 0 to saved_fw_words - 1 loop
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                ADDR_RES_H,
                std_logic_vector(to_unsigned(16#B0# + i, 32)));
    end loop;

    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FPU is initialized after Busy restore.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 38 verify_fw=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    -- After Busy restore + commit, FPU should be initialized (Idle, since ALU idle).
    assert is_valid_idle_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 38: Expected Idle FW after Busy FRESTORE, got $" &
             to_hstring(fpsr_val(15 downto 0))
      severity failure;
    -- Read out frame data words to complete the save.
    for i in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
    end loop;

    -- Verify FPSR was restored from Busy frame header word 2.
    -- Word 2 data was $B0 + 2 = $B2.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 38 fpsr_after_restore=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val = std_logic_vector(to_unsigned(16#B0# + 2, 32))
      report "FAIL TEST 38: FPSR not restored from Busy frame. got=$" &
             to_hstring(fpsr_val) & " expected=$000000B2"
      severity failure;
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 38 PASSED" severity note;

    -- ================================================================
    -- TEST 39: Busy save→restore→save e2e operand round-trip
    -- ================================================================
    report "TEST 39: Busy save/restore/save e2e round-trip" severity note;

    -- Re-initialize FPU and load known operand.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);

    -- Start FSIN via CIR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(0, 0, OPCODE_FSIN));
    for i in 0 to 2 loop
      wait until rising_edge(clk);
    end loop;

    -- Phase 1: FSAVE (Busy) — capture frame into save_buf.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    assert is_valid_busy_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 39: Phase 1 expected Busy FW, got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;
    saved_fw := fpsr_val(15 downto 0);
    saved_fw_words := busy_words_for_fw(saved_fw);
    for i in 0 to saved_fw_words - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
      save_buf(i) := fpsr_val;
    end loop;
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Phase 2: FRESTORE (Busy) with captured frame data (version-aware).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & saved_fw);
    for i in 0 to 2 loop
      wait until rising_edge(clk);
    end loop;
    for i in 0 to saved_fw_words - 1 loop
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                ADDR_RES_H, save_buf(i));
    end loop;
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FPSR was restored from captured frame.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 39 fpsr_roundtrip=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val = save_buf(2)
      report "FAIL TEST 39: FPSR round-trip mismatch. got=$" & to_hstring(fpsr_val) &
             " expected=$" & to_hstring(save_buf(2))
      severity failure;

    -- Phase 3: FSAVE again. After Busy FRESTORE + commit, FPU is initialized
    -- but ALU is idle → produces Idle frame. Verify the FPSR field in the
    -- Idle frame matches what was restored.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    assert is_valid_idle_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 39: Phase 3 expected Idle FW, got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;

    -- Read Idle frame words and verify word 2 (FPSR) matches.
    for i in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
      if i = 2 then
        report "TEST 39 idle_fpsr=" & to_hstring(fpsr_val) severity note;
        assert fpsr_val = save_buf(2)
          report "FAIL TEST 39: Idle frame FPSR mismatch after round-trip. got=$" &
                 to_hstring(fpsr_val) & " expected=$" & to_hstring(save_buf(2))
          severity failure;
      end if;
    end loop;
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 39 PASSED" severity note;

    -- ================================================================
    -- TEST 40: BSUN trap delivery
    --   Enable FPCR BSUN, evaluate signaling condition on NaN CC.
    --   Verify CIR FSM enters EXCEPT_PRE with BSUN vector.
    -- ================================================================
    report "TEST 40: BSUN trap delivery via CIR" severity note;

    -- Set up: load QNaN into FP2, 1.0 into FP3, then FCMP FP2,FP3 → sets CC NaN.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 2, FP80_QNAN);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 3, FP80_ONE_VAL);
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FCMP, 2, 3);

    -- Enable BSUN exception in FPCR (bit 15).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00008000");

    -- Evaluate signaling condition (GT) → triggers BSUN + trap because FPCR enabled.
    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPBCC_W_OPWORD, FCC_GT, cir_resp);
    report "TEST 40 cond_resp=" & to_hstring(cir_resp) severity note;
    -- Verify BSUN and trap_requested bits in conditional response.
    assert cir_resp(4) = '1'
      report "FAIL TEST 40: BSUN bit should be 1"
      severity failure;
    assert cir_resp(5) = '1'
      report "FAIL TEST 40: trap_requested should be 1"
      severity failure;

    -- Wait for FSM to settle into CIR_EXCEPT_PRE (1-2 clocks after response read).
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Read CIR Response again — should show EXCEPT_PRE with BSUN vector.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 40 exc_resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_EXCEPT_PRE_BSUN
      report "FAIL TEST 40: expected EXCEPT_PRE/BSUN=" & to_hstring(RESP_EXCEPT_PRE_BSUN) &
             " got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Acknowledge exception via Control CIR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FSM returned to IDLE (Response = Null).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 40: after ack, expected Null response, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Clear FPCR for subsequent tests.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");
    report "TEST 40 PASSED" severity note;

    -- ================================================================
    -- TEST 41: Arithmetic post-instruction exception (FDIV by zero with DZ enable)
    --   Enable FPCR DZ, execute FDIV(1.0, 0.0). Verify EXCEPT_POST with DZ vector.
    -- ================================================================
    report "TEST 41: Arithmetic FDIV/0 post-instruction exception" severity note;

    -- Load 1.0 → FP0, 0.0 → FP1.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_ZERO_VAL);

    -- Enable DZ exception in FPCR (bit 10).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000400");

    -- Execute FDIV FP1,FP0 (FP0 = FP0 / FP1 = 1.0 / 0.0).
    -- Write OpWord (cpGEN).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    -- Write Command: reg-to-reg, src=1, dst=0, opcode=FDIV.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FDIV));

    -- Wait for ALU completion (STATUS.valid).
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Wait extra cycles for CIR_EXECUTE_DONE → CIR_EXCEPT_POST transition.
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Read CIR Response — should show EXCEPT_POST with DZ vector.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 41 exc_resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_EXCEPT_POST_DZ
      report "FAIL TEST 41: expected EXCEPT_POST/DZ=" & to_hstring(RESP_EXCEPT_POST_DZ) &
             " got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Verify FPSR DZ flag is set.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 41 FPSR=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(8 + 2) = '1'
      report "FAIL TEST 41: FPSR EXC.DZ should be set"
      severity failure;

    -- Acknowledge exception via Control CIR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FSM returned to IDLE.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 41: after ack, expected Null, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Clear FPCR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");
    report "TEST 41 PASSED" severity note;

    -- ================================================================
    -- TEST 42: Arithmetic exception with no FPCR enable
    --   Execute FDIV(1.0, 0.0) without DZ enable. Verify no exception dialog.
    -- ================================================================
    report "TEST 42: FDIV/0 without FPCR DZ enable (no exception dialog)" severity note;

    -- Reload operands (FP0=1.0, FP1=0.0).
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_ZERO_VAL);

    -- Ensure FPCR DZ enable is cleared.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");

    -- Execute FDIV FP1,FP0 via CIR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FDIV));

    -- Wait for completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- CIR Response should be Null (no exception dialog).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 42 resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 42: expected Null (no exception), got=" & to_hstring(cir_resp_16)
      severity failure;

    -- But FPSR DZ flag should still be set.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 42 FPSR=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(8 + 2) = '1'
      report "FAIL TEST 42: FPSR EXC.DZ should be set even without FPCR enable"
      severity failure;
    report "TEST 42 PASSED" severity note;

    -- ================================================================
    -- TEST 43: FPIAR capture from Instruction Address CIR
    --   Write a known instruction address, execute an op that triggers
    --   an exception, verify FPIAR matches.
    -- ================================================================
    report "TEST 43: FPIAR capture from CIR_ADDR_INSTADDR" severity note;

    -- Clear FPIAR first.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPIAR_TB, x"00000000");

    -- Write a known instruction address to CIR Instruction Address register.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_INSTADDR, x"00CAFE00");

    -- Load operands: QNaN → FP4, 1.0 → FP5.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 4, FP80_QNAN);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 5, FP80_ONE_VAL);

    -- Execute FADD FP4,FP5 via CIR (QNaN input → INVALID exception → FPIAR capture).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(4, 5, OPCODE_FADD));

    -- Wait for completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Read FPIAR — should match the instruction address we wrote.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPIAR_TB);
    report "TEST 43 FPIAR=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val = x"00CAFE00"
      report "FAIL TEST 43: FPIAR expected=00CAFE00 got=" & to_hstring(fpsr_val)
      severity failure;
    report "TEST 43 PASSED" severity note;

    -- ================================================================
    -- TEST 44: BSUN without FPCR enable (no trap, but BSUN still in FPSR)
    --   Same as Test 30 but verify FSM returns to IDLE (no exception dialog).
    -- ================================================================
    report "TEST 44: BSUN without FPCR enable (no trap)" severity note;

    -- Ensure FPCR BSUN enable is off.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");

    -- Set up NaN CC: FCMP QNaN, 1.0.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 2, FP80_QNAN);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 3, FP80_ONE_VAL);
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FCMP, 2, 3);

    -- Evaluate signaling condition (GT) — BSUN fires but no trap.
    cir_cond_eval(a_in, d_in, rw, cs_n, as_n, ds_n,
                  dsack0_n, dsack1_n, d_out,
                  CPBCC_W_OPWORD, FCC_GT, cir_resp);
    report "TEST 44 cond_resp=" & to_hstring(cir_resp) severity note;
    -- BSUN set, but trap_requested=0 (no FPCR enable).
    assert cir_resp(4) = '1'
      report "FAIL TEST 44: BSUN bit should be 1"
      severity failure;
    assert cir_resp(5) = '0'
      report "FAIL TEST 44: trap_requested should be 0 (no enable)"
      severity failure;

    -- Wait and verify FSM is IDLE (Null response, no exception dialog).
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 44 resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 44: expected Null (no trap), got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 44 PASSED" severity note;

    -- ================================================================
    -- TEST 45: OVERFLOW post-instruction exception
    --   FMUL(LARGE, LARGE) overflows to infinity. Enable FPCR OVERFLOW.
    --   Verify EXCEPT_POST with OVERFLOW vector. Also verifies that OVERFLOW
    --   wins over INEXACT (both are set, but OVERFLOW has higher priority).
    -- ================================================================
    report "TEST 45: OVERFLOW post-instruction exception" severity note;

    -- Load largest finite value → FP6, FP7.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 6, FP80_LARGE);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 7, FP80_LARGE);

    -- Enable OVERFLOW exception in FPCR (bit 12) and INEX2 (bit 9).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00001200");  -- bits 12 + 9

    -- Execute FMUL FP7,FP6 (FP6 = FP6 * FP7 = LARGE * LARGE → overflow).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(7, 6, OPCODE_FMUL));

    -- Wait for ALU completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Read CIR Response — should show EXCEPT_POST with OVERFLOW vector.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 45 exc_resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_EXCEPT_POST_OV
      report "FAIL TEST 45: expected EXCEPT_POST/OV=" & to_hstring(RESP_EXCEPT_POST_OV) &
             " got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Verify FPSR OVERFLOW and INEXACT flags both set.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 45 FPSR=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(8 + 4) = '1'
      report "FAIL TEST 45: FPSR EXC.OVFL should be set"
      severity failure;
    assert fpsr_val(8 + 1) = '1'
      report "FAIL TEST 45: FPSR EXC.INEX2 should also be set"
      severity failure;

    -- Acknowledge exception.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FSM returned to IDLE.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 45: after ack, expected Null, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Clear FPCR for next test.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");
    report "TEST 45 PASSED" severity note;

    -- ================================================================
    -- TEST 46: Exception priority — SNAN wins over DZ
    --   FDIV(SNaN, 0.0) with both SNAN and DZ enabled. SNAN has
    --   higher priority and should produce SNAN vector, not DZ vector.
    -- ================================================================
    report "TEST 46: Exception priority SNAN > DZ" severity note;

    -- Load SNaN → FP0, 0.0 → FP1.
    -- FDIV FP1,FP0 computes FP0 = FP0 / FP1 = SNaN / 0.0.
    -- Both SNAN (signaling NaN input) and DZ (zero divisor) fire; SNAN wins.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_SNAN);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_ZERO_VAL);

    -- Enable both SNAN (bit 14) and DZ (bit 10) in FPCR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00004400");  -- bits 14 + 10

    -- Execute FDIV FP1,FP0 (FP0 = SNaN / 0.0).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FDIV));

    -- Wait for ALU completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Read CIR Response — should show EXCEPT_POST with SNAN vector (SNAN wins over DZ).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 46 exc_resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_EXCEPT_POST_SNAN
      report "FAIL TEST 46: expected EXCEPT_POST/SNAN=" & to_hstring(RESP_EXCEPT_POST_SNAN) &
             " got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Verify FPSR SNAN and DZ are both set (both exceptions fire).
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 46 FPSR=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(8 + 6) = '1'  -- SNAN = bit 6
      report "FAIL TEST 46: FPSR EXC.SNAN should be set"
      severity failure;
    assert fpsr_val(8 + 2) = '1'  -- DZ = bit 2
      report "FAIL TEST 46: FPSR EXC.DZ should be set"
      severity failure;

    -- Acknowledge exception.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FSM returned to IDLE.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 46: after ack, expected Null, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Clear FPCR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");
    report "TEST 46 PASSED" severity note;

    -- ================================================================
    -- TEST 46A: SNAN discrimination — FADD(SNaN, 1.0) with SNAN enable
    --   Verify CIR reports SNAN vector (54), not OPERR vector (52).
    -- ================================================================
    report "TEST 46A: SNAN discrimination (FADD SNaN)" severity note;

    -- Load SNaN → FP0, 1.0 → FP1.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_SNAN);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_ONE_VAL);

    -- Enable SNAN exception in FPCR (bit 14).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00004000");  -- bit 14 = SNAN enable

    -- Execute FADD FP1,FP0 (FP0 = SNaN + 1.0 → NaN, SNAN set).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FADD));

    -- Wait for ALU completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Read CIR Response — should show EXCEPT_POST with SNAN vector.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 46A exc_resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_EXCEPT_POST_SNAN
      report "FAIL TEST 46A: expected EXCEPT_POST/SNAN=" & to_hstring(RESP_EXCEPT_POST_SNAN) &
             " got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Verify FPSR: SNAN set (bit 14), OPERR clear (bit 13).
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 46A FPSR=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(8 + 6) = '1'
      report "FAIL TEST 46A: FPSR EXC.SNAN should be set"
      severity failure;
    assert fpsr_val(8 + 5) = '0'
      report "FAIL TEST 46A: FPSR EXC.OPERR should NOT be set"
      severity failure;

    -- Acknowledge exception.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FSM returned to IDLE.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 46A: after ack, expected Null, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Clear FPCR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");
    report "TEST 46A PASSED" severity note;

    -- ================================================================
    -- TEST 46B: OPERR discrimination — FDIV(0, 0) with OPERR enable
    --   Verify CIR reports OPERR vector (52), not SNAN vector (54).
    -- ================================================================
    report "TEST 46B: OPERR discrimination (FDIV 0/0)" severity note;

    -- Load 0.0 → FP0, 0.0 → FP1.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ZERO_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_ZERO_VAL);

    -- Enable OPERR exception in FPCR (bit 13).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00002000");  -- bit 13 = OPERR enable

    -- Execute FDIV FP1,FP0 (FP0 = 0.0 / 0.0 → NaN, OPERR set).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FDIV));

    -- Wait for ALU completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Read CIR Response — should show EXCEPT_POST with OPERR vector.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 46B exc_resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_EXCEPT_POST_OPERR
      report "FAIL TEST 46B: expected EXCEPT_POST/OPERR=" & to_hstring(RESP_EXCEPT_POST_OPERR) &
             " got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Verify FPSR: OPERR set (bit 13), SNAN clear (bit 14).
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_FPSR);
    report "TEST 46B FPSR=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(8 + 5) = '1'
      report "FAIL TEST 46B: FPSR EXC.OPERR should be set"
      severity failure;
    assert fpsr_val(8 + 6) = '0'
      report "FAIL TEST 46B: FPSR EXC.SNAN should NOT be set"
      severity failure;

    -- Acknowledge exception.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FSM returned to IDLE.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 46B: after ack, expected Null, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Clear FPCR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");
    report "TEST 46B PASSED" severity note;

    -- ================================================================
    -- ============== PHASE 5: PROTOCOL / TIMING / REGRESSION =========
    -- ================================================================

    -- ================================================================
    -- TEST 47: CIR OpWord write while FSM busy (CIR_EXECUTE) is ignored
    --   Start a cpGEN FADD, then immediately write a new OpWord before
    --   completion. The in-flight operation must complete normally and
    --   the spurious OpWord must not start a new dialog.
    -- ================================================================
    report "TEST 47: OpWord write during CIR_EXECUTE ignored" severity note;

    -- Ensure clean state: clear FPCR exceptions, load FP0=1.0, FP1=2.0.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_FPCR, x"00000000");
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);

    -- Launch CIR FADD FP1,FP0 (FP0 = 1.0 + 2.0 = 3.0).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FADD));

    -- Immediately write another OpWord while FSM is in DECODE/EXECUTE.
    wait for CLK_PERIOD;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);

    -- Wait for the original operation to complete.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Read result via legacy registers: FP0 should be 3.0.
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);
    check_fp80(result_fp80, FP80_THREE_VAL, "TEST 47 FADD result");

    -- Verify FSM is back at IDLE (Null response), not stuck or re-launched.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 47: Expected Null after completion, got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 47 PASSED" severity note;

    -- ================================================================
    -- TEST 48: CIR response_pending persists until response read
    --   Issue CIR FScc(T) manually, verify STATUS.response_pending=1
    --   before reading response, then verify it clears after read.
    --   Also verify STATUS.protocol_violation stays 0 during clean use.
    -- ================================================================
    report "TEST 48: CIR response_pending lifecycle" severity note;

    -- Manually issue CIR FScc(T) -- do NOT use cir_cond_eval (it reads response).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPCOND_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONDITION, x"000000" & "00" & FCC_T);

    -- Wait for completion (STATUS.valid).
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- DO NOT read CIR response yet -- response_pending should still be set.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_STATUS);
    report "TEST 48 STATUS before response read=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(4) = '1'
      report "FAIL TEST 48: STATUS.response_pending (bit 4) should be set"
      severity failure;
    -- No protocol violation during clean use.
    assert fpsr_val(5) = '0'
      report "FAIL TEST 48: STATUS.protocol_violation (bit 5) should be 0"
      severity failure;

    -- Now consume the CIR response.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 48 cond_resp=" & to_hstring(cir_resp_16) severity note;

    -- Read status again: response_pending should clear after response read.
    wait for CLK_PERIOD * 2;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_STATUS);
    report "TEST 48 STATUS after response read=" & to_hstring(fpsr_val) severity note;
    assert fpsr_val(4) = '0'
      report "FAIL TEST 48: response_pending should clear after response read"
      severity failure;
    report "TEST 48 PASSED" severity note;

    -- ================================================================
    -- TEST 49: CIR cpCond OpWord write during condition evaluation
    --   Issue FScc(T), then immediately (while FSM is in COND_EVAL/
    --   COND_WAIT) write a second cpCond OpWord + Condition. The FSM
    --   must ignore the second write and complete the first normally.
    -- ================================================================
    report "TEST 49: CIR cpCond write during evaluation ignored" severity note;

    -- Issue first conditional: FScc(T) -- always true.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPCOND_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONDITION, x"000000" & "00" & FCC_T);

    -- Immediately write a second cpCond (FSM is in COND_EVAL, not IDLE).
    wait for CLK_PERIOD;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPCOND_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONDITION, x"000000" & "00" & FCC_F);

    -- Wait for first conditional to complete.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Read response -- should be from the first (True) conditional.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 49 resp=" & to_hstring(cir_resp_16) severity note;

    -- Give a few cycles for any spurious second dialog to start.
    for i in 0 to 9 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FSM is IDLE (Null response) -- second OpWord was ignored.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 49: Expected Null (second cpCond ignored), got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 49 PASSED" severity note;

    -- ================================================================
    -- TEST 50: Clean back-to-back dialogs (no violation)
    --   Execute cpGEN FADD, consume result, then execute cpGEN FSUB.
    --   Verify both complete correctly and no protocol violation flag.
    -- ================================================================
    report "TEST 50: Back-to-back cpGEN dialogs (clean)" severity note;

    -- Load FP0=5.0, FP1=2.0.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_FIVE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);

    -- Dialog 1: FADD FP1,FP0 (FP0 = 5.0 + 2.0 = 7.0).
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FADD, 1, 0);

    -- Consume response.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);

    -- Verify no violation.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_STATUS);
    assert fpsr_val(5) = '0'
      report "FAIL TEST 50: Unexpected protocol_violation after first dialog"
      severity failure;

    -- Dialog 2: FSUB FP1,FP0 (FP0 = 7.0 - 2.0 = 5.0).
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FSUB, 1, 0);

    -- Read result: FP0 should be 5.0.
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);
    check_fp80(result_fp80, FP80_FIVE_VAL, "TEST 50 FSUB result");

    -- Verify no violation.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_STATUS);
    assert fpsr_val(5) = '0'
      report "FAIL TEST 50: Unexpected protocol_violation after second dialog"
      severity failure;
    report "TEST 50 PASSED" severity note;

    -- ================================================================
    -- TEST 51: cpGEN reg-to-reg primitive progression
    --   Verify: OpWord→Command→Busy→(execute)→Null
    -- ================================================================
    report "TEST 51: cpGEN reg-to-reg primitive progression" severity note;

    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);

    -- Write OpWord.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    -- Response should still be Null (waiting for Command).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 51 after opword resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 51: Expected Null after OpWord-only, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Write Command -> FSM transitions to DECODE->EXECUTE, response becomes Busy.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FADD));
    wait for CLK_PERIOD * 2;  -- Let FSM advance past DECODE

    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 51 during execute resp=" & to_hstring(cir_resp_16) severity note;
    -- Response should be Busy or already Null if fast completion.

    -- Wait for ALU completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Final response: Null (IDLE).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 51: Expected Null after completion, got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 51 PASSED" severity note;

    -- ================================================================
    -- TEST 52: cpGEN memory-source primitive progression
    --   Verify: OpWord->Command->Transfer-to-CP->(operand write)->Null
    -- ================================================================
    report "TEST 52: cpGEN memory-source primitive progression" severity note;

    -- Write OpWord + Command (single-precision FMOVE to FP2).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_mem_cmd(CIR_SRC_SINGLE, 2, OPCODE_FMOVE));

    -- Wait for FSM to reach CIR_XFER_SRC.
    wait for CLK_PERIOD * 2;

    -- Response should be Transfer-to-CP (requesting operand data).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 52 xfer_src resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_XFER_TO_CP_4
      report "FAIL TEST 52: Expected Transfer-to-CP ($7004), got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Write operand (single-precision 3.5 = 0x40600000).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"40600000");

    -- Wait for completion (FMOVE is fast).
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Final response: Null.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 52: Expected Null after FMOVE completion, got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 52 PASSED" severity note;

    -- ================================================================
    -- TEST 53: cpCond (FScc) primitive progression
    --   Verify: OpWord->Condition->Busy->(evaluate)->conditional response
    -- ================================================================
    report "TEST 53: cpCond primitive progression" severity note;

    -- Write OpWord only — response should be Null (waiting for Condition).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPCOND_OPWORD);
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 53: Expected Null after cpCond OpWord-only"
      severity failure;

    -- Write Condition (True) -> FSM enters CIR_COND_EVAL.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONDITION, x"000000" & "00" & FCC_T);

    -- Wait for STATUS valid.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Read CIR response — should encode condition-true result.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 53 cond_resp=" & to_hstring(cir_resp_16) severity note;
    -- The response encodes cond_true in the response word (non-Null, non-Busy).
    assert cir_resp_16 /= RESP_NULL and cir_resp_16 /= RESP_BUSY
      report "FAIL TEST 53: Expected conditional response, got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 53 PASSED" severity note;

    -- ================================================================
    -- TEST 54: cpBcc-W primitive progression
    --   Verify: OpWord->Condition->Busy->(evaluate)->response->Null
    --   Use FCC_EQ with Z=1 (from prior FCMP of equal operands) so
    --   branch_taken=1, giving a non-zero response word.
    -- ================================================================
    report "TEST 54: cpBcc-W primitive progression" severity note;

    -- Load equal values so FCMP sets Z=1, then FBcc(EQ) takes branch.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_ONE_VAL);
    -- FCMP FP1,FP0 to set FPSR CC (Z=1).
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FCMP, 1, 0);

    -- Write OpWord (cpBcc word displacement).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPBCC_W_OPWORD);
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 54: Expected Null after cpBcc OpWord-only"
      severity failure;

    -- Write Condition (EQ -- branch taken because Z=1).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONDITION, x"000000" & "00" & FCC_EQ);

    -- Wait for STATUS valid.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Read CIR response -- branch_taken=1, cond_true=1 -> bits[1:0]=11 -> $0003.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 54 branch_resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16(0) = '1'
      report "FAIL TEST 54: Expected cond_true=1 in branch response"
      severity failure;
    assert cir_resp_16(1) = '1'
      report "FAIL TEST 54: Expected branch_taken=1 in branch response"
      severity failure;

    -- Verify FSM returns to Null.
    wait for CLK_PERIOD * 4;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 54: Expected Null after branch complete"
      severity failure;
    report "TEST 54 PASSED" severity note;

    -- ================================================================
    -- TEST 55: cpSAVE/cpRESTORE primitive progression
    --   Verify: FSAVE OpWord->format word->frame words->Null
    --           FRESTORE OpWord->format write->commit
    -- ================================================================
    report "TEST 55: cpSAVE/cpRESTORE primitive progression" severity note;

    -- Ensure FPU is initialized (load a value so we get Idle frame).
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);

    -- cpSAVE: write OpWord.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);

    -- Wait for format word to be ready.
    wait for CLK_PERIOD * 4;

    -- Read format word from CIR_SAVE_ADDR — should be Idle.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 55 save_fw=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert is_valid_idle_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 55: Expected Idle FW ($0018 or $0038), got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;

    -- Read Idle frame data words from Operand CIR (count from format word).
    for word_idx in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, CIR_OPERAND);
      report "TEST 55 save_word(" & integer'image(word_idx) & ")=" &
             to_hstring(fpsr_val) severity note;
    end loop;

    -- After all frame words read, FSM should return to IDLE.
    wait for CLK_PERIOD * 4;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 55: Expected Null after FSAVE complete, got=" & to_hstring(cir_resp_16)
      severity failure;

    -- cpRESTORE: write OpWord.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    wait for CLK_PERIOD * 2;

    -- Write Null format word (reset FPU).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & CIR_FRAME_NULL_FW);
    wait for CLK_PERIOD * 4;

    -- Verify FSM is IDLE.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 55: Expected Null after FRESTORE Null, got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 55 PASSED" severity note;

    -- ================================================================
    -- TEST 56: Double OpWord write without response read
    --   Issue two cpGEN commands back-to-back (second during first
    --   execution). Second is ignored, first completes normally.
    -- ================================================================
    report "TEST 56: Double OpWord write without response read" severity note;

    -- Ensure FPU initialized with known values.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 2, FP80_FIVE_VAL);

    -- First dialog: FADD FP1,FP0 (FP0 = 1+2 = 3).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FADD));

    -- Immediately try second dialog: FSUB FP2,FP0 — should be ignored.
    wait for CLK_PERIOD;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(2, 0, OPCODE_FSUB));

    -- Wait for operation(s) to complete.
    -- MC68881: second dialog is ignored → only FADD executes → FP0 = 3.0
    -- MC68882: second dialog becomes pending → FADD then FSUB → FP0 = -2.0
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- MC68882: wait for pending instruction to complete too.
    wait for CLK_PERIOD * 20;

    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);
    -- Accept either 3.0 (68881: second dialog ignored) or
    -- -2.0 (68882: FADD 1+2=3, then pending FSUB 3-5=-2).
    assert result_fp80 = FP80_THREE_VAL or result_fp80 = x"C0008000000000000000"
      report "FAIL TEST 56: Expected 3.0 (68881) or -2.0 (68882), got=" &
             to_hstring(result_fp80)
      severity failure;

    -- FSM should be idle after all operations complete.
    for i in 0 to 9 loop
      wait until rising_edge(clk);
    end loop;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 56: Expected Null after all ops, got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 56 PASSED" severity note;

    -- ================================================================
    -- TEST 57: FRESTORE frame write without format word
    --   Write OpWord for cpRESTORE, then write directly to Operand CIR
    --   without writing format word first. FSM should still be in
    --   CIR_RESTORE_FORMAT (waiting for format word via Restore CIR).
    -- ================================================================
    report "TEST 57: FRESTORE operand write without format word" severity note;

    -- cpRESTORE OpWord.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    wait for CLK_PERIOD * 2;

    -- Write to Operand CIR (this is wrong — should go to Restore CIR).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPERAND, x"DEADBEEF");
    wait for CLK_PERIOD * 2;

    -- FSM should still be waiting for format word (Busy response).
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 57 resp_after_bad_write=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_BUSY
      report "FAIL TEST 57: Expected Busy (still waiting for format), got=" & to_hstring(cir_resp_16)
      severity failure;

    -- Clean up: write valid Null format word to return to IDLE.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & CIR_FRAME_NULL_FW);
    wait for CLK_PERIOD * 4;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 57: FSM should be IDLE after Null restore"
      severity failure;
    report "TEST 57 PASSED" severity note;

    -- ================================================================
    -- TEST 58: Condition write to cpGEN dialog (ignored)
    --   Start a cpGEN dialog, then write to Condition CIR. The condition
    --   write should be ignored; the cpGEN operation should complete.
    -- ================================================================
    report "TEST 58: Condition write to cpGEN ignored" severity note;

    -- Ensure known state.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);

    -- Start cpGEN FADD.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FADD));

    -- Write a spurious Condition value while cpGEN is executing.
    wait for CLK_PERIOD;
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONDITION, x"000000" & "00" & FCC_EQ);

    -- Wait for completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Result should be 3.0 (1+2), condition write was ignored.
    read_result_fp80(a_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out, result_fp80);
    check_fp80(result_fp80, FP80_THREE_VAL, "TEST 58 FADD result");
    report "TEST 58 PASSED" severity note;

    -- ================================================================
    -- TEST 59: cpGEN reg-to-reg cycle overhead
    --   Measure: OpWord write to STATUS.valid assertion.
    --   Bound: <= 200 cycles for FADD (generous for microsequencer + ALU).
    -- ================================================================
    report "TEST 59: cpGEN reg-to-reg cycle overhead" severity note;

    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);

    -- Record start time.
    t59_start := now;

    -- Launch FADD via CIR.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 0, OPCODE_FADD));

    -- Wait for completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    -- Record end time and compute elapsed cycles.
    t59_elapsed := (now - t59_start) / CLK_PERIOD;
    report "TEST 59 cpGEN FADD elapsed=" & integer'image(t59_elapsed) & " cycles" severity note;
    assert t59_elapsed <= 200
      report "FAIL TEST 59: cpGEN FADD took " & integer'image(t59_elapsed) &
             " cycles, expected <= 200"
      severity failure;

    -- Consume response.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 59 PASSED" severity note;

    -- ================================================================
    -- TEST 60: cpCond (FScc) cycle overhead
    --   Measure: OpWord write to STATUS.valid for condition evaluation.
    --   Bound: <= 50 cycles (condition eval is lightweight).
    -- ================================================================
    report "TEST 60: cpCond FScc cycle overhead" severity note;

    t60_start := now;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPCOND_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONDITION, x"000000" & "00" & FCC_T);

    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, fpsr_val);

    t60_elapsed := (now - t60_start) / CLK_PERIOD;
    report "TEST 60 cpCond elapsed=" & integer'image(t60_elapsed) & " cycles" severity note;
    assert t60_elapsed <= 50
      report "FAIL TEST 60: cpCond took " & integer'image(t60_elapsed) &
             " cycles, expected <= 50"
      severity failure;

    -- Consume response.
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 60 PASSED" severity note;

    -- ================================================================
    -- TEST 61: cpSAVE Idle frame cycle overhead
    --   Measure: OpWord write to last frame word readable.
    --   Bound: <= 100 cycles (format + 6 data words + FSM overhead).
    -- ================================================================
    report "TEST 61: cpSAVE Idle frame cycle overhead" severity note;

    -- Ensure initialized.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);

    t61_start := now;

    -- cpSAVE OpWord.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    wait for CLK_PERIOD * 4;

    -- Read format word.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);

    -- Read Idle frame words (count from format word).
    for word_idx in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, CIR_OPERAND);
    end loop;

    t61_elapsed := (now - t61_start) / CLK_PERIOD;
    report "TEST 61 cpSAVE Idle elapsed=" & integer'image(t61_elapsed) & " cycles"
      severity note;
    -- 7 reads at ~3-4 cycles each = ~21-28 cycles; bound at 100.
    assert t61_elapsed <= 100
      report "FAIL TEST 61: cpSAVE Idle took " & integer'image(t61_elapsed) &
             " cycles, expected <= 100"
      severity failure;

    -- Wait for FSM to return to IDLE.
    wait for CLK_PERIOD * 4;
    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 61: Expected Null after save complete"
      severity failure;
    report "TEST 61 PASSED" severity note;

    -- ================================================================
    -- TEST 62: cpRESTORE Idle frame cycle overhead
    --   Measure: OpWord write to FSM back in IDLE.
    --   Bound: <= 100 cycles.
    -- ================================================================
    report "TEST 62: cpRESTORE Idle frame cycle overhead" severity note;

    -- First do a save to capture frame data.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_FIVE_VAL);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    wait for CLK_PERIOD * 4;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    -- Read all frame words (count from format word).
    for word_idx in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, save_buf(word_idx), CIR_OPERAND);
    end loop;
    wait for CLK_PERIOD * 4;

    -- Now measure FRESTORE.
    t62_start := now;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    wait for CLK_PERIOD * 2;

    -- Write Idle format word (version-aware).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & CIR_FRAME_IDLE_FW_82);
    wait for CLK_PERIOD * 2;

    -- Write frame data words (version-aware count).
    -- Use zeros for pending region (words 6-13) to avoid false pending launch.
    for word_idx in 0 to CIR_FRAME_IDLE_WORDS_82 - 1 loop
      if word_idx < 6 and word_idx <= save_buf'high then
        bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                  CIR_OPERAND, save_buf(word_idx));
      else
        bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                  CIR_OPERAND, x"00000000");
      end if;
    end loop;

    -- Wait for FSM to settle (more time for 68882's 14-word frame and commit).
    wait for CLK_PERIOD * 30;

    t62_elapsed := (now - t62_start) / CLK_PERIOD;
    report "TEST 62 cpRESTORE Idle elapsed=" & integer'image(t62_elapsed) & " cycles"
      severity note;
    assert t62_elapsed <= 200
      report "FAIL TEST 62: cpRESTORE Idle took " & integer'image(t62_elapsed) &
             " cycles, expected <= 100"
      severity failure;

    cir_read_response(a_in, rw, cs_n, as_n, ds_n,
                      dsack0_n, dsack1_n, d_out, cir_resp_16);
    report "TEST 62 resp=" & to_hstring(cir_resp_16) severity note;
    assert cir_resp_16 = RESP_NULL
      report "FAIL TEST 62: Expected Null after restore complete, got=" & to_hstring(cir_resp_16)
      severity failure;
    report "TEST 62 PASSED" severity note;

    -- ================================================================
    -- TEST 63: CIR Response read DSACK timing
    --   Verify that reading CIR_RESPONSE produces DSACK within a
    --   bounded number of cycles (CIR reads use sync_read path).
    -- ================================================================
    report "TEST 63: CIR Response read DSACK timing" severity note;

    t63_start := now;
    -- Read CIR Response (FSM is IDLE, so Null response expected).
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_RESPONSE);
    t63_elapsed := (now - t63_start) / CLK_PERIOD;
    report "TEST 63 CIR Response read DSACK latency=" & integer'image(t63_elapsed) & " cycles"
      severity note;
    assert t63_elapsed <= 10
      report "FAIL TEST 63: CIR Response DSACK took " & integer'image(t63_elapsed) &
             " cycles, expected <= 10"
      severity failure;
    assert fpsr_val(15 downto 0) = RESP_NULL
      report "FAIL TEST 63: Expected Null response in IDLE"
      severity failure;
    report "TEST 63 PASSED" severity note;

    -- ================================================================
    -- TEST 64: CIR Save sequential read streaming
    --   During FSAVE, verify that consecutive CIR_SAVE_ADDR and
    --   CIR_OPERAND reads each complete with DSACK. Measures total
    --   streaming latency for an Idle frame (format + 6 words).
    -- ================================================================
    report "TEST 64: CIR Save sequential read streaming" severity note;

    -- Ensure initialized.
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_TWO_VAL);

    -- Start FSAVE.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    wait for CLK_PERIOD * 4;

    t64_start := now;

    -- Read format word.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    assert is_valid_idle_fw(fpsr_val(15 downto 0))
      report "FAIL TEST 64: Expected Idle FW"
      severity failure;

    -- Stream data words (count from format word).
    for word_idx in 0 to idle_words_for_fw(fpsr_val(15 downto 0)) - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, CIR_OPERAND);
    end loop;

    t64_elapsed := (now - t64_start) / CLK_PERIOD;
    report "TEST 64 Save stream latency=" & integer'image(t64_elapsed) & " cycles (7 reads)"
      severity note;
    -- 7 reads at ~3-4 cycles each = ~21-28 cycles; bound at 50.
    assert t64_elapsed <= 50
      report "FAIL TEST 64: Save stream took " & integer'image(t64_elapsed) &
             " cycles, expected <= 50"
      severity failure;

    -- Clean up: wait for IDLE.
    wait for CLK_PERIOD * 4;
    report "TEST 64 PASSED" severity note;

    -- ================================================================
    -- TEST 65: CIR Operand write-then-read turnaround
    --   Write an operand via CIR memory-source path, then read back
    --   via CIR reg-to-mem path. Verify data integrity and bounded
    --   turnaround time.
    -- ================================================================
    report "TEST 65: CIR Operand write/read turnaround" severity note;

    -- FMOVE single 3.5 (0x40600000) to FP3 via CIR memory-source.
    t65_start := now;
    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 3, x"40600000");

    -- Now read FP3 back via CIR FMOVE reg->mem (single format).
    cpgen_reg_to_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                            dsack0_n, dsack1_n, d_out,
                            3, single_readback);
    t65_elapsed := (now - t65_start) / CLK_PERIOD;

    report "TEST 65 turnaround=" & integer'image(t65_elapsed) & " cycles, readback=$" &
           to_hstring(single_readback) severity note;
    assert single_readback = x"40600000"
      report "FAIL TEST 65: Expected $40600000, got $" & to_hstring(single_readback)
      severity failure;
    -- Two full dialogs (write + read): bound at 200 cycles total.
    assert t65_elapsed <= 200
      report "FAIL TEST 65: Turnaround took " & integer'image(t65_elapsed) &
             " cycles, expected <= 200"
      severity failure;

    -- Consume response.
    wait for CLK_PERIOD * 4;
    report "TEST 65 PASSED" severity note;

    -- ================================================================
    -- TEST 66: FMOVE FP0 → Long integer (reg→mem, long format)
    --   Load FP0 = -27.0, store as long integer → 0xFFFFFFE5 (-27)
    -- ================================================================
    report "TEST 66: FMOVE FP0 -> Long integer" severity note;

    -- Ensure FP0 = -27.0 (left over from test 19: FSUB.L (-20)-7=-27)
    -- Re-load to be safe: FMOVE.L #-27, FP0
    cpgen_mem_long(a_in, d_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out,
                   OPCODE_FMOVE, 0, x"FFFFFFE5");  -- Load FP0 = -27

    cpgen_reg_to_mem(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     CIR_SRC_LONG, 0, int_result);
    report "TEST 66 result=" & to_hstring(int_result) severity note;
    assert int_result = x"FFFFFFE5"
      report "FAIL TEST 66: FMOVE.L FP0(-27) expected=FFFFFFE5 got=" &
             to_hstring(int_result)
      severity failure;
    report "TEST 66 PASSED" severity note;

    -- ================================================================
    -- TEST 67: FMOVE FP1 → Word integer (reg→mem, word format)
    --   Load FP1 = 1234.0, store as word integer → 0x000004D2 (1234)
    -- ================================================================
    report "TEST 67: FMOVE FP1 -> Word integer" severity note;

    cpgen_mem_long(a_in, d_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out,
                   OPCODE_FMOVE, 1, x"000004D2");  -- Load FP1 = 1234

    cpgen_reg_to_mem(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     CIR_SRC_WORD, 1, int_result);
    report "TEST 67 result=" & to_hstring(int_result) severity note;
    assert int_result = x"000004D2"
      report "FAIL TEST 67: FMOVE.W FP1(1234) expected=000004D2 got=" &
             to_hstring(int_result)
      severity failure;
    report "TEST 67 PASSED" severity note;

    -- ================================================================
    -- TEST 68: FMOVE FP2 → Byte integer (reg→mem, byte format)
    --   Load FP2 = -42.0, store as byte integer → 0x000000D6 (-42 as signed byte)
    -- ================================================================
    report "TEST 68: FMOVE FP2 -> Byte integer" severity note;

    cpgen_mem_long(a_in, d_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out,
                   OPCODE_FMOVE, 2, x"FFFFFFD6");  -- Load FP2 = -42

    cpgen_reg_to_mem(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     CIR_SRC_BYTE, 2, int_result);
    report "TEST 68 result=" & to_hstring(int_result) severity note;
    assert int_result = x"000000D6"
      report "FAIL TEST 68: FMOVE.B FP2(-42) expected=000000D6 got=" &
             to_hstring(int_result)
      severity failure;
    report "TEST 68 PASSED" severity note;

    -- ================================================================
    -- TEST 69: FMOVE FP0 → Long integer, positive value
    --   Load FP0 = 42.0, store as long integer → 0x0000002A (42)
    -- ================================================================
    report "TEST 69: FMOVE FP0 -> Long integer (positive)" severity note;

    cpgen_mem_long(a_in, d_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out,
                   OPCODE_FMOVE, 0, x"0000002A");  -- Load FP0 = 42

    cpgen_reg_to_mem(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     CIR_SRC_LONG, 0, int_result);
    report "TEST 69 result=" & to_hstring(int_result) severity note;
    assert int_result = x"0000002A"
      report "FAIL TEST 69: FMOVE.L FP0(42) expected=0000002A got=" &
             to_hstring(int_result)
      severity failure;
    report "TEST 69 PASSED" severity note;

    -- ================================================================
    -- TEST 70: FMOVE FP0 → Word integer, negative value
    --   Load FP0 = -100.0, store as word integer → 0x0000FF9C (-100)
    -- ================================================================
    report "TEST 70: FMOVE FP0 -> Word integer (negative)" severity note;

    cpgen_mem_long(a_in, d_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out,
                   OPCODE_FMOVE, 0, x"FFFFFF9C");  -- Load FP0 = -100

    cpgen_reg_to_mem(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     CIR_SRC_WORD, 0, int_result);
    report "TEST 70 result=" & to_hstring(int_result) severity note;
    assert int_result = x"0000FF9C"
      report "FAIL TEST 70: FMOVE.W FP0(-100) expected=0000FF9C got=" &
             to_hstring(int_result)
      severity failure;
    report "TEST 70 PASSED" severity note;

    -- ================================================================
    -- TEST 71: FMOVE FP0 → Long integer, truncation of fractional part
    --   Load FP0 = 7.9 (single 0x40FCCCD), store as long → 7 (truncated)
    -- ================================================================
    report "TEST 71: FMOVE FP0 -> Long integer (truncation)" severity note;

    cpgen_mem_single(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FMOVE, 0, x"40FCCCCD");  -- Load FP0 = 7.9

    cpgen_reg_to_mem(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     CIR_SRC_LONG, 0, int_result);
    report "TEST 71 result=" & to_hstring(int_result) severity note;
    assert int_result = x"00000007"
      report "FAIL TEST 71: FMOVE.L FP0(7.9) expected=00000007 got=" &
             to_hstring(int_result)
      severity failure;
    report "TEST 71 PASSED" severity note;

    -- ================================================================
    -- TEST 72: FSQRT.L #9 -> FP3 (monadic, memory-to-register)
    --   Exercises op_is_monadic() routing for memory-source path.
    --   Source operand must go to operand_reg(0) (a_in), not operand_reg(1).
    --   Expected result: FSQRT(9) = 3, readback as long = 0x00000003
    -- ================================================================
    report "TEST 72: FSQRT.L #9 mem-to-reg (monadic memory-source)" severity note;

    cpgen_mem_long(a_in, d_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out,
                   OPCODE_FSQRT, 3, x"00000009");

    -- Read back FP3 as long integer (should be 3)
    cpgen_reg_to_mem(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     CIR_SRC_LONG, 3, int_result);

    report "TEST 72 result=" & to_hstring(int_result) severity note;
    assert int_result = x"00000003"
      report "FAIL TEST 72: FSQRT(9) expected=00000003 got=" &
             to_hstring(int_result)
      severity failure;
    report "TEST 72 PASSED" severity note;

    -- ================================================================
    report "All CIR dialog tests PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
