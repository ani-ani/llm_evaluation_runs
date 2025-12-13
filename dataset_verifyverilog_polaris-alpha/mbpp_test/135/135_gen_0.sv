module hexagonal_num(
  input  [7:0]  n,
  output [17:0] result
);

  // Intermediate signals
  wire [8:0]  two_n;      // 2*n fits in 9 bits (max 510)
  wire [8:0]  two_n_minus1; // (2*n - 1) also fits in 9 bits
  wire [17:0] product;    // n * (2*n - 1) fits in 18 bits

  assign two_n        = {n, 1'b0};        // 2*n via left shift
  assign two_n_minus1 = two_n - 9'd1;     // 2*n - 1
  assign product      = n * two_n_minus1; // combinational multiply

  assign result = product;

endmodule