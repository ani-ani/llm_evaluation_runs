module find_min_value(
  input wire signed [7:0] numbers [7:0], // 8 elements, each 8-bit signed
  output wire signed [7:0] min_value
);
  // Level 0: pair-wise minimum
  wire signed [7:0] m0_0, m0_1, m0_2, m0_3;
  assign m0_0 = ($signed(numbers[0]) < $signed(numbers[1])) ? numbers[0] : numbers[1];
  assign m0_1 = ($signed(numbers[2]) < $signed(numbers[3])) ? numbers[2] : numbers[3];
  assign m0_2 = ($signed(numbers[4]) < $signed(numbers[5])) ? numbers[4] : numbers[5];
  assign m0_3 = ($signed(numbers[6]) < $signed(numbers[7])) ? numbers[6] : numbers[7];

  // Level 1: 4-way reduction
  wire signed [7:0] m1_0, m1_1;
  assign m1_0 = ($signed(m0_0) < $signed(m0_1)) ? m0_0 : m0_1;
  assign m1_1 = ($signed(m0_2) < $signed(m0_3)) ? m0_2 : m0_3;

  // Level 2: final min
  assign min_value = ($signed(m1_0) < $signed(m1_1)) ? m1_0 : m1_1;
endmodule
