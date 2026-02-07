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
    constant expected  : fp80_t;
    constant test_name : string
  ) is
  begin
    assert result = expected
      report "Mismatch: " & test_name
      severity failure;
  end procedure;

  function fp80_from_int(value : integer) return fp80_t is
  begin
    return work.mc68881_pkg.fp80_from_int(value);
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
    a_in   <= fp80_from_int(10);
    b_in   <= fp80_from_int(5);
    wait for 10 ns;
    check_result(fp80_from_int(15), "ADD 10+5");

    -- SUB
    op_sel <= FPU_OP_SUB;
    a_in   <= fp80_from_int(10);
    b_in   <= fp80_from_int(3);
    wait for 10 ns;
    check_result(fp80_from_int(7), "SUB 10-3");

    -- SUB negative result
    op_sel <= FPU_OP_SUB;
    a_in   <= fp80_from_int(3);
    b_in   <= fp80_from_int(10);
    wait for 10 ns;
    check_result(fp80_from_int(-7), "SUB 3-10");

    -- MUL
    op_sel <= FPU_OP_MUL;
    a_in   <= fp80_from_int(7);
    b_in   <= fp80_from_int(9);
    wait for 10 ns;
    check_result(fp80_from_int(63), "MUL 7*9");

    -- DIV
    op_sel <= FPU_OP_DIV;
    a_in   <= fp80_from_int(40);
    b_in   <= fp80_from_int(5);
    wait for 10 ns;
    check_result(fp80_from_int(8), "DIV 40/5");

    wait;
  end process;
end architecture sim;
