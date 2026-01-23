module sum_even_squares (
  input [7:0] n,
  output [31:0] result
);

  wire [31:0] term1 = 2 * n;
  wire [31:0] term2 = n + 1;
  wire [31:0] term3 = 2 * n + 1;
  wire [31:0] product = term1 * term2 * term3;
  wire [31:0] result_int = product / 3;

  assign result = result_int;

endmodule