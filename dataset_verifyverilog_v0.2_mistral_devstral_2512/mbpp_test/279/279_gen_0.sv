module decagonal (
  input [7:0] n,
  output [19:0] result
);
  
  wire [15:0] n_squared = n * n;
  wire [17:0] term1 = n_squared << 2;
  wire [9:0] term2 = 3 * n;
  
  assign result = term1 - term2;
  
endmodule