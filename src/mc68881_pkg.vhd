library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mc68881_pkg is
  constant FP_WIDTH : natural := 80;
  constant FP_EXP_WIDTH : natural := 15;
  constant FP_FRAC_WIDTH : natural := 63;
  constant FP_MANT_WIDTH : natural := 1 + FP_FRAC_WIDTH;
  constant FP_EXP_BIAS : natural := 16383;

  subtype fp80_t is std_logic_vector(FP_WIDTH-1 downto 0);

  type fpu_op_t is (
    FPU_OP_NOP,
    FPU_OP_ADD,
    FPU_OP_SUB,
    FPU_OP_MUL,
    FPU_OP_DIV
  );

  function to_fp80(value : unsigned) return fp80_t;
  function fp80_from_int(value : integer) return fp80_t;
  function add_sub_fp80(
    a        : fp80_t;
    b        : fp80_t;
    subtract : boolean
  ) return fp80_t;
end package mc68881_pkg;

package body mc68881_pkg is
  constant FP_GRS_BITS : natural := 3;
  constant FP_MANT_EXT_WIDTH : natural := FP_MANT_WIDTH + FP_GRS_BITS;
  constant FP_EXP_ALL_ONES : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '1');

  type fp_unpacked_t is record
    sign : std_logic;
    exp  : unsigned(FP_EXP_WIDTH-1 downto 0);
    mant : unsigned(FP_MANT_WIDTH-1 downto 0);
  end record;

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

    if shift = 1 then
      result := value(value'length-1 downto 1) & sticky;
    else
      result := value(value'length-1 downto shift) & (shift-1 downto 1 => '0') & sticky;
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
    subtract : boolean
  ) return fp80_t is
    variable a_u : fp_unpacked_t := unpack_fp80(a);
    variable b_u : fp_unpacked_t := unpack_fp80(b);
    variable res_u : fp_unpacked_t;
    variable mant_a_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_b_ext : unsigned(FP_MANT_EXT_WIDTH-1 downto 0) := (others => '0');
    variable mant_sum   : unsigned(FP_MANT_EXT_WIDTH downto 0) := (others => '0');
    variable mant_main  : unsigned(FP_MANT_WIDTH-1 downto 0) := (others => '0');
    variable exp_diff   : natural := 0;
    variable exp_res    : unsigned(FP_EXP_WIDTH-1 downto 0) := (others => '0');
    variable sign_b     : std_logic := '0';
    variable guard      : std_logic := '0';
    variable round_bit  : std_logic := '0';
    variable sticky     : std_logic := '0';
    variable increment  : std_logic := '0';
    variable mant_round : unsigned(FP_MANT_WIDTH downto 0) := (others => '0');
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

    guard := mant_sum(2);
    round_bit := mant_sum(1);
    sticky := mant_sum(0);
    mant_main := mant_sum(mant_sum'left-1 downto FP_GRS_BITS);

    if guard = '1' and (round_bit = '1' or sticky = '1' or mant_main(0) = '1') then
      increment := '1';
    end if;

    if increment = '1' then
      mant_round := ('0' & mant_main) + 1;
      if mant_round(mant_round'left) = '1' then
        mant_main := shift_right_with_sticky(mant_round(mant_round'left-1 downto 0), 1);
        if exp_res /= FP_EXP_ALL_ONES then
          exp_res := exp_res + 1;
        end if;
      else
        mant_main := mant_round(mant_round'left-1 downto 0);
      end if;
    end if;

    if mant_main = 0 then
      res_u.sign := '0';
      res_u.exp := (others => '0');
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    if exp_res = FP_EXP_ALL_ONES then
      res_u.exp := exp_res;
      res_u.mant := (others => '0');
      return pack_fp80(res_u);
    end if;

    res_u.exp := exp_res;
    res_u.mant := mant_main;
    return pack_fp80(res_u);
  end function;
end package body mc68881_pkg;
