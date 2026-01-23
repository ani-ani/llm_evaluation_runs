module square_sum(input [5:0] n, output [31:0] result);
  assign n_squared = n * n;
  assign temp = 4 * n_squared;
  assign temp_minus_1 = temp - 1;
  assign numerator = n * temp_minus_1;
  assign result = numerator / 3;
endmodule