module sphere_surface_area (
  input [31:0] radius,
  output [31:0] surface_area
);

  // PI constant in Q16.16 format (3.14159265359)
  localparam PI_Q16_16 = 32'h0003243F;

  // Step 1: Square the radius (r * r)
  wire [63:0] r_squared_full = $signed(radius) * $signed(radius);
  wire [31:0] r_squared = r_squared_full[47:16]; // Q16.16 result

  // Step 2: Multiply by PI (PI * r_squared)
  wire [63:0] pi_times_r_squared_full = $signed(PI_Q16_16) * $signed(r_squared);
  wire [31:0] pi_times_r_squared = pi_times_r_squared_full[47:16]; // Q16.16 result

  // Step 3: Multiply by 4 (4 * pi_times_r_squared)
  wire [63:0] result_full = 4 * $signed(pi_times_r_squared);
  assign surface_area = result_full[47:16]; // Q16.16 result

endmodule