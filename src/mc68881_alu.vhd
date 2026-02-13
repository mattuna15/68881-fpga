library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_alu is
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
    aux_valid  : out std_logic
  );
end entity mc68881_alu;

architecture rtl of mc68881_alu is
  function is_trig_op(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_SIN or op = FPU_OP_COS or op = FPU_OP_TAN or op = FPU_OP_SINCOS;
  end function;

  function is_divrem_op(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_DIV or op = FPU_OP_MOD or op = FPU_OP_REM;
  end function;

  function is_sglops_op(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_SCALE or op = FPU_OP_SGLDIV or op = FPU_OP_SGLMUL;
  end function;

  signal result_reg : fp80_t := (others => '0');
  signal busy_reg : std_logic := '0';

  signal trig_start_reg : std_logic := '0';
  signal trig_busy : std_logic := '0';
  signal trig_done : std_logic := '0';
  signal trig_result : fp80_t := (others => '0');
  signal trig_aux_result : fp80_t := (others => '0');
  signal trig_aux_valid : std_logic := '0';

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
  signal divrem_flag_invalid : std_logic := '0';
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

  attribute keep_hierarchy : string;
  attribute keep_hierarchy of trig_inst : label is "yes";
  attribute keep_hierarchy of divrem_inst : label is "yes";
  attribute keep_hierarchy of sglops_inst : label is "yes";
begin
  trig_inst : entity work.mc68881_trig_unit
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
      aux_result => trig_aux_result
    );

  divrem_inst : entity work.mc68881_divrem_unit
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
      flag_invalid   => divrem_flag_invalid,
      flag_divzero   => divrem_flag_divzero,
      flag_overflow  => divrem_flag_overflow,
      flag_underflow => divrem_flag_underflow,
      flag_inexact   => divrem_flag_inexact
    );

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

  op_pending_is_trig <= '1' when is_trig_op(op_pending_reg) else '0';
  op_pending_is_divrem <= '1' when is_divrem_op(op_pending_reg) else '0';
  op_pending_is_sglops <= '1' when is_sglops_op(op_pending_reg) else '0';

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
    elsif rising_edge(clk) then
      valid <= '0';
      aux_valid <= '0';
      quotient_valid_reg <= '0';
      trig_start_reg <= '0';
      divrem_start_reg <= '0';
      sglops_start_reg <= '0';
      if divrem_complete_reg = '1' then
        valid <= '1';
        quotient_valid_reg <= divrem_quotient_valid_latched_reg;
        busy_reg <= '0';
        op_pending_reg <= FPU_OP_NOP;
        divrem_complete_reg <= '0';
      end if;
      if sglops_complete_reg = '1' then
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
          if latency_count_reg = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
          else
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
        op_pending_reg <= op_sel;
        if is_trig_op(op_sel) then
          trig_start_reg <= '1';
          busy_reg <= '1';
          trig_done_seen_reg <= '0';
          if op_alu_latency(op_sel) <= 1 then
            latency_count_reg <= 0;
          else
            latency_count_reg <= op_alu_latency(op_sel) - 2;
          end if;
        elsif op_sel = FPU_OP_ADD then
          result_reg <= add_sub_fp80(a_in, b_in, false, round_mode, round_prec);
          if op_alu_latency(op_sel) = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
            latency_count_reg <= 0;
          else
            busy_reg <= '1';
            latency_count_reg <= op_alu_latency(op_sel) - 1;
          end if;
        elsif op_sel = FPU_OP_SUB then
          result_reg <= add_sub_fp80(a_in, b_in, true, round_mode, round_prec);
          if op_alu_latency(op_sel) = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
            latency_count_reg <= 0;
          else
            busy_reg <= '1';
            latency_count_reg <= op_alu_latency(op_sel) - 1;
          end if;
        elsif op_sel = FPU_OP_MUL then
          result_reg <= mul_fp80(a_in, b_in, round_mode, round_prec);
          if op_alu_latency(op_sel) = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
            latency_count_reg <= 0;
          else
            busy_reg <= '1';
            latency_count_reg <= op_alu_latency(op_sel) - 1;
          end if;
        elsif op_sel = FPU_OP_SQRT then
          result_reg <= sqrt_fp80(a_in, round_mode, round_prec);
          if op_alu_latency(op_sel) = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
            latency_count_reg <= 0;
          else
            busy_reg <= '1';
            latency_count_reg <= op_alu_latency(op_sel) - 1;
          end if;
        elsif is_divrem_op(op_sel) then
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
        elsif op_sel = FPU_OP_CMP then
          result_reg <= fp80_from_int(compare_fp80(a_in, b_in));
          if op_alu_latency(op_sel) = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
            latency_count_reg <= 0;
          else
            busy_reg <= '1';
            latency_count_reg <= op_alu_latency(op_sel) - 1;
          end if;
        elsif is_sglops_op(op_sel) then
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
          result_reg <= (others => '0');
          if op_alu_latency(op_sel) = 0 then
            valid <= '1';
            busy_reg <= '0';
            op_pending_reg <= FPU_OP_NOP;
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
  busy <= busy_reg or trig_busy or divrem_busy or sglops_busy;
  quotient_byte <= quotient_byte_reg;
  quotient_valid <= quotient_valid_reg;
  aux_result <= aux_result_reg;
end architecture rtl;
