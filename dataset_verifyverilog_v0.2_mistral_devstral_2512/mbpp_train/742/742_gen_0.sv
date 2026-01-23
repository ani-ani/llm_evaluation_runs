module tetrahedron_area (
  input [15:0] side,
  output [31:0] area
);
  
  // Q16.16 representation of sqrt(3) = 1.7320508075688772
  localparam [31:0] SQRT_3 = 32'h0001BC28;
  
  // Calculate side squared (16.16 * 16.16 = 32.32)
  wire [31:0] side_squared = $signed({16'h0, side}) * $signed({16'h0, side});
  
  // Multiply by sqrt(3) and shift right by 16 to get back to Q16.16
  wire [31:0] product = side_squared * SQRT_3;
  
  // Final result (Q16.16 format)
  assign area = product >>> 16;
  
endmodule