module square_sum (
  input [5:0] n,
  output [31:0] result
);

  wire [11:0] n_squared = n * n;
  wire [15:0] temp = 4 * n_squared;
  wire [15:0] temp_minus_1 = temp - 1;
  wire [21:0] numerator = n * temp_minus_1;
  assign result = numerator / 3;

endmodule