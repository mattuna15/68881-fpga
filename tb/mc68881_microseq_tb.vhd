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
    assert decode_op_sel_word(x"01000011") = FPU_OP_SQRT
      report "decode_op_sel_word core-v1 SQRT mapping failed." severity failure;
    assert decode_op_sel_word(x"01000020") = FPU_OP_FNOP
      report "decode_op_sel_word core-v1 FNOP mapping failed." severity failure;
    assert decode_op_sel_word(x"01000021") = FPU_OP_FSCC
      report "decode_op_sel_word core-v1 FScc mapping failed." severity failure;
    assert decode_op_sel_word(x"01000022") = FPU_OP_FBCC
      report "decode_op_sel_word core-v1 FBcc mapping failed." severity failure;
    assert decode_op_sel_word(x"01000023") = FPU_OP_FDBCC
      report "decode_op_sel_word core-v1 FDBcc mapping failed." severity failure;
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
    assert decode_op_sel_word(x"01000040") = FPU_OP_ACOS
      report "decode_op_sel_word core-v1 FACOS mapping failed." severity failure;
    assert decode_op_sel_word(x"01000041") = FPU_OP_ASIN
      report "decode_op_sel_word core-v1 FASIN mapping failed." severity failure;
    assert decode_op_sel_word(x"01000042") = FPU_OP_ATAN
      report "decode_op_sel_word core-v1 FATAN mapping failed." severity failure;
    assert decode_op_sel_word(x"01000043") = FPU_OP_ATANH
      report "decode_op_sel_word core-v1 FATANH mapping failed." severity failure;
    assert decode_op_sel_word(x"01000044") = FPU_OP_COSH
      report "decode_op_sel_word core-v1 FCOSH mapping failed." severity failure;
    assert decode_op_sel_word(x"01000045") = FPU_OP_ETOX
      report "decode_op_sel_word core-v1 FETOX mapping failed." severity failure;
    assert decode_op_sel_word(x"01000046") = FPU_OP_ETOXM1
      report "decode_op_sel_word core-v1 FETOXM1 mapping failed." severity failure;
    assert decode_op_sel_word(x"01000047") = FPU_OP_LOGN
      report "decode_op_sel_word core-v1 FLOGN mapping failed." severity failure;
    assert decode_op_sel_word(x"01000048") = FPU_OP_LOGNP1
      report "decode_op_sel_word core-v1 FLOGNP1 mapping failed." severity failure;
    assert decode_op_sel_word(x"01000049") = FPU_OP_LOG10
      report "decode_op_sel_word core-v1 FLOG10 mapping failed." severity failure;
    assert decode_op_sel_word(x"0100004A") = FPU_OP_LOG2
      report "decode_op_sel_word core-v1 FLOG2 mapping failed." severity failure;
    assert decode_op_sel_word(x"0100004B") = FPU_OP_SINH
      report "decode_op_sel_word core-v1 FSINH mapping failed." severity failure;
    assert decode_op_sel_word(x"0100004C") = FPU_OP_TANH
      report "decode_op_sel_word core-v1 FTANH mapping failed." severity failure;
    assert decode_op_sel_word(x"0100004D") = FPU_OP_TENTOX
      report "decode_op_sel_word core-v1 FTENTOX mapping failed." severity failure;
    assert decode_op_sel_word(x"0100004E") = FPU_OP_TWOTOX
      report "decode_op_sel_word core-v1 FTWOTOX mapping failed." severity failure;
    assert decode_op_sel_word(x"01000012") = FPU_OP_ABS
      report "decode_op_sel_word core-v1 FABS mapping failed." severity failure;
    assert decode_op_sel_word(x"01000013") = FPU_OP_NEG
      report "decode_op_sel_word core-v1 FNEG mapping failed." severity failure;
    assert decode_op_sel_word(x"01000014") = FPU_OP_INT
      report "decode_op_sel_word core-v1 FINT mapping failed." severity failure;
    assert decode_op_sel_word(x"01000015") = FPU_OP_INTRZ
      report "decode_op_sel_word core-v1 FINTRZ mapping failed." severity failure;
    assert decode_op_sel_word(x"01000016") = FPU_OP_GETEXP
      report "decode_op_sel_word core-v1 FGETEXP mapping failed." severity failure;
    assert decode_op_sel_word(x"01000017") = FPU_OP_GETMAN
      report "decode_op_sel_word core-v1 FGETMAN mapping failed." severity failure;
    assert decode_op_sel_word(x"01000018") = FPU_OP_TST
      report "decode_op_sel_word core-v1 FTST mapping failed." severity failure;
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
    assert op_class(FPU_OP_ETOX) = OP_CLASS_ARITH
      report "op_class FETOX mapping failed." severity failure;
    assert op_class(FPU_OP_SQRT) = OP_CLASS_ARITH
      report "op_class SQRT mapping failed." severity failure;
    assert op_class(FPU_OP_TST) = OP_CLASS_ARITH
      report "op_class FTST mapping failed." severity failure;
    assert op_class(FPU_OP_FNOP) = OP_CLASS_PROG_CTRL
      report "op_class FNOP mapping failed." severity failure;
    assert op_class(FPU_OP_FSCC) = OP_CLASS_PROG_CTRL
      report "op_class FScc mapping failed." severity failure;
    assert op_class(FPU_OP_FBCC) = OP_CLASS_PROG_CTRL
      report "op_class FBcc mapping failed." severity failure;
    assert op_class(FPU_OP_FDBCC) = OP_CLASS_PROG_CTRL
      report "op_class FDBcc mapping failed." severity failure;
    assert op_class(FPU_OP_FSAVE) = OP_CLASS_SYS_CTRL
      report "op_class FSAVE mapping failed." severity failure;
    assert op_class(FPU_OP_FRESTORE) = OP_CLASS_SYS_CTRL
      report "op_class FRESTORE mapping failed." severity failure;
    assert op_class(FPU_OP_NOP) = OP_CLASS_NONE
      report "op_class NOP mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_DIV) = 73
      report "op_alu_latency DIV mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_MOVE) = 0
      report "op_alu_latency MOVE mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_TAN) = 34
      report "op_alu_latency TAN mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_LOGN) = 14
      report "op_alu_latency FLOGN mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_SQRT) = 73
      report "op_alu_latency SQRT mapping failed." severity failure;
    assert op_alu_latency(FPU_OP_GETMAN) = 5
      report "op_alu_latency FGETMAN mapping failed." severity failure;
    assert op_cycle_model(FPU_OP_ADD) = OP_CYCLE_ARITH
      report "op_cycle_model ADD mapping failed." severity failure;
    assert op_cycle_model(FPU_OP_ACOS) = OP_CYCLE_ARITH
      report "op_cycle_model FACOS mapping failed." severity failure;
    assert op_cycle_model(FPU_OP_FRESTORE) = OP_CYCLE_ZERO
      report "op_cycle_model FRESTORE mapping failed." severity failure;
    assert op_cycle_model(FPU_OP_TST) = OP_CYCLE_ARITH
      report "op_cycle_model FTST mapping failed." severity failure;

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
    exc_policy := op_exception_policy(FPU_OP_SQRT);
    assert exc_policy.invalid_on_nan_inputs and exc_policy.invalid_on_nan_result
      report "SQRT exception policy should flag NaN inputs/results." severity failure;
    assert exc_policy.update_cc_from_result and exc_policy.capture_fpiar_on_exception
      report "SQRT exception policy should update CC and capture FPIAR." severity failure;
    exc_policy := op_exception_policy(FPU_OP_TST);
    assert exc_policy.update_cc_from_result and not exc_policy.classify_overflow_underflow
      report "FTST exception policy should update CC without overflow/underflow classification." severity failure;
    exc_policy := op_exception_policy(FPU_OP_GETEXP);
    assert exc_policy.invalid_on_nan_inputs and exc_policy.invalid_on_nan_result
      report "FGETEXP exception policy should flag NaN inputs/results." severity failure;
    exc_policy := op_exception_policy(FPU_OP_TWOTOX);
    assert exc_policy.invalid_on_nan_inputs and exc_policy.invalid_on_nan_result
      report "FTWOTOX exception policy should flag NaN inputs/results." severity failure;

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
      FPU_OP_FSCC,
      FPU_SRC_FPM,
      EA_MODE_DN_AN,
      EA_CYCLE_BEST,
      false,
      false,
      false
    );
    assert cycles = 0
      report "op_cycle_count FScc should be zero." severity failure;

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
