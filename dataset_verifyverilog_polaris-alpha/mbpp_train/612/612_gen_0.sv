module array_transposer(
  input  [3:0][3:0][7:0] arr_in,
  output [3:0][3:0][7:0] arr_out
);

  assign arr_out[0][0] = arr_in[0][0];
  assign arr_out[0][1] = arr_in[1][0];
  assign arr_out[0][2] = arr_in[2][0];
  assign arr_out[0][3] = arr_in[3][0];

  assign arr_out[1][0] = arr_in[0][1];
  assign arr_out[1][1] = arr_in[1][1];
  assign arr_out[1][2] = arr_in[2][1];
  assign arr_out[1][3] = arr_in[3][1];

  assign arr_out[2][0] = arr_in[0][2];
  assign arr_out[2][1] = arr_in[1][2];
  assign arr_out[2][2] = arr_in[2][2];
  assign arr_out[2][3] = arr_in[3][2];

  assign arr_out[3][0] = arr_in[0][3];
  assign arr_out[3][1] = arr_in[1][3];
  assign arr_out[3][2] = arr_in[2][3];
  assign arr_out[3][3] = arr_in[3][3];

endmodule