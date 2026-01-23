module is_even (
  input [7:0] n,
  output is_even
);
  
  wire [7:0] xor_result = n ^ 8'h01;
  wire [7:0] sum_result = n + 8'h01;
  
  assign is_even = (xor_result == sum_result) ? 1'b1 : 1'b0;
  
endmodule