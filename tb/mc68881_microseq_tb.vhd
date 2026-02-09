library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_microseq_tb is
end entity mc68881_microseq_tb;

architecture sim of mc68881_microseq_tb is
begin
  process
    variable cycles : natural := 0;
  begin
    report "Starting microsequencer package tests." severity note;

    assert decode_op_sel("001") = FPU_OP_ADD
      report "decode_op_sel ADD mapping failed." severity failure;
    assert decode_op_sel("010") = FPU_OP_SUB
      report "decode_op_sel SUB mapping failed." severity failure;
    assert decode_op_sel("011") = FPU_OP_MUL
      report "decode_op_sel MUL mapping failed." severity failure;
    assert decode_op_sel("100") = FPU_OP_DIV
      report "decode_op_sel DIV mapping failed." severity failure;
    assert decode_op_sel("101") = FPU_OP_MOVE
      report "decode_op_sel MOVE mapping failed." severity failure;
    assert decode_op_sel("110") = FPU_OP_MOVEM
      report "decode_op_sel MOVEM mapping failed." severity failure;
    assert decode_op_sel("111") = FPU_OP_NOP
      report "decode_op_sel default mapping failed." severity failure;

    assert op_class(FPU_OP_ADD) = OP_CLASS_ARITH
      report "op_class ADD mapping failed." severity failure;
    assert op_class(FPU_OP_MOVE) = OP_CLASS_MOVE
      report "op_class MOVE mapping failed." severity failure;
    assert op_class(FPU_OP_NOP) = OP_CLASS_NONE
      report "op_class NOP mapping failed." severity failure;

    cycles := op_cycle_count(
      FPU_OP_ADD,
      FPU_SRC_FPM,
      EA_MODE_DN_AN,
      EA_CYCLE_BEST,
      false,
      false,
      false
    );
    assert cycles = 51
      report "op_cycle_count ADD baseline mismatch." severity failure;

    cycles := op_cycle_count(
      FPU_OP_DIV,
      FPU_SRC_MEM_PACKED,
      EA_MODE_AN_POSTINC,
      EA_CYCLE_WORST,
      true,
      true,
      true
    );
    assert cycles = 953
      report "op_cycle_count DIV packed mismatch." severity failure;

    report "Microsequencer package tests completed." severity note;
    wait;
  end process;
end architecture sim;
