module nested_tuple_adder (
  input [39:0] tuple1_flattened,
  input [39:0] tuple2_flattened,
  output [39:0] result_flattened
);
  // Element-wise addition of 4x2 nested tuples (5-bit elements)
  // Flattened layout: {row3[1], row3[0], row2[1], row2[0], row1[1], row1[0], row0[1], row0[0]}
  assign result_flattened[39:35] = tuple1_flattened[39:35] + tuple2_flattened[39:35]; // row3[1]
  assign result_flattened[34:30] = tuple1_flattened[34:30] + tuple2_flattened[34:30]; // row3[0]
  assign result_flattened[29:25] = tuple1_flattened[29:25] + tuple2_flattened[29:25]; // row2[1]
  assign result_flattened[24:20] = tuple1_flattened[24:20] + tuple2_flattened[24:20]; // row2[0]
  assign result_flattened[19:15] = tuple1_flattened[19:15] + tuple2_flattened[19:15]; // row1[1]
  assign result_flattened[14:10] = tuple1_flattened[14:10] + tuple2_flattened[14:10]; // row1[0]
  assign result_flattened[9:5]   = tuple1_flattened[9:5]   + tuple2_flattened[9:5];   // row0[1]
  assign result_flattened[4:0]   = tuple1_flattened[4:0]   + tuple2_flattened[4:0];   // row0[0]
endmodule