library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_trig_unit is
  port (
    clk        : in  std_logic;
    reset_n    : in  std_logic;
    start      : in  std_logic;
    op_sel     : in  fpu_op_t;
    a_in       : in  fp80_t;
    round_mode : in  fp_round_mode_t;
    round_prec : in  fp_round_prec_t;
    busy       : out std_logic;
    done       : out std_logic;
    result     : out fp80_t;
    aux_valid  : out std_logic;
    aux_result : out fp80_t
  );
end entity mc68881_trig_unit;

architecture rtl of mc68881_trig_unit is
  type trig_state_t is (
    ST_IDLE,
    ST_CLASSIFY,
    ST_REDUCE,
    ST_QUADRANT_SCALE,
    ST_QUADRANT_FRAC,
    ST_RESIDUAL,
    ST_SIN_1,
    ST_SIN_2,
    ST_SIN_3,
    ST_COS_1,
    ST_COS_2,
    ST_COS_3,
    ST_RECONSTRUCT,
    ST_TAN_DIV,
    ST_DONE
  );

  constant FP80_ZERO      : fp80_t := x"00000000000000000000";
  constant FP80_ONE       : fp80_t := x"3FFF8000000000000000";
  constant FP80_HALF      : fp80_t := x"3FFE8000000000000000";
  constant FP80_PI        : fp80_t := x"4000C90FDAA22168C235";
  constant FP80_HALF_PI   : fp80_t := x"3FFFC90FDAA22168C235";
  constant FP80_TWO_PI    : fp80_t := x"4001C90FDAA22168C235";
  constant FP80_TWO_OVER_PI : fp80_t := x"3FFFA2F9836E4E4416F4";
  constant FP80_NEG_ONE   : fp80_t := x"BFFF8000000000000000";
  constant FP80_NEG_HALF_PI : fp80_t := x"BFFFC90FDAA22168C235";

  signal state_reg : trig_state_t := ST_IDLE;
  signal op_reg : fpu_op_t := FPU_OP_NOP;
  signal a_reg : fp80_t := (others => '0');
  signal rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;

  signal x_reg : fp80_t := (others => '0');
  signal r_reg : fp80_t := (others => '0');
  signal r2_reg : fp80_t := (others => '0');
  signal r3_reg : fp80_t := (others => '0');
  signal s_reg : fp80_t := (others => '0');
  signal c_reg : fp80_t := (others => '0');
  signal poly_reg : fp80_t := (others => '0');
  signal tmp_reg : fp80_t := (others => '0');
  signal result_reg : fp80_t := (others => '0');
  signal aux_result_reg : fp80_t := (others => '0');
  signal q_reg : integer := 0;
  signal q_mod_reg : integer range 0 to 3 := 0;
  signal done_reg : std_logic := '0';
  signal aux_valid_reg : std_logic := '0';

  function canonical_nan(value : fp80_t) return fp80_t is
    variable res : fp80_t := value;
  begin
    res(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
    res(FP_MANT_WIDTH-1) := '1';
    if res(FP_MANT_WIDTH-2 downto 0) = (res(FP_MANT_WIDTH-2 downto 0)'range => '0') then
      res(FP_MANT_WIDTH-2) := '1';
    end if;
    return res;
  end function;

begin
  process(clk, reset_n)
    variable exp_bits : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable scaled : fp80_t;
    variable q_local : integer;
    variable frac : fp80_t;
    variable p : fp80_t;
    variable sin_res : fp80_t;
    variable cos_res : fp80_t;
    variable combined : fp80_t;
    variable eps : fp80_t;
  begin
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      done_reg <= '0';
      aux_valid_reg <= '0';
      result_reg <= (others => '0');
      aux_result_reg <= (others => '0');
    elsif rising_edge(clk) then
      done_reg <= '0';
      aux_valid_reg <= '0';
      case state_reg is
        when ST_IDLE =>
          if start = '1' then
            op_reg <= op_sel;
            a_reg <= a_in;
            rm_reg <= round_mode;
            rp_reg <= round_prec;
            state_reg <= ST_CLASSIFY;
          end if;

        when ST_CLASSIFY =>
          exp_bits := unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
          if exp_bits = to_unsigned(32767, FP_EXP_WIDTH) then
            result_reg <= canonical_nan(a_reg);
            state_reg <= ST_DONE;
          elsif a_reg = FP80_ZERO then
            s_reg <= FP80_ZERO;
            c_reg <= FP80_ONE;
            state_reg <= ST_RECONSTRUCT;
          elsif a_reg = FP80_HALF_PI then
            s_reg <= FP80_ONE;
            c_reg <= FP80_ZERO;
            state_reg <= ST_RECONSTRUCT;
          elsif a_reg = FP80_NEG_HALF_PI then
            s_reg <= FP80_NEG_ONE;
            c_reg <= FP80_ZERO;
            state_reg <= ST_RECONSTRUCT;
          elsif a_reg = FP80_PI then
            s_reg <= FP80_ZERO;
            c_reg <= FP80_NEG_ONE;
            state_reg <= ST_RECONSTRUCT;
          elsif exp_bits /= 0 and to_integer(exp_bits) < FP_EXP_BIAS - 32 then
            s_reg <= add_sub_fp80(a_reg, FP80_ZERO, false, rm_reg, rp_reg);
            c_reg <= FP80_ONE;
            state_reg <= ST_RECONSTRUCT;
          else
            x_reg <= a_reg;
            state_reg <= ST_REDUCE;
          end if;

        when ST_REDUCE =>
          exp_bits := unsigned(x_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
          if exp_bits = 0 then
            state_reg <= ST_QUADRANT_SCALE;
          elsif to_integer(exp_bits) > FP_EXP_BIAS + 30 then
            x_reg <= fmod_fp80(x_reg, FP80_TWO_PI, FP_RND_NEAREST, FP_PREC_EXTENDED);
            state_reg <= ST_QUADRANT_SCALE;
          else
            state_reg <= ST_QUADRANT_SCALE;
          end if;

        when ST_QUADRANT_SCALE =>
          scaled := mul_fp80(x_reg, FP80_TWO_OVER_PI, FP_RND_NEAREST, FP_PREC_EXTENDED);
          tmp_reg <= scaled;
          q_local := fp80_to_int_trunc(scaled);
          q_reg <= q_local;
          state_reg <= ST_QUADRANT_FRAC;

        when ST_QUADRANT_FRAC =>
          frac := add_sub_fp80(tmp_reg, fp80_from_int(q_reg), true, FP_RND_NEAREST, FP_PREC_EXTENDED);
          q_local := q_reg;
          if frac(FP_WIDTH-1) = '0' and compare_fp80(frac, FP80_HALF) >= 0 then
            q_local := q_local + 1;
          elsif frac(FP_WIDTH-1) = '1' and compare_fp80(abs_fp80(frac), FP80_HALF) >= 0 then
            q_local := q_local - 1;
          end if;
          q_reg <= q_local;
          q_mod_reg <= ((q_local mod 4) + 4) mod 4;
          state_reg <= ST_RESIDUAL;

        when ST_RESIDUAL =>
          r_reg <= add_sub_fp80(x_reg, mul_fp80(fp80_from_int(q_reg), FP80_HALF_PI, FP_RND_NEAREST, FP_PREC_EXTENDED), true, FP_RND_NEAREST, FP_PREC_EXTENDED);
          state_reg <= ST_SIN_1;

        when ST_SIN_1 =>
          eps := div_fp80(FP80_ONE, fp80_from_int(1048576), FP_RND_NEAREST, FP_PREC_EXTENDED);
          if compare_fp80(abs_fp80(r_reg), eps) <= 0 then
            r_reg <= FP80_ZERO;
          end if;
          r2_reg <= mul_fp80(r_reg, r_reg, FP_RND_NEAREST, FP_PREC_EXTENDED);
          r3_reg <= mul_fp80(mul_fp80(r_reg, r_reg, FP_RND_NEAREST, FP_PREC_EXTENDED), r_reg, FP_RND_NEAREST, FP_PREC_EXTENDED);
          p := div_fp80(fp80_from_int(1), fp80_from_int(5040), FP_RND_NEAREST, FP_PREC_EXTENDED);
          p(FP_WIDTH-1) := '1';
          poly_reg <= p;
          state_reg <= ST_SIN_2;

        when ST_SIN_2 =>
          p := add_sub_fp80(div_fp80(fp80_from_int(1), fp80_from_int(120), FP_RND_NEAREST, FP_PREC_EXTENDED), mul_fp80(r2_reg, poly_reg, FP_RND_NEAREST, FP_PREC_EXTENDED), false, FP_RND_NEAREST, FP_PREC_EXTENDED);
          poly_reg <= p;
          state_reg <= ST_SIN_3;

        when ST_SIN_3 =>
          p := div_fp80(fp80_from_int(1), fp80_from_int(6), FP_RND_NEAREST, FP_PREC_EXTENDED);
          p(FP_WIDTH-1) := '1';
          p := add_sub_fp80(p, mul_fp80(r2_reg, poly_reg, FP_RND_NEAREST, FP_PREC_EXTENDED), false, FP_RND_NEAREST, FP_PREC_EXTENDED);
          sin_res := add_sub_fp80(r_reg, mul_fp80(r3_reg, p, FP_RND_NEAREST, FP_PREC_EXTENDED), false, rm_reg, rp_reg);
          s_reg <= sin_res;
          p := div_fp80(fp80_from_int(1), fp80_from_int(720), FP_RND_NEAREST, FP_PREC_EXTENDED);
          p(FP_WIDTH-1) := '1';
          poly_reg <= p;
          state_reg <= ST_COS_1;

        when ST_COS_1 =>
          p := add_sub_fp80(div_fp80(fp80_from_int(1), fp80_from_int(24), FP_RND_NEAREST, FP_PREC_EXTENDED), mul_fp80(r2_reg, poly_reg, FP_RND_NEAREST, FP_PREC_EXTENDED), false, FP_RND_NEAREST, FP_PREC_EXTENDED);
          poly_reg <= p;
          state_reg <= ST_COS_2;

        when ST_COS_2 =>
          p := FP80_HALF;
          p(FP_WIDTH-1) := '1';
          p := add_sub_fp80(p, mul_fp80(r2_reg, poly_reg, FP_RND_NEAREST, FP_PREC_EXTENDED), false, FP_RND_NEAREST, FP_PREC_EXTENDED);
          tmp_reg <= p;
          state_reg <= ST_COS_3;

        when ST_COS_3 =>
          cos_res := add_sub_fp80(FP80_ONE, mul_fp80(r2_reg, tmp_reg, FP_RND_NEAREST, FP_PREC_EXTENDED), false, rm_reg, rp_reg);
          c_reg <= cos_res;
          state_reg <= ST_RECONSTRUCT;

        when ST_RECONSTRUCT =>
          sin_res := s_reg;
          cos_res := c_reg;
          case q_mod_reg is
            when 0 =>
              null;
            when 1 =>
              combined := sin_res;
              sin_res := cos_res;
              cos_res := combined;
              sin_res(FP_WIDTH-1) := not sin_res(FP_WIDTH-1);
            when 2 =>
              sin_res(FP_WIDTH-1) := not sin_res(FP_WIDTH-1);
              cos_res(FP_WIDTH-1) := not cos_res(FP_WIDTH-1);
            when others =>
              combined := sin_res;
              sin_res := cos_res;
              cos_res := combined;
              cos_res(FP_WIDTH-1) := not cos_res(FP_WIDTH-1);
          end case;
          s_reg <= sin_res;
          c_reg <= cos_res;
          if op_reg = FPU_OP_TAN then
            state_reg <= ST_TAN_DIV;
          else
            if op_reg = FPU_OP_COS then
              result_reg <= cos_res;
            else
              result_reg <= sin_res;
            end if;
            aux_result_reg <= cos_res;
            if op_reg = FPU_OP_SINCOS then
              aux_valid_reg <= '1';
            end if;
            state_reg <= ST_DONE;
          end if;

        when ST_TAN_DIV =>
          result_reg <= div_fp80(s_reg, c_reg, rm_reg, rp_reg);
          state_reg <= ST_DONE;

        when ST_DONE =>
          done_reg <= '1';
          state_reg <= ST_IDLE;
      end case;
    end if;
  end process;

  busy <= '1' when state_reg /= ST_IDLE else '0';
  done <= done_reg;
  result <= result_reg;
  aux_valid <= aux_valid_reg;
  aux_result <= aux_result_reg;
end architecture rtl;
