module tuple_subtract (
  input signed [7:0] tuple1_0,
  input signed [7:0] tuple1_1,
  input signed [7:0] tuple1_2,
  input signed [7:0] tuple2_0,
  input signed [7:0] tuple2_1,
  input signed [7:0] tuple2_2,
  output signed [7:0] result_0,
  output signed [7:0] result_1,
  output signed [7:0] result_2
);

  assign result_0 = tuple1_0 - tuple2_0;
  assign result_1 = tuple1_1 - tuple2_1;
  assign result_2 = tuple1_2 - tuple2_2;

endmodule