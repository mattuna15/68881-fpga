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
    ST_SCALE_PREP,
    ST_SCALE_POST,
    ST_FRAC_PREP,
    ST_FRAC_POST,
    ST_QPI_PREP,
    ST_QPI_POST,
    ST_RESIDUAL_PREP,
    ST_RESIDUAL_POST,
    ST_R2_PREP,
    ST_R2_POST,
    ST_R3_PREP,
    ST_R3_POST,
    ST_SIN_MAC1_MUL_PREP,
    ST_SIN_MAC1_ADD_PREP,
    ST_SIN_MAC1_POST,
    ST_SIN_MAC2_MUL_PREP,
    ST_SIN_MAC2_ADD_PREP,
    ST_SIN_MAC2_POST,
    ST_SIN_FINAL_MUL_PREP,
    ST_SIN_FINAL_ADD_PREP,
    ST_SIN_FINAL_POST,
    ST_COS_MAC1_MUL_PREP,
    ST_COS_MAC1_ADD_PREP,
    ST_COS_MAC1_POST,
    ST_COS_MAC2_MUL_PREP,
    ST_COS_MAC2_ADD_PREP,
    ST_COS_MAC2_POST,
    ST_COS_FINAL_MUL_PREP,
    ST_COS_FINAL_ADD_PREP,
    ST_COS_FINAL_POST,
    ST_RECONSTRUCT,
    ST_FP_MUL,
    ST_FP_ADD,
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
  constant FP80_EPS_TRIG  : fp80_t := x"3FEB8000000000000000"; -- 2^-20
  constant FP80_NEG_1_OVER_5040 : fp80_t := x"BFF2D00D00D00D00D00D";
  constant FP80_POS_1_OVER_120  : fp80_t := x"3FF88888888888888889";
  constant FP80_NEG_1_OVER_6    : fp80_t := x"BFFCAAAAAAAAAAAAAAAB";
  constant FP80_NEG_1_OVER_720  : fp80_t := x"BFF5B60B60B60B60B60B";
  constant FP80_POS_1_OVER_24   : fp80_t := x"3FFAAAAAAAAAAAAAAAAB";

  signal state_reg : trig_state_t := ST_IDLE;
  signal cont_state_reg : trig_state_t := ST_IDLE;
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
  signal mul_a_reg : fp80_t := (others => '0');
  signal mul_b_reg : fp80_t := (others => '0');
  signal mul_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal mul_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;
  signal add_a_reg : fp80_t := (others => '0');
  signal add_b_reg : fp80_t := (others => '0');
  signal add_sub_reg : boolean := false;
  signal add_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal add_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;

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
    variable sin_res : fp80_t;
    variable cos_res : fp80_t;
    variable combined : fp80_t;
    variable r_clamped : fp80_t;
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
            q_mod_reg <= 0;
            state_reg <= ST_RECONSTRUCT;
          elsif a_reg = FP80_HALF_PI then
            s_reg <= FP80_ONE;
            c_reg <= FP80_ZERO;
            q_mod_reg <= 0;
            state_reg <= ST_RECONSTRUCT;
          elsif a_reg = FP80_NEG_HALF_PI then
            s_reg <= FP80_NEG_ONE;
            c_reg <= FP80_ZERO;
            q_mod_reg <= 0;
            state_reg <= ST_RECONSTRUCT;
          elsif a_reg = FP80_PI then
            s_reg <= FP80_ZERO;
            c_reg <= FP80_NEG_ONE;
            q_mod_reg <= 0;
            state_reg <= ST_RECONSTRUCT;
          elsif exp_bits /= 0 and to_integer(exp_bits) < FP_EXP_BIAS - 32 then
            s_reg <= add_sub_fp80(a_reg, FP80_ZERO, false, rm_reg, rp_reg);
            c_reg <= FP80_ONE;
            q_mod_reg <= 0;
            state_reg <= ST_RECONSTRUCT;
          else
            x_reg <= a_reg;
            state_reg <= ST_REDUCE;
          end if;

        when ST_REDUCE =>
          exp_bits := unsigned(x_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
          if exp_bits /= 0 and to_integer(exp_bits) > FP_EXP_BIAS + 30 then
            x_reg <= fmod_fp80(x_reg, FP80_TWO_PI, FP_RND_NEAREST, FP_PREC_EXTENDED);
          end if;
          state_reg <= ST_SCALE_PREP;

        when ST_SCALE_PREP =>
          mul_a_reg <= x_reg;
          mul_b_reg <= FP80_TWO_OVER_PI;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_SCALE_POST;
          state_reg <= ST_FP_MUL;

        when ST_SCALE_POST =>
          scaled := tmp_reg;
          q_local := fp80_to_int_trunc(scaled);
          q_reg <= q_local;
          state_reg <= ST_FRAC_PREP;

        when ST_FRAC_PREP =>
          add_a_reg <= tmp_reg;
          add_b_reg <= fp80_from_int(q_reg);
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_FRAC_POST;
          state_reg <= ST_FP_ADD;

        when ST_FRAC_POST =>
          frac := tmp_reg;
          q_local := q_reg;
          if frac(FP_WIDTH-1) = '0' and compare_fp80(frac, FP80_HALF) >= 0 then
            q_local := q_local + 1;
          elsif frac(FP_WIDTH-1) = '1' and compare_fp80(abs_fp80(frac), FP80_HALF) >= 0 then
            q_local := q_local - 1;
          end if;
          q_reg <= q_local;
          q_mod_reg <= ((q_local mod 4) + 4) mod 4;
          state_reg <= ST_QPI_PREP;

        when ST_QPI_PREP =>
          mul_a_reg <= fp80_from_int(q_reg);
          mul_b_reg <= FP80_HALF_PI;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_QPI_POST;
          state_reg <= ST_FP_MUL;

        when ST_QPI_POST =>
          state_reg <= ST_RESIDUAL_PREP;

        when ST_RESIDUAL_PREP =>
          add_a_reg <= x_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_RESIDUAL_POST;
          state_reg <= ST_FP_ADD;

        when ST_RESIDUAL_POST =>
          r_clamped := tmp_reg;
          if compare_fp80(abs_fp80(r_clamped), FP80_EPS_TRIG) <= 0 then
            r_clamped := FP80_ZERO;
          end if;
          r_reg <= r_clamped;
          state_reg <= ST_R2_PREP;

        when ST_R2_PREP =>
          mul_a_reg <= r_reg;
          mul_b_reg <= r_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_R2_POST;
          state_reg <= ST_FP_MUL;

        when ST_R2_POST =>
          r2_reg <= tmp_reg;
          state_reg <= ST_R3_PREP;

        when ST_R3_PREP =>
          mul_a_reg <= r2_reg;
          mul_b_reg <= r_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_R3_POST;
          state_reg <= ST_FP_MUL;

        when ST_R3_POST =>
          r3_reg <= tmp_reg;
          poly_reg <= FP80_NEG_1_OVER_5040;
          state_reg <= ST_SIN_MAC1_MUL_PREP;

        when ST_SIN_MAC1_MUL_PREP =>
          mul_a_reg <= r2_reg;
          mul_b_reg <= poly_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_SIN_MAC1_ADD_PREP;
          state_reg <= ST_FP_MUL;

        when ST_SIN_MAC1_ADD_PREP =>
          add_a_reg <= FP80_POS_1_OVER_120;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_SIN_MAC1_POST;
          state_reg <= ST_FP_ADD;

        when ST_SIN_MAC1_POST =>
          poly_reg <= tmp_reg;
          state_reg <= ST_SIN_MAC2_MUL_PREP;

        when ST_SIN_MAC2_MUL_PREP =>
          mul_a_reg <= r2_reg;
          mul_b_reg <= poly_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_SIN_MAC2_ADD_PREP;
          state_reg <= ST_FP_MUL;

        when ST_SIN_MAC2_ADD_PREP =>
          add_a_reg <= FP80_NEG_1_OVER_6;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_SIN_MAC2_POST;
          state_reg <= ST_FP_ADD;

        when ST_SIN_MAC2_POST =>
          poly_reg <= tmp_reg;
          state_reg <= ST_SIN_FINAL_MUL_PREP;

        when ST_SIN_FINAL_MUL_PREP =>
          mul_a_reg <= r3_reg;
          mul_b_reg <= poly_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_SIN_FINAL_ADD_PREP;
          state_reg <= ST_FP_MUL;

        when ST_SIN_FINAL_ADD_PREP =>
          add_a_reg <= r_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;
          add_rm_reg <= rm_reg;
          add_rp_reg <= rp_reg;
          cont_state_reg <= ST_SIN_FINAL_POST;
          state_reg <= ST_FP_ADD;

        when ST_SIN_FINAL_POST =>
          s_reg <= tmp_reg;
          poly_reg <= FP80_NEG_1_OVER_720;
          state_reg <= ST_COS_MAC1_MUL_PREP;

        when ST_COS_MAC1_MUL_PREP =>
          mul_a_reg <= r2_reg;
          mul_b_reg <= poly_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_COS_MAC1_ADD_PREP;
          state_reg <= ST_FP_MUL;

        when ST_COS_MAC1_ADD_PREP =>
          add_a_reg <= FP80_POS_1_OVER_24;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_COS_MAC1_POST;
          state_reg <= ST_FP_ADD;

        when ST_COS_MAC1_POST =>
          poly_reg <= tmp_reg;
          state_reg <= ST_COS_MAC2_MUL_PREP;

        when ST_COS_MAC2_MUL_PREP =>
          mul_a_reg <= r2_reg;
          mul_b_reg <= poly_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_COS_MAC2_ADD_PREP;
          state_reg <= ST_FP_MUL;

        when ST_COS_MAC2_ADD_PREP =>
          add_a_reg <= FP80_HALF;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_COS_MAC2_POST;
          state_reg <= ST_FP_ADD;

        when ST_COS_MAC2_POST =>
          poly_reg <= tmp_reg;
          state_reg <= ST_COS_FINAL_MUL_PREP;

        when ST_COS_FINAL_MUL_PREP =>
          mul_a_reg <= r2_reg;
          mul_b_reg <= poly_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_COS_FINAL_ADD_PREP;
          state_reg <= ST_FP_MUL;

        when ST_COS_FINAL_ADD_PREP =>
          add_a_reg <= FP80_ONE;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= rm_reg;
          add_rp_reg <= rp_reg;
          cont_state_reg <= ST_COS_FINAL_POST;
          state_reg <= ST_FP_ADD;

        when ST_COS_FINAL_POST =>
          c_reg <= tmp_reg;
          state_reg <= ST_RECONSTRUCT;

        when ST_FP_MUL =>
          tmp_reg <= mul_fp80(mul_a_reg, mul_b_reg, mul_rm_reg, mul_rp_reg);
          state_reg <= cont_state_reg;

        when ST_FP_ADD =>
          tmp_reg <= add_sub_fp80(add_a_reg, add_b_reg, add_sub_reg, add_rm_reg, add_rp_reg);
          state_reg <= cont_state_reg;

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
