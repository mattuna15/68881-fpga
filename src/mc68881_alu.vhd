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
    busy    : out std_logic
  );
end entity mc68881_alu;

architecture rtl of mc68881_alu is
  constant MAX_LATENCY : natural := 8;

  constant ADD_LATENCY : natural := 1;
  constant SUB_LATENCY : natural := 1;
  constant MUL_LATENCY : natural := 4;
  constant DIV_LATENCY : natural := 8;

  type fp80_pipe_t is array (natural range <>) of fp80_t;
  signal pipe_data  : fp80_pipe_t(0 to MAX_LATENCY) := (others => (others => '0'));
  signal pipe_valid : std_logic_vector(0 to MAX_LATENCY) := (others => '0');

  function op_latency(op_kind : fpu_op_t) return natural is
  begin
    case op_kind is
      when FPU_OP_ADD => return ADD_LATENCY;
      when FPU_OP_SUB => return SUB_LATENCY;
      when FPU_OP_MUL => return MUL_LATENCY;
      when FPU_OP_DIV => return DIV_LATENCY;
      when others     => return 0;
    end case;
  end function;
begin
  process(clk, reset_n)
    variable latency : natural := 0;
    variable result_next : fp80_t := (others => '0');
  begin
    if reset_n = '0' then
      pipe_data  <= (others => (others => '0'));
      pipe_valid <= (others => '0');
    elsif rising_edge(clk) then
      for idx in 0 to MAX_LATENCY-1 loop
        pipe_data(idx) <= pipe_data(idx + 1);
        pipe_valid(idx) <= pipe_valid(idx + 1);
      end loop;
      pipe_data(MAX_LATENCY) <= (others => '0');
      pipe_valid(MAX_LATENCY) <= '0';

      if start = '1' then
        latency := op_latency(op_sel);
        case op_sel is
          when FPU_OP_ADD =>
            result_next := add_sub_fp80(a_in, b_in, false, round_mode, round_prec);
          when FPU_OP_SUB =>
            result_next := add_sub_fp80(a_in, b_in, true, round_mode, round_prec);
          when FPU_OP_MUL =>
            result_next := mul_fp80(a_in, b_in, round_mode, round_prec);
          when FPU_OP_DIV =>
            result_next := div_fp80(a_in, b_in, round_mode, round_prec);
          when others =>
            result_next := (others => '0');
        end case;

        if latency <= MAX_LATENCY then
          pipe_data(latency) <= result_next;
          pipe_valid(latency) <= '1';
        end if;
      end if;
    end if;
  end process;

  result <= pipe_data(0);
  valid  <= pipe_valid(0);
  busy   <= '1'
    when pipe_valid(1 to MAX_LATENCY) /= (pipe_valid(1 to MAX_LATENCY)'range => '0')
    else '0';
end architecture rtl;
