module elementwise_and(
  input  [19:0] tuple1,
  input  [19:0] tuple2,
  output [19:0] result_tuple
);

  assign result_tuple[4:0]    = tuple1[4:0]    & tuple2[4:0];
  assign result_tuple[9:5]    = tuple1[9:5]    & tuple2[9:5];
  assign result_tuple[14:10]  = tuple1[14:10]  & tuple2[14:10];
  assign result_tuple[19:15]  = tuple1[19:15]  & tuple2[19:15];

endmodule