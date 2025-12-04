module score_comparator (
  input signed [7:0] scores [0:7],
  input signed [7:0] guesses [0:7],
  output reg [7:0] differences [0:7]
);

  always_comb begin
    for (int i = 0; i < 8; i++) begin
      if (scores[i] == guesses[i]) begin
        differences[i] = 8'd0;
      end else begin
        automatic signed [8:0] diff = scores[i] - guesses[i];
        automatic signed [8:0] absDiff = (diff < 0) ? -diff : diff;
        differences[i] = absDiff[7:0];
      end
    end
  end

endmodule