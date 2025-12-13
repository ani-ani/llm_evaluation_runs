module adjacent_multiplier(
  input  [4:0][7:0]   in_tuple,
  output [3:0][15:0]  out_tuple
);

  assign out_tuple[0] = in_tuple[0] * in_tuple[1];
  assign out_tuple[1] = in_tuple[1] * in_tuple[2];
  assign out_tuple[2] = in_tuple[2] * in_tuple[3];
  assign out_tuple[3] = in_tuple[3] * in_tuple[4];

endmodule