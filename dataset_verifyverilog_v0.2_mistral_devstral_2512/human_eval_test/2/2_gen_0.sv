module truncate_number (
  input [31:0] number_in,
  output [31:0] decimal_out
);

  // Extract the fractional part (lower 16 bits) and zero-extend to 32 bits
  assign decimal_out = {16'h0000, number_in[15:0]};

endmodule