module add_tuple (
  input [3:0][7:0] list_in,
  input [1:0][7:0] tuple_in,
  output [5:0][7:0] result
);

  assign result[0] = list_in[0];
  assign result[1] = list_in[1];
  assign result[2] = list_in[2];
  assign result[3] = list_in[3];
  assign result[4] = tuple_in[0];
  assign result[5] = tuple_in[1];

endmodule