module octagonal_number (
  input  [7:0]  n,
  output [17:0] oct_num
);

  wire [15:0] n_sq;       // 8x8 multiplier result fits in 16 bits
  wire [17:0] three_n_sq; // 3 * n^2 fits in 18 bits
  wire [9:0]  two_n;      // 2 * n fits in 9 bits

  // First multiplier: n * n
  assign n_sq = n * n;

  // Second multiplier: 3 * n_sq
  assign three_n_sq = 3 * n_sq;

  // 2 * n (implemented as left shift by 1)
  assign two_n = {1'b0, n} << 1;

  // Subtractor: 3n^2 - 2n
  assign oct_num = three_n_sq - two_n;

endmodule