module square_sum (
  input  [4:0]  n,
  output [15:0] sum
);

  // Use wider intermediates to avoid overflow and ensure correct truncation
  wire [9:0]   n_sq;        // n^2 fits in 10 bits (max 31^2 = 961)
  wire [11:0]  four_n_sq;   // 4*n^2 fits in 12 bits (max 3844)
  wire [11:0]  four_n_sq_m1;// (4*n^2 - 1)
  wire [21:0]  prod;        // n * (4*n^2 - 1) fits in 17 bits; use 22 for safety

  assign n_sq        = n * n;
  assign four_n_sq   = {n_sq, 2'b00};           // 4 * n^2
  assign four_n_sq_m1= four_n_sq - 12'd1;      // 4*n^2 - 1
  assign prod        = n * four_n_sq_m1;       // n * (4*n^2 - 1)

  // Integer division by 3 (truncating) using combinational divider
  assign sum = prod / 3;

endmodule