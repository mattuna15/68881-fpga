library ieee;
use ieee.std_logic_1164.all;

use work.mc68881_pkg.all;

entity tb_mc68881_cycle_counts is
end entity tb_mc68881_cycle_counts;

architecture tb of tb_mc68881_cycle_counts is
  procedure assert_base_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    expected : natural;
    label_text : string
  ) is
    variable got : natural := 0;
  begin
    got := base_arith_cycles(op_sel, src_kind);
    report "Base cycles " & label_text & " expected=" & integer'image(expected) &
      " got=" & integer'image(got) severity note;
    assert got = expected
      report "Base cycle mismatch for " & label_text severity error;
  end procedure;

  procedure assert_total_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean;
    expected : natural;
    label_text : string
  ) is
    variable got : natural := 0;
  begin
    got := total_arith_cycles(
      op_sel,
      src_kind,
      ea_mode,
      cycle_case,
      mc68020_src,
      mc68020_dst,
      packed_dynamic_k
    );
    report "Total cycles " & label_text & " expected=" & integer'image(expected) &
      " got=" & integer'image(got) severity note;
    assert got = expected
      report "Total cycle mismatch for " & label_text severity error;
  end procedure;

  procedure assert_move_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    expected : natural;
    label_text : string
  ) is
    variable got : natural := 0;
  begin
    got := base_move_cycles(op_sel, src_kind);
    report "Move cycles " & label_text & " expected=" & integer'image(expected) &
      " got=" & integer'image(got) severity note;
    assert got = expected
      report "Move cycle mismatch for " & label_text severity error;
  end procedure;

  procedure assert_op_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean;
    expected : natural;
    label_text : string
  ) is
    variable got : natural := 0;
  begin
    got := op_cycle_count(
      op_sel,
      src_kind,
      ea_mode,
      cycle_case,
      mc68020_src,
      mc68020_dst,
      packed_dynamic_k
    );
    report "Op cycles " & label_text & " expected=" & integer'image(expected) &
      " got=" & integer'image(got) severity note;
    assert got = expected
      report "Op cycle mismatch for " & label_text severity error;
  end procedure;
begin
  process
  begin
    assert_base_cycles(FPU_OP_ADD, FPU_SRC_FPM, 51, "FADD FPM");
    assert_base_cycles(FPU_OP_ADD, FPU_SRC_MEM_INTEGER, 80, "FADD mem integer");
    assert_base_cycles(FPU_OP_ADD, FPU_SRC_MEM_SINGLE, 72, "FADD mem single");
    assert_base_cycles(FPU_OP_ADD, FPU_SRC_MEM_DOUBLE, 78, "FADD mem double");
    assert_base_cycles(FPU_OP_ADD, FPU_SRC_MEM_EXTENDED, 76, "FADD mem extended");
    assert_base_cycles(FPU_OP_ADD, FPU_SRC_MEM_PACKED, 888, "FADD mem packed");

    assert_base_cycles(FPU_OP_SUB, FPU_SRC_FPM, 51, "FSUB FPM");
    assert_base_cycles(FPU_OP_SUB, FPU_SRC_MEM_INTEGER, 80, "FSUB mem integer");
    assert_base_cycles(FPU_OP_SUB, FPU_SRC_MEM_SINGLE, 72, "FSUB mem single");
    assert_base_cycles(FPU_OP_SUB, FPU_SRC_MEM_DOUBLE, 78, "FSUB mem double");
    assert_base_cycles(FPU_OP_SUB, FPU_SRC_MEM_EXTENDED, 76, "FSUB mem extended");
    assert_base_cycles(FPU_OP_SUB, FPU_SRC_MEM_PACKED, 888, "FSUB mem packed");

    assert_base_cycles(FPU_OP_MUL, FPU_SRC_FPM, 71, "FMUL FPM");
    assert_base_cycles(FPU_OP_MUL, FPU_SRC_MEM_INTEGER, 100, "FMUL mem integer");
    assert_base_cycles(FPU_OP_MUL, FPU_SRC_MEM_SINGLE, 92, "FMUL mem single");
    assert_base_cycles(FPU_OP_MUL, FPU_SRC_MEM_DOUBLE, 98, "FMUL mem double");
    assert_base_cycles(FPU_OP_MUL, FPU_SRC_MEM_EXTENDED, 96, "FMUL mem extended");
    assert_base_cycles(FPU_OP_MUL, FPU_SRC_MEM_PACKED, 908, "FMUL mem packed");

    assert_base_cycles(FPU_OP_DIV, FPU_SRC_FPM, 104, "FDIV FPM");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_INTEGER, 133, "FDIV mem integer");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_SINGLE, 125, "FDIV mem single");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_DOUBLE, 131, "FDIV mem double");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_EXTENDED, 129, "FDIV mem extended");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_PACKED, 941, "FDIV mem packed");

    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_FPM, 120, "FSQRT FPM");
    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_MEM_INTEGER, 149, "FSQRT mem integer");
    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_MEM_SINGLE, 141, "FSQRT mem single");
    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_MEM_DOUBLE, 147, "FSQRT mem double");
    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_MEM_EXTENDED, 145, "FSQRT mem extended");
    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_MEM_PACKED, 960, "FSQRT mem packed");

    assert_base_cycles(FPU_OP_CMP, FPU_SRC_FPM, 49, "FCMP FPM");
    assert_base_cycles(FPU_OP_CMP, FPU_SRC_MEM_INTEGER, 78, "FCMP mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_CMP, FPU_SRC_MEM_PACKED, 886, "FCMP mem packed (.P)");

    assert_base_cycles(FPU_OP_ABS, FPU_SRC_FPM, 49, "FABS FPM");
    assert_base_cycles(FPU_OP_NEG, FPU_SRC_FPM, 49, "FNEG FPM");
    assert_base_cycles(FPU_OP_INT, FPU_SRC_FPM, 49, "FINT FPM");
    assert_base_cycles(FPU_OP_INTRZ, FPU_SRC_FPM, 49, "FINTRZ FPM");
    assert_base_cycles(FPU_OP_GETEXP, FPU_SRC_FPM, 49, "FGETEXP FPM");
    assert_base_cycles(FPU_OP_GETMAN, FPU_SRC_FPM, 49, "FGETMAN FPM");
    assert_base_cycles(FPU_OP_TST, FPU_SRC_FPM, 49, "FTST FPM");

    assert_base_cycles(FPU_OP_ABS, FPU_SRC_MEM_INTEGER, 78, "FABS mem integer");
    assert_base_cycles(FPU_OP_ABS, FPU_SRC_MEM_SINGLE, 70, "FABS mem single");
    assert_base_cycles(FPU_OP_ABS, FPU_SRC_MEM_DOUBLE, 76, "FABS mem double");
    assert_base_cycles(FPU_OP_ABS, FPU_SRC_MEM_EXTENDED, 74, "FABS mem extended");
    assert_base_cycles(FPU_OP_ABS, FPU_SRC_MEM_PACKED, 886, "FABS mem packed");

    assert_base_cycles(FPU_OP_MOD, FPU_SRC_FPM, 110, "FMOD FPM");
    assert_base_cycles(FPU_OP_MOD, FPU_SRC_MEM_INTEGER, 139, "FMOD mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_MOD, FPU_SRC_MEM_PACKED, 947, "FMOD mem packed (.P)");

    assert_base_cycles(FPU_OP_REM, FPU_SRC_FPM, 110, "FREM FPM");
    assert_base_cycles(FPU_OP_REM, FPU_SRC_MEM_INTEGER, 139, "FREM mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_REM, FPU_SRC_MEM_PACKED, 947, "FREM mem packed (.P)");

    assert_base_cycles(FPU_OP_SCALE, FPU_SRC_FPM, 55, "FSCALE FPM");
    assert_base_cycles(FPU_OP_SCALE, FPU_SRC_MEM_INTEGER, 84, "FSCALE mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_SCALE, FPU_SRC_MEM_PACKED, 892, "FSCALE mem packed (.P)");

    assert_base_cycles(FPU_OP_SGLDIV, FPU_SRC_FPM, 95, "FSGLDIV FPM");
    assert_base_cycles(FPU_OP_SGLDIV, FPU_SRC_MEM_INTEGER, 124, "FSGLDIV mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_SGLDIV, FPU_SRC_MEM_PACKED, 932, "FSGLDIV mem packed (.P)");

    assert_base_cycles(FPU_OP_SGLMUL, FPU_SRC_FPM, 63, "FSGLMUL FPM");
    assert_base_cycles(FPU_OP_SGLMUL, FPU_SRC_MEM_INTEGER, 92, "FSGLMUL mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_SGLMUL, FPU_SRC_MEM_PACKED, 900, "FSGLMUL mem packed (.P)");

    assert_total_cycles(
      FPU_OP_ADD,
      FPU_SRC_MEM_SINGLE,
      EA_MODE_ABS_L,
      EA_CYCLE_BEST,
      false,
      false,
      false,
      73,
      "FADD mem single + EA best (xxx).L"
    );
    assert_total_cycles(
      FPU_OP_ADD,
      FPU_SRC_MEM_SINGLE,
      EA_MODE_ABS_L,
      EA_CYCLE_BEST,
      true,
      true,
      false,
      66,
      "FADD mem single + EA best (xxx).L MC68020 src/dst"
    );
    assert_total_cycles(
      FPU_OP_ADD,
      FPU_SRC_MEM_PACKED,
      EA_MODE_ABS_W,
      EA_CYCLE_BEST,
      false,
      false,
      true,
      902,
      "FADD packed + dynamic K"
    );
    assert_total_cycles(
      FPU_OP_MUL,
      FPU_SRC_MEM_EXTENDED,
      EA_MODE_AN_INDIRECT,
      EA_CYCLE_CACHE,
      false,
      false,
      false,
      98,
      "FMUL mem extended + EA cache (An)"
    );
    assert_total_cycles(
      FPU_OP_MOD,
      FPU_SRC_MEM_PACKED,
      EA_MODE_ABS_L,
      EA_CYCLE_WORST,
      false,
      false,
      true,
      966,
      "FMOD packed + dynamic K + EA worst (xxx).L"
    );
    assert_total_cycles(
      FPU_OP_SQRT,
      FPU_SRC_FPM,
      EA_MODE_DN_AN,
      EA_CYCLE_BEST,
      false,
      false,
      false,
      120,
      "FSQRT FPM base cycles"
    );

    assert_move_cycles(FPU_OP_MOVE, FPU_SRC_FPM, 4, "FMOVE FPR<->FPR");
    assert_move_cycles(FPU_OP_MOVE, FPU_SRC_MEM_EXTENDED, 12, "FMOVE mem extended");
    assert_move_cycles(FPU_OP_MOVEM, FPU_SRC_FPM, 16, "FMOVEM register list");

    assert_op_cycles(
      FPU_OP_MOVE,
      FPU_SRC_MEM_DOUBLE,
      EA_MODE_ABS_W,
      EA_CYCLE_CACHE,
      false,
      false,
      false,
      12,
      "FMOVE mem double + EA cache (xxx).W"
    );

    -- Transcendental ops: trig family (alu_latency=34)
    assert_base_cycles(FPU_OP_SIN, FPU_SRC_FPM, 120, "FSIN FPM");
    assert_base_cycles(FPU_OP_SIN, FPU_SRC_MEM_INTEGER, 149, "FSIN mem integer");
    assert_base_cycles(FPU_OP_SIN, FPU_SRC_MEM_SINGLE, 141, "FSIN mem single");
    assert_base_cycles(FPU_OP_SIN, FPU_SRC_MEM_DOUBLE, 147, "FSIN mem double");
    assert_base_cycles(FPU_OP_SIN, FPU_SRC_MEM_EXTENDED, 145, "FSIN mem extended");
    assert_base_cycles(FPU_OP_SIN, FPU_SRC_MEM_PACKED, 960, "FSIN mem packed");

    assert_base_cycles(FPU_OP_COS, FPU_SRC_FPM, 120, "FCOS FPM");
    assert_base_cycles(FPU_OP_COS, FPU_SRC_MEM_INTEGER, 149, "FCOS mem integer");
    assert_base_cycles(FPU_OP_COS, FPU_SRC_MEM_PACKED, 960, "FCOS mem packed");

    assert_base_cycles(FPU_OP_TAN, FPU_SRC_FPM, 156, "FTAN FPM");
    assert_base_cycles(FPU_OP_TAN, FPU_SRC_MEM_INTEGER, 185, "FTAN mem integer");
    assert_base_cycles(FPU_OP_TAN, FPU_SRC_MEM_PACKED, 996, "FTAN mem packed");

    assert_base_cycles(FPU_OP_SINCOS, FPU_SRC_FPM, 124, "FSINCOS FPM");
    assert_base_cycles(FPU_OP_SINCOS, FPU_SRC_MEM_INTEGER, 153, "FSINCOS mem integer");
    assert_base_cycles(FPU_OP_SINCOS, FPU_SRC_MEM_PACKED, 964, "FSINCOS mem packed");

    -- Transcendental ops: general family (alu_latency=14, all share FPM=132)
    assert_base_cycles(FPU_OP_ASIN, FPU_SRC_FPM, 132, "FASIN FPM");
    assert_base_cycles(FPU_OP_ACOS, FPU_SRC_FPM, 132, "FACOS FPM");
    assert_base_cycles(FPU_OP_ATAN, FPU_SRC_FPM, 132, "FATAN FPM");
    assert_base_cycles(FPU_OP_ATANH, FPU_SRC_FPM, 132, "FATANH FPM");
    assert_base_cycles(FPU_OP_SINH, FPU_SRC_FPM, 132, "FSINH FPM");
    assert_base_cycles(FPU_OP_COSH, FPU_SRC_FPM, 132, "FCOSH FPM");
    assert_base_cycles(FPU_OP_TANH, FPU_SRC_FPM, 132, "FTANH FPM");
    assert_base_cycles(FPU_OP_ETOX, FPU_SRC_FPM, 132, "FETOX FPM");
    assert_base_cycles(FPU_OP_ETOXM1, FPU_SRC_FPM, 132, "FETOXM1 FPM");
    assert_base_cycles(FPU_OP_TWOTOX, FPU_SRC_FPM, 132, "FTWOTOX FPM");
    assert_base_cycles(FPU_OP_TENTOX, FPU_SRC_FPM, 132, "FTENTOX FPM");
    assert_base_cycles(FPU_OP_LOGN, FPU_SRC_FPM, 132, "FLOGN FPM");
    assert_base_cycles(FPU_OP_LOGNP1, FPU_SRC_FPM, 132, "FLOGNP1 FPM");
    assert_base_cycles(FPU_OP_LOG2, FPU_SRC_FPM, 132, "FLOG2 FPM");
    assert_base_cycles(FPU_OP_LOG10, FPU_SRC_FPM, 132, "FLOG10 FPM");

    -- Spot-check memory source variants for general transcendentals
    assert_base_cycles(FPU_OP_ETOX, FPU_SRC_MEM_INTEGER, 161, "FETOX mem integer");
    assert_base_cycles(FPU_OP_ETOX, FPU_SRC_MEM_SINGLE, 153, "FETOX mem single");
    assert_base_cycles(FPU_OP_ETOX, FPU_SRC_MEM_DOUBLE, 159, "FETOX mem double");
    assert_base_cycles(FPU_OP_ETOX, FPU_SRC_MEM_EXTENDED, 157, "FETOX mem extended");
    assert_base_cycles(FPU_OP_ETOX, FPU_SRC_MEM_PACKED, 972, "FETOX mem packed");

    assert_base_cycles(FPU_OP_LOGN, FPU_SRC_MEM_INTEGER, 161, "FLOGN mem integer");
    assert_base_cycles(FPU_OP_LOGN, FPU_SRC_MEM_PACKED, 972, "FLOGN mem packed");

    assert_base_cycles(FPU_OP_ATAN, FPU_SRC_MEM_INTEGER, 161, "FATAN mem integer");
    assert_base_cycles(FPU_OP_ATAN, FPU_SRC_MEM_PACKED, 972, "FATAN mem packed");

    report "Arithmetic and transcendental cycle table checks complete." severity note;
    wait;
  end process;
end architecture tb;
