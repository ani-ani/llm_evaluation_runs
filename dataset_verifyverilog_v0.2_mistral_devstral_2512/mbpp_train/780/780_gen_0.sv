module tuple_combinations (
  input [7:0] tuple_0_x,
  input [7:0] tuple_0_y,
  input [7:0] tuple_1_x,
  input [7:0] tuple_1_y,
  input [7:0] tuple_2_x,
  input [7:0] tuple_2_y,
  input [7:0] tuple_3_x,
  input [7:0] tuple_3_y,
  output [7:0] sum_0_1_x,
  output [7:0] sum_0_1_y,
  output [7:0] sum_0_2_x,
  output [7:0] sum_0_2_y,
  output [7:0] sum_0_3_x,
  output [7:0] sum_0_3_y,
  output [7:0] sum_1_2_x,
  output [7:0] sum_1_2_y,
  output [7:0] sum_1_3_x,
  output [7:0] sum_1_3_y,
  output [7:0] sum_2_3_x,
  output [7:0] sum_2_3_y
);

  assign sum_0_1_x = tuple_0_x + tuple_1_x;
  assign sum_0_1_y = tuple_0_y + tuple_1_y;
  assign sum_0_2_x = tuple_0_x + tuple_2_x;
  assign sum_0_2_y = tuple_0_y + tuple_2_y;
  assign sum_0_3_x = tuple_0_x + tuple_3_x;
  assign sum_0_3_y = tuple_0_y + tuple_3_y;
  assign sum_1_2_x = tuple_1_x + tuple_2_x;
  assign sum_1_2_y = tuple_1_y + tuple_2_y;
  assign sum_1_3_x = tuple_1_x + tuple_3_x;
  assign sum_1_3_y = tuple_1_y + tuple_3_y;
  assign sum_2_3_x = tuple_2_x + tuple_3_x;
  assign sum_2_3_y = tuple_2_y + tuple_3_y;

endmodule