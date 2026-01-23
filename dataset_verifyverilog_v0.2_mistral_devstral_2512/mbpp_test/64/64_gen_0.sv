module sort_tuples (
  input [15:0] tuple_0,
  input [15:0] tuple_1,
  input [15:0] tuple_2,
  input [15:0] tuple_3,
  output [15:0] sorted_0,
  output [15:0] sorted_1,
  output [15:0] sorted_2,
  output [15:0] sorted_3
);

  // Stage 1: Compare (0,1) and (2,3)
  wire [15:0] stage1_0, stage1_1, stage1_2, stage1_3;
  assign stage1_0 = (tuple_0[15:8] > tuple_1[15:8]) ? tuple_1 : tuple_0;
  assign stage1_1 = (tuple_0[15:8] > tuple_1[15:8]) ? tuple_0 : tuple_1;
  assign stage1_2 = (tuple_2[15:8] > tuple_3[15:8]) ? tuple_3 : tuple_2;
  assign stage1_3 = (tuple_2[15:8] > tuple_3[15:8]) ? tuple_2 : tuple_3;

  // Stage 2: Compare (1,2) only
  wire [15:0] stage2_0, stage2_1, stage2_2, stage2_3;
  assign stage2_0 = stage1_0;
  assign stage2_1 = (stage1_1[15:8] > stage1_2[15:8]) ? stage1_2 : stage1_1;
  assign stage2_2 = (stage1_1[15:8] > stage1_2[15:8]) ? stage1_1 : stage1_2;
  assign stage2_3 = stage1_3;

  // Stage 3: Compare (0,1) and (2,3) only
  assign sorted_0 = (stage2_0[15:8] > stage2_1[15:8]) ? stage2_1 : stage2_0;
  assign sorted_1 = (stage2_0[15:8] > stage2_1[15:8]) ? stage2_0 : stage2_1;
  assign sorted_2 = (stage2_2[15:8] > stage2_3[15:8]) ? stage2_3 : stage2_2;
  assign sorted_3 = (stage2_2[15:8] > stage2_3[15:8]) ? stage2_2 : stage2_3;

endmodule