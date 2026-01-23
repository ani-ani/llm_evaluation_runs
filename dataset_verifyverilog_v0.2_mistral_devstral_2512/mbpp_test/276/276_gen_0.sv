module cylinder_volume (
  input [15:0] radius,
  input [15:0] height,
  output [31:0] volume
);

  // Fixed-point approximation for π in Q16.16 format
  localparam PI_Q16_16 = 32'h3243F;

  // Scale inputs to Q16.16 format
  wire [31:0] radius_q16_16 = {radius, 16'h0000};
  wire [31:0] height_q16_16 = {height, 16'h0000};

  // Compute r² in Q16.16 format
  wire [63:0] r_squared = $signed(radius_q16_16) * $signed(radius_q16_16);

  // Multiply r² by π
  wire [63:0] r_squared_times_pi = $signed(r_squared[63:0]) * $signed(PI_Q16_16);

  // Multiply result by height
  wire [63:0] final_product = $signed(r_squared_times_pi[63:0]) * $signed(height_q16_16);

  // Extract middle 32 bits (Q16.16 format)
  assign volume = final_product[47:16];

endmodule