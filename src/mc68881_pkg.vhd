library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mc68881_pkg is
  constant FP_WIDTH : natural := 80;

  subtype fp80_t is std_logic_vector(FP_WIDTH-1 downto 0);

  type fpu_op_t is (
    FPU_OP_NOP,
    FPU_OP_ADD,
    FPU_OP_SUB,
    FPU_OP_MUL,
    FPU_OP_DIV
  );

  function to_fp80(value : unsigned) return fp80_t;
end package mc68881_pkg;

package body mc68881_pkg is
  function to_fp80(value : unsigned) return fp80_t is
    variable result : fp80_t := (others => '0');
    variable width  : natural := value'length;
    variable copy_w : natural := 0;
  begin
    if width >= FP_WIDTH then
      copy_w := FP_WIDTH;
      result := std_logic_vector(value(copy_w-1 downto 0));
    else
      copy_w := width;
      result(copy_w-1 downto 0) := std_logic_vector(value);
    end if;
    return result;
  end function;
end package body mc68881_pkg;
