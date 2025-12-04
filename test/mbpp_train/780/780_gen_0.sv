module tuple_sum_combinations(
  input  [5:0] tuple_0_0,
  input  [5:0] tuple_0_1,
  input  [5:0] tuple_1_0,
  input  [5:0] tuple_1_1,
  input  [5:0] tuple_2_0,
  input  [5:0] tuple_2_1,
  input  [5:0] tuple_3_0,
  input  [5:0] tuple_3_1,
  output [5:0] result_0_0,
  output [5:0] result_0_1,
  output [5:0] result_1_0,
  output [5:0] result_1_1,
  output [5:0] result_2_0,
  output [5:0] result_2_1,
  output [5:0] result_3_0,
  output [5:0] result_3_1,
  output [5:0] result_4_0,
  output [5:0] result_4_1,
  output [5:0] result_5_0,
  output [5:0] result_5_1
);

  assign result_0_0 = tuple_0_0 + tuple_1_0;
  assign result_0_1 = tuple_0_1 + tuple_1_1;

  assign result_1_0 = tuple_0_0 + tuple_2_0;
  assign result_1_1 = tuple_0_1 + tuple_2_1;

  assign result_2_0 = tuple_0_0 + tuple_3_0;
  assign result_2_1 = tuple_0_1 + tuple_3_1;

  assign result_3_0 = tuple_1_0 + tuple_2_0;
  assign result_3_1 = tuple_1_1 + tuple_2_1;

  assign result_4_0 = tuple_1_0 + tuple_3_0;
  assign result_4_1 = tuple_1_1 + tuple_3_1;

  assign result_5_0 = tuple_2_0 + tuple_3_0;
  assign result_5_1 = tuple_2_1 + tuple_3_1;

endmodule