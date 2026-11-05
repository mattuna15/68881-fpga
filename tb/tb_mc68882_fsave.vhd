-- MC68882 FSAVE/FRESTORE and Pending Instruction Pipeline Testbench
-- Tests the 68882-specific features: frame format words, frame sizes,
-- cross-compatible FRESTORE, and pending instruction pipeline.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

use work.mc68881_pkg.all;

entity tb_mc68882_fsave is
end entity tb_mc68882_fsave;

architecture sim of tb_mc68882_fsave is
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

  -- Addresses.
  constant ADDR_OPSEL    : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L    : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPA_H    : unsigned(4 downto 0) := to_unsigned(2, 5);
  constant ADDR_OPA_E    : unsigned(4 downto 0) := to_unsigned(3, 5);
  constant ADDR_RES_L    : unsigned(4 downto 0) := to_unsigned(7, 5);
  constant ADDR_RES_H    : unsigned(4 downto 0) := to_unsigned(8, 5);
  constant ADDR_RES_E    : unsigned(4 downto 0) := to_unsigned(9, 5);
  constant ADDR_STATUS   : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_MOVE_CFG : unsigned(4 downto 0) := to_unsigned(23, 5);

  -- CIR addresses.
  constant CIR_OPWORD      : unsigned(4 downto 0) := unsigned(std_logic_vector(CIR_ADDR_OPWORD));
  constant CIR_COMMAND      : unsigned(4 downto 0) := unsigned(std_logic_vector(CIR_ADDR_COMMAND));
  constant CIR_OPERAND      : unsigned(4 downto 0) := unsigned(std_logic_vector(CIR_ADDR_OPERAND));
  constant CIR_RESPONSE     : unsigned(4 downto 0) := to_unsigned(13, 5);
  constant CIR_SAVE_ADDR    : unsigned(4 downto 0) := to_unsigned(12, 5);
  constant CIR_RESTORE_ADDR : unsigned(4 downto 0) := to_unsigned(28, 5);
  constant CIR_CONTROL_ADDR : unsigned(4 downto 0) := CIR_ADDR_CONTROL;

  -- OpWord constants.
  constant CPGEN_OPWORD    : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPGEN & "000000";
  constant CPSAVE_OPWORD   : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPSAVE & "000000";
  constant CPRESTORE_OPWORD : std_logic_vector(31 downto 0) :=
    x"0000" & "0000000" & CIR_TYPE_CPRESTORE & "000000";

  -- Opcode constants (core_v1 encoding bits[6:0]).
  constant OPCODE_FADD : std_logic_vector(6 downto 0) := "0100010";  -- 0x22 MC68881 FADD
  constant OPCODE_FMUL : std_logic_vector(6 downto 0) := "0100011";  -- 0x23 MC68881 FMUL
  constant OPCODE_FDIV : std_logic_vector(6 downto 0) := "0100000";  -- 0x20 MC68881 FDIV
  constant OPCODE_FSIN : std_logic_vector(6 downto 0) := "0001110";  -- 0x0E MC68881 FSIN

  -- FP80 test constants.
  constant FP80_ONE_VAL   : fp80_t := x"3FFF8000000000000000";
  constant FP80_TWO_VAL   : fp80_t := x"40008000000000000000";
  constant FP80_THREE_VAL : fp80_t := x"4000C000000000000000";
  constant FP80_SIX_VAL   : fp80_t := x"4001C000000000000000";

  -- Legacy opcode IDs.
  constant OP_FMOVE : std_logic_vector(31 downto 0) := x"00000005";

  -- Variables for bus reads.
  signal test_count : natural := 0;

  -- ----- Bus access procedures -----

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

  -- ----- Legacy FP register load -----
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
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPA_L, value(31 downto 0));
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPA_H, value(63 downto 32));
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPA_E, x"0000" & value(79 downto 64));
    cfg_word := make_move_cfg("01", 0, fp_idx, "00", '0', "00", (others => '0'), '0');
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_MOVE_CFG, cfg_word);
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                   dsack0_n_s, dsack1_n_s, d_out_s, status_word);
    -- Restore CIR mode.
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
  end procedure;

  -- ----- cpGEN register-to-register via CIR -----
  function make_cpgen_reg_cmd(
    src_reg : natural range 0 to 7;
    dst_reg : natural range 0 to 7;
    opcode  : std_logic_vector(6 downto 0)
  ) return std_logic_vector is
    variable cmd : std_logic_vector(15 downto 0) := (others => '0');
  begin
    cmd(14) := '0';  -- R/M = 0 = register source (Motorola convention)
    cmd(12 downto 10) := std_logic_vector(to_unsigned(src_reg, 3));
    cmd(9 downto 7) := std_logic_vector(to_unsigned(dst_reg, 3));
    cmd(6 downto 0) := opcode;
    return x"0000" & cmd;
  end function;

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
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_OPWORD, CPGEN_OPWORD);
    cmd_word := make_cpgen_reg_cmd(src_reg, dst_reg, opcode);
    bus_write(a_in_s, d_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
              CIR_COMMAND, cmd_word);
    wait_for_valid(a_in_s, rw_s, cs_n_s, as_n_s, ds_n_s,
                   dsack0_n_s, dsack1_n_s, d_out_s, status_word);
  end procedure;

begin
  clk <= not clk after CLK_PERIOD/2;

  dut : entity work.mc68881_top
    generic map (
      fpu_version_g => FPU_68882
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

  P1 : process
    variable rd_val : std_logic_vector(31 downto 0) := (others => '0');
    variable frame_data : std_logic_vector(31 downto 0) := (others => '0');
    variable saved_frame : std_logic_vector(31 downto 0) := (others => '0');
    type frame_buf_t is array (0 to 52) of std_logic_vector(31 downto 0);
    variable frame_buf : frame_buf_t := (others => (others => '0'));
  begin
    -- Reset.
    reset_n <= '0';
    wait for CLK_PERIOD * 3;
    reset_n <= '1';
    wait for CLK_PERIOD * 2;

    -- ================================================================
    -- TEST 1: FSAVE after reset → Null frame ($0000)
    -- ================================================================
    report "TEST 1: 68882 FSAVE after reset (Null frame)" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"00000000");
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;

    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, CIR_SAVE_ADDR);
    assert rd_val(15 downto 0) = CIR_FRAME_NULL_FW
      report "FAIL TEST 1: Expected Null FW $0000, got $" & to_hstring(rd_val(15 downto 0))
      severity failure;
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;
    report "TEST 1 PASSED" severity note;

    -- ================================================================
    -- TEST 2: FSAVE Idle → 68882 format word $0038, 14 data words
    -- ================================================================
    report "TEST 2: 68882 FSAVE Idle ($0038, 14 words)" severity note;

    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);
    cpgen_reg_to_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                     dsack0_n, dsack1_n, d_out,
                     OPCODE_FADD, 1, 0);

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;

    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, CIR_SAVE_ADDR);
    assert rd_val(15 downto 0) = CIR_FRAME_IDLE_FW_82
      report "FAIL TEST 2: Expected 68882 Idle FW $0038, got $" & to_hstring(rd_val(15 downto 0))
      severity failure;

    -- Read 14 idle frame data words.
    for i in 0 to CIR_FRAME_IDLE_WORDS_82 - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, frame_data, ADDR_RES_H);
      frame_buf(i) := frame_data;
      report "TEST 2 idle_word(" & integer'image(i) & ")=" & to_hstring(frame_data) severity note;
    end loop;

    for i in 0 to 3 loop wait until rising_edge(clk); end loop;
    report "TEST 2 PASSED" severity note;

    -- ================================================================
    -- TEST 3: FRESTORE Idle round-trip (save → restore → save, verify match)
    -- ================================================================
    report "TEST 3: 68882 FRESTORE Idle round-trip" severity note;

    -- Restore the idle frame we just saved.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & CIR_FRAME_IDLE_FW_82);
    -- Write 14 idle frame data words.
    for i in 0 to CIR_FRAME_IDLE_WORDS_82 - 1 loop
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                CIR_OPERAND, frame_buf(i));
    end loop;
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;

    -- Save again and verify format word matches.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;

    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, CIR_SAVE_ADDR);
    assert rd_val(15 downto 0) = CIR_FRAME_IDLE_FW_82
      report "FAIL TEST 3: Expected Idle FW $0038 after round-trip, got $" & to_hstring(rd_val(15 downto 0))
      severity failure;

    for i in 0 to 3 loop wait until rising_edge(clk); end loop;
    report "TEST 3 PASSED" severity note;

    -- ================================================================
    -- TEST 4: FRESTORE with 68881 idle format ($0018) to 68882 instance
    -- ================================================================
    report "TEST 4: Cross-compat FRESTORE 68881 Idle to 68882" severity note;

    -- Reset first.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"00000000");
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;

    -- Restore a 68881-format idle frame (6 words).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000" & CIR_FRAME_IDLE_FW);
    for i in 0 to CIR_FRAME_IDLE_WORDS - 1 loop
      bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
                CIR_OPERAND, x"00000000");
    end loop;
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;

    -- Verify FPU is initialized: cpSAVE should return 68882 Idle format.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPSAVE_OPWORD);
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;

    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, CIR_SAVE_ADDR);
    assert rd_val(15 downto 0) = CIR_FRAME_IDLE_FW_82
      report "FAIL TEST 4: After 68881 FRESTORE, expected 68882 Idle FW $0038, got $" &
             to_hstring(rd_val(15 downto 0))
      severity failure;

    -- Read all idle words to complete the save.
    for i in 0 to CIR_FRAME_IDLE_WORDS_82 - 1 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, frame_data, ADDR_RES_H);
    end loop;
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;
    report "TEST 4 PASSED" severity note;

    -- ================================================================
    -- TEST 5: FRESTORE invalid format → exception
    -- ================================================================
    report "TEST 5: FRESTORE invalid format $DEAD" severity note;

    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPRESTORE_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESTORE_ADDR, x"0000DEAD");
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;

    -- Read response — should be Pre-Instruction Exception with Format vector.
    -- Poll until non-BUSY response appears.
    for poll_idx in 0 to 31 loop
      bus_read(a_in, rw, cs_n, as_n, ds_n,
               dsack0_n, dsack1_n, d_out, rd_val, CIR_RESPONSE);
      exit when rd_val(15 downto 0) /= CIR_PRIM_BUSY;
    end loop;
    report "TEST 5 response=" & to_hstring(rd_val(15 downto 0)) severity note;
    -- Format error: [15:13]=101 (pre), [9:0]=0x0E (14)
    assert rd_val(15 downto 13) = "101" and rd_val(9 downto 0) = "00" & x"0E"
      report "FAIL TEST 5: Expected Pre-Exception with Format vector, got $" &
             to_hstring(rd_val(15 downto 0))
      severity failure;

    -- Acknowledge exception.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_CONTROL_ADDR, x"00000001");
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;
    report "TEST 5 PASSED" severity note;

    -- ================================================================
    -- PENDING INSTRUCTION PIPELINE TESTS
    -- ================================================================

    -- ================================================================
    -- TEST 6: Response CIR returns NULL (not BUSY) during CIR_EXECUTE
    --         when pending slot is empty (68882 behavior).
    -- ================================================================
    report "TEST 6: Response=NULL during CIR_EXECUTE (pending slot empty)" severity note;

    -- Initialize FP0=1.0 for FSIN (long-running op).
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);

    -- Start FSIN FP0,FP0 via CIR but do NOT wait for completion.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(0, 0, OPCODE_FSIN));
    -- Wait for ALU to start (CIR_IDLE -> DECODE -> EXECUTE ~3 cycles).
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;

    -- Read Response CIR: 68882 should return NULL (not BUSY) when pending slot empty.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, CIR_RESPONSE);
    report "TEST 6 response during EXECUTE=" & to_hstring(rd_val(15 downto 0)) severity note;
    assert rd_val(15 downto 0) = CIR_PRIM_NULL
      report "FAIL TEST 6: Expected NULL ($0900) during CIR_EXECUTE with empty pending, got $" &
             to_hstring(rd_val(15 downto 0))
      severity failure;

    -- Wait for FSIN to complete so FPU returns to idle.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, rd_val);
    report "TEST 6 PASSED" severity note;

    -- ================================================================
    -- TEST 7: Back-to-back FADD: send 2nd instruction during 1st EXECUTE.
    --         Verify both complete with correct results.
    -- ================================================================
    report "TEST 7: Pipeline back-to-back FADD" severity note;

    -- Setup: FP0=1.0, FP1=2.0, FP2=10.0
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 1, FP80_TWO_VAL);
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 2,
                       x"4002A000000000000000");  -- 10.0

    -- Start FSIN FP0,FP3 (long-running: ~34 cycles).
    -- This puts sin(1.0) into FP3.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(0, 3, OPCODE_FSIN));
    -- Wait for ALU to enter EXECUTE state.
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;

    -- Now send 2nd instruction: FADD FP1,FP2 (FP2 = FP2 + FP1 = 10 + 2 = 12).
    -- This should be accepted into the pending slot.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 2, OPCODE_FADD));

    -- Wait for FSIN to complete.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, rd_val);
    report "TEST 7: FSIN complete, waiting for pending FADD auto-launch" severity note;
    -- Allow pending auto-launch to fire and clear STATUS.valid.
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;
    -- Wait for FADD completion.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, rd_val);
    report "TEST 7: FADD complete" severity note;

    -- Verify FP2 = 12.0 (0x4002C000000000000000).
    -- Read FP2 by doing FSAVE and checking, or use a CIR FMOVE to read it out.
    -- Simplest: do another operation that reads FP2 and check via FSAVE idle frame.
    -- Actually: use legacy read. Switch to peripheral mode.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000000");  -- peripheral mode
    -- Issue FMOVE FP2 → result regs via legacy OPSEL.
    -- Use move_cfg: mode=REG_TO_REG, src=2, dst=0 (just to put FP2 into result regs).
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_MOVE_CFG, make_move_cfg("00", 2, 0, "00", '0', "00", (others => '0'), '0'));
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              ADDR_OPSEL, OP_FMOVE);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, rd_val);
    -- Read result.
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, ADDR_RES_L);
    saved_frame := rd_val;  -- low 32
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, ADDR_RES_H);
    frame_data := rd_val;   -- mid 32
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, ADDR_RES_E);
    -- Restore CIR mode.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");

    report "TEST 7 FP2=" & to_hstring(rd_val(15 downto 0)) &
           to_hstring(frame_data) & to_hstring(saved_frame) severity note;
    -- FP2 should be 12.0 = 0x4002C000000000000000
    assert rd_val(15 downto 0) & frame_data & saved_frame = x"4002C000000000000000"
      report "FAIL TEST 7: Expected FP2=12.0 ($4002C000...), got $" &
             to_hstring(rd_val(15 downto 0)) & to_hstring(frame_data) & to_hstring(saved_frame)
      severity failure;
    report "TEST 7 PASSED" severity note;

    -- ================================================================
    -- TEST 8: Pipeline full — 3rd instruction during EXECUTE with
    --         pending slot occupied should get BUSY response.
    -- ================================================================
    report "TEST 8: Pipeline full (3rd instr gets BUSY)" severity note;

    -- Start FSIN FP0,FP0 (long op).
    legacy_load_fp_reg(a_in, d_in, rw, cs_n, as_n, ds_n,
                       dsack0_n, dsack1_n, d_out, 0, FP80_ONE_VAL);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_RESPONSE, x"00000001");
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(0, 0, OPCODE_FSIN));
    for i in 0 to 3 loop wait until rising_edge(clk); end loop;

    -- Send 2nd instruction (fills pending slot): FADD FP1,FP1.
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_OPWORD, CPGEN_OPWORD);
    bus_write(a_in, d_in, rw, cs_n, as_n, ds_n,
              CIR_COMMAND, make_cpgen_reg_cmd(1, 1, OPCODE_FADD));
    -- Wait a few cycles for pending to be accepted.
    for i in 0 to 5 loop wait until rising_edge(clk); end loop;

    -- Read Response: should be BUSY now (pending slot occupied).
    bus_read(a_in, rw, cs_n, as_n, ds_n,
             dsack0_n, dsack1_n, d_out, rd_val, CIR_RESPONSE);
    report "TEST 8 response (pending full)=" & to_hstring(rd_val(15 downto 0)) severity note;
    assert rd_val(15 downto 0) = CIR_PRIM_BUSY
      report "FAIL TEST 8: Expected BUSY ($8900) when pending slot full, got $" &
             to_hstring(rd_val(15 downto 0))
      severity failure;

    -- Wait for both ops to complete.
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, rd_val);
    wait_for_valid(a_in, rw, cs_n, as_n, ds_n,
                   dsack0_n, dsack1_n, d_out, rd_val);
    report "TEST 8 PASSED" severity note;

    -- ================================================================
    report "All MC68882 tests PASSED (8/8)" severity note;
    finish;
  end process;

end architecture sim;
