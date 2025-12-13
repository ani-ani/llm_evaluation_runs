module even_position_checker(
  input  [7:0] nums [7:0],
  output       match
);

  wire idx0_even = (nums[0][0] == 1'b0);
  wire idx2_even = (nums[2][0] == 1'b0);
  wire idx4_even = (nums[4][0] == 1'b0);
  wire idx6_even = (nums[6][0] == 1'b0);

  assign match = idx0_even & idx2_even & idx4_even & idx6_even;

endmodule