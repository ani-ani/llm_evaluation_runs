module pyramid_area (
  input [31:0] base_edge,
  input [31:0] slant_height,
  output [31:0] surface_area
);

  wire [31:0] base_squared;
  wire [31:0] lateral_area;

  // Compute base_squared = base_edge * base_edge (Q16.16 * Q16.16 = Q32.32, then truncate to Q16.16)
  assign base_squared = (base_edge * base_edge) >>> 16;

  // Compute lateral_area = 2 * base_edge * slant_height (Q16.16 * Q16.16 = Q32.32, then truncate to Q16.16)
  assign lateral_area = (2 * base_edge * slant_height) >>> 16;

  // Compute surface_area = lateral_area + base_squared (Q16.16 + Q16.16 = Q16.16)
  assign surface_area = lateral_area + base_squared;

endmodule