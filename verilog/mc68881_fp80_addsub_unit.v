module mc68881_fp80_addsub_unit
  (input  clk,
   input  reset_n,
   input  start,
   input  [79:0] a_in,
   input  [79:0] b_in,
   input  subtract,
   input  [1:0] round_mode,
   input  [1:0] round_prec,
   output busy,
   output done,
   output [79:0] result);
  reg [2:0] state_reg;
  reg [79:0] a_reg;
  reg [79:0] b_reg;
  reg sub_reg;
  reg [1:0] rm_reg;
  reg [1:0] rp_reg;
  reg a_sign_reg;
  reg [17:0] a_exp_reg;
  reg [17:0] b_exp_reg;
  reg sign_b_reg;
  reg [66:0] mant_a_ext_reg;
  reg [66:0] mant_b_ext_reg;
  reg [17:0] exp_res_reg;
  reg early_exit_reg;
  reg [79:0] early_result_reg;
  reg [67:0] mant_sum_reg;
  reg res_sign_reg;
  reg same_sign_reg;
  reg need_normalize_reg;
  reg done_reg;
  reg [79:0] result_reg;
  wire n51;
  wire [2:0] n53;
  wire [79:0] n54;
  wire [79:0] n55;
  wire n56;
  wire [1:0] n57;
  wire [1:0] n58;
  wire n60;
  wire n61;
  wire [63:0] n62;
  wire [14:0] n63;
  wire n65;
  wire n67;
  wire n68;
  wire [31:0] n75;
  wire n77;
  wire [31:0] n78;
  wire [63:0] n80;
  wire [30:0] n83;
  wire [63:0] n85;
  wire [15:0] n86;
  wire n88;
  wire [31:0] n89;
  wire [31:0] n91;
  wire [30:0] n92;
  wire [47:0] n93;
  wire [63:0] n95;
  wire [30:0] n96;
  wire [63:0] n97;
  wire [7:0] n98;
  wire n100;
  wire [31:0] n101;
  wire [31:0] n103;
  wire [30:0] n104;
  wire [55:0] n105;
  wire [63:0] n107;
  wire [30:0] n108;
  wire [63:0] n109;
  wire [3:0] n110;
  wire n112;
  wire [31:0] n113;
  wire [31:0] n115;
  wire [30:0] n116;
  wire [59:0] n117;
  wire [63:0] n119;
  wire [30:0] n120;
  wire [63:0] n121;
  wire [1:0] n122;
  wire n124;
  wire [31:0] n125;
  wire [31:0] n127;
  wire [30:0] n128;
  wire [61:0] n129;
  wire [63:0] n131;
  wire [30:0] n132;
  wire [63:0] n133;
  wire n134;
  wire n135;
  wire [31:0] n136;
  wire [31:0] n138;
  wire [30:0] n139;
  wire [30:0] n140;
  wire [63:0] n141;
  wire [31:0] n142;
  wire [31:0] n144;
  wire [17:0] n145;
  wire [14:0] n146;
  wire [17:0] n148;
  wire [17:0] n149;
  wire [63:0] n151;
  wire [63:0] n152;
  wire [14:0] n153;
  wire n155;
  wire n157;
  wire n158;
  wire [31:0] n165;
  wire n167;
  wire [31:0] n168;
  wire [63:0] n170;
  wire [30:0] n173;
  wire [63:0] n175;
  wire [15:0] n176;
  wire n178;
  wire [31:0] n179;
  wire [31:0] n181;
  wire [30:0] n182;
  wire [47:0] n183;
  wire [63:0] n185;
  wire [30:0] n186;
  wire [63:0] n187;
  wire [7:0] n188;
  wire n190;
  wire [31:0] n191;
  wire [31:0] n193;
  wire [30:0] n194;
  wire [55:0] n195;
  wire [63:0] n197;
  wire [30:0] n198;
  wire [63:0] n199;
  wire [3:0] n200;
  wire n202;
  wire [31:0] n203;
  wire [31:0] n205;
  wire [30:0] n206;
  wire [59:0] n207;
  wire [63:0] n209;
  wire [30:0] n210;
  wire [63:0] n211;
  wire [1:0] n212;
  wire n214;
  wire [31:0] n215;
  wire [31:0] n217;
  wire [30:0] n218;
  wire [61:0] n219;
  wire [63:0] n221;
  wire [30:0] n222;
  wire [63:0] n223;
  wire n224;
  wire n225;
  wire [31:0] n226;
  wire [31:0] n228;
  wire [30:0] n229;
  wire [30:0] n230;
  wire [63:0] n231;
  wire [31:0] n232;
  wire [31:0] n234;
  wire [17:0] n235;
  wire [14:0] n236;
  wire [17:0] n238;
  wire [17:0] n239;
  wire [63:0] n241;
  wire n242;
  wire n243;
  wire n244;
  wire n245;
  wire [66:0] n247;
  wire [66:0] n249;
  wire n261;
  wire [14:0] n264;
  wire [63:0] n266;
  wire [79:0] n267;
  wire [14:0] n268;
  wire n270;
  wire n282;
  wire [14:0] n285;
  wire [63:0] n287;
  wire [79:0] n288;
  localparam [63:0] n291 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n292;
  wire [14:0] n293;
  wire n295;
  wire [63:0] n296;
  wire n298;
  wire [63:0] n299;
  wire [63:0] n300;
  wire n301;
  wire n302;
  wire n303;
  wire n304;
  wire n305;
  wire n317;
  wire [14:0] n320;
  wire [63:0] n322;
  wire [79:0] n323;
  wire [14:0] n324;
  wire n326;
  wire n338;
  wire [14:0] n341;
  wire [63:0] n343;
  wire [79:0] n344;
  localparam [63:0] n347 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n348;
  wire [14:0] n349;
  wire n351;
  wire [63:0] n352;
  wire n354;
  wire [63:0] n355;
  wire [63:0] n356;
  wire n357;
  wire n358;
  wire n359;
  wire n360;
  wire n361;
  wire n362;
  wire n375;
  wire [14:0] n378;
  wire [63:0] n380;
  wire [79:0] n381;
  wire [14:0] n382;
  wire n384;
  wire n396;
  wire [14:0] n399;
  wire [63:0] n401;
  wire [79:0] n402;
  localparam [63:0] n405 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n406;
  wire [14:0] n407;
  wire n409;
  wire [63:0] n410;
  wire n412;
  wire [63:0] n413;
  wire [63:0] n414;
  wire n415;
  wire n416;
  wire n417;
  wire n418;
  wire n419;
  wire n431;
  wire [14:0] n434;
  wire [63:0] n436;
  wire [79:0] n437;
  wire [14:0] n438;
  wire n440;
  wire n452;
  wire [14:0] n455;
  wire [63:0] n457;
  wire [79:0] n458;
  localparam [63:0] n461 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n462;
  wire [14:0] n463;
  wire n465;
  wire [63:0] n466;
  wire n468;
  wire [63:0] n469;
  wire [63:0] n470;
  wire n471;
  wire n472;
  wire n473;
  wire n474;
  wire n475;
  wire n493;
  wire [14:0] n496;
  wire [63:0] n498;
  wire [79:0] n499;
  wire [14:0] n500;
  wire n502;
  wire n503;
  wire n504;
  wire n505;
  wire [62:0] n506;
  wire n508;
  wire n509;
  wire n521;
  wire [14:0] n524;
  wire [63:0] n526;
  wire [79:0] n527;
  wire [14:0] n528;
  wire n530;
  wire n531;
  wire n532;
  wire n533;
  wire [62:0] n534;
  wire n536;
  wire n537;
  wire n539;
  wire n542;
  wire n544;
  wire [79:0] n545;
  wire [79:0] n546;
  wire [79:0] n547;
  wire [79:0] n548;
  wire [15:0] n551;
  wire [62:0] n552;
  wire [79:0] n553;
  wire [80:0] n554;
  wire [79:0] n556;
  wire n568;
  wire [14:0] n571;
  wire [63:0] n573;
  wire [79:0] n574;
  localparam [63:0] n577 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n578;
  wire [14:0] n579;
  wire n581;
  wire [63:0] n582;
  wire n584;
  wire [63:0] n585;
  wire [63:0] n586;
  wire n587;
  wire n588;
  wire n589;
  wire n601;
  wire [14:0] n604;
  wire [63:0] n606;
  wire [79:0] n607;
  localparam [63:0] n610 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n611;
  wire [14:0] n612;
  wire n614;
  wire [63:0] n615;
  wire n617;
  wire [63:0] n618;
  wire [63:0] n619;
  wire n620;
  wire n621;
  wire n622;
  wire n623;
  wire n635;
  wire [14:0] n638;
  wire [63:0] n640;
  wire [79:0] n641;
  localparam [63:0] n644 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n645;
  wire [14:0] n646;
  wire n648;
  wire [63:0] n649;
  wire n651;
  wire [63:0] n652;
  wire [63:0] n653;
  wire n654;
  wire n655;
  wire n656;
  wire n668;
  wire [14:0] n671;
  wire [63:0] n673;
  wire [79:0] n674;
  localparam [63:0] n677 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n678;
  wire [14:0] n679;
  wire n681;
  wire [63:0] n682;
  wire n684;
  wire [63:0] n685;
  wire [63:0] n686;
  wire n687;
  wire n688;
  wire n689;
  wire n690;
  wire n691;
  wire n692;
  wire n693;
  wire n694;
  wire n695;
  wire n696;
  wire n697;
  wire n698;
  wire n699;
  wire n700;
  wire n701;
  wire [79:0] n707;
  wire [79:0] n708;
  wire [79:0] n709;
  wire n721;
  wire [14:0] n724;
  wire [63:0] n726;
  wire [79:0] n727;
  localparam [63:0] n730 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n731;
  wire [14:0] n732;
  wire n734;
  wire [63:0] n735;
  wire n737;
  wire [63:0] n738;
  wire [63:0] n739;
  wire n740;
  wire n741;
  wire n742;
  wire n743;
  wire n744;
  wire [78:0] n745;
  wire [79:0] n746;
  wire [79:0] n747;
  wire [79:0] n748;
  wire [79:0] n749;
  wire [14:0] n750;
  wire n752;
  wire [63:0] n753;
  wire n755;
  wire n756;
  wire n757;
  wire n758;
  wire [78:0] n759;
  wire [79:0] n760;
  wire [79:0] n761;
  wire [14:0] n762;
  wire n764;
  wire [63:0] n765;
  wire n767;
  wire n768;
  wire n771;
  wire [79:0] n772;
  wire n774;
  wire [79:0] n775;
  wire n777;
  wire [79:0] n778;
  wire n780;
  wire [79:0] n782;
  wire n784;
  wire [31:0] n785;
  wire [31:0] n786;
  wire n787;
  wire [31:0] n788;
  wire [31:0] n789;
  wire [31:0] n790;
  wire [30:0] n791;
  wire [31:0] n800;
  wire n802;
  wire n805;
  wire n809;
  wire [66:0] n811;
  wire [31:0] n812;
  wire n814;
  wire n816;
  wire n819;
  wire n821;
  wire n823;
  wire n825;
  wire [66:0] n827;
  wire n829;
  wire n831;
  wire [66:0] n832;
  wire n833;
  wire n834;
  wire n835;
  wire n837;
  wire n839;
  wire n840;
  wire n841;
  wire n842;
  wire n844;
  localparam [66:0] n845 = 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  wire [65:0] n846;
  wire n848;
  wire n850;
  wire n852;
  localparam [66:0] n853 = 67'bX;
  wire [65:0] n854;
  wire [66:0] n855;
  wire n856;
  wire n857;
  wire n858;
  wire n859;
  wire n860;
  wire [64:0] n861;
  wire [66:0] n862;
  wire n863;
  wire n864;
  wire n865;
  wire n866;
  wire n867;
  wire [63:0] n868;
  wire [66:0] n869;
  wire n870;
  wire n871;
  wire n872;
  wire n873;
  wire n874;
  wire [62:0] n875;
  wire [66:0] n876;
  wire n877;
  wire n878;
  wire n879;
  wire n880;
  wire n881;
  wire [61:0] n882;
  wire [66:0] n883;
  wire n884;
  wire n885;
  wire n886;
  wire n887;
  wire n888;
  wire [60:0] n889;
  wire [66:0] n890;
  wire n891;
  wire n892;
  wire n893;
  wire n894;
  wire n895;
  wire [59:0] n896;
  wire [66:0] n897;
  wire n898;
  wire n899;
  wire n900;
  wire n901;
  wire n902;
  wire [58:0] n903;
  wire [66:0] n904;
  wire n905;
  wire n906;
  wire n907;
  wire n908;
  wire n909;
  wire [57:0] n910;
  wire [66:0] n911;
  wire n912;
  wire n913;
  wire n914;
  wire n915;
  wire n916;
  wire [56:0] n917;
  wire [66:0] n918;
  wire n919;
  wire n920;
  wire n921;
  wire n922;
  wire n923;
  wire [55:0] n924;
  wire [66:0] n925;
  wire n926;
  wire n927;
  wire n928;
  wire n929;
  wire n930;
  wire [54:0] n931;
  wire [66:0] n932;
  wire n933;
  wire n934;
  wire n935;
  wire n936;
  wire n937;
  wire [53:0] n938;
  wire [66:0] n939;
  wire n940;
  wire n941;
  wire n942;
  wire n943;
  wire n944;
  wire [52:0] n945;
  wire [66:0] n946;
  wire n947;
  wire n948;
  wire n949;
  wire n950;
  wire n951;
  wire [51:0] n952;
  wire [66:0] n953;
  wire n954;
  wire n955;
  wire n956;
  wire n957;
  wire n958;
  wire [50:0] n959;
  wire [66:0] n960;
  wire n961;
  wire n962;
  wire n963;
  wire n964;
  wire n965;
  wire [49:0] n966;
  wire [66:0] n967;
  wire n968;
  wire n969;
  wire n970;
  wire n971;
  wire n972;
  wire [48:0] n973;
  wire [66:0] n974;
  wire n975;
  wire n976;
  wire n977;
  wire n978;
  wire n979;
  wire [47:0] n980;
  wire [66:0] n981;
  wire n982;
  wire n983;
  wire n984;
  wire n985;
  wire n986;
  wire [46:0] n987;
  wire [66:0] n988;
  wire n989;
  wire n990;
  wire n991;
  wire n992;
  wire n993;
  wire [45:0] n994;
  wire [66:0] n995;
  wire n996;
  wire n997;
  wire n998;
  wire n999;
  wire n1000;
  wire [44:0] n1001;
  wire [66:0] n1002;
  wire n1003;
  wire n1004;
  wire n1005;
  wire n1006;
  wire n1007;
  wire [43:0] n1008;
  wire [66:0] n1009;
  wire n1010;
  wire n1011;
  wire n1012;
  wire n1013;
  wire n1014;
  wire [42:0] n1015;
  wire [66:0] n1016;
  wire n1017;
  wire n1018;
  wire n1019;
  wire n1020;
  wire n1021;
  wire [41:0] n1022;
  wire [66:0] n1023;
  wire n1024;
  wire n1025;
  wire n1026;
  wire n1027;
  wire n1028;
  wire [40:0] n1029;
  wire [66:0] n1030;
  wire n1031;
  wire n1032;
  wire n1033;
  wire n1034;
  wire n1035;
  wire [39:0] n1036;
  wire [66:0] n1037;
  wire n1038;
  wire n1039;
  wire n1040;
  wire n1041;
  wire n1042;
  wire [38:0] n1043;
  wire [66:0] n1044;
  wire n1045;
  wire n1046;
  wire n1047;
  wire n1048;
  wire n1049;
  wire [37:0] n1050;
  wire [66:0] n1051;
  wire n1052;
  wire n1053;
  wire n1054;
  wire n1055;
  wire n1056;
  wire [36:0] n1057;
  wire [66:0] n1058;
  wire n1059;
  wire n1060;
  wire n1061;
  wire n1062;
  wire n1063;
  wire [35:0] n1064;
  wire [66:0] n1065;
  wire n1066;
  wire n1067;
  wire n1068;
  wire n1069;
  wire n1070;
  wire [34:0] n1071;
  wire [66:0] n1072;
  wire n1073;
  wire n1074;
  wire n1075;
  wire n1076;
  wire n1077;
  wire [33:0] n1078;
  wire [66:0] n1079;
  wire n1080;
  wire n1081;
  wire n1082;
  wire n1083;
  wire n1084;
  wire [32:0] n1085;
  wire [66:0] n1086;
  wire n1087;
  wire n1088;
  wire n1089;
  wire n1090;
  wire n1091;
  wire [31:0] n1092;
  wire [66:0] n1093;
  wire n1094;
  wire n1095;
  wire n1096;
  wire n1097;
  wire n1098;
  wire [30:0] n1099;
  wire [66:0] n1100;
  wire n1101;
  wire n1102;
  wire n1103;
  wire n1104;
  wire n1105;
  wire [29:0] n1106;
  wire [66:0] n1107;
  wire n1108;
  wire n1109;
  wire n1110;
  wire n1111;
  wire n1112;
  wire [28:0] n1113;
  wire [66:0] n1114;
  wire n1115;
  wire n1116;
  wire n1117;
  wire n1118;
  wire n1119;
  wire [27:0] n1120;
  wire [66:0] n1121;
  wire n1122;
  wire n1123;
  wire n1124;
  wire n1125;
  wire n1126;
  wire [26:0] n1127;
  wire [66:0] n1128;
  wire n1129;
  wire n1130;
  wire n1131;
  wire n1132;
  wire n1133;
  wire [25:0] n1134;
  wire [66:0] n1135;
  wire n1136;
  wire n1137;
  wire n1138;
  wire n1139;
  wire n1140;
  wire [24:0] n1141;
  wire [66:0] n1142;
  wire n1143;
  wire n1144;
  wire n1145;
  wire n1146;
  wire n1147;
  wire [23:0] n1148;
  wire [66:0] n1149;
  wire n1150;
  wire n1151;
  wire n1152;
  wire n1153;
  wire n1154;
  wire [22:0] n1155;
  wire [66:0] n1156;
  wire n1157;
  wire n1158;
  wire n1159;
  wire n1160;
  wire n1161;
  wire [21:0] n1162;
  wire [66:0] n1163;
  wire n1164;
  wire n1165;
  wire n1166;
  wire n1167;
  wire n1168;
  wire [20:0] n1169;
  wire [66:0] n1170;
  wire n1171;
  wire n1172;
  wire n1173;
  wire n1174;
  wire n1175;
  wire [19:0] n1176;
  wire [66:0] n1177;
  wire n1178;
  wire n1179;
  wire n1180;
  wire n1181;
  wire n1182;
  wire [18:0] n1183;
  wire [66:0] n1184;
  wire n1185;
  wire n1186;
  wire n1187;
  wire n1188;
  wire n1189;
  wire [17:0] n1190;
  wire [66:0] n1191;
  wire n1192;
  wire n1193;
  wire n1194;
  wire n1195;
  wire n1196;
  wire [16:0] n1197;
  wire [66:0] n1198;
  wire n1199;
  wire n1200;
  wire n1201;
  wire n1202;
  wire n1203;
  wire [15:0] n1204;
  wire [66:0] n1205;
  wire n1206;
  wire n1207;
  wire n1208;
  wire n1209;
  wire n1210;
  wire [14:0] n1211;
  wire [66:0] n1212;
  wire n1213;
  wire n1214;
  wire n1215;
  wire n1216;
  wire n1217;
  wire [13:0] n1218;
  wire [66:0] n1219;
  wire n1220;
  wire n1221;
  wire n1222;
  wire n1223;
  wire n1224;
  wire [12:0] n1225;
  wire [66:0] n1226;
  wire n1227;
  wire n1228;
  wire n1229;
  wire n1230;
  wire n1231;
  wire [11:0] n1232;
  wire [66:0] n1233;
  wire n1234;
  wire n1235;
  wire n1236;
  wire n1237;
  wire n1238;
  wire [10:0] n1239;
  wire [66:0] n1240;
  wire n1241;
  wire n1242;
  wire n1243;
  wire n1244;
  wire n1245;
  wire [9:0] n1246;
  wire [66:0] n1247;
  wire n1248;
  wire n1249;
  wire n1250;
  wire n1251;
  wire n1252;
  wire [8:0] n1253;
  wire [66:0] n1254;
  wire n1255;
  wire n1256;
  wire n1257;
  wire n1258;
  wire n1259;
  wire [7:0] n1260;
  wire [66:0] n1261;
  wire n1262;
  wire n1263;
  wire n1264;
  wire n1265;
  wire n1266;
  wire [6:0] n1267;
  wire [66:0] n1268;
  wire n1269;
  wire n1270;
  wire n1271;
  wire n1272;
  wire n1273;
  wire [5:0] n1274;
  wire [66:0] n1275;
  wire n1276;
  wire n1277;
  wire n1278;
  wire n1279;
  wire n1280;
  wire [4:0] n1281;
  wire [66:0] n1282;
  wire n1283;
  wire n1284;
  wire n1285;
  wire n1286;
  wire n1287;
  wire [3:0] n1288;
  wire [66:0] n1289;
  wire n1290;
  wire n1291;
  wire n1292;
  wire n1293;
  wire n1294;
  wire [2:0] n1295;
  wire [66:0] n1296;
  wire n1297;
  wire n1298;
  wire n1299;
  wire n1300;
  wire n1301;
  wire [1:0] n1302;
  wire [66:0] n1303;
  wire n1304;
  wire n1305;
  wire n1306;
  wire n1307;
  wire n1308;
  wire n1309;
  wire [66:0] n1310;
  wire n1311;
  wire n1312;
  wire n1313;
  wire n1314;
  wire n1315;
  wire n1316;
  wire [65:0] n1317;
  wire [65:0] n1318;
  wire [31:0] n1319;
  wire [31:0] n1321;
  wire [6:0] n1322;
  wire [66:0] n1324;
  wire n1326;
  wire [66:0] n1327;
  wire [66:0] n1328;
  wire [66:0] n1329;
  wire n1331;
  wire n1332;
  wire n1334;
  wire n1336;
  wire [65:0] n1337;
  wire [66:0] n1338;
  wire [66:0] n1343;
  wire [31:0] n1344;
  wire [31:0] n1345;
  wire [31:0] n1346;
  wire n1347;
  wire [31:0] n1348;
  wire [31:0] n1349;
  wire [31:0] n1350;
  wire [30:0] n1351;
  wire [31:0] n1360;
  wire n1362;
  wire n1365;
  wire n1369;
  wire [66:0] n1371;
  wire [31:0] n1372;
  wire n1374;
  wire n1376;
  wire n1379;
  wire n1381;
  wire n1383;
  wire n1385;
  wire [66:0] n1387;
  wire n1389;
  wire n1391;
  wire [66:0] n1392;
  wire n1393;
  wire n1394;
  wire n1395;
  wire n1397;
  wire n1399;
  wire n1400;
  wire n1401;
  wire n1402;
  wire n1404;
  localparam [66:0] n1405 = 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  wire [65:0] n1406;
  wire n1408;
  wire n1410;
  wire n1412;
  localparam [66:0] n1413 = 67'bX;
  wire [65:0] n1414;
  wire [66:0] n1415;
  wire n1416;
  wire n1417;
  wire n1418;
  wire n1419;
  wire n1420;
  wire [64:0] n1421;
  wire [66:0] n1422;
  wire n1423;
  wire n1424;
  wire n1425;
  wire n1426;
  wire n1427;
  wire [63:0] n1428;
  wire [66:0] n1429;
  wire n1430;
  wire n1431;
  wire n1432;
  wire n1433;
  wire n1434;
  wire [62:0] n1435;
  wire [66:0] n1436;
  wire n1437;
  wire n1438;
  wire n1439;
  wire n1440;
  wire n1441;
  wire [61:0] n1442;
  wire [66:0] n1443;
  wire n1444;
  wire n1445;
  wire n1446;
  wire n1447;
  wire n1448;
  wire [60:0] n1449;
  wire [66:0] n1450;
  wire n1451;
  wire n1452;
  wire n1453;
  wire n1454;
  wire n1455;
  wire [59:0] n1456;
  wire [66:0] n1457;
  wire n1458;
  wire n1459;
  wire n1460;
  wire n1461;
  wire n1462;
  wire [58:0] n1463;
  wire [66:0] n1464;
  wire n1465;
  wire n1466;
  wire n1467;
  wire n1468;
  wire n1469;
  wire [57:0] n1470;
  wire [66:0] n1471;
  wire n1472;
  wire n1473;
  wire n1474;
  wire n1475;
  wire n1476;
  wire [56:0] n1477;
  wire [66:0] n1478;
  wire n1479;
  wire n1480;
  wire n1481;
  wire n1482;
  wire n1483;
  wire [55:0] n1484;
  wire [66:0] n1485;
  wire n1486;
  wire n1487;
  wire n1488;
  wire n1489;
  wire n1490;
  wire [54:0] n1491;
  wire [66:0] n1492;
  wire n1493;
  wire n1494;
  wire n1495;
  wire n1496;
  wire n1497;
  wire [53:0] n1498;
  wire [66:0] n1499;
  wire n1500;
  wire n1501;
  wire n1502;
  wire n1503;
  wire n1504;
  wire [52:0] n1505;
  wire [66:0] n1506;
  wire n1507;
  wire n1508;
  wire n1509;
  wire n1510;
  wire n1511;
  wire [51:0] n1512;
  wire [66:0] n1513;
  wire n1514;
  wire n1515;
  wire n1516;
  wire n1517;
  wire n1518;
  wire [50:0] n1519;
  wire [66:0] n1520;
  wire n1521;
  wire n1522;
  wire n1523;
  wire n1524;
  wire n1525;
  wire [49:0] n1526;
  wire [66:0] n1527;
  wire n1528;
  wire n1529;
  wire n1530;
  wire n1531;
  wire n1532;
  wire [48:0] n1533;
  wire [66:0] n1534;
  wire n1535;
  wire n1536;
  wire n1537;
  wire n1538;
  wire n1539;
  wire [47:0] n1540;
  wire [66:0] n1541;
  wire n1542;
  wire n1543;
  wire n1544;
  wire n1545;
  wire n1546;
  wire [46:0] n1547;
  wire [66:0] n1548;
  wire n1549;
  wire n1550;
  wire n1551;
  wire n1552;
  wire n1553;
  wire [45:0] n1554;
  wire [66:0] n1555;
  wire n1556;
  wire n1557;
  wire n1558;
  wire n1559;
  wire n1560;
  wire [44:0] n1561;
  wire [66:0] n1562;
  wire n1563;
  wire n1564;
  wire n1565;
  wire n1566;
  wire n1567;
  wire [43:0] n1568;
  wire [66:0] n1569;
  wire n1570;
  wire n1571;
  wire n1572;
  wire n1573;
  wire n1574;
  wire [42:0] n1575;
  wire [66:0] n1576;
  wire n1577;
  wire n1578;
  wire n1579;
  wire n1580;
  wire n1581;
  wire [41:0] n1582;
  wire [66:0] n1583;
  wire n1584;
  wire n1585;
  wire n1586;
  wire n1587;
  wire n1588;
  wire [40:0] n1589;
  wire [66:0] n1590;
  wire n1591;
  wire n1592;
  wire n1593;
  wire n1594;
  wire n1595;
  wire [39:0] n1596;
  wire [66:0] n1597;
  wire n1598;
  wire n1599;
  wire n1600;
  wire n1601;
  wire n1602;
  wire [38:0] n1603;
  wire [66:0] n1604;
  wire n1605;
  wire n1606;
  wire n1607;
  wire n1608;
  wire n1609;
  wire [37:0] n1610;
  wire [66:0] n1611;
  wire n1612;
  wire n1613;
  wire n1614;
  wire n1615;
  wire n1616;
  wire [36:0] n1617;
  wire [66:0] n1618;
  wire n1619;
  wire n1620;
  wire n1621;
  wire n1622;
  wire n1623;
  wire [35:0] n1624;
  wire [66:0] n1625;
  wire n1626;
  wire n1627;
  wire n1628;
  wire n1629;
  wire n1630;
  wire [34:0] n1631;
  wire [66:0] n1632;
  wire n1633;
  wire n1634;
  wire n1635;
  wire n1636;
  wire n1637;
  wire [33:0] n1638;
  wire [66:0] n1639;
  wire n1640;
  wire n1641;
  wire n1642;
  wire n1643;
  wire n1644;
  wire [32:0] n1645;
  wire [66:0] n1646;
  wire n1647;
  wire n1648;
  wire n1649;
  wire n1650;
  wire n1651;
  wire [31:0] n1652;
  wire [66:0] n1653;
  wire n1654;
  wire n1655;
  wire n1656;
  wire n1657;
  wire n1658;
  wire [30:0] n1659;
  wire [66:0] n1660;
  wire n1661;
  wire n1662;
  wire n1663;
  wire n1664;
  wire n1665;
  wire [29:0] n1666;
  wire [66:0] n1667;
  wire n1668;
  wire n1669;
  wire n1670;
  wire n1671;
  wire n1672;
  wire [28:0] n1673;
  wire [66:0] n1674;
  wire n1675;
  wire n1676;
  wire n1677;
  wire n1678;
  wire n1679;
  wire [27:0] n1680;
  wire [66:0] n1681;
  wire n1682;
  wire n1683;
  wire n1684;
  wire n1685;
  wire n1686;
  wire [26:0] n1687;
  wire [66:0] n1688;
  wire n1689;
  wire n1690;
  wire n1691;
  wire n1692;
  wire n1693;
  wire [25:0] n1694;
  wire [66:0] n1695;
  wire n1696;
  wire n1697;
  wire n1698;
  wire n1699;
  wire n1700;
  wire [24:0] n1701;
  wire [66:0] n1702;
  wire n1703;
  wire n1704;
  wire n1705;
  wire n1706;
  wire n1707;
  wire [23:0] n1708;
  wire [66:0] n1709;
  wire n1710;
  wire n1711;
  wire n1712;
  wire n1713;
  wire n1714;
  wire [22:0] n1715;
  wire [66:0] n1716;
  wire n1717;
  wire n1718;
  wire n1719;
  wire n1720;
  wire n1721;
  wire [21:0] n1722;
  wire [66:0] n1723;
  wire n1724;
  wire n1725;
  wire n1726;
  wire n1727;
  wire n1728;
  wire [20:0] n1729;
  wire [66:0] n1730;
  wire n1731;
  wire n1732;
  wire n1733;
  wire n1734;
  wire n1735;
  wire [19:0] n1736;
  wire [66:0] n1737;
  wire n1738;
  wire n1739;
  wire n1740;
  wire n1741;
  wire n1742;
  wire [18:0] n1743;
  wire [66:0] n1744;
  wire n1745;
  wire n1746;
  wire n1747;
  wire n1748;
  wire n1749;
  wire [17:0] n1750;
  wire [66:0] n1751;
  wire n1752;
  wire n1753;
  wire n1754;
  wire n1755;
  wire n1756;
  wire [16:0] n1757;
  wire [66:0] n1758;
  wire n1759;
  wire n1760;
  wire n1761;
  wire n1762;
  wire n1763;
  wire [15:0] n1764;
  wire [66:0] n1765;
  wire n1766;
  wire n1767;
  wire n1768;
  wire n1769;
  wire n1770;
  wire [14:0] n1771;
  wire [66:0] n1772;
  wire n1773;
  wire n1774;
  wire n1775;
  wire n1776;
  wire n1777;
  wire [13:0] n1778;
  wire [66:0] n1779;
  wire n1780;
  wire n1781;
  wire n1782;
  wire n1783;
  wire n1784;
  wire [12:0] n1785;
  wire [66:0] n1786;
  wire n1787;
  wire n1788;
  wire n1789;
  wire n1790;
  wire n1791;
  wire [11:0] n1792;
  wire [66:0] n1793;
  wire n1794;
  wire n1795;
  wire n1796;
  wire n1797;
  wire n1798;
  wire [10:0] n1799;
  wire [66:0] n1800;
  wire n1801;
  wire n1802;
  wire n1803;
  wire n1804;
  wire n1805;
  wire [9:0] n1806;
  wire [66:0] n1807;
  wire n1808;
  wire n1809;
  wire n1810;
  wire n1811;
  wire n1812;
  wire [8:0] n1813;
  wire [66:0] n1814;
  wire n1815;
  wire n1816;
  wire n1817;
  wire n1818;
  wire n1819;
  wire [7:0] n1820;
  wire [66:0] n1821;
  wire n1822;
  wire n1823;
  wire n1824;
  wire n1825;
  wire n1826;
  wire [6:0] n1827;
  wire [66:0] n1828;
  wire n1829;
  wire n1830;
  wire n1831;
  wire n1832;
  wire n1833;
  wire [5:0] n1834;
  wire [66:0] n1835;
  wire n1836;
  wire n1837;
  wire n1838;
  wire n1839;
  wire n1840;
  wire [4:0] n1841;
  wire [66:0] n1842;
  wire n1843;
  wire n1844;
  wire n1845;
  wire n1846;
  wire n1847;
  wire [3:0] n1848;
  wire [66:0] n1849;
  wire n1850;
  wire n1851;
  wire n1852;
  wire n1853;
  wire n1854;
  wire [2:0] n1855;
  wire [66:0] n1856;
  wire n1857;
  wire n1858;
  wire n1859;
  wire n1860;
  wire n1861;
  wire [1:0] n1862;
  wire [66:0] n1863;
  wire n1864;
  wire n1865;
  wire n1866;
  wire n1867;
  wire n1868;
  wire n1869;
  wire [66:0] n1870;
  wire n1871;
  wire n1872;
  wire n1873;
  wire n1874;
  wire n1875;
  wire n1876;
  wire [65:0] n1877;
  wire [65:0] n1878;
  wire [31:0] n1879;
  wire [31:0] n1881;
  wire [6:0] n1882;
  wire [66:0] n1884;
  wire n1886;
  wire [66:0] n1887;
  wire [66:0] n1888;
  wire [66:0] n1889;
  wire n1891;
  wire n1892;
  wire n1894;
  wire n1896;
  wire [65:0] n1897;
  wire [66:0] n1898;
  wire [66:0] n1903;
  wire [31:0] n1904;
  wire [31:0] n1905;
  wire [66:0] n1906;
  wire [31:0] n1907;
  wire [66:0] n1909;
  wire [66:0] n1910;
  wire [31:0] n1911;
  wire [17:0] n1913;
  wire n1914;
  wire [2:0] n1917;
  wire [66:0] n1918;
  wire [66:0] n1919;
  wire [17:0] n1920;
  wire n1921;
  wire n1924;
  wire [79:0] n1925;
  wire n1931;
  wire [67:0] n1933;
  wire [67:0] n1935;
  wire [67:0] n1936;
  wire n1937;
  wire [66:0] n1939;
  wire n1947;
  localparam [66:0] n1948 = 67'bX;
  wire [65:0] n1949;
  wire [66:0] n1950;
  wire n1951;
  wire n1952;
  wire n1953;
  wire [64:0] n1954;
  wire [66:0] n1955;
  wire n1956;
  wire n1957;
  wire n1958;
  wire [63:0] n1959;
  wire [66:0] n1960;
  wire n1961;
  wire n1962;
  wire n1963;
  wire [62:0] n1964;
  wire [66:0] n1965;
  wire n1966;
  wire n1967;
  wire n1968;
  wire [61:0] n1969;
  wire [66:0] n1970;
  wire n1971;
  wire n1972;
  wire n1973;
  wire [60:0] n1974;
  wire [66:0] n1975;
  wire n1976;
  wire n1977;
  wire n1978;
  wire [59:0] n1979;
  wire [66:0] n1980;
  wire n1981;
  wire n1982;
  wire n1983;
  wire [58:0] n1984;
  wire [66:0] n1985;
  wire n1986;
  wire n1987;
  wire n1988;
  wire [57:0] n1989;
  wire [66:0] n1990;
  wire n1991;
  wire n1992;
  wire n1993;
  wire [56:0] n1994;
  wire [66:0] n1995;
  wire n1996;
  wire n1997;
  wire n1998;
  wire [55:0] n1999;
  wire [66:0] n2000;
  wire n2001;
  wire n2002;
  wire n2003;
  wire [54:0] n2004;
  wire [66:0] n2005;
  wire n2006;
  wire n2007;
  wire n2008;
  wire [53:0] n2009;
  wire [66:0] n2010;
  wire n2011;
  wire n2012;
  wire n2013;
  wire [52:0] n2014;
  wire [66:0] n2015;
  wire n2016;
  wire n2017;
  wire n2018;
  wire [51:0] n2019;
  wire [66:0] n2020;
  wire n2021;
  wire n2022;
  wire n2023;
  wire [50:0] n2024;
  wire [66:0] n2025;
  wire n2026;
  wire n2027;
  wire n2028;
  wire [49:0] n2029;
  wire [66:0] n2030;
  wire n2031;
  wire n2032;
  wire n2033;
  wire [48:0] n2034;
  wire [66:0] n2035;
  wire n2036;
  wire n2037;
  wire n2038;
  wire [47:0] n2039;
  wire [66:0] n2040;
  wire n2041;
  wire n2042;
  wire n2043;
  wire [46:0] n2044;
  wire [66:0] n2045;
  wire n2046;
  wire n2047;
  wire n2048;
  wire [45:0] n2049;
  wire [66:0] n2050;
  wire n2051;
  wire n2052;
  wire n2053;
  wire [44:0] n2054;
  wire [66:0] n2055;
  wire n2056;
  wire n2057;
  wire n2058;
  wire [43:0] n2059;
  wire [66:0] n2060;
  wire n2061;
  wire n2062;
  wire n2063;
  wire [42:0] n2064;
  wire [66:0] n2065;
  wire n2066;
  wire n2067;
  wire n2068;
  wire [41:0] n2069;
  wire [66:0] n2070;
  wire n2071;
  wire n2072;
  wire n2073;
  wire [40:0] n2074;
  wire [66:0] n2075;
  wire n2076;
  wire n2077;
  wire n2078;
  wire [39:0] n2079;
  wire [66:0] n2080;
  wire n2081;
  wire n2082;
  wire n2083;
  wire [38:0] n2084;
  wire [66:0] n2085;
  wire n2086;
  wire n2087;
  wire n2088;
  wire [37:0] n2089;
  wire [66:0] n2090;
  wire n2091;
  wire n2092;
  wire n2093;
  wire [36:0] n2094;
  wire [66:0] n2095;
  wire n2096;
  wire n2097;
  wire n2098;
  wire [35:0] n2099;
  wire [66:0] n2100;
  wire n2101;
  wire n2102;
  wire n2103;
  wire [34:0] n2104;
  wire [66:0] n2105;
  wire n2106;
  wire n2107;
  wire n2108;
  wire [33:0] n2109;
  wire [66:0] n2110;
  wire n2111;
  wire n2112;
  wire n2113;
  wire [32:0] n2114;
  wire [66:0] n2115;
  wire n2116;
  wire n2117;
  wire n2118;
  wire [31:0] n2119;
  wire [66:0] n2120;
  wire n2121;
  wire n2122;
  wire n2123;
  wire [30:0] n2124;
  wire [66:0] n2125;
  wire n2126;
  wire n2127;
  wire n2128;
  wire [29:0] n2129;
  wire [66:0] n2130;
  wire n2131;
  wire n2132;
  wire n2133;
  wire [28:0] n2134;
  wire [66:0] n2135;
  wire n2136;
  wire n2137;
  wire n2138;
  wire [27:0] n2139;
  wire [66:0] n2140;
  wire n2141;
  wire n2142;
  wire n2143;
  wire [26:0] n2144;
  wire [66:0] n2145;
  wire n2146;
  wire n2147;
  wire n2148;
  wire [25:0] n2149;
  wire [66:0] n2150;
  wire n2151;
  wire n2152;
  wire n2153;
  wire [24:0] n2154;
  wire [66:0] n2155;
  wire n2156;
  wire n2157;
  wire n2158;
  wire [23:0] n2159;
  wire [66:0] n2160;
  wire n2161;
  wire n2162;
  wire n2163;
  wire [22:0] n2164;
  wire [66:0] n2165;
  wire n2166;
  wire n2167;
  wire n2168;
  wire [21:0] n2169;
  wire [66:0] n2170;
  wire n2171;
  wire n2172;
  wire n2173;
  wire [20:0] n2174;
  wire [66:0] n2175;
  wire n2176;
  wire n2177;
  wire n2178;
  wire [19:0] n2179;
  wire [66:0] n2180;
  wire n2181;
  wire n2182;
  wire n2183;
  wire [18:0] n2184;
  wire [66:0] n2185;
  wire n2186;
  wire n2187;
  wire n2188;
  wire [17:0] n2189;
  wire [66:0] n2190;
  wire n2191;
  wire n2192;
  wire n2193;
  wire [16:0] n2194;
  wire [66:0] n2195;
  wire n2196;
  wire n2197;
  wire n2198;
  wire [15:0] n2199;
  wire [66:0] n2200;
  wire n2201;
  wire n2202;
  wire n2203;
  wire [14:0] n2204;
  wire [66:0] n2205;
  wire n2206;
  wire n2207;
  wire n2208;
  wire [13:0] n2209;
  wire [66:0] n2210;
  wire n2211;
  wire n2212;
  wire n2213;
  wire [12:0] n2214;
  wire [66:0] n2215;
  wire n2216;
  wire n2217;
  wire n2218;
  wire [11:0] n2219;
  wire [66:0] n2220;
  wire n2221;
  wire n2222;
  wire n2223;
  wire [10:0] n2224;
  wire [66:0] n2225;
  wire n2226;
  wire n2227;
  wire n2228;
  wire [9:0] n2229;
  wire [66:0] n2230;
  wire n2231;
  wire n2232;
  wire n2233;
  wire [8:0] n2234;
  wire [66:0] n2235;
  wire n2236;
  wire n2237;
  wire n2238;
  wire [7:0] n2239;
  wire [66:0] n2240;
  wire n2241;
  wire n2242;
  wire n2243;
  wire [6:0] n2244;
  wire [66:0] n2245;
  wire n2246;
  wire n2247;
  wire n2248;
  wire [5:0] n2249;
  wire [66:0] n2250;
  wire n2251;
  wire n2252;
  wire n2253;
  wire [4:0] n2254;
  wire [66:0] n2255;
  wire n2256;
  wire n2257;
  wire n2258;
  wire [3:0] n2259;
  wire [66:0] n2260;
  wire n2261;
  wire n2262;
  wire n2263;
  wire [2:0] n2264;
  wire [66:0] n2265;
  wire n2266;
  wire n2267;
  wire n2268;
  wire [1:0] n2269;
  wire [66:0] n2270;
  wire n2271;
  wire n2272;
  wire n2273;
  wire n2274;
  wire [66:0] n2275;
  wire n2276;
  wire n2277;
  wire n2278;
  wire [66:0] n2279;
  wire n2280;
  wire [66:0] n2283;
  wire n2286;
  wire n2287;
  wire [65:0] n2288;
  wire [66:0] n2289;
  wire [65:0] n2291;
  wire [66:0] n2293;
  wire [31:0] n2294;
  wire n2296;
  wire [31:0] n2297;
  wire [31:0] n2299;
  wire [17:0] n2300;
  wire [17:0] n2301;
  wire n2302;
  wire [67:0] n2303;
  wire [67:0] n2304;
  wire n2307;
  wire [67:0] n2309;
  wire [67:0] n2311;
  wire [67:0] n2312;
  wire [67:0] n2314;
  wire [67:0] n2316;
  wire [67:0] n2317;
  wire n2318;
  wire [67:0] n2319;
  wire n2320;
  wire [67:0] n2321;
  wire n2322;
  wire n2325;
  wire n2330;
  wire [66:0] n2331;
  wire [31:0] n2332;
  wire n2334;
  wire n2335;
  wire n2336;
  wire n2338;
  wire n2339;
  wire [63:0] n2346;
  wire n2348;
  wire [2:0] n2349;
  wire [66:0] n2351;
  wire [30:0] n2354;
  wire [66:0] n2356;
  wire [31:0] n2357;
  wire n2359;
  wire [31:0] n2360;
  wire [31:0] n2362;
  wire [30:0] n2363;
  wire [34:0] n2364;
  wire [66:0] n2366;
  wire [30:0] n2367;
  wire [66:0] n2368;
  wire [15:0] n2369;
  wire n2371;
  wire [31:0] n2372;
  wire [31:0] n2374;
  wire [30:0] n2375;
  wire [50:0] n2376;
  wire [66:0] n2378;
  wire [30:0] n2379;
  wire [66:0] n2380;
  wire [7:0] n2381;
  wire n2383;
  wire [31:0] n2384;
  wire [31:0] n2386;
  wire [30:0] n2387;
  wire [58:0] n2388;
  wire [66:0] n2390;
  wire [30:0] n2391;
  wire [66:0] n2392;
  wire [3:0] n2393;
  wire n2395;
  wire [31:0] n2396;
  wire [31:0] n2398;
  wire [30:0] n2399;
  wire [62:0] n2400;
  wire [66:0] n2402;
  wire [30:0] n2403;
  wire [66:0] n2404;
  wire [1:0] n2405;
  wire n2407;
  wire [31:0] n2408;
  wire [31:0] n2410;
  wire [30:0] n2411;
  wire [64:0] n2412;
  wire [66:0] n2414;
  wire [30:0] n2415;
  wire [66:0] n2416;
  wire n2417;
  wire n2418;
  wire [31:0] n2419;
  wire [31:0] n2421;
  wire [30:0] n2422;
  wire [30:0] n2423;
  wire [31:0] n2424;
  wire n2425;
  wire [30:0] n2426;
  wire [30:0] n2427;
  wire [66:0] n2428;
  wire [31:0] n2429;
  wire [31:0] n2430;
  wire [66:0] n2433;
  wire [31:0] n2434;
  wire [66:0] n2437;
  wire [31:0] n2438;
  wire [17:0] n2440;
  wire [17:0] n2441;
  wire [67:0] n2442;
  wire [67:0] n2443;
  wire n2449;
  wire [31:0] n2451;
  wire [63:0] n2452;
  wire n2453;
  wire n2454;
  wire [40:0] n2455;
  wire n2457;
  wire n2460;
  wire n2462;
  wire n2463;
  wire n2464;
  wire [11:0] n2465;
  wire n2467;
  wire n2470;
  wire n2472;
  wire n2473;
  wire n2474;
  wire n2475;
  wire n2478;
  wire [1:0] n2479;
  reg n2480;
  reg n2481;
  reg n2482;
  wire n2484;
  wire n2485;
  wire n2486;
  wire n2487;
  wire n2488;
  wire n2489;
  wire n2492;
  wire n2494;
  wire n2495;
  wire n2496;
  wire n2497;
  wire n2498;
  wire n2501;
  wire n2503;
  wire n2504;
  wire n2505;
  wire n2506;
  wire n2507;
  wire n2510;
  wire [1:0] n2511;
  reg n2512;
  wire n2514;
  wire n2516;
  wire n2517;
  wire n2520;
  wire n2522;
  wire n2523;
  wire n2524;
  wire n2527;
  wire n2529;
  wire [3:0] n2530;
  reg n2533;
  wire [64:0] n2536;
  wire [64:0] n2538;
  wire n2540;
  wire [64:0] n2542;
  wire [64:0] n2544;
  wire n2546;
  wire [64:0] n2548;
  wire [64:0] n2550;
  wire [1:0] n2551;
  reg [64:0] n2552;
  wire n2553;
  wire [63:0] n2554;
  wire [63:0] n2556;
  wire n2557;
  wire n2559;
  wire n2560;
  wire [61:0] n2563;
  wire [31:0] n2565;
  wire [63:0] n2566;
  wire [63:0] n2567;
  wire [63:0] n2568;
  wire [31:0] n2569;
  wire [63:0] n2570;
  wire n2572;
  localparam [39:0] n2573 = 40'b0000000000000000000000000000000000000000;
  wire n2575;
  wire n2578;
  wire [1:0] n2579;
  wire [10:0] n2580;
  wire [10:0] n2581;
  reg [10:0] n2582;
  wire [28:0] n2583;
  wire [28:0] n2584;
  reg [28:0] n2585;
  wire [23:0] n2587;
  wire [63:0] n2588;
  wire n2590;
  wire n2592;
  wire n2596;
  wire [31:0] n2598;
  wire [30:0] n2599;
  wire [31:0] n2600;
  wire n2602;
  wire [63:0] n2603;
  wire n2605;
  wire n2606;
  wire [63:0] n2608;
  wire [63:0] n2609;
  wire [79:0] n2610;
  wire [79:0] n2612;
  wire [30:0] n2613;
  wire [14:0] n2614;
  wire [63:0] n2615;
  wire [79:0] n2616;
  wire [79:0] n2617;
  wire [79:0] n2620;
  wire [79:0] n2621;
  wire [79:0] n2625;
  wire n2629;
  wire [5:0] n2630;
  reg [2:0] n2636;
  reg [79:0] n2638;
  reg [79:0] n2640;
  reg n2642;
  reg [1:0] n2644;
  reg [1:0] n2646;
  reg n2648;
  reg [17:0] n2650;
  reg [17:0] n2652;
  reg n2654;
  reg [66:0] n2656;
  reg [66:0] n2658;
  reg [17:0] n2660;
  reg n2662;
  reg [79:0] n2664;
  reg [67:0] n2666;
  reg n2668;
  reg n2670;
  reg n2672;
  reg n2676;
  reg [79:0] n2679;
  wire [2:0] n2736;
  wire [79:0] n2738;
  wire [79:0] n2740;
  wire n2742;
  wire [1:0] n2744;
  wire [1:0] n2746;
  wire n2748;
  wire [17:0] n2750;
  wire [17:0] n2752;
  wire n2754;
  wire [66:0] n2756;
  wire [66:0] n2758;
  wire [17:0] n2760;
  wire n2762;
  wire [79:0] n2764;
  wire [67:0] n2766;
  wire n2768;
  wire n2770;
  wire n2772;
  wire n2774;
  wire [79:0] n2776;
  wire n2874;
  wire n2875;
  reg [2:0] n2877;
  reg [79:0] n2878;
  reg [79:0] n2879;
  reg n2880;
  reg [1:0] n2881;
  reg [1:0] n2882;
  reg n2883;
  reg [17:0] n2884;
  reg [17:0] n2885;
  reg n2886;
  reg [66:0] n2887;
  reg [66:0] n2888;
  reg [17:0] n2889;
  reg n2890;
  reg [79:0] n2891;
  reg [67:0] n2892;
  reg n2893;
  reg n2894;
  reg n2895;
  reg n2896;
  reg [79:0] n2897;
  wire [127:0] n2899;
  wire n2900;
  wire [127:0] n2902;
  wire n2903;
  assign busy = n2875; //(module output)
  assign done = done_reg; //(module output)
  assign result = result_reg; //(module output)
  /* mc68881_fp80_addsub_unit.vhd:49:10  */
  always @*
    state_reg = n2877; // (isignal)
  initial
    state_reg = 3'b000;
  /* mc68881_fp80_addsub_unit.vhd:52:10  */
  always @*
    a_reg = n2878; // (isignal)
  initial
    a_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:53:10  */
  always @*
    b_reg = n2879; // (isignal)
  initial
    b_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:54:10  */
  always @*
    sub_reg = n2880; // (isignal)
  initial
    sub_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:55:10  */
  always @*
    rm_reg = n2881; // (isignal)
  initial
    rm_reg = 2'b00;
  /* mc68881_fp80_addsub_unit.vhd:56:10  */
  always @*
    rp_reg = n2882; // (isignal)
  initial
    rp_reg = 2'b00;
  /* mc68881_fp80_addsub_unit.vhd:59:10  */
  always @*
    a_sign_reg = n2883; // (isignal)
  initial
    a_sign_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:60:10  */
  always @*
    a_exp_reg = n2884; // (isignal)
  initial
    a_exp_reg = 18'b000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:61:10  */
  always @*
    b_exp_reg = n2885; // (isignal)
  initial
    b_exp_reg = 18'b000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:62:10  */
  always @*
    sign_b_reg = n2886; // (isignal)
  initial
    sign_b_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:65:10  */
  always @*
    mant_a_ext_reg = n2887; // (isignal)
  initial
    mant_a_ext_reg = 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:66:10  */
  always @*
    mant_b_ext_reg = n2888; // (isignal)
  initial
    mant_b_ext_reg = 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:69:10  */
  always @*
    exp_res_reg = n2889; // (isignal)
  initial
    exp_res_reg = 18'b000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:72:10  */
  always @*
    early_exit_reg = n2890; // (isignal)
  initial
    early_exit_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:73:10  */
  always @*
    early_result_reg = n2891; // (isignal)
  initial
    early_result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:76:10  */
  always @*
    mant_sum_reg = n2892; // (isignal)
  initial
    mant_sum_reg = 68'b00000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:77:10  */
  always @*
    res_sign_reg = n2893; // (isignal)
  initial
    res_sign_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:78:10  */
  always @*
    same_sign_reg = n2894; // (isignal)
  initial
    same_sign_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:80:10  */
  always @*
    need_normalize_reg = n2895; // (isignal)
  initial
    need_normalize_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:83:10  */
  always @*
    done_reg = n2896; // (isignal)
  initial
    done_reg = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:84:10  */
  always @*
    result_reg = n2897; // (isignal)
  initial
    result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:152:16  */
  assign n51 = ~reset_n;
  /* mc68881_fp80_addsub_unit.vhd:179:11  */
  assign n53 = start ? 3'b001 : state_reg;
  /* mc68881_fp80_addsub_unit.vhd:179:11  */
  assign n54 = start ? a_in : a_reg;
  /* mc68881_fp80_addsub_unit.vhd:179:11  */
  assign n55 = start ? b_in : b_reg;
  /* mc68881_fp80_addsub_unit.vhd:179:11  */
  assign n56 = start ? subtract : sub_reg;
  /* mc68881_fp80_addsub_unit.vhd:179:11  */
  assign n57 = start ? round_mode : rm_reg;
  /* mc68881_fp80_addsub_unit.vhd:179:11  */
  assign n58 = start ? round_prec : rp_reg;
  /* mc68881_fp80_addsub_unit.vhd:178:9  */
  assign n60 = state_reg == 3'b000;
  /* mc68881_fp80_addsub_unit.vhd:190:30  */
  assign n61 = a_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:193:37  */
  assign n62 = a_reg[63:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:194:28  */
  assign n63 = a_reg[78:64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:194:73  */
  assign n65 = n63 == 15'b000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:194:90  */
  assign n67 = n62 != 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:194:77  */
  assign n68 = n67 & n65;
  /* mc68881_pkg.vhd:2502:9  */
  assign n75 = a_reg[63:32]; // extract
  /* mc68881_pkg.vhd:2502:37  */
  assign n77 = n75 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2504:13  */
  assign n78 = a_reg[31:0]; // extract
  /* mc68881_pkg.vhd:2504:36  */
  assign n80 = {n78, 32'b00000000000000000000000000000000};
  /* mc68881_pkg.vhd:2502:5  */
  assign n83 = n77 ? 31'b0000000000000000000000000100000 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:2502:5  */
  assign n85 = n77 ? n80 : n62;
  /* mc68881_pkg.vhd:2506:9  */
  assign n86 = n85[63:48]; // extract
  /* mc68881_pkg.vhd:2506:37  */
  assign n88 = n86 == 16'b0000000000000000;
  /* mc68881_pkg.vhd:2507:18  */
  assign n89 = {1'b0, n83};  //  uext
  /* mc68881_pkg.vhd:2507:18  */
  assign n91 = n89 + 32'b00000000000000000000000000010000;
  /* mc68881_pkg.vhd:2507:7  */
  assign n92 = n91[30:0];  // trunc
  /* mc68881_pkg.vhd:2508:13  */
  assign n93 = n85[47:0]; // extract
  /* mc68881_pkg.vhd:2508:36  */
  assign n95 = {n93, 16'b0000000000000000};
  /* mc68881_pkg.vhd:2506:5  */
  assign n96 = n88 ? n92 : n83;
  /* mc68881_pkg.vhd:2506:5  */
  assign n97 = n88 ? n95 : n85;
  /* mc68881_pkg.vhd:2510:9  */
  assign n98 = n97[63:56]; // extract
  /* mc68881_pkg.vhd:2510:36  */
  assign n100 = n98 == 8'b00000000;
  /* mc68881_pkg.vhd:2511:18  */
  assign n101 = {1'b0, n96};  //  uext
  /* mc68881_pkg.vhd:2511:18  */
  assign n103 = n101 + 32'b00000000000000000000000000001000;
  /* mc68881_pkg.vhd:2511:7  */
  assign n104 = n103[30:0];  // trunc
  /* mc68881_pkg.vhd:2512:13  */
  assign n105 = n97[55:0]; // extract
  /* mc68881_pkg.vhd:2512:35  */
  assign n107 = {n105, 8'b00000000};
  /* mc68881_pkg.vhd:2510:5  */
  assign n108 = n100 ? n104 : n96;
  /* mc68881_pkg.vhd:2510:5  */
  assign n109 = n100 ? n107 : n97;
  /* mc68881_pkg.vhd:2514:9  */
  assign n110 = n109[63:60]; // extract
  /* mc68881_pkg.vhd:2514:36  */
  assign n112 = n110 == 4'b0000;
  /* mc68881_pkg.vhd:2515:18  */
  assign n113 = {1'b0, n108};  //  uext
  /* mc68881_pkg.vhd:2515:18  */
  assign n115 = n113 + 32'b00000000000000000000000000000100;
  /* mc68881_pkg.vhd:2515:7  */
  assign n116 = n115[30:0];  // trunc
  /* mc68881_pkg.vhd:2516:13  */
  assign n117 = n109[59:0]; // extract
  /* mc68881_pkg.vhd:2516:35  */
  assign n119 = {n117, 4'b0000};
  /* mc68881_pkg.vhd:2514:5  */
  assign n120 = n112 ? n116 : n108;
  /* mc68881_pkg.vhd:2514:5  */
  assign n121 = n112 ? n119 : n109;
  /* mc68881_pkg.vhd:2518:9  */
  assign n122 = n121[63:62]; // extract
  /* mc68881_pkg.vhd:2518:36  */
  assign n124 = n122 == 2'b00;
  /* mc68881_pkg.vhd:2519:18  */
  assign n125 = {1'b0, n120};  //  uext
  /* mc68881_pkg.vhd:2519:18  */
  assign n127 = n125 + 32'b00000000000000000000000000000010;
  /* mc68881_pkg.vhd:2519:7  */
  assign n128 = n127[30:0];  // trunc
  /* mc68881_pkg.vhd:2520:13  */
  assign n129 = n121[61:0]; // extract
  /* mc68881_pkg.vhd:2520:35  */
  assign n131 = {n129, 2'b00};
  /* mc68881_pkg.vhd:2518:5  */
  assign n132 = n124 ? n128 : n120;
  /* mc68881_pkg.vhd:2518:5  */
  assign n133 = n124 ? n131 : n121;
  /* mc68881_pkg.vhd:2522:9  */
  assign n134 = n133[63]; // extract
  /* mc68881_pkg.vhd:2522:18  */
  assign n135 = ~n134;
  /* mc68881_pkg.vhd:2523:18  */
  assign n136 = {1'b0, n132};  //  uext
  /* mc68881_pkg.vhd:2523:18  */
  assign n138 = n136 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:2523:7  */
  assign n139 = n138[30:0];  // trunc
  /* mc68881_pkg.vhd:2522:5  */
  assign n140 = n135 ? n139 : n132;
  /* mc68881_fp80_addsub_unit.vhd:196:25  */
  assign n141 = n62 << n140;
  /* mc68881_fp80_addsub_unit.vhd:197:28  */
  assign n142 = {1'b0, n140};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:197:28  */
  assign n144 = 32'b00000000000000000000000000000001 - n142;
  /* mc68881_fp80_addsub_unit.vhd:197:26  */
  assign n145 = n144[17:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:199:51  */
  assign n146 = a_reg[78:64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:199:26  */
  assign n148 = {3'b0, n146};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:194:11  */
  assign n149 = n68 ? n145 : n148;
  /* mc68881_fp80_addsub_unit.vhd:194:11  */
  assign n151 = n68 ? n141 : n62;
  /* mc68881_fp80_addsub_unit.vhd:202:37  */
  assign n152 = b_reg[63:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:203:28  */
  assign n153 = b_reg[78:64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:203:73  */
  assign n155 = n153 == 15'b000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:203:90  */
  assign n157 = n152 != 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:203:77  */
  assign n158 = n157 & n155;
  /* mc68881_pkg.vhd:2502:9  */
  assign n165 = b_reg[63:32]; // extract
  /* mc68881_pkg.vhd:2502:37  */
  assign n167 = n165 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2504:13  */
  assign n168 = b_reg[31:0]; // extract
  /* mc68881_pkg.vhd:2504:36  */
  assign n170 = {n168, 32'b00000000000000000000000000000000};
  /* mc68881_pkg.vhd:2502:5  */
  assign n173 = n167 ? 31'b0000000000000000000000000100000 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:2502:5  */
  assign n175 = n167 ? n170 : n152;
  /* mc68881_pkg.vhd:2506:9  */
  assign n176 = n175[63:48]; // extract
  /* mc68881_pkg.vhd:2506:37  */
  assign n178 = n176 == 16'b0000000000000000;
  /* mc68881_pkg.vhd:2507:18  */
  assign n179 = {1'b0, n173};  //  uext
  /* mc68881_pkg.vhd:2507:18  */
  assign n181 = n179 + 32'b00000000000000000000000000010000;
  /* mc68881_pkg.vhd:2507:7  */
  assign n182 = n181[30:0];  // trunc
  /* mc68881_pkg.vhd:2508:13  */
  assign n183 = n175[47:0]; // extract
  /* mc68881_pkg.vhd:2508:36  */
  assign n185 = {n183, 16'b0000000000000000};
  /* mc68881_pkg.vhd:2506:5  */
  assign n186 = n178 ? n182 : n173;
  /* mc68881_pkg.vhd:2506:5  */
  assign n187 = n178 ? n185 : n175;
  /* mc68881_pkg.vhd:2510:9  */
  assign n188 = n187[63:56]; // extract
  /* mc68881_pkg.vhd:2510:36  */
  assign n190 = n188 == 8'b00000000;
  /* mc68881_pkg.vhd:2511:18  */
  assign n191 = {1'b0, n186};  //  uext
  /* mc68881_pkg.vhd:2511:18  */
  assign n193 = n191 + 32'b00000000000000000000000000001000;
  /* mc68881_pkg.vhd:2511:7  */
  assign n194 = n193[30:0];  // trunc
  /* mc68881_pkg.vhd:2512:13  */
  assign n195 = n187[55:0]; // extract
  /* mc68881_pkg.vhd:2512:35  */
  assign n197 = {n195, 8'b00000000};
  /* mc68881_pkg.vhd:2510:5  */
  assign n198 = n190 ? n194 : n186;
  /* mc68881_pkg.vhd:2510:5  */
  assign n199 = n190 ? n197 : n187;
  /* mc68881_pkg.vhd:2514:9  */
  assign n200 = n199[63:60]; // extract
  /* mc68881_pkg.vhd:2514:36  */
  assign n202 = n200 == 4'b0000;
  /* mc68881_pkg.vhd:2515:18  */
  assign n203 = {1'b0, n198};  //  uext
  /* mc68881_pkg.vhd:2515:18  */
  assign n205 = n203 + 32'b00000000000000000000000000000100;
  /* mc68881_pkg.vhd:2515:7  */
  assign n206 = n205[30:0];  // trunc
  /* mc68881_pkg.vhd:2516:13  */
  assign n207 = n199[59:0]; // extract
  /* mc68881_pkg.vhd:2516:35  */
  assign n209 = {n207, 4'b0000};
  /* mc68881_pkg.vhd:2514:5  */
  assign n210 = n202 ? n206 : n198;
  /* mc68881_pkg.vhd:2514:5  */
  assign n211 = n202 ? n209 : n199;
  /* mc68881_pkg.vhd:2518:9  */
  assign n212 = n211[63:62]; // extract
  /* mc68881_pkg.vhd:2518:36  */
  assign n214 = n212 == 2'b00;
  /* mc68881_pkg.vhd:2519:18  */
  assign n215 = {1'b0, n210};  //  uext
  /* mc68881_pkg.vhd:2519:18  */
  assign n217 = n215 + 32'b00000000000000000000000000000010;
  /* mc68881_pkg.vhd:2519:7  */
  assign n218 = n217[30:0];  // trunc
  /* mc68881_pkg.vhd:2520:13  */
  assign n219 = n211[61:0]; // extract
  /* mc68881_pkg.vhd:2520:35  */
  assign n221 = {n219, 2'b00};
  /* mc68881_pkg.vhd:2518:5  */
  assign n222 = n214 ? n218 : n210;
  /* mc68881_pkg.vhd:2518:5  */
  assign n223 = n214 ? n221 : n211;
  /* mc68881_pkg.vhd:2522:9  */
  assign n224 = n223[63]; // extract
  /* mc68881_pkg.vhd:2522:18  */
  assign n225 = ~n224;
  /* mc68881_pkg.vhd:2523:18  */
  assign n226 = {1'b0, n222};  //  uext
  /* mc68881_pkg.vhd:2523:18  */
  assign n228 = n226 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:2523:7  */
  assign n229 = n228[30:0];  // trunc
  /* mc68881_pkg.vhd:2522:5  */
  assign n230 = n225 ? n229 : n222;
  /* mc68881_fp80_addsub_unit.vhd:205:25  */
  assign n231 = n152 << n230;
  /* mc68881_fp80_addsub_unit.vhd:206:28  */
  assign n232 = {1'b0, n230};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:206:28  */
  assign n234 = 32'b00000000000000000000000000000001 - n232;
  /* mc68881_fp80_addsub_unit.vhd:206:26  */
  assign n235 = n234[17:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:208:51  */
  assign n236 = b_reg[78:64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:208:26  */
  assign n238 = {3'b0, n236};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:203:11  */
  assign n239 = n158 ? n235 : n238;
  /* mc68881_fp80_addsub_unit.vhd:203:11  */
  assign n241 = n158 ? n231 : n152;
  /* mc68881_fp80_addsub_unit.vhd:213:36  */
  assign n242 = b_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:213:27  */
  assign n243 = ~n242;
  /* mc68881_fp80_addsub_unit.vhd:215:32  */
  assign n244 = b_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:212:11  */
  assign n245 = sub_reg ? n243 : n244;
  /* mc68881_fp80_addsub_unit.vhd:219:38  */
  assign n247 = {n151, 3'b000};
  /* mc68881_fp80_addsub_unit.vhd:220:38  */
  assign n249 = {n241, 3'b000};
  /* mc68881_pkg.vhd:1538:25  */
  assign n261 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n264 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n266 = a_reg[63:0]; // extract
  assign n267 = {n266, n264, n261};
  /* mc68881_pkg.vhd:2101:20  */
  assign n268 = n267[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n270 = n268 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n282 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n285 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n287 = a_reg[63:0]; // extract
  assign n288 = {n287, n285, n282};
  assign n292 = n291[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n293 = n288[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n295 = n293 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n296 = n288[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n298 = n296 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n299 = n288[79:16]; // extract
  assign n300 = {1'b1, n292};
  /* mc68881_pkg.vhd:2095:41  */
  assign n301 = n299 == n300;
  /* mc68881_pkg.vhd:2095:25  */
  assign n302 = n298 | n301;
  /* mc68881_pkg.vhd:2094:42  */
  assign n303 = n302 & n295;
  /* mc68881_pkg.vhd:2101:46  */
  assign n304 = ~n303;
  /* mc68881_pkg.vhd:2101:42  */
  assign n305 = n304 & n270;
  /* mc68881_pkg.vhd:1538:25  */
  assign n317 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n320 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n322 = b_reg[63:0]; // extract
  assign n323 = {n322, n320, n317};
  /* mc68881_pkg.vhd:2101:20  */
  assign n324 = n323[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n326 = n324 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n338 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n341 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n343 = b_reg[63:0]; // extract
  assign n344 = {n343, n341, n338};
  assign n348 = n347[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n349 = n344[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n351 = n349 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n352 = n344[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n354 = n352 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n355 = n344[79:16]; // extract
  assign n356 = {1'b1, n348};
  /* mc68881_pkg.vhd:2095:41  */
  assign n357 = n355 == n356;
  /* mc68881_pkg.vhd:2095:25  */
  assign n358 = n354 | n357;
  /* mc68881_pkg.vhd:2094:42  */
  assign n359 = n358 & n351;
  /* mc68881_pkg.vhd:2101:46  */
  assign n360 = ~n359;
  /* mc68881_pkg.vhd:2101:42  */
  assign n361 = n360 & n326;
  /* mc68881_fp80_addsub_unit.vhd:225:33  */
  assign n362 = n305 | n361;
  /* mc68881_pkg.vhd:1538:25  */
  assign n375 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n378 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n380 = a_reg[63:0]; // extract
  assign n381 = {n380, n378, n375};
  /* mc68881_pkg.vhd:2101:20  */
  assign n382 = n381[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n384 = n382 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n396 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n399 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n401 = a_reg[63:0]; // extract
  assign n402 = {n401, n399, n396};
  assign n406 = n405[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n407 = n402[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n409 = n407 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n410 = n402[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n412 = n410 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n413 = n402[79:16]; // extract
  assign n414 = {1'b1, n406};
  /* mc68881_pkg.vhd:2095:41  */
  assign n415 = n413 == n414;
  /* mc68881_pkg.vhd:2095:25  */
  assign n416 = n412 | n415;
  /* mc68881_pkg.vhd:2094:42  */
  assign n417 = n416 & n409;
  /* mc68881_pkg.vhd:2101:46  */
  assign n418 = ~n417;
  /* mc68881_pkg.vhd:2101:42  */
  assign n419 = n418 & n384;
  /* mc68881_pkg.vhd:1538:25  */
  assign n431 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n434 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n436 = b_reg[63:0]; // extract
  assign n437 = {n436, n434, n431};
  /* mc68881_pkg.vhd:2101:20  */
  assign n438 = n437[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n440 = n438 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n452 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n455 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n457 = b_reg[63:0]; // extract
  assign n458 = {n457, n455, n452};
  assign n462 = n461[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n463 = n458[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n465 = n463 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n466 = n458[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n468 = n466 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n469 = n458[79:16]; // extract
  assign n470 = {1'b1, n462};
  /* mc68881_pkg.vhd:2095:41  */
  assign n471 = n469 == n470;
  /* mc68881_pkg.vhd:2095:25  */
  assign n472 = n468 | n471;
  /* mc68881_pkg.vhd:2094:42  */
  assign n473 = n472 & n465;
  /* mc68881_pkg.vhd:2101:46  */
  assign n474 = ~n473;
  /* mc68881_pkg.vhd:2101:42  */
  assign n475 = n474 & n440;
  /* mc68881_pkg.vhd:1538:25  */
  assign n493 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n496 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n498 = a_reg[63:0]; // extract
  assign n499 = {n498, n496, n493};
  /* mc68881_pkg.vhd:2108:20  */
  assign n500 = n499[15:1]; // extract
  /* mc68881_pkg.vhd:2108:24  */
  assign n502 = n500 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2109:24  */
  assign n503 = n499[79]; // extract
  /* mc68881_pkg.vhd:2109:42  */
  assign n504 = ~n503;
  /* mc68881_pkg.vhd:2108:42  */
  assign n505 = n504 & n502;
  /* mc68881_pkg.vhd:2110:24  */
  assign n506 = n499[78:16]; // extract
  /* mc68881_pkg.vhd:2110:51  */
  assign n508 = n506 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2109:48  */
  assign n509 = n508 & n505;
  /* mc68881_pkg.vhd:1538:25  */
  assign n521 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n524 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n526 = b_reg[63:0]; // extract
  assign n527 = {n526, n524, n521};
  /* mc68881_pkg.vhd:2108:20  */
  assign n528 = n527[15:1]; // extract
  /* mc68881_pkg.vhd:2108:24  */
  assign n530 = n528 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2109:24  */
  assign n531 = n527[79]; // extract
  /* mc68881_pkg.vhd:2109:42  */
  assign n532 = ~n531;
  /* mc68881_pkg.vhd:2108:42  */
  assign n533 = n532 & n530;
  /* mc68881_pkg.vhd:2110:24  */
  assign n534 = n527[78:16]; // extract
  /* mc68881_pkg.vhd:2110:51  */
  assign n536 = n534 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2109:48  */
  assign n537 = n536 & n533;
  /* mc68881_pkg.vhd:2147:18  */
  assign n539 = n509 | n537;
  /* mc68881_pkg.vhd:2147:5  */
  assign n542 = n539 ? 1'b1 : 1'b0;
  /* mc68881_pkg.vhd:2151:14  */
  assign n544 = n475 & n419;
  /* mc68881_pkg.vhd:2155:7  */
  assign n545 = n537 ? b_reg : a_reg;
  /* mc68881_pkg.vhd:2153:7  */
  assign n546 = n509 ? a_reg : n545;
  /* mc68881_pkg.vhd:2160:5  */
  assign n547 = n419 ? a_reg : b_reg;
  /* mc68881_pkg.vhd:2151:5  */
  assign n548 = n544 ? n546 : n547;
  assign n551 = n548[79:64]; // extract
  assign n552 = n548[62:0]; // extract
  assign n553 = {n551, 1'b1, n552};
  /* mc68881_pkg.vhd:2169:23  */
  assign n554 = {n542, n553};
  /* mc68881_fp80_addsub_unit.vhd:229:68  */
  assign n556 = n554[79:0]; // extract
  /* mc68881_pkg.vhd:1538:25  */
  assign n568 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n571 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n573 = a_reg[63:0]; // extract
  assign n574 = {n573, n571, n568};
  assign n578 = n577[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n579 = n574[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n581 = n579 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n582 = n574[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n584 = n582 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n585 = n574[79:16]; // extract
  assign n586 = {1'b1, n578};
  /* mc68881_pkg.vhd:2095:41  */
  assign n587 = n585 == n586;
  /* mc68881_pkg.vhd:2095:25  */
  assign n588 = n584 | n587;
  /* mc68881_pkg.vhd:2094:42  */
  assign n589 = n588 & n581;
  /* mc68881_pkg.vhd:1538:25  */
  assign n601 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n604 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n606 = b_reg[63:0]; // extract
  assign n607 = {n606, n604, n601};
  assign n611 = n610[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n612 = n607[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n614 = n612 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n615 = n607[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n617 = n615 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n618 = n607[79:16]; // extract
  assign n619 = {1'b1, n611};
  /* mc68881_pkg.vhd:2095:41  */
  assign n620 = n618 == n619;
  /* mc68881_pkg.vhd:2095:25  */
  assign n621 = n617 | n620;
  /* mc68881_pkg.vhd:2094:42  */
  assign n622 = n621 & n614;
  /* mc68881_fp80_addsub_unit.vhd:230:36  */
  assign n623 = n589 | n622;
  /* mc68881_pkg.vhd:1538:25  */
  assign n635 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n638 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n640 = a_reg[63:0]; // extract
  assign n641 = {n640, n638, n635};
  assign n645 = n644[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n646 = n641[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n648 = n646 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n649 = n641[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n651 = n649 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n652 = n641[79:16]; // extract
  assign n653 = {1'b1, n645};
  /* mc68881_pkg.vhd:2095:41  */
  assign n654 = n652 == n653;
  /* mc68881_pkg.vhd:2095:25  */
  assign n655 = n651 | n654;
  /* mc68881_pkg.vhd:2094:42  */
  assign n656 = n655 & n648;
  /* mc68881_pkg.vhd:1538:25  */
  assign n668 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n671 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n673 = b_reg[63:0]; // extract
  assign n674 = {n673, n671, n668};
  assign n678 = n677[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n679 = n674[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n681 = n679 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n682 = n674[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n684 = n682 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n685 = n674[79:16]; // extract
  assign n686 = {1'b1, n678};
  /* mc68881_pkg.vhd:2095:41  */
  assign n687 = n685 == n686;
  /* mc68881_pkg.vhd:2095:25  */
  assign n688 = n684 | n687;
  /* mc68881_pkg.vhd:2094:42  */
  assign n689 = n688 & n681;
  /* mc68881_fp80_addsub_unit.vhd:232:35  */
  assign n690 = n689 & n656;
  /* mc68881_fp80_addsub_unit.vhd:235:19  */
  assign n691 = ~sub_reg;
  /* mc68881_fp80_addsub_unit.vhd:235:40  */
  assign n692 = a_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:235:60  */
  assign n693 = b_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:235:53  */
  assign n694 = n692 == n693;
  /* mc68881_fp80_addsub_unit.vhd:235:31  */
  assign n695 = n694 & n691;
  /* mc68881_fp80_addsub_unit.vhd:236:36  */
  assign n696 = a_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:236:57  */
  assign n697 = b_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:236:49  */
  assign n698 = n696 != n697;
  /* mc68881_fp80_addsub_unit.vhd:236:27  */
  assign n699 = n698 & sub_reg;
  /* mc68881_fp80_addsub_unit.vhd:235:74  */
  assign n700 = n695 | n699;
  /* mc68881_fp80_addsub_unit.vhd:238:54  */
  assign n701 = a_reg[79]; // extract
  assign n707 = {1'b0, 15'b111111111111111, 64'b1111111111111111111111111111111111111111111111111111111111111111};
  assign n708 = {n701, 15'b111111111111111, 64'b0000000000000000000000000000000000000000000000000000000000000000};
  /* mc68881_fp80_addsub_unit.vhd:235:15  */
  assign n709 = n700 ? n708 : n707;
  /* mc68881_pkg.vhd:1538:25  */
  assign n721 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n724 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n726 = a_reg[63:0]; // extract
  assign n727 = {n726, n724, n721};
  assign n731 = n730[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n732 = n727[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n734 = n732 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n735 = n727[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n737 = n735 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n738 = n727[79:16]; // extract
  assign n739 = {1'b1, n731};
  /* mc68881_pkg.vhd:2095:41  */
  assign n740 = n738 == n739;
  /* mc68881_pkg.vhd:2095:25  */
  assign n741 = n737 | n740;
  /* mc68881_pkg.vhd:2094:42  */
  assign n742 = n741 & n734;
  /* mc68881_fp80_addsub_unit.vhd:253:58  */
  assign n743 = b_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:253:49  */
  assign n744 = ~n743;
  /* mc68881_fp80_addsub_unit.vhd:254:63  */
  assign n745 = b_reg[78:0]; // extract
  assign n746 = {n744, n745};
  /* mc68881_fp80_addsub_unit.vhd:252:15  */
  assign n747 = sub_reg ? n746 : b_reg;
  /* mc68881_fp80_addsub_unit.vhd:247:13  */
  assign n748 = n742 ? a_reg : n747;
  /* mc68881_fp80_addsub_unit.vhd:232:13  */
  assign n749 = n690 ? n709 : n748;
  /* mc68881_fp80_addsub_unit.vhd:259:31  */
  assign n750 = a_reg[78:64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:259:76  */
  assign n752 = n750 == 15'b000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:260:31  */
  assign n753 = a_reg[63:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:260:59  */
  assign n755 = n753 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:259:80  */
  assign n756 = n755 & n752;
  /* mc68881_fp80_addsub_unit.vhd:264:56  */
  assign n757 = b_reg[79]; // extract
  /* mc68881_fp80_addsub_unit.vhd:264:47  */
  assign n758 = ~n757;
  /* mc68881_fp80_addsub_unit.vhd:265:61  */
  assign n759 = b_reg[78:0]; // extract
  assign n760 = {n758, n759};
  /* mc68881_fp80_addsub_unit.vhd:263:13  */
  assign n761 = sub_reg ? n760 : b_reg;
  /* mc68881_fp80_addsub_unit.vhd:269:31  */
  assign n762 = b_reg[78:64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:269:76  */
  assign n764 = n762 == 15'b000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:270:31  */
  assign n765 = b_reg[63:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:270:59  */
  assign n767 = n765 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:269:80  */
  assign n768 = n767 & n764;
  /* mc68881_fp80_addsub_unit.vhd:269:11  */
  assign n771 = n768 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:269:11  */
  assign n772 = n768 ? a_reg : early_result_reg;
  /* mc68881_fp80_addsub_unit.vhd:259:11  */
  assign n774 = n756 ? 1'b1 : n771;
  /* mc68881_fp80_addsub_unit.vhd:259:11  */
  assign n775 = n756 ? n761 : n772;
  /* mc68881_fp80_addsub_unit.vhd:230:11  */
  assign n777 = n623 ? 1'b1 : n774;
  /* mc68881_fp80_addsub_unit.vhd:230:11  */
  assign n778 = n623 ? n749 : n775;
  /* mc68881_fp80_addsub_unit.vhd:225:11  */
  assign n780 = n362 ? 1'b1 : n777;
  /* mc68881_fp80_addsub_unit.vhd:225:11  */
  assign n782 = n362 ? n556 : n778;
  /* mc68881_fp80_addsub_unit.vhd:188:9  */
  assign n784 = state_reg == 3'b001;
  /* mc68881_fp80_addsub_unit.vhd:287:26  */
  assign n785 = {{14{a_exp_reg[17]}}, a_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:287:26  */
  assign n786 = {{14{b_exp_reg[17]}}, b_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:287:26  */
  assign n787 = $signed(n785) > $signed(n786);
  /* mc68881_fp80_addsub_unit.vhd:288:36  */
  assign n788 = {{14{a_exp_reg[17]}}, a_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:288:36  */
  assign n789 = {{14{b_exp_reg[17]}}, b_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:288:36  */
  assign n790 = n788 - n789;
  /* mc68881_fp80_addsub_unit.vhd:288:15  */
  assign n791 = n790[30:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:92:14  */
  assign n800 = {1'b0, n791};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:92:14  */
  assign n802 = n800 == 32'b00000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:92:5  */
  assign n805 = n802 ? 1'b0 : 1'b1;
  /* mc68881_fp80_addsub_unit.vhd:92:5  */
  assign n809 = n802 ? 1'b0 : 1'b1;
  /* mc68881_fp80_addsub_unit.vhd:92:5  */
  assign n811 = n802 ? mant_b_ext_reg : 67'bX;
  /* mc68881_fp80_addsub_unit.vhd:95:14  */
  assign n812 = {1'b0, n791};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:95:14  */
  assign n814 = $signed(n812) >= $signed(32'b00000000000000000000000001000011);
  /* mc68881_fp80_addsub_unit.vhd:96:16  */
  assign n816 = mant_b_ext_reg != 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:97:9  */
  assign n819 = n805 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:96:7  */
  assign n821 = n816 ? n819 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:96:7  */
  assign n823 = n805 ? n821 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:99:7  */
  assign n825 = n805 ? n823 : 1'b0;
  assign n827 = {66'b000000000000000000000000000000000000000000000000000000000000000000, n825};
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n829 = n840 ? 1'b0 : n805;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n831 = n841 ? 1'b0 : n809;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n832 = n842 ? n827 : n811;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n833 = n805 & n814;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n834 = n805 & n814;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n835 = n805 & n814;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n837 = n814 ? n825 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n839 = n814 ? n823 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n840 = n833 & n805;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n841 = n834 & n805;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n842 = n835 & n805;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n844 = n805 ? n837 : 1'b0;
  assign n846 = n845[66:1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n848 = n805 ? n839 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:104:26  */
  assign n850 = mant_b_ext_reg[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:104:5  */
  assign n852 = n829 ? n850 : 1'bX;
  assign n854 = n853[66:1]; // extract
  assign n855 = {n854, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n856 = n855[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n857 = mant_b_ext_reg[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n858 = n856 | n857;
  assign n859 = n853[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n860 = n829 ? n858 : n859;
  assign n861 = n853[66:2]; // extract
  assign n862 = {n861, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n863 = n862[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n864 = mant_b_ext_reg[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n865 = n863 | n864;
  assign n866 = n853[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n867 = n829 ? n865 : n866;
  assign n868 = n853[66:3]; // extract
  assign n869 = {n868, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n870 = n869[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n871 = mant_b_ext_reg[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n872 = n870 | n871;
  assign n873 = n853[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n874 = n829 ? n872 : n873;
  assign n875 = n853[66:4]; // extract
  assign n876 = {n875, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n877 = n876[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n878 = mant_b_ext_reg[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n879 = n877 | n878;
  assign n880 = n853[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n881 = n829 ? n879 : n880;
  assign n882 = n853[66:5]; // extract
  assign n883 = {n882, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n884 = n883[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n885 = mant_b_ext_reg[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n886 = n884 | n885;
  assign n887 = n853[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n888 = n829 ? n886 : n887;
  assign n889 = n853[66:6]; // extract
  assign n890 = {n889, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n891 = n890[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n892 = mant_b_ext_reg[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n893 = n891 | n892;
  assign n894 = n853[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n895 = n829 ? n893 : n894;
  assign n896 = n853[66:7]; // extract
  assign n897 = {n896, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n898 = n897[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n899 = mant_b_ext_reg[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n900 = n898 | n899;
  assign n901 = n853[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n902 = n829 ? n900 : n901;
  assign n903 = n853[66:8]; // extract
  assign n904 = {n903, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n905 = n904[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n906 = mant_b_ext_reg[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n907 = n905 | n906;
  assign n908 = n853[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n909 = n829 ? n907 : n908;
  assign n910 = n853[66:9]; // extract
  assign n911 = {n910, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n912 = n911[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n913 = mant_b_ext_reg[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n914 = n912 | n913;
  assign n915 = n853[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n916 = n829 ? n914 : n915;
  assign n917 = n853[66:10]; // extract
  assign n918 = {n917, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n919 = n918[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n920 = mant_b_ext_reg[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n921 = n919 | n920;
  assign n922 = n853[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n923 = n829 ? n921 : n922;
  assign n924 = n853[66:11]; // extract
  assign n925 = {n924, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n926 = n925[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n927 = mant_b_ext_reg[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n928 = n926 | n927;
  assign n929 = n853[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n930 = n829 ? n928 : n929;
  assign n931 = n853[66:12]; // extract
  assign n932 = {n931, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n933 = n932[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n934 = mant_b_ext_reg[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n935 = n933 | n934;
  assign n936 = n853[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n937 = n829 ? n935 : n936;
  assign n938 = n853[66:13]; // extract
  assign n939 = {n938, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n940 = n939[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n941 = mant_b_ext_reg[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n942 = n940 | n941;
  assign n943 = n853[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n944 = n829 ? n942 : n943;
  assign n945 = n853[66:14]; // extract
  assign n946 = {n945, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n947 = n946[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n948 = mant_b_ext_reg[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n949 = n947 | n948;
  assign n950 = n853[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n951 = n829 ? n949 : n950;
  assign n952 = n853[66:15]; // extract
  assign n953 = {n952, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n954 = n953[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n955 = mant_b_ext_reg[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n956 = n954 | n955;
  assign n957 = n853[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n958 = n829 ? n956 : n957;
  assign n959 = n853[66:16]; // extract
  assign n960 = {n959, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n961 = n960[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n962 = mant_b_ext_reg[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n963 = n961 | n962;
  assign n964 = n853[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n965 = n829 ? n963 : n964;
  assign n966 = n853[66:17]; // extract
  assign n967 = {n966, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n968 = n967[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n969 = mant_b_ext_reg[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n970 = n968 | n969;
  assign n971 = n853[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n972 = n829 ? n970 : n971;
  assign n973 = n853[66:18]; // extract
  assign n974 = {n973, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n975 = n974[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n976 = mant_b_ext_reg[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n977 = n975 | n976;
  assign n978 = n853[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n979 = n829 ? n977 : n978;
  assign n980 = n853[66:19]; // extract
  assign n981 = {n980, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n982 = n981[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n983 = mant_b_ext_reg[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n984 = n982 | n983;
  assign n985 = n853[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n986 = n829 ? n984 : n985;
  assign n987 = n853[66:20]; // extract
  assign n988 = {n987, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n989 = n988[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n990 = mant_b_ext_reg[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n991 = n989 | n990;
  assign n992 = n853[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n993 = n829 ? n991 : n992;
  assign n994 = n853[66:21]; // extract
  assign n995 = {n994, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n996 = n995[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n997 = mant_b_ext_reg[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n998 = n996 | n997;
  assign n999 = n853[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1000 = n829 ? n998 : n999;
  assign n1001 = n853[66:22]; // extract
  assign n1002 = {n1001, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1003 = n1002[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1004 = mant_b_ext_reg[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1005 = n1003 | n1004;
  assign n1006 = n853[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1007 = n829 ? n1005 : n1006;
  assign n1008 = n853[66:23]; // extract
  assign n1009 = {n1008, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1010 = n1009[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1011 = mant_b_ext_reg[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1012 = n1010 | n1011;
  assign n1013 = n853[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1014 = n829 ? n1012 : n1013;
  assign n1015 = n853[66:24]; // extract
  assign n1016 = {n1015, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1017 = n1016[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1018 = mant_b_ext_reg[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1019 = n1017 | n1018;
  assign n1020 = n853[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1021 = n829 ? n1019 : n1020;
  assign n1022 = n853[66:25]; // extract
  assign n1023 = {n1022, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1024 = n1023[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1025 = mant_b_ext_reg[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1026 = n1024 | n1025;
  assign n1027 = n853[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1028 = n829 ? n1026 : n1027;
  assign n1029 = n853[66:26]; // extract
  assign n1030 = {n1029, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1031 = n1030[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1032 = mant_b_ext_reg[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1033 = n1031 | n1032;
  assign n1034 = n853[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1035 = n829 ? n1033 : n1034;
  assign n1036 = n853[66:27]; // extract
  assign n1037 = {n1036, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1038 = n1037[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1039 = mant_b_ext_reg[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1040 = n1038 | n1039;
  assign n1041 = n853[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1042 = n829 ? n1040 : n1041;
  assign n1043 = n853[66:28]; // extract
  assign n1044 = {n1043, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1045 = n1044[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1046 = mant_b_ext_reg[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1047 = n1045 | n1046;
  assign n1048 = n853[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1049 = n829 ? n1047 : n1048;
  assign n1050 = n853[66:29]; // extract
  assign n1051 = {n1050, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1052 = n1051[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1053 = mant_b_ext_reg[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1054 = n1052 | n1053;
  assign n1055 = n853[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1056 = n829 ? n1054 : n1055;
  assign n1057 = n853[66:30]; // extract
  assign n1058 = {n1057, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1059 = n1058[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1060 = mant_b_ext_reg[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1061 = n1059 | n1060;
  assign n1062 = n853[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1063 = n829 ? n1061 : n1062;
  assign n1064 = n853[66:31]; // extract
  assign n1065 = {n1064, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1066 = n1065[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1067 = mant_b_ext_reg[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1068 = n1066 | n1067;
  assign n1069 = n853[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1070 = n829 ? n1068 : n1069;
  assign n1071 = n853[66:32]; // extract
  assign n1072 = {n1071, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1073 = n1072[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1074 = mant_b_ext_reg[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1075 = n1073 | n1074;
  assign n1076 = n853[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1077 = n829 ? n1075 : n1076;
  assign n1078 = n853[66:33]; // extract
  assign n1079 = {n1078, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1080 = n1079[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1081 = mant_b_ext_reg[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1082 = n1080 | n1081;
  assign n1083 = n853[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1084 = n829 ? n1082 : n1083;
  assign n1085 = n853[66:34]; // extract
  assign n1086 = {n1085, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1087 = n1086[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1088 = mant_b_ext_reg[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1089 = n1087 | n1088;
  assign n1090 = n853[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1091 = n829 ? n1089 : n1090;
  assign n1092 = n853[66:35]; // extract
  assign n1093 = {n1092, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1094 = n1093[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1095 = mant_b_ext_reg[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1096 = n1094 | n1095;
  assign n1097 = n853[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1098 = n829 ? n1096 : n1097;
  assign n1099 = n853[66:36]; // extract
  assign n1100 = {n1099, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1101 = n1100[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1102 = mant_b_ext_reg[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1103 = n1101 | n1102;
  assign n1104 = n853[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1105 = n829 ? n1103 : n1104;
  assign n1106 = n853[66:37]; // extract
  assign n1107 = {n1106, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1108 = n1107[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1109 = mant_b_ext_reg[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1110 = n1108 | n1109;
  assign n1111 = n853[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1112 = n829 ? n1110 : n1111;
  assign n1113 = n853[66:38]; // extract
  assign n1114 = {n1113, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1115 = n1114[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1116 = mant_b_ext_reg[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1117 = n1115 | n1116;
  assign n1118 = n853[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1119 = n829 ? n1117 : n1118;
  assign n1120 = n853[66:39]; // extract
  assign n1121 = {n1120, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1122 = n1121[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1123 = mant_b_ext_reg[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1124 = n1122 | n1123;
  assign n1125 = n853[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1126 = n829 ? n1124 : n1125;
  assign n1127 = n853[66:40]; // extract
  assign n1128 = {n1127, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1129 = n1128[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1130 = mant_b_ext_reg[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1131 = n1129 | n1130;
  assign n1132 = n853[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1133 = n829 ? n1131 : n1132;
  assign n1134 = n853[66:41]; // extract
  assign n1135 = {n1134, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1136 = n1135[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1137 = mant_b_ext_reg[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1138 = n1136 | n1137;
  assign n1139 = n853[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1140 = n829 ? n1138 : n1139;
  assign n1141 = n853[66:42]; // extract
  assign n1142 = {n1141, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1143 = n1142[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1144 = mant_b_ext_reg[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1145 = n1143 | n1144;
  assign n1146 = n853[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1147 = n829 ? n1145 : n1146;
  assign n1148 = n853[66:43]; // extract
  assign n1149 = {n1148, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1150 = n1149[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1151 = mant_b_ext_reg[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1152 = n1150 | n1151;
  assign n1153 = n853[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1154 = n829 ? n1152 : n1153;
  assign n1155 = n853[66:44]; // extract
  assign n1156 = {n1155, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1157 = n1156[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1158 = mant_b_ext_reg[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1159 = n1157 | n1158;
  assign n1160 = n853[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1161 = n829 ? n1159 : n1160;
  assign n1162 = n853[66:45]; // extract
  assign n1163 = {n1162, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1164 = n1163[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1165 = mant_b_ext_reg[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1166 = n1164 | n1165;
  assign n1167 = n853[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1168 = n829 ? n1166 : n1167;
  assign n1169 = n853[66:46]; // extract
  assign n1170 = {n1169, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1171 = n1170[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1172 = mant_b_ext_reg[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1173 = n1171 | n1172;
  assign n1174 = n853[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1175 = n829 ? n1173 : n1174;
  assign n1176 = n853[66:47]; // extract
  assign n1177 = {n1176, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1178 = n1177[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1179 = mant_b_ext_reg[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1180 = n1178 | n1179;
  assign n1181 = n853[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1182 = n829 ? n1180 : n1181;
  assign n1183 = n853[66:48]; // extract
  assign n1184 = {n1183, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1185 = n1184[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1186 = mant_b_ext_reg[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1187 = n1185 | n1186;
  assign n1188 = n853[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1189 = n829 ? n1187 : n1188;
  assign n1190 = n853[66:49]; // extract
  assign n1191 = {n1190, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1192 = n1191[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1193 = mant_b_ext_reg[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1194 = n1192 | n1193;
  assign n1195 = n853[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1196 = n829 ? n1194 : n1195;
  assign n1197 = n853[66:50]; // extract
  assign n1198 = {n1197, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1199 = n1198[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1200 = mant_b_ext_reg[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1201 = n1199 | n1200;
  assign n1202 = n853[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1203 = n829 ? n1201 : n1202;
  assign n1204 = n853[66:51]; // extract
  assign n1205 = {n1204, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1206 = n1205[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1207 = mant_b_ext_reg[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1208 = n1206 | n1207;
  assign n1209 = n853[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1210 = n829 ? n1208 : n1209;
  assign n1211 = n853[66:52]; // extract
  assign n1212 = {n1211, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1213 = n1212[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1214 = mant_b_ext_reg[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1215 = n1213 | n1214;
  assign n1216 = n853[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1217 = n829 ? n1215 : n1216;
  assign n1218 = n853[66:53]; // extract
  assign n1219 = {n1218, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1220 = n1219[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1221 = mant_b_ext_reg[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1222 = n1220 | n1221;
  assign n1223 = n853[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1224 = n829 ? n1222 : n1223;
  assign n1225 = n853[66:54]; // extract
  assign n1226 = {n1225, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1227 = n1226[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1228 = mant_b_ext_reg[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1229 = n1227 | n1228;
  assign n1230 = n853[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1231 = n829 ? n1229 : n1230;
  assign n1232 = n853[66:55]; // extract
  assign n1233 = {n1232, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1234 = n1233[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1235 = mant_b_ext_reg[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1236 = n1234 | n1235;
  assign n1237 = n853[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1238 = n829 ? n1236 : n1237;
  assign n1239 = n853[66:56]; // extract
  assign n1240 = {n1239, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1241 = n1240[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1242 = mant_b_ext_reg[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1243 = n1241 | n1242;
  assign n1244 = n853[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1245 = n829 ? n1243 : n1244;
  assign n1246 = n853[66:57]; // extract
  assign n1247 = {n1246, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1248 = n1247[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1249 = mant_b_ext_reg[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1250 = n1248 | n1249;
  assign n1251 = n853[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1252 = n829 ? n1250 : n1251;
  assign n1253 = n853[66:58]; // extract
  assign n1254 = {n1253, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1255 = n1254[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1256 = mant_b_ext_reg[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1257 = n1255 | n1256;
  assign n1258 = n853[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1259 = n829 ? n1257 : n1258;
  assign n1260 = n853[66:59]; // extract
  assign n1261 = {n1260, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1262 = n1261[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1263 = mant_b_ext_reg[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1264 = n1262 | n1263;
  assign n1265 = n853[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1266 = n829 ? n1264 : n1265;
  assign n1267 = n853[66:60]; // extract
  assign n1268 = {n1267, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1269 = n1268[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1270 = mant_b_ext_reg[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1271 = n1269 | n1270;
  assign n1272 = n853[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1273 = n829 ? n1271 : n1272;
  assign n1274 = n853[66:61]; // extract
  assign n1275 = {n1274, n1273, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1276 = n1275[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1277 = mant_b_ext_reg[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1278 = n1276 | n1277;
  assign n1279 = n853[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1280 = n829 ? n1278 : n1279;
  assign n1281 = n853[66:62]; // extract
  assign n1282 = {n1281, n1280, n1273, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1283 = n1282[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1284 = mant_b_ext_reg[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1285 = n1283 | n1284;
  assign n1286 = n853[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1287 = n829 ? n1285 : n1286;
  assign n1288 = n853[66:63]; // extract
  assign n1289 = {n1288, n1287, n1280, n1273, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1290 = n1289[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1291 = mant_b_ext_reg[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1292 = n1290 | n1291;
  assign n1293 = n853[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1294 = n829 ? n1292 : n1293;
  assign n1295 = n853[66:64]; // extract
  assign n1296 = {n1295, n1294, n1287, n1280, n1273, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1297 = n1296[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1298 = mant_b_ext_reg[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1299 = n1297 | n1298;
  assign n1300 = n853[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1301 = n829 ? n1299 : n1300;
  assign n1302 = n853[66:65]; // extract
  assign n1303 = {n1302, n1301, n1294, n1287, n1280, n1273, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1304 = n1303[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1305 = mant_b_ext_reg[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1306 = n1304 | n1305;
  assign n1307 = n853[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1308 = n829 ? n1306 : n1307;
  assign n1309 = n853[66]; // extract
  assign n1310 = {n1309, n1308, n1301, n1294, n1287, n1280, n1273, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860, n852};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1311 = n1310[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1312 = mant_b_ext_reg[66]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1313 = n1311 | n1312;
  assign n1314 = n853[66]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1315 = n829 ? n1313 : n1314;
  /* mc68881_fp80_addsub_unit.vhd:105:5  */
  assign n1316 = n829 ? n831 : n829;
  assign n1317 = {n1315, n1308, n1301, n1294, n1287, n1280, n1273, n1266, n1259, n1252, n1245, n1238, n1231, n1224, n1217, n1210, n1203, n1196, n1189, n1182, n1175, n1168, n1161, n1154, n1147, n1140, n1133, n1126, n1119, n1112, n1105, n1098, n1091, n1084, n1077, n1070, n1063, n1056, n1049, n1042, n1035, n1028, n1021, n1014, n1007, n1000, n993, n986, n979, n972, n965, n958, n951, n944, n937, n930, n923, n916, n909, n902, n895, n888, n881, n874, n867, n860};
  /* mc68881_fp80_addsub_unit.vhd:105:5  */
  assign n1318 = n829 ? n1317 : n854;
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n1319 = {1'b0, n791};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n1321 = n1319 - 32'b00000000000000000000000000000001;
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n1322 = n1321[6:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:108:24  */
  assign n1324 = {n1318, n852};
  /* mc68881_fp80_addsub_unit.vhd:108:5  */
  assign n1326 = n1316 ? n2900 : n848;
  /* mc68881_fp80_addsub_unit.vhd:109:12  */
  assign n1327 = mant_b_ext_reg >> n791;
  assign n1328 = {n846, n844};
  /* mc68881_fp80_addsub_unit.vhd:109:5  */
  assign n1329 = n1316 ? n1327 : n1328;
  assign n1331 = n1329[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:110:5  */
  assign n1332 = n1336 ? 1'b1 : n1331;
  /* mc68881_fp80_addsub_unit.vhd:110:5  */
  assign n1334 = n1316 & n1326;
  /* mc68881_fp80_addsub_unit.vhd:110:5  */
  assign n1336 = n1334 & n1316;
  assign n1337 = n1329[66:1]; // extract
  assign n1338 = {n1337, n1332};
  /* mc68881_fp80_addsub_unit.vhd:113:5  */
  assign n1343 = n1316 ? n1338 : n832;
  /* mc68881_fp80_addsub_unit.vhd:290:15  */
  assign n1344 = {{14{a_exp_reg[17]}}, a_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:291:29  */
  assign n1345 = {{14{b_exp_reg[17]}}, b_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:291:29  */
  assign n1346 = {{14{a_exp_reg[17]}}, a_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:291:29  */
  assign n1347 = $signed(n1345) > $signed(n1346);
  /* mc68881_fp80_addsub_unit.vhd:292:36  */
  assign n1348 = {{14{b_exp_reg[17]}}, b_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:292:36  */
  assign n1349 = {{14{a_exp_reg[17]}}, a_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:292:36  */
  assign n1350 = n1348 - n1349;
  /* mc68881_fp80_addsub_unit.vhd:292:15  */
  assign n1351 = n1350[30:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:92:14  */
  assign n1360 = {1'b0, n1351};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:92:14  */
  assign n1362 = n1360 == 32'b00000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:92:5  */
  assign n1365 = n1362 ? 1'b0 : 1'b1;
  /* mc68881_fp80_addsub_unit.vhd:92:5  */
  assign n1369 = n1362 ? 1'b0 : 1'b1;
  /* mc68881_fp80_addsub_unit.vhd:92:5  */
  assign n1371 = n1362 ? mant_a_ext_reg : 67'bX;
  /* mc68881_fp80_addsub_unit.vhd:95:14  */
  assign n1372 = {1'b0, n1351};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:95:14  */
  assign n1374 = $signed(n1372) >= $signed(32'b00000000000000000000000001000011);
  /* mc68881_fp80_addsub_unit.vhd:96:16  */
  assign n1376 = mant_a_ext_reg != 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:97:9  */
  assign n1379 = n1365 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:96:7  */
  assign n1381 = n1376 ? n1379 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:96:7  */
  assign n1383 = n1365 ? n1381 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:99:7  */
  assign n1385 = n1365 ? n1383 : 1'b0;
  assign n1387 = {66'b000000000000000000000000000000000000000000000000000000000000000000, n1385};
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1389 = n1400 ? 1'b0 : n1365;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1391 = n1401 ? 1'b0 : n1369;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1392 = n1402 ? n1387 : n1371;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1393 = n1365 & n1374;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1394 = n1365 & n1374;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1395 = n1365 & n1374;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1397 = n1374 ? n1385 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1399 = n1374 ? n1383 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1400 = n1393 & n1365;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1401 = n1394 & n1365;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1402 = n1395 & n1365;
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1404 = n1365 ? n1397 : 1'b0;
  assign n1406 = n1405[66:1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:95:5  */
  assign n1408 = n1365 ? n1399 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:104:26  */
  assign n1410 = mant_a_ext_reg[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:104:5  */
  assign n1412 = n1389 ? n1410 : 1'bX;
  assign n1414 = n1413[66:1]; // extract
  assign n1415 = {n1414, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1416 = n1415[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1417 = mant_a_ext_reg[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1418 = n1416 | n1417;
  assign n1419 = n1413[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1420 = n1389 ? n1418 : n1419;
  assign n1421 = n1413[66:2]; // extract
  assign n1422 = {n1421, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1423 = n1422[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1424 = mant_a_ext_reg[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1425 = n1423 | n1424;
  assign n1426 = n1413[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1427 = n1389 ? n1425 : n1426;
  assign n1428 = n1413[66:3]; // extract
  assign n1429 = {n1428, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1430 = n1429[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1431 = mant_a_ext_reg[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1432 = n1430 | n1431;
  assign n1433 = n1413[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1434 = n1389 ? n1432 : n1433;
  assign n1435 = n1413[66:4]; // extract
  assign n1436 = {n1435, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1437 = n1436[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1438 = mant_a_ext_reg[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1439 = n1437 | n1438;
  assign n1440 = n1413[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1441 = n1389 ? n1439 : n1440;
  assign n1442 = n1413[66:5]; // extract
  assign n1443 = {n1442, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1444 = n1443[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1445 = mant_a_ext_reg[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1446 = n1444 | n1445;
  assign n1447 = n1413[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1448 = n1389 ? n1446 : n1447;
  assign n1449 = n1413[66:6]; // extract
  assign n1450 = {n1449, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1451 = n1450[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1452 = mant_a_ext_reg[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1453 = n1451 | n1452;
  assign n1454 = n1413[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1455 = n1389 ? n1453 : n1454;
  assign n1456 = n1413[66:7]; // extract
  assign n1457 = {n1456, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1458 = n1457[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1459 = mant_a_ext_reg[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1460 = n1458 | n1459;
  assign n1461 = n1413[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1462 = n1389 ? n1460 : n1461;
  assign n1463 = n1413[66:8]; // extract
  assign n1464 = {n1463, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1465 = n1464[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1466 = mant_a_ext_reg[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1467 = n1465 | n1466;
  assign n1468 = n1413[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1469 = n1389 ? n1467 : n1468;
  assign n1470 = n1413[66:9]; // extract
  assign n1471 = {n1470, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1472 = n1471[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1473 = mant_a_ext_reg[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1474 = n1472 | n1473;
  assign n1475 = n1413[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1476 = n1389 ? n1474 : n1475;
  assign n1477 = n1413[66:10]; // extract
  assign n1478 = {n1477, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1479 = n1478[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1480 = mant_a_ext_reg[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1481 = n1479 | n1480;
  assign n1482 = n1413[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1483 = n1389 ? n1481 : n1482;
  assign n1484 = n1413[66:11]; // extract
  assign n1485 = {n1484, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1486 = n1485[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1487 = mant_a_ext_reg[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1488 = n1486 | n1487;
  assign n1489 = n1413[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1490 = n1389 ? n1488 : n1489;
  assign n1491 = n1413[66:12]; // extract
  assign n1492 = {n1491, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1493 = n1492[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1494 = mant_a_ext_reg[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1495 = n1493 | n1494;
  assign n1496 = n1413[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1497 = n1389 ? n1495 : n1496;
  assign n1498 = n1413[66:13]; // extract
  assign n1499 = {n1498, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1500 = n1499[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1501 = mant_a_ext_reg[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1502 = n1500 | n1501;
  assign n1503 = n1413[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1504 = n1389 ? n1502 : n1503;
  assign n1505 = n1413[66:14]; // extract
  assign n1506 = {n1505, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1507 = n1506[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1508 = mant_a_ext_reg[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1509 = n1507 | n1508;
  assign n1510 = n1413[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1511 = n1389 ? n1509 : n1510;
  assign n1512 = n1413[66:15]; // extract
  assign n1513 = {n1512, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1514 = n1513[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1515 = mant_a_ext_reg[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1516 = n1514 | n1515;
  assign n1517 = n1413[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1518 = n1389 ? n1516 : n1517;
  assign n1519 = n1413[66:16]; // extract
  assign n1520 = {n1519, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1521 = n1520[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1522 = mant_a_ext_reg[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1523 = n1521 | n1522;
  assign n1524 = n1413[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1525 = n1389 ? n1523 : n1524;
  assign n1526 = n1413[66:17]; // extract
  assign n1527 = {n1526, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1528 = n1527[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1529 = mant_a_ext_reg[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1530 = n1528 | n1529;
  assign n1531 = n1413[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1532 = n1389 ? n1530 : n1531;
  assign n1533 = n1413[66:18]; // extract
  assign n1534 = {n1533, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1535 = n1534[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1536 = mant_a_ext_reg[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1537 = n1535 | n1536;
  assign n1538 = n1413[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1539 = n1389 ? n1537 : n1538;
  assign n1540 = n1413[66:19]; // extract
  assign n1541 = {n1540, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1542 = n1541[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1543 = mant_a_ext_reg[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1544 = n1542 | n1543;
  assign n1545 = n1413[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1546 = n1389 ? n1544 : n1545;
  assign n1547 = n1413[66:20]; // extract
  assign n1548 = {n1547, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1549 = n1548[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1550 = mant_a_ext_reg[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1551 = n1549 | n1550;
  assign n1552 = n1413[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1553 = n1389 ? n1551 : n1552;
  assign n1554 = n1413[66:21]; // extract
  assign n1555 = {n1554, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1556 = n1555[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1557 = mant_a_ext_reg[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1558 = n1556 | n1557;
  assign n1559 = n1413[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1560 = n1389 ? n1558 : n1559;
  assign n1561 = n1413[66:22]; // extract
  assign n1562 = {n1561, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1563 = n1562[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1564 = mant_a_ext_reg[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1565 = n1563 | n1564;
  assign n1566 = n1413[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1567 = n1389 ? n1565 : n1566;
  assign n1568 = n1413[66:23]; // extract
  assign n1569 = {n1568, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1570 = n1569[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1571 = mant_a_ext_reg[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1572 = n1570 | n1571;
  assign n1573 = n1413[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1574 = n1389 ? n1572 : n1573;
  assign n1575 = n1413[66:24]; // extract
  assign n1576 = {n1575, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1577 = n1576[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1578 = mant_a_ext_reg[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1579 = n1577 | n1578;
  assign n1580 = n1413[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1581 = n1389 ? n1579 : n1580;
  assign n1582 = n1413[66:25]; // extract
  assign n1583 = {n1582, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1584 = n1583[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1585 = mant_a_ext_reg[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1586 = n1584 | n1585;
  assign n1587 = n1413[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1588 = n1389 ? n1586 : n1587;
  assign n1589 = n1413[66:26]; // extract
  assign n1590 = {n1589, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1591 = n1590[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1592 = mant_a_ext_reg[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1593 = n1591 | n1592;
  assign n1594 = n1413[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1595 = n1389 ? n1593 : n1594;
  assign n1596 = n1413[66:27]; // extract
  assign n1597 = {n1596, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1598 = n1597[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1599 = mant_a_ext_reg[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1600 = n1598 | n1599;
  assign n1601 = n1413[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1602 = n1389 ? n1600 : n1601;
  assign n1603 = n1413[66:28]; // extract
  assign n1604 = {n1603, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1605 = n1604[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1606 = mant_a_ext_reg[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1607 = n1605 | n1606;
  assign n1608 = n1413[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1609 = n1389 ? n1607 : n1608;
  assign n1610 = n1413[66:29]; // extract
  assign n1611 = {n1610, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1612 = n1611[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1613 = mant_a_ext_reg[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1614 = n1612 | n1613;
  assign n1615 = n1413[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1616 = n1389 ? n1614 : n1615;
  assign n1617 = n1413[66:30]; // extract
  assign n1618 = {n1617, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1619 = n1618[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1620 = mant_a_ext_reg[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1621 = n1619 | n1620;
  assign n1622 = n1413[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1623 = n1389 ? n1621 : n1622;
  assign n1624 = n1413[66:31]; // extract
  assign n1625 = {n1624, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1626 = n1625[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1627 = mant_a_ext_reg[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1628 = n1626 | n1627;
  assign n1629 = n1413[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1630 = n1389 ? n1628 : n1629;
  assign n1631 = n1413[66:32]; // extract
  assign n1632 = {n1631, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1633 = n1632[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1634 = mant_a_ext_reg[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1635 = n1633 | n1634;
  assign n1636 = n1413[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1637 = n1389 ? n1635 : n1636;
  assign n1638 = n1413[66:33]; // extract
  assign n1639 = {n1638, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1640 = n1639[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1641 = mant_a_ext_reg[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1642 = n1640 | n1641;
  assign n1643 = n1413[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1644 = n1389 ? n1642 : n1643;
  assign n1645 = n1413[66:34]; // extract
  assign n1646 = {n1645, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1647 = n1646[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1648 = mant_a_ext_reg[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1649 = n1647 | n1648;
  assign n1650 = n1413[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1651 = n1389 ? n1649 : n1650;
  assign n1652 = n1413[66:35]; // extract
  assign n1653 = {n1652, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1654 = n1653[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1655 = mant_a_ext_reg[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1656 = n1654 | n1655;
  assign n1657 = n1413[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1658 = n1389 ? n1656 : n1657;
  assign n1659 = n1413[66:36]; // extract
  assign n1660 = {n1659, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1661 = n1660[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1662 = mant_a_ext_reg[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1663 = n1661 | n1662;
  assign n1664 = n1413[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1665 = n1389 ? n1663 : n1664;
  assign n1666 = n1413[66:37]; // extract
  assign n1667 = {n1666, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1668 = n1667[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1669 = mant_a_ext_reg[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1670 = n1668 | n1669;
  assign n1671 = n1413[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1672 = n1389 ? n1670 : n1671;
  assign n1673 = n1413[66:38]; // extract
  assign n1674 = {n1673, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1675 = n1674[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1676 = mant_a_ext_reg[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1677 = n1675 | n1676;
  assign n1678 = n1413[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1679 = n1389 ? n1677 : n1678;
  assign n1680 = n1413[66:39]; // extract
  assign n1681 = {n1680, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1682 = n1681[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1683 = mant_a_ext_reg[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1684 = n1682 | n1683;
  assign n1685 = n1413[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1686 = n1389 ? n1684 : n1685;
  assign n1687 = n1413[66:40]; // extract
  assign n1688 = {n1687, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1689 = n1688[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1690 = mant_a_ext_reg[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1691 = n1689 | n1690;
  assign n1692 = n1413[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1693 = n1389 ? n1691 : n1692;
  assign n1694 = n1413[66:41]; // extract
  assign n1695 = {n1694, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1696 = n1695[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1697 = mant_a_ext_reg[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1698 = n1696 | n1697;
  assign n1699 = n1413[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1700 = n1389 ? n1698 : n1699;
  assign n1701 = n1413[66:42]; // extract
  assign n1702 = {n1701, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1703 = n1702[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1704 = mant_a_ext_reg[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1705 = n1703 | n1704;
  assign n1706 = n1413[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1707 = n1389 ? n1705 : n1706;
  assign n1708 = n1413[66:43]; // extract
  assign n1709 = {n1708, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1710 = n1709[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1711 = mant_a_ext_reg[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1712 = n1710 | n1711;
  assign n1713 = n1413[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1714 = n1389 ? n1712 : n1713;
  assign n1715 = n1413[66:44]; // extract
  assign n1716 = {n1715, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1717 = n1716[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1718 = mant_a_ext_reg[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1719 = n1717 | n1718;
  assign n1720 = n1413[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1721 = n1389 ? n1719 : n1720;
  assign n1722 = n1413[66:45]; // extract
  assign n1723 = {n1722, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1724 = n1723[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1725 = mant_a_ext_reg[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1726 = n1724 | n1725;
  assign n1727 = n1413[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1728 = n1389 ? n1726 : n1727;
  assign n1729 = n1413[66:46]; // extract
  assign n1730 = {n1729, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1731 = n1730[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1732 = mant_a_ext_reg[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1733 = n1731 | n1732;
  assign n1734 = n1413[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1735 = n1389 ? n1733 : n1734;
  assign n1736 = n1413[66:47]; // extract
  assign n1737 = {n1736, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1738 = n1737[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1739 = mant_a_ext_reg[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1740 = n1738 | n1739;
  assign n1741 = n1413[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1742 = n1389 ? n1740 : n1741;
  assign n1743 = n1413[66:48]; // extract
  assign n1744 = {n1743, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1745 = n1744[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1746 = mant_a_ext_reg[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1747 = n1745 | n1746;
  assign n1748 = n1413[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1749 = n1389 ? n1747 : n1748;
  assign n1750 = n1413[66:49]; // extract
  assign n1751 = {n1750, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1752 = n1751[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1753 = mant_a_ext_reg[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1754 = n1752 | n1753;
  assign n1755 = n1413[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1756 = n1389 ? n1754 : n1755;
  assign n1757 = n1413[66:50]; // extract
  assign n1758 = {n1757, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1759 = n1758[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1760 = mant_a_ext_reg[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1761 = n1759 | n1760;
  assign n1762 = n1413[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1763 = n1389 ? n1761 : n1762;
  assign n1764 = n1413[66:51]; // extract
  assign n1765 = {n1764, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1766 = n1765[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1767 = mant_a_ext_reg[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1768 = n1766 | n1767;
  assign n1769 = n1413[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1770 = n1389 ? n1768 : n1769;
  assign n1771 = n1413[66:52]; // extract
  assign n1772 = {n1771, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1773 = n1772[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1774 = mant_a_ext_reg[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1775 = n1773 | n1774;
  assign n1776 = n1413[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1777 = n1389 ? n1775 : n1776;
  assign n1778 = n1413[66:53]; // extract
  assign n1779 = {n1778, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1780 = n1779[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1781 = mant_a_ext_reg[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1782 = n1780 | n1781;
  assign n1783 = n1413[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1784 = n1389 ? n1782 : n1783;
  assign n1785 = n1413[66:54]; // extract
  assign n1786 = {n1785, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1787 = n1786[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1788 = mant_a_ext_reg[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1789 = n1787 | n1788;
  assign n1790 = n1413[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1791 = n1389 ? n1789 : n1790;
  assign n1792 = n1413[66:55]; // extract
  assign n1793 = {n1792, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1794 = n1793[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1795 = mant_a_ext_reg[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1796 = n1794 | n1795;
  assign n1797 = n1413[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1798 = n1389 ? n1796 : n1797;
  assign n1799 = n1413[66:56]; // extract
  assign n1800 = {n1799, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1801 = n1800[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1802 = mant_a_ext_reg[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1803 = n1801 | n1802;
  assign n1804 = n1413[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1805 = n1389 ? n1803 : n1804;
  assign n1806 = n1413[66:57]; // extract
  assign n1807 = {n1806, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1808 = n1807[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1809 = mant_a_ext_reg[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1810 = n1808 | n1809;
  assign n1811 = n1413[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1812 = n1389 ? n1810 : n1811;
  assign n1813 = n1413[66:58]; // extract
  assign n1814 = {n1813, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1815 = n1814[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1816 = mant_a_ext_reg[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1817 = n1815 | n1816;
  assign n1818 = n1413[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1819 = n1389 ? n1817 : n1818;
  assign n1820 = n1413[66:59]; // extract
  assign n1821 = {n1820, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1822 = n1821[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1823 = mant_a_ext_reg[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1824 = n1822 | n1823;
  assign n1825 = n1413[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1826 = n1389 ? n1824 : n1825;
  assign n1827 = n1413[66:60]; // extract
  assign n1828 = {n1827, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1829 = n1828[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1830 = mant_a_ext_reg[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1831 = n1829 | n1830;
  assign n1832 = n1413[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1833 = n1389 ? n1831 : n1832;
  assign n1834 = n1413[66:61]; // extract
  assign n1835 = {n1834, n1833, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1836 = n1835[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1837 = mant_a_ext_reg[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1838 = n1836 | n1837;
  assign n1839 = n1413[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1840 = n1389 ? n1838 : n1839;
  assign n1841 = n1413[66:62]; // extract
  assign n1842 = {n1841, n1840, n1833, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1843 = n1842[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1844 = mant_a_ext_reg[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1845 = n1843 | n1844;
  assign n1846 = n1413[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1847 = n1389 ? n1845 : n1846;
  assign n1848 = n1413[66:63]; // extract
  assign n1849 = {n1848, n1847, n1840, n1833, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1850 = n1849[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1851 = mant_a_ext_reg[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1852 = n1850 | n1851;
  assign n1853 = n1413[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1854 = n1389 ? n1852 : n1853;
  assign n1855 = n1413[66:64]; // extract
  assign n1856 = {n1855, n1854, n1847, n1840, n1833, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1857 = n1856[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1858 = mant_a_ext_reg[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1859 = n1857 | n1858;
  assign n1860 = n1413[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1861 = n1389 ? n1859 : n1860;
  assign n1862 = n1413[66:65]; // extract
  assign n1863 = {n1862, n1861, n1854, n1847, n1840, n1833, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1864 = n1863[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1865 = mant_a_ext_reg[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1866 = n1864 | n1865;
  assign n1867 = n1413[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1868 = n1389 ? n1866 : n1867;
  assign n1869 = n1413[66]; // extract
  assign n1870 = {n1869, n1868, n1861, n1854, n1847, n1840, n1833, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420, n1412};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1871 = n1870[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1872 = mant_a_ext_reg[66]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1873 = n1871 | n1872;
  assign n1874 = n1413[66]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:7  */
  assign n1875 = n1389 ? n1873 : n1874;
  /* mc68881_fp80_addsub_unit.vhd:105:5  */
  assign n1876 = n1389 ? n1391 : n1389;
  assign n1877 = {n1875, n1868, n1861, n1854, n1847, n1840, n1833, n1826, n1819, n1812, n1805, n1798, n1791, n1784, n1777, n1770, n1763, n1756, n1749, n1742, n1735, n1728, n1721, n1714, n1707, n1700, n1693, n1686, n1679, n1672, n1665, n1658, n1651, n1644, n1637, n1630, n1623, n1616, n1609, n1602, n1595, n1588, n1581, n1574, n1567, n1560, n1553, n1546, n1539, n1532, n1525, n1518, n1511, n1504, n1497, n1490, n1483, n1476, n1469, n1462, n1455, n1448, n1441, n1434, n1427, n1420};
  /* mc68881_fp80_addsub_unit.vhd:105:5  */
  assign n1878 = n1389 ? n1877 : n1414;
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n1879 = {1'b0, n1351};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n1881 = n1879 - 32'b00000000000000000000000000000001;
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n1882 = n1881[6:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:108:24  */
  assign n1884 = {n1878, n1412};
  /* mc68881_fp80_addsub_unit.vhd:108:5  */
  assign n1886 = n1876 ? n2903 : n1408;
  /* mc68881_fp80_addsub_unit.vhd:109:12  */
  assign n1887 = mant_a_ext_reg >> n1351;
  assign n1888 = {n1406, n1404};
  /* mc68881_fp80_addsub_unit.vhd:109:5  */
  assign n1889 = n1876 ? n1887 : n1888;
  assign n1891 = n1889[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:110:5  */
  assign n1892 = n1896 ? 1'b1 : n1891;
  /* mc68881_fp80_addsub_unit.vhd:110:5  */
  assign n1894 = n1876 & n1886;
  /* mc68881_fp80_addsub_unit.vhd:110:5  */
  assign n1896 = n1894 & n1876;
  assign n1897 = n1889[66:1]; // extract
  assign n1898 = {n1897, n1892};
  /* mc68881_fp80_addsub_unit.vhd:113:5  */
  assign n1903 = n1876 ? n1898 : n1392;
  /* mc68881_fp80_addsub_unit.vhd:294:15  */
  assign n1904 = {{14{b_exp_reg[17]}}, b_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:296:15  */
  assign n1905 = {{14{a_exp_reg[17]}}, a_exp_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:291:13  */
  assign n1906 = n1347 ? n1903 : mant_a_ext_reg;
  /* mc68881_fp80_addsub_unit.vhd:291:13  */
  assign n1907 = n1347 ? n1904 : n1905;
  /* mc68881_fp80_addsub_unit.vhd:287:13  */
  assign n1909 = n787 ? mant_a_ext_reg : n1906;
  /* mc68881_fp80_addsub_unit.vhd:287:13  */
  assign n1910 = n787 ? n1343 : mant_b_ext_reg;
  /* mc68881_fp80_addsub_unit.vhd:287:13  */
  assign n1911 = n787 ? n1344 : n1907;
  /* mc68881_fp80_addsub_unit.vhd:301:31  */
  assign n1913 = n1911[17:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:304:42  */
  assign n1914 = a_sign_reg == sign_b_reg;
  /* mc68881_fp80_addsub_unit.vhd:279:11  */
  assign n1917 = early_exit_reg ? 3'b000 : 3'b011;
  /* mc68881_fp80_addsub_unit.vhd:279:11  */
  assign n1918 = early_exit_reg ? mant_a_ext_reg : n1909;
  /* mc68881_fp80_addsub_unit.vhd:279:11  */
  assign n1919 = early_exit_reg ? mant_b_ext_reg : n1910;
  /* mc68881_fp80_addsub_unit.vhd:279:11  */
  assign n1920 = early_exit_reg ? exp_res_reg : n1913;
  /* mc68881_fp80_addsub_unit.vhd:279:11  */
  assign n1921 = early_exit_reg ? same_sign_reg : n1914;
  /* mc68881_fp80_addsub_unit.vhd:279:11  */
  assign n1924 = early_exit_reg ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:279:11  */
  assign n1925 = early_exit_reg ? early_result_reg : result_reg;
  /* mc68881_fp80_addsub_unit.vhd:278:9  */
  assign n1931 = state_reg == 3'b010;
  /* mc68881_fp80_addsub_unit.vhd:315:27  */
  assign n1933 = {1'b0, mant_a_ext_reg};
  /* mc68881_fp80_addsub_unit.vhd:315:52  */
  assign n1935 = {1'b0, mant_b_ext_reg};
  /* mc68881_fp80_addsub_unit.vhd:315:45  */
  assign n1936 = n1933 + n1935;
  /* mc68881_fp80_addsub_unit.vhd:319:21  */
  assign n1937 = n1936[67]; // extract
  /* mc68881_fp80_addsub_unit.vhd:320:53  */
  assign n1939 = n1936[66:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:104:26  */
  assign n1947 = n1936[0]; // extract
  assign n1949 = n1948[66:1]; // extract
  assign n1950 = {n1949, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1951 = n1950[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1952 = n1936[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1953 = n1951 | n1952;
  assign n1954 = n1948[66:2]; // extract
  assign n1955 = {n1954, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1956 = n1955[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1957 = n1936[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1958 = n1956 | n1957;
  assign n1959 = n1948[66:3]; // extract
  assign n1960 = {n1959, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1961 = n1960[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1962 = n1936[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1963 = n1961 | n1962;
  assign n1964 = n1948[66:4]; // extract
  assign n1965 = {n1964, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1966 = n1965[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1967 = n1936[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1968 = n1966 | n1967;
  assign n1969 = n1948[66:5]; // extract
  assign n1970 = {n1969, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1971 = n1970[4]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1972 = n1936[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1973 = n1971 | n1972;
  assign n1974 = n1948[66:6]; // extract
  assign n1975 = {n1974, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1976 = n1975[5]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1977 = n1936[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1978 = n1976 | n1977;
  assign n1979 = n1948[66:7]; // extract
  assign n1980 = {n1979, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1981 = n1980[6]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1982 = n1936[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1983 = n1981 | n1982;
  assign n1984 = n1948[66:8]; // extract
  assign n1985 = {n1984, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1986 = n1985[7]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1987 = n1936[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1988 = n1986 | n1987;
  assign n1989 = n1948[66:9]; // extract
  assign n1990 = {n1989, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1991 = n1990[8]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1992 = n1936[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1993 = n1991 | n1992;
  assign n1994 = n1948[66:10]; // extract
  assign n1995 = {n1994, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n1996 = n1995[9]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n1997 = n1936[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n1998 = n1996 | n1997;
  assign n1999 = n1948[66:11]; // extract
  assign n2000 = {n1999, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2001 = n2000[10]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2002 = n1936[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2003 = n2001 | n2002;
  assign n2004 = n1948[66:12]; // extract
  assign n2005 = {n2004, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2006 = n2005[11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2007 = n1936[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2008 = n2006 | n2007;
  assign n2009 = n1948[66:13]; // extract
  assign n2010 = {n2009, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2011 = n2010[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2012 = n1936[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2013 = n2011 | n2012;
  assign n2014 = n1948[66:14]; // extract
  assign n2015 = {n2014, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2016 = n2015[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2017 = n1936[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2018 = n2016 | n2017;
  assign n2019 = n1948[66:15]; // extract
  assign n2020 = {n2019, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2021 = n2020[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2022 = n1936[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2023 = n2021 | n2022;
  assign n2024 = n1948[66:16]; // extract
  assign n2025 = {n2024, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2026 = n2025[15]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2027 = n1936[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2028 = n2026 | n2027;
  assign n2029 = n1948[66:17]; // extract
  assign n2030 = {n2029, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2031 = n2030[16]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2032 = n1936[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2033 = n2031 | n2032;
  assign n2034 = n1948[66:18]; // extract
  assign n2035 = {n2034, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2036 = n2035[17]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2037 = n1936[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2038 = n2036 | n2037;
  assign n2039 = n1948[66:19]; // extract
  assign n2040 = {n2039, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2041 = n2040[18]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2042 = n1936[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2043 = n2041 | n2042;
  assign n2044 = n1948[66:20]; // extract
  assign n2045 = {n2044, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2046 = n2045[19]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2047 = n1936[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2048 = n2046 | n2047;
  assign n2049 = n1948[66:21]; // extract
  assign n2050 = {n2049, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2051 = n2050[20]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2052 = n1936[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2053 = n2051 | n2052;
  assign n2054 = n1948[66:22]; // extract
  assign n2055 = {n2054, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2056 = n2055[21]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2057 = n1936[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2058 = n2056 | n2057;
  assign n2059 = n1948[66:23]; // extract
  assign n2060 = {n2059, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2061 = n2060[22]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2062 = n1936[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2063 = n2061 | n2062;
  assign n2064 = n1948[66:24]; // extract
  assign n2065 = {n2064, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2066 = n2065[23]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2067 = n1936[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2068 = n2066 | n2067;
  assign n2069 = n1948[66:25]; // extract
  assign n2070 = {n2069, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2071 = n2070[24]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2072 = n1936[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2073 = n2071 | n2072;
  assign n2074 = n1948[66:26]; // extract
  assign n2075 = {n2074, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2076 = n2075[25]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2077 = n1936[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2078 = n2076 | n2077;
  assign n2079 = n1948[66:27]; // extract
  assign n2080 = {n2079, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2081 = n2080[26]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2082 = n1936[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2083 = n2081 | n2082;
  assign n2084 = n1948[66:28]; // extract
  assign n2085 = {n2084, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2086 = n2085[27]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2087 = n1936[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2088 = n2086 | n2087;
  assign n2089 = n1948[66:29]; // extract
  assign n2090 = {n2089, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2091 = n2090[28]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2092 = n1936[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2093 = n2091 | n2092;
  assign n2094 = n1948[66:30]; // extract
  assign n2095 = {n2094, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2096 = n2095[29]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2097 = n1936[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2098 = n2096 | n2097;
  assign n2099 = n1948[66:31]; // extract
  assign n2100 = {n2099, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2101 = n2100[30]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2102 = n1936[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2103 = n2101 | n2102;
  assign n2104 = n1948[66:32]; // extract
  assign n2105 = {n2104, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2106 = n2105[31]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2107 = n1936[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2108 = n2106 | n2107;
  assign n2109 = n1948[66:33]; // extract
  assign n2110 = {n2109, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2111 = n2110[32]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2112 = n1936[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2113 = n2111 | n2112;
  assign n2114 = n1948[66:34]; // extract
  assign n2115 = {n2114, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2116 = n2115[33]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2117 = n1936[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2118 = n2116 | n2117;
  assign n2119 = n1948[66:35]; // extract
  assign n2120 = {n2119, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2121 = n2120[34]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2122 = n1936[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2123 = n2121 | n2122;
  assign n2124 = n1948[66:36]; // extract
  assign n2125 = {n2124, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2126 = n2125[35]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2127 = n1936[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2128 = n2126 | n2127;
  assign n2129 = n1948[66:37]; // extract
  assign n2130 = {n2129, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2131 = n2130[36]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2132 = n1936[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2133 = n2131 | n2132;
  assign n2134 = n1948[66:38]; // extract
  assign n2135 = {n2134, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2136 = n2135[37]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2137 = n1936[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2138 = n2136 | n2137;
  assign n2139 = n1948[66:39]; // extract
  assign n2140 = {n2139, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2141 = n2140[38]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2142 = n1936[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2143 = n2141 | n2142;
  assign n2144 = n1948[66:40]; // extract
  assign n2145 = {n2144, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2146 = n2145[39]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2147 = n1936[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2148 = n2146 | n2147;
  assign n2149 = n1948[66:41]; // extract
  assign n2150 = {n2149, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2151 = n2150[40]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2152 = n1936[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2153 = n2151 | n2152;
  assign n2154 = n1948[66:42]; // extract
  assign n2155 = {n2154, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2156 = n2155[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2157 = n1936[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2158 = n2156 | n2157;
  assign n2159 = n1948[66:43]; // extract
  assign n2160 = {n2159, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2161 = n2160[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2162 = n1936[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2163 = n2161 | n2162;
  assign n2164 = n1948[66:44]; // extract
  assign n2165 = {n2164, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2166 = n2165[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2167 = n1936[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2168 = n2166 | n2167;
  assign n2169 = n1948[66:45]; // extract
  assign n2170 = {n2169, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2171 = n2170[44]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2172 = n1936[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2173 = n2171 | n2172;
  assign n2174 = n1948[66:46]; // extract
  assign n2175 = {n2174, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2176 = n2175[45]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2177 = n1936[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2178 = n2176 | n2177;
  assign n2179 = n1948[66:47]; // extract
  assign n2180 = {n2179, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2181 = n2180[46]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2182 = n1936[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2183 = n2181 | n2182;
  assign n2184 = n1948[66:48]; // extract
  assign n2185 = {n2184, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2186 = n2185[47]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2187 = n1936[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2188 = n2186 | n2187;
  assign n2189 = n1948[66:49]; // extract
  assign n2190 = {n2189, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2191 = n2190[48]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2192 = n1936[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2193 = n2191 | n2192;
  assign n2194 = n1948[66:50]; // extract
  assign n2195 = {n2194, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2196 = n2195[49]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2197 = n1936[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2198 = n2196 | n2197;
  assign n2199 = n1948[66:51]; // extract
  assign n2200 = {n2199, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2201 = n2200[50]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2202 = n1936[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2203 = n2201 | n2202;
  assign n2204 = n1948[66:52]; // extract
  assign n2205 = {n2204, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2206 = n2205[51]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2207 = n1936[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2208 = n2206 | n2207;
  assign n2209 = n1948[66:53]; // extract
  assign n2210 = {n2209, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2211 = n2210[52]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2212 = n1936[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2213 = n2211 | n2212;
  assign n2214 = n1948[66:54]; // extract
  assign n2215 = {n2214, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2216 = n2215[53]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2217 = n1936[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2218 = n2216 | n2217;
  assign n2219 = n1948[66:55]; // extract
  assign n2220 = {n2219, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2221 = n2220[54]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2222 = n1936[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2223 = n2221 | n2222;
  assign n2224 = n1948[66:56]; // extract
  assign n2225 = {n2224, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2226 = n2225[55]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2227 = n1936[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2228 = n2226 | n2227;
  assign n2229 = n1948[66:57]; // extract
  assign n2230 = {n2229, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2231 = n2230[56]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2232 = n1936[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2233 = n2231 | n2232;
  assign n2234 = n1948[66:58]; // extract
  assign n2235 = {n2234, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2236 = n2235[57]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2237 = n1936[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2238 = n2236 | n2237;
  assign n2239 = n1948[66:59]; // extract
  assign n2240 = {n2239, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2241 = n2240[58]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2242 = n1936[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2243 = n2241 | n2242;
  assign n2244 = n1948[66:60]; // extract
  assign n2245 = {n2244, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2246 = n2245[59]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2247 = n1936[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2248 = n2246 | n2247;
  assign n2249 = n1948[66:61]; // extract
  assign n2250 = {n2249, n2248, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2251 = n2250[60]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2252 = n1936[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2253 = n2251 | n2252;
  assign n2254 = n1948[66:62]; // extract
  assign n2255 = {n2254, n2253, n2248, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2256 = n2255[61]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2257 = n1936[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2258 = n2256 | n2257;
  assign n2259 = n1948[66:63]; // extract
  assign n2260 = {n2259, n2258, n2253, n2248, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2261 = n2260[62]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2262 = n1936[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2263 = n2261 | n2262;
  assign n2264 = n1948[66:64]; // extract
  assign n2265 = {n2264, n2263, n2258, n2253, n2248, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2266 = n2265[63]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2267 = n1936[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2268 = n2266 | n2267;
  assign n2269 = n1948[66:65]; // extract
  assign n2270 = {n2269, n2268, n2263, n2258, n2253, n2248, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2271 = n2270[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2272 = n1936[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2273 = n2271 | n2272;
  assign n2274 = n1948[66]; // extract
  assign n2275 = {n2274, n2273, n2268, n2263, n2258, n2253, n2248, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:106:32  */
  assign n2276 = n2275[65]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:46  */
  assign n2277 = n1936[66]; // extract
  /* mc68881_fp80_addsub_unit.vhd:106:38  */
  assign n2278 = n2276 | n2277;
  assign n2279 = {n2278, n2273, n2268, n2263, n2258, n2253, n2248, n2243, n2238, n2233, n2228, n2223, n2218, n2213, n2208, n2203, n2198, n2193, n2188, n2183, n2178, n2173, n2168, n2163, n2158, n2153, n2148, n2143, n2138, n2133, n2128, n2123, n2118, n2113, n2108, n2103, n2098, n2093, n2088, n2083, n2078, n2073, n2068, n2063, n2058, n2053, n2048, n2043, n2038, n2033, n2028, n2023, n2018, n2013, n2008, n2003, n1998, n1993, n1988, n1983, n1978, n1973, n1968, n1963, n1958, n1953, n1947};
  /* mc68881_fp80_addsub_unit.vhd:108:24  */
  assign n2280 = n2279[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:109:12  */
  assign n2283 = n1939 >> 31'b0000000000000000000000000000001;
  assign n2286 = n2283[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:110:5  */
  assign n2287 = n2280 ? 1'b1 : n2286;
  assign n2288 = n2283[66:1]; // extract
  assign n2289 = {n2288, n2287};
  assign n2291 = n2289[65:0]; // extract
  assign n2293 = {1'b1, n2291};
  /* mc68881_fp80_addsub_unit.vhd:324:30  */
  assign n2294 = {{14{exp_res_reg[17]}}, exp_res_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:324:30  */
  assign n2296 = $signed(n2294) < $signed(32'b00000000000000000111111111111111);
  /* mc68881_fp80_addsub_unit.vhd:325:44  */
  assign n2297 = {{14{exp_res_reg[17]}}, exp_res_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:325:44  */
  assign n2299 = n2297 + 32'b00000000000000000000000000000001;
  /* mc68881_fp80_addsub_unit.vhd:325:32  */
  assign n2300 = n2299[17:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:313:11  */
  assign n2301 = n2320 ? n2300 : exp_res_reg;
  /* mc68881_fp80_addsub_unit.vhd:319:13  */
  assign n2302 = n2296 & n1937;
  assign n2303 = {1'b0, n2293};
  /* mc68881_fp80_addsub_unit.vhd:319:13  */
  assign n2304 = n1937 ? n2303 : n1936;
  /* mc68881_fp80_addsub_unit.vhd:332:31  */
  assign n2307 = $unsigned(mant_a_ext_reg) >= $unsigned(mant_b_ext_reg);
  /* mc68881_fp80_addsub_unit.vhd:333:29  */
  assign n2309 = {1'b0, mant_a_ext_reg};
  /* mc68881_fp80_addsub_unit.vhd:333:54  */
  assign n2311 = {1'b0, mant_b_ext_reg};
  /* mc68881_fp80_addsub_unit.vhd:333:47  */
  assign n2312 = n2309 - n2311;
  /* mc68881_fp80_addsub_unit.vhd:336:29  */
  assign n2314 = {1'b0, mant_b_ext_reg};
  /* mc68881_fp80_addsub_unit.vhd:336:54  */
  assign n2316 = {1'b0, mant_a_ext_reg};
  /* mc68881_fp80_addsub_unit.vhd:336:47  */
  assign n2317 = n2314 - n2316;
  /* mc68881_fp80_addsub_unit.vhd:332:13  */
  assign n2318 = n2307 ? a_sign_reg : sign_b_reg;
  /* mc68881_fp80_addsub_unit.vhd:332:13  */
  assign n2319 = n2307 ? n2312 : n2317;
  /* mc68881_fp80_addsub_unit.vhd:313:11  */
  assign n2320 = n2302 & same_sign_reg;
  /* mc68881_fp80_addsub_unit.vhd:313:11  */
  assign n2321 = same_sign_reg ? n2304 : n2319;
  /* mc68881_fp80_addsub_unit.vhd:313:11  */
  assign n2322 = same_sign_reg ? a_sign_reg : n2318;
  /* mc68881_fp80_addsub_unit.vhd:313:11  */
  assign n2325 = same_sign_reg ? 1'b0 : 1'b1;
  /* mc68881_fp80_addsub_unit.vhd:309:9  */
  assign n2330 = state_reg == 3'b011;
  /* mc68881_fp80_addsub_unit.vhd:350:38  */
  assign n2331 = mant_sum_reg[66:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:351:13  */
  assign n2332 = {{14{exp_res_reg[17]}}, exp_res_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:353:26  */
  assign n2334 = n2331 == 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:356:28  */
  assign n2335 = mant_sum_reg[66]; // extract
  /* mc68881_fp80_addsub_unit.vhd:356:45  */
  assign n2336 = ~n2335;
  /* mc68881_fp80_addsub_unit.vhd:356:64  */
  assign n2338 = $signed(n2332) > $signed(32'b00000000000000000000000000000000);
  /* mc68881_fp80_addsub_unit.vhd:356:51  */
  assign n2339 = n2338 & n2336;
  /* mc68881_pkg.vhd:2497:11  */
  assign n2346 = mant_sum_reg[66:3]; // extract
  /* mc68881_pkg.vhd:2497:39  */
  assign n2348 = n2346 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2499:15  */
  assign n2349 = mant_sum_reg[2:0]; // extract
  /* mc68881_pkg.vhd:2499:38  */
  assign n2351 = {n2349, 64'b0000000000000000000000000000000000000000000000000000000000000000};
  /* mc68881_pkg.vhd:2497:7  */
  assign n2354 = n2348 ? 31'b0000000000000000000000001000000 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:2497:7  */
  assign n2356 = n2348 ? n2351 : n2331;
  /* mc68881_pkg.vhd:2502:9  */
  assign n2357 = n2356[66:35]; // extract
  /* mc68881_pkg.vhd:2502:37  */
  assign n2359 = n2357 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2503:18  */
  assign n2360 = {1'b0, n2354};  //  uext
  /* mc68881_pkg.vhd:2503:18  */
  assign n2362 = n2360 + 32'b00000000000000000000000000100000;
  /* mc68881_pkg.vhd:2503:7  */
  assign n2363 = n2362[30:0];  // trunc
  /* mc68881_pkg.vhd:2504:13  */
  assign n2364 = n2356[34:0]; // extract
  /* mc68881_pkg.vhd:2504:36  */
  assign n2366 = {n2364, 32'b00000000000000000000000000000000};
  /* mc68881_pkg.vhd:2502:5  */
  assign n2367 = n2359 ? n2363 : n2354;
  /* mc68881_pkg.vhd:2502:5  */
  assign n2368 = n2359 ? n2366 : n2356;
  /* mc68881_pkg.vhd:2506:9  */
  assign n2369 = n2368[66:51]; // extract
  /* mc68881_pkg.vhd:2506:37  */
  assign n2371 = n2369 == 16'b0000000000000000;
  /* mc68881_pkg.vhd:2507:18  */
  assign n2372 = {1'b0, n2367};  //  uext
  /* mc68881_pkg.vhd:2507:18  */
  assign n2374 = n2372 + 32'b00000000000000000000000000010000;
  /* mc68881_pkg.vhd:2507:7  */
  assign n2375 = n2374[30:0];  // trunc
  /* mc68881_pkg.vhd:2508:13  */
  assign n2376 = n2368[50:0]; // extract
  /* mc68881_pkg.vhd:2508:36  */
  assign n2378 = {n2376, 16'b0000000000000000};
  /* mc68881_pkg.vhd:2506:5  */
  assign n2379 = n2371 ? n2375 : n2367;
  /* mc68881_pkg.vhd:2506:5  */
  assign n2380 = n2371 ? n2378 : n2368;
  /* mc68881_pkg.vhd:2510:9  */
  assign n2381 = n2380[66:59]; // extract
  /* mc68881_pkg.vhd:2510:36  */
  assign n2383 = n2381 == 8'b00000000;
  /* mc68881_pkg.vhd:2511:18  */
  assign n2384 = {1'b0, n2379};  //  uext
  /* mc68881_pkg.vhd:2511:18  */
  assign n2386 = n2384 + 32'b00000000000000000000000000001000;
  /* mc68881_pkg.vhd:2511:7  */
  assign n2387 = n2386[30:0];  // trunc
  /* mc68881_pkg.vhd:2512:13  */
  assign n2388 = n2380[58:0]; // extract
  /* mc68881_pkg.vhd:2512:35  */
  assign n2390 = {n2388, 8'b00000000};
  /* mc68881_pkg.vhd:2510:5  */
  assign n2391 = n2383 ? n2387 : n2379;
  /* mc68881_pkg.vhd:2510:5  */
  assign n2392 = n2383 ? n2390 : n2380;
  /* mc68881_pkg.vhd:2514:9  */
  assign n2393 = n2392[66:63]; // extract
  /* mc68881_pkg.vhd:2514:36  */
  assign n2395 = n2393 == 4'b0000;
  /* mc68881_pkg.vhd:2515:18  */
  assign n2396 = {1'b0, n2391};  //  uext
  /* mc68881_pkg.vhd:2515:18  */
  assign n2398 = n2396 + 32'b00000000000000000000000000000100;
  /* mc68881_pkg.vhd:2515:7  */
  assign n2399 = n2398[30:0];  // trunc
  /* mc68881_pkg.vhd:2516:13  */
  assign n2400 = n2392[62:0]; // extract
  /* mc68881_pkg.vhd:2516:35  */
  assign n2402 = {n2400, 4'b0000};
  /* mc68881_pkg.vhd:2514:5  */
  assign n2403 = n2395 ? n2399 : n2391;
  /* mc68881_pkg.vhd:2514:5  */
  assign n2404 = n2395 ? n2402 : n2392;
  /* mc68881_pkg.vhd:2518:9  */
  assign n2405 = n2404[66:65]; // extract
  /* mc68881_pkg.vhd:2518:36  */
  assign n2407 = n2405 == 2'b00;
  /* mc68881_pkg.vhd:2519:18  */
  assign n2408 = {1'b0, n2403};  //  uext
  /* mc68881_pkg.vhd:2519:18  */
  assign n2410 = n2408 + 32'b00000000000000000000000000000010;
  /* mc68881_pkg.vhd:2519:7  */
  assign n2411 = n2410[30:0];  // trunc
  /* mc68881_pkg.vhd:2520:13  */
  assign n2412 = n2404[64:0]; // extract
  /* mc68881_pkg.vhd:2520:35  */
  assign n2414 = {n2412, 2'b00};
  /* mc68881_pkg.vhd:2518:5  */
  assign n2415 = n2407 ? n2411 : n2403;
  /* mc68881_pkg.vhd:2518:5  */
  assign n2416 = n2407 ? n2414 : n2404;
  /* mc68881_pkg.vhd:2522:9  */
  assign n2417 = n2416[66]; // extract
  /* mc68881_pkg.vhd:2522:18  */
  assign n2418 = ~n2417;
  /* mc68881_pkg.vhd:2523:18  */
  assign n2419 = {1'b0, n2415};  //  uext
  /* mc68881_pkg.vhd:2523:18  */
  assign n2421 = n2419 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:2523:7  */
  assign n2422 = n2421[30:0];  // trunc
  /* mc68881_pkg.vhd:2522:5  */
  assign n2423 = n2418 ? n2422 : n2415;
  /* mc68881_fp80_addsub_unit.vhd:360:22  */
  assign n2424 = {1'b0, n2423};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:360:22  */
  assign n2425 = $signed(n2424) > $signed(n2332);
  /* mc68881_fp80_addsub_unit.vhd:361:17  */
  assign n2426 = {{13{exp_res_reg[17]}}, exp_res_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:360:15  */
  assign n2427 = n2425 ? n2426 : n2423;
  /* mc68881_fp80_addsub_unit.vhd:365:28  */
  assign n2428 = n2331 << n2427;
  /* mc68881_fp80_addsub_unit.vhd:366:37  */
  assign n2429 = {1'b0, n2427};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:366:37  */
  assign n2430 = n2332 - n2429;
  /* mc68881_fp80_addsub_unit.vhd:356:13  */
  assign n2433 = n2339 ? n2428 : n2331;
  /* mc68881_fp80_addsub_unit.vhd:356:13  */
  assign n2434 = n2339 ? n2430 : n2332;
  /* mc68881_fp80_addsub_unit.vhd:353:13  */
  assign n2437 = n2334 ? n2331 : n2433;
  /* mc68881_fp80_addsub_unit.vhd:353:13  */
  assign n2438 = n2334 ? n2332 : n2434;
  /* mc68881_fp80_addsub_unit.vhd:371:28  */
  assign n2440 = n2438[17:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:349:11  */
  assign n2441 = need_normalize_reg ? n2440 : exp_res_reg;
  assign n2442 = {1'b0, n2437};
  /* mc68881_fp80_addsub_unit.vhd:349:11  */
  assign n2443 = need_normalize_reg ? n2442 : mant_sum_reg;
  /* mc68881_fp80_addsub_unit.vhd:347:9  */
  assign n2449 = state_reg == 3'b100;
  /* mc68881_fp80_addsub_unit.vhd:379:11  */
  assign n2451 = {{14{exp_res_reg[17]}}, exp_res_reg}; // sext
  /* mc68881_fp80_addsub_unit.vhd:382:32  */
  assign n2452 = mant_sum_reg[66:3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:388:32  */
  assign n2453 = mant_sum_reg[42]; // extract
  /* mc68881_fp80_addsub_unit.vhd:388:59  */
  assign n2454 = mant_sum_reg[41]; // extract
  /* mc68881_fp80_addsub_unit.vhd:389:26  */
  assign n2455 = mant_sum_reg[40:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:389:40  */
  assign n2457 = n2455 != 41'b00000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:389:15  */
  assign n2460 = n2457 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:387:13  */
  assign n2462 = rp_reg == 2'b01;
  /* mc68881_fp80_addsub_unit.vhd:391:32  */
  assign n2463 = mant_sum_reg[13]; // extract
  /* mc68881_fp80_addsub_unit.vhd:391:59  */
  assign n2464 = mant_sum_reg[12]; // extract
  /* mc68881_fp80_addsub_unit.vhd:392:26  */
  assign n2465 = mant_sum_reg[11:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:392:40  */
  assign n2467 = n2465 != 12'b000000000000;
  /* mc68881_fp80_addsub_unit.vhd:392:15  */
  assign n2470 = n2467 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:390:13  */
  assign n2472 = rp_reg == 2'b10;
  /* mc68881_fp80_addsub_unit.vhd:394:32  */
  assign n2473 = mant_sum_reg[2]; // extract
  /* mc68881_fp80_addsub_unit.vhd:394:58  */
  assign n2474 = mant_sum_reg[1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:395:26  */
  assign n2475 = mant_sum_reg[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:395:15  */
  assign n2478 = n2475 ? 1'b1 : 1'b0;
  assign n2479 = {n2472, n2462};
  /* mc68881_fp80_addsub_unit.vhd:386:11  */
  always @*
    case (n2479)
      2'b10: n2480 = n2463;
      2'b01: n2480 = n2453;
      default: n2480 = n2473;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:386:11  */
  always @*
    case (n2479)
      2'b10: n2481 = n2464;
      2'b01: n2481 = n2454;
      default: n2481 = n2474;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:386:11  */
  always @*
    case (n2479)
      2'b10: n2482 = n2470;
      2'b01: n2482 = n2460;
      default: n2482 = n2478;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:398:30  */
  assign n2484 = n2480 | n2481;
  /* mc68881_fp80_addsub_unit.vhd:398:43  */
  assign n2485 = n2484 | n2482;
  /* mc68881_fp80_addsub_unit.vhd:404:55  */
  assign n2486 = n2481 | n2482;
  /* mc68881_fp80_addsub_unit.vhd:404:83  */
  assign n2487 = mant_sum_reg[43]; // extract
  /* mc68881_fp80_addsub_unit.vhd:404:71  */
  assign n2488 = n2486 | n2487;
  /* mc68881_fp80_addsub_unit.vhd:404:34  */
  assign n2489 = n2488 & n2480;
  /* mc68881_fp80_addsub_unit.vhd:404:19  */
  assign n2492 = n2489 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:403:17  */
  assign n2494 = rp_reg == 2'b01;
  /* mc68881_fp80_addsub_unit.vhd:406:55  */
  assign n2495 = n2481 | n2482;
  /* mc68881_fp80_addsub_unit.vhd:406:83  */
  assign n2496 = mant_sum_reg[14]; // extract
  /* mc68881_fp80_addsub_unit.vhd:406:71  */
  assign n2497 = n2495 | n2496;
  /* mc68881_fp80_addsub_unit.vhd:406:34  */
  assign n2498 = n2497 & n2480;
  /* mc68881_fp80_addsub_unit.vhd:406:19  */
  assign n2501 = n2498 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:405:17  */
  assign n2503 = rp_reg == 2'b10;
  /* mc68881_fp80_addsub_unit.vhd:408:55  */
  assign n2504 = n2481 | n2482;
  /* mc68881_fp80_addsub_unit.vhd:408:83  */
  assign n2505 = mant_sum_reg[3]; // extract
  /* mc68881_fp80_addsub_unit.vhd:408:71  */
  assign n2506 = n2504 | n2505;
  /* mc68881_fp80_addsub_unit.vhd:408:34  */
  assign n2507 = n2506 & n2480;
  /* mc68881_fp80_addsub_unit.vhd:408:19  */
  assign n2510 = n2507 ? 1'b1 : 1'b0;
  assign n2511 = {n2503, n2494};
  /* mc68881_fp80_addsub_unit.vhd:402:15  */
  always @*
    case (n2511)
      2'b10: n2512 = n2501;
      2'b01: n2512 = n2492;
      default: n2512 = n2510;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:401:13  */
  assign n2514 = rm_reg == 2'b00;
  /* mc68881_fp80_addsub_unit.vhd:410:13  */
  assign n2516 = rm_reg == 2'b01;
  /* mc68881_fp80_addsub_unit.vhd:413:37  */
  assign n2517 = n2485 & res_sign_reg;
  /* mc68881_fp80_addsub_unit.vhd:413:15  */
  assign n2520 = n2517 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:412:13  */
  assign n2522 = rm_reg == 2'b10;
  /* mc68881_fp80_addsub_unit.vhd:415:31  */
  assign n2523 = ~res_sign_reg;
  /* mc68881_fp80_addsub_unit.vhd:415:37  */
  assign n2524 = n2485 & n2523;
  /* mc68881_fp80_addsub_unit.vhd:415:15  */
  assign n2527 = n2524 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:414:13  */
  assign n2529 = rm_reg == 2'b11;
  assign n2530 = {n2529, n2522, n2516, n2514};
  /* mc68881_fp80_addsub_unit.vhd:400:11  */
  always @*
    case (n2530)
      4'b1000: n2533 = n2527;
      4'b0100: n2533 = n2520;
      4'b0010: n2533 = 1'b0;
      4'b0001: n2533 = n2512;
      default: n2533 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:420:57  */
  assign n2536 = {1'b0, n2452};
  /* mc68881_fp80_addsub_unit.vhd:420:70  */
  assign n2538 = n2536 + 65'b00000000000000000000000010000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:420:15  */
  assign n2540 = rp_reg == 2'b01;
  /* mc68881_fp80_addsub_unit.vhd:421:57  */
  assign n2542 = {1'b0, n2452};
  /* mc68881_fp80_addsub_unit.vhd:421:70  */
  assign n2544 = n2542 + 65'b00000000000000000000000000000000000000000000000000000100000000000;
  /* mc68881_fp80_addsub_unit.vhd:421:15  */
  assign n2546 = rp_reg == 2'b10;
  /* mc68881_fp80_addsub_unit.vhd:422:49  */
  assign n2548 = {1'b0, n2452};
  /* mc68881_fp80_addsub_unit.vhd:422:62  */
  assign n2550 = n2548 + 65'b00000000000000000000000000000000000000000000000000000000000000001;
  assign n2551 = {n2546, n2540};
  /* mc68881_fp80_addsub_unit.vhd:419:13  */
  always @*
    case (n2551)
      2'b10: n2552 = n2544;
      2'b01: n2552 = n2538;
      default: n2552 = n2550;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:424:26  */
  assign n2553 = n2552[64]; // extract
  /* mc68881_fp80_addsub_unit.vhd:426:50  */
  assign n2554 = n2552[63:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:426:28  */
  assign n2556 = n2554 >> 31'b0000000000000000000000000000001;
  /* mc68881_fp80_addsub_unit.vhd:427:28  */
  assign n2557 = n2552[0]; // extract
  assign n2559 = n2556[0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:427:15  */
  assign n2560 = n2557 ? 1'b1 : n2559;
  assign n2563 = n2556[62:1]; // extract
  /* mc68881_fp80_addsub_unit.vhd:431:34  */
  assign n2565 = n2451 + 32'b00000000000000000000000000000001;
  /* mc68881_fp80_addsub_unit.vhd:433:38  */
  assign n2566 = n2552[63:0]; // extract
  assign n2567 = {1'b1, n2563, n2560};
  /* mc68881_fp80_addsub_unit.vhd:424:13  */
  assign n2568 = n2553 ? n2567 : n2566;
  /* mc68881_fp80_addsub_unit.vhd:418:11  */
  assign n2569 = n2572 ? n2565 : n2451;
  /* mc68881_fp80_addsub_unit.vhd:418:11  */
  assign n2570 = n2533 ? n2568 : n2452;
  /* mc68881_fp80_addsub_unit.vhd:418:11  */
  assign n2572 = n2553 & n2533;
  /* mc68881_fp80_addsub_unit.vhd:438:13  */
  assign n2575 = rp_reg == 2'b01;
  /* mc68881_fp80_addsub_unit.vhd:439:13  */
  assign n2578 = rp_reg == 2'b10;
  assign n2579 = {n2578, n2575};
  assign n2580 = n2573[10:0]; // extract
  assign n2581 = n2570[10:0]; // extract
  /* mc68881_fp80_addsub_unit.vhd:437:11  */
  always @*
    case (n2579)
      2'b10: n2582 = 11'b00000000000;
      2'b01: n2582 = n2580;
      default: n2582 = n2581;
    endcase
  assign n2583 = n2573[39:11]; // extract
  assign n2584 = n2570[39:11]; // extract
  /* mc68881_fp80_addsub_unit.vhd:437:11  */
  always @*
    case (n2579)
      2'b10: n2585 = n2584;
      2'b01: n2585 = n2583;
      default: n2585 = n2584;
    endcase
  assign n2587 = n2570[63:40]; // extract
  assign n2588 = {n2587, n2585, n2582};
  /* mc68881_fp80_addsub_unit.vhd:444:24  */
  assign n2590 = n2588 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:447:25  */
  assign n2592 = $signed(n2569) >= $signed(32'b00000000000000000111111111111111);
  /* mc68881_fp80_addsub_unit.vhd:452:25  */
  assign n2596 = $signed(n2569) <= $signed(32'b00000000000000000000000000000000);
  /* mc68881_fp80_addsub_unit.vhd:453:31  */
  assign n2598 = 32'b00000000000000000000000000000001 - n2569;
  /* mc68881_fp80_addsub_unit.vhd:453:13  */
  assign n2599 = n2598[30:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:454:29  */
  assign n2600 = {1'b0, n2599};  //  uext
  /* mc68881_fp80_addsub_unit.vhd:454:29  */
  assign n2602 = $signed(n2600) >= $signed(32'b00000000000000000000000001000000);
  assign n2603 = {n2587, n2585, n2582};
  /* mc68881_fp80_addsub_unit.vhd:454:59  */
  assign n2605 = n2603 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:454:46  */
  assign n2606 = n2602 | n2605;
  assign n2608 = {n2587, n2585, n2582};
  /* mc68881_fp80_addsub_unit.vhd:459:72  */
  assign n2609 = n2608 >> n2599;
  assign n2610 = {res_sign_reg, 15'b000000000000000, n2609};
  /* mc68881_fp80_addsub_unit.vhd:454:13  */
  assign n2612 = n2606 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2610;
  /* mc68881_fp80_addsub_unit.vhd:463:36  */
  assign n2613 = n2569[30:0];  // trunc
  /* mc68881_fp80_addsub_unit.vhd:463:24  */
  assign n2614 = n2613[14:0];  // trunc
  assign n2615 = {n2587, n2585, n2582};
  assign n2616 = {res_sign_reg, n2614, n2615};
  /* mc68881_fp80_addsub_unit.vhd:452:11  */
  assign n2617 = n2596 ? n2612 : n2616;
  assign n2620 = {res_sign_reg, 15'b111111111111111, 64'b0000000000000000000000000000000000000000000000000000000000000000};
  /* mc68881_fp80_addsub_unit.vhd:447:11  */
  assign n2621 = n2592 ? n2620 : n2617;
  /* mc68881_fp80_addsub_unit.vhd:444:11  */
  assign n2625 = n2590 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2621;
  /* mc68881_fp80_addsub_unit.vhd:376:9  */
  assign n2629 = state_reg == 3'b101;
  assign n2630 = {n2629, n2449, n2330, n1931, n784, n60};
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2636 = 3'b000;
      6'b010000: n2636 = 3'b101;
      6'b001000: n2636 = 3'b100;
      6'b000100: n2636 = n1917;
      6'b000010: n2636 = 3'b010;
      6'b000001: n2636 = n53;
      default: n2636 = 3'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2638 = a_reg;
      6'b010000: n2638 = a_reg;
      6'b001000: n2638 = a_reg;
      6'b000100: n2638 = a_reg;
      6'b000010: n2638 = a_reg;
      6'b000001: n2638 = n54;
      default: n2638 = 80'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2640 = b_reg;
      6'b010000: n2640 = b_reg;
      6'b001000: n2640 = b_reg;
      6'b000100: n2640 = b_reg;
      6'b000010: n2640 = b_reg;
      6'b000001: n2640 = n55;
      default: n2640 = 80'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2642 = sub_reg;
      6'b010000: n2642 = sub_reg;
      6'b001000: n2642 = sub_reg;
      6'b000100: n2642 = sub_reg;
      6'b000010: n2642 = sub_reg;
      6'b000001: n2642 = n56;
      default: n2642 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2644 = rm_reg;
      6'b010000: n2644 = rm_reg;
      6'b001000: n2644 = rm_reg;
      6'b000100: n2644 = rm_reg;
      6'b000010: n2644 = rm_reg;
      6'b000001: n2644 = n57;
      default: n2644 = 2'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2646 = rp_reg;
      6'b010000: n2646 = rp_reg;
      6'b001000: n2646 = rp_reg;
      6'b000100: n2646 = rp_reg;
      6'b000010: n2646 = rp_reg;
      6'b000001: n2646 = n58;
      default: n2646 = 2'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2648 = a_sign_reg;
      6'b010000: n2648 = a_sign_reg;
      6'b001000: n2648 = a_sign_reg;
      6'b000100: n2648 = a_sign_reg;
      6'b000010: n2648 = n61;
      6'b000001: n2648 = a_sign_reg;
      default: n2648 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2650 = a_exp_reg;
      6'b010000: n2650 = a_exp_reg;
      6'b001000: n2650 = a_exp_reg;
      6'b000100: n2650 = a_exp_reg;
      6'b000010: n2650 = n149;
      6'b000001: n2650 = a_exp_reg;
      default: n2650 = 18'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2652 = b_exp_reg;
      6'b010000: n2652 = b_exp_reg;
      6'b001000: n2652 = b_exp_reg;
      6'b000100: n2652 = b_exp_reg;
      6'b000010: n2652 = n239;
      6'b000001: n2652 = b_exp_reg;
      default: n2652 = 18'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2654 = sign_b_reg;
      6'b010000: n2654 = sign_b_reg;
      6'b001000: n2654 = sign_b_reg;
      6'b000100: n2654 = sign_b_reg;
      6'b000010: n2654 = n245;
      6'b000001: n2654 = sign_b_reg;
      default: n2654 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2656 = mant_a_ext_reg;
      6'b010000: n2656 = mant_a_ext_reg;
      6'b001000: n2656 = mant_a_ext_reg;
      6'b000100: n2656 = n1918;
      6'b000010: n2656 = n247;
      6'b000001: n2656 = mant_a_ext_reg;
      default: n2656 = 67'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2658 = mant_b_ext_reg;
      6'b010000: n2658 = mant_b_ext_reg;
      6'b001000: n2658 = mant_b_ext_reg;
      6'b000100: n2658 = n1919;
      6'b000010: n2658 = n249;
      6'b000001: n2658 = mant_b_ext_reg;
      default: n2658 = 67'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2660 = exp_res_reg;
      6'b010000: n2660 = n2441;
      6'b001000: n2660 = n2301;
      6'b000100: n2660 = n1920;
      6'b000010: n2660 = exp_res_reg;
      6'b000001: n2660 = exp_res_reg;
      default: n2660 = 18'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2662 = early_exit_reg;
      6'b010000: n2662 = early_exit_reg;
      6'b001000: n2662 = early_exit_reg;
      6'b000100: n2662 = early_exit_reg;
      6'b000010: n2662 = n780;
      6'b000001: n2662 = early_exit_reg;
      default: n2662 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2664 = early_result_reg;
      6'b010000: n2664 = early_result_reg;
      6'b001000: n2664 = early_result_reg;
      6'b000100: n2664 = early_result_reg;
      6'b000010: n2664 = n782;
      6'b000001: n2664 = early_result_reg;
      default: n2664 = 80'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2666 = mant_sum_reg;
      6'b010000: n2666 = n2443;
      6'b001000: n2666 = n2321;
      6'b000100: n2666 = mant_sum_reg;
      6'b000010: n2666 = mant_sum_reg;
      6'b000001: n2666 = mant_sum_reg;
      default: n2666 = 68'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2668 = res_sign_reg;
      6'b010000: n2668 = res_sign_reg;
      6'b001000: n2668 = n2322;
      6'b000100: n2668 = res_sign_reg;
      6'b000010: n2668 = res_sign_reg;
      6'b000001: n2668 = res_sign_reg;
      default: n2668 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2670 = same_sign_reg;
      6'b010000: n2670 = same_sign_reg;
      6'b001000: n2670 = same_sign_reg;
      6'b000100: n2670 = n1921;
      6'b000010: n2670 = same_sign_reg;
      6'b000001: n2670 = same_sign_reg;
      default: n2670 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2672 = need_normalize_reg;
      6'b010000: n2672 = need_normalize_reg;
      6'b001000: n2672 = n2325;
      6'b000100: n2672 = need_normalize_reg;
      6'b000010: n2672 = need_normalize_reg;
      6'b000001: n2672 = need_normalize_reg;
      default: n2672 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2676 = 1'b1;
      6'b010000: n2676 = 1'b0;
      6'b001000: n2676 = 1'b0;
      6'b000100: n2676 = n1924;
      6'b000010: n2676 = 1'b0;
      6'b000001: n2676 = 1'b0;
      default: n2676 = 1'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:177:7  */
  always @*
    case (n2630)
      6'b100000: n2679 = n2625;
      6'b010000: n2679 = result_reg;
      6'b001000: n2679 = result_reg;
      6'b000100: n2679 = n1925;
      6'b000010: n2679 = result_reg;
      6'b000001: n2679 = result_reg;
      default: n2679 = 80'bX;
    endcase
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2736 = n51 ? 3'b000 : n2636;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2738 = n51 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2638;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2740 = n51 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2640;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2742 = n51 ? 1'b0 : n2642;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2744 = n51 ? 2'b00 : n2644;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2746 = n51 ? 2'b00 : n2646;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2748 = n51 ? 1'b0 : n2648;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2750 = n51 ? 18'b000000000000000000 : n2650;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2752 = n51 ? 18'b000000000000000000 : n2652;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2754 = n51 ? 1'b0 : n2654;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2756 = n51 ? 67'b0000000000000000000000000000000000000000000000000000000000000000000 : n2656;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2758 = n51 ? 67'b0000000000000000000000000000000000000000000000000000000000000000000 : n2658;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2760 = n51 ? 18'b000000000000000000 : n2660;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2762 = n51 ? 1'b0 : n2662;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2764 = n51 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2664;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2766 = n51 ? 68'b00000000000000000000000000000000000000000000000000000000000000000000 : n2666;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2768 = n51 ? 1'b0 : n2668;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2770 = n51 ? 1'b0 : n2670;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2772 = n51 ? 1'b0 : n2672;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2774 = n51 ? 1'b0 : n2676;
  /* mc68881_fp80_addsub_unit.vhd:152:5  */
  assign n2776 = n51 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2679;
  /* mc68881_fp80_addsub_unit.vhd:476:32  */
  assign n2874 = state_reg != 3'b000;
  /* mc68881_fp80_addsub_unit.vhd:476:17  */
  assign n2875 = n2874 ? 1'b1 : 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2877 <= n2736;
  initial
    n2877 = 3'b000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2878 <= n2738;
  initial
    n2878 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2879 <= n2740;
  initial
    n2879 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2880 <= n2742;
  initial
    n2880 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2881 <= n2744;
  initial
    n2881 = 2'b00;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2882 <= n2746;
  initial
    n2882 = 2'b00;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2883 <= n2748;
  initial
    n2883 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2884 <= n2750;
  initial
    n2884 = 18'b000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2885 <= n2752;
  initial
    n2885 = 18'b000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2886 <= n2754;
  initial
    n2886 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2887 <= n2756;
  initial
    n2887 = 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2888 <= n2758;
  initial
    n2888 = 67'b0000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2889 <= n2760;
  initial
    n2889 = 18'b000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2890 <= n2762;
  initial
    n2890 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2891 <= n2764;
  initial
    n2891 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2892 <= n2766;
  initial
    n2892 = 68'b00000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2893 <= n2768;
  initial
    n2893 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2894 <= n2770;
  initial
    n2894 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2895 <= n2772;
  initial
    n2895 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2896 <= n2774;
  initial
    n2896 = 1'b0;
  /* mc68881_fp80_addsub_unit.vhd:151:5  */
  always @(posedge clk)
    n2897 <= n2776;
  initial
    n2897 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  assign n2899 = {61'bX, n1324};
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n2900 = n2899[n1322 * 1 +: 1]; //(Bmux)
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n2902 = {61'bX, n1884};
  /* mc68881_fp80_addsub_unit.vhd:108:31  */
  assign n2903 = n2902[n1882 * 1 +: 1]; //(Bmux)
endmodule

