module mc68881_fp80_mul_unit
  (input  clk,
   input  reset_n,
   input  start,
   input  [79:0] a_in,
   input  [79:0] b_in,
   input  [1:0] round_mode,
   input  [1:0] round_prec,
   output busy,
   output done,
   output [79:0] result);
  reg [1:0] state_reg;
  reg [79:0] a_reg;
  reg [79:0] b_reg;
  reg [1:0] rm_reg;
  reg [1:0] rp_reg;
  reg [63:0] a_mant_reg;
  reg [63:0] b_mant_reg;
  reg res_sign_reg;
  reg [17:0] exp_res_reg;
  reg early_exit_reg;
  reg [79:0] early_result_reg;
  reg [127:0] mant_prod_reg;
  reg done_reg;
  reg [79:0] result_reg;
  wire n41;
  wire [1:0] n43;
  wire [79:0] n44;
  wire [79:0] n45;
  wire [1:0] n46;
  wire [1:0] n47;
  wire n49;
  wire [63:0] n50;
  wire [63:0] n51;
  wire [14:0] n52;
  wire n54;
  wire n56;
  wire n57;
  wire [31:0] n64;
  wire n66;
  wire [31:0] n67;
  wire [63:0] n69;
  wire [30:0] n72;
  wire [63:0] n74;
  wire [15:0] n75;
  wire n77;
  wire [31:0] n78;
  wire [31:0] n80;
  wire [30:0] n81;
  wire [47:0] n82;
  wire [63:0] n84;
  wire [30:0] n85;
  wire [63:0] n86;
  wire [7:0] n87;
  wire n89;
  wire [31:0] n90;
  wire [31:0] n92;
  wire [30:0] n93;
  wire [55:0] n94;
  wire [63:0] n96;
  wire [30:0] n97;
  wire [63:0] n98;
  wire [3:0] n99;
  wire n101;
  wire [31:0] n102;
  wire [31:0] n104;
  wire [30:0] n105;
  wire [59:0] n106;
  wire [63:0] n108;
  wire [30:0] n109;
  wire [63:0] n110;
  wire [1:0] n111;
  wire n113;
  wire [31:0] n114;
  wire [31:0] n116;
  wire [30:0] n117;
  wire [61:0] n118;
  wire [63:0] n120;
  wire [30:0] n121;
  wire [63:0] n122;
  wire n123;
  wire n124;
  wire [31:0] n125;
  wire [31:0] n127;
  wire [30:0] n128;
  wire [30:0] n129;
  wire [63:0] n130;
  wire [31:0] n131;
  wire [31:0] n133;
  wire [14:0] n134;
  wire [30:0] n135;
  wire [31:0] n136;
  wire [31:0] n138;
  wire [63:0] n139;
  wire [14:0] n140;
  wire n142;
  wire n144;
  wire n145;
  wire [31:0] n152;
  wire n154;
  wire [31:0] n155;
  wire [63:0] n157;
  wire [30:0] n160;
  wire [63:0] n162;
  wire [15:0] n163;
  wire n165;
  wire [31:0] n166;
  wire [31:0] n168;
  wire [30:0] n169;
  wire [47:0] n170;
  wire [63:0] n172;
  wire [30:0] n173;
  wire [63:0] n174;
  wire [7:0] n175;
  wire n177;
  wire [31:0] n178;
  wire [31:0] n180;
  wire [30:0] n181;
  wire [55:0] n182;
  wire [63:0] n184;
  wire [30:0] n185;
  wire [63:0] n186;
  wire [3:0] n187;
  wire n189;
  wire [31:0] n190;
  wire [31:0] n192;
  wire [30:0] n193;
  wire [59:0] n194;
  wire [63:0] n196;
  wire [30:0] n197;
  wire [63:0] n198;
  wire [1:0] n199;
  wire n201;
  wire [31:0] n202;
  wire [31:0] n204;
  wire [30:0] n205;
  wire [61:0] n206;
  wire [63:0] n208;
  wire [30:0] n209;
  wire [63:0] n210;
  wire n211;
  wire n212;
  wire [31:0] n213;
  wire [31:0] n215;
  wire [30:0] n216;
  wire [30:0] n217;
  wire [63:0] n218;
  wire [31:0] n219;
  wire [31:0] n221;
  wire [14:0] n222;
  wire [30:0] n223;
  wire [31:0] n224;
  wire [31:0] n226;
  wire [63:0] n227;
  wire n228;
  wire n229;
  wire n230;
  wire n242;
  wire [14:0] n245;
  wire [63:0] n247;
  wire [79:0] n248;
  wire [14:0] n249;
  wire n251;
  wire n263;
  wire [14:0] n266;
  wire [63:0] n268;
  wire [79:0] n269;
  localparam [63:0] n272 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n273;
  wire [14:0] n274;
  wire n276;
  wire [63:0] n277;
  wire n279;
  wire [63:0] n280;
  wire [63:0] n281;
  wire n282;
  wire n283;
  wire n284;
  wire n285;
  wire n286;
  wire n298;
  wire [14:0] n301;
  wire [63:0] n303;
  wire [79:0] n304;
  wire [14:0] n305;
  wire n307;
  wire n319;
  wire [14:0] n322;
  wire [63:0] n324;
  wire [79:0] n325;
  localparam [63:0] n328 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n329;
  wire [14:0] n330;
  wire n332;
  wire [63:0] n333;
  wire n335;
  wire [63:0] n336;
  wire [63:0] n337;
  wire n338;
  wire n339;
  wire n340;
  wire n341;
  wire n342;
  wire n343;
  wire n356;
  wire [14:0] n359;
  wire [63:0] n361;
  wire [79:0] n362;
  wire [14:0] n363;
  wire n365;
  wire n377;
  wire [14:0] n380;
  wire [63:0] n382;
  wire [79:0] n383;
  localparam [63:0] n386 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n387;
  wire [14:0] n388;
  wire n390;
  wire [63:0] n391;
  wire n393;
  wire [63:0] n394;
  wire [63:0] n395;
  wire n396;
  wire n397;
  wire n398;
  wire n399;
  wire n400;
  wire n412;
  wire [14:0] n415;
  wire [63:0] n417;
  wire [79:0] n418;
  wire [14:0] n419;
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
  wire n456;
  wire n474;
  wire [14:0] n477;
  wire [63:0] n479;
  wire [79:0] n480;
  wire [14:0] n481;
  wire n483;
  wire n484;
  wire n485;
  wire n486;
  wire [62:0] n487;
  wire n489;
  wire n490;
  wire n502;
  wire [14:0] n505;
  wire [63:0] n507;
  wire [79:0] n508;
  wire [14:0] n509;
  wire n511;
  wire n512;
  wire n513;
  wire n514;
  wire [62:0] n515;
  wire n517;
  wire n518;
  wire n520;
  wire n523;
  wire n525;
  wire [79:0] n526;
  wire [79:0] n527;
  wire [79:0] n528;
  wire [79:0] n529;
  wire [15:0] n532;
  wire [62:0] n533;
  wire [79:0] n534;
  wire [80:0] n535;
  wire [79:0] n537;
  wire n549;
  wire [14:0] n552;
  wire [63:0] n554;
  wire [79:0] n555;
  localparam [63:0] n558 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n559;
  wire [14:0] n560;
  wire n562;
  wire [63:0] n563;
  wire n565;
  wire [63:0] n566;
  wire [63:0] n567;
  wire n568;
  wire n569;
  wire n570;
  wire n582;
  wire [14:0] n585;
  wire [63:0] n587;
  wire [79:0] n588;
  localparam [63:0] n591 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n592;
  wire [14:0] n593;
  wire n595;
  wire [63:0] n596;
  wire n598;
  wire [63:0] n599;
  wire [63:0] n600;
  wire n601;
  wire n602;
  wire n603;
  wire n604;
  wire n616;
  wire [14:0] n619;
  wire [63:0] n621;
  wire [79:0] n622;
  wire [14:0] n623;
  wire n625;
  wire [63:0] n626;
  wire n628;
  wire n629;
  wire n641;
  wire [14:0] n644;
  wire [63:0] n646;
  wire [79:0] n647;
  wire [14:0] n648;
  wire n650;
  wire [63:0] n651;
  wire n653;
  wire n654;
  wire n655;
  wire n659;
  wire n660;
  wire n661;
  wire [79:0] n664;
  wire [79:0] n665;
  wire [79:0] n666;
  wire n678;
  wire [14:0] n681;
  wire [63:0] n683;
  wire [79:0] n684;
  wire [14:0] n685;
  wire n687;
  wire [63:0] n688;
  wire n690;
  wire n691;
  wire n703;
  wire [14:0] n706;
  wire [63:0] n708;
  wire [79:0] n709;
  wire [14:0] n710;
  wire n712;
  wire [63:0] n713;
  wire n715;
  wire n716;
  wire n717;
  wire n720;
  wire [79:0] n722;
  wire n724;
  wire [79:0] n725;
  wire n727;
  wire [79:0] n729;
  wire [31:0] n730;
  wire [31:0] n732;
  wire [17:0] n733;
  wire n735;
  wire [127:0] n736;
  wire [127:0] n737;
  wire [127:0] n738;
  wire [1:0] n741;
  wire [127:0] n742;
  wire n745;
  wire [79:0] n746;
  wire n748;
  wire [31:0] n749;
  wire n750;
  wire [31:0] n752;
  wire [31:0] n755;
  wire [31:0] n756;
  wire [6:0] n759;
  wire [6:0] n761;
  wire [66:0] n763;
  wire [31:0] n765;
  wire n767;
  wire n769;
  wire n770;
  wire n771;
  wire n774;
  wire n776;
  wire n777;
  wire n778;
  wire n780;
  wire n782;
  wire n783;
  wire n784;
  wire n786;
  wire n788;
  wire n789;
  wire n790;
  wire n792;
  wire n794;
  wire n795;
  wire n796;
  wire n798;
  wire n800;
  wire n801;
  wire n802;
  wire n804;
  wire n806;
  wire n807;
  wire n808;
  wire n810;
  wire n812;
  wire n813;
  wire n814;
  wire n816;
  wire n818;
  wire n819;
  wire n820;
  wire n822;
  wire n824;
  wire n825;
  wire n826;
  wire n828;
  wire n830;
  wire n831;
  wire n832;
  wire n834;
  wire n836;
  wire n837;
  wire n838;
  wire n840;
  wire n842;
  wire n843;
  wire n844;
  wire n846;
  wire n848;
  wire n849;
  wire n850;
  wire n852;
  wire n854;
  wire n855;
  wire n856;
  wire n858;
  wire n860;
  wire n861;
  wire n862;
  wire n864;
  wire n866;
  wire n867;
  wire n868;
  wire n870;
  wire n872;
  wire n873;
  wire n874;
  wire n876;
  wire n878;
  wire n879;
  wire n880;
  wire n882;
  wire n884;
  wire n885;
  wire n886;
  wire n888;
  wire n890;
  wire n891;
  wire n892;
  wire n894;
  wire n896;
  wire n897;
  wire n898;
  wire n900;
  wire n902;
  wire n903;
  wire n904;
  wire n906;
  wire n908;
  wire n909;
  wire n910;
  wire n912;
  wire n914;
  wire n915;
  wire n916;
  wire n918;
  wire n920;
  wire n921;
  wire n922;
  wire n924;
  wire n926;
  wire n927;
  wire n928;
  wire n930;
  wire n932;
  wire n933;
  wire n934;
  wire n936;
  wire n938;
  wire n939;
  wire n940;
  wire n942;
  wire n944;
  wire n945;
  wire n946;
  wire n948;
  wire n950;
  wire n951;
  wire n952;
  wire n954;
  wire n956;
  wire n957;
  wire n958;
  wire n960;
  wire n962;
  wire n963;
  wire n964;
  wire n966;
  wire n968;
  wire n969;
  wire n970;
  wire n972;
  wire n974;
  wire n975;
  wire n976;
  wire n978;
  wire n980;
  wire n981;
  wire n982;
  wire n984;
  wire n986;
  wire n987;
  wire n988;
  wire n990;
  wire n992;
  wire n993;
  wire n994;
  wire n996;
  wire n998;
  wire n999;
  wire n1000;
  wire n1002;
  wire n1004;
  wire n1005;
  wire n1006;
  wire n1008;
  wire n1010;
  wire n1011;
  wire n1012;
  wire n1014;
  wire n1016;
  wire n1017;
  wire n1018;
  wire n1020;
  wire n1022;
  wire n1023;
  wire n1024;
  wire n1026;
  wire n1028;
  wire n1029;
  wire n1030;
  wire n1032;
  wire n1034;
  wire n1035;
  wire n1036;
  wire n1038;
  wire n1040;
  wire n1041;
  wire n1042;
  wire n1044;
  wire n1046;
  wire n1047;
  wire n1048;
  wire n1050;
  wire n1052;
  wire n1053;
  wire n1054;
  wire n1056;
  wire n1058;
  wire n1059;
  wire n1060;
  wire n1062;
  wire n1064;
  wire n1065;
  wire n1066;
  wire n1068;
  wire n1070;
  wire n1071;
  wire n1072;
  wire n1074;
  wire n1076;
  wire n1077;
  wire n1078;
  wire n1080;
  wire n1082;
  wire n1083;
  wire n1084;
  wire n1086;
  wire n1088;
  wire n1089;
  wire n1090;
  wire n1092;
  wire n1094;
  wire n1095;
  wire n1096;
  wire n1098;
  wire n1100;
  wire n1101;
  wire n1102;
  wire n1104;
  wire n1106;
  wire n1107;
  wire n1108;
  wire n1110;
  wire n1112;
  wire n1113;
  wire n1114;
  wire n1116;
  wire n1118;
  wire n1119;
  wire n1120;
  wire n1122;
  wire n1124;
  wire n1125;
  wire n1126;
  wire n1128;
  wire n1130;
  wire n1131;
  wire n1132;
  wire n1134;
  wire n1136;
  wire n1137;
  wire n1138;
  wire n1140;
  wire n1142;
  wire n1143;
  wire n1144;
  wire n1146;
  wire n1148;
  wire n1149;
  wire n1150;
  wire n1152;
  wire n1154;
  wire n1155;
  wire n1156;
  wire n1158;
  wire n1160;
  wire n1161;
  wire n1162;
  wire n1164;
  wire n1166;
  wire n1167;
  wire n1168;
  wire n1170;
  wire n1172;
  wire n1173;
  wire n1174;
  wire n1176;
  wire n1178;
  wire n1179;
  wire n1180;
  wire n1182;
  wire n1184;
  wire n1185;
  wire n1186;
  wire n1188;
  wire n1190;
  wire n1191;
  wire n1192;
  wire n1194;
  wire n1196;
  wire n1197;
  wire n1198;
  wire n1200;
  wire n1202;
  wire n1203;
  wire n1204;
  wire n1206;
  wire n1208;
  wire n1209;
  wire n1210;
  wire n1212;
  wire n1214;
  wire n1215;
  wire n1216;
  wire n1218;
  wire n1220;
  wire n1221;
  wire n1222;
  wire n1224;
  wire n1226;
  wire n1227;
  wire n1228;
  wire n1230;
  wire n1232;
  wire n1233;
  wire n1234;
  wire n1236;
  wire n1238;
  wire n1239;
  wire n1240;
  wire n1242;
  wire n1244;
  wire n1245;
  wire n1246;
  wire n1248;
  wire n1250;
  wire n1251;
  wire n1252;
  wire n1254;
  wire n1256;
  wire n1257;
  wire n1258;
  wire n1260;
  wire n1262;
  wire n1263;
  wire n1264;
  wire n1266;
  wire n1268;
  wire n1269;
  wire n1270;
  wire n1272;
  wire n1274;
  wire n1275;
  wire n1276;
  wire n1278;
  wire n1280;
  wire n1281;
  wire n1282;
  wire n1284;
  wire n1286;
  wire n1287;
  wire n1288;
  wire n1290;
  wire n1292;
  wire n1293;
  wire n1294;
  wire n1296;
  wire n1298;
  wire n1299;
  wire n1300;
  wire n1302;
  wire n1304;
  wire n1305;
  wire n1306;
  wire n1308;
  wire n1310;
  wire n1311;
  wire n1312;
  wire n1314;
  wire n1316;
  wire n1317;
  wire n1318;
  wire n1320;
  wire n1322;
  wire n1323;
  wire n1324;
  wire n1326;
  wire n1328;
  wire n1329;
  wire n1330;
  wire n1332;
  wire n1334;
  wire n1335;
  wire n1336;
  wire n1338;
  wire n1340;
  wire n1341;
  wire n1342;
  wire n1344;
  wire n1346;
  wire n1347;
  wire n1348;
  wire n1350;
  wire n1352;
  wire n1353;
  wire n1354;
  wire n1356;
  wire n1358;
  wire n1359;
  wire n1360;
  wire n1362;
  wire n1364;
  wire n1365;
  wire n1366;
  wire n1368;
  wire n1370;
  wire n1371;
  wire n1372;
  wire n1374;
  wire n1376;
  wire n1377;
  wire n1378;
  wire n1380;
  wire n1382;
  wire n1383;
  wire n1384;
  wire n1386;
  wire n1388;
  wire n1389;
  wire n1390;
  wire n1392;
  wire n1394;
  wire n1395;
  wire n1396;
  wire n1398;
  wire n1400;
  wire n1401;
  wire n1402;
  wire n1404;
  wire n1406;
  wire n1407;
  wire n1408;
  wire n1410;
  wire n1412;
  wire n1413;
  wire n1414;
  wire n1416;
  wire n1418;
  wire n1419;
  wire n1420;
  wire n1422;
  wire n1424;
  wire n1425;
  wire n1426;
  wire n1428;
  wire n1430;
  wire n1431;
  wire n1432;
  wire n1434;
  wire n1436;
  wire n1437;
  wire n1438;
  wire n1440;
  wire n1442;
  wire n1443;
  wire n1444;
  wire n1446;
  wire n1448;
  wire n1449;
  wire n1450;
  wire n1452;
  wire n1454;
  wire n1455;
  wire n1456;
  wire n1458;
  wire n1460;
  wire n1461;
  wire n1462;
  wire n1464;
  wire n1466;
  wire n1467;
  wire n1468;
  wire n1470;
  wire n1472;
  wire n1473;
  wire n1474;
  wire n1476;
  wire n1478;
  wire n1479;
  wire n1480;
  wire n1482;
  wire n1484;
  wire n1485;
  wire n1486;
  wire n1488;
  wire n1490;
  wire n1491;
  wire n1492;
  wire n1494;
  wire n1496;
  wire n1497;
  wire n1498;
  wire n1500;
  wire n1502;
  wire n1503;
  wire n1504;
  wire n1506;
  wire n1508;
  wire n1509;
  wire n1510;
  wire n1512;
  wire n1514;
  wire n1515;
  wire n1516;
  wire n1518;
  wire n1520;
  wire n1521;
  wire n1522;
  wire n1524;
  wire n1526;
  wire n1527;
  wire n1528;
  wire n1530;
  wire n1532;
  wire n1533;
  wire n1534;
  wire n1536;
  wire n1538;
  wire n1540;
  wire n1541;
  wire [65:0] n1542;
  wire [66:0] n1543;
  wire [63:0] n1544;
  wire [66:0] n1545;
  wire n1546;
  wire [66:0] n1547;
  wire n1548;
  wire [66:0] n1549;
  wire [40:0] n1550;
  wire n1552;
  wire n1555;
  wire n1557;
  wire [66:0] n1558;
  wire n1559;
  wire [66:0] n1560;
  wire n1561;
  wire [66:0] n1562;
  wire [11:0] n1563;
  wire n1565;
  wire n1568;
  wire n1570;
  wire [66:0] n1571;
  wire n1572;
  wire [66:0] n1573;
  wire n1574;
  wire [66:0] n1575;
  wire n1576;
  wire n1579;
  wire [1:0] n1580;
  reg n1581;
  reg n1582;
  reg n1583;
  wire n1589;
  wire n1590;
  wire n1591;
  wire n1592;
  wire n1593;
  wire n1594;
  wire n1597;
  wire n1599;
  wire n1600;
  wire n1601;
  wire n1602;
  wire n1603;
  wire n1606;
  wire n1608;
  wire n1609;
  wire n1610;
  wire n1611;
  wire n1612;
  wire n1615;
  wire [1:0] n1616;
  reg n1617;
  wire n1619;
  wire n1621;
  wire n1622;
  wire n1625;
  wire n1627;
  wire n1628;
  wire n1629;
  wire n1632;
  wire n1634;
  wire [3:0] n1635;
  reg n1638;
  wire [64:0] n1641;
  wire [64:0] n1643;
  wire n1645;
  wire [64:0] n1647;
  wire [64:0] n1649;
  wire n1651;
  wire [64:0] n1653;
  wire [64:0] n1655;
  wire [1:0] n1656;
  reg [64:0] n1657;
  wire n1658;
  wire [63:0] n1659;
  wire [63:0] n1661;
  wire n1662;
  wire n1664;
  wire n1665;
  wire [61:0] n1668;
  wire [31:0] n1670;
  wire [63:0] n1671;
  wire [63:0] n1672;
  wire [63:0] n1673;
  wire [31:0] n1674;
  wire [63:0] n1675;
  wire n1677;
  localparam [39:0] n1678 = 40'b0000000000000000000000000000000000000000;
  wire n1680;
  wire n1683;
  wire [1:0] n1684;
  wire [10:0] n1685;
  wire [10:0] n1686;
  reg [10:0] n1687;
  wire [28:0] n1688;
  wire [28:0] n1689;
  reg [28:0] n1690;
  wire [23:0] n1692;
  wire n1694;
  wire [31:0] n1696;
  wire [30:0] n1697;
  wire [31:0] n1698;
  wire n1700;
  wire [63:0] n1701;
  wire n1703;
  wire n1704;
  wire [63:0] n1706;
  wire [63:0] n1707;
  wire [79:0] n1708;
  wire [79:0] n1710;
  wire n1712;
  wire [30:0] n1715;
  wire [14:0] n1716;
  wire [63:0] n1717;
  wire [79:0] n1718;
  wire [79:0] n1719;
  wire [79:0] n1720;
  wire [79:0] n1722;
  wire n1726;
  wire [3:0] n1727;
  reg [1:0] n1731;
  reg [79:0] n1733;
  reg [79:0] n1735;
  reg [1:0] n1737;
  reg [1:0] n1739;
  reg [63:0] n1741;
  reg [63:0] n1743;
  reg n1745;
  reg [17:0] n1747;
  reg n1749;
  reg [79:0] n1751;
  reg [127:0] n1753;
  reg n1757;
  reg [79:0] n1760;
  wire [1:0] n1813;
  wire [79:0] n1815;
  wire [79:0] n1817;
  wire [1:0] n1819;
  wire [1:0] n1821;
  wire [63:0] n1823;
  wire [63:0] n1825;
  wire n1827;
  wire [17:0] n1829;
  wire n1831;
  wire [79:0] n1833;
  wire [127:0] n1835;
  wire n1837;
  wire [79:0] n1839;
  wire n1919;
  wire n1920;
  reg [1:0] n1922;
  reg [79:0] n1923;
  reg [79:0] n1924;
  reg [1:0] n1925;
  reg [1:0] n1926;
  reg [63:0] n1927;
  reg [63:0] n1928;
  reg n1929;
  reg [17:0] n1930;
  reg n1931;
  reg [79:0] n1932;
  reg [127:0] n1933;
  reg n1934;
  reg [79:0] n1935;
  assign busy = n1920; //(module output)
  assign done = done_reg; //(module output)
  assign result = result_reg; //(module output)
  /* mc68881_fp80_mul_unit.vhd:42:10  */
  always @*
    state_reg = n1922; // (isignal)
  initial
    state_reg = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:45:10  */
  always @*
    a_reg = n1923; // (isignal)
  initial
    a_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:46:10  */
  always @*
    b_reg = n1924; // (isignal)
  initial
    b_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:47:10  */
  always @*
    rm_reg = n1925; // (isignal)
  initial
    rm_reg = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:48:10  */
  always @*
    rp_reg = n1926; // (isignal)
  initial
    rp_reg = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:51:10  */
  always @*
    a_mant_reg = n1927; // (isignal)
  initial
    a_mant_reg = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:52:10  */
  always @*
    b_mant_reg = n1928; // (isignal)
  initial
    b_mant_reg = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:55:10  */
  always @*
    res_sign_reg = n1929; // (isignal)
  initial
    res_sign_reg = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:56:10  */
  always @*
    exp_res_reg = n1930; // (isignal)
  initial
    exp_res_reg = 18'b000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:57:10  */
  always @*
    early_exit_reg = n1931; // (isignal)
  initial
    early_exit_reg = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:58:10  */
  always @*
    early_result_reg = n1932; // (isignal)
  initial
    early_result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:61:10  */
  always @*
    mant_prod_reg = n1933; // (isignal)
  initial
    mant_prod_reg = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:64:10  */
  always @*
    done_reg = n1934; // (isignal)
  initial
    done_reg = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:65:10  */
  always @*
    result_reg = n1935; // (isignal)
  initial
    result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:98:16  */
  assign n41 = ~reset_n;
  /* mc68881_fp80_mul_unit.vhd:118:11  */
  assign n43 = start ? 2'b01 : state_reg;
  /* mc68881_fp80_mul_unit.vhd:118:11  */
  assign n44 = start ? a_in : a_reg;
  /* mc68881_fp80_mul_unit.vhd:118:11  */
  assign n45 = start ? b_in : b_reg;
  /* mc68881_fp80_mul_unit.vhd:118:11  */
  assign n46 = start ? round_mode : rm_reg;
  /* mc68881_fp80_mul_unit.vhd:118:11  */
  assign n47 = start ? round_prec : rp_reg;
  /* mc68881_fp80_mul_unit.vhd:117:9  */
  assign n49 = state_reg == 2'b00;
  /* mc68881_fp80_mul_unit.vhd:128:37  */
  assign n50 = a_reg[63:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:129:37  */
  assign n51 = b_reg[63:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:132:28  */
  assign n52 = a_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:132:73  */
  assign n54 = n52 == 15'b000000000000000;
  /* mc68881_fp80_mul_unit.vhd:132:90  */
  assign n56 = n50 != 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:132:77  */
  assign n57 = n56 & n54;
  /* mc68881_pkg.vhd:2502:9  */
  assign n64 = a_reg[63:32]; // extract
  /* mc68881_pkg.vhd:2502:37  */
  assign n66 = n64 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2504:13  */
  assign n67 = a_reg[31:0]; // extract
  /* mc68881_pkg.vhd:2504:36  */
  assign n69 = {n67, 32'b00000000000000000000000000000000};
  /* mc68881_pkg.vhd:2502:5  */
  assign n72 = n66 ? 31'b0000000000000000000000000100000 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:2502:5  */
  assign n74 = n66 ? n69 : n50;
  /* mc68881_pkg.vhd:2506:9  */
  assign n75 = n74[63:48]; // extract
  /* mc68881_pkg.vhd:2506:37  */
  assign n77 = n75 == 16'b0000000000000000;
  /* mc68881_pkg.vhd:2507:18  */
  assign n78 = {1'b0, n72};  //  uext
  /* mc68881_pkg.vhd:2507:18  */
  assign n80 = n78 + 32'b00000000000000000000000000010000;
  /* mc68881_pkg.vhd:2507:7  */
  assign n81 = n80[30:0];  // trunc
  /* mc68881_pkg.vhd:2508:13  */
  assign n82 = n74[47:0]; // extract
  /* mc68881_pkg.vhd:2508:36  */
  assign n84 = {n82, 16'b0000000000000000};
  /* mc68881_pkg.vhd:2506:5  */
  assign n85 = n77 ? n81 : n72;
  /* mc68881_pkg.vhd:2506:5  */
  assign n86 = n77 ? n84 : n74;
  /* mc68881_pkg.vhd:2510:9  */
  assign n87 = n86[63:56]; // extract
  /* mc68881_pkg.vhd:2510:36  */
  assign n89 = n87 == 8'b00000000;
  /* mc68881_pkg.vhd:2511:18  */
  assign n90 = {1'b0, n85};  //  uext
  /* mc68881_pkg.vhd:2511:18  */
  assign n92 = n90 + 32'b00000000000000000000000000001000;
  /* mc68881_pkg.vhd:2511:7  */
  assign n93 = n92[30:0];  // trunc
  /* mc68881_pkg.vhd:2512:13  */
  assign n94 = n86[55:0]; // extract
  /* mc68881_pkg.vhd:2512:35  */
  assign n96 = {n94, 8'b00000000};
  /* mc68881_pkg.vhd:2510:5  */
  assign n97 = n89 ? n93 : n85;
  /* mc68881_pkg.vhd:2510:5  */
  assign n98 = n89 ? n96 : n86;
  /* mc68881_pkg.vhd:2514:9  */
  assign n99 = n98[63:60]; // extract
  /* mc68881_pkg.vhd:2514:36  */
  assign n101 = n99 == 4'b0000;
  /* mc68881_pkg.vhd:2515:18  */
  assign n102 = {1'b0, n97};  //  uext
  /* mc68881_pkg.vhd:2515:18  */
  assign n104 = n102 + 32'b00000000000000000000000000000100;
  /* mc68881_pkg.vhd:2515:7  */
  assign n105 = n104[30:0];  // trunc
  /* mc68881_pkg.vhd:2516:13  */
  assign n106 = n98[59:0]; // extract
  /* mc68881_pkg.vhd:2516:35  */
  assign n108 = {n106, 4'b0000};
  /* mc68881_pkg.vhd:2514:5  */
  assign n109 = n101 ? n105 : n97;
  /* mc68881_pkg.vhd:2514:5  */
  assign n110 = n101 ? n108 : n98;
  /* mc68881_pkg.vhd:2518:9  */
  assign n111 = n110[63:62]; // extract
  /* mc68881_pkg.vhd:2518:36  */
  assign n113 = n111 == 2'b00;
  /* mc68881_pkg.vhd:2519:18  */
  assign n114 = {1'b0, n109};  //  uext
  /* mc68881_pkg.vhd:2519:18  */
  assign n116 = n114 + 32'b00000000000000000000000000000010;
  /* mc68881_pkg.vhd:2519:7  */
  assign n117 = n116[30:0];  // trunc
  /* mc68881_pkg.vhd:2520:13  */
  assign n118 = n110[61:0]; // extract
  /* mc68881_pkg.vhd:2520:35  */
  assign n120 = {n118, 2'b00};
  /* mc68881_pkg.vhd:2518:5  */
  assign n121 = n113 ? n117 : n109;
  /* mc68881_pkg.vhd:2518:5  */
  assign n122 = n113 ? n120 : n110;
  /* mc68881_pkg.vhd:2522:9  */
  assign n123 = n122[63]; // extract
  /* mc68881_pkg.vhd:2522:18  */
  assign n124 = ~n123;
  /* mc68881_pkg.vhd:2523:18  */
  assign n125 = {1'b0, n121};  //  uext
  /* mc68881_pkg.vhd:2523:18  */
  assign n127 = n125 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:2523:7  */
  assign n128 = n127[30:0];  // trunc
  /* mc68881_pkg.vhd:2522:5  */
  assign n129 = n124 ? n128 : n121;
  /* mc68881_fp80_mul_unit.vhd:134:25  */
  assign n130 = n50 << n129;
  /* mc68881_fp80_mul_unit.vhd:135:28  */
  assign n131 = {1'b0, n129};  //  uext
  /* mc68881_fp80_mul_unit.vhd:135:28  */
  assign n133 = 32'b00000000000000000000000000000001 - n131;
  /* mc68881_fp80_mul_unit.vhd:137:51  */
  assign n134 = a_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:137:26  */
  assign n135 = {16'b0, n134};  //  uext
  /* mc68881_fp80_mul_unit.vhd:137:13  */
  assign n136 = {1'b0, n135};  //  uext
  /* mc68881_fp80_mul_unit.vhd:132:11  */
  assign n138 = n57 ? n133 : n136;
  /* mc68881_fp80_mul_unit.vhd:132:11  */
  assign n139 = n57 ? n130 : n50;
  /* mc68881_fp80_mul_unit.vhd:140:28  */
  assign n140 = b_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:140:73  */
  assign n142 = n140 == 15'b000000000000000;
  /* mc68881_fp80_mul_unit.vhd:140:90  */
  assign n144 = n51 != 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:140:77  */
  assign n145 = n144 & n142;
  /* mc68881_pkg.vhd:2502:9  */
  assign n152 = b_reg[63:32]; // extract
  /* mc68881_pkg.vhd:2502:37  */
  assign n154 = n152 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2504:13  */
  assign n155 = b_reg[31:0]; // extract
  /* mc68881_pkg.vhd:2504:36  */
  assign n157 = {n155, 32'b00000000000000000000000000000000};
  /* mc68881_pkg.vhd:2502:5  */
  assign n160 = n154 ? 31'b0000000000000000000000000100000 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:2502:5  */
  assign n162 = n154 ? n157 : n51;
  /* mc68881_pkg.vhd:2506:9  */
  assign n163 = n162[63:48]; // extract
  /* mc68881_pkg.vhd:2506:37  */
  assign n165 = n163 == 16'b0000000000000000;
  /* mc68881_pkg.vhd:2507:18  */
  assign n166 = {1'b0, n160};  //  uext
  /* mc68881_pkg.vhd:2507:18  */
  assign n168 = n166 + 32'b00000000000000000000000000010000;
  /* mc68881_pkg.vhd:2507:7  */
  assign n169 = n168[30:0];  // trunc
  /* mc68881_pkg.vhd:2508:13  */
  assign n170 = n162[47:0]; // extract
  /* mc68881_pkg.vhd:2508:36  */
  assign n172 = {n170, 16'b0000000000000000};
  /* mc68881_pkg.vhd:2506:5  */
  assign n173 = n165 ? n169 : n160;
  /* mc68881_pkg.vhd:2506:5  */
  assign n174 = n165 ? n172 : n162;
  /* mc68881_pkg.vhd:2510:9  */
  assign n175 = n174[63:56]; // extract
  /* mc68881_pkg.vhd:2510:36  */
  assign n177 = n175 == 8'b00000000;
  /* mc68881_pkg.vhd:2511:18  */
  assign n178 = {1'b0, n173};  //  uext
  /* mc68881_pkg.vhd:2511:18  */
  assign n180 = n178 + 32'b00000000000000000000000000001000;
  /* mc68881_pkg.vhd:2511:7  */
  assign n181 = n180[30:0];  // trunc
  /* mc68881_pkg.vhd:2512:13  */
  assign n182 = n174[55:0]; // extract
  /* mc68881_pkg.vhd:2512:35  */
  assign n184 = {n182, 8'b00000000};
  /* mc68881_pkg.vhd:2510:5  */
  assign n185 = n177 ? n181 : n173;
  /* mc68881_pkg.vhd:2510:5  */
  assign n186 = n177 ? n184 : n174;
  /* mc68881_pkg.vhd:2514:9  */
  assign n187 = n186[63:60]; // extract
  /* mc68881_pkg.vhd:2514:36  */
  assign n189 = n187 == 4'b0000;
  /* mc68881_pkg.vhd:2515:18  */
  assign n190 = {1'b0, n185};  //  uext
  /* mc68881_pkg.vhd:2515:18  */
  assign n192 = n190 + 32'b00000000000000000000000000000100;
  /* mc68881_pkg.vhd:2515:7  */
  assign n193 = n192[30:0];  // trunc
  /* mc68881_pkg.vhd:2516:13  */
  assign n194 = n186[59:0]; // extract
  /* mc68881_pkg.vhd:2516:35  */
  assign n196 = {n194, 4'b0000};
  /* mc68881_pkg.vhd:2514:5  */
  assign n197 = n189 ? n193 : n185;
  /* mc68881_pkg.vhd:2514:5  */
  assign n198 = n189 ? n196 : n186;
  /* mc68881_pkg.vhd:2518:9  */
  assign n199 = n198[63:62]; // extract
  /* mc68881_pkg.vhd:2518:36  */
  assign n201 = n199 == 2'b00;
  /* mc68881_pkg.vhd:2519:18  */
  assign n202 = {1'b0, n197};  //  uext
  /* mc68881_pkg.vhd:2519:18  */
  assign n204 = n202 + 32'b00000000000000000000000000000010;
  /* mc68881_pkg.vhd:2519:7  */
  assign n205 = n204[30:0];  // trunc
  /* mc68881_pkg.vhd:2520:13  */
  assign n206 = n198[61:0]; // extract
  /* mc68881_pkg.vhd:2520:35  */
  assign n208 = {n206, 2'b00};
  /* mc68881_pkg.vhd:2518:5  */
  assign n209 = n201 ? n205 : n197;
  /* mc68881_pkg.vhd:2518:5  */
  assign n210 = n201 ? n208 : n198;
  /* mc68881_pkg.vhd:2522:9  */
  assign n211 = n210[63]; // extract
  /* mc68881_pkg.vhd:2522:18  */
  assign n212 = ~n211;
  /* mc68881_pkg.vhd:2523:18  */
  assign n213 = {1'b0, n209};  //  uext
  /* mc68881_pkg.vhd:2523:18  */
  assign n215 = n213 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:2523:7  */
  assign n216 = n215[30:0];  // trunc
  /* mc68881_pkg.vhd:2522:5  */
  assign n217 = n212 ? n216 : n209;
  /* mc68881_fp80_mul_unit.vhd:142:25  */
  assign n218 = n51 << n217;
  /* mc68881_fp80_mul_unit.vhd:143:28  */
  assign n219 = {1'b0, n217};  //  uext
  /* mc68881_fp80_mul_unit.vhd:143:28  */
  assign n221 = 32'b00000000000000000000000000000001 - n219;
  /* mc68881_fp80_mul_unit.vhd:145:51  */
  assign n222 = b_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:145:26  */
  assign n223 = {16'b0, n222};  //  uext
  /* mc68881_fp80_mul_unit.vhd:145:13  */
  assign n224 = {1'b0, n223};  //  uext
  /* mc68881_fp80_mul_unit.vhd:140:11  */
  assign n226 = n145 ? n221 : n224;
  /* mc68881_fp80_mul_unit.vhd:140:11  */
  assign n227 = n145 ? n218 : n51;
  /* mc68881_fp80_mul_unit.vhd:152:32  */
  assign n228 = a_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:152:54  */
  assign n229 = b_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:152:45  */
  assign n230 = n228 ^ n229;
  /* mc68881_pkg.vhd:1538:25  */
  assign n242 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n245 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n247 = a_reg[63:0]; // extract
  assign n248 = {n247, n245, n242};
  /* mc68881_pkg.vhd:2101:20  */
  assign n249 = n248[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n251 = n249 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n263 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n266 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n268 = a_reg[63:0]; // extract
  assign n269 = {n268, n266, n263};
  assign n273 = n272[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n274 = n269[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n276 = n274 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n277 = n269[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n279 = n277 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n280 = n269[79:16]; // extract
  assign n281 = {1'b1, n273};
  /* mc68881_pkg.vhd:2095:41  */
  assign n282 = n280 == n281;
  /* mc68881_pkg.vhd:2095:25  */
  assign n283 = n279 | n282;
  /* mc68881_pkg.vhd:2094:42  */
  assign n284 = n283 & n276;
  /* mc68881_pkg.vhd:2101:46  */
  assign n285 = ~n284;
  /* mc68881_pkg.vhd:2101:42  */
  assign n286 = n285 & n251;
  /* mc68881_pkg.vhd:1538:25  */
  assign n298 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n301 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n303 = b_reg[63:0]; // extract
  assign n304 = {n303, n301, n298};
  /* mc68881_pkg.vhd:2101:20  */
  assign n305 = n304[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n307 = n305 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n319 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n322 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n324 = b_reg[63:0]; // extract
  assign n325 = {n324, n322, n319};
  assign n329 = n328[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n330 = n325[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n332 = n330 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n333 = n325[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n335 = n333 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n336 = n325[79:16]; // extract
  assign n337 = {1'b1, n329};
  /* mc68881_pkg.vhd:2095:41  */
  assign n338 = n336 == n337;
  /* mc68881_pkg.vhd:2095:25  */
  assign n339 = n335 | n338;
  /* mc68881_pkg.vhd:2094:42  */
  assign n340 = n339 & n332;
  /* mc68881_pkg.vhd:2101:46  */
  assign n341 = ~n340;
  /* mc68881_pkg.vhd:2101:42  */
  assign n342 = n341 & n307;
  /* mc68881_fp80_mul_unit.vhd:157:33  */
  assign n343 = n286 | n342;
  /* mc68881_pkg.vhd:1538:25  */
  assign n356 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n359 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n361 = a_reg[63:0]; // extract
  assign n362 = {n361, n359, n356};
  /* mc68881_pkg.vhd:2101:20  */
  assign n363 = n362[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n365 = n363 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n377 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n380 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n382 = a_reg[63:0]; // extract
  assign n383 = {n382, n380, n377};
  assign n387 = n386[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n388 = n383[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n390 = n388 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n391 = n383[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n393 = n391 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n394 = n383[79:16]; // extract
  assign n395 = {1'b1, n387};
  /* mc68881_pkg.vhd:2095:41  */
  assign n396 = n394 == n395;
  /* mc68881_pkg.vhd:2095:25  */
  assign n397 = n393 | n396;
  /* mc68881_pkg.vhd:2094:42  */
  assign n398 = n397 & n390;
  /* mc68881_pkg.vhd:2101:46  */
  assign n399 = ~n398;
  /* mc68881_pkg.vhd:2101:42  */
  assign n400 = n399 & n365;
  /* mc68881_pkg.vhd:1538:25  */
  assign n412 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n415 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n417 = b_reg[63:0]; // extract
  assign n418 = {n417, n415, n412};
  /* mc68881_pkg.vhd:2101:20  */
  assign n419 = n418[15:1]; // extract
  /* mc68881_pkg.vhd:2101:24  */
  assign n421 = n419 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1538:25  */
  assign n433 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n436 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n438 = b_reg[63:0]; // extract
  assign n439 = {n438, n436, n433};
  assign n443 = n442[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n444 = n439[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n446 = n444 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n447 = n439[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n449 = n447 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n450 = n439[79:16]; // extract
  assign n451 = {1'b1, n443};
  /* mc68881_pkg.vhd:2095:41  */
  assign n452 = n450 == n451;
  /* mc68881_pkg.vhd:2095:25  */
  assign n453 = n449 | n452;
  /* mc68881_pkg.vhd:2094:42  */
  assign n454 = n453 & n446;
  /* mc68881_pkg.vhd:2101:46  */
  assign n455 = ~n454;
  /* mc68881_pkg.vhd:2101:42  */
  assign n456 = n455 & n421;
  /* mc68881_pkg.vhd:1538:25  */
  assign n474 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n477 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n479 = a_reg[63:0]; // extract
  assign n480 = {n479, n477, n474};
  /* mc68881_pkg.vhd:2108:20  */
  assign n481 = n480[15:1]; // extract
  /* mc68881_pkg.vhd:2108:24  */
  assign n483 = n481 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2109:24  */
  assign n484 = n480[79]; // extract
  /* mc68881_pkg.vhd:2109:42  */
  assign n485 = ~n484;
  /* mc68881_pkg.vhd:2108:42  */
  assign n486 = n485 & n483;
  /* mc68881_pkg.vhd:2110:24  */
  assign n487 = n480[78:16]; // extract
  /* mc68881_pkg.vhd:2110:51  */
  assign n489 = n487 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2109:48  */
  assign n490 = n489 & n486;
  /* mc68881_pkg.vhd:1538:25  */
  assign n502 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n505 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n507 = b_reg[63:0]; // extract
  assign n508 = {n507, n505, n502};
  /* mc68881_pkg.vhd:2108:20  */
  assign n509 = n508[15:1]; // extract
  /* mc68881_pkg.vhd:2108:24  */
  assign n511 = n509 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2109:24  */
  assign n512 = n508[79]; // extract
  /* mc68881_pkg.vhd:2109:42  */
  assign n513 = ~n512;
  /* mc68881_pkg.vhd:2108:42  */
  assign n514 = n513 & n511;
  /* mc68881_pkg.vhd:2110:24  */
  assign n515 = n508[78:16]; // extract
  /* mc68881_pkg.vhd:2110:51  */
  assign n517 = n515 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2109:48  */
  assign n518 = n517 & n514;
  /* mc68881_pkg.vhd:2147:18  */
  assign n520 = n490 | n518;
  /* mc68881_pkg.vhd:2147:5  */
  assign n523 = n520 ? 1'b1 : 1'b0;
  /* mc68881_pkg.vhd:2151:14  */
  assign n525 = n456 & n400;
  /* mc68881_pkg.vhd:2155:7  */
  assign n526 = n518 ? b_reg : a_reg;
  /* mc68881_pkg.vhd:2153:7  */
  assign n527 = n490 ? a_reg : n526;
  /* mc68881_pkg.vhd:2160:5  */
  assign n528 = n400 ? a_reg : b_reg;
  /* mc68881_pkg.vhd:2151:5  */
  assign n529 = n525 ? n527 : n528;
  assign n532 = n529[79:64]; // extract
  assign n533 = n529[62:0]; // extract
  assign n534 = {n532, 1'b1, n533};
  /* mc68881_pkg.vhd:2169:23  */
  assign n535 = {n523, n534};
  /* mc68881_fp80_mul_unit.vhd:161:68  */
  assign n537 = n535[79:0]; // extract
  /* mc68881_pkg.vhd:1538:25  */
  assign n549 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n552 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n554 = a_reg[63:0]; // extract
  assign n555 = {n554, n552, n549};
  assign n559 = n558[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n560 = n555[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n562 = n560 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n563 = n555[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n565 = n563 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n566 = n555[79:16]; // extract
  assign n567 = {1'b1, n559};
  /* mc68881_pkg.vhd:2095:41  */
  assign n568 = n566 == n567;
  /* mc68881_pkg.vhd:2095:25  */
  assign n569 = n565 | n568;
  /* mc68881_pkg.vhd:2094:42  */
  assign n570 = n569 & n562;
  /* mc68881_pkg.vhd:1538:25  */
  assign n582 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n585 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n587 = b_reg[63:0]; // extract
  assign n588 = {n587, n585, n582};
  assign n592 = n591[62:0]; // extract
  /* mc68881_pkg.vhd:2094:20  */
  assign n593 = n588[15:1]; // extract
  /* mc68881_pkg.vhd:2094:24  */
  assign n595 = n593 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2095:16  */
  assign n596 = n588[79:16]; // extract
  /* mc68881_pkg.vhd:2095:21  */
  assign n598 = n596 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2095:36  */
  assign n599 = n588[79:16]; // extract
  assign n600 = {1'b1, n592};
  /* mc68881_pkg.vhd:2095:41  */
  assign n601 = n599 == n600;
  /* mc68881_pkg.vhd:2095:25  */
  assign n602 = n598 | n601;
  /* mc68881_pkg.vhd:2094:42  */
  assign n603 = n602 & n595;
  /* mc68881_fp80_mul_unit.vhd:162:36  */
  assign n604 = n570 | n603;
  /* mc68881_pkg.vhd:1538:25  */
  assign n616 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n619 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n621 = a_reg[63:0]; // extract
  assign n622 = {n621, n619, n616};
  /* mc68881_pkg.vhd:2086:20  */
  assign n623 = n622[15:1]; // extract
  /* mc68881_pkg.vhd:2086:24  */
  assign n625 = n623 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2086:40  */
  assign n626 = n622[79:16]; // extract
  /* mc68881_pkg.vhd:2086:45  */
  assign n628 = n626 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2086:28  */
  assign n629 = n628 & n625;
  /* mc68881_pkg.vhd:1538:25  */
  assign n641 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n644 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n646 = b_reg[63:0]; // extract
  assign n647 = {n646, n644, n641};
  /* mc68881_pkg.vhd:2086:20  */
  assign n648 = n647[15:1]; // extract
  /* mc68881_pkg.vhd:2086:24  */
  assign n650 = n648 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2086:40  */
  assign n651 = n647[79:16]; // extract
  /* mc68881_pkg.vhd:2086:45  */
  assign n653 = n651 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2086:28  */
  assign n654 = n653 & n650;
  /* mc68881_fp80_mul_unit.vhd:164:36  */
  assign n655 = n629 | n654;
  /* mc68881_fp80_mul_unit.vhd:171:52  */
  assign n659 = a_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:171:74  */
  assign n660 = b_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:171:65  */
  assign n661 = n659 ^ n660;
  assign n664 = {n661, 15'b111111111111111, 64'b0000000000000000000000000000000000000000000000000000000000000000};
  assign n665 = {1'b0, 15'b111111111111111, 64'b1111111111111111111111111111111111111111111111111111111111111111};
  /* mc68881_fp80_mul_unit.vhd:164:13  */
  assign n666 = n655 ? n665 : n664;
  /* mc68881_pkg.vhd:1538:25  */
  assign n678 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n681 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n683 = a_reg[63:0]; // extract
  assign n684 = {n683, n681, n678};
  /* mc68881_pkg.vhd:2086:20  */
  assign n685 = n684[15:1]; // extract
  /* mc68881_pkg.vhd:2086:24  */
  assign n687 = n685 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2086:40  */
  assign n688 = n684[79:16]; // extract
  /* mc68881_pkg.vhd:2086:45  */
  assign n690 = n688 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2086:28  */
  assign n691 = n690 & n687;
  /* mc68881_pkg.vhd:1538:25  */
  assign n703 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1539:34  */
  assign n706 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1540:34  */
  assign n708 = b_reg[63:0]; // extract
  assign n709 = {n708, n706, n703};
  /* mc68881_pkg.vhd:2086:20  */
  assign n710 = n709[15:1]; // extract
  /* mc68881_pkg.vhd:2086:24  */
  assign n712 = n710 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2086:40  */
  assign n713 = n709[79:16]; // extract
  /* mc68881_pkg.vhd:2086:45  */
  assign n715 = n713 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2086:28  */
  assign n716 = n715 & n712;
  /* mc68881_fp80_mul_unit.vhd:175:37  */
  assign n717 = n691 | n716;
  /* mc68881_fp80_mul_unit.vhd:175:11  */
  assign n720 = n717 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:175:11  */
  assign n722 = n717 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : early_result_reg;
  /* mc68881_fp80_mul_unit.vhd:162:11  */
  assign n724 = n604 ? 1'b1 : n720;
  /* mc68881_fp80_mul_unit.vhd:162:11  */
  assign n725 = n604 ? n666 : n722;
  /* mc68881_fp80_mul_unit.vhd:157:11  */
  assign n727 = n343 ? 1'b1 : n724;
  /* mc68881_fp80_mul_unit.vhd:157:11  */
  assign n729 = n343 ? n537 : n725;
  /* mc68881_fp80_mul_unit.vhd:182:36  */
  assign n730 = n138 + n226;
  /* mc68881_fp80_mul_unit.vhd:182:48  */
  assign n732 = n730 - 32'b00000000000000000011111111111111;
  /* mc68881_fp80_mul_unit.vhd:182:26  */
  assign n733 = n732[17:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:126:9  */
  assign n735 = state_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:194:41  */
  assign n736 = {64'b0, a_mant_reg};  //  uext
  /* mc68881_fp80_mul_unit.vhd:194:41  */
  assign n737 = {64'b0, b_mant_reg};  //  uext
  /* mc68881_fp80_mul_unit.vhd:194:41  */
  assign n738 = n736 * n737; // umul
  /* mc68881_fp80_mul_unit.vhd:187:11  */
  assign n741 = early_exit_reg ? 2'b00 : 2'b11;
  /* mc68881_fp80_mul_unit.vhd:187:11  */
  assign n742 = early_exit_reg ? mant_prod_reg : n738;
  /* mc68881_fp80_mul_unit.vhd:187:11  */
  assign n745 = early_exit_reg ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:187:11  */
  assign n746 = early_exit_reg ? early_result_reg : result_reg;
  /* mc68881_fp80_mul_unit.vhd:186:9  */
  assign n748 = state_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:200:11  */
  assign n749 = {{14{exp_res_reg[17]}}, exp_res_reg}; // sext
  /* mc68881_fp80_mul_unit.vhd:201:27  */
  assign n750 = mant_prod_reg[127]; // extract
  /* mc68881_fp80_mul_unit.vhd:202:32  */
  assign n752 = n749 + 32'b00000000000000000000000000000001;
  /* mc68881_fp80_mul_unit.vhd:201:11  */
  assign n755 = n750 ? 32'b00000000000000000000000001111111 : 32'b00000000000000000000000001111110;
  /* mc68881_fp80_mul_unit.vhd:201:11  */
  assign n756 = n750 ? n752 : n749;
  /* mc68881_fp80_mul_unit.vhd:209:36  */
  assign n759 = n755[6:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:209:36  */
  assign n761 = n759 + 7'b0111110;
  /* mc68881_fp80_mul_unit.vhd:209:36  */
  assign n763 = mant_prod_reg[n761 + 0 +: 67]; //(dyn_extract)
  /* mc68881_fp80_mul_unit.vhd:212:29  */
  assign n765 = n755 - 32'b00000000000000000000000001000011;
  /* mc68881_fp80_mul_unit.vhd:214:21  */
  assign n767 = $signed(n765) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n769 = $signed(32'b00000000000000000000000000000000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n770 = mant_prod_reg[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n771 = n770 & n769;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n774 = n771 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n776 = $signed(32'b00000000000000000000000000000001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n777 = mant_prod_reg[1]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n778 = n777 & n776;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n780 = n778 ? 1'b1 : n774;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n782 = $signed(32'b00000000000000000000000000000010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n783 = mant_prod_reg[2]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n784 = n783 & n782;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n786 = n784 ? 1'b1 : n780;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n788 = $signed(32'b00000000000000000000000000000011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n789 = mant_prod_reg[3]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n790 = n789 & n788;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n792 = n790 ? 1'b1 : n786;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n794 = $signed(32'b00000000000000000000000000000100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n795 = mant_prod_reg[4]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n796 = n795 & n794;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n798 = n796 ? 1'b1 : n792;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n800 = $signed(32'b00000000000000000000000000000101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n801 = mant_prod_reg[5]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n802 = n801 & n800;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n804 = n802 ? 1'b1 : n798;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n806 = $signed(32'b00000000000000000000000000000110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n807 = mant_prod_reg[6]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n808 = n807 & n806;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n810 = n808 ? 1'b1 : n804;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n812 = $signed(32'b00000000000000000000000000000111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n813 = mant_prod_reg[7]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n814 = n813 & n812;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n816 = n814 ? 1'b1 : n810;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n818 = $signed(32'b00000000000000000000000000001000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n819 = mant_prod_reg[8]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n820 = n819 & n818;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n822 = n820 ? 1'b1 : n816;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n824 = $signed(32'b00000000000000000000000000001001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n825 = mant_prod_reg[9]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n826 = n825 & n824;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n828 = n826 ? 1'b1 : n822;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n830 = $signed(32'b00000000000000000000000000001010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n831 = mant_prod_reg[10]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n832 = n831 & n830;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n834 = n832 ? 1'b1 : n828;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n836 = $signed(32'b00000000000000000000000000001011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n837 = mant_prod_reg[11]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n838 = n837 & n836;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n840 = n838 ? 1'b1 : n834;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n842 = $signed(32'b00000000000000000000000000001100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n843 = mant_prod_reg[12]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n844 = n843 & n842;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n846 = n844 ? 1'b1 : n840;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n848 = $signed(32'b00000000000000000000000000001101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n849 = mant_prod_reg[13]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n850 = n849 & n848;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n852 = n850 ? 1'b1 : n846;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n854 = $signed(32'b00000000000000000000000000001110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n855 = mant_prod_reg[14]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n856 = n855 & n854;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n858 = n856 ? 1'b1 : n852;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n860 = $signed(32'b00000000000000000000000000001111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n861 = mant_prod_reg[15]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n862 = n861 & n860;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n864 = n862 ? 1'b1 : n858;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n866 = $signed(32'b00000000000000000000000000010000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n867 = mant_prod_reg[16]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n868 = n867 & n866;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n870 = n868 ? 1'b1 : n864;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n872 = $signed(32'b00000000000000000000000000010001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n873 = mant_prod_reg[17]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n874 = n873 & n872;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n876 = n874 ? 1'b1 : n870;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n878 = $signed(32'b00000000000000000000000000010010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n879 = mant_prod_reg[18]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n880 = n879 & n878;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n882 = n880 ? 1'b1 : n876;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n884 = $signed(32'b00000000000000000000000000010011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n885 = mant_prod_reg[19]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n886 = n885 & n884;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n888 = n886 ? 1'b1 : n882;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n890 = $signed(32'b00000000000000000000000000010100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n891 = mant_prod_reg[20]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n892 = n891 & n890;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n894 = n892 ? 1'b1 : n888;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n896 = $signed(32'b00000000000000000000000000010101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n897 = mant_prod_reg[21]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n898 = n897 & n896;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n900 = n898 ? 1'b1 : n894;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n902 = $signed(32'b00000000000000000000000000010110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n903 = mant_prod_reg[22]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n904 = n903 & n902;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n906 = n904 ? 1'b1 : n900;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n908 = $signed(32'b00000000000000000000000000010111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n909 = mant_prod_reg[23]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n910 = n909 & n908;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n912 = n910 ? 1'b1 : n906;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n914 = $signed(32'b00000000000000000000000000011000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n915 = mant_prod_reg[24]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n916 = n915 & n914;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n918 = n916 ? 1'b1 : n912;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n920 = $signed(32'b00000000000000000000000000011001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n921 = mant_prod_reg[25]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n922 = n921 & n920;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n924 = n922 ? 1'b1 : n918;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n926 = $signed(32'b00000000000000000000000000011010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n927 = mant_prod_reg[26]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n928 = n927 & n926;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n930 = n928 ? 1'b1 : n924;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n932 = $signed(32'b00000000000000000000000000011011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n933 = mant_prod_reg[27]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n934 = n933 & n932;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n936 = n934 ? 1'b1 : n930;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n938 = $signed(32'b00000000000000000000000000011100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n939 = mant_prod_reg[28]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n940 = n939 & n938;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n942 = n940 ? 1'b1 : n936;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n944 = $signed(32'b00000000000000000000000000011101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n945 = mant_prod_reg[29]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n946 = n945 & n944;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n948 = n946 ? 1'b1 : n942;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n950 = $signed(32'b00000000000000000000000000011110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n951 = mant_prod_reg[30]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n952 = n951 & n950;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n954 = n952 ? 1'b1 : n948;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n956 = $signed(32'b00000000000000000000000000011111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n957 = mant_prod_reg[31]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n958 = n957 & n956;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n960 = n958 ? 1'b1 : n954;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n962 = $signed(32'b00000000000000000000000000100000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n963 = mant_prod_reg[32]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n964 = n963 & n962;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n966 = n964 ? 1'b1 : n960;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n968 = $signed(32'b00000000000000000000000000100001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n969 = mant_prod_reg[33]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n970 = n969 & n968;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n972 = n970 ? 1'b1 : n966;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n974 = $signed(32'b00000000000000000000000000100010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n975 = mant_prod_reg[34]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n976 = n975 & n974;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n978 = n976 ? 1'b1 : n972;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n980 = $signed(32'b00000000000000000000000000100011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n981 = mant_prod_reg[35]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n982 = n981 & n980;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n984 = n982 ? 1'b1 : n978;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n986 = $signed(32'b00000000000000000000000000100100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n987 = mant_prod_reg[36]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n988 = n987 & n986;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n990 = n988 ? 1'b1 : n984;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n992 = $signed(32'b00000000000000000000000000100101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n993 = mant_prod_reg[37]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n994 = n993 & n992;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n996 = n994 ? 1'b1 : n990;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n998 = $signed(32'b00000000000000000000000000100110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n999 = mant_prod_reg[38]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1000 = n999 & n998;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1002 = n1000 ? 1'b1 : n996;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1004 = $signed(32'b00000000000000000000000000100111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1005 = mant_prod_reg[39]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1006 = n1005 & n1004;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1008 = n1006 ? 1'b1 : n1002;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1010 = $signed(32'b00000000000000000000000000101000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1011 = mant_prod_reg[40]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1012 = n1011 & n1010;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1014 = n1012 ? 1'b1 : n1008;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1016 = $signed(32'b00000000000000000000000000101001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1017 = mant_prod_reg[41]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1018 = n1017 & n1016;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1020 = n1018 ? 1'b1 : n1014;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1022 = $signed(32'b00000000000000000000000000101010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1023 = mant_prod_reg[42]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1024 = n1023 & n1022;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1026 = n1024 ? 1'b1 : n1020;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1028 = $signed(32'b00000000000000000000000000101011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1029 = mant_prod_reg[43]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1030 = n1029 & n1028;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1032 = n1030 ? 1'b1 : n1026;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1034 = $signed(32'b00000000000000000000000000101100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1035 = mant_prod_reg[44]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1036 = n1035 & n1034;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1038 = n1036 ? 1'b1 : n1032;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1040 = $signed(32'b00000000000000000000000000101101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1041 = mant_prod_reg[45]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1042 = n1041 & n1040;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1044 = n1042 ? 1'b1 : n1038;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1046 = $signed(32'b00000000000000000000000000101110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1047 = mant_prod_reg[46]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1048 = n1047 & n1046;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1050 = n1048 ? 1'b1 : n1044;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1052 = $signed(32'b00000000000000000000000000101111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1053 = mant_prod_reg[47]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1054 = n1053 & n1052;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1056 = n1054 ? 1'b1 : n1050;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1058 = $signed(32'b00000000000000000000000000110000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1059 = mant_prod_reg[48]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1060 = n1059 & n1058;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1062 = n1060 ? 1'b1 : n1056;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1064 = $signed(32'b00000000000000000000000000110001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1065 = mant_prod_reg[49]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1066 = n1065 & n1064;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1068 = n1066 ? 1'b1 : n1062;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1070 = $signed(32'b00000000000000000000000000110010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1071 = mant_prod_reg[50]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1072 = n1071 & n1070;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1074 = n1072 ? 1'b1 : n1068;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1076 = $signed(32'b00000000000000000000000000110011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1077 = mant_prod_reg[51]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1078 = n1077 & n1076;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1080 = n1078 ? 1'b1 : n1074;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1082 = $signed(32'b00000000000000000000000000110100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1083 = mant_prod_reg[52]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1084 = n1083 & n1082;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1086 = n1084 ? 1'b1 : n1080;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1088 = $signed(32'b00000000000000000000000000110101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1089 = mant_prod_reg[53]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1090 = n1089 & n1088;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1092 = n1090 ? 1'b1 : n1086;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1094 = $signed(32'b00000000000000000000000000110110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1095 = mant_prod_reg[54]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1096 = n1095 & n1094;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1098 = n1096 ? 1'b1 : n1092;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1100 = $signed(32'b00000000000000000000000000110111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1101 = mant_prod_reg[55]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1102 = n1101 & n1100;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1104 = n1102 ? 1'b1 : n1098;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1106 = $signed(32'b00000000000000000000000000111000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1107 = mant_prod_reg[56]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1108 = n1107 & n1106;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1110 = n1108 ? 1'b1 : n1104;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1112 = $signed(32'b00000000000000000000000000111001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1113 = mant_prod_reg[57]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1114 = n1113 & n1112;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1116 = n1114 ? 1'b1 : n1110;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1118 = $signed(32'b00000000000000000000000000111010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1119 = mant_prod_reg[58]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1120 = n1119 & n1118;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1122 = n1120 ? 1'b1 : n1116;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1124 = $signed(32'b00000000000000000000000000111011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1125 = mant_prod_reg[59]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1126 = n1125 & n1124;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1128 = n1126 ? 1'b1 : n1122;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1130 = $signed(32'b00000000000000000000000000111100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1131 = mant_prod_reg[60]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1132 = n1131 & n1130;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1134 = n1132 ? 1'b1 : n1128;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1136 = $signed(32'b00000000000000000000000000111101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1137 = mant_prod_reg[61]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1138 = n1137 & n1136;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1140 = n1138 ? 1'b1 : n1134;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1142 = $signed(32'b00000000000000000000000000111110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1143 = mant_prod_reg[62]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1144 = n1143 & n1142;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1146 = n1144 ? 1'b1 : n1140;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1148 = $signed(32'b00000000000000000000000000111111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1149 = mant_prod_reg[63]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1150 = n1149 & n1148;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1152 = n1150 ? 1'b1 : n1146;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1154 = $signed(32'b00000000000000000000000001000000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1155 = mant_prod_reg[64]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1156 = n1155 & n1154;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1158 = n1156 ? 1'b1 : n1152;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1160 = $signed(32'b00000000000000000000000001000001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1161 = mant_prod_reg[65]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1162 = n1161 & n1160;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1164 = n1162 ? 1'b1 : n1158;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1166 = $signed(32'b00000000000000000000000001000010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1167 = mant_prod_reg[66]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1168 = n1167 & n1166;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1170 = n1168 ? 1'b1 : n1164;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1172 = $signed(32'b00000000000000000000000001000011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1173 = mant_prod_reg[67]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1174 = n1173 & n1172;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1176 = n1174 ? 1'b1 : n1170;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1178 = $signed(32'b00000000000000000000000001000100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1179 = mant_prod_reg[68]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1180 = n1179 & n1178;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1182 = n1180 ? 1'b1 : n1176;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1184 = $signed(32'b00000000000000000000000001000101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1185 = mant_prod_reg[69]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1186 = n1185 & n1184;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1188 = n1186 ? 1'b1 : n1182;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1190 = $signed(32'b00000000000000000000000001000110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1191 = mant_prod_reg[70]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1192 = n1191 & n1190;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1194 = n1192 ? 1'b1 : n1188;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1196 = $signed(32'b00000000000000000000000001000111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1197 = mant_prod_reg[71]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1198 = n1197 & n1196;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1200 = n1198 ? 1'b1 : n1194;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1202 = $signed(32'b00000000000000000000000001001000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1203 = mant_prod_reg[72]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1204 = n1203 & n1202;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1206 = n1204 ? 1'b1 : n1200;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1208 = $signed(32'b00000000000000000000000001001001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1209 = mant_prod_reg[73]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1210 = n1209 & n1208;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1212 = n1210 ? 1'b1 : n1206;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1214 = $signed(32'b00000000000000000000000001001010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1215 = mant_prod_reg[74]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1216 = n1215 & n1214;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1218 = n1216 ? 1'b1 : n1212;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1220 = $signed(32'b00000000000000000000000001001011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1221 = mant_prod_reg[75]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1222 = n1221 & n1220;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1224 = n1222 ? 1'b1 : n1218;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1226 = $signed(32'b00000000000000000000000001001100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1227 = mant_prod_reg[76]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1228 = n1227 & n1226;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1230 = n1228 ? 1'b1 : n1224;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1232 = $signed(32'b00000000000000000000000001001101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1233 = mant_prod_reg[77]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1234 = n1233 & n1232;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1236 = n1234 ? 1'b1 : n1230;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1238 = $signed(32'b00000000000000000000000001001110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1239 = mant_prod_reg[78]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1240 = n1239 & n1238;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1242 = n1240 ? 1'b1 : n1236;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1244 = $signed(32'b00000000000000000000000001001111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1245 = mant_prod_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1246 = n1245 & n1244;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1248 = n1246 ? 1'b1 : n1242;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1250 = $signed(32'b00000000000000000000000001010000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1251 = mant_prod_reg[80]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1252 = n1251 & n1250;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1254 = n1252 ? 1'b1 : n1248;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1256 = $signed(32'b00000000000000000000000001010001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1257 = mant_prod_reg[81]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1258 = n1257 & n1256;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1260 = n1258 ? 1'b1 : n1254;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1262 = $signed(32'b00000000000000000000000001010010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1263 = mant_prod_reg[82]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1264 = n1263 & n1262;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1266 = n1264 ? 1'b1 : n1260;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1268 = $signed(32'b00000000000000000000000001010011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1269 = mant_prod_reg[83]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1270 = n1269 & n1268;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1272 = n1270 ? 1'b1 : n1266;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1274 = $signed(32'b00000000000000000000000001010100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1275 = mant_prod_reg[84]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1276 = n1275 & n1274;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1278 = n1276 ? 1'b1 : n1272;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1280 = $signed(32'b00000000000000000000000001010101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1281 = mant_prod_reg[85]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1282 = n1281 & n1280;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1284 = n1282 ? 1'b1 : n1278;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1286 = $signed(32'b00000000000000000000000001010110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1287 = mant_prod_reg[86]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1288 = n1287 & n1286;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1290 = n1288 ? 1'b1 : n1284;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1292 = $signed(32'b00000000000000000000000001010111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1293 = mant_prod_reg[87]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1294 = n1293 & n1292;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1296 = n1294 ? 1'b1 : n1290;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1298 = $signed(32'b00000000000000000000000001011000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1299 = mant_prod_reg[88]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1300 = n1299 & n1298;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1302 = n1300 ? 1'b1 : n1296;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1304 = $signed(32'b00000000000000000000000001011001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1305 = mant_prod_reg[89]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1306 = n1305 & n1304;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1308 = n1306 ? 1'b1 : n1302;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1310 = $signed(32'b00000000000000000000000001011010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1311 = mant_prod_reg[90]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1312 = n1311 & n1310;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1314 = n1312 ? 1'b1 : n1308;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1316 = $signed(32'b00000000000000000000000001011011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1317 = mant_prod_reg[91]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1318 = n1317 & n1316;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1320 = n1318 ? 1'b1 : n1314;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1322 = $signed(32'b00000000000000000000000001011100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1323 = mant_prod_reg[92]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1324 = n1323 & n1322;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1326 = n1324 ? 1'b1 : n1320;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1328 = $signed(32'b00000000000000000000000001011101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1329 = mant_prod_reg[93]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1330 = n1329 & n1328;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1332 = n1330 ? 1'b1 : n1326;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1334 = $signed(32'b00000000000000000000000001011110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1335 = mant_prod_reg[94]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1336 = n1335 & n1334;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1338 = n1336 ? 1'b1 : n1332;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1340 = $signed(32'b00000000000000000000000001011111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1341 = mant_prod_reg[95]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1342 = n1341 & n1340;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1344 = n1342 ? 1'b1 : n1338;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1346 = $signed(32'b00000000000000000000000001100000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1347 = mant_prod_reg[96]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1348 = n1347 & n1346;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1350 = n1348 ? 1'b1 : n1344;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1352 = $signed(32'b00000000000000000000000001100001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1353 = mant_prod_reg[97]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1354 = n1353 & n1352;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1356 = n1354 ? 1'b1 : n1350;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1358 = $signed(32'b00000000000000000000000001100010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1359 = mant_prod_reg[98]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1360 = n1359 & n1358;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1362 = n1360 ? 1'b1 : n1356;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1364 = $signed(32'b00000000000000000000000001100011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1365 = mant_prod_reg[99]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1366 = n1365 & n1364;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1368 = n1366 ? 1'b1 : n1362;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1370 = $signed(32'b00000000000000000000000001100100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1371 = mant_prod_reg[100]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1372 = n1371 & n1370;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1374 = n1372 ? 1'b1 : n1368;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1376 = $signed(32'b00000000000000000000000001100101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1377 = mant_prod_reg[101]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1378 = n1377 & n1376;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1380 = n1378 ? 1'b1 : n1374;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1382 = $signed(32'b00000000000000000000000001100110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1383 = mant_prod_reg[102]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1384 = n1383 & n1382;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1386 = n1384 ? 1'b1 : n1380;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1388 = $signed(32'b00000000000000000000000001100111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1389 = mant_prod_reg[103]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1390 = n1389 & n1388;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1392 = n1390 ? 1'b1 : n1386;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1394 = $signed(32'b00000000000000000000000001101000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1395 = mant_prod_reg[104]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1396 = n1395 & n1394;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1398 = n1396 ? 1'b1 : n1392;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1400 = $signed(32'b00000000000000000000000001101001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1401 = mant_prod_reg[105]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1402 = n1401 & n1400;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1404 = n1402 ? 1'b1 : n1398;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1406 = $signed(32'b00000000000000000000000001101010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1407 = mant_prod_reg[106]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1408 = n1407 & n1406;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1410 = n1408 ? 1'b1 : n1404;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1412 = $signed(32'b00000000000000000000000001101011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1413 = mant_prod_reg[107]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1414 = n1413 & n1412;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1416 = n1414 ? 1'b1 : n1410;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1418 = $signed(32'b00000000000000000000000001101100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1419 = mant_prod_reg[108]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1420 = n1419 & n1418;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1422 = n1420 ? 1'b1 : n1416;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1424 = $signed(32'b00000000000000000000000001101101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1425 = mant_prod_reg[109]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1426 = n1425 & n1424;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1428 = n1426 ? 1'b1 : n1422;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1430 = $signed(32'b00000000000000000000000001101110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1431 = mant_prod_reg[110]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1432 = n1431 & n1430;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1434 = n1432 ? 1'b1 : n1428;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1436 = $signed(32'b00000000000000000000000001101111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1437 = mant_prod_reg[111]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1438 = n1437 & n1436;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1440 = n1438 ? 1'b1 : n1434;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1442 = $signed(32'b00000000000000000000000001110000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1443 = mant_prod_reg[112]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1444 = n1443 & n1442;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1446 = n1444 ? 1'b1 : n1440;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1448 = $signed(32'b00000000000000000000000001110001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1449 = mant_prod_reg[113]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1450 = n1449 & n1448;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1452 = n1450 ? 1'b1 : n1446;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1454 = $signed(32'b00000000000000000000000001110010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1455 = mant_prod_reg[114]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1456 = n1455 & n1454;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1458 = n1456 ? 1'b1 : n1452;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1460 = $signed(32'b00000000000000000000000001110011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1461 = mant_prod_reg[115]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1462 = n1461 & n1460;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1464 = n1462 ? 1'b1 : n1458;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1466 = $signed(32'b00000000000000000000000001110100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1467 = mant_prod_reg[116]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1468 = n1467 & n1466;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1470 = n1468 ? 1'b1 : n1464;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1472 = $signed(32'b00000000000000000000000001110101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1473 = mant_prod_reg[117]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1474 = n1473 & n1472;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1476 = n1474 ? 1'b1 : n1470;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1478 = $signed(32'b00000000000000000000000001110110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1479 = mant_prod_reg[118]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1480 = n1479 & n1478;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1482 = n1480 ? 1'b1 : n1476;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1484 = $signed(32'b00000000000000000000000001110111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1485 = mant_prod_reg[119]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1486 = n1485 & n1484;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1488 = n1486 ? 1'b1 : n1482;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1490 = $signed(32'b00000000000000000000000001111000) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1491 = mant_prod_reg[120]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1492 = n1491 & n1490;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1494 = n1492 ? 1'b1 : n1488;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1496 = $signed(32'b00000000000000000000000001111001) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1497 = mant_prod_reg[121]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1498 = n1497 & n1496;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1500 = n1498 ? 1'b1 : n1494;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1502 = $signed(32'b00000000000000000000000001111010) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1503 = mant_prod_reg[122]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1504 = n1503 & n1502;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1506 = n1504 ? 1'b1 : n1500;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1508 = $signed(32'b00000000000000000000000001111011) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1509 = mant_prod_reg[123]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1510 = n1509 & n1508;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1512 = n1510 ? 1'b1 : n1506;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1514 = $signed(32'b00000000000000000000000001111100) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1515 = mant_prod_reg[124]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1516 = n1515 & n1514;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1518 = n1516 ? 1'b1 : n1512;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1520 = $signed(32'b00000000000000000000000001111101) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1521 = mant_prod_reg[125]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1522 = n1521 & n1520;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1524 = n1522 ? 1'b1 : n1518;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1526 = $signed(32'b00000000000000000000000001111110) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1527 = mant_prod_reg[126]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1528 = n1527 & n1526;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1530 = n1528 ? 1'b1 : n1524;
  /* mc68881_fp80_mul_unit.vhd:216:22  */
  assign n1532 = $signed(32'b00000000000000000000000001111111) <= $signed(n765);
  /* mc68881_fp80_mul_unit.vhd:216:49  */
  assign n1533 = mant_prod_reg[127]; // extract
  /* mc68881_fp80_mul_unit.vhd:216:32  */
  assign n1534 = n1533 & n1532;
  /* mc68881_fp80_mul_unit.vhd:216:15  */
  assign n1536 = n1534 ? 1'b1 : n1530;
  /* mc68881_fp80_mul_unit.vhd:214:11  */
  assign n1538 = n767 ? n1536 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:221:34  */
  assign n1540 = n763[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:221:38  */
  assign n1541 = n1540 | n1538;
  assign n1542 = n763[66:1]; // extract
  assign n1543 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:224:32  */
  assign n1544 = n1543[66:3]; // extract
  assign n1545 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:230:36  */
  assign n1546 = n1545[42]; // extract
  assign n1547 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:231:36  */
  assign n1548 = n1547[41]; // extract
  assign n1549 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:232:26  */
  assign n1550 = n1549[40:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:232:40  */
  assign n1552 = n1550 != 41'b00000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:232:15  */
  assign n1555 = n1552 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:229:13  */
  assign n1557 = rp_reg == 2'b01;
  assign n1558 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:235:36  */
  assign n1559 = n1558[13]; // extract
  assign n1560 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:236:36  */
  assign n1561 = n1560[12]; // extract
  assign n1562 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:237:26  */
  assign n1563 = n1562[11:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:237:40  */
  assign n1565 = n1563 != 12'b000000000000;
  /* mc68881_fp80_mul_unit.vhd:237:15  */
  assign n1568 = n1565 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:234:13  */
  assign n1570 = rp_reg == 2'b10;
  assign n1571 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:240:36  */
  assign n1572 = n1571[2]; // extract
  assign n1573 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:241:36  */
  assign n1574 = n1573[1]; // extract
  assign n1575 = {n1542, n1541};
  /* mc68881_fp80_mul_unit.vhd:242:26  */
  assign n1576 = n1575[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:242:15  */
  assign n1579 = n1576 ? 1'b1 : 1'b0;
  assign n1580 = {n1570, n1557};
  /* mc68881_fp80_mul_unit.vhd:228:11  */
  always @*
    case (n1580)
      2'b10: n1581 = n1559;
      2'b01: n1581 = n1546;
      default: n1581 = n1572;
    endcase
  /* mc68881_fp80_mul_unit.vhd:228:11  */
  always @*
    case (n1580)
      2'b10: n1582 = n1561;
      2'b01: n1582 = n1548;
      default: n1582 = n1574;
    endcase
  /* mc68881_fp80_mul_unit.vhd:228:11  */
  always @*
    case (n1580)
      2'b10: n1583 = n1568;
      2'b01: n1583 = n1555;
      default: n1583 = n1579;
    endcase
  /* mc68881_fp80_mul_unit.vhd:246:30  */
  assign n1589 = n1581 | n1582;
  /* mc68881_fp80_mul_unit.vhd:246:43  */
  assign n1590 = n1589 | n1583;
  /* mc68881_fp80_mul_unit.vhd:252:55  */
  assign n1591 = n1582 | n1583;
  /* mc68881_fp80_mul_unit.vhd:252:83  */
  assign n1592 = n1543[43]; // extract
  /* mc68881_fp80_mul_unit.vhd:252:71  */
  assign n1593 = n1591 | n1592;
  /* mc68881_fp80_mul_unit.vhd:252:34  */
  assign n1594 = n1593 & n1581;
  /* mc68881_fp80_mul_unit.vhd:252:19  */
  assign n1597 = n1594 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:251:17  */
  assign n1599 = rp_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:256:55  */
  assign n1600 = n1582 | n1583;
  /* mc68881_fp80_mul_unit.vhd:256:83  */
  assign n1601 = n1543[14]; // extract
  /* mc68881_fp80_mul_unit.vhd:256:71  */
  assign n1602 = n1600 | n1601;
  /* mc68881_fp80_mul_unit.vhd:256:34  */
  assign n1603 = n1602 & n1581;
  /* mc68881_fp80_mul_unit.vhd:256:19  */
  assign n1606 = n1603 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:255:17  */
  assign n1608 = rp_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:260:55  */
  assign n1609 = n1582 | n1583;
  /* mc68881_fp80_mul_unit.vhd:260:83  */
  assign n1610 = n1543[3]; // extract
  /* mc68881_fp80_mul_unit.vhd:260:71  */
  assign n1611 = n1609 | n1610;
  /* mc68881_fp80_mul_unit.vhd:260:34  */
  assign n1612 = n1611 & n1581;
  /* mc68881_fp80_mul_unit.vhd:260:19  */
  assign n1615 = n1612 ? 1'b1 : 1'b0;
  assign n1616 = {n1608, n1599};
  /* mc68881_fp80_mul_unit.vhd:250:15  */
  always @*
    case (n1616)
      2'b10: n1617 = n1606;
      2'b01: n1617 = n1597;
      default: n1617 = n1615;
    endcase
  /* mc68881_fp80_mul_unit.vhd:249:13  */
  assign n1619 = rm_reg == 2'b00;
  /* mc68881_fp80_mul_unit.vhd:264:13  */
  assign n1621 = rm_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:267:37  */
  assign n1622 = n1590 & res_sign_reg;
  /* mc68881_fp80_mul_unit.vhd:267:15  */
  assign n1625 = n1622 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:266:13  */
  assign n1627 = rm_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:271:31  */
  assign n1628 = ~res_sign_reg;
  /* mc68881_fp80_mul_unit.vhd:271:37  */
  assign n1629 = n1590 & n1628;
  /* mc68881_fp80_mul_unit.vhd:271:15  */
  assign n1632 = n1629 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:270:13  */
  assign n1634 = rm_reg == 2'b11;
  assign n1635 = {n1634, n1627, n1621, n1619};
  /* mc68881_fp80_mul_unit.vhd:248:11  */
  always @*
    case (n1635)
      4'b1000: n1638 = n1632;
      4'b0100: n1638 = n1625;
      4'b0010: n1638 = 1'b0;
      4'b0001: n1638 = n1617;
      default: n1638 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:278:57  */
  assign n1641 = {1'b0, n1544};
  /* mc68881_fp80_mul_unit.vhd:278:70  */
  assign n1643 = n1641 + 65'b00000000000000000000000010000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:278:15  */
  assign n1645 = rp_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:279:57  */
  assign n1647 = {1'b0, n1544};
  /* mc68881_fp80_mul_unit.vhd:279:70  */
  assign n1649 = n1647 + 65'b00000000000000000000000000000000000000000000000000000100000000000;
  /* mc68881_fp80_mul_unit.vhd:279:15  */
  assign n1651 = rp_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:280:57  */
  assign n1653 = {1'b0, n1544};
  /* mc68881_fp80_mul_unit.vhd:280:70  */
  assign n1655 = n1653 + 65'b00000000000000000000000000000000000000000000000000000000000000001;
  assign n1656 = {n1651, n1645};
  /* mc68881_fp80_mul_unit.vhd:277:13  */
  always @*
    case (n1656)
      2'b10: n1657 = n1649;
      2'b01: n1657 = n1643;
      default: n1657 = n1655;
    endcase
  /* mc68881_fp80_mul_unit.vhd:282:26  */
  assign n1658 = n1657[64]; // extract
  /* mc68881_fp80_mul_unit.vhd:284:50  */
  assign n1659 = n1657[63:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:284:28  */
  assign n1661 = n1659 >> 31'b0000000000000000000000000000001;
  /* mc68881_fp80_mul_unit.vhd:285:28  */
  assign n1662 = n1657[0]; // extract
  assign n1664 = n1661[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:285:15  */
  assign n1665 = n1662 ? 1'b1 : n1664;
  assign n1668 = n1661[62:1]; // extract
  /* mc68881_fp80_mul_unit.vhd:289:34  */
  assign n1670 = n756 + 32'b00000000000000000000000000000001;
  /* mc68881_fp80_mul_unit.vhd:291:38  */
  assign n1671 = n1657[63:0]; // extract
  assign n1672 = {1'b1, n1668, n1665};
  /* mc68881_fp80_mul_unit.vhd:282:13  */
  assign n1673 = n1658 ? n1672 : n1671;
  /* mc68881_fp80_mul_unit.vhd:276:11  */
  assign n1674 = n1677 ? n1670 : n756;
  /* mc68881_fp80_mul_unit.vhd:276:11  */
  assign n1675 = n1638 ? n1673 : n1544;
  /* mc68881_fp80_mul_unit.vhd:276:11  */
  assign n1677 = n1658 & n1638;
  /* mc68881_fp80_mul_unit.vhd:297:13  */
  assign n1680 = rp_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:298:13  */
  assign n1683 = rp_reg == 2'b10;
  assign n1684 = {n1683, n1680};
  assign n1685 = n1678[10:0]; // extract
  assign n1686 = n1675[10:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:296:11  */
  always @*
    case (n1684)
      2'b10: n1687 = 11'b00000000000;
      2'b01: n1687 = n1685;
      default: n1687 = n1686;
    endcase
  assign n1688 = n1678[39:11]; // extract
  assign n1689 = n1675[39:11]; // extract
  /* mc68881_fp80_mul_unit.vhd:296:11  */
  always @*
    case (n1684)
      2'b10: n1690 = n1689;
      2'b01: n1690 = n1688;
      default: n1690 = n1689;
    endcase
  assign n1692 = n1675[63:40]; // extract
  /* mc68881_fp80_mul_unit.vhd:303:22  */
  assign n1694 = $signed(n1674) <= $signed(32'b00000000000000000000000000000000);
  /* mc68881_fp80_mul_unit.vhd:304:31  */
  assign n1696 = 32'b00000000000000000000000000000001 - n1674;
  /* mc68881_fp80_mul_unit.vhd:304:13  */
  assign n1697 = n1696[30:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:305:29  */
  assign n1698 = {1'b0, n1697};  //  uext
  /* mc68881_fp80_mul_unit.vhd:305:29  */
  assign n1700 = $signed(n1698) >= $signed(32'b00000000000000000000000001000000);
  assign n1701 = {n1692, n1690, n1687};
  /* mc68881_fp80_mul_unit.vhd:305:59  */
  assign n1703 = n1701 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:305:46  */
  assign n1704 = n1700 | n1703;
  assign n1706 = {n1692, n1690, n1687};
  /* mc68881_fp80_mul_unit.vhd:310:72  */
  assign n1707 = n1706 >> n1697;
  assign n1708 = {res_sign_reg, 15'b000000000000000, n1707};
  /* mc68881_fp80_mul_unit.vhd:305:13  */
  assign n1710 = n1704 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1708;
  /* mc68881_fp80_mul_unit.vhd:313:25  */
  assign n1712 = $signed(n1674) >= $signed(32'b00000000000000000111111111111111);
  /* mc68881_fp80_mul_unit.vhd:319:36  */
  assign n1715 = n1674[30:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:319:24  */
  assign n1716 = n1715[14:0];  // trunc
  assign n1717 = {n1692, n1690, n1687};
  assign n1718 = {res_sign_reg, n1716, n1717};
  assign n1719 = {res_sign_reg, 15'b111111111111111, 64'b0000000000000000000000000000000000000000000000000000000000000000};
  /* mc68881_fp80_mul_unit.vhd:313:11  */
  assign n1720 = n1712 ? n1719 : n1718;
  /* mc68881_fp80_mul_unit.vhd:303:11  */
  assign n1722 = n1694 ? n1710 : n1720;
  /* mc68881_fp80_mul_unit.vhd:198:9  */
  assign n1726 = state_reg == 2'b11;
  assign n1727 = {n1726, n748, n735, n49};
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1731 = 2'b00;
      4'b0100: n1731 = n741;
      4'b0010: n1731 = 2'b10;
      4'b0001: n1731 = n43;
      default: n1731 = 2'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1733 = a_reg;
      4'b0100: n1733 = a_reg;
      4'b0010: n1733 = a_reg;
      4'b0001: n1733 = n44;
      default: n1733 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1735 = b_reg;
      4'b0100: n1735 = b_reg;
      4'b0010: n1735 = b_reg;
      4'b0001: n1735 = n45;
      default: n1735 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1737 = rm_reg;
      4'b0100: n1737 = rm_reg;
      4'b0010: n1737 = rm_reg;
      4'b0001: n1737 = n46;
      default: n1737 = 2'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1739 = rp_reg;
      4'b0100: n1739 = rp_reg;
      4'b0010: n1739 = rp_reg;
      4'b0001: n1739 = n47;
      default: n1739 = 2'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1741 = a_mant_reg;
      4'b0100: n1741 = a_mant_reg;
      4'b0010: n1741 = n139;
      4'b0001: n1741 = a_mant_reg;
      default: n1741 = 64'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1743 = b_mant_reg;
      4'b0100: n1743 = b_mant_reg;
      4'b0010: n1743 = n227;
      4'b0001: n1743 = b_mant_reg;
      default: n1743 = 64'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1745 = res_sign_reg;
      4'b0100: n1745 = res_sign_reg;
      4'b0010: n1745 = n230;
      4'b0001: n1745 = res_sign_reg;
      default: n1745 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1747 = exp_res_reg;
      4'b0100: n1747 = exp_res_reg;
      4'b0010: n1747 = n733;
      4'b0001: n1747 = exp_res_reg;
      default: n1747 = 18'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1749 = early_exit_reg;
      4'b0100: n1749 = early_exit_reg;
      4'b0010: n1749 = n727;
      4'b0001: n1749 = early_exit_reg;
      default: n1749 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1751 = early_result_reg;
      4'b0100: n1751 = early_result_reg;
      4'b0010: n1751 = n729;
      4'b0001: n1751 = early_result_reg;
      default: n1751 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1753 = mant_prod_reg;
      4'b0100: n1753 = n742;
      4'b0010: n1753 = mant_prod_reg;
      4'b0001: n1753 = mant_prod_reg;
      default: n1753 = 128'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1757 = 1'b1;
      4'b0100: n1757 = n745;
      4'b0010: n1757 = 1'b0;
      4'b0001: n1757 = 1'b0;
      default: n1757 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:116:7  */
  always @*
    case (n1727)
      4'b1000: n1760 = n1722;
      4'b0100: n1760 = n746;
      4'b0010: n1760 = result_reg;
      4'b0001: n1760 = result_reg;
      default: n1760 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1813 = n41 ? 2'b00 : n1731;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1815 = n41 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1733;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1817 = n41 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1735;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1819 = n41 ? 2'b00 : n1737;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1821 = n41 ? 2'b00 : n1739;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1823 = n41 ? 64'b0000000000000000000000000000000000000000000000000000000000000000 : n1741;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1825 = n41 ? 64'b0000000000000000000000000000000000000000000000000000000000000000 : n1743;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1827 = n41 ? 1'b0 : n1745;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1829 = n41 ? 18'b000000000000000000 : n1747;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1831 = n41 ? 1'b0 : n1749;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1833 = n41 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1751;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1835 = n41 ? 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1753;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1837 = n41 ? 1'b0 : n1757;
  /* mc68881_fp80_mul_unit.vhd:98:5  */
  assign n1839 = n41 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1760;
  /* mc68881_fp80_mul_unit.vhd:332:32  */
  assign n1919 = state_reg != 2'b00;
  /* mc68881_fp80_mul_unit.vhd:332:17  */
  assign n1920 = n1919 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1922 <= n1813;
  initial
    n1922 = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1923 <= n1815;
  initial
    n1923 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1924 <= n1817;
  initial
    n1924 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1925 <= n1819;
  initial
    n1925 = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1926 <= n1821;
  initial
    n1926 = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1927 <= n1823;
  initial
    n1927 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1928 <= n1825;
  initial
    n1928 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1929 <= n1827;
  initial
    n1929 = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1930 <= n1829;
  initial
    n1930 = 18'b000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1931 <= n1831;
  initial
    n1931 = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1932 <= n1833;
  initial
    n1932 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1933 <= n1835;
  initial
    n1933 = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1934 <= n1837;
  initial
    n1934 = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  always @(posedge clk)
    n1935 <= n1839;
  initial
    n1935 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
endmodule

