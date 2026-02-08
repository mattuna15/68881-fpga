library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_top is
  port (
    -- Bus interface
    a_in    : in  std_logic_vector(4 downto 0);
    d_in    : in  std_logic_vector(31 downto 0);
    d_out   : out std_logic_vector(31 downto 0);
    size_n  : in  std_logic_vector(1 downto 0); -- active low
    as_n    : in  std_logic; -- active low
    cs_n    : in  std_logic; -- active low
    rw      : in  std_logic; -- high=read, low=write
    ds_n    : in  std_logic; -- active low
    dsack0_n: out std_logic;
    dsack1_n: out std_logic;
    reset_n : in  std_logic;
    clk     : in  std_logic;
    sense_n : inout std_logic
  );
end entity mc68881_top;

architecture rtl of mc68881_top is
  type reg_array_t is array (0 to 1) of fp80_t;

  signal op_sel_reg    : fpu_op_t := FPU_OP_NOP;
  signal operand_reg   : reg_array_t := (others => (others => '0'));
  signal result    : fp80_t := (others => '0');
  signal result_lo_reg : std_logic_vector(FP80_RESULT_LO_WIDTH-1 downto 0) := (others => '0');
  signal result_hi_reg : std_logic_vector(FP80_RESULT_HI_WIDTH-1 downto 0) := (others => '0');
  signal result_ex_reg : std_logic_vector(FP80_RESULT_EX_WIDTH-1 downto 0) := (others => '0');
  signal valid     : std_logic := '0';
  signal busy      : std_logic := '0';
  signal sense_drive : std_logic := '1';
  signal op_start_reg  : std_logic := '0';
  signal status_valid_reg : std_logic := '0';
  signal status_busy_reg  : std_logic := '0';
  signal status_frame_valid_reg : std_logic := '0';
  signal status_frame_busy_reg  : std_logic := '0';
  signal fpcr_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal fpsr_reg  : std_logic_vector(31 downto 0) := (others => '0');
  signal round_mode : fp_round_mode_t := FP_RND_NEAREST;
  signal round_prec : fp_round_prec_t := FP_PREC_EXTENDED;
  signal src_kind_reg : fpu_src_kind_t := FPU_SRC_FPM;
  signal ea_mode_reg  : ea_mode_t := EA_MODE_DN_AN;
  signal cycle_case_reg : ea_cycle_case_t := EA_CYCLE_BEST;
  signal mc68020_src_reg : std_logic := '0';
  signal mc68020_dst_reg : std_logic := '0';
  signal packed_dynamic_k_reg : std_logic := '0';

  signal dsack0_i  : std_logic := '1';
  signal dsack1_i  : std_logic := '1';

  signal bus_write : std_logic;
  signal bus_read  : std_logic;
  signal start_access : std_logic;
  signal addr      : unsigned(4 downto 0);

  constant ADDR_OPSEL  : unsigned(4 downto 0) := to_unsigned(0, 5);
  constant ADDR_OPA_L  : unsigned(4 downto 0) := to_unsigned(1, 5);
  constant ADDR_OPA_H  : unsigned(4 downto 0) := to_unsigned(2, 5);
  constant ADDR_OPA_E  : unsigned(4 downto 0) := to_unsigned(3, 5);
  constant ADDR_OPB_L  : unsigned(4 downto 0) := to_unsigned(4, 5);
  constant ADDR_OPB_H  : unsigned(4 downto 0) := to_unsigned(5, 5);
  constant ADDR_OPB_E  : unsigned(4 downto 0) := to_unsigned(6, 5);
  constant ADDR_RES_L  : unsigned(4 downto 0) := to_unsigned(7, 5);
  constant ADDR_RES_H  : unsigned(4 downto 0) := to_unsigned(8, 5);
  constant ADDR_RES_E  : unsigned(4 downto 0) := to_unsigned(9, 5);
  constant ADDR_STATUS : unsigned(4 downto 0) := to_unsigned(10, 5);
  constant ADDR_FPCR   : unsigned(4 downto 0) := to_unsigned(11, 5);
  constant ADDR_CIR_SAVE    : unsigned(4 downto 0) := to_unsigned(12, 5);
  constant ADDR_CIR_RESPONSE: unsigned(4 downto 0) := to_unsigned(13, 5);
  constant ADDR_FPSR   : unsigned(4 downto 0) := to_unsigned(14, 5);
  constant ADDR_CYCLE_CFG0 : unsigned(4 downto 0) := to_unsigned(15, 5);
  constant ADDR_CYCLE_CFG1 : unsigned(4 downto 0) := to_unsigned(16, 5);
  constant ADDR_FRAME_CMD  : unsigned(4 downto 0) := to_unsigned(17, 5);
  constant ADDR_FRAME_W0   : unsigned(4 downto 0) := to_unsigned(18, 5);
  constant ADDR_FRAME_W1   : unsigned(4 downto 0) := to_unsigned(19, 5);
  constant ADDR_FRAME_W2   : unsigned(4 downto 0) := to_unsigned(20, 5);
  constant ADDR_FRAME_W3   : unsigned(4 downto 0) := to_unsigned(21, 5);
  constant ADDR_CYCLE_TOTAL: unsigned(4 downto 0) := to_unsigned(22, 5);

  type dsack_state_t is (DSACK_IDLE, DSACK_WAIT_ASSERT, DSACK_ASSERTED);
  signal dsack_state  : dsack_state_t := DSACK_IDLE;
  signal dsack_count  : natural range 0 to 3 := 0;
  signal dsack_active : std_logic := '0';
  signal latched_size : std_logic_vector(1 downto 0) := (others => '0');
  signal latched_a4   : std_logic := '0';
  signal sync_read    : std_logic := '0';
  signal d_out_reg    : std_logic_vector(31 downto 0) := (others => '0');
  signal d_out_comb   : std_logic_vector(31 downto 0) := (others => '0');
  constant DSACK_ASSERT_CYCLES_READ  : natural := 1;
  constant DSACK_ASSERT_CYCLES_WRITE : natural := 1;

  signal micro_active_reg    : std_logic := '0';
  signal micro_remaining_reg : natural := 0;
  signal micro_total_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal result_ready_reg    : std_logic := '0';
  signal last_op_sel_reg     : fpu_op_t := FPU_OP_NOP;

  type frame_mem_t is array (0 to 3) of std_logic_vector(31 downto 0);
  signal frame_mem_reg : frame_mem_t := (others => (others => '0'));
  signal frame_busy_reg : std_logic := '0';
  signal frame_remaining_reg : natural := 0;
  signal frame_valid_reg : std_logic := '0';
  signal frame_restore_pending_reg : std_logic := '0';
  signal frame_start_save_reg : std_logic := '0';
  signal frame_start_restore_reg : std_logic := '0';

  signal op_sel_write_decoded : fpu_op_t := FPU_OP_NOP;
  signal op_issue_pulse       : std_logic := '0';

  constant FRAME_LATENCY : natural := 6;
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');

  constant FPSR_EXC_INEXACT  : natural := 0;
  constant FPSR_EXC_UNDERFLOW: natural := 1;
  constant FPSR_EXC_OVERFLOW : natural := 2;
  constant FPSR_EXC_DIVZERO  : natural := 3;
  constant FPSR_EXC_INVALID  : natural := 4;

  type access_class_t is (
    ACCESS_NONE,
    ACCESS_OPERAND,
    ACCESS_RESULT,
    ACCESS_STATUS,
    ACCESS_FPCR,
    ACCESS_FPSR,
    ACCESS_CIR,
    ACCESS_FRAME,
    ACCESS_CFG
  );
  signal access_class : access_class_t := ACCESS_NONE;

  function decode_src_kind(bits : std_logic_vector(2 downto 0)) return fpu_src_kind_t is
  begin
    case bits is
      when "000" => return FPU_SRC_FPM;
      when "001" => return FPU_SRC_MEM_INTEGER;
      when "010" => return FPU_SRC_MEM_SINGLE;
      when "011" => return FPU_SRC_MEM_DOUBLE;
      when "100" => return FPU_SRC_MEM_EXTENDED;
      when others => return FPU_SRC_MEM_PACKED;
    end case;
  end function;

  function decode_ea_mode(bits : std_logic_vector(4 downto 0)) return ea_mode_t is
  begin
    case bits is
      when "00000" => return EA_MODE_DN_AN;
      when "00001" => return EA_MODE_AN_INDIRECT;
      when "00010" => return EA_MODE_AN_POSTINC;
      when "00011" => return EA_MODE_AN_PREDEC;
      when "00100" => return EA_MODE_D16_AN_PC;
      when "00101" => return EA_MODE_ABS_W;
      when "00110" => return EA_MODE_ABS_L;
      when "00111" => return EA_MODE_IMMEDIATE;
      when "01000" => return EA_MODE_D8_AN_PC_XN;
      when "01001" => return EA_MODE_D16_AN_PC_XN;
      when "01010" => return EA_MODE_B;
      when "01011" => return EA_MODE_D16_B;
      when "01100" => return EA_MODE_D32_B;
      when "01101" => return EA_MODE_B_INDIRECT_I;
      when "01110" => return EA_MODE_B_INDIRECT_I_D16;
      when "01111" => return EA_MODE_B_INDIRECT_I_D32;
      when "10000" => return EA_MODE_D16_B_INDIRECT_I;
      when "10001" => return EA_MODE_D16_B_INDIRECT_I_D16;
      when "10010" => return EA_MODE_D16_B_INDIRECT_I_D32;
      when "10011" => return EA_MODE_D32_B_INDIRECT_I;
      when "10100" => return EA_MODE_D32_B_INDIRECT_I_D16;
      when others  => return EA_MODE_D32_B_INDIRECT_I_D32;
    end case;
  end function;

  function decode_cycle_case(bits : std_logic_vector(1 downto 0)) return ea_cycle_case_t is
  begin
    case bits is
      when "00" => return EA_CYCLE_BEST;
      when "01" => return EA_CYCLE_CACHE;
      when others => return EA_CYCLE_WORST;
    end case;
  end function;

  function fp80_is_zero(value : fp80_t) return boolean is
    variable exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  begin
    exp := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return exp = 0 and mant = 0;
  end function;

  function fp80_is_inf(value : fp80_t) return boolean is
    variable exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  begin
    exp := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return exp = FP_EXP_ALL_ONES and mant = 0;
  end function;

  function fp80_is_nan(value : fp80_t) return boolean is
    variable exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  begin
    exp := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return exp = FP_EXP_ALL_ONES and mant /= 0;
  end function;

begin
  addr      <= unsigned(a_in);
  bus_write <= '1' when (cs_n = '0' and as_n = '0' and ds_n = '0' and rw = '0') else '0';
  bus_read  <= '1' when (cs_n = '0' and as_n = '0' and ds_n = '0' and rw = '1') else '0';
  -- START = CS + AS + (R/W · DS) (active low signals except R/W).
  start_access <= '1' when (cs_n = '0' and as_n = '0' and ((rw = '1' and ds_n = '0') or rw = '0')) else '0';

  process(addr)
  begin
    access_class <= ACCESS_NONE;
    case addr is
      when ADDR_OPSEL | ADDR_OPA_L | ADDR_OPA_H | ADDR_OPA_E | ADDR_OPB_L | ADDR_OPB_H | ADDR_OPB_E =>
        access_class <= ACCESS_OPERAND;
      when ADDR_RES_L | ADDR_RES_H | ADDR_RES_E =>
        access_class <= ACCESS_RESULT;
      when ADDR_STATUS =>
        access_class <= ACCESS_STATUS;
      when ADDR_FPCR =>
        access_class <= ACCESS_FPCR;
      when ADDR_FPSR =>
        access_class <= ACCESS_FPSR;
      when ADDR_CIR_SAVE | ADDR_CIR_RESPONSE =>
        access_class <= ACCESS_CIR;
      when ADDR_FRAME_CMD | ADDR_FRAME_W0 | ADDR_FRAME_W1 | ADDR_FRAME_W2 | ADDR_FRAME_W3 =>
        access_class <= ACCESS_FRAME;
      when ADDR_CYCLE_CFG0 | ADDR_CYCLE_CFG1 | ADDR_CYCLE_TOTAL =>
        access_class <= ACCESS_CFG;
      when others =>
        access_class <= ACCESS_NONE;
    end case;
  end process;

  sync_read <= '1' when (bus_read = '1' and access_class = ACCESS_CIR) else '0';
  -- FPCR mode control: bits 7-6 precision, 5-4 rounding mode.
  round_mode <= decode_round_mode(fpcr_reg(5 downto 4));
  round_prec <= decode_round_prec(fpcr_reg(7 downto 6));
  op_sel_write_decoded <= decode_op_sel(d_in(2 downto 0));
  op_issue_pulse <= '1' when (
    bus_write = '1' and
    addr = ADDR_OPSEL and
    op_sel_write_decoded /= FPU_OP_NOP and
    micro_active_reg = '0' and
    frame_busy_reg = '0' and
    busy = '0'
  ) else '0';

  alu_inst : entity work.mc68881_alu
    port map (
      clk    => clk,
      reset_n => reset_n,
      start  => op_start_reg,
      op_sel => op_sel_reg,
      round_mode => round_mode,
      round_prec => round_prec,
      a_in   => operand_reg(0),
      b_in   => operand_reg(1),
      result => result,
      valid  => valid,
      busy   => busy
    );

  bus_frame_proc : process(clk, reset_n)
    variable status_frame_word : std_logic_vector(31 downto 0);
    variable exc_flags : std_logic_vector(4 downto 0);
    variable a_zero : boolean;
    variable b_zero : boolean;
    variable a_inf  : boolean;
    variable b_inf  : boolean;
    variable a_nan  : boolean;
    variable b_nan  : boolean;
    variable res_zero : boolean;
    variable res_inf  : boolean;
    variable res_nan  : boolean;
  begin
    if reset_n = '0' then
      op_sel_reg <= FPU_OP_NOP;
      operand_reg <= (others => (others => '0'));
      fpcr_reg <= (others => '0');
      fpsr_reg <= (others => '0');
      src_kind_reg <= FPU_SRC_FPM;
      ea_mode_reg <= EA_MODE_DN_AN;
      cycle_case_reg <= EA_CYCLE_BEST;
      mc68020_src_reg <= '0';
      mc68020_dst_reg <= '0';
      packed_dynamic_k_reg <= '0';
      frame_mem_reg <= (others => (others => '0'));
      frame_busy_reg <= '0';
      frame_remaining_reg <= 0;
      frame_valid_reg <= '0';
      frame_restore_pending_reg <= '0';
      frame_start_save_reg <= '0';
      frame_start_restore_reg <= '0';
    elsif rising_edge(clk) then
      frame_start_save_reg <= '0';
      frame_start_restore_reg <= '0';

      if bus_write = '1' then
        case addr is
          when ADDR_OPSEL =>
            op_sel_reg <= op_sel_write_decoded;
          when ADDR_OPA_L =>
            operand_reg(0)(FP80_RESULT_LO_WIDTH-1 downto 0) <= d_in;
          when ADDR_OPA_H =>
            operand_reg(0)(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH) <= d_in;
          when ADDR_OPA_E =>
            operand_reg(0)(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH) <= d_in(FP80_RESULT_EX_WIDTH-1 downto 0);
          when ADDR_OPB_L =>
            operand_reg(1)(FP80_RESULT_LO_WIDTH-1 downto 0) <= d_in;
          when ADDR_OPB_H =>
            operand_reg(1)(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH) <= d_in;
          when ADDR_OPB_E =>
            operand_reg(1)(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH) <= d_in(FP80_RESULT_EX_WIDTH-1 downto 0);
          when ADDR_FPCR =>
            fpcr_reg(15 downto 0) <= d_in(15 downto 0);
            fpcr_reg(31 downto 16) <= (others => '0');
          when ADDR_FPSR =>
            fpsr_reg <= d_in;
          when ADDR_CYCLE_CFG0 =>
            src_kind_reg <= decode_src_kind(d_in(2 downto 0));
            ea_mode_reg <= decode_ea_mode(d_in(7 downto 3));
          when ADDR_CYCLE_CFG1 =>
            cycle_case_reg <= decode_cycle_case(d_in(1 downto 0));
            mc68020_src_reg <= d_in(2);
            mc68020_dst_reg <= d_in(3);
            packed_dynamic_k_reg <= d_in(4);
          when ADDR_FRAME_CMD =>
            if d_in(0) = '1' then
              frame_start_save_reg <= '1';
            end if;
            if d_in(1) = '1' then
              frame_start_restore_reg <= '1';
            end if;
          when ADDR_FRAME_W0 =>
            frame_mem_reg(0) <= d_in;
            frame_valid_reg <= '1';
          when ADDR_FRAME_W1 =>
            frame_mem_reg(1) <= d_in;
            frame_valid_reg <= '1';
          when ADDR_FRAME_W2 =>
            frame_mem_reg(2) <= d_in;
            frame_valid_reg <= '1';
          when ADDR_FRAME_W3 =>
            frame_mem_reg(3) <= d_in;
            frame_valid_reg <= '1';
          when others =>
            null;
        end case;
      end if;

      if valid = '1' then
        exc_flags := (others => '0');
        a_zero := fp80_is_zero(operand_reg(0));
        b_zero := fp80_is_zero(operand_reg(1));
        a_inf := fp80_is_inf(operand_reg(0));
        b_inf := fp80_is_inf(operand_reg(1));
        a_nan := fp80_is_nan(operand_reg(0));
        b_nan := fp80_is_nan(operand_reg(1));
        res_zero := fp80_is_zero(result);
        res_inf := fp80_is_inf(result);
        res_nan := fp80_is_nan(result);

        if a_nan or b_nan or res_nan then
          exc_flags(FPSR_EXC_INVALID) := '1';
        end if;

        if last_op_sel_reg = FPU_OP_DIV then
          if b_zero and not a_zero then
            exc_flags(FPSR_EXC_DIVZERO) := '1';
          end if;
          if (a_zero and b_zero) or (a_inf and b_inf) then
            exc_flags(FPSR_EXC_INVALID) := '1';
          end if;
        end if;

        if res_inf and not a_inf and not b_inf and not res_nan and
           exc_flags(FPSR_EXC_DIVZERO) = '0' then
          exc_flags(FPSR_EXC_OVERFLOW) := '1';
        end if;

        if res_zero and not a_zero and not b_zero and not res_nan and not res_inf then
          exc_flags(FPSR_EXC_UNDERFLOW) := '1';
        end if;

        if exc_flags(FPSR_EXC_OVERFLOW) = '1' or exc_flags(FPSR_EXC_UNDERFLOW) = '1' then
          exc_flags(FPSR_EXC_INEXACT) := '1';
        end if;

        fpsr_reg(FPSR_EXC_INVALID downto FPSR_EXC_INEXACT) <=
          fpsr_reg(FPSR_EXC_INVALID downto FPSR_EXC_INEXACT) or exc_flags;
      end if;

      if frame_busy_reg = '1' then
        if frame_remaining_reg = 0 then
          frame_busy_reg <= '0';
          if frame_restore_pending_reg = '1' then
            fpcr_reg <= frame_mem_reg(0);
            fpsr_reg <= frame_mem_reg(1);
            frame_restore_pending_reg <= '0';
            frame_valid_reg <= '0';
          else
            frame_valid_reg <= '1';
          end if;
        else
          frame_remaining_reg <= frame_remaining_reg - 1;
        end if;
      end if;

      if frame_start_save_reg = '1' and frame_busy_reg = '0' and micro_active_reg = '0' then
        status_frame_word := (others => '0');
        status_frame_word(0) := status_valid_reg;
        status_frame_word(1) := status_busy_reg;
        status_frame_word(2) := frame_valid_reg;
        status_frame_word(3) := frame_busy_reg;
        frame_mem_reg(0) <= fpcr_reg;
        frame_mem_reg(1) <= fpsr_reg;
        frame_mem_reg(2) <= status_frame_word;
        frame_mem_reg(3) <= (others => '0');
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_valid_reg <= '0';
        frame_restore_pending_reg <= '0';
      elsif frame_start_restore_reg = '1' and frame_busy_reg = '0' and micro_active_reg = '0' then
        frame_busy_reg <= '1';
        frame_remaining_reg <= FRAME_LATENCY - 1;
        frame_restore_pending_reg <= '1';
      end if;
    end if;
  end process;

  alu_control_proc : process(clk, reset_n)
    variable total_cycles : natural := 0;
  begin
    if reset_n = '0' then
      result_lo_reg <= (others => '0');
      result_hi_reg <= (others => '0');
      result_ex_reg <= (others => '0');
      op_start_reg <= '0';
      micro_active_reg <= '0';
      micro_remaining_reg <= 0;
      micro_total_reg <= (others => '0');
      result_ready_reg <= '0';
      last_op_sel_reg <= FPU_OP_NOP;
    elsif rising_edge(clk) then
      op_start_reg <= '0';

      if op_issue_pulse = '1' then
        op_start_reg <= '1';
        result_ready_reg <= '0';
        last_op_sel_reg <= op_sel_write_decoded;
        micro_active_reg <= '1';
        total_cycles := op_cycle_count(
          op_sel_write_decoded,
          src_kind_reg,
          ea_mode_reg,
          cycle_case_reg,
          mc68020_src_reg = '1',
          mc68020_dst_reg = '1',
          packed_dynamic_k_reg = '1'
        );
        micro_total_reg <= std_logic_vector(to_unsigned(total_cycles, 32));
        if total_cycles = 0 then
          micro_remaining_reg <= 0;
        else
          micro_remaining_reg <= total_cycles - 1;
        end if;
      end if;

      if valid = '1' then
        result_lo_reg <= result(FP80_RESULT_LO_WIDTH-1 downto 0);
        result_hi_reg <= result(FP80_RESULT_LO_WIDTH+FP80_RESULT_HI_WIDTH-1 downto FP80_RESULT_LO_WIDTH);
        result_ex_reg <= result(FP_WIDTH-1 downto FP_WIDTH-FP80_RESULT_EX_WIDTH);
        result_ready_reg <= '1';
      end if;

      if micro_active_reg = '1' then
        if micro_remaining_reg = 0 then
          if result_ready_reg = '1' then
            micro_active_reg <= '0';
          end if;
        else
          micro_remaining_reg <= micro_remaining_reg - 1;
        end if;
      end if;
    end if;
  end process;

  status_proc : process(clk, reset_n)
  begin
    if reset_n = '0' then
      status_valid_reg <= '0';
      status_busy_reg <= '0';
      status_frame_valid_reg <= '0';
      status_frame_busy_reg <= '0';
    elsif rising_edge(clk) then
      if op_issue_pulse = '1' then
        status_valid_reg <= '0';
      elsif micro_active_reg = '1' and micro_remaining_reg = 0 and result_ready_reg = '1' then
        status_valid_reg <= '1';
      end if;

      status_busy_reg <= micro_active_reg or frame_busy_reg;
      status_frame_valid_reg <= frame_valid_reg;
      status_frame_busy_reg <= frame_busy_reg;
    end if;
  end process;

  process(
    addr,
    bus_read,
    result_lo_reg,
    result_hi_reg,
    result_ex_reg,
    status_valid_reg,
    status_busy_reg,
    status_frame_valid_reg,
    status_frame_busy_reg,
    fpcr_reg,
    fpsr_reg,
    src_kind_reg,
    ea_mode_reg,
    cycle_case_reg,
    mc68020_src_reg,
    mc68020_dst_reg,
    packed_dynamic_k_reg,
    frame_mem_reg,
    micro_total_reg
  )
    variable cfg0 : std_logic_vector(31 downto 0);
    variable cfg1 : std_logic_vector(31 downto 0);
  begin
    cfg0 := (others => '0');
    cfg1 := (others => '0');
    cfg0(2 downto 0) := std_logic_vector(to_unsigned(fpu_src_kind_t'pos(src_kind_reg), 3));
    cfg0(7 downto 3) := std_logic_vector(to_unsigned(ea_mode_t'pos(ea_mode_reg), 5));
    cfg1(1 downto 0) := std_logic_vector(to_unsigned(ea_cycle_case_t'pos(cycle_case_reg), 2));
    cfg1(2) := mc68020_src_reg;
    cfg1(3) := mc68020_dst_reg;
    cfg1(4) := packed_dynamic_k_reg;

    d_out_comb <= (others => '0');
    if bus_read = '1' then
      case addr is
        when ADDR_RES_L => d_out_comb <= result_lo_reg;
        when ADDR_RES_H => d_out_comb <= result_hi_reg;
        when ADDR_RES_E => d_out_comb(FP80_RESULT_EX_WIDTH-1 downto 0) <= result_ex_reg;
        when ADDR_STATUS =>
          d_out_comb(0) <= status_valid_reg;
          d_out_comb(1) <= status_busy_reg;
          d_out_comb(2) <= status_frame_valid_reg;
          d_out_comb(3) <= status_frame_busy_reg;
        when ADDR_FPCR =>
          d_out_comb <= fpcr_reg;
        when ADDR_FPSR =>
          d_out_comb <= fpsr_reg;
        when ADDR_CYCLE_CFG0 =>
          d_out_comb <= cfg0;
        when ADDR_CYCLE_CFG1 =>
          d_out_comb <= cfg1;
        when ADDR_CYCLE_TOTAL =>
          d_out_comb <= micro_total_reg;
        when ADDR_FRAME_W0 =>
          d_out_comb <= frame_mem_reg(0);
        when ADDR_FRAME_W1 =>
          d_out_comb <= frame_mem_reg(1);
        when ADDR_FRAME_W2 =>
          d_out_comb <= frame_mem_reg(2);
        when ADDR_FRAME_W3 =>
          d_out_comb <= frame_mem_reg(3);
        when others => d_out_comb <= (others => '0');
      end case;
    end if;
  end process;

  process(clk, reset_n)
    variable size_code : std_logic_vector(1 downto 0);
    variable dsack_wait : boolean;
    variable assert_cycles : natural;
  begin
    if reset_n = '0' then
      dsack_state  <= DSACK_IDLE;
      dsack_count  <= 0;
      dsack_active <= '0';
      latched_size <= (others => '0');
      latched_a4   <= '0';
      d_out_reg    <= (others => '0');
    elsif rising_edge(clk) then
      if sync_read = '1' and start_access = '1' then
        d_out_reg <= d_out_comb;
      end if;

      case dsack_state is
        when DSACK_IDLE =>
          dsack_active <= '0';
          if start_access = '1' then
            size_code := not size_n;
            latched_size <= size_code;
            latched_a4   <= a_in(4);
            dsack_wait := (size_code = "11");
            if bus_read = '1' then
              assert_cycles := DSACK_ASSERT_CYCLES_READ;
            else
              assert_cycles := DSACK_ASSERT_CYCLES_WRITE;
            end if;
            if dsack_wait then
              dsack_state <= DSACK_IDLE;
            elsif assert_cycles = 0 then
              dsack_active <= '1';
              dsack_state <= DSACK_ASSERTED;
            else
              dsack_count <= assert_cycles - 1;
              dsack_state <= DSACK_WAIT_ASSERT;
            end if;
          end if;
        when DSACK_WAIT_ASSERT =>
          if start_access = '0' then
            dsack_state <= DSACK_IDLE;
            dsack_active <= '0';
          elsif dsack_count = 0 then
            dsack_active <= '1';
            dsack_state <= DSACK_ASSERTED;
          else
            dsack_count <= dsack_count - 1;
          end if;
        when DSACK_ASSERTED =>
          dsack_active <= '1';
          if start_access = '0' then
            dsack_active <= '0';
            dsack_state <= DSACK_IDLE;
          end if;
      end case;
    end if;
  end process;

  process(latched_size, latched_a4, dsack_active)
  begin
    dsack0_i <= '1';
    dsack1_i <= '1';
    if dsack_active = '1' then
      case latched_size is
        when "00" =>
          if latched_a4 = '1' then
            dsack1_i <= '0';
            dsack0_i <= '0';
          else
            dsack1_i <= '0';
            dsack0_i <= '1';
          end if;
        when "01" =>
          dsack1_i <= '0';
          dsack0_i <= '1';
        when "10" =>
          dsack1_i <= '1';
          dsack0_i <= '0';
        when others =>
          dsack1_i <= '1';
          dsack0_i <= '1';
      end case;
    end if;
  end process;

  d_out <= d_out_reg when sync_read = '1' else d_out_comb;
  dsack0_n <= dsack0_i;
  dsack1_n <= dsack1_i;
  sense_drive <= '0' when status_busy_reg = '1' else '1';
  sense_n  <= sense_drive;
end architecture rtl;
