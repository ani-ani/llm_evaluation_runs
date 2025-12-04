module pyramid_surface (
  input [3:0] b, // Base edge length
  input [3:0] s, // Slant height
  output [9:0] area // Surface area
);
  // Compute area = 2*b*s + b*b (unsigned)
  assign area = (10)'(2 * b * s) + (10)'(b * b);
endmodule