module sum_non_repeated (
  input [7:0] arr_0,
  input [7:0] arr_1,
  input [7:0] arr_2,
  input [7:0] arr_3,
  input [7:0] arr_4,
  input [7:0] arr_5,
  input [7:0] arr_6,
  input [7:0] arr_7,
  output [15:0] sum
);

  // Sorting network for 8 elements (combinational bubble sort)
  wire [7:0] sorted [0:7];

  // Stage 1
  assign sorted[0] = (arr_0 < arr_1) ? arr_0 : arr_1;
  assign sorted[1] = (arr_0 < arr_1) ? arr_1 : arr_0;
  assign sorted[2] = (arr_2 < arr_3) ? arr_2 : arr_3;
  assign sorted[3] = (arr_2 < arr_3) ? arr_3 : arr_2;
  assign sorted[4] = (arr_4 < arr_5) ? arr_4 : arr_5;
  assign sorted[5] = (arr_4 < arr_5) ? arr_5 : arr_4;
  assign sorted[6] = (arr_6 < arr_7) ? arr_6 : arr_7;
  assign sorted[7] = (arr_6 < arr_7) ? arr_7 : arr_6;

  // Stage 2
  wire [7:0] stage2 [0:7];
  assign stage2[0] = (sorted[0] < sorted[2]) ? sorted[0] : sorted[2];
  assign stage2[1] = (sorted[1] < sorted[3]) ? sorted[1] : sorted[3];
  assign stage2[2] = (sorted[0] < sorted[2]) ? sorted[2] : sorted[0];
  assign stage2[3] = (sorted[1] < sorted[3]) ? sorted[3] : sorted[1];
  assign stage2[4] = (sorted[4] < sorted[6]) ? sorted[4] : sorted[6];
  assign stage2[5] = (sorted[5] < sorted[7]) ? sorted[5] : sorted[7];
  assign stage2[6] = (sorted[4] < sorted[6]) ? sorted[6] : sorted[4];
  assign stage2[7] = (sorted[5] < sorted[7]) ? sorted[7] : sorted[5];

  // Stage 3
  wire [7:0] stage3 [0:7];
  assign stage3[0] = (stage2[0] < stage2[1]) ? stage2[0] : stage2[1];
  assign stage3[1] = (stage2[0] < stage2[1]) ? stage2[1] : stage2[0];
  assign stage3[2] = (stage2[2] < stage2[3]) ? stage2[2] : stage2[3];
  assign stage3[3] = (stage2[2] < stage2[3]) ? stage2[3] : stage2[2];
  assign stage3[4] = (stage2[4] < stage2[5]) ? stage2[4] : stage2[5];
  assign stage3[5] = (stage2[4] < stage2[5]) ? stage2[5] : stage2[4];
  assign stage3[6] = (stage2[6] < stage2[7]) ? stage2[6] : stage2[7];
  assign stage3[7] = (stage2[6] < stage2[7]) ? stage2[7] : stage2[6];

  // Stage 4
  wire [7:0] stage4 [0:7];
  assign stage4[0] = (stage3[0] < stage3[4]) ? stage3[0] : stage3[4];
  assign stage4[1] = (stage3[1] < stage3[5]) ? stage3[1] : stage3[5];
  assign stage4[2] = (stage3[2] < stage3[6]) ? stage3[2] : stage3[6];
  assign stage4[3] = (stage3[3] < stage3[7]) ? stage3[3] : stage3[7];
  assign stage4[4] = (stage3[0] < stage3[4]) ? stage3[4] : stage3[0];
  assign stage4[5] = (stage3[1] < stage3[5]) ? stage3[5] : stage3[1];
  assign stage4[6] = (stage3[2] < stage3[6]) ? stage3[6] : stage3[2];
  assign stage4[7] = (stage3[3] < stage3[7]) ? stage3[7] : stage3[3];

  // Stage 5
  wire [7:0] stage5 [0:7];
  assign stage5[0] = (stage4[0] < stage4[2]) ? stage4[0] : stage4[2];
  assign stage5[1] = (stage4[1] < stage4[3]) ? stage4[1] : stage4[3];
  assign stage5[2] = (stage4[0] < stage4[2]) ? stage4[2] : stage4[0];
  assign stage5[3] = (stage4[1] < stage4[3]) ? stage4[3] : stage4[1];
  assign stage5[4] = (stage4[4] < stage4[6]) ? stage4[4] : stage4[6];
  assign stage5[5] = (stage4[5] < stage4[7]) ? stage4[5] : stage4[7];
  assign stage5[6] = (stage4[4] < stage4[6]) ? stage4[6] : stage4[4];
  assign stage5[7] = (stage4[5] < stage4[7]) ? stage4[7] : stage4[5];

  // Stage 6
  wire [7:0] stage6 [0:7];
  assign stage6[0] = (stage5[0] < stage5[1]) ? stage5[0] : stage5[1];
  assign stage6[1] = (stage5[0] < stage5[1]) ? stage5[1] : stage5[0];
  assign stage6[2] = (stage5[2] < stage5[3]) ? stage5[2] : stage5[3];
  assign stage6[3] = (stage5[2] < stage5[3]) ? stage5[3] : stage5[2];
  assign stage6[4] = (stage5[4] < stage5[5]) ? stage5[4] : stage5[5];
  assign stage6[5] = (stage5[4] < stage5[5]) ? stage5[5] : stage5[4];
  assign stage6[6] = (stage5[6] < stage5[7]) ? stage5[6] : stage5[7];
  assign stage6[7] = (stage5[6] < stage5[7]) ? stage5[7] : stage5[6];

  // Final sorted array
  assign sorted[0] = stage6[0];
  assign sorted[1] = stage6[1];
  assign sorted[2] = stage6[2];
  assign sorted[3] = stage6[3];
  assign sorted[4] = stage6[4];
  assign sorted[5] = stage6[5];
  assign sorted[6] = stage6[6];
  assign sorted[7] = stage6[7];

  // Sum non-repeated elements
  wire [15:0] sum_temp;
  assign sum_temp = (sorted[0] != sorted[1]) ? sorted[0] : 0;
  assign sum_temp = sum_temp + ((sorted[1] != sorted[0]) && (sorted[1] != sorted[2])) ? sorted[1] : 0;
  assign sum_temp = sum_temp + ((sorted[2] != sorted[1]) && (sorted[2] != sorted[3])) ? sorted[2] : 0;
  assign sum_temp = sum_temp + ((sorted[3] != sorted[2]) && (sorted[3] != sorted[4])) ? sorted[3] : 0;
  assign sum_temp = sum_temp + ((sorted[4] != sorted[3]) && (sorted[4] != sorted[5])) ? sorted[4] : 0;
  assign sum_temp = sum_temp + ((sorted[5] != sorted[4]) && (sorted[5] != sorted[6])) ? sorted[5] : 0;
  assign sum_temp = sum_temp + ((sorted[6] != sorted[5]) && (sorted[6] != sorted[7])) ? sorted[6] : 0;
  assign sum_temp = sum_temp + (sorted[7] != sorted[6]) ? sorted[7] : 0;

  assign sum = sum_temp;

endmodule