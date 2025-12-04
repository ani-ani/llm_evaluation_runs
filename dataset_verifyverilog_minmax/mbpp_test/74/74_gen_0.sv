module pattern_matcher (
  input [2:0] length,
  input [3:0] colors [7:0],
  input [3:0] patterns [7:0],
  output match
);
  // Conditions for bijection across 'length' elements:
  // 1) For any equal patterns -> equal colors
  // 2) For any different patterns -> different colors
  assign match =
    ( (patterns[0] == patterns[1]) -> (colors[0] == colors[1]) &&
      (patterns[0] == patterns[2]) -> (colors[0] == colors[2]) &&
      (patterns[0] == patterns[3]) -> (colors[0] == colors[3]) &&
      (patterns[0] == patterns[4]) -> (colors[0] == colors[4]) &&
      (patterns[0] == patterns[5]) -> (colors[0] == colors[5]) &&
      (patterns[0] == patterns[6]) -> (colors[0] == colors[6]) &&
      (patterns[0] == patterns[7]) -> (colors[0] == colors[7]) &&
      (patterns[1] == patterns[2]) -> (colors[1] == colors[2]) &&
      (patterns[1] == patterns[3]) -> (colors[1] == colors[3]) &&
      (patterns[1] == patterns[4]) -> (colors[1] == colors[4]) &&
      (patterns[1] == patterns[5]) -> (colors[1] == colors[5]) &&
      (patterns[1] == patterns[6]) -> (colors[1] == colors[6]) &&
      (patterns[1] == patterns[7]) -> (colors[1] == colors[7]) &&
      (patterns[2] == patterns[3]) -> (colors[2] == colors[3]) &&
      (patterns[2] == patterns[4]) -> (colors[2] == colors[4]) &&
      (patterns[2] == patterns[5]) -> (colors[2] == colors[5]) &&
      (patterns[2] == patterns[6]) -> (colors[2] == colors[6]) &&
      (patterns[2] == patterns[7]) -> (colors[2] == colors[7]) &&
      (patterns[3] == patterns[4]) -> (colors[3] == colors[4]) &&
      (patterns[3] == patterns[5]) -> (colors[3] == colors[5]) &&
      (patterns[3] == patterns[6]) -> (colors[3] == colors[6]) &&
      (patterns[3] == patterns[7]) -> (colors[3] == colors[7]) &&
      (patterns[4] == patterns[5]) -> (colors[4] == colors[5]) &&
      (patterns[4] == patterns[6]) -> (colors[4] == colors[6]) &&
      (patterns[4] == patterns[7]) -> (colors[4] == colors[7]) &&
      (patterns[5] == patterns[6]) -> (colors[5] == colors[6]) &&
      (patterns[5] == patterns[7]) -> (colors[5] == colors[7]) &&
      (patterns[6] == patterns[7]) -> (colors[6] == colors[7]) ) &&
    ( (patterns[0] != patterns[1]) -> (colors[0] != colors[1]) &&
      (patterns[0] != patterns[2]) -> (colors[0] != colors[2]) &&
      (patterns[0] != patterns[3]) -> (colors[0] != colors[3]) &&
      (patterns[0] != patterns[4]) -> (colors[0] != colors[4]) &&
      (patterns[0] != patterns[5]) -> (colors[0] != colors[5]) &&
      (patterns[0] != patterns[6]) -> (colors[0] != colors[6]) &&
      (patterns[0] != patterns[7]) -> (colors[0] != colors[7]) &&
      (patterns[1] != patterns[2]) -> (colors[1] != colors[2]) &&
      (patterns[1] != patterns[3]) -> (colors[1] != colors[3]) &&
      (patterns[1] != patterns[4]) -> (colors[1] != colors[4]) &&
      (patterns[1] != patterns[5]) -> (colors[1] != colors[5]) &&
      (patterns[1] != patterns[6]) -> (colors[1] != colors[6]) &&
      (patterns[1] != patterns[7]) -> (colors[1] != colors[7]) &&
      (patterns[2] != patterns[3]) -> (colors[2] != colors[3]) &&
      (patterns[2] != patterns[4]) -> (colors[2] != colors[4]) &&
      (patterns[2] != patterns[5]) -> (colors[2] != colors[5]) &&
      (patterns[2] != patterns[6]) -> (colors[2] != colors[6]) &&
      (patterns[2] != patterns[7]) -> (colors[2] != colors[7]) &&
      (patterns[3] != patterns[4]) -> (colors[3] != colors[4]) &&
      (patterns[3] != patterns[5]) -> (colors[3] != colors[5]) &&
      (patterns[3] != patterns[6]) -> (colors[3] != colors[6]) &&
      (patterns[3] != patterns[7]) -> (colors[3] != colors[7]) &&
      (patterns[4] != patterns[5]) -> (colors[4] != colors[5]) &&
      (patterns[4] != patterns[6]) -> (colors[4] != colors[6]) &&
      (patterns[4] != patterns[7]) -> (colors[4] != colors[7]) &&
      (patterns[5] != patterns[6]) -> (colors[5] != colors[6]) &&
      (patterns[5] != patterns[7]) -> (colors[5] != colors[7]) &&
      (patterns[6] != patterns[7]) -> (colors[6] != colors[7]) );
endmodule