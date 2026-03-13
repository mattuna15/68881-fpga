library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_alu is
  generic (
    fpu_lite : boolean := false
  );
  port (
    clk     : in  std_logic;
    reset_n : in  std_logic;
    start   : in  std_logic;
    op_sel  : in  fpu_op_t;
    round_mode : in fp_round_mode_t;
    round_prec : in fp_round_prec_t;
    a_in    : in  fp80_t;
    b_in    : in  fp80_t;
    result  : out fp80_t;
    valid   : out std_logic;
    busy    : out std_logic;
    quotient_byte  : out std_logic_vector(7 downto 0);
    quotient_valid : out std_logic;
    aux_result : out fp80_t;
    aux_valid  : out std_logic;
    flag_divzero : out std_logic;
    -- Packed decimal FP multiply interface (shared FP unit)
    packed_fp_mul_start   : in  std_logic;
    packed_fp_mul_a       : in  fp80_t;
    packed_fp_mul_b       : in  fp80_t;
    packed_fp_mul_done    : out std_logic;
    packed_fp_mul_result  : out fp80_t;
    -- Packed decimal FP add interface (shared FP unit)
    packed_fp_add_start   : in  std_logic;
    packed_fp_add_a       : in  fp80_t;
    packed_fp_add_b       : in  fp80_t;
    packed_fp_add_sub     : in  boolean;
    packed_fp_add_done    : out std_logic;
    packed_fp_add_result  : out fp80_t;
    -- Save/restore interface for FSAVE/FRESTORE Busy frame.
    -- Addr 0..4: ALU state, 5..15: trig (11), 16..25: divrem+modrem_post (6+4).
    save_req     : in  std_logic;
    save_data    : out std_logic_vector(31 downto 0);
    save_addr    : in  natural range 0 to 25;
    restore_req  : in  std_logic;
    restore_data : in  std_logic_vector(31 downto 0);
    restore_addr : in  natural range 0 to 25;
    restore_wr   : in  std_logic
  );
end entity mc68881_alu;

architecture rtl of mc68881_alu is
  function is_trig_op(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_SIN or
           op = FPU_OP_COS or
           op = FPU_OP_TAN or
           op = FPU_OP_SINCOS or
           op = FPU_OP_ACOS or
           op = FPU_OP_ASIN or
           op = FPU_OP_ATAN or
           op = FPU_OP_ATANH or
           op = FPU_OP_COSH or
           op = FPU_OP_ETOX or
           op = FPU_OP_ETOXM1 or
           op = FPU_OP_LOGN or
           op = FPU_OP_LOGNP1 or
           op = FPU_OP_LOG10 or
           op = FPU_OP_LOG2 or
           op = FPU_OP_SINH or
           op = FPU_OP_TANH or
           op = FPU_OP_TENTOX or
           op = FPU_OP_TWOTOX;
  end function;

  function is_divrem_op(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_DIV or op = FPU_OP_SQRT or op = FPU_OP_MOD or op = FPU_OP_REM;
  end function;

  function is_sglops_op(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_SCALE or op = FPU_OP_SGLDIV or op = FPU_OP_SGLMUL;
  end function;

  function is_simple_op(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_ADD or
           op = FPU_OP_SUB or
           op = FPU_OP_MUL or
           op = FPU_OP_CMP or
           op = FPU_OP_ABS or
           op = FPU_OP_NEG or
           op = FPU_OP_INT or
           op = FPU_OP_INTRZ or
           op = FPU_OP_GETEXP or
           op = FPU_OP_GETMAN or
           op = FPU_OP_TST;
  end function;

  signal result_reg : fp80_t := (others => '0');
  signal busy_reg : std_logic := '0';

  signal trig_start_reg : std_logic := '0';
  signal trig_busy : std_logic := '0';
  signal trig_done : std_logic := '0';
  signal trig_result : fp80_t := (others => '0');
  signal trig_aux_result : fp80_t := (others => '0');
  signal trig_aux_valid : std_logic := '0';
  signal trig_flag_divzero : std_logic := '0';

  signal op_pending_reg : fpu_op_t := FPU_OP_NOP;
  signal latency_count_reg : natural := 0;
  signal trig_done_seen_reg : std_logic := '0';
  signal trig_result_latched_reg : fp80_t := (others => '0');
  signal trig_aux_result_latched_reg : fp80_t := (others => '0');
  signal aux_result_reg : fp80_t := (others => '0');
  signal quotient_byte_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal quotient_valid_reg : std_logic := '0';

  signal divrem_start_reg : std_logic := '0';
  signal divrem_op_reg : fpu_op_t := FPU_OP_NOP;
  signal divrem_a_reg : fp80_t := (others => '0');
  signal divrem_b_reg : fp80_t := (others => '0');
  signal divrem_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal divrem_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;
  signal divrem_busy : std_logic := '0';
  signal divrem_done : std_logic := '0';
  signal divrem_result : fp80_t := (others => '0');
  signal divrem_quotient_byte : std_logic_vector(7 downto 0) := (others => '0');
  signal divrem_quotient_valid : std_logic := '0';
  signal divrem_flag_divzero : std_logic := '0';
  signal divrem_flag_overflow : std_logic := '0';
  signal divrem_flag_underflow : std_logic := '0';
  signal divrem_flag_inexact : std_logic := '0';
  signal divrem_complete_reg : std_logic := '0';
  signal divrem_done_seen_reg : std_logic := '0';
  signal divrem_result_latched_reg : fp80_t := (others => '0');
  signal divrem_quotient_byte_latched_reg : std_logic_vector(7 downto 0) := (others => '0');
  signal divrem_quotient_valid_latched_reg : std_logic := '0';

  signal sglops_start_reg : std_logic := '0';
  signal sglops_op_reg : fpu_op_t := FPU_OP_NOP;
  signal sglops_a_reg : fp80_t := (others => '0');
  signal sglops_b_reg : fp80_t := (others => '0');
  signal sglops_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal sglops_busy : std_logic := '0';
  signal sglops_done : std_logic := '0';
  signal sglops_result : fp80_t := (others => '0');
  signal sglops_complete_reg : std_logic := '0';
  signal sglops_done_seen_reg : std_logic := '0';
  signal sglops_result_latched_reg : fp80_t := (others => '0');
  signal op_pending_is_trig : std_logic := '0';
  signal op_pending_is_divrem : std_logic := '0';
  signal op_pending_is_sglops : std_logic := '0';

  -- Registered dispatch for heavy simple ops (ADD/SUB/MUL/FINT).
  -- Operands are registered on start, FP function computed next cycle.
  signal simple_compute_pending_reg : std_logic := '0';
  signal simple_a_reg : fp80_t := (others => '0');
  signal simple_b_reg : fp80_t := (others => '0');
  signal simple_op_reg : fpu_op_t := FPU_OP_NOP;
  signal simple_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal simple_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;
  signal simple_hold_count_reg : integer range 0 to 1 := 0;  -- multi-cycle hold for FP settle (lightweight ops only)

  -- Sequential FP units for ADD/SUB/MUL (replaces combinational mul_fp80/add_sub_fp80)
  signal alu_mul_start_reg  : std_logic := '0';
  signal alu_mul_busy       : std_logic;
  signal alu_mul_done       : std_logic;
  signal alu_mul_result     : fp80_t;

  signal alu_add_start_reg  : std_logic := '0';
  signal alu_add_busy       : std_logic;
  signal alu_add_done       : std_logic;
  signal alu_add_result     : fp80_t;

  signal alu_fp_seq_pending_reg : std_logic := '0';
  signal alu_fp_is_mul_reg  : std_logic := '0';
  signal alu_fp_subtract_reg : boolean := false;

  -- Divrem modrem FP passthrough (internal to ALU)
  signal modrem_mul_start  : std_logic;
  signal modrem_mul_a      : fp80_t;
  signal modrem_mul_b      : fp80_t;
  signal modrem_add_start  : std_logic;
  signal modrem_add_a      : fp80_t;
  signal modrem_add_b      : fp80_t;
  signal modrem_add_sub    : boolean;
  signal modrem_add_rm     : fp_round_mode_t;
  signal modrem_add_rp     : fp_round_prec_t;

  -- Save/restore shadow registers for FSAVE/FRESTORE Busy frame
  type save_array_t is array (0 to 4) of std_logic_vector(31 downto 0);
  signal shadow_regs : save_array_t := (others => (others => '0'));

  -- Sub-unit save/restore routing signals.
  signal trig_save_data    : std_logic_vector(31 downto 0);
  signal trig_save_addr    : natural range 0 to 10 := 0;
  signal divrem_save_data  : std_logic_vector(31 downto 0);
  signal divrem_save_addr  : natural range 0 to 9 := 0;
  signal trig_restore_addr : natural range 0 to 10 := 0;
  signal divrem_restore_addr : natural range 0 to 9 := 0;
  signal trig_restore_wr   : std_logic := '0';
  signal divrem_restore_wr : std_logic := '0';

  -- Shared FP unit operand mux outputs
  signal shared_mul_start : std_logic;
  signal shared_mul_a     : fp80_t;
  signal shared_mul_b     : fp80_t;
  signal shared_mul_rm    : fp_round_mode_t;
  signal shared_mul_rp    : fp_round_prec_t;
  signal shared_add_start : std_logic;
  signal shared_add_a     : fp80_t;
  signal shared_add_b     : fp80_t;
  signal shared_add_sub   : boolean;
  signal shared_add_rm    : fp_round_mode_t;
  signal shared_add_rp    : fp_round_prec_t;

begin
  gen_trig_full : if not fpu_lite generate
    trig_inst : entity work.mc68881_trig_unit
      generic map (
        table_impl => TABLE_IMPL_BRAM
      )
      port map (
        clk        => clk,
        reset_n    => reset_n,
        start      => trig_start_reg,
        op_sel     => op_pending_reg,
        a_in       => a_in,
        round_mode => round_mode,
        round_prec => round_prec,
        busy       => trig_busy,
        done       => trig_done,
        result     => trig_result,
        aux_valid  => trig_aux_valid,
        aux_result => trig_aux_result,
        flag_divzero => trig_flag_divzero,
        save_req       => save_req,
        save_data      => trig_save_data,
        save_addr      => trig_save_addr,
        restore_req    => restore_req,
        restore_data   => restore_data,
        restore_addr   => trig_restore_addr,
        restore_wr     => trig_restore_wr
      );
  end generate;

  gen_trig_lite : if fpu_lite generate
  begin
    trig_busy <= '0';
    trig_done <= '0';
    trig_result <= (others => '0');
    trig_aux_result <= (others => '0');
    trig_aux_valid <= '0';
    trig_flag_divzero <= '0';
    trig_save_data <= (others => '0');
  end generate;

  divrem_inst : entity work.mc68881_divrem_unit
    generic map (
      enable_modrem_post => not fpu_lite
    )
    port map (
      clk     => clk,
      reset_n => reset_n,
      start   => divrem_start_reg,
      op_sel  => divrem_op_reg,
      a_in    => divrem_a_reg,
      b_in    => divrem_b_reg,
      round_mode => divrem_rm_reg,
      round_prec => divrem_rp_reg,
      busy    => divrem_busy,
      done    => divrem_done,
      result  => divrem_result,
      quotient_byte  => divrem_quotient_byte,
      quotient_valid => divrem_quotient_valid,
      flag_invalid   => open,
      flag_divzero   => divrem_flag_divzero,
      flag_overflow  => divrem_flag_overflow,
      flag_underflow => divrem_flag_underflow,
      flag_inexact   => divrem_flag_inexact,
      modrem_fp_mul_start  => modrem_mul_start,
      modrem_fp_mul_a      => modrem_mul_a,
      modrem_fp_mul_b      => modrem_mul_b,
      modrem_fp_mul_done   => alu_mul_done,
      modrem_fp_mul_result => alu_mul_result,
      modrem_fp_add_start  => modrem_add_start,
      modrem_fp_add_a      => modrem_add_a,
      modrem_fp_add_b      => modrem_add_b,
      modrem_fp_add_sub    => modrem_add_sub,
      modrem_fp_add_rm     => modrem_add_rm,
      modrem_fp_add_rp     => modrem_add_rp,
      modrem_fp_add_done   => alu_add_done,
      modrem_fp_add_result => alu_add_result,
      save_req       => save_req,
      save_data      => divrem_save_data,
      save_addr      => divrem_save_addr,
      restore_req    => restore_req,
      restore_data   => restore_data,
      restore_addr   => divrem_restore_addr,
      restore_wr     => divrem_restore_wr
    );

  gen_sglops_full : if not fpu_lite generate
    sglops_inst : entity work.mc68881_sgl_ops_unit
      port map (
        clk        => clk,
        reset_n    => reset_n,
        start      => sglops_start_reg,
        op_sel     => sglops_op_reg,
        a_in       => sglops_a_reg,
        b_in       => sglops_b_reg,
        round_mode => sglops_rm_reg,
        busy       => sglops_busy,
        done       => sglops_done,
        result     => sglops_result
      );
  end generate;

  gen_sglops_lite : if fpu_lite generate
  begin
    sglops_busy <= '0';
    sglops_done <= '0';
    sglops_result <= (others => '0');
  end generate;

  -- Shared FP multiply operand mux (mutually exclusive: ALU own vs modrem vs packed)
  -- pragma translate_off
  assert not (alu_mul_start_reg = '1' and modrem_mul_start = '1')
    report "MUTUAL EXCLUSION VIOLATION: ALU and modrem both requesting mul" severity failure;
  assert not (alu_mul_start_reg = '1' and packed_fp_mul_start = '1')
    report "MUTUAL EXCLUSION VIOLATION: ALU and packed both requesting mul" severity failure;
  assert not (modrem_mul_start = '1' and packed_fp_mul_start = '1')
    report "MUTUAL EXCLUSION VIOLATION: modrem and packed both requesting mul" severity failure;
  -- pragma translate_on
  shared_mul_start <= alu_mul_start_reg or modrem_mul_start or packed_fp_mul_start;
  shared_mul_a <= modrem_mul_a when modrem_mul_start = '1' else
                  packed_fp_mul_a when packed_fp_mul_start = '1' else
                  simple_a_reg;
  shared_mul_b <= modrem_mul_b when modrem_mul_start = '1' else
                  packed_fp_mul_b when packed_fp_mul_start = '1' else
                  simple_b_reg;
  shared_mul_rm <= FP_RND_NEAREST when modrem_mul_start = '1' else
                   FP_RND_NEAREST when packed_fp_mul_start = '1' else
                   simple_rm_reg;
  shared_mul_rp <= FP_PREC_EXTENDED when modrem_mul_start = '1' else
                   FP_PREC_EXTENDED when packed_fp_mul_start = '1' else
                   simple_rp_reg;

  -- Shared FP add/sub operand mux
  -- pragma translate_off
  assert not (alu_add_start_reg = '1' and modrem_add_start = '1')
    report "MUTUAL EXCLUSION VIOLATION: ALU and modrem both requesting add" severity failure;
  assert not (alu_add_start_reg = '1' and packed_fp_add_start = '1')
    report "MUTUAL EXCLUSION VIOLATION: ALU and packed both requesting add" severity failure;
  assert not (modrem_add_start = '1' and packed_fp_add_start = '1')
    report "MUTUAL EXCLUSION VIOLATION: modrem and packed both requesting add" severity failure;
  -- pragma translate_on
  shared_add_start <= alu_add_start_reg or modrem_add_start or packed_fp_add_start;
  shared_add_a <= modrem_add_a when modrem_add_start = '1' else
                  packed_fp_add_a when packed_fp_add_start = '1' else
                  simple_a_reg;
  shared_add_b <= modrem_add_b when modrem_add_start = '1' else
                  packed_fp_add_b when packed_fp_add_start = '1' else
                  simple_b_reg;
  shared_add_sub <= modrem_add_sub when modrem_add_start = '1' else
                    packed_fp_add_sub when packed_fp_add_start = '1' else
                    alu_fp_subtract_reg;
  shared_add_rm <= modrem_add_rm when modrem_add_start = '1' else
                   FP_RND_NEAREST when packed_fp_add_start = '1' else
                   simple_rm_reg;
  shared_add_rp <= modrem_add_rp when modrem_add_start = '1' else
                   FP_PREC_EXTENDED when packed_fp_add_start = '1' else
                   simple_rp_reg;

  alu_mul_inst : entity work.mc68881_fp80_mul_unit
    port map (
      clk => clk, reset_n => reset_n,
      start => shared_mul_start,
      a_in => shared_mul_a, b_in => shared_mul_b,
      round_mode => shared_mul_rm, round_prec => shared_mul_rp,
      busy => alu_mul_busy, done => alu_mul_done,
      result => alu_mul_result
    );

  alu_add_inst : entity work.mc68881_fp80_addsub_unit
    port map (
      clk => clk, reset_n => reset_n,
      start => shared_add_start,
      a_in => shared_add_a, b_in => shared_add_b,
      subtract => shared_add_sub,
      round_mode => shared_add_rm, round_prec => shared_add_rp,
      busy => alu_add_busy, done => alu_add_done,
      result => alu_add_result
    );

  -- Broadcast done/result to packed decimal consumer
  packed_fp_mul_done   <= alu_mul_done;
  packed_fp_mul_result <= alu_mul_result;
  packed_fp_add_done   <= alu_add_done;
  packed_fp_add_result <= alu_add_result;

  op_pending_is_trig <= '1' when is_trig_op(op_pending_reg) else '0';
  op_pending_is_divrem <= '1' when is_divrem_op(op_pending_reg) else '0';
  op_pending_is_sglops <= '1' when is_sglops_op(op_pending_reg) else '0';

  -- Trig/divrem DZ flags are stateful inside subunits; only expose DZ from the
  -- subunit associated with the active operation to avoid stale-flag leakage.
  flag_divzero <=
    (trig_flag_divzero and op_pending_is_trig) or
    (divrem_flag_divzero and op_pending_is_divrem);

  process(clk, reset_n)
  begin
    if reset_n = '0' then
      result_reg <= (others => '0');
      aux_result_reg <= (others => '0');
      valid <= '0';
      aux_valid <= '0';
      busy_reg <= '0';
      trig_start_reg <= '0';
      divrem_start_reg <= '0';
      sglops_start_reg <= '0';
      op_pending_reg <= FPU_OP_NOP;
      divrem_op_reg <= FPU_OP_NOP;
      divrem_a_reg <= (others => '0');
      divrem_b_reg <= (others => '0');
      divrem_rm_reg <= FP_RND_NEAREST;
      divrem_rp_reg <= FP_PREC_EXTENDED;
      divrem_complete_reg <= '0';
      divrem_done_seen_reg <= '0';
      divrem_result_latched_reg <= (others => '0');
      divrem_quotient_byte_latched_reg <= (others => '0');
      divrem_quotient_valid_latched_reg <= '0';
      sglops_op_reg <= FPU_OP_NOP;
      sglops_a_reg <= (others => '0');
      sglops_b_reg <= (others => '0');
      sglops_rm_reg <= FP_RND_NEAREST;
      sglops_complete_reg <= '0';
      sglops_done_seen_reg <= '0';
      sglops_result_latched_reg <= (others => '0');
      latency_count_reg <= 0;
      trig_done_seen_reg <= '0';
      trig_result_latched_reg <= (others => '0');
      trig_aux_result_latched_reg <= (others => '0');
      quotient_byte_reg <= (others => '0');
      quotient_valid_reg <= '0';
      simple_compute_pending_reg <= '0';
      simple_a_reg <= (others => '0');
      simple_b_reg <= (others => '0');
      simple_op_reg <= FPU_OP_NOP;
      simple_rm_reg <= FP_RND_NEAREST;
      simple_rp_reg <= FP_PREC_EXTENDED;
      simple_hold_count_reg <= 0;
      alu_mul_start_reg <= '0';
      alu_add_start_reg <= '0';
      alu_fp_seq_pending_reg <= '0';
      alu_fp_is_mul_reg <= '0';
      alu_fp_subtract_reg <= false;
    elsif rising_edge(clk) then
      valid <= '0';
      aux_valid <= '0';
      quotient_valid_reg <= '0';
      trig_start_reg <= '0';
      divrem_start_reg <= '0';
      sglops_start_reg <= '0';
      alu_mul_start_reg <= '0';
      alu_add_start_reg <= '0';
      if busy_reg = '1' and op_pending_is_divrem = '1' and divrem_complete_reg = '1' then
        valid <= '1';
        quotient_valid_reg <= divrem_quotient_valid_latched_reg;
        busy_reg <= '0';
        op_pending_reg <= FPU_OP_NOP;
        divrem_complete_reg <= '0';
      end if;
      if busy_reg = '1' and op_pending_is_sglops = '1' and sglops_complete_reg = '1' then
        valid <= '1';
        busy_reg <= '0';
        op_pending_reg <= FPU_OP_NOP;
        sglops_complete_reg <= '0';
      end if;

      if busy_reg = '1' then
        if op_pending_is_trig = '1' then
          if trig_done = '1' then
            trig_done_seen_reg <= '1';
            trig_result_latched_reg <= trig_result;
            trig_aux_result_latched_reg <= trig_aux_result;
            result_reg <= trig_result;
            aux_result_reg <= trig_aux_result;
          end if;

          if trig_aux_valid = '1' then
            trig_aux_result_latched_reg <= trig_aux_result;
            aux_result_reg <= trig_aux_result;
          end if;

          if latency_count_reg = 0 and (trig_done_seen_reg = '1' or trig_done = '1') then
            if trig_done = '1' then
              result_reg <= trig_result;
              aux_result_reg <= trig_aux_result;
            else
              result_reg <= trig_result_latched_reg;
              aux_result_reg <= trig_aux_result_latched_reg;
            end if;
            valid <= '1';
            if op_pending_reg = FPU_OP_SINCOS then
              aux_valid <= '1';
            end if;
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
            trig_done_seen_reg <= '0';
          elsif latency_count_reg /= 0 then
            latency_count_reg <= latency_count_reg - 1;
          end if;
        elsif op_pending_is_divrem = '1' then
          if divrem_quotient_valid = '1' then
            divrem_quotient_byte_latched_reg <= divrem_quotient_byte;
            divrem_quotient_valid_latched_reg <= '1';
          end if;
          if divrem_done = '1' then
            divrem_done_seen_reg <= '1';
            divrem_result_latched_reg <= divrem_result;
          end if;

          if latency_count_reg /= 0 then
            latency_count_reg <= latency_count_reg - 1;
          elsif divrem_done_seen_reg = '1' or divrem_done = '1' then
            if divrem_done = '1' then
              result_reg <= divrem_result;
              if divrem_quotient_valid = '1' then
                quotient_byte_reg <= divrem_quotient_byte;
                quotient_valid_reg <= '1';
              else
                quotient_byte_reg <= divrem_quotient_byte_latched_reg;
                quotient_valid_reg <= divrem_quotient_valid_latched_reg;
              end if;
            else
              result_reg <= divrem_result_latched_reg;
              quotient_byte_reg <= divrem_quotient_byte_latched_reg;
              quotient_valid_reg <= divrem_quotient_valid_latched_reg;
            end if;
            divrem_complete_reg <= '1';
            divrem_done_seen_reg <= '0';
          end if;
        elsif op_pending_is_sglops = '1' then
          if sglops_done = '1' then
            sglops_done_seen_reg <= '1';
            sglops_result_latched_reg <= sglops_result;
          end if;

          if latency_count_reg /= 0 then
            latency_count_reg <= latency_count_reg - 1;
          elsif sglops_done_seen_reg = '1' or sglops_done = '1' then
            if sglops_done = '1' then
              result_reg <= sglops_result;
            else
              result_reg <= sglops_result_latched_reg;
            end if;
            sglops_complete_reg <= '1';
            sglops_done_seen_reg <= '0';
          end if;
        else
          -- Sequential FP unit completion (ADD/SUB/MUL)
          if alu_fp_seq_pending_reg = '1' then
            if (alu_fp_is_mul_reg = '1' and alu_mul_done = '1') or
               (alu_fp_is_mul_reg = '0' and alu_add_done = '1') then
              if alu_fp_is_mul_reg = '1' then
                result_reg <= alu_mul_result;
              else
                result_reg <= alu_add_result;
              end if;
              alu_fp_seq_pending_reg <= '0';
              -- Complete immediately if latency already expired
              if latency_count_reg = 0 then
                valid <= '1';
                busy_reg <= '0';
                op_pending_reg <= FPU_OP_NOP;
              end if;
            end if;
          end if;

          -- Lightweight simple ops path: compute from registered operands
          -- Multi-cycle hold: wait configured cycles to let combinational FP settle.
          if simple_compute_pending_reg = '1' then
            if simple_hold_count_reg > 0 then
              simple_hold_count_reg <= simple_hold_count_reg - 1;
            else
              case simple_op_reg is
                when FPU_OP_INT    => result_reg <= fint_fp80(simple_a_reg, simple_rm_reg);
                when FPU_OP_CMP    => result_reg <= fp80_from_int(compare_fp80(simple_a_reg, simple_b_reg));
                when FPU_OP_ABS    => result_reg <= abs_fp80(simple_a_reg);
                when FPU_OP_NEG    => result_reg <= neg_fp80(simple_a_reg);
                when FPU_OP_INTRZ  => result_reg <= fintrz_fp80(simple_a_reg);
                when FPU_OP_GETEXP => result_reg <= fgetexp_fp80(simple_a_reg);
                when FPU_OP_GETMAN => result_reg <= fgetman_fp80(simple_a_reg);
                when FPU_OP_TST    => result_reg <= ftst_fp80(simple_a_reg);
                when others        => result_reg <= (others => '0');
              end case;
              simple_compute_pending_reg <= '0';
            end if;
          end if;

          if alu_fp_seq_pending_reg = '0' then
            if latency_count_reg = 0 then
              valid <= '1';
              busy_reg <= '0';
              op_pending_reg <= FPU_OP_NOP;
            elsif latency_count_reg /= 0 then
              latency_count_reg <= latency_count_reg - 1;
            end if;
          elsif latency_count_reg /= 0 then
            latency_count_reg <= latency_count_reg - 1;
          end if;
        end if;
      elsif start = '1' then
        aux_result_reg <= (others => '0');
        quotient_valid_reg <= '0';
        divrem_complete_reg <= '0';
        divrem_done_seen_reg <= '0';
        divrem_quotient_byte_latched_reg <= (others => '0');
        divrem_quotient_valid_latched_reg <= '0';
        sglops_complete_reg <= '0';
        sglops_done_seen_reg <= '0';
        simple_compute_pending_reg <= '0';
        op_pending_reg <= op_sel;
        if is_trig_op(op_sel) and not fpu_lite then
          trig_start_reg <= '1';
          busy_reg <= '1';
          trig_done_seen_reg <= '0';
          if op_alu_latency(op_sel) <= 1 then
            latency_count_reg <= 0;
          else
            latency_count_reg <= op_alu_latency(op_sel) - 2;
          end if;
        elsif is_simple_op(op_sel) and (not fpu_lite or (op_sel /= FPU_OP_GETEXP and op_sel /= FPU_OP_GETMAN)) then
          if op_sel = FPU_OP_ADD or op_sel = FPU_OP_SUB or op_sel = FPU_OP_MUL then
            -- Sequential FP path: register operands, launch unit
            simple_a_reg <= a_in;
            simple_b_reg <= b_in;
            simple_rm_reg <= round_mode;
            simple_rp_reg <= round_prec;
            alu_fp_seq_pending_reg <= '1';
            if op_sel = FPU_OP_MUL then
              alu_fp_is_mul_reg <= '1';
              alu_mul_start_reg <= '1';
            else
              alu_fp_is_mul_reg <= '0';
              alu_fp_subtract_reg <= (op_sel = FPU_OP_SUB);
              alu_add_start_reg <= '1';
            end if;
            busy_reg <= '1';
            latency_count_reg <= op_alu_latency(op_sel) - 1;
          else
            -- Lightweight combinational path (CMP/ABS/NEG/INT/INTRZ/TST; GETEXP/GETMAN in full mode)
            simple_a_reg <= a_in;
            simple_b_reg <= b_in;
            simple_op_reg <= op_sel;
            simple_rm_reg <= round_mode;
            simple_rp_reg <= round_prec;
            simple_compute_pending_reg <= '1';
            simple_hold_count_reg <= 1;  -- reduced: heaviest remaining op is FINT (~30ns)
            busy_reg <= '1';
            if op_alu_latency(op_sel) <= 1 then
              latency_count_reg <= 1;
            else
              latency_count_reg <= op_alu_latency(op_sel) - 1;
            end if;
          end if;
        elsif is_divrem_op(op_sel) and (not fpu_lite or (op_sel = FPU_OP_DIV or op_sel = FPU_OP_SQRT)) then
          divrem_op_reg <= op_sel;
          divrem_a_reg <= a_in;
          divrem_b_reg <= b_in;
          divrem_rm_reg <= round_mode;
          divrem_rp_reg <= round_prec;
          divrem_start_reg <= '1';
          busy_reg <= '1';
          if op_alu_latency(op_sel) <= 1 then
            latency_count_reg <= 0;
          else
            latency_count_reg <= op_alu_latency(op_sel) - 2;
          end if;
        elsif is_sglops_op(op_sel) and not fpu_lite then
          sglops_op_reg <= op_sel;
          sglops_a_reg <= a_in;
          sglops_b_reg <= b_in;
          sglops_rm_reg <= round_mode;
          sglops_start_reg <= '1';
          busy_reg <= '1';
          if op_alu_latency(op_sel) <= 1 then
            latency_count_reg <= 0;
          else
            latency_count_reg <= op_alu_latency(op_sel) - 2;
          end if;
        else
          -- Unsupported or NOP: return zero immediately
          result_reg <= (others => '0');
          if op_alu_latency(op_sel) = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
            latency_count_reg <= 0;
          elsif fpu_lite then
            -- Unsupported op in lite mode: complete after 1 cycle
            -- Force op_pending to NOP so the simple-ops completion path handles it
            op_pending_reg <= FPU_OP_NOP;
            busy_reg <= '1';
            latency_count_reg <= 0;
          else
            busy_reg <= '1';
            latency_count_reg <= op_alu_latency(op_sel) - 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  result <= result_reg;
  busy <= busy_reg or trig_busy or divrem_busy or sglops_busy or
          (alu_mul_busy and alu_fp_seq_pending_reg) or
          (alu_add_busy and alu_fp_seq_pending_reg);
  quotient_byte <= quotient_byte_reg;
  quotient_valid <= quotient_valid_reg;
  aux_result <= aux_result_reg;

  -- ================================================================
  -- Save/restore process for FSAVE/FRESTORE Busy frame
  -- ================================================================
  p_save_restore : process(clk, reset_n)
  begin
    if reset_n = '0' then
      shadow_regs <= (others => (others => '0'));
    elsif rising_edge(clk) then
      -- Snapshot internal state on save request
      if save_req = '1' then
        -- Word 0: op_pending (16b) | busy (1b) | latency_count (15b)
        shadow_regs(0) <= std_logic_vector(to_unsigned(fpu_op_t'pos(op_pending_reg), 16))
                        & busy_reg
                        & std_logic_vector(to_unsigned(latency_count_reg, 15));
        -- Word 1: simple_hold_count (8b) | simple_compute_pending (1b)
        --       | alu_fp_seq_pending (1b) | alu_fp_is_mul (1b) | alu_fp_subtract (1b) | pad (20b)
        shadow_regs(1) <= std_logic_vector(to_unsigned(simple_hold_count_reg, 8))
                        & simple_compute_pending_reg
                        & alu_fp_seq_pending_reg
                        & alu_fp_is_mul_reg
                        & (x"00000" & '0');  -- 21-bit padding (alu_fp_subtract is boolean, encode as bit)
        shadow_regs(1)(20) <= '1' when alu_fp_subtract_reg else '0';
        -- Word 2: simple_op (16b) | simple_rm (8b) | simple_rp (8b)
        shadow_regs(2) <= std_logic_vector(to_unsigned(fpu_op_t'pos(simple_op_reg), 16))
                        & std_logic_vector(to_unsigned(fp_round_mode_t'pos(simple_rm_reg), 8))
                        & std_logic_vector(to_unsigned(fp_round_prec_t'pos(simple_rp_reg), 8));
        -- Word 3: trig_done_seen (1b) | divrem_done_seen (1b) | sglops_done_seen (1b)
        --       | divrem_complete (1b) | sglops_complete (1b) | pad (27b)
        shadow_regs(3) <= trig_done_seen_reg
                        & divrem_done_seen_reg
                        & sglops_done_seen_reg
                        & divrem_complete_reg
                        & sglops_complete_reg
                        & (26 downto 0 => '0');
        -- Word 4: reserved
        shadow_regs(4) <= (others => '0');
      end if;
      -- Restore: write shadow register from external data (ALU words 0..4 only)
      if restore_wr = '1' and restore_addr <= 4 then
        shadow_regs(restore_addr) <= restore_data;
      end if;
    end if;
  end process p_save_restore;

  -- Sub-unit save address routing (combinational).
  -- ALU: 0-4, trig: 5-15 (11 words), divrem+modrem_post: 16-25 (6+4 words).
  trig_save_addr   <= save_addr - 5  when save_addr >= 5 and save_addr <= 15 else 0;
  divrem_save_addr <= save_addr - 16 when save_addr >= 16 and save_addr <= 25 else 0;

  -- Sub-unit restore address and write-enable routing (combinational).
  trig_restore_addr   <= restore_addr - 5  when restore_addr >= 5 and restore_addr <= 15 else 0;
  divrem_restore_addr <= restore_addr - 16 when restore_addr >= 16 and restore_addr <= 25 else 0;
  trig_restore_wr     <= restore_wr when restore_addr >= 5 and restore_addr <= 15 else '0';
  divrem_restore_wr   <= restore_wr when restore_addr >= 16 and restore_addr <= 25 else '0';

  -- Read-side mux for save_data: route to ALU shadow regs or sub-unit data.
  save_data <= shadow_regs(save_addr) when save_addr <= 4 else
               trig_save_data          when save_addr >= 5 and save_addr <= 15 else
               divrem_save_data        when save_addr >= 16 and save_addr <= 25 else
               (others => '0');

end architecture rtl;
