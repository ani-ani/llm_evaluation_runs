module centered_hexagonal (
  input [7:0] n,
  output [31:0] result
);
  
  wire [7:0] n_minus_1 = n - 1'b1;
  wire [15:0] n_mult_n_minus_1 = n * n_minus_1;
  wire [17:0] three_times_n_mult_n_minus_1 = 3'd3 * n_mult_n_minus_1;
  
  assign result = three_times_n_mult_n_minus_1 + 1'b1;

endmodule