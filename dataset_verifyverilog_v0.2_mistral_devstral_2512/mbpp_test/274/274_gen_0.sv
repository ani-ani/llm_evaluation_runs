module even_binomial_sum(
  input [5:0] n,
  output [31:0] result
);
  assign result = (n == 0) ? 0 : (1 << (n - 1));
endmodule