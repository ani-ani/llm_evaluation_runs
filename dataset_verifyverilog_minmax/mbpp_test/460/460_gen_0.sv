module extract_first (
  output wire [31:0] result,
  input  wire [127:0] flat_array
);

  // result = {first element of sublist 0,
  //           first element of sublist 1,
  //           first element of sublist 2,
  //           first element of sublist 3}
  // Sublist 0: bits[127:96] -> first element at bits[127:120]
  // Sublist 1: bits[95:64]  -> first element at bits[95:88]
  // Sublist 2: bits[63:32]  -> first element at bits[63:56]
  // Sublist 3: bits[31:0]   -> first element at bits[31:24]
  assign result = {
    flat_array[127:120],
    flat_array[95:88],
    flat_array[63:56],
    flat_array[31:24]
  };

endmodule
