module pattern_matcher (
  input [2:0] length,
  input [3:0] colors [7:0],
  input [3:0] patterns [7:0],
  output match
);

  logic [27:0] invalid_pairs;
  
  generate
    genvar i, j;
    for (i = 0; i < 8; i = i + 1) begin : LOOP_I
      for (j = i + 1; j < 8; j = j + 1) begin : LOOP_J
        localparam int idx = (i * (15 - i)) / 2 + (j - i - 1);
        wire pair_active = (i < length) && (j < length);
        wire patterns_eq = (patterns[i] == patterns[j]);
        wire colors_eq = (colors[i] == colors[j]);
        wire invalid_pair = pair_active && ((patterns_eq && !colors_eq) || (!patterns_eq && colors_eq));
        assign invalid_pairs[idx] = invalid_pair;
      end
    end
  endgenerate
  
  assign match = (length == 3'b0) ? 1'b1 : !(|invalid_pairs);

endmodule