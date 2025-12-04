module sum_cube_difference (input reg [7:0] n, output [29:0] result);
  wire [8:0] n_plus_1 = n + 1'b1;
  wire [16:0] product = n * n_plus_1;
  wire [15:0] Sum_S = product[16:1];
  assign result = Sum_S * (Sum_S - 1'b1);
endmodule