module min_lifts(
  input [2:0] curr_shelf0_pos0, curr_shelf0_pos1,
  input [2:0] curr_shelf1_pos0, curr_shelf1_pos1,
  input [2:0] targ_shelf0_pos0, targ_shelf0_pos1,
  input [2:0] targ_shelf1_pos0, targ_shelf1_pos1,
  output reg [2:0] min_lifts_out
);
  wire [1:0] curr_total = (curr_shelf0_pos0 != 3'b0) + (curr_shelf0_pos1 != 3'b0)
    + (curr_shelf1_pos0 != 3'b0) + (curr_shelf1_pos1 != 3'b0);
  wire [1:0] targ_total = (targ_shelf0_pos0 != 3'b0) + (targ_shelf0_pos1 != 3'b0)
    + (targ_shelf1_pos0 != 3'b0) + (targ_shelf1_pos1 != 3'b0);
  wire total_equal = (curr_total == targ_total);

  wire [1:0] curr_book1 = (curr_shelf0_pos0 == 3'd1) + (curr_shelf0_pos1 == 3'd1)
    + (curr_shelf1_pos0 == 3'd1) + (curr_shelf1_pos1 == 3'd1);
  wire [1:0] targ_book1 = (targ_shelf0_pos0 == 3'd1) + (targ_shelf0_pos1 == 3'd1)
    + (targ_shelf1_pos0 == 3'd1) + (targ_shelf1_pos1 == 3'd1);
  wire book1_equal = (curr_book1 == targ_book1);

  wire [1:0] curr_book2 = (curr_shelf0_pos0 == 3'd2) + (curr_shelf0_pos1 == 3'd2)
    + (curr_shelf1_pos0 == 3'd2) + (curr_shelf1_pos1 == 3'd2);
  wire [1:0] targ_book2 = (targ_shelf0_pos0 == 3'd2) + (targ_shelf0_pos1 == 3'd2)
    + (targ_shelf1_pos0 == 3'd2) + (targ_shelf1_pos1 == 3'd2);
  wire book2_equal = (curr_book2 == targ_book2);

  wire [1:0] curr_book3 = (curr_shelf0_pos0 == 3'd3) + (curr_shelf0_pos1 == 3'd3)
    + (curr_shelf1_pos0 == 3'd3) + (curr_shelf1_pos1 == 3'd3);
  wire [1:0] targ_book3 = (targ_shelf0_pos0 == 3'd3) + (targ_shelf0_pos1 == 3'd3)
    + (targ_shelf1_pos0 == 3'd3) + (targ_shelf1_pos1 == 3'd3);
  wire book3_equal = (curr_book3 == targ_book3);

  wire [1:0] curr_book4 = (curr_shelf0_pos0 == 3'd4) + (curr_shelf0_pos1 == 3'd4)
    + (curr_shelf1_pos0 == 3'd4) + (curr_shelf1_pos1 == 3'd4);
  wire [1:0] targ_book4 = (targ_shelf0_pos0 == 3'd4) + (targ_shelf0_pos1 == 3'd4)
    + (targ_shelf1_pos0 == 3'd4) + (targ_shelf1_pos1 == 3'd4);
  wire book4_equal = (curr_book4 == targ_book4);

  wire books_match = book1_equal && book2_equal && book3_equal && book4_equal;

  wire [2:0] mismatch_count = (curr_shelf0_pos0 != targ_shelf0_pos0)
    + (curr_shelf0_pos1 != targ_shelf0_pos1)
    + (curr_shelf1_pos0 != targ_shelf1_pos0)
    + (curr_shelf1_pos1 != targ_shelf1_pos1);

  always_comb begin
    if (total_equal && books_match) min_lifts_out = mismatch_count;
    else min_lifts_out = 3'b111;
  end
endmodule