module unique_checker(
  input reg [3:0] data[0:3],
  output reg is_unique
);

  // Pairwise equality checks
  wire eq_0_1 = (data[0] == data[1]);
  wire eq_0_2 = (data[0] == data[2]);
  wire eq_0_3 = (data[0] == data[3]);
  wire eq_1_2 = (data[1] == data[2]);
  wire eq_1_3 = (data[1] == data[3]);
  wire eq_2_3 = (data[2] == data[3]);

  // OR all equality checks
  wire any_equal = eq_0_1 | eq_0_2 | eq_0_3 | eq_1_2 | eq_1_3 | eq_2_3;

  // Invert to get is_unique
  assign is_unique = ~any_equal;

endmodule