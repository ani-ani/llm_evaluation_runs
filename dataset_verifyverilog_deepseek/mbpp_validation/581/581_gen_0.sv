module pyramid_surface(input [3:0] b, input [3:0] s, output [9:0] area);
  assign area = (2 * b * s) + (b * b);
endmodule