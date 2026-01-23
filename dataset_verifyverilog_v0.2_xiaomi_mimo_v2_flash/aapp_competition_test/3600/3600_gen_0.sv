module basin_city_drones(
    input [7:0] k,
    input [7:0] n,
    input [7:0] adj_0,
    input [7:0] adj_1,
    input [7:0] adj_2,
    input [7:0] adj_3,
    input [7:0] adj_4,
    input [7:0] adj_5,
    input [7:0] adj_6,
    input [7:0] adj_7,
    output reg possible
);

    // Concatenate adjacency inputs into an array for easier indexing
    wire [7:0] adj [0:7];
    assign adj[0] = adj_0;
    assign adj[1] = adj_1;
    assign adj[2] = adj_2;
    assign adj[3] = adj_3;
    assign adj[4] = adj_4;
    assign adj[5] = adj_5;
    assign adj[6] = adj_6;
    assign adj[7] = adj_7;

    // Mask to ignore nodes >= n
    // If n=8, mask=8'hFF. If n=5, mask=8'h1F (bits 0-4 set).
    wire [7:0] node_mask;
    assign node_mask = (n >= 8) ? 8'hFF : 
                      (n == 7) ? 8'h7F : 
                      (n == 6) ? 8'h3F : 
                      (n == 5) ? 8'h1F : 
                      (n == 4) ? 8'h0F : 
                      (n == 3) ? 8'h07 : 
                      (n == 2) ? 8'h03 : 
                      (n == 1) ? 8'h01 : 8'h00;

    // Intermediate signals for each placement (256 possible placements)
    wire valid_p [0:255];
    wire [7:0] popcount_p [0:255];

    genvar i, j;
    generate
        // Iterate over all possible placements P (0 to 255)
        for (i = 0; i < 256; i = i + 1) begin : gen_placements
            // Extract the placement bitmask, but mask out unused nodes
            wire [7:0] P_masked;
            assign P_masked = i[7:0] & node_mask;

            // Calculate popcount for this placement (on masked P)
            // Using behavioral addition for synthesis efficiency
            wire [7:0] p_sum;
            assign p_sum = {
                1'b0, P_masked[7], P_masked[6], P_masked[5], P_masked[4],
                P_masked[3], P_masked[2], P_masked[1], P_masked[0]
            };
            // Partial sums
            wire [2:0] pc;
            assign pc = P_masked[0] + P_masked[1] + P_masked[2] + P_masked[3] +
                        P_masked[4] + P_masked[5] + P_masked[6] + P_masked[7];
            assign popcount_p[i] = pc;

            // Validate placement
            // Check: For every node i set in P_masked, no adjacent node is set in P_masked.
            // Simplified check: (P_masked & adj[i]) == 0 for all i in P_masked.
            // Or equivalently: (P_masked & (adj[0]|adj[1]|...)) == 0 is NOT sufficient.
            // We need: For each j where P_masked[j] is 1, (P_masked & adj[j]) == 0.
            
            // Compute a validity mask.
            // A placement is invalid if: (P_masked & adj[i]) != 0 for any i where P_masked[i]==1.
            // This is equivalent to: ((P_masked & adj[0]) & P_masked) | ... != 0? No.
            // Let's do it explicitly with a loop over nodes.
            
            wire conflict;
            assign conflict = 
                (P_masked[0] && (P_masked & adj[0] != 0)) ||
                (P_masked[1] && (P_masked & adj[1] != 0)) ||
                (P_masked[2] && (P_masked & adj[2] != 0)) ||
                (P_masked[3] && (P_masked & adj[3] != 0)) ||
                (P_masked[4] && (P_masked & adj[4] != 0)) ||
                (P_masked[5] && (P_masked & adj[5] != 0)) ||
                (P_masked[6] && (P_masked & adj[6] != 0)) ||
                (P_masked[7] && (P_masked & adj[7] != 0));
            
            // Note: The (P_masked & adj[X]) != 0 check must be careful about zero.
            // If P_masked[X] is 0, the condition (P_masked & adj[X]) != 0 might be true
            // if adj[X] has bits set that overlap with other P_masked bits.
            // However, we only check this term if P_masked[X] == 1.
            // So: (P_masked[X] && ((P_masked & adj[X]) != 0))
            // Let's implement the bit-wise check cleanly.
            
            wire [7:0] conflicts;
            assign conflicts[0] = P_masked[0] && ((P_masked & adj[0]) != 0);
            assign conflicts[1] = P_masked[1] && ((P_masked & adj[1]) != 0);
            assign conflicts[2] = P_masked[2] && ((P_masked & adj[2]) != 0);
            assign conflicts[3] = P_masked[3] && ((P_masked & adj[3]) != 0);
            assign conflicts[4] = P_masked[4] && ((P_masked & adj[4]) != 0);
            assign conflicts[5] = P_masked[5] && ((P_masked & adj[5]) != 0);
            assign conflicts[6] = P_masked[6] && ((P_masked & adj[6]) != 0);
            assign conflicts[7] = P_masked[7] && ((P_masked & adj[7]) != 0);

            assign valid_p[i] = (conflicts == 8'h0);
        end
    endgenerate

    // Check if any valid placement matches k
    always @(*) begin
        possible = 0;
        // Check all 256 placements
        // Unrolled for synthesis efficiency
        if (valid_p[0] && popcount_p[0] == k) possible = 1;
        if (valid_p[1] && popcount_p[1] == k) possible = 1;
        if (valid_p[2] && popcount_p[2] == k) possible = 1;
        if (valid_p[3] && popcount_p[3] == k) possible = 1;
        if (valid_p[4] && popcount_p[4] == k) possible = 1;
        if (valid_p[5] && popcount_p[5] == k) possible = 1;
        if (valid_p[6] && popcount_p[6] == k) possible = 1;
        if (valid_p[7] && popcount_p[7] == k) possible = 1;
        if (valid_p[8] && popcount_p[8] == k) possible = 1;
        if (valid_p[9] && popcount_p[9] == k) possible = 1;
        if (valid_p[10] && popcount_p[10] == k) possible = 1;
        if (valid_p[11] && popcount_p[11] == k) possible = 1;
        if (valid_p[12] && popcount_p[12] == k) possible = 1;
        if (valid_p[13] && popcount_p[13] == k) possible = 1;
        if (valid_p[14] && popcount_p[14] == k) possible = 1;
        if (valid_p[15] && popcount_p[15] == k) possible = 1;
        if (valid_p[16] && popcount_p[16] == k) possible = 1;
        if (valid_p[17] && popcount_p[17] == k) possible = 1;
        if (valid_p[18] && popcount_p[18] == k) possible = 1;
        if (valid_p[19] && popcount_p[19] == k) possible = 1;
        if (valid_p[20] && popcount_p[20] == k) possible = 1;
        if (valid_p[21] && popcount_p[21] == k) possible = 1;
        if (valid_p[22] && popcount_p[22] == k) possible = 1;
        if (valid_p[23] && popcount_p[23] == k) possible = 1;
        if (valid_p[24] && popcount_p[24] == k) possible = 1;
        if (valid_p[25] && popcount_p[25] == k) possible = 1;
        if (valid_p[26] && popcount_p[26] == k) possible = 1;
        if (valid_p[27] && popcount_p[27] == k) possible = 1;
        if (valid_p[28] && popcount_p[28] == k) possible = 1;
        if (valid_p[29] && popcount_p[29] == k) possible = 1;
        if (valid_p[30] && popcount_p[30] == k) possible = 1;
        if (valid_p[31] && popcount_p[31] == k) possible = 1;
        if (valid_p[32] && popcount_p[32] == k) possible = 1;
        if (valid_p[33] && popcount_p[33] == k) possible = 1;
        if (valid_p[34] && popcount_p[34] == k) possible = 1;
        if (valid_p[35] && popcount_p[35] == k) possible = 1;
        if (valid_p[36] && popcount_p[36] == k) possible = 1;
        if (valid_p[37] && popcount_p[37] == k) possible = 1;
        if (valid_p[38] && popcount_p[38] == k) possible = 1;
        if (valid_p[39] && popcount_p[39] == k) possible = 1;
        if (valid_p[40] && popcount_p[40] == k) possible = 1;
        if (valid_p[41] && popcount_p[41] == k) possible = 1;
        if (valid_p[42] && popcount_p[42] == k) possible = 1;
        if (valid_p[43] && popcount_p[43] == k) possible = 1;
        if (valid_p[44] && popcount_p[44] == k) possible = 1;
        if (valid_p[45] && popcount_p[45] == k) possible = 1;
        if (valid_p[46] && popcount_p[46] == k) possible = 1;
        if (valid_p[47] && popcount_p[47] == k) possible = 1;
        if (valid_p[48] && popcount_p[48] == k) possible = 1;
        if (valid_p[49] && popcount_p[49] == k) possible = 1;
        if (valid_p[50] && popcount_p[50] == k) possible = 1;
        if (valid_p[51] && popcount_p[51] == k) possible = 1;
        if (valid_p[52] && popcount_p[52] == k) possible = 1;
        if (valid_p[53] && popcount_p[53] == k) possible = 1;
        if (valid_p[54] && popcount_p[54] == k) possible = 1;
        if (valid_p[55] && popcount_p[55] == k) possible = 1;
        if (valid_p[56] && popcount_p[56] == k) possible = 1;
        if (valid_p[57] && popcount_p[57] == k) possible = 1;
        if (valid_p[58] && popcount_p[58] == k) possible = 1;
        if (valid_p[59] && popcount_p[59] == k) possible = 1;
        if (valid_p[60] && popcount_p[60] == k) possible = 1;
        if (valid_p[61] && popcount_p[61] == k) possible = 1;
        if (valid_p[62] && popcount_p[62] == k) possible = 1;
        if (valid_p[63] && popcount_p[63] == k) possible = 1;
        if (valid_p[64] && popcount_p[64] == k) possible = 1;
        if (valid_p[65] && popcount_p[65] == k) possible = 1;
        if (valid_p[66] && popcount_p[66] == k) possible = 1;
        if (valid_p[67] && popcount_p[67] == k) possible = 1;
        if (valid_p[68] && popcount_p[68] == k) possible = 1;
        if (valid_p[69] && popcount_p[69] == k) possible = 1;
        if (valid_p[70] && popcount_p[70] == k) possible = 1;
        if (valid_p[71] && popcount_p[71] == k) possible = 1;
        if (valid_p[72] && popcount_p[72] == k) possible = 1;
        if (valid_p[73] && popcount_p[73] == k) possible = 1;
        if (valid_p[74] && popcount_p[74] == k) possible = 1;
        if (valid_p[75] && popcount_p[75] == k) possible = 1;
        if (valid_p[76] && popcount_p[76] == k) possible = 1;
        if (valid_p[77] && popcount_p[77] == k) possible = 1;
        if (valid_p[78] && popcount_p[78] == k) possible = 1;
        if (valid_p[79] && popcount_p[79] == k) possible = 1;
        if (valid_p[80] && popcount_p[80] == k) possible = 1;
        if (valid_p[81] && popcount_p[81] == k) possible = 1;
        if (valid_p[82] && popcount_p[82] == k) possible = 1;
        if (valid_p[83] && popcount_p[83] == k) possible = 1;
        if (valid_p[84] && popcount_p[84] == k) possible = 1;
        if (valid_p[85] && popcount_p[85] == k) possible = 1;
        if (valid_p[86] && popcount_p[86] == k) possible = 1;
        if (valid_p[87] && popcount_p[87] == k) possible = 1;
        if (valid_p[88] && popcount_p[88] == k) possible = 1;
        if (valid_p[89] && popcount_p[89] == k) possible = 1;
        if (valid_p[90] && popcount_p[90] == k) possible = 1;
        if (valid_p[91] && popcount_p[91] == k) possible = 1;
        if (valid_p[92] && popcount_p[92] == k) possible = 1;
        if (valid_p[93] && popcount_p[93] == k) possible = 1;
        if (valid_p[94] && popcount_p[94] == k) possible = 1;
        if (valid_p[95] && popcount_p[95] == k) possible = 1;
        if (valid_p[96] && popcount_p[96] == k) possible = 1;
        if (valid_p[97] && popcount_p[97] == k) possible = 1;
        if (valid_p[98] && popcount_p[98] == k) possible = 1;
        if (valid_p[99] && popcount_p[99] == k) possible = 1;
        if (valid_p[100] && popcount_p[100] == k) possible = 1;
        if (valid_p[101] && popcount_p[101] == k) possible = 1;
        if (valid_p[102] && popcount_p[102] == k) possible = 1;
        if (valid_p[103] && popcount_p[103] == k) possible = 1;
        if (valid_p[104] && popcount_p[104] == k) possible = 1;
        if (valid_p[105] && popcount_p[105] == k) possible = 1;
        if (valid_p[106] && popcount_p[106] == k) possible = 1;
        if (valid_p[107] && popcount_p[107] == k) possible = 1;
        if (valid_p[108] && popcount_p[108] == k) possible = 1;
        if (valid_p[109] && popcount_p[109] == k) possible = 1;
        if (valid_p[110] && popcount_p[110] == k) possible = 1;
        if (valid_p[111] && popcount_p[111] == k) possible = 1;
        if (valid_p[112] && popcount_p[112] == k) possible = 1;
        if (valid_p[113] && popcount_p[113] == k) possible = 1;
        if (valid_p[114] && popcount_p[114] == k) possible = 1;
        if (valid_p[115] && popcount_p[115] == k) possible = 1;
        if (valid_p[116] && popcount_p[116] == k) possible = 1;
        if (valid_p[117] && popcount_p[117] == k) possible = 1;
        if (valid_p[118] && popcount_p[118] == k) possible = 1;
        if (valid_p[119] && popcount_p[119] == k) possible = 1;
        if (valid_p[120] && popcount_p[120] == k) possible = 1;
        if (valid_p[121] && popcount_p[121] == k) possible = 1;
        if (valid_p[122] && popcount_p[122] == k) possible = 1;
        if (valid_p[123] && popcount_p[123] == k) possible = 1;
        if (valid_p[124] && popcount_p[124] == k) possible = 1;
        if (valid_p[125] && popcount_p[125] == k) possible = 1;
        if (valid_p[126] && popcount_p[126] == k) possible = 1;
        if (valid_p[127] && popcount_p[127] == k) possible = 1;
        if (valid_p[128] && popcount_p[128] == k) possible = 1;
        if (valid_p[129] && popcount_p[129] == k) possible = 1;
        if (valid_p[130] && popcount_p[130] == k) possible = 1;
        if (valid_p[131] && popcount_p[131] == k) possible = 1;
        if (valid_p[132] && popcount_p[132] == k) possible = 1;
        if (valid_p[133] && popcount_p[133] == k) possible = 1;
        if (valid_p[134] && popcount_p[134] == k) possible = 1;
        if (valid_p[135] && popcount_p[135] == k) possible = 1;
        if (valid_p[136] && popcount_p[136] == k) possible = 1;
        if (valid_p[137] && popcount_p[137] == k) possible = 1;
        if (valid_p[138] && popcount_p[138] == k) possible = 1;
        if (valid_p[139] && popcount_p[139] == k) possible = 1;
        if (valid_p[140] && popcount_p[140] == k) possible = 1;
        if (valid_p[141] && popcount_p[141] == k) possible = 1;
        if (valid_p[142] && popcount_p[142] == k) possible = 1;
        if (valid_p[143] && popcount_p[143] == k) possible = 1;
        if (valid_p[144] && popcount_p[144] == k) possible = 1;
        if (valid_p[145] && popcount_p[145] == k) possible = 1;
        if (valid_p[146] && popcount_p[146] == k) possible = 1;
        if (valid_p[147] && popcount_p[147] == k) possible = 1;
        if (valid_p[148] && popcount_p[148] == k) possible = 1;
        if (valid_p[149] && popcount_p[149] == k) possible = 1;
        if (valid_p[150] && popcount_p[150] == k) possible = 1;
        if (valid_p[151] && popcount_p[151] == k) possible = 1;
        if (valid_p[152] && popcount_p[152] == k) possible = 1;
        if (valid_p[153] && popcount_p[153] == k) possible = 1;
        if (valid_p[154] && popcount_p[154] == k) possible = 1;
        if (valid_p[155] && popcount_p[155] == k) possible = 1;
        if (valid_p[156] && popcount_p[156] == k) possible = 1;
        if (valid_p[157] && popcount_p[157] == k) possible = 1;
        if (valid_p[158] && popcount_p[158] == k) possible = 1;
        if (valid_p[159] && popcount_p[159] == k) possible = 1;
        if (valid_p[160] && popcount_p[160] == k) possible = 1;
        if (valid_p[161] && popcount_p[161] == k) possible = 1;
        if (valid_p[162] && popcount_p[162] == k) possible = 1;
        if (valid_p[163] && popcount_p[163] == k) possible = 1;
        if (valid_p[164] && popcount_p[164] == k) possible = 1;
        if (valid_p[165] && popcount_p[165] == k) possible = 1;
        if (valid_p[166] && popcount_p[166] == k) possible = 1;
        if (valid_p[167] && popcount_p[167] == k) possible = 1;
        if (valid_p[168] && popcount_p[168] == k) possible = 1;
        if (valid_p[169] && popcount_p[169] == k) possible = 1;
        if (valid_p[170] && popcount_p[170] == k) possible = 1;
        if (valid_p[171] && popcount_p[171] == k) possible = 1;
        if (valid_p[172] && popcount_p[172] == k) possible = 1;
        if (valid_p[173] && popcount_p[173] == k) possible = 1;
        if (valid_p[174] && popcount_p[174] == k) possible = 1;
        if (valid_p[175] && popcount_p[175] == k) possible = 1;
        if (valid_p[176] && popcount_p[176] == k) possible = 1;
        if (valid_p[177] && popcount_p[177] == k) possible = 1;
        if (valid_p[178] && popcount_p[178] == k) possible = 1;
        if (valid_p[179] && popcount_p[179] == k) possible = 1;
        if (valid_p[180] && popcount_p[180] == k) possible = 1;
        if (valid_p[181] && popcount_p[181] == k) possible = 1;
        if (valid_p[182] && popcount_p[182] == k) possible = 1;
        if (valid_p[183] && popcount_p[183] == k) possible = 1;
        if (valid_p[184] && popcount_p[184] == k) possible = 1;
        if (valid_p[185] && popcount_p[185] == k) possible = 1;
        if (valid_p[186] && popcount_p[186] == k) possible = 1;
        if (valid_p[187] && popcount_p[187] == k) possible = 1;
        if (valid_p[188] && popcount_p[188] == k) possible = 1;
        if (valid_p[189] && popcount_p[189] == k) possible = 1;
        if (valid_p[190] && popcount_p[190] == k) possible = 1;
        if (valid_p[191] && popcount_p[191] == k) possible = 1;
        if (valid_p[192] && popcount_p[192] == k) possible = 1;
        if (valid_p[193] && popcount_p[193] == k) possible = 1;
        if (valid_p[194] && popcount_p[194] == k) possible = 1;
        if (valid_p[195] && popcount_p[195] == k) possible = 1;
        if (valid_p[196] && popcount_p[196] == k) possible = 1;
        if (valid_p[197] && popcount_p[197] == k) possible = 1;
        if (valid_p[198] && popcount_p[198] == k) possible = 1;
        if (valid_p[199] && popcount_p[199] == k) possible = 1;
        if (valid_p[200] && popcount_p[200] == k) possible = 1;
        if (valid_p[201] && popcount_p[201] == k) possible = 1;
        if (valid_p[202] && popcount_p[202] == k) possible = 1;
        if (valid_p[203] && popcount_p[203] == k) possible = 1;
        if (valid_p[204] && popcount_p[204] == k) possible = 1;
        if (valid_p[205] && popcount_p[205] == k) possible = 1;
        if (valid_p[206] && popcount_p[206] == k) possible = 1;
        if (valid_p[207] && popcount_p[207] == k) possible = 1;
        if (valid_p[208] && popcount_p[208] == k) possible = 1;
        if (valid_p[209] && popcount_p[209] == k) possible = 1;
        if (valid_p[210] && popcount_p[210] == k) possible = 1;
        if (valid_p[211] && popcount_p[211] == k) possible = 1;
        if (valid_p[212] && popcount_p[212] == k) possible = 1;
        if (valid_p[213] && popcount_p[213] == k) possible = 1;
        if (valid_p[214] && popcount_p[214] == k) possible = 1;
        if (valid_p[215] && popcount_p[215] == k) possible = 1;
        if (valid_p[216] && popcount_p[216] == k) possible = 1;
        if (valid_p[217] && popcount_p[217] == k) possible = 1;
        if (valid_p[218] && popcount_p[218] == k) possible = 1;
        if (valid_p[219] && popcount_p[219] == k) possible = 1;
        if (valid_p[220] && popcount_p[220] == k) possible = 1;
        if (valid_p[221] && popcount_p[221] == k) possible = 1;
        if (valid_p[222] && popcount_p[222] == k) possible = 1;
        if (valid_p[223] && popcount_p[223] == k) possible = 1;
        if (valid_p[224] && popcount_p[224] == k) possible = 1;
        if (valid_p[225] && popcount_p[225] == k) possible = 1;
        if (valid_p[226] && popcount_p[226] == k) possible = 1;
        if (valid_p[227] && popcount_p[227] == k) possible = 1;
        if (valid_p[228] && popcount_p[228] == k) possible = 1;
        if (valid_p[229] && popcount_p[229] == k) possible = 1;
        if (valid_p[230] && popcount_p[230] == k) possible = 1;
        if (valid_p[231] && popcount_p[231] == k) possible = 1;
        if (valid_p[232] && popcount_p[232] == k) possible = 1;
        if (valid_p[233] && popcount_p[233] == k) possible = 1;
        if (valid_p[234] && popcount_p[234] == k) possible = 1;
        if (valid_p[235] && popcount_p[235] == k) possible = 1;
        if (valid_p[236] && popcount_p[236] == k) possible = 1;
        if (valid_p[237] && popcount_p[237] == k) possible = 1;
        if (valid_p[238] && popcount_p[238] == k) possible = 1;
        if (valid_p[239] && popcount_p[239] == k) possible = 1;
        if (valid_p[240] && popcount_p[240] == k) possible = 1;
        if (valid_p[241] && popcount_p[241] == k) possible = 1;
        if (valid_p[242] && popcount_p[242] == k) possible = 1;
        if (valid_p[243] && popcount_p[243] == k) possible = 1;
        if (valid_p[244] && popcount_p[244] == k) possible = 1;
        if (valid_p[245] && popcount_p[245] == k) possible = 1;
        if (valid_p[246] && popcount_p[246] == k) possible = 1;
        if (valid_p[247] && popcount_p[247] == k) possible = 1;
        if (valid_p[248] && popcount_p[248] == k) possible = 1;
        if (valid_p[249] && popcount_p[249] == k) possible = 1;
        if (valid_p[250] && popcount_p[250] == k) possible = 1;
        if (valid_p[251] && popcount_p[251] == k) possible = 1;
        if (valid_p[252] && popcount_p[252] == k) possible = 1;
        if (valid_p[253] && popcount_p[253] == k) possible = 1;
        if (valid_p[254] && popcount_p[254] == k) possible = 1;
        if (valid_p[255] && popcount_p[255] == k) possible = 1;
    end

endmodule
