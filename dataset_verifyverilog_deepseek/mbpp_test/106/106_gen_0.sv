module append_arrays(
  input [3:0] tuple_array[1:0],
  input [3:0] list_array[2:0],
  output [3:0] result_array[4:0]
);
  assign result_array[0] = tuple_array[0];
  assign result_array[1] = tuple_array[1];
  assign result_array[2] = list_array[0];
  assign result_array[3] = list_array[1];
  assign result_array[4] = list_array[2];
endmodule