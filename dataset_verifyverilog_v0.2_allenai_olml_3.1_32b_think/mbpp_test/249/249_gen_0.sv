module array_intersection(
   input [7:0] array1 [0:7],
   input [7:0] array2 [0:7],
   input [2:0] len1,
   input [2:0] len2,
   output [7:0] result [0:7],
   output [7:0] result_valid
);

reg [2:0] len1_int = len1;
reg [2:0] len2_int = len2;

assign enable_0 = (0 < len1_int) ? 1'b1 : 1'b0;
assign enable_1 = (1 < len1_int) ? 1'b1 : 1'b0;
assign enable_2 = (2 < len1_int) ? 1'b1 : 1'b0;
assign enable_3 = (3 < len1_int) ? 1'b1 : 1'b0;
assign enable_4 = (4 < len1_int) ? 1'b1 : 1'b0;
assign enable_5 = (5 < len1_int) ? 1'b1 : 1'b0;
assign enable_6 = (6 < len1_int) ? 1'b1 : 1'b0;
assign enable_7 = (7 < len1_int) ? 1'b1 : 1'b0;

assign in_range_0 = (0 < len2_int) ? 1'b1 : 1'b0;
assign in_range_1 = (1 < len2_int) ? 1'b1 : 1'b0;
assign in_range_2 = (2 < len2_int) ? 1'b1 : 1'b0;
assign in_range_3 = (3 < len2_int) ? 1'b1 : 1'b0;
assign in_range_4 = (4 < len2_int) ? 1'b1 : 1'b0;
assign in_range_5 = (5 < len2_int) ? 1'b1 : 1'b0;
assign in_range_6 = (6 < len2_int) ? 1'b1 : 1'b0;
assign in_range_7 = (7 < len2_int) ? 1'b1 : 1'b0;

assign match_0 = (array1[0] == array2[0]) & enable_0 | (array1[1] == array2[0]) & enable_1 | (array1[2] == array2[0]) & enable_2 | (array1[3] == array2[0]) & enable_3 | (array1[4] == array2[0]) & enable_4 | (array1[5] == array2[0]) & enable_5 | (array1[6] == array2[0]) & enable_6 | (array1[7] == array2[0]) & enable_7;
assign match_1 = (array1[0] == array2[1]) & enable_0 | (array1[1] == array2[1]) & enable_1 | (array1[2] == array2[1]) & enable_2 | (array1[3] == array2[1]) & enable_3 | (array1[4] == array2[1]) & enable_4 | (array1[5] == array2[1]) & enable_5 | (array1[6] == array2[1]) & enable_6 | (array1[7] == array2[1]) & enable_7;
assign match_2 = (array1[0] == array2[2]) & enable_0 | (array1[1] == array2[2]) & enable_1 | (array1[2] == array2[2]) & enable_2 | (array1[3] == array2[2]) & enable_3 | (array1[4] == array2[2]) & enable_4 | (array1[5] == array2[2]) & enable_5 | (array1[6] == array2[2]) & enable_6 | (array1[7] == array2[2]) & enable_7;
assign match_3 = (array1[0] == array2[3]) & enable_0 | (array1[1] == array2[3]) & enable_1 | (array1[2] == array2[3]) & enable_2 | (array1[3] == array2[3]) & enable_3 | (array1[4] == array2[3]) & enable_4 | (array1[5] == array2[3]) & enable_5 | (array1[6] == array2[3]) & enable_6 | (array1[7] == array2[3]) & enable_7;
assign match_4 = (array1[0] == array2[4]) & enable_0 | (array1[1] == array2[4]) & enable_1 | (array1[2] == array2[4]) & enable_2 | (array1[3] == array2[4]) & enable_3 | (array1[4] == array2[4]) & enable_4 | (array1[5] == array2[4]) & enable_5 | (array1[6] == array2[4]) & enable_6 | (array1[7] == array2[4]) & enable_7;
assign match_5 = (array1[0] == array2[5]) & enable_0 | (array1[1] == array2[5]) & enable_1 | (array1[2] == array2[5]) & enable_2 | (array1[3] == array2[5]) & enable_3 | (array1[4] == array2[5]) & enable_4 | (array1[5] == array2[5]) & enable_5 | (array1[6] == array2[5]) & enable_6 | (array1[7] == array2[5]) & enable_7;
assign match_6 = (array1[0] == array2[6]) & enable_0 | (array1[1] == array2[6]) & enable_1 | (array1[2] == array2[6]) & enable_2 | (array1[3] == array2[6]) & enable_3 | (array1[4] == array2[6]) & enable_4 | (array1[5] == array2[6]) & enable_5 | (array1[6] == array2[6]) & enable_6 | (array1[7] == array2[6]) & enable_7;
assign match_7 = (array1[0] == array2[7]) & enable_0 | (array1[1] == array2[7]) & enable_1 | (array1[2] == array2[7]) & enable_2 | (array1[3] == array2[7]) & enable_3 | (array1[4] == array2[7]) & enable_4 | (array1[5] == array2[7]) & enable_5 | (array1[6] == array2[7]) & enable_6 | (array1[7] == array2[7]) & enable_7;

assign valid_0 = in_range_0 & match_0;
assign valid_1 = in_range_1 & match_1;
assign valid_2 = in_range_2 & match_2;
assign valid_3 = in_range_3 & match_3;
assign valid_4 = in_range_4 & match_4;
assign valid_5 = in_range_5 & match_5;
assign valid_6 = in_range_6 & match_6;
assign valid_7 = in_range_7 & match_7;

assign cnt_valid_0 = valid_0 ? 1 : 0;
assign cnt_valid_1 = cnt_valid_0 + (valid_1 ? 1 : 0);
assign cnt_valid_2 = cnt_valid_1 + (valid_2 ? 1 : 0);
assign cnt_valid_3 = cnt_valid_2 + (valid_3 ? 1 : 0);
assign cnt_valid_4 = cnt_valid_3 + (valid_4 ? 1 : 0);
assign cnt_valid_5 = cnt_valid_4 + (valid_5 ? 1 : 0);
assign cnt_valid_6 = cnt_valid_5 + (valid_6 ? 1 : 0);
assign cnt_valid_7 = cnt_valid_6 + (valid_7 ? 1 : 0);

assign result_valid_0 = (0 < cnt_valid_7) ? 1'b1 : 1'b0;
assign result_valid_1 = (1 < cnt_valid_7) ? 1'b1 : 1'b0;
assign result_valid_2 = (2 < cnt_valid_7) ? 1'b1 : 1'b0;
assign result_valid_3 = (3 < cnt_valid_7) ? 1'b1 : 1'b0;
assign result_valid_4 = (4 < cnt_valid_7) ? 1'b1 : 1'b0;
assign result_valid_5 = (5 < cnt_valid_7) ? 1'b1 : 1'b0;
assign result_valid_6 = (6 < cnt_valid_7) ? 1'b1 : 1'b0;
assign result_valid_7 = (7 < cnt_valid_7) ? 1'b1 : 1'b0;

assign result_0 = (valid_0 && 1'b1) ? array2[0] : (valid_1 && (cnt_valid_0 == 0)) ? array2[1] : (valid_2 && (cnt_valid_1 == 0)) ? array2[2] : (valid_3 && (cnt_valid_2 == 0)) ? array2[3] : (valid_4 && (cnt_valid_3 == 0)) ? array2[4] : (valid_5 && (cnt_valid_4 == 0)) ? array2[5] : (valid_6 && (cnt_valid_5 == 0)) ? array2[6] : (valid_7 && (cnt_valid_6 == 0)) ? array2[7] : 0;
assign result_1 = (valid_1 && (cnt_valid_0 == 1)) ? array2[1] : (valid_2 && (cnt_valid_1 == 1)) ? array2[2] : (valid_3 && (cnt_valid_2 == 1)) ? array2[3] : (valid_4 && (cnt_valid_3 == 1)) ? array2[4] : (valid_5 && (cnt_valid_4 == 1)) ? array2[5] : (valid_6 && (cnt_valid_5 == 1)) ? array2[6] : (valid_7 && (cnt_valid_6 == 1)) ? array2[7] : 0;
assign result_2 = (valid_2 && (cnt_valid_1 == 2)) ? array2[2] : (valid_3 && (cnt_valid_2 == 2)) ? array2[3] : (valid_4 && (cnt_valid_3 == 2)) ? array2[4] : (valid_5 && (cnt_valid_4 == 2)) ? array2[5] : (valid_6 && (cnt_valid_5 == 2)) ? array2[6] : (valid_7 && (cnt_valid_6 == 2)) ? array2[7] : 0;
assign result_3 = (valid_3 && (cnt_valid_2 == 3)) ? array2[3] : (valid_4 && (cnt_valid_3 == 3)) ? array2[4] : (valid_5 && (cnt_valid_4 == 3)) ? array2[5] : (valid_6 && (cnt_valid_5 == 3)) ? array2[6] : (valid_7 && (cnt_valid_6 == 3)) ? array2[7] : 0;
assign result_4 = (valid_4 && (cnt_valid_3 ==4)) ? array2[4] : (valid_5 && (cnt_valid_4 ==4)) ? array2[5] : (valid_6 && (cnt_valid_5 ==4)) ? array2[6] : (valid_7 && (cnt_valid_6 ==4)) ? array2[7] : 0;
assign result_5 = (valid_5 && (cnt_valid_4 ==5)) ? array2[5] : (valid_6 && (cnt_valid_5 ==5)) ? array2[6] : (valid_7 && (cnt_valid_6 ==5)) ? array2[7] : 0;
assign result_6 = (valid_6 && (cnt_valid_5 ==6)) ? array2[6] : (valid_7 && (cnt_valid_6 ==6)) ? array2[7] : 0;
assign result_7 = (valid_7 && (cnt_valid_6 ==7)) ? array2[7] : 0;

assign result = {result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7};
assign result_valid = {result_valid_0, result_valid_1, result_valid_2, result_valid_3, result_valid_4, result_valid_5, result_valid_6, result_valid_7};

endmodule