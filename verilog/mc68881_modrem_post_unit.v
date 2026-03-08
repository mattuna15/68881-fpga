module mc68881_modrem_post_unit
  (input  clk,
   input  reset_n,
   input  start,
   input  [5:0] op_sel,
   input  [79:0] a_in,
   input  [79:0] b_in,
   input  [79:0] quotient_in,
   input  [1:0] round_mode,
   input  [1:0] round_prec,
   input  fp_mul_done,
   input  [79:0] fp_mul_result,
   input  fp_add_done,
   input  [79:0] fp_add_result,
   input  save_req,
   input  [1:0] save_addr,
   input  restore_req,
   input  [31:0] restore_data,
   input  [1:0] restore_addr,
   input  restore_wr,
   output busy,
   output done,
   output [79:0] result,
   output [7:0] quotient_byte,
   output quotient_valid,
   output fp_mul_start,
   output [79:0] fp_mul_a_out,
   output [79:0] fp_mul_b_out,
   output fp_add_start,
   output [79:0] fp_add_a_out,
   output [79:0] fp_add_b_out,
   output fp_add_sub_out,
   output [1:0] fp_add_rm_out,
   output [1:0] fp_add_rp_out,
   output [31:0] save_data);
  reg [3:0] state_reg;
  reg [5:0] op_reg;
  reg [79:0] a_reg;
  reg [79:0] b_reg;
  reg [79:0] quotient_reg;
  reg [1:0] rm_reg;
  reg [1:0] rp_reg;
  reg [79:0] n_fp_reg;
  reg [79:0] result_reg;
  reg [7:0] quotient_byte_reg;
  reg quotient_valid_reg;
  reg done_reg;
  reg [79:0] mod_fp_add_a;
  reg [79:0] mod_fp_add_b;
  reg mod_fp_add_is_sub;
  reg [1:0] mod_fp_add_rm;
  reg [1:0] mod_fp_add_rp;
  reg [79:0] mod_fp_mul_a;
  reg [79:0] mod_fp_mul_b;
  reg [79:0] mod_add_result_reg;
  reg [79:0] mod_mul_result_reg;
  reg [3:0] mod_fp_cont_state_reg;
  reg fp_hold_loaded_reg;
  reg modpost_mul_start_reg;
  reg modpost_add_start_reg;
  reg [31:0] shadow_state;
  reg [31:0] shadow_word1;
  reg [31:0] shadow_word2;
  reg [31:0] shadow_word3;
  wire n51;
  wire [3:0] n54;
  wire [5:0] n55;
  wire [79:0] n56;
  wire [79:0] n57;
  wire [79:0] n58;
  wire [1:0] n59;
  wire [1:0] n60;
  wire [7:0] n62;
  wire n64;
  wire n66;
  wire n78;
  wire [14:0] n81;
  wire [63:0] n83;
  wire [79:0] n84;
  wire [14:0] n87;
  wire n89;
  wire [14:0] n90;
  wire n92;
  wire n93;
  wire n96;
  wire n100;
  wire [79:0] n102;
  wire [14:0] n103;
  wire [30:0] n104;
  wire [31:0] n105;
  wire [31:0] n107;
  wire [31:0] n109;
  wire n112;
  wire [14:0] n114;
  wire [14:0] n115;
  wire [63:0] n117;
  wire [63:0] n118;
  wire n119;
  wire [79:0] n120;
  wire n121;
  wire n122;
  wire n123;
  wire n124;
  wire [79:0] n125;
  wire [14:0] n126;
  wire [14:0] n127;
  wire [14:0] n128;
  wire n129;
  wire [79:0] n130;
  wire [63:0] n131;
  wire [63:0] n132;
  wire [63:0] n133;
  wire [79:0] n134;
  wire n136;
  wire n138;
  wire [79:0] n139;
  wire n140;
  wire n141;
  wire n142;
  wire [78:0] n143;
  wire [78:0] n144;
  wire [78:0] n145;
  wire [79:0] n146;
  wire [79:0] n147;
  wire n148;
  wire n149;
  wire n150;
  wire n152;
  wire n153;
  wire n154;
  wire n156;
  wire n158;
  wire n160;
  wire [79:0] n161;
  wire n162;
  wire n163;
  wire n164;
  wire n165;
  wire n166;
  wire n167;
  wire [31:0] n169;
  wire [31:0] n171;
  wire n174;
  wire n176;
  wire n177;
  wire n179;
  wire n181;
  wire n183;
  wire n185;
  wire n186;
  wire n188;
  wire n190;
  wire n192;
  wire n194;
  wire n195;
  wire n197;
  wire n199;
  wire n201;
  wire n203;
  wire n204;
  wire n206;
  wire n208;
  wire n210;
  wire n212;
  wire n213;
  wire n215;
  wire n217;
  wire n219;
  wire n221;
  wire n222;
  wire n224;
  wire n226;
  wire n228;
  wire n230;
  wire n231;
  wire n233;
  wire n235;
  wire n237;
  wire n239;
  wire n240;
  wire n242;
  wire n244;
  wire n246;
  wire n248;
  wire n249;
  wire n251;
  wire n253;
  wire n255;
  wire n257;
  wire n258;
  wire n260;
  wire n262;
  wire n264;
  wire n266;
  wire n267;
  wire n269;
  wire n271;
  wire n273;
  wire n275;
  wire n276;
  wire n278;
  wire n280;
  wire n282;
  wire n284;
  wire n285;
  wire n287;
  wire n289;
  wire n291;
  wire n293;
  wire n294;
  wire n296;
  wire n298;
  wire n300;
  wire n302;
  wire n303;
  wire n305;
  wire n307;
  wire n309;
  wire n311;
  wire n312;
  wire n314;
  wire n316;
  wire n318;
  wire n320;
  wire n321;
  wire n323;
  wire n325;
  wire n327;
  wire n329;
  wire n330;
  wire n332;
  wire n334;
  wire n336;
  wire n338;
  wire n339;
  wire n341;
  wire n343;
  wire n345;
  wire n347;
  wire n348;
  wire n350;
  wire n352;
  wire n354;
  wire n356;
  wire n357;
  wire n359;
  wire n361;
  wire n363;
  wire n365;
  wire n366;
  wire n368;
  wire n370;
  wire n372;
  wire n374;
  wire n375;
  wire n377;
  wire n379;
  wire n381;
  wire n383;
  wire n384;
  wire n386;
  wire n388;
  wire n390;
  wire n392;
  wire n393;
  wire n395;
  wire n397;
  wire n399;
  wire n401;
  wire n402;
  wire n404;
  wire n406;
  wire n408;
  wire n410;
  wire n411;
  wire n413;
  wire n415;
  wire n417;
  wire n419;
  wire n420;
  wire n422;
  wire n424;
  wire n426;
  wire n428;
  wire n429;
  wire n431;
  wire n433;
  wire n435;
  wire n437;
  wire n438;
  wire n440;
  wire n442;
  wire n444;
  wire n446;
  wire n447;
  wire n449;
  wire n451;
  wire n453;
  wire n455;
  wire n456;
  wire n458;
  wire n460;
  wire n462;
  wire n464;
  wire n465;
  wire n467;
  wire n469;
  wire n471;
  wire n473;
  wire n474;
  wire n476;
  wire n478;
  wire n480;
  wire n482;
  wire n483;
  wire n485;
  wire n487;
  wire n489;
  wire n491;
  wire n492;
  wire n494;
  wire n496;
  wire n498;
  wire n500;
  wire n501;
  wire n503;
  wire n505;
  wire n507;
  wire n509;
  wire n510;
  wire n512;
  wire n514;
  wire n516;
  wire n518;
  wire n519;
  wire n521;
  wire n523;
  wire n525;
  wire n527;
  wire n528;
  wire n530;
  wire n532;
  wire n534;
  wire n536;
  wire n537;
  wire n539;
  wire n541;
  wire n543;
  wire n545;
  wire n546;
  wire n548;
  wire n550;
  wire n552;
  wire n554;
  wire n555;
  wire n557;
  wire n559;
  wire n561;
  wire n563;
  wire n564;
  wire n566;
  wire n568;
  wire n570;
  wire n572;
  wire n573;
  wire n575;
  wire n577;
  wire n579;
  wire n581;
  wire n582;
  wire n584;
  wire n586;
  wire n588;
  wire n590;
  wire n591;
  wire n593;
  wire n595;
  wire n597;
  wire n599;
  wire n600;
  wire n602;
  wire n604;
  wire n606;
  wire n608;
  wire n609;
  wire n611;
  wire n613;
  wire n615;
  wire n617;
  wire n618;
  wire n620;
  wire n622;
  wire n624;
  wire n626;
  wire n627;
  wire n629;
  wire n631;
  wire n633;
  wire n635;
  wire n636;
  wire n638;
  wire n640;
  wire n642;
  wire n644;
  wire n645;
  wire n647;
  wire n649;
  wire n651;
  wire n653;
  wire n654;
  wire n656;
  wire n658;
  wire n660;
  wire n662;
  wire n663;
  wire n665;
  wire n667;
  wire n669;
  wire n671;
  wire n672;
  wire n674;
  wire n676;
  wire n678;
  wire n680;
  wire n681;
  wire n683;
  wire n685;
  wire n687;
  wire n689;
  wire n690;
  wire n692;
  wire n694;
  wire n696;
  wire n698;
  wire n699;
  wire n701;
  wire n703;
  wire n705;
  wire n707;
  wire n708;
  wire n710;
  wire n712;
  wire n714;
  wire n716;
  wire n717;
  wire n719;
  wire n721;
  wire n723;
  wire n725;
  wire n726;
  wire n728;
  wire n730;
  wire n732;
  wire n734;
  wire n735;
  wire n737;
  wire n739;
  wire n741;
  wire n743;
  wire n744;
  wire n746;
  wire n748;
  wire n749;
  wire [63:0] n750;
  wire [63:0] n751;
  wire [63:0] n752;
  wire [14:0] n753;
  wire [79:0] n754;
  wire n755;
  wire n756;
  wire n757;
  wire [79:0] n759;
  wire [14:0] n760;
  wire [14:0] n761;
  wire [14:0] n762;
  wire [63:0] n763;
  wire [79:0] n764;
  wire [63:0] n765;
  wire [63:0] n766;
  wire [79:0] n767;
  wire [79:0] n772;
  wire n774;
  wire n786;
  wire [14:0] n789;
  wire [63:0] n791;
  wire [79:0] n792;
  wire [14:0] n798;
  wire n800;
  wire [14:0] n801;
  wire n803;
  wire n804;
  wire [63:0] n805;
  wire n807;
  wire n808;
  wire n812;
  wire [7:0] n818;
  wire n819;
  wire n821;
  wire [14:0] n823;
  wire [30:0] n824;
  wire [31:0] n825;
  wire [31:0] n827;
  wire [31:0] n829;
  wire n832;
  wire n835;
  wire [7:0] n838;
  wire n839;
  wire n841;
  wire n842;
  wire n844;
  wire n846;
  wire [31:0] n848;
  wire [31:0] n850;
  wire n852;
  wire [63:0] n853;
  wire [30:0] n854;
  wire [63:0] n855;
  wire [6:0] n856;
  wire [6:0] n858;
  wire [6:0] n860;
  wire [6:0] n862;
  wire [31:0] n864;
  wire [31:0] n866;
  wire [63:0] n867;
  wire [30:0] n868;
  wire [63:0] n869;
  wire [6:0] n870;
  wire [6:0] n872;
  wire [6:0] n874;
  wire [6:0] n879;
  wire n882;
  localparam [7:0] n883 = 8'b00000000;
  wire [6:0] n884;
  wire [6:0] n885;
  wire [7:0] n886;
  wire [7:0] n891;
  wire [3:0] n894;
  wire [7:0] n895;
  wire n897;
  wire [79:0] n898;
  wire [79:0] n899;
  wire n901;
  wire [1:0] n903;
  wire [1:0] n905;
  wire [79:0] n906;
  wire [79:0] n907;
  wire [3:0] n910;
  wire n912;
  wire n913;
  wire [3:0] n914;
  wire [79:0] n915;
  wire n917;
  wire [3:0] n918;
  wire [79:0] n919;
  wire n921;
  wire n924;
  wire n926;
  wire n927;
  wire [3:0] n928;
  wire [79:0] n929;
  wire n931;
  wire [3:0] n932;
  wire [79:0] n933;
  wire n935;
  wire n938;
  wire n940;
  wire [78:0] n947;
  wire [79:0] n948;
  wire [78:0] n961;
  wire [79:0] n962;
  wire n967;
  wire n969;
  wire n970;
  wire n974;
  wire [31:0] n978;
  wire n981;
  wire [31:0] n984;
  wire n986;
  wire [31:0] n991;
  wire n1003;
  wire [14:0] n1006;
  wire [63:0] n1008;
  wire [79:0] n1009;
  localparam [79:0] n1016 = 80'b00111111111111101000000000000000000000000000000000000000000000000000000000000000;
  wire n1017;
  localparam [79:0] n1020 = 80'b00111111111111101000000000000000000000000000000000000000000000000000000000000000;
  wire [14:0] n1021;
  localparam [79:0] n1023 = 80'b00111111111111101000000000000000000000000000000000000000000000000000000000000000;
  wire [63:0] n1024;
  wire [79:0] n1025;
  wire [14:0] n1026;
  wire [14:0] n1027;
  wire n1028;
  wire [14:0] n1030;
  wire [14:0] n1031;
  wire n1032;
  wire [63:0] n1034;
  wire [63:0] n1035;
  wire n1036;
  wire [63:0] n1038;
  wire [63:0] n1039;
  wire n1040;
  wire [31:0] n1043;
  wire [31:0] n1044;
  wire [31:0] n1045;
  wire [31:0] n1046;
  wire [31:0] n1048;
  wire n1050;
  wire [31:0] n1051;
  wire n1053;
  wire [31:0] n1056;
  wire n1057;
  wire n1059;
  wire n1060;
  wire n1062;
  wire [31:0] n1067;
  wire n1069;
  wire n1071;
  wire n1083;
  wire [14:0] n1086;
  wire [63:0] n1088;
  wire [79:0] n1089;
  wire [14:0] n1092;
  wire n1094;
  wire [14:0] n1095;
  wire n1097;
  wire n1098;
  wire n1102;
  wire n1108;
  wire [14:0] n1109;
  wire [30:0] n1110;
  wire [31:0] n1111;
  wire [31:0] n1113;
  wire [31:0] n1115;
  wire n1118;
  wire n1121;
  wire n1124;
  wire n1125;
  wire n1127;
  wire n1128;
  wire n1130;
  wire n1132;
  wire n1135;
  wire n1138;
  wire n1139;
  wire n1141;
  wire n1142;
  wire n1144;
  wire [31:0] n1146;
  wire [31:0] n1148;
  wire [5:0] n1150;
  wire n1157;
  wire n1158;
  wire n1159;
  wire n1160;
  wire n1172;
  wire [14:0] n1175;
  wire [63:0] n1177;
  wire [79:0] n1178;
  wire [14:0] n1184;
  wire n1186;
  wire [14:0] n1187;
  wire n1189;
  wire n1190;
  wire [63:0] n1191;
  wire n1193;
  wire n1194;
  wire n1198;
  wire [7:0] n1204;
  wire n1205;
  wire n1207;
  wire [14:0] n1209;
  wire [30:0] n1210;
  wire [31:0] n1211;
  wire [31:0] n1213;
  wire [31:0] n1215;
  wire n1218;
  wire n1221;
  wire [7:0] n1224;
  wire n1225;
  wire n1227;
  wire n1228;
  wire n1230;
  wire n1232;
  wire [31:0] n1234;
  wire [31:0] n1236;
  wire n1238;
  wire [63:0] n1239;
  wire [30:0] n1240;
  wire [63:0] n1241;
  wire [6:0] n1242;
  wire [6:0] n1244;
  wire [6:0] n1246;
  wire [6:0] n1248;
  wire [31:0] n1250;
  wire [31:0] n1252;
  wire [63:0] n1253;
  wire [30:0] n1254;
  wire [63:0] n1255;
  wire [6:0] n1256;
  wire [6:0] n1258;
  wire [6:0] n1260;
  wire [6:0] n1265;
  wire n1268;
  localparam [7:0] n1269 = 8'b00000000;
  wire [6:0] n1270;
  wire [6:0] n1271;
  wire [7:0] n1272;
  wire [7:0] n1277;
  wire [3:0] n1280;
  wire [7:0] n1281;
  wire n1283;
  wire [79:0] n1284;
  wire [79:0] n1286;
  wire n1287;
  wire [1:0] n1289;
  wire [1:0] n1291;
  wire [79:0] n1292;
  wire [79:0] n1293;
  wire [3:0] n1296;
  wire n1298;
  wire n1310;
  wire [14:0] n1313;
  wire [63:0] n1315;
  wire [79:0] n1316;
  wire [14:0] n1322;
  wire n1324;
  wire [14:0] n1325;
  wire n1327;
  wire n1328;
  wire [63:0] n1329;
  wire n1331;
  wire n1332;
  wire n1336;
  wire [7:0] n1342;
  wire n1343;
  wire n1345;
  wire [14:0] n1347;
  wire [30:0] n1348;
  wire [31:0] n1349;
  wire [31:0] n1351;
  wire [31:0] n1353;
  wire n1356;
  wire n1359;
  wire [7:0] n1362;
  wire n1363;
  wire n1365;
  wire n1366;
  wire n1368;
  wire n1370;
  wire [31:0] n1372;
  wire [31:0] n1374;
  wire n1376;
  wire [63:0] n1377;
  wire [30:0] n1378;
  wire [63:0] n1379;
  wire [6:0] n1380;
  wire [6:0] n1382;
  wire [6:0] n1384;
  wire [6:0] n1386;
  wire [31:0] n1388;
  wire [31:0] n1390;
  wire [63:0] n1391;
  wire [30:0] n1392;
  wire [63:0] n1393;
  wire [6:0] n1394;
  wire [6:0] n1396;
  wire [6:0] n1398;
  wire [6:0] n1403;
  wire n1406;
  localparam [7:0] n1407 = 8'b00000000;
  wire [6:0] n1408;
  wire [6:0] n1409;
  wire [7:0] n1410;
  wire [7:0] n1415;
  wire n1417;
  wire n1419;
  wire n1421;
  wire n1423;
  wire [8:0] n1424;
  reg [3:0] n1430;
  reg [5:0] n1432;
  reg [79:0] n1434;
  reg [79:0] n1436;
  reg [79:0] n1438;
  reg [1:0] n1440;
  reg [1:0] n1442;
  reg [79:0] n1444;
  reg [79:0] n1446;
  reg [7:0] n1448;
  reg n1451;
  reg n1455;
  reg [79:0] n1458;
  reg [79:0] n1460;
  reg n1463;
  reg [1:0] n1465;
  reg [1:0] n1467;
  reg [79:0] n1469;
  reg [79:0] n1471;
  reg [79:0] n1473;
  reg [79:0] n1475;
  reg [3:0] n1479;
  reg n1481;
  reg n1484;
  reg n1488;
  wire n1595;
  wire [15:0] n1599;
  wire [15:0] n1602;
  wire [31:0] n1603;
  wire [31:0] n1604;
  wire [31:0] n1605;
  wire [15:0] n1606;
  wire [31:0] n1608;
  wire [31:0] n1609;
  wire [31:0] n1610;
  wire [31:0] n1611;
  wire [31:0] n1612;
  wire n1614;
  wire n1616;
  wire n1618;
  wire n1620;
  wire [3:0] n1621;
  reg [31:0] n1623;
  reg [31:0] n1625;
  reg [31:0] n1627;
  reg [31:0] n1629;
  wire [31:0] n1630;
  wire [31:0] n1631;
  wire [31:0] n1632;
  wire [31:0] n1633;
  wire [31:0] n1647;
  wire n1649;
  wire [31:0] n1650;
  wire [31:0] n1651;
  wire n1653;
  wire [31:0] n1654;
  wire [31:0] n1655;
  wire n1657;
  wire [31:0] n1658;
  wire [31:0] n1659;
  wire n1661;
  wire [31:0] n1662;
  wire n1666;
  wire n1667;
  reg [3:0] n1669;
  reg [5:0] n1670;
  reg [79:0] n1671;
  reg [79:0] n1672;
  reg [79:0] n1673;
  reg [1:0] n1674;
  reg [1:0] n1675;
  reg [79:0] n1676;
  reg [79:0] n1677;
  reg [7:0] n1678;
  reg n1679;
  reg n1680;
  wire n1681;
  wire [79:0] n1682;
  reg [79:0] n1683;
  wire n1684;
  wire [79:0] n1685;
  reg [79:0] n1686;
  wire n1687;
  wire n1688;
  reg n1689;
  wire n1690;
  wire [1:0] n1691;
  reg [1:0] n1692;
  wire n1693;
  wire [1:0] n1694;
  reg [1:0] n1695;
  wire n1696;
  wire [79:0] n1697;
  reg [79:0] n1698;
  wire n1699;
  wire [79:0] n1700;
  reg [79:0] n1701;
  reg [79:0] n1702;
  reg [79:0] n1703;
  reg [3:0] n1704;
  reg n1705;
  reg n1706;
  reg n1707;
  reg [31:0] n1708;
  reg [31:0] n1709;
  reg [31:0] n1710;
  reg [31:0] n1711;
  wire [63:0] n1712;
  wire n1713;
  assign busy = n1667; //(module output)
  assign done = done_reg; //(module output)
  assign result = result_reg; //(module output)
  assign quotient_byte = quotient_byte_reg; //(module output)
  assign quotient_valid = quotient_valid_reg; //(module output)
  assign fp_mul_start = modpost_mul_start_reg; //(module output)
  assign fp_mul_a_out = mod_fp_mul_a; //(module output)
  assign fp_mul_b_out = mod_fp_mul_b; //(module output)
  assign fp_add_start = modpost_add_start_reg; //(module output)
  assign fp_add_a_out = mod_fp_add_a; //(module output)
  assign fp_add_b_out = mod_fp_add_b; //(module output)
  assign fp_add_sub_out = mod_fp_add_is_sub; //(module output)
  assign fp_add_rm_out = mod_fp_add_rm; //(module output)
  assign fp_add_rp_out = mod_fp_add_rp; //(module output)
  assign save_data = n1650; //(module output)
  /* mc68881_modrem_post_unit.vhd:72:10  */
  always @*
    state_reg = n1669; // (isignal)
  initial
    state_reg = 4'b0000;
  /* mc68881_modrem_post_unit.vhd:73:10  */
  always @*
    op_reg = n1670; // (isignal)
  initial
    op_reg = 6'b000000;
  /* mc68881_modrem_post_unit.vhd:74:10  */
  always @*
    a_reg = n1671; // (isignal)
  initial
    a_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:75:10  */
  always @*
    b_reg = n1672; // (isignal)
  initial
    b_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:76:10  */
  always @*
    quotient_reg = n1673; // (isignal)
  initial
    quotient_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:77:10  */
  always @*
    rm_reg = n1674; // (isignal)
  initial
    rm_reg = 2'b00;
  /* mc68881_modrem_post_unit.vhd:78:10  */
  always @*
    rp_reg = n1675; // (isignal)
  initial
    rp_reg = 2'b00;
  /* mc68881_modrem_post_unit.vhd:79:10  */
  always @*
    n_fp_reg = n1676; // (isignal)
  initial
    n_fp_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:81:10  */
  always @*
    result_reg = n1677; // (isignal)
  initial
    result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:82:10  */
  always @*
    quotient_byte_reg = n1678; // (isignal)
  initial
    quotient_byte_reg = 8'b00000000;
  /* mc68881_modrem_post_unit.vhd:83:10  */
  always @*
    quotient_valid_reg = n1679; // (isignal)
  initial
    quotient_valid_reg = 1'b0;
  /* mc68881_modrem_post_unit.vhd:84:10  */
  always @*
    done_reg = n1680; // (isignal)
  initial
    done_reg = 1'b0;
  /* mc68881_modrem_post_unit.vhd:86:10  */
  always @*
    mod_fp_add_a = n1683; // (isignal)
  initial
    mod_fp_add_a = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:87:10  */
  always @*
    mod_fp_add_b = n1686; // (isignal)
  initial
    mod_fp_add_b = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:88:10  */
  always @*
    mod_fp_add_is_sub = n1689; // (isignal)
  initial
    mod_fp_add_is_sub = 1'b0;
  /* mc68881_modrem_post_unit.vhd:89:10  */
  always @*
    mod_fp_add_rm = n1692; // (isignal)
  initial
    mod_fp_add_rm = 2'b00;
  /* mc68881_modrem_post_unit.vhd:90:10  */
  always @*
    mod_fp_add_rp = n1695; // (isignal)
  initial
    mod_fp_add_rp = 2'b00;
  /* mc68881_modrem_post_unit.vhd:91:10  */
  always @*
    mod_fp_mul_a = n1698; // (isignal)
  initial
    mod_fp_mul_a = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:92:10  */
  always @*
    mod_fp_mul_b = n1701; // (isignal)
  initial
    mod_fp_mul_b = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:93:10  */
  always @*
    mod_add_result_reg = n1702; // (isignal)
  initial
    mod_add_result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:94:10  */
  always @*
    mod_mul_result_reg = n1703; // (isignal)
  initial
    mod_mul_result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:96:10  */
  always @*
    mod_fp_cont_state_reg = n1704; // (isignal)
  initial
    mod_fp_cont_state_reg = 4'b0000;
  /* mc68881_modrem_post_unit.vhd:97:10  */
  always @*
    fp_hold_loaded_reg = n1705; // (isignal)
  initial
    fp_hold_loaded_reg = 1'b0;
  /* mc68881_modrem_post_unit.vhd:99:10  */
  always @*
    modpost_mul_start_reg = n1706; // (isignal)
  initial
    modpost_mul_start_reg = 1'b0;
  /* mc68881_modrem_post_unit.vhd:100:10  */
  always @*
    modpost_add_start_reg = n1707; // (isignal)
  initial
    modpost_add_start_reg = 1'b0;
  /* mc68881_modrem_post_unit.vhd:103:10  */
  always @*
    shadow_state = n1708; // (isignal)
  initial
    shadow_state = 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:104:10  */
  always @*
    shadow_word1 = n1709; // (isignal)
  initial
    shadow_word1 = 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:105:10  */
  always @*
    shadow_word2 = n1710; // (isignal)
  initial
    shadow_word2 = 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:106:10  */
  always @*
    shadow_word3 = n1711; // (isignal)
  initial
    shadow_word3 = 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:230:16  */
  assign n51 = ~reset_n;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n54 = start ? 4'b0001 : state_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n55 = start ? op_sel : op_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n56 = start ? a_in : a_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n57 = start ? b_in : b_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n58 = start ? quotient_in : quotient_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n59 = start ? round_mode : rm_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n60 = start ? round_prec : rp_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n62 = start ? 8'b00000000 : quotient_byte_reg;
  /* mc68881_modrem_post_unit.vhd:256:11  */
  assign n64 = start ? 1'b0 : quotient_valid_reg;
  /* mc68881_modrem_post_unit.vhd:255:9  */
  assign n66 = state_reg == 4'b0000;
  /* mc68881_modrem_post_unit.vhd:111:27  */
  assign n78 = quotient_reg[79]; // extract
  /* mc68881_modrem_post_unit.vhd:112:35  */
  assign n81 = quotient_reg[78:64]; // extract
  /* mc68881_modrem_post_unit.vhd:113:36  */
  assign n83 = quotient_reg[63:0]; // extract
  assign n84 = {n83, n81, n78};
  /* mc68881_modrem_post_unit.vhd:124:16  */
  assign n87 = n84[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:124:20  */
  assign n89 = n87 == 15'b000000000000000;
  /* mc68881_modrem_post_unit.vhd:124:35  */
  assign n90 = n84[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:124:39  */
  assign n92 = n90 == 15'b111111111111111;
  /* mc68881_modrem_post_unit.vhd:124:24  */
  assign n93 = n89 | n92;
  /* mc68881_modrem_post_unit.vhd:124:5  */
  assign n96 = n93 ? 1'b0 : 1'b1;
  /* mc68881_modrem_post_unit.vhd:124:5  */
  assign n100 = n93 ? 1'b0 : 1'b1;
  /* mc68881_modrem_post_unit.vhd:124:5  */
  assign n102 = n93 ? quotient_reg : 80'bX;
  /* mc68881_modrem_post_unit.vhd:128:33  */
  assign n103 = n84[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:128:14  */
  assign n104 = {16'b0, n103};  //  uext
  /* mc68881_modrem_post_unit.vhd:128:38  */
  assign n105 = {1'b0, n104};  //  uext
  /* mc68881_modrem_post_unit.vhd:128:38  */
  assign n107 = n105 - 32'b00000000000000000011111111111111;
  /* mc68881_modrem_post_unit.vhd:128:5  */
  assign n109 = n96 ? n107 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:129:14  */
  assign n112 = $signed(n109) < $signed(32'b00000000000000000000000000000000);
  assign n114 = n84[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:130:7  */
  assign n115 = n96 ? 15'b000000000000000 : n114;
  assign n117 = n84[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:131:7  */
  assign n118 = n96 ? 64'b0000000000000000000000000000000000000000000000000000000000000000 : n117;
  assign n119 = n84[0]; // extract
  assign n120 = {n118, n115, n119};
  /* mc68881_modrem_post_unit.vhd:132:38  */
  assign n121 = n120[0]; // extract
  assign n122 = quotient_reg[79]; // extract
  /* mc68881_modrem_post_unit.vhd:132:7  */
  assign n123 = n96 ? n121 : n122;
  assign n124 = n84[0]; // extract
  assign n125 = {n118, n115, n124};
  /* mc68881_modrem_post_unit.vhd:133:86  */
  assign n126 = n125[15:1]; // extract
  assign n127 = quotient_reg[78:64]; // extract
  /* mc68881_modrem_post_unit.vhd:133:7  */
  assign n128 = n96 ? n126 : n127;
  assign n129 = n84[0]; // extract
  assign n130 = {n118, n115, n129};
  /* mc68881_modrem_post_unit.vhd:134:69  */
  assign n131 = n130[79:16]; // extract
  assign n132 = quotient_reg[63:0]; // extract
  /* mc68881_modrem_post_unit.vhd:134:7  */
  assign n133 = n96 ? n131 : n132;
  assign n134 = {n123, n128, n133};
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n136 = n148 ? 1'b0 : n96;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n138 = n149 ? 1'b0 : n100;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n139 = n150 ? n134 : n102;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n140 = n96 & n112;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n141 = n96 & n112;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n142 = n96 & n112;
  assign n143 = {n118, n115};
  assign n144 = n84[79:1]; // extract
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n145 = n152 ? n143 : n144;
  assign n146 = {n123, n128, n133};
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n147 = n154 ? n146 : quotient_reg;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n148 = n140 & n96;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n149 = n141 & n96;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n150 = n142 & n96;
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n152 = n112 & n96;
  assign n153 = n84[0]; // extract
  /* mc68881_modrem_post_unit.vhd:129:5  */
  assign n154 = n112 & n96;
  /* mc68881_modrem_post_unit.vhd:138:14  */
  assign n156 = $signed(n109) >= $signed(32'b00000000000000000000000000111111);
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n158 = n165 ? 1'b0 : n136;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n160 = n166 ? 1'b0 : n138;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n161 = n167 ? quotient_reg : n139;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n162 = n136 & n156;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n163 = n136 & n156;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n164 = n136 & n156;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n165 = n162 & n136;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n166 = n163 & n136;
  /* mc68881_modrem_post_unit.vhd:138:5  */
  assign n167 = n164 & n136;
  /* mc68881_modrem_post_unit.vhd:142:45  */
  assign n169 = 32'b00000000000000000000000000111111 - n109;
  /* mc68881_modrem_post_unit.vhd:142:5  */
  assign n171 = n158 ? n169 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n174 = $signed(32'b00000000000000000000000000000000) < $signed(n171);
  assign n176 = n145[15]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n177 = n181 ? 1'b0 : n176;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n179 = n158 & n174;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n181 = n179 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n183 = $signed(32'b00000000000000000000000000000001) < $signed(n171);
  assign n185 = n145[16]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n186 = n190 ? 1'b0 : n185;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n188 = n158 & n183;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n190 = n188 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n192 = $signed(32'b00000000000000000000000000000010) < $signed(n171);
  assign n194 = n145[17]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n195 = n199 ? 1'b0 : n194;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n197 = n158 & n192;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n199 = n197 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n201 = $signed(32'b00000000000000000000000000000011) < $signed(n171);
  assign n203 = n145[18]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n204 = n208 ? 1'b0 : n203;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n206 = n158 & n201;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n208 = n206 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n210 = $signed(32'b00000000000000000000000000000100) < $signed(n171);
  assign n212 = n145[19]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n213 = n217 ? 1'b0 : n212;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n215 = n158 & n210;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n217 = n215 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n219 = $signed(32'b00000000000000000000000000000101) < $signed(n171);
  assign n221 = n145[20]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n222 = n226 ? 1'b0 : n221;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n224 = n158 & n219;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n226 = n224 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n228 = $signed(32'b00000000000000000000000000000110) < $signed(n171);
  assign n230 = n145[21]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n231 = n235 ? 1'b0 : n230;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n233 = n158 & n228;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n235 = n233 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n237 = $signed(32'b00000000000000000000000000000111) < $signed(n171);
  assign n239 = n145[22]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n240 = n244 ? 1'b0 : n239;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n242 = n158 & n237;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n244 = n242 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n246 = $signed(32'b00000000000000000000000000001000) < $signed(n171);
  assign n248 = n145[23]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n249 = n253 ? 1'b0 : n248;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n251 = n158 & n246;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n253 = n251 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n255 = $signed(32'b00000000000000000000000000001001) < $signed(n171);
  assign n257 = n145[24]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n258 = n262 ? 1'b0 : n257;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n260 = n158 & n255;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n262 = n260 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n264 = $signed(32'b00000000000000000000000000001010) < $signed(n171);
  assign n266 = n145[25]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n267 = n271 ? 1'b0 : n266;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n269 = n158 & n264;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n271 = n269 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n273 = $signed(32'b00000000000000000000000000001011) < $signed(n171);
  assign n275 = n145[26]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n276 = n280 ? 1'b0 : n275;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n278 = n158 & n273;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n280 = n278 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n282 = $signed(32'b00000000000000000000000000001100) < $signed(n171);
  assign n284 = n145[27]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n285 = n289 ? 1'b0 : n284;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n287 = n158 & n282;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n289 = n287 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n291 = $signed(32'b00000000000000000000000000001101) < $signed(n171);
  assign n293 = n145[28]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n294 = n298 ? 1'b0 : n293;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n296 = n158 & n291;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n298 = n296 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n300 = $signed(32'b00000000000000000000000000001110) < $signed(n171);
  assign n302 = n145[29]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n303 = n307 ? 1'b0 : n302;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n305 = n158 & n300;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n307 = n305 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n309 = $signed(32'b00000000000000000000000000001111) < $signed(n171);
  assign n311 = n145[30]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n312 = n316 ? 1'b0 : n311;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n314 = n158 & n309;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n316 = n314 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n318 = $signed(32'b00000000000000000000000000010000) < $signed(n171);
  assign n320 = n145[31]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n321 = n325 ? 1'b0 : n320;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n323 = n158 & n318;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n325 = n323 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n327 = $signed(32'b00000000000000000000000000010001) < $signed(n171);
  assign n329 = n145[32]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n330 = n334 ? 1'b0 : n329;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n332 = n158 & n327;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n334 = n332 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n336 = $signed(32'b00000000000000000000000000010010) < $signed(n171);
  assign n338 = n145[33]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n339 = n343 ? 1'b0 : n338;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n341 = n158 & n336;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n343 = n341 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n345 = $signed(32'b00000000000000000000000000010011) < $signed(n171);
  assign n347 = n145[34]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n348 = n352 ? 1'b0 : n347;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n350 = n158 & n345;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n352 = n350 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n354 = $signed(32'b00000000000000000000000000010100) < $signed(n171);
  assign n356 = n145[35]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n357 = n361 ? 1'b0 : n356;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n359 = n158 & n354;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n361 = n359 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n363 = $signed(32'b00000000000000000000000000010101) < $signed(n171);
  assign n365 = n145[36]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n366 = n370 ? 1'b0 : n365;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n368 = n158 & n363;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n370 = n368 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n372 = $signed(32'b00000000000000000000000000010110) < $signed(n171);
  assign n374 = n145[37]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n375 = n379 ? 1'b0 : n374;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n377 = n158 & n372;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n379 = n377 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n381 = $signed(32'b00000000000000000000000000010111) < $signed(n171);
  assign n383 = n145[38]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n384 = n388 ? 1'b0 : n383;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n386 = n158 & n381;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n388 = n386 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n390 = $signed(32'b00000000000000000000000000011000) < $signed(n171);
  assign n392 = n145[39]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n393 = n397 ? 1'b0 : n392;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n395 = n158 & n390;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n397 = n395 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n399 = $signed(32'b00000000000000000000000000011001) < $signed(n171);
  assign n401 = n145[40]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n402 = n406 ? 1'b0 : n401;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n404 = n158 & n399;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n406 = n404 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n408 = $signed(32'b00000000000000000000000000011010) < $signed(n171);
  assign n410 = n145[41]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n411 = n415 ? 1'b0 : n410;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n413 = n158 & n408;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n415 = n413 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n417 = $signed(32'b00000000000000000000000000011011) < $signed(n171);
  assign n419 = n145[42]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n420 = n424 ? 1'b0 : n419;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n422 = n158 & n417;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n424 = n422 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n426 = $signed(32'b00000000000000000000000000011100) < $signed(n171);
  assign n428 = n145[43]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n429 = n433 ? 1'b0 : n428;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n431 = n158 & n426;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n433 = n431 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n435 = $signed(32'b00000000000000000000000000011101) < $signed(n171);
  assign n437 = n145[44]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n438 = n442 ? 1'b0 : n437;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n440 = n158 & n435;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n442 = n440 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n444 = $signed(32'b00000000000000000000000000011110) < $signed(n171);
  assign n446 = n145[45]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n447 = n451 ? 1'b0 : n446;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n449 = n158 & n444;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n451 = n449 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n453 = $signed(32'b00000000000000000000000000011111) < $signed(n171);
  assign n455 = n145[46]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n456 = n460 ? 1'b0 : n455;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n458 = n158 & n453;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n460 = n458 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n462 = $signed(32'b00000000000000000000000000100000) < $signed(n171);
  assign n464 = n145[47]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n465 = n469 ? 1'b0 : n464;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n467 = n158 & n462;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n469 = n467 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n471 = $signed(32'b00000000000000000000000000100001) < $signed(n171);
  assign n473 = n145[48]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n474 = n478 ? 1'b0 : n473;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n476 = n158 & n471;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n478 = n476 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n480 = $signed(32'b00000000000000000000000000100010) < $signed(n171);
  assign n482 = n145[49]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n483 = n487 ? 1'b0 : n482;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n485 = n158 & n480;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n487 = n485 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n489 = $signed(32'b00000000000000000000000000100011) < $signed(n171);
  assign n491 = n145[50]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n492 = n496 ? 1'b0 : n491;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n494 = n158 & n489;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n496 = n494 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n498 = $signed(32'b00000000000000000000000000100100) < $signed(n171);
  assign n500 = n145[51]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n501 = n505 ? 1'b0 : n500;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n503 = n158 & n498;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n505 = n503 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n507 = $signed(32'b00000000000000000000000000100101) < $signed(n171);
  assign n509 = n145[52]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n510 = n514 ? 1'b0 : n509;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n512 = n158 & n507;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n514 = n512 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n516 = $signed(32'b00000000000000000000000000100110) < $signed(n171);
  assign n518 = n145[53]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n519 = n523 ? 1'b0 : n518;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n521 = n158 & n516;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n523 = n521 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n525 = $signed(32'b00000000000000000000000000100111) < $signed(n171);
  assign n527 = n145[54]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n528 = n532 ? 1'b0 : n527;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n530 = n158 & n525;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n532 = n530 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n534 = $signed(32'b00000000000000000000000000101000) < $signed(n171);
  assign n536 = n145[55]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n537 = n541 ? 1'b0 : n536;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n539 = n158 & n534;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n541 = n539 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n543 = $signed(32'b00000000000000000000000000101001) < $signed(n171);
  assign n545 = n145[56]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n546 = n550 ? 1'b0 : n545;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n548 = n158 & n543;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n550 = n548 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n552 = $signed(32'b00000000000000000000000000101010) < $signed(n171);
  assign n554 = n145[57]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n555 = n559 ? 1'b0 : n554;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n557 = n158 & n552;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n559 = n557 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n561 = $signed(32'b00000000000000000000000000101011) < $signed(n171);
  assign n563 = n145[58]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n564 = n568 ? 1'b0 : n563;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n566 = n158 & n561;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n568 = n566 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n570 = $signed(32'b00000000000000000000000000101100) < $signed(n171);
  assign n572 = n145[59]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n573 = n577 ? 1'b0 : n572;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n575 = n158 & n570;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n577 = n575 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n579 = $signed(32'b00000000000000000000000000101101) < $signed(n171);
  assign n581 = n145[60]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n582 = n586 ? 1'b0 : n581;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n584 = n158 & n579;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n586 = n584 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n588 = $signed(32'b00000000000000000000000000101110) < $signed(n171);
  assign n590 = n145[61]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n591 = n595 ? 1'b0 : n590;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n593 = n158 & n588;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n595 = n593 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n597 = $signed(32'b00000000000000000000000000101111) < $signed(n171);
  assign n599 = n145[62]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n600 = n604 ? 1'b0 : n599;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n602 = n158 & n597;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n604 = n602 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n606 = $signed(32'b00000000000000000000000000110000) < $signed(n171);
  assign n608 = n145[63]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n609 = n613 ? 1'b0 : n608;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n611 = n158 & n606;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n613 = n611 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n615 = $signed(32'b00000000000000000000000000110001) < $signed(n171);
  assign n617 = n145[64]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n618 = n622 ? 1'b0 : n617;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n620 = n158 & n615;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n622 = n620 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n624 = $signed(32'b00000000000000000000000000110010) < $signed(n171);
  assign n626 = n145[65]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n627 = n631 ? 1'b0 : n626;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n629 = n158 & n624;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n631 = n629 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n633 = $signed(32'b00000000000000000000000000110011) < $signed(n171);
  assign n635 = n145[66]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n636 = n640 ? 1'b0 : n635;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n638 = n158 & n633;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n640 = n638 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n642 = $signed(32'b00000000000000000000000000110100) < $signed(n171);
  assign n644 = n145[67]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n645 = n649 ? 1'b0 : n644;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n647 = n158 & n642;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n649 = n647 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n651 = $signed(32'b00000000000000000000000000110101) < $signed(n171);
  assign n653 = n145[68]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n654 = n658 ? 1'b0 : n653;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n656 = n158 & n651;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n658 = n656 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n660 = $signed(32'b00000000000000000000000000110110) < $signed(n171);
  assign n662 = n145[69]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n663 = n667 ? 1'b0 : n662;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n665 = n158 & n660;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n667 = n665 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n669 = $signed(32'b00000000000000000000000000110111) < $signed(n171);
  assign n671 = n145[70]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n672 = n676 ? 1'b0 : n671;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n674 = n158 & n669;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n676 = n674 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n678 = $signed(32'b00000000000000000000000000111000) < $signed(n171);
  assign n680 = n145[71]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n681 = n685 ? 1'b0 : n680;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n683 = n158 & n678;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n685 = n683 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n687 = $signed(32'b00000000000000000000000000111001) < $signed(n171);
  assign n689 = n145[72]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n690 = n694 ? 1'b0 : n689;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n692 = n158 & n687;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n694 = n692 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n696 = $signed(32'b00000000000000000000000000111010) < $signed(n171);
  assign n698 = n145[73]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n699 = n703 ? 1'b0 : n698;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n701 = n158 & n696;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n703 = n701 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n705 = $signed(32'b00000000000000000000000000111011) < $signed(n171);
  assign n707 = n145[74]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n708 = n712 ? 1'b0 : n707;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n710 = n158 & n705;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n712 = n710 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n714 = $signed(32'b00000000000000000000000000111100) < $signed(n171);
  assign n716 = n145[75]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n717 = n721 ? 1'b0 : n716;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n719 = n158 & n714;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n721 = n719 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n723 = $signed(32'b00000000000000000000000000111101) < $signed(n171);
  assign n725 = n145[76]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n726 = n730 ? 1'b0 : n725;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n728 = n158 & n723;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n730 = n728 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n732 = $signed(32'b00000000000000000000000000111110) < $signed(n171);
  assign n734 = n145[77]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n735 = n739 ? 1'b0 : n734;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n737 = n158 & n732;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n739 = n737 & n158;
  /* mc68881_modrem_post_unit.vhd:144:18  */
  assign n741 = $signed(32'b00000000000000000000000000111111) < $signed(n171);
  assign n743 = n145[78]; // extract
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n744 = n748 ? 1'b0 : n743;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n746 = n158 & n741;
  /* mc68881_modrem_post_unit.vhd:144:7  */
  assign n748 = n746 & n158;
  /* mc68881_modrem_post_unit.vhd:143:5  */
  assign n749 = n158 ? n160 : n158;
  assign n750 = {n744, n735, n726, n717, n708, n699, n690, n681, n672, n663, n654, n645, n636, n627, n618, n609, n600, n591, n582, n573, n564, n555, n546, n537, n528, n519, n510, n501, n492, n483, n474, n465, n456, n447, n438, n429, n420, n411, n402, n393, n384, n375, n366, n357, n348, n339, n330, n321, n312, n303, n294, n285, n276, n267, n258, n249, n240, n231, n222, n213, n204, n195, n186, n177};
  assign n751 = n145[78:15]; // extract
  /* mc68881_modrem_post_unit.vhd:143:5  */
  assign n752 = n158 ? n750 : n751;
  assign n753 = n145[14:0]; // extract
  assign n754 = {n752, n753, n153};
  /* mc68881_modrem_post_unit.vhd:148:36  */
  assign n755 = n754[0]; // extract
  assign n756 = n147[79]; // extract
  /* mc68881_modrem_post_unit.vhd:148:5  */
  assign n757 = n749 ? n755 : n756;
  assign n759 = {n752, n753, n153};
  /* mc68881_modrem_post_unit.vhd:149:84  */
  assign n760 = n759[15:1]; // extract
  assign n761 = n147[78:64]; // extract
  /* mc68881_modrem_post_unit.vhd:149:5  */
  assign n762 = n749 ? n760 : n761;
  assign n763 = n147[63:0]; // extract
  assign n764 = {n752, n753, n153};
  /* mc68881_modrem_post_unit.vhd:150:67  */
  assign n765 = n764[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:150:5  */
  assign n766 = n749 ? n765 : n763;
  assign n767 = {n757, n762, n766};
  /* mc68881_modrem_post_unit.vhd:151:5  */
  assign n772 = n749 ? n767 : n161;
  /* mc68881_modrem_post_unit.vhd:272:21  */
  assign n774 = op_reg == 6'b000111;
  /* mc68881_modrem_post_unit.vhd:111:27  */
  assign n786 = n772[79]; // extract
  /* mc68881_modrem_post_unit.vhd:112:35  */
  assign n789 = n772[78:64]; // extract
  /* mc68881_modrem_post_unit.vhd:113:36  */
  assign n791 = n772[63:0]; // extract
  assign n792 = {n791, n789, n786};
  /* mc68881_modrem_post_unit.vhd:184:10  */
  assign n798 = n792[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:184:14  */
  assign n800 = n798 == 15'b000000000000000;
  /* mc68881_modrem_post_unit.vhd:184:23  */
  assign n801 = n792[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:184:27  */
  assign n803 = n801 == 15'b111111111111111;
  /* mc68881_modrem_post_unit.vhd:184:18  */
  assign n804 = n800 | n803;
  /* mc68881_modrem_post_unit.vhd:184:50  */
  assign n805 = n792[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:184:55  */
  assign n807 = n805 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:184:45  */
  assign n808 = n804 | n807;
  /* mc68881_modrem_post_unit.vhd:184:5  */
  assign n812 = n808 ? 1'b0 : 1'b1;
  /* mc68881_modrem_post_unit.vhd:184:5  */
  assign n818 = n808 ? 8'b00000000 : 8'bX;
  /* mc68881_modrem_post_unit.vhd:188:19  */
  assign n819 = n792[0]; // extract
  /* mc68881_modrem_post_unit.vhd:188:5  */
  assign n821 = n812 ? n819 : 1'b0;
  /* mc68881_modrem_post_unit.vhd:189:27  */
  assign n823 = n792[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:189:14  */
  assign n824 = {16'b0, n823};  //  uext
  /* mc68881_modrem_post_unit.vhd:189:32  */
  assign n825 = {1'b0, n824};  //  uext
  /* mc68881_modrem_post_unit.vhd:189:32  */
  assign n827 = n825 - 32'b00000000000000000011111111111111;
  /* mc68881_modrem_post_unit.vhd:189:5  */
  assign n829 = n812 ? n827 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:190:14  */
  assign n832 = $signed(n829) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n835 = n842 ? 1'b0 : n812;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n838 = n844 ? 8'b00000000 : n818;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n839 = n812 & n832;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n841 = n812 & n832;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n842 = n839 & n812;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n844 = n841 & n812;
  /* mc68881_modrem_post_unit.vhd:194:14  */
  assign n846 = $signed(n829) >= $signed(32'b00000000000000000000000000111111);
  /* mc68881_modrem_post_unit.vhd:195:26  */
  assign n848 = n829 - 32'b00000000000000000000000000111111;
  /* mc68881_modrem_post_unit.vhd:195:7  */
  assign n850 = n835 ? n848 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:196:20  */
  assign n852 = $signed(n850) >= $signed(32'b00000000000000000000000000000111);
  /* mc68881_modrem_post_unit.vhd:199:37  */
  assign n853 = n792[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:199:43  */
  assign n854 = n850[30:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:199:24  */
  assign n855 = n853 << n854;
  /* mc68881_modrem_post_unit.vhd:199:17  */
  assign n856 = n855[6:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:199:9  */
  assign n858 = n835 ? n856 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:196:7  */
  assign n860 = n852 ? 7'b0000000 : n858;
  /* mc68881_modrem_post_unit.vhd:196:7  */
  assign n862 = n835 ? n860 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:202:47  */
  assign n864 = 32'b00000000000000000000000000111111 - n829;
  /* mc68881_modrem_post_unit.vhd:202:7  */
  assign n866 = n835 ? n864 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:203:36  */
  assign n867 = n792[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:203:42  */
  assign n868 = n866[30:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:203:22  */
  assign n869 = n867 >> n868;
  /* mc68881_modrem_post_unit.vhd:203:15  */
  assign n870 = n869[6:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:203:7  */
  assign n872 = n835 ? n870 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:194:5  */
  assign n874 = n846 ? n862 : n872;
  /* mc68881_modrem_post_unit.vhd:194:5  */
  assign n879 = n835 ? n874 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:206:5  */
  assign n882 = n835 ? n821 : 1'b0;
  assign n884 = n883[6:0]; // extract
  /* mc68881_modrem_post_unit.vhd:207:5  */
  assign n885 = n835 ? n879 : n884;
  assign n886 = {n882, n885};
  /* mc68881_modrem_post_unit.vhd:208:5  */
  assign n891 = n835 ? n886 : n838;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n894 = n774 ? 4'b0011 : 4'b0010;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n895 = n774 ? n891 : quotient_byte_reg;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n897 = n774 ? 1'b1 : quotient_valid_reg;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n898 = n774 ? mod_fp_add_a : quotient_reg;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n899 = n774 ? mod_fp_add_b : n772;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n901 = n774 ? mod_fp_add_is_sub : 1'b1;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n903 = n774 ? mod_fp_add_rm : 2'b00;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n905 = n774 ? mod_fp_add_rp : 2'b00;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n906 = n774 ? b_reg : mod_fp_mul_a;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n907 = n774 ? n772 : mod_fp_mul_b;
  /* mc68881_modrem_post_unit.vhd:272:11  */
  assign n910 = n774 ? 4'b0110 : 4'b0100;
  /* mc68881_modrem_post_unit.vhd:268:9  */
  assign n912 = state_reg == 4'b0001;
  /* mc68881_modrem_post_unit.vhd:290:33  */
  assign n913 = ~fp_hold_loaded_reg;
  /* mc68881_modrem_post_unit.vhd:293:11  */
  assign n914 = fp_add_done ? mod_fp_cont_state_reg : state_reg;
  /* mc68881_modrem_post_unit.vhd:293:11  */
  assign n915 = fp_add_done ? fp_add_result : mod_add_result_reg;
  /* mc68881_modrem_post_unit.vhd:293:11  */
  assign n917 = fp_add_done ? 1'b0 : fp_hold_loaded_reg;
  /* mc68881_modrem_post_unit.vhd:290:11  */
  assign n918 = n913 ? state_reg : n914;
  /* mc68881_modrem_post_unit.vhd:290:11  */
  assign n919 = n913 ? mod_add_result_reg : n915;
  /* mc68881_modrem_post_unit.vhd:290:11  */
  assign n921 = n913 ? 1'b1 : n917;
  /* mc68881_modrem_post_unit.vhd:290:11  */
  assign n924 = n913 ? 1'b1 : 1'b0;
  /* mc68881_modrem_post_unit.vhd:289:9  */
  assign n926 = state_reg == 4'b0010;
  /* mc68881_modrem_post_unit.vhd:300:33  */
  assign n927 = ~fp_hold_loaded_reg;
  /* mc68881_modrem_post_unit.vhd:303:11  */
  assign n928 = fp_mul_done ? mod_fp_cont_state_reg : state_reg;
  /* mc68881_modrem_post_unit.vhd:303:11  */
  assign n929 = fp_mul_done ? fp_mul_result : mod_mul_result_reg;
  /* mc68881_modrem_post_unit.vhd:303:11  */
  assign n931 = fp_mul_done ? 1'b0 : fp_hold_loaded_reg;
  /* mc68881_modrem_post_unit.vhd:300:11  */
  assign n932 = n927 ? state_reg : n928;
  /* mc68881_modrem_post_unit.vhd:300:11  */
  assign n933 = n927 ? mod_mul_result_reg : n929;
  /* mc68881_modrem_post_unit.vhd:300:11  */
  assign n935 = n927 ? 1'b1 : n931;
  /* mc68881_modrem_post_unit.vhd:300:11  */
  assign n938 = n927 ? 1'b1 : 1'b0;
  /* mc68881_modrem_post_unit.vhd:299:9  */
  assign n940 = state_reg == 4'b0011;
  assign n947 = mod_add_result_reg[78:0]; // extract
  assign n948 = {1'b0, n947};
  assign n961 = n948[78:0]; // extract
  assign n962 = {1'b0, n961};
  /* mc68881_pkg.vhd:2206:9  */
  assign n967 = n948[79]; // extract
  /* mc68881_pkg.vhd:2206:22  */
  assign n969 = n967 != 1'b0;
  /* mc68881_pkg.vhd:2207:11  */
  assign n970 = n948[79]; // extract
  /* mc68881_pkg.vhd:2207:7  */
  assign n974 = n970 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:2207:7  */
  assign n978 = n970 ? 32'b11111111111111111111111111111111 : 32'bX;
  /* mc68881_pkg.vhd:2210:7  */
  assign n981 = n974 ? 1'b0 : n974;
  /* mc68881_pkg.vhd:2210:7  */
  assign n984 = n974 ? 32'b00000000000000000000000000000001 : n978;
  /* mc68881_pkg.vhd:2206:5  */
  assign n986 = n969 ? n981 : 1'b1;
  /* mc68881_pkg.vhd:2206:5  */
  assign n991 = n969 ? n984 : 32'bX;
  /* mc68881_pkg.vhd:1538:25  */
  assign n1003 = n962[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n1006 = n962[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n1008 = n962[63:0]; // extract
  assign n1009 = {n1008, n1006, n1003};
  /* mc68881_pkg.vhd:1538:25  */
  assign n1017 = n1016[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n1021 = n1020[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n1024 = n1023[63:0]; // extract
  assign n1025 = {n1024, n1021, n1017};
  /* mc68881_pkg.vhd:2184:12  */
  assign n1026 = n1009[15:1]; // extract
  /* mc68881_pkg.vhd:2184:22  */
  assign n1027 = n1025[15:1]; // extract
  /* mc68881_pkg.vhd:2184:16  */
  assign n1028 = $unsigned(n1026) > $unsigned(n1027);
  /* mc68881_pkg.vhd:2186:15  */
  assign n1030 = n1009[15:1]; // extract
  /* mc68881_pkg.vhd:2186:25  */
  assign n1031 = n1025[15:1]; // extract
  /* mc68881_pkg.vhd:2186:19  */
  assign n1032 = $unsigned(n1030) < $unsigned(n1031);
  /* mc68881_pkg.vhd:2188:15  */
  assign n1034 = n1009[79:16]; // extract
  /* mc68881_pkg.vhd:2188:26  */
  assign n1035 = n1025[79:16]; // extract
  /* mc68881_pkg.vhd:2188:20  */
  assign n1036 = $unsigned(n1034) > $unsigned(n1035);
  /* mc68881_pkg.vhd:2190:15  */
  assign n1038 = n1009[79:16]; // extract
  /* mc68881_pkg.vhd:2190:26  */
  assign n1039 = n1025[79:16]; // extract
  /* mc68881_pkg.vhd:2190:20  */
  assign n1040 = $unsigned(n1038) < $unsigned(n1039);
  /* mc68881_pkg.vhd:2190:5  */
  assign n1043 = n1040 ? 32'b11111111111111111111111111111111 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2188:5  */
  assign n1044 = n1036 ? 32'b00000000000000000000000000000001 : n1043;
  /* mc68881_pkg.vhd:2186:5  */
  assign n1045 = n1032 ? 32'b11111111111111111111111111111111 : n1044;
  /* mc68881_pkg.vhd:2184:5  */
  assign n1046 = n1028 ? 32'b00000000000000000000000000000001 : n1045;
  /* mc68881_pkg.vhd:2213:5  */
  assign n1048 = n986 ? n1046 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2214:9  */
  assign n1050 = n948[79]; // extract
  /* mc68881_pkg.vhd:2215:14  */
  assign n1051 = -n1048;
  /* mc68881_pkg.vhd:2214:5  */
  assign n1053 = n1060 ? 1'b0 : n986;
  /* mc68881_pkg.vhd:2214:5  */
  assign n1056 = n1062 ? n1051 : n991;
  /* mc68881_pkg.vhd:2214:5  */
  assign n1057 = n986 & n1050;
  /* mc68881_pkg.vhd:2214:5  */
  assign n1059 = n986 & n1050;
  /* mc68881_pkg.vhd:2214:5  */
  assign n1060 = n1057 & n986;
  /* mc68881_pkg.vhd:2214:5  */
  assign n1062 = n1059 & n986;
  /* mc68881_pkg.vhd:2217:5  */
  assign n1067 = n1053 ? n1048 : n1056;
  /* mc68881_modrem_post_unit.vhd:313:24  */
  assign n1069 = $signed(n1067) > $signed(32'b00000000000000000000000000000000);
  /* mc68881_modrem_post_unit.vhd:313:42  */
  assign n1071 = n1067 == 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:111:27  */
  assign n1083 = n_fp_reg[79]; // extract
  /* mc68881_modrem_post_unit.vhd:112:35  */
  assign n1086 = n_fp_reg[78:64]; // extract
  /* mc68881_modrem_post_unit.vhd:113:36  */
  assign n1088 = n_fp_reg[63:0]; // extract
  /* mc68881_modrem_post_unit.vhd:173:24  */
  assign n1089 = {n1088, n1086, n1083};
  /* mc68881_modrem_post_unit.vhd:159:16  */
  assign n1092 = n1089[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:159:20  */
  assign n1094 = n1092 == 15'b000000000000000;
  /* mc68881_modrem_post_unit.vhd:159:35  */
  assign n1095 = n1089[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:159:39  */
  assign n1097 = n1095 == 15'b111111111111111;
  /* mc68881_modrem_post_unit.vhd:159:24  */
  assign n1098 = n1094 | n1097;
  /* mc68881_modrem_post_unit.vhd:159:5  */
  assign n1102 = n1098 ? 1'b0 : 1'b1;
  /* mc68881_modrem_post_unit.vhd:159:5  */
  assign n1108 = n1098 ? 1'b0 : 1'bX;
  /* mc68881_modrem_post_unit.vhd:163:33  */
  assign n1109 = n1089[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:163:14  */
  assign n1110 = {16'b0, n1109};  //  uext
  /* mc68881_modrem_post_unit.vhd:163:38  */
  assign n1111 = {1'b0, n1110};  //  uext
  /* mc68881_modrem_post_unit.vhd:163:38  */
  assign n1113 = n1111 - 32'b00000000000000000011111111111111;
  /* mc68881_modrem_post_unit.vhd:163:5  */
  assign n1115 = n1102 ? n1113 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:164:14  */
  assign n1118 = $signed(n1115) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_modrem_post_unit.vhd:164:5  */
  assign n1121 = n1128 ? 1'b0 : n1102;
  /* mc68881_modrem_post_unit.vhd:164:5  */
  assign n1124 = n1130 ? 1'b0 : n1108;
  /* mc68881_modrem_post_unit.vhd:164:5  */
  assign n1125 = n1102 & n1118;
  /* mc68881_modrem_post_unit.vhd:164:5  */
  assign n1127 = n1102 & n1118;
  /* mc68881_modrem_post_unit.vhd:164:5  */
  assign n1128 = n1125 & n1102;
  /* mc68881_modrem_post_unit.vhd:164:5  */
  assign n1130 = n1127 & n1102;
  /* mc68881_modrem_post_unit.vhd:168:14  */
  assign n1132 = $signed(n1115) > $signed(32'b00000000000000000000000000111111);
  /* mc68881_modrem_post_unit.vhd:168:5  */
  assign n1135 = n1142 ? 1'b0 : n1121;
  /* mc68881_modrem_post_unit.vhd:168:5  */
  assign n1138 = n1144 ? 1'b0 : n1124;
  /* mc68881_modrem_post_unit.vhd:168:5  */
  assign n1139 = n1121 & n1132;
  /* mc68881_modrem_post_unit.vhd:168:5  */
  assign n1141 = n1121 & n1132;
  /* mc68881_modrem_post_unit.vhd:168:5  */
  assign n1142 = n1139 & n1121;
  /* mc68881_modrem_post_unit.vhd:168:5  */
  assign n1144 = n1141 & n1121;
  /* mc68881_modrem_post_unit.vhd:172:43  */
  assign n1146 = 32'b00000000000000000000000000111111 - n1115;
  /* mc68881_modrem_post_unit.vhd:172:5  */
  assign n1148 = n1135 ? n1146 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:173:25  */
  assign n1150 = n1148[5:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:173:5  */
  assign n1157 = n1135 ? n1713 : n1138;
  /* mc68881_modrem_post_unit.vhd:313:46  */
  assign n1158 = n1157 & n1071;
  /* mc68881_modrem_post_unit.vhd:313:29  */
  assign n1159 = n1069 | n1158;
  /* mc68881_modrem_post_unit.vhd:316:46  */
  assign n1160 = quotient_reg[79]; // extract
  /* mc68881_modrem_post_unit.vhd:111:27  */
  assign n1172 = n_fp_reg[79]; // extract
  /* mc68881_modrem_post_unit.vhd:112:35  */
  assign n1175 = n_fp_reg[78:64]; // extract
  /* mc68881_modrem_post_unit.vhd:113:36  */
  assign n1177 = n_fp_reg[63:0]; // extract
  assign n1178 = {n1177, n1175, n1172};
  /* mc68881_modrem_post_unit.vhd:184:10  */
  assign n1184 = n1178[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:184:14  */
  assign n1186 = n1184 == 15'b000000000000000;
  /* mc68881_modrem_post_unit.vhd:184:23  */
  assign n1187 = n1178[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:184:27  */
  assign n1189 = n1187 == 15'b111111111111111;
  /* mc68881_modrem_post_unit.vhd:184:18  */
  assign n1190 = n1186 | n1189;
  /* mc68881_modrem_post_unit.vhd:184:50  */
  assign n1191 = n1178[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:184:55  */
  assign n1193 = n1191 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:184:45  */
  assign n1194 = n1190 | n1193;
  /* mc68881_modrem_post_unit.vhd:184:5  */
  assign n1198 = n1194 ? 1'b0 : 1'b1;
  /* mc68881_modrem_post_unit.vhd:184:5  */
  assign n1204 = n1194 ? 8'b00000000 : 8'bX;
  /* mc68881_modrem_post_unit.vhd:188:19  */
  assign n1205 = n1178[0]; // extract
  /* mc68881_modrem_post_unit.vhd:188:5  */
  assign n1207 = n1198 ? n1205 : 1'b0;
  /* mc68881_modrem_post_unit.vhd:189:27  */
  assign n1209 = n1178[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:189:14  */
  assign n1210 = {16'b0, n1209};  //  uext
  /* mc68881_modrem_post_unit.vhd:189:32  */
  assign n1211 = {1'b0, n1210};  //  uext
  /* mc68881_modrem_post_unit.vhd:189:32  */
  assign n1213 = n1211 - 32'b00000000000000000011111111111111;
  /* mc68881_modrem_post_unit.vhd:189:5  */
  assign n1215 = n1198 ? n1213 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:190:14  */
  assign n1218 = $signed(n1215) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1221 = n1228 ? 1'b0 : n1198;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1224 = n1230 ? 8'b00000000 : n1204;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1225 = n1198 & n1218;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1227 = n1198 & n1218;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1228 = n1225 & n1198;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1230 = n1227 & n1198;
  /* mc68881_modrem_post_unit.vhd:194:14  */
  assign n1232 = $signed(n1215) >= $signed(32'b00000000000000000000000000111111);
  /* mc68881_modrem_post_unit.vhd:195:26  */
  assign n1234 = n1215 - 32'b00000000000000000000000000111111;
  /* mc68881_modrem_post_unit.vhd:195:7  */
  assign n1236 = n1221 ? n1234 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:196:20  */
  assign n1238 = $signed(n1236) >= $signed(32'b00000000000000000000000000000111);
  /* mc68881_modrem_post_unit.vhd:199:37  */
  assign n1239 = n1178[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:199:43  */
  assign n1240 = n1236[30:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:199:24  */
  assign n1241 = n1239 << n1240;
  /* mc68881_modrem_post_unit.vhd:199:17  */
  assign n1242 = n1241[6:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:199:9  */
  assign n1244 = n1221 ? n1242 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:196:7  */
  assign n1246 = n1238 ? 7'b0000000 : n1244;
  /* mc68881_modrem_post_unit.vhd:196:7  */
  assign n1248 = n1221 ? n1246 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:202:47  */
  assign n1250 = 32'b00000000000000000000000000111111 - n1215;
  /* mc68881_modrem_post_unit.vhd:202:7  */
  assign n1252 = n1221 ? n1250 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:203:36  */
  assign n1253 = n1178[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:203:42  */
  assign n1254 = n1252[30:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:203:22  */
  assign n1255 = n1253 >> n1254;
  /* mc68881_modrem_post_unit.vhd:203:15  */
  assign n1256 = n1255[6:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:203:7  */
  assign n1258 = n1221 ? n1256 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:194:5  */
  assign n1260 = n1232 ? n1248 : n1258;
  /* mc68881_modrem_post_unit.vhd:194:5  */
  assign n1265 = n1221 ? n1260 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:206:5  */
  assign n1268 = n1221 ? n1207 : 1'b0;
  assign n1270 = n1269[6:0]; // extract
  /* mc68881_modrem_post_unit.vhd:207:5  */
  assign n1271 = n1221 ? n1265 : n1270;
  assign n1272 = {n1268, n1271};
  /* mc68881_modrem_post_unit.vhd:208:5  */
  assign n1277 = n1221 ? n1272 : n1224;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1280 = n1159 ? 4'b0010 : 4'b0011;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1281 = n1159 ? quotient_byte_reg : n1277;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1283 = n1159 ? quotient_valid_reg : 1'b1;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1284 = n1159 ? n_fp_reg : mod_fp_add_a;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1286 = n1159 ? 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000 : mod_fp_add_b;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1287 = n1159 ? n1160 : mod_fp_add_is_sub;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1289 = n1159 ? 2'b00 : mod_fp_add_rm;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1291 = n1159 ? 2'b00 : mod_fp_add_rp;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1292 = n1159 ? mod_fp_mul_a : b_reg;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1293 = n1159 ? mod_fp_mul_b : n_fp_reg;
  /* mc68881_modrem_post_unit.vhd:313:11  */
  assign n1296 = n1159 ? 4'b0101 : 4'b0110;
  /* mc68881_modrem_post_unit.vhd:309:9  */
  assign n1298 = state_reg == 4'b0100;
  /* mc68881_modrem_post_unit.vhd:111:27  */
  assign n1310 = mod_add_result_reg[79]; // extract
  /* mc68881_modrem_post_unit.vhd:112:35  */
  assign n1313 = mod_add_result_reg[78:64]; // extract
  /* mc68881_modrem_post_unit.vhd:113:36  */
  assign n1315 = mod_add_result_reg[63:0]; // extract
  assign n1316 = {n1315, n1313, n1310};
  /* mc68881_modrem_post_unit.vhd:184:10  */
  assign n1322 = n1316[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:184:14  */
  assign n1324 = n1322 == 15'b000000000000000;
  /* mc68881_modrem_post_unit.vhd:184:23  */
  assign n1325 = n1316[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:184:27  */
  assign n1327 = n1325 == 15'b111111111111111;
  /* mc68881_modrem_post_unit.vhd:184:18  */
  assign n1328 = n1324 | n1327;
  /* mc68881_modrem_post_unit.vhd:184:50  */
  assign n1329 = n1316[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:184:55  */
  assign n1331 = n1329 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:184:45  */
  assign n1332 = n1328 | n1331;
  /* mc68881_modrem_post_unit.vhd:184:5  */
  assign n1336 = n1332 ? 1'b0 : 1'b1;
  /* mc68881_modrem_post_unit.vhd:184:5  */
  assign n1342 = n1332 ? 8'b00000000 : 8'bX;
  /* mc68881_modrem_post_unit.vhd:188:19  */
  assign n1343 = n1316[0]; // extract
  /* mc68881_modrem_post_unit.vhd:188:5  */
  assign n1345 = n1336 ? n1343 : 1'b0;
  /* mc68881_modrem_post_unit.vhd:189:27  */
  assign n1347 = n1316[15:1]; // extract
  /* mc68881_modrem_post_unit.vhd:189:14  */
  assign n1348 = {16'b0, n1347};  //  uext
  /* mc68881_modrem_post_unit.vhd:189:32  */
  assign n1349 = {1'b0, n1348};  //  uext
  /* mc68881_modrem_post_unit.vhd:189:32  */
  assign n1351 = n1349 - 32'b00000000000000000011111111111111;
  /* mc68881_modrem_post_unit.vhd:189:5  */
  assign n1353 = n1336 ? n1351 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:190:14  */
  assign n1356 = $signed(n1353) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1359 = n1366 ? 1'b0 : n1336;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1362 = n1368 ? 8'b00000000 : n1342;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1363 = n1336 & n1356;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1365 = n1336 & n1356;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1366 = n1363 & n1336;
  /* mc68881_modrem_post_unit.vhd:190:5  */
  assign n1368 = n1365 & n1336;
  /* mc68881_modrem_post_unit.vhd:194:14  */
  assign n1370 = $signed(n1353) >= $signed(32'b00000000000000000000000000111111);
  /* mc68881_modrem_post_unit.vhd:195:26  */
  assign n1372 = n1353 - 32'b00000000000000000000000000111111;
  /* mc68881_modrem_post_unit.vhd:195:7  */
  assign n1374 = n1359 ? n1372 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:196:20  */
  assign n1376 = $signed(n1374) >= $signed(32'b00000000000000000000000000000111);
  /* mc68881_modrem_post_unit.vhd:199:37  */
  assign n1377 = n1316[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:199:43  */
  assign n1378 = n1374[30:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:199:24  */
  assign n1379 = n1377 << n1378;
  /* mc68881_modrem_post_unit.vhd:199:17  */
  assign n1380 = n1379[6:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:199:9  */
  assign n1382 = n1359 ? n1380 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:196:7  */
  assign n1384 = n1376 ? 7'b0000000 : n1382;
  /* mc68881_modrem_post_unit.vhd:196:7  */
  assign n1386 = n1359 ? n1384 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:202:47  */
  assign n1388 = 32'b00000000000000000000000000111111 - n1353;
  /* mc68881_modrem_post_unit.vhd:202:7  */
  assign n1390 = n1359 ? n1388 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:203:36  */
  assign n1391 = n1316[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:203:42  */
  assign n1392 = n1390[30:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:203:22  */
  assign n1393 = n1391 >> n1392;
  /* mc68881_modrem_post_unit.vhd:203:15  */
  assign n1394 = n1393[6:0];  // trunc
  /* mc68881_modrem_post_unit.vhd:203:7  */
  assign n1396 = n1359 ? n1394 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:194:5  */
  assign n1398 = n1370 ? n1386 : n1396;
  /* mc68881_modrem_post_unit.vhd:194:5  */
  assign n1403 = n1359 ? n1398 : 7'b0000000;
  /* mc68881_modrem_post_unit.vhd:206:5  */
  assign n1406 = n1359 ? n1345 : 1'b0;
  assign n1408 = n1407[6:0]; // extract
  /* mc68881_modrem_post_unit.vhd:207:5  */
  assign n1409 = n1359 ? n1403 : n1408;
  assign n1410 = {n1406, n1409};
  /* mc68881_modrem_post_unit.vhd:208:5  */
  assign n1415 = n1359 ? n1410 : n1362;
  /* mc68881_modrem_post_unit.vhd:330:9  */
  assign n1417 = state_reg == 4'b0101;
  /* mc68881_modrem_post_unit.vhd:339:9  */
  assign n1419 = state_reg == 4'b0110;
  /* mc68881_modrem_post_unit.vhd:348:9  */
  assign n1421 = state_reg == 4'b0111;
  /* mc68881_modrem_post_unit.vhd:352:9  */
  assign n1423 = state_reg == 4'b1000;
  assign n1424 = {n1423, n1421, n1419, n1417, n1298, n940, n926, n912, n66};
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1430 = 4'b0000;
      9'b010000000: n1430 = 4'b1000;
      9'b001000000: n1430 = 4'b0010;
      9'b000100000: n1430 = 4'b0011;
      9'b000010000: n1430 = n1280;
      9'b000001000: n1430 = n932;
      9'b000000100: n1430 = n918;
      9'b000000010: n1430 = n894;
      9'b000000001: n1430 = n54;
      default: n1430 = 4'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1432 = op_reg;
      9'b010000000: n1432 = op_reg;
      9'b001000000: n1432 = op_reg;
      9'b000100000: n1432 = op_reg;
      9'b000010000: n1432 = op_reg;
      9'b000001000: n1432 = op_reg;
      9'b000000100: n1432 = op_reg;
      9'b000000010: n1432 = op_reg;
      9'b000000001: n1432 = n55;
      default: n1432 = 6'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1434 = a_reg;
      9'b010000000: n1434 = a_reg;
      9'b001000000: n1434 = a_reg;
      9'b000100000: n1434 = a_reg;
      9'b000010000: n1434 = a_reg;
      9'b000001000: n1434 = a_reg;
      9'b000000100: n1434 = a_reg;
      9'b000000010: n1434 = a_reg;
      9'b000000001: n1434 = n56;
      default: n1434 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1436 = b_reg;
      9'b010000000: n1436 = b_reg;
      9'b001000000: n1436 = b_reg;
      9'b000100000: n1436 = b_reg;
      9'b000010000: n1436 = b_reg;
      9'b000001000: n1436 = b_reg;
      9'b000000100: n1436 = b_reg;
      9'b000000010: n1436 = b_reg;
      9'b000000001: n1436 = n57;
      default: n1436 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1438 = quotient_reg;
      9'b010000000: n1438 = quotient_reg;
      9'b001000000: n1438 = quotient_reg;
      9'b000100000: n1438 = quotient_reg;
      9'b000010000: n1438 = quotient_reg;
      9'b000001000: n1438 = quotient_reg;
      9'b000000100: n1438 = quotient_reg;
      9'b000000010: n1438 = quotient_reg;
      9'b000000001: n1438 = n58;
      default: n1438 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1440 = rm_reg;
      9'b010000000: n1440 = rm_reg;
      9'b001000000: n1440 = rm_reg;
      9'b000100000: n1440 = rm_reg;
      9'b000010000: n1440 = rm_reg;
      9'b000001000: n1440 = rm_reg;
      9'b000000100: n1440 = rm_reg;
      9'b000000010: n1440 = rm_reg;
      9'b000000001: n1440 = n59;
      default: n1440 = 2'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1442 = rp_reg;
      9'b010000000: n1442 = rp_reg;
      9'b001000000: n1442 = rp_reg;
      9'b000100000: n1442 = rp_reg;
      9'b000010000: n1442 = rp_reg;
      9'b000001000: n1442 = rp_reg;
      9'b000000100: n1442 = rp_reg;
      9'b000000010: n1442 = rp_reg;
      9'b000000001: n1442 = n60;
      default: n1442 = 2'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1444 = n_fp_reg;
      9'b010000000: n1444 = n_fp_reg;
      9'b001000000: n1444 = n_fp_reg;
      9'b000100000: n1444 = mod_add_result_reg;
      9'b000010000: n1444 = n_fp_reg;
      9'b000001000: n1444 = n_fp_reg;
      9'b000000100: n1444 = n_fp_reg;
      9'b000000010: n1444 = n772;
      9'b000000001: n1444 = n_fp_reg;
      default: n1444 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1446 = result_reg;
      9'b010000000: n1446 = mod_add_result_reg;
      9'b001000000: n1446 = result_reg;
      9'b000100000: n1446 = result_reg;
      9'b000010000: n1446 = result_reg;
      9'b000001000: n1446 = result_reg;
      9'b000000100: n1446 = result_reg;
      9'b000000010: n1446 = result_reg;
      9'b000000001: n1446 = result_reg;
      default: n1446 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1448 = quotient_byte_reg;
      9'b010000000: n1448 = quotient_byte_reg;
      9'b001000000: n1448 = quotient_byte_reg;
      9'b000100000: n1448 = n1415;
      9'b000010000: n1448 = n1281;
      9'b000001000: n1448 = quotient_byte_reg;
      9'b000000100: n1448 = quotient_byte_reg;
      9'b000000010: n1448 = n895;
      9'b000000001: n1448 = n62;
      default: n1448 = 8'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1451 = quotient_valid_reg;
      9'b010000000: n1451 = quotient_valid_reg;
      9'b001000000: n1451 = quotient_valid_reg;
      9'b000100000: n1451 = 1'b1;
      9'b000010000: n1451 = n1283;
      9'b000001000: n1451 = quotient_valid_reg;
      9'b000000100: n1451 = quotient_valid_reg;
      9'b000000010: n1451 = n897;
      9'b000000001: n1451 = n64;
      default: n1451 = 1'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1455 = 1'b1;
      9'b010000000: n1455 = 1'b0;
      9'b001000000: n1455 = 1'b0;
      9'b000100000: n1455 = 1'b0;
      9'b000010000: n1455 = 1'b0;
      9'b000001000: n1455 = 1'b0;
      9'b000000100: n1455 = 1'b0;
      9'b000000010: n1455 = 1'b0;
      9'b000000001: n1455 = 1'b0;
      default: n1455 = 1'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1458 = mod_fp_add_a;
      9'b010000000: n1458 = mod_fp_add_a;
      9'b001000000: n1458 = a_reg;
      9'b000100000: n1458 = mod_fp_add_a;
      9'b000010000: n1458 = n1284;
      9'b000001000: n1458 = mod_fp_add_a;
      9'b000000100: n1458 = mod_fp_add_a;
      9'b000000010: n1458 = n898;
      9'b000000001: n1458 = mod_fp_add_a;
      default: n1458 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1460 = mod_fp_add_b;
      9'b010000000: n1460 = mod_fp_add_b;
      9'b001000000: n1460 = mod_mul_result_reg;
      9'b000100000: n1460 = mod_fp_add_b;
      9'b000010000: n1460 = n1286;
      9'b000001000: n1460 = mod_fp_add_b;
      9'b000000100: n1460 = mod_fp_add_b;
      9'b000000010: n1460 = n899;
      9'b000000001: n1460 = mod_fp_add_b;
      default: n1460 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1463 = mod_fp_add_is_sub;
      9'b010000000: n1463 = mod_fp_add_is_sub;
      9'b001000000: n1463 = 1'b1;
      9'b000100000: n1463 = mod_fp_add_is_sub;
      9'b000010000: n1463 = n1287;
      9'b000001000: n1463 = mod_fp_add_is_sub;
      9'b000000100: n1463 = mod_fp_add_is_sub;
      9'b000000010: n1463 = n901;
      9'b000000001: n1463 = mod_fp_add_is_sub;
      default: n1463 = 1'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1465 = mod_fp_add_rm;
      9'b010000000: n1465 = mod_fp_add_rm;
      9'b001000000: n1465 = rm_reg;
      9'b000100000: n1465 = mod_fp_add_rm;
      9'b000010000: n1465 = n1289;
      9'b000001000: n1465 = mod_fp_add_rm;
      9'b000000100: n1465 = mod_fp_add_rm;
      9'b000000010: n1465 = n903;
      9'b000000001: n1465 = mod_fp_add_rm;
      default: n1465 = 2'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1467 = mod_fp_add_rp;
      9'b010000000: n1467 = mod_fp_add_rp;
      9'b001000000: n1467 = rp_reg;
      9'b000100000: n1467 = mod_fp_add_rp;
      9'b000010000: n1467 = n1291;
      9'b000001000: n1467 = mod_fp_add_rp;
      9'b000000100: n1467 = mod_fp_add_rp;
      9'b000000010: n1467 = n905;
      9'b000000001: n1467 = mod_fp_add_rp;
      default: n1467 = 2'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1469 = mod_fp_mul_a;
      9'b010000000: n1469 = mod_fp_mul_a;
      9'b001000000: n1469 = mod_fp_mul_a;
      9'b000100000: n1469 = b_reg;
      9'b000010000: n1469 = n1292;
      9'b000001000: n1469 = mod_fp_mul_a;
      9'b000000100: n1469 = mod_fp_mul_a;
      9'b000000010: n1469 = n906;
      9'b000000001: n1469 = mod_fp_mul_a;
      default: n1469 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1471 = mod_fp_mul_b;
      9'b010000000: n1471 = mod_fp_mul_b;
      9'b001000000: n1471 = mod_fp_mul_b;
      9'b000100000: n1471 = mod_add_result_reg;
      9'b000010000: n1471 = n1293;
      9'b000001000: n1471 = mod_fp_mul_b;
      9'b000000100: n1471 = mod_fp_mul_b;
      9'b000000010: n1471 = n907;
      9'b000000001: n1471 = mod_fp_mul_b;
      default: n1471 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1473 = mod_add_result_reg;
      9'b010000000: n1473 = mod_add_result_reg;
      9'b001000000: n1473 = mod_add_result_reg;
      9'b000100000: n1473 = mod_add_result_reg;
      9'b000010000: n1473 = mod_add_result_reg;
      9'b000001000: n1473 = mod_add_result_reg;
      9'b000000100: n1473 = n919;
      9'b000000010: n1473 = mod_add_result_reg;
      9'b000000001: n1473 = mod_add_result_reg;
      default: n1473 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1475 = mod_mul_result_reg;
      9'b010000000: n1475 = mod_mul_result_reg;
      9'b001000000: n1475 = mod_mul_result_reg;
      9'b000100000: n1475 = mod_mul_result_reg;
      9'b000010000: n1475 = mod_mul_result_reg;
      9'b000001000: n1475 = n933;
      9'b000000100: n1475 = mod_mul_result_reg;
      9'b000000010: n1475 = mod_mul_result_reg;
      9'b000000001: n1475 = mod_mul_result_reg;
      default: n1475 = 80'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1479 = mod_fp_cont_state_reg;
      9'b010000000: n1479 = mod_fp_cont_state_reg;
      9'b001000000: n1479 = 4'b0111;
      9'b000100000: n1479 = 4'b0110;
      9'b000010000: n1479 = n1296;
      9'b000001000: n1479 = mod_fp_cont_state_reg;
      9'b000000100: n1479 = mod_fp_cont_state_reg;
      9'b000000010: n1479 = n910;
      9'b000000001: n1479 = mod_fp_cont_state_reg;
      default: n1479 = 4'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1481 = fp_hold_loaded_reg;
      9'b010000000: n1481 = fp_hold_loaded_reg;
      9'b001000000: n1481 = fp_hold_loaded_reg;
      9'b000100000: n1481 = fp_hold_loaded_reg;
      9'b000010000: n1481 = fp_hold_loaded_reg;
      9'b000001000: n1481 = n935;
      9'b000000100: n1481 = n921;
      9'b000000010: n1481 = fp_hold_loaded_reg;
      9'b000000001: n1481 = fp_hold_loaded_reg;
      default: n1481 = 1'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1484 = 1'b0;
      9'b010000000: n1484 = 1'b0;
      9'b001000000: n1484 = 1'b0;
      9'b000100000: n1484 = 1'b0;
      9'b000010000: n1484 = 1'b0;
      9'b000001000: n1484 = n938;
      9'b000000100: n1484 = 1'b0;
      9'b000000010: n1484 = 1'b0;
      9'b000000001: n1484 = 1'b0;
      default: n1484 = 1'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:254:7  */
  always @*
    case (n1424)
      9'b100000000: n1488 = 1'b0;
      9'b010000000: n1488 = 1'b0;
      9'b001000000: n1488 = 1'b0;
      9'b000100000: n1488 = 1'b0;
      9'b000010000: n1488 = 1'b0;
      9'b000001000: n1488 = 1'b0;
      9'b000000100: n1488 = n924;
      9'b000000010: n1488 = 1'b0;
      9'b000000001: n1488 = 1'b0;
      default: n1488 = 1'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:362:16  */
  assign n1595 = ~reset_n;
  /* mc68881_modrem_post_unit.vhd:370:42  */
  assign n1599 = {12'b0, state_reg};  //  uext
  /* mc68881_modrem_post_unit.vhd:371:42  */
  assign n1602 = {12'b0, mod_fp_cont_state_reg};  //  uext
  /* mc68881_modrem_post_unit.vhd:370:83  */
  assign n1603 = {n1599, n1602};
  /* mc68881_modrem_post_unit.vhd:373:50  */
  assign n1604 = n_fp_reg[31:0]; // extract
  /* mc68881_modrem_post_unit.vhd:374:50  */
  assign n1605 = n_fp_reg[63:32]; // extract
  /* mc68881_modrem_post_unit.vhd:375:50  */
  assign n1606 = n_fp_reg[79:64]; // extract
  /* mc68881_modrem_post_unit.vhd:375:66  */
  assign n1608 = {n1606, 16'b0000000000000000};
  /* mc68881_modrem_post_unit.vhd:368:7  */
  assign n1609 = save_req ? n1603 : shadow_state;
  /* mc68881_modrem_post_unit.vhd:368:7  */
  assign n1610 = save_req ? n1604 : shadow_word1;
  /* mc68881_modrem_post_unit.vhd:368:7  */
  assign n1611 = save_req ? n1605 : shadow_word2;
  /* mc68881_modrem_post_unit.vhd:368:7  */
  assign n1612 = save_req ? n1608 : shadow_word3;
  /* mc68881_modrem_post_unit.vhd:379:11  */
  assign n1614 = restore_addr == 2'b00;
  /* mc68881_modrem_post_unit.vhd:380:11  */
  assign n1616 = restore_addr == 2'b01;
  /* mc68881_modrem_post_unit.vhd:381:11  */
  assign n1618 = restore_addr == 2'b10;
  /* mc68881_modrem_post_unit.vhd:382:11  */
  assign n1620 = restore_addr == 2'b11;
  assign n1621 = {n1620, n1618, n1616, n1614};
  /* mc68881_modrem_post_unit.vhd:378:9  */
  always @*
    case (n1621)
      4'b1000: n1623 = n1609;
      4'b0100: n1623 = n1609;
      4'b0010: n1623 = n1609;
      4'b0001: n1623 = restore_data;
      default: n1623 = 32'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:378:9  */
  always @*
    case (n1621)
      4'b1000: n1625 = n1610;
      4'b0100: n1625 = n1610;
      4'b0010: n1625 = restore_data;
      4'b0001: n1625 = n1610;
      default: n1625 = 32'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:378:9  */
  always @*
    case (n1621)
      4'b1000: n1627 = n1611;
      4'b0100: n1627 = restore_data;
      4'b0010: n1627 = n1611;
      4'b0001: n1627 = n1611;
      default: n1627 = 32'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:378:9  */
  always @*
    case (n1621)
      4'b1000: n1629 = restore_data;
      4'b0100: n1629 = n1612;
      4'b0010: n1629 = n1612;
      4'b0001: n1629 = n1612;
      default: n1629 = 32'bX;
    endcase
  /* mc68881_modrem_post_unit.vhd:377:7  */
  assign n1630 = restore_wr ? n1623 : n1609;
  /* mc68881_modrem_post_unit.vhd:377:7  */
  assign n1631 = restore_wr ? n1625 : n1610;
  /* mc68881_modrem_post_unit.vhd:377:7  */
  assign n1632 = restore_wr ? n1627 : n1611;
  /* mc68881_modrem_post_unit.vhd:377:7  */
  assign n1633 = restore_wr ? n1629 : n1612;
  /* mc68881_modrem_post_unit.vhd:389:44  */
  assign n1647 = {30'b0, save_addr};  //  uext
  /* mc68881_modrem_post_unit.vhd:389:44  */
  assign n1649 = n1647 == 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:389:29  */
  assign n1650 = n1649 ? shadow_state : n1654;
  /* mc68881_modrem_post_unit.vhd:390:44  */
  assign n1651 = {30'b0, save_addr};  //  uext
  /* mc68881_modrem_post_unit.vhd:390:44  */
  assign n1653 = n1651 == 32'b00000000000000000000000000000001;
  /* mc68881_modrem_post_unit.vhd:389:48  */
  assign n1654 = n1653 ? shadow_word1 : n1658;
  /* mc68881_modrem_post_unit.vhd:391:44  */
  assign n1655 = {30'b0, save_addr};  //  uext
  /* mc68881_modrem_post_unit.vhd:391:44  */
  assign n1657 = n1655 == 32'b00000000000000000000000000000010;
  /* mc68881_modrem_post_unit.vhd:390:48  */
  assign n1658 = n1657 ? shadow_word2 : n1662;
  /* mc68881_modrem_post_unit.vhd:392:44  */
  assign n1659 = {30'b0, save_addr};  //  uext
  /* mc68881_modrem_post_unit.vhd:392:44  */
  assign n1661 = n1659 == 32'b00000000000000000000000000000011;
  /* mc68881_modrem_post_unit.vhd:391:48  */
  assign n1662 = n1661 ? shadow_word3 : 32'b00000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:395:30  */
  assign n1666 = state_reg != 4'b0000;
  /* mc68881_modrem_post_unit.vhd:395:15  */
  assign n1667 = n1666 ? 1'b1 : 1'b0;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1669 <= 4'b0000;
    else
      n1669 <= n1430;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1670 <= 6'b000000;
    else
      n1670 <= n1432;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1671 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n1671 <= n1434;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1672 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n1672 <= n1436;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1673 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n1673 <= n1438;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1674 <= 2'b00;
    else
      n1674 <= n1440;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1675 <= 2'b00;
    else
      n1675 <= n1442;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1676 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n1676 <= n1444;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1677 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n1677 <= n1446;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1678 <= 8'b00000000;
    else
      n1678 <= n1448;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1679 <= 1'b0;
    else
      n1679 <= n1451;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1680 <= 1'b0;
    else
      n1680 <= n1455;
  /* mc68881_modrem_post_unit.vhd:223:3  */
  assign n1681 = ~n51;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  assign n1682 = n1681 ? n1458 : mod_fp_add_a;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk)
    n1683 <= n1682;
  initial
    n1683 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:223:3  */
  assign n1684 = ~n51;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  assign n1685 = n1684 ? n1460 : mod_fp_add_b;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk)
    n1686 <= n1685;
  initial
    n1686 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:223:3  */
  assign n1687 = ~n51;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  assign n1688 = n1687 ? n1463 : mod_fp_add_is_sub;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk)
    n1689 <= n1688;
  initial
    n1689 = 1'b0;
  /* mc68881_modrem_post_unit.vhd:223:3  */
  assign n1690 = ~n51;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  assign n1691 = n1690 ? n1465 : mod_fp_add_rm;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk)
    n1692 <= n1691;
  initial
    n1692 = 2'b00;
  /* mc68881_modrem_post_unit.vhd:223:3  */
  assign n1693 = ~n51;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  assign n1694 = n1693 ? n1467 : mod_fp_add_rp;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk)
    n1695 <= n1694;
  initial
    n1695 = 2'b00;
  /* mc68881_modrem_post_unit.vhd:223:3  */
  assign n1696 = ~n51;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  assign n1697 = n1696 ? n1469 : mod_fp_mul_a;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk)
    n1698 <= n1697;
  initial
    n1698 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:223:3  */
  assign n1699 = ~n51;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  assign n1700 = n1699 ? n1471 : mod_fp_mul_b;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk)
    n1701 <= n1700;
  initial
    n1701 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1702 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n1702 <= n1473;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1703 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n1703 <= n1475;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1704 <= 4'b0000;
    else
      n1704 <= n1479;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1705 <= 1'b0;
    else
      n1705 <= n1481;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1706 <= 1'b0;
    else
      n1706 <= n1484;
  /* mc68881_modrem_post_unit.vhd:249:5  */
  always @(posedge clk or posedge n51)
    if (n51)
      n1707 <= 1'b0;
    else
      n1707 <= n1488;
  /* mc68881_modrem_post_unit.vhd:367:5  */
  always @(posedge clk or posedge n1595)
    if (n1595)
      n1708 <= 32'b00000000000000000000000000000000;
    else
      n1708 <= n1630;
  /* mc68881_modrem_post_unit.vhd:367:5  */
  always @(posedge clk or posedge n1595)
    if (n1595)
      n1709 <= 32'b00000000000000000000000000000000;
    else
      n1709 <= n1631;
  /* mc68881_modrem_post_unit.vhd:367:5  */
  always @(posedge clk or posedge n1595)
    if (n1595)
      n1710 <= 32'b00000000000000000000000000000000;
    else
      n1710 <= n1632;
  /* mc68881_modrem_post_unit.vhd:367:5  */
  always @(posedge clk or posedge n1595)
    if (n1595)
      n1711 <= 32'b00000000000000000000000000000000;
    else
      n1711 <= n1633;
  assign n1712 = n1089[79:16]; // extract
  /* mc68881_modrem_post_unit.vhd:173:25  */
  assign n1713 = n1712[n1150 * 1 +: 1]; //(Bmux)
endmodule

