library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mc68881_pkg is
  constant FP_WIDTH : natural := 80;
  constant FP_EXP_WIDTH : natural := 15;
  constant FP_FRAC_WIDTH : natural := 63;
  constant FP_MANT_WIDTH : natural := 1 + FP_FRAC_WIDTH;
  constant FP_EXP_BIAS : natural := 16383;
  constant FP_BUS_WORD_WIDTH : natural := 32;
  constant FP80_RESULT_LO_WIDTH : natural := FP_BUS_WORD_WIDTH;
  constant FP80_RESULT_HI_WIDTH : natural := FP_BUS_WORD_WIDTH;
  constant FP80_RESULT_EX_WIDTH : natural := FP_WIDTH - FP80_RESULT_LO_WIDTH - FP80_RESULT_HI_WIDTH;

  subtype fp80_t is std_logic_vector(FP_WIDTH-1 downto 0);

  type fpu_op_t is (
    FPU_OP_NOP,
    FPU_OP_ADD,
    FPU_OP_SUB,
    FPU_OP_MUL,
    FPU_OP_DIV,
    FPU_OP_CMP,
    FPU_OP_MOD,
    FPU_OP_REM,
    FPU_OP_SCALE,
    FPU_OP_SGLDIV,
    FPU_OP_SGLMUL,
    FPU_OP_MOVE,
    FPU_OP_MOVEM
  );

  type fpu_op_class_t is (
    OP_CLASS_NONE,
    OP_CLASS_ARITH,
    OP_CLASS_MOVE
  );

  type fp_round_mode_t is (
    FP_RND_NEAREST,
    FP_RND_ZERO,
    FP_RND_MINUS_INF,
    FP_RND_PLUS_INF
  );

  type fp_round_prec_t is (
    FP_PREC_EXTENDED,
    FP_PREC_SINGLE,
    FP_PREC_DOUBLE,
    FP_PREC_RESERVED
  );

  type ea_cycle_case_t is (
    EA_CYCLE_BEST,
    EA_CYCLE_CACHE,
    EA_CYCLE_WORST
  );

  type ea_mode_t is (
    EA_MODE_DN_AN,
    EA_MODE_AN_INDIRECT,
    EA_MODE_AN_POSTINC,
    EA_MODE_AN_PREDEC,
    EA_MODE_D16_AN_PC,
    EA_MODE_ABS_W,
    EA_MODE_ABS_L,
    EA_MODE_IMMEDIATE,
    EA_MODE_D8_AN_PC_XN,
    EA_MODE_D16_AN_PC_XN,
    EA_MODE_B,
    EA_MODE_D16_B,
    EA_MODE_D32_B,
    EA_MODE_B_INDIRECT_I,
    EA_MODE_B_INDIRECT_I_D16,
    EA_MODE_B_INDIRECT_I_D32,
    EA_MODE_D16_B_INDIRECT_I,
    EA_MODE_D16_B_INDIRECT_I_D16,
    EA_MODE_D16_B_INDIRECT_I_D32,
    EA_MODE_D32_B_INDIRECT_I,
    EA_MODE_D32_B_INDIRECT_I_D16,
    EA_MODE_D32_B_INDIRECT_I_D32
  );

  type fpu_src_kind_t is (
    FPU_SRC_FPM,
    FPU_SRC_MEM_INTEGER,
    FPU_SRC_MEM_SINGLE,
    FPU_SRC_MEM_DOUBLE,
    FPU_SRC_MEM_EXTENDED,
    FPU_SRC_MEM_PACKED
  );

  function decode_round_mode(bits : std_logic_vector(1 downto 0)) return fp_round_mode_t;
  function decode_round_prec(bits : std_logic_vector(1 downto 0)) return fp_round_prec_t;
  function decode_op_sel(bits : std_logic_vector) return fpu_op_t;
  function op_class(op_sel : fpu_op_t) return fpu_op_class_t;
  function ea_cycles(mode : ea_mode_t; cycle_case : ea_cycle_case_t) return natural;
  function base_arith_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural;
  function base_move_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural;
  function total_arith_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural;
  function op_cycle_count(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural;

  function to_fp80(value : unsigned) return fp80_t;
  function fp80_from_int(value : integer) return fp80_t;
  function add_sub_fp80(
    a        : fp80_t;
    b        : fp80_t;
    subtract : boolean;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function mul_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function div_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function fmod_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function frem_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t;
  function fscale_fp80(a : fp80_t; b : fp80_t) return fp80_t;
  function sgldiv_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t;
  function sglmul_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t;
end package mc68881_pkg;

package body mc68881_pkg is
  constant FP_GRS_BITS : natural := 3;
  constant FP_MANT_EXT_WIDTH : natural := FP_MANT_WIDTH + FP_GRS_BITS;
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');
  constant FP_EXP_MAX : integer := (2**FP_EXP_WIDTH) - 1;
  type op_decode_table_t is array (0 to 15) of fpu_op_t;
  constant OP_DECODE_TABLE : op_decode_table_t := (
    0 => FPU_OP_NOP,
    1 => FPU_OP_ADD,
    2 => FPU_OP_SUB,
    3 => FPU_OP_MUL,
    4 => FPU_OP_DIV,
    5 => FPU_OP_MOVE,
    6 => FPU_OP_MOVEM,
    7 => FPU_OP_CMP,
    8 => FPU_OP_MOD,
    9 => FPU_OP_REM,
    10 => FPU_OP_SCALE,
    11 => FPU_OP_SGLDIV,
    12 => FPU_OP_SGLMUL,
    others => FPU_OP_NOP
  );

  type fp_unpacked_t is record
    sign : std_logic;
    exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  end record;

  function decode_round_mode(bits : std_logic_vector(1 downto 0)) return fp_round_mode_t is
  begin
    case bits is
      when "00" => return FP_RND_NEAREST;
      when "01" => return FP_RND_ZERO;
      when "10" => return FP_RND_MINUS_INF;
      when others => return FP_RND_PLUS_INF;
    end case;
  end function;

  function decode_round_prec(bits : std_logic_vector(1 downto 0)) return fp_round_prec_t is
  begin
    case bits is
      when "00" => return FP_PREC_EXTENDED;
      when "01" => return FP_PREC_SINGLE;
      when "10" => return FP_PREC_DOUBLE;
      when others => return FP_PREC_RESERVED;
    end case;
  end function;

  function decode_op_sel(bits : std_logic_vector) return fpu_op_t is
    variable idx : natural := 0;
  begin
    if bits'length = 0 or is_x(bits) then
      return FPU_OP_NOP;
    end if;

    idx := to_integer(unsigned(bits));

    if bits'length = 3 then
      -- Legacy 3-bit decode kept for existing tests.
      case idx is
        when 1 => return FPU_OP_ADD;
        when 2 => return FPU_OP_SUB;
        when 3 => return FPU_OP_MUL;
        when 4 => return FPU_OP_DIV;
        when 5 => return FPU_OP_MOVE;
        when 6 => return FPU_OP_MOVEM;
        when others => return FPU_OP_NOP;
      end case;
    end if;

    if idx <= OP_DECODE_TABLE'high then
      return OP_DECODE_TABLE(idx);
    end if;
    return FPU_OP_NOP;
  end function;

  function op_class(op_sel : fpu_op_t) return fpu_op_class_t is
  begin
    case op_sel is
      when FPU_OP_ADD | FPU_OP_SUB | FPU_OP_MUL | FPU_OP_DIV |
           FPU_OP_CMP | FPU_OP_MOD | FPU_OP_REM | FPU_OP_SCALE |
           FPU_OP_SGLDIV | FPU_OP_SGLMUL =>
        return OP_CLASS_ARITH;
      when FPU_OP_MOVE | FPU_OP_MOVEM =>
        return OP_CLASS_MOVE;
      when others =>
        return OP_CLASS_NONE;
    end case;
  end function;

  function ea_cycles(mode : ea_mode_t; cycle_case : ea_cycle_case_t) return natural is
    function pick(best_case : natural; cache_case : natural; worst_case : natural) return natural is
    begin
      case cycle_case is
        when EA_CYCLE_BEST => return best_case;
        when EA_CYCLE_CACHE => return cache_case;
        when others => return worst_case;
      end case;
    end function;
  begin
    case mode is
      when EA_MODE_DN_AN => return pick(0, 0, 0);
      when EA_MODE_AN_INDIRECT => return pick(0, 2, 2);
      when EA_MODE_AN_POSTINC => return pick(3, 6, 6);
      when EA_MODE_AN_PREDEC => return pick(3, 6, 6);
      when EA_MODE_D16_AN_PC => return pick(0, 2, 3);
      when EA_MODE_ABS_W => return pick(0, 2, 3);
      when EA_MODE_ABS_L => return pick(1, 4, 5);
      when EA_MODE_IMMEDIATE => return pick(0, 0, 0);
      when EA_MODE_D8_AN_PC_XN => return pick(1, 4, 5);
      when EA_MODE_D16_AN_PC_XN => return pick(3, 6, 7);
      when EA_MODE_B => return pick(3, 6, 7);
      when EA_MODE_D16_B => return pick(5, 8, 9);
      when EA_MODE_D32_B => return pick(11, 14, 16);
      when EA_MODE_B_INDIRECT_I => return pick(8, 11, 12);
      when EA_MODE_B_INDIRECT_I_D16 => return pick(8, 11, 12);
      when EA_MODE_B_INDIRECT_I_D32 => return pick(10, 13, 15);
      when EA_MODE_D16_B_INDIRECT_I => return pick(10, 13, 14);
      when EA_MODE_D16_B_INDIRECT_I_D16 => return pick(10, 13, 15);
      when EA_MODE_D16_B_INDIRECT_I_D32 => return pick(12, 15, 17);
      when EA_MODE_D32_B_INDIRECT_I => return pick(16, 19, 21);
      when EA_MODE_D32_B_INDIRECT_I_D16 => return pick(16, 19, 21);
      when EA_MODE_D32_B_INDIRECT_I_D32 => return pick(18, 21, 24);
    end case;
  end function;

  function base_arith_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural is
    variable fpm_cycles : natural := 0;
    variable mem_int_cycles : natural := 0;
    variable mem_single_cycles : natural := 0;
    variable mem_double_cycles : natural := 0;
    variable mem_ext_cycles : natural := 0;
    variable mem_packed_cycles : natural := 0;
  begin
    case op_sel is
      when FPU_OP_ADD =>
        fpm_cycles := 51;
        mem_int_cycles := 80;
        mem_single_cycles := 72;
        mem_double_cycles := 78;
        mem_ext_cycles := 76;
        mem_packed_cycles := 888;
      when FPU_OP_SUB =>
        fpm_cycles := 51;
        mem_int_cycles := 80;
        mem_single_cycles := 72;
        mem_double_cycles := 78;
        mem_ext_cycles := 76;
        mem_packed_cycles := 888;
      when FPU_OP_MUL =>
        fpm_cycles := 71;
        mem_int_cycles := 100;
        mem_single_cycles := 92;
        mem_double_cycles := 98;
        mem_ext_cycles := 96;
        mem_packed_cycles := 908;
      when FPU_OP_DIV =>
        fpm_cycles := 103;
        mem_int_cycles := 132;
        mem_single_cycles := 124;
        mem_double_cycles := 130;
        mem_ext_cycles := 128;
        mem_packed_cycles := 940;
      when FPU_OP_CMP =>
        fpm_cycles := 49;
        mem_int_cycles := 78;
        mem_single_cycles := 70;
        mem_double_cycles := 76;
        mem_ext_cycles := 74;
        mem_packed_cycles := 886;
      when FPU_OP_MOD =>
        fpm_cycles := 109;
        mem_int_cycles := 138;
        mem_single_cycles := 130;
        mem_double_cycles := 136;
        mem_ext_cycles := 134;
        mem_packed_cycles := 946;
      when FPU_OP_REM =>
        fpm_cycles := 109;
        mem_int_cycles := 138;
        mem_single_cycles := 130;
        mem_double_cycles := 136;
        mem_ext_cycles := 134;
        mem_packed_cycles := 946;
      when FPU_OP_SCALE =>
        fpm_cycles := 55;
        mem_int_cycles := 84;
        mem_single_cycles := 76;
        mem_double_cycles := 82;
        mem_ext_cycles := 80;
        mem_packed_cycles := 892;
      when FPU_OP_SGLDIV =>
        fpm_cycles := 95;
        mem_int_cycles := 124;
        mem_single_cycles := 116;
        mem_double_cycles := 122;
        mem_ext_cycles := 120;
        mem_packed_cycles := 932;
      when FPU_OP_SGLMUL =>
        fpm_cycles := 63;
        mem_int_cycles := 92;
        mem_single_cycles := 84;
        mem_double_cycles := 90;
        mem_ext_cycles := 88;
        mem_packed_cycles := 900;
      when others =>
        return 0;
    end case;

    case src_kind is
      when FPU_SRC_FPM => return fpm_cycles;
      when FPU_SRC_MEM_INTEGER => return mem_int_cycles;
      when FPU_SRC_MEM_SINGLE => return mem_single_cycles;
      when FPU_SRC_MEM_DOUBLE => return mem_double_cycles;
      when FPU_SRC_MEM_EXTENDED => return mem_ext_cycles;
      when FPU_SRC_MEM_PACKED => return mem_packed_cycles;
    end case;
  end function;

  function base_move_cycles(op_sel : fpu_op_t; src_kind : fpu_src_kind_t) return natural is
  begin
    case op_sel is
      when FPU_OP_MOVE =>
        case src_kind is
          when FPU_SRC_FPM => return 4;
          when FPU_SRC_MEM_SINGLE => return 8;
          when FPU_SRC_MEM_DOUBLE => return 10;
          when FPU_SRC_MEM_EXTENDED => return 12;
          when others => return 10;
        end case;
      when FPU_OP_MOVEM =>
        case src_kind is
          when FPU_SRC_FPM => return 16;
          when FPU_SRC_MEM_SINGLE => return 20;
          when FPU_SRC_MEM_DOUBLE => return 22;
          when FPU_SRC_MEM_EXTENDED => return 24;
          when others => return 20;
        end case;
      when others =>
        return 0;
    end case;
  end function;

  function total_arith_cycles(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural is
    variable total_cycles : integer := 0;
    variable ea_add : natural := 0;
    variable k_add : natural := 0;
  begin
    ea_add := ea_cycles(ea_mode, cycle_case);
    total_cycles := integer(base_arith_cycles(op_sel, src_kind)) + integer(ea_add);

    if mc68020_src then
      total_cycles := total_cycles - 5;
    end if;

    if mc68020_dst then
      total_cycles := total_cycles - 2;
    end if;

    if packed_dynamic_k and src_kind = FPU_SRC_MEM_PACKED then
      k_add := 14;
      total_cycles := total_cycles + integer(k_add);
    end if;

    if total_cycles < 0 then
      total_cycles := 0;
    end if;
    return natural(total_cycles);
  end function;

  function op_cycle_count(
    op_sel : fpu_op_t;
    src_kind : fpu_src_kind_t;
    ea_mode : ea_mode_t;
    cycle_case : ea_cycle_case_t;
    mc68020_src : boolean;
    mc68020_dst : boolean;
    packed_dynamic_k : boolean
  ) return natural is
  begin
    case op_class(op_sel) is
      when OP_CLASS_ARITH =>
        return total_arith_cycles(
          op_sel,
          src_kind,
          ea_mode,
          cycle_case,
          mc68020_src,
          mc68020_dst,
          packed_dynamic_k
        );
      when OP_CLASS_MOVE =>
        return base_move_cycles(op_sel, src_kind) + ea_cycles(ea_mode, cycle_case);
      when others =>
        return 0;
    end case;
  end function;

  function prec_bits(prec : fp_round_prec_t) return natural is
  begin
    case prec is
      when FP_PREC_SINGLE => return 24;
      when FP_PREC_DOUBLE => return 53;
      when others => return FP_MANT_WIDTH;
    end case;
  end function;

  function shift_right_with_sticky(
    value : unsigned;
    shift : natural
  ) return unsigned;

  procedure apply_rounding(
    sign       : in  std_logic;
    mant_ext   : in  unsigned(FP_MANT_EXT_WIDTH-1 downto 0);
    exp_in     : in  integer;
    round_mode : in  fp_round_mode_t;
    round_prec : in  fp_round_prec_t;
    mant_out   : out unsigned(FP_MANT_WIDTH-1 downto 0);
    exp_out    : out integer
  ) is
    -- Keep intermediate exponent state in a local variable: Vivado/VRFC does
    -- not allow reading from an `out` parameter inside the subprogram body.
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable mant_round : unsigned(FP_MANT_WIDTH downto 0) := (others => '0');
    variable guard      : std_logic := '0';
    variable round_bit  : std_logic := '0';
    variable sticky     : std_logic := '0';
    variable increment  : std_logic := '0';
    variable any_disc   : std_logic := '0';
    variable prec_w     : natural := FP_MANT_WIDTH;
    variable drop_bits  : natural := 0;
    variable lsb_keep   : integer := FP_GRS_BITS;
    variable exp_var    : integer := 0;
  begin
    mant_main := mant_ext(FP_MANT_EXT_WIDTH-1 downto FP_GRS_BITS);
    prec_w := prec_bits(round_prec);
    drop_bits := FP_MANT_WIDTH - prec_w;
    lsb_keep := FP_GRS_BITS + drop_bits;


    guard := mant_ext(lsb_keep-1);
    round_bit := mant_ext(lsb_keep-2);
    if lsb_keep > 2 then
      if mant_ext(lsb_keep-3 downto 0) /= 0 then
        sticky := '1';
      end if;
    end if;

    any_disc := guard or round_bit or sticky;
    case round_mode is
      when FP_RND_NEAREST =>
        if guard = '1' and (round_bit = '1' or sticky = '1' or mant_main(drop_bits) = '1') then
          increment := '1';
        end if;
      when FP_RND_ZERO =>
        increment := '0';
      when FP_RND_MINUS_INF =>
        if sign = '1' and any_disc = '1' then
          increment := '1';
        end if;
      when FP_RND_PLUS_INF =>
        if sign = '0' and any_disc = '1' then
          increment := '1';
        end if;
    end case;

    exp_var := exp_in;
    if increment = '1' then
      mant_round := ('0' & mant_main) + (to_unsigned(1, FP_MANT_WIDTH+1) sll drop_bits);
      if mant_round(mant_round'left) = '1' then
        mant_main := shift_right_with_sticky(mant_round(mant_round'left-1 downto 0), 1);
        exp_var := exp_var + 1;
      else
        mant_main := mant_round(mant_round'left-1 downto 0);
      end if;
    end if;

    if drop_bits > 0 then
      mant_main(drop_bits-1 downto 0) := (others => '0');
    end if;

    mant_out := mant_main;
    exp_out := exp_var;
  end procedure;

  function unpack_fp80(value : fp80_t) return fp_unpacked_t is
    variable result : fp_unpacked_t;
  begin
    result.sign := value(FP_WIDTH-1);
    result.exp  := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    result.mant := unsigned(value(FP_MANT_WIDTH-1 downto 0));
    return result;
  end function;

  function pack_fp80(value : fp_unpacked_t) return fp80_t is
    variable result : fp80_t := (others => '0');
  begin
    result(FP_WIDTH-1) := value.sign;
    result(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(value.exp);
    result(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(value.mant);
    return result;
  end function;

  function shift_right_with_sticky(
    value : unsigned;
    shift : natural
  ) return unsigned is
    variable result : unsigned(value'length-1 downto 0) := (others => '0');
    variable sticky : std_logic := '0';
  begin
    if shift = 0 then
      return value;
    end if;

    if shift >= value'length then
      if value /= 0 then
        sticky := '1';
      end if;
      result(0) := sticky;
      return result;
    end if;

    if value(shift-1 downto 0) /= 0 then
      sticky := '1';
    end if;

    result := shift_right(value, shift);
    if sticky = '1' then
      result(0) := '1';
    end if;
    return result;
  end function;

  procedure normalize_left(
    value   : in  unsigned;
    exp_in  : in  unsigned;
    value_o : out unsigned;
    exp_o   : out unsigned
  ) is
    variable result : unsigned(value'range) := value;
    variable exp_var : unsigned(exp_in'range) := exp_in;
  begin
    while result(result'left) = '0' and exp_var /= 0 and result /= 0 loop
      result := result(result'left-1 downto 0) & '0';
      exp_var := exp_var - 1;
    end loop;
    value_o := result;
    exp_o := exp_var;
  end procedure;

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

  function fp80_from_int(value : integer) return fp80_t is
    variable result : fp80_t := (others => '0');
    variable abs_val : natural := 0;
    variable sign    : std_logic := '0';
    variable exp     : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable mant    : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable msb_pos : integer := 0;
    variable tmp     : natural := 0;
  begin
    if value = 0 then
      return result;
    end if;

    if value < 0 then
      sign := '1';
      abs_val := natural(-value);
    else
      abs_val := natural(value);
    end if;

    tmp := abs_val;
    msb_pos := 0;
    while tmp > 1 loop
      tmp := tmp / 2;
      msb_pos := msb_pos + 1;
    end loop;

    exp := to_unsigned(FP_EXP_BIAS + msb_pos, FP_EXP_WIDTH);
    mant := resize(to_unsigned(abs_val, FP_MANT_WIDTH), FP_MANT_WIDTH) sll (FP_MANT_WIDTH-1-msb_pos);

    result(FP_WIDTH-1) := sign;
    result(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := std_logic_vector(exp);
    result(FP_MANT_WIDTH-1 downto 0) := std_logic_vector(mant);
    return result;
  end function;

  function add_sub_fp80(
    a        : fp80_t;
    b        : fp80_t;
    subtract : boolean;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable res_u : fp_unpacked_t;
    variable mant_a_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_b_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_sum   : unsigned(FP_MANT_EXT_WIDTH downto 0) := (others => '0');
    variable mant_main  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable mant_ext   : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable exp_diff   : natural := 0;
    variable exp_res    : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable exp_res_i  : integer := 0;
    variable sign_b     : std_logic := '0';
  begin
    res_u.sign := '0';
    res_u.exp  := (others => '0');
    res_u.mant := (others => '0');

    if a_u.exp = 0 and a_u.mant = 0 then
      if subtract then
        b_u.sign := not b_u.sign;
      end if;
      return pack_fp80(b_u);
    end if;

    if b_u.exp = 0 and b_u.mant = 0 then
      return pack_fp80(a_u);
    end if;

    sign_b := b_u.sign;
    if subtract then
      sign_b := not sign_b;
    end if;

    mant_a_ext := a_u.mant & (FP_GRS_BITS-1 downto 0 => '0');
    mant_b_ext := b_u.mant & (FP_GRS_BITS-1 downto 0 => '0');

    if a_u.exp > b_u.exp then
      exp_diff := to_integer(a_u.exp - b_u.exp);
      mant_b_ext := shift_right_with_sticky(mant_b_ext, exp_diff);
      exp_res := a_u.exp;
    elsif b_u.exp > a_u.exp then
      exp_diff := to_integer(b_u.exp - a_u.exp);
      mant_a_ext := shift_right_with_sticky(mant_a_ext, exp_diff);
      exp_res := b_u.exp;
    else
      exp_res := a_u.exp;
    end if;

    if a_u.sign = sign_b then
      mant_sum := ('0' & mant_a_ext) + ('0' & mant_b_ext);
      res_u.sign := a_u.sign;

      if mant_sum(mant_sum'left) = '1' then
        mant_sum(mant_sum'left-1 downto 0) := shift_right_with_sticky(mant_sum(mant_sum'left-1 downto 0), 1);
        mant_sum(mant_sum'left) := '0';
        if exp_res /= FP_EXP_ALL_ONES then
          exp_res := exp_res + 1;
        end if;
      end if;
    else
      if mant_a_ext >= mant_b_ext then
        mant_sum := ('0' & mant_a_ext) - ('0' & mant_b_ext);
        res_u.sign := a_u.sign;
      else
        mant_sum := ('0' & mant_b_ext) - ('0' & mant_a_ext);
        res_u.sign := sign_b;
      end if;

      normalize_left(
        mant_sum(mant_sum'left-1 downto 0),
        exp_res,
        mant_sum(mant_sum'left-1 downto 0),
        exp_res
      );
    end if;

    mant_ext := mant_sum(mant_sum'left-1 downto 0);
    exp_res_i := to_integer(exp_res);
    apply_rounding(res_u.sign, mant_ext, exp_res_i, round_mode, round_prec, mant_main, exp_res_i);

    if mant_main = 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i >= FP_EXP_MAX then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i <= 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res := to_unsigned(exp_res_i, FP_EXP_WIDTH);
    res_u.exp := exp_res;
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;

  function mul_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable res_u : fp_unpacked_t;
    variable mant_prod : unsigned((FP_MANT_WIDTH*2)-1 downto 0) := (others => '0');
    variable mant_ext  : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_res_i : integer := 0;
    variable exp_res   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable low_or : std_logic := '0';
  begin
    res_u.sign := a_u.sign xor b_u.sign;
    res_u.exp  := (others => '0');
    res_u.mant := (others => '0');

    if (a_u.exp = 0 and a_u.mant = 0) or (b_u.exp = 0 and b_u.mant = 0) then
      res_u.sign := '0';
      return pack_fp80(res_u);
    end if;

    if a_u.exp = FP_EXP_ALL_ONES or b_u.exp = FP_EXP_ALL_ONES then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res_i := to_integer(a_u.exp) + to_integer(b_u.exp) - FP_EXP_BIAS;
    mant_prod := a_u.mant * b_u.mant;

    if mant_prod(mant_prod'left) = '1' then
      exp_res_i := exp_res_i + 1;
    end if;

    mant_ext := mant_prod(mant_prod'left-1 downto mant_prod'left-1-(FP_MANT_EXT_WIDTH-1));
    if (mant_prod'left-1-(FP_MANT_EXT_WIDTH) >= 0) then
      for idx in 0 to mant_prod'left-1-FP_MANT_EXT_WIDTH loop
        if mant_prod(idx) = '1' then
          low_or := '1';
        end if;
      end loop;
    end if;

    if low_or = '1' then
      mant_ext(0) := mant_ext(0) or low_or;
    end if;

    apply_rounding(res_u.sign, mant_ext, exp_res_i, round_mode, round_prec, mant_main, exp_res_i);

    if exp_res_i <= 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i >= FP_EXP_MAX then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res := to_unsigned(exp_res_i, FP_EXP_WIDTH);
    res_u.exp := exp_res;
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;

  function div_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable res_u : fp_unpacked_t;
    variable num : unsigned((FP_MANT_WIDTH*2)+FP_GRS_BITS-1 downto 0) := (others => '0');
    variable quot : unsigned((FP_MANT_WIDTH*2)+FP_GRS_BITS-1 downto 0) := (others => '0');
    variable rem_val  : unsigned((FP_MANT_WIDTH*2)+FP_GRS_BITS-1 downto 0) := (others => '0');
    variable mant_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_main : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_res_i : integer := 0;
    variable exp_res   : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable shift     : integer := 0;
    variable low_or : std_logic := '0';
    variable top_index : integer := FP_MANT_WIDTH + FP_GRS_BITS;
  begin
    res_u.sign := a_u.sign xor b_u.sign;
    res_u.exp  := (others => '0');
    res_u.mant := (others => '0');

    if b_u.exp = 0 and b_u.mant = 0 then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if a_u.exp = 0 and a_u.mant = 0 then
      res_u.sign := '0';
      return pack_fp80(res_u);
    end if;

    if a_u.exp = FP_EXP_ALL_ONES or b_u.exp = FP_EXP_ALL_ONES then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res_i := to_integer(a_u.exp) - to_integer(b_u.exp) + FP_EXP_BIAS;

    num := a_u.mant & (FP_MANT_WIDTH+FP_GRS_BITS-1 downto 0 => '0');
    quot := num / b_u.mant;
    rem_val  := num mod resize(b_u.mant, num'length);

    if quot(top_index+1) = '1' then
      shift := 1;
      exp_res_i := exp_res_i + 1;
    elsif quot(top_index) = '0' then
      shift := -1;
      exp_res_i := exp_res_i - 1;
    else
      shift := 0;
    end if;

    if shift = 1 then
      mant_ext := quot(top_index+1 downto top_index+1-(FP_MANT_EXT_WIDTH-1));
      if top_index+1-FP_MANT_EXT_WIDTH >= 0 then
        for idx in 0 to top_index+1-FP_MANT_EXT_WIDTH loop
          if quot(idx) = '1' then
            low_or := '1';
          end if;
        end loop;
      end if;
    elsif shift = -1 then
      mant_ext := quot(top_index-1 downto top_index-1-(FP_MANT_EXT_WIDTH-1));
      if top_index-1-FP_MANT_EXT_WIDTH >= 0 then
        for idx in 0 to top_index-1-FP_MANT_EXT_WIDTH loop
          if quot(idx) = '1' then
            low_or := '1';
          end if;
        end loop;
      end if;
    else
      mant_ext := quot(top_index downto top_index-(FP_MANT_EXT_WIDTH-1));
      if top_index-FP_MANT_EXT_WIDTH >= 0 then
        for idx in 0 to top_index-FP_MANT_EXT_WIDTH loop
          if quot(idx) = '1' then
            low_or := '1';
          end if;
        end loop;
      end if;
    end if;

    if rem_val /= 0 then
      low_or := '1';
    end if;

    if low_or = '1' then
      mant_ext(0) := mant_ext(0) or low_or;
    end if;

    apply_rounding(res_u.sign, mant_ext, exp_res_i, round_mode, round_prec, mant_main, exp_res_i);

    if exp_res_i <= 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res_i >= FP_EXP_MAX then
      res_u.exp := FP_EXP_ALL_ONES;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    exp_res := to_unsigned(exp_res_i, FP_EXP_WIDTH);
    res_u.exp := exp_res;
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;

  function abs_fp80(value : fp80_t) return fp80_t is
    variable result : fp80_t := value;
  begin
    result(FP_WIDTH-1) := '0';
    return result;
  end function;

  function compare_magnitude(a : fp80_t; b : fp80_t) return integer is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
  begin
    if a_u.exp > b_u.exp then
      return 1;
    elsif a_u.exp < b_u.exp then
      return -1;
    elsif a_u.mant > b_u.mant then
      return 1;
    elsif a_u.mant < b_u.mant then
      return -1;
    else
      return 0;
    end if;
  end function;

  function compare_fp80(a : fp80_t; b : fp80_t) return integer is
    variable cmp_mag : integer := 0;
    variable a_abs : fp80_t := abs_fp80(a);
    variable b_abs : fp80_t := abs_fp80(b);
  begin
    if a_abs = (a_abs'range => '0') and b_abs = (b_abs'range => '0') then
      return 0;
    end if;

    if a(FP_WIDTH-1) /= b(FP_WIDTH-1) then
      if a(FP_WIDTH-1) = '1' then
        return -1;
      end if;
      return 1;
    end if;

    cmp_mag := compare_magnitude(a_abs, b_abs);
    if a(FP_WIDTH-1) = '1' then
      return -cmp_mag;
    end if;
    return cmp_mag;
  end function;

  function fp80_to_int_trunc(value : fp80_t) return integer is
    variable value_u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable shift : integer := 0;
    variable magnitude_u : unsigned(63 downto 0) := (others => '0');
    constant INT_HIGH_U64 : unsigned(63 downto 0) := to_unsigned(integer'high, 64);
    variable abs_int : integer := 0;
  begin
    if value_u.exp = 0 or value_u.exp = FP_EXP_ALL_ONES then
      return 0;
    end if;

    exp_i := to_integer(value_u.exp);
    shift := exp_i - FP_EXP_BIAS;
    if shift < 0 then
      return 0;
    end if;

    if shift > 30 then
      if value_u.sign = '1' then
        return integer'low;
      end if;
      return integer'high;
    end if;

    magnitude_u := resize(shift_right(value_u.mant, FP_MANT_WIDTH-1-shift), 64);
    if magnitude_u > INT_HIGH_U64 then
      if value_u.sign = '1' then
        return integer'low;
      end if;
      return integer'high;
    end if;

    abs_int := to_integer(magnitude_u);
    if value_u.sign = '1' then
      return -abs_int;
    end if;
    return abs_int;
  end function;

  function fp80_trunc_toward_zero(value : fp80_t) return fp80_t is
    variable value_u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable frac_bits : integer := 0;
    variable result_u : fp_unpacked_t := value_u;
  begin
    if value_u.exp = 0 or value_u.exp = FP_EXP_ALL_ONES then
      return value;
    end if;

    exp_i := to_integer(value_u.exp) - FP_EXP_BIAS;
    if exp_i < 0 then
      result_u.exp := (others => '0');
      result_u.mant := (others => '0');
      return pack_fp80(result_u);
    end if;

    if exp_i >= integer(FP_MANT_WIDTH - 1) then
      return value;
    end if;

    frac_bits := integer(FP_MANT_WIDTH - 1) - exp_i;
    result_u.mant(frac_bits-1 downto 0) := (others => '0');
    return pack_fp80(result_u);
  end function;

  function fp80_is_odd_integer(value : fp80_t) return boolean is
    variable value_u : fp_unpacked_t := unpack_fp80(value);
    variable exp_i : integer := 0;
    variable lsb_idx : integer := 0;
  begin
    if value_u.exp = 0 or value_u.exp = FP_EXP_ALL_ONES then
      return false;
    end if;

    exp_i := to_integer(value_u.exp) - FP_EXP_BIAS;
    if exp_i < 0 then
      return false;
    end if;

    if exp_i > integer(FP_MANT_WIDTH - 1) then
      -- ULP > 1, all representable integers at this magnitude are even.
      return false;
    end if;

    lsb_idx := integer(FP_MANT_WIDTH - 1) - exp_i;
    return value_u.mant(lsb_idx) = '1';
  end function;

  function fmod_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable quotient : fp80_t := (others => '0');
    variable quotient_u : fp_unpacked_t;
    variable quotient_trunc : fp80_t := (others => '0');
    variable quotient_i : integer := 0;
    variable product : fp80_t := (others => '0');
    variable result : fp80_t := (others => '0');
    variable nan_result : fp_unpacked_t;
  begin
    if b_u.exp = 0 and b_u.mant = 0 then
      nan_result.sign := '0';
      nan_result.exp := FP_EXP_ALL_ONES;
      nan_result.mant := (others => '0');
      nan_result.mant(FP_MANT_WIDTH-1) := '1';
      return pack_fp80(nan_result);
    end if;

    quotient := div_fp80(a, b, FP_RND_ZERO, FP_PREC_EXTENDED);
    quotient_u := unpack_fp80(quotient);
    if quotient_u.exp /= 0 and quotient_u.exp /= FP_EXP_ALL_ONES and
       (to_integer(quotient_u.exp) - FP_EXP_BIAS) <= 30 then
      quotient_i := fp80_to_int_trunc(quotient);
      quotient_trunc := fp80_from_int(quotient_i);
    else
      quotient_trunc := fp80_trunc_toward_zero(quotient);
    end if;
    product := mul_fp80(b, quotient_trunc, FP_RND_NEAREST, FP_PREC_EXTENDED);
    result := add_sub_fp80(a, product, true, round_mode, round_prec);
    return result;
  end function;

  function frem_fp80(
    a : fp80_t;
    b : fp80_t;
    round_mode : fp_round_mode_t;
    round_prec : fp_round_prec_t
  ) return fp80_t is
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable quotient : fp80_t := (others => '0');
    variable quotient_u : fp_unpacked_t;
    variable quotient_trunc : fp80_t := (others => '0');
    variable nearest_q : fp80_t := (others => '0');
    variable quotient_i : integer := 0;
    variable nearest_i : integer := 0;
    variable step_i : integer := 0;
    variable use_integer_path : boolean := false;
    variable frac : fp80_t := (others => '0');
    variable frac_abs : fp80_t := (others => '0');
    variable half_fp : fp80_t := x"3FFE8000000000000000";
    variable one_fp : fp80_t := x"3FFF8000000000000000";
    variable half_cmp : integer := 0;
    variable product : fp80_t := (others => '0');
    variable result : fp80_t := (others => '0');
    variable nan_result : fp_unpacked_t;
  begin
    if b_u.exp = 0 and b_u.mant = 0 then
      nan_result.sign := '0';
      nan_result.exp := FP_EXP_ALL_ONES;
      nan_result.mant := (others => '0');
      nan_result.mant(FP_MANT_WIDTH-1) := '1';
      return pack_fp80(nan_result);
    end if;

    quotient := div_fp80(a, b, FP_RND_NEAREST, FP_PREC_EXTENDED);
    quotient_u := unpack_fp80(quotient);
    use_integer_path := quotient_u.exp /= 0 and quotient_u.exp /= FP_EXP_ALL_ONES and
      (to_integer(quotient_u.exp) - FP_EXP_BIAS) <= 30;

    if use_integer_path then
      quotient_i := fp80_to_int_trunc(quotient);
      nearest_i := quotient_i;
      quotient_trunc := fp80_from_int(quotient_i);
      frac := add_sub_fp80(quotient, quotient_trunc, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
      frac_abs := abs_fp80(frac);
      half_cmp := compare_fp80(frac_abs, half_fp);
      if quotient(FP_WIDTH-1) = '1' then
        step_i := -1;
      else
        step_i := 1;
      end if;
      if half_cmp > 0 then
        if not ((step_i > 0 and nearest_i = integer'high) or
                (step_i < 0 and nearest_i = integer'low)) then
          nearest_i := nearest_i + step_i;
        end if;
      elsif half_cmp = 0 and (quotient_i rem 2) /= 0 then
        if not ((step_i > 0 and nearest_i = integer'high) or
                (step_i < 0 and nearest_i = integer'low)) then
          nearest_i := nearest_i + step_i;
        end if;
      end if;
      nearest_q := fp80_from_int(nearest_i);
    else
      quotient_trunc := fp80_trunc_toward_zero(quotient);
      nearest_q := quotient_trunc;
      frac := add_sub_fp80(quotient, quotient_trunc, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
      frac_abs := abs_fp80(frac);
      half_cmp := compare_fp80(frac_abs, half_fp);
      if half_cmp > 0 then
        if quotient(FP_WIDTH-1) = '1' then
          nearest_q := add_sub_fp80(nearest_q, one_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
        else
          nearest_q := add_sub_fp80(nearest_q, one_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
        end if;
      elsif half_cmp = 0 and fp80_is_odd_integer(quotient_trunc) then
        if quotient(FP_WIDTH-1) = '1' then
          nearest_q := add_sub_fp80(nearest_q, one_fp, true, FP_RND_NEAREST, FP_PREC_EXTENDED);
        else
          nearest_q := add_sub_fp80(nearest_q, one_fp, false, FP_RND_NEAREST, FP_PREC_EXTENDED);
        end if;
      end if;
    end if;

    product := mul_fp80(b, nearest_q, FP_RND_NEAREST, FP_PREC_EXTENDED);
    result := add_sub_fp80(a, product, true, round_mode, round_prec);
    return result;
  end function;

  function fscale_fp80(a : fp80_t; b : fp80_t) return fp80_t is
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable scale_i : integer := fp80_to_int_trunc(a);
    variable exp_i : integer := 0;
    variable result_u : fp_unpacked_t := b_u;
  begin
    if b_u.exp = 0 or b_u.exp = FP_EXP_ALL_ONES then
      return b;
    end if;

    exp_i := to_integer(b_u.exp) + scale_i;
    if exp_i <= 0 then
      result_u.exp := (others => '0');
      result_u.mant := (others => '0');
      return pack_fp80(result_u);
    end if;

    if exp_i >= FP_EXP_MAX then
      result_u.exp := FP_EXP_ALL_ONES;
      result_u.mant := (others => '0');
      return pack_fp80(result_u);
    end if;

    result_u.exp := to_unsigned(exp_i, FP_EXP_WIDTH);
    return pack_fp80(result_u);
  end function;

  function sgldiv_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t is
  begin
    return div_fp80(a, b, round_mode, FP_PREC_SINGLE);
  end function;

  function sglmul_fp80(a : fp80_t; b : fp80_t; round_mode : fp_round_mode_t) return fp80_t is
  begin
    return mul_fp80(a, b, round_mode, FP_PREC_SINGLE);
  end function;
end package body mc68881_pkg;
