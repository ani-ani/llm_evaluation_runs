module array_diff(
  input [7:0] nums_0, nums_1, nums_2, nums_3,
  output [7:0] diff
);

  wire [7:0] max01 = (nums_0 > nums_1) ? nums_0 : nums_1;
  wire [7:0] max23 = (nums_2 > nums_3) ? nums_2 : nums_3;
  wire [7:0] max_final = (max01 > max23) ? max01 : max23;

  wire [7:0] min01 = (nums_0 < nums_1) ? nums_0 : nums_1;
  wire [7:0] min23 = (nums_2 < nums_3) ? nums_2 : nums_3;
  wire [7:0] min_final = (min01 < min23) ? min01 : min23;

  assign diff = max_final - min_final;

endmodule