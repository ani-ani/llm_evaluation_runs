module elementwise_subtractor(
  input  signed [6:0] tuple1 [3:0],
  input  signed [6:0] tuple2 [3:0],
  output signed [6:0] result [3:0]
);

  // Element-wise signed subtraction
  assign result[0] = tuple1[0] - tuple2[0];
  assign result[1] = tuple1[1] - tuple2[1];
  assign result[2] = tuple1[2] - tuple2[2];
  assign result[3] = tuple1[3] - tuple2[3];

endmodule