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
    variable exc_policy : op_exception_policy_t;
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
    assert decode_op_sel_word(x"0000000D") = FPU_OP_SIN
      report "decode_op_sel_word legacy SIN mapping failed." severity failure;
    assert decode_op_sel_word(x"0100000E") = FPU_OP_COS
      report "decode_op_sel_word core-v1 COS mapping failed." severity failure;
    assert decode_op_sel_word(x"0100000F") = FPU_OP_TAN
      report "decode_op_sel_word core-v1 TAN mapping failed." severity failure;
    assert decode_op_sel_word(x"01000010") = FPU_OP_SINCOS
      report "decode_op_sel_word core-v1 SINCOS mapping failed." severity failure;
    assert decode_op_sel_word(x"7F000005") = FPU_OP_NOP
      report "decode_op_sel_word unknown namespace should map to NOP." severity failure;

    op_key := decode_op_key(x"0100000B");
    assert op_key.namespace = OP_NS_CORE_V1 and op_key.opcode_id = x"0B"
      report "decode_op_key namespace/opcode extraction failed." severity failure;

    assert op_class(FPU_OP_ADD) = OP_CLASS_ARITH
      report "op_class ADD mapping failed." severity failure;
    assert op_class(FPU_OP_MOVE) = OP_CLASS_MOVE
      report "op_class MOVE mapping failed." severity failure;
    assert op_class(FPU_OP_SIN) = OP_CLASS_ARITH
      report "op_class SIN mapping failed." severity failure;
    assert op_class(FPU_OP_FNOP) = OP_CLASS_PROG_CTRL
      report "op_class FNOP mapping failed." severity failure;
    assert op_class(FPU_OP_FSAVE) = OP_CLASS_SYS_CTRL
      report "op_class FSAVE mapping failed." severity failure;
    assert op_class(FPU_OP_FRESTORE) = OP_CLASS_SYS_CTRL
      report "op_class FRESTORE mapping failed." severity failure;
    assert op_class(FPU_OP_NOP) = OP_CLASS_NONE
      report "op_class NOP mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_DIV) = 8
      report "op_alu_latency DIV mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_MOVE) = 0
      report "op_alu_latency MOVE mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_TAN) = 8
      report "op_alu_latency TAN mapping failed." severity failure;
    assert op_cycle_model(FPU_OP_ADD) = OP_CYCLE_ARITH
      report "op_cycle_model ADD mapping failed." severity failure;
    assert op_cycle_model(FPU_OP_FRESTORE) = OP_CYCLE_ZERO
      report "op_cycle_model FRESTORE mapping failed." severity failure;

    exc_policy := op_exception_policy(FPU_OP_DIV);
    assert exc_policy.divzero_on_zero_divisor_nonzero_dividend
      report "DIV exception policy missing divzero behavior." severity failure;
    assert exc_policy.invalid_zero_over_zero and exc_policy.invalid_inf_over_inf
      report "DIV exception policy missing invalid behavior." severity failure;
    assert exc_policy.update_exc_status and exc_policy.update_accumulated_exc
      report "DIV exception policy should update FPSR status/accrued bytes." severity failure;
    assert exc_policy.update_cc_from_result and exc_policy.capture_fpiar_on_exception
      report "DIV exception policy should drive CC and exception-time FPIAR capture." severity failure;
    exc_policy := op_exception_policy(FPU_OP_MOD);
    assert exc_policy.invalid_divisor_zero
      report "MOD exception policy missing divisor-zero invalid behavior." severity failure;
    assert exc_policy.classify_overflow_underflow
      report "MOD exception policy should enable overflow/underflow classification." severity failure;
    exc_policy := op_exception_policy(FPU_OP_CMP);
    assert exc_policy.update_cc_from_compare and not exc_policy.update_cc_from_result
      report "CMP exception policy should source CC from compare relation." severity failure;

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
      FPU_OP_SIN,
      FPU_SRC_FPM,
      EA_MODE_DN_AN,
      EA_CYCLE_BEST,
      false,
      false,
      false
    );
    assert cycles = 120
      report "op_cycle_count SIN baseline mismatch." severity failure;

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
