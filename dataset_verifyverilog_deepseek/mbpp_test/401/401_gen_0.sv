module nested_tuple_adder (
  input [39:0] tuple1_flattened,
  input [39:0] tuple2_flattened,
  output [39:0] result_flattened
);

  assign result_flattened = {
    (tuple1_flattened[39:35] + tuple2_flattened[39:35]),
    (tuple1_flattened[34:30] + tuple2_flattened[34:30]),
    (tuple1_flattened[29:25] + tuple2_flattened[29:25]),
    (tuple1_flattened[24:20] + tuple2_flattened[24:20]),
    (tuple1_flattened[19:15] + tuple2_flattened[19:15]),
    (tuple1_flattened[14:10] + tuple2_flattened[14:10]),
    (tuple1_flattened[9:5] + tuple2_flattened[9:5]),
    (tuple1_flattened[4:0] + tuple2_flattened[4:0])
  };

endmodule