module score_comparator(
  input  signed [7:0] scores  [0:7],
  input  signed [7:0] guesses [0:7],
  output reg   [7:0] differences [0:7]
);

  integer i;
  reg signed [8:0] diff;

  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      if (scores[i] == guesses[i]) begin
        differences[i] = 8'd0;
      end else begin
        diff = scores[i] - guesses[i];
        if (diff[8] == 1'b1) begin
          differences[i] = (~diff[7:0]) + 8'd1;
        end else begin
          differences[i] = diff[7:0];
        end
      end
    end
  end

endmodule