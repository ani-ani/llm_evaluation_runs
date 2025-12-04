module pattern_matcher(
  input  [2:0] length,
  input  [3:0] colors  [7:0],
  input  [3:0] patterns[7:0],
  output       match
);

  integer i, j;

  reg eq_pattern[7:0][7:0];
  reg eq_color  [7:0][7:0];
  reg both_valid[7:0][7:0];

  reg violation_same_pattern_diff_color;
  reg violation_diff_pattern_same_color;

  // Precompute comparisons in parallel (combinational)
  always @* begin
    // Initialize
    violation_same_pattern_diff_color = 1'b0;
    violation_diff_pattern_same_color = 1'b0;

    // Default all comparison helpers
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        eq_pattern[i][j]  = (patterns[i] == patterns[j]);
        eq_color[i][j]    = (colors[i]   == colors[j]);
        // Valid if both indices are within length
        both_valid[i][j]  = (i < length) && (j < length);
      end
    end

    // Check constraints only for indices < length
    for (i = 0; i < 8; i = i + 1) begin
      for (j = i + 1; j < 8; j = j + 1) begin
        if (both_valid[i][j]) begin
          // If patterns equal, colors must be equal
          if (eq_pattern[i][j] && !eq_color[i][j]) begin
            violation_same_pattern_diff_color = 1'b1;
          end
          // If patterns different, colors must be different
          if (!eq_pattern[i][j] && eq_color[i][j]) begin
            violation_diff_pattern_same_color = 1'b1;
          end
        end
      end
    end
  end

  assign match = !(violation_same_pattern_diff_color | violation_diff_pattern_same_color);

endmodule