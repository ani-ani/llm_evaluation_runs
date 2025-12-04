module truncate_fixed (
  input  wire [31:0] number, // Q16.16 format: bits [31:16] = integer, [15:0] = fractional
  output wire [15:0] decimal // fractional part (Q16 format)
);
  assign decimal = number[15:0]; // directly output lower 16 bits (fractional part)
endmodule