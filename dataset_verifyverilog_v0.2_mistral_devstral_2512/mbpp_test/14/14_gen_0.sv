module triangular_prism_volume (
  input [15:0] l,
  input [15:0] b,
  input [15:0] h,
  output [15:0] volume
);

  wire [47:0] product = $unsigned(l) * $unsigned(b) * $unsigned(h);
  assign volume = product[47:1]; // Equivalent to (product) / 2 by right shift

endmodule