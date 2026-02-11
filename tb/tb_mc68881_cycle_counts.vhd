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

    assert_base_cycles(FPU_OP_DIV, FPU_SRC_FPM, 103, "FDIV FPM");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_INTEGER, 132, "FDIV mem integer");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_SINGLE, 124, "FDIV mem single");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_DOUBLE, 130, "FDIV mem double");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_EXTENDED, 128, "FDIV mem extended");
    assert_base_cycles(FPU_OP_DIV, FPU_SRC_MEM_PACKED, 940, "FDIV mem packed");

    assert_base_cycles(FPU_OP_CMP, FPU_SRC_FPM, 49, "FCMP FPM");
    assert_base_cycles(FPU_OP_CMP, FPU_SRC_MEM_INTEGER, 78, "FCMP mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_CMP, FPU_SRC_MEM_PACKED, 886, "FCMP mem packed (.P)");

    assert_base_cycles(FPU_OP_MOD, FPU_SRC_FPM, 109, "FMOD FPM");
    assert_base_cycles(FPU_OP_MOD, FPU_SRC_MEM_INTEGER, 138, "FMOD mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_MOD, FPU_SRC_MEM_PACKED, 946, "FMOD mem packed (.P)");

    assert_base_cycles(FPU_OP_REM, FPU_SRC_FPM, 109, "FREM FPM");
    assert_base_cycles(FPU_OP_REM, FPU_SRC_MEM_INTEGER, 138, "FREM mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_REM, FPU_SRC_MEM_PACKED, 946, "FREM mem packed (.P)");

    assert_base_cycles(FPU_OP_SCALE, FPU_SRC_FPM, 55, "FSCALE FPM");
    assert_base_cycles(FPU_OP_SCALE, FPU_SRC_MEM_INTEGER, 84, "FSCALE mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_SCALE, FPU_SRC_MEM_PACKED, 892, "FSCALE mem packed (.P)");

    assert_base_cycles(FPU_OP_SGLDIV, FPU_SRC_FPM, 95, "FSGLDIV FPM");
    assert_base_cycles(FPU_OP_SGLDIV, FPU_SRC_MEM_INTEGER, 124, "FSGLDIV mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_SGLDIV, FPU_SRC_MEM_PACKED, 932, "FSGLDIV mem packed (.P)");

    assert_base_cycles(FPU_OP_SGLMUL, FPU_SRC_FPM, 63, "FSGLMUL FPM");
    assert_base_cycles(FPU_OP_SGLMUL, FPU_SRC_MEM_INTEGER, 92, "FSGLMUL mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_SGLMUL, FPU_SRC_MEM_PACKED, 900, "FSGLMUL mem packed (.P)");

    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_FPM, 120, "FSQRT FPM");
    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_MEM_INTEGER, 149, "FSQRT mem integer (B/W/L)");
    assert_base_cycles(FPU_OP_SQRT, FPU_SRC_MEM_PACKED, 957, "FSQRT mem packed (.P)");

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
      965,
      "FMOD packed + dynamic K + EA worst (xxx).L"
    );
    assert_total_cycles(
      FPU_OP_SQRT,
      FPU_SRC_MEM_SINGLE,
      EA_MODE_ABS_L,
      EA_CYCLE_BEST,
      false,
      false,
      false,
      142,
      "FSQRT mem single + EA best (xxx).L"
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

    report "Arithmetic cycle table checks complete." severity note;
    wait;
  end process;
end architecture tb;
