module average_of_cubes(
  input  [3:0]  n,
  output [31:0] average_q16_16
);

  // All arithmetic is unsigned by default for these widths
  wire [4:0]  n_plus_1;       // n+1 fits in 5 bits (max 16)
  wire [9:0]  sq;             // (n+1)^2 fits in 9 bits (max 256)
  wire [13:0] prod;           // n*(n+1)^2 fits in 13 bits (max 3840)
  wire [31:0] shifted;        // Final shifted result (13+14 = 27 bits max)

  assign n_plus_1 = n + 5'd1;
  assign sq       = n_plus_1 * n_plus_1;
  assign prod     = n * sq;
  assign shifted  = {prod, 14'b0};  // Left shift by 14

  assign average_q16_16 = shifted;

endmodule