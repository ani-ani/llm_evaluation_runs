module lateral_surface_cube(
  input  [15:0] side,
  output [31:0] lsa
);

  wire [31:0] side_sq;

  assign side_sq = side * side;
  assign lsa     = 4 * side_sq;

endmodule