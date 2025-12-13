module cube_sum(
  input  [7:0]  n,
  output [31:0] sum
);

  // Intermediate wires for calculations
  wire [8:0]  n_plus_1;       // n + 1 fits in 9 bits
  wire [16:0] prod_n_np1;     // n * (n + 1) fits in up to 15 bits (8+9)
  wire [16:0] half_term;      // (n * (n + 1)) / 2
  wire [33:0] square_term;    // square of half_term (up to 34 bits)
  wire [36:0] scaled_term;    // 8 * square_term (shift left by 3)

  assign n_plus_1   = n + 1'b1;
  assign prod_n_np1 = n * n_plus_1;
  assign half_term  = prod_n_np1 >> 1;         // integer division by 2
  assign square_term = half_term * half_term;  // square operation
  assign scaled_term = square_term << 3;       // multiply by 8

  // Truncate to 32-bit output as specified
  assign sum = scaled_term[31:0];

endmodule