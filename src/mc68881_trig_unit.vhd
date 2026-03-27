library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mc68881_pkg.all;

entity mc68881_trig_unit is
  generic (
    table_impl : natural := TABLE_IMPL_BRAM
  );
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
    aux_result : out fp80_t;
    flag_divzero : out std_logic;
    -- Save/restore interface for FSAVE/FRESTORE Busy frame.
    save_req     : in  std_logic;
    save_data    : out std_logic_vector(31 downto 0);
    save_addr    : in  natural range 0 to 10;
    restore_req  : in  std_logic;
    restore_data : in  std_logic_vector(31 downto 0);
    restore_addr : in  natural range 0 to 10;
    restore_wr   : in  std_logic
  );
end entity mc68881_trig_unit;

architecture rtl of mc68881_trig_unit is
  type trig_state_t is (
    ST_IDLE,
    ST_A_SETTLE,
    ST_CLASSIFY,
    ST_TRIG_REDUCE,
    ST_TRIG_MOD_SCALE_POST,
    ST_TRIG_MOD_INV4_POST,
    ST_TRIG_MOD_QPI_PREP,
    ST_TRIG_MOD_QPI_POST,
    ST_TRIG_MOD_SUB_PREP,
    ST_TRIG_MOD_SUB_POST,
    ST_TRIG_SCALE_PREP,
    ST_TRIG_SCALE_POST,
    ST_TRIG_FRAC_PREP,
    ST_TRIG_FRAC_POST,
    ST_TRIG_QROUND_POST,
    ST_TRIG_QPI_PREP,
    ST_TRIG_QPI_POST,
    ST_TRIG_RESIDUAL_PREP,
    ST_TRIG_RESIDUAL_POST,
    ST_TRIG_CW_LO_MUL,
    ST_TRIG_CW_LO_SUB,
    ST_TRIG_CW_C3_MUL,
    ST_TRIG_CW_C3_SUB,
    ST_TRIG_SEED_INDEX_ADD_PREP,
    ST_TRIG_SEED_INDEX_ADD_POST,
    ST_TRIG_SEED_INDEX_SCALE_POST,
    ST_SEED_READ,
    ST_SEED_READ_WAIT,
    ST_SEED_READ_LATCH,
    ST_TRIG_SEED_DELTA_PREP,
    ST_TRIG_SEED_DELTA_POST,
    ST_TRIG_SEED_DELTA2_PREP,
    ST_TRIG_SEED_DELTA2_POST,
    ST_TRIG_SEED_SIN_LIN_PREP,
    ST_TRIG_SEED_SIN_LIN_POST,
    ST_TRIG_SEED_SIN_QUAD_PREP,
    ST_TRIG_SEED_SIN_QUAD_POST,
    ST_TRIG_SEED_SIN_HALF_POST,
    ST_TRIG_SEED_COS_LIN_PREP,
    ST_TRIG_SEED_COS_LIN_POST,
    ST_TRIG_SEED_COS_QUAD_PREP,
    ST_TRIG_SEED_COS_QUAD_POST,
    ST_TRIG_SEED_COS_HALF_POST,
    ST_TRIG_COS_FINAL_POST,
    ST_TRIG_RECONSTRUCT,
    ST_TRIG_TAN_DIV,
    ST_TRIG_TAN_DIV_POST,
    ST_TRIG_TINY_ROUND_POST,
    ST_TWOTOX_ROUND,
    ST_TWOTOX_ROUND_POST,
    ST_TWOTOX_FRAC_POST,
    ST_TWOTOX_RLN2_POST,
    ST_TANH_2X_POST,
    ST_TANH_EXP_POST,
    ST_TANH_NUMER_POST,
    ST_TANH_DENOM_POST,
    ST_TANH_DIV_POST,
    ST_EXP64_N_ROUND,
    ST_EXP64_N_POST,
    ST_EXP64_TABLE_WAIT,
    ST_EXP64_TABLE_LATCH,
    ST_EXP64_CW_HI_POST,
    ST_EXP64_CW_LO_MUL,
    ST_EXP64_CW_LO_POST,
    ST_EXP_REDUCE_K_POST,
    ST_EXP_REDUCE_KLN2_POST,
    ST_EXP_REDUCE_R_POST,
    ST_EXP_CW_LO_MUL,
    ST_EXP_CW_LO_SUB,
    ST_EXP_CW_C3_MUL,
    ST_EXP_CW_C3_SUB,
    ST_LOG_EXP_TERM_POST,
    ST_LOG_GETEXP,
    ST_LOG_GETEXP_HOLD,
    ST_LOG_GETEXP_POST,
    ST_LOGNP1_Z_POST,
    ST_LOGNP1_META_POST,
    ST_LOGNP1_GETEXP_POST,
    ST_ATAN_INV_POST,
    ST_ATAN_INDEX_MUL_POST,
    ST_ATAN_DELTA_PREP,
    ST_ATAN_DELTA_POST,
    ST_ATAN_CX_MUL_POST,
    ST_ATAN_DENOM_ADD_POST,
    ST_ATAN_U_POST,
    ST_ATAN_RECIP_SUB,
    ST_ATAN_RECIP_POST,
    ST_ASIN_X2_POST,
    ST_ASIN_ONEMX2_POST,
    ST_ASIN_SQRT_POST,
    ST_ASIN_DIV_POST,
    ST_ACOS_FINAL,
    ST_ACOS_FINAL_POST,
    ST_ATANH_NUMER_POST,
    ST_ATANH_DENOM_POST,
    ST_ATANH_DIV_POST,
    ST_ATANH_HALF_PREP,
    ST_ATANH_HALF_POST,
    ST_LOG_TABLE_INDEX,
    ST_LOG_TABLE_WAIT,
    ST_LOG_TABLE_LATCH,
    ST_LOG_DELTA_PREP,
    ST_LOG_DELTA_POST,
    ST_LOG_U_POST,
    ST_FP_SQRT,
    ST_TRANS_PREP,
    ST_TRANS_ADD_PREP,
    ST_TRANS_INPUT_ADJUST_POST,
    ST_TRANS_PRE_MUL_POST,
    ST_TRANS_POLY_INIT,
    ST_TRANS_POLY_INIT_WAIT,
    ST_TRANS_POLY_MUL_PREP,
    ST_TRANS_POLY_MUL_POST,
    ST_TRANS_POLY_ADD_POST,
    ST_TRANS_POST_MUL_PREP,
    ST_TRANS_POST_MUL_POST,
    ST_TRANS_POST_ADD_PREP,
    ST_TRANS_POST_ADD_POST,
    ST_TRANS_FINAL_ROUND_POST,
    ST_FP_MUL,
    ST_FP_ADD,
    ST_FP_DIV,
    ST_DONE
  );

  constant FP80_ZERO      : fp80_t := x"00000000000000000000";
  constant FP80_ONE       : fp80_t := x"3FFF8000000000000000";
  constant FP80_HALF      : fp80_t := x"3FFE8000000000000000";
  constant FP80_TWO       : fp80_t := x"40008000000000000000";
  constant FP80_TEN       : fp80_t := x"4002A000000000000000";
  constant FP80_NEG_ONE   : fp80_t := x"BFFF8000000000000000";
  constant FP80_POS_INF   : fp80_t := x"7FFF8000000000000000";
  constant FP80_NEG_INF   : fp80_t := x"FFFF8000000000000000";
  constant FP80_PI        : fp80_t := x"4000C90FDAA22168C235";
  constant FP80_HALF_PI   : fp80_t := x"3FFFC90FDAA22168C235";
  constant FP80_HALF_PI_HI : fp80_t := x"3FFFC90FDAA200000000";
  constant FP80_HALF_PI_LO : fp80_t := x"3FDD85A308D400000000";  -- pi/2 - HALF_PI_HI (C1+C2 = FP80_HALF_PI exactly)
  constant FP80_HALF_PI_C3 : fp80_t := x"BFBDECE675D1FC8F8CBB";  -- true pi/2 - FP80_HALF_PI (~131 bits)
  constant FP80_QUARTER_PI : fp80_t := x"3FFEC90FDAA22168C000";
  constant FP80_NEG_HALF_PI : fp80_t := x"BFFFC90FDAA22168C235";
  constant FP80_TWO_PI    : fp80_t := x"4001C90FDAA22168C235";
  constant FP80_TWO_OVER_PI : fp80_t := x"3FFEA2F9836E4E4416F4";
  constant FP80_TRIG_INDEX_SCALE : fp80_t := x"4004A2F9836E4E441800"; -- 128/pi
  constant FP80_EPS_TRIG  : fp80_t := x"3FEB8000000000000000"; -- 2^-20

  constant FP80_SIXTY_FOUR : fp80_t := x"40058000000000000000"; -- 64.0

  constant FP80_ONE_THIRD : fp80_t := x"3FFDAAAAAAAAAAAAAAAB";
  constant FP80_ONE_FOURTH : fp80_t := x"3FFD8000000000000000";
  constant FP80_ONE_FIFTH : fp80_t := x"3FFCCCCCCCCCCCCCCCCD";
  constant FP80_ONE_SIXTH : fp80_t := x"3FFCAAAAAAAAAAAAAAAB";
  constant FP80_ONE_TWENTYFOURTH : fp80_t := x"3FFAAAAAAAAAAAAAAAAB";
  constant FP80_ONE_120TH : fp80_t := x"3FF88888888888888889";
  constant FP80_TWO_FIFTEENTHS : fp80_t := x"3FF8AAAAAAAAAAAAAAAB";
  constant FP80_THREE_FORTIETHS : fp80_t := x"3FF94CCCCCCCCCCCCCCD";
  constant FP80_NEG_HALF : fp80_t := x"BFFE8000000000000000";
  constant FP80_NEG_ONE_THIRD : fp80_t := x"BFFDAAAAAAAAAAAAAAAB";
  constant FP80_NEG_ONE_FOURTH : fp80_t := x"BFFD8000000000000000";
  constant FP80_NEG_ONE_SIXTH : fp80_t := x"BFFCAAAAAAAAAAAAAAAB";
  constant FP80_LN2 : fp80_t := x"3FFEB17217F7D1CF79AC";
  constant FP80_LN2_HI : fp80_t := x"3FFEB17217F700000000";  -- ln(2) with low 32 mantissa bits zeroed
  constant FP80_LN2_LO : fp80_t := x"3FDED1CF79AC00000000";  -- ln(2) - LN2_HI (C1+C2 = FP80_LN2 exactly)
  constant FP80_LN2_C3 : fp80_t := x"BFBCD871319FF0342542";  -- true ln(2) - FP80_LN2 (~129 bits)
  constant FP80_LN10 : fp80_t := x"4000935D8DDDAAA8AC17";
  constant FP80_INV_LN2 : fp80_t := x"3FFFB8AA3B295C17F0BC";
  constant FP80_INV_LN10 : fp80_t := x"3FFDDE5BD8A937287195";
  constant FP80_LOG10_2 : fp80_t := x"3FFD9A209A84FBCFF798";
  constant FP80_LOG2_10 : fp80_t := x"4000D49A784BCD1B8AFE"; -- log2(10) = ln(10)/ln(2)

  -- EXP 2^(J/64) decomposition constants
  constant FP80_64_INV_LN2    : fp80_t := x"4005B8AA3B295C17F0BC"; -- 64/ln(2)
  constant FP80_LN2_DIV64_HI  : fp80_t := x"3FF8B17217F700000000"; -- ln(2)/64 high
  constant FP80_LN2_DIV64_LO  : fp80_t := x"3FD8D1CF79AC00000000"; -- ln(2)/64 low

  constant FP80_ONE_720TH     : fp80_t := x"3FF5B60B60B60B60B60B"; -- 1/720 = 1/6!
  constant FP80_ONE_5040TH    : fp80_t := x"3FF2D00D00D00D00D00D"; -- 1/5040 = 1/7!
  constant FP80_ONE_40320TH   : fp80_t := x"3FEFD00D00D00D00D00D"; -- 1/40320 = 1/8!
  constant FP80_ONE_362880TH  : fp80_t := x"3FECB8EF1D2AB6399C7D"; -- 1/362880 = 1/9!
  constant FP80_ONE_SEVENTH   : fp80_t := x"3FFC9249249249249249"; -- 1/7
  constant FP80_ONE_EIGHTH    : fp80_t := x"3FFC8000000000000000"; -- 1/8
  constant FP80_ONE_NINTH     : fp80_t := x"3FFBE38E38E38E38E38E"; -- 1/9
  constant FP80_NEG_ONE_FIFTH : fp80_t := x"BFFCCCCCCCCCCCCCCCCD"; -- -1/5
  constant FP80_NEG_ONE_SEVENTH : fp80_t := x"BFFC9249249249249249"; -- -1/7
  constant FP80_NEG_ONE_EIGHTH  : fp80_t := x"BFFC8000000000000000"; -- -1/8
  constant FP80_NEG_ONE_NINTH   : fp80_t := x"BFFBE38E38E38E38E38E"; -- -1/9

  type fp80_table64_t is array (0 to 63) of fp80_t;
  type seed_domain_t is (SEED_DOMAIN_TRIG, SEED_DOMAIN_EXP, SEED_DOMAIN_LOG, SEED_DOMAIN_ATAN);

  -- Coefficient ROM: 6 sets × 10 coefficients for Horner polynomial evaluation
  constant COEFF_SET_EXP   : integer := 0;  -- TWOTOX/TENTOX (Taylor, wide range)
  constant COEFF_SET_LOG   : integer := 1;  -- LOGN/LOG2/LOG10/LOGNP1/ATANH
  constant COEFF_SET_ATAN  : integer := 2;  -- ATAN/ASIN/ACOS
  constant COEFF_SET_SINH  : integer := 3;  -- SINH (odd terms of EXP)
  constant COEFF_SET_COSH  : integer := 4;  -- COSH (even terms of EXP)
  constant COEFF_SET_EXP64 : integer := 5;  -- ETOX/ETOXM1/TANH (minimax, tight range)
  type fp80_table60_t is array (0 to 59) of fp80_t;
  constant COEFF_ROM_INIT : fp80_table60_t := (
    -- EXP set (indices 0-9): 1/n! Taylor series for TWOTOX/TENTOX (wide range)
     0 => x"3FFF8000000000000000", -- 1         (coeff0: constant term)
     1 => x"3FFF8000000000000000", -- 1         (coeff1: x)
     2 => x"3FFE8000000000000000", -- 1/2       (coeff2: x^2)
     3 => x"3FFCAAAAAAAAAAAAAAAB", -- 1/6       (coeff3: x^3)
     4 => x"3FFAAAAAAAAAAAAAAAAB", -- 1/24      (coeff4: x^4)
     5 => x"3FF88888888888888889", -- 1/120     (coeff5: x^5)
     6 => x"3FF5B60B60B60B60B60B", -- 1/720     (coeff6: x^6)
     7 => x"3FF2D00D00D00D00D00D", -- 1/5040    (coeff7: x^7)
     8 => x"3FEFD00D00D00D00D00D", -- 1/40320   (coeff8: x^8)
     9 => x"3FECB8EF1D2AB6399C7D", -- 1/362880  (coeff9: x^9)
    -- LOG set (indices 10-19): alternating 1/n series for ln(1+x)
    10 => x"00000000000000000000", -- 0         (coeff0: overridden by table for LOG)
    11 => x"3FFF8000000000000000", -- 1         (coeff1: x)
    12 => x"BFFE8000000000000000", -- -1/2      (coeff2: x^2)
    13 => x"3FFDAAAAAAAAAAAAAAAB", -- 1/3       (coeff3: x^3)
    14 => x"BFFD8000000000000000", -- -1/4      (coeff4: x^4)
    15 => x"3FFCCCCCCCCCCCCCCCCD", -- 1/5       (coeff5: x^5)
    16 => x"BFFCAAAAAAAAAAAAAAAB", -- -1/6      (coeff6: x^6)
    17 => x"3FFC9249249249249249", -- 1/7       (coeff7: x^7)
    18 => x"BFFC8000000000000000", -- -1/8      (coeff8: x^8)
    19 => x"3FFBE38E38E38E38E38E", -- 1/9       (coeff9: x^9)
    -- ATAN set (indices 20-29): odd-power series for atan(x)
    20 => x"00000000000000000000", -- 0         (coeff0: constant term)
    21 => x"3FFF8000000000000000", -- 1         (coeff1: x)
    22 => x"00000000000000000000", -- 0         (coeff2: x^2 unused)
    23 => x"BFFDAAAAAAAAAAAAAAAB", -- -1/3      (coeff3: x^3)
    24 => x"00000000000000000000", -- 0         (coeff4: x^4 unused)
    25 => x"3FFCCCCCCCCCCCCCCCCD", -- 1/5       (coeff5: x^5)
    26 => x"00000000000000000000", -- 0         (coeff6: x^6 unused)
    27 => x"BFFC9249249249249249", -- -1/7      (coeff7: x^7)
    28 => x"00000000000000000000", -- 0         (coeff8: x^8 unused)
    29 => x"3FFBE38E38E38E38E38E", -- 1/9       (coeff9: x^9)
    -- SINH set (indices 30-39): odd Taylor terms (x + x^3/3! + x^5/5! + ...)
    30 => x"00000000000000000000", -- 0         (coeff0)
    31 => x"3FFF8000000000000000", -- 1         (coeff1: x)
    32 => x"00000000000000000000", -- 0         (coeff2)
    33 => x"3FFCAAAAAAAAAAAAAAAB", -- 1/6       (coeff3: x^3)
    34 => x"00000000000000000000", -- 0         (coeff4)
    35 => x"3FF88888888888888889", -- 1/120     (coeff5: x^5)
    36 => x"00000000000000000000", -- 0         (coeff6)
    37 => x"3FF2D00D00D00D00D00D", -- 1/5040    (coeff7: x^7)
    38 => x"00000000000000000000", -- 0         (coeff8)
    39 => x"3FECB8EF1D2AB6399C7D", -- 1/362880  (coeff9: x^9)
    -- COSH set (indices 40-49): even Taylor terms (1 + x^2/2! + x^4/4! + ...)
    40 => x"3FFF8000000000000000", -- 1         (coeff0: constant term)
    41 => x"00000000000000000000", -- 0         (coeff1)
    42 => x"3FFE8000000000000000", -- 1/2       (coeff2: x^2)
    43 => x"00000000000000000000", -- 0         (coeff3)
    44 => x"3FFAAAAAAAAAAAAAAAAB", -- 1/24      (coeff4: x^4)
    45 => x"00000000000000000000", -- 0         (coeff5)
    46 => x"3FF5B60B60B60B60B60B", -- 1/720     (coeff6: x^6)
    47 => x"00000000000000000000", -- 0         (coeff7)
    48 => x"3FEFD00D00D00D00D00D", -- 1/40320   (coeff8: x^8)
    49 => x"00000000000000000000", -- 0         (coeff9)
    -- EXP64 set (indices 50-56): FPSP minimax for 2^(J/64) decomposition
    -- exp(R) = 1 + R*(1 + R*(A1 + R*(A2 + R*(A3 + R*(A4 + R*A5)))))
    -- Valid for |R| <= ln(2)/128 ~ 0.0054 (after 2^(J/64) reduction)
    50 => x"3FFF8000000000000000", -- 1         (coeff0: constant term)
    51 => x"3FFF8000000000000000", -- 1         (coeff1: R)
    52 => x"3FFE8000000000000000", -- A1 = 0.5  (coeff2: R^2)
    53 => x"3FFCAAAAAAAAAA52A000", -- A2        (coeff3: R^3, minimax ~1/6)
    54 => x"3FFAAAAAAAAAAA660800", -- A3        (coeff4: R^4, minimax ~1/24)
    55 => x"3FF88888918163896000", -- A4        (coeff5: R^5, minimax ~1/120)
    56 => x"3FF5B60B6B7BDE859000", -- A5        (coeff6: R^6, minimax ~1/720)
    57 => x"00000000000000000000", -- unused
    58 => x"00000000000000000000", -- unused
    59 => x"00000000000000000000"  -- unused
  );
  constant TRIG_SEED_CENTER_INIT : fp80_table64_t := (
     0 => x"BFFEC5EB9B3798E32000",
     1 => x"BFFEBFA31C6287D7D800",
     2 => x"BFFEB95A9D8D76CC9000",
     3 => x"BFFEB3121EB865C14800",
     4 => x"BFFEACC99FE354B60800",
     5 => x"BFFEA681210E43AAC000",
     6 => x"BFFEA038A239329F7800",
     7 => x"BFFE99F0236421943000",
     8 => x"BFFE93A7A48F1088F000",
     9 => x"BFFE8D5F25B9FF7DA800",
    10 => x"BFFE8716A6E4EE726000",
    11 => x"BFFE80CE280FDD672000",
    12 => x"BFFDF50B527598B7A800",
    13 => x"BFFDE87A54CB76A12000",
    14 => x"BFFDDBE95721548A9000",
    15 => x"BFFDCF58597732740800",
    16 => x"BFFDC2C75BCD105D7800",
    17 => x"BFFDB6365E22EE46F000",
    18 => x"BFFDA9A56078CC306000",
    19 => x"BFFD9D1462CEAA19D800",
    20 => x"BFFD9083652488035000",
    21 => x"BFFD83F2677A65ECC000",
    22 => x"BFFCEEC2D3A087AC6000",
    23 => x"BFFCD5A0D84C437F4000",
    24 => x"BFFCBC7EDCF7FF524000",
    25 => x"BFFCA35CE1A3BB252000",
    26 => x"BFFC8A3AE64F76F80000",
    27 => x"BFFBE231D5F66595C000",
    28 => x"BFFBAFEDDF4DDD3BC000",
    29 => x"BFFAFB53D14AA9C30000",
    30 => x"BFFA96CBE3F9990E8000",
    31 => x"BFF8C90FDAA221680000",
    32 => x"3FF8C90FDAA221680000",
    33 => x"3FFA96CBE3F9990E8000",
    34 => x"3FFAFB53D14AA9C30000",
    35 => x"3FFBAFEDDF4DDD3BC000",
    36 => x"3FFBE231D5F66595C000",
    37 => x"3FFC8A3AE64F76F80000",
    38 => x"3FFCA35CE1A3BB252000",
    39 => x"3FFCBC7EDCF7FF524000",
    40 => x"3FFCD5A0D84C437F4000",
    41 => x"3FFCEEC2D3A087AC8000",
    42 => x"3FFD83F2677A65ECC000",
    43 => x"3FFD9083652488034000",
    44 => x"3FFD9D1462CEAA19E000",
    45 => x"3FFDA9A56078CC306000",
    46 => x"3FFDB6365E22EE46E000",
    47 => x"3FFDC2C75BCD105D8000",
    48 => x"3FFDCF58597732740000",
    49 => x"3FFDDBE95721548AA000",
    50 => x"3FFDE87A54CB76A12000",
    51 => x"3FFDF50B527598B7A000",
    52 => x"3FFE80CE280FDD672000",
    53 => x"3FFE8716A6E4EE726000",
    54 => x"3FFE8D5F25B9FF7DA000",
    55 => x"3FFE93A7A48F1088F000",
    56 => x"3FFE99F0236421943000",
    57 => x"3FFEA038A239329F8000",
    58 => x"3FFEA681210E43AAC000",
    59 => x"3FFEACC99FE354B60000",
    60 => x"3FFEB3121EB865C15000",
    61 => x"3FFEB95A9D8D76CC9000",
    62 => x"3FFEBFA31C6287D7D000",
    63 => x"3FFEC5EB9B3798E32000"
  );
  constant TRIG_SEED_SIN_INIT : fp80_table64_t := (
     0 => x"BFFEB2C8C92F83C1E800",
     1 => x"BFFEAE3BDDF3280C6000",
     2 => x"BFFEA99414951AACB000",
     3 => x"BFFEA4D224DCD849C000",
     4 => x"BFFE9FF6CA9A2AB6A000",
     5 => x"BFFE9B02C58832CF9800",
     6 => x"BFFE95F6D92FD79F5000",
     7 => x"BFFE90D3CCC99F5AC000",
     8 => x"BFFE8B9A6B1EF6DA4800",
     9 => x"BFFE864B826AEC4C7800",
    10 => x"BFFE80E7E43A61F5B800",
    11 => x"BFFDF6E0CA977BC6B000",
    12 => x"BFFDEBCBBADC371C4800",
    13 => x"BFFDE0924EC008F73800",
    14 => x"BFFDD536415B69FE4800",
    15 => x"BFFDC9B9531DE49EB800",
    16 => x"BFFDBE1D4988EE673800",
    17 => x"BFFDB263EEE9F93E3000",
    18 => x"BFFDA68F1213C73B5000",
    19 => x"BFFD9AA086170C0A9000",
    20 => x"BFFD8E9A21FA66D9F000",
    21 => x"BFFD827DC071BFED7000",
    22 => x"BFFCEC9A7F2A2A188800",
    23 => x"BFFCD415012D80227800",
    24 => x"BFFCBB6ECEF285F99000",
    25 => x"BFFCA2ABB58949F2D000",
    26 => x"BFFC89CF8676D7ABB000",
    27 => x"BFFBE1BC2E3CF6169000",
    28 => x"BFFBAFB68054D520E000",
    29 => x"BFFAFB2B73CFC1071000",
    30 => x"BFFA96C32BACA2AE5800",
    31 => x"BFF8C90E8FE6F63B6000",
    32 => x"3FF8C90E8FE6F63B6000",
    33 => x"3FFA96C32BACA2AE5800",
    34 => x"3FFAFB2B73CFC1071000",
    35 => x"3FFBAFB68054D520E000",
    36 => x"3FFBE1BC2E3CF6169000",
    37 => x"3FFC89CF8676D7ABB000",
    38 => x"3FFCA2ABB58949F2D000",
    39 => x"3FFCBB6ECEF285F99000",
    40 => x"3FFCD415012D80227800",
    41 => x"3FFCEC9A7F2A2A18A000",
    42 => x"3FFD827DC071BFED7000",
    43 => x"3FFD8E9A21FA66D9E000",
    44 => x"3FFD9AA086170C0A9800",
    45 => x"3FFDA68F1213C73B5000",
    46 => x"3FFDB263EEE9F93E2000",
    47 => x"3FFDBE1D4988EE673800",
    48 => x"3FFDC9B9531DE49EB000",
    49 => x"3FFDD536415B69FE5800",
    50 => x"3FFDE0924EC008F73800",
    51 => x"3FFDEBCBBADC371C4000",
    52 => x"3FFDF6E0CA977BC6B000",
    53 => x"3FFE80E7E43A61F5B800",
    54 => x"3FFE864B826AEC4C7000",
    55 => x"3FFE8B9A6B1EF6DA4800",
    56 => x"3FFE90D3CCC99F5AC000",
    57 => x"3FFE95F6D92FD79F5000",
    58 => x"3FFE9B02C58832CF9800",
    59 => x"3FFE9FF6CA9A2AB6A000",
    60 => x"3FFEA4D224DCD849C800",
    61 => x"3FFEA99414951AACB000",
    62 => x"3FFEAE3BDDF3280C5800",
    63 => x"3FFEB2C8C92F83C1E800"
  );
  constant TRIG_SEED_COS_INIT : fp80_table64_t := (
     0 => x"3FFEB73A22A755457800",
     1 => x"3FFEBB8F3AF81B930800",
     2 => x"3FFEBFC7671AB8BB8800",
     3 => x"3FFEC3E2007DD175F800",
     4 => x"3FFEC7DE651F7CA06800",
     5 => x"3FFECBBBF7A63EBA1000",
     6 => x"3FFECF7A1F794D7CA000",
     7 => x"3FFED31848D817D71000",
     8 => x"3FFED695E4F10EA88800",
     9 => x"3FFED9F269F7AAB89000",
    10 => x"3FFEDD2D5339AC869000",
    11 => x"3FFEE046213392AA4800",
    12 => x"3FFEE33C59A4439CD800",
    13 => x"3FFEE60F879FE7E2E000",
    14 => x"3FFEE8BF3BA1F1AEE000",
    15 => x"3FFEEB4B0B9E4F345800",
    16 => x"3FFEEDB29311C504D800",
    17 => x"3FFEEFF573116DF15800",
    18 => x"3FFEF21352595E0BF000",
    19 => x"3FFEF40BDD5A66886800",
    20 => x"3FFEF5DEC646F85BA000",
    21 => x"3FFEF78BC51F239E1000",
    22 => x"3FFEF91297BBB1D6D000",
    23 => x"3FFEFA7301D859796800",
    24 => x"3FFEFBACCD1D0903B800",
    25 => x"3FFEFCBFC926484CD800",
    26 => x"3FFEFDABCB8CAEBA0800",
    27 => x"3FFEFE70AFEB6D33D800",
    28 => x"3FFEFF0E57E5EAD84800",
    29 => x"3FFEFF84AB2C738D6800",
    30 => x"3FFEFFD3977FF7BAE800",
    31 => x"3FFEFFFB10B4DC96D800",
    32 => x"3FFEFFFB10B4DC96D800",
    33 => x"3FFEFFD3977FF7BAE800",
    34 => x"3FFEFF84AB2C738D6800",
    35 => x"3FFEFF0E57E5EAD84800",
    36 => x"3FFEFE70AFEB6D33D800",
    37 => x"3FFEFDABCB8CAEBA0800",
    38 => x"3FFEFCBFC926484CD800",
    39 => x"3FFEFBACCD1D0903B800",
    40 => x"3FFEFA7301D859796800",
    41 => x"3FFEF91297BBB1D6D000",
    42 => x"3FFEF78BC51F239E1000",
    43 => x"3FFEF5DEC646F85BA000",
    44 => x"3FFEF40BDD5A66886800",
    45 => x"3FFEF21352595E0BF000",
    46 => x"3FFEEFF573116DF15800",
    47 => x"3FFEEDB29311C504D800",
    48 => x"3FFEEB4B0B9E4F345800",
    49 => x"3FFEE8BF3BA1F1AEE000",
    50 => x"3FFEE60F879FE7E2E000",
    51 => x"3FFEE33C59A4439CE000",
    52 => x"3FFEE046213392AA4800",
    53 => x"3FFEDD2D5339AC869000",
    54 => x"3FFED9F269F7AAB89000",
    55 => x"3FFED695E4F10EA88800",
    56 => x"3FFED31848D817D71000",
    57 => x"3FFECF7A1F794D7CA000",
    58 => x"3FFECBBBF7A63EBA1000",
    59 => x"3FFEC7DE651F7CA06800",
    60 => x"3FFEC3E2007DD175F800",
    61 => x"3FFEBFC7671AB8BB8800",
    62 => x"3FFEBB8F3AF81B931000",
    63 => x"3FFEB73A22A755457800"
  );
  -- FPSP EXPTBL: 2^(J/64) for J=0..63 (minimax precision)
  constant EXP64_TABLE_INIT : fp80_table64_t := (
     0 => x"3FFF8000000000000000",  1 => x"3FFF8164D1F3BC030774",
     2 => x"3FFF82CD8698AC2BA1D8",  3 => x"3FFF843A28C3ACDE4048",
     4 => x"3FFF85AAC367CC487B14",  5 => x"3FFF871F61969E8D1010",
     6 => x"3FFF88980E8092DA8528",  7 => x"3FFF8A14D575496EFD9C",
     8 => x"3FFF8B95C1E3EA8BD6E8",  9 => x"3FFF8D1ADF5B7E5BA9E4",
    10 => x"3FFF8EA4398B45CD53C0", 11 => x"3FFF9031DC431466B1DC",
    12 => x"3FFF91C3D373AB11C338", 13 => x"3FFF935A2B2F13E6E92C",
    14 => x"3FFF94F4EFA8FEF70960", 15 => x"3FFF96942D3720185A00",
    16 => x"3FFF9837F0518DB8A970", 17 => x"3FFF99E0459320B7FA64",
    18 => x"3FFF9B8D39B9D54E5538", 19 => x"3FFF9D3ED9A72CFFB750",
    20 => x"3FFF9EF5326091A111AC", 21 => x"3FFFA0B0510FB9714FC4",
    22 => x"3FFFA27043030C496818", 23 => x"3FFFA43515AE09E680A0",
    24 => x"3FFFA5FED6A9B15138EC", 25 => x"3FFFA7CD93B4E9653568",
    26 => x"3FFFA9A15AB4EA7C0EF8", 27 => x"3FFFAB7A39B5A93ED338",
    28 => x"3FFFAD583EEA42A14AC8", 29 => x"3FFFAF3B78AD690A4374",
    30 => x"3FFFB123F581D2AC2590", 31 => x"3FFFB311C412A9112488",
    32 => x"3FFFB504F333F9DE6484", 33 => x"3FFFB6FD91E328D17790",
    34 => x"3FFFB8FBAF4762FB9EE8", 35 => x"3FFFBAFF5AB2133E45FC",
    36 => x"3FFFBD08A39F580C36C0", 37 => x"3FFFBF1799B67A731084",
    38 => x"3FFFC12C4CCA66709458", 39 => x"3FFFC346CCDA24976408",
    40 => x"3FFFC5672A115506DADC", 41 => x"3FFFC78D74C8ABB9B15C",
    42 => x"3FFFC9B9BD866E2F27A4", 43 => x"3FFFCBEC14FEF2727C5C",
    44 => x"3FFFCE248C151F8480E4", 45 => x"3FFFD06333DAEF2B2594",
    46 => x"3FFFD2A81D91F12AE45C", 47 => x"3FFFD4F35AABCFEDFA20",
    48 => x"3FFFD744FCCAD69D6AF4", 49 => x"3FFFD99D15C278AFD7B4",
    50 => x"3FFFDBFBB797DAF23754", 51 => x"3FFFDE60F4825E0E9124",
    52 => x"3FFFE0CCDEEC2A94E110", 53 => x"3FFFE33F8972BE8A5A50",
    54 => x"3FFFE5B906E77C8348A8", 55 => x"3FFFE8396A503C4BDC68",
    56 => x"3FFFEAC0C6E7DD243930", 57 => x"3FFFED4F301ED9942B84",
    58 => x"3FFFEFE4B99BDCDAF5CC", 59 => x"3FFFF281773C59FFB138",
    60 => x"3FFFF5257D152486CC2C", 61 => x"3FFFF7D0DF730AD13BB8",
    62 => x"3FFFFA83B2DB722A033C", 63 => x"3FFFFD3E0C0CF486C174"
  );
  constant EXP_SEED_PRE_MUL_INIT : fp80_table64_t := (
     0 => FP80_ONE,
     1 => FP80_LN2,
     2 => FP80_LN10,
    others => FP80_ONE
  );
  constant LOG_SEED_INPUT_ADJ_INIT : fp80_table64_t := (
     0 => FP80_ONE,
     1 => FP80_ZERO,
     2 => FP80_ONE,
     3 => FP80_ONE,
    others => FP80_ZERO
  );
  constant LOG_SEED_POST_SCALE_INIT : fp80_table64_t := (
     0 => FP80_ONE,
     1 => FP80_ONE,
     2 => FP80_INV_LN2,
     3 => FP80_INV_LN10,
    others => FP80_ONE
  );
  -- Table-assisted LOG range reduction: center points c_i = 1 + (2i+1)/128
  constant LOG_CENTER_INIT : fp80_table64_t := (
     0 => x"3FFF8100000000000000",
     1 => x"3FFF8300000000000000",
     2 => x"3FFF8500000000000000",
     3 => x"3FFF8700000000000000",
     4 => x"3FFF8900000000000000",
     5 => x"3FFF8B00000000000000",
     6 => x"3FFF8D00000000000000",
     7 => x"3FFF8F00000000000000",
     8 => x"3FFF9100000000000000",
     9 => x"3FFF9300000000000000",
    10 => x"3FFF9500000000000000",
    11 => x"3FFF9700000000000000",
    12 => x"3FFF9900000000000000",
    13 => x"3FFF9B00000000000000",
    14 => x"3FFF9D00000000000000",
    15 => x"3FFF9F00000000000000",
    16 => x"3FFFA100000000000000",
    17 => x"3FFFA300000000000000",
    18 => x"3FFFA500000000000000",
    19 => x"3FFFA700000000000000",
    20 => x"3FFFA900000000000000",
    21 => x"3FFFAB00000000000000",
    22 => x"3FFFAD00000000000000",
    23 => x"3FFFAF00000000000000",
    24 => x"3FFFB100000000000000",
    25 => x"3FFFB300000000000000",
    26 => x"3FFFB500000000000000",
    27 => x"3FFFB700000000000000",
    28 => x"3FFFB900000000000000",
    29 => x"3FFFBB00000000000000",
    30 => x"3FFFBD00000000000000",
    31 => x"3FFFBF00000000000000",
    32 => x"3FFFC100000000000000",
    33 => x"3FFFC300000000000000",
    34 => x"3FFFC500000000000000",
    35 => x"3FFFC700000000000000",
    36 => x"3FFFC900000000000000",
    37 => x"3FFFCB00000000000000",
    38 => x"3FFFCD00000000000000",
    39 => x"3FFFCF00000000000000",
    40 => x"3FFFD100000000000000",
    41 => x"3FFFD300000000000000",
    42 => x"3FFFD500000000000000",
    43 => x"3FFFD700000000000000",
    44 => x"3FFFD900000000000000",
    45 => x"3FFFDB00000000000000",
    46 => x"3FFFDD00000000000000",
    47 => x"3FFFDF00000000000000",
    48 => x"3FFFE100000000000000",
    49 => x"3FFFE300000000000000",
    50 => x"3FFFE500000000000000",
    51 => x"3FFFE700000000000000",
    52 => x"3FFFE900000000000000",
    53 => x"3FFFEB00000000000000",
    54 => x"3FFFED00000000000000",
    55 => x"3FFFEF00000000000000",
    56 => x"3FFFF100000000000000",
    57 => x"3FFFF300000000000000",
    58 => x"3FFFF500000000000000",
    59 => x"3FFFF700000000000000",
    60 => x"3FFFF900000000000000",
    61 => x"3FFFFB00000000000000",
    62 => x"3FFFFD00000000000000",
    63 => x"3FFFFF00000000000000"
  );
  -- Table-assisted LOG range reduction: 1/c_i (reciprocal, avoids FP division)
  constant LOG_RECIP_CENTER_INIT : fp80_table64_t := (
     0 => x"3FFEFE03F80FE03F80FE",
     1 => x"3FFEFA232CF252138AC0",
     2 => x"3FFEF6603D980F6603DA",
     3 => x"3FFEF2B9D6480F2B9D65",
     4 => x"3FFEEF2EB71FC4345238",
     5 => x"3FFEEBBDB2A5C1619C8C",
     6 => x"3FFEE865AC7B7603A197",
     7 => x"3FFEE525982AF70C880E",
     8 => x"3FFEE1FC780E1FC780E2",
     9 => x"3FFEDEE95C4CA037BA57",
    10 => x"3FFEDBEB61EED19C5958",
    11 => x"3FFED901B2036406C80E",
    12 => x"3FFED62B80D62B80D62C",
    13 => x"3FFED3680D3680D3680D",
    14 => x"3FFED0B69FCBD2580D0B",
    15 => x"3FFECE168A7725080CE1",
    16 => x"3FFECB8727C065C393E0",
    17 => x"3FFEC907DA4E871146AD",
    18 => x"3FFEC6980C6980C6980C",
    19 => x"3FFEC4372F855D824CA6",
    20 => x"3FFEC1E4BBD595F6E947",
    21 => x"3FFEBFA02FE80BFA02FF",
    22 => x"3FFEBD69104707661AA3",
    23 => x"3FFEBB3EE721A54D880C",
    24 => x"3FFEB92143FA36F5E02E",
    25 => x"3FFEB70FBB5A19BE3659",
    26 => x"3FFEB509E68A9B94821F",
    27 => x"3FFEB30F63528917C80B",
    28 => x"3FFEB11FD3B80B11FD3C",
    29 => x"3FFEAF3ADDC680AF3ADE",
    30 => x"3FFEAD602B580AD602B6",
    31 => x"3FFEAB8F69E28359CD11",
    32 => x"3FFEA9C84A47A07F5638",
    33 => x"3FFEA80A80A80A80A80B",
    34 => x"3FFEA655C4392D7B73A8",
    35 => x"3FFEA4A9CF1D96833751",
    36 => x"3FFEA3065E3FAE7CD0E0",
    37 => x"3FFEA16B312EA8FC377D",
    38 => x"3FFE9FD809FD809FD80A",
    39 => x"3FFE9E4CAD23DD5F3A20",
    40 => x"3FFE9CC8E160C3FB19B9",
    41 => x"3FFE9B4C6F9EF03A3CAA",
    42 => x"3FFE99D722DABDE58F06",
    43 => x"3FFE9868C809868C8098",
    44 => x"3FFE97012E025C04B809",
    45 => x"3FFE95A02568095A0257",
    46 => x"3FFE9445809445809446",
    47 => x"3FFE92F113840497889C",
    48 => x"3FFE91A2B3C4D5E6F809",
    49 => x"3FFE905A38633E06C43B",
    50 => x"3FFE8F1779D9FDC3A219",
    51 => x"3FFE8DDA520237694809",
    52 => x"3FFE8CA29C046514E023",
    53 => x"3FFE8B70344A139BC75A",
    54 => x"3FFE8A42F8705669DB46",
    55 => x"3FFE891AC73AE9819B50",
    56 => x"3FFE87F78087F78087F8",
    57 => x"3FFE86D905447A34ACC6",
    58 => x"3FFE85BF37612CEE3C9B",
    59 => x"3FFE84A9F9C8084A9F9D",
    60 => x"3FFE839930523FBE3368",
    61 => x"3FFE828CBFBEB9A020A3",
    62 => x"3FFE81848DA8FAF0D277",
    63 => x"3FFE8080808080808081"
  );
  -- Table-assisted LOG range reduction: ln(c_i)
  constant LOG_LN_CENTER_INIT : fp80_table64_t := (
     0 => x"3FF7FF015358833C4800",
     1 => x"3FF9BDC8D83EAD88D800",
     2 => x"3FFA9CF43DCFF5EB0000",
     3 => x"3FFADA16EB88CB8DF800",
     4 => x"3FFB8B29B7751BD70800",
     5 => x"3FFBA8D839F830C1F800",
     6 => x"3FFBC61A2EB18CD90800",
     7 => x"3FFBE2F2A47ADE3A1800",
     8 => x"3FFBFF64898EDF55D800",
     9 => x"3FFC8DB956A97B3D0000",
    10 => x"3FFC9B8FE100F47BA000",
    11 => x"3FFCA9372F1D0DA1C000",
    12 => x"3FFCB6B07F38CE90E800",
    13 => x"3FFCC3FD032906488800",
    14 => x"3FFCD11DE0FF15AB1800",
    15 => x"3FFCDE1433A16C66B000",
    16 => x"3FFCEAE10B5A7DDC8800",
    17 => x"3FFCF7856E5EE2C9B000",
    18 => x"3FFD82012CA5A6820800",
    19 => x"3FFD882C5FCD7256A800",
    20 => x"3FFD8E44C60B4CCFD800",
    21 => x"3FFD944AD09EF4351800",
    22 => x"3FFD9A3EECD4C3EAA800",
    23 => x"3FFDA0218434353F2000",
    24 => x"3FFDA5F2FCABBBC50800",
    25 => x"3FFDABB3B8BA2AD36000",
    26 => x"3FFDB1641795CE3CA800",
    27 => x"3FFDB70475515D0F2000",
    28 => x"3FFDBC952AFEEA3D1000",
    29 => x"3FFDC2168ED0F458B800",
    30 => x"3FFDC788F439B3163800",
    31 => x"3FFDCCECAC08BF045800",
    32 => x"3FFDD24204872DD85000",
    33 => x"3FFDD78949923BC35800",
    34 => x"3FFDDCC2C4B49887D800",
    35 => x"3FFDE1EEBD3E6D6A6800",
    36 => x"3FFDE70D785C2F9F5800",
    37 => x"3FFDEC1F392C5179F000",
    38 => x"3FFDF12440D3E3613000",
    39 => x"3FFDF61CCE9234660000",
    40 => x"3FFDFB091FD381456000",
    41 => x"3FFDFFE97042BFA4C000",
    42 => x"3FFE825EFCED49369000",
    43 => x"3FFE84C37A7AB9A90800",
    44 => x"3FFE87224C2E8E646000",
    45 => x"3FFE897B8CAC9F7DE000",
    46 => x"3FFE8BCF55DEC4CD0800",
    47 => x"3FFE8E1DC0FB89E12800",
    48 => x"3FFE9066E68C955B7000",
    49 => x"3FFE92AADE74C7BE5800",
    50 => x"3FFE94E9BFF615845800",
    51 => x"3FFE9723A1B720134000",
    52 => x"3FFE995899C890EB8800",
    53 => x"3FFE9B88BDAA3A3DB000",
    54 => x"3FFE9DB4224FFFE11800",
    55 => x"3FFE9FDADC268B7A1000",
    56 => x"3FFEA1FCFF17CE733800",
    57 => x"3FFEA41A9E8F5446F800",
    58 => x"3FFEA633CD7E6771D000",
    59 => x"3FFEA8489E600B435800",
    60 => x"3FFEAA59233CCCA4C000",
    61 => x"3FFEAC656DAE6BCC4800",
    62 => x"3FFEAE6D8EE360BB2800",
    63 => x"3FFEB07197A23C46C800"
  );
  constant ATAN_CENTER_INIT : fp80_table64_t := (
     0 => x"3FF88000000000000000",
     1 => x"3FF9C000000000000000",
     2 => x"3FFAA000000000000000",
     3 => x"3FFAE000000000000000",
     4 => x"3FFB9000000000000000",
     5 => x"3FFBB000000000000000",
     6 => x"3FFBD000000000000000",
     7 => x"3FFBF000000000000000",
     8 => x"3FFC8800000000000000",
     9 => x"3FFC9800000000000000",
    10 => x"3FFCA800000000000000",
    11 => x"3FFCB800000000000000",
    12 => x"3FFCC800000000000000",
    13 => x"3FFCD800000000000000",
    14 => x"3FFCE800000000000000",
    15 => x"3FFCF800000000000000",
    16 => x"3FFD8400000000000000",
    17 => x"3FFD8C00000000000000",
    18 => x"3FFD9400000000000000",
    19 => x"3FFD9C00000000000000",
    20 => x"3FFDA400000000000000",
    21 => x"3FFDAC00000000000000",
    22 => x"3FFDB400000000000000",
    23 => x"3FFDBC00000000000000",
    24 => x"3FFDC400000000000000",
    25 => x"3FFDCC00000000000000",
    26 => x"3FFDD400000000000000",
    27 => x"3FFDDC00000000000000",
    28 => x"3FFDE400000000000000",
    29 => x"3FFDEC00000000000000",
    30 => x"3FFDF400000000000000",
    31 => x"3FFDFC00000000000000",
    32 => x"3FFE8200000000000000",
    33 => x"3FFE8600000000000000",
    34 => x"3FFE8A00000000000000",
    35 => x"3FFE8E00000000000000",
    36 => x"3FFE9200000000000000",
    37 => x"3FFE9600000000000000",
    38 => x"3FFE9A00000000000000",
    39 => x"3FFE9E00000000000000",
    40 => x"3FFEA200000000000000",
    41 => x"3FFEA600000000000000",
    42 => x"3FFEAA00000000000000",
    43 => x"3FFEAE00000000000000",
    44 => x"3FFEB200000000000000",
    45 => x"3FFEB600000000000000",
    46 => x"3FFEBA00000000000000",
    47 => x"3FFEBE00000000000000",
    48 => x"3FFEC200000000000000",
    49 => x"3FFEC600000000000000",
    50 => x"3FFECA00000000000000",
    51 => x"3FFECE00000000000000",
    52 => x"3FFED200000000000000",
    53 => x"3FFED600000000000000",
    54 => x"3FFEDA00000000000000",
    55 => x"3FFEDE00000000000000",
    56 => x"3FFEE200000000000000",
    57 => x"3FFEE600000000000000",
    58 => x"3FFEEA00000000000000",
    59 => x"3FFEEE00000000000000",
    60 => x"3FFEF200000000000000",
    61 => x"3FFEF600000000000000",
    62 => x"3FFEFA00000000000000",
    63 => x"3FFEFE00000000000000"
  );
  constant ATAN_SEED_OFFSET_INIT : fp80_table64_t := (
     0 => x"3FF7FFFEAAADDDD4B800",
     1 => x"3FF9BFF700C252E1B000",
     2 => x"3FFA9FEB2F8B4E4EC800",
     3 => x"3FFADFC6EF89CE222000",
     4 => x"3FFB8FC36DF8416AC800",
     5 => x"3FFBAF91927E96BD9000",
     6 => x"3FFBCF4A0A9E7EE78800",
     7 => x"3FFBEEE90B80F5D37000",
     8 => x"3FFC87356E67A0441000",
     9 => x"3FFC96E5ED97DD0FF800",
    10 => x"3FFCA6843D4ED278B800",
    11 => x"3FFCB60EA44C499EC800",
    12 => x"3FFCC58377143CE14800",
    13 => x"3FFCD4E118DA0193C800",
    14 => x"3FFCE425FC53A1737000",
    15 => x"3FFCF350A474B7626800",
    16 => x"3FFD812FD288332DB000",
    17 => x"3FFD88A8D1B1218E5000",
    18 => x"3FFD9012AB3F23E4B000",
    19 => x"3FFD976CC3D411E7F000",
    20 => x"3FFD9EB689493889A000",
    21 => x"3FFDA5EF72C344873800",
    22 => x"3FFDAD1700BAF07A7000",
    23 => x"3FFDB42CBCFAFD37F000",
    24 => x"3FFDBB303A940BA81000",
    25 => x"3FFDC22115C6FCAEB800",
    26 => x"3FFDC8FEF3E686331000",
    27 => x"3FFDCFC98330B4001000",
    28 => x"3FFDD6807AA1102C6000",
    29 => x"3FFDDD2399BC31252800",
    30 => x"3FFDE3B2A8556B8FC800",
    31 => x"3FFDEA2D764F64315800",
    32 => x"3FFDF093DB583A258000",
    33 => x"3FFDF6E5B6A1FC21A800",
    34 => x"3FFDFD22EE981492C800",
    35 => x"3FFE81A5B84928244000",
    36 => x"3FFE84AF98430D2C8000",
    37 => x"3FFE87AF145B3F14A800",
    38 => x"3FFE8AA42CB1BB235000",
    39 => x"3FFE8D8EE43C82142800",
    40 => x"3FFE906F409F411D9000",
    41 => x"3FFE93454A034B6D3000",
    42 => x"3FFE96110AF012233000",
    43 => x"3FFE98D2902443A5F000",
    44 => x"3FFE9B89E86FB6282000",
    45 => x"3FFE9E37248E3C6E2000",
    46 => x"3FFEA0DA57037F520800",
    47 => x"3FFEA37393F7F238B000",
    48 => x"3FFEA602F116F4A72000",
    49 => x"3FFEA888856E2F6C0800",
    50 => x"3FFEAB04694E3861A000",
    51 => x"3FFEAD76B62C84A8B800",
    52 => x"3FFEAFDF8686AE625000",
    53 => x"3FFEB23EF5C7105C8000",
    54 => x"3FFEB495202AB7DB5000",
    55 => x"3FFEB6E222A8AA9D7800",
    56 => x"3FFEB9261ADA7D73D800",
    57 => x"3FFEBB6126E636360000",
    58 => x"3FFEBD9365697287F000",
    59 => x"3FFEBFBCF565CBC4C000",
    60 => x"3FFEC1DDF62E6F711000",
    61 => x"3FFEC3F68756E2D15000",
    62 => x"3FFEC606C8A2E7A4E800",
    63 => x"3FFEC80ED9F7778C3800"
  );

  signal state_reg : trig_state_t := ST_IDLE;
  signal cont_state_reg : trig_state_t := ST_IDLE;
  signal a_settle_count_reg : natural range 0 to 5 := 0;
  signal a_settle_return_reg : trig_state_t := ST_CLASSIFY;

  signal op_reg : fpu_op_t := FPU_OP_NOP;
  signal a_reg : fp80_t := (others => '0');
  signal rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;

  signal x_reg : fp80_t := (others => '0');
  signal r_reg : fp80_t := (others => '0');
  signal s_reg : fp80_t := (others => '0');
  signal c_reg : fp80_t := (others => '0');
  signal poly_reg : fp80_t := (others => '0');
  signal tmp_reg : fp80_t := (others => '0');
  signal fintrz_tmp : fp80_t;
  signal fgetman_a : fp80_t;
  signal fgetman_tmp : fp80_t;
  signal result_reg : fp80_t := (others => '0');
  signal aux_result_reg : fp80_t := (others => '0');
  signal done_reg : std_logic := '0';
  signal aux_valid_reg : std_logic := '0';
  signal flag_divzero_reg : std_logic := '0';

  signal coeff_set_reg : integer range 0 to 5 := COEFF_SET_EXP;
  signal coeff_rom_sig : fp80_table60_t := COEFF_ROM_INIT;
  signal coeff_rom_addr_reg : integer range 0 to 59 := 0;
  signal coeff_rom_q : fp80_t := (others => '0');
  signal coeff0_override_en_reg : std_logic := '0';
  signal coeff0_override_reg : fp80_t := (others => '0');
  signal poly_degree_reg : integer range 0 to 9 := 5;
  signal poly_idx_reg : integer range 0 to 9 := 0;
  signal poly_init_flag : std_logic := '0';
  signal q_fp_reg : fp80_t := (others => '0');
  signal q_mod_reg : integer range 0 to 3 := 0;
  signal seed_idx_reg : integer range 0 to 63 := 0;
  signal seed_domain_reg : seed_domain_t := SEED_DOMAIN_TRIG;
  signal seed_return_state_reg : trig_state_t := ST_IDLE;
  signal seed_center_reg : fp80_t := (others => '0');
  signal seed_sin_reg : fp80_t := (others => '0');
  signal seed_cos_reg : fp80_t := (others => '0');
  signal seed_delta_reg : fp80_t := (others => '0');
  signal seed_delta2_reg : fp80_t := (others => '0');
  signal seed_aux0_reg : fp80_t := (others => '0');
  signal seed_aux1_reg : fp80_t := (others => '0');
  signal trig_seed_addr_reg : integer range 0 to 63 := 0;
  signal aux_seed_addr_reg : integer range 0 to 63 := 0;
  signal trig_seed_center_q : fp80_t := (others => '0');
  signal trig_seed_sin_q : fp80_t := (others => '0');
  signal trig_seed_cos_q : fp80_t := (others => '0');
  signal exp_seed_pre_mul_q : fp80_t := (others => '0');
  signal log_seed_input_adj_q : fp80_t := (others => '0');
  signal log_seed_post_scale_q : fp80_t := (others => '0');
  signal atan_seed_offset_q : fp80_t := (others => '0');
  signal atan_center_q : fp80_t := (others => '0');

  signal trig_seed_center_rom : fp80_table64_t := TRIG_SEED_CENTER_INIT;
  signal trig_seed_sin_rom : fp80_table64_t := TRIG_SEED_SIN_INIT;
  signal trig_seed_cos_rom : fp80_table64_t := TRIG_SEED_COS_INIT;
  signal exp_seed_pre_mul_rom : fp80_table64_t := EXP_SEED_PRE_MUL_INIT;
  signal log_seed_input_adj_rom : fp80_table64_t := LOG_SEED_INPUT_ADJ_INIT;
  signal log_seed_post_scale_rom : fp80_table64_t := LOG_SEED_POST_SCALE_INIT;
  signal atan_center_rom : fp80_table64_t := ATAN_CENTER_INIT;
  signal atan_seed_offset_rom : fp80_table64_t := ATAN_SEED_OFFSET_INIT;
  signal exp64_table_rom : fp80_table64_t := EXP64_TABLE_INIT;
  signal log_center_rom : fp80_table64_t := LOG_CENTER_INIT;
  signal log_ln_center_rom : fp80_table64_t := LOG_LN_CENTER_INIT;
  signal log_recip_center_rom : fp80_table64_t := LOG_RECIP_CENTER_INIT;
  attribute rom_style : string;
  attribute rom_style of trig_seed_center_rom : signal is "block";
  attribute rom_style of trig_seed_sin_rom : signal is "block";
  attribute rom_style of trig_seed_cos_rom : signal is "block";
  attribute rom_style of exp_seed_pre_mul_rom : signal is "block";
  attribute rom_style of log_seed_input_adj_rom : signal is "block";
  attribute rom_style of log_seed_post_scale_rom : signal is "block";
  attribute rom_style of atan_center_rom : signal is "block";
  attribute rom_style of atan_seed_offset_rom : signal is "block";
  attribute rom_style of log_center_rom : signal is "block";
  attribute rom_style of log_ln_center_rom : signal is "block";
  attribute rom_style of log_recip_center_rom : signal is "block";
  attribute rom_style of exp64_table_rom : signal is "block";
  attribute rom_style of coeff_rom_sig : signal is "block";

  signal exp64_table_addr_reg : integer range 0 to 63 := 0;
  signal exp64_table_q : fp80_t := (others => '0');
  signal exp64_n_int_reg : integer := 0;  -- N = nint(x * 64/ln2)

  signal log_table_addr_reg : integer range 0 to 63 := 0;
  signal log_center_q : fp80_t := (others => '0');
  signal log_ln_center_q : fp80_t := (others => '0');
  signal log_recip_center_q : fp80_t := (others => '0');

  signal trans_pre_mul_en_reg : std_logic := '0';
  signal trans_pre_mul_const_reg : fp80_t := (others => '0');
  signal trans_input_adjust_en_reg : std_logic := '0';
  signal trans_input_adjust_sub_reg : std_logic := '0';
  signal trans_input_adjust_const_reg : fp80_t := (others => '0');
  signal trans_post_mul_en_reg : std_logic := '0';
  signal trans_post_mul_const_reg : fp80_t := (others => '0');
  signal trans_post_add_en_reg : std_logic := '0';
  signal trans_post_add_sub_reg : std_logic := '0';
  signal trans_post_add_const_reg : fp80_t := (others => '0');
  signal exp_reduce_en_reg : std_logic := '0';
  signal exp_reduce_done_reg : std_logic := '0';
  signal exp_k_reg : fp80_t := (others => '0');
  signal log_exp_term_reg : fp80_t := (others => '0');
  signal log_unbiased_exp_reg : integer range (2 - FP_EXP_BIAS - FP_MANT_WIDTH) to FP_EXP_BIAS := 0;
  signal log_exp_term_zero_reg : std_logic := '1';
  signal log_exp_add_en_reg : std_logic := '0';
  signal log_scale_reg : fp80_t := FP80_LN2;

  signal mul_a_reg : fp80_t := (others => '0');
  signal mul_b_reg : fp80_t := (others => '0');
  signal mul_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal mul_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;
  signal add_a_reg : fp80_t := (others => '0');
  signal add_b_reg : fp80_t := (others => '0');
  signal add_sub_reg : boolean := false;
  signal add_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal add_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;
  signal div_a_reg : fp80_t := (others => '0');
  signal div_b_reg : fp80_t := (others => '0');
  signal div_rm_reg : fp_round_mode_t := FP_RND_NEAREST;
  signal div_rp_reg : fp_round_prec_t := FP_PREC_EXTENDED;
  signal trig_divrem_op_reg : fpu_op_t := FPU_OP_DIV;
  signal trig_div_start_reg : std_logic := '0';
  signal trig_div_busy : std_logic := '0';
  signal trig_div_done : std_logic := '0';
  signal trig_div_result : fp80_t := (others => '0');
  signal trig_div_flag_divzero : std_logic := '0';

  signal atan_neg_reg : std_logic := '0';
  signal atan_recip_reg : std_logic := '0';
  signal acos_neg_input_reg : std_logic := '0';


  signal trig_mul_start_reg : std_logic := '0';
  signal trig_mul_busy      : std_logic;
  signal trig_mul_done      : std_logic;
  signal trig_mul_result    : fp80_t;

  signal trig_add_start_reg : std_logic := '0';
  signal trig_add_busy      : std_logic;
  signal trig_add_done      : std_logic;
  signal trig_add_result    : fp80_t;

  -- Serialized FP execution control for shared trig FP micro-ops.
  signal fp_exec_busy_reg : std_logic := '0';

  function canonical_nan(value : fp80_t) return fp80_t is
    variable res : fp80_t := value;
  begin
    res(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH) := (others => '1');
    res(FP_MANT_WIDTH-1) := '1';
    if unsigned(res(FP_MANT_WIDTH-2 downto 0)) = 0 then
      -- FPCP-created NaN: all mantissa bits set per datasheet.
      res(FP_MANT_WIDTH-2 downto 0) := (others => '1');
    end if;
    return res;
  end function;

  function is_legacy_trig(op : fpu_op_t) return boolean is
  begin
    return op = FPU_OP_SIN or op = FPU_OP_COS or op = FPU_OP_TAN or op = FPU_OP_SINCOS;
  end function;

  function fp80_sign(value : fp80_t) return std_logic is
  begin
    return value(FP_WIDTH-1);
  end function;

  function clamp_seed_index(value : integer) return integer is
  begin
    if value < 0 then
      return 0;
    elsif value > 63 then
      return 63;
    else
      return value;
    end if;
  end function;

  function fp80_int_mod4(value : fp80_t) return integer is
    variable exp_bits : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable exp_i : integer := 0;
    variable idx0 : integer := 0;
    variable idx1 : integer := 0;
    variable bit0 : integer := 0;
    variable bit1 : integer := 0;
    variable mag_mod : integer := 0;
  begin
    exp_bits := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
    if exp_bits = 0 or exp_bits = to_unsigned(32767, FP_EXP_WIDTH) then
      return 0;
    end if;

    exp_i := to_integer(exp_bits) - FP_EXP_BIAS;
    if exp_i < 0 then
      return 0;
    end if;

    -- Always derive low modulo bits from aligned mantissa indices.
    -- For exp_i = 64, idx1 = 0 still contributes to the 2's bit.
    idx0 := integer(FP_MANT_WIDTH - 1) - exp_i;
    idx1 := idx0 + 1;
    if idx0 >= 0 and idx0 < integer(FP_MANT_WIDTH) and value(idx0) = '1' then
      bit0 := 1;
    end if;
    if idx1 >= 0 and idx1 < integer(FP_MANT_WIDTH) and value(idx1) = '1' then
      bit1 := 1;
    end if;

    mag_mod := bit0 + (2 * bit1);
    if value(FP_WIDTH-1) = '1' and mag_mod /= 0 then
      return 4 - mag_mod;
    end if;
    return mag_mod;
  end function;

  function fgetexp_unbiased_int(value : fp80_t) return integer is
    variable exp_bits : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable unbiased_exp : integer := 0;
  begin
    -- Log setup only needs finite/non-zero behavior; keep special classes inert.
    if fp80_is_zero(value) or fp80_is_nan(value) or fp80_is_inf(value) then
      return 0;
    end if;

    exp_bits := unsigned(value(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));

    if exp_bits = 0 then
      -- Subnormal: unbiased exponent adjusted by leading zero count.
      unbiased_exp := 1 - FP_EXP_BIAS - clz(unsigned(value(FP_MANT_WIDTH-1 downto 0)));
    else
      unbiased_exp := to_integer(exp_bits) - FP_EXP_BIAS;
    end if;

    return unbiased_exp;
  end function;

  -- Save/restore shadow register array (11 words: full tmp_reg needs 3 words).
  type save_array_t is array (0 to 10) of std_logic_vector(31 downto 0);
  signal shadow_regs : save_array_t := (others => (others => '0'));

begin
  trig_div_inst : entity work.mc68881_divrem_unit
    generic map (
      enable_modrem_post => false
    )
    port map (
      clk     => clk,
      reset_n => reset_n,
      start   => trig_div_start_reg,
      op_sel  => trig_divrem_op_reg,
      a_in    => div_a_reg,
      b_in    => div_b_reg,
      round_mode => div_rm_reg,
      round_prec => div_rp_reg,
      busy    => trig_div_busy,
      done    => trig_div_done,
      result  => trig_div_result,
      quotient_byte  => open,
      quotient_valid => open,
      flag_invalid   => open,
      flag_divzero   => trig_div_flag_divzero,
      flag_overflow  => open,
      flag_underflow => open,
      flag_inexact   => open,
      modrem_fp_mul_start  => open,
      modrem_fp_mul_a      => open,
      modrem_fp_mul_b      => open,
      modrem_fp_mul_done   => '0',
      modrem_fp_mul_result => (others => '0'),
      modrem_fp_add_start  => open,
      modrem_fp_add_a      => open,
      modrem_fp_add_b      => open,
      modrem_fp_add_sub    => open,
      modrem_fp_add_rm     => open,
      modrem_fp_add_rp     => open,
      modrem_fp_add_done   => '0',
      modrem_fp_add_result => (others => '0'),
      save_req       => '0',
      save_data      => open,
      save_addr      => 0,
      restore_req    => '0',
      restore_data   => (others => '0'),
      restore_addr   => 0,
      restore_wr     => '0'
    );

  trig_mul_inst : entity work.mc68881_fp80_mul_unit
    port map (
      clk        => clk,
      reset_n    => reset_n,
      start      => trig_mul_start_reg,
      a_in       => mul_a_reg,
      b_in       => mul_b_reg,
      round_mode => mul_rm_reg,
      round_prec => mul_rp_reg,
      busy       => trig_mul_busy,
      done       => trig_mul_done,
      result     => trig_mul_result
    );

  trig_add_inst : entity work.mc68881_fp80_addsub_unit
    port map (
      clk        => clk,
      reset_n    => reset_n,
      start      => trig_add_start_reg,
      a_in       => add_a_reg,
      b_in       => add_b_reg,
      subtract   => add_sub_reg,
      round_mode => add_rm_reg,
      round_prec => add_rp_reg,
      busy       => trig_add_busy,
      done       => trig_add_done,
      result     => trig_add_result
    );

  trig_seed_read_proc : process(clk)
  begin
    if rising_edge(clk) then
      trig_seed_center_q <= trig_seed_center_rom(trig_seed_addr_reg);
      trig_seed_sin_q <= trig_seed_sin_rom(trig_seed_addr_reg);
      trig_seed_cos_q <= trig_seed_cos_rom(trig_seed_addr_reg);
      exp_seed_pre_mul_q <= exp_seed_pre_mul_rom(aux_seed_addr_reg);
      log_seed_input_adj_q <= log_seed_input_adj_rom(aux_seed_addr_reg);
      log_seed_post_scale_q <= log_seed_post_scale_rom(aux_seed_addr_reg);
      atan_seed_offset_q <= atan_seed_offset_rom(aux_seed_addr_reg);
      atan_center_q <= atan_center_rom(aux_seed_addr_reg);
      exp64_table_q <= exp64_table_rom(exp64_table_addr_reg);
      log_center_q <= log_center_rom(log_table_addr_reg);
      log_ln_center_q <= log_ln_center_rom(log_table_addr_reg);
      log_recip_center_q <= log_recip_center_rom(log_table_addr_reg);
      coeff_rom_q <= coeff_rom_sig(coeff_rom_addr_reg);
    end if;
  end process;

  -- Shared combinational de-duplicated functions
  fintrz_tmp <= fintrz_fp80(tmp_reg);
  fgetman_a <= fgetman_fp80(a_reg);
  fgetman_tmp <= fgetman_fp80(tmp_reg);

  process(clk, reset_n)
    variable abs_a : fp80_t;
    variable exp_bits : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable frac : fp80_t;
    variable q_mod_local : integer;
    variable sin_res : fp80_t;
    variable cos_res : fp80_t;
    variable combined : fp80_t;
    variable r_clamped : fp80_t;
    variable coeff_sel : fp80_t;
    variable x_local : fp80_t;
    variable z_local : fp80_t;
    variable unbiased_exp_local : integer;
    variable abs_a_gt_one : boolean;
    variable a_exp_v : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable a_mant_v : unsigned(63 downto 0);
    variable frac_abs_ge_half : boolean;
    variable v_exp : unsigned(FP_EXP_WIDTH-1 downto 0);
    variable v_mant : unsigned(63 downto 0);
  begin
    if reset_n = '0' then
      state_reg <= ST_IDLE;
      a_settle_count_reg <= 0;
      a_settle_return_reg <= ST_CLASSIFY;
      done_reg <= '0';
      aux_valid_reg <= '0';
      flag_divzero_reg <= '0';
      result_reg <= (others => '0');
      aux_result_reg <= (others => '0');
      x_reg <= (others => '0');
      poly_reg <= (others => '0');
      tmp_reg <= (others => '0');
      poly_idx_reg <= 0;
      poly_degree_reg <= 5;
      coeff_set_reg <= COEFF_SET_EXP;
      coeff_rom_addr_reg <= 0;
      coeff0_override_en_reg <= '0';
      coeff0_override_reg <= (others => '0');
      q_fp_reg <= (others => '0');
      q_mod_reg <= 0;
      seed_idx_reg <= 0;
      seed_domain_reg <= SEED_DOMAIN_TRIG;
      seed_return_state_reg <= ST_IDLE;
      seed_center_reg <= (others => '0');
      seed_sin_reg <= (others => '0');
      seed_cos_reg <= (others => '0');
      seed_delta_reg <= (others => '0');
      seed_delta2_reg <= (others => '0');
      seed_aux0_reg <= (others => '0');
      seed_aux1_reg <= (others => '0');
      trig_seed_addr_reg <= 0;
      log_table_addr_reg <= 0;
      r_reg <= (others => '0');
      s_reg <= (others => '0');
      c_reg <= (others => '0');
      trans_input_adjust_en_reg <= '0';
      trans_input_adjust_sub_reg <= '0';
      trans_input_adjust_const_reg <= (others => '0');
      trans_pre_mul_en_reg <= '0';
      trans_pre_mul_const_reg <= (others => '0');
      trans_post_mul_en_reg <= '0';
      trans_post_mul_const_reg <= (others => '0');
      trans_post_add_en_reg <= '0';
      trans_post_add_sub_reg <= '0';
      trans_post_add_const_reg <= (others => '0');
      exp_reduce_en_reg <= '0';
      exp_reduce_done_reg <= '0';
      exp_k_reg <= (others => '0');
      log_exp_term_reg <= (others => '0');
      log_unbiased_exp_reg <= 0;
      log_exp_term_zero_reg <= '1';
      log_exp_add_en_reg <= '0';
      div_a_reg <= (others => '0');
      div_b_reg <= (others => '0');
      fp_exec_busy_reg <= '0';
      trig_div_start_reg <= '0';
      trig_mul_start_reg <= '0';
      trig_add_start_reg <= '0';
      trig_divrem_op_reg <= FPU_OP_DIV;
      atan_neg_reg <= '0';
      atan_recip_reg <= '0';
      acos_neg_input_reg <= '0';
    elsif rising_edge(clk) then
      done_reg <= '0';
      aux_valid_reg <= '0';
      trig_div_start_reg <= '0';
      trig_mul_start_reg <= '0';
      trig_add_start_reg <= '0';
      case state_reg is
        when ST_IDLE =>
          if start = '1' then
            op_reg <= op_sel;
            a_reg <= a_in;
            rm_reg <= round_mode;
            rp_reg <= round_prec;
            flag_divzero_reg <= '0';
            a_settle_count_reg <= 5;
            a_settle_return_reg <= ST_CLASSIFY;
            state_reg <= ST_A_SETTLE;
          end if;

        when ST_A_SETTLE =>
          -- Wait for a_reg combinational fan-out (fgetexp, fgetman, abs, etc.)
          -- to settle before sampling derived values.
          -- 7-cycle MCP: a_reg clocked in ST_IDLE (cycle 0), 6 settle cycles,
          -- then a_settle_return_reg (ST_CLASSIFY or ST_LOG_GETEXP).
          if a_settle_count_reg = 0 then
            state_reg <= a_settle_return_reg;
          else
            a_settle_count_reg <= a_settle_count_reg - 1;
          end if;

        when ST_CLASSIFY =>
          abs_a := abs_fp80(a_reg);
          -- Pre-compute |a| > 1.0 using direct field comparison (replaces 4 compare_fp80 calls)
          a_exp_v := unsigned(abs_a(78 downto 64));
          a_mant_v := unsigned(abs_a(63 downto 0));
          abs_a_gt_one := a_exp_v > to_unsigned(FP_EXP_BIAS, FP_EXP_WIDTH)
                       or (a_exp_v = to_unsigned(FP_EXP_BIAS, FP_EXP_WIDTH)
                           and a_mant_v > x"8000000000000000");
          trans_input_adjust_en_reg <= '0';
          trans_input_adjust_sub_reg <= '0';
          trans_input_adjust_const_reg <= FP80_ZERO;
          trans_pre_mul_en_reg <= '0';
          trans_post_mul_en_reg <= '0';
          trans_post_add_en_reg <= '0';
          trans_post_add_sub_reg <= '0';
          trans_pre_mul_const_reg <= FP80_ZERO;
          trans_post_mul_const_reg <= FP80_ZERO;
          trans_post_add_const_reg <= FP80_ZERO;
          exp_reduce_en_reg <= '0';
          exp_reduce_done_reg <= '0';
          exp_k_reg <= FP80_ZERO;
          log_exp_add_en_reg <= '0';
          seed_domain_reg <= SEED_DOMAIN_EXP;
          seed_idx_reg <= 0;
          seed_return_state_reg <= ST_TRANS_PREP;
          aux_result_reg <= FP80_ZERO;

          if is_legacy_trig(op_reg) then
            exp_bits := unsigned(a_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
              if exp_bits = to_unsigned(32767, FP_EXP_WIDTH) and fp80_is_nan(a_reg) then
                -- NaN input: quiet and preserve payload
                result_reg <= fp80_quiet_nan(a_reg);
                if op_reg = FPU_OP_SINCOS then
                  aux_result_reg <= fp80_quiet_nan(a_reg);
                  aux_valid_reg <= '1';
                end if;
                state_reg <= ST_DONE;
              elsif exp_bits = to_unsigned(32767, FP_EXP_WIDTH) then
                -- Infinity input: domain error, canonical QNaN
                result_reg <= canonical_nan(FP80_ZERO);
                if op_reg = FPU_OP_SINCOS then
                  aux_result_reg <= canonical_nan(FP80_ZERO);
                  aux_valid_reg <= '1';
                end if;
                state_reg <= ST_DONE;
              elsif a_reg = FP80_ZERO then
                s_reg <= FP80_ZERO;
                c_reg <= FP80_ONE;
                q_mod_reg <= 0;
                state_reg <= ST_TRIG_RECONSTRUCT;
              elsif a_reg = FP80_HALF_PI then
                s_reg <= FP80_ONE;
                c_reg <= FP80_ZERO;
                q_mod_reg <= 0;
                state_reg <= ST_TRIG_RECONSTRUCT;
              elsif a_reg = FP80_NEG_HALF_PI then
                s_reg <= FP80_NEG_ONE;
                c_reg <= FP80_ZERO;
                q_mod_reg <= 0;
                state_reg <= ST_TRIG_RECONSTRUCT;
              elsif a_reg = FP80_PI then
                s_reg <= FP80_ZERO;
                c_reg <= FP80_NEG_ONE;
                q_mod_reg <= 0;
                state_reg <= ST_TRIG_RECONSTRUCT;
              elsif exp_bits /= 0 and to_integer(exp_bits) < FP_EXP_BIAS - 32 then
                c_reg <= FP80_ONE;
                q_mod_reg <= 0;
                add_a_reg <= a_reg;
                add_b_reg <= FP80_ZERO;
                add_sub_reg <= false;
                add_rm_reg <= rm_reg;
                add_rp_reg <= rp_reg;
                cont_state_reg <= ST_TRIG_TINY_ROUND_POST;
                state_reg <= ST_FP_ADD;
              else
                x_reg <= a_reg;
                state_reg <= ST_TRIG_REDUCE;
              end if;
          elsif fp80_is_nan(a_reg) then
            result_reg <= fp80_quiet_nan(a_reg);
            state_reg <= ST_DONE;
          else
            coeff0_override_en_reg <= '0';
            poly_degree_reg <= 5;
            x_local := a_reg;

            case op_reg is
              when FPU_OP_ETOX =>
                if fp80_is_inf(a_reg) then
                  if fp80_sign(a_reg) = '1' then
                    result_reg <= FP80_ZERO;
                  else
                    result_reg <= FP80_POS_INF;
                  end if;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ONE;
                  state_reg <= ST_DONE;
                else
                  -- EXP via 2^(J/64) decomposition (FPSP algorithm):
                  -- N = nint(x * 64/ln2), J = N mod 64, M = (N-J)/64
                  -- R = x - N*(ln2/64), |R| <= ln2/128 ~ 0.0054
                  -- exp(x) = 2^M * EXPTBL[J] * exp(R)
                  -- exp(R) = minimax degree 6 polynomial
                  exp_reduce_en_reg <= '1';
                  exp_reduce_done_reg <= '1';  -- skip old CW reduction
                  coeff_set_reg <= COEFF_SET_EXP64;
                  poly_degree_reg <= 6;
                  trans_post_mul_en_reg <= '1';  -- will multiply by EXPTBL[J]
                  x_reg <= x_local;
                  -- Start: compute N = nint(x * 64/ln(2))
                  mul_a_reg <= x_local;
                  mul_b_reg <= FP80_64_INV_LN2;
                  mul_rm_reg <= FP_RND_NEAREST;
                  mul_rp_reg <= FP_PREC_EXTENDED;
                  cont_state_reg <= ST_EXP64_N_ROUND;
                  state_reg <= ST_FP_MUL;
                end if;

              when FPU_OP_ETOXM1 =>
                if fp80_is_inf(a_reg) then
                  if fp80_sign(a_reg) = '1' then
                    result_reg <= FP80_NEG_ONE;
                  else
                    result_reg <= FP80_POS_INF;
                  end if;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  -- ETOXM1 via 2^(J/64) decomposition, then subtract 1
                  exp_reduce_en_reg <= '1';
                  exp_reduce_done_reg <= '1';
                  coeff_set_reg <= COEFF_SET_EXP64;
                  poly_degree_reg <= 6;
                  trans_post_mul_en_reg <= '1';  -- multiply by EXPTBL[J]
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  trans_post_add_const_reg <= FP80_NEG_ONE;
                  x_reg <= x_local;
                  mul_a_reg <= x_local;
                  mul_b_reg <= FP80_64_INV_LN2;
                  mul_rm_reg <= FP_RND_NEAREST;
                  mul_rp_reg <= FP_PREC_EXTENDED;
                  cont_state_reg <= ST_EXP64_N_ROUND;
                  state_reg <= ST_FP_MUL;
                end if;

              when FPU_OP_TWOTOX =>
                if fp80_is_inf(a_reg) then
                  if fp80_sign(a_reg) = '1' then
                    result_reg <= FP80_ZERO;
                  else
                    result_reg <= FP80_POS_INF;
                  end if;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ONE;
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_ONE then
                  result_reg <= FP80_TWO;
                  state_reg <= ST_DONE;
                else
                  -- Direct 2^x: k=round(x), r=x-k, exp(r*ln2)*2^k
                  -- Skips redundant pre-multiply by ln(2) then divide by ln(2).
                  exp_reduce_en_reg <= '1';
                  exp_reduce_done_reg <= '1';  -- skip EXP CW reduction
                  coeff_set_reg <= COEFF_SET_EXP;
                  poly_degree_reg <= 9;
                  x_reg <= x_local;
                  state_reg <= ST_TWOTOX_ROUND;
                end if;

              when FPU_OP_TENTOX =>
                if fp80_is_inf(a_reg) then
                  if fp80_sign(a_reg) = '1' then
                    result_reg <= FP80_ZERO;
                  else
                    result_reg <= FP80_POS_INF;
                  end if;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ONE;
                  state_reg <= ST_DONE;
                else
                  -- Direct 10^x: y=x*log2(10), k=round(y), r=y-k, exp(r*ln2)*2^k
                  -- Replaces pre-multiply by ln(10) + EXP reduction INV_LN2 with
                  -- single multiply by log2(10), saving 1 FP multiply + CW chain.
                  exp_reduce_en_reg <= '1';
                  exp_reduce_done_reg <= '1';  -- skip EXP CW reduction
                  coeff_set_reg <= COEFF_SET_EXP;
                  poly_degree_reg <= 9;
                  x_reg <= x_local;
                  -- Multiply x by log2(10), then route to TWOTOX path
                  mul_a_reg <= x_local;
                  mul_b_reg <= FP80_LOG2_10;
                  mul_rm_reg <= FP_RND_NEAREST;
                  mul_rp_reg <= FP_PREC_EXTENDED;
                  cont_state_reg <= ST_TWOTOX_ROUND;
                  state_reg <= ST_FP_MUL;
                end if;

              when FPU_OP_LOGN =>
                if fp80_is_inf(a_reg) and fp80_sign(a_reg) = '0' then
                  result_reg <= FP80_POS_INF;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  -- DZ: log(0) = -infinity per datasheet.
                  result_reg <= FP80_NEG_INF;
                  state_reg <= ST_DONE;
                elsif fp80_sign(a_reg) = '1' then
                  result_reg <= canonical_nan(FP80_ZERO);
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_ONE then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  -- Defer heavy fgetexp/fgetman to ST_LOG_GETEXP (7-cycle MCP).
                  log_scale_reg <= FP80_LN2;
                  log_exp_add_en_reg <= '1';
                  coeff_set_reg <= COEFF_SET_LOG;
                  poly_degree_reg <= 9;
                  trans_input_adjust_en_reg <= '1';
                  trans_input_adjust_sub_reg <= '1';
                  trans_post_mul_en_reg <= '1';
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  seed_domain_reg <= SEED_DOMAIN_LOG;
                  seed_idx_reg <= 0;
                  seed_return_state_reg <= ST_LOG_TABLE_INDEX;
                  state_reg <= ST_LOG_GETEXP;
                end if;

              when FPU_OP_LOGNP1 =>
                if fp80_is_inf(a_reg) and fp80_sign(a_reg) = '0' then
                  result_reg <= FP80_POS_INF;
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_NEG_ONE then
                  -- Singularity: log(1 + (-1)) = log(0) = -infinity, DZ.
                  result_reg <= FP80_NEG_INF;
                  flag_divzero_reg <= '1';
                  state_reg <= ST_DONE;
                elsif a_reg(FP_WIDTH-1) = '1' and abs_a_gt_one then
                  result_reg <= canonical_nan(FP80_ZERO);
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  -- Route z = a + 1 through shared FP add engine.
                  add_a_reg <= a_reg;
                  add_b_reg <= FP80_ONE;
                  add_sub_reg <= false;
                  add_rm_reg <= FP_RND_NEAREST;
                  add_rp_reg <= FP_PREC_EXTENDED;
                  log_scale_reg <= FP80_LN2;
                  cont_state_reg <= ST_LOGNP1_Z_POST;
                  state_reg <= ST_FP_ADD;
                end if;

              when FPU_OP_LOG2 =>
                if fp80_is_inf(a_reg) and fp80_sign(a_reg) = '0' then
                  result_reg <= FP80_POS_INF;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  -- DZ: log2(0) = -infinity per datasheet.
                  result_reg <= FP80_NEG_INF;
                  state_reg <= ST_DONE;
                elsif fp80_sign(a_reg) = '1' then
                  result_reg <= canonical_nan(FP80_ZERO);
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_ONE then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  -- Defer heavy fgetexp/fgetman to ST_LOG_GETEXP (7-cycle MCP).
                  log_exp_add_en_reg <= '1';
                  coeff_set_reg <= COEFF_SET_LOG;
                  poly_degree_reg <= 9;
                  trans_input_adjust_en_reg <= '1';
                  trans_input_adjust_sub_reg <= '1';
                  trans_post_mul_en_reg <= '1';
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  seed_domain_reg <= SEED_DOMAIN_LOG;
                  seed_idx_reg <= 2;
                  seed_return_state_reg <= ST_LOG_TABLE_INDEX;
                  state_reg <= ST_LOG_GETEXP;
                end if;

              when FPU_OP_LOG10 =>
                if fp80_is_inf(a_reg) and fp80_sign(a_reg) = '0' then
                  result_reg <= FP80_POS_INF;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  -- DZ: log10(0) = -infinity per datasheet.
                  result_reg <= FP80_NEG_INF;
                  state_reg <= ST_DONE;
                elsif fp80_sign(a_reg) = '1' then
                  result_reg <= canonical_nan(FP80_ZERO);
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_ONE then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  -- Defer heavy fgetexp/fgetman to ST_LOG_GETEXP (7-cycle MCP).
                  log_scale_reg <= FP80_LOG10_2;
                  log_exp_add_en_reg <= '1';
                  coeff_set_reg <= COEFF_SET_LOG;
                  poly_degree_reg <= 9;
                  trans_input_adjust_en_reg <= '1';
                  trans_input_adjust_sub_reg <= '1';
                  trans_post_mul_en_reg <= '1';
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  seed_domain_reg <= SEED_DOMAIN_LOG;
                  seed_idx_reg <= 3;
                  seed_return_state_reg <= ST_LOG_TABLE_INDEX;
                  state_reg <= ST_LOG_GETEXP;
                end if;

              when FPU_OP_ATAN =>
                if fp80_is_inf(a_reg) then
                  if fp80_sign(a_reg) = '1' then
                    result_reg <= FP80_NEG_HALF_PI;
                  else
                    result_reg <= FP80_HALF_PI;
                  end if;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  coeff_set_reg <= COEFF_SET_ATAN;
                  poly_degree_reg <= 9;
                  atan_neg_reg <= fp80_sign(a_reg);
                  if abs_a_gt_one then
                    -- |x| > 1: compute 1/|x|, then table-assisted atan(1/|x|)
                    atan_recip_reg <= '1';
                    div_a_reg <= FP80_ONE;
                    div_b_reg <= abs_a;
                    div_rm_reg <= FP_RND_NEAREST;
                    div_rp_reg <= FP_PREC_EXTENDED;
                    cont_state_reg <= ST_ATAN_INV_POST;
                    state_reg <= ST_FP_DIV;
                  else
                    -- |x| <= 1: table-assisted atan(|x|)
                    atan_recip_reg <= '0';
                    x_reg <= abs_a;
                    mul_a_reg <= abs_a;
                    mul_b_reg <= FP80_SIXTY_FOUR;
                    mul_rm_reg <= FP_RND_NEAREST;
                    mul_rp_reg <= FP_PREC_EXTENDED;
                    cont_state_reg <= ST_ATAN_INDEX_MUL_POST;
                    state_reg <= ST_FP_MUL;
                  end if;
                end if;

              when FPU_OP_ASIN =>
                if abs_a_gt_one then
                  result_reg <= canonical_nan(FP80_ZERO);
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_ONE then
                  result_reg <= FP80_HALF_PI;
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_NEG_ONE then
                  result_reg <= FP80_NEG_HALF_PI;
                  state_reg <= ST_DONE;
                elsif a_exp_v /= 0 and to_integer(a_exp_v) < FP_EXP_BIAS - 32 then
                  -- Tiny argument: asin(x) = x
                  result_reg <= a_reg;
                  state_reg <= ST_DONE;
                else
                  -- ASIN(x) = ATAN(x / sqrt(1-x^2))
                  atan_neg_reg <= fp80_sign(a_reg);
                  atan_recip_reg <= '0';
                  coeff_set_reg <= COEFF_SET_ATAN;
                  poly_degree_reg <= 9;
                  -- Start computing x^2
                  x_reg <= abs_a;
                  mul_a_reg <= abs_a;
                  mul_b_reg <= abs_a;
                  mul_rm_reg <= FP_RND_NEAREST;
                  mul_rp_reg <= FP_PREC_EXTENDED;
                  cont_state_reg <= ST_ASIN_X2_POST;
                  state_reg <= ST_FP_MUL;
                end if;

              when FPU_OP_ACOS =>
                if abs_a_gt_one then
                  result_reg <= canonical_nan(FP80_ZERO);
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_HALF_PI;
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_ONE then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                elsif a_reg = FP80_NEG_ONE then
                  result_reg <= FP80_PI;
                  state_reg <= ST_DONE;
                else
                  -- ACOS(x) = pi/2 - ASIN(x)
                  -- Compute ASIN(|x|) first, then adjust with pi/2
                  acos_neg_input_reg <= fp80_sign(a_reg);
                  atan_neg_reg <= '0'; -- don't negate the ASIN result
                  atan_recip_reg <= '0';
                  coeff_set_reg <= COEFF_SET_ATAN;
                  poly_degree_reg <= 9;
                  -- Start computing x^2
                  x_reg <= abs_a;
                  mul_a_reg <= abs_a;
                  mul_b_reg <= abs_a;
                  mul_rm_reg <= FP_RND_NEAREST;
                  mul_rp_reg <= FP_PREC_EXTENDED;
                  cont_state_reg <= ST_ASIN_X2_POST;
                  state_reg <= ST_FP_MUL;
                end if;

              when FPU_OP_ATANH =>
                if abs_a = FP80_ONE then
                  -- Singularity: atanh(±1) = ±infinity, DZ.
                  if fp80_sign(a_reg) = '1' then
                    result_reg <= FP80_NEG_INF;
                  else
                    result_reg <= FP80_POS_INF;
                  end if;
                  flag_divzero_reg <= '1';
                  state_reg <= ST_DONE;
                elsif abs_a_gt_one then
                  result_reg <= canonical_nan(FP80_ZERO);
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                elsif a_exp_v /= 0 and to_integer(a_exp_v) < FP_EXP_BIAS - 32 then
                  -- Tiny argument: atanh(x) = x
                  result_reg <= a_reg;
                  state_reg <= ST_DONE;
                else
                  -- ATANH(x) = 0.5 * ln((1+x)/(1-x))
                  -- Step 1: compute 1+x
                  add_a_reg <= FP80_ONE;
                  add_b_reg <= a_reg;
                  add_sub_reg <= false;
                  add_rm_reg <= FP_RND_NEAREST;
                  add_rp_reg <= FP_PREC_EXTENDED;
                  cont_state_reg <= ST_ATANH_NUMER_POST;
                  state_reg <= ST_FP_ADD;
                end if;

              when FPU_OP_SINH =>
                if fp80_is_inf(a_reg) then
                  result_reg <= a_reg;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  coeff_set_reg <= COEFF_SET_SINH;
                  poly_degree_reg <= 9;
                  seed_domain_reg <= SEED_DOMAIN_EXP;
                  seed_idx_reg <= 0;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
                end if;

              when FPU_OP_COSH =>
                if fp80_is_inf(a_reg) then
                  result_reg <= FP80_POS_INF;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ONE;
                  state_reg <= ST_DONE;
                else
                  coeff_set_reg <= COEFF_SET_COSH;
                  poly_degree_reg <= 9;
                  seed_domain_reg <= SEED_DOMAIN_EXP;
                  seed_idx_reg <= 0;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
                end if;

              when FPU_OP_TANH =>
                if fp80_is_inf(a_reg) then
                  if fp80_sign(a_reg) = '1' then
                    result_reg <= FP80_NEG_ONE;
                  else
                    result_reg <= FP80_ONE;
                  end if;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  -- tanh(x) = (e^(2|x|) - 1) / (e^(2|x|) + 1), sign applied at end
                  v_exp := unsigned(abs_a(78 downto 64));
                  v_mant := unsigned(abs_a(63 downto 0));
                  if v_exp > to_unsigned(FP_EXP_BIAS + 3, FP_EXP_WIDTH)
                     or (v_exp = to_unsigned(FP_EXP_BIAS + 3, FP_EXP_WIDTH)
                         and v_mant > x"A000000000000000") then
                    -- |x| > 10, tanh saturates to sign(x)
                    if fp80_sign(a_reg) = '1' then
                      result_reg <= FP80_NEG_ONE;
                    else
                      result_reg <= FP80_ONE;
                    end if;
                    state_reg <= ST_DONE;
                  elsif v_exp /= 0 and to_integer(v_exp) < FP_EXP_BIAS - 32 then
                    -- |x| < 2^-32, tanh(x) ~ x
                    result_reg <= a_reg;
                    state_reg <= ST_DONE;
                  else
                    -- Save sign, compute 2*|x| then route through EXP64 pipeline
                    atan_neg_reg <= fp80_sign(a_reg);
                    exp_reduce_en_reg <= '1';
                    exp_reduce_done_reg <= '1';
                    coeff_set_reg <= COEFF_SET_EXP64;
                    poly_degree_reg <= 6;
                    trans_post_mul_en_reg <= '1';  -- multiply by EXPTBL[J]
                    -- Multiply |x| * 2
                    mul_a_reg <= abs_a;
                    mul_b_reg <= FP80_TWO;
                    mul_rm_reg <= FP_RND_NEAREST;
                    mul_rp_reg <= FP_PREC_EXTENDED;
                    cont_state_reg <= ST_TANH_2X_POST;
                    state_reg <= ST_FP_MUL;
                  end if;
                end if;

              when others =>
                result_reg <= canonical_nan(FP80_ZERO);
                state_reg <= ST_DONE;
            end case;
          end if;

        when ST_TRIG_REDUCE =>
          exp_bits := unsigned(x_reg(FP_WIDTH-2 downto FP_WIDTH-1-FP_EXP_WIDTH));
          if exp_bits /= 0 and to_integer(exp_bits) > FP_EXP_BIAS + 20 then
            mul_a_reg <= x_reg;
            mul_b_reg <= FP80_TWO_OVER_PI;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_TRIG_MOD_SCALE_POST;
            state_reg <= ST_FP_MUL;
          else
            state_reg <= ST_TRIG_SCALE_PREP;
          end if;

        when ST_TRIG_MOD_SCALE_POST =>
          mul_a_reg <= tmp_reg;
          mul_b_reg <= FP80_ONE_FOURTH;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_MOD_INV4_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_MOD_INV4_POST =>
          q_fp_reg <= fintrz_tmp;
          state_reg <= ST_TRIG_MOD_QPI_PREP;

        when ST_TRIG_MOD_QPI_PREP =>
          mul_a_reg <= q_fp_reg;
          mul_b_reg <= FP80_TWO_PI;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_MOD_QPI_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_MOD_QPI_POST =>
          state_reg <= ST_TRIG_MOD_SUB_PREP;

        when ST_TRIG_MOD_SUB_PREP =>
          add_a_reg <= x_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_MOD_SUB_POST;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_MOD_SUB_POST =>
          x_reg <= tmp_reg;
          state_reg <= ST_TRIG_SCALE_PREP;

        when ST_TRIG_SCALE_PREP =>
          mul_a_reg <= x_reg;
          mul_b_reg <= FP80_TWO_OVER_PI;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SCALE_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SCALE_POST =>
          q_fp_reg <= fintrz_tmp;
          state_reg <= ST_TRIG_FRAC_PREP;

        when ST_TRIG_FRAC_PREP =>
          add_a_reg <= tmp_reg;
          add_b_reg <= q_fp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_FRAC_POST;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_FRAC_POST =>
          frac := tmp_reg;
          q_mod_local := fp80_int_mod4(q_fp_reg);
          -- |frac| >= 0.5: compare exponent/mantissa against FP80_HALF (exp=3FFE, mant=8000...)
          v_exp := unsigned(frac(78 downto 64));
          v_mant := unsigned(frac(63 downto 0));
          frac_abs_ge_half := v_exp > to_unsigned(FP_EXP_BIAS - 1, FP_EXP_WIDTH)
                           or (v_exp = to_unsigned(FP_EXP_BIAS - 1, FP_EXP_WIDTH)
                               and v_mant >= x"8000000000000000");
          if frac(FP_WIDTH-1) = '0' and frac_abs_ge_half then
            q_mod_local := (q_mod_local + 1) mod 4;
            add_a_reg <= q_fp_reg;
            add_b_reg <= FP80_ONE;
            add_sub_reg <= false;
            add_rm_reg <= FP_RND_NEAREST;
            add_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_TRIG_QROUND_POST;
            q_mod_reg <= q_mod_local;
            state_reg <= ST_FP_ADD;
          elsif frac(FP_WIDTH-1) = '1' and frac_abs_ge_half then
            q_mod_local := (q_mod_local + 3) mod 4;
            add_a_reg <= q_fp_reg;
            add_b_reg <= FP80_ONE;
            add_sub_reg <= true;
            add_rm_reg <= FP_RND_NEAREST;
            add_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_TRIG_QROUND_POST;
            q_mod_reg <= q_mod_local;
            state_reg <= ST_FP_ADD;
          else
            q_mod_reg <= q_mod_local;
            state_reg <= ST_TRIG_QPI_PREP;
          end if;

        when ST_TRIG_QROUND_POST =>
          q_fp_reg <= tmp_reg;
          state_reg <= ST_TRIG_QPI_PREP;

        when ST_TRIG_QPI_PREP =>
          mul_a_reg <= q_fp_reg;
          mul_b_reg <= FP80_HALF_PI_HI;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_QPI_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_QPI_POST =>
          state_reg <= ST_TRIG_RESIDUAL_PREP;

        when ST_TRIG_RESIDUAL_PREP =>
          add_a_reg <= x_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_RESIDUAL_POST;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_RESIDUAL_POST =>
          -- r_hi = x - q * HALF_PI_HI (in tmp_reg)
          -- Save r_hi, then apply Cody-Waite LO correction
          r_reg <= tmp_reg;
          -- Compute q * HALF_PI_LO
          mul_a_reg <= q_fp_reg;
          mul_b_reg <= FP80_HALF_PI_LO;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_CW_LO_MUL;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_CW_LO_MUL =>
          -- tmp_reg = q * HALF_PI_LO
          -- Compute r = r_hi - q * HALF_PI_LO
          add_a_reg <= r_reg;       -- r_hi
          add_b_reg <= tmp_reg;     -- q * HALF_PI_LO
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_CW_LO_SUB;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_CW_LO_SUB =>
          -- tmp_reg = r_mid = r_hi - q * HALF_PI_LO
          -- Apply 3rd Cody-Waite term for ~131 bits of pi/2
          -- Skip C3 when r_mid=0 (exact cancellation)
          if fp80_is_zero(tmp_reg) then
            r_reg <= FP80_ZERO;
            state_reg <= ST_TRIG_SEED_INDEX_ADD_PREP;
          else
            r_reg <= tmp_reg;
            mul_a_reg <= q_fp_reg;
            mul_b_reg <= FP80_HALF_PI_C3;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_TRIG_CW_C3_MUL;
            state_reg <= ST_FP_MUL;
          end if;

        when ST_TRIG_CW_C3_MUL =>
          -- tmp_reg = q * HALF_PI_C3.  Compute r = r_mid - q * HALF_PI_C3.
          add_a_reg <= r_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_CW_C3_SUB;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_CW_C3_SUB =>
          -- tmp_reg = r = r_mid - q * HALF_PI_C3 (fully corrected residual)
          r_clamped := tmp_reg;
          -- |r_clamped| <= 2^-20: check exponent field <= EPS exponent (3FEB)
          v_exp := unsigned(r_clamped(78 downto 64));
          v_mant := unsigned(r_clamped(63 downto 0));
          if v_exp < to_unsigned(16363, FP_EXP_WIDTH)
             or (v_exp = to_unsigned(16363, FP_EXP_WIDTH)
                 and v_mant <= x"8000000000000000") then
            r_clamped := FP80_ZERO;
          end if;
          r_reg <= r_clamped;
          state_reg <= ST_TRIG_SEED_INDEX_ADD_PREP;

        when ST_TRIG_SEED_INDEX_ADD_PREP =>
          add_a_reg <= r_reg;
          add_b_reg <= FP80_QUARTER_PI;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_INDEX_ADD_POST;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_SEED_INDEX_ADD_POST =>
          mul_a_reg <= tmp_reg;
          mul_b_reg <= FP80_TRIG_INDEX_SCALE;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_INDEX_SCALE_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_INDEX_SCALE_POST =>
          seed_idx_reg <= clamp_seed_index(fp80_to_int_trunc(tmp_reg));
          seed_domain_reg <= SEED_DOMAIN_TRIG;
          seed_return_state_reg <= ST_TRIG_SEED_DELTA_PREP;
          state_reg <= ST_SEED_READ;

        when ST_SEED_READ =>
          case seed_domain_reg is
            when SEED_DOMAIN_TRIG =>
              if table_impl = TABLE_IMPL_BRAM then
                trig_seed_addr_reg <= seed_idx_reg;
                state_reg <= ST_SEED_READ_WAIT;
              else
                seed_center_reg <= TRIG_SEED_CENTER_INIT(seed_idx_reg);
                seed_sin_reg <= TRIG_SEED_SIN_INIT(seed_idx_reg);
                seed_cos_reg <= TRIG_SEED_COS_INIT(seed_idx_reg);
                state_reg <= seed_return_state_reg;
              end if;
            when SEED_DOMAIN_EXP =>
              if table_impl = TABLE_IMPL_BRAM then
                aux_seed_addr_reg <= seed_idx_reg;
                state_reg <= ST_SEED_READ_WAIT;
              else
                seed_aux0_reg <= EXP_SEED_PRE_MUL_INIT(seed_idx_reg);
                state_reg <= seed_return_state_reg;
              end if;
            when SEED_DOMAIN_LOG =>
              if table_impl = TABLE_IMPL_BRAM then
                aux_seed_addr_reg <= seed_idx_reg;
                state_reg <= ST_SEED_READ_WAIT;
              else
                seed_aux0_reg <= LOG_SEED_INPUT_ADJ_INIT(seed_idx_reg);
                seed_aux1_reg <= LOG_SEED_POST_SCALE_INIT(seed_idx_reg);
                state_reg <= seed_return_state_reg;
              end if;
            when others =>
              if table_impl = TABLE_IMPL_BRAM then
                aux_seed_addr_reg <= seed_idx_reg;
                state_reg <= ST_SEED_READ_WAIT;
              else
                seed_aux0_reg <= ATAN_CENTER_INIT(seed_idx_reg);
                seed_aux1_reg <= ATAN_SEED_OFFSET_INIT(seed_idx_reg);
                state_reg <= seed_return_state_reg;
              end if;
          end case;

        when ST_SEED_READ_WAIT =>
          state_reg <= ST_SEED_READ_LATCH;

        when ST_SEED_READ_LATCH =>
          case seed_domain_reg is
            when SEED_DOMAIN_TRIG =>
              seed_center_reg <= trig_seed_center_q;
              seed_sin_reg <= trig_seed_sin_q;
              seed_cos_reg <= trig_seed_cos_q;
            when SEED_DOMAIN_EXP =>
              seed_aux0_reg <= exp_seed_pre_mul_q;
            when SEED_DOMAIN_LOG =>
              seed_aux0_reg <= log_seed_input_adj_q;
              seed_aux1_reg <= log_seed_post_scale_q;
            when others =>
              seed_aux0_reg <= atan_center_q;
              seed_aux1_reg <= atan_seed_offset_q;
          end case;
          state_reg <= seed_return_state_reg;

        when ST_TRIG_SEED_DELTA_PREP =>
          add_a_reg <= r_reg;
          add_b_reg <= seed_center_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_DELTA_POST;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_SEED_DELTA_POST =>
          seed_delta_reg <= tmp_reg;
          state_reg <= ST_TRIG_SEED_DELTA2_PREP;

        when ST_TRIG_SEED_DELTA2_PREP =>
          mul_a_reg <= seed_delta_reg;
          mul_b_reg <= seed_delta_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_DELTA2_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_DELTA2_POST =>
          seed_delta2_reg <= tmp_reg;
          state_reg <= ST_TRIG_SEED_SIN_LIN_PREP;

        when ST_TRIG_SEED_SIN_LIN_PREP =>
          mul_a_reg <= seed_cos_reg;
          mul_b_reg <= seed_delta_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_SIN_LIN_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_SIN_LIN_POST =>
          add_a_reg <= seed_sin_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_SIN_QUAD_PREP;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_SEED_SIN_QUAD_PREP =>
          s_reg <= tmp_reg;
          mul_a_reg <= seed_sin_reg;
          mul_b_reg <= seed_delta2_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_SIN_QUAD_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_SIN_QUAD_POST =>
          mul_a_reg <= FP80_HALF;
          mul_b_reg <= tmp_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_SIN_HALF_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_SIN_HALF_POST =>
          add_a_reg <= s_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= rm_reg;
          add_rp_reg <= rp_reg;
          cont_state_reg <= ST_TRIG_SEED_COS_LIN_PREP;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_SEED_COS_LIN_PREP =>
          s_reg <= tmp_reg;
          mul_a_reg <= seed_sin_reg;
          mul_b_reg <= seed_delta_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_COS_LIN_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_COS_LIN_POST =>
          add_a_reg <= seed_cos_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_COS_QUAD_PREP;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_SEED_COS_QUAD_PREP =>
          c_reg <= tmp_reg;
          mul_a_reg <= seed_cos_reg;
          mul_b_reg <= seed_delta2_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_COS_QUAD_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_COS_QUAD_POST =>
          mul_a_reg <= FP80_HALF;
          mul_b_reg <= tmp_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRIG_SEED_COS_HALF_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRIG_SEED_COS_HALF_POST =>
          add_a_reg <= c_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= rm_reg;
          add_rp_reg <= rp_reg;
          cont_state_reg <= ST_TRIG_COS_FINAL_POST;
          state_reg <= ST_FP_ADD;

        when ST_TRIG_COS_FINAL_POST =>
          c_reg <= tmp_reg;
          state_reg <= ST_TRIG_RECONSTRUCT;

        when ST_TRIG_RECONSTRUCT =>
          sin_res := s_reg;
          cos_res := c_reg;
          case q_mod_reg is
            when 0 =>
              null;
            when 1 =>
              combined := sin_res;
              sin_res := cos_res;
              cos_res := combined;
              cos_res(FP_WIDTH-1) := not cos_res(FP_WIDTH-1);
            when 2 =>
              sin_res(FP_WIDTH-1) := not sin_res(FP_WIDTH-1);
              cos_res(FP_WIDTH-1) := not cos_res(FP_WIDTH-1);
            when others =>
              combined := sin_res;
              sin_res := cos_res;
              cos_res := combined;
              sin_res(FP_WIDTH-1) := not sin_res(FP_WIDTH-1);
          end case;
          s_reg <= sin_res;
          c_reg <= cos_res;
          if op_reg = FPU_OP_TAN then
            state_reg <= ST_TRIG_TAN_DIV;
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

        when ST_TRIG_TAN_DIV =>
          div_a_reg <= s_reg;
          div_b_reg <= c_reg;
          div_rm_reg <= rm_reg;
          div_rp_reg <= rp_reg;
          cont_state_reg <= ST_TRIG_TAN_DIV_POST;
          state_reg <= ST_FP_DIV;

        when ST_TRIG_TAN_DIV_POST =>
          -- |tmp_reg| > 1.0: direct field comparison replaces compare_fp80
          v_exp := unsigned(tmp_reg(78 downto 64));
          v_mant := unsigned(tmp_reg(63 downto 0));
          if op_reg = FPU_OP_TANH
             and (v_exp > to_unsigned(FP_EXP_BIAS, FP_EXP_WIDTH)
                  or (v_exp = to_unsigned(FP_EXP_BIAS, FP_EXP_WIDTH)
                      and v_mant > x"8000000000000000")) then
            if tmp_reg(FP_WIDTH-1) = '1' then
              result_reg <= FP80_NEG_ONE;
            else
              result_reg <= FP80_ONE;
            end if;
          else
            result_reg <= tmp_reg;
          end if;
          state_reg <= ST_DONE;

        when ST_TRIG_TINY_ROUND_POST =>
          s_reg <= tmp_reg;
          state_reg <= ST_TRIG_RECONSTRUCT;

        -- ================================================================
        -- TWOTOX/TENTOX Direct Reduction States
        -- Saves 1-2 FP multiplies by avoiding pre-mul × ln(2)/ln(10)
        -- then divide by ln(2) round-trip in EXP reduction.
        -- ================================================================
        when ST_TWOTOX_ROUND =>
          -- For TWOTOX: x_reg = x (the input).
          -- For TENTOX: tmp_reg = x*log2(10) from preceding FP_MUL.
          if op_reg = FPU_OP_TENTOX then
            x_reg <= tmp_reg;  -- x_reg = x * log2(10)
          end if;
          -- Round to nearest integer: add ±0.5 then fintrz.
          -- This ensures |r| <= 0.5 so |r*ln2| <= ln(2)/2 ~ 0.347.
          if op_reg = FPU_OP_TENTOX then
            add_a_reg <= tmp_reg;
          else
            add_a_reg <= x_reg;
          end if;
          add_b_reg <= FP80_HALF;
          if op_reg = FPU_OP_TENTOX then
            add_sub_reg <= (tmp_reg(FP_WIDTH-1) = '1');  -- subtract 0.5 if negative
          else
            add_sub_reg <= (x_reg(FP_WIDTH-1) = '1');
          end if;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TWOTOX_ROUND_POST;
          state_reg <= ST_FP_ADD;

        when ST_TWOTOX_ROUND_POST =>
          -- fintrz_tmp = fintrz(x ± 0.5) = nearest integer k
          exp_k_reg <= fintrz_tmp;
          -- Compute r = x_reg - k (exact by Sterbenz lemma since |r| <= 0.5)
          add_a_reg <= x_reg;
          add_b_reg <= fintrz_tmp;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TWOTOX_FRAC_POST;
          state_reg <= ST_FP_ADD;

        when ST_TWOTOX_FRAC_POST =>
          -- tmp_reg = r = fractional part (x - k), |r| <= 0.5
          -- Compute x_new = r * ln(2) for polynomial evaluation
          mul_a_reg <= tmp_reg;
          mul_b_reg <= FP80_LN2;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TWOTOX_RLN2_POST;
          state_reg <= ST_FP_MUL;

        when ST_TWOTOX_RLN2_POST =>
          -- tmp_reg = r * ln(2), the reduced argument for exp()
          -- |r*ln(2)| <= 0.5*ln(2) ~ 0.347 (same range as standard EXP)
          x_reg <= tmp_reg;
          -- exp_reduce_done=1 already set, so ST_TRANS_PREP skips reduction
          state_reg <= ST_TRANS_PREP;

        when ST_TANH_2X_POST =>
          -- tmp_reg = 2|x|, feed into EXP64 pipeline
          x_reg <= tmp_reg;
          -- Start EXP64 reduction: N = nint(2|x| * 64/ln(2))
          mul_a_reg <= tmp_reg;
          mul_b_reg <= FP80_64_INV_LN2;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP64_N_ROUND;
          state_reg <= ST_FP_MUL;

        when ST_TANH_EXP_POST =>
          -- result_reg = e^(2|x|); save it, compute e^(2|x|) - 1
          s_reg <= result_reg;
          add_a_reg <= result_reg;
          add_b_reg <= FP80_ONE;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TANH_NUMER_POST;
          state_reg <= ST_FP_ADD;

        when ST_TANH_NUMER_POST =>
          -- tmp_reg = e^(2|x|) - 1 (numerator); compute e^(2|x|) + 1
          r_reg <= tmp_reg;
          add_a_reg <= s_reg;
          add_b_reg <= FP80_ONE;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TANH_DENOM_POST;
          state_reg <= ST_FP_ADD;

        when ST_TANH_DENOM_POST =>
          -- tmp_reg = e^(2|x|) + 1 (denominator); divide
          div_a_reg <= r_reg;
          div_b_reg <= tmp_reg;
          div_rm_reg <= rm_reg;
          div_rp_reg <= rp_reg;
          cont_state_reg <= ST_TANH_DIV_POST;
          state_reg <= ST_FP_DIV;

        when ST_TANH_DIV_POST =>
          -- tmp_reg = tanh(|x|); apply original sign
          result_reg <= tmp_reg;
          if atan_neg_reg = '1' then
            result_reg(FP_WIDTH-1) <= not tmp_reg(FP_WIDTH-1);
          end if;
          state_reg <= ST_DONE;

        -- ================================================================
        -- EXP 2^(J/64) Decomposition States
        -- exp(x) = 2^M * EXPTBL[J] * exp(R) where
        --   N = nint(x*64/ln2), J = N mod 64, M = (N-J)/64
        --   R = x - N*ln(2)/64, |R| <= ln(2)/128 ~ 0.0054
        -- ================================================================
        when ST_EXP64_N_ROUND =>
          -- tmp_reg = x * 64/ln(2), round to nearest integer
          -- Add ±0.5 for round-to-nearest (same trick as TWOTOX)
          add_a_reg <= tmp_reg;
          add_b_reg <= FP80_HALF;
          add_sub_reg <= (tmp_reg(FP_WIDTH-1) = '1');
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP64_N_POST;
          state_reg <= ST_FP_ADD;

        when ST_EXP64_N_POST =>
          -- fintrz_tmp = N = nint(x * 64/ln(2))
          -- Extract J = N mod 64 and M = (N-J)/64
          exp64_n_int_reg <= fp80_to_int_trunc(fintrz_tmp);
          -- J = N mod 64 (always in 0..63)
          exp64_table_addr_reg <= fp80_to_int_trunc(fintrz_tmp) mod 64;
          -- exp_k_reg = N as fp80 (for CW subtraction)
          exp_k_reg <= fintrz_tmp;
          -- Start BRAM read for EXPTBL[J]
          state_reg <= ST_EXP64_TABLE_WAIT;

        when ST_EXP64_TABLE_WAIT =>
          -- BRAM read latency cycle
          state_reg <= ST_EXP64_TABLE_LATCH;

        when ST_EXP64_TABLE_LATCH =>
          -- Latch EXPTBL[J] as post-multiply factor
          trans_post_mul_const_reg <= exp64_table_q;
          -- exp_k_reg still holds N (fp80) from ST_EXP64_N_POST.
          -- Keep it for the CW chain; will compute M after CW completes.
          -- Start Cody-Waite: R = x - N * ln(2)/64
          -- Step 1: multiply N * LN2_DIV64_HI
          mul_a_reg <= exp_k_reg;  -- N as fp80
          mul_b_reg <= FP80_LN2_DIV64_HI;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP64_CW_HI_POST;
          state_reg <= ST_FP_MUL;

        when ST_EXP64_CW_HI_POST =>
          -- tmp_reg = N * LN2_DIV64_HI, compute x - N*LN2_DIV64_HI
          add_a_reg <= x_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP64_CW_LO_MUL;
          state_reg <= ST_FP_ADD;

        when ST_EXP64_CW_LO_MUL =>
          -- tmp_reg = x - N*LN2_DIV64_HI (r_hi), save and compute LO correction
          r_reg <= tmp_reg;
          -- exp_k_reg still holds N (fp80)
          mul_a_reg <= exp_k_reg;  -- N
          mul_b_reg <= FP80_LN2_DIV64_LO;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP64_CW_LO_POST;
          state_reg <= ST_FP_MUL;

        when ST_EXP64_CW_LO_POST =>
          -- tmp_reg = N * LN2_DIV64_LO, compute R = r_hi - N*LN2_DIV64_LO
          -- Also compute M = (N-J)/64 for final fscale (before exp_k_reg gets to poly)
          exp_k_reg <= fp80_from_int(
            (exp64_n_int_reg - (exp64_n_int_reg mod 64)) / 64);
          add_a_reg <= r_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP_REDUCE_R_POST;  -- reuse: sets x_reg, goes to poly
          state_reg <= ST_FP_ADD;

        when ST_EXP_REDUCE_K_POST =>
          exp_k_reg <= fintrz_tmp;
          mul_a_reg <= fintrz_tmp;
          mul_b_reg <= FP80_LN2_HI;  -- Cody-Waite: use high-part of ln(2)
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP_REDUCE_KLN2_POST;
          state_reg <= ST_FP_MUL;

        when ST_EXP_REDUCE_KLN2_POST =>
          -- tmp_reg = k * LN2_HI.  Compute r_hi = x - k * LN2_HI
          add_a_reg <= x_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP_CW_LO_MUL;
          state_reg <= ST_FP_ADD;

        when ST_EXP_CW_LO_MUL =>
          -- tmp_reg = r_hi = x - k * LN2_HI.  Save and compute k * LN2_LO.
          r_reg <= tmp_reg;
          mul_a_reg <= exp_k_reg;
          mul_b_reg <= FP80_LN2_LO;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP_CW_LO_SUB;
          state_reg <= ST_FP_MUL;

        when ST_EXP_CW_LO_SUB =>
          -- tmp_reg = k * LN2_LO.  Compute r_mid = r_hi - k * LN2_LO.
          add_a_reg <= r_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP_CW_C3_MUL;
          state_reg <= ST_FP_ADD;

        when ST_EXP_CW_C3_MUL =>
          -- tmp_reg = r_mid = r_hi - k * LN2_LO.  Apply 3rd term.
          -- Skip C3 when r_mid=0 (exact cancellation, e.g. FTWOTOX integer)
          if fp80_is_zero(tmp_reg) then
            x_reg <= tmp_reg;
            exp_reduce_done_reg <= '1';
            state_reg <= ST_TRANS_PREP;
          else
            r_reg <= tmp_reg;
            mul_a_reg <= exp_k_reg;
            mul_b_reg <= FP80_LN2_C3;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_EXP_CW_C3_SUB;
            state_reg <= ST_FP_MUL;
          end if;

        when ST_EXP_CW_C3_SUB =>
          -- tmp_reg = k * LN2_C3.  Compute r = r_mid - k * LN2_C3.
          add_a_reg <= r_reg;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP_REDUCE_R_POST;
          state_reg <= ST_FP_ADD;

        when ST_EXP_REDUCE_R_POST =>
          x_reg <= tmp_reg;
          exp_reduce_done_reg <= '1';
          state_reg <= ST_TRANS_PREP;

        when ST_LOG_EXP_TERM_POST =>
          log_exp_term_reg <= tmp_reg;
          state_reg <= ST_SEED_READ;

        when ST_LOG_GETEXP =>
          -- Pipeline stage: capture unbiased exponent metadata and fgetman result.
          -- a_reg was loaded in ST_IDLE, with ST_A_SETTLE wait cycles before
          -- ST_CLASSIFY.  This gives the heavy combinational logic seven clock
          -- periods (212 ns at 33 MHz) to settle (7-cycle MCP).
          unbiased_exp_local := fgetexp_unbiased_int(a_reg);
          log_unbiased_exp_reg <= unbiased_exp_local;
          if unbiased_exp_local = 0 then
            log_exp_term_zero_reg <= '1';
          else
            log_exp_term_zero_reg <= '0';
          end if;
          x_reg <= fgetman_a;
          state_reg <= ST_LOG_GETEXP_HOLD;

        when ST_LOG_GETEXP_HOLD =>
          -- Hold state: gives fp80_from_int(log_unbiased_exp_reg) an extra
          -- cycle to settle (2-cycle MCP from log_unbiased_exp_reg).
          state_reg <= ST_LOG_GETEXP_POST;

        when ST_LOG_GETEXP_POST =>
          if op_reg = FPU_OP_LOG2 or log_exp_term_zero_reg = '1' then
            -- log2 uses exponent term directly; logn/log10 skip scaling for zero exp.
            log_exp_term_reg <= fp80_from_int(log_unbiased_exp_reg);
            state_reg <= ST_SEED_READ;
          else
            mul_a_reg <= fp80_from_int(log_unbiased_exp_reg);
            mul_b_reg <= log_scale_reg;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_LOG_EXP_TERM_POST;
            state_reg <= ST_FP_MUL;
          end if;

        when ST_LOGNP1_Z_POST =>
          -- z = tmp_reg = a + 1.  Finish FLOGNP1 setup using z.
          z_local := tmp_reg;
          x_local := fgetman_tmp;
          unbiased_exp_local := fgetexp_unbiased_int(z_local);
          log_unbiased_exp_reg <= unbiased_exp_local;
          log_scale_reg <= FP80_LN2;
          log_exp_add_en_reg <= '1';
          coeff_set_reg <= COEFF_SET_LOG;
          poly_degree_reg <= 9;
          trans_input_adjust_en_reg <= '1';
          trans_input_adjust_sub_reg <= '1';
          trans_post_mul_en_reg <= '1';
          trans_post_add_en_reg <= '1';
          trans_post_add_sub_reg <= '0';
          seed_domain_reg <= SEED_DOMAIN_LOG;
          seed_idx_reg <= 0;
          seed_return_state_reg <= ST_LOG_TABLE_INDEX;
          x_reg <= x_local;
          state_reg <= ST_LOGNP1_META_POST;

        when ST_LOGNP1_META_POST =>
          -- Isolate metadata/branching from z decode to shorten this timing cone.
          if log_unbiased_exp_reg = 0 then
            log_exp_term_zero_reg <= '1';
          else
            log_exp_term_zero_reg <= '0';
          end if;
          state_reg <= ST_LOGNP1_GETEXP_POST;

        when ST_LOGNP1_GETEXP_POST =>
          if log_exp_term_zero_reg = '1' then
            log_exp_term_reg <= fp80_from_int(log_unbiased_exp_reg);
            state_reg <= ST_SEED_READ;
          else
            mul_a_reg <= fp80_from_int(log_unbiased_exp_reg);
            mul_b_reg <= log_scale_reg;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_LOG_EXP_TERM_POST;
            state_reg <= ST_FP_MUL;
          end if;

        when ST_ATAN_INV_POST =>
          -- tmp_reg = 1/|x|, which is < 1
          x_reg <= tmp_reg;
          -- Compute table index: |y| * 64
          mul_a_reg <= tmp_reg;
          mul_b_reg <= FP80_SIXTY_FOUR;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ATAN_INDEX_MUL_POST;
          state_reg <= ST_FP_MUL;

        when ST_ATAN_INDEX_MUL_POST =>
          -- tmp_reg = |x| * 64 (or |1/x| * 64 for recip path)
          seed_idx_reg <= clamp_seed_index(fp80_to_int_trunc(tmp_reg));
          seed_domain_reg <= SEED_DOMAIN_ATAN;
          seed_return_state_reg <= ST_ATAN_DELTA_PREP;
          state_reg <= ST_SEED_READ;

        when ST_ATAN_DELTA_PREP =>
          -- seed_aux0_reg = c_i (center), seed_aux1_reg = atan(c_i)
          -- Set up the post-add to add atan(c_i) after polynomial
          trans_post_add_en_reg <= '1';
          trans_post_add_sub_reg <= '0';
          trans_post_add_const_reg <= seed_aux1_reg;  -- atan(c_i)
          -- Compute delta = x_reg - c_i
          add_a_reg <= x_reg;
          add_b_reg <= seed_aux0_reg;
          add_sub_reg <= true;  -- subtraction
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ATAN_DELTA_POST;
          state_reg <= ST_FP_ADD;

        when ST_ATAN_DELTA_POST =>
          -- tmp_reg = delta = x - c_i
          r_reg <= tmp_reg;
          -- Now compute c_i * x
          mul_a_reg <= seed_aux0_reg;  -- c_i
          mul_b_reg <= x_reg;          -- |x|
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ATAN_CX_MUL_POST;
          state_reg <= ST_FP_MUL;

        when ST_ATAN_CX_MUL_POST =>
          -- tmp_reg = c_i * x
          -- Compute 1 + c_i * x
          add_a_reg <= FP80_ONE;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;  -- addition
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ATAN_DENOM_ADD_POST;
          state_reg <= ST_FP_ADD;

        when ST_ATAN_DENOM_ADD_POST =>
          -- tmp_reg = 1 + c_i * x (denominator)
          -- Compute u = delta / (1 + c_i * x)
          div_a_reg <= r_reg;    -- delta
          div_b_reg <= tmp_reg;  -- 1 + c_i * x
          div_rm_reg <= FP_RND_NEAREST;
          div_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ATAN_U_POST;
          state_reg <= ST_FP_DIV;

        when ST_ATAN_U_POST =>
          -- tmp_reg = u = delta / (1 + c_i * x), small value |u| < ~1/64
          x_reg <= tmp_reg;
          state_reg <= ST_TRANS_POLY_INIT;

        when ST_ATAN_RECIP_SUB =>
          -- result_reg = atan(1/|x|), need pi/2 - atan(1/|x|)
          add_a_reg <= FP80_HALF_PI;
          add_b_reg <= result_reg;
          add_sub_reg <= true;
          add_rm_reg <= rm_reg;
          add_rp_reg <= rp_reg;
          cont_state_reg <= ST_ATAN_RECIP_POST;
          state_reg <= ST_FP_ADD;

        when ST_ATAN_RECIP_POST =>
          result_reg <= tmp_reg;
          if op_reg = FPU_OP_ACOS then
            state_reg <= ST_ACOS_FINAL;
          elsif atan_neg_reg = '1' then
            result_reg(FP_WIDTH-1) <= not tmp_reg(FP_WIDTH-1);
            state_reg <= ST_DONE;
          else
            state_reg <= ST_DONE;
          end if;

        when ST_ASIN_X2_POST =>
          -- tmp_reg = x^2, compute 1 - x^2
          add_a_reg <= FP80_ONE;
          add_b_reg <= tmp_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ASIN_ONEMX2_POST;
          state_reg <= ST_FP_ADD;

        when ST_ASIN_ONEMX2_POST =>
          -- tmp_reg = 1-x^2, compute sqrt(1-x^2)
          div_a_reg <= tmp_reg;
          div_rm_reg <= FP_RND_NEAREST;
          div_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ASIN_SQRT_POST;
          state_reg <= ST_FP_SQRT;

        when ST_ASIN_SQRT_POST =>
          -- tmp_reg = sqrt(1-x^2), compute |x| / sqrt(1-x^2)
          div_a_reg <= x_reg;    -- |x|
          div_b_reg <= tmp_reg;  -- sqrt(1-x^2)
          div_rm_reg <= FP_RND_NEAREST;
          div_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ASIN_DIV_POST;
          state_reg <= ST_FP_DIV;

        when ST_ASIN_DIV_POST =>
          -- tmp_reg = y = |x| / sqrt(1-x^2)
          -- Check if |y| > 1
          v_exp := unsigned(tmp_reg(78 downto 64));
          v_mant := unsigned(tmp_reg(63 downto 0));
          if v_exp > to_unsigned(FP_EXP_BIAS, FP_EXP_WIDTH)
             or (v_exp = to_unsigned(FP_EXP_BIAS, FP_EXP_WIDTH)
                 and v_mant > x"8000000000000000") then
            -- |y| > 1: compute 1/y, set recip flag
            atan_recip_reg <= '1';
            div_a_reg <= FP80_ONE;
            div_b_reg <= tmp_reg;
            div_rm_reg <= FP_RND_NEAREST;
            div_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_ATAN_INV_POST;
            state_reg <= ST_FP_DIV;
          else
            -- |y| <= 1: direct to ATAN table path
            atan_recip_reg <= '0';
            x_reg <= tmp_reg;
            mul_a_reg <= tmp_reg;
            mul_b_reg <= FP80_SIXTY_FOUR;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_ATAN_INDEX_MUL_POST;
            state_reg <= ST_FP_MUL;
          end if;

        when ST_ACOS_FINAL =>
          -- result_reg = ASIN(|x|), compute pi/2 +/- ASIN(|x|)
          add_a_reg <= FP80_HALF_PI;
          add_b_reg <= result_reg;
          if acos_neg_input_reg = '0' then
            add_sub_reg <= true;   -- pi/2 - ASIN(|x|) for positive x
          else
            add_sub_reg <= false;  -- pi/2 + ASIN(|x|) for negative x
          end if;
          add_rm_reg <= rm_reg;
          add_rp_reg <= rp_reg;
          cont_state_reg <= ST_ACOS_FINAL_POST;
          state_reg <= ST_FP_ADD;

        when ST_ACOS_FINAL_POST =>
          result_reg <= tmp_reg;
          state_reg <= ST_DONE;

        when ST_ATANH_NUMER_POST =>
          -- tmp_reg = 1+x, save and compute 1-x
          r_reg <= tmp_reg;  -- numerator
          add_a_reg <= FP80_ONE;
          add_b_reg <= a_reg;
          add_sub_reg <= true;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ATANH_DENOM_POST;
          state_reg <= ST_FP_ADD;

        when ST_ATANH_DENOM_POST =>
          -- tmp_reg = 1-x, compute (1+x)/(1-x)
          div_a_reg <= r_reg;   -- 1+x
          div_b_reg <= tmp_reg; -- 1-x
          div_rm_reg <= FP_RND_NEAREST;
          div_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_ATANH_DIV_POST;
          state_reg <= ST_FP_DIV;

        when ST_ATANH_DIV_POST =>
          -- tmp_reg = (1+x)/(1-x), always > 0 for |x| < 1
          -- Route through LOGN pipeline via ST_A_SETTLE (a_reg needs
          -- settle cycles for fgetexp/fgetman fan-out, 7-cycle MCP).
          a_reg <= tmp_reg;
          log_scale_reg <= FP80_LN2;
          log_exp_add_en_reg <= '1';
          coeff_set_reg <= COEFF_SET_LOG;
          poly_degree_reg <= 9;
          trans_input_adjust_en_reg <= '1';
          trans_input_adjust_sub_reg <= '1';
          trans_post_mul_en_reg <= '1';
          trans_post_add_en_reg <= '1';
          trans_post_add_sub_reg <= '0';
          seed_domain_reg <= SEED_DOMAIN_LOG;
          seed_idx_reg <= 0;
          seed_return_state_reg <= ST_LOG_TABLE_INDEX;
          a_settle_count_reg <= 5;
          a_settle_return_reg <= ST_LOG_GETEXP;
          state_reg <= ST_A_SETTLE;

        when ST_ATANH_HALF_PREP =>
          -- Multiply ln result by 0.5
          mul_a_reg <= result_reg;
          mul_b_reg <= FP80_HALF;
          mul_rm_reg <= rm_reg;
          mul_rp_reg <= rp_reg;
          cont_state_reg <= ST_ATANH_HALF_POST;
          state_reg <= ST_FP_MUL;

        when ST_ATANH_HALF_POST =>
          result_reg <= tmp_reg;
          state_reg <= ST_DONE;

        when ST_FP_SQRT =>
          if fp_exec_busy_reg = '0' then
            trig_divrem_op_reg <= FPU_OP_SQRT;
            fp_exec_busy_reg <= '1';
            trig_div_start_reg <= '1';
          elsif trig_div_done = '1' then
            tmp_reg <= trig_div_result;
            trig_divrem_op_reg <= FPU_OP_DIV;
            state_reg <= cont_state_reg;
            fp_exec_busy_reg <= '0';
          end if;

        -- ================================================================
        -- LOG Table-Assisted Range Reduction States
        -- ================================================================
        when ST_LOG_TABLE_INDEX =>
          -- x_reg = m = mantissa in [1, 2) from fgetman
          -- Index = top 6 fractional bits = bits [62:57]
          log_table_addr_reg <= to_integer(unsigned(x_reg(62 downto 57)));
          state_reg <= ST_LOG_TABLE_WAIT;

        when ST_LOG_TABLE_WAIT =>
          -- BRAM read latency
          state_reg <= ST_LOG_TABLE_LATCH;

        when ST_LOG_TABLE_LATCH =>
          -- Latch c_i and ln(c_i) from tables
          c_reg <= log_center_q;           -- c_i (save for division)
          coeff0_override_en_reg <= '1';
          coeff0_override_reg <= log_ln_center_q;   -- ln(c_i) overrides ROM coeff0
          state_reg <= ST_LOG_DELTA_PREP;

        when ST_LOG_DELTA_PREP =>
          -- Compute delta = m - c_i
          add_a_reg <= x_reg;              -- m
          add_b_reg <= c_reg;              -- c_i
          add_sub_reg <= true;             -- subtraction
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_LOG_DELTA_POST;
          state_reg <= ST_FP_ADD;

        when ST_LOG_DELTA_POST =>
          -- tmp_reg = m - c_i (delta), compute u = delta * (1/c_i)
          -- Uses reciprocal table to avoid FP division (~50 cycle savings).
          mul_a_reg <= tmp_reg;            -- delta
          mul_b_reg <= log_recip_center_q; -- 1/c_i (from BRAM table)
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_LOG_U_POST;
          state_reg <= ST_FP_MUL;

        when ST_LOG_U_POST =>
          -- tmp_reg = u = (m - c_i) / c_i, a small value |u| < 1/128
          x_reg <= tmp_reg;
          -- Disable input adjust since we already computed u
          trans_input_adjust_en_reg <= '0';
          -- coeff0_override already set to ln(c_i) in ST_LOG_TABLE_LATCH
          -- Continue to polynomial via ST_TRANS_PREP (which will skip input adjust)
          state_reg <= ST_TRANS_PREP;

        when ST_TRANS_PREP =>
          if trans_input_adjust_en_reg = '1' then
            add_a_reg <= x_reg;
            if seed_domain_reg = SEED_DOMAIN_LOG then
              add_b_reg <= seed_aux0_reg;
            else
              add_b_reg <= trans_input_adjust_const_reg;
            end if;
            add_sub_reg <= (trans_input_adjust_sub_reg = '1');
            add_rm_reg <= FP_RND_NEAREST;
            add_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_TRANS_INPUT_ADJUST_POST;
            state_reg <= ST_TRANS_ADD_PREP;
          elsif trans_pre_mul_en_reg = '1' then
            mul_a_reg <= x_reg;
            if seed_domain_reg = SEED_DOMAIN_EXP then
              mul_b_reg <= seed_aux0_reg;
            else
              mul_b_reg <= trans_pre_mul_const_reg;
            end if;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_TRANS_PRE_MUL_POST;
            state_reg <= ST_FP_MUL;
          elsif exp_reduce_en_reg = '1' and exp_reduce_done_reg = '0' then
            mul_a_reg <= x_reg;
            mul_b_reg <= FP80_INV_LN2;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_EXP_REDUCE_K_POST;
            state_reg <= ST_FP_MUL;
          else
            state_reg <= ST_TRANS_POLY_INIT;
          end if;

        when ST_TRANS_ADD_PREP =>
          -- One-cycle launch stage to decouple add operand muxing from ST_FP_ADD.
          state_reg <= ST_FP_ADD;

        when ST_TRANS_INPUT_ADJUST_POST =>
          x_reg <= tmp_reg;
          trans_input_adjust_en_reg <= '0';
          state_reg <= ST_TRANS_PREP;

        when ST_TRANS_PRE_MUL_POST =>
          x_reg <= tmp_reg;
          trans_pre_mul_en_reg <= '0';
          state_reg <= ST_TRANS_PREP;

        when ST_TRANS_POLY_INIT =>
          -- Issue BRAM read for highest coefficient
          coeff_rom_addr_reg <= coeff_set_reg * 10 + poly_degree_reg;
          poly_idx_reg <= poly_degree_reg - 1;
          poly_init_flag <= '1';
          state_reg <= ST_TRANS_POLY_INIT_WAIT;

        when ST_TRANS_POLY_INIT_WAIT =>
          -- Wait for BRAM read latency (coeff_rom_q valid next cycle)
          state_reg <= ST_TRANS_POLY_MUL_PREP;

        when ST_TRANS_POLY_MUL_PREP =>
          mul_a_reg <= x_reg;
          if poly_init_flag = '1' then
            -- First iteration: use BRAM output directly (valid after 2-cycle latency)
            mul_b_reg <= coeff_rom_q;
            poly_init_flag <= '0';
          else
            -- Subsequent iterations: use accumulated polynomial result
            mul_b_reg <= poly_reg;
          end if;
          -- Pre-read coefficient for current poly_idx (needed at MUL_POST)
          coeff_rom_addr_reg <= coeff_set_reg * 10 + poly_idx_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRANS_POLY_MUL_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRANS_POLY_MUL_POST =>
          -- coeff_rom_q has coeff[poly_idx] (pre-read issued in MUL_PREP, 3+ cycles ago)
          if poly_idx_reg = 0 and coeff0_override_en_reg = '1' then
            coeff_sel := coeff0_override_reg;
          else
            coeff_sel := coeff_rom_q;
          end if;
          add_a_reg <= coeff_sel;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRANS_POLY_ADD_POST;
          state_reg <= ST_TRANS_ADD_PREP;

        when ST_TRANS_POLY_ADD_POST =>
          poly_reg <= tmp_reg;
          if poly_idx_reg = 0 then
            result_reg <= tmp_reg;
            state_reg <= ST_TRANS_POST_MUL_PREP;
          else
            poly_idx_reg <= poly_idx_reg - 1;
            state_reg <= ST_TRANS_POLY_MUL_PREP;
          end if;

        when ST_TRANS_POST_MUL_PREP =>
          if trans_post_mul_en_reg = '1' then
            mul_a_reg <= result_reg;
            if seed_domain_reg = SEED_DOMAIN_LOG then
              mul_b_reg <= seed_aux1_reg;
            else
              mul_b_reg <= trans_post_mul_const_reg;
            end if;
            mul_rm_reg <= FP_RND_NEAREST;
            mul_rp_reg <= FP_PREC_EXTENDED;
            cont_state_reg <= ST_TRANS_POST_MUL_POST;
            state_reg <= ST_FP_MUL;
          else
            state_reg <= ST_TRANS_POST_ADD_PREP;
          end if;

        when ST_TRANS_POST_MUL_POST =>
          result_reg <= tmp_reg;
          state_reg <= ST_TRANS_POST_ADD_PREP;

        when ST_TRANS_POST_ADD_PREP =>
          if trans_post_add_en_reg = '1' then
            if log_exp_add_en_reg = '1' then
              add_a_reg <= log_exp_term_reg;
            else
              add_a_reg <= trans_post_add_const_reg;
            end if;
            add_b_reg <= result_reg;
            add_sub_reg <= (trans_post_add_sub_reg = '1');
            add_rm_reg <= rm_reg;
            add_rp_reg <= rp_reg;
            cont_state_reg <= ST_TRANS_POST_ADD_POST;
            state_reg <= ST_TRANS_ADD_PREP;
          else
            add_a_reg <= result_reg;
            add_b_reg <= FP80_ZERO;
            add_sub_reg <= false;
            add_rm_reg <= rm_reg;
            add_rp_reg <= rp_reg;
            cont_state_reg <= ST_TRANS_FINAL_ROUND_POST;
            state_reg <= ST_TRANS_ADD_PREP;
          end if;

        when ST_TRANS_POST_ADD_POST =>
          if exp_reduce_en_reg = '1' then
            result_reg <= fscale_fp80(exp_k_reg, tmp_reg);
            if op_reg = FPU_OP_TANH then
              state_reg <= ST_TANH_EXP_POST;
            else
              state_reg <= ST_DONE;
            end if;
          elsif op_reg = FPU_OP_ATANH then
            result_reg <= tmp_reg;
            state_reg <= ST_ATANH_HALF_PREP;
          elsif (op_reg = FPU_OP_ATAN or op_reg = FPU_OP_ASIN or op_reg = FPU_OP_ACOS) and atan_recip_reg = '1' then
            result_reg <= tmp_reg;
            state_reg <= ST_ATAN_RECIP_SUB;
          elsif op_reg = FPU_OP_ACOS then
            result_reg <= tmp_reg;
            state_reg <= ST_ACOS_FINAL;
          elsif (op_reg = FPU_OP_ATAN or op_reg = FPU_OP_ASIN) and atan_neg_reg = '1' then
            result_reg <= tmp_reg;
            result_reg(FP_WIDTH-1) <= not tmp_reg(FP_WIDTH-1);
            state_reg <= ST_DONE;
          else
            result_reg <= tmp_reg;
            state_reg <= ST_DONE;
          end if;

        when ST_TRANS_FINAL_ROUND_POST =>
          if exp_reduce_en_reg = '1' then
            result_reg <= fscale_fp80(exp_k_reg, tmp_reg);
            if op_reg = FPU_OP_TANH then
              state_reg <= ST_TANH_EXP_POST;
            else
              state_reg <= ST_DONE;
            end if;
          elsif op_reg = FPU_OP_ATANH then
            result_reg <= tmp_reg;
            state_reg <= ST_ATANH_HALF_PREP;
          elsif (op_reg = FPU_OP_ATAN or op_reg = FPU_OP_ASIN or op_reg = FPU_OP_ACOS) and atan_recip_reg = '1' then
            result_reg <= tmp_reg;
            state_reg <= ST_ATAN_RECIP_SUB;
          elsif op_reg = FPU_OP_ACOS then
            result_reg <= tmp_reg;
            state_reg <= ST_ACOS_FINAL;
          elsif (op_reg = FPU_OP_ATAN or op_reg = FPU_OP_ASIN) and atan_neg_reg = '1' then
            result_reg <= tmp_reg;
            result_reg(FP_WIDTH-1) <= not tmp_reg(FP_WIDTH-1);
            state_reg <= ST_DONE;
          else
            result_reg <= tmp_reg;
            state_reg <= ST_DONE;
          end if;

        when ST_FP_MUL =>
          if fp_exec_busy_reg = '0' then
            fp_exec_busy_reg <= '1';
            trig_mul_start_reg <= '1';
          elsif trig_mul_done = '1' then
            tmp_reg <= trig_mul_result;
            state_reg <= cont_state_reg;
            fp_exec_busy_reg <= '0';
          end if;

        when ST_FP_ADD =>
          if fp_exec_busy_reg = '0' then
            fp_exec_busy_reg <= '1';
            trig_add_start_reg <= '1';
          elsif trig_add_done = '1' then
            tmp_reg <= trig_add_result;
            state_reg <= cont_state_reg;
            fp_exec_busy_reg <= '0';
          end if;

        when ST_FP_DIV =>
          if fp_exec_busy_reg = '0' then
            fp_exec_busy_reg <= '1';
            trig_div_start_reg <= '1';
          elsif trig_div_done = '1' then
            tmp_reg <= trig_div_result;
            state_reg <= cont_state_reg;
            fp_exec_busy_reg <= '0';
            if trig_div_flag_divzero = '1' then
              flag_divzero_reg <= '1';
            end if;
          end if;

        when ST_DONE =>
          done_reg <= '1';
          state_reg <= ST_IDLE;
      end case;
    end if;
  end process;

  busy <= '1' when state_reg /= ST_IDLE else '0';
  done <= done_reg;
  flag_divzero <= flag_divzero_reg;
  result <= result_reg;
  aux_valid <= aux_valid_reg;
  aux_result <= aux_result_reg;
  -- ----------------------------------------------------------------
  -- Save / Restore process for FSAVE/FRESTORE Busy frame support.
  -- ----------------------------------------------------------------
  p_save_restore : process(clk, reset_n)
  begin
    if reset_n = '0' then
      shadow_regs <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if save_req = '1' then
        -- Snapshot internal state into shadow registers.
        shadow_regs(0) <= std_logic_vector(to_unsigned(trig_state_t'pos(state_reg), 16))
                        & std_logic_vector(to_unsigned(trig_state_t'pos(cont_state_reg), 16));
        shadow_regs(1) <= std_logic_vector(to_unsigned(fpu_op_t'pos(op_reg), 16))
                        & std_logic_vector(to_unsigned(poly_idx_reg, 8))
                        & std_logic_vector(to_unsigned(seed_idx_reg, 8));
        shadow_regs(2) <= std_logic_vector(to_unsigned(seed_domain_t'pos(seed_domain_reg), 8))
                        & std_logic_vector(to_unsigned(trig_state_t'pos(seed_return_state_reg), 16))
                        & fp_exec_busy_reg & "0000000";
        shadow_regs(3) <= x_reg(31 downto 0);
        shadow_regs(4) <= x_reg(63 downto 32);
        shadow_regs(5) <= x_reg(79 downto 64) & poly_reg(79 downto 64);
        shadow_regs(6) <= poly_reg(31 downto 0);
        shadow_regs(7) <= poly_reg(63 downto 32);
        shadow_regs(8) <= tmp_reg(31 downto 0);
        shadow_regs(9) <= tmp_reg(63 downto 32);
        shadow_regs(10) <= tmp_reg(79 downto 64) & x"0000";
      end if;

      if restore_req = '1' and restore_wr = '1' then
        shadow_regs(restore_addr) <= restore_data;
      end if;
    end if;
  end process p_save_restore;

  save_data <= shadow_regs(save_addr);

end architecture rtl;
