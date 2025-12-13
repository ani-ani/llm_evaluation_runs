module nested_tuple_adder(
  input  [39:0] tuple1_flattened,
  input  [39:0] tuple2_flattened,
  output [39:0] result_flattened
);

  // Each element is 5 bits, laid out as:
  // {row3[1], row3[0], row2[1], row2[0], row1[1], row1[0], row0[1], row0[0]}

  assign result_flattened[4:0]    = tuple1_flattened[4:0]    + tuple2_flattened[4:0];
  assign result_flattened[9:5]    = tuple1_flattened[9:5]    + tuple2_flattened[9:5];
  assign result_flattened[14:10]  = tuple1_flattened[14:10]  + tuple2_flattened[14:10];
  assign result_flattened[19:15]  = tuple1_flattened[19:15]  + tuple2_flattened[19:15];
  assign result_flattened[24:20]  = tuple1_flattened[24:20]  + tuple2_flattened[24:20];
  assign result_flattened[29:25]  = tuple1_flattened[29:25]  + tuple2_flattened[29:25];
  assign result_flattened[34:30]  = tuple1_flattened[34:30]  + tuple2_flattened[34:30];
  assign result_flattened[39:35]  = tuple1_flattened[39:35]  + tuple2_flattened[39:35];

endmodule