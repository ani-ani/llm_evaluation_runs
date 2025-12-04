module tetrahedral_number(
  input [7:0] n,
  output [15:0] result
);

  // Extend n to 16 bits for intermediate calculations
  wire [15:0] n_ext = n;
  wire [15:0] n1 = n_ext + 1;
  wire [15:0] n2 = n_ext + 2;

  // First product: n * (n+1) - fits in 16 bits (max 65280)
  wire [15:0] product1 = n_ext * n1;

  // Second product: product1 * (n+2) - use 24 bits to capture full range
  wire [23:0] product2 = product1 * n2;

  // Exact division by 6 (divisible since product of three consecutive numbers)
  wire [23:0] exact = product2 / 6;

  // Truncate to 16-bit output
  assign result = exact[15:0];

endmodule