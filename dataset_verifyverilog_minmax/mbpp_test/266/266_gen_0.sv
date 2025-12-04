module lateral_surface_cube(
  input reg [15:0] side,
  output reg [31:0] lsa
);
  // LSA of a cube (4 * side^2) computed combinatorially
  always @(*) begin
    lsa = side * side * 4;
  end
endmodule