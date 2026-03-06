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
    ST_TANH_X2_PREP,
    ST_TANH_X2_POST,
    ST_TANH_NUM_ADD_PREP,
    ST_TANH_NUM_ADD_POST,
    ST_TANH_NUM_MUL_POST,
    ST_TANH_DEN_MUL_PREP,
    ST_TANH_DEN_MUL_POST,
    ST_TANH_DEN_ADD_POST,
    ST_EXP_REDUCE_K_POST,
    ST_EXP_REDUCE_KLN2_POST,
    ST_EXP_REDUCE_R_POST,
    ST_LOG_EXP_TERM_POST,
    ST_LOG_GETEXP,
    ST_LOG_GETEXP_POST,
    ST_LOGNP1_Z_POST,
    ST_LOGNP1_META_POST,
    ST_LOGNP1_GETEXP_POST,
    ST_ATAN_INV_POST,
    ST_TRANS_PREP,
    ST_TRANS_ADD_PREP,
    ST_TRANS_INPUT_ADJUST_POST,
    ST_TRANS_PRE_MUL_POST,
    ST_TRANS_POLY_INIT,
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
  constant FP80_NINE      : fp80_t := x"40028800000000000000";
  constant FP80_TWENTY_SEVEN : fp80_t := x"4003D800000000000000";
  constant FP80_NEG_ONE   : fp80_t := x"BFFF8000000000000000";
  constant FP80_POS_INF   : fp80_t := x"7FFF8000000000000000";
  constant FP80_NEG_INF   : fp80_t := x"FFFF8000000000000000";
  constant FP80_PI        : fp80_t := x"4000C90FDAA22168C235";
  constant FP80_HALF_PI   : fp80_t := x"3FFFC90FDAA22168C235";
  constant FP80_QUARTER_PI : fp80_t := x"3FFEC90FDAA22168C000";
  constant FP80_NEG_HALF_PI : fp80_t := x"BFFFC90FDAA22168C235";
  constant FP80_TWO_PI    : fp80_t := x"4001C90FDAA22168C235";
  constant FP80_TWO_OVER_PI : fp80_t := x"3FFEA2F9836E4E4416F4";
  constant FP80_TRIG_INDEX_SCALE : fp80_t := x"4004A2F9836E4E441800"; -- 128/pi
  constant FP80_EPS_TRIG  : fp80_t := x"3FEB8000000000000000"; -- 2^-20

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
  constant FP80_LN10 : fp80_t := x"4000935D8DDDAAA8AC17";
  constant FP80_INV_LN2 : fp80_t := x"3FFFB8AA3B295C17F0BC";
  constant FP80_INV_LN10 : fp80_t := x"3FFDDE5BD8A937287195";
  constant FP80_LOG10_2 : fp80_t := x"3FFD9A209A84FBCFF798";

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
  constant ATAN_SEED_OFFSET_INIT : fp80_table64_t := (
    others => FP80_ZERO
  );

  signal state_reg : trig_state_t := ST_IDLE;
  signal cont_state_reg : trig_state_t := ST_IDLE;

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
  signal tanh_x2_reg : fp80_t := (others => '0');
  signal result_reg : fp80_t := (others => '0');
  signal aux_result_reg : fp80_t := (others => '0');
  signal done_reg : std_logic := '0';
  signal aux_valid_reg : std_logic := '0';
  signal flag_divzero_reg : std_logic := '0';

  signal coeff0_reg : fp80_t := (others => '0');
  signal coeff1_reg : fp80_t := (others => '0');
  signal coeff2_reg : fp80_t := (others => '0');
  signal coeff3_reg : fp80_t := (others => '0');
  signal coeff4_reg : fp80_t := (others => '0');
  signal coeff5_reg : fp80_t := (others => '0');
  signal coeff6_reg : fp80_t := (others => '0');
  signal coeff7_reg : fp80_t := (others => '0');
  signal coeff8_reg : fp80_t := (others => '0');
  signal coeff9_reg : fp80_t := (others => '0');
  signal poly_degree_reg : integer range 0 to 9 := 5;
  signal poly_idx_reg : integer range 0 to 9 := 0;
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

  signal trig_seed_center_rom : fp80_table64_t := TRIG_SEED_CENTER_INIT;
  signal trig_seed_sin_rom : fp80_table64_t := TRIG_SEED_SIN_INIT;
  signal trig_seed_cos_rom : fp80_table64_t := TRIG_SEED_COS_INIT;
  signal exp_seed_pre_mul_rom : fp80_table64_t := EXP_SEED_PRE_MUL_INIT;
  signal log_seed_input_adj_rom : fp80_table64_t := LOG_SEED_INPUT_ADJ_INIT;
  signal log_seed_post_scale_rom : fp80_table64_t := LOG_SEED_POST_SCALE_INIT;
  signal atan_seed_offset_rom : fp80_table64_t := ATAN_SEED_OFFSET_INIT;
  attribute rom_style : string;
  attribute rom_style of trig_seed_center_rom : signal is "block";
  attribute rom_style of trig_seed_sin_rom : signal is "block";
  attribute rom_style of trig_seed_cos_rom : signal is "block";
  attribute rom_style of exp_seed_pre_mul_rom : signal is "block";
  attribute rom_style of log_seed_input_adj_rom : signal is "block";
  attribute rom_style of log_seed_post_scale_rom : signal is "block";
  attribute rom_style of atan_seed_offset_rom : signal is "block";

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
  signal trig_div_start_reg : std_logic := '0';
  signal trig_div_busy : std_logic := '0';
  signal trig_div_done : std_logic := '0';
  signal trig_div_result : fp80_t := (others => '0');
  signal trig_div_flag_divzero : std_logic := '0';

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
    if res(FP_MANT_WIDTH-2 downto 0) = (res(FP_MANT_WIDTH-2 downto 0)'range => '0') then
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
      op_sel  => FPU_OP_DIV,
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
      done_reg <= '0';
      aux_valid_reg <= '0';
      flag_divzero_reg <= '0';
      result_reg <= (others => '0');
      aux_result_reg <= (others => '0');
      x_reg <= (others => '0');
      poly_reg <= (others => '0');
      tmp_reg <= (others => '0');
      tanh_x2_reg <= (others => '0');
      poly_idx_reg <= 0;
      poly_degree_reg <= 5;
      coeff6_reg <= (others => '0');
      coeff7_reg <= (others => '0');
      coeff8_reg <= (others => '0');
      coeff9_reg <= (others => '0');
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
            state_reg <= ST_CLASSIFY;
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
            coeff0_reg <= FP80_ZERO;
            coeff1_reg <= FP80_ZERO;
            coeff2_reg <= FP80_ZERO;
            coeff3_reg <= FP80_ZERO;
            coeff4_reg <= FP80_ZERO;
            coeff5_reg <= FP80_ZERO;
            coeff6_reg <= FP80_ZERO;
            coeff7_reg <= FP80_ZERO;
            coeff8_reg <= FP80_ZERO;
            coeff9_reg <= FP80_ZERO;
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
                  exp_reduce_en_reg <= '1';
                  coeff0_reg <= FP80_ONE;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_HALF;
                  coeff3_reg <= FP80_ONE_SIXTH;
                  coeff4_reg <= FP80_ONE_TWENTYFOURTH;
                  coeff5_reg <= FP80_ONE_120TH;
                  coeff6_reg <= FP80_ONE_720TH;
                  coeff7_reg <= FP80_ONE_5040TH;
                  coeff8_reg <= FP80_ONE_40320TH;
                  coeff9_reg <= FP80_ONE_362880TH;
                  poly_degree_reg <= 9;
                  seed_domain_reg <= SEED_DOMAIN_EXP;
                  seed_idx_reg <= 0;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
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
                  coeff0_reg <= FP80_ONE;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_HALF;
                  coeff3_reg <= FP80_ONE_SIXTH;
                  coeff4_reg <= FP80_ONE_TWENTYFOURTH;
                  coeff5_reg <= FP80_ONE_120TH;
                  coeff6_reg <= FP80_ONE_720TH;
                  coeff7_reg <= FP80_ONE_5040TH;
                  coeff8_reg <= FP80_ONE_40320TH;
                  coeff9_reg <= FP80_ONE_362880TH;
                  poly_degree_reg <= 9;
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  trans_post_add_const_reg <= FP80_NEG_ONE;
                  seed_domain_reg <= SEED_DOMAIN_EXP;
                  seed_idx_reg <= 0;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
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
                  exp_reduce_en_reg <= '1';
                  coeff0_reg <= FP80_ONE;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_HALF;
                  coeff3_reg <= FP80_ONE_SIXTH;
                  coeff4_reg <= FP80_ONE_TWENTYFOURTH;
                  coeff5_reg <= FP80_ONE_120TH;
                  coeff6_reg <= FP80_ONE_720TH;
                  coeff7_reg <= FP80_ONE_5040TH;
                  coeff8_reg <= FP80_ONE_40320TH;
                  coeff9_reg <= FP80_ONE_362880TH;
                  poly_degree_reg <= 9;
                  trans_pre_mul_en_reg <= '1';
                  seed_domain_reg <= SEED_DOMAIN_EXP;
                  seed_idx_reg <= 1;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
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
                  exp_reduce_en_reg <= '1';
                  coeff0_reg <= FP80_ONE;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_HALF;
                  coeff3_reg <= FP80_ONE_SIXTH;
                  coeff4_reg <= FP80_ONE_TWENTYFOURTH;
                  coeff5_reg <= FP80_ONE_120TH;
                  coeff6_reg <= FP80_ONE_720TH;
                  coeff7_reg <= FP80_ONE_5040TH;
                  coeff8_reg <= FP80_ONE_40320TH;
                  coeff9_reg <= FP80_ONE_362880TH;
                  poly_degree_reg <= 9;
                  trans_pre_mul_en_reg <= '1';
                  seed_domain_reg <= SEED_DOMAIN_EXP;
                  seed_idx_reg <= 2;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
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
                  -- Defer heavy fgetexp/fgetman to ST_LOG_GETEXP (2-cycle MCP).
                  log_scale_reg <= FP80_LN2;
                  log_exp_add_en_reg <= '1';
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_NEG_HALF;
                  coeff3_reg <= FP80_ONE_THIRD;
                  coeff4_reg <= FP80_NEG_ONE_FOURTH;
                  coeff5_reg <= FP80_ONE_FIFTH;
                  coeff6_reg <= FP80_NEG_ONE_SIXTH;
                  coeff7_reg <= FP80_ONE_SEVENTH;
                  coeff8_reg <= FP80_NEG_ONE_EIGHTH;
                  coeff9_reg <= FP80_ONE_NINTH;
                  poly_degree_reg <= 9;
                  trans_input_adjust_en_reg <= '1';
                  trans_input_adjust_sub_reg <= '1';
                  trans_post_mul_en_reg <= '1';
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  seed_domain_reg <= SEED_DOMAIN_LOG;
                  seed_idx_reg <= 0;
                  seed_return_state_reg <= ST_TRANS_PREP;
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
                  -- Defer heavy fgetexp/fgetman to ST_LOG_GETEXP (2-cycle MCP).
                  log_exp_add_en_reg <= '1';
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_NEG_HALF;
                  coeff3_reg <= FP80_ONE_THIRD;
                  coeff4_reg <= FP80_NEG_ONE_FOURTH;
                  coeff5_reg <= FP80_ONE_FIFTH;
                  coeff6_reg <= FP80_NEG_ONE_SIXTH;
                  coeff7_reg <= FP80_ONE_SEVENTH;
                  coeff8_reg <= FP80_NEG_ONE_EIGHTH;
                  coeff9_reg <= FP80_ONE_NINTH;
                  poly_degree_reg <= 9;
                  trans_input_adjust_en_reg <= '1';
                  trans_input_adjust_sub_reg <= '1';
                  trans_post_mul_en_reg <= '1';
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  seed_domain_reg <= SEED_DOMAIN_LOG;
                  seed_idx_reg <= 2;
                  seed_return_state_reg <= ST_TRANS_PREP;
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
                  -- Defer heavy fgetexp/fgetman to ST_LOG_GETEXP (2-cycle MCP).
                  log_scale_reg <= FP80_LOG10_2;
                  log_exp_add_en_reg <= '1';
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_NEG_HALF;
                  coeff3_reg <= FP80_ONE_THIRD;
                  coeff4_reg <= FP80_NEG_ONE_FOURTH;
                  coeff5_reg <= FP80_ONE_FIFTH;
                  coeff6_reg <= FP80_NEG_ONE_SIXTH;
                  coeff7_reg <= FP80_ONE_SEVENTH;
                  coeff8_reg <= FP80_NEG_ONE_EIGHTH;
                  coeff9_reg <= FP80_ONE_NINTH;
                  poly_degree_reg <= 9;
                  trans_input_adjust_en_reg <= '1';
                  trans_input_adjust_sub_reg <= '1';
                  trans_post_mul_en_reg <= '1';
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '0';
                  seed_domain_reg <= SEED_DOMAIN_LOG;
                  seed_idx_reg <= 3;
                  seed_return_state_reg <= ST_TRANS_PREP;
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
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_ZERO;
                  coeff3_reg <= FP80_NEG_ONE_THIRD;
                  coeff4_reg <= FP80_ZERO;
                  coeff5_reg <= FP80_ONE_FIFTH;
                  if abs_a_gt_one then
                    trans_post_add_en_reg <= '1';
                    trans_post_add_sub_reg <= '1';
                    if fp80_sign(a_reg) = '1' then
                      trans_post_add_const_reg <= FP80_NEG_HALF_PI;
                    else
                      trans_post_add_const_reg <= FP80_HALF_PI;
                    end if;
                    div_a_reg <= FP80_ONE;
                    div_b_reg <= x_local;
                    div_rm_reg <= FP_RND_NEAREST;
                    div_rp_reg <= FP_PREC_EXTENDED;
                    cont_state_reg <= ST_ATAN_INV_POST;
                    state_reg <= ST_FP_DIV;
                  else
                    seed_domain_reg <= SEED_DOMAIN_ATAN;
                    seed_idx_reg <= 0;
                    seed_return_state_reg <= ST_TRANS_PREP;
                    x_reg <= x_local;
                    state_reg <= ST_SEED_READ;
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
                else
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_ZERO;
                  coeff3_reg <= FP80_ONE_SIXTH;
                  coeff4_reg <= FP80_ZERO;
                  coeff5_reg <= FP80_THREE_FORTIETHS;
                  seed_domain_reg <= SEED_DOMAIN_ATAN;
                  seed_idx_reg <= 1;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
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
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_ZERO;
                  coeff3_reg <= FP80_ONE_SIXTH;
                  coeff4_reg <= FP80_ZERO;
                  coeff5_reg <= FP80_THREE_FORTIETHS;
                  trans_post_add_en_reg <= '1';
                  trans_post_add_sub_reg <= '1';
                  trans_post_add_const_reg <= FP80_HALF_PI;
                  seed_domain_reg <= SEED_DOMAIN_ATAN;
                  seed_idx_reg <= 2;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
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
                else
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_ZERO;
                  coeff3_reg <= FP80_ONE_THIRD;
                  coeff4_reg <= FP80_ZERO;
                  coeff5_reg <= FP80_ONE_FIFTH;
                  seed_domain_reg <= SEED_DOMAIN_ATAN;
                  seed_idx_reg <= 3;
                  seed_return_state_reg <= ST_TRANS_PREP;
                  x_reg <= x_local;
                  state_reg <= ST_SEED_READ;
                end if;

              when FPU_OP_SINH =>
                if fp80_is_inf(a_reg) then
                  result_reg <= a_reg;
                  state_reg <= ST_DONE;
                elsif fp80_is_zero(a_reg) then
                  result_reg <= FP80_ZERO;
                  state_reg <= ST_DONE;
                else
                  coeff0_reg <= FP80_ZERO;
                  coeff1_reg <= FP80_ONE;
                  coeff2_reg <= FP80_ZERO;
                  coeff3_reg <= FP80_ONE_SIXTH;
                  coeff4_reg <= FP80_ZERO;
                  coeff5_reg <= FP80_ONE_120TH;
                  coeff6_reg <= FP80_ZERO;
                  coeff7_reg <= FP80_ONE_5040TH;
                  coeff8_reg <= FP80_ZERO;
                  coeff9_reg <= FP80_ONE_362880TH;
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
                  coeff0_reg <= FP80_ONE;
                  coeff1_reg <= FP80_ZERO;
                  coeff2_reg <= FP80_HALF;
                  coeff3_reg <= FP80_ZERO;
                  coeff4_reg <= FP80_ONE_TWENTYFOURTH;
                  coeff5_reg <= FP80_ZERO;
                  coeff6_reg <= FP80_ONE_720TH;
                  coeff7_reg <= FP80_ZERO;
                  coeff8_reg <= FP80_ONE_40320TH;
                  coeff9_reg <= FP80_ZERO;
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
                  x_reg <= x_local;
                  state_reg <= ST_TANH_X2_PREP;
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
          mul_b_reg <= FP80_HALF_PI;
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
                seed_aux0_reg <= ATAN_SEED_OFFSET_INIT(seed_idx_reg);
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
              seed_aux0_reg <= atan_seed_offset_q;
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

        when ST_TANH_X2_PREP =>
          mul_a_reg <= x_reg;
          mul_b_reg <= x_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TANH_X2_POST;
          state_reg <= ST_FP_MUL;

        when ST_TANH_X2_POST =>
          tanh_x2_reg <= tmp_reg;
          state_reg <= ST_TANH_NUM_ADD_PREP;

        when ST_TANH_NUM_ADD_PREP =>
          add_a_reg <= FP80_TWENTY_SEVEN;
          add_b_reg <= tanh_x2_reg;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TANH_NUM_ADD_POST;
          state_reg <= ST_FP_ADD;

        when ST_TANH_NUM_ADD_POST =>
          mul_a_reg <= x_reg;
          mul_b_reg <= tmp_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TANH_NUM_MUL_POST;
          state_reg <= ST_FP_MUL;

        when ST_TANH_NUM_MUL_POST =>
          s_reg <= tmp_reg;
          state_reg <= ST_TANH_DEN_MUL_PREP;

        when ST_TANH_DEN_MUL_PREP =>
          mul_a_reg <= FP80_NINE;
          mul_b_reg <= tanh_x2_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TANH_DEN_MUL_POST;
          state_reg <= ST_FP_MUL;

        when ST_TANH_DEN_MUL_POST =>
          add_a_reg <= FP80_TWENTY_SEVEN;
          add_b_reg <= tmp_reg;
          add_sub_reg <= false;
          add_rm_reg <= FP_RND_NEAREST;
          add_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TANH_DEN_ADD_POST;
          state_reg <= ST_FP_ADD;

        when ST_TANH_DEN_ADD_POST =>
          c_reg <= tmp_reg;
          state_reg <= ST_TRIG_TAN_DIV;

        when ST_EXP_REDUCE_K_POST =>
          exp_k_reg <= fintrz_tmp;
          mul_a_reg <= fintrz_tmp;
          mul_b_reg <= FP80_LN2;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_EXP_REDUCE_KLN2_POST;
          state_reg <= ST_FP_MUL;

        when ST_EXP_REDUCE_KLN2_POST =>
          add_a_reg <= x_reg;
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
          -- a_reg was loaded in ST_IDLE, one full cycle before ST_CLASSIFY set up
          -- coefficients and transitioned here.  This gives the heavy combinational
          -- logic two clock periods (200 ns) to settle.
          unbiased_exp_local := fgetexp_unbiased_int(a_reg);
          log_unbiased_exp_reg <= unbiased_exp_local;
          if unbiased_exp_local = 0 then
            log_exp_term_zero_reg <= '1';
          else
            log_exp_term_zero_reg <= '0';
          end if;
          x_reg <= fgetman_a;
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
          coeff0_reg <= FP80_ZERO;
          coeff1_reg <= FP80_ONE;
          coeff2_reg <= FP80_NEG_HALF;
          coeff3_reg <= FP80_ONE_THIRD;
          coeff4_reg <= FP80_NEG_ONE_FOURTH;
          coeff5_reg <= FP80_ONE_FIFTH;
          coeff6_reg <= FP80_NEG_ONE_SIXTH;
          coeff7_reg <= FP80_ONE_SEVENTH;
          coeff8_reg <= FP80_NEG_ONE_EIGHTH;
          coeff9_reg <= FP80_ONE_NINTH;
          poly_degree_reg <= 9;
          trans_input_adjust_en_reg <= '1';
          trans_input_adjust_sub_reg <= '1';
          trans_post_mul_en_reg <= '1';
          trans_post_add_en_reg <= '1';
          trans_post_add_sub_reg <= '0';
          seed_domain_reg <= SEED_DOMAIN_LOG;
          seed_idx_reg <= 0;
          seed_return_state_reg <= ST_TRANS_PREP;
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
          seed_domain_reg <= SEED_DOMAIN_ATAN;
          seed_idx_reg <= 0;
          seed_return_state_reg <= ST_TRANS_PREP;
          x_reg <= tmp_reg;
          state_reg <= ST_SEED_READ;

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
          case poly_degree_reg is
            when 9 => poly_reg <= coeff9_reg; poly_idx_reg <= 8;
            when 8 => poly_reg <= coeff8_reg; poly_idx_reg <= 7;
            when 7 => poly_reg <= coeff7_reg; poly_idx_reg <= 6;
            when 6 => poly_reg <= coeff6_reg; poly_idx_reg <= 5;
            when others => poly_reg <= coeff5_reg; poly_idx_reg <= 4;
          end case;
          state_reg <= ST_TRANS_POLY_MUL_PREP;

        when ST_TRANS_POLY_MUL_PREP =>
          mul_a_reg <= x_reg;
          mul_b_reg <= poly_reg;
          mul_rm_reg <= FP_RND_NEAREST;
          mul_rp_reg <= FP_PREC_EXTENDED;
          cont_state_reg <= ST_TRANS_POLY_MUL_POST;
          state_reg <= ST_FP_MUL;

        when ST_TRANS_POLY_MUL_POST =>
          case poly_idx_reg is
            when 8 => coeff_sel := coeff8_reg;
            when 7 => coeff_sel := coeff7_reg;
            when 6 => coeff_sel := coeff6_reg;
            when 5 => coeff_sel := coeff5_reg;
            when 4 => coeff_sel := coeff4_reg;
            when 3 => coeff_sel := coeff3_reg;
            when 2 => coeff_sel := coeff2_reg;
            when 1 => coeff_sel := coeff1_reg;
            when others => coeff_sel := coeff0_reg;
          end case;
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
          else
            result_reg <= tmp_reg;
          end if;
          state_reg <= ST_DONE;

        when ST_TRANS_FINAL_ROUND_POST =>
          if exp_reduce_en_reg = '1' then
            result_reg <= fscale_fp80(exp_k_reg, tmp_reg);
          else
            result_reg <= tmp_reg;
          end if;
          state_reg <= ST_DONE;

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
