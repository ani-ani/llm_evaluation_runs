module octagonal_number (
  input [7:0] n,
  output [15:0] result
);
  
  wire [15:0] n_squared = n * n;
  wire [15:0] three_n_squared = 3 * n_squared;
  wire [15:0] two_n = 2 * n;
  
  assign result = three_n_squared - two_n;
  
endmodule