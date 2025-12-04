module find_min_value(
  input signed [7:0] numbers [7:0],
  output signed [7:0] min_value
);

  wire signed [7:0] min01 = (numbers[0] < numbers[1]) ? numbers[0] : numbers[1];
  wire signed [7:0] min23 = (numbers[2] < numbers[3]) ? numbers[2] : numbers[3];
  wire signed [7:0] min45 = (numbers[4] < numbers[5]) ? numbers[4] : numbers[5];
  wire signed [7:0] min67 = (numbers[6] < numbers[7]) ? numbers[6] : numbers[7];

  wire signed [7:0] min03 = (min01 < min23) ? min01 : min23;
  wire signed [7:0] min47 = (min45 < min67) ? min45 : min67;

  assign min_value = (min03 < min47) ? min03 : min47;

endmodule