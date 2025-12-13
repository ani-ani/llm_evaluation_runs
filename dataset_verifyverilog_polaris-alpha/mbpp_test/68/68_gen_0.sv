module monotonic_checker(
  input  [7:0][7:0] array_in,
  input  [2:0]      actual_elements,
  output            is_monotonic
);

  // Generate masks for valid comparison indices (0..6)
  wire [6:0] cmp_valid;
  assign cmp_valid[0] = (actual_elements > 3'd1);
  assign cmp_valid[1] = (actual_elements > 3'd2);
  assign cmp_valid[2] = (actual_elements > 3'd3);
  assign cmp_valid[3] = (actual_elements > 3'd4);
  assign cmp_valid[4] = (actual_elements > 3'd5);
  assign cmp_valid[5] = (actual_elements > 3'd6);
  assign cmp_valid[6] = (actual_elements > 3'd7);

  // Non-decreasing comparisons (array_in[i] <= array_in[i+1])
  wire [6:0] le_cmp;
  assign le_cmp[0] = (array_in[0] <= array_in[1]);
  assign le_cmp[1] = (array_in[1] <= array_in[2]);
  assign le_cmp[2] = (array_in[2] <= array_in[3]);
  assign le_cmp[3] = (array_in[3] <= array_in[4]);
  assign le_cmp[4] = (array_in[4] <= array_in[5]);
  assign le_cmp[5] = (array_in[5] <= array_in[6]);
  assign le_cmp[6] = (array_in[6] <= array_in[7]);

  // Non-increasing comparisons (array_in[i] >= array_in[i+1])
  wire [6:0] ge_cmp;
  assign ge_cmp[0] = (array_in[0] >= array_in[1]);
  assign ge_cmp[1] = (array_in[1] >= array_in[2]);
  assign ge_cmp[2] = (array_in[2] >= array_in[3]);
  assign ge_cmp[3] = (array_in[3] >= array_in[4]);
  assign ge_cmp[4] = (array_in[4] >= array_in[5]);
  assign ge_cmp[5] = (array_in[5] >= array_in[6]);
  assign ge_cmp[6] = (array_in[6] >= array_in[7]);

  // Apply validity mask so only active comparisons matter
  wire [6:0] le_masked = le_cmp | ~cmp_valid; // inactive comparisons forced to 1
  wire [6:0] ge_masked = ge_cmp | ~cmp_valid; // inactive comparisons forced to 1

  wire non_decreasing = &le_masked;
  wire non_increasing = &ge_masked;

  assign is_monotonic = non_decreasing | non_increasing;

endmodule