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
    a_in    : in  fp80_t;
    b_in    : in  fp80_t;
    result  : out fp80_t;
    valid   : out std_logic;
    busy    : out std_logic
  );
end entity mc68881_alu;

architecture rtl of mc68881_alu is
  signal result_reg : fp80_t := (others => '0');
  signal valid_reg  : std_logic := '0';
  signal busy_reg   : std_logic := '0';
  signal cycle_cnt  : natural := 0;

  constant ADD_LATENCY : natural := 1;
  constant SUB_LATENCY : natural := 1;
  constant MUL_LATENCY : natural := 4;
  constant DIV_LATENCY : natural := 8;

  function op_latency(op_sel : fpu_op_t) return natural is
  begin
    case op_sel is
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
  begin
    if reset_n = '0' then
      result_reg <= (others => '0');
      valid_reg  <= '0';
      busy_reg   <= '0';
      cycle_cnt  <= 0;
    elsif rising_edge(clk) then
      valid_reg <= '0';

      if start = '1' and busy_reg = '0' then
        latency := op_latency(op_sel);
        case op_sel is
          when FPU_OP_ADD =>
            result_reg <= add_sub_fp80(a_in, b_in, false);
          when FPU_OP_SUB =>
            result_reg <= add_sub_fp80(a_in, b_in, true);
          when FPU_OP_MUL =>
            result_reg <= mul_fp80(a_in, b_in);
          when FPU_OP_DIV =>
            result_reg <= div_fp80(a_in, b_in);
          when others =>
            result_reg <= (others => '0');
        end case;

        if latency = 0 then
          valid_reg <= '1';
          busy_reg  <= '0';
          cycle_cnt <= 0;
        else
          busy_reg  <= '1';
          cycle_cnt <= latency - 1;
        end if;
      elsif busy_reg = '1' then
        if cycle_cnt = 0 then
          valid_reg <= '1';
          busy_reg  <= '0';
        else
          cycle_cnt <= cycle_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  result <= result_reg;
  valid  <= valid_reg;
  busy   <= busy_reg;
end architecture rtl;
