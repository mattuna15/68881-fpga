-- CIR Dialog Protocol Testbench
-- Tests the Section 7 coprocessor interface register dialog.
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
    variable fpsr_val : std_logic_vector(31 downto 0) := (others => '0');
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
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_OPWORD, CPGEN_OPWORD, "10", 2);
    cmd_word := make_cpgen_reg_cmd(3, 2, OPCODE_FADD);
    bus_write_sized(a_in, d_in, rw, cs_n, as_n, ds_n, size_n,
                    dsack0_n, dsack1_n, CIR_COMMAND, cmd_word, "10", 2);
    wait_for_valid_sized(a_in, rw, cs_n, as_n, ds_n, size_n,
                         dsack0_n, dsack1_n, d_out, status_word, "10", 2);

    -- Readback FP2 as single via CIR FMOVE reg→mem (16-bit bus)
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
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"00000000");
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Now issue cpSAVE.
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
    -- TEST 33: FSAVE after operation → Idle frame (format word = $0018, 6 data words)
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
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Read format word from Save CIR.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 33 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert fpsr_val(15 downto 0) = CIR_FRAME_IDLE_FW
      report "FAIL TEST 33: Expected Idle FW $0018, got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;

    -- Read 6 frame data words from Operand CIR.
    for i in 0 to CIR_FRAME_IDLE_WORDS - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
      report "TEST 33 frame_word(" & integer'image(i) & ")=" & to_hstring(fpsr_val) severity note;
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
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"00000000");
    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FPU is in Null state: cpSAVE should return Null format word.
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

    -- Issue cpRESTORE with Idle format word.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"00000018");
    for i in 0 to 2 loop
      wait until rising_edge(clk);
    end loop;

    -- Write 6 idle frame data words (arbitrary non-zero data).
    for i in 0 to CIR_FRAME_IDLE_WORDS - 1 loop
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                ADDR_RES_H,
                std_logic_vector(to_unsigned(16#A0# + i, 32)));
    end loop;

    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FPU is now initialized: cpSAVE should return Idle format word.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 35 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert fpsr_val(15 downto 0) = CIR_FRAME_IDLE_FW
      report "FAIL TEST 35: Expected Idle FW $0018 after FRESTORE-Idle, got $" &
             to_hstring(fpsr_val(15 downto 0))
      severity failure;
    -- Read out the 6 idle frame data words to complete the save.
    for i in 0 to CIR_FRAME_IDLE_WORDS - 1 loop
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
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;

    -- Read format word: should be Busy ($00B4).
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 37 format_word=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    assert fpsr_val(15 downto 0) = CIR_FRAME_BUSY_FW
      report "FAIL TEST 37: Expected Busy FW $00B4, got $" & to_hstring(fpsr_val(15 downto 0))
      severity failure;

    -- Read all 45 frame data words.
    for i in 0 to CIR_FRAME_BUSY_WORDS - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
      if i < 6 then
        report "TEST 37 frame_word(" & integer'image(i) & ")=" & to_hstring(fpsr_val)
          severity note;
      end if;
    end loop;

    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 37 PASSED" severity note;

    -- ================================================================
    -- TEST 38: FRESTORE Busy frame → round-trip
    -- ================================================================
    report "TEST 38: FRESTORE Busy frame (round-trip)" severity note;

    -- Issue cpRESTORE with Busy format word.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"000000B4");
    for i in 0 to 2 loop
      wait until rising_edge(clk);
    end loop;

    -- Write 45 data words (arbitrary non-zero test data).
    for i in 0 to CIR_FRAME_BUSY_WORDS - 1 loop
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                ADDR_RES_H,
                std_logic_vector(to_unsigned(16#B0# + i, 32)));
    end loop;

    for i in 0 to 5 loop
      wait until rising_edge(clk);
    end loop;

    -- Verify FPU is initialized after Busy restore.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, fpsr_val, CIR_SAVE_ADDR);
    report "TEST 38 verify_fw=" & to_hstring(fpsr_val(15 downto 0)) severity note;
    -- After Busy restore + commit, FPU should be initialized (Idle or Busy).
    assert fpsr_val(15 downto 0) /= CIR_FRAME_NULL_FW
      report "FAIL TEST 38: FPU should be initialized after Busy FRESTORE"
      severity failure;
    -- Read out frame data words to complete the save.
    for i in 0 to CIR_FRAME_IDLE_WORDS - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, fpsr_val, ADDR_RES_H);
    end loop;
    for i in 0 to 3 loop
      wait until rising_edge(clk);
    end loop;
    report "TEST 38 PASSED" severity note;

    -- ================================================================
    report "All CIR dialog tests PASSED" severity note;
    std.env.finish;
  end process;

end architecture sim;
