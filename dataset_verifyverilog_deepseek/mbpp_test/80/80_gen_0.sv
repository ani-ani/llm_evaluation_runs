module tetrahedral_number(input [7:0] n, output [15:0] result);
  wire [8:0] n_plus_1 = n + 1;
  wire [8:0] n_plus_2 = n + 2;
  wire [16:0] product1 = n * n_plus_1;
  wire [25:0] product2 = product1 * n_plus_2;
  wire [25:0] divided = product2 / 6;
  assign result = divided[15:0];
endmodule