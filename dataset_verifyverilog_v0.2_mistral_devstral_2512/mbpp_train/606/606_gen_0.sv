module deg_to_rad (
  input [15:0] degree,
  output [31:0] radian
);
  
  // Precomputed constant for π/180 in Q16.16 format (0x0000477)
  localparam [31:0] PI_OVER_180 = 32'h0000477;
  
  // Convert degree from Q8.8 to Q16.16 by left-shifting by 8 bits
  wire [31:0] degree_q16_16 = {degree, 16'h0000};
  
  // Multiply by π/180 constant (result is Q32.32)
  wire [63:0] product = $signed(degree_q16_16) * $signed(PI_OVER_180);
  
  // Right-shift by 16 bits to normalize to Q16.16
  assign radian = product[47:16];
  
endmodule