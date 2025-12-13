module surface_area_sphere(
  input  [7:0]  r,
  output [31:0] surfacearea
);

  // Step 1: radius squared (16-bit)
  wire [15:0] r_sq;
  assign r_sq = r * r;

  // Step 2: 4*pi constant in Q16.16 (0x000C90FD)
  localparam [31:0] FOUR_PI_Q16_16 = 32'h000C90FD;

  // Step 3: Multiply r_sq (16-bit) by FOUR_PI_Q16_16 (Q16.16)
  // Result: 48-bit, still in Q16.16 format due to integer interpretation.
  wire [47:0] mult_full;
  assign mult_full = r_sq * FOUR_PI_Q16_16;

  // Step 4: Take lower 32 bits as Q16.16 surface area
  assign surfacearea = mult_full[31:0];

endmodule