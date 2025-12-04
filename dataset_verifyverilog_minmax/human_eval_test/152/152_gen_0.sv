module score_comparator (
  input signed [7:0] scores [0:7],
  input signed [7:0] guesses [0:7],
  output reg [7:0] differences [0:7]
);
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : per_index
      // Signed difference computed in 9 bits to avoid overflow
      wire signed [8:0] diff9 = $signed({1'b0, scores[i]}) - $signed({1'b0, guesses[i]});
      // Absolute value of the 9-bit difference
      wire signed [8:0] abs9 = diff9[8] ? -diff9 : diff9;
      // Zero detection and mapping to 0 or the absolute difference
      assign differences[i] = (abs9 == 9'sd0) ? 8'd0 : abs9[7:0];
    end
  endgenerate
endmodule