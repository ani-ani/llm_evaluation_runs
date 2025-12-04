module lateral_surface_cube (input [15:0] side, output [31:0] lsa);
  assign lsa = 4 * (side * side);
endmodule