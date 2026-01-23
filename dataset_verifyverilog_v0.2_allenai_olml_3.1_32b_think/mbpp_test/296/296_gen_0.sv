module inversion_counter (
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output [7:0] inv_count
);

wire [27:0] compares;

assign compares[0] = arr_0 > arr_1;
assign compares[1] = arr_0 > arr_2;
assign compares[2] = arr_0 > arr_3;
assign compares[3] = arr_0 > arr_4;
assign compares[4] = arr_0 > arr_5;
assign compares[5] = arr_0 > arr_6;
assign compares[6] = arr_0 > arr_7;
assign compares[7] = arr_1 > arr_2;
assign compares[8] = arr_1 > arr_3;
assign compares[9] = arr_1 > arr_4;
assign compares[10] = arr_1 > arr_5;
assign compares[11] = arr_1 > arr_6;
assign compares[12] = arr_1 > arr_7;
assign compares[13] = arr_2 > arr_3;
assign compares[14] = arr_2 > arr_4;
assign compares[15] = arr_2 > arr_5;
assign compares[16] = arr_2 > arr_6;
assign compares[17] = arr_2 > arr_7;
assign compares[18] = arr_3 > arr_4;
assign compares[19] = arr_3 > arr_5;
assign compares[20] = arr_3 > arr_6;
assign compares[21] = arr_3 > arr_7;
assign compares[22] = arr_4 > arr_5;
assign compares[23] = arr_4 > arr_6;
assign compares[24] = arr_4 > arr_7;
assign compares[25] = arr_5 > arr_6;
assign compares[26] = arr_5 > arr_7;
assign compares[27] = arr_6 > arr_7;

wire [1:0] level1 [0:13];
assign level1[0] = compares[0] + compares[1];
assign level1[1] = compares[2] + compares[3];
assign level1[2] = compares[4] + compares[5];
assign level1[3] = compares[6] + compares[7];
assign level1[4] = compares[8] + compares[9];
assign level1[5] = compares[10] + compares[11];
assign level1[6] = compares[12] + compares[13];
assign level1[7] = compares[14] + compares[15];
assign level1[8] = compares[16] + compares[17];
assign level1[9] = compares[18] + compares[19];
assign level1[10] = compares[20] + compares[21];
assign level1[11] = compares[22] + compares[23];
assign level1[12] = compares[24] + compares[25];
assign level1[13] = compares[26] + compares[27];

wire [2:0] level2 [0:6];
assign level2[0] = level1[0] + level1[1];
assign level2[1] = level1[2] + level1[3];
assign level2[2] = level1[4] + level1[5];
assign level2[3] = level1[6] + level1[7];
assign level2[4] = level1[8] + level1[9];
assign level2[5] = level1[10] + level1[11];
assign level2[6] = level1[12] + level1[13];

wire [3:0] level3 [0:3];
assign level3[0] = level2[0] + level2[1];
assign level3[1] = level2[2] + level2[3];
assign level3[2] = level2[4] + level2[5];
assign level3[3] = level2[6];

wire [4:0] level4 [0:1];
assign level4[0] = level3[0] + level3[1];
assign level4[1] = level3[2] + level3[3];

wire [5:0] final_sum;
assign final_sum = level4[0] + level4[1];

assign inv_count = {2'b0, final_sum};

endmodule