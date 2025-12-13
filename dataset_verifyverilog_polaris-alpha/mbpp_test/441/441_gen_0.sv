module surface_area_cube(
  input  [7:0]  l,
  output [15:0] surface_area
);

  assign surface_area = 6 * l * l;

endmodule