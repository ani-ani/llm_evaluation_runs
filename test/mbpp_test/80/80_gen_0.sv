module tetrahedral_number (
  input  [7:0]  n,
  output [15:0] result
);

  // Use wider intermediates to avoid overflow during computation
  wire [8:0]  n_plus_1;   // n + 1 fits in 9 bits
  wire [8:0]  n_plus_2;   // n + 2 fits in 9 bits
  wire [17:0] mult1;      // n * (n + 1) fits in up to 16 bits (use 18 for margin)
  wire [26:0] mult2;      // mult1 * (n + 2) fits within 27 bits

  assign n_plus_1 = n + 9'd1;
  assign n_plus_2 = n + 9'd2;

  assign mult1 = n * n_plus_1;
  assign mult2 = mult1 * n_plus_2;

  // Divide by 6 using unsigned integer division; result fits in 16 bits
  assign result = mult2 / 27'd6;

endmodule