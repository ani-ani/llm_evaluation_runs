module first_odd_finder (
  input [7:0][15:0] nums,
  output [15:0] result
);
  assign result = (nums[0][0]) ? nums[0] :
                  (nums[1][0]) ? nums[1] :
                  (nums[2][0]) ? nums[2] :
                  (nums[3][0]) ? nums[3] :
                  (nums[4][0]) ? nums[4] :
                  (nums[5][0]) ? nums[5] :
                  (nums[6][0]) ? nums[6] :
                  (nums[7][0]) ? nums[7] :
                  16'hFFFF;
endmodule