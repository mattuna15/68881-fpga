module mc68881_sgl_ops_unit
  (input  clk,
   input  reset_n,
   input  start,
   input  [5:0] op_sel,
   input  [79:0] a_in,
   input  [79:0] b_in,
   input  [1:0] round_mode,
   output busy,
   output done,
   output [79:0] result);
  reg [2:0] state_reg;
  reg [5:0] op_reg;
  reg [79:0] a_reg;
  reg [79:0] b_reg;
  reg [1:0] rm_reg;
  reg done_reg;
  reg [79:0] result_reg;
  reg [23:0] mul_a_reg;
  reg [23:0] mul_b_reg;
  reg [47:0] mul_acc_reg;
  reg [4:0] mul_idx_reg;
  reg mul_sign_reg;
  reg [31:0] mul_exp_base_reg;
  reg [23:0] div_divisor_reg;
  reg [24:0] div_rem_reg;
  reg [23:0] div_quot_reg;
  reg [4:0] div_idx_reg;
  reg div_sign_reg;
  reg [31:0] div_exp_base_reg;
  wire n42;
  wire [2:0] n45;
  wire [5:0] n46;
  wire [79:0] n47;
  wire [79:0] n48;
  wire [1:0] n49;
  wire n51;
  wire n58;
  wire [14:0] n61;
  wire [63:0] n63;
  wire [79:0] n64;
  wire n71;
  wire [14:0] n74;
  wire [63:0] n76;
  wire [79:0] n77;
  wire n79;
  wire n81;
  wire n93;
  wire [14:0] n96;
  wire [63:0] n98;
  wire [79:0] n99;
  wire [14:0] n100;
  wire n102;
  wire n114;
  wire [14:0] n117;
  wire [63:0] n119;
  wire [79:0] n120;
  localparam [63:0] n123 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n124;
  wire [14:0] n125;
  wire n127;
  wire [63:0] n128;
  wire n130;
  wire [63:0] n131;
  wire [63:0] n132;
  wire n133;
  wire n134;
  wire n135;
  wire n136;
  wire n137;
  wire n149;
  wire [14:0] n152;
  wire [63:0] n154;
  wire [79:0] n155;
  wire [14:0] n156;
  wire n158;
  wire n170;
  wire [14:0] n173;
  wire [63:0] n175;
  wire [79:0] n176;
  localparam [63:0] n179 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n180;
  wire [14:0] n181;
  wire n183;
  wire [63:0] n184;
  wire n186;
  wire [63:0] n187;
  wire [63:0] n188;
  wire n189;
  wire n190;
  wire n191;
  wire n192;
  wire n193;
  wire n194;
  wire n207;
  wire [14:0] n210;
  wire [63:0] n212;
  wire [79:0] n213;
  wire [14:0] n214;
  wire n216;
  wire n228;
  wire [14:0] n231;
  wire [63:0] n233;
  wire [79:0] n234;
  localparam [63:0] n237 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n238;
  wire [14:0] n239;
  wire n241;
  wire [63:0] n242;
  wire n244;
  wire [63:0] n245;
  wire [63:0] n246;
  wire n247;
  wire n248;
  wire n249;
  wire n250;
  wire n251;
  wire n263;
  wire [14:0] n266;
  wire [63:0] n268;
  wire [79:0] n269;
  wire [14:0] n270;
  wire n272;
  wire n284;
  wire [14:0] n287;
  wire [63:0] n289;
  wire [79:0] n290;
  localparam [63:0] n293 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n294;
  wire [14:0] n295;
  wire n297;
  wire [63:0] n298;
  wire n300;
  wire [63:0] n301;
  wire [63:0] n302;
  wire n303;
  wire n304;
  wire n305;
  wire n306;
  wire n307;
  wire n325;
  wire [14:0] n328;
  wire [63:0] n330;
  wire [79:0] n331;
  wire [14:0] n332;
  wire n334;
  wire n335;
  wire n336;
  wire n337;
  wire [62:0] n338;
  wire n340;
  wire n341;
  wire n353;
  wire [14:0] n356;
  wire [63:0] n358;
  wire [79:0] n359;
  wire [14:0] n360;
  wire n362;
  wire n363;
  wire n364;
  wire n365;
  wire [62:0] n366;
  wire n368;
  wire n369;
  wire n371;
  wire n374;
  wire n376;
  wire [79:0] n377;
  wire [79:0] n378;
  wire [79:0] n379;
  wire [79:0] n380;
  wire [15:0] n383;
  wire [62:0] n384;
  wire [79:0] n385;
  wire [80:0] n386;
  wire [79:0] n388;
  wire n400;
  wire [14:0] n403;
  wire [63:0] n405;
  wire [79:0] n406;
  localparam [63:0] n409 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n410;
  wire [14:0] n411;
  wire n413;
  wire [63:0] n414;
  wire n416;
  wire [63:0] n417;
  wire [63:0] n418;
  wire n419;
  wire n420;
  wire n421;
  wire n433;
  wire [14:0] n436;
  wire [63:0] n438;
  wire [79:0] n439;
  localparam [63:0] n442 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n443;
  wire [14:0] n444;
  wire n446;
  wire [63:0] n447;
  wire n449;
  wire [63:0] n450;
  wire [63:0] n451;
  wire n452;
  wire n453;
  wire n454;
  wire n455;
  wire n467;
  wire [14:0] n470;
  wire [63:0] n472;
  wire [79:0] n473;
  wire [14:0] n474;
  wire n476;
  wire [63:0] n477;
  wire n479;
  wire n480;
  wire n492;
  wire [14:0] n495;
  wire [63:0] n497;
  wire [79:0] n498;
  wire [14:0] n499;
  wire n501;
  wire [63:0] n502;
  wire n504;
  wire n505;
  wire n506;
  wire n509;
  wire n510;
  wire n511;
  wire [79:0] n520;
  wire n521;
  wire [79:0] n524;
  wire [14:0] n525;
  wire [79:0] n527;
  wire [63:0] n528;
  wire [79:0] n529;
  wire [79:0] n531;
  wire n545;
  wire [14:0] n548;
  wire [63:0] n550;
  wire [79:0] n551;
  wire [14:0] n552;
  wire n554;
  wire [63:0] n555;
  wire n557;
  wire n558;
  wire n570;
  wire [14:0] n573;
  wire [63:0] n575;
  wire [79:0] n576;
  wire [14:0] n577;
  wire n579;
  wire [63:0] n580;
  wire n582;
  wire n583;
  wire n584;
  wire [23:0] n585;
  wire [23:0] n586;
  wire n587;
  wire n588;
  wire n589;
  wire [14:0] n590;
  wire [30:0] n591;
  wire [31:0] n592;
  wire [14:0] n593;
  wire [30:0] n594;
  wire [31:0] n595;
  wire [31:0] n596;
  wire [31:0] n598;
  wire [2:0] n601;
  wire [79:0] n603;
  wire [23:0] n604;
  wire [23:0] n605;
  wire [47:0] n607;
  wire [4:0] n609;
  wire n610;
  wire [31:0] n611;
  wire [2:0] n613;
  wire [79:0] n614;
  wire [23:0] n615;
  wire [23:0] n616;
  wire [47:0] n617;
  wire [4:0] n618;
  wire n619;
  wire [31:0] n620;
  wire [2:0] n623;
  wire [79:0] n624;
  wire [23:0] n625;
  wire [23:0] n626;
  wire [47:0] n627;
  wire [4:0] n628;
  wire n629;
  wire [31:0] n630;
  wire n634;
  wire n646;
  wire [14:0] n649;
  wire [63:0] n651;
  wire [79:0] n652;
  wire [14:0] n653;
  wire n655;
  wire n667;
  wire [14:0] n670;
  wire [63:0] n672;
  wire [79:0] n673;
  localparam [63:0] n676 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n677;
  wire [14:0] n678;
  wire n680;
  wire [63:0] n681;
  wire n683;
  wire [63:0] n684;
  wire [63:0] n685;
  wire n686;
  wire n687;
  wire n688;
  wire n689;
  wire n690;
  wire n702;
  wire [14:0] n705;
  wire [63:0] n707;
  wire [79:0] n708;
  wire [14:0] n709;
  wire n711;
  wire n723;
  wire [14:0] n726;
  wire [63:0] n728;
  wire [79:0] n729;
  localparam [63:0] n732 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n733;
  wire [14:0] n734;
  wire n736;
  wire [63:0] n737;
  wire n739;
  wire [63:0] n740;
  wire [63:0] n741;
  wire n742;
  wire n743;
  wire n744;
  wire n745;
  wire n746;
  wire n747;
  wire n760;
  wire [14:0] n763;
  wire [63:0] n765;
  wire [79:0] n766;
  wire [14:0] n767;
  wire n769;
  wire n781;
  wire [14:0] n784;
  wire [63:0] n786;
  wire [79:0] n787;
  localparam [63:0] n790 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n791;
  wire [14:0] n792;
  wire n794;
  wire [63:0] n795;
  wire n797;
  wire [63:0] n798;
  wire [63:0] n799;
  wire n800;
  wire n801;
  wire n802;
  wire n803;
  wire n804;
  wire n816;
  wire [14:0] n819;
  wire [63:0] n821;
  wire [79:0] n822;
  wire [14:0] n823;
  wire n825;
  wire n837;
  wire [14:0] n840;
  wire [63:0] n842;
  wire [79:0] n843;
  localparam [63:0] n846 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n847;
  wire [14:0] n848;
  wire n850;
  wire [63:0] n851;
  wire n853;
  wire [63:0] n854;
  wire [63:0] n855;
  wire n856;
  wire n857;
  wire n858;
  wire n859;
  wire n860;
  wire n878;
  wire [14:0] n881;
  wire [63:0] n883;
  wire [79:0] n884;
  wire [14:0] n885;
  wire n887;
  wire n888;
  wire n889;
  wire n890;
  wire [62:0] n891;
  wire n893;
  wire n894;
  wire n906;
  wire [14:0] n909;
  wire [63:0] n911;
  wire [79:0] n912;
  wire [14:0] n913;
  wire n915;
  wire n916;
  wire n917;
  wire n918;
  wire [62:0] n919;
  wire n921;
  wire n922;
  wire n924;
  wire n927;
  wire n929;
  wire [79:0] n930;
  wire [79:0] n931;
  wire [79:0] n932;
  wire [79:0] n933;
  wire [15:0] n936;
  wire [62:0] n937;
  wire [79:0] n938;
  wire [80:0] n939;
  wire [79:0] n941;
  wire n953;
  wire [14:0] n956;
  wire [63:0] n958;
  wire [79:0] n959;
  wire [14:0] n960;
  wire n962;
  wire [63:0] n963;
  wire n965;
  wire n966;
  wire n978;
  wire [14:0] n981;
  wire [63:0] n983;
  wire [79:0] n984;
  wire [14:0] n985;
  wire n987;
  wire [63:0] n988;
  wire n990;
  wire n991;
  wire n994;
  wire n995;
  wire n996;
  wire [79:0] n1004;
  wire n1005;
  wire [79:0] n1008;
  wire [14:0] n1009;
  wire [79:0] n1011;
  wire [63:0] n1012;
  wire [79:0] n1013;
  wire [79:0] n1015;
  wire n1029;
  wire [14:0] n1032;
  wire [63:0] n1034;
  wire [79:0] n1035;
  wire [14:0] n1036;
  wire n1038;
  wire [63:0] n1039;
  wire n1041;
  wire n1042;
  wire n1054;
  wire [14:0] n1057;
  wire [63:0] n1059;
  wire [79:0] n1060;
  localparam [63:0] n1063 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1064;
  wire [14:0] n1065;
  wire n1067;
  wire [63:0] n1068;
  wire n1070;
  wire [63:0] n1071;
  wire [63:0] n1072;
  wire n1073;
  wire n1074;
  wire n1075;
  wire n1087;
  wire [14:0] n1090;
  wire [63:0] n1092;
  wire [79:0] n1093;
  localparam [63:0] n1096 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1097;
  wire [14:0] n1098;
  wire n1100;
  wire [63:0] n1101;
  wire n1103;
  wire [63:0] n1104;
  wire [63:0] n1105;
  wire n1106;
  wire n1107;
  wire n1108;
  wire n1109;
  wire n1123;
  wire [14:0] n1126;
  wire [63:0] n1128;
  wire [79:0] n1129;
  localparam [63:0] n1132 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1133;
  wire [14:0] n1134;
  wire n1136;
  wire [63:0] n1137;
  wire n1139;
  wire [63:0] n1140;
  wire [63:0] n1141;
  wire n1142;
  wire n1143;
  wire n1144;
  wire n1145;
  wire n1146;
  wire n1147;
  wire [79:0] n1155;
  wire n1156;
  wire [79:0] n1159;
  wire [14:0] n1160;
  wire [79:0] n1162;
  wire [63:0] n1163;
  wire [79:0] n1164;
  wire n1176;
  wire [14:0] n1179;
  wire [63:0] n1181;
  wire [79:0] n1182;
  localparam [63:0] n1185 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1186;
  wire [14:0] n1187;
  wire n1189;
  wire [63:0] n1190;
  wire n1192;
  wire [63:0] n1193;
  wire [63:0] n1194;
  wire n1195;
  wire n1196;
  wire n1197;
  wire [23:0] n1198;
  wire [23:0] n1199;
  wire [23:0] n1200;
  wire n1201;
  localparam [23:0] n1203 = 24'b000000000000000000000000;
  wire [22:0] n1204;
  wire [23:0] n1205;
  wire [23:0] n1206;
  wire [23:0] n1207;
  wire [24:0] n1208;
  wire [23:0] n1209;
  wire [24:0] n1210;
  wire [24:0] n1211;
  wire [23:0] n1212;
  wire [23:0] n1214;
  wire n1215;
  wire n1216;
  wire n1217;
  wire [14:0] n1218;
  wire [30:0] n1219;
  wire [31:0] n1220;
  wire [14:0] n1221;
  wire [30:0] n1222;
  wire [31:0] n1223;
  wire [31:0] n1224;
  wire [31:0] n1226;
  wire [2:0] n1229;
  wire [79:0] n1231;
  wire [23:0] n1232;
  wire [24:0] n1233;
  wire [23:0] n1234;
  wire [4:0] n1236;
  wire n1237;
  wire [31:0] n1238;
  wire [2:0] n1240;
  wire [79:0] n1241;
  wire [23:0] n1242;
  wire [24:0] n1243;
  wire [23:0] n1244;
  wire [4:0] n1245;
  wire n1246;
  wire [31:0] n1247;
  wire [2:0] n1251;
  wire [79:0] n1253;
  wire [23:0] n1254;
  wire [24:0] n1255;
  wire [23:0] n1256;
  wire [4:0] n1257;
  wire n1258;
  wire [31:0] n1259;
  wire [2:0] n1262;
  wire [79:0] n1264;
  wire [23:0] n1265;
  wire [24:0] n1266;
  wire [23:0] n1267;
  wire [4:0] n1268;
  wire n1269;
  wire [31:0] n1270;
  wire [2:0] n1273;
  wire [79:0] n1274;
  wire [23:0] n1275;
  wire [24:0] n1276;
  wire [23:0] n1277;
  wire [4:0] n1278;
  wire n1279;
  wire [31:0] n1280;
  wire [2:0] n1283;
  wire [79:0] n1284;
  wire [23:0] n1285;
  wire [24:0] n1286;
  wire [23:0] n1287;
  wire [4:0] n1288;
  wire n1289;
  wire [31:0] n1290;
  wire [2:0] n1294;
  wire [79:0] n1296;
  wire [23:0] n1297;
  wire [24:0] n1298;
  wire [23:0] n1299;
  wire [4:0] n1300;
  wire n1301;
  wire [31:0] n1302;
  wire [2:0] n1305;
  wire [79:0] n1306;
  wire [23:0] n1307;
  wire [23:0] n1308;
  wire [47:0] n1309;
  wire [4:0] n1310;
  wire n1311;
  wire [31:0] n1312;
  wire [23:0] n1313;
  wire [24:0] n1314;
  wire [23:0] n1315;
  wire [4:0] n1316;
  wire n1317;
  wire [31:0] n1318;
  wire [2:0] n1322;
  wire [79:0] n1323;
  wire [23:0] n1324;
  wire [23:0] n1325;
  wire [47:0] n1326;
  wire [4:0] n1327;
  wire n1328;
  wire [31:0] n1329;
  wire [23:0] n1330;
  wire [24:0] n1331;
  wire [23:0] n1332;
  wire [4:0] n1333;
  wire n1334;
  wire [31:0] n1335;
  wire n1339;
  wire n1359;
  wire [14:0] n1362;
  wire [63:0] n1364;
  wire [79:0] n1365;
  wire n1377;
  wire [14:0] n1380;
  wire [63:0] n1382;
  wire [79:0] n1383;
  wire [14:0] n1384;
  wire n1386;
  wire n1398;
  wire [14:0] n1401;
  wire [63:0] n1403;
  wire [79:0] n1404;
  localparam [63:0] n1407 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1408;
  wire [14:0] n1409;
  wire n1411;
  wire [63:0] n1412;
  wire n1414;
  wire [63:0] n1415;
  wire [63:0] n1416;
  wire n1417;
  wire n1418;
  wire n1419;
  wire n1420;
  wire n1421;
  wire n1433;
  wire [14:0] n1436;
  wire [63:0] n1438;
  wire [79:0] n1439;
  wire [14:0] n1440;
  wire n1442;
  wire n1454;
  wire [14:0] n1457;
  wire [63:0] n1459;
  wire [79:0] n1460;
  localparam [63:0] n1463 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1464;
  wire [14:0] n1465;
  wire n1467;
  wire [63:0] n1468;
  wire n1470;
  wire [63:0] n1471;
  wire [63:0] n1472;
  wire n1473;
  wire n1474;
  wire n1475;
  wire n1476;
  wire n1477;
  wire n1478;
  wire n1491;
  wire [14:0] n1494;
  wire [63:0] n1496;
  wire [79:0] n1497;
  wire [14:0] n1498;
  wire n1500;
  wire n1512;
  wire [14:0] n1515;
  wire [63:0] n1517;
  wire [79:0] n1518;
  localparam [63:0] n1521 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1522;
  wire [14:0] n1523;
  wire n1525;
  wire [63:0] n1526;
  wire n1528;
  wire [63:0] n1529;
  wire [63:0] n1530;
  wire n1531;
  wire n1532;
  wire n1533;
  wire n1534;
  wire n1535;
  wire n1547;
  wire [14:0] n1550;
  wire [63:0] n1552;
  wire [79:0] n1553;
  wire [14:0] n1554;
  wire n1556;
  wire n1568;
  wire [14:0] n1571;
  wire [63:0] n1573;
  wire [79:0] n1574;
  localparam [63:0] n1577 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1578;
  wire [14:0] n1579;
  wire n1581;
  wire [63:0] n1582;
  wire n1584;
  wire [63:0] n1585;
  wire [63:0] n1586;
  wire n1587;
  wire n1588;
  wire n1589;
  wire n1590;
  wire n1591;
  wire n1609;
  wire [14:0] n1612;
  wire [63:0] n1614;
  wire [79:0] n1615;
  wire [14:0] n1616;
  wire n1618;
  wire n1619;
  wire n1620;
  wire n1621;
  wire [62:0] n1622;
  wire n1624;
  wire n1625;
  wire n1637;
  wire [14:0] n1640;
  wire [63:0] n1642;
  wire [79:0] n1643;
  wire [14:0] n1644;
  wire n1646;
  wire n1647;
  wire n1648;
  wire n1649;
  wire [62:0] n1650;
  wire n1652;
  wire n1653;
  wire n1655;
  wire n1658;
  wire n1660;
  wire [79:0] n1661;
  wire [79:0] n1662;
  wire [79:0] n1663;
  wire [79:0] n1664;
  wire [15:0] n1667;
  wire [62:0] n1668;
  wire [79:0] n1669;
  wire [80:0] n1670;
  wire [79:0] n1672;
  wire [14:0] n1673;
  wire n1675;
  wire n1687;
  wire [14:0] n1690;
  wire [63:0] n1692;
  wire [79:0] n1693;
  localparam [63:0] n1696 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n1697;
  wire [14:0] n1698;
  wire n1700;
  wire [63:0] n1701;
  wire n1703;
  wire [63:0] n1704;
  wire [63:0] n1705;
  wire n1706;
  wire n1707;
  wire n1708;
  wire n1709;
  wire n1721;
  wire [14:0] n1724;
  wire [63:0] n1726;
  wire [79:0] n1727;
  wire [14:0] n1732;
  wire n1734;
  wire [14:0] n1735;
  wire n1737;
  wire n1738;
  wire n1742;
  wire [31:0] n1748;
  wire [14:0] n1749;
  wire [30:0] n1750;
  wire [31:0] n1751;
  wire [31:0] n1753;
  wire [31:0] n1756;
  wire [31:0] n1758;
  wire n1761;
  wire n1764;
  wire [31:0] n1767;
  wire n1768;
  wire n1770;
  wire n1771;
  wire n1773;
  wire n1775;
  wire n1776;
  wire n1779;
  wire [31:0] n1782;
  wire n1783;
  wire n1785;
  wire n1786;
  wire n1788;
  wire n1791;
  wire [31:0] n1794;
  wire n1795;
  wire [31:0] n1797;
  wire n1798;
  wire n1800;
  wire [63:0] n1801;
  wire [31:0] n1803;
  wire [30:0] n1804;
  wire [63:0] n1805;
  wire [63:0] n1807;
  wire n1810;
  wire n1811;
  wire n1814;
  wire [31:0] n1817;
  wire n1818;
  wire n1820;
  wire n1821;
  wire n1823;
  wire n1826;
  wire [31:0] n1829;
  wire n1830;
  wire [31:0] n1832;
  wire n1833;
  wire n1835;
  wire [30:0] n1836;
  wire [31:0] n1837;
  wire [31:0] n1839;
  wire n1841;
  wire [31:0] n1842;
  wire n1844;
  wire [31:0] n1847;
  wire n1848;
  wire n1850;
  wire n1851;
  wire n1853;
  wire [31:0] n1858;
  wire [14:0] n1859;
  wire [30:0] n1860;
  wire [31:0] n1861;
  wire [31:0] n1862;
  wire n1863;
  wire n1865;
  wire n1869;
  wire [30:0] n1871;
  wire [14:0] n1872;
  wire [63:0] n1873;
  wire [78:0] n1874;
  wire [78:0] n1875;
  wire [78:0] n1876;
  wire [78:0] n1877;
  wire [78:0] n1878;
  wire [79:0] n1885;
  wire n1886;
  wire [79:0] n1889;
  wire [14:0] n1890;
  wire [79:0] n1892;
  wire [63:0] n1893;
  wire [79:0] n1894;
  wire [79:0] n1895;
  wire [79:0] n1900;
  wire n1906;
  wire n1907;
  wire [47:0] n1908;
  wire [30:0] n1909;
  wire [47:0] n1910;
  wire [47:0] n1911;
  wire [47:0] n1912;
  wire [23:0] n1914;
  wire [31:0] n1915;
  wire n1917;
  wire [31:0] n1918;
  wire [31:0] n1920;
  wire [4:0] n1921;
  wire [2:0] n1923;
  wire [4:0] n1924;
  wire n1926;
  wire [24:0] n1928;
  wire [24:0] n1930;
  wire n1931;
  wire [24:0] n1933;
  wire [24:0] n1934;
  wire [24:0] n1941;
  wire [23:0] n1942;
  wire [31:0] n1943;
  wire n1945;
  wire [31:0] n1946;
  wire [31:0] n1948;
  wire [4:0] n1949;
  wire [2:0] n1951;
  wire [4:0] n1952;
  wire n1954;
  wire n1956;
  wire n1957;
  wire [23:0] n1958;
  wire n1959;
  wire [22:0] n1960;
  wire n1962;
  wire n1965;
  wire [31:0] n1967;
  wire [23:0] n1968;
  wire n1969;
  wire [21:0] n1970;
  wire n1972;
  wire n1975;
  wire [23:0] n1976;
  wire [31:0] n1977;
  wire n1978;
  wire n1979;
  wire n1981;
  wire n1987;
  wire n1988;
  wire n1991;
  wire n1993;
  wire n1995;
  wire n1996;
  wire n1997;
  wire n2000;
  wire n2002;
  wire n2003;
  wire n2004;
  wire n2005;
  wire n2008;
  wire n2010;
  wire [3:0] n2011;
  reg n2014;
  wire [24:0] n2017;
  wire [24:0] n2019;
  wire n2020;
  wire [23:0] n2021;
  wire [31:0] n2023;
  wire [23:0] n2024;
  wire [23:0] n2025;
  wire [31:0] n2026;
  wire [23:0] n2027;
  wire n2029;
  wire n2031;
  wire n2033;
  wire [79:0] n2041;
  wire n2042;
  wire [79:0] n2045;
  wire [14:0] n2046;
  wire [79:0] n2048;
  wire [63:0] n2049;
  wire [79:0] n2050;
  wire [30:0] n2051;
  wire [14:0] n2052;
  wire [63:0] n2054;
  wire [79:0] n2061;
  wire n2062;
  wire [79:0] n2065;
  wire [14:0] n2066;
  wire [79:0] n2068;
  wire [63:0] n2069;
  wire [79:0] n2070;
  wire [79:0] n2071;
  wire [79:0] n2078;
  wire [79:0] n2084;
  wire n2097;
  wire n2099;
  wire [24:0] n2101;
  wire [24:0] n2103;
  wire n2104;
  wire [24:0] n2106;
  wire [24:0] n2107;
  wire n2110;
  wire [24:0] n2111;
  wire n2113;
  wire n2116;
  wire n2117;
  wire n2118;
  wire [22:0] n2119;
  wire [23:0] n2120;
  wire [24:0] n2122;
  wire [24:0] n2124;
  wire n2125;
  wire [24:0] n2127;
  wire [24:0] n2128;
  wire n2131;
  wire [24:0] n2132;
  wire n2134;
  wire n2136;
  wire [31:0] n2138;
  wire [23:0] n2139;
  wire [31:0] n2140;
  wire n2141;
  wire n2142;
  wire n2145;
  wire n2151;
  wire n2152;
  wire n2155;
  wire n2157;
  wire n2159;
  wire n2160;
  wire n2161;
  wire n2164;
  wire n2166;
  wire n2167;
  wire n2168;
  wire n2169;
  wire n2172;
  wire n2174;
  wire [3:0] n2175;
  reg n2178;
  wire [24:0] n2181;
  wire [24:0] n2183;
  wire n2184;
  wire [23:0] n2185;
  wire [31:0] n2187;
  wire [23:0] n2188;
  wire [23:0] n2189;
  wire [31:0] n2190;
  wire [23:0] n2191;
  wire n2193;
  wire n2195;
  wire n2197;
  wire [79:0] n2205;
  wire n2206;
  wire [79:0] n2209;
  wire [14:0] n2210;
  wire [79:0] n2212;
  wire [63:0] n2213;
  wire [79:0] n2214;
  wire [30:0] n2215;
  wire [14:0] n2216;
  wire [63:0] n2218;
  wire [79:0] n2225;
  wire n2226;
  wire [79:0] n2229;
  wire [14:0] n2230;
  wire [79:0] n2232;
  wire [63:0] n2233;
  wire [79:0] n2234;
  wire [79:0] n2235;
  wire [79:0] n2242;
  wire [79:0] n2248;
  wire n2264;
  wire n2266;
  wire [7:0] n2267;
  reg [2:0] n2273;
  reg [5:0] n2275;
  reg [79:0] n2277;
  reg [79:0] n2279;
  reg [1:0] n2281;
  reg n2285;
  reg [79:0] n2288;
  reg [23:0] n2290;
  reg [23:0] n2292;
  reg [47:0] n2294;
  reg [4:0] n2296;
  reg n2298;
  reg [31:0] n2300;
  reg [23:0] n2302;
  reg [24:0] n2304;
  reg [23:0] n2306;
  reg [4:0] n2308;
  reg n2310;
  reg [31:0] n2312;
  wire n2513;
  wire n2514;
  reg [2:0] n2516;
  reg [5:0] n2517;
  reg [79:0] n2518;
  reg [79:0] n2519;
  reg [1:0] n2520;
  reg n2521;
  reg [79:0] n2522;
  reg [23:0] n2523;
  reg [23:0] n2524;
  reg [47:0] n2525;
  reg [4:0] n2526;
  reg n2527;
  reg [31:0] n2528;
  reg [23:0] n2529;
  reg [24:0] n2530;
  reg [23:0] n2531;
  reg [4:0] n2532;
  reg n2533;
  reg [31:0] n2534;
  wire n2535;
  wire n2536;
  wire n2537;
  wire n2538;
  wire n2539;
  wire n2540;
  wire n2541;
  wire n2542;
  wire n2543;
  wire n2544;
  wire n2545;
  wire n2546;
  wire n2547;
  wire n2548;
  wire n2549;
  wire n2550;
  wire n2551;
  wire n2552;
  wire n2553;
  wire n2554;
  wire n2555;
  wire n2556;
  wire n2557;
  wire n2558;
  wire n2559;
  wire n2560;
  wire n2561;
  wire n2562;
  wire n2563;
  wire n2564;
  wire n2565;
  wire n2566;
  wire n2567;
  wire n2568;
  wire n2569;
  wire n2570;
  wire n2571;
  wire n2572;
  wire n2573;
  wire n2574;
  wire n2575;
  wire n2576;
  wire n2577;
  wire n2578;
  wire n2579;
  wire n2580;
  wire n2581;
  wire n2582;
  wire n2583;
  wire n2584;
  wire n2585;
  wire n2586;
  wire n2587;
  wire n2588;
  wire n2589;
  wire n2590;
  wire n2591;
  wire n2592;
  wire n2593;
  wire n2594;
  wire n2595;
  wire n2596;
  wire n2597;
  wire n2598;
  wire n2599;
  wire n2600;
  wire n2601;
  wire n2602;
  wire n2603;
  wire n2604;
  wire n2605;
  wire n2606;
  wire n2607;
  wire n2608;
  wire n2609;
  wire n2610;
  wire n2611;
  wire n2612;
  wire n2613;
  wire n2614;
  wire n2615;
  wire n2616;
  wire n2617;
  wire n2618;
  wire n2619;
  wire n2620;
  wire n2621;
  wire n2622;
  wire n2623;
  wire n2624;
  wire n2625;
  wire n2626;
  wire n2627;
  wire n2628;
  wire n2629;
  wire n2630;
  wire n2631;
  wire n2632;
  wire n2633;
  wire n2634;
  wire n2635;
  wire n2636;
  wire n2637;
  wire [23:0] n2638;
  wire n2639;
  wire n2640;
  wire n2641;
  wire n2642;
  wire n2643;
  wire n2644;
  wire n2645;
  wire n2646;
  wire n2647;
  wire n2648;
  wire n2649;
  wire n2650;
  wire n2651;
  wire n2652;
  wire n2653;
  wire n2654;
  wire n2655;
  wire n2656;
  wire n2657;
  wire n2658;
  wire n2659;
  wire n2660;
  wire n2661;
  wire n2662;
  wire n2663;
  wire n2664;
  wire n2665;
  wire n2666;
  wire n2667;
  wire n2668;
  wire n2669;
  wire n2670;
  wire n2671;
  wire n2672;
  wire n2673;
  wire n2674;
  wire n2675;
  wire n2676;
  wire n2677;
  wire n2678;
  wire n2679;
  wire n2680;
  wire n2681;
  wire n2682;
  wire n2683;
  wire n2684;
  wire n2685;
  wire n2686;
  wire n2687;
  wire n2688;
  wire n2689;
  wire n2690;
  wire n2691;
  wire n2692;
  wire n2693;
  wire n2694;
  wire n2695;
  wire n2696;
  wire n2697;
  wire n2698;
  wire n2699;
  wire n2700;
  wire n2701;
  wire n2702;
  wire n2703;
  wire n2704;
  wire n2705;
  wire n2706;
  wire n2707;
  wire n2708;
  wire n2709;
  wire n2710;
  wire n2711;
  wire n2712;
  wire n2713;
  wire n2714;
  wire n2715;
  wire n2716;
  wire n2717;
  wire n2718;
  wire n2719;
  wire n2720;
  wire n2721;
  wire n2722;
  wire n2723;
  wire n2724;
  wire n2725;
  wire n2726;
  wire n2727;
  wire n2728;
  wire n2729;
  wire n2730;
  wire n2731;
  wire n2732;
  wire n2733;
  wire n2734;
  wire n2735;
  wire n2736;
  wire n2737;
  wire n2738;
  wire n2739;
  wire n2740;
  wire n2741;
  wire [23:0] n2742;
  assign busy = n2514; //(module output)
  assign done = done_reg; //(module output)
  assign result = result_reg; //(module output)
  /* mc68881_sgl_ops_unit.vhd:44:10  */
  always @*
    state_reg = n2516; // (isignal)
  initial
    state_reg = 3'b000;
  /* mc68881_sgl_ops_unit.vhd:45:10  */
  always @*
    op_reg = n2517; // (isignal)
  initial
    op_reg = 6'b000000;
  /* mc68881_sgl_ops_unit.vhd:46:10  */
  always @*
    a_reg = n2518; // (isignal)
  initial
    a_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:47:10  */
  always @*
    b_reg = n2519; // (isignal)
  initial
    b_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:48:10  */
  always @*
    rm_reg = n2520; // (isignal)
  initial
    rm_reg = 2'b00;
  /* mc68881_sgl_ops_unit.vhd:49:10  */
  always @*
    done_reg = n2521; // (isignal)
  initial
    done_reg = 1'b0;
  /* mc68881_sgl_ops_unit.vhd:50:10  */
  always @*
    result_reg = n2522; // (isignal)
  initial
    result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:52:10  */
  always @*
    mul_a_reg = n2523; // (isignal)
  initial
    mul_a_reg = 24'b000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:53:10  */
  always @*
    mul_b_reg = n2524; // (isignal)
  initial
    mul_b_reg = 24'b000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:54:10  */
  always @*
    mul_acc_reg = n2525; // (isignal)
  initial
    mul_acc_reg = 48'b000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:55:10  */
  always @*
    mul_idx_reg = n2526; // (isignal)
  initial
    mul_idx_reg = 5'b00000;
  /* mc68881_sgl_ops_unit.vhd:56:10  */
  always @*
    mul_sign_reg = n2527; // (isignal)
  initial
    mul_sign_reg = 1'b0;
  /* mc68881_sgl_ops_unit.vhd:57:10  */
  always @*
    mul_exp_base_reg = n2528; // (isignal)
  initial
    mul_exp_base_reg = 32'b00000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:59:10  */
  always @*
    div_divisor_reg = n2529; // (isignal)
  initial
    div_divisor_reg = 24'b000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:60:10  */
  always @*
    div_rem_reg = n2530; // (isignal)
  initial
    div_rem_reg = 25'b0000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:61:10  */
  always @*
    div_quot_reg = n2531; // (isignal)
  initial
    div_quot_reg = 24'b000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:62:10  */
  always @*
    div_idx_reg = n2532; // (isignal)
  initial
    div_idx_reg = 5'b10110;
  /* mc68881_sgl_ops_unit.vhd:63:10  */
  always @*
    div_sign_reg = n2533; // (isignal)
  initial
    div_sign_reg = 1'b0;
  /* mc68881_sgl_ops_unit.vhd:64:10  */
  always @*
    div_exp_base_reg = n2534; // (isignal)
  initial
    div_exp_base_reg = 32'b00000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:161:16  */
  assign n42 = ~reset_n;
  /* mc68881_sgl_ops_unit.vhd:185:11  */
  assign n45 = start ? 3'b001 : state_reg;
  /* mc68881_sgl_ops_unit.vhd:185:11  */
  assign n46 = start ? op_sel : op_reg;
  /* mc68881_sgl_ops_unit.vhd:185:11  */
  assign n47 = start ? a_in : a_reg;
  /* mc68881_sgl_ops_unit.vhd:185:11  */
  assign n48 = start ? b_in : b_reg;
  /* mc68881_sgl_ops_unit.vhd:185:11  */
  assign n49 = start ? round_mode : rm_reg;
  /* mc68881_sgl_ops_unit.vhd:184:9  */
  assign n51 = state_reg == 3'b000;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n58 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n61 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n63 = a_reg[63:0]; // extract
  assign n64 = {n63, n61, n58};
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n71 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n74 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n76 = b_reg[63:0]; // extract
  assign n77 = {n76, n74, n71};
  /* mc68881_sgl_ops_unit.vhd:197:21  */
  assign n79 = op_reg == 6'b001001;
  /* mc68881_sgl_ops_unit.vhd:199:24  */
  assign n81 = op_reg == 6'b001011;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n93 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n96 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n98 = a_reg[63:0]; // extract
  assign n99 = {n98, n96, n93};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n100 = n99[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n102 = n100 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n114 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n117 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n119 = a_reg[63:0]; // extract
  assign n120 = {n119, n117, n114};
  assign n124 = n123[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n125 = n120[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n127 = n125 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n128 = n120[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n130 = n128 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n131 = n120[79:16]; // extract
  assign n132 = {1'b1, n124};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n133 = n131 == n132;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n134 = n130 | n133;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n135 = n134 & n127;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n136 = ~n135;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n137 = n136 & n102;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n149 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n152 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n154 = b_reg[63:0]; // extract
  assign n155 = {n154, n152, n149};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n156 = n155[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n158 = n156 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n170 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n173 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n175 = b_reg[63:0]; // extract
  assign n176 = {n175, n173, n170};
  assign n180 = n179[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n181 = n176[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n183 = n181 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n184 = n176[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n186 = n184 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n187 = n176[79:16]; // extract
  assign n188 = {1'b1, n180};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n189 = n187 == n188;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n190 = n186 | n189;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n191 = n190 & n183;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n192 = ~n191;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n193 = n192 & n158;
  /* mc68881_sgl_ops_unit.vhd:200:41  */
  assign n194 = n137 | n193;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n207 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n210 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n212 = a_reg[63:0]; // extract
  assign n213 = {n212, n210, n207};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n214 = n213[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n216 = n214 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n228 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n231 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n233 = a_reg[63:0]; // extract
  assign n234 = {n233, n231, n228};
  assign n238 = n237[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n239 = n234[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n241 = n239 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n242 = n234[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n244 = n242 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n245 = n234[79:16]; // extract
  assign n246 = {1'b1, n238};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n247 = n245 == n246;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n248 = n244 | n247;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n249 = n248 & n241;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n250 = ~n249;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n251 = n250 & n216;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n263 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n266 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n268 = b_reg[63:0]; // extract
  assign n269 = {n268, n266, n263};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n270 = n269[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n272 = n270 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n284 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n287 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n289 = b_reg[63:0]; // extract
  assign n290 = {n289, n287, n284};
  assign n294 = n293[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n295 = n290[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n297 = n295 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n298 = n290[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n300 = n298 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n301 = n290[79:16]; // extract
  assign n302 = {1'b1, n294};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n303 = n301 == n302;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n304 = n300 | n303;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n305 = n304 & n297;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n306 = ~n305;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n307 = n306 & n272;
  /* mc68881_pkg.vhd:1556:25  */
  assign n325 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1557:34  */
  assign n328 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1558:34  */
  assign n330 = a_reg[63:0]; // extract
  assign n331 = {n330, n328, n325};
  /* mc68881_pkg.vhd:2126:20  */
  assign n332 = n331[15:1]; // extract
  /* mc68881_pkg.vhd:2126:24  */
  assign n334 = n332 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2127:24  */
  assign n335 = n331[79]; // extract
  /* mc68881_pkg.vhd:2127:42  */
  assign n336 = ~n335;
  /* mc68881_pkg.vhd:2126:42  */
  assign n337 = n336 & n334;
  /* mc68881_pkg.vhd:2128:24  */
  assign n338 = n331[78:16]; // extract
  /* mc68881_pkg.vhd:2128:51  */
  assign n340 = n338 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2127:48  */
  assign n341 = n340 & n337;
  /* mc68881_pkg.vhd:1556:25  */
  assign n353 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1557:34  */
  assign n356 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1558:34  */
  assign n358 = b_reg[63:0]; // extract
  assign n359 = {n358, n356, n353};
  /* mc68881_pkg.vhd:2126:20  */
  assign n360 = n359[15:1]; // extract
  /* mc68881_pkg.vhd:2126:24  */
  assign n362 = n360 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2127:24  */
  assign n363 = n359[79]; // extract
  /* mc68881_pkg.vhd:2127:42  */
  assign n364 = ~n363;
  /* mc68881_pkg.vhd:2126:42  */
  assign n365 = n364 & n362;
  /* mc68881_pkg.vhd:2128:24  */
  assign n366 = n359[78:16]; // extract
  /* mc68881_pkg.vhd:2128:51  */
  assign n368 = n366 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2127:48  */
  assign n369 = n368 & n365;
  /* mc68881_pkg.vhd:2165:18  */
  assign n371 = n341 | n369;
  /* mc68881_pkg.vhd:2165:5  */
  assign n374 = n371 ? 1'b1 : 1'b0;
  /* mc68881_pkg.vhd:2169:14  */
  assign n376 = n307 & n251;
  /* mc68881_pkg.vhd:2173:7  */
  assign n377 = n369 ? b_reg : a_reg;
  /* mc68881_pkg.vhd:2171:7  */
  assign n378 = n341 ? a_reg : n377;
  /* mc68881_pkg.vhd:2178:5  */
  assign n379 = n251 ? a_reg : b_reg;
  /* mc68881_pkg.vhd:2169:5  */
  assign n380 = n376 ? n378 : n379;
  assign n383 = n380[79:64]; // extract
  assign n384 = n380[62:0]; // extract
  assign n385 = {n383, 1'b1, n384};
  /* mc68881_pkg.vhd:2187:23  */
  assign n386 = {n374, n385};
  /* mc68881_sgl_ops_unit.vhd:203:37  */
  assign n388 = n386[79:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n400 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n403 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n405 = a_reg[63:0]; // extract
  assign n406 = {n405, n403, n400};
  assign n410 = n409[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n411 = n406[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n413 = n411 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n414 = n406[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n416 = n414 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n417 = n406[79:16]; // extract
  assign n418 = {1'b1, n410};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n419 = n417 == n418;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n420 = n416 | n419;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n421 = n420 & n413;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n433 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n436 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n438 = b_reg[63:0]; // extract
  assign n439 = {n438, n436, n433};
  assign n443 = n442[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n444 = n439[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n446 = n444 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n447 = n439[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n449 = n447 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n450 = n439[79:16]; // extract
  assign n451 = {1'b1, n443};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n452 = n450 == n451;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n453 = n449 | n452;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n454 = n453 & n446;
  /* mc68881_sgl_ops_unit.vhd:205:44  */
  assign n455 = n421 | n454;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n467 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n470 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n472 = a_reg[63:0]; // extract
  assign n473 = {n472, n470, n467};
  /* mc68881_sgl_ops_unit.vhd:87:14  */
  assign n474 = n473[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:18  */
  assign n476 = n474 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:28  */
  assign n477 = n473[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:33  */
  assign n479 = n477 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:22  */
  assign n480 = n479 & n476;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n492 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n495 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n497 = b_reg[63:0]; // extract
  assign n498 = {n497, n495, n492};
  /* mc68881_sgl_ops_unit.vhd:87:14  */
  assign n499 = n498[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:18  */
  assign n501 = n499 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:28  */
  assign n502 = n498[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:33  */
  assign n504 = n502 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:22  */
  assign n505 = n504 & n501;
  /* mc68881_sgl_ops_unit.vhd:206:44  */
  assign n506 = n480 | n505;
  /* mc68881_sgl_ops_unit.vhd:209:35  */
  assign n509 = n64[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:209:48  */
  assign n510 = n77[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:209:40  */
  assign n511 = n509 ^ n510;
  assign n520 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n511};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n521 = n520[0]; // extract
  assign n524 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n511};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n525 = n524[15:1]; // extract
  assign n527 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n511};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n528 = n527[79:16]; // extract
  assign n529 = {n521, n525, n528};
  /* mc68881_sgl_ops_unit.vhd:206:15  */
  assign n531 = n506 ? 80'b01111111111111111111111111111111111111111111111111111111111111111111111111111111 : n529;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n545 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n548 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n550 = a_reg[63:0]; // extract
  assign n551 = {n550, n548, n545};
  /* mc68881_sgl_ops_unit.vhd:87:14  */
  assign n552 = n551[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:18  */
  assign n554 = n552 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:28  */
  assign n555 = n551[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:33  */
  assign n557 = n555 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:22  */
  assign n558 = n557 & n554;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n570 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n573 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n575 = b_reg[63:0]; // extract
  assign n576 = {n575, n573, n570};
  /* mc68881_sgl_ops_unit.vhd:87:14  */
  assign n577 = n576[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:18  */
  assign n579 = n577 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:28  */
  assign n580 = n576[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:33  */
  assign n582 = n580 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:22  */
  assign n583 = n582 & n579;
  /* mc68881_sgl_ops_unit.vhd:215:45  */
  assign n584 = n558 | n583;
  /* mc68881_sgl_ops_unit.vhd:219:36  */
  assign n585 = n64[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:220:36  */
  assign n586 = n77[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:223:35  */
  assign n587 = n64[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:223:48  */
  assign n588 = n77[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:223:40  */
  assign n589 = n587 ^ n588;
  /* mc68881_sgl_ops_unit.vhd:224:50  */
  assign n590 = n64[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:224:35  */
  assign n591 = {16'b0, n590};  //  uext
  /* mc68881_sgl_ops_unit.vhd:224:55  */
  assign n592 = {1'b0, n591};  //  uext
  /* mc68881_sgl_ops_unit.vhd:224:72  */
  assign n593 = n77[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:224:57  */
  assign n594 = {16'b0, n593};  //  uext
  /* mc68881_sgl_ops_unit.vhd:224:55  */
  assign n595 = {1'b0, n594};  //  uext
  /* mc68881_sgl_ops_unit.vhd:224:55  */
  assign n596 = n592 + n595;
  /* mc68881_sgl_ops_unit.vhd:224:77  */
  assign n598 = n596 - 32'b00000000000000000011111111111111;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n601 = n584 ? 3'b111 : 3'b011;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n603 = n584 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : result_reg;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n604 = n584 ? mul_a_reg : n585;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n605 = n584 ? mul_b_reg : n586;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n607 = n584 ? mul_acc_reg : 48'b000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n609 = n584 ? mul_idx_reg : 5'b00000;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n610 = n584 ? mul_sign_reg : n589;
  /* mc68881_sgl_ops_unit.vhd:215:13  */
  assign n611 = n584 ? mul_exp_base_reg : n598;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n613 = n455 ? 3'b111 : n601;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n614 = n455 ? n531 : n603;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n615 = n455 ? mul_a_reg : n604;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n616 = n455 ? mul_b_reg : n605;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n617 = n455 ? mul_acc_reg : n607;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n618 = n455 ? mul_idx_reg : n609;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n619 = n455 ? mul_sign_reg : n610;
  /* mc68881_sgl_ops_unit.vhd:205:13  */
  assign n620 = n455 ? mul_exp_base_reg : n611;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n623 = n194 ? 3'b111 : n613;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n624 = n194 ? n388 : n614;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n625 = n194 ? mul_a_reg : n615;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n626 = n194 ? mul_b_reg : n616;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n627 = n194 ? mul_acc_reg : n617;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n628 = n194 ? mul_idx_reg : n618;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n629 = n194 ? mul_sign_reg : n619;
  /* mc68881_sgl_ops_unit.vhd:200:13  */
  assign n630 = n194 ? mul_exp_base_reg : n620;
  /* mc68881_sgl_ops_unit.vhd:227:24  */
  assign n634 = op_reg == 6'b001010;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n646 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n649 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n651 = a_reg[63:0]; // extract
  assign n652 = {n651, n649, n646};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n653 = n652[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n655 = n653 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n667 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n670 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n672 = a_reg[63:0]; // extract
  assign n673 = {n672, n670, n667};
  assign n677 = n676[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n678 = n673[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n680 = n678 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n681 = n673[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n683 = n681 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n684 = n673[79:16]; // extract
  assign n685 = {1'b1, n677};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n686 = n684 == n685;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n687 = n683 | n686;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n688 = n687 & n680;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n689 = ~n688;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n690 = n689 & n655;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n702 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n705 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n707 = b_reg[63:0]; // extract
  assign n708 = {n707, n705, n702};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n709 = n708[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n711 = n709 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n723 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n726 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n728 = b_reg[63:0]; // extract
  assign n729 = {n728, n726, n723};
  assign n733 = n732[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n734 = n729[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n736 = n734 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n737 = n729[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n739 = n737 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n740 = n729[79:16]; // extract
  assign n741 = {1'b1, n733};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n742 = n740 == n741;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n743 = n739 | n742;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n744 = n743 & n736;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n745 = ~n744;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n746 = n745 & n711;
  /* mc68881_sgl_ops_unit.vhd:228:41  */
  assign n747 = n690 | n746;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n760 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n763 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n765 = a_reg[63:0]; // extract
  assign n766 = {n765, n763, n760};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n767 = n766[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n769 = n767 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n781 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n784 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n786 = a_reg[63:0]; // extract
  assign n787 = {n786, n784, n781};
  assign n791 = n790[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n792 = n787[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n794 = n792 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n795 = n787[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n797 = n795 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n798 = n787[79:16]; // extract
  assign n799 = {1'b1, n791};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n800 = n798 == n799;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n801 = n797 | n800;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n802 = n801 & n794;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n803 = ~n802;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n804 = n803 & n769;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n816 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n819 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n821 = b_reg[63:0]; // extract
  assign n822 = {n821, n819, n816};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n823 = n822[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n825 = n823 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n837 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n840 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n842 = b_reg[63:0]; // extract
  assign n843 = {n842, n840, n837};
  assign n847 = n846[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n848 = n843[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n850 = n848 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n851 = n843[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n853 = n851 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n854 = n843[79:16]; // extract
  assign n855 = {1'b1, n847};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n856 = n854 == n855;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n857 = n853 | n856;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n858 = n857 & n850;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n859 = ~n858;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n860 = n859 & n825;
  /* mc68881_pkg.vhd:1556:25  */
  assign n878 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1557:34  */
  assign n881 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1558:34  */
  assign n883 = a_reg[63:0]; // extract
  assign n884 = {n883, n881, n878};
  /* mc68881_pkg.vhd:2126:20  */
  assign n885 = n884[15:1]; // extract
  /* mc68881_pkg.vhd:2126:24  */
  assign n887 = n885 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2127:24  */
  assign n888 = n884[79]; // extract
  /* mc68881_pkg.vhd:2127:42  */
  assign n889 = ~n888;
  /* mc68881_pkg.vhd:2126:42  */
  assign n890 = n889 & n887;
  /* mc68881_pkg.vhd:2128:24  */
  assign n891 = n884[78:16]; // extract
  /* mc68881_pkg.vhd:2128:51  */
  assign n893 = n891 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2127:48  */
  assign n894 = n893 & n890;
  /* mc68881_pkg.vhd:1556:25  */
  assign n906 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1557:34  */
  assign n909 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1558:34  */
  assign n911 = b_reg[63:0]; // extract
  assign n912 = {n911, n909, n906};
  /* mc68881_pkg.vhd:2126:20  */
  assign n913 = n912[15:1]; // extract
  /* mc68881_pkg.vhd:2126:24  */
  assign n915 = n913 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2127:24  */
  assign n916 = n912[79]; // extract
  /* mc68881_pkg.vhd:2127:42  */
  assign n917 = ~n916;
  /* mc68881_pkg.vhd:2126:42  */
  assign n918 = n917 & n915;
  /* mc68881_pkg.vhd:2128:24  */
  assign n919 = n912[78:16]; // extract
  /* mc68881_pkg.vhd:2128:51  */
  assign n921 = n919 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2127:48  */
  assign n922 = n921 & n918;
  /* mc68881_pkg.vhd:2165:18  */
  assign n924 = n894 | n922;
  /* mc68881_pkg.vhd:2165:5  */
  assign n927 = n924 ? 1'b1 : 1'b0;
  /* mc68881_pkg.vhd:2169:14  */
  assign n929 = n860 & n804;
  /* mc68881_pkg.vhd:2173:7  */
  assign n930 = n922 ? b_reg : a_reg;
  /* mc68881_pkg.vhd:2171:7  */
  assign n931 = n894 ? a_reg : n930;
  /* mc68881_pkg.vhd:2178:5  */
  assign n932 = n804 ? a_reg : b_reg;
  /* mc68881_pkg.vhd:2169:5  */
  assign n933 = n929 ? n931 : n932;
  assign n936 = n933[79:64]; // extract
  assign n937 = n933[62:0]; // extract
  assign n938 = {n936, 1'b1, n937};
  /* mc68881_pkg.vhd:2187:23  */
  assign n939 = {n927, n938};
  /* mc68881_sgl_ops_unit.vhd:231:37  */
  assign n941 = n939[79:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n953 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n956 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n958 = b_reg[63:0]; // extract
  assign n959 = {n958, n956, n953};
  /* mc68881_sgl_ops_unit.vhd:87:14  */
  assign n960 = n959[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:18  */
  assign n962 = n960 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:28  */
  assign n963 = n959[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:33  */
  assign n965 = n963 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:22  */
  assign n966 = n965 & n962;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n978 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n981 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n983 = a_reg[63:0]; // extract
  assign n984 = {n983, n981, n978};
  /* mc68881_sgl_ops_unit.vhd:87:14  */
  assign n985 = n984[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:18  */
  assign n987 = n985 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:28  */
  assign n988 = n984[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:33  */
  assign n990 = n988 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:22  */
  assign n991 = n990 & n987;
  /* mc68881_sgl_ops_unit.vhd:237:35  */
  assign n994 = n64[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:237:48  */
  assign n995 = n77[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:237:40  */
  assign n996 = n994 ^ n995;
  assign n1004 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n996};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n1005 = n1004[0]; // extract
  assign n1008 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n996};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n1009 = n1008[15:1]; // extract
  assign n1011 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n996};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n1012 = n1011[79:16]; // extract
  assign n1013 = {n1005, n1009, n1012};
  /* mc68881_sgl_ops_unit.vhd:234:15  */
  assign n1015 = n991 ? 80'b01111111111111111111111111111111111111111111111111111111111111111111111111111111 : n1013;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1029 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1032 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1034 = a_reg[63:0]; // extract
  assign n1035 = {n1034, n1032, n1029};
  /* mc68881_sgl_ops_unit.vhd:87:14  */
  assign n1036 = n1035[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:18  */
  assign n1038 = n1036 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:28  */
  assign n1039 = n1035[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:87:33  */
  assign n1041 = n1039 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:87:22  */
  assign n1042 = n1041 & n1038;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1054 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1057 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1059 = a_reg[63:0]; // extract
  assign n1060 = {n1059, n1057, n1054};
  assign n1064 = n1063[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1065 = n1060[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1067 = n1065 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1068 = n1060[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1070 = n1068 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1071 = n1060[79:16]; // extract
  assign n1072 = {1'b1, n1064};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1073 = n1071 == n1072;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1074 = n1070 | n1073;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1075 = n1074 & n1067;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1087 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1090 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1092 = b_reg[63:0]; // extract
  assign n1093 = {n1092, n1090, n1087};
  assign n1097 = n1096[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1098 = n1093[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1100 = n1098 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1101 = n1093[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1103 = n1101 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1104 = n1093[79:16]; // extract
  assign n1105 = {1'b1, n1097};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1106 = n1104 == n1105;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1107 = n1103 | n1106;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1108 = n1107 & n1100;
  /* mc68881_sgl_ops_unit.vhd:246:44  */
  assign n1109 = n1108 & n1075;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1123 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1126 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1128 = a_reg[63:0]; // extract
  assign n1129 = {n1128, n1126, n1123};
  assign n1133 = n1132[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1134 = n1129[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1136 = n1134 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1137 = n1129[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1139 = n1137 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1140 = n1129[79:16]; // extract
  assign n1141 = {1'b1, n1133};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1142 = n1140 == n1141;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1143 = n1139 | n1142;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1144 = n1143 & n1136;
  /* mc68881_sgl_ops_unit.vhd:250:33  */
  assign n1145 = n64[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:250:46  */
  assign n1146 = n77[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:250:38  */
  assign n1147 = n1145 ^ n1146;
  assign n1155 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n1147};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n1156 = n1155[0]; // extract
  assign n1159 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n1147};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n1160 = n1159[15:1]; // extract
  assign n1162 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, n1147};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n1163 = n1162[79:16]; // extract
  assign n1164 = {n1156, n1160, n1163};
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1176 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1179 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1181 = b_reg[63:0]; // extract
  assign n1182 = {n1181, n1179, n1176};
  assign n1186 = n1185[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1187 = n1182[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1189 = n1187 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1190 = n1182[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1192 = n1190 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1193 = n1182[79:16]; // extract
  assign n1194 = {1'b1, n1186};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1195 = n1193 == n1194;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1196 = n1192 | n1195;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1197 = n1196 & n1189;
  /* mc68881_sgl_ops_unit.vhd:259:42  */
  assign n1198 = n77[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:260:26  */
  assign n1199 = n64[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:260:79  */
  assign n1200 = n77[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:260:68  */
  assign n1201 = $unsigned(n1199) >= $unsigned(n1200);
  assign n1204 = n1203[22:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:264:27  */
  assign n1205 = n64[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:264:79  */
  assign n1206 = n77[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:264:69  */
  assign n1207 = n1205 - n1206;
  /* mc68881_sgl_ops_unit.vhd:263:32  */
  assign n1208 = {1'b0, n1207};  //  uext
  /* mc68881_sgl_ops_unit.vhd:269:47  */
  assign n1209 = n64[79:56]; // extract
  /* mc68881_sgl_ops_unit.vhd:269:32  */
  assign n1210 = {1'b0, n1209};  //  uext
  /* mc68881_sgl_ops_unit.vhd:260:15  */
  assign n1211 = n1201 ? n1208 : n1210;
  assign n1212 = {1'b1, n1204};
  /* mc68881_sgl_ops_unit.vhd:260:15  */
  assign n1214 = n1201 ? n1212 : 24'b000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:272:35  */
  assign n1215 = n64[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:272:48  */
  assign n1216 = n77[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:272:40  */
  assign n1217 = n1215 ^ n1216;
  /* mc68881_sgl_ops_unit.vhd:273:50  */
  assign n1218 = n64[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:273:35  */
  assign n1219 = {16'b0, n1218};  //  uext
  /* mc68881_sgl_ops_unit.vhd:273:55  */
  assign n1220 = {1'b0, n1219};  //  uext
  /* mc68881_sgl_ops_unit.vhd:273:72  */
  assign n1221 = n77[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:273:57  */
  assign n1222 = {16'b0, n1221};  //  uext
  /* mc68881_sgl_ops_unit.vhd:273:55  */
  assign n1223 = {1'b0, n1222};  //  uext
  /* mc68881_sgl_ops_unit.vhd:273:55  */
  assign n1224 = n1220 - n1223;
  /* mc68881_sgl_ops_unit.vhd:273:77  */
  assign n1226 = n1224 + 32'b00000000000000000011111111111111;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1229 = n1197 ? 3'b111 : 3'b100;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1231 = n1197 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : result_reg;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1232 = n1197 ? div_divisor_reg : n1198;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1233 = n1197 ? div_rem_reg : n1211;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1234 = n1197 ? div_quot_reg : n1214;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1236 = n1197 ? div_idx_reg : 5'b10110;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1237 = n1197 ? div_sign_reg : n1217;
  /* mc68881_sgl_ops_unit.vhd:255:13  */
  assign n1238 = n1197 ? div_exp_base_reg : n1226;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1240 = n1144 ? 3'b111 : n1229;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1241 = n1144 ? n1164 : n1231;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1242 = n1144 ? div_divisor_reg : n1232;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1243 = n1144 ? div_rem_reg : n1233;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1244 = n1144 ? div_quot_reg : n1234;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1245 = n1144 ? div_idx_reg : n1236;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1246 = n1144 ? div_sign_reg : n1237;
  /* mc68881_sgl_ops_unit.vhd:249:13  */
  assign n1247 = n1144 ? div_exp_base_reg : n1238;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1251 = n1109 ? 3'b111 : n1240;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1253 = n1109 ? 80'b01111111111111111111111111111111111111111111111111111111111111111111111111111111 : n1241;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1254 = n1109 ? div_divisor_reg : n1242;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1255 = n1109 ? div_rem_reg : n1243;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1256 = n1109 ? div_quot_reg : n1244;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1257 = n1109 ? div_idx_reg : n1245;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1258 = n1109 ? div_sign_reg : n1246;
  /* mc68881_sgl_ops_unit.vhd:246:13  */
  assign n1259 = n1109 ? div_exp_base_reg : n1247;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1262 = n1042 ? 3'b111 : n1251;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1264 = n1042 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1253;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1265 = n1042 ? div_divisor_reg : n1254;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1266 = n1042 ? div_rem_reg : n1255;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1267 = n1042 ? div_quot_reg : n1256;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1268 = n1042 ? div_idx_reg : n1257;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1269 = n1042 ? div_sign_reg : n1258;
  /* mc68881_sgl_ops_unit.vhd:243:13  */
  assign n1270 = n1042 ? div_exp_base_reg : n1259;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1273 = n966 ? 3'b111 : n1262;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1274 = n966 ? n1015 : n1264;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1275 = n966 ? div_divisor_reg : n1265;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1276 = n966 ? div_rem_reg : n1266;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1277 = n966 ? div_quot_reg : n1267;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1278 = n966 ? div_idx_reg : n1268;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1279 = n966 ? div_sign_reg : n1269;
  /* mc68881_sgl_ops_unit.vhd:233:13  */
  assign n1280 = n966 ? div_exp_base_reg : n1270;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1283 = n747 ? 3'b111 : n1273;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1284 = n747 ? n941 : n1274;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1285 = n747 ? div_divisor_reg : n1275;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1286 = n747 ? div_rem_reg : n1276;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1287 = n747 ? div_quot_reg : n1277;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1288 = n747 ? div_idx_reg : n1278;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1289 = n747 ? div_sign_reg : n1279;
  /* mc68881_sgl_ops_unit.vhd:228:13  */
  assign n1290 = n747 ? div_exp_base_reg : n1280;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1294 = n634 ? n1283 : 3'b111;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1296 = n634 ? n1284 : 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1297 = n634 ? n1285 : div_divisor_reg;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1298 = n634 ? n1286 : div_rem_reg;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1299 = n634 ? n1287 : div_quot_reg;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1300 = n634 ? n1288 : div_idx_reg;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1301 = n634 ? n1289 : div_sign_reg;
  /* mc68881_sgl_ops_unit.vhd:227:11  */
  assign n1302 = n634 ? n1290 : div_exp_base_reg;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1305 = n81 ? n623 : n1294;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1306 = n81 ? n624 : n1296;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1307 = n81 ? n625 : mul_a_reg;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1308 = n81 ? n626 : mul_b_reg;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1309 = n81 ? n627 : mul_acc_reg;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1310 = n81 ? n628 : mul_idx_reg;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1311 = n81 ? n629 : mul_sign_reg;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1312 = n81 ? n630 : mul_exp_base_reg;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1313 = n81 ? div_divisor_reg : n1297;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1314 = n81 ? div_rem_reg : n1298;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1315 = n81 ? div_quot_reg : n1299;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1316 = n81 ? div_idx_reg : n1300;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1317 = n81 ? div_sign_reg : n1301;
  /* mc68881_sgl_ops_unit.vhd:199:11  */
  assign n1318 = n81 ? div_exp_base_reg : n1302;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1322 = n79 ? 3'b010 : n1305;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1323 = n79 ? result_reg : n1306;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1324 = n79 ? mul_a_reg : n1307;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1325 = n79 ? mul_b_reg : n1308;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1326 = n79 ? mul_acc_reg : n1309;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1327 = n79 ? mul_idx_reg : n1310;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1328 = n79 ? mul_sign_reg : n1311;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1329 = n79 ? mul_exp_base_reg : n1312;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1330 = n79 ? div_divisor_reg : n1313;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1331 = n79 ? div_rem_reg : n1314;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1332 = n79 ? div_quot_reg : n1315;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1333 = n79 ? div_idx_reg : n1316;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1334 = n79 ? div_sign_reg : n1317;
  /* mc68881_sgl_ops_unit.vhd:197:11  */
  assign n1335 = n79 ? div_exp_base_reg : n1318;
  /* mc68881_sgl_ops_unit.vhd:193:9  */
  assign n1339 = state_reg == 3'b001;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1359 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1362 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1364 = b_reg[63:0]; // extract
  assign n1365 = {n1364, n1362, n1359};
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1377 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1380 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1382 = a_reg[63:0]; // extract
  assign n1383 = {n1382, n1380, n1377};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n1384 = n1383[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n1386 = n1384 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1398 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1401 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1403 = a_reg[63:0]; // extract
  assign n1404 = {n1403, n1401, n1398};
  assign n1408 = n1407[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1409 = n1404[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1411 = n1409 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1412 = n1404[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1414 = n1412 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1415 = n1404[79:16]; // extract
  assign n1416 = {1'b1, n1408};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1417 = n1415 == n1416;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1418 = n1414 | n1417;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1419 = n1418 & n1411;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n1420 = ~n1419;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n1421 = n1420 & n1386;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1433 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1436 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1438 = b_reg[63:0]; // extract
  assign n1439 = {n1438, n1436, n1433};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n1440 = n1439[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n1442 = n1440 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1454 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1457 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1459 = b_reg[63:0]; // extract
  assign n1460 = {n1459, n1457, n1454};
  assign n1464 = n1463[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1465 = n1460[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1467 = n1465 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1468 = n1460[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1470 = n1468 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1471 = n1460[79:16]; // extract
  assign n1472 = {1'b1, n1464};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1473 = n1471 == n1472;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1474 = n1470 | n1473;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1475 = n1474 & n1467;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n1476 = ~n1475;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n1477 = n1476 & n1442;
  /* mc68881_sgl_ops_unit.vhd:284:39  */
  assign n1478 = n1421 | n1477;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1491 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1494 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1496 = a_reg[63:0]; // extract
  assign n1497 = {n1496, n1494, n1491};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n1498 = n1497[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n1500 = n1498 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1512 = a_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1515 = a_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1517 = a_reg[63:0]; // extract
  assign n1518 = {n1517, n1515, n1512};
  assign n1522 = n1521[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1523 = n1518[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1525 = n1523 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1526 = n1518[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1528 = n1526 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1529 = n1518[79:16]; // extract
  assign n1530 = {1'b1, n1522};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1531 = n1529 == n1530;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1532 = n1528 | n1531;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1533 = n1532 & n1525;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n1534 = ~n1533;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n1535 = n1534 & n1500;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1547 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1550 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1552 = b_reg[63:0]; // extract
  assign n1553 = {n1552, n1550, n1547};
  /* mc68881_sgl_ops_unit.vhd:101:31  */
  assign n1554 = n1553[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:101:35  */
  assign n1556 = n1554 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1568 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1571 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1573 = b_reg[63:0]; // extract
  assign n1574 = {n1573, n1571, n1568};
  assign n1578 = n1577[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1579 = n1574[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1581 = n1579 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1582 = n1574[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1584 = n1582 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1585 = n1574[79:16]; // extract
  assign n1586 = {1'b1, n1578};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1587 = n1585 == n1586;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1588 = n1584 | n1587;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1589 = n1588 & n1581;
  /* mc68881_sgl_ops_unit.vhd:101:57  */
  assign n1590 = ~n1589;
  /* mc68881_sgl_ops_unit.vhd:101:53  */
  assign n1591 = n1590 & n1556;
  /* mc68881_pkg.vhd:1556:25  */
  assign n1609 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1557:34  */
  assign n1612 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1558:34  */
  assign n1614 = a_reg[63:0]; // extract
  assign n1615 = {n1614, n1612, n1609};
  /* mc68881_pkg.vhd:2126:20  */
  assign n1616 = n1615[15:1]; // extract
  /* mc68881_pkg.vhd:2126:24  */
  assign n1618 = n1616 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2127:24  */
  assign n1619 = n1615[79]; // extract
  /* mc68881_pkg.vhd:2127:42  */
  assign n1620 = ~n1619;
  /* mc68881_pkg.vhd:2126:42  */
  assign n1621 = n1620 & n1618;
  /* mc68881_pkg.vhd:2128:24  */
  assign n1622 = n1615[78:16]; // extract
  /* mc68881_pkg.vhd:2128:51  */
  assign n1624 = n1622 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2127:48  */
  assign n1625 = n1624 & n1621;
  /* mc68881_pkg.vhd:1556:25  */
  assign n1637 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1557:34  */
  assign n1640 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1558:34  */
  assign n1642 = b_reg[63:0]; // extract
  assign n1643 = {n1642, n1640, n1637};
  /* mc68881_pkg.vhd:2126:20  */
  assign n1644 = n1643[15:1]; // extract
  /* mc68881_pkg.vhd:2126:24  */
  assign n1646 = n1644 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2127:24  */
  assign n1647 = n1643[79]; // extract
  /* mc68881_pkg.vhd:2127:42  */
  assign n1648 = ~n1647;
  /* mc68881_pkg.vhd:2126:42  */
  assign n1649 = n1648 & n1646;
  /* mc68881_pkg.vhd:2128:24  */
  assign n1650 = n1643[78:16]; // extract
  /* mc68881_pkg.vhd:2128:51  */
  assign n1652 = n1650 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2127:48  */
  assign n1653 = n1652 & n1649;
  /* mc68881_pkg.vhd:2165:18  */
  assign n1655 = n1625 | n1653;
  /* mc68881_pkg.vhd:2165:5  */
  assign n1658 = n1655 ? 1'b1 : 1'b0;
  /* mc68881_pkg.vhd:2169:14  */
  assign n1660 = n1591 & n1535;
  /* mc68881_pkg.vhd:2173:7  */
  assign n1661 = n1653 ? b_reg : a_reg;
  /* mc68881_pkg.vhd:2171:7  */
  assign n1662 = n1625 ? a_reg : n1661;
  /* mc68881_pkg.vhd:2178:5  */
  assign n1663 = n1535 ? a_reg : b_reg;
  /* mc68881_pkg.vhd:2169:5  */
  assign n1664 = n1660 ? n1662 : n1663;
  assign n1667 = n1664[79:64]; // extract
  assign n1668 = n1664[62:0]; // extract
  assign n1669 = {n1667, 1'b1, n1668};
  /* mc68881_pkg.vhd:2187:23  */
  assign n1670 = {n1658, n1669};
  /* mc68881_sgl_ops_unit.vhd:287:35  */
  assign n1672 = n1670[79:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:288:21  */
  assign n1673 = n1365[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:288:25  */
  assign n1675 = n1673 == 15'b000000000000000;
  /* mc68881_sgl_ops_unit.vhd:69:27  */
  assign n1687 = b_reg[79]; // extract
  /* mc68881_sgl_ops_unit.vhd:70:35  */
  assign n1690 = b_reg[78:64]; // extract
  /* mc68881_sgl_ops_unit.vhd:71:36  */
  assign n1692 = b_reg[63:0]; // extract
  assign n1693 = {n1692, n1690, n1687};
  assign n1697 = n1696[62:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:14  */
  assign n1698 = n1693[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:95:18  */
  assign n1700 = n1698 == 15'b111111111111111;
  /* mc68881_sgl_ops_unit.vhd:96:10  */
  assign n1701 = n1693[79:16]; // extract
  /* mc68881_sgl_ops_unit.vhd:96:15  */
  assign n1703 = n1701 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:96:24  */
  assign n1704 = n1693[79:16]; // extract
  assign n1705 = {1'b1, n1697};
  /* mc68881_sgl_ops_unit.vhd:96:29  */
  assign n1706 = n1704 == n1705;
  /* mc68881_sgl_ops_unit.vhd:96:19  */
  assign n1707 = n1703 | n1706;
  /* mc68881_sgl_ops_unit.vhd:95:36  */
  assign n1708 = n1707 & n1700;
  /* mc68881_sgl_ops_unit.vhd:288:29  */
  assign n1709 = n1675 | n1708;
  /* mc68881_pkg.vhd:1556:25  */
  assign n1721 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1557:34  */
  assign n1724 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1558:34  */
  assign n1726 = a_reg[63:0]; // extract
  assign n1727 = {n1726, n1724, n1721};
  /* mc68881_pkg.vhd:2246:16  */
  assign n1732 = n1727[15:1]; // extract
  /* mc68881_pkg.vhd:2246:20  */
  assign n1734 = n1732 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2246:35  */
  assign n1735 = n1727[15:1]; // extract
  /* mc68881_pkg.vhd:2246:39  */
  assign n1737 = n1735 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2246:24  */
  assign n1738 = n1734 | n1737;
  /* mc68881_pkg.vhd:2246:5  */
  assign n1742 = n1738 ? 1'b0 : 1'b1;
  /* mc68881_pkg.vhd:2246:5  */
  assign n1748 = n1738 ? 32'b00000000000000000000000000000000 : 32'bX;
  /* mc68881_pkg.vhd:2250:33  */
  assign n1749 = n1727[15:1]; // extract
  /* mc68881_pkg.vhd:2250:14  */
  assign n1750 = {16'b0, n1749};  //  uext
  /* mc68881_pkg.vhd:2250:5  */
  assign n1751 = {1'b0, n1750};  //  uext
  /* mc68881_pkg.vhd:2250:5  */
  assign n1753 = n1742 ? n1751 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2251:20  */
  assign n1756 = n1753 - 32'b00000000000000000011111111111111;
  /* mc68881_pkg.vhd:2251:5  */
  assign n1758 = n1742 ? n1756 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2252:14  */
  assign n1761 = $signed(n1758) < $signed(32'b00000000000000000000000000000000);
  /* mc68881_pkg.vhd:2252:5  */
  assign n1764 = n1771 ? 1'b0 : n1742;
  /* mc68881_pkg.vhd:2252:5  */
  assign n1767 = n1773 ? 32'b00000000000000000000000000000000 : n1748;
  /* mc68881_pkg.vhd:2252:5  */
  assign n1768 = n1742 & n1761;
  /* mc68881_pkg.vhd:2252:5  */
  assign n1770 = n1742 & n1761;
  /* mc68881_pkg.vhd:2252:5  */
  assign n1771 = n1768 & n1742;
  /* mc68881_pkg.vhd:2252:5  */
  assign n1773 = n1770 & n1742;
  /* mc68881_pkg.vhd:2256:14  */
  assign n1775 = $signed(n1758) > $signed(32'b00000000000000000000000000011110);
  /* mc68881_pkg.vhd:2257:18  */
  assign n1776 = n1727[0]; // extract
  /* mc68881_pkg.vhd:2257:7  */
  assign n1779 = n1786 ? 1'b0 : n1764;
  /* mc68881_pkg.vhd:2257:7  */
  assign n1782 = n1788 ? 32'b10000000000000000000000000000000 : n1767;
  /* mc68881_pkg.vhd:2257:7  */
  assign n1783 = n1764 & n1776;
  /* mc68881_pkg.vhd:2257:7  */
  assign n1785 = n1764 & n1776;
  /* mc68881_pkg.vhd:2257:7  */
  assign n1786 = n1783 & n1764;
  /* mc68881_pkg.vhd:2257:7  */
  assign n1788 = n1785 & n1764;
  /* mc68881_pkg.vhd:2260:7  */
  assign n1791 = n1779 ? 1'b0 : n1779;
  /* mc68881_pkg.vhd:2260:7  */
  assign n1794 = n1779 ? 32'b01111111111111111111111111111111 : n1782;
  /* mc68881_pkg.vhd:2256:5  */
  assign n1795 = n1798 ? n1791 : n1764;
  /* mc68881_pkg.vhd:2256:5  */
  assign n1797 = n1800 ? n1794 : n1767;
  /* mc68881_pkg.vhd:2256:5  */
  assign n1798 = n1775 & n1764;
  /* mc68881_pkg.vhd:2256:5  */
  assign n1800 = n1775 & n1764;
  /* mc68881_pkg.vhd:2263:47  */
  assign n1801 = n1727[79:16]; // extract
  /* mc68881_pkg.vhd:2263:68  */
  assign n1803 = 32'b00000000000000000000000000111111 - n1758;
  /* mc68881_pkg.vhd:2263:53  */
  assign n1804 = n1803[30:0];  // trunc
  /* mc68881_pkg.vhd:2263:27  */
  assign n1805 = n1801 >> n1804;
  /* mc68881_pkg.vhd:2263:5  */
  assign n1807 = n1795 ? n1805 : 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2264:20  */
  assign n1810 = $unsigned(n1807) > $unsigned(64'b0000000000000000000000000000000001111111111111111111111111111111);
  /* mc68881_pkg.vhd:2265:18  */
  assign n1811 = n1727[0]; // extract
  /* mc68881_pkg.vhd:2265:7  */
  assign n1814 = n1821 ? 1'b0 : n1795;
  /* mc68881_pkg.vhd:2265:7  */
  assign n1817 = n1823 ? 32'b10000000000000000000000000000000 : n1797;
  /* mc68881_pkg.vhd:2265:7  */
  assign n1818 = n1795 & n1811;
  /* mc68881_pkg.vhd:2265:7  */
  assign n1820 = n1795 & n1811;
  /* mc68881_pkg.vhd:2265:7  */
  assign n1821 = n1818 & n1795;
  /* mc68881_pkg.vhd:2265:7  */
  assign n1823 = n1820 & n1795;
  /* mc68881_pkg.vhd:2268:7  */
  assign n1826 = n1814 ? 1'b0 : n1814;
  /* mc68881_pkg.vhd:2268:7  */
  assign n1829 = n1814 ? 32'b01111111111111111111111111111111 : n1817;
  /* mc68881_pkg.vhd:2264:5  */
  assign n1830 = n1833 ? n1826 : n1795;
  /* mc68881_pkg.vhd:2264:5  */
  assign n1832 = n1835 ? n1829 : n1797;
  /* mc68881_pkg.vhd:2264:5  */
  assign n1833 = n1810 & n1795;
  /* mc68881_pkg.vhd:2264:5  */
  assign n1835 = n1810 & n1795;
  /* mc68881_pkg.vhd:2272:38  */
  assign n1836 = n1807[30:0]; // extract
  /* mc68881_pkg.vhd:2272:5  */
  assign n1837 = {1'b0, n1836};  //  uext
  /* mc68881_pkg.vhd:2272:5  */
  assign n1839 = n1830 ? n1837 : 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2273:16  */
  assign n1841 = n1727[0]; // extract
  /* mc68881_pkg.vhd:2274:14  */
  assign n1842 = -n1839;
  /* mc68881_pkg.vhd:2273:5  */
  assign n1844 = n1851 ? 1'b0 : n1830;
  /* mc68881_pkg.vhd:2273:5  */
  assign n1847 = n1853 ? n1842 : n1832;
  /* mc68881_pkg.vhd:2273:5  */
  assign n1848 = n1830 & n1841;
  /* mc68881_pkg.vhd:2273:5  */
  assign n1850 = n1830 & n1841;
  /* mc68881_pkg.vhd:2273:5  */
  assign n1851 = n1848 & n1830;
  /* mc68881_pkg.vhd:2273:5  */
  assign n1853 = n1850 & n1830;
  /* mc68881_pkg.vhd:2276:5  */
  assign n1858 = n1844 ? n1839 : n1847;
  /* mc68881_sgl_ops_unit.vhd:292:37  */
  assign n1859 = n1365[15:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:292:22  */
  assign n1860 = {16'b0, n1859};  //  uext
  /* mc68881_sgl_ops_unit.vhd:292:42  */
  assign n1861 = {1'b0, n1860};  //  uext
  /* mc68881_sgl_ops_unit.vhd:292:42  */
  assign n1862 = n1861 + n1858;
  /* mc68881_sgl_ops_unit.vhd:293:31  */
  assign n1863 = n1365[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:294:22  */
  assign n1865 = $signed(n1862) <= $signed(32'b00000000000000000000000000000000);
  /* mc68881_sgl_ops_unit.vhd:297:25  */
  assign n1869 = $signed(n1862) >= $signed(32'b00000000000000000111111111111111);
  /* mc68881_sgl_ops_unit.vhd:301:40  */
  assign n1871 = n1862[30:0];  // trunc
  /* mc68881_sgl_ops_unit.vhd:301:28  */
  assign n1872 = n1871[14:0];  // trunc
  /* mc68881_sgl_ops_unit.vhd:302:33  */
  assign n1873 = n1365[79:16]; // extract
  assign n1874 = {n1873, n1872};
  assign n1875 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111};
  /* mc68881_sgl_ops_unit.vhd:297:13  */
  assign n1876 = n1869 ? n1875 : n1874;
  assign n1877 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b000000000000000};
  /* mc68881_sgl_ops_unit.vhd:294:13  */
  assign n1878 = n1865 ? n1877 : n1876;
  assign n1885 = {n1878, n1863};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n1886 = n1885[0]; // extract
  assign n1889 = {n1878, n1863};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n1890 = n1889[15:1]; // extract
  assign n1892 = {n1878, n1863};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n1893 = n1892[79:16]; // extract
  assign n1894 = {n1886, n1890, n1893};
  /* mc68881_sgl_ops_unit.vhd:288:11  */
  assign n1895 = n1709 ? b_reg : n1894;
  /* mc68881_sgl_ops_unit.vhd:284:11  */
  assign n1900 = n1478 ? n1672 : n1895;
  /* mc68881_sgl_ops_unit.vhd:281:9  */
  assign n1906 = state_reg == 3'b010;
  /* mc68881_sgl_ops_unit.vhd:310:23  */
  assign n1907 = mul_b_reg[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:311:45  */
  assign n1908 = {24'b0, mul_a_reg};  //  uext
  /* mc68881_sgl_ops_unit.vhd:311:68  */
  assign n1909 = {26'b0, mul_idx_reg};  //  uext
  /* mc68881_sgl_ops_unit.vhd:311:34  */
  assign n1910 = n1908 << n1909;
  /* mc68881_sgl_ops_unit.vhd:311:32  */
  assign n1911 = mul_acc_reg + n1910;
  /* mc68881_sgl_ops_unit.vhd:310:11  */
  assign n1912 = n1907 ? n1911 : mul_acc_reg;
  /* mc68881_sgl_ops_unit.vhd:314:24  */
  assign n1914 = mul_b_reg >> 31'b0000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:315:26  */
  assign n1915 = {27'b0, mul_idx_reg};  //  uext
  /* mc68881_sgl_ops_unit.vhd:315:26  */
  assign n1917 = n1915 == 32'b00000000000000000000000000010111;
  /* mc68881_sgl_ops_unit.vhd:318:40  */
  assign n1918 = {27'b0, mul_idx_reg};  //  uext
  /* mc68881_sgl_ops_unit.vhd:318:40  */
  assign n1920 = n1918 + 32'b00000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:318:28  */
  assign n1921 = n1920[4:0];  // trunc
  /* mc68881_sgl_ops_unit.vhd:315:11  */
  assign n1923 = n1917 ? 3'b101 : state_reg;
  /* mc68881_sgl_ops_unit.vhd:315:11  */
  assign n1924 = n1917 ? mul_idx_reg : n1921;
  /* mc68881_sgl_ops_unit.vhd:308:9  */
  assign n1926 = state_reg == 3'b011;
  /* mc68881_sgl_ops_unit.vhd:322:23  */
  assign n1928 = div_rem_reg << 31'b0000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:324:31  */
  assign n1930 = {1'b0, div_divisor_reg};
  /* mc68881_sgl_ops_unit.vhd:324:23  */
  assign n1931 = $unsigned(n1928) >= $unsigned(n1930);
  /* mc68881_sgl_ops_unit.vhd:325:41  */
  assign n1933 = {1'b0, div_divisor_reg};
  /* mc68881_sgl_ops_unit.vhd:325:34  */
  assign n1934 = n1928 - n1933;
  /* mc68881_sgl_ops_unit.vhd:324:11  */
  assign n1941 = n1931 ? n1934 : n1928;
  /* mc68881_sgl_ops_unit.vhd:324:11  */
  assign n1942 = n1931 ? n2638 : n2742;
  /* mc68881_sgl_ops_unit.vhd:332:26  */
  assign n1943 = {27'b0, div_idx_reg};  //  uext
  /* mc68881_sgl_ops_unit.vhd:332:26  */
  assign n1945 = n1943 == 32'b00000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:335:40  */
  assign n1946 = {27'b0, div_idx_reg};  //  uext
  /* mc68881_sgl_ops_unit.vhd:335:40  */
  assign n1948 = n1946 - 32'b00000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:335:28  */
  assign n1949 = n1948[4:0];  // trunc
  /* mc68881_sgl_ops_unit.vhd:332:11  */
  assign n1951 = n1945 ? 3'b110 : state_reg;
  /* mc68881_sgl_ops_unit.vhd:332:11  */
  assign n1952 = n1945 ? div_idx_reg : n1949;
  /* mc68881_sgl_ops_unit.vhd:321:9  */
  assign n1954 = state_reg == 3'b100;
  /* mc68881_sgl_ops_unit.vhd:341:26  */
  assign n1956 = mul_acc_reg == 48'b000000000000000000000000000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:346:27  */
  assign n1957 = mul_acc_reg[47]; // extract
  /* mc68881_sgl_ops_unit.vhd:347:35  */
  assign n1958 = mul_acc_reg[47:24]; // extract
  /* mc68881_sgl_ops_unit.vhd:348:39  */
  assign n1959 = mul_acc_reg[23]; // extract
  /* mc68881_sgl_ops_unit.vhd:349:29  */
  assign n1960 = mul_acc_reg[22:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:349:43  */
  assign n1962 = n1960 != 23'b00000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:349:15  */
  assign n1965 = n1962 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:354:30  */
  assign n1967 = mul_exp_base_reg + 32'b00000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:356:35  */
  assign n1968 = mul_acc_reg[46:23]; // extract
  /* mc68881_sgl_ops_unit.vhd:357:39  */
  assign n1969 = mul_acc_reg[22]; // extract
  /* mc68881_sgl_ops_unit.vhd:358:29  */
  assign n1970 = mul_acc_reg[21:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:358:43  */
  assign n1972 = n1970 != 22'b0000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:358:15  */
  assign n1975 = n1972 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:346:13  */
  assign n1976 = n1957 ? n1958 : n1968;
  /* mc68881_sgl_ops_unit.vhd:346:13  */
  assign n1977 = n1957 ? n1967 : mul_exp_base_reg;
  /* mc68881_sgl_ops_unit.vhd:346:13  */
  assign n1978 = n1957 ? n1959 : n1969;
  /* mc68881_sgl_ops_unit.vhd:346:13  */
  assign n1979 = n1957 ? n1965 : n1975;
  /* mc68881_sgl_ops_unit.vhd:365:82  */
  assign n1981 = n1976[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:124:42  */
  assign n1987 = n1979 | n1981;
  /* mc68881_sgl_ops_unit.vhd:124:24  */
  assign n1988 = n1987 & n1978;
  /* mc68881_sgl_ops_unit.vhd:124:9  */
  assign n1991 = n1988 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:123:7  */
  assign n1993 = rm_reg == 2'b00;
  /* mc68881_sgl_ops_unit.vhd:127:7  */
  assign n1995 = rm_reg == 2'b01;
  /* mc68881_sgl_ops_unit.vhd:130:44  */
  assign n1996 = n1978 | n1979;
  /* mc68881_sgl_ops_unit.vhd:130:27  */
  assign n1997 = n1996 & mul_sign_reg;
  /* mc68881_sgl_ops_unit.vhd:130:9  */
  assign n2000 = n1997 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:129:7  */
  assign n2002 = rm_reg == 2'b10;
  /* mc68881_sgl_ops_unit.vhd:134:21  */
  assign n2003 = ~mul_sign_reg;
  /* mc68881_sgl_ops_unit.vhd:134:44  */
  assign n2004 = n1978 | n1979;
  /* mc68881_sgl_ops_unit.vhd:134:27  */
  assign n2005 = n2004 & n2003;
  /* mc68881_sgl_ops_unit.vhd:134:9  */
  assign n2008 = n2005 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:133:7  */
  assign n2010 = rm_reg == 2'b11;
  assign n2011 = {n2010, n2002, n1995, n1993};
  /* mc68881_sgl_ops_unit.vhd:122:5  */
  always @*
    case (n2011)
      4'b1000: n2014 = n2008;
      4'b0100: n2014 = n2000;
      4'b0010: n2014 = 1'b0;
      4'b0001: n2014 = n1991;
      default: n2014 = 1'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:366:29  */
  assign n2017 = {1'b0, n1976};
  /* mc68881_sgl_ops_unit.vhd:366:38  */
  assign n2019 = n2017 + 25'b0000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:367:23  */
  assign n2020 = n2019[24]; // extract
  /* mc68881_sgl_ops_unit.vhd:368:31  */
  assign n2021 = n2019[24:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:369:32  */
  assign n2023 = n1977 + 32'b00000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:371:31  */
  assign n2024 = n2019[23:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:367:15  */
  assign n2025 = n2020 ? n2021 : n2024;
  /* mc68881_sgl_ops_unit.vhd:365:13  */
  assign n2026 = n2029 ? n2023 : n1977;
  /* mc68881_sgl_ops_unit.vhd:365:13  */
  assign n2027 = n2014 ? n2025 : n1976;
  /* mc68881_sgl_ops_unit.vhd:365:13  */
  assign n2029 = n2020 & n2014;
  /* mc68881_sgl_ops_unit.vhd:375:22  */
  assign n2031 = $signed(n2026) <= $signed(32'b00000000000000000000000000000000);
  /* mc68881_sgl_ops_unit.vhd:377:25  */
  assign n2033 = $signed(n2026) >= $signed(32'b00000000000000000111111111111111);
  assign n2041 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, mul_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n2042 = n2041[0]; // extract
  assign n2045 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, mul_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n2046 = n2045[15:1]; // extract
  assign n2048 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, mul_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n2049 = n2048[79:16]; // extract
  assign n2050 = {n2042, n2046, n2049};
  /* mc68881_sgl_ops_unit.vhd:382:40  */
  assign n2051 = n2026[30:0];  // trunc
  /* mc68881_sgl_ops_unit.vhd:382:28  */
  assign n2052 = n2051[14:0];  // trunc
  assign n2054 = {n2027, 40'b0000000000000000000000000000000000000000};
  assign n2061 = {n2054, n2052, mul_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n2062 = n2061[0]; // extract
  assign n2065 = {n2054, n2052, mul_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n2066 = n2065[15:1]; // extract
  assign n2068 = {n2054, n2052, mul_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n2069 = n2068[79:16]; // extract
  assign n2070 = {n2062, n2066, n2069};
  /* mc68881_sgl_ops_unit.vhd:377:13  */
  assign n2071 = n2033 ? n2050 : n2070;
  /* mc68881_sgl_ops_unit.vhd:375:13  */
  assign n2078 = n2031 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2071;
  /* mc68881_sgl_ops_unit.vhd:341:11  */
  assign n2084 = n1956 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2078;
  /* mc68881_sgl_ops_unit.vhd:338:9  */
  assign n2097 = state_reg == 3'b101;
  /* mc68881_sgl_ops_unit.vhd:393:39  */
  assign n2099 = div_quot_reg == 24'b000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:401:29  */
  assign n2101 = div_rem_reg << 31'b0000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:402:37  */
  assign n2103 = {1'b0, div_divisor_reg};
  /* mc68881_sgl_ops_unit.vhd:402:29  */
  assign n2104 = $unsigned(n2101) >= $unsigned(n2103);
  /* mc68881_sgl_ops_unit.vhd:404:51  */
  assign n2106 = {1'b0, div_divisor_reg};
  /* mc68881_sgl_ops_unit.vhd:404:44  */
  assign n2107 = n2101 - n2106;
  /* mc68881_sgl_ops_unit.vhd:402:13  */
  assign n2110 = n2104 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:402:13  */
  assign n2111 = n2104 ? n2107 : n2101;
  /* mc68881_sgl_ops_unit.vhd:409:29  */
  assign n2113 = n2111 != 25'b0000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:409:13  */
  assign n2116 = n2113 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:416:21  */
  assign n2117 = div_quot_reg[23]; // extract
  /* mc68881_sgl_ops_unit.vhd:416:26  */
  assign n2118 = ~n2117;
  /* mc68881_sgl_ops_unit.vhd:417:29  */
  assign n2119 = div_quot_reg[22:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:417:43  */
  assign n2120 = {n2119, n2110};
  /* mc68881_sgl_ops_unit.vhd:418:32  */
  assign n2122 = n2111 << 31'b0000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:419:40  */
  assign n2124 = {1'b0, div_divisor_reg};
  /* mc68881_sgl_ops_unit.vhd:419:32  */
  assign n2125 = $unsigned(n2122) >= $unsigned(n2124);
  /* mc68881_sgl_ops_unit.vhd:421:55  */
  assign n2127 = {1'b0, div_divisor_reg};
  /* mc68881_sgl_ops_unit.vhd:421:48  */
  assign n2128 = n2122 - n2127;
  /* mc68881_sgl_ops_unit.vhd:419:15  */
  assign n2131 = n2125 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:419:15  */
  assign n2132 = n2125 ? n2128 : n2122;
  /* mc68881_sgl_ops_unit.vhd:425:32  */
  assign n2134 = n2132 != 25'b0000000000000000000000000;
  /* mc68881_sgl_ops_unit.vhd:416:13  */
  assign n2136 = n2142 ? 1'b1 : n2116;
  /* mc68881_sgl_ops_unit.vhd:428:30  */
  assign n2138 = div_exp_base_reg - 32'b00000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:416:13  */
  assign n2139 = n2118 ? n2120 : div_quot_reg;
  /* mc68881_sgl_ops_unit.vhd:416:13  */
  assign n2140 = n2118 ? n2138 : div_exp_base_reg;
  /* mc68881_sgl_ops_unit.vhd:416:13  */
  assign n2141 = n2118 ? n2131 : n2110;
  /* mc68881_sgl_ops_unit.vhd:416:13  */
  assign n2142 = n2134 & n2118;
  /* mc68881_sgl_ops_unit.vhd:431:82  */
  assign n2145 = n2139[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:124:42  */
  assign n2151 = n2136 | n2145;
  /* mc68881_sgl_ops_unit.vhd:124:24  */
  assign n2152 = n2151 & n2141;
  /* mc68881_sgl_ops_unit.vhd:124:9  */
  assign n2155 = n2152 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:123:7  */
  assign n2157 = rm_reg == 2'b00;
  /* mc68881_sgl_ops_unit.vhd:127:7  */
  assign n2159 = rm_reg == 2'b01;
  /* mc68881_sgl_ops_unit.vhd:130:44  */
  assign n2160 = n2141 | n2136;
  /* mc68881_sgl_ops_unit.vhd:130:27  */
  assign n2161 = n2160 & div_sign_reg;
  /* mc68881_sgl_ops_unit.vhd:130:9  */
  assign n2164 = n2161 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:129:7  */
  assign n2166 = rm_reg == 2'b10;
  /* mc68881_sgl_ops_unit.vhd:134:21  */
  assign n2167 = ~div_sign_reg;
  /* mc68881_sgl_ops_unit.vhd:134:44  */
  assign n2168 = n2141 | n2136;
  /* mc68881_sgl_ops_unit.vhd:134:27  */
  assign n2169 = n2168 & n2167;
  /* mc68881_sgl_ops_unit.vhd:134:9  */
  assign n2172 = n2169 ? 1'b1 : 1'b0;
  /* mc68881_sgl_ops_unit.vhd:133:7  */
  assign n2174 = rm_reg == 2'b11;
  assign n2175 = {n2174, n2166, n2159, n2157};
  /* mc68881_sgl_ops_unit.vhd:122:5  */
  always @*
    case (n2175)
      4'b1000: n2178 = n2172;
      4'b0100: n2178 = n2164;
      4'b0010: n2178 = 1'b0;
      4'b0001: n2178 = n2155;
      default: n2178 = 1'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:432:29  */
  assign n2181 = {1'b0, n2139};
  /* mc68881_sgl_ops_unit.vhd:432:38  */
  assign n2183 = n2181 + 25'b0000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:433:23  */
  assign n2184 = n2183[24]; // extract
  /* mc68881_sgl_ops_unit.vhd:434:31  */
  assign n2185 = n2183[24:1]; // extract
  /* mc68881_sgl_ops_unit.vhd:435:32  */
  assign n2187 = n2140 + 32'b00000000000000000000000000000001;
  /* mc68881_sgl_ops_unit.vhd:437:31  */
  assign n2188 = n2183[23:0]; // extract
  /* mc68881_sgl_ops_unit.vhd:433:15  */
  assign n2189 = n2184 ? n2185 : n2188;
  /* mc68881_sgl_ops_unit.vhd:431:13  */
  assign n2190 = n2193 ? n2187 : n2140;
  /* mc68881_sgl_ops_unit.vhd:431:13  */
  assign n2191 = n2178 ? n2189 : n2139;
  /* mc68881_sgl_ops_unit.vhd:431:13  */
  assign n2193 = n2184 & n2178;
  /* mc68881_sgl_ops_unit.vhd:441:22  */
  assign n2195 = $signed(n2190) <= $signed(32'b00000000000000000000000000000000);
  /* mc68881_sgl_ops_unit.vhd:443:25  */
  assign n2197 = $signed(n2190) >= $signed(32'b00000000000000000111111111111111);
  assign n2205 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, div_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n2206 = n2205[0]; // extract
  assign n2209 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, div_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n2210 = n2209[15:1]; // extract
  assign n2212 = {64'b0000000000000000000000000000000000000000000000000000000000000000, 15'b111111111111111, div_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n2213 = n2212[79:16]; // extract
  assign n2214 = {n2206, n2210, n2213};
  /* mc68881_sgl_ops_unit.vhd:448:40  */
  assign n2215 = n2190[30:0];  // trunc
  /* mc68881_sgl_ops_unit.vhd:448:28  */
  assign n2216 = n2215[14:0];  // trunc
  assign n2218 = {n2191, 40'b0000000000000000000000000000000000000000};
  assign n2225 = {n2218, n2216, div_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:78:33  */
  assign n2226 = n2225[0]; // extract
  assign n2229 = {n2218, n2216, div_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:79:81  */
  assign n2230 = n2229[15:1]; // extract
  assign n2232 = {n2218, n2216, div_sign_reg};
  /* mc68881_sgl_ops_unit.vhd:80:64  */
  assign n2233 = n2232[79:16]; // extract
  assign n2234 = {n2226, n2230, n2233};
  /* mc68881_sgl_ops_unit.vhd:443:13  */
  assign n2235 = n2197 ? n2214 : n2234;
  /* mc68881_sgl_ops_unit.vhd:441:13  */
  assign n2242 = n2195 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2235;
  /* mc68881_sgl_ops_unit.vhd:394:11  */
  assign n2248 = n2099 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n2242;
  /* mc68881_sgl_ops_unit.vhd:390:9  */
  assign n2264 = state_reg == 3'b110;
  /* mc68881_sgl_ops_unit.vhd:456:9  */
  assign n2266 = state_reg == 3'b111;
  assign n2267 = {n2266, n2264, n2097, n1954, n1926, n1906, n1339, n51};
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2273 = 3'b000;
      8'b01000000: n2273 = 3'b111;
      8'b00100000: n2273 = 3'b111;
      8'b00010000: n2273 = n1951;
      8'b00001000: n2273 = n1923;
      8'b00000100: n2273 = 3'b111;
      8'b00000010: n2273 = n1322;
      8'b00000001: n2273 = n45;
      default: n2273 = 3'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2275 = op_reg;
      8'b01000000: n2275 = op_reg;
      8'b00100000: n2275 = op_reg;
      8'b00010000: n2275 = op_reg;
      8'b00001000: n2275 = op_reg;
      8'b00000100: n2275 = op_reg;
      8'b00000010: n2275 = op_reg;
      8'b00000001: n2275 = n46;
      default: n2275 = 6'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2277 = a_reg;
      8'b01000000: n2277 = a_reg;
      8'b00100000: n2277 = a_reg;
      8'b00010000: n2277 = a_reg;
      8'b00001000: n2277 = a_reg;
      8'b00000100: n2277 = a_reg;
      8'b00000010: n2277 = a_reg;
      8'b00000001: n2277 = n47;
      default: n2277 = 80'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2279 = b_reg;
      8'b01000000: n2279 = b_reg;
      8'b00100000: n2279 = b_reg;
      8'b00010000: n2279 = b_reg;
      8'b00001000: n2279 = b_reg;
      8'b00000100: n2279 = b_reg;
      8'b00000010: n2279 = b_reg;
      8'b00000001: n2279 = n48;
      default: n2279 = 80'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2281 = rm_reg;
      8'b01000000: n2281 = rm_reg;
      8'b00100000: n2281 = rm_reg;
      8'b00010000: n2281 = rm_reg;
      8'b00001000: n2281 = rm_reg;
      8'b00000100: n2281 = rm_reg;
      8'b00000010: n2281 = rm_reg;
      8'b00000001: n2281 = n49;
      default: n2281 = 2'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2285 = 1'b1;
      8'b01000000: n2285 = 1'b0;
      8'b00100000: n2285 = 1'b0;
      8'b00010000: n2285 = 1'b0;
      8'b00001000: n2285 = 1'b0;
      8'b00000100: n2285 = 1'b0;
      8'b00000010: n2285 = 1'b0;
      8'b00000001: n2285 = 1'b0;
      default: n2285 = 1'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2288 = result_reg;
      8'b01000000: n2288 = n2248;
      8'b00100000: n2288 = n2084;
      8'b00010000: n2288 = result_reg;
      8'b00001000: n2288 = result_reg;
      8'b00000100: n2288 = n1900;
      8'b00000010: n2288 = n1323;
      8'b00000001: n2288 = result_reg;
      default: n2288 = 80'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2290 = mul_a_reg;
      8'b01000000: n2290 = mul_a_reg;
      8'b00100000: n2290 = mul_a_reg;
      8'b00010000: n2290 = mul_a_reg;
      8'b00001000: n2290 = mul_a_reg;
      8'b00000100: n2290 = mul_a_reg;
      8'b00000010: n2290 = n1324;
      8'b00000001: n2290 = mul_a_reg;
      default: n2290 = 24'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2292 = mul_b_reg;
      8'b01000000: n2292 = mul_b_reg;
      8'b00100000: n2292 = mul_b_reg;
      8'b00010000: n2292 = mul_b_reg;
      8'b00001000: n2292 = n1914;
      8'b00000100: n2292 = mul_b_reg;
      8'b00000010: n2292 = n1325;
      8'b00000001: n2292 = mul_b_reg;
      default: n2292 = 24'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2294 = mul_acc_reg;
      8'b01000000: n2294 = mul_acc_reg;
      8'b00100000: n2294 = mul_acc_reg;
      8'b00010000: n2294 = mul_acc_reg;
      8'b00001000: n2294 = n1912;
      8'b00000100: n2294 = mul_acc_reg;
      8'b00000010: n2294 = n1326;
      8'b00000001: n2294 = mul_acc_reg;
      default: n2294 = 48'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2296 = mul_idx_reg;
      8'b01000000: n2296 = mul_idx_reg;
      8'b00100000: n2296 = mul_idx_reg;
      8'b00010000: n2296 = mul_idx_reg;
      8'b00001000: n2296 = n1924;
      8'b00000100: n2296 = mul_idx_reg;
      8'b00000010: n2296 = n1327;
      8'b00000001: n2296 = mul_idx_reg;
      default: n2296 = 5'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2298 = mul_sign_reg;
      8'b01000000: n2298 = mul_sign_reg;
      8'b00100000: n2298 = mul_sign_reg;
      8'b00010000: n2298 = mul_sign_reg;
      8'b00001000: n2298 = mul_sign_reg;
      8'b00000100: n2298 = mul_sign_reg;
      8'b00000010: n2298 = n1328;
      8'b00000001: n2298 = mul_sign_reg;
      default: n2298 = 1'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2300 = mul_exp_base_reg;
      8'b01000000: n2300 = mul_exp_base_reg;
      8'b00100000: n2300 = mul_exp_base_reg;
      8'b00010000: n2300 = mul_exp_base_reg;
      8'b00001000: n2300 = mul_exp_base_reg;
      8'b00000100: n2300 = mul_exp_base_reg;
      8'b00000010: n2300 = n1329;
      8'b00000001: n2300 = mul_exp_base_reg;
      default: n2300 = 32'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2302 = div_divisor_reg;
      8'b01000000: n2302 = div_divisor_reg;
      8'b00100000: n2302 = div_divisor_reg;
      8'b00010000: n2302 = div_divisor_reg;
      8'b00001000: n2302 = div_divisor_reg;
      8'b00000100: n2302 = div_divisor_reg;
      8'b00000010: n2302 = n1330;
      8'b00000001: n2302 = div_divisor_reg;
      default: n2302 = 24'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2304 = div_rem_reg;
      8'b01000000: n2304 = div_rem_reg;
      8'b00100000: n2304 = div_rem_reg;
      8'b00010000: n2304 = n1941;
      8'b00001000: n2304 = div_rem_reg;
      8'b00000100: n2304 = div_rem_reg;
      8'b00000010: n2304 = n1331;
      8'b00000001: n2304 = div_rem_reg;
      default: n2304 = 25'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2306 = div_quot_reg;
      8'b01000000: n2306 = div_quot_reg;
      8'b00100000: n2306 = div_quot_reg;
      8'b00010000: n2306 = n1942;
      8'b00001000: n2306 = div_quot_reg;
      8'b00000100: n2306 = div_quot_reg;
      8'b00000010: n2306 = n1332;
      8'b00000001: n2306 = div_quot_reg;
      default: n2306 = 24'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2308 = div_idx_reg;
      8'b01000000: n2308 = div_idx_reg;
      8'b00100000: n2308 = div_idx_reg;
      8'b00010000: n2308 = n1952;
      8'b00001000: n2308 = div_idx_reg;
      8'b00000100: n2308 = div_idx_reg;
      8'b00000010: n2308 = n1333;
      8'b00000001: n2308 = div_idx_reg;
      default: n2308 = 5'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2310 = div_sign_reg;
      8'b01000000: n2310 = div_sign_reg;
      8'b00100000: n2310 = div_sign_reg;
      8'b00010000: n2310 = div_sign_reg;
      8'b00001000: n2310 = div_sign_reg;
      8'b00000100: n2310 = div_sign_reg;
      8'b00000010: n2310 = n1334;
      8'b00000001: n2310 = div_sign_reg;
      default: n2310 = 1'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  always @*
    case (n2267)
      8'b10000000: n2312 = div_exp_base_reg;
      8'b01000000: n2312 = div_exp_base_reg;
      8'b00100000: n2312 = div_exp_base_reg;
      8'b00010000: n2312 = div_exp_base_reg;
      8'b00001000: n2312 = div_exp_base_reg;
      8'b00000100: n2312 = div_exp_base_reg;
      8'b00000010: n2312 = n1335;
      8'b00000001: n2312 = div_exp_base_reg;
      default: n2312 = 32'bX;
    endcase
  /* mc68881_sgl_ops_unit.vhd:463:30  */
  assign n2513 = state_reg == 3'b000;
  /* mc68881_sgl_ops_unit.vhd:463:15  */
  assign n2514 = n2513 ? 1'b0 : 1'b1;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2516 <= 3'b000;
    else
      n2516 <= n2273;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2517 <= 6'b000000;
    else
      n2517 <= n2275;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2518 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n2518 <= n2277;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2519 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n2519 <= n2279;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2520 <= 2'b00;
    else
      n2520 <= n2281;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2521 <= 1'b0;
    else
      n2521 <= n2285;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2522 <= 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
    else
      n2522 <= n2288;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2523 <= 24'b000000000000000000000000;
    else
      n2523 <= n2290;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2524 <= 24'b000000000000000000000000;
    else
      n2524 <= n2292;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2525 <= 48'b000000000000000000000000000000000000000000000000;
    else
      n2525 <= n2294;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2526 <= 5'b00000;
    else
      n2526 <= n2296;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2527 <= 1'b0;
    else
      n2527 <= n2298;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2528 <= 32'b00000000000000000000000000000000;
    else
      n2528 <= n2300;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2529 <= 24'b000000000000000000000000;
    else
      n2529 <= n2302;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2530 <= 25'b0000000000000000000000000;
    else
      n2530 <= n2304;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2531 <= 24'b000000000000000000000000;
    else
      n2531 <= n2306;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2532 <= 5'b10110;
    else
      n2532 <= n2308;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2533 <= 1'b0;
    else
      n2533 <= n2310;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  always @(posedge clk or posedge n42)
    if (n42)
      n2534 <= 32'b00000000000000000000000000000000;
    else
      n2534 <= n2312;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2535 = div_idx_reg[4]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2536 = ~n2535;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2537 = div_idx_reg[3]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2538 = ~n2537;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2539 = n2536 & n2538;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2540 = n2536 & n2537;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2541 = n2535 & n2538;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2542 = div_idx_reg[2]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2543 = ~n2542;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2544 = n2539 & n2543;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2545 = n2539 & n2542;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2546 = n2540 & n2543;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2547 = n2540 & n2542;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2548 = n2541 & n2543;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2549 = n2541 & n2542;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2550 = div_idx_reg[1]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2551 = ~n2550;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2552 = n2544 & n2551;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2553 = n2544 & n2550;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2554 = n2545 & n2551;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2555 = n2545 & n2550;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2556 = n2546 & n2551;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2557 = n2546 & n2550;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2558 = n2547 & n2551;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2559 = n2547 & n2550;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2560 = n2548 & n2551;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2561 = n2548 & n2550;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2562 = n2549 & n2551;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2563 = n2549 & n2550;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2564 = div_idx_reg[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2565 = ~n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2566 = n2552 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2567 = n2552 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2568 = n2553 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2569 = n2553 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2570 = n2554 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2571 = n2554 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2572 = n2555 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2573 = n2555 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2574 = n2556 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2575 = n2556 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2576 = n2557 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2577 = n2557 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2578 = n2558 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2579 = n2558 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2580 = n2559 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2581 = n2559 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2582 = n2560 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2583 = n2560 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2584 = n2561 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2585 = n2561 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2586 = n2562 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2587 = n2562 & n2564;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2588 = n2563 & n2565;
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2589 = n2563 & n2564;
  /* mc68881_sgl_ops_unit.vhd:181:5  */
  assign n2590 = div_quot_reg[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2591 = n2566 ? 1'b1 : n2590;
  assign n2592 = div_quot_reg[1]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2593 = n2567 ? 1'b1 : n2592;
  assign n2594 = div_quot_reg[2]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2595 = n2568 ? 1'b1 : n2594;
  assign n2596 = div_quot_reg[3]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2597 = n2569 ? 1'b1 : n2596;
  assign n2598 = div_quot_reg[4]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2599 = n2570 ? 1'b1 : n2598;
  assign n2600 = div_quot_reg[5]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2601 = n2571 ? 1'b1 : n2600;
  assign n2602 = div_quot_reg[6]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2603 = n2572 ? 1'b1 : n2602;
  assign n2604 = div_quot_reg[7]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2605 = n2573 ? 1'b1 : n2604;
  assign n2606 = div_quot_reg[8]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2607 = n2574 ? 1'b1 : n2606;
  assign n2608 = div_quot_reg[9]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2609 = n2575 ? 1'b1 : n2608;
  assign n2610 = div_quot_reg[10]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2611 = n2576 ? 1'b1 : n2610;
  assign n2612 = div_quot_reg[11]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2613 = n2577 ? 1'b1 : n2612;
  assign n2614 = div_quot_reg[12]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2615 = n2578 ? 1'b1 : n2614;
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  assign n2616 = div_quot_reg[13]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2617 = n2579 ? 1'b1 : n2616;
  assign n2618 = div_quot_reg[14]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2619 = n2580 ? 1'b1 : n2618;
  assign n2620 = div_quot_reg[15]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2621 = n2581 ? 1'b1 : n2620;
  assign n2622 = div_quot_reg[16]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2623 = n2582 ? 1'b1 : n2622;
  assign n2624 = div_quot_reg[17]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2625 = n2583 ? 1'b1 : n2624;
  assign n2626 = div_quot_reg[18]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2627 = n2584 ? 1'b1 : n2626;
  assign n2628 = div_quot_reg[19]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2629 = n2585 ? 1'b1 : n2628;
  assign n2630 = div_quot_reg[20]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2631 = n2586 ? 1'b1 : n2630;
  assign n2632 = div_quot_reg[21]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2633 = n2587 ? 1'b1 : n2632;
  /* mc68881_sgl_ops_unit.vhd:183:7  */
  assign n2634 = div_quot_reg[22]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2635 = n2588 ? 1'b1 : n2634;
  assign n2636 = div_quot_reg[23]; // extract
  /* mc68881_sgl_ops_unit.vhd:326:13  */
  assign n2637 = n2589 ? 1'b1 : n2636;
  assign n2638 = {n2637, n2635, n2633, n2631, n2629, n2627, n2625, n2623, n2621, n2619, n2617, n2615, n2613, n2611, n2609, n2607, n2605, n2603, n2601, n2599, n2597, n2595, n2593, n2591};
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2639 = div_idx_reg[4]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2640 = ~n2639;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2641 = div_idx_reg[3]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2642 = ~n2641;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2643 = n2640 & n2642;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2644 = n2640 & n2641;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2645 = n2639 & n2642;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2646 = div_idx_reg[2]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2647 = ~n2646;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2648 = n2643 & n2647;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2649 = n2643 & n2646;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2650 = n2644 & n2647;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2651 = n2644 & n2646;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2652 = n2645 & n2647;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2653 = n2645 & n2646;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2654 = div_idx_reg[1]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2655 = ~n2654;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2656 = n2648 & n2655;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2657 = n2648 & n2654;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2658 = n2649 & n2655;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2659 = n2649 & n2654;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2660 = n2650 & n2655;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2661 = n2650 & n2654;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2662 = n2651 & n2655;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2663 = n2651 & n2654;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2664 = n2652 & n2655;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2665 = n2652 & n2654;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2666 = n2653 & n2655;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2667 = n2653 & n2654;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2668 = div_idx_reg[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2669 = ~n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2670 = n2656 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2671 = n2656 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2672 = n2657 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2673 = n2657 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2674 = n2658 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2675 = n2658 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2676 = n2659 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2677 = n2659 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2678 = n2660 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2679 = n2660 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2680 = n2661 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2681 = n2661 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2682 = n2662 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2683 = n2662 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2684 = n2663 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2685 = n2663 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2686 = n2664 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2687 = n2664 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2688 = n2665 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2689 = n2665 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2690 = n2666 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2691 = n2666 & n2668;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2692 = n2667 & n2669;
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2693 = n2667 & n2668;
  /* mc68881_sgl_ops_unit.vhd:113:12  */
  assign n2694 = div_quot_reg[0]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2695 = n2670 ? 1'b0 : n2694;
  /* mc68881_sgl_ops_unit.vhd:341:11  */
  assign n2696 = div_quot_reg[1]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2697 = n2671 ? 1'b0 : n2696;
  /* mc68881_sgl_ops_unit.vhd:341:11  */
  assign n2698 = div_quot_reg[2]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2699 = n2672 ? 1'b0 : n2698;
  assign n2700 = div_quot_reg[3]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2701 = n2673 ? 1'b0 : n2700;
  assign n2702 = div_quot_reg[4]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2703 = n2674 ? 1'b0 : n2702;
  /* mc68881_sgl_ops_unit.vhd:341:11  */
  assign n2704 = div_quot_reg[5]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2705 = n2675 ? 1'b0 : n2704;
  assign n2706 = div_quot_reg[6]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2707 = n2676 ? 1'b0 : n2706;
  assign n2708 = div_quot_reg[7]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2709 = n2677 ? 1'b0 : n2708;
  assign n2710 = div_quot_reg[8]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2711 = n2678 ? 1'b0 : n2710;
  assign n2712 = div_quot_reg[9]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2713 = n2679 ? 1'b0 : n2712;
  assign n2714 = div_quot_reg[10]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2715 = n2680 ? 1'b0 : n2714;
  assign n2716 = div_quot_reg[11]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2717 = n2681 ? 1'b0 : n2716;
  assign n2718 = div_quot_reg[12]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2719 = n2682 ? 1'b0 : n2718;
  assign n2720 = div_quot_reg[13]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2721 = n2683 ? 1'b0 : n2720;
  /* mc68881_sgl_ops_unit.vhd:75:12  */
  assign n2722 = div_quot_reg[14]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2723 = n2684 ? 1'b0 : n2722;
  /* mc68881_sgl_ops_unit.vhd:75:12  */
  assign n2724 = div_quot_reg[15]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2725 = n2685 ? 1'b0 : n2724;
  assign n2726 = div_quot_reg[16]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2727 = n2686 ? 1'b0 : n2726;
  /* mc68881_sgl_ops_unit.vhd:76:14  */
  assign n2728 = div_quot_reg[17]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2729 = n2687 ? 1'b0 : n2728;
  /* mc68881_sgl_ops_unit.vhd:75:12  */
  assign n2730 = div_quot_reg[18]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2731 = n2688 ? 1'b0 : n2730;
  assign n2732 = div_quot_reg[19]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2733 = n2689 ? 1'b0 : n2732;
  /* mc68881_sgl_ops_unit.vhd:365:13  */
  assign n2734 = div_quot_reg[20]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2735 = n2690 ? 1'b0 : n2734;
  /* mc68881_sgl_ops_unit.vhd:120:14  */
  assign n2736 = div_quot_reg[21]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2737 = n2691 ? 1'b0 : n2736;
  /* mc68881_sgl_ops_unit.vhd:113:12  */
  assign n2738 = div_quot_reg[22]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2739 = n2692 ? 1'b0 : n2738;
  assign n2740 = div_quot_reg[23]; // extract
  /* mc68881_sgl_ops_unit.vhd:328:13  */
  assign n2741 = n2693 ? 1'b0 : n2740;
  /* mc68881_sgl_ops_unit.vhd:284:11  */
  assign n2742 = {n2741, n2739, n2737, n2735, n2733, n2731, n2729, n2727, n2725, n2723, n2721, n2719, n2717, n2715, n2713, n2711, n2709, n2707, n2705, n2703, n2701, n2699, n2697, n2695};
endmodule

