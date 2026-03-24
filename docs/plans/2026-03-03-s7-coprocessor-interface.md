# Section 7 Coprocessor Interface Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the custom register-mapped host interface with the standard MC68020 CIR dialog protocol, enabling true coprocessor operation on M68020/M68030 and AN-947 peripheral operation on M68000.

**Architecture:** CIR address decoder overlay on the existing internal engine. A dialog FSM in `mc68881_top.vhd` drives the Response CIR based on instruction phase. Sub-units gain save/restore ports for FSAVE Busy frame serialization. The ALU, trig, divrem, and other computation units are internally unchanged.

**Tech Stack:** VHDL-2008, GHDL for simulation (`C:\code\ghdl-mcode-5.1.1-mingw64\bin\ghdl.exe`), Vivado for synthesis (`C:\amddesigntools\2025.2\Vivado\bin\vivado.bat`), test suite via `scripts/run_tests.ps1`.

**Design doc:** `docs/plans/2026-03-03-s7-coprocessor-interface-design.md`

---

## Phase 1: CIR Types + Dialog FSM Skeleton

### Task 1: Add CIR types and constants to package

**Files:**
- Modify: `src/mc68881_pkg.vhd` (add after line ~313, after `op_descriptor_table_t`)

**Step 1: Add CIR type definitions**

Add the following types and constants after the existing `op_descriptor_table_t` definition (line 313):

```vhdl
  -- ===== Section 7 Coprocessor Interface Types =====

  -- CIR register addresses (5-bit, maps to A[4:1] of CPU-space address).
  -- MC68020 CIR offset $XX maps to addr = $XX / 2.
  constant CIR_ADDR_RESPONSE     : unsigned(4 downto 0) := "00000";  -- $00
  constant CIR_ADDR_CONTROL      : unsigned(4 downto 0) := "00001";  -- $02
  constant CIR_ADDR_SAVE         : unsigned(4 downto 0) := "00010";  -- $04
  constant CIR_ADDR_RESTORE      : unsigned(4 downto 0) := "00011";  -- $06
  constant CIR_ADDR_OPWORD       : unsigned(4 downto 0) := "00100";  -- $08
  constant CIR_ADDR_COMMAND      : unsigned(4 downto 0) := "00101";  -- $0A
  constant CIR_ADDR_CONDITION    : unsigned(4 downto 0) := "00111";  -- $0E
  constant CIR_ADDR_OPERAND      : unsigned(4 downto 0) := "01000";  -- $10
  constant CIR_ADDR_REGSELECT    : unsigned(4 downto 0) := "01010";  -- $14
  constant CIR_ADDR_INSTADDR     : unsigned(4 downto 0) := "01100";  -- $18
  constant CIR_ADDR_OPADDR       : unsigned(4 downto 0) := "01110";  -- $1C

  -- Dialog FSM states.
  type cir_dialog_state_t is (
    CIR_IDLE,
    CIR_DECODE,
    CIR_XFER_SRC,
    CIR_XFER_SRC_WAIT,
    CIR_EXECUTE,
    CIR_XFER_DST,
    CIR_XFER_DST_WAIT,
    CIR_COND_EVAL,
    CIR_EXCEPT_PRE,
    CIR_EXCEPT_MID,
    CIR_EXCEPT_POST,
    CIR_SAVE_FORMAT,
    CIR_SAVE_FRAME,
    CIR_RESTORE_FORMAT,
    CIR_RESTORE_FRAME
  );

  -- Response primitive categories (bits 15:13 of Response CIR).
  constant CIR_RESP_BUSY         : std_logic_vector(2 downto 0) := "000";
  constant CIR_RESP_NULL         : std_logic_vector(2 downto 0) := "001";
  constant CIR_RESP_SUPERVISOR   : std_logic_vector(2 downto 0) := "010";
  constant CIR_RESP_TRANSFER     : std_logic_vector(2 downto 0) := "011";
  constant CIR_RESP_WRITEBACK    : std_logic_vector(2 downto 0) := "100";
  constant CIR_RESP_EXCEPT_PRE   : std_logic_vector(2 downto 0) := "101";
  constant CIR_RESP_EXCEPT_MID   : std_logic_vector(2 downto 0) := "110";
  constant CIR_RESP_EXCEPT_POST  : std_logic_vector(2 downto 0) := "111";

  -- Common response primitive words.
  constant CIR_PRIM_BUSY         : std_logic_vector(15 downto 0) := x"0000";
  constant CIR_PRIM_NULL         : std_logic_vector(15 downto 0) := x"2001";

  -- Operation Word type field [8:6] — instruction family.
  constant CIR_TYPE_CPGEN        : std_logic_vector(2 downto 0) := "000";
  constant CIR_TYPE_CPCOND       : std_logic_vector(2 downto 0) := "001";
  constant CIR_TYPE_CPBCC_W      : std_logic_vector(2 downto 0) := "010";
  constant CIR_TYPE_CPBCC_L      : std_logic_vector(2 downto 0) := "011";
  constant CIR_TYPE_CPSAVE       : std_logic_vector(2 downto 0) := "100";
  constant CIR_TYPE_CPRESTORE    : std_logic_vector(2 downto 0) := "101";

  -- Source format field [12:10] of cpGEN command word.
  constant CIR_SRC_LONG          : std_logic_vector(2 downto 0) := "000";
  constant CIR_SRC_SINGLE        : std_logic_vector(2 downto 0) := "001";
  constant CIR_SRC_EXTENDED      : std_logic_vector(2 downto 0) := "010";
  constant CIR_SRC_PACKED        : std_logic_vector(2 downto 0) := "011";
  constant CIR_SRC_WORD          : std_logic_vector(2 downto 0) := "100";
  constant CIR_SRC_DOUBLE        : std_logic_vector(2 downto 0) := "101";
  constant CIR_SRC_BYTE          : std_logic_vector(2 downto 0) := "110";
  constant CIR_SRC_FPN           : std_logic_vector(2 downto 0) := "111";

  -- FSAVE frame format words.
  constant CIR_FRAME_NULL_FW     : std_logic_vector(15 downto 0) := x"0000";
  constant CIR_FRAME_IDLE_FW     : std_logic_vector(15 downto 0) := x"0018";
  constant CIR_FRAME_BUSY_FW     : std_logic_vector(15 downto 0) := x"00B4";
  constant CIR_FRAME_IDLE_WORDS  : natural := 6;   -- 24 bytes / 4
  constant CIR_FRAME_BUSY_WORDS  : natural := 45;  -- 180 bytes / 4

  -- Helper: number of 32-bit operand words for a given source format.
  function cir_src_word_count(src_fmt : std_logic_vector(2 downto 0)) return natural;

  -- Helper: decode command word bits [6:0] to fpu_op_t.
  function cir_decode_cpgen_opcode(cmd_word : std_logic_vector(15 downto 0)) return fpu_op_t;
```

**Step 2: Add helper function bodies**

In the package body (after line ~1133, after `decode_op_sel_word` body), add:

```vhdl
  function cir_src_word_count(src_fmt : std_logic_vector(2 downto 0)) return natural is
  begin
    case src_fmt is
      when CIR_SRC_LONG | CIR_SRC_SINGLE | CIR_SRC_WORD | CIR_SRC_BYTE =>
        return 1;
      when CIR_SRC_DOUBLE =>
        return 2;
      when CIR_SRC_EXTENDED | CIR_SRC_PACKED =>
        return 3;
      when CIR_SRC_FPN =>
        return 0;
      when others =>
        return 0;
    end case;
  end function;

  function cir_decode_cpgen_opcode(cmd_word : std_logic_vector(15 downto 0)) return fpu_op_t is
    variable opcode_bits : std_logic_vector(6 downto 0);
    variable key : op_key_t;
  begin
    opcode_bits := cmd_word(6 downto 0);
    -- Look up MC68881 native opcode in OP_DESCRIPTORS.
    -- The decode IDs now match MC68881 encoding directly
    -- (e.g. $00=FMOVE, $22=FADD, $28=FSUB, $23=FMUL, $20=FDIV, etc.).
    key.namespace := OP_NS_CORE_V1;
    key.opcode_id := '0' & opcode_bits;
    for op in fpu_op_t loop
      if OP_DESCRIPTORS(op).core_v1_decode_id_valid and
         OP_DESCRIPTORS(op).core_v1_decode_id = key.opcode_id then
        return op;
      end if;
    end loop;
    return FPU_OP_NOP;
  end function;
```

**Step 3: Verify GHDL analysis passes**

Run: `cd /c/code/68881-fpga && C:/code/ghdl-mcode-5.1.1-mingw64/bin/ghdl.exe -a --std=08 src/mc68881_pkg.vhd`
Expected: Clean compile, no errors.

**Step 4: Commit**

```
git add src/mc68881_pkg.vhd
git commit -m "Add CIR types, constants, and helper functions to package (S7 Phase 1)"
```

---

### Task 2: Replace address decode and add CIR registers in top-level

**Files:**
- Modify: `src/mc68881_top.vhd`

This task replaces the register-mapped address constants and access_class decode with the CIR register map, and adds the new CIR dialog signals. The internal engine (ALU dispatch, exception classification, microsequencer) is NOT changed yet — this task just lays the addressing foundation.

**Step 1: Replace address constants (lines 84-111)**

Remove the old `ADDR_OPSEL` through `ADDR_AUX_RES_E` constants. Replace with CIR addresses imported from the package (the constants added in Task 1 are in `mc68881_pkg`). Add local aliases if needed for readability.

Add new CIR dialog signals in the signal declaration area (after line ~169):

```vhdl
  -- CIR dialog state machine signals.
  signal cir_state_reg         : cir_dialog_state_t := CIR_IDLE;
  signal cir_opword_reg        : std_logic_vector(15 downto 0) := (others => '0');
  signal cir_command_reg       : std_logic_vector(15 downto 0) := (others => '0');
  signal cir_condition_reg     : std_logic_vector(5 downto 0) := (others => '0');
  signal cir_instr_type        : std_logic_vector(2 downto 0) := (others => '0');
  signal cir_src_fmt           : std_logic_vector(2 downto 0) := (others => '0');
  signal cir_dst_reg_idx       : natural range 0 to 7 := 0;
  signal cir_src_reg_idx       : natural range 0 to 7 := 0;
  signal cir_reg_to_reg        : std_logic := '0';
  signal cir_xfer_word_idx     : natural range 0 to 44 := 0;
  signal cir_xfer_word_count   : natural range 0 to 45 := 0;
  signal cir_response_word     : std_logic_vector(15 downto 0) := CIR_PRIM_NULL;
  signal cir_opword_written    : std_logic := '0';
  signal cir_command_written   : std_logic := '0';
  signal cir_exc_vector        : std_logic_vector(9 downto 0) := (others => '0');
  signal cir_control_ack       : std_logic := '0';
```

**Step 2: Replace address decode process (lines 1599-1626)**

Replace the `access_class` case statement to decode CIR addresses:

```vhdl
  process(addr)
  begin
    access_class <= ACCESS_NONE;
    case addr is
      when CIR_ADDR_RESPONSE =>
        access_class <= ACCESS_CIR;
      when CIR_ADDR_CONTROL =>
        access_class <= ACCESS_CIR;
      when CIR_ADDR_SAVE =>
        access_class <= ACCESS_FRAME;
      when CIR_ADDR_RESTORE =>
        access_class <= ACCESS_FRAME;
      when CIR_ADDR_OPWORD | CIR_ADDR_COMMAND =>
        access_class <= ACCESS_OPERAND;
      when CIR_ADDR_CONDITION =>
        access_class <= ACCESS_CIR;
      when CIR_ADDR_OPERAND =>
        access_class <= ACCESS_OPERAND;
      when CIR_ADDR_REGSELECT =>
        access_class <= ACCESS_CIR;
      when CIR_ADDR_INSTADDR =>
        access_class <= ACCESS_FPIAR;
      when CIR_ADDR_OPADDR =>
        access_class <= ACCESS_CIR;
      when others =>
        access_class <= ACCESS_NONE;
    end case;
  end process;
```

**Step 3: Replace bus read mux (lines 2731-2831)**

Replace the `d_out_comb` process to return CIR register values:

```vhdl
  process(addr, cir_response_word, cir_state_reg, ...)
  begin
    d_out_comb <= (others => '0');
    case addr is
      when CIR_ADDR_RESPONSE =>
        d_out_comb(15 downto 0) <= cir_response_word;
      when CIR_ADDR_SAVE =>
        -- Format word (set by FSAVE dialog)
        d_out_comb(15 downto 0) <= frame_format_word_reg;
      when CIR_ADDR_OPERAND =>
        -- Operand data (transfer direction depends on dialog state)
        d_out_comb <= cir_operand_read_data;
      when CIR_ADDR_REGSELECT =>
        d_out_comb(15 downto 0) <= cir_regselect_word;
      when CIR_ADDR_OPADDR =>
        d_out_comb <= cir_operand_addr_reg;
      when others =>
        d_out_comb <= (others => '0');
    end case;
  end process;
```

**Step 4: Verify GHDL analysis passes**

Run: `cd /c/code/68881-fpga && C:/code/ghdl-mcode-5.1.1-mingw64/bin/ghdl.exe -a --std=08 src/mc68881_pkg.vhd src/mc68881_top.vhd`
Expected: Clean compile (testbenches will NOT compile yet — they still reference old addresses).

**Step 5: Commit**

```
git add src/mc68881_top.vhd
git commit -m "Replace register-mapped address decode with CIR register map (S7 Phase 1)"
```

---

### Task 3: Implement dialog FSM skeleton

**Files:**
- Modify: `src/mc68881_top.vhd`

This task adds the core dialog state machine process that drives `cir_response_word` based on `cir_state_reg`. Initially it handles only the CIR_IDLE → CIR_DECODE → CIR_EXECUTE → CIR_IDLE flow for register-to-register cpGEN ops. Other paths are stubbed.

**Step 1: Add CIR register write handling**

In the synchronous bus write process, add handlers for OpWord, Command, and Condition CIR writes:

```vhdl
  -- OpWord CIR write: latch F-line operation word, extract type field.
  when CIR_ADDR_OPWORD =>
    cir_opword_reg <= d_in(15 downto 0);
    cir_instr_type <= d_in(8 downto 6);
    cir_opword_written <= '1';

  -- Command CIR write: latch command word, extract fields.
  when CIR_ADDR_COMMAND =>
    cir_command_reg <= d_in(15 downto 0);
    cir_src_fmt <= d_in(12 downto 10);
    cir_dst_reg_idx <= to_integer(unsigned(d_in(9 downto 7)));
    cir_reg_to_reg <= d_in(14);
    cir_command_written <= '1';

  -- Condition CIR write: latch condition selector, trigger eval.
  when CIR_ADDR_CONDITION =>
    cir_condition_reg <= d_in(5 downto 0);

  -- Instruction Address CIR write: capture FPIAR.
  when CIR_ADDR_INSTADDR =>
    fpiar_reg <= d_in;

  -- Control CIR write: exception acknowledge.
  when CIR_ADDR_CONTROL =>
    cir_control_ack <= d_in(0);
```

**Step 2: Add dialog FSM process**

New synchronous process `cir_dialog_proc` that manages state transitions:

```vhdl
  cir_dialog_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      cir_state_reg <= CIR_IDLE;
      cir_opword_written <= '0';
      cir_command_written <= '0';
      cir_xfer_word_idx <= 0;
      cir_xfer_word_count <= 0;
    elsif rising_edge(clk) then
      case cir_state_reg is

        when CIR_IDLE =>
          -- Wait for OpWord + Command (cpGEN) or OpWord + Condition (cpBcc/cpScc).
          if cir_opword_written = '1' and cir_command_written = '1' then
            cir_state_reg <= CIR_DECODE;
            cir_opword_written <= '0';
            cir_command_written <= '0';
          end if;

        when CIR_DECODE =>
          case cir_instr_type is
            when CIR_TYPE_CPGEN =>
              if cir_src_fmt = CIR_SRC_FPN then
                -- Register-to-register: launch ALU directly.
                -- (op_issue wiring goes here — Task 4)
                cir_state_reg <= CIR_EXECUTE;
              else
                -- Memory source: request operand transfer.
                cir_xfer_word_count <= cir_src_word_count(cir_src_fmt);
                cir_xfer_word_idx <= 0;
                cir_state_reg <= CIR_XFER_SRC;
              end if;
            when CIR_TYPE_CPCOND | CIR_TYPE_CPBCC_W | CIR_TYPE_CPBCC_L =>
              cir_state_reg <= CIR_COND_EVAL;
            when CIR_TYPE_CPSAVE =>
              cir_state_reg <= CIR_SAVE_FORMAT;
            when CIR_TYPE_CPRESTORE =>
              cir_state_reg <= CIR_RESTORE_FORMAT;
            when others =>
              cir_state_reg <= CIR_EXCEPT_PRE;  -- Unknown type
          end case;

        when CIR_EXECUTE =>
          -- Wait for ALU completion.
          if valid = '1' then
            cir_state_reg <= CIR_IDLE;
          end if;

        when CIR_XFER_SRC =>
          -- Present transfer-operand response. Wait for host writes.
          null;  -- Operand CIR write handler increments xfer_word_idx.

        when CIR_XFER_SRC_WAIT =>
          if cir_xfer_word_idx >= cir_xfer_word_count then
            cir_state_reg <= CIR_EXECUTE;
          end if;

        -- Stub remaining states for later phases:
        when CIR_XFER_DST | CIR_XFER_DST_WAIT =>
          null;
        when CIR_COND_EVAL =>
          cir_state_reg <= CIR_IDLE;  -- Phase 2 fills this in
        when CIR_EXCEPT_PRE | CIR_EXCEPT_MID | CIR_EXCEPT_POST =>
          if cir_control_ack = '1' then
            cir_state_reg <= CIR_IDLE;
            cir_control_ack <= '0';
          end if;
        when CIR_SAVE_FORMAT | CIR_SAVE_FRAME =>
          null;  -- Phase 3
        when CIR_RESTORE_FORMAT | CIR_RESTORE_FRAME =>
          null;  -- Phase 3
      end case;
    end if;
  end process;
```

**Step 3: Add combinational response word generation**

```vhdl
  process(cir_state_reg, cir_xfer_word_count)
  begin
    case cir_state_reg is
      when CIR_IDLE =>
        cir_response_word <= CIR_PRIM_NULL;
      when CIR_EXECUTE =>
        cir_response_word <= CIR_PRIM_BUSY;
      when CIR_XFER_SRC =>
        -- Transfer Operand to-CP: bits [15:13]=011, [12]=1, [7:0]=byte count
        cir_response_word <= "011" & '1' & "0000" &
          std_logic_vector(to_unsigned(cir_xfer_word_count * 4, 8));
      when CIR_EXCEPT_PRE =>
        cir_response_word <= CIR_RESP_EXCEPT_PRE & "0" & "000000000000";
      when CIR_EXCEPT_MID =>
        cir_response_word <= CIR_RESP_EXCEPT_MID & "0" & "000000000000";
      when CIR_EXCEPT_POST =>
        cir_response_word <= CIR_RESP_EXCEPT_POST & "0" & "000000000000";
      when others =>
        cir_response_word <= CIR_PRIM_NULL;
    end case;
  end process;
```

**Step 4: Verify GHDL analysis passes**

Run: `cd /c/code/68881-fpga && C:/code/ghdl-mcode-5.1.1-mingw64/bin/ghdl.exe -a --std=08 src/mc68881_pkg.vhd src/mc68881_top.vhd`
Expected: Clean compile.

**Step 5: Commit**

```
git add src/mc68881_top.vhd
git commit -m "Add CIR dialog FSM skeleton with cpGEN decode path (S7 Phase 1)"
```

---

### Task 4: Wire cpGEN register-to-register through dialog FSM to ALU

**Files:**
- Modify: `src/mc68881_top.vhd`

Connect the dialog FSM's CIR_DECODE → CIR_EXECUTE path to the existing ALU dispatch. When the FSM decodes a register-to-register cpGEN instruction:
1. Decode command word opcode bits [6:0] to `fpu_op_t` via `cir_decode_cpgen_opcode`.
2. Load source operand from `fp_reg_file_reg(cir_src_reg_idx)`.
3. Load destination operand from `fp_reg_file_reg(cir_dst_reg_idx)` (for dyadic ops).
4. Set `op_sel_reg` and pulse `op_start_reg`.
5. On ALU `valid`, write result back to `fp_reg_file_reg(cir_dst_reg_idx)`.

The existing `alu_control_proc` op_issue_pulse logic (line 1638) must be replaced: instead of triggering from an OPSEL address write, it triggers from the dialog FSM entering CIR_EXECUTE.

**Step 1: Modify op_issue_pulse to trigger from FSM**

Replace the combinational `op_issue_pulse` (lines 1638-1647) with a registered pulse driven by the FSM:

```vhdl
  -- op_issue_pulse is now driven by the dialog FSM, not by OPSEL write.
  -- It fires for one cycle when the FSM transitions to CIR_EXECUTE.
```

In `cir_dialog_proc`, at the CIR_DECODE → CIR_EXECUTE transition:
```vhdl
  -- Decode opcode, stage operands, fire ALU.
  op_sel_reg <= cir_decode_cpgen_opcode(cir_command_reg);
  cir_src_reg_idx <= to_integer(unsigned(cir_command_reg(12 downto 10)))
                     when cir_src_fmt = CIR_SRC_FPN else 0;
  operand_reg(0) <= fp_reg_file_reg(cir_dst_reg_idx);  -- Destination = operand A
  operand_reg(1) <= fp_reg_file_reg(cir_src_reg_idx);  -- Source = operand B
  op_start_reg <= '1';
  cir_state_reg <= CIR_EXECUTE;
```

Note: For the MC68881, dyadic ops use `FPn,FPm` where source is the second operand. The operand mapping (which goes to A vs B) must match the existing ALU convention. Check the existing `alu_control_proc` OP_CLASS_ARITH section to verify operand order.

**Step 2: Add result writeback on ALU completion**

In `cir_dialog_proc` CIR_EXECUTE state:
```vhdl
  when CIR_EXECUTE =>
    op_start_reg <= '0';
    if valid = '1' then
      -- Write result to destination FP register.
      fp_reg_file_reg(cir_dst_reg_idx) <= result;
      -- Run exception classification (existing exc_status_proc).
      -- Transition based on exception state.
      cir_state_reg <= CIR_IDLE;
    end if;
```

**Step 3: Verify GHDL analysis passes**

Run: `cd /c/code/68881-fpga && C:/code/ghdl-mcode-5.1.1-mingw64/bin/ghdl.exe -a --std=08 src/mc68881_pkg.vhd src/mc68881_top.vhd`

**Step 4: Commit**

```
git add src/mc68881_top.vhd
git commit -m "Wire cpGEN reg-to-reg path through dialog FSM to ALU (S7 Phase 1)"
```

---

### Task 5: Write CIR dialog testbench with first cpGEN reg-to-reg test

**Files:**
- Create: `tb/tb_mc68881_cir_dialog.vhd`
- Modify: `scripts/run_tests.ps1` (add to compile/run list)

**Step 1: Create CIR dialog testbench**

Create `tb/tb_mc68881_cir_dialog.vhd` with:
- DUT instantiation of `mc68881_top`
- CIR-protocol bus procedures:
  - `cir_write_opword(opword)` — write to CIR_ADDR_OPWORD
  - `cir_write_command(cmd)` — write to CIR_ADDR_COMMAND
  - `cir_write_condition(cond)` — write to CIR_ADDR_CONDITION
  - `cir_write_operand(data)` — write to CIR_ADDR_OPERAND
  - `cir_read_response() → 16-bit` — read CIR_ADDR_RESPONSE
  - `cir_read_operand() → 32-bit` — read CIR_ADDR_OPERAND
  - `cir_write_instaddr(addr)` — write to CIR_ADDR_INSTADDR
  - `cir_poll_until_not_busy() → response` — loop read Response until not Busy
- Higher-level dialog procedures:
  - `cpgen_reg_to_reg(opcode, src_reg, dst_reg)` — full cpGEN dialog for FPn,FPm
  - `cpgen_mem_source(opcode, src_fmt, dst_reg, operand_words)` — full dialog with operand transfer
- First test case: `FADD FP1,FP0`
  1. Pre-load FP0 with 1.0 via cpGEN FMOVE with memory source (or direct register init)
  2. Pre-load FP1 with 2.0
  3. Execute `cpgen_reg_to_reg(FADD, src=1, dst=0)`
  4. Verify FP0 = 3.0 by reading back via FMOVE to memory dialog
  5. Assert response was Busy then Null

**Step 2: Add to compile/run list**

Add `tb/tb_mc68881_cir_dialog.vhd` to the GHDL compile line in `scripts/run_tests.ps1` (line 28), and add elaborate+run lines.

**Step 3: Run test**

Run: `cd /c/code/68881-fpga && powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: New CIR dialog test passes (other tests may need adjustment).

**Step 4: Commit**

```
git add tb/tb_mc68881_cir_dialog.vhd scripts/run_tests.ps1
git commit -m "Add CIR dialog testbench with cpGEN reg-to-reg FADD test (S7 Phase 1)"
```

---

### Task 6: Implement cpGEN memory-source operand transfer

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Add Operand CIR write handler for source transfer**

When `cir_state_reg = CIR_XFER_SRC` and host writes to CIR_ADDR_OPERAND:
- Store the word into the appropriate slice of the operand staging register based on `cir_xfer_word_idx` and `cir_src_fmt`.
- Increment `cir_xfer_word_idx`.
- When `cir_xfer_word_idx = cir_xfer_word_count`, convert from source format to FP80 (using existing `fp80_from_single`, `fp80_from_double`, `fp80_from_integer` functions) and transition to CIR_EXECUTE.

Word packing for each format:
- **Long/Word/Byte**: 1 word → `operand_reg(1)(31 downto 0)`
- **Single**: 1 word → pass to `fp80_from_single`
- **Double**: word 0 = upper 32, word 1 = lower 32 → pass to `fp80_from_double`
- **Extended**: word 0[31:16] = sign+exp, word 1 = mant high, word 2 = mant low → direct FP80 pack
- **Packed**: word 0 = SE/YY/exp, word 1 = digits high, word 2 = digits low → packed decode path

**Step 2: Add test for FADD.S with memory source**

In `tb/tb_mc68881_cir_dialog.vhd`, add test:
1. Write OpWord for cpGEN
2. Write Command with src_fmt=Single, opcode=FADD, dst=FP0
3. Read Response → expect Transfer Operand primitive ($6804)
4. Write 1 longword to Operand CIR (single-precision 2.0 = $40000000)
5. Poll Response until not Busy
6. Verify FP0 contains expected result

**Step 3: Run tests**

Run: `cd /c/code/68881-fpga && powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`

**Step 4: Commit**

```
git add src/mc68881_top.vhd tb/tb_mc68881_cir_dialog.vhd
git commit -m "Implement cpGEN memory-source operand transfer via Operand CIR (S7 Phase 1)"
```

---

### Task 7: Implement cpGEN destination transfer (FMOVE reg→mem)

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Add CIR_XFER_DST path**

When the dialog FSM decodes an FMOVE reg→mem (command word bit [13]=1 indicating direction, or however the existing move_cfg decode determines direction):
- Transition to CIR_XFER_DST after ALU/conversion completes.
- Present transfer-from-CP response primitive with byte count.
- On each host read of CIR_ADDR_OPERAND, output the next result word and increment `cir_xfer_word_idx`.
- When all words transferred, transition to CIR_IDLE.

**Step 2: Add test for FMOVE FP0 to memory (single format)**

Test: load FP0 with a known value, then execute FMOVE to memory dialog:
1. Write OpWord for cpGEN
2. Write Command for FMOVE with dst_fmt=Single, src=FP0
3. Read Response → expect transfer-from-CP primitive ($6404)
4. Read 1 longword from Operand CIR → verify single-precision encoding

**Step 3: Run tests and commit**

---

### Task 8: Update existing testbenches for CIR protocol

**Files:**
- Modify: `tb/tb_mc68881_top.vhd`
- Modify: `tb/tb_mc68881_fpcr_fpsr.vhd`
- Modify: `tb/tb_mc68881_fmove_fmovem.vhd`
- Modify: `tb/tb_mc68881_fmovecr.vhd`
- Modify: `tb/tb_mc68881_ea_cycles.vhd`
- Modify: `tb/tb_mc68881_cycle_counts.vhd`
- Modify: `tb/tb_mc68881_cycle_counts_top.vhd`
- Modify: `tb/tb_mc68881_ac_timing.vhd`
- Modify: `tb/tb_mc68881_op_class_dispatch.vhd`
- Modify: `tb/tb_mc68881_known_defects.vhd`

Each testbench that talks to `mc68881_top` must be updated:
1. Replace ADDR_OPSEL/OPA/OPB/RES/STATUS constants with CIR addresses.
2. Replace `bus_write(ADDR_OPSEL, opcode)` pattern with cpGEN dialog sequence (write OpWord, write Command, poll Response).
3. Replace `wait_for_valid` (STATUS polling) with `cir_poll_until_not_busy` (Response polling).
4. Replace `bus_read(ADDR_RES_*)` with Operand CIR read sequence for FMOVE to memory.
5. Replace direct FPCR/FPSR reads with FMOVE control register dialog (or keep direct if FPCR/FPSR remain readable).

Note: FPCR/FPSR/FPIAR are now accessed through the CIR dialog (FMOVEM.CR). Consider whether to keep them as directly addressable registers during Phase 1 for easier migration, or convert them now. Decision: Keep direct FPCR/FPSR/FPIAR access as additional CIR addresses temporarily (addresses not used by the standard CIR map) for testbench convenience, and remove in Phase 5.

**This is the largest task. Break it into sub-commits per testbench file.**

Run full test suite after each file: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`

---

## Phase 2: Conditional Dialog Paths

### Task 9: Implement cpScc dialog (FScc)

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Fill in CIR_COND_EVAL state for cpScc**

When `cir_instr_type = CIR_TYPE_CPCOND` and command word indicates FScc:
1. Extract condition selector from Condition CIR (written via CIR_ADDR_CONDITION).
2. Evaluate condition using existing `eval_fcc_condition(cir_condition_reg, fpsr_cc_bits)`.
3. Check BSUN via `is_signaling_fcc_condition`.
4. Set result byte (0xFF true, 0x00 false) — host reads via Operand CIR.
5. If BSUN and FPCR BSUN enabled: transition to CIR_EXCEPT_POST.
6. Otherwise: transition to CIR_IDLE with Null response.

Reuse the existing conditional evaluation logic from lines 2561-2572 of the current `alu_control_proc`.

**Step 2: Add FScc test cases**

In `tb/tb_mc68881_cir_dialog.vhd`:
- FScc with EQ condition, FPSR Z=1 → result = $FF
- FScc with EQ condition, FPSR Z=0 → result = $00
- FScc with signaling condition + NAN → BSUN exception

**Step 3: Run tests and commit**

---

### Task 10: Implement cpBcc dialog (FBcc)

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

FBcc evaluates condition. If true: response = Take Post-Instruction Exception (the M68020 takes this to mean "branch taken" — the CPU adds the displacement to PC). If false: response = Null (fall through).

If BSUN: Take Post-Instruction Exception with BSUN vector.

**Step 1: Add FBcc handling in CIR_COND_EVAL**

Distinguish cpBcc from cpScc using `cir_instr_type` (CIR_TYPE_CPBCC_W or CIR_TYPE_CPBCC_L vs CIR_TYPE_CPCOND).

**Step 2: Add FBcc test cases**

- FBcc.W with condition true → Post-Instruction Exception (branch taken)
- FBcc.W with condition false → Null
- FBcc.L variant

**Step 3: Run tests and commit**

---

### Task 11: Implement cpDBcc and cpTRAPcc dialogs

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**FDBcc**: Condition true → Null (skip). Condition false → decrement counter (host provides counter via Operand CIR), if counter != -1 → response encodes "branch taken", else → Null (expired).

**FTRAPcc**: Condition true → Take Post-Instruction Exception (trap). Condition false → Null.

These map closely to the existing logic at lines 2587-2629.

**Step 1: Add FDBcc and FTRAPcc handling**

FDBcc needs the host to write the counter value to the Operand CIR before the condition evaluation completes. The dialog flow:
1. Host writes OpWord (type = CIR_TYPE_CPCOND with FDBcc sub-encoding)
2. FPU requests operand transfer (counter word)
3. Host writes counter to Operand CIR
4. FPU evaluates condition, decrements if needed
5. Response carries updated counter and branch decision

FTRAPcc is simpler — just condition eval → trap or null.

**Step 2: Add test cases for FDBcc loop and FTRAPcc**

**Step 3: Run tests and commit**

---

## Phase 3: FSAVE/FRESTORE

### Task 12: Implement Null and Idle FSAVE

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Add frame type determination**

When the dialog FSM enters CIR_SAVE_FORMAT:
- If FPU has never been initialized (no operation executed since reset): frame type = Null ($0000).
- If FPU is idle (no operation in progress): frame type = Idle ($0018).
- If FPU is busy (ALU/trig/div active): frame type = Busy ($00B4).

Store determined format word in `frame_format_word_reg`.

**Step 2: Implement Idle frame serialization**

For Idle frame (6 longwords), the CIR_SAVE_FRAME state reads from:
- Word 0: Frame version tag (constant) + internal flags
- Word 1: `fpu_op_t'pos(last_op_sel_reg)` + op class encoding
- Word 2: Exception event registers packed
- Word 3: Microsequencer state
- Word 4: CIR dialog flags
- Word 5: Reserved (zero)

Each host read of CIR_ADDR_OPERAND returns the next word and increments `cir_xfer_word_idx`. When all words transferred, transition to CIR_IDLE.

**Step 3: Add FSAVE tests**

- FSAVE after reset → Null frame ($0000), 0 data words
- FSAVE after FADD completes → Idle frame ($0018), 6 data words

**Step 4: Run tests and commit**

---

### Task 13: Implement Null and Idle FRESTORE

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Add FRESTORE format word validation**

When host writes format word to CIR_ADDR_RESTORE:
- $0000 (Null): Reset FPU to power-on state. No frame data. Respond Null.
- $0018 (Idle): Expect 6 longwords of frame data via Operand CIR.
- $00B4 (Busy): Expect 45 longwords (Task 15).
- Anything else: Respond Pre-Instruction Exception (invalid format).

**Step 2: Implement Idle frame deserialization**

CIR_RESTORE_FRAME receives 6 longwords via Operand CIR writes, unpacking into the same internal signals that FSAVE serialized. After the last word, commit restored state.

**Step 3: Add FRESTORE tests**

- FRESTORE with Null format → FPU reset
- FRESTORE with Idle frame → internal state restored
- FRESTORE with invalid format word → Pre-Instruction Exception
- Round-trip: FSAVE(idle) → FRESTORE(idle) → verify state matches

**Step 4: Run tests and commit**

---

### Task 14: Add save/restore ports to sub-units

**Files:**
- Modify: `src/mc68881_trig_unit.vhd`
- Modify: `src/mc68881_divrem_unit.vhd`
- Modify: `src/mc68881_modrem_post_unit.vhd`
- Modify: `src/mc68881_packed_decimal_unit.vhd`
- Modify: `src/mc68881_alu.vhd`
- Modify: `src/mc68881_top.vhd` (port map updates)

Add the save/restore port interface to each computation unit:

```vhdl
  -- Save/restore interface for FSAVE/FRESTORE Busy frame.
  save_req     : in  std_logic;
  save_data    : out std_logic_vector(31 downto 0);
  save_addr    : in  natural range 0 to UNIT_SAVE_WORDS-1;
  save_busy    : out std_logic;
  restore_req  : in  std_logic;
  restore_data : in  std_logic_vector(31 downto 0);
  restore_addr : in  natural range 0 to UNIT_SAVE_WORDS-1;
  restore_wr   : in  std_logic;
```

Each unit implements save/restore by:
- **Save**: On `save_req`, copy FSM state + working registers into shadow registers. `save_data` muxes shadow registers by `save_addr`.
- **Restore**: On `restore_wr`, write `restore_data` into shadow register at `restore_addr`. On `restore_req`, commit shadow registers to working state.

Word allocation per unit:
- Trig unit: 9 words (FSM state, tmp_reg, x_reg, a_reg, poly index, iteration, quadrant, sub-unit state x2)
- Divrem unit: 6 words (FSM state, iteration, mantissa x2, partial quotient, exponent)
- Modrem post: 3 words (continuation state, working registers)
- Packed decimal: 3 words (arith state, digit index, accumulator)
- ALU: 5 words (simple_hold, shared FP unit pipeline state x4)

Total sub-unit words: 26. Plus 6 idle frame + 2 ALU control + 4 operands + 7 padding = 45 words = 180 bytes.

**Do each unit as a separate sub-commit. Verify GHDL compile after each.**

---

### Task 15: Implement Busy FSAVE/FRESTORE

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Extend FSAVE serializer for Busy frame**

When frame type = Busy:
- Words 0-5: Same as Idle frame
- Words 6-7: op_sel_reg encoding, operand staging metadata
- Words 8-11: operand_reg(0) and operand_reg(1) packed as 80-bit → 3 words each (but only 2.5 words each, pack into 2 words with upper bits)
- Words 12-20: Trig unit save_data[0..8]
- Words 21-26: Divrem unit save_data[0..5]
- Words 27-29: Modrem post save_data[0..2]
- Words 30-32: Packed decimal save_data[0..2]
- Words 33-37: ALU save_data[0..4]
- Words 38-44: Zero padding

The top-level serializer steps through word addresses, routing to the appropriate sub-unit's `save_data` output based on address range.

**Step 2: Extend FRESTORE deserializer for Busy frame**

Inverse: route incoming words to sub-unit `restore_data`/`restore_wr` based on address, then pulse `restore_req` on all units after the last word.

**Step 3: Add Busy frame test**

- Start a long-running operation (e.g. FSIN)
- While busy: issue FSAVE → get Busy format word ($00B4)
- Read 45 longwords
- Issue FRESTORE with the saved frame
- Poll until operation completes
- Verify result matches expected FSIN output

**Step 4: Run tests and commit**

---

## Phase 4: Exception Paths

### Task 16: Implement pre-instruction exception dialog

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Add pre-instruction exception detection**

In CIR_DECODE: if opcode is unrecognized (cir_decode_cpgen_opcode returns FPU_OP_NOP for non-NOP command), transition to CIR_EXCEPT_PRE with F-line vector (11).

**Step 2: Add Control CIR acknowledge handling**

When host writes to CIR_ADDR_CONTROL with acknowledge bit: clear exception state, return to CIR_IDLE.

**Step 3: Add tests**

- Write invalid command word opcode → Pre-Instruction Exception response
- Write Control CIR ack → returns to Idle

**Step 4: Run tests and commit**

---

### Task 17: Implement mid-instruction exception dialog

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

**Step 1: Check FPCR enables after ALU completion**

In CIR_EXECUTE, when `valid = '1'`: before transitioning to CIR_IDLE, check if any exception bits in FPSR EXC byte have their corresponding FPCR enable bits set. If so, transition to CIR_EXCEPT_MID instead of CIR_IDLE.

The existing `exc_status_proc` already computes exception flags. Add a combinational signal:
```vhdl
cir_mid_exception <= '1' when (fpsr_exc_byte AND fpcr_enable_byte) /= x"00" else '0';
```

**Step 2: Add tests**

- FDIV by zero with FPCR DZ enabled → Mid-Instruction Exception
- FADD overflow with FPCR OVFL enabled → Mid-Instruction Exception
- Same operations with FPCR enables clear → Null (no exception)

**Step 3: Run tests and commit**

---

### Task 18: Implement post-instruction exception dialog

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

Post-instruction exceptions are primarily for conditional operations (BSUN, FTRAPcc). The result is committed but the host should take the exception.

**Step 1: Wire BSUN and trap paths to CIR_EXCEPT_POST**

In the conditional evaluation path (CIR_COND_EVAL), when BSUN is detected and FPCR BSUN enable is set, or when FTRAPcc condition is true: transition to CIR_EXCEPT_POST with appropriate vector.

**Step 2: Add tests**

- FBcc with signaling condition + NAN + BSUN enabled → Post-Instruction Exception
- FTRAPcc with condition true → Post-Instruction Exception

**Step 3: Run tests and commit**

---

## Phase 5: Timing, Integration, and Test Closure

### Task 19: FPCR/FPSR/FPIAR access via FMOVEM dialog

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

Implement FMOVEM for control registers (FPCR/FPSR/FPIAR) through the CIR dialog protocol. The command word register-list field identifies which control registers to transfer. The Register Select CIR ($14) communicates the register list.

**Step 1: Implement FMOVEM.CR to/from memory**

**Step 2: Remove temporary direct FPCR/FPSR/FPIAR access (if added in Task 8)**

**Step 3: Update all testbenches to use FMOVEM.CR dialog for control register access**

**Step 4: Run full test suite and commit**

---

### Task 20: FMOVEM.X register list transfer

**Files:**
- Modify: `src/mc68881_top.vhd`
- Modify: `tb/tb_mc68881_cir_dialog.vhd`

Implement FMOVEM for FP data registers (FP0-FP7). The register list mask determines which registers transfer. Each FP register is 3 longwords (80-bit extended + padding).

**Step 1: Implement FMOVEM.X to/from memory via Operand CIR**

**Step 2: Add test for FMOVEM with multiple registers**

**Step 3: Run tests and commit**

---

### Task 21: Remove legacy testbench compatibility shims

**Files:**
- Modify: All testbench files

Remove any temporary direct-access addresses or legacy compatibility code added in Task 8. All host communication now goes through the CIR dialog protocol exclusively.

Run full test suite: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`

---

### Task 22: Update S7 checklist and run synthesis

**Files:**
- Modify: `docs/fpu-progress-checklist.md`

**Step 1: Mark S7 checklist items as done**

Update all S7-* items that are now implemented to `[x]`.

**Step 2: Run GHDL full regression**

Run: `powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1`
Expected: All tests pass.

**Step 3: Run Vivado synthesis for LUT/timing check**

Run non-incremental synthesis to verify the CIR FSM addition hasn't blown the LUT budget or broken timing.

**Step 4: Commit and update implementation snapshot**

---

## Task Dependency Summary

```
Phase 1: Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 7 → Task 8
Phase 2: Task 9 → Task 10 → Task 11
Phase 3: Task 12 → Task 13 → Task 14 → Task 15
Phase 4: Task 16 → Task 17 → Task 18
Phase 5: Task 19 → Task 20 → Task 21 → Task 22
```

Phases 2, 3, 4 can proceed in any order after Phase 1 completes.
Phase 5 requires all prior phases.
