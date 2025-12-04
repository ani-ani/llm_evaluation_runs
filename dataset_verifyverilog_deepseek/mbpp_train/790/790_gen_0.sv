module even_position_checker (input [7:0] nums[7:0], output match);
  assign match = (nums[0][0] == 1'b0) & (nums[2][0] == 1'b0) & (nums[4][0] == 1'b0) & (nums[6][0] == 1'b0);
endmodule