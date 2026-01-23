module compare_arrays(
  input [7:0] scores_i,
  input [7:0] guesses_i,
  input [2:0] index,
  output [7:0] diff_o
);
wire signed [7:0] diff;
wire signed [7:0] abs_diff;
assign diff = (signed)scores_i - (signed)guesses_i;
assign abs_diff = (diff < 0) ? -diff : diff;
assign diff_o = (unsigned)abs_diff;
endmodule