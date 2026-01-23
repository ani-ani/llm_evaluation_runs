module tetrahedral_number (
  input [7:0] n,
  output [31:0] result
);

  wire [7:0] n_plus_1 = n + 1'b1;
  wire [7:0] n_plus_2 = n + 2'b10;

  wire [15:0] product1 = n * n_plus_1;
  wire [23:0] product2 = product1 * n_plus_2;

  assign result = product2 / 6;

endmodule