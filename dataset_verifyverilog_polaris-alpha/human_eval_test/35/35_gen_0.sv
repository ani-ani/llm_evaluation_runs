module max_element(
  input  signed [7:0] values [0:7],
  output signed [7:0] max_value
);

  // Level 1 comparisons
  wire signed [7:0] max_l1_0;
  wire signed [7:0] max_l1_1;
  wire signed [7:0] max_l1_2;
  wire signed [7:0] max_l1_3;

  assign max_l1_0 = (values[0] >= values[1]) ? values[0] : values[1];
  assign max_l1_1 = (values[2] >= values[3]) ? values[2] : values[3];
  assign max_l1_2 = (values[4] >= values[5]) ? values[4] : values[5];
  assign max_l1_3 = (values[6] >= values[7]) ? values[6] : values[7];

  // Level 2 comparisons
  wire signed [7:0] max_l2_0;
  wire signed [7:0] max_l2_1;

  assign max_l2_0 = (max_l1_0 >= max_l1_1) ? max_l1_0 : max_l1_1;
  assign max_l2_1 = (max_l1_2 >= max_l1_3) ? max_l1_2 : max_l1_3;

  // Level 3 (final) comparison
  assign max_value = (max_l2_0 >= max_l2_1) ? max_l2_0 : max_l2_1;

endmodule