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
  wire n40;
  wire [1:0] n42;
  wire [79:0] n43;
  wire [79:0] n44;
  wire [1:0] n45;
  wire [1:0] n46;
  wire n48;
  wire [63:0] n49;
  wire [63:0] n50;
  wire [14:0] n51;
  wire n53;
  wire n55;
  wire n56;
  wire [31:0] n63;
  wire n65;
  wire [31:0] n66;
  wire [63:0] n68;
  wire [30:0] n71;
  wire [63:0] n73;
  wire [15:0] n74;
  wire n76;
  wire [31:0] n77;
  wire [31:0] n79;
  wire [30:0] n80;
  wire [47:0] n81;
  wire [63:0] n83;
  wire [30:0] n84;
  wire [63:0] n85;
  wire [7:0] n86;
  wire n88;
  wire [31:0] n89;
  wire [31:0] n91;
  wire [30:0] n92;
  wire [55:0] n93;
  wire [63:0] n95;
  wire [30:0] n96;
  wire [63:0] n97;
  wire [3:0] n98;
  wire n100;
  wire [31:0] n101;
  wire [31:0] n103;
  wire [30:0] n104;
  wire [59:0] n105;
  wire [63:0] n107;
  wire [30:0] n108;
  wire [63:0] n109;
  wire [1:0] n110;
  wire n112;
  wire [31:0] n113;
  wire [31:0] n115;
  wire [30:0] n116;
  wire [61:0] n117;
  wire [63:0] n119;
  wire [30:0] n120;
  wire [63:0] n121;
  wire n122;
  wire n123;
  wire [31:0] n124;
  wire [31:0] n126;
  wire [30:0] n127;
  wire [30:0] n128;
  wire [63:0] n129;
  wire [31:0] n130;
  wire [31:0] n132;
  wire [14:0] n133;
  wire [30:0] n134;
  wire [31:0] n135;
  wire [31:0] n137;
  wire [63:0] n138;
  wire [14:0] n139;
  wire n141;
  wire n143;
  wire n144;
  wire [31:0] n151;
  wire n153;
  wire [31:0] n154;
  wire [63:0] n156;
  wire [30:0] n159;
  wire [63:0] n161;
  wire [15:0] n162;
  wire n164;
  wire [31:0] n165;
  wire [31:0] n167;
  wire [30:0] n168;
  wire [47:0] n169;
  wire [63:0] n171;
  wire [30:0] n172;
  wire [63:0] n173;
  wire [7:0] n174;
  wire n176;
  wire [31:0] n177;
  wire [31:0] n179;
  wire [30:0] n180;
  wire [55:0] n181;
  wire [63:0] n183;
  wire [30:0] n184;
  wire [63:0] n185;
  wire [3:0] n186;
  wire n188;
  wire [31:0] n189;
  wire [31:0] n191;
  wire [30:0] n192;
  wire [59:0] n193;
  wire [63:0] n195;
  wire [30:0] n196;
  wire [63:0] n197;
  wire [1:0] n198;
  wire n200;
  wire [31:0] n201;
  wire [31:0] n203;
  wire [30:0] n204;
  wire [61:0] n205;
  wire [63:0] n207;
  wire [30:0] n208;
  wire [63:0] n209;
  wire n210;
  wire n211;
  wire [31:0] n212;
  wire [31:0] n214;
  wire [30:0] n215;
  wire [30:0] n216;
  wire [63:0] n217;
  wire [31:0] n218;
  wire [31:0] n220;
  wire [14:0] n221;
  wire [30:0] n222;
  wire [31:0] n223;
  wire [31:0] n225;
  wire [63:0] n226;
  wire n227;
  wire n228;
  wire n229;
  wire n241;
  wire [14:0] n244;
  wire [63:0] n246;
  wire [79:0] n247;
  wire [14:0] n248;
  wire n250;
  wire n262;
  wire [14:0] n265;
  wire [63:0] n267;
  wire [79:0] n268;
  localparam [63:0] n271 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n272;
  wire [14:0] n273;
  wire n275;
  wire [63:0] n276;
  wire n278;
  wire [63:0] n279;
  wire [63:0] n280;
  wire n281;
  wire n282;
  wire n283;
  wire n284;
  wire n285;
  wire n297;
  wire [14:0] n300;
  wire [63:0] n302;
  wire [79:0] n303;
  wire [14:0] n304;
  wire n306;
  wire n318;
  wire [14:0] n321;
  wire [63:0] n323;
  wire [79:0] n324;
  localparam [63:0] n327 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n328;
  wire [14:0] n329;
  wire n331;
  wire [63:0] n332;
  wire n334;
  wire [63:0] n335;
  wire [63:0] n336;
  wire n337;
  wire n338;
  wire n339;
  wire n340;
  wire n341;
  wire n342;
  wire n355;
  wire [14:0] n358;
  wire [63:0] n360;
  wire [79:0] n361;
  wire [14:0] n362;
  wire n364;
  wire n376;
  wire [14:0] n379;
  wire [63:0] n381;
  wire [79:0] n382;
  localparam [63:0] n385 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n386;
  wire [14:0] n387;
  wire n389;
  wire [63:0] n390;
  wire n392;
  wire [63:0] n393;
  wire [63:0] n394;
  wire n395;
  wire n396;
  wire n397;
  wire n398;
  wire n399;
  wire n411;
  wire [14:0] n414;
  wire [63:0] n416;
  wire [79:0] n417;
  wire [14:0] n418;
  wire n420;
  wire n432;
  wire [14:0] n435;
  wire [63:0] n437;
  wire [79:0] n438;
  localparam [63:0] n441 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n442;
  wire [14:0] n443;
  wire n445;
  wire [63:0] n446;
  wire n448;
  wire [63:0] n449;
  wire [63:0] n450;
  wire n451;
  wire n452;
  wire n453;
  wire n454;
  wire n455;
  wire n473;
  wire [14:0] n476;
  wire [63:0] n478;
  wire [79:0] n479;
  wire [14:0] n480;
  wire n482;
  wire n483;
  wire n484;
  wire n485;
  wire [62:0] n486;
  wire n488;
  wire n489;
  wire n501;
  wire [14:0] n504;
  wire [63:0] n506;
  wire [79:0] n507;
  wire [14:0] n508;
  wire n510;
  wire n511;
  wire n512;
  wire n513;
  wire [62:0] n514;
  wire n516;
  wire n517;
  wire n519;
  wire n522;
  wire n524;
  wire [79:0] n525;
  wire [79:0] n526;
  wire [79:0] n527;
  wire [79:0] n528;
  wire [15:0] n531;
  wire [62:0] n532;
  wire [79:0] n533;
  wire [80:0] n534;
  wire [79:0] n536;
  wire n548;
  wire [14:0] n551;
  wire [63:0] n553;
  wire [79:0] n554;
  localparam [63:0] n557 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n558;
  wire [14:0] n559;
  wire n561;
  wire [63:0] n562;
  wire n564;
  wire [63:0] n565;
  wire [63:0] n566;
  wire n567;
  wire n568;
  wire n569;
  wire n581;
  wire [14:0] n584;
  wire [63:0] n586;
  wire [79:0] n587;
  localparam [63:0] n590 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  wire [62:0] n591;
  wire [14:0] n592;
  wire n594;
  wire [63:0] n595;
  wire n597;
  wire [63:0] n598;
  wire [63:0] n599;
  wire n600;
  wire n601;
  wire n602;
  wire n603;
  wire n615;
  wire [14:0] n618;
  wire [63:0] n620;
  wire [79:0] n621;
  wire [14:0] n622;
  wire n624;
  wire [63:0] n625;
  wire n627;
  wire n628;
  wire n640;
  wire [14:0] n643;
  wire [63:0] n645;
  wire [79:0] n646;
  wire [14:0] n647;
  wire n649;
  wire [63:0] n650;
  wire n652;
  wire n653;
  wire n654;
  wire n658;
  wire n659;
  wire n660;
  wire [79:0] n663;
  wire [79:0] n664;
  wire [79:0] n665;
  wire n677;
  wire [14:0] n680;
  wire [63:0] n682;
  wire [79:0] n683;
  wire [14:0] n684;
  wire n686;
  wire [63:0] n687;
  wire n689;
  wire n690;
  wire n702;
  wire [14:0] n705;
  wire [63:0] n707;
  wire [79:0] n708;
  wire [14:0] n709;
  wire n711;
  wire [63:0] n712;
  wire n714;
  wire n715;
  wire n716;
  wire n719;
  wire [79:0] n721;
  wire n723;
  wire [79:0] n724;
  wire n726;
  wire [79:0] n728;
  wire [31:0] n729;
  wire [31:0] n731;
  wire [17:0] n732;
  wire n734;
  wire [127:0] n735;
  wire [127:0] n736;
  wire [127:0] n737;
  wire [1:0] n740;
  wire [127:0] n741;
  wire n744;
  wire [79:0] n745;
  wire n747;
  wire [31:0] n748;
  wire n749;
  wire [31:0] n751;
  wire [31:0] n754;
  wire [31:0] n755;
  wire [6:0] n758;
  wire [6:0] n760;
  wire [66:0] n762;
  wire [31:0] n764;
  wire n766;
  wire n768;
  wire n769;
  wire n770;
  wire n773;
  wire n775;
  wire n776;
  wire n777;
  wire n779;
  wire n781;
  wire n782;
  wire n783;
  wire n785;
  wire n787;
  wire n788;
  wire n789;
  wire n791;
  wire n793;
  wire n794;
  wire n795;
  wire n797;
  wire n799;
  wire n800;
  wire n801;
  wire n803;
  wire n805;
  wire n806;
  wire n807;
  wire n809;
  wire n811;
  wire n812;
  wire n813;
  wire n815;
  wire n817;
  wire n818;
  wire n819;
  wire n821;
  wire n823;
  wire n824;
  wire n825;
  wire n827;
  wire n829;
  wire n830;
  wire n831;
  wire n833;
  wire n835;
  wire n836;
  wire n837;
  wire n839;
  wire n841;
  wire n842;
  wire n843;
  wire n845;
  wire n847;
  wire n848;
  wire n849;
  wire n851;
  wire n853;
  wire n854;
  wire n855;
  wire n857;
  wire n859;
  wire n860;
  wire n861;
  wire n863;
  wire n865;
  wire n866;
  wire n867;
  wire n869;
  wire n871;
  wire n872;
  wire n873;
  wire n875;
  wire n877;
  wire n878;
  wire n879;
  wire n881;
  wire n883;
  wire n884;
  wire n885;
  wire n887;
  wire n889;
  wire n890;
  wire n891;
  wire n893;
  wire n895;
  wire n896;
  wire n897;
  wire n899;
  wire n901;
  wire n902;
  wire n903;
  wire n905;
  wire n907;
  wire n908;
  wire n909;
  wire n911;
  wire n913;
  wire n914;
  wire n915;
  wire n917;
  wire n919;
  wire n920;
  wire n921;
  wire n923;
  wire n925;
  wire n926;
  wire n927;
  wire n929;
  wire n931;
  wire n932;
  wire n933;
  wire n935;
  wire n937;
  wire n938;
  wire n939;
  wire n941;
  wire n943;
  wire n944;
  wire n945;
  wire n947;
  wire n949;
  wire n950;
  wire n951;
  wire n953;
  wire n955;
  wire n956;
  wire n957;
  wire n959;
  wire n961;
  wire n962;
  wire n963;
  wire n965;
  wire n967;
  wire n968;
  wire n969;
  wire n971;
  wire n973;
  wire n974;
  wire n975;
  wire n977;
  wire n979;
  wire n980;
  wire n981;
  wire n983;
  wire n985;
  wire n986;
  wire n987;
  wire n989;
  wire n991;
  wire n992;
  wire n993;
  wire n995;
  wire n997;
  wire n998;
  wire n999;
  wire n1001;
  wire n1003;
  wire n1004;
  wire n1005;
  wire n1007;
  wire n1009;
  wire n1010;
  wire n1011;
  wire n1013;
  wire n1015;
  wire n1016;
  wire n1017;
  wire n1019;
  wire n1021;
  wire n1022;
  wire n1023;
  wire n1025;
  wire n1027;
  wire n1028;
  wire n1029;
  wire n1031;
  wire n1033;
  wire n1034;
  wire n1035;
  wire n1037;
  wire n1039;
  wire n1040;
  wire n1041;
  wire n1043;
  wire n1045;
  wire n1046;
  wire n1047;
  wire n1049;
  wire n1051;
  wire n1052;
  wire n1053;
  wire n1055;
  wire n1057;
  wire n1058;
  wire n1059;
  wire n1061;
  wire n1063;
  wire n1064;
  wire n1065;
  wire n1067;
  wire n1069;
  wire n1070;
  wire n1071;
  wire n1073;
  wire n1075;
  wire n1076;
  wire n1077;
  wire n1079;
  wire n1081;
  wire n1082;
  wire n1083;
  wire n1085;
  wire n1087;
  wire n1088;
  wire n1089;
  wire n1091;
  wire n1093;
  wire n1094;
  wire n1095;
  wire n1097;
  wire n1099;
  wire n1100;
  wire n1101;
  wire n1103;
  wire n1105;
  wire n1106;
  wire n1107;
  wire n1109;
  wire n1111;
  wire n1112;
  wire n1113;
  wire n1115;
  wire n1117;
  wire n1118;
  wire n1119;
  wire n1121;
  wire n1123;
  wire n1124;
  wire n1125;
  wire n1127;
  wire n1129;
  wire n1130;
  wire n1131;
  wire n1133;
  wire n1135;
  wire n1136;
  wire n1137;
  wire n1139;
  wire n1141;
  wire n1142;
  wire n1143;
  wire n1145;
  wire n1147;
  wire n1148;
  wire n1149;
  wire n1151;
  wire n1153;
  wire n1154;
  wire n1155;
  wire n1157;
  wire n1159;
  wire n1160;
  wire n1161;
  wire n1163;
  wire n1165;
  wire n1166;
  wire n1167;
  wire n1169;
  wire n1171;
  wire n1172;
  wire n1173;
  wire n1175;
  wire n1177;
  wire n1178;
  wire n1179;
  wire n1181;
  wire n1183;
  wire n1184;
  wire n1185;
  wire n1187;
  wire n1189;
  wire n1190;
  wire n1191;
  wire n1193;
  wire n1195;
  wire n1196;
  wire n1197;
  wire n1199;
  wire n1201;
  wire n1202;
  wire n1203;
  wire n1205;
  wire n1207;
  wire n1208;
  wire n1209;
  wire n1211;
  wire n1213;
  wire n1214;
  wire n1215;
  wire n1217;
  wire n1219;
  wire n1220;
  wire n1221;
  wire n1223;
  wire n1225;
  wire n1226;
  wire n1227;
  wire n1229;
  wire n1231;
  wire n1232;
  wire n1233;
  wire n1235;
  wire n1237;
  wire n1238;
  wire n1239;
  wire n1241;
  wire n1243;
  wire n1244;
  wire n1245;
  wire n1247;
  wire n1249;
  wire n1250;
  wire n1251;
  wire n1253;
  wire n1255;
  wire n1256;
  wire n1257;
  wire n1259;
  wire n1261;
  wire n1262;
  wire n1263;
  wire n1265;
  wire n1267;
  wire n1268;
  wire n1269;
  wire n1271;
  wire n1273;
  wire n1274;
  wire n1275;
  wire n1277;
  wire n1279;
  wire n1280;
  wire n1281;
  wire n1283;
  wire n1285;
  wire n1286;
  wire n1287;
  wire n1289;
  wire n1291;
  wire n1292;
  wire n1293;
  wire n1295;
  wire n1297;
  wire n1298;
  wire n1299;
  wire n1301;
  wire n1303;
  wire n1304;
  wire n1305;
  wire n1307;
  wire n1309;
  wire n1310;
  wire n1311;
  wire n1313;
  wire n1315;
  wire n1316;
  wire n1317;
  wire n1319;
  wire n1321;
  wire n1322;
  wire n1323;
  wire n1325;
  wire n1327;
  wire n1328;
  wire n1329;
  wire n1331;
  wire n1333;
  wire n1334;
  wire n1335;
  wire n1337;
  wire n1339;
  wire n1340;
  wire n1341;
  wire n1343;
  wire n1345;
  wire n1346;
  wire n1347;
  wire n1349;
  wire n1351;
  wire n1352;
  wire n1353;
  wire n1355;
  wire n1357;
  wire n1358;
  wire n1359;
  wire n1361;
  wire n1363;
  wire n1364;
  wire n1365;
  wire n1367;
  wire n1369;
  wire n1370;
  wire n1371;
  wire n1373;
  wire n1375;
  wire n1376;
  wire n1377;
  wire n1379;
  wire n1381;
  wire n1382;
  wire n1383;
  wire n1385;
  wire n1387;
  wire n1388;
  wire n1389;
  wire n1391;
  wire n1393;
  wire n1394;
  wire n1395;
  wire n1397;
  wire n1399;
  wire n1400;
  wire n1401;
  wire n1403;
  wire n1405;
  wire n1406;
  wire n1407;
  wire n1409;
  wire n1411;
  wire n1412;
  wire n1413;
  wire n1415;
  wire n1417;
  wire n1418;
  wire n1419;
  wire n1421;
  wire n1423;
  wire n1424;
  wire n1425;
  wire n1427;
  wire n1429;
  wire n1430;
  wire n1431;
  wire n1433;
  wire n1435;
  wire n1436;
  wire n1437;
  wire n1439;
  wire n1441;
  wire n1442;
  wire n1443;
  wire n1445;
  wire n1447;
  wire n1448;
  wire n1449;
  wire n1451;
  wire n1453;
  wire n1454;
  wire n1455;
  wire n1457;
  wire n1459;
  wire n1460;
  wire n1461;
  wire n1463;
  wire n1465;
  wire n1466;
  wire n1467;
  wire n1469;
  wire n1471;
  wire n1472;
  wire n1473;
  wire n1475;
  wire n1477;
  wire n1478;
  wire n1479;
  wire n1481;
  wire n1483;
  wire n1484;
  wire n1485;
  wire n1487;
  wire n1489;
  wire n1490;
  wire n1491;
  wire n1493;
  wire n1495;
  wire n1496;
  wire n1497;
  wire n1499;
  wire n1501;
  wire n1502;
  wire n1503;
  wire n1505;
  wire n1507;
  wire n1508;
  wire n1509;
  wire n1511;
  wire n1513;
  wire n1514;
  wire n1515;
  wire n1517;
  wire n1519;
  wire n1520;
  wire n1521;
  wire n1523;
  wire n1525;
  wire n1526;
  wire n1527;
  wire n1529;
  wire n1531;
  wire n1532;
  wire n1533;
  wire n1535;
  wire n1537;
  wire n1539;
  wire n1540;
  wire [65:0] n1541;
  wire [66:0] n1542;
  wire [63:0] n1543;
  wire [66:0] n1544;
  wire n1545;
  wire [66:0] n1546;
  wire n1547;
  wire [66:0] n1548;
  wire [40:0] n1549;
  wire n1551;
  wire n1554;
  wire n1556;
  wire [66:0] n1557;
  wire n1558;
  wire [66:0] n1559;
  wire n1560;
  wire [66:0] n1561;
  wire [11:0] n1562;
  wire n1564;
  wire n1567;
  wire n1569;
  wire [66:0] n1570;
  wire n1571;
  wire [66:0] n1572;
  wire n1573;
  wire [66:0] n1574;
  wire n1575;
  wire n1578;
  wire [1:0] n1579;
  reg n1580;
  reg n1581;
  reg n1582;
  wire n1584;
  wire n1585;
  wire n1586;
  wire n1587;
  wire n1588;
  wire n1589;
  wire n1592;
  wire n1594;
  wire n1595;
  wire n1596;
  wire n1597;
  wire n1598;
  wire n1601;
  wire n1603;
  wire n1604;
  wire n1605;
  wire n1606;
  wire n1607;
  wire n1610;
  wire [1:0] n1611;
  reg n1612;
  wire n1614;
  wire n1616;
  wire n1617;
  wire n1620;
  wire n1622;
  wire n1623;
  wire n1624;
  wire n1627;
  wire n1629;
  wire [3:0] n1630;
  reg n1633;
  wire [64:0] n1636;
  wire [64:0] n1638;
  wire n1640;
  wire [64:0] n1642;
  wire [64:0] n1644;
  wire n1646;
  wire [64:0] n1648;
  wire [64:0] n1650;
  wire [1:0] n1651;
  reg [64:0] n1652;
  wire n1653;
  wire [63:0] n1654;
  wire [63:0] n1656;
  wire n1657;
  wire n1659;
  wire n1660;
  wire [61:0] n1663;
  wire [31:0] n1665;
  wire [63:0] n1666;
  wire [63:0] n1667;
  wire [63:0] n1668;
  wire [31:0] n1669;
  wire [63:0] n1670;
  wire n1672;
  localparam [39:0] n1673 = 40'b0000000000000000000000000000000000000000;
  wire n1675;
  wire n1678;
  wire [1:0] n1679;
  wire [10:0] n1680;
  wire [10:0] n1681;
  reg [10:0] n1682;
  wire [28:0] n1683;
  wire [28:0] n1684;
  reg [28:0] n1685;
  wire [23:0] n1687;
  wire n1689;
  wire [31:0] n1691;
  wire [30:0] n1692;
  wire [31:0] n1693;
  wire n1695;
  wire [63:0] n1696;
  wire n1698;
  wire n1699;
  wire [63:0] n1701;
  wire [63:0] n1702;
  wire [79:0] n1703;
  wire [79:0] n1705;
  wire n1707;
  wire [30:0] n1710;
  wire [14:0] n1711;
  wire [63:0] n1712;
  wire [79:0] n1713;
  wire [79:0] n1714;
  wire [79:0] n1715;
  wire [79:0] n1717;
  wire n1721;
  wire [3:0] n1722;
  reg [1:0] n1726;
  reg [79:0] n1728;
  reg [79:0] n1730;
  reg [1:0] n1732;
  reg [1:0] n1734;
  reg [63:0] n1736;
  reg [63:0] n1738;
  reg n1740;
  reg [17:0] n1742;
  reg n1744;
  reg [79:0] n1746;
  reg [127:0] n1748;
  reg n1752;
  reg [79:0] n1755;
  wire [1:0] n1806;
  wire [79:0] n1808;
  wire [79:0] n1810;
  wire [1:0] n1812;
  wire [1:0] n1814;
  wire [63:0] n1816;
  wire [63:0] n1818;
  wire n1820;
  wire [17:0] n1822;
  wire n1824;
  wire [79:0] n1826;
  wire [127:0] n1828;
  wire n1830;
  wire [79:0] n1832;
  wire n1909;
  wire n1910;
  reg [1:0] n1912;
  reg [79:0] n1913;
  reg [79:0] n1914;
  reg [1:0] n1915;
  reg [1:0] n1916;
  reg [63:0] n1917;
  reg [63:0] n1918;
  reg n1919;
  reg [17:0] n1920;
  reg n1921;
  reg [79:0] n1922;
  reg [127:0] n1923;
  reg n1924;
  reg [79:0] n1925;
  assign busy = n1910; //(module output)
  assign done = done_reg; //(module output)
  assign result = result_reg; //(module output)
  /* mc68881_fp80_mul_unit.vhd:42:10  */
  always @*
    state_reg = n1912; // (isignal)
  initial
    state_reg = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:45:10  */
  always @*
    a_reg = n1913; // (isignal)
  initial
    a_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:46:10  */
  always @*
    b_reg = n1914; // (isignal)
  initial
    b_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:47:10  */
  always @*
    rm_reg = n1915; // (isignal)
  initial
    rm_reg = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:48:10  */
  always @*
    rp_reg = n1916; // (isignal)
  initial
    rp_reg = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:51:10  */
  always @*
    a_mant_reg = n1917; // (isignal)
  initial
    a_mant_reg = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:52:10  */
  always @*
    b_mant_reg = n1918; // (isignal)
  initial
    b_mant_reg = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:55:10  */
  always @*
    res_sign_reg = n1919; // (isignal)
  initial
    res_sign_reg = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:56:10  */
  always @*
    exp_res_reg = n1920; // (isignal)
  initial
    exp_res_reg = 18'b000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:57:10  */
  always @*
    early_exit_reg = n1921; // (isignal)
  initial
    early_exit_reg = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:58:10  */
  always @*
    early_result_reg = n1922; // (isignal)
  initial
    early_result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:61:10  */
  always @*
    mant_prod_reg = n1923; // (isignal)
  initial
    mant_prod_reg = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:64:10  */
  always @*
    done_reg = n1924; // (isignal)
  initial
    done_reg = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:65:10  */
  always @*
    result_reg = n1925; // (isignal)
  initial
    result_reg = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:97:16  */
  assign n40 = ~reset_n;
  /* mc68881_fp80_mul_unit.vhd:117:11  */
  assign n42 = start ? 2'b01 : state_reg;
  /* mc68881_fp80_mul_unit.vhd:117:11  */
  assign n43 = start ? a_in : a_reg;
  /* mc68881_fp80_mul_unit.vhd:117:11  */
  assign n44 = start ? b_in : b_reg;
  /* mc68881_fp80_mul_unit.vhd:117:11  */
  assign n45 = start ? round_mode : rm_reg;
  /* mc68881_fp80_mul_unit.vhd:117:11  */
  assign n46 = start ? round_prec : rp_reg;
  /* mc68881_fp80_mul_unit.vhd:116:9  */
  assign n48 = state_reg == 2'b00;
  /* mc68881_fp80_mul_unit.vhd:127:37  */
  assign n49 = a_reg[63:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:128:37  */
  assign n50 = b_reg[63:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:131:28  */
  assign n51 = a_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:131:73  */
  assign n53 = n51 == 15'b000000000000000;
  /* mc68881_fp80_mul_unit.vhd:131:90  */
  assign n55 = n49 != 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:131:77  */
  assign n56 = n55 & n53;
  /* mc68881_pkg.vhd:2499:9  */
  assign n63 = a_reg[63:32]; // extract
  /* mc68881_pkg.vhd:2499:37  */
  assign n65 = n63 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2501:13  */
  assign n66 = a_reg[31:0]; // extract
  /* mc68881_pkg.vhd:2501:36  */
  assign n68 = {n66, 32'b00000000000000000000000000000000};
  /* mc68881_pkg.vhd:2499:5  */
  assign n71 = n65 ? 31'b0000000000000000000000000100000 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:2499:5  */
  assign n73 = n65 ? n68 : n49;
  /* mc68881_pkg.vhd:2503:9  */
  assign n74 = n73[63:48]; // extract
  /* mc68881_pkg.vhd:2503:37  */
  assign n76 = n74 == 16'b0000000000000000;
  /* mc68881_pkg.vhd:2504:18  */
  assign n77 = {1'b0, n71};  //  uext
  /* mc68881_pkg.vhd:2504:18  */
  assign n79 = n77 + 32'b00000000000000000000000000010000;
  /* mc68881_pkg.vhd:2504:7  */
  assign n80 = n79[30:0];  // trunc
  /* mc68881_pkg.vhd:2505:13  */
  assign n81 = n73[47:0]; // extract
  /* mc68881_pkg.vhd:2505:36  */
  assign n83 = {n81, 16'b0000000000000000};
  /* mc68881_pkg.vhd:2503:5  */
  assign n84 = n76 ? n80 : n71;
  /* mc68881_pkg.vhd:2503:5  */
  assign n85 = n76 ? n83 : n73;
  /* mc68881_pkg.vhd:2507:9  */
  assign n86 = n85[63:56]; // extract
  /* mc68881_pkg.vhd:2507:36  */
  assign n88 = n86 == 8'b00000000;
  /* mc68881_pkg.vhd:2508:18  */
  assign n89 = {1'b0, n84};  //  uext
  /* mc68881_pkg.vhd:2508:18  */
  assign n91 = n89 + 32'b00000000000000000000000000001000;
  /* mc68881_pkg.vhd:2508:7  */
  assign n92 = n91[30:0];  // trunc
  /* mc68881_pkg.vhd:2509:13  */
  assign n93 = n85[55:0]; // extract
  /* mc68881_pkg.vhd:2509:35  */
  assign n95 = {n93, 8'b00000000};
  /* mc68881_pkg.vhd:2507:5  */
  assign n96 = n88 ? n92 : n84;
  /* mc68881_pkg.vhd:2507:5  */
  assign n97 = n88 ? n95 : n85;
  /* mc68881_pkg.vhd:2511:9  */
  assign n98 = n97[63:60]; // extract
  /* mc68881_pkg.vhd:2511:36  */
  assign n100 = n98 == 4'b0000;
  /* mc68881_pkg.vhd:2512:18  */
  assign n101 = {1'b0, n96};  //  uext
  /* mc68881_pkg.vhd:2512:18  */
  assign n103 = n101 + 32'b00000000000000000000000000000100;
  /* mc68881_pkg.vhd:2512:7  */
  assign n104 = n103[30:0];  // trunc
  /* mc68881_pkg.vhd:2513:13  */
  assign n105 = n97[59:0]; // extract
  /* mc68881_pkg.vhd:2513:35  */
  assign n107 = {n105, 4'b0000};
  /* mc68881_pkg.vhd:2511:5  */
  assign n108 = n100 ? n104 : n96;
  /* mc68881_pkg.vhd:2511:5  */
  assign n109 = n100 ? n107 : n97;
  /* mc68881_pkg.vhd:2515:9  */
  assign n110 = n109[63:62]; // extract
  /* mc68881_pkg.vhd:2515:36  */
  assign n112 = n110 == 2'b00;
  /* mc68881_pkg.vhd:2516:18  */
  assign n113 = {1'b0, n108};  //  uext
  /* mc68881_pkg.vhd:2516:18  */
  assign n115 = n113 + 32'b00000000000000000000000000000010;
  /* mc68881_pkg.vhd:2516:7  */
  assign n116 = n115[30:0];  // trunc
  /* mc68881_pkg.vhd:2517:13  */
  assign n117 = n109[61:0]; // extract
  /* mc68881_pkg.vhd:2517:35  */
  assign n119 = {n117, 2'b00};
  /* mc68881_pkg.vhd:2515:5  */
  assign n120 = n112 ? n116 : n108;
  /* mc68881_pkg.vhd:2515:5  */
  assign n121 = n112 ? n119 : n109;
  /* mc68881_pkg.vhd:2519:9  */
  assign n122 = n121[63]; // extract
  /* mc68881_pkg.vhd:2519:18  */
  assign n123 = ~n122;
  /* mc68881_pkg.vhd:2520:18  */
  assign n124 = {1'b0, n120};  //  uext
  /* mc68881_pkg.vhd:2520:18  */
  assign n126 = n124 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:2520:7  */
  assign n127 = n126[30:0];  // trunc
  /* mc68881_pkg.vhd:2519:5  */
  assign n128 = n123 ? n127 : n120;
  /* mc68881_fp80_mul_unit.vhd:133:25  */
  assign n129 = n49 << n128;
  /* mc68881_fp80_mul_unit.vhd:134:28  */
  assign n130 = {1'b0, n128};  //  uext
  /* mc68881_fp80_mul_unit.vhd:134:28  */
  assign n132 = 32'b00000000000000000000000000000001 - n130;
  /* mc68881_fp80_mul_unit.vhd:136:51  */
  assign n133 = a_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:136:26  */
  assign n134 = {16'b0, n133};  //  uext
  /* mc68881_fp80_mul_unit.vhd:136:13  */
  assign n135 = {1'b0, n134};  //  uext
  /* mc68881_fp80_mul_unit.vhd:131:11  */
  assign n137 = n56 ? n132 : n135;
  /* mc68881_fp80_mul_unit.vhd:131:11  */
  assign n138 = n56 ? n129 : n49;
  /* mc68881_fp80_mul_unit.vhd:139:28  */
  assign n139 = b_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:139:73  */
  assign n141 = n139 == 15'b000000000000000;
  /* mc68881_fp80_mul_unit.vhd:139:90  */
  assign n143 = n50 != 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:139:77  */
  assign n144 = n143 & n141;
  /* mc68881_pkg.vhd:2499:9  */
  assign n151 = b_reg[63:32]; // extract
  /* mc68881_pkg.vhd:2499:37  */
  assign n153 = n151 == 32'b00000000000000000000000000000000;
  /* mc68881_pkg.vhd:2501:13  */
  assign n154 = b_reg[31:0]; // extract
  /* mc68881_pkg.vhd:2501:36  */
  assign n156 = {n154, 32'b00000000000000000000000000000000};
  /* mc68881_pkg.vhd:2499:5  */
  assign n159 = n153 ? 31'b0000000000000000000000000100000 : 31'b0000000000000000000000000000000;
  /* mc68881_pkg.vhd:2499:5  */
  assign n161 = n153 ? n156 : n50;
  /* mc68881_pkg.vhd:2503:9  */
  assign n162 = n161[63:48]; // extract
  /* mc68881_pkg.vhd:2503:37  */
  assign n164 = n162 == 16'b0000000000000000;
  /* mc68881_pkg.vhd:2504:18  */
  assign n165 = {1'b0, n159};  //  uext
  /* mc68881_pkg.vhd:2504:18  */
  assign n167 = n165 + 32'b00000000000000000000000000010000;
  /* mc68881_pkg.vhd:2504:7  */
  assign n168 = n167[30:0];  // trunc
  /* mc68881_pkg.vhd:2505:13  */
  assign n169 = n161[47:0]; // extract
  /* mc68881_pkg.vhd:2505:36  */
  assign n171 = {n169, 16'b0000000000000000};
  /* mc68881_pkg.vhd:2503:5  */
  assign n172 = n164 ? n168 : n159;
  /* mc68881_pkg.vhd:2503:5  */
  assign n173 = n164 ? n171 : n161;
  /* mc68881_pkg.vhd:2507:9  */
  assign n174 = n173[63:56]; // extract
  /* mc68881_pkg.vhd:2507:36  */
  assign n176 = n174 == 8'b00000000;
  /* mc68881_pkg.vhd:2508:18  */
  assign n177 = {1'b0, n172};  //  uext
  /* mc68881_pkg.vhd:2508:18  */
  assign n179 = n177 + 32'b00000000000000000000000000001000;
  /* mc68881_pkg.vhd:2508:7  */
  assign n180 = n179[30:0];  // trunc
  /* mc68881_pkg.vhd:2509:13  */
  assign n181 = n173[55:0]; // extract
  /* mc68881_pkg.vhd:2509:35  */
  assign n183 = {n181, 8'b00000000};
  /* mc68881_pkg.vhd:2507:5  */
  assign n184 = n176 ? n180 : n172;
  /* mc68881_pkg.vhd:2507:5  */
  assign n185 = n176 ? n183 : n173;
  /* mc68881_pkg.vhd:2511:9  */
  assign n186 = n185[63:60]; // extract
  /* mc68881_pkg.vhd:2511:36  */
  assign n188 = n186 == 4'b0000;
  /* mc68881_pkg.vhd:2512:18  */
  assign n189 = {1'b0, n184};  //  uext
  /* mc68881_pkg.vhd:2512:18  */
  assign n191 = n189 + 32'b00000000000000000000000000000100;
  /* mc68881_pkg.vhd:2512:7  */
  assign n192 = n191[30:0];  // trunc
  /* mc68881_pkg.vhd:2513:13  */
  assign n193 = n185[59:0]; // extract
  /* mc68881_pkg.vhd:2513:35  */
  assign n195 = {n193, 4'b0000};
  /* mc68881_pkg.vhd:2511:5  */
  assign n196 = n188 ? n192 : n184;
  /* mc68881_pkg.vhd:2511:5  */
  assign n197 = n188 ? n195 : n185;
  /* mc68881_pkg.vhd:2515:9  */
  assign n198 = n197[63:62]; // extract
  /* mc68881_pkg.vhd:2515:36  */
  assign n200 = n198 == 2'b00;
  /* mc68881_pkg.vhd:2516:18  */
  assign n201 = {1'b0, n196};  //  uext
  /* mc68881_pkg.vhd:2516:18  */
  assign n203 = n201 + 32'b00000000000000000000000000000010;
  /* mc68881_pkg.vhd:2516:7  */
  assign n204 = n203[30:0];  // trunc
  /* mc68881_pkg.vhd:2517:13  */
  assign n205 = n197[61:0]; // extract
  /* mc68881_pkg.vhd:2517:35  */
  assign n207 = {n205, 2'b00};
  /* mc68881_pkg.vhd:2515:5  */
  assign n208 = n200 ? n204 : n196;
  /* mc68881_pkg.vhd:2515:5  */
  assign n209 = n200 ? n207 : n197;
  /* mc68881_pkg.vhd:2519:9  */
  assign n210 = n209[63]; // extract
  /* mc68881_pkg.vhd:2519:18  */
  assign n211 = ~n210;
  /* mc68881_pkg.vhd:2520:18  */
  assign n212 = {1'b0, n208};  //  uext
  /* mc68881_pkg.vhd:2520:18  */
  assign n214 = n212 + 32'b00000000000000000000000000000001;
  /* mc68881_pkg.vhd:2520:7  */
  assign n215 = n214[30:0];  // trunc
  /* mc68881_pkg.vhd:2519:5  */
  assign n216 = n211 ? n215 : n208;
  /* mc68881_fp80_mul_unit.vhd:141:25  */
  assign n217 = n50 << n216;
  /* mc68881_fp80_mul_unit.vhd:142:28  */
  assign n218 = {1'b0, n216};  //  uext
  /* mc68881_fp80_mul_unit.vhd:142:28  */
  assign n220 = 32'b00000000000000000000000000000001 - n218;
  /* mc68881_fp80_mul_unit.vhd:144:51  */
  assign n221 = b_reg[78:64]; // extract
  /* mc68881_fp80_mul_unit.vhd:144:26  */
  assign n222 = {16'b0, n221};  //  uext
  /* mc68881_fp80_mul_unit.vhd:144:13  */
  assign n223 = {1'b0, n222};  //  uext
  /* mc68881_fp80_mul_unit.vhd:139:11  */
  assign n225 = n144 ? n220 : n223;
  /* mc68881_fp80_mul_unit.vhd:139:11  */
  assign n226 = n144 ? n217 : n50;
  /* mc68881_fp80_mul_unit.vhd:151:32  */
  assign n227 = a_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:151:54  */
  assign n228 = b_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:151:45  */
  assign n229 = n227 ^ n228;
  /* mc68881_pkg.vhd:1535:25  */
  assign n241 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n244 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n246 = a_reg[63:0]; // extract
  assign n247 = {n246, n244, n241};
  /* mc68881_pkg.vhd:2098:20  */
  assign n248 = n247[15:1]; // extract
  /* mc68881_pkg.vhd:2098:24  */
  assign n250 = n248 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1535:25  */
  assign n262 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n265 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n267 = a_reg[63:0]; // extract
  assign n268 = {n267, n265, n262};
  assign n272 = n271[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n273 = n268[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n275 = n273 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n276 = n268[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n278 = n276 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n279 = n268[79:16]; // extract
  assign n280 = {1'b1, n272};
  /* mc68881_pkg.vhd:2092:41  */
  assign n281 = n279 == n280;
  /* mc68881_pkg.vhd:2092:25  */
  assign n282 = n278 | n281;
  /* mc68881_pkg.vhd:2091:42  */
  assign n283 = n282 & n275;
  /* mc68881_pkg.vhd:2098:46  */
  assign n284 = ~n283;
  /* mc68881_pkg.vhd:2098:42  */
  assign n285 = n284 & n250;
  /* mc68881_pkg.vhd:1535:25  */
  assign n297 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n300 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n302 = b_reg[63:0]; // extract
  assign n303 = {n302, n300, n297};
  /* mc68881_pkg.vhd:2098:20  */
  assign n304 = n303[15:1]; // extract
  /* mc68881_pkg.vhd:2098:24  */
  assign n306 = n304 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1535:25  */
  assign n318 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n321 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n323 = b_reg[63:0]; // extract
  assign n324 = {n323, n321, n318};
  assign n328 = n327[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n329 = n324[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n331 = n329 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n332 = n324[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n334 = n332 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n335 = n324[79:16]; // extract
  assign n336 = {1'b1, n328};
  /* mc68881_pkg.vhd:2092:41  */
  assign n337 = n335 == n336;
  /* mc68881_pkg.vhd:2092:25  */
  assign n338 = n334 | n337;
  /* mc68881_pkg.vhd:2091:42  */
  assign n339 = n338 & n331;
  /* mc68881_pkg.vhd:2098:46  */
  assign n340 = ~n339;
  /* mc68881_pkg.vhd:2098:42  */
  assign n341 = n340 & n306;
  /* mc68881_fp80_mul_unit.vhd:156:33  */
  assign n342 = n285 | n341;
  /* mc68881_pkg.vhd:1535:25  */
  assign n355 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n358 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n360 = a_reg[63:0]; // extract
  assign n361 = {n360, n358, n355};
  /* mc68881_pkg.vhd:2098:20  */
  assign n362 = n361[15:1]; // extract
  /* mc68881_pkg.vhd:2098:24  */
  assign n364 = n362 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1535:25  */
  assign n376 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n379 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n381 = a_reg[63:0]; // extract
  assign n382 = {n381, n379, n376};
  assign n386 = n385[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n387 = n382[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n389 = n387 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n390 = n382[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n392 = n390 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n393 = n382[79:16]; // extract
  assign n394 = {1'b1, n386};
  /* mc68881_pkg.vhd:2092:41  */
  assign n395 = n393 == n394;
  /* mc68881_pkg.vhd:2092:25  */
  assign n396 = n392 | n395;
  /* mc68881_pkg.vhd:2091:42  */
  assign n397 = n396 & n389;
  /* mc68881_pkg.vhd:2098:46  */
  assign n398 = ~n397;
  /* mc68881_pkg.vhd:2098:42  */
  assign n399 = n398 & n364;
  /* mc68881_pkg.vhd:1535:25  */
  assign n411 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n414 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n416 = b_reg[63:0]; // extract
  assign n417 = {n416, n414, n411};
  /* mc68881_pkg.vhd:2098:20  */
  assign n418 = n417[15:1]; // extract
  /* mc68881_pkg.vhd:2098:24  */
  assign n420 = n418 == 15'b111111111111111;
  /* mc68881_pkg.vhd:1535:25  */
  assign n432 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n435 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n437 = b_reg[63:0]; // extract
  assign n438 = {n437, n435, n432};
  assign n442 = n441[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n443 = n438[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n445 = n443 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n446 = n438[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n448 = n446 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n449 = n438[79:16]; // extract
  assign n450 = {1'b1, n442};
  /* mc68881_pkg.vhd:2092:41  */
  assign n451 = n449 == n450;
  /* mc68881_pkg.vhd:2092:25  */
  assign n452 = n448 | n451;
  /* mc68881_pkg.vhd:2091:42  */
  assign n453 = n452 & n445;
  /* mc68881_pkg.vhd:2098:46  */
  assign n454 = ~n453;
  /* mc68881_pkg.vhd:2098:42  */
  assign n455 = n454 & n420;
  /* mc68881_pkg.vhd:1535:25  */
  assign n473 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n476 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n478 = a_reg[63:0]; // extract
  assign n479 = {n478, n476, n473};
  /* mc68881_pkg.vhd:2105:20  */
  assign n480 = n479[15:1]; // extract
  /* mc68881_pkg.vhd:2105:24  */
  assign n482 = n480 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2106:24  */
  assign n483 = n479[79]; // extract
  /* mc68881_pkg.vhd:2106:42  */
  assign n484 = ~n483;
  /* mc68881_pkg.vhd:2105:42  */
  assign n485 = n484 & n482;
  /* mc68881_pkg.vhd:2107:24  */
  assign n486 = n479[78:16]; // extract
  /* mc68881_pkg.vhd:2107:51  */
  assign n488 = n486 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2106:48  */
  assign n489 = n488 & n485;
  /* mc68881_pkg.vhd:1535:25  */
  assign n501 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n504 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n506 = b_reg[63:0]; // extract
  assign n507 = {n506, n504, n501};
  /* mc68881_pkg.vhd:2105:20  */
  assign n508 = n507[15:1]; // extract
  /* mc68881_pkg.vhd:2105:24  */
  assign n510 = n508 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2106:24  */
  assign n511 = n507[79]; // extract
  /* mc68881_pkg.vhd:2106:42  */
  assign n512 = ~n511;
  /* mc68881_pkg.vhd:2105:42  */
  assign n513 = n512 & n510;
  /* mc68881_pkg.vhd:2107:24  */
  assign n514 = n507[78:16]; // extract
  /* mc68881_pkg.vhd:2107:51  */
  assign n516 = n514 != 63'b000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2106:48  */
  assign n517 = n516 & n513;
  /* mc68881_pkg.vhd:2144:18  */
  assign n519 = n489 | n517;
  /* mc68881_pkg.vhd:2144:5  */
  assign n522 = n519 ? 1'b1 : 1'b0;
  /* mc68881_pkg.vhd:2148:14  */
  assign n524 = n455 & n399;
  /* mc68881_pkg.vhd:2152:7  */
  assign n525 = n517 ? b_reg : a_reg;
  /* mc68881_pkg.vhd:2150:7  */
  assign n526 = n489 ? a_reg : n525;
  /* mc68881_pkg.vhd:2157:5  */
  assign n527 = n399 ? a_reg : b_reg;
  /* mc68881_pkg.vhd:2148:5  */
  assign n528 = n524 ? n526 : n527;
  assign n531 = n528[79:64]; // extract
  assign n532 = n528[62:0]; // extract
  assign n533 = {n531, 1'b1, n532};
  /* mc68881_pkg.vhd:2166:23  */
  assign n534 = {n522, n533};
  /* mc68881_fp80_mul_unit.vhd:160:68  */
  assign n536 = n534[79:0]; // extract
  /* mc68881_pkg.vhd:1535:25  */
  assign n548 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n551 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n553 = a_reg[63:0]; // extract
  assign n554 = {n553, n551, n548};
  assign n558 = n557[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n559 = n554[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n561 = n559 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n562 = n554[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n564 = n562 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n565 = n554[79:16]; // extract
  assign n566 = {1'b1, n558};
  /* mc68881_pkg.vhd:2092:41  */
  assign n567 = n565 == n566;
  /* mc68881_pkg.vhd:2092:25  */
  assign n568 = n564 | n567;
  /* mc68881_pkg.vhd:2091:42  */
  assign n569 = n568 & n561;
  /* mc68881_pkg.vhd:1535:25  */
  assign n581 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n584 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n586 = b_reg[63:0]; // extract
  assign n587 = {n586, n584, n581};
  assign n591 = n590[62:0]; // extract
  /* mc68881_pkg.vhd:2091:20  */
  assign n592 = n587[15:1]; // extract
  /* mc68881_pkg.vhd:2091:24  */
  assign n594 = n592 == 15'b111111111111111;
  /* mc68881_pkg.vhd:2092:16  */
  assign n595 = n587[79:16]; // extract
  /* mc68881_pkg.vhd:2092:21  */
  assign n597 = n595 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2092:36  */
  assign n598 = n587[79:16]; // extract
  assign n599 = {1'b1, n591};
  /* mc68881_pkg.vhd:2092:41  */
  assign n600 = n598 == n599;
  /* mc68881_pkg.vhd:2092:25  */
  assign n601 = n597 | n600;
  /* mc68881_pkg.vhd:2091:42  */
  assign n602 = n601 & n594;
  /* mc68881_fp80_mul_unit.vhd:161:36  */
  assign n603 = n569 | n602;
  /* mc68881_pkg.vhd:1535:25  */
  assign n615 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n618 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n620 = a_reg[63:0]; // extract
  assign n621 = {n620, n618, n615};
  /* mc68881_pkg.vhd:2083:20  */
  assign n622 = n621[15:1]; // extract
  /* mc68881_pkg.vhd:2083:24  */
  assign n624 = n622 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2083:40  */
  assign n625 = n621[79:16]; // extract
  /* mc68881_pkg.vhd:2083:45  */
  assign n627 = n625 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2083:28  */
  assign n628 = n627 & n624;
  /* mc68881_pkg.vhd:1535:25  */
  assign n640 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n643 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n645 = b_reg[63:0]; // extract
  assign n646 = {n645, n643, n640};
  /* mc68881_pkg.vhd:2083:20  */
  assign n647 = n646[15:1]; // extract
  /* mc68881_pkg.vhd:2083:24  */
  assign n649 = n647 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2083:40  */
  assign n650 = n646[79:16]; // extract
  /* mc68881_pkg.vhd:2083:45  */
  assign n652 = n650 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2083:28  */
  assign n653 = n652 & n649;
  /* mc68881_fp80_mul_unit.vhd:163:36  */
  assign n654 = n628 | n653;
  /* mc68881_fp80_mul_unit.vhd:170:52  */
  assign n658 = a_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:170:74  */
  assign n659 = b_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:170:65  */
  assign n660 = n658 ^ n659;
  assign n663 = {n660, 15'b111111111111111, 64'b0000000000000000000000000000000000000000000000000000000000000000};
  assign n664 = {1'b0, 15'b111111111111111, 64'b1111111111111111111111111111111111111111111111111111111111111111};
  /* mc68881_fp80_mul_unit.vhd:163:13  */
  assign n665 = n654 ? n664 : n663;
  /* mc68881_pkg.vhd:1535:25  */
  assign n677 = a_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n680 = a_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n682 = a_reg[63:0]; // extract
  assign n683 = {n682, n680, n677};
  /* mc68881_pkg.vhd:2083:20  */
  assign n684 = n683[15:1]; // extract
  /* mc68881_pkg.vhd:2083:24  */
  assign n686 = n684 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2083:40  */
  assign n687 = n683[79:16]; // extract
  /* mc68881_pkg.vhd:2083:45  */
  assign n689 = n687 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2083:28  */
  assign n690 = n689 & n686;
  /* mc68881_pkg.vhd:1535:25  */
  assign n702 = b_reg[79]; // extract
  /* mc68881_pkg.vhd:1536:34  */
  assign n705 = b_reg[78:64]; // extract
  /* mc68881_pkg.vhd:1537:34  */
  assign n707 = b_reg[63:0]; // extract
  assign n708 = {n707, n705, n702};
  /* mc68881_pkg.vhd:2083:20  */
  assign n709 = n708[15:1]; // extract
  /* mc68881_pkg.vhd:2083:24  */
  assign n711 = n709 == 15'b000000000000000;
  /* mc68881_pkg.vhd:2083:40  */
  assign n712 = n708[79:16]; // extract
  /* mc68881_pkg.vhd:2083:45  */
  assign n714 = n712 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_pkg.vhd:2083:28  */
  assign n715 = n714 & n711;
  /* mc68881_fp80_mul_unit.vhd:174:37  */
  assign n716 = n690 | n715;
  /* mc68881_fp80_mul_unit.vhd:174:11  */
  assign n719 = n716 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:174:11  */
  assign n721 = n716 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : early_result_reg;
  /* mc68881_fp80_mul_unit.vhd:161:11  */
  assign n723 = n603 ? 1'b1 : n719;
  /* mc68881_fp80_mul_unit.vhd:161:11  */
  assign n724 = n603 ? n665 : n721;
  /* mc68881_fp80_mul_unit.vhd:156:11  */
  assign n726 = n342 ? 1'b1 : n723;
  /* mc68881_fp80_mul_unit.vhd:156:11  */
  assign n728 = n342 ? n536 : n724;
  /* mc68881_fp80_mul_unit.vhd:181:36  */
  assign n729 = n137 + n225;
  /* mc68881_fp80_mul_unit.vhd:181:48  */
  assign n731 = n729 - 32'b00000000000000000011111111111111;
  /* mc68881_fp80_mul_unit.vhd:181:26  */
  assign n732 = n731[17:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:125:9  */
  assign n734 = state_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:193:41  */
  assign n735 = {64'b0, a_mant_reg};  //  uext
  /* mc68881_fp80_mul_unit.vhd:193:41  */
  assign n736 = {64'b0, b_mant_reg};  //  uext
  /* mc68881_fp80_mul_unit.vhd:193:41  */
  assign n737 = n735 * n736; // umul
  /* mc68881_fp80_mul_unit.vhd:186:11  */
  assign n740 = early_exit_reg ? 2'b00 : 2'b11;
  /* mc68881_fp80_mul_unit.vhd:186:11  */
  assign n741 = early_exit_reg ? mant_prod_reg : n737;
  /* mc68881_fp80_mul_unit.vhd:186:11  */
  assign n744 = early_exit_reg ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:186:11  */
  assign n745 = early_exit_reg ? early_result_reg : result_reg;
  /* mc68881_fp80_mul_unit.vhd:185:9  */
  assign n747 = state_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:199:11  */
  assign n748 = {{14{exp_res_reg[17]}}, exp_res_reg}; // sext
  /* mc68881_fp80_mul_unit.vhd:200:27  */
  assign n749 = mant_prod_reg[127]; // extract
  /* mc68881_fp80_mul_unit.vhd:201:32  */
  assign n751 = n748 + 32'b00000000000000000000000000000001;
  /* mc68881_fp80_mul_unit.vhd:200:11  */
  assign n754 = n749 ? 32'b00000000000000000000000001111111 : 32'b00000000000000000000000001111110;
  /* mc68881_fp80_mul_unit.vhd:200:11  */
  assign n755 = n749 ? n751 : n748;
  /* mc68881_fp80_mul_unit.vhd:208:36  */
  assign n758 = n754[6:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:208:36  */
  assign n760 = n758 + 7'b0111110;
  /* mc68881_fp80_mul_unit.vhd:208:36  */
  assign n762 = mant_prod_reg[n760 + 0 +: 67]; //(dyn_extract)
  /* mc68881_fp80_mul_unit.vhd:211:29  */
  assign n764 = n754 - 32'b00000000000000000000000001000011;
  /* mc68881_fp80_mul_unit.vhd:213:21  */
  assign n766 = $signed(n764) >= $signed(32'b00000000000000000000000000000000);
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n768 = $signed(32'b00000000000000000000000000000000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n769 = mant_prod_reg[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n770 = n769 & n768;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n773 = n770 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n775 = $signed(32'b00000000000000000000000000000001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n776 = mant_prod_reg[1]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n777 = n776 & n775;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n779 = n777 ? 1'b1 : n773;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n781 = $signed(32'b00000000000000000000000000000010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n782 = mant_prod_reg[2]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n783 = n782 & n781;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n785 = n783 ? 1'b1 : n779;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n787 = $signed(32'b00000000000000000000000000000011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n788 = mant_prod_reg[3]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n789 = n788 & n787;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n791 = n789 ? 1'b1 : n785;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n793 = $signed(32'b00000000000000000000000000000100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n794 = mant_prod_reg[4]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n795 = n794 & n793;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n797 = n795 ? 1'b1 : n791;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n799 = $signed(32'b00000000000000000000000000000101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n800 = mant_prod_reg[5]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n801 = n800 & n799;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n803 = n801 ? 1'b1 : n797;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n805 = $signed(32'b00000000000000000000000000000110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n806 = mant_prod_reg[6]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n807 = n806 & n805;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n809 = n807 ? 1'b1 : n803;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n811 = $signed(32'b00000000000000000000000000000111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n812 = mant_prod_reg[7]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n813 = n812 & n811;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n815 = n813 ? 1'b1 : n809;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n817 = $signed(32'b00000000000000000000000000001000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n818 = mant_prod_reg[8]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n819 = n818 & n817;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n821 = n819 ? 1'b1 : n815;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n823 = $signed(32'b00000000000000000000000000001001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n824 = mant_prod_reg[9]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n825 = n824 & n823;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n827 = n825 ? 1'b1 : n821;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n829 = $signed(32'b00000000000000000000000000001010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n830 = mant_prod_reg[10]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n831 = n830 & n829;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n833 = n831 ? 1'b1 : n827;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n835 = $signed(32'b00000000000000000000000000001011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n836 = mant_prod_reg[11]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n837 = n836 & n835;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n839 = n837 ? 1'b1 : n833;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n841 = $signed(32'b00000000000000000000000000001100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n842 = mant_prod_reg[12]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n843 = n842 & n841;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n845 = n843 ? 1'b1 : n839;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n847 = $signed(32'b00000000000000000000000000001101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n848 = mant_prod_reg[13]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n849 = n848 & n847;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n851 = n849 ? 1'b1 : n845;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n853 = $signed(32'b00000000000000000000000000001110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n854 = mant_prod_reg[14]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n855 = n854 & n853;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n857 = n855 ? 1'b1 : n851;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n859 = $signed(32'b00000000000000000000000000001111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n860 = mant_prod_reg[15]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n861 = n860 & n859;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n863 = n861 ? 1'b1 : n857;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n865 = $signed(32'b00000000000000000000000000010000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n866 = mant_prod_reg[16]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n867 = n866 & n865;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n869 = n867 ? 1'b1 : n863;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n871 = $signed(32'b00000000000000000000000000010001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n872 = mant_prod_reg[17]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n873 = n872 & n871;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n875 = n873 ? 1'b1 : n869;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n877 = $signed(32'b00000000000000000000000000010010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n878 = mant_prod_reg[18]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n879 = n878 & n877;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n881 = n879 ? 1'b1 : n875;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n883 = $signed(32'b00000000000000000000000000010011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n884 = mant_prod_reg[19]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n885 = n884 & n883;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n887 = n885 ? 1'b1 : n881;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n889 = $signed(32'b00000000000000000000000000010100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n890 = mant_prod_reg[20]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n891 = n890 & n889;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n893 = n891 ? 1'b1 : n887;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n895 = $signed(32'b00000000000000000000000000010101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n896 = mant_prod_reg[21]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n897 = n896 & n895;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n899 = n897 ? 1'b1 : n893;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n901 = $signed(32'b00000000000000000000000000010110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n902 = mant_prod_reg[22]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n903 = n902 & n901;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n905 = n903 ? 1'b1 : n899;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n907 = $signed(32'b00000000000000000000000000010111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n908 = mant_prod_reg[23]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n909 = n908 & n907;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n911 = n909 ? 1'b1 : n905;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n913 = $signed(32'b00000000000000000000000000011000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n914 = mant_prod_reg[24]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n915 = n914 & n913;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n917 = n915 ? 1'b1 : n911;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n919 = $signed(32'b00000000000000000000000000011001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n920 = mant_prod_reg[25]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n921 = n920 & n919;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n923 = n921 ? 1'b1 : n917;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n925 = $signed(32'b00000000000000000000000000011010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n926 = mant_prod_reg[26]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n927 = n926 & n925;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n929 = n927 ? 1'b1 : n923;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n931 = $signed(32'b00000000000000000000000000011011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n932 = mant_prod_reg[27]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n933 = n932 & n931;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n935 = n933 ? 1'b1 : n929;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n937 = $signed(32'b00000000000000000000000000011100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n938 = mant_prod_reg[28]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n939 = n938 & n937;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n941 = n939 ? 1'b1 : n935;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n943 = $signed(32'b00000000000000000000000000011101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n944 = mant_prod_reg[29]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n945 = n944 & n943;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n947 = n945 ? 1'b1 : n941;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n949 = $signed(32'b00000000000000000000000000011110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n950 = mant_prod_reg[30]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n951 = n950 & n949;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n953 = n951 ? 1'b1 : n947;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n955 = $signed(32'b00000000000000000000000000011111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n956 = mant_prod_reg[31]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n957 = n956 & n955;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n959 = n957 ? 1'b1 : n953;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n961 = $signed(32'b00000000000000000000000000100000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n962 = mant_prod_reg[32]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n963 = n962 & n961;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n965 = n963 ? 1'b1 : n959;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n967 = $signed(32'b00000000000000000000000000100001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n968 = mant_prod_reg[33]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n969 = n968 & n967;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n971 = n969 ? 1'b1 : n965;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n973 = $signed(32'b00000000000000000000000000100010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n974 = mant_prod_reg[34]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n975 = n974 & n973;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n977 = n975 ? 1'b1 : n971;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n979 = $signed(32'b00000000000000000000000000100011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n980 = mant_prod_reg[35]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n981 = n980 & n979;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n983 = n981 ? 1'b1 : n977;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n985 = $signed(32'b00000000000000000000000000100100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n986 = mant_prod_reg[36]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n987 = n986 & n985;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n989 = n987 ? 1'b1 : n983;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n991 = $signed(32'b00000000000000000000000000100101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n992 = mant_prod_reg[37]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n993 = n992 & n991;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n995 = n993 ? 1'b1 : n989;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n997 = $signed(32'b00000000000000000000000000100110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n998 = mant_prod_reg[38]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n999 = n998 & n997;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1001 = n999 ? 1'b1 : n995;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1003 = $signed(32'b00000000000000000000000000100111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1004 = mant_prod_reg[39]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1005 = n1004 & n1003;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1007 = n1005 ? 1'b1 : n1001;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1009 = $signed(32'b00000000000000000000000000101000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1010 = mant_prod_reg[40]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1011 = n1010 & n1009;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1013 = n1011 ? 1'b1 : n1007;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1015 = $signed(32'b00000000000000000000000000101001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1016 = mant_prod_reg[41]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1017 = n1016 & n1015;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1019 = n1017 ? 1'b1 : n1013;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1021 = $signed(32'b00000000000000000000000000101010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1022 = mant_prod_reg[42]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1023 = n1022 & n1021;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1025 = n1023 ? 1'b1 : n1019;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1027 = $signed(32'b00000000000000000000000000101011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1028 = mant_prod_reg[43]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1029 = n1028 & n1027;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1031 = n1029 ? 1'b1 : n1025;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1033 = $signed(32'b00000000000000000000000000101100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1034 = mant_prod_reg[44]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1035 = n1034 & n1033;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1037 = n1035 ? 1'b1 : n1031;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1039 = $signed(32'b00000000000000000000000000101101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1040 = mant_prod_reg[45]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1041 = n1040 & n1039;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1043 = n1041 ? 1'b1 : n1037;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1045 = $signed(32'b00000000000000000000000000101110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1046 = mant_prod_reg[46]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1047 = n1046 & n1045;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1049 = n1047 ? 1'b1 : n1043;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1051 = $signed(32'b00000000000000000000000000101111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1052 = mant_prod_reg[47]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1053 = n1052 & n1051;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1055 = n1053 ? 1'b1 : n1049;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1057 = $signed(32'b00000000000000000000000000110000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1058 = mant_prod_reg[48]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1059 = n1058 & n1057;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1061 = n1059 ? 1'b1 : n1055;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1063 = $signed(32'b00000000000000000000000000110001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1064 = mant_prod_reg[49]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1065 = n1064 & n1063;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1067 = n1065 ? 1'b1 : n1061;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1069 = $signed(32'b00000000000000000000000000110010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1070 = mant_prod_reg[50]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1071 = n1070 & n1069;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1073 = n1071 ? 1'b1 : n1067;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1075 = $signed(32'b00000000000000000000000000110011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1076 = mant_prod_reg[51]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1077 = n1076 & n1075;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1079 = n1077 ? 1'b1 : n1073;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1081 = $signed(32'b00000000000000000000000000110100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1082 = mant_prod_reg[52]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1083 = n1082 & n1081;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1085 = n1083 ? 1'b1 : n1079;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1087 = $signed(32'b00000000000000000000000000110101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1088 = mant_prod_reg[53]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1089 = n1088 & n1087;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1091 = n1089 ? 1'b1 : n1085;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1093 = $signed(32'b00000000000000000000000000110110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1094 = mant_prod_reg[54]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1095 = n1094 & n1093;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1097 = n1095 ? 1'b1 : n1091;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1099 = $signed(32'b00000000000000000000000000110111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1100 = mant_prod_reg[55]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1101 = n1100 & n1099;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1103 = n1101 ? 1'b1 : n1097;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1105 = $signed(32'b00000000000000000000000000111000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1106 = mant_prod_reg[56]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1107 = n1106 & n1105;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1109 = n1107 ? 1'b1 : n1103;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1111 = $signed(32'b00000000000000000000000000111001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1112 = mant_prod_reg[57]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1113 = n1112 & n1111;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1115 = n1113 ? 1'b1 : n1109;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1117 = $signed(32'b00000000000000000000000000111010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1118 = mant_prod_reg[58]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1119 = n1118 & n1117;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1121 = n1119 ? 1'b1 : n1115;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1123 = $signed(32'b00000000000000000000000000111011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1124 = mant_prod_reg[59]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1125 = n1124 & n1123;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1127 = n1125 ? 1'b1 : n1121;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1129 = $signed(32'b00000000000000000000000000111100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1130 = mant_prod_reg[60]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1131 = n1130 & n1129;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1133 = n1131 ? 1'b1 : n1127;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1135 = $signed(32'b00000000000000000000000000111101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1136 = mant_prod_reg[61]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1137 = n1136 & n1135;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1139 = n1137 ? 1'b1 : n1133;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1141 = $signed(32'b00000000000000000000000000111110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1142 = mant_prod_reg[62]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1143 = n1142 & n1141;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1145 = n1143 ? 1'b1 : n1139;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1147 = $signed(32'b00000000000000000000000000111111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1148 = mant_prod_reg[63]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1149 = n1148 & n1147;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1151 = n1149 ? 1'b1 : n1145;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1153 = $signed(32'b00000000000000000000000001000000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1154 = mant_prod_reg[64]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1155 = n1154 & n1153;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1157 = n1155 ? 1'b1 : n1151;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1159 = $signed(32'b00000000000000000000000001000001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1160 = mant_prod_reg[65]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1161 = n1160 & n1159;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1163 = n1161 ? 1'b1 : n1157;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1165 = $signed(32'b00000000000000000000000001000010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1166 = mant_prod_reg[66]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1167 = n1166 & n1165;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1169 = n1167 ? 1'b1 : n1163;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1171 = $signed(32'b00000000000000000000000001000011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1172 = mant_prod_reg[67]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1173 = n1172 & n1171;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1175 = n1173 ? 1'b1 : n1169;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1177 = $signed(32'b00000000000000000000000001000100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1178 = mant_prod_reg[68]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1179 = n1178 & n1177;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1181 = n1179 ? 1'b1 : n1175;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1183 = $signed(32'b00000000000000000000000001000101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1184 = mant_prod_reg[69]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1185 = n1184 & n1183;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1187 = n1185 ? 1'b1 : n1181;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1189 = $signed(32'b00000000000000000000000001000110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1190 = mant_prod_reg[70]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1191 = n1190 & n1189;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1193 = n1191 ? 1'b1 : n1187;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1195 = $signed(32'b00000000000000000000000001000111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1196 = mant_prod_reg[71]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1197 = n1196 & n1195;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1199 = n1197 ? 1'b1 : n1193;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1201 = $signed(32'b00000000000000000000000001001000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1202 = mant_prod_reg[72]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1203 = n1202 & n1201;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1205 = n1203 ? 1'b1 : n1199;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1207 = $signed(32'b00000000000000000000000001001001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1208 = mant_prod_reg[73]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1209 = n1208 & n1207;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1211 = n1209 ? 1'b1 : n1205;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1213 = $signed(32'b00000000000000000000000001001010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1214 = mant_prod_reg[74]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1215 = n1214 & n1213;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1217 = n1215 ? 1'b1 : n1211;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1219 = $signed(32'b00000000000000000000000001001011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1220 = mant_prod_reg[75]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1221 = n1220 & n1219;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1223 = n1221 ? 1'b1 : n1217;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1225 = $signed(32'b00000000000000000000000001001100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1226 = mant_prod_reg[76]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1227 = n1226 & n1225;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1229 = n1227 ? 1'b1 : n1223;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1231 = $signed(32'b00000000000000000000000001001101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1232 = mant_prod_reg[77]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1233 = n1232 & n1231;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1235 = n1233 ? 1'b1 : n1229;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1237 = $signed(32'b00000000000000000000000001001110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1238 = mant_prod_reg[78]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1239 = n1238 & n1237;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1241 = n1239 ? 1'b1 : n1235;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1243 = $signed(32'b00000000000000000000000001001111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1244 = mant_prod_reg[79]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1245 = n1244 & n1243;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1247 = n1245 ? 1'b1 : n1241;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1249 = $signed(32'b00000000000000000000000001010000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1250 = mant_prod_reg[80]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1251 = n1250 & n1249;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1253 = n1251 ? 1'b1 : n1247;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1255 = $signed(32'b00000000000000000000000001010001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1256 = mant_prod_reg[81]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1257 = n1256 & n1255;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1259 = n1257 ? 1'b1 : n1253;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1261 = $signed(32'b00000000000000000000000001010010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1262 = mant_prod_reg[82]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1263 = n1262 & n1261;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1265 = n1263 ? 1'b1 : n1259;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1267 = $signed(32'b00000000000000000000000001010011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1268 = mant_prod_reg[83]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1269 = n1268 & n1267;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1271 = n1269 ? 1'b1 : n1265;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1273 = $signed(32'b00000000000000000000000001010100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1274 = mant_prod_reg[84]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1275 = n1274 & n1273;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1277 = n1275 ? 1'b1 : n1271;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1279 = $signed(32'b00000000000000000000000001010101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1280 = mant_prod_reg[85]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1281 = n1280 & n1279;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1283 = n1281 ? 1'b1 : n1277;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1285 = $signed(32'b00000000000000000000000001010110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1286 = mant_prod_reg[86]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1287 = n1286 & n1285;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1289 = n1287 ? 1'b1 : n1283;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1291 = $signed(32'b00000000000000000000000001010111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1292 = mant_prod_reg[87]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1293 = n1292 & n1291;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1295 = n1293 ? 1'b1 : n1289;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1297 = $signed(32'b00000000000000000000000001011000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1298 = mant_prod_reg[88]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1299 = n1298 & n1297;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1301 = n1299 ? 1'b1 : n1295;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1303 = $signed(32'b00000000000000000000000001011001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1304 = mant_prod_reg[89]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1305 = n1304 & n1303;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1307 = n1305 ? 1'b1 : n1301;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1309 = $signed(32'b00000000000000000000000001011010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1310 = mant_prod_reg[90]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1311 = n1310 & n1309;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1313 = n1311 ? 1'b1 : n1307;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1315 = $signed(32'b00000000000000000000000001011011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1316 = mant_prod_reg[91]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1317 = n1316 & n1315;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1319 = n1317 ? 1'b1 : n1313;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1321 = $signed(32'b00000000000000000000000001011100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1322 = mant_prod_reg[92]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1323 = n1322 & n1321;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1325 = n1323 ? 1'b1 : n1319;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1327 = $signed(32'b00000000000000000000000001011101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1328 = mant_prod_reg[93]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1329 = n1328 & n1327;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1331 = n1329 ? 1'b1 : n1325;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1333 = $signed(32'b00000000000000000000000001011110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1334 = mant_prod_reg[94]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1335 = n1334 & n1333;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1337 = n1335 ? 1'b1 : n1331;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1339 = $signed(32'b00000000000000000000000001011111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1340 = mant_prod_reg[95]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1341 = n1340 & n1339;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1343 = n1341 ? 1'b1 : n1337;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1345 = $signed(32'b00000000000000000000000001100000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1346 = mant_prod_reg[96]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1347 = n1346 & n1345;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1349 = n1347 ? 1'b1 : n1343;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1351 = $signed(32'b00000000000000000000000001100001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1352 = mant_prod_reg[97]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1353 = n1352 & n1351;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1355 = n1353 ? 1'b1 : n1349;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1357 = $signed(32'b00000000000000000000000001100010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1358 = mant_prod_reg[98]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1359 = n1358 & n1357;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1361 = n1359 ? 1'b1 : n1355;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1363 = $signed(32'b00000000000000000000000001100011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1364 = mant_prod_reg[99]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1365 = n1364 & n1363;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1367 = n1365 ? 1'b1 : n1361;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1369 = $signed(32'b00000000000000000000000001100100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1370 = mant_prod_reg[100]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1371 = n1370 & n1369;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1373 = n1371 ? 1'b1 : n1367;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1375 = $signed(32'b00000000000000000000000001100101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1376 = mant_prod_reg[101]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1377 = n1376 & n1375;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1379 = n1377 ? 1'b1 : n1373;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1381 = $signed(32'b00000000000000000000000001100110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1382 = mant_prod_reg[102]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1383 = n1382 & n1381;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1385 = n1383 ? 1'b1 : n1379;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1387 = $signed(32'b00000000000000000000000001100111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1388 = mant_prod_reg[103]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1389 = n1388 & n1387;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1391 = n1389 ? 1'b1 : n1385;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1393 = $signed(32'b00000000000000000000000001101000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1394 = mant_prod_reg[104]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1395 = n1394 & n1393;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1397 = n1395 ? 1'b1 : n1391;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1399 = $signed(32'b00000000000000000000000001101001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1400 = mant_prod_reg[105]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1401 = n1400 & n1399;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1403 = n1401 ? 1'b1 : n1397;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1405 = $signed(32'b00000000000000000000000001101010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1406 = mant_prod_reg[106]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1407 = n1406 & n1405;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1409 = n1407 ? 1'b1 : n1403;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1411 = $signed(32'b00000000000000000000000001101011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1412 = mant_prod_reg[107]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1413 = n1412 & n1411;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1415 = n1413 ? 1'b1 : n1409;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1417 = $signed(32'b00000000000000000000000001101100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1418 = mant_prod_reg[108]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1419 = n1418 & n1417;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1421 = n1419 ? 1'b1 : n1415;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1423 = $signed(32'b00000000000000000000000001101101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1424 = mant_prod_reg[109]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1425 = n1424 & n1423;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1427 = n1425 ? 1'b1 : n1421;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1429 = $signed(32'b00000000000000000000000001101110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1430 = mant_prod_reg[110]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1431 = n1430 & n1429;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1433 = n1431 ? 1'b1 : n1427;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1435 = $signed(32'b00000000000000000000000001101111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1436 = mant_prod_reg[111]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1437 = n1436 & n1435;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1439 = n1437 ? 1'b1 : n1433;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1441 = $signed(32'b00000000000000000000000001110000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1442 = mant_prod_reg[112]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1443 = n1442 & n1441;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1445 = n1443 ? 1'b1 : n1439;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1447 = $signed(32'b00000000000000000000000001110001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1448 = mant_prod_reg[113]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1449 = n1448 & n1447;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1451 = n1449 ? 1'b1 : n1445;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1453 = $signed(32'b00000000000000000000000001110010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1454 = mant_prod_reg[114]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1455 = n1454 & n1453;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1457 = n1455 ? 1'b1 : n1451;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1459 = $signed(32'b00000000000000000000000001110011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1460 = mant_prod_reg[115]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1461 = n1460 & n1459;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1463 = n1461 ? 1'b1 : n1457;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1465 = $signed(32'b00000000000000000000000001110100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1466 = mant_prod_reg[116]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1467 = n1466 & n1465;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1469 = n1467 ? 1'b1 : n1463;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1471 = $signed(32'b00000000000000000000000001110101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1472 = mant_prod_reg[117]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1473 = n1472 & n1471;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1475 = n1473 ? 1'b1 : n1469;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1477 = $signed(32'b00000000000000000000000001110110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1478 = mant_prod_reg[118]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1479 = n1478 & n1477;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1481 = n1479 ? 1'b1 : n1475;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1483 = $signed(32'b00000000000000000000000001110111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1484 = mant_prod_reg[119]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1485 = n1484 & n1483;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1487 = n1485 ? 1'b1 : n1481;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1489 = $signed(32'b00000000000000000000000001111000) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1490 = mant_prod_reg[120]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1491 = n1490 & n1489;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1493 = n1491 ? 1'b1 : n1487;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1495 = $signed(32'b00000000000000000000000001111001) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1496 = mant_prod_reg[121]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1497 = n1496 & n1495;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1499 = n1497 ? 1'b1 : n1493;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1501 = $signed(32'b00000000000000000000000001111010) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1502 = mant_prod_reg[122]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1503 = n1502 & n1501;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1505 = n1503 ? 1'b1 : n1499;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1507 = $signed(32'b00000000000000000000000001111011) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1508 = mant_prod_reg[123]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1509 = n1508 & n1507;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1511 = n1509 ? 1'b1 : n1505;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1513 = $signed(32'b00000000000000000000000001111100) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1514 = mant_prod_reg[124]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1515 = n1514 & n1513;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1517 = n1515 ? 1'b1 : n1511;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1519 = $signed(32'b00000000000000000000000001111101) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1520 = mant_prod_reg[125]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1521 = n1520 & n1519;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1523 = n1521 ? 1'b1 : n1517;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1525 = $signed(32'b00000000000000000000000001111110) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1526 = mant_prod_reg[126]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1527 = n1526 & n1525;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1529 = n1527 ? 1'b1 : n1523;
  /* mc68881_fp80_mul_unit.vhd:215:22  */
  assign n1531 = $signed(32'b00000000000000000000000001111111) <= $signed(n764);
  /* mc68881_fp80_mul_unit.vhd:215:49  */
  assign n1532 = mant_prod_reg[127]; // extract
  /* mc68881_fp80_mul_unit.vhd:215:32  */
  assign n1533 = n1532 & n1531;
  /* mc68881_fp80_mul_unit.vhd:215:15  */
  assign n1535 = n1533 ? 1'b1 : n1529;
  /* mc68881_fp80_mul_unit.vhd:213:11  */
  assign n1537 = n766 ? n1535 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:220:34  */
  assign n1539 = n762[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:220:38  */
  assign n1540 = n1539 | n1537;
  assign n1541 = n762[66:1]; // extract
  assign n1542 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:223:32  */
  assign n1543 = n1542[66:3]; // extract
  assign n1544 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:229:36  */
  assign n1545 = n1544[42]; // extract
  assign n1546 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:230:36  */
  assign n1547 = n1546[41]; // extract
  assign n1548 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:231:26  */
  assign n1549 = n1548[40:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:231:40  */
  assign n1551 = n1549 != 41'b00000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:231:15  */
  assign n1554 = n1551 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:228:13  */
  assign n1556 = rp_reg == 2'b01;
  assign n1557 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:233:36  */
  assign n1558 = n1557[13]; // extract
  assign n1559 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:234:36  */
  assign n1560 = n1559[12]; // extract
  assign n1561 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:235:26  */
  assign n1562 = n1561[11:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:235:40  */
  assign n1564 = n1562 != 12'b000000000000;
  /* mc68881_fp80_mul_unit.vhd:235:15  */
  assign n1567 = n1564 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:232:13  */
  assign n1569 = rp_reg == 2'b10;
  assign n1570 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:237:36  */
  assign n1571 = n1570[2]; // extract
  assign n1572 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:238:36  */
  assign n1573 = n1572[1]; // extract
  assign n1574 = {n1541, n1540};
  /* mc68881_fp80_mul_unit.vhd:239:26  */
  assign n1575 = n1574[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:239:15  */
  assign n1578 = n1575 ? 1'b1 : 1'b0;
  assign n1579 = {n1569, n1556};
  /* mc68881_fp80_mul_unit.vhd:227:11  */
  always @*
    case (n1579)
      2'b10: n1580 = n1558;
      2'b01: n1580 = n1545;
      default: n1580 = n1571;
    endcase
  /* mc68881_fp80_mul_unit.vhd:227:11  */
  always @*
    case (n1579)
      2'b10: n1581 = n1560;
      2'b01: n1581 = n1547;
      default: n1581 = n1573;
    endcase
  /* mc68881_fp80_mul_unit.vhd:227:11  */
  always @*
    case (n1579)
      2'b10: n1582 = n1567;
      2'b01: n1582 = n1554;
      default: n1582 = n1578;
    endcase
  /* mc68881_fp80_mul_unit.vhd:242:30  */
  assign n1584 = n1580 | n1581;
  /* mc68881_fp80_mul_unit.vhd:242:43  */
  assign n1585 = n1584 | n1582;
  /* mc68881_fp80_mul_unit.vhd:248:55  */
  assign n1586 = n1581 | n1582;
  /* mc68881_fp80_mul_unit.vhd:248:83  */
  assign n1587 = n1542[43]; // extract
  /* mc68881_fp80_mul_unit.vhd:248:71  */
  assign n1588 = n1586 | n1587;
  /* mc68881_fp80_mul_unit.vhd:248:34  */
  assign n1589 = n1588 & n1580;
  /* mc68881_fp80_mul_unit.vhd:248:19  */
  assign n1592 = n1589 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:247:17  */
  assign n1594 = rp_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:252:55  */
  assign n1595 = n1581 | n1582;
  /* mc68881_fp80_mul_unit.vhd:252:83  */
  assign n1596 = n1542[14]; // extract
  /* mc68881_fp80_mul_unit.vhd:252:71  */
  assign n1597 = n1595 | n1596;
  /* mc68881_fp80_mul_unit.vhd:252:34  */
  assign n1598 = n1597 & n1580;
  /* mc68881_fp80_mul_unit.vhd:252:19  */
  assign n1601 = n1598 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:251:17  */
  assign n1603 = rp_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:256:55  */
  assign n1604 = n1581 | n1582;
  /* mc68881_fp80_mul_unit.vhd:256:83  */
  assign n1605 = n1542[3]; // extract
  /* mc68881_fp80_mul_unit.vhd:256:71  */
  assign n1606 = n1604 | n1605;
  /* mc68881_fp80_mul_unit.vhd:256:34  */
  assign n1607 = n1606 & n1580;
  /* mc68881_fp80_mul_unit.vhd:256:19  */
  assign n1610 = n1607 ? 1'b1 : 1'b0;
  assign n1611 = {n1603, n1594};
  /* mc68881_fp80_mul_unit.vhd:246:15  */
  always @*
    case (n1611)
      2'b10: n1612 = n1601;
      2'b01: n1612 = n1592;
      default: n1612 = n1610;
    endcase
  /* mc68881_fp80_mul_unit.vhd:245:13  */
  assign n1614 = rm_reg == 2'b00;
  /* mc68881_fp80_mul_unit.vhd:260:13  */
  assign n1616 = rm_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:263:37  */
  assign n1617 = n1585 & res_sign_reg;
  /* mc68881_fp80_mul_unit.vhd:263:15  */
  assign n1620 = n1617 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:262:13  */
  assign n1622 = rm_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:267:31  */
  assign n1623 = ~res_sign_reg;
  /* mc68881_fp80_mul_unit.vhd:267:37  */
  assign n1624 = n1585 & n1623;
  /* mc68881_fp80_mul_unit.vhd:267:15  */
  assign n1627 = n1624 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:266:13  */
  assign n1629 = rm_reg == 2'b11;
  assign n1630 = {n1629, n1622, n1616, n1614};
  /* mc68881_fp80_mul_unit.vhd:244:11  */
  always @*
    case (n1630)
      4'b1000: n1633 = n1627;
      4'b0100: n1633 = n1620;
      4'b0010: n1633 = 1'b0;
      4'b0001: n1633 = n1612;
      default: n1633 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:274:57  */
  assign n1636 = {1'b0, n1543};
  /* mc68881_fp80_mul_unit.vhd:274:70  */
  assign n1638 = n1636 + 65'b00000000000000000000000010000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:274:15  */
  assign n1640 = rp_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:275:57  */
  assign n1642 = {1'b0, n1543};
  /* mc68881_fp80_mul_unit.vhd:275:70  */
  assign n1644 = n1642 + 65'b00000000000000000000000000000000000000000000000000000100000000000;
  /* mc68881_fp80_mul_unit.vhd:275:15  */
  assign n1646 = rp_reg == 2'b10;
  /* mc68881_fp80_mul_unit.vhd:276:57  */
  assign n1648 = {1'b0, n1543};
  /* mc68881_fp80_mul_unit.vhd:276:70  */
  assign n1650 = n1648 + 65'b00000000000000000000000000000000000000000000000000000000000000001;
  assign n1651 = {n1646, n1640};
  /* mc68881_fp80_mul_unit.vhd:273:13  */
  always @*
    case (n1651)
      2'b10: n1652 = n1644;
      2'b01: n1652 = n1638;
      default: n1652 = n1650;
    endcase
  /* mc68881_fp80_mul_unit.vhd:278:26  */
  assign n1653 = n1652[64]; // extract
  /* mc68881_fp80_mul_unit.vhd:280:50  */
  assign n1654 = n1652[63:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:280:28  */
  assign n1656 = n1654 >> 31'b0000000000000000000000000000001;
  /* mc68881_fp80_mul_unit.vhd:281:28  */
  assign n1657 = n1652[0]; // extract
  assign n1659 = n1656[0]; // extract
  /* mc68881_fp80_mul_unit.vhd:281:15  */
  assign n1660 = n1657 ? 1'b1 : n1659;
  assign n1663 = n1656[62:1]; // extract
  /* mc68881_fp80_mul_unit.vhd:285:34  */
  assign n1665 = n755 + 32'b00000000000000000000000000000001;
  /* mc68881_fp80_mul_unit.vhd:287:38  */
  assign n1666 = n1652[63:0]; // extract
  assign n1667 = {1'b1, n1663, n1660};
  /* mc68881_fp80_mul_unit.vhd:278:13  */
  assign n1668 = n1653 ? n1667 : n1666;
  /* mc68881_fp80_mul_unit.vhd:272:11  */
  assign n1669 = n1672 ? n1665 : n755;
  /* mc68881_fp80_mul_unit.vhd:272:11  */
  assign n1670 = n1633 ? n1668 : n1543;
  /* mc68881_fp80_mul_unit.vhd:272:11  */
  assign n1672 = n1653 & n1633;
  /* mc68881_fp80_mul_unit.vhd:293:13  */
  assign n1675 = rp_reg == 2'b01;
  /* mc68881_fp80_mul_unit.vhd:294:13  */
  assign n1678 = rp_reg == 2'b10;
  assign n1679 = {n1678, n1675};
  assign n1680 = n1673[10:0]; // extract
  assign n1681 = n1670[10:0]; // extract
  /* mc68881_fp80_mul_unit.vhd:292:11  */
  always @*
    case (n1679)
      2'b10: n1682 = 11'b00000000000;
      2'b01: n1682 = n1680;
      default: n1682 = n1681;
    endcase
  assign n1683 = n1673[39:11]; // extract
  assign n1684 = n1670[39:11]; // extract
  /* mc68881_fp80_mul_unit.vhd:292:11  */
  always @*
    case (n1679)
      2'b10: n1685 = n1684;
      2'b01: n1685 = n1683;
      default: n1685 = n1684;
    endcase
  assign n1687 = n1670[63:40]; // extract
  /* mc68881_fp80_mul_unit.vhd:299:22  */
  assign n1689 = $signed(n1669) <= $signed(32'b00000000000000000000000000000000);
  /* mc68881_fp80_mul_unit.vhd:300:31  */
  assign n1691 = 32'b00000000000000000000000000000001 - n1669;
  /* mc68881_fp80_mul_unit.vhd:300:13  */
  assign n1692 = n1691[30:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:301:29  */
  assign n1693 = {1'b0, n1692};  //  uext
  /* mc68881_fp80_mul_unit.vhd:301:29  */
  assign n1695 = $signed(n1693) >= $signed(32'b00000000000000000000000001000000);
  assign n1696 = {n1687, n1685, n1682};
  /* mc68881_fp80_mul_unit.vhd:301:59  */
  assign n1698 = n1696 == 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:301:46  */
  assign n1699 = n1695 | n1698;
  assign n1701 = {n1687, n1685, n1682};
  /* mc68881_fp80_mul_unit.vhd:306:72  */
  assign n1702 = n1701 >> n1692;
  assign n1703 = {res_sign_reg, 15'b000000000000000, n1702};
  /* mc68881_fp80_mul_unit.vhd:301:13  */
  assign n1705 = n1699 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1703;
  /* mc68881_fp80_mul_unit.vhd:309:25  */
  assign n1707 = $signed(n1669) >= $signed(32'b00000000000000000111111111111111);
  /* mc68881_fp80_mul_unit.vhd:315:36  */
  assign n1710 = n1669[30:0];  // trunc
  /* mc68881_fp80_mul_unit.vhd:315:24  */
  assign n1711 = n1710[14:0];  // trunc
  assign n1712 = {n1687, n1685, n1682};
  assign n1713 = {res_sign_reg, n1711, n1712};
  assign n1714 = {res_sign_reg, 15'b111111111111111, 64'b0000000000000000000000000000000000000000000000000000000000000000};
  /* mc68881_fp80_mul_unit.vhd:309:11  */
  assign n1715 = n1707 ? n1714 : n1713;
  /* mc68881_fp80_mul_unit.vhd:299:11  */
  assign n1717 = n1689 ? n1705 : n1715;
  /* mc68881_fp80_mul_unit.vhd:197:9  */
  assign n1721 = state_reg == 2'b11;
  assign n1722 = {n1721, n747, n734, n48};
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1726 = 2'b00;
      4'b0100: n1726 = n740;
      4'b0010: n1726 = 2'b10;
      4'b0001: n1726 = n42;
      default: n1726 = 2'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1728 = a_reg;
      4'b0100: n1728 = a_reg;
      4'b0010: n1728 = a_reg;
      4'b0001: n1728 = n43;
      default: n1728 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1730 = b_reg;
      4'b0100: n1730 = b_reg;
      4'b0010: n1730 = b_reg;
      4'b0001: n1730 = n44;
      default: n1730 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1732 = rm_reg;
      4'b0100: n1732 = rm_reg;
      4'b0010: n1732 = rm_reg;
      4'b0001: n1732 = n45;
      default: n1732 = 2'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1734 = rp_reg;
      4'b0100: n1734 = rp_reg;
      4'b0010: n1734 = rp_reg;
      4'b0001: n1734 = n46;
      default: n1734 = 2'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1736 = a_mant_reg;
      4'b0100: n1736 = a_mant_reg;
      4'b0010: n1736 = n138;
      4'b0001: n1736 = a_mant_reg;
      default: n1736 = 64'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1738 = b_mant_reg;
      4'b0100: n1738 = b_mant_reg;
      4'b0010: n1738 = n226;
      4'b0001: n1738 = b_mant_reg;
      default: n1738 = 64'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1740 = res_sign_reg;
      4'b0100: n1740 = res_sign_reg;
      4'b0010: n1740 = n229;
      4'b0001: n1740 = res_sign_reg;
      default: n1740 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1742 = exp_res_reg;
      4'b0100: n1742 = exp_res_reg;
      4'b0010: n1742 = n732;
      4'b0001: n1742 = exp_res_reg;
      default: n1742 = 18'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1744 = early_exit_reg;
      4'b0100: n1744 = early_exit_reg;
      4'b0010: n1744 = n726;
      4'b0001: n1744 = early_exit_reg;
      default: n1744 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1746 = early_result_reg;
      4'b0100: n1746 = early_result_reg;
      4'b0010: n1746 = n728;
      4'b0001: n1746 = early_result_reg;
      default: n1746 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1748 = mant_prod_reg;
      4'b0100: n1748 = n741;
      4'b0010: n1748 = mant_prod_reg;
      4'b0001: n1748 = mant_prod_reg;
      default: n1748 = 128'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1752 = 1'b1;
      4'b0100: n1752 = n744;
      4'b0010: n1752 = 1'b0;
      4'b0001: n1752 = 1'b0;
      default: n1752 = 1'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:115:7  */
  always @*
    case (n1722)
      4'b1000: n1755 = n1717;
      4'b0100: n1755 = n745;
      4'b0010: n1755 = result_reg;
      4'b0001: n1755 = result_reg;
      default: n1755 = 80'bX;
    endcase
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1806 = n40 ? 2'b00 : n1726;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1808 = n40 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1728;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1810 = n40 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1730;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1812 = n40 ? 2'b00 : n1732;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1814 = n40 ? 2'b00 : n1734;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1816 = n40 ? 64'b0000000000000000000000000000000000000000000000000000000000000000 : n1736;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1818 = n40 ? 64'b0000000000000000000000000000000000000000000000000000000000000000 : n1738;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1820 = n40 ? 1'b0 : n1740;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1822 = n40 ? 18'b000000000000000000 : n1742;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1824 = n40 ? 1'b0 : n1744;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1826 = n40 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1746;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1828 = n40 ? 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1748;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1830 = n40 ? 1'b0 : n1752;
  /* mc68881_fp80_mul_unit.vhd:97:5  */
  assign n1832 = n40 ? 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000 : n1755;
  /* mc68881_fp80_mul_unit.vhd:328:32  */
  assign n1909 = state_reg != 2'b00;
  /* mc68881_fp80_mul_unit.vhd:328:17  */
  assign n1910 = n1909 ? 1'b1 : 1'b0;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1912 <= n1806;
  initial
    n1912 = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1913 <= n1808;
  initial
    n1913 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1914 <= n1810;
  initial
    n1914 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1915 <= n1812;
  initial
    n1915 = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1916 <= n1814;
  initial
    n1916 = 2'b00;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1917 <= n1816;
  initial
    n1917 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1918 <= n1818;
  initial
    n1918 = 64'b0000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1919 <= n1820;
  initial
    n1919 = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1920 <= n1822;
  initial
    n1920 = 18'b000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1921 <= n1824;
  initial
    n1921 = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1922 <= n1826;
  initial
    n1922 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1923 <= n1828;
  initial
    n1923 = 128'b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1924 <= n1830;
  initial
    n1924 = 1'b0;
  /* mc68881_fp80_mul_unit.vhd:96:5  */
  always @(posedge clk)
    n1925 <= n1832;
  initial
    n1925 = 80'b00000000000000000000000000000000000000000000000000000000000000000000000000000000;
endmodule

