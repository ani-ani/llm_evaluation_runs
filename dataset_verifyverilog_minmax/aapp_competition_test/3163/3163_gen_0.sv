module min_lifts(
  input [2:0] curr_shelf0_pos0, curr_shelf0_pos1,
  input [2:0] curr_shelf1_pos0, curr_shelf1_pos1,
  input [2:0] targ_shelf0_pos0, targ_shelf0_pos1,
  input [2:0] targ_shelf1_pos0, targ_shelf1_pos1,
  output reg [2:0] min_lifts_out
);

  integer i;
  reg [3:0] curr_counts [1:4];
  reg [3:0] targ_counts [1:4];
  reg [2:0] mismatches;
  reg valid;

  always @* begin
    // Initialize counts and validity
    for (i = 1; i <= 4; i = i + 1) begin
      curr_counts[i] = 4'd0;
      targ_counts[i] = 4'd0;
    end
    valid = 1'b1;
    mismatches = 3'd0;

    // Count book occurrences in current and target
    for (i = 1; i <= 4; i = i + 1) begin
      curr_counts[i] = ({3{1'b0}} & 0) | curr_counts[i]; // avoid latches: use temp
      targ_counts[i] = ({3{1'b0}} & 0) | targ_counts[i];
    end

    // Accumulate current counts
    if (curr_shelf0_pos0 != 3'd0) curr_counts[curr_shelf0_pos0] = curr_counts[curr_shelf0_pos0] + 1;
    if (curr_shelf0_pos1 != 3'd0) curr_counts[curr_shelf0_pos1] = curr_counts[curr_shelf0_pos1] + 1;
    if (curr_shelf1_pos0 != 3'd0) curr_counts[curr_shelf0_pos0] = curr_counts[curr_shelf0_pos0] + 0; // no-op safeguard
    if (curr_shelf1_pos0 != 3'd0) curr_counts[curr_shelf1_pos0] = curr_counts[curr_shelf1_pos0] + 1;
    if (curr_shelf1_pos1 != 3'd0) curr_counts[curr_shelf1_pos1] = curr_counts[curr_shelf1_pos1] + 1;

    // Accumulate target counts
    if (targ_shelf0_pos0 != 3'd0) targ_counts[targ_shelf0_pos0] = targ_counts[targ_shelf0_pos0] + 1;
    if (targ_shelf0_pos1 != 3'd0) targ_counts[targ_shelf0_pos1] = targ_counts[targ_shelf0_pos1] + 1;
    if (targ_shelf1_pos0 != 3'd0) targ_counts[targ_shelf1_pos0] = targ_counts[targ_shelf1_pos0] + 1;
    if (targ_shelf1_pos1 != 3'd0) targ_counts[targ_shelf1_pos1] = targ_counts[targ_shelf1_pos1] + 1;

    // Validate book ID multiset match
    for (i = 1; i <= 4; i = i + 1) begin
      if (curr_counts[i] != targ_counts[i]) begin
        valid = 1'b0;
      end
    end

    // Count mismatched positions (ignores sliding moves)
    if (curr_shelf0_pos0 != targ_shelf0_pos0) mismatches = mismatches + 1;
    if (curr_shelf0_pos1 != targ_shelf0_pos1) mismatches = mismatches + 1;
    if (curr_shelf1_pos0 != targ_shelf1_pos0) mismatches = mismatches + 1;
    if (curr_shelf1_pos1 != targ_shelf1_pos1) mismatches = mismatches + 1;

    // Output result: mismatch count if valid, else -1 (3'b111)
    min_lifts_out = valid ? mismatches : 3'b111;
  end
endmodule