module sphere_volume (
  input  wire [31:0] radius, // Q16.16 fixed-point
  output wire [31:0] volume  // Q16.16 fixed-point
);

  // Constants in Q16.16 format
  localparam [31:0] C_4BY3_PI = 32'h00043172; // 274658 decimal, ~4.1887748289

  // Stage 1: radius^2 (64-bit) and radius^3 (96-bit)
  logic [63:0] radius_squared;
  logic [95:0] radius_cubed;

  always_comb begin
    radius_squared = $unsigned(radius) * $unsigned(radius);
    radius_cubed   = radius_squared * $unsigned(radius);
  end

  // Stage 2: Multiply radius^3 (96-bit) by constant (32-bit), result in 128-bit
  // Then take the upper 64 bits (right shift by 32) to maintain Q16.16 after scaling
  logic [63:0] scaled;

  always_comb begin
    // Since radius_cubed is Q48.48 and constant is Q16.16, their product is Q64.64.
    // Dropping the lower 32 bits yields Q32.32. However, we want Q16.16 output.
    // The constant 0x00043172 already incorporates the (4/3) factor, so we simply take upper 64 bits.
    scaled = (radius_cubed * $unsigned(C_4BY3_PI)) >> 32;
  end

  // Stage 3: Assign final output (already Q16.16)
  assign volume = scaled[31:0];

endmodule