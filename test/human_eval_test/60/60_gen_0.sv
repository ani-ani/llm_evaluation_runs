module sum_to_n(
  input  [15:0] n,
  output [15:0] sum
);

  wire [16:0] n_plus_1;
  wire [32:0] product;

  assign n_plus_1 = n + 16'd1;
  assign product  = n * n_plus_1;
  assign sum      = product[17:1];

endmodule