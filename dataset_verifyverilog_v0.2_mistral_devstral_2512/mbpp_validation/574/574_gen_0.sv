module surfacearea_cylinder (
  input [31:0] r,
  input [31:0] h,
  output [31:0] result
);

  // Constants in Q16.16 format
  localparam [31:0] PI_Q16_16 = 32'h323AF; // 3.1415 * 65536 = 205887
  localparam [31:0] TWO_PI_Q16_16 = 32'h6485E; // 6.283 * 65536 = 411774

  // Compute r_squared = r * r (64-bit intermediate, take upper 32 bits)
  wire [63:0] r_squared_extended = $signed(r) * $signed(r);
  wire [31:0] r_squared = r_squared_extended[63:32];

  // Compute term1 = 2 * π * r_squared
  wire [63:0] term1_extended = $signed(TWO_PI_Q16_16) * $signed(r_squared);
  wire [31:0] term1 = term1_extended[63:32];

  // Compute term2 = 2 * π * r * h
  wire [63:0] r_h_extended = $signed(r) * $signed(h);
  wire [31:0] r_h = r_h_extended[63:32];
  wire [63:0] term2_extended = $signed(TWO_PI_Q16_16) * $signed(r_h);
  wire [31:0] term2 = term2_extended[63:32];

  // result = term1 + term2
  assign result = term1 + term2;

endmodule