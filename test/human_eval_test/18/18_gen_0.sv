module substring_counter(
  input      [63:0] main_str,
  input      [63:0] sub_str,
  input      [3:0]  main_len,
  input      [3:0]  sub_len,
  output     [3:0]  count
);

  // Generate mask for the valid substring bits: high bits contain substring, rest zero
  wire [63:0] sub_masked;
  assign sub_masked = (sub_len == 0) ? 64'd0 : (sub_str & (~64'd0 << (64 - (sub_len * 8))));

  // Wires for each possible match position (0..7)
  wire match0, match1, match2, match3, match4, match5, match6, match7;

  // Position 0
  assign match0 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd0 + sub_len) &&
                  ((main_str[63 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Position 1
  assign match1 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd1 + sub_len) &&
                  ((main_str[63-8 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Position 2
  assign match2 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd2 + sub_len) &&
                  ((main_str[63-16 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Position 3
  assign match3 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd3 + sub_len) &&
                  ((main_str[63-24 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Position 4
  assign match4 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd4 + sub_len) &&
                  ((main_str[63-32 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Position 5
  assign match5 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd5 + sub_len) &&
                  ((main_str[63-40 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Position 6
  assign match6 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd6 + sub_len) &&
                  ((main_str[63-48 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Position 7
  assign match7 = (sub_len != 0) && (sub_len <= main_len) &&
                  (main_len >= 4'd7 + sub_len) &&
                  ((main_str[63-56 -: (8*sub_len)]) == (sub_masked[63 -: (8*sub_len)]));

  // Count all matches
  wire [3:0] sum_matches;
  assign sum_matches = match0 + match1 + match2 + match3 +
                       match4 + match5 + match6 + match7;

  // Final count with required constraints
  assign count = (sub_len == 0 || sub_len > main_len) ? 4'd0 : sum_matches;

endmodule