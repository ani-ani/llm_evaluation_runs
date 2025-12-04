module even_position_checker(input reg [7:0] nums [0:7], output reg match);
  assign match = (nums[0][0] == 0) && (nums[2][0] == 0) && (nums[4][0] == 0) && (nums[6][0] == 0);
endmodule