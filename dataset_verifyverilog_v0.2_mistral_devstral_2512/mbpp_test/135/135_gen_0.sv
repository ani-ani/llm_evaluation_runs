module hexagonal_number(
  input [7:0] n,
  output [15:0] result
);
  wire [8:0] two_n = 2 * n;
  wire [8:0] two_n_minus_1 = two_n - 1;
  assign result = n * two_n_minus_1;
endmodule