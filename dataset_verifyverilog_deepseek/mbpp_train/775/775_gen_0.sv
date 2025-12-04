module odd_position_checker (input [7:0] nums [0:7], output reg is_correct);
  always_comb begin
    is_correct = (~nums[0][0]) && nums[1][0] && (~nums[2][0]) && nums[3][0] && 
                 (~nums[4][0]) && nums[5][0] && (~nums[6][0]) && nums[7][0];
  end
endmodule