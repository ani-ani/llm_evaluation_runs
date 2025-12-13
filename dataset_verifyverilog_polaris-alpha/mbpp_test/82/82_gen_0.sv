module sphere_volume(
  input  [31:0] radius,
  output [31:0] volume
);

  // Stage 1: radius_cubed = radius * radius * radius (96-bit intermediate)
  wire [63:0] radius_sq;
  wire [95:0] radius_cubed;

  assign radius_sq    = radius * radius;              // 32x32 -> 64 bits
  assign radius_cubed = radius_sq * radius;           // 64x32 -> 96 bits

  // Stage 2: Multiply by (4/3)*pi constant (0x00043172) using 64-bit intermediate
  // Use lower 32 bits of radius_cubed as specified for the 64-bit intermediate step
  localparam [31:0] CONST_4_3_PI = 32'h00043172;      // (4/3)*pi in Q16.16

  wire [63:0] mult_result;
  assign mult_result = radius_cubed[31:0] * CONST_4_3_PI; // 32x32 -> 64 bits

  // Stage 3: Right-shift by 32 bits to maintain Q16.16 format
  assign volume = mult_result[63:32];

endmodule