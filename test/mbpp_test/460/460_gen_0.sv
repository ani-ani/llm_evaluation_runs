module extract_first(
  input  [127:0] flat_array,
  output [31:0]  result
);

  assign result = {flat_array[127:120], flat_array[95:88], flat_array[63:56], flat_array[31:24]};

endmodule