module sum_cube_difference(input reg [7:0] n, output wire [29:0] result);
  wire [8:0] n_plus_1 = n + 1;
  wire [15:0] sum_s;
  assign sum_s = (n[0] == 1'b0) ? 
                 ((n >> 1) * n_plus_1) : 
                 (n * (n_plus_1 >> 1));
  assign result = sum_s * (sum_s - 1);
endmodule