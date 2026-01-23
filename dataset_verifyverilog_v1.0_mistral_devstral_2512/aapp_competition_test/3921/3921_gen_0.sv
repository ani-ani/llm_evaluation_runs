module GoodSequenceFinder(
    input clk, rst_n, start,
    input [3:0] len,
    input [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
                arr_8, arr_9, arr_10, arr_11, arr_12, arr_13, arr_14, arr_15,
    output reg done,
    output reg [7:0] result
);
    
    // States
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE = 2'd2;
    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] overall_max;
    reg [7:0] dp_reg [0:255];  // DP values for primes
    reg [7:0] arr_reg [0:15];  // Input array storage
    reg [3:0] len_reg;
    
    // Prime factors ROM [prime0, prime1, prime2, prime3, count]
    reg [33:0] rom [0:255];
    
    // Initialize ROM (generated from Python)
    initial begin
        // Initialize all to zeros
        integer i;
        for (i=0; i<256; i=i+1) rom[i] = 34'd0;
        // Populate with precomputed factors
        rom[1] = {8'd0,8'd0,8'd0,8'd0,2'd0};
        rom[2] = {8'd2,8'd0,8'd0,8'd0,2'd1};
        rom[3] = {8'd3,8'd0,8'd0,8'd0,2'd1};
        rom[4] = {8'd2,8'd0,8'd0,8'd0,2'd1};
        rom[5] = {8'd5,8'd0,8'd0,8'd0,2'd1};
        rom[6] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[7] = {8'd7,8'd0,8'd0,8'd0,2'd1};
        rom[8] = {8'd2,8'd0,8'd0,8'd0,2'd1};
        rom[9] = {8'd3,8'd0,8'd0,8'd0,2'd1};
        rom[10] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[11] = {8'd11,8'd0,8'd0,8'd0,2'd1};
        rom[12] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[13] = {8'd13,8'd0,8'd0,8'd0,2'd1};
        rom[14] = {8'd2,8'd7,8'd0,8'd0,2'd2};
        rom[15] = {8'd3,8'd5,8'd0,8'd0,2'd2};
        rom[16] = {8'd2,8'd0,8'd0,8'd0,2'd1};
        rom[17] = {8'd17,8'd0,8'd0,8'd0,2'd1};
        rom[18] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[19] = {8'd19,8'd0,8'd0,8'd0,2'd1};
        rom[20] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[21] = {8'd3,8'd7,8'd0,8'd0,2'd2};
        rom[22] = {8'd2,8'd11,8'd0,8'd0,2'd2};
        rom[23] = {8'd23,8'd0,8'd0,8'd0,2'd1};
        rom[24] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[25] = {8'd5,8'd0,8'd0,8'd0,2'd1};
        rom[26] = {8'd2,8'd13,8'd0,8'd0,2'd2};
        rom[27] = {8'd3,8'd0,8'd0,8'd0,2'd1};
        rom[28] = {8'd2,8'd7,8'd0,8'd0,2'd2};
        rom[29] = {8'd29,8'd0,8'd0,8'd0,2'd1};
        rom[30] = {8'd2,8'd3,8'd5,8'd0,2'd3};
        rom[31] = {8'd31,8'd0,8'd0,8'd0,2'd1};
        rom[32] = {8'd2,8'd0,8'd0,8'd0,2'd1};
        rom[33] = {8'd3,8'd11,8'd0,8'd0,2'd2};
        rom[34] = {8'd2,8'd17,8'd0,8'd0,2'd2};
        rom[35] = {8'd5,8'd7,8'd0,8'd0,2'd2};
        rom[36] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[37] = {8'd37,8'd0,8'd0,8'd0,2'd1};
        rom[38] = {8'd2,8'd19,8'd0,8'd0,2'd2};
        rom[39] = {8'd3,8'd13,8'd0,8'd0,2'd2};
        rom[40] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[41] = {8'd41,8'd0,8'd0,8'd0,2'd1};
        rom[42] = {8'd2,8'd3,8'd7,8'd0,2'd3};
        rom[43] = {8'd43,8'd0,8'd0,8'd0,2'd1};
        rom[44] = {8'd2,8'd11,8'd0,8'd0,2'd2};
        rom[45] = {8'd3,8'd5,8'd0,8'd0,2'd2};
        rom[46] = {8'd2,8'd23,8'd0,8'd0,2'd2};
        rom[47] = {8'd47,8'd0,8'd0,8'd0,2'd1};
        rom[48] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[49] = {8'd7,8'd0,8'd0,8'd0,2'd1};
        rom[50] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[51] = {8'd3,8'd17,8'd0,8'd0,2'd2};
        rom[52] = {8'd2,8'd13,8'd0,8'd0,2'd2};
        rom[53] = {8'd53,8'd0,8'd0,8'd0,2'd1};
        rom[54] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[55] = {8'd5,8'd11,8'd0,8'd0,2'd2};
        rom[56] = {8'd2,8'd7,8'd0,8'd0,2'd2};
        rom[57] = {8'd3,8'd19,8'd0,8'd0,2'd2};
        rom[58] = {8'd2,8'd29,8'd0,8'd0,2'd2};
        rom[59] = {8'd59,8'd0,8'd0,8'd0,2'd1};
        rom[60] = {8'd2,8'd3,8'd5,8'd0,2'd3};
        rom[61] = {8'd61,8'd0,8'd0,8'd0,2'd1};
        rom[62] = {8'd2,8'd31,8'd0,8'd0,2'd2};
        rom[63] = {8'd3,8'd7,8'd0,8'd0,2'd2};
        rom[64] = {8'd2,8'd0,8'd0,8'd0,2'd1};
        rom[65] = {8'd5,8'd13,8'd0,8'd0,2'd2};
        rom[66] = {8'd2,8'd3,8'd11,8'd0,2'd3};
        rom[67] = {8'd67,8'd0,8'd0,8'd0,2'd1};
        rom[68] = {8'd2,8'd17,8'd0,8'd0,2'd2};
        rom[69] = {8'd3,8'd23,8'd0,8'd0,2'd2};
        rom[70] = {8'd2,8'd5,8'd7,8'd0,2'd3};
        rom[71] = {8'd71,8'd0,8'd0,8'd0,2'd1};
        rom[72] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[73] = {8'd73,8'd0,8'd0,8'd0,2'd1};
        rom[74] = {8'd2,8'd37,8'd0,8'd0,2'd2};
        rom[75] = {8'd3,8'd5,8'd0,8'd0,2'd2};
        rom[76] = {8'd2,8'd19,8'd0,8'd0,2'd2};
        rom[77] = {8'd7,8'd11,8'd0,8'd0,2'd2};
        rom[78] = {8'd2,8'd3,8'd13,8'd0,2'd3};
        rom[79] = {8'd79,8'd0,8'd0,8'd0,2'd1};
        rom[80] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[81] = {8'd3,8'd0,8'd0,8'd0,2'd1};
        rom[82] = {8'd2,8'd41,8'd0,8'd0,2'd2};
        rom[83] = {8'd83,8'd0,8'd0,8'd0,2'd1};
        rom[84] = {8'd2,8'd3,8'd7,8'd0,2'd3};
        rom[85] = {8'd5,8'd17,8'd0,8'd0,2'd2};
        rom[86] = {8'd2,8'd43,8'd0,8'd0,2'd2};
        rom[87] = {8'd3,8'd29,8'd0,8'd0,2'd2};
        rom[88] = {8'd2,8'd11,8'd0,8'd0,2'd2};
        rom[89] = {8'd89,8'd0,8'd0,8'd0,2'd1};
        rom[90] = {8'd2,8'd3,8'd5,8'd0,2'd3};
        rom[91] = {8'd7,8'd13,8'd0,8'd0,2'd2};
        rom[92] = {8'd2,8'd23,8'd0,8'd0,2'd2};
        rom[93] = {8'd3,8'd31,8'd0,8'd0,2'd2};
        rom[94] = {8'd2,8'd47,8'd0,8'd0,2'd2};
        rom[95] = {8'd5,8'd19,8'd0,8'd0,2'd2};
        rom[96] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[97] = {8'd97,8'd0,8'd0,8'd0,2'd1};
        rom[98] = {8'd2,8'd7,8'd0,8'd0,2'd2};
        rom[99] = {8'd3,8'd11,8'd0,8'd0,2'd2};
        rom[100] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[101] = {8'd101,8'd0,8'd0,8'd0,2'd1};
        rom[102] = {8'd2,8'd3,8'd17,8'd0,2'd3};
        rom[103] = {8'd103,8'd0,8'd0,8'd0,2'd1};
        rom[104] = {8'd2,8'd13,8'd0,8'd0,2'd2};
        rom[105] = {8'd3,8'd5,8'd7,8'd0,2'd3};
        rom[106] = {8'd2,8'd53,8'd0,8'd0,2'd2};
        rom[107] = {8'd107,8'd0,8'd0,8'd0,2'd1};
        rom[108] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[109] = {8'd109,8'd0,8'd0,8'd0,2'd1};
        rom[110] = {8'd2,8'd5,8'd11,8'd0,2'd3};
        rom[111] = {8'd3,8'd37,8'd0,8'd0,2'd2};
        rom[112] = {8'd2,8'd7,8'd0,8'd0,2'd2};
        rom[113] = {8'd113,8'd0,8'd0,8'd0,2'd1};
        rom[114] = {8'd2,8'd3,8'd19,8'd0,2'd3};
        rom[115] = {8'd5,8'd23,8'd0,8'd0,2'd2};
        rom[116] = {8'd2,8'd29,8'd0,8'd0,2'd2};
        rom[117] = {8'd3,8'd13,8'd0,8'd0,2'd2};
        rom[118] = {8'd2,8'd59,8'd0,8'd0,2'd2};
        rom[119] = {8'd7,8'd17,8'd0,8'd0,2'd2};
        rom[120] = {8'd2,8'd3,8'd5,8'd0,2'd3};
        rom[121] = {8'd11,8'd0,8'd0,8'd0,2'd1};
        rom[122] = {8'd2,8'd61,8'd0,8'd0,2'd2};
        rom[123] = {8'd3,8'd41,8'd0,8'd0,2'd2};
        rom[124] = {8'd2,8'd31,8'd0,8'd0,2'd2};
        rom[125] = {8'd5,8'd0,8'd0,8'd0,2'd1};
        rom[126] = {8'd2,8'd3,8'd7,8'd0,2'd3};
        rom[127] = {8'd127,8'd0,8'd0,8'd0,2'd1};
        rom[128] = {8'd2,8'd0,8'd0,8'd0,2'd1};
        rom[129] = {8'd3,8'd43,8'd0,8'd0,2'd2};
        rom[130] = {8'd2,8'd5,8'd13,8'd0,2'd3};
        rom[131] = {8'd131,8'd0,8'd0,8'd0,2'd1};
        rom[132] = {8'd2,8'd3,8'd11,8'd0,2'd3};
        rom[133] = {8'd7,8'd19,8'd0,8'd0,2'd2};
        rom[134] = {8'd2,8'd67,8'd0,8'd0,2'd2};
        rom[135] = {8'd3,8'd5,8'd0,8'd0,2'd2};
        rom[136] = {8'd2,8'd17,8'd0,8'd0,2'd2};
        rom[137] = {8'd137,8'd0,8'd0,8'd0,2'd1};
        rom[138] = {8'd2,8'd3,8'd23,8'd0,2'd3};
        rom[139] = {8'd139,8'd0,8'd0,8'd0,2'd1};
        rom[140] = {8'd2,8'd5,8'd7,8'd0,2'd3};
        rom[141] = {8'd3,8'd47,8'd0,8'd0,2'd2};
        rom[142] = {8'd2,8'd71,8'd0,8'd0,2'd2};
        rom[143] = {8'd11,8'd13,8'd0,8'd0,2'd2};
        rom[144] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[145] = {8'd5,8'd29,8'd0,8'd0,2'd2};
        rom[146] = {8'd2,8'd73,8'd0,8'd0,2'd2};
        rom[147] = {8'd3,8'd7,8'd0,8'd0,2'd2};
        rom[148] = {8'd2,8'd37,8'd0,8'd0,2'd2};
        rom[149] = {8'd149,8'd0,8'd0,8'd0,2'd1};
        rom[150] = {8'd2,8'd3,8'd5,8'd0,2'd3};
        rom[151] = {8'd151,8'd0,8'd0,8'd0,2'd1};
        rom[152] = {8'd2,8'd19,8'd0,8'd0,2'd2};
        rom[153] = {8'd3,8'd17,8'd0,8'd0,2'd2};
        rom[154] = {8'd2,8'd7,8'd11,8'd0,2'd3};
        rom[155] = {8'd5,8'd31,8'd0,8'd0,2'd2};
        rom[156] = {8'd2,8'd39,8'd0,8'd0,2'd2};
        rom[157] = {8'd157,8'd0,8'd0,8'd0,2'd1};
        rom[158] = {8'd2,8'd79,8'd0,8'd0,2'd2};
        rom[159] = {8'd3,8'd53,8'd0,8'd0,2'd2};
        rom[160] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[161] = {8'd7,8'd23,8'd0,8'd0,2'd2};
        rom[162] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[163] = {8'd163,8'd0,8'd0,8'd0,2'd1};
        rom[164] = {8'd2,8'd41,8'd0,8'd0,2'd2};
        rom[165] = {8'd3,8'd5,8'd11,8'd0,2'd3};
        rom[166] = {8'd2,8'd83,8'd0,8'd0,2'd2};
        rom[167] = {8'd167,8'd0,8'd0,8'd0,2'd1};
        rom[168] = {8'd2,8'd3,8'd7,8'd0,2'd3};
        rom[169] = {8'd13,8'd0,8'd0,8'd0,2'd1};
        rom[170] = {8'd2,8'd5,8'd17,8'd0,2'd3};
        rom[171] = {8'd3,8'd19,8'd0,8'd0,2'd2};
        rom[172] = {8'd2,8'd43,8'd0,8'd0,2'd2};
        rom[173] = {8'd173,8'd0,8'd0,8'd0,2'd1};
        rom[174] = {8'd2,8'd3,8'd29,8'd0,2'd3};
        rom[175] = {8'd5,8'd7,8'd0,8'd0,2'd2};
        rom[176] = {8'd2,8'd11,8'd0,8'd0,2'd2};
        rom[177] = {8'd3,8'd59,8'd0,8'd0,2'd2};
        rom[178] = {8'd2,8'd89,8'd0,8'd0,2'd2};
        rom[179] = {8'd179,8'd0,8'd0,8'd0,2'd1};
        rom[180] = {8'd2,8'd3,8'd5,8'd0,2'd3};
        rom[181] = {8'd181,8'd0,8'd0,8'd0,2'd1};
        rom[182] = {8'd2,8'd7,8'd13,8'd0,2'd3};
        rom[183] = {8'd183,8'd0,8'd0,8'd0,2'd1};
        rom[184] = {8'd2,8'd23,8'd0,8'd0,2'd2};
        rom[185] = {8'd5,8'd37,8'd0,8'd0,2'd2};
        rom[186] = {8'd2,8'd3,8'd31,8'd0,2'd3};
        rom[187] = {8'd11,8'd17,8'd0,8'd0,2'd2};
        rom[188] = {8'd2,8'd47,8'd0,8'd0,2'd2};
        rom[189] = {8'd3,8'd63,8'd0,8'd0,2'd2};
        rom[190] = {8'd2,8'd5,8'd19,8'd0,2'd3};
        rom[191] = {8'd191,8'd0,8'd0,8'd0,2'd1};
        rom[192] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[193] = {8'd193,8'd0,8'd0,8'd0,2'd1};
        rom[194] = {8'd2,8'd97,8'd0,8'd0,2'd2};
        rom[195] = {8'd3,8'd5,8'd13,8'd0,2'd3};
        rom[196] = {8'd2,8'd49,8'd0,8'd0,2'd2};
        rom[197] = {8'd197,8'd0,8'd0,8'd0,2'd1};
        rom[198] = {8'd2,8'd3,8'd11,8'd0,2'd3};
        rom[199] = {8'd199,8'd0,8'd0,8'd0,2'd1};
        rom[200] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[201] = {8'd3,8'd67,8'd0,8'd0,2'd2};
        rom[202] = {8'd2,8'd101,8'd0,8'd0,2'd2};
        rom[203] = {8'd7,8'd29,8'd0,8'd0,2'd2};
        rom[204] = {8'd2,8'd3,8'd17,8'd0,2'd3};
        rom[205] = {8'd5,8'd41,8'd0,8'd0,2'd2};
        rom[206] = {8'd2,8'd103,8'd0,8'd0,2'd2};
        rom[207] = {8'd3,8'd9,8'd0,8'd0,2'd2};
        rom[208] = {8'd2,8'd13,8'd0,8'd0,2'd2};
        rom[209] = {8'd11,8'd19,8'd0,8'd0,2'd2};
        rom[210] = {8'd2,8'd3,8'd5,8'd7,2'd4};
        rom[211] = {8'd211,8'd0,8'd0,8'd0,2'd1};
        rom[212] = {8'd2,8'd53,8'd0,8'd0,2'd2};
        rom[213] = {8'd3,8'd71,8'd0,8'd0,2'd2};
        rom[214] = {8'd2,8'd107,8'd0,8'd0,2'd2};
        rom[215] = {8'd5,8'd43,8'd0,8'd0,2'd2};
        rom[216] = {8'd2,8'd3,8'd0,8'd0,2'd2};
        rom[217] = {8'd7,8'd31,8'd0,8'd0,2'd2};
        rom[218] = {8'd2,8'd109,8'd0,8'd0,2'd2};
        rom[219] = {8'd3,8'd73,8'd0,8'd0,2'd2};
        rom[220] = {8'd2,8'd5,8'd11,8'd0,2'd3};
        rom[221] = {8'd13,8'd17,8'd0,8'd0,2'd2};
        rom[222] = {8'd2,8'd3,8'd37,8'd0,2'd3};
        rom[223] = {8'd223,8'd0,8'd0,8'd0,2'd1};
        rom[224] = {8'd2,8'd7,8'd0,8'd0,2'd2};
        rom[225] = {8'd3,8'd5,8'd0,8'd0,2'd2};
        rom[226] = {8'd2,8'd113,8'd0,8'd0,2'd2};
        rom[227] = {8'd227,8'd0,8'd0,8'd0,2'd1};
        rom[228] = {8'd2,8'd3,8'd19,8'd0,2'd3};
        rom[229] = {8'd229,8'd0,8'd0,8'd0,2'd1};
        rom[230] = {8'd2,8'd5,8'd23,8'd0,2'd3};
        rom[231] = {8'd3,8'd7,8'd11,8'd0,2'd3};
        rom[232] = {8'd2,8'd29,8'd0,8'd0,2'd2};
        rom[233] = {8'd233,8'd0,8'd0,8'd0,2'd1};
        rom[234] = {8'd2,8'd3,8'd13,8'd0,2'd3};
        rom[235] = {8'd5,8'd47,8'd0,8'd0,2'd2};
        rom[236] = {8'd2,8'd59,8'd0,8'd0,2'd2};
        rom[237] = {8'd3,8'd79,8'd0,8'd0,2'd2};
        rom[238] = {8'd2,8'd7,8'd17,8'd0,2'd3};
        rom[239] = {8'd239,8'd0,8'd0,8'd0,2'd1};
        rom[240] = {8'd2,8'd3,8'd5,8'd0,2'd3};
        rom[241] = {8'd241,8'd0,8'd0,8'd0,2'd1};
        rom[242] = {8'd2,8'd11,8'd0,8'd0,2'd2};
        rom[243] = {8'd3,8'd81,8'd0,8'd0,2'd2};
        rom[244] = {8'd2,8'd61,8'd0,8'd0,2'd2};
        rom[245] = {8'd5,8'd7,8'd0,8'd0,2'd2};
        rom[246] = {8'd2,8'd3,8'd41,8'd0,2'd3};
        rom[247] = {8'd13,8'd19,8'd0,8'd0,2'd2};
        rom[248] = {8'd2,8'd31,8'd0,8'd0,2'd2};
        rom[249] = {8'd7,8'd35,8'd0,8'd0,2'd2};
        rom[250] = {8'd2,8'd5,8'd0,8'd0,2'd2};
        rom[251] = {8'd251,8'd0,8'd0,8'd0,2'd1};
        rom[252] = {8'd2,8'd3,8'd7,8'd0,2'd3};
        rom[253] = {8'd11,8'd23,8'd0,8'd0,2'd2};
        rom[254] = {8'd2,8'd127,8'd0,8'd0,2'd2};
        rom[255] = {8'd3,8'd5,8'd17,8'd0,2'd3};
    end
    
    // Current number and factors
    wire [7:0] current_num = arr_reg[index];
    wire [33:0] factors = rom[current_num];
    wire [7:0] factor0 = factors[33:26];
    wire [7:0] factor1 = factors[25:18];
    wire [7:0] factor2 = factors[17:10];
    wire [7:0] factor3 = factors[9:2];
    wire [1:0] factor_cnt = factors[1:0];
    
    // Read DP values for factors
    wire [7:0] dp0 = (factor_cnt > 0) ? dp_reg[factor0] : 8'd0;
    wire [7:0] dp1 = (factor_cnt > 1) ? dp_reg[factor1] : 8'd0;
    wire [7:0] dp2 = (factor_cnt > 2) ? dp_reg[factor2] : 8'd0;
    wire [7:0] dp3 = (factor_cnt > 3) ? dp_reg[factor3] : 8'd0;
    
    // Compute max_prev
    wire [7:0] max1 = (dp0 > dp1) ? dp0 : dp1;
    wire [7:0] max2 = (dp2 > dp3) ? dp2 : dp3;
    wire [7:0] max_prev = (max1 > max2) ? max1 : max2;
    wire [7:0] current_length = max_prev + 1;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            index <= 0;
            overall_max <= 0;
            // Reset DP registers
            integer i;
            for (i=0; i<256; i=i+1) dp_reg[i] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Capture inputs
                        arr_reg[0] <= arr_0; arr_reg[1] <= arr_1; arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3; arr_reg[4] <= arr_4; arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6; arr_reg[7] <= arr_7; arr_reg[8] <= arr_8;
                        arr_reg[9] <= arr_9; arr_reg[10] <= arr_10; arr_reg[11] <= arr_11;
                        arr_reg[12] <= arr_12; arr_reg[13] <= arr_13; arr_reg[14] <= arr_14;
                        arr_reg[15] <= arr_15;
                        len_reg <= len;
                        index <= 4'd0;
                        overall_max <= 8'd0;
                        state <= PROCESS;
                    end
                end
                PROCESS: begin
                    // Update overall_max
                    if (current_length > overall_max) 
                        overall_max <= current_length;
                    
                    // Update DP registers for valid factors
                    if (factor_cnt > 0 && current_length > dp_reg[factor0]) 
                        dp_reg[factor0] <= current_length;
                    if (factor_cnt > 1 && current_length > dp_reg[factor1]) 
                        dp_reg[factor1] <= current_length;
                    if (factor_cnt > 2 && current_length > dp_reg[factor2]) 
                        dp_reg[factor2] <= current_length;
                    if (factor_cnt > 3 && current_length > dp_reg[factor3]) 
                        dp_reg[factor3] <= current_length;
                    
                    // Next element or done
                    if (index + 1 == len_reg) 
                        state <= DONE;
                    else 
                        index <= index + 1;
                end
                DONE: begin
                    done <= 1;
                    result <= overall_max;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule