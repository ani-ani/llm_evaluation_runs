module big_diff (
  input [7:0] nums [0:7],
  output [7:0] diff
);

  wire [7:0] max_val;
  wire [7:0] min_val;

  // Find maximum value using parallel comparators
  assign max_val = (nums[0] > nums[1]) ? ((nums[0] > nums[2]) ? ((nums[0] > nums[3]) ? ((nums[0] > nums[4]) ? ((nums[0] > nums[5]) ? ((nums[0] > nums[6]) ? nums[0] : nums[6]) : nums[5]) : nums[4]) : nums[3]) : nums[2]) : ((nums[1] > nums[2]) ? ((nums[1] > nums[3]) ? ((nums[1] > nums[4]) ? ((nums[1] > nums[5]) ? ((nums[1] > nums[6]) ? nums[1] : nums[6]) : nums[5]) : nums[4]) : nums[3]) : nums[2]));
  assign max_val = (max_val > nums[7]) ? max_val : nums[7];

  // Find minimum value using parallel comparators
  assign min_val = (nums[0] < nums[1]) ? ((nums[0] < nums[2]) ? ((nums[0] < nums[3]) ? ((nums[0] < nums[4]) ? ((nums[0] < nums[5]) ? ((nums[0] < nums[6]) ? nums[0] : nums[6]) : nums[5]) : nums[4]) : nums[3]) : nums[2]) : ((nums[1] < nums[2]) ? ((nums[1] < nums[3]) ? ((nums[1] < nums[4]) ? ((nums[1] < nums[5]) ? ((nums[1] < nums[6]) ? nums[1] : nums[6]) : nums[5]) : nums[4]) : nums[3]) : nums[2]));
  assign min_val = (min_val < nums[7]) ? min_val : nums[7];

  // Compute difference
  assign diff = max_val - min_val;

endmodule