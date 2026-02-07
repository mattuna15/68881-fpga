library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity tb_mc68881_alu is
end entity tb_mc68881_alu;

architecture sim of tb_mc68881_alu is
  signal op_sel : fpu_op_t := FPU_OP_NOP;
  signal a_in   : fp80_t := (others => '0');
  signal b_in   : fp80_t := (others => '0');
  signal result : fp80_t;
  signal valid  : std_logic;

  procedure check_result(
    constant expected : fp80_t;
    constant label    : string
  ) is
  begin
    assert result = expected
      report "Mismatch: " & label
      severity failure;
  end procedure;

  function fp80_of(value : natural) return fp80_t is
    variable tmp : fp80_t := (others => '0');
  begin
    tmp(31 downto 0) := std_logic_vector(to_unsigned(value, 32));
    return tmp;
  end function;

begin
  dut : entity work.mc68881_alu
    port map (
      op_sel => op_sel,
      a_in   => a_in,
      b_in   => b_in,
      result => result,
      valid  => valid
    );

  process
  begin
    -- ADD
    op_sel <= FPU_OP_ADD;
    a_in   <= fp80_of(10);
    b_in   <= fp80_of(5);
    wait for 10 ns;
    check_result(fp80_of(15), "ADD 10+5");

    -- SUB
    op_sel <= FPU_OP_SUB;
    a_in   <= fp80_of(10);
    b_in   <= fp80_of(3);
    wait for 10 ns;
    check_result(fp80_of(7), "SUB 10-3");

    -- MUL
    op_sel <= FPU_OP_MUL;
    a_in   <= fp80_of(7);
    b_in   <= fp80_of(9);
    wait for 10 ns;
    check_result(fp80_of(63), "MUL 7*9");

    -- DIV
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_of(40);
    b_in   <= fp80_of(5);
    wait for 10 ns;
    check_result(fp80_of(8), "DIV 40/5");

    wait;
  end process;
end architecture sim;
