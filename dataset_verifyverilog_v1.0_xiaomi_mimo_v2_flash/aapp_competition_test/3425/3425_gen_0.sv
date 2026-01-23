module max_queens_4x4 (
    input clk,
    input rst_n,
    input start,
    input [15:0] broken,
    output reg [3:0] max_queens,
    output reg [15:0] num_ways,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_BROKEN = 3'd2;
    localparam [2:0] POPCOUNT = 3'd3;
    localparam [2:0] CHECK_TRIANGLE = 3'd4;
    localparam [2:0] UPDATE_MAX = 3'd5;
    localparam [2:0] NEXT_SUBSET = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    // Constants
    localparam [15:0] MAX_SUBSET = 16'hFFFF;
    localparam [9:0] MAX_TRIANGLES = 10'd560;

    // Registers
    reg [2:0] state;
    reg [15:0] subset;
    reg [3:0] max_q;
    reg [15:0] ways;
    reg [3:0] popcnt;
    reg [9:0] tri_idx;
    reg triangle_found;
    reg [15:0] current_mask;
    reg [3:0] bit_idx;
    reg [15:0] temp_mask;
    reg [15:0] triangle_mask_reg;

    // Triangle table: precomputed 4x4 triangles (packed as 16-bit masks)
    reg [15:0] triangle_mask [0:559];

    // Initialize triangle table
    initial begin
        // Row 0 triangles
        triangle_mask[0] = 16'h0007; triangle_mask[1] = 16'h000B; triangle_mask[2] = 16'h000D;
        triangle_mask[3] = 16'h000E; triangle_mask[4] = 16'h000F; triangle_mask[5] = 16'h0017;
        triangle_mask[6] = 16'h001B; triangle_mask[7] = 16'h001D; triangle_mask[8] = 16'h001E;
        triangle_mask[9] = 16'h001F; triangle_mask[10] = 16'h0027; triangle_mask[11] = 16'h002B;
        triangle_mask[12] = 16'h002D; triangle_mask[13] = 16'h002E; triangle_mask[14] = 16'h002F;
        triangle_mask[15] = 16'h0037; triangle_mask[16] = 16'h003B; triangle_mask[17] = 16'h003D;
        triangle_mask[18] = 16'h003E; triangle_mask[19] = 16'h003F; triangle_mask[20] = 16'h0047;
        triangle_mask[21] = 16'h004B; triangle_mask[22] = 16'h004D; triangle_mask[23] = 16'h004E;
        triangle_mask[24] = 16'h004F; triangle_mask[25] = 16'h0057; triangle_mask[26] = 16'h005B;
        triangle_mask[27] = 16'h005D; triangle_mask[28] = 16'h005E; triangle_mask[29] = 16'h005F;
        triangle_mask[30] = 16'h0067; triangle_mask[31] = 16'h006B; triangle_mask[32] = 16'h006D;
        triangle_mask[33] = 16'h006E; triangle_mask[34] = 16'h006F; triangle_mask[35] = 16'h0077;
        triangle_mask[36] = 16'h007B; triangle_mask[37] = 16'h007D; triangle_mask[38] = 16'h007E;
        triangle_mask[39] = 16'h007F; triangle_mask[40] = 16'h0087; triangle_mask[41] = 16'h008B;
        triangle_mask[42] = 16'h008D; triangle_mask[43] = 16'h008E; triangle_mask[44] = 16'h008F;
        triangle_mask[45] = 16'h0097; triangle_mask[46] = 16'h009B; triangle_mask[47] = 16'h009D;
        triangle_mask[48] = 16'h009E; triangle_mask[49] = 16'h009F; triangle_mask[50] = 16'h00A7;
        triangle_mask[51] = 16'h00AB; triangle_mask[52] = 16'h00AD; triangle_mask[53] = 16'h00AE;
        triangle_mask[54] = 16'h00AF; triangle_mask[55] = 16'h00B7; triangle_mask[56] = 16'h00BB;
        triangle_mask[57] = 16'h00BD; triangle_mask[58] = 16'h00BE; triangle_mask[59] = 16'h00BF;
        triangle_mask[60] = 16'h00C7; triangle_mask[61] = 16'h00CB; triangle_mask[62] = 16'h00CD;
        triangle_mask[63] = 16'h00CE; triangle_mask[64] = 16'h00CF; triangle_mask[65] = 16'h00D7;
        triangle_mask[66] = 16'h00DB; triangle_mask[67] = 16'h00DD; triangle_mask[68] = 16'h00DE;
        triangle_mask[69] = 16'h00DF; triangle_mask[70] = 16'h00E7; triangle_mask[71] = 16'h00EB;
        triangle_mask[72] = 16'h00ED; triangle_mask[73] = 16'h00EE; triangle_mask[74] = 16'h00EF;
        triangle_mask[75] = 16'h00F7; triangle_mask[76] = 16'h00FB; triangle_mask[77] = 16'h00FD;
        triangle_mask[78] = 16'h00FE; triangle_mask[79] = 16'h00FF;
        // Row 1 triangles
        triangle_mask[80] = 16'h0107; triangle_mask[81] = 16'h010B; triangle_mask[82] = 16'h010D;
        triangle_mask[83] = 16'h010E; triangle_mask[84] = 16'h010F; triangle_mask[85] = 16'h0117;
        triangle_mask[86] = 16'h011B; triangle_mask[87] = 16'h011D; triangle_mask[88] = 16'h011E;
        triangle_mask[89] = 16'h011F; triangle_mask[90] = 16'h0127; triangle_mask[91] = 16'h012B;
        triangle_mask[92] = 16'h012D; triangle_mask[93] = 16'h012E; triangle_mask[94] = 16'h012F;
        triangle_mask[95] = 16'h0137; triangle_mask[96] = 16'h013B; triangle_mask[97] = 16'h013D;
        triangle_mask[98] = 16'h013E; triangle_mask[99] = 16'h013F; triangle_mask[100] = 16'h0147;
        triangle_mask[101] = 16'h014B; triangle_mask[102] = 16'h014D; triangle_mask[103] = 16'h014E;
        triangle_mask[104] = 16'h014F; triangle_mask[105] = 16'h0157; triangle_mask[106] = 16'h015B;
        triangle_mask[107] = 16'h015D; triangle_mask[108] = 16'h015E; triangle_mask[109] = 16'h015F;
        triangle_mask[110] = 16'h0167; triangle_mask[111] = 16'h016B; triangle_mask[112] = 16'h016D;
        triangle_mask[113] = 16'h016E; triangle_mask[114] = 16'h016F; triangle_mask[115] = 16'h0177;
        triangle_mask[116] = 16'h017B; triangle_mask[117] = 16'h017D; triangle_mask[118] = 16'h017E;
        triangle_mask[119] = 16'h017F; triangle_mask[120] = 16'h0187; triangle_mask[121] = 16'h018B;
        triangle_mask[122] = 16'h018D; triangle_mask[123] = 16'h018E; triangle_mask[124] = 16'h018F;
        triangle_mask[125] = 16'h0197; triangle_mask[126] = 16'h019B; triangle_mask[127] = 16'h019D;
        triangle_mask[128] = 16'h019E; triangle_mask[129] = 16'h019F; triangle_mask[130] = 16'h01A7;
        triangle_mask[131] = 16'h01AB; triangle_mask[132] = 16'h01AD; triangle_mask[133] = 16'h01AE;
        triangle_mask[134] = 16'h01AF; triangle_mask[135] = 16'h01B7; triangle_mask[136] = 16'h01BB;
        triangle_mask[137] = 16'h01BD; triangle_mask[138] = 16'h01BE; triangle_mask[139] = 16'h01BF;
        triangle_mask[140] = 16'h01C7; triangle_mask[141] = 16'h01CB; triangle_mask[142] = 16'h01CD;
        triangle_mask[143] = 16'h01CE; triangle_mask[144] = 16'h01CF; triangle_mask[145] = 16'h01D7;
        triangle_mask[146] = 16'h01DB; triangle_mask[147] = 16'h01DD; triangle_mask[148] = 16'h01DE;
        triangle_mask[149] = 16'h01DF; triangle_mask[150] = 16'h01E7; triangle_mask[151] = 16'h01EB;
        triangle_mask[152] = 16'h01ED; triangle_mask[153] = 16'h01EE; triangle_mask[154] = 16'h01EF;
        triangle_mask[155] = 16'h01F7; triangle_mask[156] = 16'h01FB; triangle_mask[157] = 16'h01FD;
        triangle_mask[158] = 16'h01FE; triangle_mask[159] = 16'h01FF;
        // Row 2 triangles
        triangle_mask[160] = 16'h0207; triangle_mask[161] = 16'h020B; triangle_mask[162] = 16'h020D;
        triangle_mask[163] = 16'h020E; triangle_mask[164] = 16'h020F; triangle_mask[165] = 16'h0217;
        triangle_mask[166] = 16'h021B; triangle_mask[167] = 16'h021D; triangle_mask[168] = 16'h021E;
        triangle_mask[169] = 16'h021F; triangle_mask[170] = 16'h0227; triangle_mask[171] = 16'h022B;
        triangle_mask[172] = 16'h022D; triangle_mask[173] = 16'h022E; triangle_mask[174] = 16'h022F;
        triangle_mask[175] = 16'h0237; triangle_mask[176] = 16'h023B; triangle_mask[177] = 16'h023D;
        triangle_mask[178] = 16'h023E; triangle_mask[179] = 16'h023F; triangle_mask[180] = 16'h0247;
        triangle_mask[181] = 16'h024B; triangle_mask[182] = 16'h024D; triangle_mask[183] = 16'h024E;
        triangle_mask[184] = 16'h024F; triangle_mask[185] = 16'h0257; triangle_mask[186] = 16'h025B;
        triangle_mask[187] = 16'h025D; triangle_mask[188] = 16'h025E; triangle_mask[189] = 16'h025F;
        triangle_mask[190] = 16'h0267; triangle_mask[191] = 16'h026B; triangle_mask[192] = 16'h026D;
        triangle_mask[193] = 16'h026E; triangle_mask[194] = 16'h026F; triangle_mask[195] = 16'h0277;
        triangle_mask[196] = 16'h027B; triangle_mask[197] = 16'h027D; triangle_mask[198] = 16'h027E;
        triangle_mask[199] = 16'h027F; triangle_mask[200] = 16'h0287; triangle_mask[201] = 16'h028B;
        triangle_mask[202] = 16'h028D; triangle_mask[203] = 16'h028E; triangle_mask[204] = 16'h028F;
        triangle_mask[205] = 16'h0297; triangle_mask[206] = 16'h029B; triangle_mask[207] = 16'h029D;
        triangle_mask[208] = 16'h029E; triangle_mask[209] = 16'h029F; triangle_mask[210] = 16'h02A7;
        triangle_mask[211] = 16'h02AB; triangle_mask[212] = 16'h02AD; triangle_mask[213] = 16'h02AE;
        triangle_mask[214] = 16'h02AF; triangle_mask[215] = 16'h02B7; triangle_mask[216] = 16'h02BB;
        triangle_mask[217] = 16'h02BD; triangle_mask[218] = 16'h02BE; triangle_mask[219] = 16'h02BF;
        triangle_mask[220] = 16'h02C7; triangle_mask[221] = 16'h02CB; triangle_mask[222] = 16'h02CD;
        triangle_mask[223] = 16'h02CE; triangle_mask[224] = 16'h02CF; triangle_mask[225] = 16'h02D7;
        triangle_mask[226] = 16'h02DB; triangle_mask[227] = 16'h02DD; triangle_mask[228] = 16'h02DE;
        triangle_mask[229] = 16'h02DF; triangle_mask[230] = 16'h02E7; triangle_mask[231] = 16'h02EB;
        triangle_mask[232] = 16'h02ED; triangle_mask[233] = 16'h02EE; triangle_mask[234] = 16'h02EF;
        triangle_mask[235] = 16'h02F7; triangle_mask[236] = 16'h02FB; triangle_mask[237] = 16'h02FD;
        triangle_mask[238] = 16'h02FE; triangle_mask[239] = 16'h02FF;
        // Row 3 triangles
        triangle_mask[240] = 16'h0307; triangle_mask[241] = 16'h030B; triangle_mask[242] = 16'h030D;
        triangle_mask[243] = 16'h030E; triangle_mask[244] = 16'h030F; triangle_mask[245] = 16'h0317;
        triangle_mask[246] = 16'h031B; triangle_mask[247] = 16'h031D; triangle_mask[248] = 16'h031E;
        triangle_mask[249] = 16'h031F; triangle_mask[250] = 16'h0327; triangle_mask[251] = 16'h032B;
        triangle_mask[252] = 16'h032D; triangle_mask[253] = 16'h032E; triangle_mask[254] = 16'h032F;
        triangle_mask[255] = 16'h0337; triangle_mask[256] = 16'h033B; triangle_mask[257] = 16'h033D;
        triangle_mask[258] = 16'h033E; triangle_mask[259] = 16'h033F; triangle_mask[260] = 16'h0347;
        triangle_mask[261] = 16'h034B; triangle_mask[262] = 16'h034D; triangle_mask[263] = 16'h034E;
        triangle_mask[264] = 16'h034F; triangle_mask[265] = 16'h0357; triangle_mask[266] = 16'h035B;
        triangle_mask[267] = 16'h035D; triangle_mask[268] = 16'h035E; triangle_mask[269] = 16'h035F;
        triangle_mask[270] = 16'h0367; triangle_mask[271] = 16'h036B; triangle_mask[272] = 16'h036D;
        triangle_mask[273] = 16'h036E; triangle_mask[274] = 16'h036F; triangle_mask[275] = 16'h0377;
        triangle_mask[276] = 16'h037B; triangle_mask[277] = 16'h037D; triangle_mask[278] = 16'h037E;
        triangle_mask[279] = 16'h037F; triangle_mask[280] = 16'h0387; triangle_mask[281] = 16'h038B;
        triangle_mask[282] = 16'h038D; triangle_mask[283] = 16'h038E; triangle_mask[284] = 16'h038F;
        triangle_mask[285] = 16'h0397; triangle_mask[286] = 16'h039B; triangle_mask[287] = 16'h039D;
        triangle_mask[288] = 16'h039E; triangle_mask[289] = 16'h039F; triangle_mask[290] = 16'h03A7;
        triangle_mask[291] = 16'h03AB; triangle_mask[292] = 16'h03AD; triangle_mask[293] = 16'h03AE;
        triangle_mask[294] = 16'h03AF; triangle_mask[295] = 16'h03B7; triangle_mask[296] = 16'h03BB;
        triangle_mask[297] = 16'h03BD; triangle_mask[298] = 16'h03BE; triangle_mask[299] = 16'h03BF;
        triangle_mask[300] = 16'h03C7; triangle_mask[301] = 16'h03CB; triangle_mask[302] = 16'h03CD;
        triangle_mask[303] = 16'h03CE; triangle_mask[304] = 16'h03CF; triangle_mask[305] = 16'h03D7;
        triangle_mask[306] = 16'h03DB; triangle_mask[307] = 16'h03DD; triangle_mask[308] = 16'h03DE;
        triangle_mask[309] = 16'h03DF; triangle_mask[310] = 16'h03E7; triangle_mask[311] = 16'h03EB;
        triangle_mask[312] = 16'h03ED; triangle_mask[313] = 16'h03EE; triangle_mask[314] = 16'h03EF;
        triangle_mask[315] = 16'h03F7; triangle_mask[316] = 16'h03FB; triangle_mask[317] = 16'h03FD;
        triangle_mask[318] = 16'h03FE; triangle_mask[319] = 16'h03FF;
        // Column 0 triangles
        triangle_mask[320] = 16'h0701; triangle_mask[321] = 16'h0702; triangle_mask[322] = 16'h0703;
        triangle_mask[323] = 16'h0704; triangle_mask[324] = 16'h0705; triangle_mask[325] = 16'h0706;
        triangle_mask[326] = 16'h0707; triangle_mask[327] = 16'h0708; triangle_mask[328] = 16'h0709;
        triangle_mask[329] = 16'h070A; triangle_mask[330] = 16'h070B; triangle_mask[331] = 16'h070C;
        triangle_mask[332] = 16'h070D; triangle_mask[333] = 16'h070E; triangle_mask[334] = 16'h070F;
        triangle_mask[335] = 16'h0B01; triangle_mask[336] = 16'h0B02; triangle_mask[337] = 16'h0B03;
        triangle_mask[338] = 16'h0B04; triangle_mask[339] = 16'h0B05; triangle_mask[340] = 16'h0B06;
        triangle_mask[341] = 16'h0B07; triangle_mask[342] = 16'h0B08; triangle_mask[343] = 16'h0B09;
        triangle_mask[344] = 16'h0B0A; triangle_mask[345] = 16'h0B0B; triangle_mask[346] = 16'h0B0C;
        triangle_mask[347] = 16'h0B0D; triangle_mask[348] = 16'h0B0E; triangle_mask[349] = 16'h0B0F;
        triangle_mask[350] = 16'h0D01; triangle_mask[351] = 16'h0D02; triangle_mask[352] = 16'h0D03;
        triangle_mask[353] = 16'h0D04; triangle_mask[354] = 16'h0D05; triangle_mask[355] = 16'h0D06;
        triangle_mask[356] = 16'h0D07; triangle_mask[357] = 16'h0D08; triangle_mask[358] = 16'h0D09;
        triangle_mask[359] = 16'h0D0A; triangle_mask[360] = 16'h0D0B; triangle_mask[361] = 16'h0D0C;
        triangle_mask[362] = 16'h0D0D; triangle_mask[363] = 16'h0D0E; triangle_mask[364] = 16'h0D0F;
        triangle_mask[365] = 16'h0E01; triangle_mask[366] = 16'h0E02; triangle_mask[367] = 16'h0E03;
        triangle_mask[368] = 16'h0E04; triangle_mask[369] = 16'h0E05; triangle_mask[370] = 16'h0E06;
        triangle_mask[371] = 16'h0E07; triangle_mask[372] = 16'h0E08; triangle_mask[373] = 16'h0E09;
        triangle_mask[374] = 16'h0E0A; triangle_mask[375] = 16'h0E0B; triangle_mask[376] = 16'h0E0C;
        triangle_mask[377] = 16'h0E0D; triangle_mask[378] = 16'h0E0E; triangle_mask[379] = 16'h0E0F;
        triangle_mask[380] = 16'h0F01; triangle_mask[381] = 16'h0F02; triangle_mask[382] = 16'h0F03;
        triangle_mask[383] = 16'h0F04; triangle_mask[384] = 16'h0F05; triangle_mask[385] = 16'h0F06;
        triangle_mask[386] = 16'h0F07; triangle_mask[387] = 16'h0F08; triangle_mask[388] = 16'h0F09;
        triangle_mask[389] = 16'h0F0A; triangle_mask[390] = 16'h0F0B; triangle_mask[391] = 16'h0F0C;
        triangle_mask[392] = 16'h0F0D; triangle_mask[393] = 16'h0F0E; triangle_mask[394] = 16'h0F0F;
        // Column 1 triangles
        triangle_mask[395] = 16'h1701; triangle_mask[396] = 16'h1702; triangle_mask[397] = 16'h1703;
        triangle_mask[398] = 16'h1704; triangle_mask[399] = 16'h1705; triangle_mask[400] = 16'h1706;
        triangle_mask[401] = 16'h1707; triangle_mask[402] = 16'h1708; triangle_mask[403] = 16'h1709;
        triangle_mask[404] = 16'h170A; triangle_mask[405] = 16'h170B; triangle_mask[406] = 16'h170C;
        triangle_mask[407] = 16'h170D; triangle_mask[408] = 16'h170E; triangle_mask[409] = 16'h170F;
        triangle_mask[410] = 16'h1B01; triangle_mask[411] = 16'h1B02; triangle_mask[412] = 16'h1B03;
        triangle_mask[413] = 16'h1B04; triangle_mask[414] = 16'h1B05; triangle_mask[415] = 16'h1B06;
        triangle_mask[416] = 16'h1B07; triangle_mask[417] = 16'h1B08; triangle_mask[418] = 16'h1B09;
        triangle_mask[419] = 16'h1B0A; triangle_mask[420] = 16'h1B0B; triangle_mask[421] = 16'h1B0C;
        triangle_mask[422] = 16'h1B0D; triangle_mask[423] = 16'h1B0E; triangle_mask[424] = 16'h1B0F;
        triangle_mask[425] = 16'h1D01; triangle_mask[426] = 16'h1D02; triangle_mask[427] = 16'h1D03;
        triangle_mask[428] = 16'h1D04; triangle_mask[429] = 16'h1D05; triangle_mask[430] = 16'h1D06;
        triangle_mask[431] = 16'h1D07; triangle_mask[432] = 16'h1D08; triangle_mask[433] = 16'h1D09;
        triangle_mask[434] = 16'h1D0A; triangle_mask[435] = 16'h1D0B; triangle_mask[436] = 16'h1D0C;
        triangle_mask[437] = 16'h1D0D; triangle_mask[438] = 16'h1D0E; triangle_mask[439] = 16'h1D0F;
        triangle_mask[440] = 16'h1E01; triangle_mask[441] = 16'h1E02; triangle_mask[442] = 16'h1E03;
        triangle_mask[443] = 16'h1E04; triangle_mask[444] = 16'h1E05; triangle_mask[445] = 16'h1E06;
        triangle_mask[446] = 16'h1E07; triangle_mask[447] = 16'h1E08; triangle_mask[448] = 16'h1E09;
        triangle_mask[449] = 16'h1E0A; triangle_mask[450] = 16'h1E0B; triangle_mask[451] = 16'h1E0C;
        triangle_mask[452] = 16'h1E0D; triangle_mask[453] = 16'h1E0E; triangle_mask[454] = 16'h1E0F;
        triangle_mask[455] = 16'h1F01; triangle_mask[456] = 16'h1F02; triangle_mask[457] = 16'h1F03;
        triangle_mask[458] = 16'h1F04; triangle_mask[459] = 16'h1F05; triangle_mask[460] = 16'h1F06;
        triangle_mask[461] = 16'h1F07; triangle_mask[462] = 16'h1F08; triangle_mask[463] = 16'h1F09;
        triangle_mask[464] = 16'h1F0A; triangle_mask[465] = 16'h1F0B; triangle_mask[466] = 16'h1F0C;
        triangle_mask[467] = 16'h1F0D; triangle_mask[468] = 16'h1F0E; triangle_mask[469] = 16'h1F0F;
        // Column 2 triangles
        triangle_mask[470] = 16'h2701; triangle_mask[471] = 16'h2702; triangle_mask[472] = 16'h2703;
        triangle_mask[473] = 16'h2704; triangle_mask[474] = 16'h2705; triangle_mask[475] = 16'h2706;
        triangle_mask[476] = 16'h2707; triangle_mask[477] = 16'h2708; triangle_mask[478] = 16'h2709;
        triangle_mask[479] = 16'h270A; triangle_mask[480] = 16'h270B; triangle_mask[481] = 16'h270C;
        triangle_mask[482] = 16'h270D; triangle_mask[483] = 16'h270E; triangle_mask[484] = 16'h270F;
        triangle_mask[485] = 16'h2B01; triangle_mask[486] = 16'h2B02; triangle_mask[487] = 16'h2B03;
        triangle_mask[488] = 16'h2B04; triangle_mask[489] = 16'h2B05; triangle_mask[490] = 16'h2B06;
        triangle_mask[491] = 16'h2B07; triangle_mask[492] = 16'h2B08; triangle_mask[493] = 16'h2B09;
        triangle_mask[494] = 16'h2B0A; triangle_mask[495] = 16'h2B0B; triangle_mask[496] = 16'h2B0C;
        triangle_mask[497] = 16'h2B0D; triangle_mask[498] = 16'h2B0E; triangle_mask[499] = 16'h2B0F;
        triangle_mask[500] = 16'h2D01; triangle_mask[501] = 16'h2D02; triangle_mask[502] = 16'h2D03;
        triangle_mask[503] = 16'h2D04; triangle_mask[504] = 16'h2D05; triangle_mask[505] = 16'h2D06;
        triangle_mask[506] = 16'h2D07; triangle_mask[507] = 16'h2D08; triangle_mask[508] = 16'h2D09;
        triangle_mask[509] = 16'h2D0A; triangle_mask[510] = 16'h2D0B; triangle_mask[511] = 16'h2D0C;
        triangle_mask[512] = 16'h2D0D; triangle_mask[513] = 16'h2D0E; triangle_mask[514] = 16'h2D0F;
        triangle_mask[515] = 16'h2E01; triangle_mask[516] = 16'h2E02; triangle_mask[517] = 16'h2E03;
        triangle_mask[518] = 16'h2E04; triangle_mask[519] = 16'h2E05; triangle_mask[520] = 16'h2E06;
        triangle_mask[521] = 16'h2E07; triangle_mask[522] = 16'h2E08; triangle_mask[523] = 16'h2E09;
        triangle_mask[524] = 16'h2E0A; triangle_mask[525] = 16'h2E0B; triangle_mask[526] = 16'h2E0C;
        triangle_mask[527] = 16'h2E0D; triangle_mask[528] = 16'h2E0E; triangle_mask[529] = 16'h2E0F;
        triangle_mask[530] = 16'h2F01; triangle_mask[531] = 16'h2F02; triangle_mask[532] = 16'h2F03;
        triangle_mask[533] = 16'h2F04; triangle_mask[534] = 16'h2F05; triangle_mask[535] = 16'h2F06;
        triangle_mask[536] = 16'h2F07; triangle_mask[537] = 16'h2F08; triangle_mask[538] = 16'h2F09;
        triangle_mask[539] = 16'h2F0A; triangle_mask[540] = 16'h2F0B; triangle_mask[541] = 16'h2F0C;
        triangle_mask[542] = 16'h2F0D; triangle_mask[543] = 16'h2F0E; triangle_mask[544] = 16'h2F0F;
        // Column 3 triangles
        triangle_mask[545] = 16'h3701; triangle_mask[546] = 16'h3702; triangle_mask[547] = 16'h3703;
        triangle_mask[548] = 16'h3704; triangle_mask[549] = 16'h3705; triangle_mask[550] = 16'h3706;
        triangle_mask[551] = 16'h3707; triangle_mask[552] = 16'h3708; triangle_mask[553] = 16'h3709;
        triangle_mask[554] = 16'h370A; triangle_mask[555] = 16'h370B; triangle_mask[556] = 16'h370C;
        triangle_mask[557] = 16'h370D; triangle_mask[558] = 16'h370E; triangle_mask[559] = 16'h370F;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset <= 16'b0;
            max_q <= 4'b0;
            ways <= 16'b0;
            popcnt <= 4'b0;
            tri_idx <= 10'b0;
            triangle_found <= 1'b0;
            done <= 1'b0;
            bit_idx <= 4'b0;
            current_mask <= 16'b0;
            max_queens <= 4'b0;
            num_ways <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 1'b0;
                    end
                end

                INIT: begin
                    subset <= 16'b0;
                    max_q <= 4'b0;
                    ways <= 16'b0;
                    state <= CHECK_BROKEN;
                end

                CHECK_BROKEN: begin
                    // Check if current subset intersects broken cells
                    if (|(subset & broken)) begin
                        // Skip this subset
                        state <= NEXT_SUBSET;
                    end else begin
                        // Initialize popcount variables
                        popcnt <= 4'b0;
                        bit_idx <= 4'b0;
                        state <= POPCOUNT;
                    end
                end

                POPCOUNT: begin
                    if (bit_idx < 4'd16) begin
                        if (subset[bit_idx]) begin
                            popcnt <= popcnt + 1'b1;
                        end
                        bit_idx <= bit_idx + 1'b1;
                    end else begin
                        // Popcount done, initialize triangle check
                        tri_idx <= 10'b0;
                        triangle_found <= 1'b0;
                        state <= CHECK_TRIANGLE;
                    end
                end

                CHECK_TRIANGLE: begin
                    if (tri_idx < MAX_TRIANGLES) begin
                        current_mask <= triangle_mask[tri_idx];
                        // Check if triangle_mask[tri_idx] is subset of subset
                        if ((subset & current_mask) == current_mask) begin
                            triangle_found <= 1'b1;
                            // No need to check further
                            state <= NEXT_SUBSET;
                        end else begin
                            tri_idx <= tri_idx + 10'd1;
                        end
                    end else begin
                        // No triangle found, update max and ways
                        if (triangle_found == 1'b0) begin
                            state <= UPDATE_MAX;
                        end else begin
                            state <= NEXT_SUBSET;
                        end
                    end
                end

                UPDATE_MAX: begin
                    if (popcnt > max_q) begin
                        max_q <= popcnt;
                        ways <= 16'd1;
                    end else if (popcnt == max_q) begin
                        ways <= ways + 16'd1;
                    end
                    state <= NEXT_SUBSET;
                end

                NEXT_SUBSET: begin
                    if (subset < MAX_SUBSET) begin
                        subset <= subset + 16'd1;
                        state <= CHECK_BROKEN;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    max_queens <= max_q;
                    num_ways <= ways;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule