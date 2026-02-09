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
    variable op_key : op_key_t;
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
    assert decode_op_sel_word(x"00000005") = FPU_OP_MOVE
      report "decode_op_sel_word legacy MOVE mapping failed." severity failure;
    assert decode_op_sel_word(x"01000005") = FPU_OP_MOVE
      report "decode_op_sel_word core-v1 MOVE mapping failed." severity failure;
    assert decode_op_sel_word(x"01000020") = FPU_OP_FNOP
      report "decode_op_sel_word core-v1 FNOP mapping failed." severity failure;
    assert decode_op_sel_word(x"01000030") = FPU_OP_FSAVE
      report "decode_op_sel_word core-v1 FSAVE mapping failed." severity failure;
    assert decode_op_sel_word(x"01000031") = FPU_OP_FRESTORE
      report "decode_op_sel_word core-v1 FRESTORE mapping failed." severity failure;
    assert decode_op_sel_word(x"7F000005") = FPU_OP_NOP
      report "decode_op_sel_word unknown namespace should map to NOP." severity failure;

    op_key := decode_op_key(x"0100000B");
    assert op_key.namespace = OP_NS_CORE_V1 and op_key.opcode_id = x"0B"
      report "decode_op_key namespace/opcode extraction failed." severity failure;

    assert op_class(FPU_OP_ADD) = OP_CLASS_ARITH
      report "op_class ADD mapping failed." severity failure;
    assert op_class(FPU_OP_MOVE) = OP_CLASS_MOVE
      report "op_class MOVE mapping failed." severity failure;
    assert op_class(FPU_OP_FNOP) = OP_CLASS_PROG_CTRL
      report "op_class FNOP mapping failed." severity failure;
    assert op_class(FPU_OP_FSAVE) = OP_CLASS_SYS_CTRL
      report "op_class FSAVE mapping failed." severity failure;
    assert op_class(FPU_OP_FRESTORE) = OP_CLASS_SYS_CTRL
      report "op_class FRESTORE mapping failed." severity failure;
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

    cycles := op_cycle_count(
      FPU_OP_FNOP,
      FPU_SRC_FPM,
      EA_MODE_DN_AN,
      EA_CYCLE_BEST,
      false,
      false,
      false
    );
    assert cycles = 0
      report "op_cycle_count FNOP should be zero." severity failure;

    cycles := op_cycle_count(
      FPU_OP_FSAVE,
      FPU_SRC_FPM,
      EA_MODE_DN_AN,
      EA_CYCLE_BEST,
      false,
      false,
      false
    );
    assert cycles = 0
      report "op_cycle_count FSAVE should be zero." severity failure;

    report "Microsequencer package tests completed." severity note;
    wait;
  end process;
end architecture sim;
