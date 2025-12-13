module pyramid_surface(
  input  [3:0] b,
  input  [3:0] s,
  output [9:0] area
);

  wire [7:0] mult_bs;
  wire [8:0] two_bs;
  wire [7:0] b_sq;

  assign mult_bs = b * s;       // 4x4 -> 8 bits
  assign two_bs  = {1'b0, mult_bs} << 1; // 2*b*s -> up to 9 bits
  assign b_sq    = b * b;       // 4x4 -> 8 bits
  assign area    = two_bs + b_sq; // result fits in 10 bits

endmodule