module tuple_size_calculator(
  input  [31:0] tuple_data,
  output [7:0]  byte_size
);

  // Fixed tuple of 4 elements, each 1 byte
  assign byte_size = 8'd4;

endmodule