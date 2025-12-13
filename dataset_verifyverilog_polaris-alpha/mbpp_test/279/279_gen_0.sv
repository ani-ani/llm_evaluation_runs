module decagonal_number (
  input  [7:0]  n,
  output [17:0] result
);

  wire [15:0] n_sq;      // n^2 fits in 16 bits (max 255^2 = 65025)
  wire [17:0] term1;     // 4 * n^2 (max 260100)
  wire [17:0] term2;     // 3 * n   (max 765)

  assign n_sq  = n * n;
  assign term1 = {2'b00, n_sq} << 2; // 4 * n^2
  assign term2 = n * 3;              // 3 * n

  assign result = term1 - term2;

endmodule