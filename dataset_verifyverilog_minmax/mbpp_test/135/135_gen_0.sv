module hexagonal_num (
  input [7:0] n,
  output [17:0] result
);
  logic [8:0] two_n_minus_1;
  assign two_n_minus_1 = (n << 1) - 1;
  assign result = {1'b0, n * two_n_minus_1};
endmodule
