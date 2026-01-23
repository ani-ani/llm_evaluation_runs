module is_sum_of_powers_of_two(
  input [7:0] n,
  output is_sum
);
  
  assign is_sum = (n[0] == 1'b0);
  
endmodule