module compare_arrays (
  input [7:0] scores_i,
  input [7:0] guesses_i,
  input [2:0] index,
  output [7:0] diff_o
);

  wire signed [7:0] score = scores_i;
  wire signed [7:0] guess = guesses_i;
  wire signed [7:0] diff = score - guess;
  wire signed [7:0] abs_diff = (diff < 0) ? -diff : diff;

  assign diff_o = abs_diff;

endmodule