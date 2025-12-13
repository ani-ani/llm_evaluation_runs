module pairwise_add (
  input  [7:0][3:0] in_array,
  output [6:0][4:0] out_array
);

  assign out_array[0] = in_array[0] + in_array[1];
  assign out_array[1] = in_array[1] + in_array[2];
  assign out_array[2] = in_array[2] + in_array[3];
  assign out_array[3] = in_array[3] + in_array[4];
  assign out_array[4] = in_array[4] + in_array[5];
  assign out_array[5] = in_array[5] + in_array[6];
  assign out_array[6] = in_array[6] + in_array[7];

endmodule