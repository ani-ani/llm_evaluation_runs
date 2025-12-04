module min_lifts(
  input [2:0] curr_shelf0_pos0, curr_shelf0_pos1,
  input [2:0] curr_shelf1_pos0, curr_shelf1_pos1,
  input [2:0] targ_shelf0_pos0, targ_shelf0_pos1,
  input [2:0] targ_shelf1_pos0, targ_shelf1_pos1,
  output reg [2:0] min_lifts_out
);

  // Internal wires for non-zero (book present) detection
  wire c0p0_nz = (curr_shelf0_pos0 != 3'd0);
  wire c0p1_nz = (curr_shelf0_pos1 != 3'd0);
  wire c1p0_nz = (curr_shelf1_pos0 != 3'd0);
  wire c1p1_nz = (curr_shelf1_pos1 != 3'd0);

  wire t0p0_nz = (targ_shelf0_pos0 != 3'd0);
  wire t0p1_nz = (targ_shelf0_pos1 != 3'd0);
  wire t1p0_nz = (targ_shelf1_pos0 != 3'd0);
  wire t1p1_nz = (targ_shelf1_pos1 != 3'd0);

  // Count non-zero books in current and target
  wire [2:0] curr_count = c0p0_nz + c0p1_nz + c1p0_nz + c1p1_nz;
  wire [2:0] targ_count = t0p0_nz + t0p1_nz + t1p0_nz + t1p1_nz;

  // Equality flags for each position
  wire eq0 = (curr_shelf0_pos0 == targ_shelf0_pos0);
  wire eq1 = (curr_shelf0_pos1 == targ_shelf0_pos1);
  wire eq2 = (curr_shelf1_pos0 == targ_shelf1_pos0);
  wire eq3 = (curr_shelf1_pos1 == targ_shelf1_pos1);

  // Mismatch count (0..4) for positions
  wire [2:0] mismatch_count = (eq0 ? 3'd0 : 3'd1)
                            + (eq1 ? 3'd0 : 3'd1)
                            + (eq2 ? 3'd0 : 3'd1)
                            + (eq3 ? 3'd0 : 3'd1);

  // Book ID presence per ID (1..4) in current
  wire cur_id1 = (curr_shelf0_pos0 == 3'd1) || (curr_shelf0_pos1 == 3'd1) ||
                 (curr_shelf1_pos0 == 3'd1) || (curr_shelf1_pos1 == 3'd1);
  wire cur_id2 = (curr_shelf0_pos0 == 3'd2) || (curr_shelf0_pos1 == 3'd2) ||
                 (curr_shelf1_pos0 == 3'd2) || (curr_shelf1_pos1 == 3'd2);
  wire cur_id3 = (curr_shelf0_pos0 == 3'd3) || (curr_shelf0_pos1 == 3'd3) ||
                 (curr_shelf1_pos0 == 3'd3) || (curr_shelf1_pos1 == 3'd3);
  wire cur_id4 = (curr_shelf0_pos0 == 3'd4) || (curr_shelf0_pos1 == 3'd4) ||
                 (curr_shelf1_pos0 == 3'd4) || (curr_shelf1_pos1 == 3'd4);

  // Book ID presence per ID (1..4) in target
  wire tar_id1 = (targ_shelf0_pos0 == 3'd1) || (targ_shelf0_pos1 == 3'd1) ||
                 (targ_shelf1_pos0 == 3'd1) || (targ_shelf1_pos1 == 3'd1);
  wire tar_id2 = (targ_shelf0_pos0 == 3'd2) || (targ_shelf0_pos1 == 3'd2) ||
                 (targ_shelf1_pos0 == 3'd2) || (targ_shelf1_pos1 == 3'd2);
  wire tar_id3 = (targ_shelf0_pos0 == 3'd3) || (targ_shelf0_pos1 == 3'd3) ||
                 (targ_shelf1_pos0 == 3'd3) || (targ_shelf1_pos1 == 3'd3);
  wire tar_id4 = (targ_shelf0_pos0 == 3'd4) || (targ_shelf0_pos1 == 3'd4) ||
                 (targ_shelf1_pos0 == 3'd4) || (targ_shelf1_pos1 == 3'd4);

  // Valid if counts match and the set of book IDs (1..4) matches
  wire valid_books = (curr_count == targ_count) &&
                     (cur_id1 == tar_id1) &&
                     (cur_id2 == tar_id2) &&
                     (cur_id3 == tar_id3) &&
                     (cur_id4 == tar_id4);

  always @* begin
    if (!valid_books)
      min_lifts_out = 3'b111; // -1: impossible
    else begin
      // Clamp mismatch_count (0..4) into 3 bits (0..7)
      min_lifts_out = mismatch_count[2:0];
    end
  end

endmodule