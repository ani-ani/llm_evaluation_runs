module find_min_value (
  input  signed [7:0] numbers [7:0],
  output signed [7:0] min_value
);

  // Level 1 comparisons (pairwise)
  wire signed [7:0] l1_0 = (numbers[0] <= numbers[1]) ? numbers[0] : numbers[1];
  wire signed [7:0] l1_1 = (numbers[2] <= numbers[3]) ? numbers[2] : numbers[3];
  wire signed [7:0] l1_2 = (numbers[4] <= numbers[5]) ? numbers[4] : numbers[5];
  wire signed [7:0] l1_3 = (numbers[6] <= numbers[7]) ? numbers[6] : numbers[7];

  // Level 2 comparisons
  wire signed [7:0] l2_0 = (l1_0 <= l1_1) ? l1_0 : l1_1;
  wire signed [7:0] l2_1 = (l1_2 <= l1_3) ? l1_2 : l1_3;

  // Level 3 (final) comparison
  assign min_value = (l2_0 <= l2_1) ? l2_0 : l2_1;

endmodule