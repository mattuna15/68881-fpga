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
    aux_result : out fp80_t;
    aux_valid  : out std_logic
  );
end entity mc68881_alu;

architecture rtl of mc68881_alu is
  signal result_reg : fp80_t := (others => '0');
  signal valid_reg : std_logic := '0';
  signal busy_reg : std_logic := '0';

  signal trig_start_reg : std_logic := '0';
  signal trig_busy : std_logic := '0';
  signal trig_done : std_logic := '0';
  signal trig_result : fp80_t := (others => '0');
  signal trig_aux_result : fp80_t := (others => '0');
  signal trig_aux_valid : std_logic := '0';

  signal op_pending_reg : fpu_op_t := FPU_OP_NOP;
  signal aux_result_reg : fp80_t := (others => '0');
  signal aux_valid_reg : std_logic := '0';

  attribute keep_hierarchy : string;
  attribute keep_hierarchy of trig_inst : label is "yes";
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

  process(clk, reset_n)
  begin
    if reset_n = '0' then
      result_reg <= (others => '0');
      aux_result_reg <= (others => '0');
      valid_reg <= '0';
      aux_valid_reg <= '0';
      busy_reg <= '0';
      trig_start_reg <= '0';
      op_pending_reg <= FPU_OP_NOP;
    elsif rising_edge(clk) then
      valid_reg <= '0';
      aux_valid_reg <= '0';
      trig_start_reg <= '0';

      if busy_reg = '1' then
        if trig_done = '1' then
          result_reg <= trig_result;
          aux_result_reg <= trig_aux_result;
          valid_reg <= '1';
          aux_valid_reg <= trig_aux_valid;
          busy_reg <= '0';
          op_pending_reg <= FPU_OP_NOP;
        end if;
      elsif start = '1' then
        case op_sel is
          when FPU_OP_SIN | FPU_OP_COS | FPU_OP_TAN | FPU_OP_SINCOS =>
            op_pending_reg <= op_sel;
            trig_start_reg <= '1';
            busy_reg <= '1';
          when FPU_OP_ADD =>
            result_reg <= add_sub_fp80(a_in, b_in, false, round_mode, round_prec);
            valid_reg <= '1';
          when FPU_OP_SUB =>
            result_reg <= add_sub_fp80(a_in, b_in, true, round_mode, round_prec);
            valid_reg <= '1';
          when FPU_OP_MUL =>
            result_reg <= mul_fp80(a_in, b_in, round_mode, round_prec);
            valid_reg <= '1';
          when FPU_OP_DIV =>
            result_reg <= div_fp80(a_in, b_in, round_mode, round_prec);
            valid_reg <= '1';
          when FPU_OP_CMP =>
            result_reg <= add_sub_fp80(a_in, b_in, true, round_mode, round_prec);
            valid_reg <= '1';
          when FPU_OP_MOD =>
            result_reg <= fmod_fp80(a_in, b_in, round_mode, round_prec);
            valid_reg <= '1';
          when FPU_OP_REM =>
            result_reg <= frem_fp80(a_in, b_in, round_mode, round_prec);
            valid_reg <= '1';
          when FPU_OP_SCALE =>
            result_reg <= fscale_fp80(a_in, b_in);
            valid_reg <= '1';
          when FPU_OP_SGLDIV =>
            result_reg <= sgldiv_fp80(a_in, b_in, round_mode);
            valid_reg <= '1';
          when FPU_OP_SGLMUL =>
            result_reg <= sglmul_fp80(a_in, b_in, round_mode);
            valid_reg <= '1';
          when others =>
            result_reg <= (others => '0');
            valid_reg <= '1';
        end case;
      end if;
    end if;
  end process;

  result <= result_reg;
  valid <= valid_reg;
  busy <= busy_reg or trig_busy;
  aux_result <= aux_result_reg;
  aux_valid <= aux_valid_reg;
end architecture rtl;
