library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_alu is
  port (
    op_sel  : in  fpu_op_t;
    a_in    : in  fp80_t;
    b_in    : in  fp80_t;
    result  : out fp80_t;
    valid   : out std_logic
  );
end entity mc68881_alu;

architecture rtl of mc68881_alu is
  signal a_u : unsigned(FP_WIDTH-1 downto 0);
  signal b_u : unsigned(FP_WIDTH-1 downto 0);
  signal r_u : unsigned(FP_WIDTH-1 downto 0);
  signal r_ext : unsigned((FP_WIDTH*2)-1 downto 0);
begin
  a_u <= unsigned(a_in);
  b_u <= unsigned(b_in);

  process(op_sel, a_u, b_u)
  begin
    r_u   <= (others => '0');
    r_ext <= (others => '0');
    valid <= '1';

    case op_sel is
      when FPU_OP_ADD =>
        r_u <= a_u + b_u;
      when FPU_OP_SUB =>
        r_u <= a_u - b_u;
      when FPU_OP_MUL =>
        r_ext <= a_u * b_u;
        r_u   <= r_ext(FP_WIDTH-1 downto 0);
      when FPU_OP_DIV =>
        if b_u = 0 then
          r_u <= (others => '0');
        else
          r_u <= a_u / b_u;
        end if;
      when others =>
        valid <= '0';
        r_u   <= (others => '0');
    end case;
  end process;

  result <= std_logic_vector(r_u);
end architecture rtl;
