module mc68881_packed_decimal_unit
  (input  clk,
   input  reset_n,
   input  req_valid,
   input  req_encode,
   input  [79:0] req_fp,
   input  [95:0] req_word,
   input  [79:0] req_fallback_fp,
   input  [6:0] req_k,
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
   output rsp_valid,
   output [95:0] rsp_word,
   output [79:0] rsp_fp,
   output rsp_inexact,
   output rsp_invalid,
   output fp_mul_start,
   output [79:0] fp_mul_a_out,
   output [79:0] fp_mul_b_out,
   output fp_add_start,
   output [79:0] fp_add_a_out,
   output [79:0] fp_add_b_out,
   output fp_add_sub_out,
   output [31:0] save_data);
  reg [4:0] state_reg;
  reg [4:0] scale_return_state_reg;
  reg [79:0] req_fp_reg;
  reg [95:0] req_word_reg;
  reg [6:0] req_k_reg;
  reg sign_reg;
  reg [14:0] exp10_reg;
  reg [15:0] bin_exp_reg;
  reg [79:0] work_fp_reg;
  reg [67:0] digits_reg;
  reg [3:0] enc_digit_reg;
  reg [4:0] idx_reg;
  reg [2:0] tune_iter_reg;
  reg [4:0] keep_digits_reg;
  reg inexact_reg;
  reg [13:0] scale_abs_exp_reg;
  wire [11:0] scale_abs_exp_slv;
  reg scale_use_neg_reg;
  reg [3:0] scale_bit_idx_reg;
  reg [63:0] mant_u64_reg;
  reg kround_carry_reg;
  reg [4:0] kround_idx_reg;
  reg rsp_valid_reg;
  reg [95:0] rsp_word_reg;
  reg [79:0] rsp_fp_reg;
  reg rsp_inexact_reg;
  reg rsp_invalid_reg;
  reg [1:0] arith_stage_reg;
  reg [2:0] arith_hold_count_reg;
  reg [2:0] arith_commit_reg;
  reg [1:0] arith_tune_exp_delta_reg;
  reg [79:0] arith_mul_a_reg;
  reg [79:0] arith_mul_b_reg;
  reg [79:0] arith_add_a_reg;
  reg [79:0] arith_add_b_reg;
  reg arith_add_sub_reg;
  reg [79:0] arith_int_arg_reg;
  reg [79:0] arith_mul_res_reg;
  reg [79:0] arith_add_res_reg;
  reg [4:0] arith_int_res_reg;
  reg packed_mul_start_reg;
  reg packed_add_start_reg;
  reg [31:0] shadow_word0;
  reg [31:0] shadow_word1;
  reg [31:0] shadow_word2;
  wire [11:0] n59;
  wire n62;
  wire n63;
  wire n104;
  wire n107;
  wire [31:0] n108;
  wire n110;
  wire [1:0] n112;
  wire [79:0] n113;
  wire [1:0] n114;
  wire [2:0] n116;
  wire [79:0] n117;
  wire n120;
  wire n122;
  wire n124;
  wire n125;
  wire n127;
  wire n128;
  wire n130;
  wire n131;
  wire [31:0] n132;
  wire n134;
  wire [1:0] n136;
  wire [79:0] n137;
  wire [1:0] n138;
  wire [2:0] n140;
  wire [79:0] n141;
  wire n144;
  wire n146;
  wire [31:0] n147;
  wire n149;
  wire [31:0] n150;
  wire [31:0] n152;
  wire [2:0] n153;
  wire n166;
  wire [14:0] n169;
  wire [63:0] n171;
  wire [79:0] n172;
  wire [14:0] n177;
  wire n179;
  wire [14:0] n180;
  wire n182;
  wire n183;
  wire n187;
  wire [31:0] n193;
  wire [14:0] n194;
  wire [30:0] n195;
  wire [31:0] n196;
  wire [31:0] n198;
  wire [31:0] n201;
  wire [31:0] n203;
  wire n206;
  wire n209;
  wire [31:0] n212;
  wire n213;
  wire n215;
  wire n216;
  wire n218;
  wire n220;
  wire n221;
  wire n224;
  wire [31:0] n227;
  wire n228;
  wire n230;
  wire n231;
  wire n233;
  wire n236;
  wire [31:0] n239;
  wire n240;
  wire [31:0] n242;
  wire n243;
  wire n245;
  wire [63:0] n246;
  wire [31:0] n248;
  wire [30:0] n249;
  wire [63:0] n250;
  wire [63:0] n252;
  wire n255;
  wire n256;
  wire n259;
  wire [31:0] n262;
  wire n263;
  wire n265;
  wire n266;
  wire n268;
  wire n271;
  wire [31:0] n274;
  wire n275;
  wire [31:0] n277;
  wire n278;
  wire n280;
  wire [30:0] n281;
  wire [31:0] n282;
  wire [31:0] n284;
  wire n286;
  wire [31:0] n287;
  wire n289;
  wire [31:0] n292;
  wire n293;
  wire n295;
  wire n296;
  wire n298;
  wire [31:0] n303;
  wire n309;
  wire n312;
  wire n316;
  wire [31:0] n320;
  wire n322;
  wire [31:0] n327;
  wire [31:0] n332;
  wire [4:0] n333;
  wire [1:0] n335;
  wire [2:0] n336;
  wire [4:0] n337;
  wire n339;
  wire n341;
  wire n342;
  wire [2:0] n343;
  reg [1:0] n345;
  reg [2:0] n346;
  reg [79:0] n347;
  reg [79:0] n348;
  reg [4:0] n349;
  reg n351;
  reg n353;
  wire n355;
  wire [31:0] n356;
  wire [31:0] n358;
  wire [13:0] n359;
  wire n361;
  wire [31:0] n362;
  wire [31:0] n364;
  wire [3:0] n365;
  wire n367;
  wire [31:0] n368;
  wire [31:0] n369;
  wire [31:0] n370;
  wire [14:0] n371;
  wire n373;
  wire [31:0] n374;
  wire n376;
  wire [31:0] n377;
  wire n379;
  wire [30:0] n380;
  wire [30:0] n382;
  wire [30:0] n384;
  wire [3:0] n385;
  wire n387;
  wire n389;
  wire [4:0] n391;
  wire [31:0] n394;
  wire n396;
  wire [31:0] n397;
  wire [31:0] n399;
  wire [4:0] n400;
  wire [4:0] n403;
  wire [4:0] n404;
  wire n406;
  wire [31:0] n407;
  wire n409;
  wire [31:0] n411;
  wire n417;
  wire n420;
  wire n424;
  wire [31:0] n428;
  wire n430;
  wire [31:0] n435;
  wire [31:0] n440;
  wire n442;
  wire [31:0] n443;
  wire [31:0] n445;
  wire [31:0] n446;
  wire [31:0] n447;
  wire [31:0] n448;
  wire n450;
  wire n452;
  wire [31:0] n454;
  wire [31:0] n456;
  wire [4:0] n457;
  wire [4:0] n460;
  wire [4:0] n461;
  wire n463;
  wire [4:0] n465;
  wire n469;
  wire [6:0] n470;
  reg [4:0] n473;
  reg [14:0] n474;
  reg [79:0] n475;
  reg [67:0] n476;
  reg [3:0] n477;
  reg [4:0] n478;
  reg [4:0] n479;
  reg [13:0] n480;
  reg [3:0] n481;
  reg n482;
  reg [4:0] n483;
  wire [4:0] n488;
  wire [14:0] n489;
  wire [79:0] n490;
  wire [67:0] n491;
  wire [3:0] n492;
  wire [4:0] n493;
  wire [4:0] n494;
  wire [13:0] n495;
  wire [3:0] n496;
  wire n497;
  wire [4:0] n498;
  wire [1:0] n500;
  wire [2:0] n502;
  wire [4:0] n507;
  wire [14:0] n508;
  wire [79:0] n509;
  wire [67:0] n510;
  wire [3:0] n511;
  wire [4:0] n512;
  wire [4:0] n513;
  wire [13:0] n514;
  wire [3:0] n515;
  wire n516;
  wire [4:0] n517;
  wire [1:0] n518;
  wire [2:0] n519;
  wire [2:0] n520;
  wire n525;
  wire n528;
  wire n535;
  wire n536;
  wire n537;
  wire [1:0] n538;
  wire n540;
  wire n541;
  localparam [79:0] n542 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n547;
  wire [67:0] n548;
  wire n550;
  wire [62:0] n552;
  wire [79:0] n553;
  wire [3:0] n555;
  wire [30:0] n561;
  wire [31:0] n562;
  wire n565;
  wire n567;
  wire n568;
  wire n571;
  wire [31:0] n577;
  wire [31:0] n583;
  wire [3:0] n585;
  wire [30:0] n591;
  wire [31:0] n592;
  wire n595;
  wire n597;
  wire n598;
  wire n601;
  wire [31:0] n607;
  wire [31:0] n613;
  wire [3:0] n615;
  wire [30:0] n621;
  wire [31:0] n622;
  wire n625;
  wire n627;
  wire n628;
  wire n631;
  wire [31:0] n637;
  wire [31:0] n643;
  wire [3:0] n645;
  wire [30:0] n651;
  wire [31:0] n652;
  wire n655;
  wire n657;
  wire n658;
  wire n661;
  wire [31:0] n667;
  wire [31:0] n673;
  wire [3:0] n675;
  wire [30:0] n681;
  wire [31:0] n682;
  wire n685;
  wire n687;
  wire n688;
  wire n691;
  wire [31:0] n697;
  wire [31:0] n703;
  wire n705;
  wire n707;
  wire n708;
  wire n710;
  wire n711;
  wire n713;
  wire n714;
  wire n716;
  wire n717;
  wire [31:0] n719;
  wire [31:0] n721;
  wire [31:0] n722;
  wire [31:0] n724;
  wire [31:0] n725;
  wire [31:0] n726;
  wire n727;
  wire [31:0] n728;
  wire [31:0] n729;
  wire [30:0] n730;
  wire [3:0] n731;
  localparam [67:0] n732 = 68'b00000000000000000000000000000000000000000000000000000000000000000000;
  wire n735;
  wire [3:0] n738;
  wire [30:0] n744;
  wire [31:0] n745;
  wire n748;
  wire n750;
  wire n751;
  wire n754;
  wire [31:0] n760;
  wire [31:0] n766;
  wire n768;
  wire n771;
  wire n773;
  wire n776;
  wire [30:0] n778;
  wire [3:0] n779;
  wire [3:0] n780;
  wire [3:0] n781;
  wire n784;
  wire n786;
  wire n787;
  wire n788;
  wire [3:0] n790;
  wire [30:0] n796;
  wire [31:0] n797;
  wire n800;
  wire n802;
  wire n803;
  wire n806;
  wire [31:0] n812;
  wire [31:0] n818;
  wire [31:0] n819;
  wire n821;
  wire n823;
  wire n825;
  wire n827;
  wire n828;
  wire n829;
  wire n830;
  wire n831;
  wire n832;
  wire n833;
  wire [30:0] n834;
  wire [3:0] n835;
  wire [3:0] n836;
  wire [3:0] n837;
  wire n840;
  wire n842;
  wire n843;
  wire n844;
  wire [3:0] n846;
  wire [30:0] n852;
  wire [31:0] n853;
  wire n856;
  wire n858;
  wire n859;
  wire n862;
  wire [31:0] n868;
  wire [31:0] n874;
  wire [31:0] n875;
  wire n877;
  wire n879;
  wire n881;
  wire n883;
  wire n884;
  wire n885;
  wire n886;
  wire n887;
  wire n888;
  wire n889;
  wire [30:0] n890;
  wire [3:0] n891;
  wire [3:0] n892;
  wire [3:0] n893;
  wire n896;
  wire n898;
  wire n899;
  wire n900;
  wire [3:0] n902;
  wire [30:0] n908;
  wire [31:0] n909;
  wire n912;
  wire n914;
  wire n915;
  wire n918;
  wire [31:0] n924;
  wire [31:0] n930;
  wire [31:0] n931;
  wire n933;
  wire n935;
  wire n937;
  wire n939;
  wire n940;
  wire n941;
  wire n942;
  wire n943;
  wire n944;
  wire n945;
  wire [30:0] n946;
  wire [3:0] n947;
  wire [3:0] n948;
  wire [3:0] n949;
  wire n952;
  wire n954;
  wire n955;
  wire n956;
  wire [3:0] n958;
  wire [30:0] n964;
  wire [31:0] n965;
  wire n968;
  wire n970;
  wire n971;
  wire n974;
  wire [31:0] n980;
  wire [31:0] n986;
  wire [31:0] n987;
  wire n989;
  wire n991;
  wire n993;
  wire n995;
  wire n996;
  wire n997;
  wire n998;
  wire n999;
  wire n1000;
  wire n1001;
  wire [30:0] n1002;
  wire [3:0] n1003;
  wire [3:0] n1004;
  wire [3:0] n1005;
  wire n1008;
  wire n1010;
  wire n1011;
  wire n1012;
  wire [3:0] n1014;
  wire [30:0] n1020;
  wire [31:0] n1021;
  wire n1024;
  wire n1026;
  wire n1027;
  wire n1030;
  wire [31:0] n1036;
  wire [31:0] n1042;
  wire [31:0] n1043;
  wire n1045;
  wire n1047;
  wire n1049;
  wire n1051;
  wire n1052;
  wire n1053;
  wire n1054;
  wire n1055;
  wire n1056;
  wire n1057;
  wire [30:0] n1058;
  wire [3:0] n1059;
  wire [3:0] n1060;
  wire [3:0] n1061;
  wire n1064;
  wire n1066;
  wire n1067;
  wire n1068;
  wire [3:0] n1070;
  wire [30:0] n1076;
  wire [31:0] n1077;
  wire n1080;
  wire n1082;
  wire n1083;
  wire n1086;
  wire [31:0] n1092;
  wire [31:0] n1098;
  wire [31:0] n1099;
  wire n1101;
  wire n1103;
  wire n1105;
  wire n1107;
  wire n1108;
  wire n1109;
  wire n1110;
  wire n1111;
  wire n1112;
  wire n1113;
  wire [30:0] n1114;
  wire [3:0] n1115;
  wire [3:0] n1116;
  wire [3:0] n1117;
  wire n1120;
  wire n1122;
  wire n1123;
  wire n1124;
  wire [3:0] n1126;
  wire [30:0] n1132;
  wire [31:0] n1133;
  wire n1136;
  wire n1138;
  wire n1139;
  wire n1142;
  wire [31:0] n1148;
  wire [31:0] n1154;
  wire [31:0] n1155;
  wire n1157;
  wire n1159;
  wire n1161;
  wire n1163;
  wire n1164;
  wire n1165;
  wire n1166;
  wire n1167;
  wire n1168;
  wire n1169;
  wire [30:0] n1170;
  wire [3:0] n1171;
  wire [3:0] n1172;
  wire [3:0] n1173;
  wire n1176;
  wire n1178;
  wire n1179;
  wire n1180;
  wire [3:0] n1182;
  wire [30:0] n1188;
  wire [31:0] n1189;
  wire n1192;
  wire n1194;
  wire n1195;
  wire n1198;
  wire [31:0] n1204;
  wire [31:0] n1210;
  wire [31:0] n1211;
  wire n1213;
  wire n1215;
  wire n1217;
  wire n1219;
  wire n1220;
  wire n1221;
  wire n1222;
  wire n1223;
  wire n1224;
  wire n1225;
  wire [30:0] n1226;
  wire [3:0] n1227;
  wire [3:0] n1228;
  wire [3:0] n1229;
  wire n1232;
  wire n1234;
  wire n1235;
  wire n1236;
  wire [3:0] n1238;
  wire [30:0] n1244;
  wire [31:0] n1245;
  wire n1248;
  wire n1250;
  wire n1251;
  wire n1254;
  wire [31:0] n1260;
  wire [31:0] n1266;
  wire [31:0] n1267;
  wire n1269;
  wire n1271;
  wire n1273;
  wire n1275;
  wire n1276;
  wire n1277;
  wire n1278;
  wire n1279;
  wire n1280;
  wire n1281;
  wire [30:0] n1282;
  wire [3:0] n1283;
  wire [3:0] n1284;
  wire [3:0] n1285;
  wire n1288;
  wire n1290;
  wire n1291;
  wire n1292;
  wire [3:0] n1294;
  wire [30:0] n1300;
  wire [31:0] n1301;
  wire n1304;
  wire n1306;
  wire n1307;
  wire n1310;
  wire [31:0] n1316;
  wire [31:0] n1322;
  wire [31:0] n1323;
  wire n1325;
  wire n1327;
  wire n1329;
  wire n1331;
  wire n1332;
  wire n1333;
  wire n1334;
  wire n1335;
  wire n1336;
  wire n1337;
  wire [30:0] n1338;
  wire [3:0] n1339;
  wire [3:0] n1340;
  wire [3:0] n1341;
  wire n1344;
  wire n1346;
  wire n1347;
  wire n1348;
  wire [3:0] n1350;
  wire [30:0] n1356;
  wire [31:0] n1357;
  wire n1360;
  wire n1362;
  wire n1363;
  wire n1366;
  wire [31:0] n1372;
  wire [31:0] n1378;
  wire [31:0] n1379;
  wire n1381;
  wire n1383;
  wire n1385;
  wire n1387;
  wire n1388;
  wire n1389;
  wire n1390;
  wire n1391;
  wire n1392;
  wire n1393;
  wire [30:0] n1394;
  wire [3:0] n1395;
  wire [3:0] n1396;
  wire [3:0] n1397;
  wire n1400;
  wire n1402;
  wire n1403;
  wire n1404;
  wire [3:0] n1406;
  wire [30:0] n1412;
  wire [31:0] n1413;
  wire n1416;
  wire n1418;
  wire n1419;
  wire n1422;
  wire [31:0] n1428;
  wire [31:0] n1434;
  wire [31:0] n1435;
  wire n1437;
  wire n1439;
  wire n1441;
  wire n1443;
  wire n1444;
  wire n1445;
  wire n1446;
  wire n1447;
  wire n1448;
  wire n1449;
  wire [30:0] n1450;
  wire [3:0] n1451;
  wire [3:0] n1452;
  wire [3:0] n1453;
  wire n1456;
  wire n1458;
  wire n1459;
  wire n1460;
  wire [3:0] n1462;
  wire [30:0] n1468;
  wire [31:0] n1469;
  wire n1472;
  wire n1474;
  wire n1475;
  wire n1478;
  wire [31:0] n1484;
  wire [31:0] n1490;
  wire [31:0] n1491;
  wire n1493;
  wire n1495;
  wire n1497;
  wire n1499;
  wire n1500;
  wire n1501;
  wire n1502;
  wire n1503;
  wire n1504;
  wire n1505;
  wire [30:0] n1506;
  wire [3:0] n1507;
  wire [3:0] n1508;
  wire [3:0] n1509;
  wire n1512;
  wire n1514;
  wire n1515;
  wire n1516;
  wire [3:0] n1518;
  wire [30:0] n1524;
  wire [31:0] n1525;
  wire n1528;
  wire n1530;
  wire n1531;
  wire n1534;
  wire [31:0] n1540;
  wire [31:0] n1546;
  wire [31:0] n1547;
  wire n1549;
  wire n1551;
  wire n1553;
  wire n1555;
  wire n1556;
  wire n1557;
  wire n1558;
  wire n1559;
  wire n1560;
  wire n1561;
  wire [30:0] n1562;
  wire [3:0] n1563;
  wire [3:0] n1564;
  wire [3:0] n1565;
  wire [3:0] n1566;
  wire n1568;
  wire n1570;
  wire n1571;
  wire n1572;
  wire [3:0] n1574;
  wire [30:0] n1580;
  wire [31:0] n1581;
  wire n1584;
  wire n1586;
  wire n1587;
  wire n1590;
  wire [31:0] n1596;
  wire [31:0] n1602;
  wire [31:0] n1603;
  wire n1605;
  wire n1607;
  wire n1609;
  wire n1612;
  wire n1613;
  wire n1615;
  wire n1616;
  wire [30:0] n1618;
  wire [3:0] n1619;
  wire [3:0] n1620;
  wire n1622;
  wire n1624;
  wire n1625;
  wire n1626;
  wire n1628;
  wire n1629;
  localparam [79:0] n1630 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire [78:0] n1631;
  wire [79:0] n1632;
  wire [67:0] n1633;
  wire [67:0] n1634;
  wire [3:0] n1635;
  wire [30:0] n1636;
  wire [63:0] n1637;
  wire [14:0] n1638;
  wire [4:0] n1640;
  wire [14:0] n1641;
  wire [67:0] n1643;
  wire [4:0] n1646;
  wire [63:0] n1647;
  wire n1650;
  wire [95:0] n1651;
  wire [79:0] n1652;
  wire n1654;
  wire n1656;
  wire [4:0] n1659;
  wire [14:0] n1660;
  wire [67:0] n1662;
  wire [4:0] n1664;
  wire [63:0] n1665;
  wire n1667;
  wire [95:0] n1668;
  wire [79:0] n1669;
  wire n1671;
  wire n1673;
  wire [4:0] n1675;
  wire [14:0] n1676;
  wire [67:0] n1678;
  wire [4:0] n1680;
  wire [63:0] n1681;
  wire n1683;
  wire [95:0] n1684;
  wire [79:0] n1685;
  wire n1687;
  wire n1689;
  wire [4:0] n1696;
  wire [14:0] n1697;
  wire [67:0] n1699;
  wire [4:0] n1701;
  wire [63:0] n1702;
  wire n1704;
  wire [95:0] n1705;
  wire [79:0] n1706;
  wire n1708;
  wire n1710;
  wire [4:0] n1722;
  wire n1723;
  wire [14:0] n1724;
  wire [67:0] n1726;
  wire [4:0] n1729;
  wire [63:0] n1731;
  wire n1733;
  wire [95:0] n1734;
  wire [79:0] n1735;
  wire n1736;
  wire n1737;
  wire [4:0] n1748;
  wire [79:0] n1749;
  wire [95:0] n1750;
  wire [6:0] n1751;
  wire n1752;
  wire [14:0] n1753;
  wire [67:0] n1754;
  wire [3:0] n1756;
  wire [4:0] n1757;
  wire [2:0] n1759;
  wire n1761;
  wire [63:0] n1762;
  wire n1764;
  wire [95:0] n1765;
  wire [79:0] n1766;
  wire n1767;
  wire n1768;
  wire n1780;
  localparam [95:0] n1781 = 96'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire [94:0] n1782;
  wire n1794;
  wire [14:0] n1797;
  wire [63:0] n1799;
  wire [79:0] n1800;
  wire [14:0] n1801;
  wire n1803;
  wire [63:0] n1804;
  wire n1806;
  wire n1807;
  wire [95:0] n1808;
  wire n1820;
  wire [14:0] n1823;
  wire [63:0] n1825;
  wire [79:0] n1826;
  localparam [63:0] n1829 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1830;
  wire [14:0] n1831;
  wire n1833;
  wire [63:0] n1834;
  wire n1836;
  wire [63:0] n1837;
  wire [63:0] n1838;
  wire n1839;
  wire n1840;
  wire n1841;
  wire [75:0] n1847;
  wire n1848;
  wire [95:0] n1849;
  wire n1861;
  wire [14:0] n1864;
  wire [63:0] n1866;
  wire [79:0] n1867;
  wire [14:0] n1868;
  wire n1870;
  wire n1882;
  wire [14:0] n1885;
  wire [63:0] n1887;
  wire [79:0] n1888;
  localparam [63:0] n1891 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1892;
  wire [14:0] n1893;
  wire n1895;
  wire [63:0] n1896;
  wire n1898;
  wire [63:0] n1899;
  wire [63:0] n1900;
  wire n1901;
  wire n1902;
  wire n1903;
  wire n1904;
  wire n1905;
  wire [7:0] n1913;
  wire n1914;
  wire [95:0] n1915;
  wire [78:0] n1917;
  wire [79:0] n1918;
  wire [14:0] n1919;
  wire [30:0] n1920;
  wire [31:0] n1921;
  wire [31:0] n1923;
  wire [79:0] n1924;
  wire [14:0] n1925;
  wire n1927;
  wire [79:0] n1929;
  wire n1930;
  wire n1933;
  wire n1936;
  wire [31:0] n1940;
  wire [79:0] n1942;
  wire n1943;
  wire n1945;
  wire n1947;
  wire n1948;
  wire n1949;
  wire [31:0] n1951;
  wire [31:0] n1952;
  wire [79:0] n1953;
  wire n1954;
  wire n1956;
  wire n1958;
  wire n1959;
  wire n1960;
  wire [31:0] n1962;
  wire [31:0] n1963;
  wire [79:0] n1964;
  wire n1965;
  wire n1967;
  wire n1969;
  wire n1970;
  wire n1971;
  wire [31:0] n1973;
  wire [31:0] n1974;
  wire [79:0] n1975;
  wire n1976;
  wire n1978;
  wire n1980;
  wire n1981;
  wire n1982;
  wire [31:0] n1984;
  wire [31:0] n1985;
  wire [79:0] n1986;
  wire n1987;
  wire n1989;
  wire n1991;
  wire n1992;
  wire n1993;
  wire [31:0] n1995;
  wire [31:0] n1996;
  wire [79:0] n1997;
  wire n1998;
  wire n2000;
  wire n2002;
  wire n2003;
  wire n2004;
  wire [31:0] n2006;
  wire [31:0] n2007;
  wire [79:0] n2008;
  wire n2009;
  wire n2011;
  wire n2013;
  wire n2014;
  wire n2015;
  wire [31:0] n2017;
  wire [31:0] n2018;
  wire [79:0] n2019;
  wire n2020;
  wire n2022;
  wire n2024;
  wire n2025;
  wire n2026;
  wire [31:0] n2028;
  wire [31:0] n2029;
  wire [79:0] n2030;
  wire n2031;
  wire n2033;
  wire n2035;
  wire n2036;
  wire n2037;
  wire [31:0] n2039;
  wire [31:0] n2040;
  wire [79:0] n2041;
  wire n2042;
  wire n2044;
  wire n2046;
  wire n2047;
  wire n2048;
  wire [31:0] n2050;
  wire [31:0] n2051;
  wire [79:0] n2052;
  wire n2053;
  wire n2055;
  wire n2057;
  wire n2058;
  wire n2059;
  wire [31:0] n2061;
  wire [31:0] n2062;
  wire [79:0] n2063;
  wire n2064;
  wire n2066;
  wire n2068;
  wire n2069;
  wire n2070;
  wire [31:0] n2072;
  wire [31:0] n2073;
  wire [79:0] n2074;
  wire n2075;
  wire n2077;
  wire n2079;
  wire n2080;
  wire n2081;
  wire [31:0] n2083;
  wire [31:0] n2084;
  wire [79:0] n2085;
  wire n2086;
  wire n2088;
  wire n2090;
  wire n2091;
  wire n2092;
  wire [31:0] n2094;
  wire [31:0] n2095;
  wire [79:0] n2096;
  wire n2097;
  wire n2099;
  wire n2101;
  wire n2102;
  wire n2103;
  wire [31:0] n2105;
  wire [31:0] n2106;
  wire [79:0] n2107;
  wire n2108;
  wire n2110;
  wire n2112;
  wire n2113;
  wire n2114;
  wire [31:0] n2116;
  wire [31:0] n2117;
  wire [79:0] n2118;
  wire n2119;
  wire n2121;
  wire n2123;
  wire n2124;
  wire n2125;
  wire [31:0] n2127;
  wire [31:0] n2128;
  wire [79:0] n2129;
  wire n2130;
  wire n2132;
  wire n2134;
  wire n2135;
  wire n2136;
  wire [31:0] n2138;
  wire [31:0] n2139;
  wire [79:0] n2140;
  wire n2141;
  wire n2143;
  wire n2145;
  wire n2146;
  wire n2147;
  wire [31:0] n2149;
  wire [31:0] n2150;
  wire [79:0] n2151;
  wire n2152;
  wire n2154;
  wire n2156;
  wire n2157;
  wire n2158;
  wire [31:0] n2160;
  wire [31:0] n2161;
  wire [79:0] n2162;
  wire n2163;
  wire n2165;
  wire n2167;
  wire n2168;
  wire n2169;
  wire [31:0] n2171;
  wire [31:0] n2172;
  wire [79:0] n2173;
  wire n2174;
  wire n2176;
  wire n2178;
  wire n2179;
  wire n2180;
  wire [31:0] n2182;
  wire [31:0] n2183;
  wire [79:0] n2184;
  wire n2185;
  wire n2187;
  wire n2189;
  wire n2190;
  wire n2191;
  wire [31:0] n2193;
  wire [31:0] n2194;
  wire [79:0] n2195;
  wire n2196;
  wire n2198;
  wire n2200;
  wire n2201;
  wire n2202;
  wire [31:0] n2204;
  wire [31:0] n2205;
  wire [79:0] n2206;
  wire n2207;
  wire n2209;
  wire n2211;
  wire n2212;
  wire n2213;
  wire [31:0] n2215;
  wire [31:0] n2216;
  wire [79:0] n2217;
  wire n2218;
  wire n2220;
  wire n2222;
  wire n2223;
  wire n2224;
  wire [31:0] n2226;
  wire [31:0] n2227;
  wire [79:0] n2228;
  wire n2229;
  wire n2231;
  wire n2233;
  wire n2234;
  wire n2235;
  wire [31:0] n2237;
  wire [31:0] n2238;
  wire [79:0] n2239;
  wire n2240;
  wire n2242;
  wire n2244;
  wire n2245;
  wire n2246;
  wire [31:0] n2248;
  wire [31:0] n2249;
  wire [79:0] n2250;
  wire n2251;
  wire n2253;
  wire n2255;
  wire n2256;
  wire n2257;
  wire [31:0] n2259;
  wire [31:0] n2260;
  wire [79:0] n2261;
  wire n2262;
  wire n2264;
  wire n2266;
  wire n2267;
  wire n2268;
  wire [31:0] n2270;
  wire [31:0] n2271;
  wire [79:0] n2272;
  wire n2273;
  wire n2275;
  wire n2277;
  wire n2278;
  wire n2279;
  wire [31:0] n2281;
  wire [31:0] n2282;
  wire [79:0] n2283;
  wire n2284;
  wire n2286;
  wire n2288;
  wire n2289;
  wire n2290;
  wire [31:0] n2292;
  wire [31:0] n2293;
  wire [79:0] n2294;
  wire n2295;
  wire n2297;
  wire n2299;
  wire n2300;
  wire n2301;
  wire [31:0] n2303;
  wire [31:0] n2304;
  wire [79:0] n2305;
  wire n2306;
  wire n2308;
  wire n2310;
  wire n2311;
  wire n2312;
  wire [31:0] n2314;
  wire [31:0] n2315;
  wire [79:0] n2316;
  wire n2317;
  wire n2319;
  wire n2321;
  wire n2322;
  wire n2323;
  wire [31:0] n2325;
  wire [31:0] n2326;
  wire [79:0] n2327;
  wire n2328;
  wire n2330;
  wire n2332;
  wire n2333;
  wire n2334;
  wire [31:0] n2336;
  wire [31:0] n2337;
  wire [79:0] n2338;
  wire n2339;
  wire n2341;
  wire n2343;
  wire n2344;
  wire n2345;
  wire [31:0] n2347;
  wire [31:0] n2348;
  wire [79:0] n2349;
  wire n2350;
  wire n2352;
  wire n2354;
  wire n2355;
  wire n2356;
  wire [31:0] n2358;
  wire [31:0] n2359;
  wire [79:0] n2360;
  wire n2361;
  wire n2363;
  wire n2365;
  wire n2366;
  wire n2367;
  wire [31:0] n2369;
  wire [31:0] n2370;
  wire [79:0] n2371;
  wire n2372;
  wire n2374;
  wire n2376;
  wire n2377;
  wire n2378;
  wire [31:0] n2380;
  wire [31:0] n2381;
  wire [79:0] n2382;
  wire n2383;
  wire n2385;
  wire n2387;
  wire n2388;
  wire n2389;
  wire [31:0] n2391;
  wire [31:0] n2392;
  wire [79:0] n2393;
  wire n2394;
  wire n2396;
  wire n2398;
  wire n2399;
  wire n2400;
  wire [31:0] n2402;
  wire [31:0] n2403;
  wire [79:0] n2404;
  wire n2405;
  wire n2407;
  wire n2409;
  wire n2410;
  wire n2411;
  wire [31:0] n2413;
  wire [31:0] n2414;
  wire [79:0] n2415;
  wire n2416;
  wire n2418;
  wire n2420;
  wire n2421;
  wire n2422;
  wire [31:0] n2424;
  wire [31:0] n2425;
  wire [79:0] n2426;
  wire n2427;
  wire n2429;
  wire n2431;
  wire n2432;
  wire n2433;
  wire [31:0] n2435;
  wire [31:0] n2436;
  wire [79:0] n2437;
  wire n2438;
  wire n2440;
  wire n2442;
  wire n2443;
  wire n2444;
  wire [31:0] n2446;
  wire [31:0] n2447;
  wire [79:0] n2448;
  wire n2449;
  wire n2451;
  wire n2453;
  wire n2454;
  wire n2455;
  wire [31:0] n2457;
  wire [31:0] n2458;
  wire [79:0] n2459;
  wire n2460;
  wire n2462;
  wire n2464;
  wire n2465;
  wire n2466;
  wire [31:0] n2468;
  wire [31:0] n2469;
  wire [79:0] n2470;
  wire n2471;
  wire n2473;
  wire n2475;
  wire n2476;
  wire n2477;
  wire [31:0] n2479;
  wire [31:0] n2480;
  wire [79:0] n2481;
  wire n2482;
  wire n2484;
  wire n2486;
  wire n2487;
  wire n2488;
  wire [31:0] n2490;
  wire [31:0] n2491;
  wire [79:0] n2492;
  wire n2493;
  wire n2495;
  wire n2497;
  wire n2498;
  wire n2499;
  wire [31:0] n2501;
  wire [31:0] n2502;
  wire [79:0] n2503;
  wire n2504;
  wire n2506;
  wire n2508;
  wire n2509;
  wire n2510;
  wire [31:0] n2512;
  wire [31:0] n2513;
  wire [79:0] n2514;
  wire n2515;
  wire n2517;
  wire n2519;
  wire n2520;
  wire n2521;
  wire [31:0] n2523;
  wire [31:0] n2524;
  wire [79:0] n2525;
  wire n2526;
  wire n2528;
  wire n2530;
  wire n2531;
  wire n2532;
  wire [31:0] n2534;
  wire [31:0] n2535;
  wire [79:0] n2536;
  wire n2537;
  wire n2539;
  wire n2541;
  wire n2542;
  wire n2543;
  wire [31:0] n2545;
  wire [31:0] n2546;
  wire [79:0] n2547;
  wire n2548;
  wire n2550;
  wire n2552;
  wire n2553;
  wire n2554;
  wire [31:0] n2556;
  wire [31:0] n2557;
  wire [79:0] n2558;
  wire n2559;
  wire n2561;
  wire n2563;
  wire n2564;
  wire n2565;
  wire [31:0] n2567;
  wire [31:0] n2568;
  wire [79:0] n2569;
  wire n2570;
  wire n2572;
  wire n2574;
  wire n2575;
  wire n2576;
  wire [31:0] n2578;
  wire [31:0] n2579;
  wire [79:0] n2580;
  wire n2581;
  wire n2583;
  wire n2585;
  wire n2586;
  wire n2587;
  wire [31:0] n2589;
  wire [31:0] n2590;
  wire [79:0] n2591;
  wire n2592;
  wire n2594;
  wire n2596;
  wire n2597;
  wire n2598;
  wire [31:0] n2600;
  wire [31:0] n2601;
  wire [79:0] n2602;
  wire n2603;
  wire n2605;
  wire n2607;
  wire n2608;
  wire n2609;
  wire [31:0] n2611;
  wire [31:0] n2612;
  wire [79:0] n2613;
  wire n2614;
  wire n2616;
  wire n2618;
  wire n2619;
  wire n2620;
  wire [31:0] n2622;
  wire [31:0] n2623;
  wire [79:0] n2624;
  wire n2625;
  wire n2627;
  wire n2630;
  wire [31:0] n2633;
  wire [31:0] n2634;
  wire [31:0] n2635;
  wire [15:0] n2636;
  wire [79:0] n2637;
  wire [4:0] n2640;
  wire [15:0] n2641;
  wire [79:0] n2642;
  wire n2645;
  wire [95:0] n2646;
  wire [79:0] n2647;
  wire n2649;
  wire n2651;
  wire [4:0] n2662;
  wire [15:0] n2663;
  wire [79:0] n2664;
  wire n2666;
  wire [95:0] n2667;
  wire [79:0] n2668;
  wire n2670;
  wire n2672;
  wire [4:0] n2680;
  wire [15:0] n2681;
  wire [79:0] n2682;
  wire n2684;
  wire [95:0] n2685;
  wire [79:0] n2686;
  wire n2688;
  wire n2690;
  wire n2701;
  wire [31:0] n2702;
  wire n2704;
  wire [31:0] n2705;
  wire [31:0] n2707;
  wire [31:0] n2709;
  wire [14:0] n2710;
  wire [31:0] n2711;
  wire [31:0] n2712;
  wire [31:0] n2714;
  wire [31:0] n2716;
  wire [31:0] n2718;
  wire [31:0] n2719;
  wire [14:0] n2720;
  wire [14:0] n2721;
  wire n2723;
  wire [31:0] n2724;
  wire [31:0] n2725;
  wire n2727;
  wire n2729;
  wire [31:0] n2730;
  wire [30:0] n2731;
  wire [13:0] n2732;
  wire [30:0] n2733;
  wire [13:0] n2734;
  wire [13:0] n2735;
  wire n2738;
  wire [4:0] n2741;
  wire [4:0] n2743;
  wire [13:0] n2744;
  wire n2745;
  wire [3:0] n2747;
  wire n2749;
  wire [31:0] n2750;
  wire n2752;
  wire [79:0] n2755;
  wire [4:0] n2757;
  wire [3:0] n2759;
  wire [79:0] n2764;
  wire [79:0] n2766;
  wire [2:0] n2769;
  wire n2771;
  wire [31:0] n2772;
  wire n2774;
  wire [30:0] n2778;
  wire n2785;
  wire n2788;
  wire n2791;
  wire n2794;
  wire n2797;
  wire n2800;
  wire n2803;
  wire n2806;
  wire n2809;
  wire n2812;
  wire n2815;
  wire [10:0] n2817;
  reg [79:0] n2818;
  wire n2821;
  wire [79:0] n2827;
  wire [79:0] n2833;
  wire n2835;
  wire [79:0] n2841;
  wire n2843;
  wire [79:0] n2849;
  wire n2851;
  wire [79:0] n2857;
  wire n2859;
  wire [79:0] n2865;
  wire n2867;
  wire [79:0] n2873;
  wire n2875;
  wire [79:0] n2881;
  wire n2883;
  wire [79:0] n2889;
  wire n2891;
  wire [79:0] n2897;
  wire n2899;
  wire [79:0] n2905;
  wire n2907;
  wire [79:0] n2913;
  wire n2915;
  wire [79:0] n2921;
  wire [10:0] n2922;
  reg [79:0] n2925;
  wire [79:0] n2928;
  wire [31:0] n2929;
  wire [31:0] n2931;
  wire [3:0] n2932;
  wire [3:0] n2933;
  wire [79:0] n2938;
  wire [79:0] n2940;
  wire [2:0] n2943;
  wire [4:0] n2944;
  wire [3:0] n2945;
  wire [79:0] n2949;
  wire [79:0] n2951;
  wire [2:0] n2953;
  wire n2955;
  wire [78:0] n2968;
  wire [79:0] n2969;
  wire n2974;
  wire n2976;
  wire n2977;
  wire n2981;
  wire [31:0] n2985;
  wire n2988;
  wire [31:0] n2991;
  wire n2993;
  wire [31:0] n2998;
  wire n3010;
  wire [14:0] n3013;
  wire [63:0] n3015;
  wire [79:0] n3016;
  localparam [79:0] n3023 = 80'b01000000000000101010000000000000000000000000000000000000000000000000000000000000;
  wire n3024;
  localparam [79:0] n3027 = 80'b01000000000000101010000000000000000000000000000000000000000000000000000000000000;
  wire [14:0] n3028;
  localparam [79:0] n3030 = 80'b01000000000000101010000000000000000000000000000000000000000000000000000000000000;
  wire [63:0] n3031;
  wire [79:0] n3032;
  wire [14:0] n3033;
  wire [14:0] n3034;
  wire n3035;
  wire [14:0] n3037;
  wire [14:0] n3038;
  wire n3039;
  wire [63:0] n3041;
  wire [63:0] n3042;
  wire n3043;
  wire [63:0] n3045;
  wire [63:0] n3046;
  wire n3047;
  wire [31:0] n3050;
  wire [31:0] n3051;
  wire [31:0] n3052;
  wire [31:0] n3053;
  wire [31:0] n3055;
  wire n3057;
  wire [31:0] n3058;
  wire n3060;
  wire [31:0] n3063;
  wire n3064;
  wire n3066;
  wire n3067;
  wire n3069;
  wire [31:0] n3074;
  wire n3076;
  wire [78:0] n3089;
  wire [79:0] n3090;
  wire n3095;
  wire n3097;
  wire n3098;
  wire n3102;
  wire [31:0] n3106;
  wire n3109;
  wire [31:0] n3112;
  wire n3114;
  wire [31:0] n3119;
  wire n3131;
  wire [14:0] n3134;
  wire [63:0] n3136;
  wire [79:0] n3137;
  localparam [79:0] n3144 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  wire n3145;
  localparam [79:0] n3148 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  wire [14:0] n3149;
  localparam [79:0] n3151 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  wire [63:0] n3152;
  wire [79:0] n3153;
  wire [14:0] n3154;
  wire [14:0] n3155;
  wire n3156;
  wire [14:0] n3158;
  wire [14:0] n3159;
  wire n3160;
  wire [63:0] n3162;
  wire [63:0] n3163;
  wire n3164;
  wire [63:0] n3166;
  wire [63:0] n3167;
  wire n3168;
  wire [31:0] n3171;
  wire [31:0] n3172;
  wire [31:0] n3173;
  wire [31:0] n3174;
  wire [31:0] n3176;
  wire n3178;
  wire [31:0] n3179;
  wire n3181;
  wire [31:0] n3184;
  wire n3185;
  wire n3187;
  wire n3188;
  wire n3190;
  wire [31:0] n3195;
  wire n3197;
  wire n3200;
  wire [79:0] n3205;
  wire [79:0] n3208;
  wire [31:0] n3211;
  wire [2:0] n3214;
  wire n3216;
  wire [79:0] n3220;
  wire [79:0] n3222;
  wire [31:0] n3224;
  wire [2:0] n3226;
  wire [31:0] n3227;
  wire n3229;
  wire [31:0] n3230;
  wire [31:0] n3232;
  wire [2:0] n3233;
  wire [4:0] n3235;
  wire [4:0] n3237;
  wire [2:0] n3238;
  wire [4:0] n3240;
  wire [4:0] n3242;
  wire [2:0] n3243;
  wire n3245;
  wire n3247;
  wire [31:0] n3249;
  wire n3262;
  wire n3266;
  wire n3270;
  wire [79:0] n3272;
  wire n3274;
  wire n3277;
  wire [31:0] n3278;
  wire [30:0] n3279;
  wire [30:0] n3281;
  wire [30:0] n3282;
  wire [30:0] n3284;
  wire [30:0] n3285;
  wire n3287;
  wire [30:0] n3289;
  wire n3292;
  wire [30:0] n3295;
  wire [31:0] n3298;
  wire n3300;
  wire n3302;
  wire n3305;
  wire n3306;
  wire n3308;
  wire [31:0] n3310;
  wire [31:0] n3312;
  wire [30:0] n3313;
  wire [30:0] n3314;
  wire [31:0] n3317;
  wire n3318;
  wire n3319;
  wire [31:0] n3320;
  wire n3322;
  wire n3324;
  wire n3326;
  wire n3327;
  wire n3328;
  wire [31:0] n3329;
  wire [31:0] n3331;
  wire [30:0] n3332;
  wire [30:0] n3333;
  wire [31:0] n3335;
  wire [31:0] n3336;
  wire n3337;
  wire n3338;
  wire [31:0] n3339;
  wire n3341;
  wire n3343;
  wire n3345;
  wire n3346;
  wire n3347;
  wire [31:0] n3348;
  wire [31:0] n3350;
  wire [30:0] n3351;
  wire [30:0] n3352;
  wire [31:0] n3354;
  wire [31:0] n3355;
  wire n3356;
  wire n3357;
  wire [31:0] n3358;
  wire n3360;
  wire n3362;
  wire n3364;
  wire n3365;
  wire n3366;
  wire [31:0] n3367;
  wire [31:0] n3369;
  wire [30:0] n3370;
  wire [30:0] n3371;
  wire [31:0] n3373;
  wire [31:0] n3374;
  wire n3375;
  wire n3376;
  wire [31:0] n3377;
  wire n3379;
  wire n3381;
  wire n3383;
  wire n3384;
  wire n3385;
  wire [31:0] n3386;
  wire [31:0] n3388;
  wire [30:0] n3389;
  wire [30:0] n3390;
  wire [31:0] n3392;
  wire [31:0] n3393;
  wire n3394;
  wire n3395;
  wire [31:0] n3396;
  wire n3398;
  wire n3400;
  wire n3402;
  wire n3403;
  wire n3404;
  wire [31:0] n3405;
  wire [31:0] n3407;
  wire [30:0] n3408;
  wire [30:0] n3409;
  wire [31:0] n3411;
  wire [31:0] n3412;
  wire n3413;
  wire n3414;
  wire [31:0] n3415;
  wire n3417;
  wire n3419;
  wire n3421;
  wire n3422;
  wire n3423;
  wire [31:0] n3424;
  wire [31:0] n3426;
  wire [30:0] n3427;
  wire [30:0] n3428;
  wire [31:0] n3430;
  wire [31:0] n3431;
  wire n3432;
  wire n3433;
  wire [31:0] n3434;
  wire n3436;
  wire n3438;
  wire n3440;
  wire n3441;
  wire n3442;
  wire [31:0] n3443;
  wire [31:0] n3445;
  wire [30:0] n3446;
  wire [30:0] n3447;
  wire [31:0] n3449;
  wire [31:0] n3450;
  wire n3451;
  wire n3452;
  wire [31:0] n3453;
  wire n3455;
  wire n3457;
  wire n3459;
  wire n3460;
  wire n3461;
  wire [31:0] n3462;
  wire [31:0] n3464;
  wire [30:0] n3465;
  wire [30:0] n3466;
  wire [31:0] n3468;
  wire [31:0] n3469;
  wire n3470;
  wire n3471;
  wire [31:0] n3472;
  wire n3474;
  wire n3476;
  wire n3478;
  wire n3479;
  wire n3480;
  wire [31:0] n3481;
  wire [31:0] n3483;
  wire [30:0] n3484;
  wire [30:0] n3485;
  wire [31:0] n3487;
  wire [31:0] n3488;
  wire n3489;
  wire n3490;
  wire [31:0] n3491;
  wire n3493;
  wire n3495;
  wire n3497;
  wire n3498;
  wire n3499;
  wire [31:0] n3500;
  wire [31:0] n3502;
  wire [30:0] n3503;
  wire [30:0] n3504;
  wire [31:0] n3506;
  wire [31:0] n3507;
  wire n3508;
  wire n3509;
  wire [31:0] n3510;
  wire n3512;
  wire n3514;
  wire n3516;
  wire n3517;
  wire n3518;
  wire [31:0] n3519;
  wire [31:0] n3521;
  wire [30:0] n3522;
  wire [30:0] n3523;
  wire [31:0] n3525;
  wire [31:0] n3526;
  wire n3527;
  wire n3528;
  wire [31:0] n3529;
  wire n3531;
  wire n3533;
  wire n3535;
  wire n3536;
  wire n3537;
  wire [31:0] n3538;
  wire [31:0] n3540;
  wire [30:0] n3541;
  wire [30:0] n3542;
  wire [31:0] n3544;
  wire [31:0] n3545;
  wire n3546;
  wire n3547;
  wire [31:0] n3548;
  wire n3550;
  wire n3552;
  wire n3554;
  wire n3555;
  wire n3556;
  wire [31:0] n3557;
  wire [31:0] n3559;
  wire [30:0] n3560;
  wire [30:0] n3561;
  wire [31:0] n3563;
  wire [31:0] n3564;
  wire n3565;
  wire n3566;
  wire [31:0] n3567;
  wire n3569;
  wire n3571;
  wire n3573;
  wire n3574;
  wire n3575;
  wire [31:0] n3576;
  wire [31:0] n3578;
  wire [30:0] n3579;
  wire [30:0] n3580;
  wire [31:0] n3582;
  wire [31:0] n3583;
  wire n3584;
  wire n3585;
  wire [31:0] n3586;
  wire n3588;
  wire n3590;
  wire n3592;
  wire n3593;
  wire n3594;
  wire [31:0] n3595;
  wire [31:0] n3597;
  wire [30:0] n3598;
  wire [30:0] n3599;
  wire [31:0] n3601;
  wire [31:0] n3602;
  wire n3603;
  wire n3604;
  wire [31:0] n3605;
  wire n3607;
  wire n3609;
  wire n3611;
  wire n3612;
  wire n3613;
  wire [31:0] n3614;
  wire [31:0] n3616;
  wire [30:0] n3617;
  wire [30:0] n3618;
  wire [31:0] n3620;
  wire [31:0] n3621;
  wire n3622;
  wire n3623;
  wire [31:0] n3624;
  wire n3626;
  wire n3628;
  wire n3630;
  wire n3631;
  wire n3632;
  wire [31:0] n3633;
  wire [31:0] n3635;
  wire [30:0] n3636;
  wire [30:0] n3637;
  wire [31:0] n3639;
  wire [31:0] n3640;
  wire n3641;
  wire n3642;
  wire [31:0] n3643;
  wire n3645;
  wire n3647;
  wire n3649;
  wire n3650;
  wire n3651;
  wire [31:0] n3652;
  wire [31:0] n3654;
  wire [30:0] n3655;
  wire [30:0] n3656;
  wire [31:0] n3658;
  wire [31:0] n3659;
  wire n3660;
  wire n3661;
  wire [31:0] n3662;
  wire n3664;
  wire n3666;
  wire n3668;
  wire n3669;
  wire n3670;
  wire [31:0] n3671;
  wire [31:0] n3673;
  wire [30:0] n3674;
  wire [30:0] n3675;
  wire [31:0] n3677;
  wire [31:0] n3678;
  wire n3679;
  wire n3680;
  wire [31:0] n3681;
  wire n3683;
  wire n3685;
  wire n3687;
  wire n3688;
  wire n3689;
  wire [31:0] n3690;
  wire [31:0] n3692;
  wire [30:0] n3693;
  wire [30:0] n3694;
  wire [31:0] n3696;
  wire [31:0] n3697;
  wire n3698;
  wire n3699;
  wire [31:0] n3700;
  wire n3702;
  wire n3704;
  wire n3706;
  wire n3707;
  wire n3708;
  wire [31:0] n3709;
  wire [31:0] n3711;
  wire [30:0] n3712;
  wire [30:0] n3713;
  wire [31:0] n3715;
  wire [31:0] n3716;
  wire n3717;
  wire n3718;
  wire [31:0] n3719;
  wire n3721;
  wire n3723;
  wire n3725;
  wire n3726;
  wire n3727;
  wire [31:0] n3728;
  wire [31:0] n3730;
  wire [30:0] n3731;
  wire [30:0] n3732;
  wire [31:0] n3734;
  wire [31:0] n3735;
  wire n3736;
  wire n3737;
  wire [31:0] n3738;
  wire n3740;
  wire n3742;
  wire n3744;
  wire n3745;
  wire n3746;
  wire [31:0] n3747;
  wire [31:0] n3749;
  wire [30:0] n3750;
  wire [30:0] n3751;
  wire [31:0] n3753;
  wire [31:0] n3754;
  wire n3755;
  wire n3756;
  wire [31:0] n3757;
  wire n3759;
  wire n3761;
  wire n3763;
  wire n3764;
  wire n3765;
  wire [31:0] n3766;
  wire [31:0] n3768;
  wire [30:0] n3769;
  wire [30:0] n3770;
  wire [31:0] n3772;
  wire [31:0] n3773;
  wire n3774;
  wire n3775;
  wire [31:0] n3776;
  wire n3778;
  wire n3780;
  wire n3782;
  wire n3783;
  wire n3784;
  wire [31:0] n3785;
  wire [31:0] n3787;
  wire [30:0] n3788;
  wire [30:0] n3789;
  wire [31:0] n3791;
  wire [31:0] n3792;
  wire n3793;
  wire n3794;
  wire [31:0] n3795;
  wire n3797;
  wire n3799;
  wire n3801;
  wire n3802;
  wire n3803;
  wire [31:0] n3804;
  wire [31:0] n3806;
  wire [30:0] n3807;
  wire [30:0] n3808;
  wire [31:0] n3810;
  wire [31:0] n3811;
  wire n3812;
  wire n3813;
  wire [31:0] n3814;
  wire n3816;
  wire n3818;
  wire n3820;
  wire n3821;
  wire n3822;
  wire [31:0] n3823;
  wire [31:0] n3825;
  wire [30:0] n3826;
  wire [30:0] n3827;
  wire [31:0] n3829;
  wire [31:0] n3830;
  wire n3831;
  wire n3832;
  wire [31:0] n3833;
  wire n3835;
  wire n3837;
  wire n3839;
  wire n3840;
  wire n3841;
  wire [31:0] n3842;
  wire [31:0] n3844;
  wire [30:0] n3845;
  wire [30:0] n3846;
  wire [31:0] n3848;
  wire [31:0] n3849;
  wire n3850;
  wire n3851;
  wire [31:0] n3852;
  wire n3854;
  wire n3856;
  wire n3858;
  wire n3859;
  wire n3860;
  wire [31:0] n3861;
  wire [31:0] n3863;
  wire [30:0] n3864;
  wire [30:0] n3865;
  wire [31:0] n3867;
  wire [31:0] n3868;
  wire n3869;
  wire n3870;
  wire [31:0] n3871;
  wire n3873;
  wire n3875;
  wire n3878;
  wire [31:0] n3886;
  wire [31:0] n3887;
  wire n3890;
  wire n3891;
  wire [31:0] n3893;
  wire [31:0] n3897;
  wire [30:0] n3898;
  wire [14:0] n3899;
  wire [14:0] n3901;
  wire [63:0] n3903;
  wire [31:0] n3905;
  wire [63:0] n3906;
  wire [31:0] n3907;
  wire [63:0] n3908;
  wire n3909;
  wire [63:0] n3910;
  wire [63:0] n3912;
  wire n3915;
  localparam [79:0] n3916 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire [14:0] n3918;
  wire [14:0] n3919;
  wire [63:0] n3920;
  wire [63:0] n3921;
  wire [79:0] n3922;
  wire [79:0] n3927;
  wire n3929;
  wire n3931;
  wire n3943;
  wire [14:0] n3946;
  wire [63:0] n3948;
  wire [79:0] n3949;
  wire [14:0] n3950;
  wire n3952;
  wire [63:0] n3953;
  wire n3955;
  wire n3956;
  wire n3957;
  wire n3959;
  wire n3961;
  wire [4:0] n3963;
  wire [31:0] n3966;
  wire n3968;
  wire [4:0] n3970;
  wire [31:0] n3974;
  wire n3976;
  wire [31:0] n3978;
  wire [31:0] n3980;
  wire [14:0] n3981;
  wire [31:0] n3983;
  wire n3989;
  wire n3992;
  wire n3996;
  wire [31:0] n4000;
  wire n4002;
  wire [31:0] n4007;
  wire [31:0] n4012;
  wire n4014;
  wire [31:0] n4015;
  wire [31:0] n4017;
  wire [31:0] n4018;
  wire [31:0] n4019;
  wire [31:0] n4020;
  wire n4022;
  wire n4024;
  wire [31:0] n4026;
  wire [31:0] n4028;
  wire [4:0] n4029;
  wire [31:0] n4030;
  wire [31:0] n4032;
  wire [4:0] n4033;
  wire [4:0] n4035;
  wire [14:0] n4036;
  wire [3:0] n4037;
  wire [3:0] n4038;
  wire [63:0] n4039;
  wire [4:0] n4040;
  wire [4:0] n4041;
  wire [4:0] n4045;
  wire [4:0] n4048;
  wire [31:0] n4051;
  wire [31:0] n4053;
  wire [3:0] n4054;
  wire [31:0] n4057;
  wire n4063;
  wire n4066;
  wire n4070;
  wire [31:0] n4074;
  wire n4076;
  wire [31:0] n4081;
  wire [31:0] n4086;
  wire n4088;
  wire [31:0] n4089;
  wire [31:0] n4091;
  wire [31:0] n4092;
  wire [31:0] n4093;
  wire [31:0] n4094;
  wire n4096;
  wire n4098;
  wire [31:0] n4100;
  wire [31:0] n4102;
  wire [4:0] n4103;
  wire [4:0] n4105;
  wire n4106;
  wire [67:0] n4107;
  wire [67:0] n4108;
  wire [4:0] n4109;
  wire [4:0] n4110;
  wire n4114;
  wire [31:0] n4115;
  wire n4117;
  wire [4:0] n4119;
  wire [30:0] n4122;
  wire [31:0] n4123;
  wire n4125;
  wire [31:0] n4126;
  wire n4128;
  wire n4130;
  wire [3:0] n4131;
  wire [31:0] n4132;
  wire n4134;
  wire n4135;
  wire n4138;
  wire n4141;
  wire [3:0] n4142;
  wire [31:0] n4143;
  wire n4145;
  wire n4146;
  wire n4148;
  wire n4150;
  wire [3:0] n4151;
  wire [31:0] n4152;
  wire n4154;
  wire n4155;
  wire n4157;
  wire n4159;
  wire [3:0] n4160;
  wire [31:0] n4161;
  wire n4163;
  wire n4164;
  wire n4166;
  wire n4168;
  wire [3:0] n4169;
  wire [31:0] n4170;
  wire n4172;
  wire n4173;
  wire n4175;
  wire n4177;
  wire [3:0] n4178;
  wire [31:0] n4179;
  wire n4181;
  wire n4182;
  wire n4184;
  wire n4186;
  wire [3:0] n4187;
  wire [31:0] n4188;
  wire n4190;
  wire n4191;
  wire n4193;
  wire n4195;
  wire [3:0] n4196;
  wire [31:0] n4197;
  wire n4199;
  wire n4200;
  wire n4202;
  wire n4204;
  wire [3:0] n4205;
  wire [31:0] n4206;
  wire n4208;
  wire n4209;
  wire n4211;
  wire n4213;
  wire [3:0] n4214;
  wire [31:0] n4215;
  wire n4217;
  wire n4218;
  wire n4220;
  wire n4222;
  wire [3:0] n4223;
  wire [31:0] n4224;
  wire n4226;
  wire n4227;
  wire n4229;
  wire n4231;
  wire [3:0] n4232;
  wire [31:0] n4233;
  wire n4235;
  wire n4236;
  wire n4238;
  wire n4240;
  wire [3:0] n4241;
  wire [31:0] n4242;
  wire n4244;
  wire n4245;
  wire n4247;
  wire n4249;
  wire [3:0] n4250;
  wire [31:0] n4251;
  wire n4253;
  wire n4254;
  wire n4256;
  wire n4258;
  wire [3:0] n4259;
  wire [31:0] n4260;
  wire n4262;
  wire n4263;
  wire n4265;
  wire n4267;
  wire [3:0] n4268;
  wire [31:0] n4269;
  wire n4271;
  wire n4272;
  wire n4274;
  wire n4276;
  wire [3:0] n4277;
  wire [31:0] n4278;
  wire n4280;
  wire n4281;
  wire n4283;
  wire [31:0] n4285;
  wire [4:0] n4286;
  wire [4:0] n4288;
  wire [31:0] n4291;
  wire n4292;
  wire [31:0] n4293;
  wire n4295;
  wire n4296;
  wire [31:0] n4299;
  wire [31:0] n4301;
  wire [31:0] n4304;
  wire n4308;
  wire [3:0] n4309;
  wire [31:0] n4310;
  wire n4312;
  wire n4313;
  wire n4315;
  wire n4317;
  wire [3:0] n4318;
  wire [31:0] n4319;
  wire n4321;
  wire n4322;
  wire n4324;
  wire n4326;
  wire [3:0] n4327;
  wire [31:0] n4328;
  wire n4330;
  wire n4331;
  wire n4333;
  wire n4335;
  wire [3:0] n4336;
  wire [31:0] n4337;
  wire n4339;
  wire n4340;
  wire n4342;
  wire n4344;
  wire [3:0] n4345;
  wire [31:0] n4346;
  wire n4348;
  wire n4349;
  wire n4351;
  wire n4353;
  wire [3:0] n4354;
  wire [31:0] n4355;
  wire n4357;
  wire n4358;
  wire n4360;
  wire n4362;
  wire [3:0] n4363;
  wire [31:0] n4364;
  wire n4366;
  wire n4367;
  wire n4369;
  wire n4371;
  wire [3:0] n4372;
  wire [31:0] n4373;
  wire n4375;
  wire n4376;
  wire n4378;
  wire n4380;
  wire [3:0] n4381;
  wire [31:0] n4382;
  wire n4384;
  wire n4385;
  wire n4387;
  wire n4389;
  wire [3:0] n4390;
  wire [31:0] n4391;
  wire n4393;
  wire n4394;
  wire n4396;
  wire n4398;
  wire [3:0] n4399;
  wire [31:0] n4400;
  wire n4402;
  wire n4403;
  wire n4405;
  wire n4407;
  wire [3:0] n4408;
  wire [31:0] n4409;
  wire n4411;
  wire n4412;
  wire n4414;
  wire n4416;
  wire [3:0] n4417;
  wire [31:0] n4418;
  wire n4420;
  wire n4421;
  wire n4423;
  wire n4425;
  wire [3:0] n4426;
  wire [31:0] n4427;
  wire n4429;
  wire n4430;
  wire n4432;
  wire n4434;
  wire [3:0] n4435;
  wire [31:0] n4436;
  wire n4438;
  wire n4439;
  wire n4441;
  wire n4443;
  wire [3:0] n4444;
  wire [31:0] n4445;
  wire n4447;
  wire n4448;
  wire n4450;
  wire n4452;
  wire [3:0] n4453;
  wire [31:0] n4454;
  wire n4456;
  wire n4457;
  wire n4459;
  wire n4461;
  wire [3:0] n4463;
  wire [3:0] n4464;
  wire n4466;
  wire [3:0] n4468;
  wire [3:0] n4469;
  wire n4471;
  wire [3:0] n4473;
  wire [3:0] n4474;
  wire n4476;
  wire [3:0] n4478;
  wire [3:0] n4479;
  wire n4481;
  wire [3:0] n4483;
  wire [3:0] n4484;
  wire n4486;
  wire [3:0] n4488;
  wire [3:0] n4489;
  wire n4491;
  wire [3:0] n4493;
  wire [3:0] n4494;
  wire n4496;
  wire [3:0] n4498;
  wire [3:0] n4499;
  wire n4501;
  wire [3:0] n4503;
  wire [3:0] n4504;
  wire n4506;
  wire [3:0] n4508;
  wire [3:0] n4509;
  wire n4511;
  wire [3:0] n4513;
  wire [3:0] n4514;
  wire n4516;
  wire [3:0] n4518;
  wire [3:0] n4519;
  wire n4521;
  wire [3:0] n4523;
  wire [3:0] n4524;
  wire n4526;
  wire [3:0] n4528;
  wire [3:0] n4529;
  wire n4531;
  wire [3:0] n4533;
  wire [3:0] n4534;
  wire n4536;
  wire [3:0] n4538;
  wire [3:0] n4539;
  wire n4541;
  wire [3:0] n4543;
  wire [3:0] n4544;
  wire n4546;
  wire [31:0] n4548;
  wire [4:0] n4549;
  wire [4:0] n4552;
  wire n4554;
  wire [4:0] n4555;
  wire [4:0] n4557;
  wire [67:0] n4558;
  wire [67:0] n4559;
  wire n4560;
  wire n4561;
  wire n4562;
  wire n4567;
  wire [4:0] n4569;
  wire [31:0] n4572;
  wire n4574;
  wire [4:0] n4576;
  wire [31:0] n4580;
  wire n4582;
  wire [31:0] n4584;
  wire [31:0] n4586;
  wire [14:0] n4587;
  wire [31:0] n4588;
  wire [31:0] n4590;
  wire [4:0] n4591;
  wire [4:0] n4593;
  wire [14:0] n4594;
  wire [3:0] n4595;
  wire [3:0] n4596;
  wire [63:0] n4597;
  wire n4599;
  wire [4:0] n4600;
  wire [4:0] n4602;
  wire [4:0] n4605;
  wire [31:0] n4608;
  wire [31:0] n4610;
  wire [3:0] n4611;
  wire [4:0] n4614;
  wire n4615;
  wire [67:0] n4616;
  wire [67:0] n4617;
  wire n4619;
  wire [4:0] n4620;
  wire [4:0] n4622;
  wire n4623;
  wire [67:0] n4624;
  wire n4625;
  wire n4626;
  wire n4628;
  wire [31:0] n4631;
  wire n4633;
  wire [31:0] n4635;
  wire [31:0] n4636;
  wire [30:0] n4637;
  wire [13:0] n4638;
  wire [13:0] n4641;
  wire n4642;
  wire [13:0] n4644;
  wire [31:0] n4645;
  wire [31:0] n4647;
  wire [30:0] n4648;
  wire [31:0] n4649;
  wire [31:0] n4651;
  wire [31:0] n4653;
  wire [30:0] n4654;
  wire [31:0] n4655;
  wire [31:0] n4657;
  wire [31:0] n4659;
  wire [30:0] n4660;
  wire [31:0] n4661;
  wire [31:0] n4663;
  wire [31:0] n4665;
  wire [30:0] n4666;
  wire [31:0] n4675;
  wire n4677;
  wire n4679;
  wire n4680;
  wire [31:0] n4682;
  wire [31:0] n4684;
  wire [30:0] n4685;
  wire [3:0] n4686;
  wire [31:0] n4695;
  wire n4697;
  wire n4699;
  wire n4700;
  wire [31:0] n4702;
  wire [31:0] n4704;
  wire [30:0] n4705;
  wire [3:0] n4706;
  wire [31:0] n4715;
  wire n4717;
  wire n4719;
  wire n4720;
  wire [31:0] n4722;
  wire [31:0] n4724;
  wire [30:0] n4725;
  wire [3:0] n4726;
  wire [31:0] n4735;
  wire n4737;
  wire n4739;
  wire n4740;
  wire [31:0] n4742;
  wire [31:0] n4744;
  wire [30:0] n4745;
  wire [3:0] n4746;
  wire [3:0] n4752;
  wire [30:0] n4753;
  wire [31:0] n4759;
  wire n4761;
  wire n4763;
  wire n4764;
  wire [31:0] n4766;
  wire [31:0] n4768;
  wire [30:0] n4769;
  wire [3:0] n4770;
  wire [3:0] n4774;
  wire [30:0] n4775;
  wire [31:0] n4781;
  wire n4783;
  wire n4785;
  wire n4786;
  wire [31:0] n4788;
  wire [31:0] n4790;
  wire [30:0] n4791;
  wire [3:0] n4792;
  wire [3:0] n4796;
  wire [30:0] n4797;
  wire [31:0] n4803;
  wire n4805;
  wire n4807;
  wire n4808;
  wire [31:0] n4810;
  wire [31:0] n4812;
  wire [30:0] n4813;
  wire [3:0] n4814;
  wire [3:0] n4818;
  wire [30:0] n4819;
  wire [31:0] n4825;
  wire n4827;
  wire n4829;
  wire n4830;
  wire [31:0] n4832;
  wire [31:0] n4834;
  wire [30:0] n4835;
  wire [3:0] n4836;
  wire [3:0] n4840;
  wire [30:0] n4841;
  wire [31:0] n4847;
  wire n4849;
  wire n4851;
  wire n4852;
  wire [31:0] n4854;
  wire [31:0] n4856;
  wire [30:0] n4857;
  wire [3:0] n4858;
  wire [3:0] n4862;
  wire [30:0] n4863;
  wire [31:0] n4869;
  wire n4871;
  wire n4873;
  wire n4874;
  wire [31:0] n4876;
  wire [31:0] n4878;
  wire [30:0] n4879;
  wire [3:0] n4880;
  wire [3:0] n4884;
  wire [30:0] n4885;
  wire [31:0] n4891;
  wire n4893;
  wire n4895;
  wire n4896;
  wire [31:0] n4898;
  wire [31:0] n4900;
  wire [30:0] n4901;
  wire [3:0] n4902;
  wire [3:0] n4906;
  wire [30:0] n4907;
  wire [31:0] n4913;
  wire n4915;
  wire n4917;
  wire n4918;
  wire [31:0] n4920;
  wire [31:0] n4922;
  wire [30:0] n4923;
  wire [3:0] n4924;
  wire [3:0] n4928;
  wire [30:0] n4929;
  wire [31:0] n4935;
  wire n4937;
  wire n4939;
  wire n4940;
  wire [31:0] n4942;
  wire [31:0] n4944;
  wire [30:0] n4945;
  wire [3:0] n4946;
  wire [3:0] n4950;
  wire [30:0] n4951;
  wire [31:0] n4957;
  wire n4959;
  wire n4961;
  wire n4962;
  wire [31:0] n4964;
  wire [31:0] n4966;
  wire [30:0] n4967;
  wire [3:0] n4968;
  wire [3:0] n4972;
  wire [30:0] n4973;
  wire [31:0] n4979;
  wire n4981;
  wire n4983;
  wire n4984;
  wire [31:0] n4986;
  wire [31:0] n4988;
  wire [30:0] n4989;
  wire [3:0] n4990;
  wire [3:0] n4994;
  wire [30:0] n4995;
  wire [31:0] n5001;
  wire n5003;
  wire n5005;
  wire n5006;
  wire [31:0] n5008;
  wire [31:0] n5010;
  wire [30:0] n5011;
  wire [3:0] n5012;
  wire [3:0] n5016;
  wire [30:0] n5017;
  wire [31:0] n5023;
  wire n5025;
  wire n5027;
  wire n5028;
  wire [31:0] n5030;
  wire [31:0] n5032;
  wire [30:0] n5033;
  wire [3:0] n5034;
  wire [3:0] n5038;
  wire [30:0] n5039;
  wire [31:0] n5045;
  wire n5047;
  wire n5049;
  wire n5050;
  wire [31:0] n5052;
  wire [31:0] n5054;
  wire [30:0] n5055;
  wire [3:0] n5056;
  wire [3:0] n5060;
  wire [30:0] n5061;
  wire [31:0] n5067;
  wire n5069;
  wire n5071;
  wire n5072;
  wire [31:0] n5074;
  wire [31:0] n5076;
  wire [30:0] n5077;
  wire [3:0] n5078;
  wire [3:0] n5082;
  wire [30:0] n5083;
  wire [31:0] n5089;
  wire n5091;
  wire n5093;
  wire n5094;
  wire [31:0] n5096;
  wire [31:0] n5098;
  wire [30:0] n5099;
  wire [3:0] n5100;
  wire [3:0] n5104;
  wire [30:0] n5105;
  wire [31:0] n5111;
  wire n5113;
  wire n5115;
  wire n5116;
  wire [31:0] n5118;
  wire [31:0] n5120;
  wire [30:0] n5121;
  wire [3:0] n5122;
  wire [95:0] n5124;
  wire n5126;
  wire [63:0] n5128;
  wire [63:0] n5130;
  wire [63:0] n5131;
  wire [4:0] n5133;
  wire [30:0] n5136;
  wire [63:0] n5137;
  wire [63:0] n5138;
  wire [31:0] n5139;
  wire n5141;
  wire [31:0] n5142;
  wire [31:0] n5144;
  wire [4:0] n5145;
  wire [4:0] n5147;
  wire [4:0] n5148;
  wire n5150;
  wire n5161;
  wire n5165;
  wire n5169;
  wire [79:0] n5171;
  wire [31:0] n5174;
  wire n5177;
  wire [31:0] n5179;
  wire n5184;
  wire n5186;
  wire n5188;
  wire n5190;
  wire n5192;
  wire n5194;
  wire n5195;
  wire n5196;
  wire [31:0] n5198;
  wire n5202;
  wire n5204;
  wire n5205;
  wire n5207;
  wire n5208;
  wire n5209;
  wire n5210;
  wire n5211;
  wire [31:0] n5213;
  wire n5217;
  wire n5219;
  wire n5220;
  wire n5222;
  wire n5223;
  wire n5224;
  wire n5225;
  wire n5226;
  wire [31:0] n5228;
  wire n5232;
  wire n5234;
  wire n5235;
  wire n5237;
  wire n5238;
  wire n5239;
  wire n5240;
  wire n5241;
  wire [31:0] n5243;
  wire n5247;
  wire n5249;
  wire n5250;
  wire n5252;
  wire n5253;
  wire n5254;
  wire n5255;
  wire n5256;
  wire [31:0] n5258;
  wire n5262;
  wire n5264;
  wire n5265;
  wire n5267;
  wire n5268;
  wire n5269;
  wire n5270;
  wire n5271;
  wire [31:0] n5273;
  wire n5277;
  wire n5279;
  wire n5280;
  wire n5282;
  wire n5283;
  wire n5284;
  wire n5285;
  wire n5286;
  wire [31:0] n5288;
  wire n5292;
  wire n5294;
  wire n5295;
  wire n5297;
  wire n5298;
  wire n5299;
  wire n5300;
  wire n5301;
  wire [31:0] n5303;
  wire n5307;
  wire n5309;
  wire n5310;
  wire n5312;
  wire n5313;
  wire n5314;
  wire n5315;
  wire n5316;
  wire [31:0] n5318;
  wire n5322;
  wire n5324;
  wire n5325;
  wire n5327;
  wire n5328;
  wire n5329;
  wire n5330;
  wire n5331;
  wire [31:0] n5333;
  wire n5337;
  wire n5339;
  wire n5340;
  wire n5342;
  wire n5343;
  wire n5344;
  wire n5345;
  wire n5346;
  wire [31:0] n5348;
  wire n5352;
  wire n5354;
  wire n5355;
  wire n5357;
  wire n5358;
  wire n5359;
  wire n5360;
  wire n5361;
  wire [31:0] n5363;
  wire n5367;
  wire n5369;
  wire n5370;
  wire n5372;
  wire n5373;
  wire n5374;
  wire n5375;
  wire n5376;
  wire [31:0] n5378;
  wire n5382;
  wire n5384;
  wire n5385;
  wire n5387;
  wire n5388;
  wire n5389;
  wire n5390;
  wire n5391;
  wire [31:0] n5393;
  wire n5397;
  wire n5399;
  wire n5400;
  wire n5402;
  wire n5403;
  wire n5404;
  wire n5405;
  wire n5406;
  wire [31:0] n5408;
  wire n5412;
  wire n5414;
  wire n5415;
  wire n5417;
  wire n5418;
  wire n5419;
  wire n5420;
  wire n5421;
  wire [31:0] n5423;
  wire n5427;
  wire n5429;
  wire n5430;
  wire n5432;
  wire n5433;
  wire n5434;
  wire n5435;
  wire n5436;
  wire [31:0] n5438;
  wire n5442;
  wire n5444;
  wire n5445;
  wire n5447;
  wire n5448;
  wire n5449;
  wire n5450;
  wire n5451;
  wire [31:0] n5453;
  wire n5457;
  wire n5459;
  wire n5460;
  wire n5462;
  wire n5463;
  wire n5464;
  wire n5465;
  wire n5466;
  wire [31:0] n5468;
  wire n5472;
  wire n5474;
  wire n5475;
  wire n5477;
  wire n5478;
  wire n5479;
  wire n5480;
  wire n5481;
  wire [31:0] n5483;
  wire n5487;
  wire n5489;
  wire n5490;
  wire n5492;
  wire n5493;
  wire n5494;
  wire n5495;
  wire n5496;
  wire [31:0] n5498;
  wire n5502;
  wire n5504;
  wire n5505;
  wire n5507;
  wire n5508;
  wire n5509;
  wire n5510;
  wire n5511;
  wire [31:0] n5513;
  wire n5517;
  wire n5519;
  wire n5520;
  wire n5522;
  wire n5523;
  wire n5524;
  wire n5525;
  wire n5526;
  wire [31:0] n5528;
  wire n5532;
  wire n5534;
  wire n5535;
  wire n5537;
  wire n5538;
  wire n5539;
  wire n5540;
  wire n5541;
  wire [31:0] n5543;
  wire n5547;
  wire n5549;
  wire n5550;
  wire n5552;
  wire n5553;
  wire n5554;
  wire n5555;
  wire n5556;
  wire [31:0] n5558;
  wire n5562;
  wire n5564;
  wire n5565;
  wire n5567;
  wire n5568;
  wire n5569;
  wire n5570;
  wire n5571;
  wire [31:0] n5573;
  wire n5577;
  wire n5579;
  wire n5580;
  wire n5582;
  wire n5583;
  wire n5584;
  wire n5585;
  wire n5586;
  wire [31:0] n5588;
  wire n5592;
  wire n5594;
  wire n5595;
  wire n5597;
  wire n5598;
  wire n5599;
  wire n5600;
  wire n5601;
  wire [31:0] n5603;
  wire n5607;
  wire n5609;
  wire n5610;
  wire n5612;
  wire n5613;
  wire n5614;
  wire n5615;
  wire n5616;
  wire [31:0] n5618;
  wire n5622;
  wire n5624;
  wire n5625;
  wire n5627;
  wire n5628;
  wire n5629;
  wire n5630;
  wire n5631;
  wire [31:0] n5633;
  wire n5637;
  wire n5639;
  wire n5640;
  wire n5642;
  wire n5643;
  wire n5644;
  wire n5645;
  wire n5646;
  wire [31:0] n5648;
  wire n5652;
  wire n5654;
  wire n5655;
  wire n5657;
  wire n5658;
  wire n5659;
  wire n5660;
  wire n5661;
  wire [31:0] n5663;
  wire n5667;
  wire n5669;
  wire n5670;
  wire n5672;
  wire n5673;
  wire n5674;
  wire n5675;
  wire n5676;
  wire [31:0] n5678;
  wire n5682;
  wire n5684;
  wire n5685;
  wire n5687;
  wire n5688;
  wire n5689;
  wire n5690;
  wire n5691;
  wire [31:0] n5693;
  wire n5697;
  wire n5699;
  wire n5700;
  wire n5702;
  wire n5703;
  wire n5704;
  wire n5705;
  wire n5706;
  wire [31:0] n5708;
  wire n5712;
  wire n5714;
  wire n5715;
  wire n5717;
  wire n5718;
  wire n5719;
  wire n5720;
  wire n5721;
  wire [31:0] n5723;
  wire n5727;
  wire n5729;
  wire n5730;
  wire n5732;
  wire n5733;
  wire n5734;
  wire n5735;
  wire n5736;
  wire [31:0] n5738;
  wire n5742;
  wire n5744;
  wire n5745;
  wire n5747;
  wire n5748;
  wire n5749;
  wire n5750;
  wire n5751;
  wire [31:0] n5753;
  wire n5757;
  wire n5759;
  wire n5760;
  wire n5762;
  wire n5763;
  wire n5764;
  wire n5765;
  wire n5766;
  wire [31:0] n5768;
  wire n5772;
  wire n5774;
  wire n5775;
  wire n5777;
  wire n5778;
  wire n5779;
  wire n5780;
  wire n5781;
  wire [31:0] n5783;
  wire n5787;
  wire n5789;
  wire n5790;
  wire n5792;
  wire n5793;
  wire n5794;
  wire n5795;
  wire n5796;
  wire [31:0] n5798;
  wire n5802;
  wire n5804;
  wire n5805;
  wire n5807;
  wire n5808;
  wire n5809;
  wire n5810;
  wire n5811;
  wire [31:0] n5813;
  wire n5817;
  wire n5819;
  wire n5820;
  wire n5822;
  wire n5823;
  wire n5824;
  wire n5825;
  wire n5826;
  wire [31:0] n5828;
  wire n5832;
  wire n5834;
  wire n5835;
  wire n5837;
  wire n5838;
  wire n5839;
  wire n5840;
  wire n5841;
  wire [31:0] n5843;
  wire n5847;
  wire n5849;
  wire n5850;
  wire n5852;
  wire n5853;
  wire n5854;
  wire n5855;
  wire n5856;
  wire [31:0] n5858;
  wire n5862;
  wire n5864;
  wire n5865;
  wire n5867;
  wire n5868;
  wire n5869;
  wire n5870;
  wire n5871;
  wire [31:0] n5873;
  wire n5877;
  wire n5879;
  wire n5880;
  wire n5882;
  wire n5883;
  wire n5884;
  wire n5885;
  wire n5886;
  wire [31:0] n5888;
  wire n5892;
  wire n5894;
  wire n5895;
  wire n5897;
  wire n5898;
  wire n5899;
  wire n5900;
  wire n5901;
  wire [31:0] n5903;
  wire n5907;
  wire n5909;
  wire n5910;
  wire n5912;
  wire n5913;
  wire n5914;
  wire n5915;
  wire n5916;
  wire [31:0] n5918;
  wire n5922;
  wire n5924;
  wire n5925;
  wire n5927;
  wire n5928;
  wire n5929;
  wire n5930;
  wire n5931;
  wire [31:0] n5933;
  wire n5937;
  wire n5939;
  wire n5940;
  wire n5942;
  wire n5943;
  wire n5944;
  wire n5945;
  wire n5946;
  wire [31:0] n5948;
  wire n5952;
  wire n5954;
  wire n5955;
  wire n5957;
  wire n5958;
  wire n5959;
  wire n5960;
  wire n5961;
  wire [31:0] n5963;
  wire n5967;
  wire n5969;
  wire n5970;
  wire n5972;
  wire n5973;
  wire n5974;
  wire n5975;
  wire n5976;
  wire [31:0] n5978;
  wire n5982;
  wire n5984;
  wire n5985;
  wire n5987;
  wire n5988;
  wire n5989;
  wire n5990;
  wire n5991;
  wire [31:0] n5993;
  wire n5997;
  wire n5999;
  wire n6000;
  wire n6002;
  wire n6003;
  wire n6004;
  wire n6005;
  wire n6006;
  wire [31:0] n6008;
  wire n6012;
  wire n6014;
  wire n6015;
  wire n6017;
  wire n6018;
  wire n6019;
  wire n6020;
  wire n6021;
  wire [31:0] n6023;
  wire n6027;
  wire n6029;
  wire n6030;
  wire n6032;
  wire n6033;
  wire n6034;
  wire n6035;
  wire n6036;
  wire [31:0] n6038;
  wire n6042;
  wire n6044;
  wire n6045;
  wire n6047;
  wire n6048;
  wire n6049;
  wire n6050;
  wire n6051;
  wire [31:0] n6053;
  wire n6057;
  wire n6059;
  wire n6060;
  wire n6062;
  wire n6063;
  wire n6064;
  wire n6065;
  wire n6066;
  wire [31:0] n6068;
  wire n6072;
  wire n6074;
  wire n6075;
  wire n6077;
  wire n6078;
  wire n6079;
  wire n6080;
  wire n6081;
  wire [31:0] n6083;
  wire n6087;
  wire n6089;
  wire n6090;
  wire n6092;
  wire n6093;
  wire n6094;
  wire n6095;
  wire n6096;
  wire [31:0] n6098;
  wire n6102;
  wire n6104;
  wire n6105;
  wire n6107;
  wire n6108;
  wire n6109;
  wire n6110;
  wire n6111;
  wire [31:0] n6113;
  wire n6117;
  wire n6119;
  wire n6120;
  wire n6122;
  wire n6123;
  wire n6124;
  wire n6125;
  wire n6126;
  wire [31:0] n6128;
  wire n6134;
  wire n6137;
  wire n6141;
  wire n6142;
  wire [31:0] n6143;
  wire [31:0] n6145;
  wire [30:0] n6146;
  wire [14:0] n6147;
  wire [14:0] n6149;
  wire [31:0] n6152;
  wire [63:0] n6153;
  wire [31:0] n6154;
  wire [63:0] n6155;
  wire n6156;
  wire [63:0] n6157;
  wire [63:0] n6159;
  wire n6163;
  localparam [79:0] n6164 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  wire [14:0] n6166;
  wire [14:0] n6167;
  wire [63:0] n6168;
  wire [63:0] n6169;
  wire [79:0] n6170;
  wire [79:0] n6175;
  wire [31:0] n6176;
  wire [31:0] n6178;
  wire n6180;
  wire n6182;
  wire [31:0] n6183;
  wire [30:0] n6184;
  wire [13:0] n6185;
  wire [30:0] n6186;
  wire [13:0] n6187;
  wire [13:0] n6188;
  wire n6191;
  wire [4:0] n6194;
  wire [4:0] n6196;
  wire [13:0] n6197;
  wire n6198;
  wire [3:0] n6200;
  wire n6202;
  wire [78:0] n6203;
  wire [79:0] n6204;
  wire n6206;
  wire [17:0] n6207;
  reg [4:0] n6212;
  reg [4:0] n6213;
  reg [79:0] n6214;
  reg [95:0] n6215;
  reg [6:0] n6216;
  reg n6217;
  reg [14:0] n6218;
  reg [15:0] n6219;
  reg [79:0] n6220;
  reg [67:0] n6221;
  reg [3:0] n6222;
  reg [4:0] n6223;
  reg [2:0] n6224;
  reg [4:0] n6225;
  reg n6226;
  reg [13:0] n6227;
  reg n6228;
  reg [3:0] n6229;
  reg [63:0] n6230;
  reg n6231;
  reg [4:0] n6232;
  reg n6236;
  reg [95:0] n6237;
  reg [79:0] n6238;
  reg n6240;
  reg n6243;
  reg [79:0] n6382;
  reg [79:0] n6385;
  reg [79:0] n6387;
  reg [79:0] n6389;
  reg n6392;
  reg [79:0] n6394;
  reg [31:0] n6396;
  reg [2:0] n6402;
  reg n6405;
  reg n6408;
  reg n6411;
  reg n6414;
  reg n6417;
  reg n6420;
  reg n6423;
  reg n6426;
  reg n6429;
  reg n6432;
  reg n6435;
  reg n6438;
  reg n6441;
  reg n6444;
  reg n6447;
  reg n6450;
  reg n6453;
  reg n6456;
  reg n6459;
  reg n6462;
  reg n6465;
  wire n6467;
  wire [1:0] n6468;
  wire n6471;
  wire n6473;
  wire n6475;
  wire n6476;
  wire [2:0] n6479;
  wire [1:0] n6481;
  wire [2:0] n6482;
  wire [2:0] n6483;
  wire [4:0] n6491;
  wire [14:0] n6497;
  wire [79:0] n6499;
  wire [67:0] n6500;
  wire [3:0] n6501;
  wire [4:0] n6502;
  wire [4:0] n6504;
  wire [13:0] n6506;
  wire [3:0] n6508;
  wire n6510;
  wire [4:0] n6511;
  wire n6513;
  wire n6519;
  wire n6520;
  wire n6521;
  wire n6522;
  wire n6523;
  wire n6524;
  wire n6525;
  wire n6526;
  wire n6527;
  wire n6528;
  wire n6589;
  wire n6591;
  wire n6593;
  wire n6595;
  wire n6597;
  wire n6599;
  wire n6601;
  wire n6603;
  wire n6605;
  wire n6607;
  wire n6609;
  wire n6611;
  wire n6613;
  wire n6615;
  wire n6617;
  wire n6619;
  wire n6621;
  wire n6623;
  wire n6625;
  wire n6627;
  wire n6629;
  reg n6934;
  reg n6936;
  reg n6938;
  reg n6940;
  reg n6942;
  reg n6944;
  reg n6946;
  reg n6948;
  reg n6950;
  reg n6952;
  reg n6954;
  reg n6956;
  reg n6958;
  reg n6960;
  reg n6962;
  reg n6964;
  reg n6966;
  reg n6968;
  reg n6970;
  reg n6972;
  reg n6974;
  wire n7109;
  wire [15:0] n7113;
  wire [15:0] n7116;
  wire [15:0] n7118;
  wire [15:0] n7121;
  wire [31:0] n7122;
  wire [15:0] n7124;
  wire [7:0] n7126;
  wire [23:0] n7127;
  wire [30:0] n7129;
  wire [31:0] n7130;
  wire [31:0] n7131;
  wire [31:0] n7132;
  wire [31:0] n7133;
  wire [31:0] n7134;
  wire n7136;
  wire n7138;
  wire n7140;
  wire [2:0] n7141;
  reg [31:0] n7142;
  reg [31:0] n7143;
  reg [31:0] n7144;
  wire [31:0] n7145;
  wire [31:0] n7146;
  wire [31:0] n7147;
  wire [31:0] n7158;
  wire n7160;
  wire [31:0] n7161;
  wire [31:0] n7162;
  wire n7164;
  wire [31:0] n7165;
  wire [31:0] n7166;
  wire n7168;
  wire [31:0] n7169;
  reg [4:0] n7171;
  wire [4:0] n7172;
  reg [4:0] n7173;
  wire [79:0] n7174;
  reg [79:0] n7175;
  wire [95:0] n7176;
  reg [95:0] n7177;
  wire [6:0] n7178;
  reg [6:0] n7179;
  wire n7180;
  reg n7181;
  reg [14:0] n7182;
  wire [15:0] n7183;
  reg [15:0] n7184;
  reg [79:0] n7185;
  reg [67:0] n7186;
  reg [3:0] n7187;
  reg [4:0] n7188;
  wire [2:0] n7189;
  reg [2:0] n7190;
  reg [4:0] n7191;
  wire n7192;
  reg n7193;
  reg [13:0] n7194;
  wire n7195;
  reg n7196;
  reg [3:0] n7197;
  wire [63:0] n7198;
  reg [63:0] n7199;
  reg n7200;
  reg [4:0] n7201;
  reg n7202;
  wire [95:0] n7203;
  reg [95:0] n7204;
  wire [79:0] n7205;
  reg [79:0] n7206;
  wire n7207;
  reg n7208;
  wire n7209;
  reg n7210;
  reg [1:0] n7211;
  reg [2:0] n7212;
  reg [2:0] n7213;
  wire [1:0] n7214;
  reg [1:0] n7215;
  wire [79:0] n7216;
  reg [79:0] n7217;
  wire [79:0] n7218;
  reg [79:0] n7219;
  wire [79:0] n7220;
  reg [79:0] n7221;
  wire [79:0] n7222;
  reg [79:0] n7223;
  wire n7224;
  reg n7225;
  wire [79:0] n7226;
  reg [79:0] n7227;
  wire [79:0] n7228;
  reg [79:0] n7229;
  wire [79:0] n7230;
  reg [79:0] n7231;
  wire [4:0] n7232;
  reg [4:0] n7233;
  reg n7234;
  reg n7235;
  reg [31:0] n7236;
  reg [31:0] n7237;
  reg [31:0] n7238;
  wire n7239;
  wire n7240;
  wire n7241;
  wire n7242;
  wire n7243;
  wire n7244;
  wire n7245;
  wire n7246;
  wire n7247;
  wire n7248;
  wire n7249;
  wire n7250;
  wire n7251;
  wire n7252;
  wire n7253;
  wire n7254;
  wire n7255;
  wire n7256;
  wire n7257;
  wire n7258;
  wire n7259;
  wire n7260;
  wire n7261;
  wire n7262;
  wire n7263;
  wire n7264;
  wire n7265;
  wire n7266;
  wire n7267;
  wire n7268;
  wire n7269;
  wire n7270;
  wire n7271;
  wire n7272;
  wire n7273;
  wire n7274;
  wire n7275;
  wire n7276;
  wire n7277;
  wire n7278;
  wire n7279;
  wire n7280;
  wire n7281;
  wire n7282;
  wire [3:0] n7283;
  wire [3:0] n7284;
  wire [3:0] n7285;
  wire [3:0] n7286;
  wire [3:0] n7287;
  wire [3:0] n7288;
  wire [3:0] n7289;
  wire [3:0] n7290;
  wire [3:0] n7291;
  wire [3:0] n7292;
  wire [3:0] n7293;
  wire [3:0] n7294;
  wire [3:0] n7295;
  wire [3:0] n7296;
  wire [3:0] n7297;
  wire [3:0] n7298;
  wire [3:0] n7299;
  wire [3:0] n7300;
  wire [3:0] n7301;
  wire [3:0] n7302;
  wire [3:0] n7303;
  wire [3:0] n7304;
  wire [3:0] n7305;
  wire [3:0] n7306;
  wire [3:0] n7307;
  wire [3:0] n7308;
  wire [3:0] n7309;
  wire [3:0] n7310;
  wire [3:0] n7311;
  wire [3:0] n7312;
  wire [3:0] n7313;
  wire [3:0] n7314;
  wire [3:0] n7315;
  wire [3:0] n7316;
  wire [67:0] n7317;
  wire [15:0] n7319;
  wire n7320;
  wire [127:0] n7322;
  wire [3:0] n7323;
  wire n7324;
  wire n7325;
  wire n7326;
  wire n7327;
  wire n7328;
  wire n7329;
  wire n7330;
  wire n7331;
  wire n7332;
  wire n7333;
  wire n7334;
  wire n7335;
  wire n7336;
  wire n7337;
  wire n7338;
  wire n7339;
  wire n7340;
  wire n7341;
  wire n7342;
  wire n7343;
  wire n7344;
  wire n7345;
  wire n7346;
  wire n7347;
  wire n7348;
  wire n7349;
  wire n7350;
  wire n7351;
  wire n7352;
  wire n7353;
  wire n7354;
  wire n7355;
  wire n7356;
  wire n7357;
  wire n7358;
  wire n7359;
  wire n7360;
  wire n7361;
  wire n7362;
  wire n7363;
  wire n7364;
  wire n7365;
  wire n7366;
  wire n7367;
  wire [3:0] n7368;
  wire [3:0] n7369;
  wire [3:0] n7370;
  wire [3:0] n7371;
  wire [3:0] n7372;
  wire [3:0] n7373;
  wire [3:0] n7374;
  wire [3:0] n7375;
  wire [3:0] n7376;
  wire [3:0] n7377;
  wire [3:0] n7378;
  wire [3:0] n7379;
  wire [3:0] n7380;
  wire [3:0] n7381;
  wire [3:0] n7382;
  wire [3:0] n7383;
  wire [3:0] n7384;
  wire [3:0] n7385;
  wire [3:0] n7386;
  wire [3:0] n7387;
  wire [3:0] n7388;
  wire [3:0] n7389;
  wire [3:0] n7390;
  wire [3:0] n7391;
  wire [3:0] n7392;
  wire [3:0] n7393;
  wire [3:0] n7394;
  wire [3:0] n7395;
  wire [3:0] n7396;
  wire [3:0] n7397;
  wire [3:0] n7398;
  wire [3:0] n7399;
  wire [3:0] n7400;
  wire [3:0] n7401;
  wire [67:0] n7402;
  wire [127:0] n7404;
  wire [3:0] n7405;
  wire n7406;
  wire n7407;
  wire n7408;
  wire n7409;
  wire n7410;
  wire n7411;
  wire n7412;
  wire n7413;
  wire n7414;
  wire n7415;
  wire n7416;
  wire n7417;
  wire n7418;
  wire n7419;
  wire n7420;
  wire n7421;
  wire n7422;
  wire n7423;
  wire n7424;
  wire n7425;
  wire n7426;
  wire n7427;
  wire n7428;
  wire n7429;
  wire n7430;
  wire n7431;
  wire n7432;
  wire n7433;
  wire n7434;
  wire n7435;
  wire n7436;
  wire n7437;
  wire n7438;
  wire n7439;
  wire n7440;
  wire n7441;
  wire n7442;
  wire n7443;
  wire n7444;
  wire n7445;
  wire n7446;
  wire n7447;
  wire n7448;
  wire n7449;
  wire [3:0] n7450;
  wire [3:0] n7451;
  wire [3:0] n7452;
  wire [3:0] n7453;
  wire [3:0] n7454;
  wire [3:0] n7455;
  wire [3:0] n7456;
  wire [3:0] n7457;
  wire [3:0] n7458;
  wire [3:0] n7459;
  wire [3:0] n7460;
  wire [3:0] n7461;
  wire [3:0] n7462;
  wire [3:0] n7463;
  wire [3:0] n7464;
  wire [3:0] n7465;
  wire [3:0] n7466;
  wire [3:0] n7467;
  wire [3:0] n7468;
  wire [3:0] n7469;
  wire [3:0] n7470;
  wire [3:0] n7471;
  wire [3:0] n7472;
  wire [3:0] n7473;
  wire [3:0] n7474;
  wire [3:0] n7475;
  wire [3:0] n7476;
  wire [3:0] n7477;
  wire [3:0] n7478;
  wire [3:0] n7479;
  wire [3:0] n7480;
  wire [3:0] n7481;
  wire [3:0] n7482;
  wire [3:0] n7483;
  wire [67:0] n7484;
  wire [127:0] n7486;
  wire [3:0] n7487;
  wire [127:0] n7489;
  wire [3:0] n7490;
  wire [127:0] n7492;
  wire [3:0] n7493;
  wire n7494;
  wire n7495;
  wire n7496;
  wire n7497;
  wire n7498;
  wire n7499;
  wire n7500;
  wire n7501;
  wire n7502;
  wire n7503;
  wire n7504;
  wire n7505;
  wire n7506;
  wire n7507;
  wire n7508;
  wire n7509;
  wire n7510;
  wire n7511;
  wire n7512;
  wire n7513;
  wire n7514;
  wire n7515;
  wire n7516;
  wire n7517;
  wire n7518;
  wire n7519;
  wire n7520;
  wire n7521;
  wire n7522;
  wire n7523;
  wire n7524;
  wire n7525;
  wire n7526;
  wire n7527;
  wire n7528;
  wire n7529;
  wire n7530;
  wire n7531;
  wire n7532;
  wire n7533;
  wire n7534;
  wire n7535;
  wire n7536;
  wire n7537;
  wire [3:0] n7538;
  wire [3:0] n7539;
  wire [3:0] n7540;
  wire [3:0] n7541;
  wire [3:0] n7542;
  wire [3:0] n7543;
  wire [3:0] n7544;
  wire [3:0] n7545;
  wire [3:0] n7546;
  wire [3:0] n7547;
  wire [3:0] n7548;
  wire [3:0] n7549;
  wire [3:0] n7550;
  wire [3:0] n7551;
  wire [3:0] n7552;
  wire [3:0] n7553;
  wire [3:0] n7554;
  wire [3:0] n7555;
  wire [3:0] n7556;
  wire [3:0] n7557;
  wire [3:0] n7558;
  wire [3:0] n7559;
  wire [3:0] n7560;
  wire [3:0] n7561;
  wire [3:0] n7562;
  wire [3:0] n7563;
  wire [3:0] n7564;
  wire [3:0] n7565;
  wire [3:0] n7566;
  wire [3:0] n7567;
  wire [3:0] n7568;
  wire [3:0] n7569;
  wire [3:0] n7570;
  wire [3:0] n7571;
  wire [67:0] n7572;
  wire [127:0] n7574;
  wire [3:0] n7575;
  wire n7576;
  wire n7577;
  wire n7578;
  wire n7579;
  wire n7580;
  wire n7581;
  wire n7582;
  wire n7583;
  wire n7584;
  wire n7585;
  wire n7586;
  wire n7587;
  wire n7588;
  wire n7589;
  wire n7590;
  wire n7591;
  wire n7592;
  wire n7593;
  wire n7594;
  wire n7595;
  wire n7596;
  wire n7597;
  wire n7598;
  wire n7599;
  wire n7600;
  wire n7601;
  wire n7602;
  wire n7603;
  wire n7604;
  wire n7605;
  wire n7606;
  wire n7607;
  wire n7608;
  wire n7609;
  wire n7610;
  wire n7611;
  wire n7612;
  wire n7613;
  wire n7614;
  wire n7615;
  wire n7616;
  wire n7617;
  wire n7618;
  wire n7619;
  wire [3:0] n7620;
  wire [3:0] n7621;
  wire [3:0] n7622;
  wire [3:0] n7623;
  wire [3:0] n7624;
  wire [3:0] n7625;
  wire [3:0] n7626;
  wire [3:0] n7627;
  wire [3:0] n7628;
  wire [3:0] n7629;
  wire [3:0] n7630;
  wire [3:0] n7631;
  wire [3:0] n7632;
  wire [3:0] n7633;
  wire [3:0] n7634;
  wire [3:0] n7635;
  wire [3:0] n7636;
  wire [3:0] n7637;
  wire [3:0] n7638;
  wire [3:0] n7639;
  wire [3:0] n7640;
  wire [3:0] n7641;
  wire [3:0] n7642;
  wire [3:0] n7643;
  wire [3:0] n7644;
  wire [3:0] n7645;
  wire [3:0] n7646;
  wire [3:0] n7647;
  wire [3:0] n7648;
  wire [3:0] n7649;
  wire [3:0] n7650;
  wire [3:0] n7651;
  wire [3:0] n7652;
  wire [3:0] n7653;
  wire [67:0] n7654;
  wire [127:0] n7656;
  wire [3:0] n7657;
  assign busy = n63; //(module output)
  assign rsp_valid = rsp_valid_reg; //(module output)
  assign rsp_word = rsp_word_reg; //(module output)
  assign rsp_fp = rsp_fp_reg; //(module output)
  assign rsp_inexact = rsp_inexact_reg; //(module output)
  assign rsp_invalid = rsp_invalid_reg; //(module output)
  assign fp_mul_start = packed_mul_start_reg; //(module output)
  assign fp_mul_a_out = arith_mul_a_reg; //(module output)
  assign fp_mul_b_out = arith_mul_b_reg; //(module output)
  assign fp_add_start = packed_add_start_reg; //(module output)
  assign fp_add_a_out = arith_add_a_reg; //(module output)
  assign fp_add_b_out = arith_add_b_reg; //(module output)
  assign fp_add_sub_out = arith_add_sub_reg; //(module output)
  assign save_data = n7161; //(module output)
  /* mc68881_packed_decimal_unit.vhd:117:10  */
  always @*
    state_reg = n7171; // (isignal)
  initial
    state_reg = 5'b00000;
  /* mc68881_packed_decimal_unit.vhd:118:10  */
  always @*
    scale_return_state_reg = n7173; // (isignal)
  initial
    scale_return_state_reg = 5'b00000;
  /* mc68881_packed_decimal_unit.vhd:120:10  */
  always @*
    req_fp_reg = n7175; // (isignal)
  initial
    req_fp_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:121:10  */
  always @*
    req_word_reg = n7177; // (isignal)
  initial
    req_word_reg = 96'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:122:10  */
  always @*
    req_k_reg = n7179; // (isignal)
  initial
    req_k_reg = 7'b0000000;
  /* mc68881_packed_decimal_unit.vhd:124:10  */
  always @*
    sign_reg = n7181; // (isignal)
  initial
    sign_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:125:10  */
  always @*
    exp10_reg = n7182; // (isignal)
  initial
    exp10_reg = 15'b000000000000000;
  /* mc68881_packed_decimal_unit.vhd:126:10  */
  always @*
    bin_exp_reg = n7184; // (isignal)
  initial
    bin_exp_reg = 16'b0000000000000000;
  /* mc68881_packed_decimal_unit.vhd:127:10  */
  always @*
    work_fp_reg = n7185; // (isignal)
  initial
    work_fp_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:128:10  */
  always @*
    digits_reg = n7186; // (isignal)
  initial
    digits_reg = 68'b00000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:129:10  */
  always @*
    enc_digit_reg = n7187; // (isignal)
  initial
    enc_digit_reg = 4'b0000;
  /* mc68881_packed_decimal_unit.vhd:130:10  */
  always @*
    idx_reg = n7188; // (isignal)
  initial
    idx_reg = 5'b00000;
  /* mc68881_packed_decimal_unit.vhd:131:10  */
  always @*
    tune_iter_reg = n7190; // (isignal)
  initial
    tune_iter_reg = 3'b000;
  /* mc68881_packed_decimal_unit.vhd:132:10  */
  always @*
    keep_digits_reg = n7191; // (isignal)
  initial
    keep_digits_reg = 5'b10001;
  /* mc68881_packed_decimal_unit.vhd:133:10  */
  always @*
    inexact_reg = n7193; // (isignal)
  initial
    inexact_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:135:10  */
  always @*
    scale_abs_exp_reg = n7194; // (isignal)
  initial
    scale_abs_exp_reg = 14'b00000000000000;
  /* mc68881_packed_decimal_unit.vhd:136:10  */
  assign scale_abs_exp_slv = n59; // (signal)
  /* mc68881_packed_decimal_unit.vhd:137:10  */
  always @*
    scale_use_neg_reg = n7196; // (isignal)
  initial
    scale_use_neg_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:138:10  */
  always @*
    scale_bit_idx_reg = n7197; // (isignal)
  initial
    scale_bit_idx_reg = 4'b0000;
  /* mc68881_packed_decimal_unit.vhd:140:10  */
  always @*
    mant_u64_reg = n7199; // (isignal)
  initial
    mant_u64_reg = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:142:10  */
  always @*
    kround_carry_reg = n7200; // (isignal)
  initial
    kround_carry_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:143:10  */
  always @*
    kround_idx_reg = n7201; // (isignal)
  initial
    kround_idx_reg = 5'b00000;
  /* mc68881_packed_decimal_unit.vhd:145:10  */
  always @*
    rsp_valid_reg = n7202; // (isignal)
  initial
    rsp_valid_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:146:10  */
  always @*
    rsp_word_reg = n7204; // (isignal)
  initial
    rsp_word_reg = 96'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:147:10  */
  always @*
    rsp_fp_reg = n7206; // (isignal)
  initial
    rsp_fp_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:148:10  */
  always @*
    rsp_inexact_reg = n7208; // (isignal)
  initial
    rsp_inexact_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:149:10  */
  always @*
    rsp_invalid_reg = n7210; // (isignal)
  initial
    rsp_invalid_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:151:10  */
  always @*
    arith_stage_reg = n7211; // (isignal)
  initial
    arith_stage_reg = 2'b00;
  /* mc68881_packed_decimal_unit.vhd:152:10  */
  always @*
    arith_hold_count_reg = n7212; // (isignal)
  initial
    arith_hold_count_reg = 3'b000;
  /* mc68881_packed_decimal_unit.vhd:153:10  */
  always @*
    arith_commit_reg = n7213; // (isignal)
  initial
    arith_commit_reg = 3'b000;
  /* mc68881_packed_decimal_unit.vhd:154:10  */
  always @*
    arith_tune_exp_delta_reg = n7215; // (isignal)
  initial
    arith_tune_exp_delta_reg = 2'b00;
  /* mc68881_packed_decimal_unit.vhd:155:10  */
  always @*
    arith_mul_a_reg = n7217; // (isignal)
  initial
    arith_mul_a_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:156:10  */
  always @*
    arith_mul_b_reg = n7219; // (isignal)
  initial
    arith_mul_b_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:157:10  */
  always @*
    arith_add_a_reg = n7221; // (isignal)
  initial
    arith_add_a_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:158:10  */
  always @*
    arith_add_b_reg = n7223; // (isignal)
  initial
    arith_add_b_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:159:10  */
  always @*
    arith_add_sub_reg = n7225; // (isignal)
  initial
    arith_add_sub_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:160:10  */
  always @*
    arith_int_arg_reg = n7227; // (isignal)
  initial
    arith_int_arg_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:161:10  */
  always @*
    arith_mul_res_reg = n7229; // (isignal)
  initial
    arith_mul_res_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:162:10  */
  always @*
    arith_add_res_reg = n7231; // (isignal)
  initial
    arith_add_res_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:163:10  */
  always @*
    arith_int_res_reg = n7233; // (isignal)
  initial
    arith_int_res_reg = 5'b00000;
  /* mc68881_packed_decimal_unit.vhd:165:10  */
  always @*
    packed_mul_start_reg = n7234; // (isignal)
  initial
    packed_mul_start_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:166:10  */
  always @*
    packed_add_start_reg = n7235; // (isignal)
  initial
    packed_add_start_reg = 1'b0;
  /* mc68881_packed_decimal_unit.vhd:169:10  */
  always @*
    shadow_word0 = n7236; // (isignal)
  initial
    shadow_word0 = 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:170:10  */
  always @*
    shadow_word1 = n7237; // (isignal)
  initial
    shadow_word1 = 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:171:10  */
  always @*
    shadow_word2 = n7238; // (isignal)
  initial
    shadow_word2 = 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:237:41  */
  assign n59 = scale_abs_exp_reg[11:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:248:30  */
  assign n62 = state_reg != 5'b00000;
  /* mc68881_packed_decimal_unit.vhd:248:15  */
  assign n63 = n62 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:294:16  */
  assign n104 = ~reset_n;
  /* mc68881_packed_decimal_unit.vhd:352:26  */
  assign n107 = arith_stage_reg == 2'b01;
  /* mc68881_packed_decimal_unit.vhd:356:37  */
  assign n108 = {29'b0, arith_hold_count_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:356:37  */
  assign n110 = n108 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:359:13  */
  assign n112 = fp_mul_done ? 2'b10 : arith_stage_reg;
  /* mc68881_packed_decimal_unit.vhd:359:13  */
  assign n113 = fp_mul_done ? fp_mul_result : arith_mul_res_reg;
  /* mc68881_packed_decimal_unit.vhd:356:13  */
  assign n114 = n110 ? arith_stage_reg : n112;
  /* mc68881_packed_decimal_unit.vhd:356:13  */
  assign n116 = n110 ? 3'b001 : arith_hold_count_reg;
  /* mc68881_packed_decimal_unit.vhd:356:13  */
  assign n117 = n110 ? arith_mul_res_reg : n113;
  /* mc68881_packed_decimal_unit.vhd:356:13  */
  assign n120 = n110 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:354:11  */
  assign n122 = arith_commit_reg == 3'b001;
  /* mc68881_packed_decimal_unit.vhd:354:31  */
  assign n124 = arith_commit_reg == 3'b010;
  /* mc68881_packed_decimal_unit.vhd:354:31  */
  assign n125 = n122 | n124;
  /* mc68881_packed_decimal_unit.vhd:354:47  */
  assign n127 = arith_commit_reg == 3'b011;
  /* mc68881_packed_decimal_unit.vhd:354:47  */
  assign n128 = n125 | n127;
  /* mc68881_packed_decimal_unit.vhd:354:61  */
  assign n130 = arith_commit_reg == 3'b110;
  /* mc68881_packed_decimal_unit.vhd:354:61  */
  assign n131 = n128 | n130;
  /* mc68881_packed_decimal_unit.vhd:365:37  */
  assign n132 = {29'b0, arith_hold_count_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:365:37  */
  assign n134 = n132 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:368:13  */
  assign n136 = fp_add_done ? 2'b10 : arith_stage_reg;
  /* mc68881_packed_decimal_unit.vhd:368:13  */
  assign n137 = fp_add_done ? fp_add_result : arith_add_res_reg;
  /* mc68881_packed_decimal_unit.vhd:365:13  */
  assign n138 = n134 ? arith_stage_reg : n136;
  /* mc68881_packed_decimal_unit.vhd:365:13  */
  assign n140 = n134 ? 3'b001 : arith_hold_count_reg;
  /* mc68881_packed_decimal_unit.vhd:365:13  */
  assign n141 = n134 ? arith_add_res_reg : n137;
  /* mc68881_packed_decimal_unit.vhd:365:13  */
  assign n144 = n134 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:363:11  */
  assign n146 = arith_commit_reg == 3'b101;
  /* mc68881_packed_decimal_unit.vhd:374:37  */
  assign n147 = {29'b0, arith_hold_count_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:374:37  */
  assign n149 = n147 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:375:60  */
  assign n150 = {29'b0, arith_hold_count_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:375:60  */
  assign n152 = n150 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:375:39  */
  assign n153 = n152[2:0];  // trunc
  /* mc68881_pkg.vhd:1535:25  */
  assign n166 = arith_int_arg_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n169 = arith_int_arg_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n171 = arith_int_arg_reg[63:0]; // extract
  assign n172 = {n171, n169, n166};
  /* mc68881_pkg.vhd:2225:16  */
  assign n177 = n172[15:1]; // extract
  /* mc68881_pkg.vhd:2225:20  */
  assign n179 = n177 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2225:35  */
  assign n180 = n172[15:1]; // extract
  /* mc68881_pkg.vhd:2225:39  */
  assign n182 = n180 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2225:24  */
  assign n183 = n179 | n182;
  /* mc68881_pkg.vhd:2225:5  */
  assign n187 = n183 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:2225:5  */
  assign n193 = n183 ? 32'b00000000000000000000000000000000 : 32'bX;
  /* mc68881_pkg.vhd:2229:33  */
  assign n194 = n172[15:1]; // extract
  /* mc68881_pkg.vhd:2229:14  */
  assign n195 = {16'b0, n194};  //  uext
  /* mc68881_pkg.vhd:2229:5  */
  assign n196 = {1'b0, n195};  //  uext
  /* mc68881_pkg.vhd:2229:5  */
  assign n198 = n187 ? n196 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2230:20  */
  assign n201 = n198 - 32'b00000000000000000011111111111111;
  /* mc68881_pkg.vhd:2230:5  */
  assign n203 = n187 ? n201 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2231:14  */
  assign n206 = $signed(n203) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_pkg.vhd:2231:5  */
  assign n209 = n216 ? 1'b0 : n187;
  /* mc68881_pkg.vhd:2231:5  */
  assign n212 = n218 ? 32'b00000000000000000000000000000000 : n193;
  /* mc68881_pkg.vhd:2231:5  */
  assign n213 = n187 & n206;
  /* mc68881_pkg.vhd:2231:5  */
  assign n215 = n187 & n206;
  /* mc68881_pkg.vhd:2231:5  */
  assign n216 = n213 & n187;
  /* mc68881_pkg.vhd:2231:5  */
  assign n218 = n215 & n187;
  /* mc68881_pkg.vhd:2235:14  */
  assign n220 = $signed(n203) > $signed(32'b00000000000000000000000000011110);
  /* mc68881_pkg.vhd:2236:18  */
  assign n221 = n172[0]; // extract
  /* mc68881_pkg.vhd:2236:7  */
  assign n224 = n231 ? 1'b0 : n209;
  /* mc68881_pkg.vhd:2236:7  */
  assign n227 = n233 ? 32'b10000000000000000000000000000000 : n212;
  /* mc68881_pkg.vhd:2236:7  */
  assign n228 = n209 & n221;
  /* mc68881_pkg.vhd:2236:7  */
  assign n230 = n209 & n221;
  /* mc68881_pkg.vhd:2236:7  */
  assign n231 = n228 & n209;
  /* mc68881_pkg.vhd:2236:7  */
  assign n233 = n230 & n209;
  /* mc68881_pkg.vhd:2239:7  */
  assign n236 = n224 ? 1'b0 : n224;
  /* mc68881_pkg.vhd:2239:7  */
  assign n239 = n224 ? 32'b01111111111111111111111111111111 : n227;
  /* mc68881_pkg.vhd:2235:5  */
  assign n240 = n243 ? n236 : n209;
  /* mc68881_pkg.vhd:2235:5  */
  assign n242 = n245 ? n239 : n212;
  /* mc68881_pkg.vhd:2235:5  */
  assign n243 = n220 & n209;
  /* mc68881_pkg.vhd:2235:5  */
  assign n245 = n220 & n209;
  /* mc68881_pkg.vhd:2242:47  */
  assign n246 = n172[79:16]; // extract
  /* mc68881_pkg.vhd:2242:68  */
  assign n248 = 32'b00000000000000000000000000111111 - n203;
  /* mc68881_pkg.vhd:2242:53  */
  assign n249 = n248[30:0];  // trunc
  /* mc68881_pkg.vhd:2242:27  */
  assign n250 = n246 >> n249;
  /* mc68881_pkg.vhd:2242:5  */
  assign n252 = n240 ? n250 : 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2243:20  */
  assign n255 = $unsigned(n252) > $unsigned(64'b0000000000000000000000000000000001111111111111111111111111111111);
  /* mc68881_pkg.vhd:2244:18  */
  assign n256 = n172[0]; // extract
  /* mc68881_pkg.vhd:2244:7  */
  assign n259 = n266 ? 1'b0 : n240;
  /* mc68881_pkg.vhd:2244:7  */
  assign n262 = n268 ? 32'b10000000000000000000000000000000 : n242;
  /* mc68881_pkg.vhd:2244:7  */
  assign n263 = n240 & n256;
  /* mc68881_pkg.vhd:2244:7  */
  assign n265 = n240 & n256;
  /* mc68881_pkg.vhd:2244:7  */
  assign n266 = n263 & n240;
  /* mc68881_pkg.vhd:2244:7  */
  assign n268 = n265 & n240;
  /* mc68881_pkg.vhd:2247:7  */
  assign n271 = n259 ? 1'b0 : n259;
  /* mc68881_pkg.vhd:2247:7  */
  assign n274 = n259 ? 32'b01111111111111111111111111111111 : n262;
  /* mc68881_pkg.vhd:2243:5  */
  assign n275 = n278 ? n271 : n240;
  /* mc68881_pkg.vhd:2243:5  */
  assign n277 = n280 ? n274 : n242;
  /* mc68881_pkg.vhd:2243:5  */
  assign n278 = n255 & n240;
  /* mc68881_pkg.vhd:2243:5  */
  assign n280 = n255 & n240;
  /* mc68881_pkg.vhd:2251:38  */
  assign n281 = n252[30:0]; // extract
  /* mc68881_pkg.vhd:2251:5  */
  assign n282 = {1'b0, n281};  //  uext
  /* mc68881_pkg.vhd:2251:5  */
  assign n284 = n275 ? n282 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2252:16  */
  assign n286 = n172[0]; // extract
  /* mc68881_pkg.vhd:2253:14  */
  assign n287 = -n284;
  /* mc68881_pkg.vhd:2252:5  */
  assign n289 = n296 ? 1'b0 : n275;
  /* mc68881_pkg.vhd:2252:5  */
  assign n292 = n298 ? n287 : n277;
  /* mc68881_pkg.vhd:2252:5  */
  assign n293 = n275 & n286;
  /* mc68881_pkg.vhd:2252:5  */
  assign n295 = n275 & n286;
  /* mc68881_pkg.vhd:2252:5  */
  assign n296 = n293 & n275;
  /* mc68881_pkg.vhd:2252:5  */
  assign n298 = n295 & n275;
  /* mc68881_pkg.vhd:2255:5  */
  assign n303 = n289 ? n284 : n292;
  /* mc68881_packed_decimal_unit.vhd:193:14  */
  assign n309 = $signed(n303) < $signed(32'b11111111111111111111111111111111);
  /* mc68881_packed_decimal_unit.vhd:195:17  */
  assign n312 = $signed(n303) > $signed(32'b00000000000000000000000000001111);
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n316 = n312 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n320 = n312 ? 32'b00000000000000000000000000001111 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n322 = n309 ? 1'b0 : n316;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n327 = n309 ? 32'b11111111111111111111111111111111 : n320;
  /* mc68881_packed_decimal_unit.vhd:198:5  */
  assign n332 = n322 ? n303 : n327;
  /* mc68881_packed_decimal_unit.vhd:377:36  */
  assign n333 = n332[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:374:13  */
  assign n335 = n149 ? arith_stage_reg : 2'b10;
  /* mc68881_packed_decimal_unit.vhd:374:13  */
  assign n336 = n149 ? n153 : arith_hold_count_reg;
  /* mc68881_packed_decimal_unit.vhd:374:13  */
  assign n337 = n149 ? arith_int_res_reg : n333;
  /* mc68881_packed_decimal_unit.vhd:372:11  */
  assign n339 = arith_commit_reg == 3'b100;
  /* mc68881_packed_decimal_unit.vhd:372:33  */
  assign n341 = arith_commit_reg == 3'b111;
  /* mc68881_packed_decimal_unit.vhd:372:33  */
  assign n342 = n339 | n341;
  assign n343 = {n342, n146, n131};
  /* mc68881_packed_decimal_unit.vhd:353:9  */
  always @*
    case (n343)
      3'b100: n345 = n335;
      3'b010: n345 = n138;
      3'b001: n345 = n114;
      default: n345 = 2'b10;
    endcase
  /* mc68881_packed_decimal_unit.vhd:353:9  */
  always @*
    case (n343)
      3'b100: n346 = n336;
      3'b010: n346 = n140;
      3'b001: n346 = n116;
      default: n346 = arith_hold_count_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:353:9  */
  always @*
    case (n343)
      3'b100: n347 = arith_mul_res_reg;
      3'b010: n347 = arith_mul_res_reg;
      3'b001: n347 = n117;
      default: n347 = arith_mul_res_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:353:9  */
  always @*
    case (n343)
      3'b100: n348 = arith_add_res_reg;
      3'b010: n348 = n141;
      3'b001: n348 = arith_add_res_reg;
      default: n348 = arith_add_res_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:353:9  */
  always @*
    case (n343)
      3'b100: n349 = n337;
      3'b010: n349 = arith_int_res_reg;
      3'b001: n349 = arith_int_res_reg;
      default: n349 = arith_int_res_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:353:9  */
  always @*
    case (n343)
      3'b100: n351 = 1'b0;
      3'b010: n351 = 1'b0;
      3'b001: n351 = n120;
      default: n351 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:353:9  */
  always @*
    case (n343)
      3'b100: n353 = 1'b0;
      3'b010: n353 = n144;
      3'b001: n353 = 1'b0;
      default: n353 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:383:29  */
  assign n355 = arith_stage_reg == 2'b10;
  /* mc68881_packed_decimal_unit.vhd:387:52  */
  assign n356 = {18'b0, scale_abs_exp_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:387:52  */
  assign n358 = n356 - 32'b00000000000000000001000000000000;
  /* mc68881_packed_decimal_unit.vhd:387:34  */
  assign n359 = n358[13:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:385:11  */
  assign n361 = arith_commit_reg == 3'b001;
  /* mc68881_packed_decimal_unit.vhd:391:52  */
  assign n362 = {28'b0, scale_bit_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:391:52  */
  assign n364 = n362 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:391:34  */
  assign n365 = n364[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:389:11  */
  assign n367 = arith_commit_reg == 3'b010;
  /* mc68881_packed_decimal_unit.vhd:395:36  */
  assign n368 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:395:36  */
  assign n369 = {{30{arith_tune_exp_delta_reg[1]}}, arith_tune_exp_delta_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:395:36  */
  assign n370 = n368 + n369;
  /* mc68881_packed_decimal_unit.vhd:395:26  */
  assign n371 = n370[14:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:393:11  */
  assign n373 = arith_commit_reg == 3'b011;
  /* mc68881_packed_decimal_unit.vhd:398:34  */
  assign n374 = {{27{arith_int_res_reg[4]}}, arith_int_res_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:398:34  */
  assign n376 = $signed(n374) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:400:37  */
  assign n377 = {{27{arith_int_res_reg[4]}}, arith_int_res_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:400:37  */
  assign n379 = $signed(n377) > $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:403:35  */
  assign n380 = {{26{arith_int_res_reg[4]}}, arith_int_res_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:400:13  */
  assign n382 = n379 ? 31'b0000000000000000000000000001001 : n380;
  /* mc68881_packed_decimal_unit.vhd:398:13  */
  assign n384 = n376 ? 31'b0000000000000000000000000000000 : n382;
  /* mc68881_packed_decimal_unit.vhd:405:30  */
  assign n385 = n384[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:397:11  */
  assign n387 = arith_commit_reg == 3'b100;
  /* mc68881_packed_decimal_unit.vhd:408:11  */
  assign n389 = arith_commit_reg == 3'b101;
  /* mc68881_packed_decimal_unit.vhd:413:24  */
  assign n391 = 5'b10000 - idx_reg;
  /* mc68881_packed_decimal_unit.vhd:415:24  */
  assign n394 = {27'b0, idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:415:24  */
  assign n396 = n394 == 32'b00000000000000000000000000010000;
  /* mc68881_packed_decimal_unit.vhd:418:34  */
  assign n397 = {27'b0, idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:418:34  */
  assign n399 = n397 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:418:26  */
  assign n400 = n399[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:415:13  */
  assign n403 = n396 ? 5'b01010 : 5'b00111;
  /* mc68881_packed_decimal_unit.vhd:415:13  */
  assign n404 = n396 ? idx_reg : n400;
  /* mc68881_packed_decimal_unit.vhd:412:11  */
  assign n406 = arith_commit_reg == 3'b110;
  /* mc68881_packed_decimal_unit.vhd:423:13  */
  assign n407 = {{27{arith_int_res_reg[4]}}, arith_int_res_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:424:26  */
  assign n409 = $signed(n407) >= $signed(32'b00000000000000000000000000000101);
  /* mc68881_packed_decimal_unit.vhd:430:42  */
  assign n411 = {{25{req_k_reg[6]}}, req_k_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:193:14  */
  assign n417 = $signed(n411) < $signed(32'b11111111111111111111111111000000);
  /* mc68881_packed_decimal_unit.vhd:195:17  */
  assign n420 = $signed(n411) > $signed(32'b00000000000000000000000000010001);
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n424 = n420 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n428 = n420 ? 32'b00000000000000000000000000010001 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n430 = n417 ? 1'b0 : n424;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n435 = n417 ? 32'b11111111111111111111111111000000 : n428;
  /* mc68881_packed_decimal_unit.vhd:198:5  */
  assign n440 = n430 ? n411 : n435;
  /* mc68881_packed_decimal_unit.vhd:431:28  */
  assign n442 = $signed(n440) > $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:434:42  */
  assign n443 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:434:42  */
  assign n445 = n443 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:434:49  */
  assign n446 = -n440;
  /* mc68881_packed_decimal_unit.vhd:434:46  */
  assign n447 = n445 + n446;
  /* mc68881_packed_decimal_unit.vhd:431:15  */
  assign n448 = n442 ? n440 : n447;
  /* mc68881_packed_decimal_unit.vhd:437:30  */
  assign n450 = $signed(n448) < $signed(32'b00000000000000000000000000000001);
  /* mc68881_packed_decimal_unit.vhd:439:33  */
  assign n452 = $signed(n448) > $signed(32'b00000000000000000000000000010001);
  /* mc68881_packed_decimal_unit.vhd:439:15  */
  assign n454 = n452 ? 32'b00000000000000000000000000010001 : n448;
  /* mc68881_packed_decimal_unit.vhd:437:15  */
  assign n456 = n450 ? 32'b00000000000000000000000000000001 : n454;
  /* mc68881_packed_decimal_unit.vhd:443:34  */
  assign n457 = n456[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:424:13  */
  assign n460 = n409 ? 5'b01011 : 5'b01100;
  /* mc68881_packed_decimal_unit.vhd:424:13  */
  assign n461 = n409 ? keep_digits_reg : n457;
  /* mc68881_packed_decimal_unit.vhd:424:13  */
  assign n463 = n409 ? 1'b1 : kround_carry_reg;
  /* mc68881_packed_decimal_unit.vhd:424:13  */
  assign n465 = n409 ? 5'b10000 : kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:422:11  */
  assign n469 = arith_commit_reg == 3'b111;
  assign n470 = {n469, n406, n389, n387, n373, n367, n361};
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n473 = n460;
      7'b0100000: n473 = n403;
      7'b0010000: n473 = 5'b01001;
      7'b0001000: n473 = 5'b01000;
      7'b0000100: n473 = state_reg;
      7'b0000010: n473 = state_reg;
      7'b0000001: n473 = state_reg;
      default: n473 = state_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n474 = exp10_reg;
      7'b0100000: n474 = exp10_reg;
      7'b0010000: n474 = exp10_reg;
      7'b0001000: n474 = exp10_reg;
      7'b0000100: n474 = n371;
      7'b0000010: n474 = exp10_reg;
      7'b0000001: n474 = exp10_reg;
      default: n474 = exp10_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n475 = work_fp_reg;
      7'b0100000: n475 = arith_mul_res_reg;
      7'b0010000: n475 = arith_add_res_reg;
      7'b0001000: n475 = work_fp_reg;
      7'b0000100: n475 = arith_mul_res_reg;
      7'b0000010: n475 = arith_mul_res_reg;
      7'b0000001: n475 = arith_mul_res_reg;
      default: n475 = work_fp_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n476 = digits_reg;
      7'b0100000: n476 = n7317;
      7'b0010000: n476 = digits_reg;
      7'b0001000: n476 = digits_reg;
      7'b0000100: n476 = digits_reg;
      7'b0000010: n476 = digits_reg;
      7'b0000001: n476 = digits_reg;
      default: n476 = digits_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n477 = enc_digit_reg;
      7'b0100000: n477 = enc_digit_reg;
      7'b0010000: n477 = enc_digit_reg;
      7'b0001000: n477 = n385;
      7'b0000100: n477 = enc_digit_reg;
      7'b0000010: n477 = enc_digit_reg;
      7'b0000001: n477 = enc_digit_reg;
      default: n477 = enc_digit_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n478 = idx_reg;
      7'b0100000: n478 = n404;
      7'b0010000: n478 = idx_reg;
      7'b0001000: n478 = idx_reg;
      7'b0000100: n478 = idx_reg;
      7'b0000010: n478 = idx_reg;
      7'b0000001: n478 = idx_reg;
      default: n478 = idx_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n479 = n461;
      7'b0100000: n479 = keep_digits_reg;
      7'b0010000: n479 = keep_digits_reg;
      7'b0001000: n479 = keep_digits_reg;
      7'b0000100: n479 = keep_digits_reg;
      7'b0000010: n479 = keep_digits_reg;
      7'b0000001: n479 = keep_digits_reg;
      default: n479 = keep_digits_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n480 = scale_abs_exp_reg;
      7'b0100000: n480 = scale_abs_exp_reg;
      7'b0010000: n480 = scale_abs_exp_reg;
      7'b0001000: n480 = scale_abs_exp_reg;
      7'b0000100: n480 = scale_abs_exp_reg;
      7'b0000010: n480 = scale_abs_exp_reg;
      7'b0000001: n480 = n359;
      default: n480 = scale_abs_exp_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n481 = scale_bit_idx_reg;
      7'b0100000: n481 = scale_bit_idx_reg;
      7'b0010000: n481 = scale_bit_idx_reg;
      7'b0001000: n481 = scale_bit_idx_reg;
      7'b0000100: n481 = scale_bit_idx_reg;
      7'b0000010: n481 = n365;
      7'b0000001: n481 = scale_bit_idx_reg;
      default: n481 = scale_bit_idx_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n482 = n463;
      7'b0100000: n482 = kround_carry_reg;
      7'b0010000: n482 = kround_carry_reg;
      7'b0001000: n482 = kround_carry_reg;
      7'b0000100: n482 = kround_carry_reg;
      7'b0000010: n482 = kround_carry_reg;
      7'b0000001: n482 = kround_carry_reg;
      default: n482 = kround_carry_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:384:9  */
  always @*
    case (n470)
      7'b1000000: n483 = n465;
      7'b0100000: n483 = kround_idx_reg;
      7'b0010000: n483 = kround_idx_reg;
      7'b0001000: n483 = kround_idx_reg;
      7'b0000100: n483 = kround_idx_reg;
      7'b0000010: n483 = kround_idx_reg;
      7'b0000001: n483 = kround_idx_reg;
      default: n483 = kround_idx_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n488 = n355 ? n473 : state_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n489 = n355 ? n474 : exp10_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n490 = n355 ? n475 : work_fp_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n491 = n355 ? n476 : digits_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n492 = n355 ? n477 : enc_digit_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n493 = n355 ? n478 : idx_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n494 = n355 ? n479 : keep_digits_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n495 = n355 ? n480 : scale_abs_exp_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n496 = n355 ? n481 : scale_bit_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n497 = n355 ? n482 : kround_carry_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n498 = n355 ? n483 : kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n500 = n355 ? 2'b00 : arith_stage_reg;
  /* mc68881_packed_decimal_unit.vhd:383:7  */
  assign n502 = n355 ? 3'b000 : arith_commit_reg;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n507 = n107 ? state_reg : n488;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n508 = n107 ? exp10_reg : n489;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n509 = n107 ? work_fp_reg : n490;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n510 = n107 ? digits_reg : n491;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n511 = n107 ? enc_digit_reg : n492;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n512 = n107 ? idx_reg : n493;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n513 = n107 ? keep_digits_reg : n494;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n514 = n107 ? scale_abs_exp_reg : n495;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n515 = n107 ? scale_bit_idx_reg : n496;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n516 = n107 ? kround_carry_reg : n497;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n517 = n107 ? kround_idx_reg : n498;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n518 = n107 ? n345 : n500;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n519 = n107 ? n346 : arith_hold_count_reg;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n520 = n107 ? arith_commit_reg : n502;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n525 = n107 ? n351 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:352:7  */
  assign n528 = n107 ? n353 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:26  */
  assign n535 = arith_stage_reg == 2'b00;
  /* mc68881_packed_decimal_unit.vhd:468:33  */
  assign n536 = req_fp[79]; // extract
  /* mc68881_packed_decimal_unit.vhd:471:35  */
  assign n537 = req_word[95]; // extract
  /* mc68881_packed_decimal_unit.vhd:474:31  */
  assign n538 = req_word[93:92]; // extract
  /* mc68881_packed_decimal_unit.vhd:474:46  */
  assign n540 = n538 == 2'b11;
  /* mc68881_packed_decimal_unit.vhd:476:53  */
  assign n541 = req_word[95]; // extract
  assign n547 = n542[62:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:479:33  */
  assign n548 = req_word[67:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:479:47  */
  assign n550 = n548 != 68'b00000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:479:17  */
  assign n552 = n550 ? 63'b111111111111111111111111111111111111111111111111111111111111111 : n547;
  assign n553 = {n541, 15'b111111111111111, 1'b1, n552};
  /* mc68881_packed_decimal_unit.vhd:488:55  */
  assign n555 = req_word[83:80]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n561 = {27'b0, n555};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n562 = {1'b0, n561};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n565 = $signed(n562) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n567 = $signed(n562) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n568 = n567 & n565;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n571 = n568 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n577 = n568 ? n562 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n583 = n571 ? 32'b11111111111111111111111111111111 : n577;
  /* mc68881_packed_decimal_unit.vhd:489:55  */
  assign n585 = req_word[87:84]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n591 = {27'b0, n585};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n592 = {1'b0, n591};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n595 = $signed(n592) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n597 = $signed(n592) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n598 = n597 & n595;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n601 = n598 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n607 = n598 ? n592 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n613 = n601 ? 32'b11111111111111111111111111111111 : n607;
  /* mc68881_packed_decimal_unit.vhd:490:55  */
  assign n615 = req_word[91:88]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n621 = {27'b0, n615};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n622 = {1'b0, n621};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n625 = $signed(n622) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n627 = $signed(n622) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n628 = n627 & n625;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n631 = n628 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n637 = n628 ? n622 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n643 = n631 ? 32'b11111111111111111111111111111111 : n637;
  /* mc68881_packed_decimal_unit.vhd:491:55  */
  assign n645 = req_word[79:76]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n651 = {27'b0, n645};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n652 = {1'b0, n651};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n655 = $signed(n652) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n657 = $signed(n652) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n658 = n657 & n655;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n661 = n658 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n667 = n658 ? n652 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n673 = n661 ? 32'b11111111111111111111111111111111 : n667;
  /* mc68881_packed_decimal_unit.vhd:492:55  */
  assign n675 = req_word[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n681 = {27'b0, n675};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n682 = {1'b0, n681};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n685 = $signed(n682) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n687 = $signed(n682) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n688 = n687 & n685;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n691 = n688 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n697 = n688 ? n682 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n703 = n691 ? 32'b11111111111111111111111111111111 : n697;
  /* mc68881_packed_decimal_unit.vhd:494:27  */
  assign n705 = $signed(n583) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:494:41  */
  assign n707 = $signed(n613) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:494:31  */
  assign n708 = n705 | n707;
  /* mc68881_packed_decimal_unit.vhd:494:55  */
  assign n710 = $signed(n643) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:494:45  */
  assign n711 = n708 | n710;
  /* mc68881_packed_decimal_unit.vhd:494:69  */
  assign n713 = $signed(n673) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:494:59  */
  assign n714 = n711 | n713;
  /* mc68881_packed_decimal_unit.vhd:494:83  */
  assign n716 = $signed(n703) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:494:73  */
  assign n717 = n714 | n716;
  /* mc68881_packed_decimal_unit.vhd:501:40  */
  assign n719 = $signed(n673) * $signed(32'b00000000000000000000001111101000); // smul
  /* mc68881_packed_decimal_unit.vhd:501:54  */
  assign n721 = $signed(n643) * $signed(32'b00000000000000000000000001100100); // smul
  /* mc68881_packed_decimal_unit.vhd:501:46  */
  assign n722 = n719 + n721;
  /* mc68881_packed_decimal_unit.vhd:501:67  */
  assign n724 = $signed(n613) * $signed(32'b00000000000000000000000000001010); // smul
  /* mc68881_packed_decimal_unit.vhd:501:59  */
  assign n725 = n722 + n724;
  /* mc68881_packed_decimal_unit.vhd:501:71  */
  assign n726 = n725 + n583;
  /* mc68881_packed_decimal_unit.vhd:502:35  */
  assign n727 = req_word[94]; // extract
  /* mc68881_packed_decimal_unit.vhd:503:36  */
  assign n728 = -n726;
  /* mc68881_packed_decimal_unit.vhd:502:19  */
  assign n729 = n727 ? n728 : n726;
  /* mc68881_packed_decimal_unit.vhd:507:41  */
  assign n730 = n703[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:507:19  */
  assign n731 = n730[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:508:39  */
  assign n735 = n703 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n738 = req_word[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n744 = {27'b0, n738};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n745 = {1'b0, n744};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n748 = $signed(n745) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n750 = $signed(n745) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n751 = n750 & n748;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n754 = n751 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n760 = n751 ? n745 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n766 = n754 ? 32'b11111111111111111111111111111111 : n760;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n768 = $signed(n766) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n771 = n768 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n773 = n768 ? 1'b0 : n735;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n776 = n768 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n778 = n766[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n779 = n778[3:0];  // trunc
  assign n780 = n732[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n781 = n771 ? n779 : n780;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n784 = n766 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n786 = n788 ? 1'b0 : n773;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n787 = n771 & n784;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n788 = n787 & n771;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n790 = req_word[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n796 = {27'b0, n790};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n797 = {1'b0, n796};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n800 = $signed(n797) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n802 = $signed(n797) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n803 = n802 & n800;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n806 = n803 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n812 = n803 ? n797 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n818 = n806 ? 32'b11111111111111111111111111111111 : n812;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n819 = n776 ? n818 : n766;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n821 = $signed(n819) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n823 = n832 ? 1'b0 : n786;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n825 = n831 ? 1'b0 : n776;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n827 = n833 ? 1'b0 : n776;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n828 = n776 & n821;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n829 = n776 & n821;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n830 = n776 & n821;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n831 = n828 & n776;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n832 = n829 & n776;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n833 = n830 & n776;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n834 = n819[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n835 = n834[3:0];  // trunc
  assign n836 = n732[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n837 = n825 ? n835 : n836;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n840 = n819 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n842 = n844 ? 1'b0 : n823;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n843 = n825 & n840;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n844 = n843 & n825;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n846 = req_word[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n852 = {27'b0, n846};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n853 = {1'b0, n852};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n856 = $signed(n853) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n858 = $signed(n853) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n859 = n858 & n856;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n862 = n859 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n868 = n859 ? n853 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n874 = n862 ? 32'b11111111111111111111111111111111 : n868;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n875 = n827 ? n874 : n819;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n877 = $signed(n875) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n879 = n888 ? 1'b0 : n842;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n881 = n887 ? 1'b0 : n827;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n883 = n889 ? 1'b0 : n827;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n884 = n827 & n877;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n885 = n827 & n877;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n886 = n827 & n877;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n887 = n884 & n827;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n888 = n885 & n827;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n889 = n886 & n827;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n890 = n875[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n891 = n890[3:0];  // trunc
  assign n892 = n732[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n893 = n881 ? n891 : n892;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n896 = n875 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n898 = n900 ? 1'b0 : n879;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n899 = n881 & n896;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n900 = n899 & n881;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n902 = req_word[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n908 = {27'b0, n902};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n909 = {1'b0, n908};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n912 = $signed(n909) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n914 = $signed(n909) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n915 = n914 & n912;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n918 = n915 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n924 = n915 ? n909 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n930 = n918 ? 32'b11111111111111111111111111111111 : n924;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n931 = n883 ? n930 : n875;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n933 = $signed(n931) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n935 = n944 ? 1'b0 : n898;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n937 = n943 ? 1'b0 : n883;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n939 = n945 ? 1'b0 : n883;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n940 = n883 & n933;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n941 = n883 & n933;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n942 = n883 & n933;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n943 = n940 & n883;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n944 = n941 & n883;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n945 = n942 & n883;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n946 = n931[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n947 = n946[3:0];  // trunc
  assign n948 = n732[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n949 = n937 ? n947 : n948;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n952 = n931 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n954 = n956 ? 1'b0 : n935;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n955 = n937 & n952;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n956 = n955 & n937;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n958 = req_word[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n964 = {27'b0, n958};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n965 = {1'b0, n964};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n968 = $signed(n965) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n970 = $signed(n965) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n971 = n970 & n968;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n974 = n971 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n980 = n971 ? n965 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n986 = n974 ? 32'b11111111111111111111111111111111 : n980;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n987 = n939 ? n986 : n931;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n989 = $signed(n987) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n991 = n1000 ? 1'b0 : n954;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n993 = n999 ? 1'b0 : n939;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n995 = n1001 ? 1'b0 : n939;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n996 = n939 & n989;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n997 = n939 & n989;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n998 = n939 & n989;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n999 = n996 & n939;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1000 = n997 & n939;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1001 = n998 & n939;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1002 = n987[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1003 = n1002[3:0];  // trunc
  assign n1004 = n732[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1005 = n993 ? n1003 : n1004;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1008 = n987 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1010 = n1012 ? 1'b0 : n991;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1011 = n993 & n1008;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1012 = n1011 & n993;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1014 = req_word[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1020 = {27'b0, n1014};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1021 = {1'b0, n1020};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1024 = $signed(n1021) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1026 = $signed(n1021) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1027 = n1026 & n1024;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1030 = n1027 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1036 = n1027 ? n1021 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1042 = n1030 ? 32'b11111111111111111111111111111111 : n1036;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1043 = n995 ? n1042 : n987;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1045 = $signed(n1043) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1047 = n1056 ? 1'b0 : n1010;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1049 = n1055 ? 1'b0 : n995;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1051 = n1057 ? 1'b0 : n995;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1052 = n995 & n1045;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1053 = n995 & n1045;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1054 = n995 & n1045;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1055 = n1052 & n995;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1056 = n1053 & n995;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1057 = n1054 & n995;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1058 = n1043[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1059 = n1058[3:0];  // trunc
  assign n1060 = n732[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1061 = n1049 ? n1059 : n1060;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1064 = n1043 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1066 = n1068 ? 1'b0 : n1047;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1067 = n1049 & n1064;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1068 = n1067 & n1049;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1070 = req_word[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1076 = {27'b0, n1070};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1077 = {1'b0, n1076};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1080 = $signed(n1077) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1082 = $signed(n1077) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1083 = n1082 & n1080;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1086 = n1083 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1092 = n1083 ? n1077 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1098 = n1086 ? 32'b11111111111111111111111111111111 : n1092;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1099 = n1051 ? n1098 : n1043;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1101 = $signed(n1099) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1103 = n1112 ? 1'b0 : n1066;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1105 = n1111 ? 1'b0 : n1051;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1107 = n1113 ? 1'b0 : n1051;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1108 = n1051 & n1101;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1109 = n1051 & n1101;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1110 = n1051 & n1101;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1111 = n1108 & n1051;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1112 = n1109 & n1051;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1113 = n1110 & n1051;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1114 = n1099[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1115 = n1114[3:0];  // trunc
  assign n1116 = n732[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1117 = n1105 ? n1115 : n1116;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1120 = n1099 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1122 = n1124 ? 1'b0 : n1103;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1123 = n1105 & n1120;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1124 = n1123 & n1105;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1126 = req_word[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1132 = {27'b0, n1126};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1133 = {1'b0, n1132};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1136 = $signed(n1133) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1138 = $signed(n1133) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1139 = n1138 & n1136;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1142 = n1139 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1148 = n1139 ? n1133 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1154 = n1142 ? 32'b11111111111111111111111111111111 : n1148;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1155 = n1107 ? n1154 : n1099;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1157 = $signed(n1155) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1159 = n1168 ? 1'b0 : n1122;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1161 = n1167 ? 1'b0 : n1107;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1163 = n1169 ? 1'b0 : n1107;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1164 = n1107 & n1157;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1165 = n1107 & n1157;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1166 = n1107 & n1157;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1167 = n1164 & n1107;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1168 = n1165 & n1107;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1169 = n1166 & n1107;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1170 = n1155[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1171 = n1170[3:0];  // trunc
  assign n1172 = n732[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1173 = n1161 ? n1171 : n1172;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1176 = n1155 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1178 = n1180 ? 1'b0 : n1159;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1179 = n1161 & n1176;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1180 = n1179 & n1161;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1182 = req_word[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1188 = {27'b0, n1182};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1189 = {1'b0, n1188};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1192 = $signed(n1189) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1194 = $signed(n1189) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1195 = n1194 & n1192;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1198 = n1195 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1204 = n1195 ? n1189 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1210 = n1198 ? 32'b11111111111111111111111111111111 : n1204;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1211 = n1163 ? n1210 : n1155;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1213 = $signed(n1211) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1215 = n1224 ? 1'b0 : n1178;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1217 = n1223 ? 1'b0 : n1163;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1219 = n1225 ? 1'b0 : n1163;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1220 = n1163 & n1213;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1221 = n1163 & n1213;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1222 = n1163 & n1213;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1223 = n1220 & n1163;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1224 = n1221 & n1163;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1225 = n1222 & n1163;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1226 = n1211[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1227 = n1226[3:0];  // trunc
  assign n1228 = n732[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1229 = n1217 ? n1227 : n1228;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1232 = n1211 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1234 = n1236 ? 1'b0 : n1215;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1235 = n1217 & n1232;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1236 = n1235 & n1217;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1238 = req_word[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1244 = {27'b0, n1238};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1245 = {1'b0, n1244};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1248 = $signed(n1245) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1250 = $signed(n1245) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1251 = n1250 & n1248;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1254 = n1251 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1260 = n1251 ? n1245 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1266 = n1254 ? 32'b11111111111111111111111111111111 : n1260;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1267 = n1219 ? n1266 : n1211;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1269 = $signed(n1267) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1271 = n1280 ? 1'b0 : n1234;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1273 = n1279 ? 1'b0 : n1219;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1275 = n1281 ? 1'b0 : n1219;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1276 = n1219 & n1269;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1277 = n1219 & n1269;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1278 = n1219 & n1269;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1279 = n1276 & n1219;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1280 = n1277 & n1219;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1281 = n1278 & n1219;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1282 = n1267[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1283 = n1282[3:0];  // trunc
  assign n1284 = n732[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1285 = n1273 ? n1283 : n1284;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1288 = n1267 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1290 = n1292 ? 1'b0 : n1271;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1291 = n1273 & n1288;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1292 = n1291 & n1273;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1294 = req_word[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1300 = {27'b0, n1294};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1301 = {1'b0, n1300};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1304 = $signed(n1301) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1306 = $signed(n1301) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1307 = n1306 & n1304;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1310 = n1307 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1316 = n1307 ? n1301 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1322 = n1310 ? 32'b11111111111111111111111111111111 : n1316;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1323 = n1275 ? n1322 : n1267;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1325 = $signed(n1323) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1327 = n1336 ? 1'b0 : n1290;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1329 = n1335 ? 1'b0 : n1275;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1331 = n1337 ? 1'b0 : n1275;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1332 = n1275 & n1325;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1333 = n1275 & n1325;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1334 = n1275 & n1325;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1335 = n1332 & n1275;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1336 = n1333 & n1275;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1337 = n1334 & n1275;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1338 = n1323[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1339 = n1338[3:0];  // trunc
  assign n1340 = n732[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1341 = n1329 ? n1339 : n1340;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1344 = n1323 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1346 = n1348 ? 1'b0 : n1327;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1347 = n1329 & n1344;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1348 = n1347 & n1329;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1350 = req_word[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1356 = {27'b0, n1350};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1357 = {1'b0, n1356};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1360 = $signed(n1357) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1362 = $signed(n1357) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1363 = n1362 & n1360;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1366 = n1363 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1372 = n1363 ? n1357 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1378 = n1366 ? 32'b11111111111111111111111111111111 : n1372;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1379 = n1331 ? n1378 : n1323;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1381 = $signed(n1379) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1383 = n1392 ? 1'b0 : n1346;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1385 = n1391 ? 1'b0 : n1331;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1387 = n1393 ? 1'b0 : n1331;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1388 = n1331 & n1381;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1389 = n1331 & n1381;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1390 = n1331 & n1381;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1391 = n1388 & n1331;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1392 = n1389 & n1331;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1393 = n1390 & n1331;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1394 = n1379[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1395 = n1394[3:0];  // trunc
  assign n1396 = n732[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1397 = n1385 ? n1395 : n1396;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1400 = n1379 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1402 = n1404 ? 1'b0 : n1383;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1403 = n1385 & n1400;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1404 = n1403 & n1385;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1406 = req_word[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1412 = {27'b0, n1406};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1413 = {1'b0, n1412};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1416 = $signed(n1413) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1418 = $signed(n1413) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1419 = n1418 & n1416;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1422 = n1419 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1428 = n1419 ? n1413 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1434 = n1422 ? 32'b11111111111111111111111111111111 : n1428;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1435 = n1387 ? n1434 : n1379;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1437 = $signed(n1435) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1439 = n1448 ? 1'b0 : n1402;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1441 = n1447 ? 1'b0 : n1387;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1443 = n1449 ? 1'b0 : n1387;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1444 = n1387 & n1437;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1445 = n1387 & n1437;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1446 = n1387 & n1437;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1447 = n1444 & n1387;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1448 = n1445 & n1387;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1449 = n1446 & n1387;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1450 = n1435[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1451 = n1450[3:0];  // trunc
  assign n1452 = n732[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1453 = n1441 ? n1451 : n1452;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1456 = n1435 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1458 = n1460 ? 1'b0 : n1439;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1459 = n1441 & n1456;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1460 = n1459 & n1441;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1462 = req_word[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1468 = {27'b0, n1462};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1469 = {1'b0, n1468};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1472 = $signed(n1469) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1474 = $signed(n1469) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1475 = n1474 & n1472;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1478 = n1475 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1484 = n1475 ? n1469 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1490 = n1478 ? 32'b11111111111111111111111111111111 : n1484;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1491 = n1443 ? n1490 : n1435;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1493 = $signed(n1491) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1495 = n1504 ? 1'b0 : n1458;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1497 = n1503 ? 1'b0 : n1443;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1499 = n1505 ? 1'b0 : n1443;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1500 = n1443 & n1493;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1501 = n1443 & n1493;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1502 = n1443 & n1493;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1503 = n1500 & n1443;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1504 = n1501 & n1443;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1505 = n1502 & n1443;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1506 = n1491[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1507 = n1506[3:0];  // trunc
  assign n1508 = n732[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1509 = n1497 ? n1507 : n1508;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1512 = n1491 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1514 = n1516 ? 1'b0 : n1495;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1515 = n1497 & n1512;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1516 = n1515 & n1497;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1518 = req_word[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1524 = {27'b0, n1518};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1525 = {1'b0, n1524};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1528 = $signed(n1525) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1530 = $signed(n1525) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1531 = n1530 & n1528;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1534 = n1531 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1540 = n1531 ? n1525 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1546 = n1534 ? 32'b11111111111111111111111111111111 : n1540;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1547 = n1499 ? n1546 : n1491;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1549 = $signed(n1547) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1551 = n1560 ? 1'b0 : n1514;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1553 = n1559 ? 1'b0 : n1499;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1555 = n1561 ? 1'b0 : n1499;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1556 = n1499 & n1549;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1557 = n1499 & n1549;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1558 = n1499 & n1549;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1559 = n1556 & n1499;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1560 = n1557 & n1499;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1561 = n1558 & n1499;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1562 = n1547[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1563 = n1562[3:0];  // trunc
  assign n1564 = n732[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1565 = n1553 ? n1563 : n1564;
  assign n1566 = n732[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1568 = n1547 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1570 = n1572 ? 1'b0 : n1551;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1571 = n1553 & n1568;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1572 = n1571 & n1553;
  /* mc68881_packed_decimal_unit.vhd:510:59  */
  assign n1574 = req_word[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:184:16  */
  assign n1580 = {27'b0, n1574};  //  uext
  /* mc68881_packed_decimal_unit.vhd:184:5  */
  assign n1581 = {1'b0, n1580};  //  uext
  /* mc68881_packed_decimal_unit.vhd:185:16  */
  assign n1584 = $signed(n1581) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:185:33  */
  assign n1586 = $signed(n1581) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:185:21  */
  assign n1587 = n1586 & n1584;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1590 = n1587 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:185:5  */
  assign n1596 = n1587 ? n1581 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:188:5  */
  assign n1602 = n1590 ? 32'b11111111111111111111111111111111 : n1596;
  /* mc68881_packed_decimal_unit.vhd:510:21  */
  assign n1603 = n1555 ? n1602 : n1547;
  /* mc68881_packed_decimal_unit.vhd:511:31  */
  assign n1605 = $signed(n1603) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1607 = n1616 ? 1'b0 : n1570;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1609 = n1615 ? 1'b0 : n1555;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1612 = n1555 & n1605;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1613 = n1555 & n1605;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1615 = n1612 & n1555;
  /* mc68881_packed_decimal_unit.vhd:511:21  */
  assign n1616 = n1613 & n1555;
  /* mc68881_packed_decimal_unit.vhd:515:51  */
  assign n1618 = n1603[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1619 = n1618[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:515:21  */
  assign n1620 = n1609 ? n1619 : n1566;
  /* mc68881_packed_decimal_unit.vhd:516:31  */
  assign n1622 = n1603 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1624 = n1626 ? 1'b0 : n1607;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1625 = n1609 & n1622;
  /* mc68881_packed_decimal_unit.vhd:516:21  */
  assign n1626 = n1625 & n1609;
  /* mc68881_packed_decimal_unit.vhd:521:29  */
  assign n1628 = $signed(n1603) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:529:57  */
  assign n1629 = req_word[95]; // extract
  assign n1631 = n1630[78:0]; // extract
  assign n1632 = {n1629, n1631};
  assign n1633 = {n731, n781, n837, n893, n949, n1005, n1061, n1117, n1173, n1229, n1285, n1341, n1397, n1453, n1509, n1565, n1620};
  assign n1634 = {n731, n781, n837, n893, n949, n1005, n1061, n1117, n1173, n1229, n1285, n1341, n1397, n1453, n1509, n1565, n1620};
  /* mc68881_packed_decimal_unit.vhd:537:57  */
  assign n1635 = n1634[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:537:49  */
  assign n1636 = {27'b0, n1635};  //  uext
  /* mc68881_packed_decimal_unit.vhd:537:37  */
  assign n1637 = {33'b0, n1636};  //  uext
  /* mc68881_packed_decimal_unit.vhd:539:34  */
  assign n1638 = n729[14:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1640 = n1624 ? n507 : 5'b01111;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1641 = n1624 ? n508 : n1638;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1643 = n1624 ? 68'b00000000000000000000000000000000000000000000000000000000000000000000 : n1633;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1646 = n1624 ? 5'b00000 : 5'b00001;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1647 = n1624 ? mant_u64_reg : n1637;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1650 = n1624 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1651 = n1624 ? req_word : rsp_word_reg;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1652 = n1624 ? n1632 : rsp_fp_reg;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1654 = n1624 ? 1'b0 : rsp_inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:527:19  */
  assign n1656 = n1624 ? 1'b0 : rsp_invalid_reg;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1659 = n1628 ? n507 : n1640;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1660 = n1628 ? n508 : n1641;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1662 = n1628 ? 68'b00000000000000000000000000000000000000000000000000000000000000000000 : n1643;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1664 = n1628 ? 5'b00000 : n1646;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1665 = n1628 ? mant_u64_reg : n1647;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1667 = n1628 ? 1'b1 : n1650;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1668 = n1628 ? req_word : n1651;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1669 = n1628 ? req_fallback_fp : n1652;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1671 = n1628 ? 1'b0 : n1654;
  /* mc68881_packed_decimal_unit.vhd:521:19  */
  assign n1673 = n1628 ? 1'b1 : n1656;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1675 = n717 ? n507 : n1659;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1676 = n717 ? n508 : n1660;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1678 = n717 ? 68'b00000000000000000000000000000000000000000000000000000000000000000000 : n1662;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1680 = n717 ? 5'b00000 : n1664;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1681 = n717 ? mant_u64_reg : n1665;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1683 = n717 ? 1'b1 : n1667;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1684 = n717 ? req_word : n1668;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1685 = n717 ? req_fallback_fp : n1669;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1687 = n717 ? 1'b0 : n1671;
  /* mc68881_packed_decimal_unit.vhd:494:17  */
  assign n1689 = n717 ? 1'b1 : n1673;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1696 = n540 ? n507 : n1675;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1697 = n540 ? n508 : n1676;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1699 = n540 ? 68'b00000000000000000000000000000000000000000000000000000000000000000000 : n1678;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1701 = n540 ? 5'b00000 : n1680;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1702 = n540 ? mant_u64_reg : n1681;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1704 = n540 ? 1'b1 : n1683;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1705 = n540 ? req_word : n1684;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1706 = n540 ? n553 : n1685;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1708 = n540 ? 1'b0 : n1687;
  /* mc68881_packed_decimal_unit.vhd:474:15  */
  assign n1710 = n540 ? 1'b0 : n1689;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1722 = req_encode ? 5'b00001 : n1696;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1723 = req_encode ? n536 : n537;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1724 = req_encode ? n508 : n1697;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1726 = req_encode ? 68'b00000000000000000000000000000000000000000000000000000000000000000000 : n1699;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1729 = req_encode ? 5'b00000 : n1701;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1731 = req_encode ? mant_u64_reg : n1702;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1733 = req_encode ? 1'b0 : n1704;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1734 = req_encode ? rsp_word_reg : n1705;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1735 = req_encode ? rsp_fp_reg : n1706;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1736 = req_encode ? rsp_inexact_reg : n1708;
  /* mc68881_packed_decimal_unit.vhd:467:13  */
  assign n1737 = req_encode ? rsp_invalid_reg : n1710;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1748 = req_valid ? n1722 : n507;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1749 = req_valid ? req_fp : req_fp_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1750 = req_valid ? req_word : req_word_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1751 = req_valid ? req_k : req_k_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1752 = req_valid ? n1723 : sign_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1753 = req_valid ? n1724 : n508;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1754 = req_valid ? n1726 : n510;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1756 = req_valid ? 4'b0000 : n511;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1757 = req_valid ? n1729 : n512;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1759 = req_valid ? 3'b000 : tune_iter_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1761 = req_valid ? 1'b0 : inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1762 = req_valid ? n1731 : mant_u64_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1764 = req_valid ? n1733 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1765 = req_valid ? n1734 : rsp_word_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1766 = req_valid ? n1735 : rsp_fp_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1767 = req_valid ? n1736 : rsp_inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:457:11  */
  assign n1768 = req_valid ? n1737 : rsp_invalid_reg;
  /* mc68881_packed_decimal_unit.vhd:456:9  */
  assign n1780 = state_reg == 5'b00000;
  assign n1782 = n1781[94:0]; // extract
  /* mc68881_pkg.vhd:1535:25  */
  assign n1794 = req_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n1797 = req_fp_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n1799 = req_fp_reg[63:0]; // extract
  assign n1800 = {n1799, n1797, n1794};
  /* mc68881_pkg.vhd:2083:20  */
  assign n1801 = n1800[15:1]; // extract
  /* mc68881_pkg.vhd:2083:24  */
  assign n1803 = n1801 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2083:40  */
  assign n1804 = n1800[79:16]; // extract
  /* mc68881_pkg.vhd:2083:45  */
  assign n1806 = n1804 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2083:28  */
  assign n1807 = n1806 & n1803;
  assign n1808 = {sign_reg, n1782};
  /* mc68881_pkg.vhd:1535:25  */
  assign n1820 = req_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n1823 = req_fp_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n1825 = req_fp_reg[63:0]; // extract
  assign n1826 = {n1825, n1823, n1820};
  assign n1830 = n1829[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n1831 = n1826[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n1833 = n1831 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n1834 = n1826[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n1836 = n1834 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n1837 = n1826[79:16]; // extract
  assign n1838 = {1'b1, n1830};
  /* mc68881_pkg.vhd:2092:41  */
  assign n1839 = n1837 == n1838;
  /* mc68881_pkg.vhd:2092:25  */
  assign n1840 = n1836 | n1839;
  /* mc68881_pkg.vhd:2091:42  */
  assign n1841 = n1840 & n1833;
  assign n1847 = n1781[75:0]; // extract
  assign n1848 = n1781[94]; // extract
  assign n1849 = {sign_reg, n1848, 2'b11, 4'b1111, 4'b1111, 4'b1111, 4'b1111, n1847};
  /* mc68881_pkg.vhd:1535:25  */
  assign n1861 = req_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n1864 = req_fp_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n1866 = req_fp_reg[63:0]; // extract
  assign n1867 = {n1866, n1864, n1861};
  /* mc68881_pkg.vhd:2098:20  */
  assign n1868 = n1867[15:1]; // extract
  /* mc68881_pkg.vhd:2098:24  */
  assign n1870 = n1868 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1535:25  */
  assign n1882 = req_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n1885 = req_fp_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n1887 = req_fp_reg[63:0]; // extract
  assign n1888 = {n1887, n1885, n1882};
  assign n1892 = n1891[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n1893 = n1888[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n1895 = n1893 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n1896 = n1888[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n1898 = n1896 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n1899 = n1888[79:16]; // extract
  assign n1900 = {1'b1, n1892};
  /* mc68881_pkg.vhd:2092:41  */
  assign n1901 = n1899 == n1900;
  /* mc68881_pkg.vhd:2092:25  */
  assign n1902 = n1898 | n1901;
  /* mc68881_pkg.vhd:2091:42  */
  assign n1903 = n1902 & n1895;
  /* mc68881_pkg.vhd:2098:46  */
  assign n1904 = ~n1903;
  /* mc68881_pkg.vhd:2098:42  */
  assign n1905 = n1904 & n1870;
  assign n1913 = n1781[75:68]; // extract
  assign n1914 = n1781[94]; // extract
  assign n1915 = {sign_reg, n1914, 2'b11, 4'b1111, 4'b1111, 4'b1111, 4'b1111, n1913, 4'b0001, 64'b1111111111111111111111111111111111111111111111111111111111111111};
  assign n1917 = req_fp_reg[78:0]; // extract
  assign n1918 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:591:51  */
  assign n1919 = n1918[78:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:591:24  */
  assign n1920 = {16'b0, n1919};  //  uext
  /* mc68881_packed_decimal_unit.vhd:591:87  */
  assign n1921 = {1'b0, n1920};  //  uext
  /* mc68881_packed_decimal_unit.vhd:591:87  */
  assign n1923 = n1921 - 32'b00000000000000000011111111111111;
  assign n1924 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:592:32  */
  assign n1925 = n1924[78:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:592:67  */
  assign n1927 = n1925 == 15'b000000000000000;
  assign n1929 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n1930 = n1929[63]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1933 = n1930 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1936 = n1930 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n1940 = n1933 ? 32'b11111111111111111100000000000001 : 32'b11111111111111111100000000000010;
  assign n1942 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n1943 = n1942[62]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1945 = n1948 ? 1'b0 : n1936;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1947 = n1949 ? 1'b0 : n1936;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1948 = n1943 & n1936;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1949 = n1943 & n1936;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n1951 = n1940 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n1952 = n1945 ? n1951 : n1940;
  assign n1953 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n1954 = n1953[61]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1956 = n1959 ? 1'b0 : n1947;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1958 = n1960 ? 1'b0 : n1947;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1959 = n1954 & n1947;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1960 = n1954 & n1947;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n1962 = n1952 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n1963 = n1956 ? n1962 : n1952;
  assign n1964 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n1965 = n1964[60]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1967 = n1970 ? 1'b0 : n1958;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1969 = n1971 ? 1'b0 : n1958;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1970 = n1965 & n1958;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1971 = n1965 & n1958;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n1973 = n1963 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n1974 = n1967 ? n1973 : n1963;
  assign n1975 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n1976 = n1975[59]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1978 = n1981 ? 1'b0 : n1969;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1980 = n1982 ? 1'b0 : n1969;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1981 = n1976 & n1969;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1982 = n1976 & n1969;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n1984 = n1974 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n1985 = n1978 ? n1984 : n1974;
  assign n1986 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n1987 = n1986[58]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1989 = n1992 ? 1'b0 : n1980;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1991 = n1993 ? 1'b0 : n1980;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1992 = n1987 & n1980;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n1993 = n1987 & n1980;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n1995 = n1985 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n1996 = n1989 ? n1995 : n1985;
  assign n1997 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n1998 = n1997[57]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2000 = n2003 ? 1'b0 : n1991;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2002 = n2004 ? 1'b0 : n1991;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2003 = n1998 & n1991;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2004 = n1998 & n1991;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2006 = n1996 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2007 = n2000 ? n2006 : n1996;
  assign n2008 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2009 = n2008[56]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2011 = n2014 ? 1'b0 : n2002;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2013 = n2015 ? 1'b0 : n2002;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2014 = n2009 & n2002;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2015 = n2009 & n2002;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2017 = n2007 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2018 = n2011 ? n2017 : n2007;
  assign n2019 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2020 = n2019[55]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2022 = n2025 ? 1'b0 : n2013;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2024 = n2026 ? 1'b0 : n2013;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2025 = n2020 & n2013;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2026 = n2020 & n2013;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2028 = n2018 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2029 = n2022 ? n2028 : n2018;
  assign n2030 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2031 = n2030[54]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2033 = n2036 ? 1'b0 : n2024;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2035 = n2037 ? 1'b0 : n2024;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2036 = n2031 & n2024;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2037 = n2031 & n2024;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2039 = n2029 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2040 = n2033 ? n2039 : n2029;
  assign n2041 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2042 = n2041[53]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2044 = n2047 ? 1'b0 : n2035;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2046 = n2048 ? 1'b0 : n2035;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2047 = n2042 & n2035;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2048 = n2042 & n2035;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2050 = n2040 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2051 = n2044 ? n2050 : n2040;
  assign n2052 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2053 = n2052[52]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2055 = n2058 ? 1'b0 : n2046;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2057 = n2059 ? 1'b0 : n2046;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2058 = n2053 & n2046;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2059 = n2053 & n2046;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2061 = n2051 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2062 = n2055 ? n2061 : n2051;
  assign n2063 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2064 = n2063[51]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2066 = n2069 ? 1'b0 : n2057;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2068 = n2070 ? 1'b0 : n2057;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2069 = n2064 & n2057;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2070 = n2064 & n2057;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2072 = n2062 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2073 = n2066 ? n2072 : n2062;
  assign n2074 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2075 = n2074[50]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2077 = n2080 ? 1'b0 : n2068;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2079 = n2081 ? 1'b0 : n2068;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2080 = n2075 & n2068;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2081 = n2075 & n2068;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2083 = n2073 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2084 = n2077 ? n2083 : n2073;
  assign n2085 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2086 = n2085[49]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2088 = n2091 ? 1'b0 : n2079;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2090 = n2092 ? 1'b0 : n2079;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2091 = n2086 & n2079;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2092 = n2086 & n2079;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2094 = n2084 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2095 = n2088 ? n2094 : n2084;
  assign n2096 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2097 = n2096[48]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2099 = n2102 ? 1'b0 : n2090;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2101 = n2103 ? 1'b0 : n2090;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2102 = n2097 & n2090;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2103 = n2097 & n2090;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2105 = n2095 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2106 = n2099 ? n2105 : n2095;
  assign n2107 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2108 = n2107[47]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2110 = n2113 ? 1'b0 : n2101;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2112 = n2114 ? 1'b0 : n2101;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2113 = n2108 & n2101;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2114 = n2108 & n2101;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2116 = n2106 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2117 = n2110 ? n2116 : n2106;
  assign n2118 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2119 = n2118[46]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2121 = n2124 ? 1'b0 : n2112;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2123 = n2125 ? 1'b0 : n2112;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2124 = n2119 & n2112;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2125 = n2119 & n2112;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2127 = n2117 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2128 = n2121 ? n2127 : n2117;
  assign n2129 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2130 = n2129[45]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2132 = n2135 ? 1'b0 : n2123;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2134 = n2136 ? 1'b0 : n2123;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2135 = n2130 & n2123;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2136 = n2130 & n2123;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2138 = n2128 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2139 = n2132 ? n2138 : n2128;
  assign n2140 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2141 = n2140[44]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2143 = n2146 ? 1'b0 : n2134;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2145 = n2147 ? 1'b0 : n2134;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2146 = n2141 & n2134;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2147 = n2141 & n2134;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2149 = n2139 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2150 = n2143 ? n2149 : n2139;
  assign n2151 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2152 = n2151[43]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2154 = n2157 ? 1'b0 : n2145;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2156 = n2158 ? 1'b0 : n2145;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2157 = n2152 & n2145;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2158 = n2152 & n2145;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2160 = n2150 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2161 = n2154 ? n2160 : n2150;
  assign n2162 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2163 = n2162[42]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2165 = n2168 ? 1'b0 : n2156;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2167 = n2169 ? 1'b0 : n2156;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2168 = n2163 & n2156;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2169 = n2163 & n2156;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2171 = n2161 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2172 = n2165 ? n2171 : n2161;
  assign n2173 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2174 = n2173[41]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2176 = n2179 ? 1'b0 : n2167;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2178 = n2180 ? 1'b0 : n2167;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2179 = n2174 & n2167;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2180 = n2174 & n2167;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2182 = n2172 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2183 = n2176 ? n2182 : n2172;
  assign n2184 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2185 = n2184[40]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2187 = n2190 ? 1'b0 : n2178;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2189 = n2191 ? 1'b0 : n2178;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2190 = n2185 & n2178;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2191 = n2185 & n2178;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2193 = n2183 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2194 = n2187 ? n2193 : n2183;
  assign n2195 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2196 = n2195[39]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2198 = n2201 ? 1'b0 : n2189;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2200 = n2202 ? 1'b0 : n2189;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2201 = n2196 & n2189;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2202 = n2196 & n2189;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2204 = n2194 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2205 = n2198 ? n2204 : n2194;
  assign n2206 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2207 = n2206[38]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2209 = n2212 ? 1'b0 : n2200;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2211 = n2213 ? 1'b0 : n2200;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2212 = n2207 & n2200;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2213 = n2207 & n2200;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2215 = n2205 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2216 = n2209 ? n2215 : n2205;
  assign n2217 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2218 = n2217[37]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2220 = n2223 ? 1'b0 : n2211;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2222 = n2224 ? 1'b0 : n2211;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2223 = n2218 & n2211;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2224 = n2218 & n2211;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2226 = n2216 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2227 = n2220 ? n2226 : n2216;
  assign n2228 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2229 = n2228[36]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2231 = n2234 ? 1'b0 : n2222;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2233 = n2235 ? 1'b0 : n2222;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2234 = n2229 & n2222;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2235 = n2229 & n2222;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2237 = n2227 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2238 = n2231 ? n2237 : n2227;
  assign n2239 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2240 = n2239[35]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2242 = n2245 ? 1'b0 : n2233;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2244 = n2246 ? 1'b0 : n2233;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2245 = n2240 & n2233;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2246 = n2240 & n2233;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2248 = n2238 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2249 = n2242 ? n2248 : n2238;
  assign n2250 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2251 = n2250[34]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2253 = n2256 ? 1'b0 : n2244;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2255 = n2257 ? 1'b0 : n2244;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2256 = n2251 & n2244;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2257 = n2251 & n2244;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2259 = n2249 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2260 = n2253 ? n2259 : n2249;
  assign n2261 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2262 = n2261[33]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2264 = n2267 ? 1'b0 : n2255;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2266 = n2268 ? 1'b0 : n2255;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2267 = n2262 & n2255;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2268 = n2262 & n2255;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2270 = n2260 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2271 = n2264 ? n2270 : n2260;
  assign n2272 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2273 = n2272[32]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2275 = n2278 ? 1'b0 : n2266;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2277 = n2279 ? 1'b0 : n2266;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2278 = n2273 & n2266;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2279 = n2273 & n2266;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2281 = n2271 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2282 = n2275 ? n2281 : n2271;
  assign n2283 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2284 = n2283[31]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2286 = n2289 ? 1'b0 : n2277;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2288 = n2290 ? 1'b0 : n2277;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2289 = n2284 & n2277;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2290 = n2284 & n2277;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2292 = n2282 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2293 = n2286 ? n2292 : n2282;
  assign n2294 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2295 = n2294[30]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2297 = n2300 ? 1'b0 : n2288;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2299 = n2301 ? 1'b0 : n2288;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2300 = n2295 & n2288;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2301 = n2295 & n2288;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2303 = n2293 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2304 = n2297 ? n2303 : n2293;
  assign n2305 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2306 = n2305[29]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2308 = n2311 ? 1'b0 : n2299;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2310 = n2312 ? 1'b0 : n2299;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2311 = n2306 & n2299;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2312 = n2306 & n2299;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2314 = n2304 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2315 = n2308 ? n2314 : n2304;
  assign n2316 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2317 = n2316[28]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2319 = n2322 ? 1'b0 : n2310;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2321 = n2323 ? 1'b0 : n2310;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2322 = n2317 & n2310;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2323 = n2317 & n2310;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2325 = n2315 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2326 = n2319 ? n2325 : n2315;
  assign n2327 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2328 = n2327[27]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2330 = n2333 ? 1'b0 : n2321;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2332 = n2334 ? 1'b0 : n2321;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2333 = n2328 & n2321;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2334 = n2328 & n2321;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2336 = n2326 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2337 = n2330 ? n2336 : n2326;
  assign n2338 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2339 = n2338[26]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2341 = n2344 ? 1'b0 : n2332;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2343 = n2345 ? 1'b0 : n2332;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2344 = n2339 & n2332;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2345 = n2339 & n2332;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2347 = n2337 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2348 = n2341 ? n2347 : n2337;
  assign n2349 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2350 = n2349[25]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2352 = n2355 ? 1'b0 : n2343;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2354 = n2356 ? 1'b0 : n2343;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2355 = n2350 & n2343;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2356 = n2350 & n2343;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2358 = n2348 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2359 = n2352 ? n2358 : n2348;
  assign n2360 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2361 = n2360[24]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2363 = n2366 ? 1'b0 : n2354;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2365 = n2367 ? 1'b0 : n2354;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2366 = n2361 & n2354;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2367 = n2361 & n2354;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2369 = n2359 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2370 = n2363 ? n2369 : n2359;
  assign n2371 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2372 = n2371[23]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2374 = n2377 ? 1'b0 : n2365;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2376 = n2378 ? 1'b0 : n2365;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2377 = n2372 & n2365;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2378 = n2372 & n2365;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2380 = n2370 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2381 = n2374 ? n2380 : n2370;
  assign n2382 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2383 = n2382[22]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2385 = n2388 ? 1'b0 : n2376;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2387 = n2389 ? 1'b0 : n2376;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2388 = n2383 & n2376;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2389 = n2383 & n2376;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2391 = n2381 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2392 = n2385 ? n2391 : n2381;
  assign n2393 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2394 = n2393[21]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2396 = n2399 ? 1'b0 : n2387;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2398 = n2400 ? 1'b0 : n2387;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2399 = n2394 & n2387;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2400 = n2394 & n2387;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2402 = n2392 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2403 = n2396 ? n2402 : n2392;
  assign n2404 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2405 = n2404[20]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2407 = n2410 ? 1'b0 : n2398;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2409 = n2411 ? 1'b0 : n2398;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2410 = n2405 & n2398;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2411 = n2405 & n2398;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2413 = n2403 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2414 = n2407 ? n2413 : n2403;
  assign n2415 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2416 = n2415[19]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2418 = n2421 ? 1'b0 : n2409;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2420 = n2422 ? 1'b0 : n2409;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2421 = n2416 & n2409;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2422 = n2416 & n2409;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2424 = n2414 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2425 = n2418 ? n2424 : n2414;
  assign n2426 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2427 = n2426[18]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2429 = n2432 ? 1'b0 : n2420;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2431 = n2433 ? 1'b0 : n2420;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2432 = n2427 & n2420;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2433 = n2427 & n2420;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2435 = n2425 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2436 = n2429 ? n2435 : n2425;
  assign n2437 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2438 = n2437[17]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2440 = n2443 ? 1'b0 : n2431;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2442 = n2444 ? 1'b0 : n2431;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2443 = n2438 & n2431;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2444 = n2438 & n2431;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2446 = n2436 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2447 = n2440 ? n2446 : n2436;
  assign n2448 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2449 = n2448[16]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2451 = n2454 ? 1'b0 : n2442;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2453 = n2455 ? 1'b0 : n2442;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2454 = n2449 & n2442;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2455 = n2449 & n2442;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2457 = n2447 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2458 = n2451 ? n2457 : n2447;
  assign n2459 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2460 = n2459[15]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2462 = n2465 ? 1'b0 : n2453;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2464 = n2466 ? 1'b0 : n2453;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2465 = n2460 & n2453;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2466 = n2460 & n2453;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2468 = n2458 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2469 = n2462 ? n2468 : n2458;
  assign n2470 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2471 = n2470[14]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2473 = n2476 ? 1'b0 : n2464;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2475 = n2477 ? 1'b0 : n2464;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2476 = n2471 & n2464;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2477 = n2471 & n2464;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2479 = n2469 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2480 = n2473 ? n2479 : n2469;
  assign n2481 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2482 = n2481[13]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2484 = n2487 ? 1'b0 : n2475;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2486 = n2488 ? 1'b0 : n2475;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2487 = n2482 & n2475;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2488 = n2482 & n2475;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2490 = n2480 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2491 = n2484 ? n2490 : n2480;
  assign n2492 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2493 = n2492[12]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2495 = n2498 ? 1'b0 : n2486;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2497 = n2499 ? 1'b0 : n2486;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2498 = n2493 & n2486;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2499 = n2493 & n2486;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2501 = n2491 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2502 = n2495 ? n2501 : n2491;
  assign n2503 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2504 = n2503[11]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2506 = n2509 ? 1'b0 : n2497;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2508 = n2510 ? 1'b0 : n2497;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2509 = n2504 & n2497;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2510 = n2504 & n2497;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2512 = n2502 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2513 = n2506 ? n2512 : n2502;
  assign n2514 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2515 = n2514[10]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2517 = n2520 ? 1'b0 : n2508;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2519 = n2521 ? 1'b0 : n2508;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2520 = n2515 & n2508;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2521 = n2515 & n2508;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2523 = n2513 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2524 = n2517 ? n2523 : n2513;
  assign n2525 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2526 = n2525[9]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2528 = n2531 ? 1'b0 : n2519;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2530 = n2532 ? 1'b0 : n2519;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2531 = n2526 & n2519;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2532 = n2526 & n2519;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2534 = n2524 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2535 = n2528 ? n2534 : n2524;
  assign n2536 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2537 = n2536[8]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2539 = n2542 ? 1'b0 : n2530;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2541 = n2543 ? 1'b0 : n2530;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2542 = n2537 & n2530;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2543 = n2537 & n2530;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2545 = n2535 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2546 = n2539 ? n2545 : n2535;
  assign n2547 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2548 = n2547[7]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2550 = n2553 ? 1'b0 : n2541;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2552 = n2554 ? 1'b0 : n2541;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2553 = n2548 & n2541;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2554 = n2548 & n2541;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2556 = n2546 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2557 = n2550 ? n2556 : n2546;
  assign n2558 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2559 = n2558[6]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2561 = n2564 ? 1'b0 : n2552;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2563 = n2565 ? 1'b0 : n2552;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2564 = n2559 & n2552;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2565 = n2559 & n2552;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2567 = n2557 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2568 = n2561 ? n2567 : n2557;
  assign n2569 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2570 = n2569[5]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2572 = n2575 ? 1'b0 : n2563;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2574 = n2576 ? 1'b0 : n2563;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2575 = n2570 & n2563;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2576 = n2570 & n2563;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2578 = n2568 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2579 = n2572 ? n2578 : n2568;
  assign n2580 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2581 = n2580[4]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2583 = n2586 ? 1'b0 : n2574;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2585 = n2587 ? 1'b0 : n2574;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2586 = n2581 & n2574;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2587 = n2581 & n2574;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2589 = n2579 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2590 = n2583 ? n2589 : n2579;
  assign n2591 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2592 = n2591[3]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2594 = n2597 ? 1'b0 : n2585;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2596 = n2598 ? 1'b0 : n2585;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2597 = n2592 & n2585;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2598 = n2592 & n2585;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2600 = n2590 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2601 = n2594 ? n2600 : n2590;
  assign n2602 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2603 = n2602[2]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2605 = n2608 ? 1'b0 : n2596;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2607 = n2609 ? 1'b0 : n2596;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2608 = n2603 & n2596;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2609 = n2603 & n2596;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2611 = n2601 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2612 = n2605 ? n2611 : n2601;
  assign n2613 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2614 = n2613[1]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2616 = n2619 ? 1'b0 : n2607;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2618 = n2620 ? 1'b0 : n2607;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2619 = n2614 & n2607;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2620 = n2614 & n2607;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2622 = n2612 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2623 = n2616 ? n2622 : n2612;
  assign n2624 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:595:34  */
  assign n2625 = n2624[0]; // extract
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2627 = n2630 ? 1'b0 : n2618;
  /* mc68881_packed_decimal_unit.vhd:595:17  */
  assign n2630 = n2625 & n2618;
  /* mc68881_packed_decimal_unit.vhd:596:36  */
  assign n2633 = n2623 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:596:17  */
  assign n2634 = n2627 ? n2633 : n2623;
  /* mc68881_packed_decimal_unit.vhd:592:13  */
  assign n2635 = n1927 ? n2634 : n1923;
  /* mc68881_packed_decimal_unit.vhd:600:28  */
  assign n2636 = n2635[15:0];  // trunc
  assign n2637 = {1'b0, n1917};
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2640 = n1905 ? 5'b00000 : 5'b00010;
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2641 = n1905 ? bin_exp_reg : n2636;
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2642 = n1905 ? n509 : n2637;
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2645 = n1905 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2646 = n1905 ? n1915 : rsp_word_reg;
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2647 = n1905 ? req_fp_reg : rsp_fp_reg;
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2649 = n1905 ? 1'b0 : rsp_inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:573:11  */
  assign n2651 = n1905 ? 1'b0 : rsp_invalid_reg;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2662 = n1841 ? 5'b00000 : n2640;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2663 = n1841 ? bin_exp_reg : n2641;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2664 = n1841 ? n509 : n2642;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2666 = n1841 ? 1'b1 : n2645;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2667 = n1841 ? n1849 : n2646;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2668 = n1841 ? req_fp_reg : n2647;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2670 = n1841 ? 1'b0 : n2649;
  /* mc68881_packed_decimal_unit.vhd:561:11  */
  assign n2672 = n1841 ? 1'b0 : n2651;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2680 = n1807 ? 5'b00000 : n2662;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2681 = n1807 ? bin_exp_reg : n2663;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2682 = n1807 ? n509 : n2664;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2684 = n1807 ? 1'b1 : n2666;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2685 = n1807 ? n1808 : n2667;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2686 = n1807 ? req_fp_reg : n2668;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2688 = n1807 ? 1'b0 : n2670;
  /* mc68881_packed_decimal_unit.vhd:554:11  */
  assign n2690 = n1807 ? 1'b0 : n2672;
  /* mc68881_packed_decimal_unit.vhd:547:9  */
  assign n2701 = state_reg == 5'b00001;
  /* mc68881_packed_decimal_unit.vhd:609:26  */
  assign n2702 = {{16{bin_exp_reg[15]}}, bin_exp_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:609:26  */
  assign n2704 = $signed(n2702) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:610:39  */
  assign n2705 = {{16{bin_exp_reg[15]}}, bin_exp_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:610:39  */
  assign n2707 = $signed(n2705) * $signed(32'b00000000000000000000000001001101); // smul
  /* mc68881_packed_decimal_unit.vhd:610:45  */
  assign n2709 = $signed(n2707) / $signed(32'b00000000000000000000000100000000); // sdiv
  /* mc68881_packed_decimal_unit.vhd:610:26  */
  assign n2710 = n2709[14:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:612:30  */
  assign n2711 = {{16{bin_exp_reg[15]}}, bin_exp_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:612:30  */
  assign n2712 = -n2711;
  /* mc68881_packed_decimal_unit.vhd:612:44  */
  assign n2714 = $signed(n2712) * $signed(32'b00000000000000000000000001001101); // smul
  /* mc68881_packed_decimal_unit.vhd:612:49  */
  assign n2716 = n2714 + 32'b00000000000000000000000011111111;
  /* mc68881_packed_decimal_unit.vhd:612:56  */
  assign n2718 = $signed(n2716) / $signed(32'b00000000000000000000000100000000); // sdiv
  /* mc68881_packed_decimal_unit.vhd:612:26  */
  assign n2719 = -n2718;
  /* mc68881_packed_decimal_unit.vhd:612:26  */
  assign n2720 = n2719[14:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:609:11  */
  assign n2721 = n2704 ? n2710 : n2720;
  /* mc68881_packed_decimal_unit.vhd:605:9  */
  assign n2723 = state_reg == 5'b00010;
  /* mc68881_packed_decimal_unit.vhd:618:30  */
  assign n2724 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:618:30  */
  assign n2725 = -n2724;
  /* mc68881_packed_decimal_unit.vhd:619:30  */
  assign n2727 = n2725 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:622:32  */
  assign n2729 = $signed(n2725) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:624:44  */
  assign n2730 = -n2725;
  /* mc68881_packed_decimal_unit.vhd:624:43  */
  assign n2731 = n2730[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:624:36  */
  assign n2732 = n2731[13:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:627:43  */
  assign n2733 = n2725[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:627:36  */
  assign n2734 = n2733[13:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:622:13  */
  assign n2735 = n2729 ? n2732 : n2734;
  /* mc68881_packed_decimal_unit.vhd:622:13  */
  assign n2738 = n2729 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:619:11  */
  assign n2741 = n2727 ? 5'b00110 : 5'b00100;
  /* mc68881_packed_decimal_unit.vhd:619:11  */
  assign n2743 = n2727 ? scale_return_state_reg : 5'b00110;
  /* mc68881_packed_decimal_unit.vhd:619:11  */
  assign n2744 = n2727 ? n514 : n2735;
  /* mc68881_packed_decimal_unit.vhd:619:11  */
  assign n2745 = n2727 ? scale_use_neg_reg : n2738;
  /* mc68881_packed_decimal_unit.vhd:619:11  */
  assign n2747 = n2727 ? n515 : 4'b0000;
  /* mc68881_packed_decimal_unit.vhd:616:9  */
  assign n2749 = state_reg == 5'b00011;
  /* mc68881_packed_decimal_unit.vhd:635:32  */
  assign n2750 = {18'b0, scale_abs_exp_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:635:32  */
  assign n2752 = $signed(n2750) >= $signed(32'b00000000000000000001000000000000);
  /* mc68881_packed_decimal_unit.vhd:638:13  */
  assign n2755 = scale_use_neg_reg ? 80'b00001010110110001010011011011101000001001100100011010010110011101001111111011110 : 80'b01110101001001011100010001100000010100100000001010001010001000001001011110011011;
  /* mc68881_packed_decimal_unit.vhd:635:11  */
  assign n2757 = n2752 ? n507 : 5'b00101;
  /* mc68881_packed_decimal_unit.vhd:635:11  */
  assign n2759 = n2752 ? n515 : 4'b0000;
  /* mc68881_packed_decimal_unit.vhd:635:11  */
  assign n2764 = n2752 ? work_fp_reg : 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:635:11  */
  assign n2766 = n2752 ? n2755 : 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:635:11  */
  assign n2769 = n2752 ? 3'b001 : 3'b000;
  /* mc68881_packed_decimal_unit.vhd:634:9  */
  assign n2771 = state_reg == 5'b00100;
  /* mc68881_packed_decimal_unit.vhd:650:32  */
  assign n2772 = {28'b0, scale_bit_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:650:32  */
  assign n2774 = n2772 == 32'b00000000000000000000000000001100;
  /* mc68881_packed_decimal_unit.vhd:656:40  */
  assign n2778 = {27'b0, scale_bit_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:205:9  */
  assign n2785 = n2778 == 31'b0000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:206:9  */
  assign n2788 = n2778 == 31'b0000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:207:9  */
  assign n2791 = n2778 == 31'b0000000000000000000000000000010;
  /* mc68881_packed_decimal_unit.vhd:208:9  */
  assign n2794 = n2778 == 31'b0000000000000000000000000000011;
  /* mc68881_packed_decimal_unit.vhd:209:9  */
  assign n2797 = n2778 == 31'b0000000000000000000000000000100;
  /* mc68881_packed_decimal_unit.vhd:210:9  */
  assign n2800 = n2778 == 31'b0000000000000000000000000000101;
  /* mc68881_packed_decimal_unit.vhd:211:9  */
  assign n2803 = n2778 == 31'b0000000000000000000000000000110;
  /* mc68881_packed_decimal_unit.vhd:212:9  */
  assign n2806 = n2778 == 31'b0000000000000000000000000000111;
  /* mc68881_packed_decimal_unit.vhd:213:9  */
  assign n2809 = n2778 == 31'b0000000000000000000000000001000;
  /* mc68881_packed_decimal_unit.vhd:214:9  */
  assign n2812 = n2778 == 31'b0000000000000000000000000001001;
  /* mc68881_packed_decimal_unit.vhd:215:9  */
  assign n2815 = n2778 == 31'b0000000000000000000000000001010;
  assign n2817 = {n2815, n2812, n2809, n2806, n2803, n2800, n2797, n2794, n2791, n2788, n2785};
  /* mc68881_packed_decimal_unit.vhd:204:7  */
  always @*
    case (n2817)
      11'b10000000000: n2818 = 80'b00110010101101011010001010100110100000101010010111011010010101111100000010111110;
      11'b01000000000: n2818 = 80'b00111001010110101001000001001001111011100011001011011011001000111101001000011100;
      11'b00100000000: n2818 = 80'b00111100101011001100000000110001010000110010010101100011011110100001100100111010;
      11'b00010000000: n2818 = 80'b00111110010101011101110111010000010001100111110001100100101111001110010010100001;
      11'b00001000000: n2818 = 80'b00111111001010101010100001111111111010100010011110100101001110011110100110100101;
      11'b00000100000: n2818 = 80'b00111111100101001100111110110001000111101010110101000101001110011001010010111010;
      11'b00000010000: n2818 = 80'b00111111110010011110011010010101100101001011111011000100010011011110000101011011;
      11'b00000001000: n2818 = 80'b00111111111001001010101111001100011101110001000110000100011000011100111011111101;
      11'b00000000100: n2818 = 80'b00111111111100011101000110110111000101110101100011100010000110010110010100101100;
      11'b00000000010: n2818 = 80'b00111111111110001010001111010111000010100011110101110000101000111101011100001010;
      11'b00000000001: n2818 = 80'b00111111111110111100110011001100110011001100110011001100110011001100110011001101;
      default: n2818 = 80'b00100101011010111100111010101110010100110100111100110100001101100010110111100100;
    endcase
  /* mc68881_packed_decimal_unit.vhd:203:5  */
  assign n2821 = scale_use_neg_reg ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:203:5  */
  assign n2827 = scale_use_neg_reg ? n2818 : 80'bX;
  /* mc68881_packed_decimal_unit.vhd:221:17  */
  assign n2833 = n2821 ? 80'b01000000000000101010000000000000000000000000000000000000000000000000000000000000 : n2827;
  /* mc68881_packed_decimal_unit.vhd:221:7  */
  assign n2835 = n2778 == 31'b0000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:222:17  */
  assign n2841 = n2821 ? 80'b01000000000001011100100000000000000000000000000000000000000000000000000000000000 : n2827;
  /* mc68881_packed_decimal_unit.vhd:222:7  */
  assign n2843 = n2778 == 31'b0000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:223:17  */
  assign n2849 = n2821 ? 80'b01000000000011001001110001000000000000000000000000000000000000000000000000000000 : n2827;
  /* mc68881_packed_decimal_unit.vhd:223:7  */
  assign n2851 = n2778 == 31'b0000000000000000000000000000010;
  /* mc68881_packed_decimal_unit.vhd:224:17  */
  assign n2857 = n2821 ? 80'b01000000000110011011111010111100001000000000000000000000000000000000000000000000 : n2827;
  /* mc68881_packed_decimal_unit.vhd:224:7  */
  assign n2859 = n2778 == 31'b0000000000000000000000000000011;
  /* mc68881_packed_decimal_unit.vhd:225:17  */
  assign n2865 = n2821 ? 80'b01000000001101001000111000011011110010011011111100000100000000000000000000000000 : n2827;
  /* mc68881_packed_decimal_unit.vhd:225:7  */
  assign n2867 = n2778 == 31'b0000000000000000000000000000100;
  /* mc68881_packed_decimal_unit.vhd:226:17  */
  assign n2873 = n2821 ? 80'b01000000011010011001110111000101101011011010100000101011011100001011010110011110 : n2827;
  /* mc68881_packed_decimal_unit.vhd:226:7  */
  assign n2875 = n2778 == 31'b0000000000000000000000000000101;
  /* mc68881_packed_decimal_unit.vhd:227:17  */
  assign n2881 = n2821 ? 80'b01000000110100111100001001111000000111110100100111111111110011111010011011010101 : n2827;
  /* mc68881_packed_decimal_unit.vhd:227:7  */
  assign n2883 = n2778 == 31'b0000000000000000000000000000110;
  /* mc68881_packed_decimal_unit.vhd:228:17  */
  assign n2889 = n2821 ? 80'b01000001101010001001001110111010010001111100100110000000111010011000110011100000 : n2827;
  /* mc68881_packed_decimal_unit.vhd:228:7  */
  assign n2891 = n2778 == 31'b0000000000000000000000000000111;
  /* mc68881_packed_decimal_unit.vhd:229:17  */
  assign n2897 = n2821 ? 80'b01000011010100011010101001111110111010111111101110011101111110011101111010001110 : n2827;
  /* mc68881_packed_decimal_unit.vhd:229:7  */
  assign n2899 = n2778 == 31'b0000000000000000000000000001000;
  /* mc68881_packed_decimal_unit.vhd:230:17  */
  assign n2905 = n2821 ? 80'b01000110101000111110001100011001101000001010111010100110000011101001000111000111 : n2827;
  /* mc68881_packed_decimal_unit.vhd:230:7  */
  assign n2907 = n2778 == 31'b0000000000000000000000000001001;
  /* mc68881_packed_decimal_unit.vhd:231:18  */
  assign n2913 = n2821 ? 80'b01001101010010001100100101110110011101011000011010000001011101010000110000010111 : n2827;
  /* mc68881_packed_decimal_unit.vhd:231:7  */
  assign n2915 = n2778 == 31'b0000000000000000000000000001010;
  /* mc68881_packed_decimal_unit.vhd:232:22  */
  assign n2921 = n2821 ? 80'b01011010100100101001111010001011001110110101110111000101001111010101110111100101 : n2827;
  assign n2922 = {n2915, n2907, n2899, n2891, n2883, n2875, n2867, n2859, n2851, n2843, n2835};
  /* mc68881_packed_decimal_unit.vhd:220:5  */
  always @*
    case (n2922)
      11'b10000000000: n2925 = n2913;
      11'b01000000000: n2925 = n2905;
      11'b00100000000: n2925 = n2897;
      11'b00010000000: n2925 = n2889;
      11'b00001000000: n2925 = n2881;
      11'b00000100000: n2925 = n2873;
      11'b00000010000: n2925 = n2865;
      11'b00000001000: n2925 = n2857;
      11'b00000000100: n2925 = n2849;
      11'b00000000010: n2925 = n2841;
      11'b00000000001: n2925 = n2833;
      default: n2925 = n2921;
    endcase
  /* mc68881_packed_decimal_unit.vhd:220:5  */
  assign n2928 = n2821 ? n2925 : n2827;
  /* mc68881_packed_decimal_unit.vhd:659:54  */
  assign n2929 = {28'b0, scale_bit_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:659:54  */
  assign n2931 = n2929 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:659:36  */
  assign n2932 = n2931[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:653:13  */
  assign n2933 = n7320 ? n515 : n2932;
  /* mc68881_packed_decimal_unit.vhd:653:13  */
  assign n2938 = n7320 ? work_fp_reg : 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:653:13  */
  assign n2940 = n7320 ? n2928 : 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:653:13  */
  assign n2943 = n7320 ? 3'b010 : 3'b000;
  /* mc68881_packed_decimal_unit.vhd:650:11  */
  assign n2944 = n2774 ? scale_return_state_reg : n507;
  /* mc68881_packed_decimal_unit.vhd:650:11  */
  assign n2945 = n2774 ? n515 : n2933;
  /* mc68881_packed_decimal_unit.vhd:650:11  */
  assign n2949 = n2774 ? 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000 : n2938;
  /* mc68881_packed_decimal_unit.vhd:650:11  */
  assign n2951 = n2774 ? 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000 : n2940;
  /* mc68881_packed_decimal_unit.vhd:650:11  */
  assign n2953 = n2774 ? 3'b000 : n2943;
  /* mc68881_packed_decimal_unit.vhd:649:9  */
  assign n2955 = state_reg == 5'b00101;
  assign n2968 = work_fp_reg[78:0]; // extract
  assign n2969 = {1'b0, n2968};
  /* mc68881_pkg.vhd:2203:9  */
  assign n2974 = work_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:2203:22  */
  assign n2976 = n2974 != 1'b0;
  /* mc68881_pkg.vhd:2204:11  */
  assign n2977 = work_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:2204:7  */
  assign n2981 = n2977 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:2204:7  */
  assign n2985 = n2977 ? 32'b11111111111111111111111111111111 : 32'bX;
  /* mc68881_pkg.vhd:2207:7  */
  assign n2988 = n2981 ? 1'b0 : n2981;
  /* mc68881_pkg.vhd:2207:7  */
  assign n2991 = n2981 ? 32'b00000000000000000000000000000001 : n2985;
  /* mc68881_pkg.vhd:2203:5  */
  assign n2993 = n2976 ? n2988 : 1'b1;
  /* mc68881_pkg.vhd:2203:5  */
  assign n2998 = n2976 ? n2991 : 32'bX;
  /* mc68881_pkg.vhd:1535:25  */
  assign n3010 = n2969[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n3013 = n2969[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n3015 = n2969[63:0]; // extract
  assign n3016 = {n3015, n3013, n3010};
  /* mc68881_pkg.vhd:1535:25  */
  assign n3024 = n3023[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n3028 = n3027[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n3031 = n3030[63:0]; // extract
  assign n3032 = {n3031, n3028, n3024};
  /* mc68881_pkg.vhd:2181:12  */
  assign n3033 = n3016[15:1]; // extract
  /* mc68881_pkg.vhd:2181:22  */
  assign n3034 = n3032[15:1]; // extract
  /* mc68881_pkg.vhd:2181:16  */
  assign n3035 = $unsigned(n3033) > $unsigned(n3034);
  /* mc68881_pkg.vhd:2183:15  */
  assign n3037 = n3016[15:1]; // extract
  /* mc68881_pkg.vhd:2183:25  */
  assign n3038 = n3032[15:1]; // extract
  /* mc68881_pkg.vhd:2183:19  */
  assign n3039 = $unsigned(n3037) < $unsigned(n3038);
  /* mc68881_pkg.vhd:2185:15  */
  assign n3041 = n3016[79:16]; // extract
  /* mc68881_pkg.vhd:2185:26  */
  assign n3042 = n3032[79:16]; // extract
  /* mc68881_pkg.vhd:2185:20  */
  assign n3043 = $unsigned(n3041) > $unsigned(n3042);
  /* mc68881_pkg.vhd:2187:15  */
  assign n3045 = n3016[79:16]; // extract
  /* mc68881_pkg.vhd:2187:26  */
  assign n3046 = n3032[79:16]; // extract
  /* mc68881_pkg.vhd:2187:20  */
  assign n3047 = $unsigned(n3045) < $unsigned(n3046);
  /* mc68881_pkg.vhd:2187:5  */
  assign n3050 = n3047 ? 32'b11111111111111111111111111111111 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2185:5  */
  assign n3051 = n3043 ? 32'b00000000000000000000000000000001 : n3050;
  /* mc68881_pkg.vhd:2183:5  */
  assign n3052 = n3039 ? 32'b11111111111111111111111111111111 : n3051;
  /* mc68881_pkg.vhd:2181:5  */
  assign n3053 = n3035 ? 32'b00000000000000000000000000000001 : n3052;
  /* mc68881_pkg.vhd:2210:5  */
  assign n3055 = n2993 ? n3053 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2211:9  */
  assign n3057 = work_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:2212:14  */
  assign n3058 = -n3055;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3060 = n3067 ? 1'b0 : n2993;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3063 = n3069 ? n3058 : n2998;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3064 = n2993 & n3057;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3066 = n2993 & n3057;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3067 = n3064 & n2993;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3069 = n3066 & n2993;
  /* mc68881_pkg.vhd:2214:5  */
  assign n3074 = n3060 ? n3055 : n3063;
  /* mc68881_packed_decimal_unit.vhd:665:56  */
  assign n3076 = $signed(n3074) >= $signed(32'b00000000000000000000000000000000);
  assign n3089 = work_fp_reg[78:0]; // extract
  assign n3090 = {1'b0, n3089};
  /* mc68881_pkg.vhd:2203:9  */
  assign n3095 = work_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:2203:22  */
  assign n3097 = n3095 != 1'b0;
  /* mc68881_pkg.vhd:2204:11  */
  assign n3098 = work_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:2204:7  */
  assign n3102 = n3098 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:2204:7  */
  assign n3106 = n3098 ? 32'b11111111111111111111111111111111 : 32'bX;
  /* mc68881_pkg.vhd:2207:7  */
  assign n3109 = n3102 ? 1'b0 : n3102;
  /* mc68881_pkg.vhd:2207:7  */
  assign n3112 = n3102 ? 32'b00000000000000000000000000000001 : n3106;
  /* mc68881_pkg.vhd:2203:5  */
  assign n3114 = n3097 ? n3109 : 1'b1;
  /* mc68881_pkg.vhd:2203:5  */
  assign n3119 = n3097 ? n3112 : 32'bX;
  /* mc68881_pkg.vhd:1535:25  */
  assign n3131 = n3090[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n3134 = n3090[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n3136 = n3090[63:0]; // extract
  assign n3137 = {n3136, n3134, n3131};
  /* mc68881_pkg.vhd:1535:25  */
  assign n3145 = n3144[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n3149 = n3148[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n3152 = n3151[63:0]; // extract
  assign n3153 = {n3152, n3149, n3145};
  /* mc68881_pkg.vhd:2181:12  */
  assign n3154 = n3137[15:1]; // extract
  /* mc68881_pkg.vhd:2181:22  */
  assign n3155 = n3153[15:1]; // extract
  /* mc68881_pkg.vhd:2181:16  */
  assign n3156 = $unsigned(n3154) > $unsigned(n3155);
  /* mc68881_pkg.vhd:2183:15  */
  assign n3158 = n3137[15:1]; // extract
  /* mc68881_pkg.vhd:2183:25  */
  assign n3159 = n3153[15:1]; // extract
  /* mc68881_pkg.vhd:2183:19  */
  assign n3160 = $unsigned(n3158) < $unsigned(n3159);
  /* mc68881_pkg.vhd:2185:15  */
  assign n3162 = n3137[79:16]; // extract
  /* mc68881_pkg.vhd:2185:26  */
  assign n3163 = n3153[79:16]; // extract
  /* mc68881_pkg.vhd:2185:20  */
  assign n3164 = $unsigned(n3162) > $unsigned(n3163);
  /* mc68881_pkg.vhd:2187:15  */
  assign n3166 = n3137[79:16]; // extract
  /* mc68881_pkg.vhd:2187:26  */
  assign n3167 = n3153[79:16]; // extract
  /* mc68881_pkg.vhd:2187:20  */
  assign n3168 = $unsigned(n3166) < $unsigned(n3167);
  /* mc68881_pkg.vhd:2187:5  */
  assign n3171 = n3168 ? 32'b11111111111111111111111111111111 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2185:5  */
  assign n3172 = n3164 ? 32'b00000000000000000000000000000001 : n3171;
  /* mc68881_pkg.vhd:2183:5  */
  assign n3173 = n3160 ? 32'b11111111111111111111111111111111 : n3172;
  /* mc68881_pkg.vhd:2181:5  */
  assign n3174 = n3156 ? 32'b00000000000000000000000000000001 : n3173;
  /* mc68881_pkg.vhd:2210:5  */
  assign n3176 = n3114 ? n3174 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2211:9  */
  assign n3178 = work_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:2212:14  */
  assign n3179 = -n3176;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3181 = n3188 ? 1'b0 : n3114;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3184 = n3190 ? n3179 : n3119;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3185 = n3114 & n3178;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3187 = n3114 & n3178;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3188 = n3185 & n3114;
  /* mc68881_pkg.vhd:2211:5  */
  assign n3190 = n3187 & n3114;
  /* mc68881_pkg.vhd:2214:5  */
  assign n3195 = n3181 ? n3176 : n3184;
  /* mc68881_packed_decimal_unit.vhd:671:53  */
  assign n3197 = $signed(n3195) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:671:11  */
  assign n3200 = n3197 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:671:11  */
  assign n3205 = n3197 ? work_fp_reg : 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:671:11  */
  assign n3208 = n3197 ? 80'b01000000000000101010000000000000000000000000000000000000000000000000000000000000 : 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:671:11  */
  assign n3211 = n3197 ? 32'b11111111111111111111111111111111 : 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:671:11  */
  assign n3214 = n3197 ? 3'b011 : 3'b000;
  /* mc68881_packed_decimal_unit.vhd:665:11  */
  assign n3216 = n3076 ? 1'b0 : n3200;
  /* mc68881_packed_decimal_unit.vhd:665:11  */
  assign n3220 = n3076 ? work_fp_reg : n3205;
  /* mc68881_packed_decimal_unit.vhd:665:11  */
  assign n3222 = n3076 ? 80'b00111111111110111100110011001100110011001100110011001100110011001100110011001101 : n3208;
  /* mc68881_packed_decimal_unit.vhd:665:11  */
  assign n3224 = n3076 ? 32'b00000000000000000000000000000001 : n3211;
  /* mc68881_packed_decimal_unit.vhd:665:11  */
  assign n3226 = n3076 ? 3'b011 : n3214;
  /* mc68881_packed_decimal_unit.vhd:684:31  */
  assign n3227 = {29'b0, tune_iter_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:684:31  */
  assign n3229 = n3227 == 32'b00000000000000000000000000000101;
  /* mc68881_packed_decimal_unit.vhd:688:44  */
  assign n3230 = {29'b0, tune_iter_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:688:44  */
  assign n3232 = n3230 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:688:30  */
  assign n3233 = n3232[2:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:684:11  */
  assign n3235 = n3229 ? 5'b00111 : n507;
  /* mc68881_packed_decimal_unit.vhd:684:11  */
  assign n3237 = n3229 ? 5'b00000 : n512;
  /* mc68881_packed_decimal_unit.vhd:684:11  */
  assign n3238 = n3229 ? tune_iter_reg : n3233;
  /* mc68881_packed_decimal_unit.vhd:681:11  */
  assign n3240 = n3216 ? 5'b00111 : n3235;
  /* mc68881_packed_decimal_unit.vhd:681:11  */
  assign n3242 = n3216 ? 5'b00000 : n3237;
  /* mc68881_packed_decimal_unit.vhd:681:11  */
  assign n3243 = n3216 ? tune_iter_reg : n3238;
  /* mc68881_packed_decimal_unit.vhd:663:9  */
  assign n3245 = state_reg == 5'b00110;
  /* mc68881_packed_decimal_unit.vhd:691:9  */
  assign n3247 = state_reg == 5'b00111;
  /* mc68881_packed_decimal_unit.vhd:699:36  */
  assign n3249 = {28'b0, enc_digit_reg};  //  uext
  /* mc68881_pkg.vhd:1628:14  */
  assign n3262 = n3249 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:1628:5  */
  assign n3266 = n3262 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:1628:5  */
  assign n3270 = n3262 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:1628:5  */
  assign n3272 = n3262 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : 80'bX;
  /* mc68881_pkg.vhd:1632:14  */
  assign n3274 = $signed(n3249) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_pkg.vhd:1633:7  */
  assign n3277 = n3266 ? 1'b1 : 1'b0;
  /* mc68881_pkg.vhd:1634:26  */
  assign n3278 = -n3249;
  /* mc68881_pkg.vhd:1634:25  */
  assign n3279 = n3278[30:0];  // trunc
  /* mc68881_pkg.vhd:1634:7  */
  assign n3281 = n3266 ? n3279 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:1636:25  */
  assign n3282 = {27'b0, enc_digit_reg};  //  uext
  /* mc68881_pkg.vhd:1636:7  */
  assign n3284 = n3266 ? n3282 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:1632:5  */
  assign n3285 = n3274 ? n3281 : n3284;
  /* mc68881_pkg.vhd:1632:5  */
  assign n3287 = n3274 ? n3277 : 1'b0;
  /* mc68881_pkg.vhd:1632:5  */
  assign n3289 = n3266 ? n3285 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:1632:5  */
  assign n3292 = n3266 ? n3287 : 1'b0;
  /* mc68881_pkg.vhd:1639:5  */
  assign n3295 = n3266 ? n3289 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3298 = {1'b0, n3295};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3300 = $signed(n3298) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3302 = n3306 ? 1'b0 : n3266;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3305 = n3300 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3306 = n3300 & n3266;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3308 = n3266 ? n3305 : 1'b1;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3310 = {1'b0, n3295};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3312 = $signed(n3310) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3313 = n3312[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3314 = n3302 ? n3313 : n3295;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3317 = n3302 ? 32'b00000000000000000000000000000001 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3318 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3319 = n3318 & n3308;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3320 = {1'b0, n3314};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3322 = $signed(n3320) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3324 = n3327 ? 1'b0 : n3319;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3326 = n3328 ? 1'b0 : n3308;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3327 = n3322 & n3319;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3328 = n3322 & n3319;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3329 = {1'b0, n3314};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3331 = $signed(n3329) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3332 = n3331[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3333 = n3324 ? n3332 : n3314;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3335 = n3317 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3336 = n3324 ? n3335 : n3317;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3337 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3338 = n3337 & n3326;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3339 = {1'b0, n3333};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3341 = $signed(n3339) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3343 = n3346 ? 1'b0 : n3338;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3345 = n3347 ? 1'b0 : n3326;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3346 = n3341 & n3338;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3347 = n3341 & n3338;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3348 = {1'b0, n3333};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3350 = $signed(n3348) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3351 = n3350[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3352 = n3343 ? n3351 : n3333;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3354 = n3336 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3355 = n3343 ? n3354 : n3336;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3356 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3357 = n3356 & n3345;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3358 = {1'b0, n3352};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3360 = $signed(n3358) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3362 = n3365 ? 1'b0 : n3357;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3364 = n3366 ? 1'b0 : n3345;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3365 = n3360 & n3357;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3366 = n3360 & n3357;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3367 = {1'b0, n3352};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3369 = $signed(n3367) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3370 = n3369[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3371 = n3362 ? n3370 : n3352;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3373 = n3355 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3374 = n3362 ? n3373 : n3355;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3375 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3376 = n3375 & n3364;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3377 = {1'b0, n3371};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3379 = $signed(n3377) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3381 = n3384 ? 1'b0 : n3376;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3383 = n3385 ? 1'b0 : n3364;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3384 = n3379 & n3376;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3385 = n3379 & n3376;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3386 = {1'b0, n3371};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3388 = $signed(n3386) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3389 = n3388[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3390 = n3381 ? n3389 : n3371;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3392 = n3374 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3393 = n3381 ? n3392 : n3374;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3394 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3395 = n3394 & n3383;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3396 = {1'b0, n3390};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3398 = $signed(n3396) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3400 = n3403 ? 1'b0 : n3395;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3402 = n3404 ? 1'b0 : n3383;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3403 = n3398 & n3395;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3404 = n3398 & n3395;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3405 = {1'b0, n3390};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3407 = $signed(n3405) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3408 = n3407[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3409 = n3400 ? n3408 : n3390;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3411 = n3393 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3412 = n3400 ? n3411 : n3393;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3413 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3414 = n3413 & n3402;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3415 = {1'b0, n3409};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3417 = $signed(n3415) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3419 = n3422 ? 1'b0 : n3414;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3421 = n3423 ? 1'b0 : n3402;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3422 = n3417 & n3414;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3423 = n3417 & n3414;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3424 = {1'b0, n3409};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3426 = $signed(n3424) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3427 = n3426[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3428 = n3419 ? n3427 : n3409;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3430 = n3412 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3431 = n3419 ? n3430 : n3412;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3432 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3433 = n3432 & n3421;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3434 = {1'b0, n3428};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3436 = $signed(n3434) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3438 = n3441 ? 1'b0 : n3433;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3440 = n3442 ? 1'b0 : n3421;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3441 = n3436 & n3433;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3442 = n3436 & n3433;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3443 = {1'b0, n3428};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3445 = $signed(n3443) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3446 = n3445[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3447 = n3438 ? n3446 : n3428;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3449 = n3431 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3450 = n3438 ? n3449 : n3431;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3451 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3452 = n3451 & n3440;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3453 = {1'b0, n3447};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3455 = $signed(n3453) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3457 = n3460 ? 1'b0 : n3452;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3459 = n3461 ? 1'b0 : n3440;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3460 = n3455 & n3452;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3461 = n3455 & n3452;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3462 = {1'b0, n3447};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3464 = $signed(n3462) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3465 = n3464[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3466 = n3457 ? n3465 : n3447;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3468 = n3450 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3469 = n3457 ? n3468 : n3450;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3470 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3471 = n3470 & n3459;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3472 = {1'b0, n3466};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3474 = $signed(n3472) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3476 = n3479 ? 1'b0 : n3471;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3478 = n3480 ? 1'b0 : n3459;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3479 = n3474 & n3471;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3480 = n3474 & n3471;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3481 = {1'b0, n3466};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3483 = $signed(n3481) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3484 = n3483[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3485 = n3476 ? n3484 : n3466;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3487 = n3469 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3488 = n3476 ? n3487 : n3469;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3489 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3490 = n3489 & n3478;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3491 = {1'b0, n3485};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3493 = $signed(n3491) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3495 = n3498 ? 1'b0 : n3490;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3497 = n3499 ? 1'b0 : n3478;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3498 = n3493 & n3490;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3499 = n3493 & n3490;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3500 = {1'b0, n3485};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3502 = $signed(n3500) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3503 = n3502[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3504 = n3495 ? n3503 : n3485;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3506 = n3488 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3507 = n3495 ? n3506 : n3488;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3508 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3509 = n3508 & n3497;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3510 = {1'b0, n3504};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3512 = $signed(n3510) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3514 = n3517 ? 1'b0 : n3509;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3516 = n3518 ? 1'b0 : n3497;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3517 = n3512 & n3509;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3518 = n3512 & n3509;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3519 = {1'b0, n3504};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3521 = $signed(n3519) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3522 = n3521[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3523 = n3514 ? n3522 : n3504;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3525 = n3507 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3526 = n3514 ? n3525 : n3507;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3527 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3528 = n3527 & n3516;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3529 = {1'b0, n3523};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3531 = $signed(n3529) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3533 = n3536 ? 1'b0 : n3528;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3535 = n3537 ? 1'b0 : n3516;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3536 = n3531 & n3528;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3537 = n3531 & n3528;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3538 = {1'b0, n3523};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3540 = $signed(n3538) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3541 = n3540[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3542 = n3533 ? n3541 : n3523;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3544 = n3526 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3545 = n3533 ? n3544 : n3526;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3546 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3547 = n3546 & n3535;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3548 = {1'b0, n3542};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3550 = $signed(n3548) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3552 = n3555 ? 1'b0 : n3547;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3554 = n3556 ? 1'b0 : n3535;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3555 = n3550 & n3547;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3556 = n3550 & n3547;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3557 = {1'b0, n3542};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3559 = $signed(n3557) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3560 = n3559[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3561 = n3552 ? n3560 : n3542;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3563 = n3545 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3564 = n3552 ? n3563 : n3545;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3565 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3566 = n3565 & n3554;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3567 = {1'b0, n3561};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3569 = $signed(n3567) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3571 = n3574 ? 1'b0 : n3566;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3573 = n3575 ? 1'b0 : n3554;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3574 = n3569 & n3566;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3575 = n3569 & n3566;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3576 = {1'b0, n3561};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3578 = $signed(n3576) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3579 = n3578[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3580 = n3571 ? n3579 : n3561;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3582 = n3564 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3583 = n3571 ? n3582 : n3564;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3584 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3585 = n3584 & n3573;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3586 = {1'b0, n3580};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3588 = $signed(n3586) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3590 = n3593 ? 1'b0 : n3585;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3592 = n3594 ? 1'b0 : n3573;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3593 = n3588 & n3585;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3594 = n3588 & n3585;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3595 = {1'b0, n3580};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3597 = $signed(n3595) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3598 = n3597[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3599 = n3590 ? n3598 : n3580;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3601 = n3583 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3602 = n3590 ? n3601 : n3583;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3603 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3604 = n3603 & n3592;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3605 = {1'b0, n3599};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3607 = $signed(n3605) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3609 = n3612 ? 1'b0 : n3604;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3611 = n3613 ? 1'b0 : n3592;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3612 = n3607 & n3604;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3613 = n3607 & n3604;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3614 = {1'b0, n3599};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3616 = $signed(n3614) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3617 = n3616[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3618 = n3609 ? n3617 : n3599;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3620 = n3602 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3621 = n3609 ? n3620 : n3602;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3622 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3623 = n3622 & n3611;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3624 = {1'b0, n3618};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3626 = $signed(n3624) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3628 = n3631 ? 1'b0 : n3623;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3630 = n3632 ? 1'b0 : n3611;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3631 = n3626 & n3623;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3632 = n3626 & n3623;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3633 = {1'b0, n3618};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3635 = $signed(n3633) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3636 = n3635[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3637 = n3628 ? n3636 : n3618;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3639 = n3621 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3640 = n3628 ? n3639 : n3621;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3641 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3642 = n3641 & n3630;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3643 = {1'b0, n3637};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3645 = $signed(n3643) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3647 = n3650 ? 1'b0 : n3642;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3649 = n3651 ? 1'b0 : n3630;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3650 = n3645 & n3642;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3651 = n3645 & n3642;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3652 = {1'b0, n3637};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3654 = $signed(n3652) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3655 = n3654[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3656 = n3647 ? n3655 : n3637;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3658 = n3640 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3659 = n3647 ? n3658 : n3640;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3660 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3661 = n3660 & n3649;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3662 = {1'b0, n3656};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3664 = $signed(n3662) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3666 = n3669 ? 1'b0 : n3661;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3668 = n3670 ? 1'b0 : n3649;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3669 = n3664 & n3661;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3670 = n3664 & n3661;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3671 = {1'b0, n3656};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3673 = $signed(n3671) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3674 = n3673[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3675 = n3666 ? n3674 : n3656;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3677 = n3659 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3678 = n3666 ? n3677 : n3659;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3679 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3680 = n3679 & n3668;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3681 = {1'b0, n3675};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3683 = $signed(n3681) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3685 = n3688 ? 1'b0 : n3680;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3687 = n3689 ? 1'b0 : n3668;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3688 = n3683 & n3680;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3689 = n3683 & n3680;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3690 = {1'b0, n3675};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3692 = $signed(n3690) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3693 = n3692[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3694 = n3685 ? n3693 : n3675;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3696 = n3678 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3697 = n3685 ? n3696 : n3678;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3698 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3699 = n3698 & n3687;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3700 = {1'b0, n3694};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3702 = $signed(n3700) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3704 = n3707 ? 1'b0 : n3699;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3706 = n3708 ? 1'b0 : n3687;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3707 = n3702 & n3699;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3708 = n3702 & n3699;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3709 = {1'b0, n3694};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3711 = $signed(n3709) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3712 = n3711[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3713 = n3704 ? n3712 : n3694;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3715 = n3697 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3716 = n3704 ? n3715 : n3697;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3717 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3718 = n3717 & n3706;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3719 = {1'b0, n3713};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3721 = $signed(n3719) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3723 = n3726 ? 1'b0 : n3718;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3725 = n3727 ? 1'b0 : n3706;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3726 = n3721 & n3718;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3727 = n3721 & n3718;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3728 = {1'b0, n3713};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3730 = $signed(n3728) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3731 = n3730[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3732 = n3723 ? n3731 : n3713;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3734 = n3716 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3735 = n3723 ? n3734 : n3716;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3736 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3737 = n3736 & n3725;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3738 = {1'b0, n3732};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3740 = $signed(n3738) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3742 = n3745 ? 1'b0 : n3737;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3744 = n3746 ? 1'b0 : n3725;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3745 = n3740 & n3737;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3746 = n3740 & n3737;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3747 = {1'b0, n3732};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3749 = $signed(n3747) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3750 = n3749[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3751 = n3742 ? n3750 : n3732;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3753 = n3735 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3754 = n3742 ? n3753 : n3735;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3755 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3756 = n3755 & n3744;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3757 = {1'b0, n3751};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3759 = $signed(n3757) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3761 = n3764 ? 1'b0 : n3756;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3763 = n3765 ? 1'b0 : n3744;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3764 = n3759 & n3756;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3765 = n3759 & n3756;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3766 = {1'b0, n3751};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3768 = $signed(n3766) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3769 = n3768[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3770 = n3761 ? n3769 : n3751;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3772 = n3754 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3773 = n3761 ? n3772 : n3754;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3774 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3775 = n3774 & n3763;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3776 = {1'b0, n3770};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3778 = $signed(n3776) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3780 = n3783 ? 1'b0 : n3775;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3782 = n3784 ? 1'b0 : n3763;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3783 = n3778 & n3775;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3784 = n3778 & n3775;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3785 = {1'b0, n3770};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3787 = $signed(n3785) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3788 = n3787[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3789 = n3780 ? n3788 : n3770;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3791 = n3773 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3792 = n3780 ? n3791 : n3773;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3793 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3794 = n3793 & n3782;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3795 = {1'b0, n3789};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3797 = $signed(n3795) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3799 = n3802 ? 1'b0 : n3794;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3801 = n3803 ? 1'b0 : n3782;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3802 = n3797 & n3794;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3803 = n3797 & n3794;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3804 = {1'b0, n3789};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3806 = $signed(n3804) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3807 = n3806[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3808 = n3799 ? n3807 : n3789;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3810 = n3792 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3811 = n3799 ? n3810 : n3792;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3812 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3813 = n3812 & n3801;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3814 = {1'b0, n3808};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3816 = $signed(n3814) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3818 = n3821 ? 1'b0 : n3813;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3820 = n3822 ? 1'b0 : n3801;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3821 = n3816 & n3813;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3822 = n3816 & n3813;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3823 = {1'b0, n3808};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3825 = $signed(n3823) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3826 = n3825[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3827 = n3818 ? n3826 : n3808;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3829 = n3811 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3830 = n3818 ? n3829 : n3811;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3831 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3832 = n3831 & n3820;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3833 = {1'b0, n3827};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3835 = $signed(n3833) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3837 = n3840 ? 1'b0 : n3832;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3839 = n3841 ? 1'b0 : n3820;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3840 = n3835 & n3832;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3841 = n3835 & n3832;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3842 = {1'b0, n3827};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3844 = $signed(n3842) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3845 = n3844[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3846 = n3837 ? n3845 : n3827;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3848 = n3830 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3849 = n3837 ? n3848 : n3830;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3850 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3851 = n3850 & n3839;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3852 = {1'b0, n3846};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3854 = $signed(n3852) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3856 = n3859 ? 1'b0 : n3851;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3858 = n3860 ? 1'b0 : n3839;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3859 = n3854 & n3851;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3860 = n3854 & n3851;
  /* mc68881_pkg.vhd:1644:18  */
  assign n3861 = {1'b0, n3846};  //  uext
  /* mc68881_pkg.vhd:1644:18  */
  assign n3863 = $signed(n3861) / $signed(32'b00000000000000000000000000000010); // sdiv
  /* mc68881_pkg.vhd:1644:7  */
  assign n3864 = n3863[30:0];  // trunc
  /* mc68881_pkg.vhd:1644:7  */
  assign n3865 = n3856 ? n3864 : n3846;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3867 = n3849 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3868 = n3856 ? n3867 : n3849;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3869 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3870 = n3869 & n3858;
  /* mc68881_pkg.vhd:1643:21  */
  assign n3871 = {1'b0, n3865};  //  uext
  /* mc68881_pkg.vhd:1643:21  */
  assign n3873 = $signed(n3871) <= $signed(32'b00000000000000000000000000000001);
  /* mc68881_pkg.vhd:1643:7  */
  assign n3875 = n3878 ? 1'b0 : n3870;
  /* mc68881_pkg.vhd:1643:7  */
  assign n3878 = n3873 & n3870;
  /* mc68881_pkg.vhd:1645:26  */
  assign n3886 = n3868 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:1645:7  */
  assign n3887 = n3875 ? n3886 : n3868;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3890 = n3266 & n3270;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3891 = n3266 ? n3890 : n3266;
  /* mc68881_pkg.vhd:1642:5  */
  assign n3893 = n3266 ? n3887 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:1648:36  */
  assign n3897 = 32'b00000000000000000011111111111111 + n3893;
  /* mc68881_pkg.vhd:1648:24  */
  assign n3898 = n3897[30:0];  // trunc
  /* mc68881_pkg.vhd:1648:12  */
  assign n3899 = n3898[14:0];  // trunc
  /* mc68881_pkg.vhd:1648:5  */
  assign n3901 = n3891 ? n3899 : 15'b000000000000000;
  /* mc68881_pkg.vhd:1649:20  */
  assign n3903 = {33'b0, n3289};  //  uext
  /* mc68881_pkg.vhd:1649:92  */
  assign n3905 = 32'b00000000000000000000000000111111 - n3893;
  /* mc68881_pkg.vhd:1649:72  */
  assign n3906 = n3903 << n3905;
  /* mc68881_pkg.vhd:1649:72  */
  assign n3907 = -n3905;
  /* mc68881_pkg.vhd:1649:72  */
  assign n3908 = n3903 >> n3907;
  /* mc68881_pkg.vhd:1649:72  */
  assign n3909 = n3905[31]; // extract
  /* mc68881_pkg.vhd:1649:72  */
  assign n3910 = n3909 ? n3908 : n3906;
  /* mc68881_pkg.vhd:1649:5  */
  assign n3912 = n3891 ? n3910 : 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:1651:5  */
  assign n3915 = n3891 ? n3292 : 1'b0;
  assign n3918 = n3916[78:64]; // extract
  /* mc68881_pkg.vhd:1652:5  */
  assign n3919 = n3891 ? n3901 : n3918;
  assign n3920 = n3916[63:0]; // extract
  /* mc68881_pkg.vhd:1653:5  */
  assign n3921 = n3891 ? n3912 : n3920;
  assign n3922 = {n3915, n3919, n3921};
  /* mc68881_pkg.vhd:1654:5  */
  assign n3927 = n3891 ? n3922 : n3272;
  /* mc68881_packed_decimal_unit.vhd:696:9  */
  assign n3929 = state_reg == 5'b01000;
  /* mc68881_packed_decimal_unit.vhd:703:9  */
  assign n3931 = state_reg == 5'b01001;
  /* mc68881_pkg.vhd:1535:25  */
  assign n3943 = work_fp_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n3946 = work_fp_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n3948 = work_fp_reg[63:0]; // extract
  assign n3949 = {n3948, n3946, n3943};
  /* mc68881_pkg.vhd:2083:20  */
  assign n3950 = n3949[15:1]; // extract
  /* mc68881_pkg.vhd:2083:24  */
  assign n3952 = n3950 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2083:40  */
  assign n3953 = n3949[79:16]; // extract
  /* mc68881_pkg.vhd:2083:45  */
  assign n3955 = n3953 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2083:28  */
  assign n3956 = n3955 & n3952;
  /* mc68881_packed_decimal_unit.vhd:710:14  */
  assign n3957 = ~n3956;
  /* mc68881_packed_decimal_unit.vhd:710:11  */
  assign n3959 = n3957 ? 1'b1 : inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:709:9  */
  assign n3961 = state_reg == 5'b01010;
  /* mc68881_packed_decimal_unit.vhd:720:25  */
  assign n3963 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:720:41  */
  assign n3966 = {28'b0, n7323};  //  uext
  /* mc68881_packed_decimal_unit.vhd:720:41  */
  assign n3968 = n3966 == 32'b00000000000000000000000000001001;
  /* mc68881_packed_decimal_unit.vhd:721:24  */
  assign n3970 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:722:31  */
  assign n3974 = {27'b0, kround_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:722:31  */
  assign n3976 = n3974 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:725:38  */
  assign n3978 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:725:38  */
  assign n3980 = n3978 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:725:28  */
  assign n3981 = n3980[14:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:730:42  */
  assign n3983 = {{25{req_k_reg[6]}}, req_k_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:193:14  */
  assign n3989 = $signed(n3983) < $signed(32'b11111111111111111111111111000000);
  /* mc68881_packed_decimal_unit.vhd:195:17  */
  assign n3992 = $signed(n3983) > $signed(32'b00000000000000000000000000010001);
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n3996 = n3992 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n4000 = n3992 ? 32'b00000000000000000000000000010001 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n4002 = n3989 ? 1'b0 : n3996;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n4007 = n3989 ? 32'b11111111111111111111111111000000 : n4000;
  /* mc68881_packed_decimal_unit.vhd:198:5  */
  assign n4012 = n4002 ? n3983 : n4007;
  /* mc68881_packed_decimal_unit.vhd:731:28  */
  assign n4014 = $signed(n4012) > $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:734:42  */
  assign n4015 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:734:42  */
  assign n4017 = n4015 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:734:49  */
  assign n4018 = -n4012;
  /* mc68881_packed_decimal_unit.vhd:734:46  */
  assign n4019 = n4017 + n4018;
  /* mc68881_packed_decimal_unit.vhd:731:15  */
  assign n4020 = n4014 ? n4012 : n4019;
  /* mc68881_packed_decimal_unit.vhd:736:30  */
  assign n4022 = $signed(n4020) < $signed(32'b00000000000000000000000000000001);
  /* mc68881_packed_decimal_unit.vhd:738:33  */
  assign n4024 = $signed(n4020) > $signed(32'b00000000000000000000000000010001);
  /* mc68881_packed_decimal_unit.vhd:738:15  */
  assign n4026 = n4024 ? 32'b00000000000000000000000000010001 : n4020;
  /* mc68881_packed_decimal_unit.vhd:736:15  */
  assign n4028 = n4022 ? 32'b00000000000000000000000000000001 : n4026;
  /* mc68881_packed_decimal_unit.vhd:741:34  */
  assign n4029 = n4028[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:744:48  */
  assign n4030 = {27'b0, kround_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:744:48  */
  assign n4032 = n4030 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:744:33  */
  assign n4033 = n4032[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:722:13  */
  assign n4035 = n3976 ? 5'b01100 : n507;
  /* mc68881_packed_decimal_unit.vhd:720:11  */
  assign n4036 = n4106 ? n3981 : n508;
  assign n4037 = n7402[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:722:13  */
  assign n4038 = n3976 ? 4'b0001 : n4037;
  assign n4039 = n7402[63:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:722:13  */
  assign n4040 = n3976 ? n4029 : n513;
  /* mc68881_packed_decimal_unit.vhd:722:13  */
  assign n4041 = n3976 ? n517 : n4033;
  /* mc68881_packed_decimal_unit.vhd:747:24  */
  assign n4045 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:747:54  */
  assign n4048 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:747:70  */
  assign n4051 = {28'b0, n7405};  //  uext
  /* mc68881_packed_decimal_unit.vhd:747:70  */
  assign n4053 = n4051 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:747:43  */
  assign n4054 = n4053[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:749:40  */
  assign n4057 = {{25{req_k_reg[6]}}, req_k_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:193:14  */
  assign n4063 = $signed(n4057) < $signed(32'b11111111111111111111111111000000);
  /* mc68881_packed_decimal_unit.vhd:195:17  */
  assign n4066 = $signed(n4057) > $signed(32'b00000000000000000000000000010001);
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n4070 = n4066 ? 1'b0 : 1'b1;
  /* mc68881_packed_decimal_unit.vhd:195:5  */
  assign n4074 = n4066 ? 32'b00000000000000000000000000010001 : 32'bX;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n4076 = n4063 ? 1'b0 : n4070;
  /* mc68881_packed_decimal_unit.vhd:193:5  */
  assign n4081 = n4063 ? 32'b11111111111111111111111111000000 : n4074;
  /* mc68881_packed_decimal_unit.vhd:198:5  */
  assign n4086 = n4076 ? n4057 : n4081;
  /* mc68881_packed_decimal_unit.vhd:750:26  */
  assign n4088 = $signed(n4086) > $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:753:40  */
  assign n4089 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:753:40  */
  assign n4091 = n4089 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:753:47  */
  assign n4092 = -n4086;
  /* mc68881_packed_decimal_unit.vhd:753:44  */
  assign n4093 = n4091 + n4092;
  /* mc68881_packed_decimal_unit.vhd:750:13  */
  assign n4094 = n4088 ? n4086 : n4093;
  /* mc68881_packed_decimal_unit.vhd:755:28  */
  assign n4096 = $signed(n4094) < $signed(32'b00000000000000000000000000000001);
  /* mc68881_packed_decimal_unit.vhd:757:31  */
  assign n4098 = $signed(n4094) > $signed(32'b00000000000000000000000000010001);
  /* mc68881_packed_decimal_unit.vhd:757:13  */
  assign n4100 = n4098 ? 32'b00000000000000000000000000010001 : n4094;
  /* mc68881_packed_decimal_unit.vhd:755:13  */
  assign n4102 = n4096 ? 32'b00000000000000000000000000000001 : n4100;
  /* mc68881_packed_decimal_unit.vhd:760:32  */
  assign n4103 = n4102[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:720:11  */
  assign n4105 = n3968 ? n4035 : 5'b01100;
  /* mc68881_packed_decimal_unit.vhd:720:11  */
  assign n4106 = n3976 & n3968;
  assign n4107 = {n4038, n4039};
  /* mc68881_packed_decimal_unit.vhd:720:11  */
  assign n4108 = n3968 ? n4107 : n7484;
  /* mc68881_packed_decimal_unit.vhd:720:11  */
  assign n4109 = n3968 ? n4040 : n4103;
  /* mc68881_packed_decimal_unit.vhd:720:11  */
  assign n4110 = n3968 ? n4041 : n517;
  /* mc68881_packed_decimal_unit.vhd:718:9  */
  assign n4114 = state_reg == 5'b01011;
  /* mc68881_packed_decimal_unit.vhd:765:11  */
  assign n4115 = {27'b0, keep_digits_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:767:26  */
  assign n4117 = $signed(n4115) < $signed(32'b00000000000000000000000000010001);
  /* mc68881_packed_decimal_unit.vhd:768:39  */
  assign n4119 = 5'b10000 - keep_digits_reg;
  /* mc68881_packed_decimal_unit.vhd:768:13  */
  assign n4122 = {27'b0, n7487};  //  uext
  /* mc68881_packed_decimal_unit.vhd:772:28  */
  assign n4123 = {1'b0, n4122};  //  uext
  /* mc68881_packed_decimal_unit.vhd:772:28  */
  assign n4125 = $signed(n4123) > $signed(32'b00000000000000000000000000000101);
  /* mc68881_packed_decimal_unit.vhd:774:31  */
  assign n4126 = {1'b0, n4122};  //  uext
  /* mc68881_packed_decimal_unit.vhd:774:31  */
  assign n4128 = n4126 == 32'b00000000000000000000000000000101;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4130 = $signed(32'b00000000000000000000000000000000) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4131 = digits_reg[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4132 = {28'b0, n4131};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4134 = n4132 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4135 = n4134 & n4130;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4138 = n4135 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4141 = $signed(32'b00000000000000000000000000000001) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4142 = digits_reg[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4143 = {28'b0, n4142};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4145 = n4143 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4146 = n4145 & n4141;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4148 = n4146 ? 1'b1 : n4138;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4150 = $signed(32'b00000000000000000000000000000010) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4151 = digits_reg[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4152 = {28'b0, n4151};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4154 = n4152 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4155 = n4154 & n4150;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4157 = n4155 ? 1'b1 : n4148;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4159 = $signed(32'b00000000000000000000000000000011) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4160 = digits_reg[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4161 = {28'b0, n4160};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4163 = n4161 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4164 = n4163 & n4159;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4166 = n4164 ? 1'b1 : n4157;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4168 = $signed(32'b00000000000000000000000000000100) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4169 = digits_reg[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4170 = {28'b0, n4169};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4172 = n4170 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4173 = n4172 & n4168;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4175 = n4173 ? 1'b1 : n4166;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4177 = $signed(32'b00000000000000000000000000000101) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4178 = digits_reg[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4179 = {28'b0, n4178};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4181 = n4179 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4182 = n4181 & n4177;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4184 = n4182 ? 1'b1 : n4175;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4186 = $signed(32'b00000000000000000000000000000110) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4187 = digits_reg[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4188 = {28'b0, n4187};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4190 = n4188 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4191 = n4190 & n4186;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4193 = n4191 ? 1'b1 : n4184;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4195 = $signed(32'b00000000000000000000000000000111) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4196 = digits_reg[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4197 = {28'b0, n4196};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4199 = n4197 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4200 = n4199 & n4195;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4202 = n4200 ? 1'b1 : n4193;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4204 = $signed(32'b00000000000000000000000000001000) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4205 = digits_reg[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4206 = {28'b0, n4205};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4208 = n4206 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4209 = n4208 & n4204;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4211 = n4209 ? 1'b1 : n4202;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4213 = $signed(32'b00000000000000000000000000001001) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4214 = digits_reg[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4215 = {28'b0, n4214};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4217 = n4215 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4218 = n4217 & n4213;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4220 = n4218 ? 1'b1 : n4211;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4222 = $signed(32'b00000000000000000000000000001010) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4223 = digits_reg[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4224 = {28'b0, n4223};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4226 = n4224 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4227 = n4226 & n4222;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4229 = n4227 ? 1'b1 : n4220;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4231 = $signed(32'b00000000000000000000000000001011) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4232 = digits_reg[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4233 = {28'b0, n4232};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4235 = n4233 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4236 = n4235 & n4231;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4238 = n4236 ? 1'b1 : n4229;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4240 = $signed(32'b00000000000000000000000000001100) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4241 = digits_reg[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4242 = {28'b0, n4241};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4244 = n4242 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4245 = n4244 & n4240;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4247 = n4245 ? 1'b1 : n4238;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4249 = $signed(32'b00000000000000000000000000001101) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4250 = digits_reg[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4251 = {28'b0, n4250};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4253 = n4251 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4254 = n4253 & n4249;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4256 = n4254 ? 1'b1 : n4247;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4258 = $signed(32'b00000000000000000000000000001110) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4259 = digits_reg[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4260 = {28'b0, n4259};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4262 = n4260 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4263 = n4262 & n4258;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4265 = n4263 ? 1'b1 : n4256;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4267 = $signed(32'b00000000000000000000000000001111) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4268 = digits_reg[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4269 = {28'b0, n4268};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4271 = n4269 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4272 = n4271 & n4267;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4274 = n4272 ? 1'b1 : n4265;
  /* mc68881_packed_decimal_unit.vhd:777:24  */
  assign n4276 = $signed(32'b00000000000000000000000000010000) > $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:777:52  */
  assign n4277 = digits_reg[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4278 = {28'b0, n4277};  //  uext
  /* mc68881_packed_decimal_unit.vhd:777:58  */
  assign n4280 = n4278 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:777:38  */
  assign n4281 = n4280 & n4276;
  /* mc68881_packed_decimal_unit.vhd:777:17  */
  assign n4283 = n4281 ? 1'b1 : n4274;
  /* mc68881_packed_decimal_unit.vhd:781:57  */
  assign n4285 = n4115 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:781:57  */
  assign n4286 = n4285[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:781:57  */
  assign n4288 = 5'b10000 - n4286;
  /* mc68881_packed_decimal_unit.vhd:781:61  */
  assign n4291 = {28'b0, n7490};  //  uext
  assign n4292 = n4291[0]; // extract
  /* mc68881_packed_decimal_unit.vhd:781:61  */
  assign n4293 = {31'b0, n4292};  //  uext
  /* mc68881_packed_decimal_unit.vhd:781:67  */
  assign n4295 = n4293 == 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:781:31  */
  assign n4296 = n4283 | n4295;
  /* mc68881_packed_decimal_unit.vhd:781:15  */
  assign n4299 = n4296 ? 32'b00000000000000000000000000000001 : 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:774:13  */
  assign n4301 = n4128 ? n4299 : 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:772:13  */
  assign n4304 = n4125 ? 32'b00000000000000000000000000000001 : n4301;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4308 = $signed(32'b00000000000000000000000000000000) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4309 = digits_reg[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4310 = {28'b0, n4309};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4312 = n4310 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4313 = n4312 & n4308;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4315 = n4313 ? 1'b1 : inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4317 = $signed(32'b00000000000000000000000000000001) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4318 = digits_reg[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4319 = {28'b0, n4318};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4321 = n4319 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4322 = n4321 & n4317;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4324 = n4322 ? 1'b1 : n4315;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4326 = $signed(32'b00000000000000000000000000000010) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4327 = digits_reg[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4328 = {28'b0, n4327};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4330 = n4328 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4331 = n4330 & n4326;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4333 = n4331 ? 1'b1 : n4324;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4335 = $signed(32'b00000000000000000000000000000011) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4336 = digits_reg[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4337 = {28'b0, n4336};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4339 = n4337 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4340 = n4339 & n4335;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4342 = n4340 ? 1'b1 : n4333;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4344 = $signed(32'b00000000000000000000000000000100) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4345 = digits_reg[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4346 = {28'b0, n4345};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4348 = n4346 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4349 = n4348 & n4344;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4351 = n4349 ? 1'b1 : n4342;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4353 = $signed(32'b00000000000000000000000000000101) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4354 = digits_reg[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4355 = {28'b0, n4354};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4357 = n4355 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4358 = n4357 & n4353;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4360 = n4358 ? 1'b1 : n4351;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4362 = $signed(32'b00000000000000000000000000000110) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4363 = digits_reg[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4364 = {28'b0, n4363};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4366 = n4364 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4367 = n4366 & n4362;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4369 = n4367 ? 1'b1 : n4360;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4371 = $signed(32'b00000000000000000000000000000111) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4372 = digits_reg[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4373 = {28'b0, n4372};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4375 = n4373 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4376 = n4375 & n4371;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4378 = n4376 ? 1'b1 : n4369;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4380 = $signed(32'b00000000000000000000000000001000) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4381 = digits_reg[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4382 = {28'b0, n4381};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4384 = n4382 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4385 = n4384 & n4380;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4387 = n4385 ? 1'b1 : n4378;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4389 = $signed(32'b00000000000000000000000000001001) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4390 = digits_reg[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4391 = {28'b0, n4390};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4393 = n4391 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4394 = n4393 & n4389;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4396 = n4394 ? 1'b1 : n4387;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4398 = $signed(32'b00000000000000000000000000001010) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4399 = digits_reg[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4400 = {28'b0, n4399};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4402 = n4400 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4403 = n4402 & n4398;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4405 = n4403 ? 1'b1 : n4396;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4407 = $signed(32'b00000000000000000000000000001011) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4408 = digits_reg[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4409 = {28'b0, n4408};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4411 = n4409 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4412 = n4411 & n4407;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4414 = n4412 ? 1'b1 : n4405;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4416 = $signed(32'b00000000000000000000000000001100) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4417 = digits_reg[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4418 = {28'b0, n4417};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4420 = n4418 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4421 = n4420 & n4416;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4423 = n4421 ? 1'b1 : n4414;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4425 = $signed(32'b00000000000000000000000000001101) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4426 = digits_reg[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4427 = {28'b0, n4426};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4429 = n4427 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4430 = n4429 & n4425;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4432 = n4430 ? 1'b1 : n4423;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4434 = $signed(32'b00000000000000000000000000001110) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4435 = digits_reg[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4436 = {28'b0, n4435};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4438 = n4436 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4439 = n4438 & n4434;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4441 = n4439 ? 1'b1 : n4432;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4443 = $signed(32'b00000000000000000000000000001111) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4444 = digits_reg[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4445 = {28'b0, n4444};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4447 = n4445 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4448 = n4447 & n4443;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4450 = n4448 ? 1'b1 : n4441;
  /* mc68881_packed_decimal_unit.vhd:788:22  */
  assign n4452 = $signed(32'b00000000000000000000000000010000) >= $signed(n4115);
  /* mc68881_packed_decimal_unit.vhd:788:51  */
  assign n4453 = digits_reg[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4454 = {28'b0, n4453};  //  uext
  /* mc68881_packed_decimal_unit.vhd:788:57  */
  assign n4456 = n4454 != 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:788:37  */
  assign n4457 = n4456 & n4452;
  /* mc68881_packed_decimal_unit.vhd:788:15  */
  assign n4459 = n4457 ? 1'b1 : n4450;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4461 = $signed(32'b00000000000000000000000000000000) >= $signed(n4115);
  assign n4463 = n510[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4464 = n4461 ? 4'b0000 : n4463;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4466 = $signed(32'b00000000000000000000000000000001) >= $signed(n4115);
  assign n4468 = n510[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4469 = n4466 ? 4'b0000 : n4468;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4471 = $signed(32'b00000000000000000000000000000010) >= $signed(n4115);
  assign n4473 = n510[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4474 = n4471 ? 4'b0000 : n4473;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4476 = $signed(32'b00000000000000000000000000000011) >= $signed(n4115);
  assign n4478 = n510[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4479 = n4476 ? 4'b0000 : n4478;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4481 = $signed(32'b00000000000000000000000000000100) >= $signed(n4115);
  assign n4483 = n510[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4484 = n4481 ? 4'b0000 : n4483;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4486 = $signed(32'b00000000000000000000000000000101) >= $signed(n4115);
  assign n4488 = n510[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4489 = n4486 ? 4'b0000 : n4488;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4491 = $signed(32'b00000000000000000000000000000110) >= $signed(n4115);
  assign n4493 = n510[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4494 = n4491 ? 4'b0000 : n4493;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4496 = $signed(32'b00000000000000000000000000000111) >= $signed(n4115);
  assign n4498 = n510[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4499 = n4496 ? 4'b0000 : n4498;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4501 = $signed(32'b00000000000000000000000000001000) >= $signed(n4115);
  assign n4503 = n510[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4504 = n4501 ? 4'b0000 : n4503;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4506 = $signed(32'b00000000000000000000000000001001) >= $signed(n4115);
  assign n4508 = n510[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4509 = n4506 ? 4'b0000 : n4508;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4511 = $signed(32'b00000000000000000000000000001010) >= $signed(n4115);
  assign n4513 = n510[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4514 = n4511 ? 4'b0000 : n4513;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4516 = $signed(32'b00000000000000000000000000001011) >= $signed(n4115);
  assign n4518 = n510[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4519 = n4516 ? 4'b0000 : n4518;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4521 = $signed(32'b00000000000000000000000000001100) >= $signed(n4115);
  assign n4523 = n510[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4524 = n4521 ? 4'b0000 : n4523;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4526 = $signed(32'b00000000000000000000000000001101) >= $signed(n4115);
  assign n4528 = n510[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4529 = n4526 ? 4'b0000 : n4528;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4531 = $signed(32'b00000000000000000000000000001110) >= $signed(n4115);
  assign n4533 = n510[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4534 = n4531 ? 4'b0000 : n4533;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4536 = $signed(32'b00000000000000000000000000001111) >= $signed(n4115);
  assign n4538 = n510[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4539 = n4536 ? 4'b0000 : n4538;
  /* mc68881_packed_decimal_unit.vhd:795:22  */
  assign n4541 = $signed(32'b00000000000000000000000000010000) >= $signed(n4115);
  assign n4543 = n510[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:795:15  */
  assign n4544 = n4541 ? 4'b0000 : n4543;
  /* mc68881_packed_decimal_unit.vhd:800:22  */
  assign n4546 = n4304 == 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:803:45  */
  assign n4548 = n4115 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:803:33  */
  assign n4549 = n4548[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:800:13  */
  assign n4552 = n4546 ? 5'b01101 : 5'b01110;
  /* mc68881_packed_decimal_unit.vhd:767:11  */
  assign n4554 = n4561 ? 1'b1 : n516;
  /* mc68881_packed_decimal_unit.vhd:767:11  */
  assign n4555 = n4562 ? n4549 : n517;
  /* mc68881_packed_decimal_unit.vhd:767:11  */
  assign n4557 = n4117 ? n4552 : 5'b01110;
  assign n4558 = {n4464, n4469, n4474, n4479, n4484, n4489, n4494, n4499, n4504, n4509, n4514, n4519, n4524, n4529, n4534, n4539, n4544};
  /* mc68881_packed_decimal_unit.vhd:767:11  */
  assign n4559 = n4117 ? n4558 : n510;
  /* mc68881_packed_decimal_unit.vhd:767:11  */
  assign n4560 = n4117 ? n4459 : inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:767:11  */
  assign n4561 = n4546 & n4117;
  /* mc68881_packed_decimal_unit.vhd:767:11  */
  assign n4562 = n4546 & n4117;
  /* mc68881_packed_decimal_unit.vhd:764:9  */
  assign n4567 = state_reg == 5'b01100;
  /* mc68881_packed_decimal_unit.vhd:815:27  */
  assign n4569 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:815:43  */
  assign n4572 = {28'b0, n7493};  //  uext
  /* mc68881_packed_decimal_unit.vhd:815:43  */
  assign n4574 = n4572 == 32'b00000000000000000000000000001001;
  /* mc68881_packed_decimal_unit.vhd:816:26  */
  assign n4576 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:817:33  */
  assign n4580 = {27'b0, kround_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:817:33  */
  assign n4582 = n4580 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:821:40  */
  assign n4584 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:821:40  */
  assign n4586 = n4584 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:821:30  */
  assign n4587 = n4586[14:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:825:50  */
  assign n4588 = {27'b0, kround_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:825:50  */
  assign n4590 = n4588 - 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:825:35  */
  assign n4591 = n4590[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:817:15  */
  assign n4593 = n4582 ? 5'b01110 : n507;
  /* mc68881_packed_decimal_unit.vhd:814:11  */
  assign n4594 = n4623 ? n4587 : n508;
  assign n4595 = n7572[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:817:15  */
  assign n4596 = n4582 ? 4'b0001 : n4595;
  assign n4597 = n7572[63:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:817:15  */
  assign n4599 = n4582 ? 1'b0 : n516;
  /* mc68881_packed_decimal_unit.vhd:817:15  */
  assign n4600 = n4582 ? n517 : n4591;
  /* mc68881_packed_decimal_unit.vhd:828:26  */
  assign n4602 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:828:56  */
  assign n4605 = 5'b10000 - kround_idx_reg;
  /* mc68881_packed_decimal_unit.vhd:828:72  */
  assign n4608 = {28'b0, n7575};  //  uext
  /* mc68881_packed_decimal_unit.vhd:828:72  */
  assign n4610 = n4608 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:828:45  */
  assign n4611 = n4610[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:815:13  */
  assign n4614 = n4574 ? n4593 : 5'b01110;
  /* mc68881_packed_decimal_unit.vhd:815:13  */
  assign n4615 = n4582 & n4574;
  assign n4616 = {n4596, n4597};
  /* mc68881_packed_decimal_unit.vhd:815:13  */
  assign n4617 = n4574 ? n4616 : n7654;
  /* mc68881_packed_decimal_unit.vhd:815:13  */
  assign n4619 = n4574 ? n4599 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:814:11  */
  assign n4620 = n4626 ? n4600 : n517;
  /* mc68881_packed_decimal_unit.vhd:814:11  */
  assign n4622 = kround_carry_reg ? n4614 : 5'b01110;
  /* mc68881_packed_decimal_unit.vhd:814:11  */
  assign n4623 = n4615 & kround_carry_reg;
  /* mc68881_packed_decimal_unit.vhd:814:11  */
  assign n4624 = kround_carry_reg ? n4617 : n510;
  /* mc68881_packed_decimal_unit.vhd:814:11  */
  assign n4625 = kround_carry_reg ? n4619 : n516;
  /* mc68881_packed_decimal_unit.vhd:814:11  */
  assign n4626 = n4574 & kround_carry_reg;
  /* mc68881_packed_decimal_unit.vhd:812:9  */
  assign n4628 = state_reg == 5'b01101;
  /* mc68881_packed_decimal_unit.vhd:839:24  */
  assign n4631 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:839:24  */
  assign n4633 = $signed(n4631) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:841:32  */
  assign n4635 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:841:32  */
  assign n4636 = -n4635;
  /* mc68881_packed_decimal_unit.vhd:841:31  */
  assign n4637 = n4636[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:841:13  */
  assign n4638 = n4637[13:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:844:13  */
  assign n4641 = exp10_reg[13:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:839:11  */
  assign n4642 = n4633 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:839:11  */
  assign n4644 = n4633 ? n4638 : n4641;
  /* mc68881_packed_decimal_unit.vhd:846:27  */
  assign n4645 = {18'b0, n4644};  //  uext
  /* mc68881_packed_decimal_unit.vhd:846:27  */
  assign n4647 = n4645 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:846:11  */
  assign n4648 = n4647[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:847:28  */
  assign n4649 = {18'b0, n4644};  //  uext
  /* mc68881_packed_decimal_unit.vhd:847:28  */
  assign n4651 = $signed(n4649) / $signed(32'b00000000000000000000000000001010); // sdiv
  /* mc68881_packed_decimal_unit.vhd:847:34  */
  assign n4653 = n4651 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:847:11  */
  assign n4654 = n4653[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:848:28  */
  assign n4655 = {18'b0, n4644};  //  uext
  /* mc68881_packed_decimal_unit.vhd:848:28  */
  assign n4657 = $signed(n4655) / $signed(32'b00000000000000000000000001100100); // sdiv
  /* mc68881_packed_decimal_unit.vhd:848:35  */
  assign n4659 = n4657 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:848:11  */
  assign n4660 = n4659[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:849:28  */
  assign n4661 = {18'b0, n4644};  //  uext
  /* mc68881_packed_decimal_unit.vhd:849:28  */
  assign n4663 = $signed(n4661) / $signed(32'b00000000000000000000001111101000); // sdiv
  /* mc68881_packed_decimal_unit.vhd:849:36  */
  assign n4665 = n4663 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:849:11  */
  assign n4666 = n4665[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4675 = {1'b0, n4660};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4677 = $signed(n4675) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4679 = ~n6589;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4680 = n4679 | n4677;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6934)
      $fatal(1, "assertion failure n4681");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4682 = {1'b0, n4660};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4684 = n4682 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4685 = n4684[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4686 = n4685[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4695 = {1'b0, n4654};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4697 = $signed(n4695) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4699 = ~n6591;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4700 = n4699 | n4697;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6936)
      $fatal(1, "assertion failure n4701");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4702 = {1'b0, n4654};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4704 = n4702 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4705 = n4704[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4706 = n4705[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4715 = {1'b0, n4648};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4717 = $signed(n4715) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4719 = ~n6593;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4720 = n4719 | n4717;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6938)
      $fatal(1, "assertion failure n4721");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4722 = {1'b0, n4648};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4724 = n4722 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4725 = n4724[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4726 = n4725[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4735 = {1'b0, n4666};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4737 = $signed(n4735) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4739 = ~n6595;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4740 = n4739 | n4737;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6940)
      $fatal(1, "assertion failure n4741");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4742 = {1'b0, n4666};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4744 = n4742 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4745 = n4744[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4746 = n4745[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:857:62  */
  assign n4752 = digits_reg[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:857:52  */
  assign n4753 = {27'b0, n4752};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4759 = {1'b0, n4753};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4761 = $signed(n4759) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4763 = ~n6597;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4764 = n4763 | n4761;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6942)
      $fatal(1, "assertion failure n4765");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4766 = {1'b0, n4753};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4768 = n4766 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4769 = n4768[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4770 = n4769[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4774 = digits_reg[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4775 = {27'b0, n4774};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4781 = {1'b0, n4775};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4783 = $signed(n4781) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4785 = ~n6599;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4786 = n4785 | n4783;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6944)
      $fatal(1, "assertion failure n4787");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4788 = {1'b0, n4775};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4790 = n4788 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4791 = n4790[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4792 = n4791[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4796 = digits_reg[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4797 = {27'b0, n4796};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4803 = {1'b0, n4797};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4805 = $signed(n4803) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4807 = ~n6601;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4808 = n4807 | n4805;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6946)
      $fatal(1, "assertion failure n4809");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4810 = {1'b0, n4797};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4812 = n4810 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4813 = n4812[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4814 = n4813[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4818 = digits_reg[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4819 = {27'b0, n4818};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4825 = {1'b0, n4819};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4827 = $signed(n4825) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4829 = ~n6603;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4830 = n4829 | n4827;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6948)
      $fatal(1, "assertion failure n4831");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4832 = {1'b0, n4819};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4834 = n4832 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4835 = n4834[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4836 = n4835[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4840 = digits_reg[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4841 = {27'b0, n4840};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4847 = {1'b0, n4841};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4849 = $signed(n4847) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4851 = ~n6605;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4852 = n4851 | n4849;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6950)
      $fatal(1, "assertion failure n4853");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4854 = {1'b0, n4841};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4856 = n4854 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4857 = n4856[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4858 = n4857[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4862 = digits_reg[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4863 = {27'b0, n4862};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4869 = {1'b0, n4863};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4871 = $signed(n4869) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4873 = ~n6607;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4874 = n4873 | n4871;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6952)
      $fatal(1, "assertion failure n4875");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4876 = {1'b0, n4863};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4878 = n4876 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4879 = n4878[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4880 = n4879[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4884 = digits_reg[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4885 = {27'b0, n4884};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4891 = {1'b0, n4885};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4893 = $signed(n4891) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4895 = ~n6609;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4896 = n4895 | n4893;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6954)
      $fatal(1, "assertion failure n4897");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4898 = {1'b0, n4885};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4900 = n4898 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4901 = n4900[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4902 = n4901[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4906 = digits_reg[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4907 = {27'b0, n4906};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4913 = {1'b0, n4907};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4915 = $signed(n4913) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4917 = ~n6611;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4918 = n4917 | n4915;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6956)
      $fatal(1, "assertion failure n4919");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4920 = {1'b0, n4907};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4922 = n4920 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4923 = n4922[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4924 = n4923[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4928 = digits_reg[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4929 = {27'b0, n4928};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4935 = {1'b0, n4929};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4937 = $signed(n4935) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4939 = ~n6613;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4940 = n4939 | n4937;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6958)
      $fatal(1, "assertion failure n4941");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4942 = {1'b0, n4929};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4944 = n4942 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4945 = n4944[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4946 = n4945[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4950 = digits_reg[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4951 = {27'b0, n4950};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4957 = {1'b0, n4951};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4959 = $signed(n4957) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4961 = ~n6615;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4962 = n4961 | n4959;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6960)
      $fatal(1, "assertion failure n4963");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4964 = {1'b0, n4951};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4966 = n4964 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4967 = n4966[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4968 = n4967[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4972 = digits_reg[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4973 = {27'b0, n4972};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4979 = {1'b0, n4973};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n4981 = $signed(n4979) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4983 = ~n6617;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n4984 = n4983 | n4981;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6962)
      $fatal(1, "assertion failure n4985");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4986 = {1'b0, n4973};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n4988 = n4986 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n4989 = n4988[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n4990 = n4989[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n4994 = digits_reg[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n4995 = {27'b0, n4994};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5001 = {1'b0, n4995};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5003 = $signed(n5001) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5005 = ~n6619;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5006 = n5005 | n5003;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6964)
      $fatal(1, "assertion failure n5007");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5008 = {1'b0, n4995};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5010 = n5008 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n5011 = n5010[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n5012 = n5011[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n5016 = digits_reg[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n5017 = {27'b0, n5016};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5023 = {1'b0, n5017};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5025 = $signed(n5023) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5027 = ~n6621;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5028 = n5027 | n5025;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6966)
      $fatal(1, "assertion failure n5029");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5030 = {1'b0, n5017};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5032 = n5030 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n5033 = n5032[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n5034 = n5033[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n5038 = digits_reg[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n5039 = {27'b0, n5038};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5045 = {1'b0, n5039};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5047 = $signed(n5045) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5049 = ~n6623;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5050 = n5049 | n5047;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6968)
      $fatal(1, "assertion failure n5051");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5052 = {1'b0, n5039};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5054 = n5052 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n5055 = n5054[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n5056 = n5055[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n5060 = digits_reg[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n5061 = {27'b0, n5060};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5067 = {1'b0, n5061};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5069 = $signed(n5067) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5071 = ~n6625;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5072 = n5071 | n5069;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6970)
      $fatal(1, "assertion failure n5073");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5074 = {1'b0, n5061};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5076 = n5074 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n5077 = n5076[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n5078 = n5077[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n5082 = digits_reg[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n5083 = {27'b0, n5082};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5089 = {1'b0, n5083};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5091 = $signed(n5089) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5093 = ~n6627;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5094 = n5093 | n5091;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6972)
      $fatal(1, "assertion failure n5095");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5096 = {1'b0, n5083};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5098 = n5096 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n5099 = n5098[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n5100 = n5099[3:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:859:80  */
  assign n5104 = digits_reg[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:859:70  */
  assign n5105 = {27'b0, n5104};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5111 = {1'b0, n5105};  //  uext
  /* mc68881_packed_decimal_unit.vhd:176:18  */
  assign n5113 = $signed(n5111) <= $signed(32'b00000000000000000000000000001001);
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5115 = ~n6629;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  assign n5116 = n5115 | n5113;
  /* mc68881_packed_decimal_unit.vhd:176:5  */
  always @*
    if (!n6974)
      $fatal(1, "assertion failure n5117");
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5118 = {1'b0, n5105};  //  uext
  /* mc68881_packed_decimal_unit.vhd:177:50  */
  assign n5120 = n5118 % 32'b00000000000000000000000000001010; // smod
  /* mc68881_packed_decimal_unit.vhd:177:44  */
  assign n5121 = n5120[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:177:32  */
  assign n5122 = n5121[3:0];  // trunc
  assign n5124 = {sign_reg, n4642, 2'b00, n4686, n4706, n4726, n4746, 8'b00000000, n4770, n4792, n4814, n4836, n4858, n4880, n4902, n4924, n4946, n4968, n4990, n5012, n5034, n5056, n5078, n5100, n5122};
  /* mc68881_packed_decimal_unit.vhd:836:9  */
  assign n5126 = state_reg == 5'b01110;
  /* mc68881_packed_decimal_unit.vhd:870:24  */
  assign n5128 = mant_u64_reg << 31'b0000000000000000000000000000011;
  /* mc68881_packed_decimal_unit.vhd:870:54  */
  assign n5130 = mant_u64_reg << 31'b0000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:870:52  */
  assign n5131 = n5128 + n5130;
  /* mc68881_packed_decimal_unit.vhd:871:47  */
  assign n5133 = 5'b10000 - idx_reg;
  /* mc68881_packed_decimal_unit.vhd:871:36  */
  assign n5136 = {27'b0, n7657};  //  uext
  /* mc68881_packed_decimal_unit.vhd:871:24  */
  assign n5137 = {33'b0, n5136};  //  uext
  /* mc68881_packed_decimal_unit.vhd:870:82  */
  assign n5138 = n5131 + n5137;
  /* mc68881_packed_decimal_unit.vhd:873:22  */
  assign n5139 = {27'b0, idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:873:22  */
  assign n5141 = n5139 == 32'b00000000000000000000000000010000;
  /* mc68881_packed_decimal_unit.vhd:876:32  */
  assign n5142 = {27'b0, idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:876:32  */
  assign n5144 = n5142 + 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:876:24  */
  assign n5145 = n5144[4:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:873:11  */
  assign n5147 = n5141 ? 5'b10000 : n507;
  /* mc68881_packed_decimal_unit.vhd:873:11  */
  assign n5148 = n5141 ? n512 : n5145;
  /* mc68881_packed_decimal_unit.vhd:869:9  */
  assign n5150 = state_reg == 5'b01111;
  /* mc68881_pkg.vhd:1663:14  */
  assign n5161 = mant_u64_reg == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:1663:5  */
  assign n5165 = n5161 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:1663:5  */
  assign n5169 = n5161 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:1663:5  */
  assign n5171 = n5161 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : 80'bX;
  /* mc68881_pkg.vhd:1667:5  */
  assign n5174 = n5165 ? 32'b00000000000000000000000000111111 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5177 = mant_u64_reg[63]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5179 = n5190 ? 32'b00000000000000000000000000111111 : n5174;
  /* mc68881_pkg.vhd:1671:9  */
  assign n5184 = n5165 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5186 = n5165 & n5177;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5188 = n5177 ? n5184 : 1'b1;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5190 = n5186 & n5165;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5192 = n5165 ? n5188 : 1'b1;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5194 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5195 = n5194 & n5192;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5196 = mant_u64_reg[62]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5198 = n5207 ? 32'b00000000000000000000000000111110 : n5179;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5202 = n5208 ? 1'b0 : n5192;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5204 = n5195 & n5196;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5205 = n5195 & n5196;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5207 = n5204 & n5195;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5208 = n5205 & n5195;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5209 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5210 = n5209 & n5202;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5211 = mant_u64_reg[61]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5213 = n5222 ? 32'b00000000000000000000000000111101 : n5198;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5217 = n5223 ? 1'b0 : n5202;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5219 = n5210 & n5211;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5220 = n5210 & n5211;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5222 = n5219 & n5210;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5223 = n5220 & n5210;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5224 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5225 = n5224 & n5217;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5226 = mant_u64_reg[60]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5228 = n5237 ? 32'b00000000000000000000000000111100 : n5213;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5232 = n5238 ? 1'b0 : n5217;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5234 = n5225 & n5226;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5235 = n5225 & n5226;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5237 = n5234 & n5225;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5238 = n5235 & n5225;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5239 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5240 = n5239 & n5232;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5241 = mant_u64_reg[59]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5243 = n5252 ? 32'b00000000000000000000000000111011 : n5228;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5247 = n5253 ? 1'b0 : n5232;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5249 = n5240 & n5241;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5250 = n5240 & n5241;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5252 = n5249 & n5240;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5253 = n5250 & n5240;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5254 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5255 = n5254 & n5247;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5256 = mant_u64_reg[58]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5258 = n5267 ? 32'b00000000000000000000000000111010 : n5243;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5262 = n5268 ? 1'b0 : n5247;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5264 = n5255 & n5256;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5265 = n5255 & n5256;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5267 = n5264 & n5255;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5268 = n5265 & n5255;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5269 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5270 = n5269 & n5262;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5271 = mant_u64_reg[57]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5273 = n5282 ? 32'b00000000000000000000000000111001 : n5258;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5277 = n5283 ? 1'b0 : n5262;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5279 = n5270 & n5271;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5280 = n5270 & n5271;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5282 = n5279 & n5270;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5283 = n5280 & n5270;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5284 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5285 = n5284 & n5277;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5286 = mant_u64_reg[56]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5288 = n5297 ? 32'b00000000000000000000000000111000 : n5273;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5292 = n5298 ? 1'b0 : n5277;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5294 = n5285 & n5286;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5295 = n5285 & n5286;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5297 = n5294 & n5285;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5298 = n5295 & n5285;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5299 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5300 = n5299 & n5292;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5301 = mant_u64_reg[55]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5303 = n5312 ? 32'b00000000000000000000000000110111 : n5288;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5307 = n5313 ? 1'b0 : n5292;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5309 = n5300 & n5301;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5310 = n5300 & n5301;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5312 = n5309 & n5300;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5313 = n5310 & n5300;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5314 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5315 = n5314 & n5307;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5316 = mant_u64_reg[54]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5318 = n5327 ? 32'b00000000000000000000000000110110 : n5303;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5322 = n5328 ? 1'b0 : n5307;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5324 = n5315 & n5316;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5325 = n5315 & n5316;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5327 = n5324 & n5315;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5328 = n5325 & n5315;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5329 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5330 = n5329 & n5322;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5331 = mant_u64_reg[53]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5333 = n5342 ? 32'b00000000000000000000000000110101 : n5318;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5337 = n5343 ? 1'b0 : n5322;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5339 = n5330 & n5331;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5340 = n5330 & n5331;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5342 = n5339 & n5330;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5343 = n5340 & n5330;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5344 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5345 = n5344 & n5337;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5346 = mant_u64_reg[52]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5348 = n5357 ? 32'b00000000000000000000000000110100 : n5333;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5352 = n5358 ? 1'b0 : n5337;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5354 = n5345 & n5346;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5355 = n5345 & n5346;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5357 = n5354 & n5345;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5358 = n5355 & n5345;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5359 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5360 = n5359 & n5352;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5361 = mant_u64_reg[51]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5363 = n5372 ? 32'b00000000000000000000000000110011 : n5348;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5367 = n5373 ? 1'b0 : n5352;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5369 = n5360 & n5361;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5370 = n5360 & n5361;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5372 = n5369 & n5360;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5373 = n5370 & n5360;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5374 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5375 = n5374 & n5367;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5376 = mant_u64_reg[50]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5378 = n5387 ? 32'b00000000000000000000000000110010 : n5363;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5382 = n5388 ? 1'b0 : n5367;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5384 = n5375 & n5376;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5385 = n5375 & n5376;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5387 = n5384 & n5375;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5388 = n5385 & n5375;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5389 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5390 = n5389 & n5382;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5391 = mant_u64_reg[49]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5393 = n5402 ? 32'b00000000000000000000000000110001 : n5378;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5397 = n5403 ? 1'b0 : n5382;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5399 = n5390 & n5391;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5400 = n5390 & n5391;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5402 = n5399 & n5390;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5403 = n5400 & n5390;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5404 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5405 = n5404 & n5397;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5406 = mant_u64_reg[48]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5408 = n5417 ? 32'b00000000000000000000000000110000 : n5393;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5412 = n5418 ? 1'b0 : n5397;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5414 = n5405 & n5406;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5415 = n5405 & n5406;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5417 = n5414 & n5405;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5418 = n5415 & n5405;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5419 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5420 = n5419 & n5412;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5421 = mant_u64_reg[47]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5423 = n5432 ? 32'b00000000000000000000000000101111 : n5408;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5427 = n5433 ? 1'b0 : n5412;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5429 = n5420 & n5421;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5430 = n5420 & n5421;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5432 = n5429 & n5420;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5433 = n5430 & n5420;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5434 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5435 = n5434 & n5427;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5436 = mant_u64_reg[46]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5438 = n5447 ? 32'b00000000000000000000000000101110 : n5423;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5442 = n5448 ? 1'b0 : n5427;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5444 = n5435 & n5436;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5445 = n5435 & n5436;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5447 = n5444 & n5435;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5448 = n5445 & n5435;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5449 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5450 = n5449 & n5442;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5451 = mant_u64_reg[45]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5453 = n5462 ? 32'b00000000000000000000000000101101 : n5438;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5457 = n5463 ? 1'b0 : n5442;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5459 = n5450 & n5451;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5460 = n5450 & n5451;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5462 = n5459 & n5450;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5463 = n5460 & n5450;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5464 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5465 = n5464 & n5457;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5466 = mant_u64_reg[44]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5468 = n5477 ? 32'b00000000000000000000000000101100 : n5453;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5472 = n5478 ? 1'b0 : n5457;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5474 = n5465 & n5466;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5475 = n5465 & n5466;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5477 = n5474 & n5465;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5478 = n5475 & n5465;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5479 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5480 = n5479 & n5472;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5481 = mant_u64_reg[43]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5483 = n5492 ? 32'b00000000000000000000000000101011 : n5468;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5487 = n5493 ? 1'b0 : n5472;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5489 = n5480 & n5481;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5490 = n5480 & n5481;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5492 = n5489 & n5480;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5493 = n5490 & n5480;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5494 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5495 = n5494 & n5487;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5496 = mant_u64_reg[42]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5498 = n5507 ? 32'b00000000000000000000000000101010 : n5483;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5502 = n5508 ? 1'b0 : n5487;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5504 = n5495 & n5496;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5505 = n5495 & n5496;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5507 = n5504 & n5495;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5508 = n5505 & n5495;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5509 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5510 = n5509 & n5502;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5511 = mant_u64_reg[41]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5513 = n5522 ? 32'b00000000000000000000000000101001 : n5498;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5517 = n5523 ? 1'b0 : n5502;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5519 = n5510 & n5511;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5520 = n5510 & n5511;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5522 = n5519 & n5510;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5523 = n5520 & n5510;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5524 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5525 = n5524 & n5517;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5526 = mant_u64_reg[40]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5528 = n5537 ? 32'b00000000000000000000000000101000 : n5513;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5532 = n5538 ? 1'b0 : n5517;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5534 = n5525 & n5526;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5535 = n5525 & n5526;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5537 = n5534 & n5525;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5538 = n5535 & n5525;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5539 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5540 = n5539 & n5532;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5541 = mant_u64_reg[39]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5543 = n5552 ? 32'b00000000000000000000000000100111 : n5528;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5547 = n5553 ? 1'b0 : n5532;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5549 = n5540 & n5541;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5550 = n5540 & n5541;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5552 = n5549 & n5540;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5553 = n5550 & n5540;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5554 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5555 = n5554 & n5547;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5556 = mant_u64_reg[38]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5558 = n5567 ? 32'b00000000000000000000000000100110 : n5543;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5562 = n5568 ? 1'b0 : n5547;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5564 = n5555 & n5556;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5565 = n5555 & n5556;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5567 = n5564 & n5555;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5568 = n5565 & n5555;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5569 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5570 = n5569 & n5562;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5571 = mant_u64_reg[37]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5573 = n5582 ? 32'b00000000000000000000000000100101 : n5558;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5577 = n5583 ? 1'b0 : n5562;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5579 = n5570 & n5571;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5580 = n5570 & n5571;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5582 = n5579 & n5570;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5583 = n5580 & n5570;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5584 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5585 = n5584 & n5577;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5586 = mant_u64_reg[36]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5588 = n5597 ? 32'b00000000000000000000000000100100 : n5573;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5592 = n5598 ? 1'b0 : n5577;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5594 = n5585 & n5586;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5595 = n5585 & n5586;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5597 = n5594 & n5585;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5598 = n5595 & n5585;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5599 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5600 = n5599 & n5592;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5601 = mant_u64_reg[35]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5603 = n5612 ? 32'b00000000000000000000000000100011 : n5588;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5607 = n5613 ? 1'b0 : n5592;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5609 = n5600 & n5601;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5610 = n5600 & n5601;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5612 = n5609 & n5600;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5613 = n5610 & n5600;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5614 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5615 = n5614 & n5607;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5616 = mant_u64_reg[34]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5618 = n5627 ? 32'b00000000000000000000000000100010 : n5603;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5622 = n5628 ? 1'b0 : n5607;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5624 = n5615 & n5616;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5625 = n5615 & n5616;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5627 = n5624 & n5615;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5628 = n5625 & n5615;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5629 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5630 = n5629 & n5622;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5631 = mant_u64_reg[33]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5633 = n5642 ? 32'b00000000000000000000000000100001 : n5618;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5637 = n5643 ? 1'b0 : n5622;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5639 = n5630 & n5631;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5640 = n5630 & n5631;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5642 = n5639 & n5630;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5643 = n5640 & n5630;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5644 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5645 = n5644 & n5637;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5646 = mant_u64_reg[32]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5648 = n5657 ? 32'b00000000000000000000000000100000 : n5633;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5652 = n5658 ? 1'b0 : n5637;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5654 = n5645 & n5646;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5655 = n5645 & n5646;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5657 = n5654 & n5645;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5658 = n5655 & n5645;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5659 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5660 = n5659 & n5652;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5661 = mant_u64_reg[31]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5663 = n5672 ? 32'b00000000000000000000000000011111 : n5648;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5667 = n5673 ? 1'b0 : n5652;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5669 = n5660 & n5661;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5670 = n5660 & n5661;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5672 = n5669 & n5660;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5673 = n5670 & n5660;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5674 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5675 = n5674 & n5667;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5676 = mant_u64_reg[30]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5678 = n5687 ? 32'b00000000000000000000000000011110 : n5663;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5682 = n5688 ? 1'b0 : n5667;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5684 = n5675 & n5676;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5685 = n5675 & n5676;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5687 = n5684 & n5675;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5688 = n5685 & n5675;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5689 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5690 = n5689 & n5682;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5691 = mant_u64_reg[29]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5693 = n5702 ? 32'b00000000000000000000000000011101 : n5678;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5697 = n5703 ? 1'b0 : n5682;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5699 = n5690 & n5691;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5700 = n5690 & n5691;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5702 = n5699 & n5690;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5703 = n5700 & n5690;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5704 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5705 = n5704 & n5697;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5706 = mant_u64_reg[28]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5708 = n5717 ? 32'b00000000000000000000000000011100 : n5693;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5712 = n5718 ? 1'b0 : n5697;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5714 = n5705 & n5706;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5715 = n5705 & n5706;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5717 = n5714 & n5705;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5718 = n5715 & n5705;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5719 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5720 = n5719 & n5712;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5721 = mant_u64_reg[27]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5723 = n5732 ? 32'b00000000000000000000000000011011 : n5708;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5727 = n5733 ? 1'b0 : n5712;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5729 = n5720 & n5721;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5730 = n5720 & n5721;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5732 = n5729 & n5720;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5733 = n5730 & n5720;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5734 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5735 = n5734 & n5727;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5736 = mant_u64_reg[26]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5738 = n5747 ? 32'b00000000000000000000000000011010 : n5723;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5742 = n5748 ? 1'b0 : n5727;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5744 = n5735 & n5736;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5745 = n5735 & n5736;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5747 = n5744 & n5735;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5748 = n5745 & n5735;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5749 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5750 = n5749 & n5742;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5751 = mant_u64_reg[25]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5753 = n5762 ? 32'b00000000000000000000000000011001 : n5738;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5757 = n5763 ? 1'b0 : n5742;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5759 = n5750 & n5751;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5760 = n5750 & n5751;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5762 = n5759 & n5750;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5763 = n5760 & n5750;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5764 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5765 = n5764 & n5757;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5766 = mant_u64_reg[24]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5768 = n5777 ? 32'b00000000000000000000000000011000 : n5753;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5772 = n5778 ? 1'b0 : n5757;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5774 = n5765 & n5766;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5775 = n5765 & n5766;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5777 = n5774 & n5765;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5778 = n5775 & n5765;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5779 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5780 = n5779 & n5772;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5781 = mant_u64_reg[23]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5783 = n5792 ? 32'b00000000000000000000000000010111 : n5768;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5787 = n5793 ? 1'b0 : n5772;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5789 = n5780 & n5781;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5790 = n5780 & n5781;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5792 = n5789 & n5780;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5793 = n5790 & n5780;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5794 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5795 = n5794 & n5787;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5796 = mant_u64_reg[22]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5798 = n5807 ? 32'b00000000000000000000000000010110 : n5783;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5802 = n5808 ? 1'b0 : n5787;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5804 = n5795 & n5796;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5805 = n5795 & n5796;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5807 = n5804 & n5795;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5808 = n5805 & n5795;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5809 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5810 = n5809 & n5802;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5811 = mant_u64_reg[21]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5813 = n5822 ? 32'b00000000000000000000000000010101 : n5798;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5817 = n5823 ? 1'b0 : n5802;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5819 = n5810 & n5811;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5820 = n5810 & n5811;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5822 = n5819 & n5810;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5823 = n5820 & n5810;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5824 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5825 = n5824 & n5817;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5826 = mant_u64_reg[20]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5828 = n5837 ? 32'b00000000000000000000000000010100 : n5813;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5832 = n5838 ? 1'b0 : n5817;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5834 = n5825 & n5826;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5835 = n5825 & n5826;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5837 = n5834 & n5825;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5838 = n5835 & n5825;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5839 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5840 = n5839 & n5832;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5841 = mant_u64_reg[19]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5843 = n5852 ? 32'b00000000000000000000000000010011 : n5828;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5847 = n5853 ? 1'b0 : n5832;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5849 = n5840 & n5841;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5850 = n5840 & n5841;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5852 = n5849 & n5840;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5853 = n5850 & n5840;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5854 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5855 = n5854 & n5847;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5856 = mant_u64_reg[18]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5858 = n5867 ? 32'b00000000000000000000000000010010 : n5843;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5862 = n5868 ? 1'b0 : n5847;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5864 = n5855 & n5856;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5865 = n5855 & n5856;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5867 = n5864 & n5855;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5868 = n5865 & n5855;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5869 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5870 = n5869 & n5862;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5871 = mant_u64_reg[17]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5873 = n5882 ? 32'b00000000000000000000000000010001 : n5858;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5877 = n5883 ? 1'b0 : n5862;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5879 = n5870 & n5871;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5880 = n5870 & n5871;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5882 = n5879 & n5870;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5883 = n5880 & n5870;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5884 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5885 = n5884 & n5877;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5886 = mant_u64_reg[16]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5888 = n5897 ? 32'b00000000000000000000000000010000 : n5873;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5892 = n5898 ? 1'b0 : n5877;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5894 = n5885 & n5886;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5895 = n5885 & n5886;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5897 = n5894 & n5885;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5898 = n5895 & n5885;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5899 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5900 = n5899 & n5892;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5901 = mant_u64_reg[15]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5903 = n5912 ? 32'b00000000000000000000000000001111 : n5888;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5907 = n5913 ? 1'b0 : n5892;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5909 = n5900 & n5901;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5910 = n5900 & n5901;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5912 = n5909 & n5900;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5913 = n5910 & n5900;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5914 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5915 = n5914 & n5907;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5916 = mant_u64_reg[14]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5918 = n5927 ? 32'b00000000000000000000000000001110 : n5903;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5922 = n5928 ? 1'b0 : n5907;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5924 = n5915 & n5916;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5925 = n5915 & n5916;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5927 = n5924 & n5915;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5928 = n5925 & n5915;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5929 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5930 = n5929 & n5922;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5931 = mant_u64_reg[13]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5933 = n5942 ? 32'b00000000000000000000000000001101 : n5918;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5937 = n5943 ? 1'b0 : n5922;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5939 = n5930 & n5931;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5940 = n5930 & n5931;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5942 = n5939 & n5930;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5943 = n5940 & n5930;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5944 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5945 = n5944 & n5937;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5946 = mant_u64_reg[12]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5948 = n5957 ? 32'b00000000000000000000000000001100 : n5933;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5952 = n5958 ? 1'b0 : n5937;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5954 = n5945 & n5946;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5955 = n5945 & n5946;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5957 = n5954 & n5945;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5958 = n5955 & n5945;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5959 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5960 = n5959 & n5952;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5961 = mant_u64_reg[11]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5963 = n5972 ? 32'b00000000000000000000000000001011 : n5948;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5967 = n5973 ? 1'b0 : n5952;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5969 = n5960 & n5961;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5970 = n5960 & n5961;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5972 = n5969 & n5960;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5973 = n5970 & n5960;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5974 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5975 = n5974 & n5967;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5976 = mant_u64_reg[10]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5978 = n5987 ? 32'b00000000000000000000000000001010 : n5963;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5982 = n5988 ? 1'b0 : n5967;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5984 = n5975 & n5976;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5985 = n5975 & n5976;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5987 = n5984 & n5975;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5988 = n5985 & n5975;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5989 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n5990 = n5989 & n5982;
  /* mc68881_pkg.vhd:1669:15  */
  assign n5991 = mant_u64_reg[9]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n5993 = n6002 ? 32'b00000000000000000000000000001001 : n5978;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5997 = n6003 ? 1'b0 : n5982;
  /* mc68881_pkg.vhd:1669:7  */
  assign n5999 = n5990 & n5991;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6000 = n5990 & n5991;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6002 = n5999 & n5990;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6003 = n6000 & n5990;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6004 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6005 = n6004 & n5997;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6006 = mant_u64_reg[8]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6008 = n6017 ? 32'b00000000000000000000000000001000 : n5993;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6012 = n6018 ? 1'b0 : n5997;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6014 = n6005 & n6006;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6015 = n6005 & n6006;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6017 = n6014 & n6005;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6018 = n6015 & n6005;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6019 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6020 = n6019 & n6012;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6021 = mant_u64_reg[7]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6023 = n6032 ? 32'b00000000000000000000000000000111 : n6008;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6027 = n6033 ? 1'b0 : n6012;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6029 = n6020 & n6021;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6030 = n6020 & n6021;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6032 = n6029 & n6020;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6033 = n6030 & n6020;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6034 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6035 = n6034 & n6027;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6036 = mant_u64_reg[6]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6038 = n6047 ? 32'b00000000000000000000000000000110 : n6023;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6042 = n6048 ? 1'b0 : n6027;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6044 = n6035 & n6036;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6045 = n6035 & n6036;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6047 = n6044 & n6035;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6048 = n6045 & n6035;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6049 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6050 = n6049 & n6042;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6051 = mant_u64_reg[5]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6053 = n6062 ? 32'b00000000000000000000000000000101 : n6038;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6057 = n6063 ? 1'b0 : n6042;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6059 = n6050 & n6051;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6060 = n6050 & n6051;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6062 = n6059 & n6050;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6063 = n6060 & n6050;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6064 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6065 = n6064 & n6057;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6066 = mant_u64_reg[4]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6068 = n6077 ? 32'b00000000000000000000000000000100 : n6053;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6072 = n6078 ? 1'b0 : n6057;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6074 = n6065 & n6066;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6075 = n6065 & n6066;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6077 = n6074 & n6065;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6078 = n6075 & n6065;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6079 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6080 = n6079 & n6072;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6081 = mant_u64_reg[3]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6083 = n6092 ? 32'b00000000000000000000000000000011 : n6068;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6087 = n6093 ? 1'b0 : n6072;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6089 = n6080 & n6081;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6090 = n6080 & n6081;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6092 = n6089 & n6080;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6093 = n6090 & n6080;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6094 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6095 = n6094 & n6087;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6096 = mant_u64_reg[2]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6098 = n6107 ? 32'b00000000000000000000000000000010 : n6083;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6102 = n6108 ? 1'b0 : n6087;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6104 = n6095 & n6096;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6105 = n6095 & n6096;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6107 = n6104 & n6095;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6108 = n6105 & n6095;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6109 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6110 = n6109 & n6102;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6111 = mant_u64_reg[1]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6113 = n6122 ? 32'b00000000000000000000000000000001 : n6098;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6117 = n6123 ? 1'b0 : n6102;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6119 = n6110 & n6111;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6120 = n6110 & n6111;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6122 = n6119 & n6110;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6123 = n6120 & n6110;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6124 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6125 = n6124 & n6117;
  /* mc68881_pkg.vhd:1669:15  */
  assign n6126 = mant_u64_reg[0]; // extract
  /* mc68881_pkg.vhd:1669:7  */
  assign n6128 = n6137 ? 32'b00000000000000000000000000000000 : n6113;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6134 = n6125 & n6126;
  /* mc68881_pkg.vhd:1669:7  */
  assign n6137 = n6134 & n6125;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6141 = n5165 & n5169;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6142 = n5165 ? n6141 : n5165;
  /* mc68881_pkg.vhd:1668:5  */
  assign n6143 = n5165 ? n6128 : n5174;
  /* mc68881_pkg.vhd:1675:36  */
  assign n6145 = 32'b00000000000000000011111111111111 + n6143;
  /* mc68881_pkg.vhd:1675:24  */
  assign n6146 = n6145[30:0];  // trunc
  /* mc68881_pkg.vhd:1675:12  */
  assign n6147 = n6146[14:0];  // trunc
  /* mc68881_pkg.vhd:1675:5  */
  assign n6149 = n6142 ? n6147 : 15'b000000000000000;
  /* mc68881_pkg.vhd:1676:62  */
  assign n6152 = 32'b00000000000000000000000000111111 - n6143;
  /* mc68881_pkg.vhd:1676:42  */
  assign n6153 = mant_u64_reg << n6152;
  /* mc68881_pkg.vhd:1676:42  */
  assign n6154 = -n6152;
  /* mc68881_pkg.vhd:1676:42  */
  assign n6155 = mant_u64_reg >> n6154;
  /* mc68881_pkg.vhd:1676:42  */
  assign n6156 = n6152[31]; // extract
  /* mc68881_pkg.vhd:1676:42  */
  assign n6157 = n6156 ? n6155 : n6153;
  /* mc68881_pkg.vhd:1676:5  */
  assign n6159 = n6142 ? n6157 : 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:1678:5  */
  assign n6163 = n6142 ? 1'b0 : 1'b0;
  assign n6166 = n6164[78:64]; // extract
  /* mc68881_pkg.vhd:1679:5  */
  assign n6167 = n6142 ? n6149 : n6166;
  assign n6168 = n6164[63:0]; // extract
  /* mc68881_pkg.vhd:1680:5  */
  assign n6169 = n6142 ? n6159 : n6168;
  assign n6170 = {n6163, n6167, n6169};
  /* mc68881_pkg.vhd:1681:5  */
  assign n6175 = n6142 ? n6170 : n5171;
  /* mc68881_packed_decimal_unit.vhd:881:40  */
  assign n6176 = {{17{exp10_reg[14]}}, exp10_reg}; // sext
  /* mc68881_packed_decimal_unit.vhd:881:40  */
  assign n6178 = n6176 - 32'b00000000000000000000000000010000;
  /* mc68881_packed_decimal_unit.vhd:882:30  */
  assign n6180 = n6178 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:885:32  */
  assign n6182 = $signed(n6178) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_packed_decimal_unit.vhd:887:44  */
  assign n6183 = -n6178;
  /* mc68881_packed_decimal_unit.vhd:887:43  */
  assign n6184 = n6183[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:887:36  */
  assign n6185 = n6184[13:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:890:43  */
  assign n6186 = n6178[30:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:890:36  */
  assign n6187 = n6186[13:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:885:13  */
  assign n6188 = n6182 ? n6185 : n6187;
  /* mc68881_packed_decimal_unit.vhd:885:13  */
  assign n6191 = n6182 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:882:11  */
  assign n6194 = n6180 ? 5'b10001 : 5'b00100;
  /* mc68881_packed_decimal_unit.vhd:882:11  */
  assign n6196 = n6180 ? scale_return_state_reg : 5'b10001;
  /* mc68881_packed_decimal_unit.vhd:882:11  */
  assign n6197 = n6180 ? n514 : n6188;
  /* mc68881_packed_decimal_unit.vhd:882:11  */
  assign n6198 = n6180 ? scale_use_neg_reg : n6191;
  /* mc68881_packed_decimal_unit.vhd:882:11  */
  assign n6200 = n6180 ? n515 : 4'b0000;
  /* mc68881_packed_decimal_unit.vhd:879:9  */
  assign n6202 = state_reg == 5'b10000;
  assign n6203 = work_fp_reg[78:0]; // extract
  assign n6204 = {sign_reg, n6203};
  /* mc68881_packed_decimal_unit.vhd:897:9  */
  assign n6206 = state_reg == 5'b10001;
  assign n6207 = {n6206, n6202, n5150, n5126, n4628, n4567, n4114, n3961, n3931, n3929, n3247, n3245, n2955, n2771, n2749, n2723, n2701, n1780};
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6212 = 5'b00000;
      18'b010000000000000000: n6212 = n6194;
      18'b001000000000000000: n6212 = n5147;
      18'b000100000000000000: n6212 = 5'b00000;
      18'b000010000000000000: n6212 = n4622;
      18'b000001000000000000: n6212 = n4557;
      18'b000000100000000000: n6212 = n4105;
      18'b000000010000000000: n6212 = n507;
      18'b000000001000000000: n6212 = n507;
      18'b000000000100000000: n6212 = n507;
      18'b000000000010000000: n6212 = n507;
      18'b000000000001000000: n6212 = n3240;
      18'b000000000000100000: n6212 = n2944;
      18'b000000000000010000: n6212 = n2757;
      18'b000000000000001000: n6212 = n2741;
      18'b000000000000000100: n6212 = 5'b00011;
      18'b000000000000000010: n6212 = n2680;
      18'b000000000000000001: n6212 = n1748;
      default: n6212 = 5'b00000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6213 = scale_return_state_reg;
      18'b010000000000000000: n6213 = n6196;
      18'b001000000000000000: n6213 = scale_return_state_reg;
      18'b000100000000000000: n6213 = scale_return_state_reg;
      18'b000010000000000000: n6213 = scale_return_state_reg;
      18'b000001000000000000: n6213 = scale_return_state_reg;
      18'b000000100000000000: n6213 = scale_return_state_reg;
      18'b000000010000000000: n6213 = scale_return_state_reg;
      18'b000000001000000000: n6213 = scale_return_state_reg;
      18'b000000000100000000: n6213 = scale_return_state_reg;
      18'b000000000010000000: n6213 = scale_return_state_reg;
      18'b000000000001000000: n6213 = scale_return_state_reg;
      18'b000000000000100000: n6213 = scale_return_state_reg;
      18'b000000000000010000: n6213 = scale_return_state_reg;
      18'b000000000000001000: n6213 = n2743;
      18'b000000000000000100: n6213 = scale_return_state_reg;
      18'b000000000000000010: n6213 = scale_return_state_reg;
      18'b000000000000000001: n6213 = scale_return_state_reg;
      default: n6213 = scale_return_state_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6214 = req_fp_reg;
      18'b010000000000000000: n6214 = req_fp_reg;
      18'b001000000000000000: n6214 = req_fp_reg;
      18'b000100000000000000: n6214 = req_fp_reg;
      18'b000010000000000000: n6214 = req_fp_reg;
      18'b000001000000000000: n6214 = req_fp_reg;
      18'b000000100000000000: n6214 = req_fp_reg;
      18'b000000010000000000: n6214 = req_fp_reg;
      18'b000000001000000000: n6214 = req_fp_reg;
      18'b000000000100000000: n6214 = req_fp_reg;
      18'b000000000010000000: n6214 = req_fp_reg;
      18'b000000000001000000: n6214 = req_fp_reg;
      18'b000000000000100000: n6214 = req_fp_reg;
      18'b000000000000010000: n6214 = req_fp_reg;
      18'b000000000000001000: n6214 = req_fp_reg;
      18'b000000000000000100: n6214 = req_fp_reg;
      18'b000000000000000010: n6214 = req_fp_reg;
      18'b000000000000000001: n6214 = n1749;
      default: n6214 = req_fp_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6215 = req_word_reg;
      18'b010000000000000000: n6215 = req_word_reg;
      18'b001000000000000000: n6215 = req_word_reg;
      18'b000100000000000000: n6215 = req_word_reg;
      18'b000010000000000000: n6215 = req_word_reg;
      18'b000001000000000000: n6215 = req_word_reg;
      18'b000000100000000000: n6215 = req_word_reg;
      18'b000000010000000000: n6215 = req_word_reg;
      18'b000000001000000000: n6215 = req_word_reg;
      18'b000000000100000000: n6215 = req_word_reg;
      18'b000000000010000000: n6215 = req_word_reg;
      18'b000000000001000000: n6215 = req_word_reg;
      18'b000000000000100000: n6215 = req_word_reg;
      18'b000000000000010000: n6215 = req_word_reg;
      18'b000000000000001000: n6215 = req_word_reg;
      18'b000000000000000100: n6215 = req_word_reg;
      18'b000000000000000010: n6215 = req_word_reg;
      18'b000000000000000001: n6215 = n1750;
      default: n6215 = req_word_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6216 = req_k_reg;
      18'b010000000000000000: n6216 = req_k_reg;
      18'b001000000000000000: n6216 = req_k_reg;
      18'b000100000000000000: n6216 = req_k_reg;
      18'b000010000000000000: n6216 = req_k_reg;
      18'b000001000000000000: n6216 = req_k_reg;
      18'b000000100000000000: n6216 = req_k_reg;
      18'b000000010000000000: n6216 = req_k_reg;
      18'b000000001000000000: n6216 = req_k_reg;
      18'b000000000100000000: n6216 = req_k_reg;
      18'b000000000010000000: n6216 = req_k_reg;
      18'b000000000001000000: n6216 = req_k_reg;
      18'b000000000000100000: n6216 = req_k_reg;
      18'b000000000000010000: n6216 = req_k_reg;
      18'b000000000000001000: n6216 = req_k_reg;
      18'b000000000000000100: n6216 = req_k_reg;
      18'b000000000000000010: n6216 = req_k_reg;
      18'b000000000000000001: n6216 = n1751;
      default: n6216 = req_k_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6217 = sign_reg;
      18'b010000000000000000: n6217 = sign_reg;
      18'b001000000000000000: n6217 = sign_reg;
      18'b000100000000000000: n6217 = sign_reg;
      18'b000010000000000000: n6217 = sign_reg;
      18'b000001000000000000: n6217 = sign_reg;
      18'b000000100000000000: n6217 = sign_reg;
      18'b000000010000000000: n6217 = sign_reg;
      18'b000000001000000000: n6217 = sign_reg;
      18'b000000000100000000: n6217 = sign_reg;
      18'b000000000010000000: n6217 = sign_reg;
      18'b000000000001000000: n6217 = sign_reg;
      18'b000000000000100000: n6217 = sign_reg;
      18'b000000000000010000: n6217 = sign_reg;
      18'b000000000000001000: n6217 = sign_reg;
      18'b000000000000000100: n6217 = sign_reg;
      18'b000000000000000010: n6217 = sign_reg;
      18'b000000000000000001: n6217 = n1752;
      default: n6217 = sign_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6218 = n508;
      18'b010000000000000000: n6218 = n508;
      18'b001000000000000000: n6218 = n508;
      18'b000100000000000000: n6218 = n508;
      18'b000010000000000000: n6218 = n4594;
      18'b000001000000000000: n6218 = n508;
      18'b000000100000000000: n6218 = n4036;
      18'b000000010000000000: n6218 = n508;
      18'b000000001000000000: n6218 = n508;
      18'b000000000100000000: n6218 = n508;
      18'b000000000010000000: n6218 = n508;
      18'b000000000001000000: n6218 = n508;
      18'b000000000000100000: n6218 = n508;
      18'b000000000000010000: n6218 = n508;
      18'b000000000000001000: n6218 = n508;
      18'b000000000000000100: n6218 = n2721;
      18'b000000000000000010: n6218 = n508;
      18'b000000000000000001: n6218 = n1753;
      default: n6218 = n508;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6219 = bin_exp_reg;
      18'b010000000000000000: n6219 = bin_exp_reg;
      18'b001000000000000000: n6219 = bin_exp_reg;
      18'b000100000000000000: n6219 = bin_exp_reg;
      18'b000010000000000000: n6219 = bin_exp_reg;
      18'b000001000000000000: n6219 = bin_exp_reg;
      18'b000000100000000000: n6219 = bin_exp_reg;
      18'b000000010000000000: n6219 = bin_exp_reg;
      18'b000000001000000000: n6219 = bin_exp_reg;
      18'b000000000100000000: n6219 = bin_exp_reg;
      18'b000000000010000000: n6219 = bin_exp_reg;
      18'b000000000001000000: n6219 = bin_exp_reg;
      18'b000000000000100000: n6219 = bin_exp_reg;
      18'b000000000000010000: n6219 = bin_exp_reg;
      18'b000000000000001000: n6219 = bin_exp_reg;
      18'b000000000000000100: n6219 = bin_exp_reg;
      18'b000000000000000010: n6219 = n2681;
      18'b000000000000000001: n6219 = bin_exp_reg;
      default: n6219 = bin_exp_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6220 = n509;
      18'b010000000000000000: n6220 = n6175;
      18'b001000000000000000: n6220 = n509;
      18'b000100000000000000: n6220 = n509;
      18'b000010000000000000: n6220 = n509;
      18'b000001000000000000: n6220 = n509;
      18'b000000100000000000: n6220 = n509;
      18'b000000010000000000: n6220 = n509;
      18'b000000001000000000: n6220 = n509;
      18'b000000000100000000: n6220 = n509;
      18'b000000000010000000: n6220 = n509;
      18'b000000000001000000: n6220 = n509;
      18'b000000000000100000: n6220 = n509;
      18'b000000000000010000: n6220 = n509;
      18'b000000000000001000: n6220 = n509;
      18'b000000000000000100: n6220 = n509;
      18'b000000000000000010: n6220 = n2682;
      18'b000000000000000001: n6220 = n509;
      default: n6220 = n509;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6221 = n510;
      18'b010000000000000000: n6221 = n510;
      18'b001000000000000000: n6221 = n510;
      18'b000100000000000000: n6221 = n510;
      18'b000010000000000000: n6221 = n4624;
      18'b000001000000000000: n6221 = n4559;
      18'b000000100000000000: n6221 = n4108;
      18'b000000010000000000: n6221 = n510;
      18'b000000001000000000: n6221 = n510;
      18'b000000000100000000: n6221 = n510;
      18'b000000000010000000: n6221 = n510;
      18'b000000000001000000: n6221 = n510;
      18'b000000000000100000: n6221 = n510;
      18'b000000000000010000: n6221 = n510;
      18'b000000000000001000: n6221 = n510;
      18'b000000000000000100: n6221 = n510;
      18'b000000000000000010: n6221 = n510;
      18'b000000000000000001: n6221 = n1754;
      default: n6221 = n510;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6222 = n511;
      18'b010000000000000000: n6222 = n511;
      18'b001000000000000000: n6222 = n511;
      18'b000100000000000000: n6222 = n511;
      18'b000010000000000000: n6222 = n511;
      18'b000001000000000000: n6222 = n511;
      18'b000000100000000000: n6222 = n511;
      18'b000000010000000000: n6222 = n511;
      18'b000000001000000000: n6222 = n511;
      18'b000000000100000000: n6222 = n511;
      18'b000000000010000000: n6222 = n511;
      18'b000000000001000000: n6222 = n511;
      18'b000000000000100000: n6222 = n511;
      18'b000000000000010000: n6222 = n511;
      18'b000000000000001000: n6222 = n511;
      18'b000000000000000100: n6222 = n511;
      18'b000000000000000010: n6222 = n511;
      18'b000000000000000001: n6222 = n1756;
      default: n6222 = n511;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6223 = n512;
      18'b010000000000000000: n6223 = n512;
      18'b001000000000000000: n6223 = n5148;
      18'b000100000000000000: n6223 = n512;
      18'b000010000000000000: n6223 = n512;
      18'b000001000000000000: n6223 = n512;
      18'b000000100000000000: n6223 = n512;
      18'b000000010000000000: n6223 = n512;
      18'b000000001000000000: n6223 = n512;
      18'b000000000100000000: n6223 = n512;
      18'b000000000010000000: n6223 = n512;
      18'b000000000001000000: n6223 = n3242;
      18'b000000000000100000: n6223 = n512;
      18'b000000000000010000: n6223 = n512;
      18'b000000000000001000: n6223 = n512;
      18'b000000000000000100: n6223 = n512;
      18'b000000000000000010: n6223 = n512;
      18'b000000000000000001: n6223 = n1757;
      default: n6223 = n512;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6224 = tune_iter_reg;
      18'b010000000000000000: n6224 = tune_iter_reg;
      18'b001000000000000000: n6224 = tune_iter_reg;
      18'b000100000000000000: n6224 = tune_iter_reg;
      18'b000010000000000000: n6224 = tune_iter_reg;
      18'b000001000000000000: n6224 = tune_iter_reg;
      18'b000000100000000000: n6224 = tune_iter_reg;
      18'b000000010000000000: n6224 = tune_iter_reg;
      18'b000000001000000000: n6224 = tune_iter_reg;
      18'b000000000100000000: n6224 = tune_iter_reg;
      18'b000000000010000000: n6224 = tune_iter_reg;
      18'b000000000001000000: n6224 = n3243;
      18'b000000000000100000: n6224 = tune_iter_reg;
      18'b000000000000010000: n6224 = tune_iter_reg;
      18'b000000000000001000: n6224 = tune_iter_reg;
      18'b000000000000000100: n6224 = tune_iter_reg;
      18'b000000000000000010: n6224 = tune_iter_reg;
      18'b000000000000000001: n6224 = n1759;
      default: n6224 = tune_iter_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6225 = n513;
      18'b010000000000000000: n6225 = n513;
      18'b001000000000000000: n6225 = n513;
      18'b000100000000000000: n6225 = n513;
      18'b000010000000000000: n6225 = n513;
      18'b000001000000000000: n6225 = n513;
      18'b000000100000000000: n6225 = n4109;
      18'b000000010000000000: n6225 = n513;
      18'b000000001000000000: n6225 = n513;
      18'b000000000100000000: n6225 = n513;
      18'b000000000010000000: n6225 = n513;
      18'b000000000001000000: n6225 = n513;
      18'b000000000000100000: n6225 = n513;
      18'b000000000000010000: n6225 = n513;
      18'b000000000000001000: n6225 = n513;
      18'b000000000000000100: n6225 = n513;
      18'b000000000000000010: n6225 = n513;
      18'b000000000000000001: n6225 = n513;
      default: n6225 = n513;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6226 = inexact_reg;
      18'b010000000000000000: n6226 = inexact_reg;
      18'b001000000000000000: n6226 = inexact_reg;
      18'b000100000000000000: n6226 = inexact_reg;
      18'b000010000000000000: n6226 = inexact_reg;
      18'b000001000000000000: n6226 = n4560;
      18'b000000100000000000: n6226 = inexact_reg;
      18'b000000010000000000: n6226 = n3959;
      18'b000000001000000000: n6226 = inexact_reg;
      18'b000000000100000000: n6226 = inexact_reg;
      18'b000000000010000000: n6226 = inexact_reg;
      18'b000000000001000000: n6226 = inexact_reg;
      18'b000000000000100000: n6226 = inexact_reg;
      18'b000000000000010000: n6226 = inexact_reg;
      18'b000000000000001000: n6226 = inexact_reg;
      18'b000000000000000100: n6226 = inexact_reg;
      18'b000000000000000010: n6226 = inexact_reg;
      18'b000000000000000001: n6226 = n1761;
      default: n6226 = inexact_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6227 = n514;
      18'b010000000000000000: n6227 = n6197;
      18'b001000000000000000: n6227 = n514;
      18'b000100000000000000: n6227 = n514;
      18'b000010000000000000: n6227 = n514;
      18'b000001000000000000: n6227 = n514;
      18'b000000100000000000: n6227 = n514;
      18'b000000010000000000: n6227 = n514;
      18'b000000001000000000: n6227 = n514;
      18'b000000000100000000: n6227 = n514;
      18'b000000000010000000: n6227 = n514;
      18'b000000000001000000: n6227 = n514;
      18'b000000000000100000: n6227 = n514;
      18'b000000000000010000: n6227 = n514;
      18'b000000000000001000: n6227 = n2744;
      18'b000000000000000100: n6227 = n514;
      18'b000000000000000010: n6227 = n514;
      18'b000000000000000001: n6227 = n514;
      default: n6227 = n514;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6228 = scale_use_neg_reg;
      18'b010000000000000000: n6228 = n6198;
      18'b001000000000000000: n6228 = scale_use_neg_reg;
      18'b000100000000000000: n6228 = scale_use_neg_reg;
      18'b000010000000000000: n6228 = scale_use_neg_reg;
      18'b000001000000000000: n6228 = scale_use_neg_reg;
      18'b000000100000000000: n6228 = scale_use_neg_reg;
      18'b000000010000000000: n6228 = scale_use_neg_reg;
      18'b000000001000000000: n6228 = scale_use_neg_reg;
      18'b000000000100000000: n6228 = scale_use_neg_reg;
      18'b000000000010000000: n6228 = scale_use_neg_reg;
      18'b000000000001000000: n6228 = scale_use_neg_reg;
      18'b000000000000100000: n6228 = scale_use_neg_reg;
      18'b000000000000010000: n6228 = scale_use_neg_reg;
      18'b000000000000001000: n6228 = n2745;
      18'b000000000000000100: n6228 = scale_use_neg_reg;
      18'b000000000000000010: n6228 = scale_use_neg_reg;
      18'b000000000000000001: n6228 = scale_use_neg_reg;
      default: n6228 = scale_use_neg_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6229 = n515;
      18'b010000000000000000: n6229 = n6200;
      18'b001000000000000000: n6229 = n515;
      18'b000100000000000000: n6229 = n515;
      18'b000010000000000000: n6229 = n515;
      18'b000001000000000000: n6229 = n515;
      18'b000000100000000000: n6229 = n515;
      18'b000000010000000000: n6229 = n515;
      18'b000000001000000000: n6229 = n515;
      18'b000000000100000000: n6229 = n515;
      18'b000000000010000000: n6229 = n515;
      18'b000000000001000000: n6229 = n515;
      18'b000000000000100000: n6229 = n2945;
      18'b000000000000010000: n6229 = n2759;
      18'b000000000000001000: n6229 = n2747;
      18'b000000000000000100: n6229 = n515;
      18'b000000000000000010: n6229 = n515;
      18'b000000000000000001: n6229 = n515;
      default: n6229 = n515;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6230 = mant_u64_reg;
      18'b010000000000000000: n6230 = mant_u64_reg;
      18'b001000000000000000: n6230 = n5138;
      18'b000100000000000000: n6230 = mant_u64_reg;
      18'b000010000000000000: n6230 = mant_u64_reg;
      18'b000001000000000000: n6230 = mant_u64_reg;
      18'b000000100000000000: n6230 = mant_u64_reg;
      18'b000000010000000000: n6230 = mant_u64_reg;
      18'b000000001000000000: n6230 = mant_u64_reg;
      18'b000000000100000000: n6230 = mant_u64_reg;
      18'b000000000010000000: n6230 = mant_u64_reg;
      18'b000000000001000000: n6230 = mant_u64_reg;
      18'b000000000000100000: n6230 = mant_u64_reg;
      18'b000000000000010000: n6230 = mant_u64_reg;
      18'b000000000000001000: n6230 = mant_u64_reg;
      18'b000000000000000100: n6230 = mant_u64_reg;
      18'b000000000000000010: n6230 = mant_u64_reg;
      18'b000000000000000001: n6230 = n1762;
      default: n6230 = mant_u64_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6231 = n516;
      18'b010000000000000000: n6231 = n516;
      18'b001000000000000000: n6231 = n516;
      18'b000100000000000000: n6231 = n516;
      18'b000010000000000000: n6231 = n4625;
      18'b000001000000000000: n6231 = n4554;
      18'b000000100000000000: n6231 = n516;
      18'b000000010000000000: n6231 = n516;
      18'b000000001000000000: n6231 = n516;
      18'b000000000100000000: n6231 = n516;
      18'b000000000010000000: n6231 = n516;
      18'b000000000001000000: n6231 = n516;
      18'b000000000000100000: n6231 = n516;
      18'b000000000000010000: n6231 = n516;
      18'b000000000000001000: n6231 = n516;
      18'b000000000000000100: n6231 = n516;
      18'b000000000000000010: n6231 = n516;
      18'b000000000000000001: n6231 = n516;
      default: n6231 = n516;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6232 = n517;
      18'b010000000000000000: n6232 = n517;
      18'b001000000000000000: n6232 = n517;
      18'b000100000000000000: n6232 = n517;
      18'b000010000000000000: n6232 = n4620;
      18'b000001000000000000: n6232 = n4555;
      18'b000000100000000000: n6232 = n4110;
      18'b000000010000000000: n6232 = n517;
      18'b000000001000000000: n6232 = n517;
      18'b000000000100000000: n6232 = n517;
      18'b000000000010000000: n6232 = n517;
      18'b000000000001000000: n6232 = n517;
      18'b000000000000100000: n6232 = n517;
      18'b000000000000010000: n6232 = n517;
      18'b000000000000001000: n6232 = n517;
      18'b000000000000000100: n6232 = n517;
      18'b000000000000000010: n6232 = n517;
      18'b000000000000000001: n6232 = n517;
      default: n6232 = n517;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6236 = 1'b1;
      18'b010000000000000000: n6236 = 1'b0;
      18'b001000000000000000: n6236 = 1'b0;
      18'b000100000000000000: n6236 = 1'b1;
      18'b000010000000000000: n6236 = 1'b0;
      18'b000001000000000000: n6236 = 1'b0;
      18'b000000100000000000: n6236 = 1'b0;
      18'b000000010000000000: n6236 = 1'b0;
      18'b000000001000000000: n6236 = 1'b0;
      18'b000000000100000000: n6236 = 1'b0;
      18'b000000000010000000: n6236 = 1'b0;
      18'b000000000001000000: n6236 = 1'b0;
      18'b000000000000100000: n6236 = 1'b0;
      18'b000000000000010000: n6236 = 1'b0;
      18'b000000000000001000: n6236 = 1'b0;
      18'b000000000000000100: n6236 = 1'b0;
      18'b000000000000000010: n6236 = n2684;
      18'b000000000000000001: n6236 = n1764;
      default: n6236 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6237 = req_word_reg;
      18'b010000000000000000: n6237 = rsp_word_reg;
      18'b001000000000000000: n6237 = rsp_word_reg;
      18'b000100000000000000: n6237 = n5124;
      18'b000010000000000000: n6237 = rsp_word_reg;
      18'b000001000000000000: n6237 = rsp_word_reg;
      18'b000000100000000000: n6237 = rsp_word_reg;
      18'b000000010000000000: n6237 = rsp_word_reg;
      18'b000000001000000000: n6237 = rsp_word_reg;
      18'b000000000100000000: n6237 = rsp_word_reg;
      18'b000000000010000000: n6237 = rsp_word_reg;
      18'b000000000001000000: n6237 = rsp_word_reg;
      18'b000000000000100000: n6237 = rsp_word_reg;
      18'b000000000000010000: n6237 = rsp_word_reg;
      18'b000000000000001000: n6237 = rsp_word_reg;
      18'b000000000000000100: n6237 = rsp_word_reg;
      18'b000000000000000010: n6237 = n2685;
      18'b000000000000000001: n6237 = n1765;
      default: n6237 = rsp_word_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6238 = n6204;
      18'b010000000000000000: n6238 = rsp_fp_reg;
      18'b001000000000000000: n6238 = rsp_fp_reg;
      18'b000100000000000000: n6238 = req_fp_reg;
      18'b000010000000000000: n6238 = rsp_fp_reg;
      18'b000001000000000000: n6238 = rsp_fp_reg;
      18'b000000100000000000: n6238 = rsp_fp_reg;
      18'b000000010000000000: n6238 = rsp_fp_reg;
      18'b000000001000000000: n6238 = rsp_fp_reg;
      18'b000000000100000000: n6238 = rsp_fp_reg;
      18'b000000000010000000: n6238 = rsp_fp_reg;
      18'b000000000001000000: n6238 = rsp_fp_reg;
      18'b000000000000100000: n6238 = rsp_fp_reg;
      18'b000000000000010000: n6238 = rsp_fp_reg;
      18'b000000000000001000: n6238 = rsp_fp_reg;
      18'b000000000000000100: n6238 = rsp_fp_reg;
      18'b000000000000000010: n6238 = n2686;
      18'b000000000000000001: n6238 = n1766;
      default: n6238 = rsp_fp_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6240 = 1'b0;
      18'b010000000000000000: n6240 = rsp_inexact_reg;
      18'b001000000000000000: n6240 = rsp_inexact_reg;
      18'b000100000000000000: n6240 = inexact_reg;
      18'b000010000000000000: n6240 = rsp_inexact_reg;
      18'b000001000000000000: n6240 = rsp_inexact_reg;
      18'b000000100000000000: n6240 = rsp_inexact_reg;
      18'b000000010000000000: n6240 = rsp_inexact_reg;
      18'b000000001000000000: n6240 = rsp_inexact_reg;
      18'b000000000100000000: n6240 = rsp_inexact_reg;
      18'b000000000010000000: n6240 = rsp_inexact_reg;
      18'b000000000001000000: n6240 = rsp_inexact_reg;
      18'b000000000000100000: n6240 = rsp_inexact_reg;
      18'b000000000000010000: n6240 = rsp_inexact_reg;
      18'b000000000000001000: n6240 = rsp_inexact_reg;
      18'b000000000000000100: n6240 = rsp_inexact_reg;
      18'b000000000000000010: n6240 = n2688;
      18'b000000000000000001: n6240 = n1767;
      default: n6240 = rsp_inexact_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6243 = 1'b0;
      18'b010000000000000000: n6243 = rsp_invalid_reg;
      18'b001000000000000000: n6243 = rsp_invalid_reg;
      18'b000100000000000000: n6243 = 1'b0;
      18'b000010000000000000: n6243 = rsp_invalid_reg;
      18'b000001000000000000: n6243 = rsp_invalid_reg;
      18'b000000100000000000: n6243 = rsp_invalid_reg;
      18'b000000010000000000: n6243 = rsp_invalid_reg;
      18'b000000001000000000: n6243 = rsp_invalid_reg;
      18'b000000000100000000: n6243 = rsp_invalid_reg;
      18'b000000000010000000: n6243 = rsp_invalid_reg;
      18'b000000000001000000: n6243 = rsp_invalid_reg;
      18'b000000000000100000: n6243 = rsp_invalid_reg;
      18'b000000000000010000: n6243 = rsp_invalid_reg;
      18'b000000000000001000: n6243 = rsp_invalid_reg;
      18'b000000000000000100: n6243 = rsp_invalid_reg;
      18'b000000000000000010: n6243 = n2690;
      18'b000000000000000001: n6243 = n1768;
      default: n6243 = rsp_invalid_reg;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b010000000000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b001000000000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000100000000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000010000000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000001000000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000100000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000010000000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000001000000000: n6382 = work_fp_reg;
      18'b000000000100000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000010000000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000001000000: n6382 = n3220;
      18'b000000000000100000: n6382 = n2949;
      18'b000000000000010000: n6382 = n2764;
      18'b000000000000001000: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000100: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000010: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000001: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      default: n6382 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b010000000000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b001000000000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000100000000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000010000000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000001000000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000100000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000010000000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000001000000000: n6385 = 80'b01000000000000101010000000000000000000000000000000000000000000000000000000000000;
      18'b000000000100000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000010000000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000001000000: n6385 = n3222;
      18'b000000000000100000: n6385 = n2951;
      18'b000000000000010000: n6385 = n2766;
      18'b000000000000001000: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000100: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000010: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000001: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      default: n6385 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b010000000000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b001000000000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000100000000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000010000000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000001000000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000100000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000010000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000001000000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000100000000: n6387 = work_fp_reg;
      18'b000000000010000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000001000000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000100000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000010000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000001000: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000100: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000010: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000001: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      default: n6387 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b010000000000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b001000000000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000100000000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000010000000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000001000000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000100000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000010000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000001000000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000100000000: n6389 = n3927;
      18'b000000000010000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000001000000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000100000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000010000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000001000: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000100: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000010: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000001: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      default: n6389 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6392 = 1'b0;
      18'b010000000000000000: n6392 = 1'b0;
      18'b001000000000000000: n6392 = 1'b0;
      18'b000100000000000000: n6392 = 1'b0;
      18'b000010000000000000: n6392 = 1'b0;
      18'b000001000000000000: n6392 = 1'b0;
      18'b000000100000000000: n6392 = 1'b0;
      18'b000000010000000000: n6392 = 1'b0;
      18'b000000001000000000: n6392 = 1'b0;
      18'b000000000100000000: n6392 = 1'b1;
      18'b000000000010000000: n6392 = 1'b0;
      18'b000000000001000000: n6392 = 1'b0;
      18'b000000000000100000: n6392 = 1'b0;
      18'b000000000000010000: n6392 = 1'b0;
      18'b000000000000001000: n6392 = 1'b0;
      18'b000000000000000100: n6392 = 1'b0;
      18'b000000000000000010: n6392 = 1'b0;
      18'b000000000000000001: n6392 = 1'b0;
      default: n6392 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b010000000000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b001000000000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000100000000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000010000000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000001000000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000100000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000010000000000: n6394 = work_fp_reg;
      18'b000000001000000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000100000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000010000000: n6394 = work_fp_reg;
      18'b000000000001000000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000100000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000010000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000001000: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000100: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000010: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      18'b000000000000000001: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
      default: n6394 = 80'b00111111111111111000000000000000000000000000000000000000000000000000000000000000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b010000000000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b001000000000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000100000000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000010000000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000001000000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000100000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000010000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000001000000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000100000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000010000000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000001000000: n6396 = n3224;
      18'b000000000000100000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000000010000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000000001000: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000000000100: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000000000010: n6396 = 32'b00000000000000000000000000000000;
      18'b000000000000000001: n6396 = 32'b00000000000000000000000000000000;
      default: n6396 = 32'b00000000000000000000000000000000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6402 = 3'b000;
      18'b010000000000000000: n6402 = 3'b000;
      18'b001000000000000000: n6402 = 3'b000;
      18'b000100000000000000: n6402 = 3'b000;
      18'b000010000000000000: n6402 = 3'b000;
      18'b000001000000000000: n6402 = 3'b000;
      18'b000000100000000000: n6402 = 3'b000;
      18'b000000010000000000: n6402 = 3'b111;
      18'b000000001000000000: n6402 = 3'b110;
      18'b000000000100000000: n6402 = 3'b101;
      18'b000000000010000000: n6402 = 3'b100;
      18'b000000000001000000: n6402 = n3226;
      18'b000000000000100000: n6402 = n2953;
      18'b000000000000010000: n6402 = n2769;
      18'b000000000000001000: n6402 = 3'b000;
      18'b000000000000000100: n6402 = 3'b000;
      18'b000000000000000010: n6402 = 3'b000;
      18'b000000000000000001: n6402 = 3'b000;
      default: n6402 = 3'b000;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6405 = 1'b0;
      18'b010000000000000000: n6405 = 1'b0;
      18'b001000000000000000: n6405 = 1'b0;
      18'b000100000000000000: n6405 = 1'b1;
      18'b000010000000000000: n6405 = 1'b0;
      18'b000001000000000000: n6405 = 1'b0;
      18'b000000100000000000: n6405 = 1'b0;
      18'b000000010000000000: n6405 = 1'b0;
      18'b000000001000000000: n6405 = 1'b0;
      18'b000000000100000000: n6405 = 1'b0;
      18'b000000000010000000: n6405 = 1'b0;
      18'b000000000001000000: n6405 = 1'b0;
      18'b000000000000100000: n6405 = 1'b0;
      18'b000000000000010000: n6405 = 1'b0;
      18'b000000000000001000: n6405 = 1'b0;
      18'b000000000000000100: n6405 = 1'b0;
      18'b000000000000000010: n6405 = 1'b0;
      18'b000000000000000001: n6405 = 1'b0;
      default: n6405 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6408 = 1'b0;
      18'b010000000000000000: n6408 = 1'b0;
      18'b001000000000000000: n6408 = 1'b0;
      18'b000100000000000000: n6408 = 1'b1;
      18'b000010000000000000: n6408 = 1'b0;
      18'b000001000000000000: n6408 = 1'b0;
      18'b000000100000000000: n6408 = 1'b0;
      18'b000000010000000000: n6408 = 1'b0;
      18'b000000001000000000: n6408 = 1'b0;
      18'b000000000100000000: n6408 = 1'b0;
      18'b000000000010000000: n6408 = 1'b0;
      18'b000000000001000000: n6408 = 1'b0;
      18'b000000000000100000: n6408 = 1'b0;
      18'b000000000000010000: n6408 = 1'b0;
      18'b000000000000001000: n6408 = 1'b0;
      18'b000000000000000100: n6408 = 1'b0;
      18'b000000000000000010: n6408 = 1'b0;
      18'b000000000000000001: n6408 = 1'b0;
      default: n6408 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6411 = 1'b0;
      18'b010000000000000000: n6411 = 1'b0;
      18'b001000000000000000: n6411 = 1'b0;
      18'b000100000000000000: n6411 = 1'b1;
      18'b000010000000000000: n6411 = 1'b0;
      18'b000001000000000000: n6411 = 1'b0;
      18'b000000100000000000: n6411 = 1'b0;
      18'b000000010000000000: n6411 = 1'b0;
      18'b000000001000000000: n6411 = 1'b0;
      18'b000000000100000000: n6411 = 1'b0;
      18'b000000000010000000: n6411 = 1'b0;
      18'b000000000001000000: n6411 = 1'b0;
      18'b000000000000100000: n6411 = 1'b0;
      18'b000000000000010000: n6411 = 1'b0;
      18'b000000000000001000: n6411 = 1'b0;
      18'b000000000000000100: n6411 = 1'b0;
      18'b000000000000000010: n6411 = 1'b0;
      18'b000000000000000001: n6411 = 1'b0;
      default: n6411 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6414 = 1'b0;
      18'b010000000000000000: n6414 = 1'b0;
      18'b001000000000000000: n6414 = 1'b0;
      18'b000100000000000000: n6414 = 1'b1;
      18'b000010000000000000: n6414 = 1'b0;
      18'b000001000000000000: n6414 = 1'b0;
      18'b000000100000000000: n6414 = 1'b0;
      18'b000000010000000000: n6414 = 1'b0;
      18'b000000001000000000: n6414 = 1'b0;
      18'b000000000100000000: n6414 = 1'b0;
      18'b000000000010000000: n6414 = 1'b0;
      18'b000000000001000000: n6414 = 1'b0;
      18'b000000000000100000: n6414 = 1'b0;
      18'b000000000000010000: n6414 = 1'b0;
      18'b000000000000001000: n6414 = 1'b0;
      18'b000000000000000100: n6414 = 1'b0;
      18'b000000000000000010: n6414 = 1'b0;
      18'b000000000000000001: n6414 = 1'b0;
      default: n6414 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6417 = 1'b0;
      18'b010000000000000000: n6417 = 1'b0;
      18'b001000000000000000: n6417 = 1'b0;
      18'b000100000000000000: n6417 = 1'b1;
      18'b000010000000000000: n6417 = 1'b0;
      18'b000001000000000000: n6417 = 1'b0;
      18'b000000100000000000: n6417 = 1'b0;
      18'b000000010000000000: n6417 = 1'b0;
      18'b000000001000000000: n6417 = 1'b0;
      18'b000000000100000000: n6417 = 1'b0;
      18'b000000000010000000: n6417 = 1'b0;
      18'b000000000001000000: n6417 = 1'b0;
      18'b000000000000100000: n6417 = 1'b0;
      18'b000000000000010000: n6417 = 1'b0;
      18'b000000000000001000: n6417 = 1'b0;
      18'b000000000000000100: n6417 = 1'b0;
      18'b000000000000000010: n6417 = 1'b0;
      18'b000000000000000001: n6417 = 1'b0;
      default: n6417 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6420 = 1'b0;
      18'b010000000000000000: n6420 = 1'b0;
      18'b001000000000000000: n6420 = 1'b0;
      18'b000100000000000000: n6420 = 1'b1;
      18'b000010000000000000: n6420 = 1'b0;
      18'b000001000000000000: n6420 = 1'b0;
      18'b000000100000000000: n6420 = 1'b0;
      18'b000000010000000000: n6420 = 1'b0;
      18'b000000001000000000: n6420 = 1'b0;
      18'b000000000100000000: n6420 = 1'b0;
      18'b000000000010000000: n6420 = 1'b0;
      18'b000000000001000000: n6420 = 1'b0;
      18'b000000000000100000: n6420 = 1'b0;
      18'b000000000000010000: n6420 = 1'b0;
      18'b000000000000001000: n6420 = 1'b0;
      18'b000000000000000100: n6420 = 1'b0;
      18'b000000000000000010: n6420 = 1'b0;
      18'b000000000000000001: n6420 = 1'b0;
      default: n6420 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6423 = 1'b0;
      18'b010000000000000000: n6423 = 1'b0;
      18'b001000000000000000: n6423 = 1'b0;
      18'b000100000000000000: n6423 = 1'b1;
      18'b000010000000000000: n6423 = 1'b0;
      18'b000001000000000000: n6423 = 1'b0;
      18'b000000100000000000: n6423 = 1'b0;
      18'b000000010000000000: n6423 = 1'b0;
      18'b000000001000000000: n6423 = 1'b0;
      18'b000000000100000000: n6423 = 1'b0;
      18'b000000000010000000: n6423 = 1'b0;
      18'b000000000001000000: n6423 = 1'b0;
      18'b000000000000100000: n6423 = 1'b0;
      18'b000000000000010000: n6423 = 1'b0;
      18'b000000000000001000: n6423 = 1'b0;
      18'b000000000000000100: n6423 = 1'b0;
      18'b000000000000000010: n6423 = 1'b0;
      18'b000000000000000001: n6423 = 1'b0;
      default: n6423 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6426 = 1'b0;
      18'b010000000000000000: n6426 = 1'b0;
      18'b001000000000000000: n6426 = 1'b0;
      18'b000100000000000000: n6426 = 1'b1;
      18'b000010000000000000: n6426 = 1'b0;
      18'b000001000000000000: n6426 = 1'b0;
      18'b000000100000000000: n6426 = 1'b0;
      18'b000000010000000000: n6426 = 1'b0;
      18'b000000001000000000: n6426 = 1'b0;
      18'b000000000100000000: n6426 = 1'b0;
      18'b000000000010000000: n6426 = 1'b0;
      18'b000000000001000000: n6426 = 1'b0;
      18'b000000000000100000: n6426 = 1'b0;
      18'b000000000000010000: n6426 = 1'b0;
      18'b000000000000001000: n6426 = 1'b0;
      18'b000000000000000100: n6426 = 1'b0;
      18'b000000000000000010: n6426 = 1'b0;
      18'b000000000000000001: n6426 = 1'b0;
      default: n6426 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6429 = 1'b0;
      18'b010000000000000000: n6429 = 1'b0;
      18'b001000000000000000: n6429 = 1'b0;
      18'b000100000000000000: n6429 = 1'b1;
      18'b000010000000000000: n6429 = 1'b0;
      18'b000001000000000000: n6429 = 1'b0;
      18'b000000100000000000: n6429 = 1'b0;
      18'b000000010000000000: n6429 = 1'b0;
      18'b000000001000000000: n6429 = 1'b0;
      18'b000000000100000000: n6429 = 1'b0;
      18'b000000000010000000: n6429 = 1'b0;
      18'b000000000001000000: n6429 = 1'b0;
      18'b000000000000100000: n6429 = 1'b0;
      18'b000000000000010000: n6429 = 1'b0;
      18'b000000000000001000: n6429 = 1'b0;
      18'b000000000000000100: n6429 = 1'b0;
      18'b000000000000000010: n6429 = 1'b0;
      18'b000000000000000001: n6429 = 1'b0;
      default: n6429 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6432 = 1'b0;
      18'b010000000000000000: n6432 = 1'b0;
      18'b001000000000000000: n6432 = 1'b0;
      18'b000100000000000000: n6432 = 1'b1;
      18'b000010000000000000: n6432 = 1'b0;
      18'b000001000000000000: n6432 = 1'b0;
      18'b000000100000000000: n6432 = 1'b0;
      18'b000000010000000000: n6432 = 1'b0;
      18'b000000001000000000: n6432 = 1'b0;
      18'b000000000100000000: n6432 = 1'b0;
      18'b000000000010000000: n6432 = 1'b0;
      18'b000000000001000000: n6432 = 1'b0;
      18'b000000000000100000: n6432 = 1'b0;
      18'b000000000000010000: n6432 = 1'b0;
      18'b000000000000001000: n6432 = 1'b0;
      18'b000000000000000100: n6432 = 1'b0;
      18'b000000000000000010: n6432 = 1'b0;
      18'b000000000000000001: n6432 = 1'b0;
      default: n6432 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6435 = 1'b0;
      18'b010000000000000000: n6435 = 1'b0;
      18'b001000000000000000: n6435 = 1'b0;
      18'b000100000000000000: n6435 = 1'b1;
      18'b000010000000000000: n6435 = 1'b0;
      18'b000001000000000000: n6435 = 1'b0;
      18'b000000100000000000: n6435 = 1'b0;
      18'b000000010000000000: n6435 = 1'b0;
      18'b000000001000000000: n6435 = 1'b0;
      18'b000000000100000000: n6435 = 1'b0;
      18'b000000000010000000: n6435 = 1'b0;
      18'b000000000001000000: n6435 = 1'b0;
      18'b000000000000100000: n6435 = 1'b0;
      18'b000000000000010000: n6435 = 1'b0;
      18'b000000000000001000: n6435 = 1'b0;
      18'b000000000000000100: n6435 = 1'b0;
      18'b000000000000000010: n6435 = 1'b0;
      18'b000000000000000001: n6435 = 1'b0;
      default: n6435 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6438 = 1'b0;
      18'b010000000000000000: n6438 = 1'b0;
      18'b001000000000000000: n6438 = 1'b0;
      18'b000100000000000000: n6438 = 1'b1;
      18'b000010000000000000: n6438 = 1'b0;
      18'b000001000000000000: n6438 = 1'b0;
      18'b000000100000000000: n6438 = 1'b0;
      18'b000000010000000000: n6438 = 1'b0;
      18'b000000001000000000: n6438 = 1'b0;
      18'b000000000100000000: n6438 = 1'b0;
      18'b000000000010000000: n6438 = 1'b0;
      18'b000000000001000000: n6438 = 1'b0;
      18'b000000000000100000: n6438 = 1'b0;
      18'b000000000000010000: n6438 = 1'b0;
      18'b000000000000001000: n6438 = 1'b0;
      18'b000000000000000100: n6438 = 1'b0;
      18'b000000000000000010: n6438 = 1'b0;
      18'b000000000000000001: n6438 = 1'b0;
      default: n6438 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6441 = 1'b0;
      18'b010000000000000000: n6441 = 1'b0;
      18'b001000000000000000: n6441 = 1'b0;
      18'b000100000000000000: n6441 = 1'b1;
      18'b000010000000000000: n6441 = 1'b0;
      18'b000001000000000000: n6441 = 1'b0;
      18'b000000100000000000: n6441 = 1'b0;
      18'b000000010000000000: n6441 = 1'b0;
      18'b000000001000000000: n6441 = 1'b0;
      18'b000000000100000000: n6441 = 1'b0;
      18'b000000000010000000: n6441 = 1'b0;
      18'b000000000001000000: n6441 = 1'b0;
      18'b000000000000100000: n6441 = 1'b0;
      18'b000000000000010000: n6441 = 1'b0;
      18'b000000000000001000: n6441 = 1'b0;
      18'b000000000000000100: n6441 = 1'b0;
      18'b000000000000000010: n6441 = 1'b0;
      18'b000000000000000001: n6441 = 1'b0;
      default: n6441 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6444 = 1'b0;
      18'b010000000000000000: n6444 = 1'b0;
      18'b001000000000000000: n6444 = 1'b0;
      18'b000100000000000000: n6444 = 1'b1;
      18'b000010000000000000: n6444 = 1'b0;
      18'b000001000000000000: n6444 = 1'b0;
      18'b000000100000000000: n6444 = 1'b0;
      18'b000000010000000000: n6444 = 1'b0;
      18'b000000001000000000: n6444 = 1'b0;
      18'b000000000100000000: n6444 = 1'b0;
      18'b000000000010000000: n6444 = 1'b0;
      18'b000000000001000000: n6444 = 1'b0;
      18'b000000000000100000: n6444 = 1'b0;
      18'b000000000000010000: n6444 = 1'b0;
      18'b000000000000001000: n6444 = 1'b0;
      18'b000000000000000100: n6444 = 1'b0;
      18'b000000000000000010: n6444 = 1'b0;
      18'b000000000000000001: n6444 = 1'b0;
      default: n6444 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6447 = 1'b0;
      18'b010000000000000000: n6447 = 1'b0;
      18'b001000000000000000: n6447 = 1'b0;
      18'b000100000000000000: n6447 = 1'b1;
      18'b000010000000000000: n6447 = 1'b0;
      18'b000001000000000000: n6447 = 1'b0;
      18'b000000100000000000: n6447 = 1'b0;
      18'b000000010000000000: n6447 = 1'b0;
      18'b000000001000000000: n6447 = 1'b0;
      18'b000000000100000000: n6447 = 1'b0;
      18'b000000000010000000: n6447 = 1'b0;
      18'b000000000001000000: n6447 = 1'b0;
      18'b000000000000100000: n6447 = 1'b0;
      18'b000000000000010000: n6447 = 1'b0;
      18'b000000000000001000: n6447 = 1'b0;
      18'b000000000000000100: n6447 = 1'b0;
      18'b000000000000000010: n6447 = 1'b0;
      18'b000000000000000001: n6447 = 1'b0;
      default: n6447 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6450 = 1'b0;
      18'b010000000000000000: n6450 = 1'b0;
      18'b001000000000000000: n6450 = 1'b0;
      18'b000100000000000000: n6450 = 1'b1;
      18'b000010000000000000: n6450 = 1'b0;
      18'b000001000000000000: n6450 = 1'b0;
      18'b000000100000000000: n6450 = 1'b0;
      18'b000000010000000000: n6450 = 1'b0;
      18'b000000001000000000: n6450 = 1'b0;
      18'b000000000100000000: n6450 = 1'b0;
      18'b000000000010000000: n6450 = 1'b0;
      18'b000000000001000000: n6450 = 1'b0;
      18'b000000000000100000: n6450 = 1'b0;
      18'b000000000000010000: n6450 = 1'b0;
      18'b000000000000001000: n6450 = 1'b0;
      18'b000000000000000100: n6450 = 1'b0;
      18'b000000000000000010: n6450 = 1'b0;
      18'b000000000000000001: n6450 = 1'b0;
      default: n6450 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6453 = 1'b0;
      18'b010000000000000000: n6453 = 1'b0;
      18'b001000000000000000: n6453 = 1'b0;
      18'b000100000000000000: n6453 = 1'b1;
      18'b000010000000000000: n6453 = 1'b0;
      18'b000001000000000000: n6453 = 1'b0;
      18'b000000100000000000: n6453 = 1'b0;
      18'b000000010000000000: n6453 = 1'b0;
      18'b000000001000000000: n6453 = 1'b0;
      18'b000000000100000000: n6453 = 1'b0;
      18'b000000000010000000: n6453 = 1'b0;
      18'b000000000001000000: n6453 = 1'b0;
      18'b000000000000100000: n6453 = 1'b0;
      18'b000000000000010000: n6453 = 1'b0;
      18'b000000000000001000: n6453 = 1'b0;
      18'b000000000000000100: n6453 = 1'b0;
      18'b000000000000000010: n6453 = 1'b0;
      18'b000000000000000001: n6453 = 1'b0;
      default: n6453 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6456 = 1'b0;
      18'b010000000000000000: n6456 = 1'b0;
      18'b001000000000000000: n6456 = 1'b0;
      18'b000100000000000000: n6456 = 1'b1;
      18'b000010000000000000: n6456 = 1'b0;
      18'b000001000000000000: n6456 = 1'b0;
      18'b000000100000000000: n6456 = 1'b0;
      18'b000000010000000000: n6456 = 1'b0;
      18'b000000001000000000: n6456 = 1'b0;
      18'b000000000100000000: n6456 = 1'b0;
      18'b000000000010000000: n6456 = 1'b0;
      18'b000000000001000000: n6456 = 1'b0;
      18'b000000000000100000: n6456 = 1'b0;
      18'b000000000000010000: n6456 = 1'b0;
      18'b000000000000001000: n6456 = 1'b0;
      18'b000000000000000100: n6456 = 1'b0;
      18'b000000000000000010: n6456 = 1'b0;
      18'b000000000000000001: n6456 = 1'b0;
      default: n6456 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6459 = 1'b0;
      18'b010000000000000000: n6459 = 1'b0;
      18'b001000000000000000: n6459 = 1'b0;
      18'b000100000000000000: n6459 = 1'b1;
      18'b000010000000000000: n6459 = 1'b0;
      18'b000001000000000000: n6459 = 1'b0;
      18'b000000100000000000: n6459 = 1'b0;
      18'b000000010000000000: n6459 = 1'b0;
      18'b000000001000000000: n6459 = 1'b0;
      18'b000000000100000000: n6459 = 1'b0;
      18'b000000000010000000: n6459 = 1'b0;
      18'b000000000001000000: n6459 = 1'b0;
      18'b000000000000100000: n6459 = 1'b0;
      18'b000000000000010000: n6459 = 1'b0;
      18'b000000000000001000: n6459 = 1'b0;
      18'b000000000000000100: n6459 = 1'b0;
      18'b000000000000000010: n6459 = 1'b0;
      18'b000000000000000001: n6459 = 1'b0;
      default: n6459 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6462 = 1'b0;
      18'b010000000000000000: n6462 = 1'b0;
      18'b001000000000000000: n6462 = 1'b0;
      18'b000100000000000000: n6462 = 1'b1;
      18'b000010000000000000: n6462 = 1'b0;
      18'b000001000000000000: n6462 = 1'b0;
      18'b000000100000000000: n6462 = 1'b0;
      18'b000000010000000000: n6462 = 1'b0;
      18'b000000001000000000: n6462 = 1'b0;
      18'b000000000100000000: n6462 = 1'b0;
      18'b000000000010000000: n6462 = 1'b0;
      18'b000000000001000000: n6462 = 1'b0;
      18'b000000000000100000: n6462 = 1'b0;
      18'b000000000000010000: n6462 = 1'b0;
      18'b000000000000001000: n6462 = 1'b0;
      18'b000000000000000100: n6462 = 1'b0;
      18'b000000000000000010: n6462 = 1'b0;
      18'b000000000000000001: n6462 = 1'b0;
      default: n6462 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  always @*
    case (n6207)
      18'b100000000000000000: n6465 = 1'b0;
      18'b010000000000000000: n6465 = 1'b0;
      18'b001000000000000000: n6465 = 1'b0;
      18'b000100000000000000: n6465 = 1'b1;
      18'b000010000000000000: n6465 = 1'b0;
      18'b000001000000000000: n6465 = 1'b0;
      18'b000000100000000000: n6465 = 1'b0;
      18'b000000010000000000: n6465 = 1'b0;
      18'b000000001000000000: n6465 = 1'b0;
      18'b000000000100000000: n6465 = 1'b0;
      18'b000000000010000000: n6465 = 1'b0;
      18'b000000000001000000: n6465 = 1'b0;
      18'b000000000000100000: n6465 = 1'b0;
      18'b000000000000010000: n6465 = 1'b0;
      18'b000000000000001000: n6465 = 1'b0;
      18'b000000000000000100: n6465 = 1'b0;
      18'b000000000000000010: n6465 = 1'b0;
      18'b000000000000000001: n6465 = 1'b0;
      default: n6465 = 1'b0;
    endcase
  /* mc68881_packed_decimal_unit.vhd:910:23  */
  assign n6467 = n6402 != 3'b000;
  /* mc68881_packed_decimal_unit.vhd:912:37  */
  assign n6468 = n6396[1:0];  // trunc
  /* mc68881_packed_decimal_unit.vhd:917:9  */
  assign n6471 = n6392 ? 1'b1 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:925:25  */
  assign n6473 = n6402 == 3'b100;
  /* mc68881_packed_decimal_unit.vhd:925:60  */
  assign n6475 = n6402 == 3'b111;
  /* mc68881_packed_decimal_unit.vhd:925:44  */
  assign n6476 = n6473 | n6475;
  /* mc68881_packed_decimal_unit.vhd:925:9  */
  assign n6479 = n6476 ? 3'b011 : 3'b000;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6481 = n6519 ? 2'b01 : n518;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6482 = n6520 ? n6479 : n519;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6483 = n6521 ? n6402 : n520;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6491 = n535 ? n6212 : n507;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6497 = n535 ? n6218 : n508;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6499 = n535 ? n6220 : n509;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6500 = n535 ? n6221 : n510;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6501 = n535 ? n6222 : n511;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6502 = n535 ? n6223 : n512;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6504 = n535 ? n6225 : n513;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6506 = n535 ? n6227 : n514;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6508 = n535 ? n6229 : n515;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6510 = n535 ? n6231 : n516;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6511 = n535 ? n6232 : n517;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6513 = n535 ? n6236 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6519 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6520 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6521 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6522 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6523 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6524 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6525 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6526 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6527 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6528 = n6467 & n535;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6589 = n535 ? n6405 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6591 = n535 ? n6408 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6593 = n535 ? n6411 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6595 = n535 ? n6414 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6597 = n535 ? n6417 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6599 = n535 ? n6420 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6601 = n535 ? n6423 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6603 = n535 ? n6426 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6605 = n535 ? n6429 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6607 = n535 ? n6432 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6609 = n535 ? n6435 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6611 = n535 ? n6438 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6613 = n535 ? n6441 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6615 = n535 ? n6444 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6617 = n535 ? n6447 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6619 = n535 ? n6450 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6621 = n535 ? n6453 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6623 = n535 ? n6456 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6625 = n535 ? n6459 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6627 = n535 ? n6462 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n6629 = n535 ? n6465 : 1'b0;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6934 <= 1'b1;
    else
      n6934 <= n4680;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6936 <= 1'b1;
    else
      n6936 <= n4700;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6938 <= 1'b1;
    else
      n6938 <= n4720;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6940 <= 1'b1;
    else
      n6940 <= n4740;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6942 <= 1'b1;
    else
      n6942 <= n4764;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6944 <= 1'b1;
    else
      n6944 <= n4786;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6946 <= 1'b1;
    else
      n6946 <= n4808;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6948 <= 1'b1;
    else
      n6948 <= n4830;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6950 <= 1'b1;
    else
      n6950 <= n4852;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6952 <= 1'b1;
    else
      n6952 <= n4874;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6954 <= 1'b1;
    else
      n6954 <= n4896;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6956 <= 1'b1;
    else
      n6956 <= n4918;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6958 <= 1'b1;
    else
      n6958 <= n4940;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6960 <= 1'b1;
    else
      n6960 <= n4962;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6962 <= 1'b1;
    else
      n6962 <= n4984;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6964 <= 1'b1;
    else
      n6964 <= n5006;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6966 <= 1'b1;
    else
      n6966 <= n5028;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6968 <= 1'b1;
    else
      n6968 <= n5050;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6970 <= 1'b1;
    else
      n6970 <= n5072;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6972 <= 1'b1;
    else
      n6972 <= n5094;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  always @(posedge clk or posedge n104)
    if (n104)
      n6974 <= 1'b1;
    else
      n6974 <= n5116;
  /* mc68881_packed_decimal_unit.vhd:938:16  */
  assign n7109 = ~reset_n;
  /* mc68881_packed_decimal_unit.vhd:945:55  */
  assign n7113 = {11'b0, state_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:947:56  */
  assign n7116 = {14'b0, arith_stage_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:950:42  */
  assign n7118 = {11'b0, idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:951:42  */
  assign n7121 = {11'b0, scale_return_state_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:950:68  */
  assign n7122 = {n7118, n7121};
  /* mc68881_packed_decimal_unit.vhd:954:42  */
  assign n7124 = {2'b0, scale_abs_exp_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:955:42  */
  assign n7126 = {4'b0, scale_bit_idx_reg};  //  uext
  /* mc68881_packed_decimal_unit.vhd:954:78  */
  assign n7127 = {n7124, n7126};
  /* mc68881_packed_decimal_unit.vhd:955:77  */
  assign n7129 = {n7127, 7'b0000000};
  /* mc68881_packed_decimal_unit.vhd:956:35  */
  assign n7130 = {n7129, scale_use_neg_reg};
  assign n7131 = {n7116, n7113};
  /* mc68881_packed_decimal_unit.vhd:943:7  */
  assign n7132 = save_req ? n7131 : shadow_word0;
  /* mc68881_packed_decimal_unit.vhd:943:7  */
  assign n7133 = save_req ? n7122 : shadow_word1;
  /* mc68881_packed_decimal_unit.vhd:943:7  */
  assign n7134 = save_req ? n7130 : shadow_word2;
  /* mc68881_packed_decimal_unit.vhd:960:11  */
  assign n7136 = restore_addr == 2'b00;
  /* mc68881_packed_decimal_unit.vhd:961:11  */
  assign n7138 = restore_addr == 2'b01;
  /* mc68881_packed_decimal_unit.vhd:962:11  */
  assign n7140 = restore_addr == 2'b10;
  assign n7141 = {n7140, n7138, n7136};
  /* mc68881_packed_decimal_unit.vhd:959:9  */
  always @*
    case (n7141)
      3'b100: n7142 = n7132;
      3'b010: n7142 = n7132;
      3'b001: n7142 = restore_data;
      default: n7142 = n7132;
    endcase
  /* mc68881_packed_decimal_unit.vhd:959:9  */
  always @*
    case (n7141)
      3'b100: n7143 = n7133;
      3'b010: n7143 = restore_data;
      3'b001: n7143 = n7133;
      default: n7143 = n7133;
    endcase
  /* mc68881_packed_decimal_unit.vhd:959:9  */
  always @*
    case (n7141)
      3'b100: n7144 = restore_data;
      3'b010: n7144 = n7134;
      3'b001: n7144 = n7134;
      default: n7144 = n7134;
    endcase
  /* mc68881_packed_decimal_unit.vhd:958:7  */
  assign n7145 = restore_wr ? n7142 : n7132;
  /* mc68881_packed_decimal_unit.vhd:958:7  */
  assign n7146 = restore_wr ? n7143 : n7133;
  /* mc68881_packed_decimal_unit.vhd:958:7  */
  assign n7147 = restore_wr ? n7144 : n7134;
  /* mc68881_packed_decimal_unit.vhd:970:44  */
  assign n7158 = {30'b0, save_addr};  //  uext
  /* mc68881_packed_decimal_unit.vhd:970:44  */
  assign n7160 = n7158 == 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:970:29  */
  assign n7161 = n7160 ? shadow_word0 : n7165;
  /* mc68881_packed_decimal_unit.vhd:971:44  */
  assign n7162 = {30'b0, save_addr};  //  uext
  /* mc68881_packed_decimal_unit.vhd:971:44  */
  assign n7164 = n7162 == 32'b00000000000000000000000000000001;
  /* mc68881_packed_decimal_unit.vhd:970:48  */
  assign n7165 = n7164 ? shadow_word1 : n7169;
  /* mc68881_packed_decimal_unit.vhd:972:44  */
  assign n7166 = {30'b0, save_addr};  //  uext
  /* mc68881_packed_decimal_unit.vhd:972:44  */
  assign n7168 = n7166 == 32'b00000000000000000000000000000010;
  /* mc68881_packed_decimal_unit.vhd:971:48  */
  assign n7169 = n7168 ? shadow_word2 : 32'b00000000000000000000000000000000;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7171 <= 5'b00000;
    else
      n7171 <= n6491;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7172 = n535 ? n6213 : scale_return_state_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7173 <= 5'b00000;
    else
      n7173 <= n7172;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7174 = n535 ? n6214 : req_fp_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7175 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7175 <= n7174;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7176 = n535 ? n6215 : req_word_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7177 <= 96'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7177 <= n7176;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7178 = n535 ? n6216 : req_k_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7179 <= 7'b0000000;
    else
      n7179 <= n7178;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7180 = n535 ? n6217 : sign_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7181 <= 1'b0;
    else
      n7181 <= n7180;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7182 <= 15'b000000000000000;
    else
      n7182 <= n6497;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7183 = n535 ? n6219 : bin_exp_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7184 <= 16'b0000000000000000;
    else
      n7184 <= n7183;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7185 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7185 <= n6499;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7186 <= 68'b00000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7186 <= n6500;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7187 <= 4'b0000;
    else
      n7187 <= n6501;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7188 <= 5'b00000;
    else
      n7188 <= n6502;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7189 = n535 ? n6224 : tune_iter_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7190 <= 3'b000;
    else
      n7190 <= n7189;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7191 <= 5'b10001;
    else
      n7191 <= n6504;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7192 = n535 ? n6226 : inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7193 <= 1'b0;
    else
      n7193 <= n7192;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7194 <= 14'b00000000000000;
    else
      n7194 <= n6506;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7195 = n535 ? n6228 : scale_use_neg_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7196 <= 1'b0;
    else
      n7196 <= n7195;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7197 <= 4'b0000;
    else
      n7197 <= n6508;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7198 = n535 ? n6230 : mant_u64_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7199 <= 64'b0000000000000000000000000000000000000000000000000000000000000000;
    else
      n7199 <= n7198;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7200 <= 1'b0;
    else
      n7200 <= n6510;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7201 <= 5'b00000;
    else
      n7201 <= n6511;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7202 <= 1'b0;
    else
      n7202 <= n6513;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7203 = n535 ? n6237 : rsp_word_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7204 <= 96'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7204 <= n7203;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7205 = n535 ? n6238 : rsp_fp_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7206 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7206 <= n7205;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7207 = n535 ? n6240 : rsp_inexact_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7208 <= 1'b0;
    else
      n7208 <= n7207;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7209 = n535 ? n6243 : rsp_invalid_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7210 <= 1'b0;
    else
      n7210 <= n7209;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7211 <= 2'b00;
    else
      n7211 <= n6481;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7212 <= 3'b000;
    else
      n7212 <= n6482;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7213 <= 3'b000;
    else
      n7213 <= n6483;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7214 = n6522 ? n6468 : arith_tune_exp_delta_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7215 <= 2'b00;
    else
      n7215 <= n7214;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7216 = n6523 ? n6382 : arith_mul_a_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7217 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7217 <= n7216;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7218 = n6524 ? n6385 : arith_mul_b_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7219 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7219 <= n7218;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7220 = n6525 ? n6387 : arith_add_a_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7221 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7221 <= n7220;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7222 = n6526 ? n6389 : arith_add_b_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7223 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7223 <= n7222;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7224 = n6527 ? n6471 : arith_add_sub_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7225 <= 1'b0;
    else
      n7225 <= n7224;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7226 = n6528 ? n6394 : arith_int_arg_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7227 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7227 <= n7226;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7228 = n107 ? n347 : arith_mul_res_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7229 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7229 <= n7228;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7230 = n107 ? n348 : arith_add_res_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7231 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n7231 <= n7230;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7232 = n107 ? n349 : arith_int_res_reg;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7233 <= 5'b00000;
    else
      n7233 <= n7232;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7234 <= 1'b0;
    else
      n7234 <= n525;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  always @(posedge clk or posedge n104)
    if (n104)
      n7235 <= 1'b0;
    else
      n7235 <= n528;
  /* mc68881_packed_decimal_unit.vhd:942:5  */
  always @(posedge clk or posedge n7109)
    if (n7109)
      n7236 <= 32'b00000000000000000000000000000000;
    else
      n7236 <= n7145;
  /* mc68881_packed_decimal_unit.vhd:942:5  */
  always @(posedge clk or posedge n7109)
    if (n7109)
      n7237 <= 32'b00000000000000000000000000000000;
    else
      n7237 <= n7146;
  /* mc68881_packed_decimal_unit.vhd:942:5  */
  always @(posedge clk or posedge n7109)
    if (n7109)
      n7238 <= 32'b00000000000000000000000000000000;
    else
      n7238 <= n7147;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7239 = n391[4]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7240 = ~n7239;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7241 = n391[3]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7242 = ~n7241;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7243 = n7240 & n7242;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7244 = n7240 & n7241;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7245 = n7239 & n7242;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7246 = n391[2]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7247 = ~n7246;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7248 = n7243 & n7247;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7249 = n7243 & n7246;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7250 = n7244 & n7247;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7251 = n7244 & n7246;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7252 = n7245 & n7247;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7253 = n391[1]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7254 = ~n7253;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7255 = n7248 & n7254;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7256 = n7248 & n7253;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7257 = n7249 & n7254;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7258 = n7249 & n7253;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7259 = n7250 & n7254;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7260 = n7250 & n7253;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7261 = n7251 & n7254;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7262 = n7251 & n7253;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7263 = n7252 & n7254;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7264 = n391[0]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7265 = ~n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7266 = n7255 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7267 = n7255 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7268 = n7256 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7269 = n7256 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7270 = n7257 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7271 = n7257 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7272 = n7258 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7273 = n7258 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7274 = n7259 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7275 = n7259 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7276 = n7260 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7277 = n7260 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7278 = n7261 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7279 = n7261 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7280 = n7262 & n7265;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7281 = n7262 & n7264;
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7282 = n7263 & n7265;
  /* mc68881_packed_decimal_unit.vhd:946:26  */
  assign n7283 = digits_reg[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7284 = n7266 ? enc_digit_reg : n7283;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7285 = digits_reg[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7286 = n7267 ? enc_digit_reg : n7285;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7287 = digits_reg[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7288 = n7268 ? enc_digit_reg : n7287;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7289 = digits_reg[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7290 = n7269 ? enc_digit_reg : n7289;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7291 = digits_reg[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7292 = n7270 ? enc_digit_reg : n7291;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7293 = digits_reg[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7294 = n7271 ? enc_digit_reg : n7293;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7295 = digits_reg[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7296 = n7272 ? enc_digit_reg : n7295;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7297 = digits_reg[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7298 = n7273 ? enc_digit_reg : n7297;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7299 = digits_reg[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7300 = n7274 ? enc_digit_reg : n7299;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7301 = digits_reg[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7302 = n7275 ? enc_digit_reg : n7301;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7303 = digits_reg[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7304 = n7276 ? enc_digit_reg : n7303;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7305 = digits_reg[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7306 = n7277 ? enc_digit_reg : n7305;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7307 = digits_reg[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7308 = n7278 ? enc_digit_reg : n7307;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7309 = digits_reg[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7310 = n7279 ? enc_digit_reg : n7309;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7311 = digits_reg[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7312 = n7280 ? enc_digit_reg : n7311;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7313 = digits_reg[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7314 = n7281 ? enc_digit_reg : n7313;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7315 = digits_reg[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7316 = n7282 ? enc_digit_reg : n7315;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7317 = {n7316, n7314, n7312, n7310, n7308, n7306, n7304, n7302, n7300, n7298, n7296, n7294, n7292, n7290, n7288, n7286, n7284};
  /* mc68881_packed_decimal_unit.vhd:413:13  */
  assign n7319 = {4'bX, scale_abs_exp_slv};
  /* mc68881_packed_decimal_unit.vhd:653:34  */
  assign n7320 = n7319[scale_bit_idx_reg * 1 +: 1]; //(Bmux)
  /* mc68881_packed_decimal_unit.vhd:653:34  */
  assign n7322 = {60'bX, digits_reg};
  /* mc68881_packed_decimal_unit.vhd:720:25  */
  assign n7323 = n7322[n3963 * 4 +: 4]; //(Bmux)
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7324 = n3970[4]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7325 = ~n7324;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7326 = n3970[3]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7327 = ~n7326;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7328 = n7325 & n7327;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7329 = n7325 & n7326;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7330 = n7324 & n7327;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7331 = n3970[2]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7332 = ~n7331;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7333 = n7328 & n7332;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7334 = n7328 & n7331;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7335 = n7329 & n7332;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7336 = n7329 & n7331;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7337 = n7330 & n7332;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7338 = n3970[1]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7339 = ~n7338;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7340 = n7333 & n7339;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7341 = n7333 & n7338;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7342 = n7334 & n7339;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7343 = n7334 & n7338;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7344 = n7335 & n7339;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7345 = n7335 & n7338;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7346 = n7336 & n7339;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7347 = n7336 & n7338;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7348 = n7337 & n7339;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7349 = n3970[0]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7350 = ~n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7351 = n7340 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7352 = n7340 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7353 = n7341 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7354 = n7341 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7355 = n7342 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7356 = n7342 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7357 = n7343 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7358 = n7343 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7359 = n7344 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7360 = n7344 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7361 = n7345 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7362 = n7345 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7363 = n7346 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7364 = n7346 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7365 = n7347 & n7350;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7366 = n7347 & n7349;
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7367 = n7348 & n7350;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7368 = n510[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7369 = n7351 ? 4'b0000 : n7368;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7370 = n510[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7371 = n7352 ? 4'b0000 : n7370;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7372 = n510[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7373 = n7353 ? 4'b0000 : n7372;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7374 = n510[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7375 = n7354 ? 4'b0000 : n7374;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7376 = n510[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7377 = n7355 ? 4'b0000 : n7376;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7378 = n510[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7379 = n7356 ? 4'b0000 : n7378;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7380 = n510[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7381 = n7357 ? 4'b0000 : n7380;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7382 = n510[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7383 = n7358 ? 4'b0000 : n7382;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7384 = n510[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7385 = n7359 ? 4'b0000 : n7384;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7386 = n510[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7387 = n7360 ? 4'b0000 : n7386;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7388 = n510[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7389 = n7361 ? 4'b0000 : n7388;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7390 = n510[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7391 = n7362 ? 4'b0000 : n7390;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7392 = n510[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7393 = n7363 ? 4'b0000 : n7392;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7394 = n510[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7395 = n7364 ? 4'b0000 : n7394;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7396 = n510[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7397 = n7365 ? 4'b0000 : n7396;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7398 = n510[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7399 = n7366 ? 4'b0000 : n7398;
  /* mc68881_packed_decimal_unit.vhd:255:3  */
  assign n7400 = n510[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7401 = n7367 ? 4'b0000 : n7400;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7402 = {n7401, n7399, n7397, n7395, n7393, n7391, n7389, n7387, n7385, n7383, n7381, n7379, n7377, n7375, n7373, n7371, n7369};
  /* mc68881_packed_decimal_unit.vhd:721:13  */
  assign n7404 = {60'bX, digits_reg};
  /* mc68881_packed_decimal_unit.vhd:747:54  */
  assign n7405 = n7404[n4048 * 4 +: 4]; //(Bmux)
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7406 = n4045[4]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7407 = ~n7406;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7408 = n4045[3]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7409 = ~n7408;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7410 = n7407 & n7409;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7411 = n7407 & n7408;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7412 = n7406 & n7409;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7413 = n4045[2]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7414 = ~n7413;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7415 = n7410 & n7414;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7416 = n7410 & n7413;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7417 = n7411 & n7414;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7418 = n7411 & n7413;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7419 = n7412 & n7414;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7420 = n4045[1]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7421 = ~n7420;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7422 = n7415 & n7421;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7423 = n7415 & n7420;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7424 = n7416 & n7421;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7425 = n7416 & n7420;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7426 = n7417 & n7421;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7427 = n7417 & n7420;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7428 = n7418 & n7421;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7429 = n7418 & n7420;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7430 = n7419 & n7421;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7431 = n4045[0]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7432 = ~n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7433 = n7422 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7434 = n7422 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7435 = n7423 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7436 = n7423 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7437 = n7424 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7438 = n7424 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7439 = n7425 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7440 = n7425 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7441 = n7426 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7442 = n7426 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7443 = n7427 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7444 = n7427 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7445 = n7428 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7446 = n7428 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7447 = n7429 & n7432;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7448 = n7429 & n7431;
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7449 = n7430 & n7432;
  assign n7450 = n510[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7451 = n7433 ? n4054 : n7450;
  assign n7452 = n510[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7453 = n7434 ? n4054 : n7452;
  /* mc68881_packed_decimal_unit.vhd:294:5  */
  assign n7454 = n510[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7455 = n7435 ? n4054 : n7454;
  assign n7456 = n510[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7457 = n7436 ? n4054 : n7456;
  assign n7458 = n510[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7459 = n7437 ? n4054 : n7458;
  /* mc68881_packed_decimal_unit.vhd:294:5  */
  assign n7460 = n510[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7461 = n7438 ? n4054 : n7460;
  assign n7462 = n510[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7463 = n7439 ? n4054 : n7462;
  assign n7464 = n510[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7465 = n7440 ? n4054 : n7464;
  /* mc68881_packed_decimal_unit.vhd:294:5  */
  assign n7466 = n510[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7467 = n7441 ? n4054 : n7466;
  assign n7468 = n510[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7469 = n7442 ? n4054 : n7468;
  assign n7470 = n510[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7471 = n7443 ? n4054 : n7470;
  /* mc68881_packed_decimal_unit.vhd:294:5  */
  assign n7472 = n510[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7473 = n7444 ? n4054 : n7472;
  assign n7474 = n510[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7475 = n7445 ? n4054 : n7474;
  assign n7476 = n510[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7477 = n7446 ? n4054 : n7476;
  /* mc68881_packed_decimal_unit.vhd:294:5  */
  assign n7478 = n510[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7479 = n7447 ? n4054 : n7478;
  assign n7480 = n510[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7481 = n7448 ? n4054 : n7480;
  assign n7482 = n510[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7483 = n7449 ? n4054 : n7482;
  /* mc68881_packed_decimal_unit.vhd:294:5  */
  assign n7484 = {n7483, n7481, n7479, n7477, n7475, n7473, n7471, n7469, n7467, n7465, n7463, n7461, n7459, n7457, n7455, n7453, n7451};
  /* mc68881_packed_decimal_unit.vhd:747:13  */
  assign n7486 = {60'bX, digits_reg};
  /* mc68881_packed_decimal_unit.vhd:768:39  */
  assign n7487 = n7486[n4119 * 4 +: 4]; //(Bmux)
  /* mc68881_packed_decimal_unit.vhd:768:39  */
  assign n7489 = {60'bX, digits_reg};
  /* mc68881_packed_decimal_unit.vhd:781:57  */
  assign n7490 = n7489[n4288 * 4 +: 4]; //(Bmux)
  /* mc68881_packed_decimal_unit.vhd:781:57  */
  assign n7492 = {60'bX, digits_reg};
  /* mc68881_packed_decimal_unit.vhd:815:27  */
  assign n7493 = n7492[n4569 * 4 +: 4]; //(Bmux)
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7494 = n4576[4]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7495 = ~n7494;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7496 = n4576[3]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7497 = ~n7496;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7498 = n7495 & n7497;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7499 = n7495 & n7496;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7500 = n7494 & n7497;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7501 = n4576[2]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7502 = ~n7501;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7503 = n7498 & n7502;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7504 = n7498 & n7501;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7505 = n7499 & n7502;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7506 = n7499 & n7501;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7507 = n7500 & n7502;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7508 = n4576[1]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7509 = ~n7508;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7510 = n7503 & n7509;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7511 = n7503 & n7508;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7512 = n7504 & n7509;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7513 = n7504 & n7508;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7514 = n7505 & n7509;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7515 = n7505 & n7508;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7516 = n7506 & n7509;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7517 = n7506 & n7508;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7518 = n7507 & n7509;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7519 = n4576[0]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7520 = ~n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7521 = n7510 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7522 = n7510 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7523 = n7511 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7524 = n7511 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7525 = n7512 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7526 = n7512 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7527 = n7513 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7528 = n7513 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7529 = n7514 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7530 = n7514 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7531 = n7515 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7532 = n7515 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7533 = n7516 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7534 = n7516 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7535 = n7517 & n7520;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7536 = n7517 & n7519;
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7537 = n7518 & n7520;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7538 = n510[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7539 = n7521 ? 4'b0000 : n7538;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7540 = n510[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7541 = n7522 ? 4'b0000 : n7540;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7542 = n510[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7543 = n7523 ? 4'b0000 : n7542;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7544 = n510[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7545 = n7524 ? 4'b0000 : n7544;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7546 = n510[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7547 = n7525 ? 4'b0000 : n7546;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7548 = n510[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7549 = n7526 ? 4'b0000 : n7548;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7550 = n510[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7551 = n7527 ? 4'b0000 : n7550;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7552 = n510[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7553 = n7528 ? 4'b0000 : n7552;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7554 = n510[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7555 = n7529 ? 4'b0000 : n7554;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7556 = n510[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7557 = n7530 ? 4'b0000 : n7556;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7558 = n510[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7559 = n7531 ? 4'b0000 : n7558;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7560 = n510[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7561 = n7532 ? 4'b0000 : n7560;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7562 = n510[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7563 = n7533 ? 4'b0000 : n7562;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7564 = n510[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7565 = n7534 ? 4'b0000 : n7564;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7566 = n510[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7567 = n7535 ? 4'b0000 : n7566;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7568 = n510[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7569 = n7536 ? 4'b0000 : n7568;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7570 = n510[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7571 = n7537 ? 4'b0000 : n7570;
  /* mc68881_packed_decimal_unit.vhd:336:5  */
  assign n7572 = {n7571, n7569, n7567, n7565, n7563, n7561, n7559, n7557, n7555, n7553, n7551, n7549, n7547, n7545, n7543, n7541, n7539};
  /* mc68881_packed_decimal_unit.vhd:816:15  */
  assign n7574 = {60'bX, digits_reg};
  /* mc68881_packed_decimal_unit.vhd:828:56  */
  assign n7575 = n7574[n4605 * 4 +: 4]; //(Bmux)
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7576 = n4602[4]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7577 = ~n7576;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7578 = n4602[3]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7579 = ~n7578;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7580 = n7577 & n7579;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7581 = n7577 & n7578;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7582 = n7576 & n7579;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7583 = n4602[2]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7584 = ~n7583;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7585 = n7580 & n7584;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7586 = n7580 & n7583;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7587 = n7581 & n7584;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7588 = n7581 & n7583;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7589 = n7582 & n7584;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7590 = n4602[1]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7591 = ~n7590;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7592 = n7585 & n7591;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7593 = n7585 & n7590;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7594 = n7586 & n7591;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7595 = n7586 & n7590;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7596 = n7587 & n7591;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7597 = n7587 & n7590;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7598 = n7588 & n7591;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7599 = n7588 & n7590;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7600 = n7589 & n7591;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7601 = n4602[0]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7602 = ~n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7603 = n7592 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7604 = n7592 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7605 = n7593 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7606 = n7593 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7607 = n7594 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7608 = n7594 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7609 = n7595 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7610 = n7595 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7611 = n7596 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7612 = n7596 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7613 = n7597 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7614 = n7597 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7615 = n7598 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7616 = n7598 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7617 = n7599 & n7602;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7618 = n7599 & n7601;
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7619 = n7600 & n7602;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n7620 = n510[3:0]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7621 = n7603 ? n4611 : n7620;
  assign n7622 = n510[7:4]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7623 = n7604 ? n4611 : n7622;
  assign n7624 = n510[11:8]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7625 = n7605 ? n4611 : n7624;
  /* mc68881_packed_decimal_unit.vhd:454:7  */
  assign n7626 = n510[15:12]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7627 = n7606 ? n4611 : n7626;
  assign n7628 = n510[19:16]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7629 = n7607 ? n4611 : n7628;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7630 = n510[23:20]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7631 = n7608 ? n4611 : n7630;
  assign n7632 = n510[27:24]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7633 = n7609 ? n4611 : n7632;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7634 = n510[31:28]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7635 = n7610 ? n4611 : n7634;
  assign n7636 = n510[35:32]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7637 = n7611 ? n4611 : n7636;
  assign n7638 = n510[39:36]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7639 = n7612 ? n4611 : n7638;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7640 = n510[43:40]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7641 = n7613 ? n4611 : n7640;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7642 = n510[47:44]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7643 = n7614 ? n4611 : n7642;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7644 = n510[51:48]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7645 = n7615 ? n4611 : n7644;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7646 = n510[55:52]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7647 = n7616 ? n4611 : n7646;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7648 = n510[59:56]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7649 = n7617 ? n4611 : n7648;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7650 = n510[63:60]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7651 = n7618 ? n4611 : n7650;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7652 = n510[67:64]; // extract
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7653 = n7619 ? n4611 : n7652;
  /* mc68881_packed_decimal_unit.vhd:455:7  */
  assign n7654 = {n7653, n7651, n7649, n7647, n7645, n7643, n7641, n7639, n7637, n7635, n7633, n7631, n7629, n7627, n7625, n7623, n7621};
  /* mc68881_packed_decimal_unit.vhd:828:15  */
  assign n7656 = {60'bX, digits_reg};
  /* mc68881_packed_decimal_unit.vhd:871:47  */
  assign n7657 = n7656[n5133 * 4 +: 4]; //(Bmux)
endmodule

