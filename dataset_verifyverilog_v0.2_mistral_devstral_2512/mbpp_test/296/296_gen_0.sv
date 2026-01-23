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

  // Generate all 28 comparison results
  wire [27:0] comparisons;
  assign comparisons[0] = (arr_0 > arr_1);
  assign comparisons[1] = (arr_0 > arr_2);
  assign comparisons[2] = (arr_0 > arr_3);
  assign comparisons[3] = (arr_0 > arr_4);
  assign comparisons[4] = (arr_0 > arr_5);
  assign comparisons[5] = (arr_0 > arr_6);
  assign comparisons[6] = (arr_0 > arr_7);
  assign comparisons[7] = (arr_1 > arr_2);
  assign comparisons[8] = (arr_1 > arr_3);
  assign comparisons[9] = (arr_1 > arr_4);
  assign comparisons[10] = (arr_1 > arr_5);
  assign comparisons[11] = (arr_1 > arr_6);
  assign comparisons[12] = (arr_1 > arr_7);
  assign comparisons[13] = (arr_2 > arr_3);
  assign comparisons[14] = (arr_2 > arr_4);
  assign comparisons[15] = (arr_2 > arr_5);
  assign comparisons[16] = (arr_2 > arr_6);
  assign comparisons[17] = (arr_2 > arr_7);
  assign comparisons[18] = (arr_3 > arr_4);
  assign comparisons[19] = (arr_3 > arr_5);
  assign comparisons[20] = (arr_3 > arr_6);
  assign comparisons[21] = (arr_3 > arr_7);
  assign comparisons[22] = (arr_4 > arr_5);
  assign comparisons[23] = (arr_4 > arr_6);
  assign comparisons[24] = (arr_4 > arr_7);
  assign comparisons[25] = (arr_5 > arr_6);
  assign comparisons[26] = (arr_5 > arr_7);
  assign comparisons[27] = (arr_6 > arr_7);

  // Tree of adders to sum all comparison results
  wire [3:0] sum1_0 = comparisons[0] + comparisons[1] + comparisons[2] + comparisons[3];
  wire [3:0] sum1_1 = comparisons[4] + comparisons[5] + comparisons[6] + comparisons[7];
  wire [3:0] sum1_2 = comparisons[8] + comparisons[9] + comparisons[10] + comparisons[11];
  wire [3:0] sum1_3 = comparisons[12] + comparisons[13] + comparisons[14] + comparisons[15];
  wire [3:0] sum1_4 = comparisons[16] + comparisons[17] + comparisons[18] + comparisons[19];
  wire [3:0] sum1_5 = comparisons[20] + comparisons[21] + comparisons[22] + comparisons[23];
  wire [3:0] sum1_6 = comparisons[24] + comparisons[25] + comparisons[26] + comparisons[27];

  wire [4:0] sum2_0 = sum1_0 + sum1_1;
  wire [4:0] sum2_1 = sum1_2 + sum1_3;
  wire [4:0] sum2_2 = sum1_4 + sum1_5;
  wire [4:0] sum2_3 = sum1_6;

  wire [5:0] sum3_0 = sum2_0 + sum2_1;
  wire [5:0] sum3_1 = sum2_2 + sum2_3;

  wire [6:0] sum4_0 = sum3_0 + sum3_1;

  assign inv_count = sum4_0;

endmodule