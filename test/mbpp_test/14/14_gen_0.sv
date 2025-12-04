module triangular_prism_volume(
  input  [7:0] l,
  input  [7:0] b,
  input  [7:0] h,
  output [7:0] volume
);

  wire [15:0] mult_lb;
  wire [23:0] mult_lbh;
  wire [23:0] volume_full;

  assign mult_lb    = l * b;
  assign mult_lbh   = mult_lb * h;
  assign volume_full = mult_lbh >> 1;
  assign volume     = volume_full[7:0];

endmodule