module even_filter(input [63:0] nums, output [7:0] mask);
  assign mask[0] = ~nums[0];
  assign mask[1] = ~nums[8];
  assign mask[2] = ~nums[16];
  assign mask[3] = ~nums[24];
  assign mask[4] = ~nums[32];
  assign mask[5] = ~nums[40];
  assign mask[6] = ~nums[48];
  assign mask[7] = ~nums[56];
endmodule