module sum_to_n (input reg [15:0] n, output [15:0] sum);
  reg [16:0] n_plus_one;
  reg [31:0] product;
  assign n_plus_one = n + 1;
  assign product = n * n_plus_one;
  assign sum = product >> 1;
endmodule