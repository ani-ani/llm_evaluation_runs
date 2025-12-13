module array_diff(
  input  [7:0] nums_0,
  input  [7:0] nums_1,
  input  [7:0] nums_2,
  input  [7:0] nums_3,
  output [7:0] diff
);

  wire [7:0] max01;
  wire [7:0] max23;
  wire [7:0] min01;
  wire [7:0] min23;
  wire [7:0] max_val;
  wire [7:0] min_val;

  assign max01 = (nums_0 >= nums_1) ? nums_0 : nums_1;
  assign max23 = (nums_2 >= nums_3) ? nums_2 : nums_3;
  assign min01 = (nums_0 <= nums_1) ? nums_0 : nums_1;
  assign min23 = (nums_2 <= nums_3) ? nums_2 : nums_3;

  assign max_val = (max01 >= max23) ? max01 : max23;
  assign min_val = (min01 <= min23) ? min01 : min23;

  assign diff = max_val - min_val;

endmodule