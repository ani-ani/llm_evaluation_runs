module sum_to_n (
  input [6:0] n,
  output [15:0] result
);
  
  wire [13:0] product = n * (n + 1'b1);
  assign result = product >> 1;
  
endmodule