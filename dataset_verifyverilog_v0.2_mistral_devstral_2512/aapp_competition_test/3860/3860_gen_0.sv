module badge_decks (
  input [5:0] b,
  input [5:0] g,
  input [5:0] n,
  output reg [5:0] count
);

  integer k;
  always @* begin
    count = 0;
    for (k = 0; k <= n; k = k + 1) begin
      if ((b >= k) && (g >= (n - k))) begin
        count = count + 1;
      end
    end
  end

endmodule