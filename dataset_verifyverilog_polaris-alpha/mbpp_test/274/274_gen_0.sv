module even_binomial_sum(
  input  [3:0]  n,
  output [15:0] sum
);

  // sum = 1 << (n - 1), valid for n in [1..15]
  assign sum = (n == 4'd0) ? 16'd0 : (16'd1 << (n - 4'd1));

endmodule