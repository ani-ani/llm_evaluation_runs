module even_binomial_sum (input [3:0] n, output [15:0] sum);
  assign sum = 16'b1 << (n - 1);
endmodule