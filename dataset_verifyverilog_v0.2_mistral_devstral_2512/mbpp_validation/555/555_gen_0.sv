module difference_module (
  input [3:0] n,
  output [31:0] result
);
  
  wire [4:0] sum;
  wire [4:0] sum_minus_one;
  
  assign sum = (n * (n + 1)) >> 1;
  assign sum_minus_one = sum - 1;
  assign result = sum * sum_minus_one;
  
endmodule