module array_diff(
  input [7:0] nums_0,
  input [7:0] nums_1,
  input [7:0] nums_2,
  input [7:0] nums_3,
  output [7:0] diff
);

  logic [7:0] max01, max23, max_val;
  logic [7:0] min01, min23, min_val;

  // First level: pairwise max/min
  assign max01 = (nums_0 > nums_1) ? nums_0 : nums_1;
  assign max23 = (nums_2 > nums_3) ? nums_2 : nums_3;
  assign min01 = (nums_0 < nums_1) ? nums_0 : nums_1;
  assign min23 = (nums_2 < nums_3) ? nums_2 : nums_3;

  // Second level: combine results from first level
  assign max_val = (max01 > max23) ? max01 : max23;
  assign min_val = (min01 < min23) ? min01 : min23;

  // Final difference
  assign diff = max_val - min_val;

endmodule