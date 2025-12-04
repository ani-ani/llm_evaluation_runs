module max_game_score(input [3:0] n, input [15:0] arr [0:7], output reg [31:0] score);
  reg [15:0] sorted [0:8][0:7];
  integer stage, elem, i;
  always_comb begin
    for (elem = 0; elem < 8; elem = elem + 1) begin
      sorted[0][elem] = arr[elem];
    end
    for (stage = 0; stage < 8; stage = stage + 1) begin
      for (elem = 0; elem < 8; elem = elem + 1) begin
        sorted[stage+1][elem] = sorted[stage][elem];
      end
      if (stage % 2 == 0) begin
        for (elem = 0; elem < 7; elem = elem + 2) begin
          if (elem < n-1) begin
            if (sorted[stage][elem] > sorted[stage][elem+1]) begin
              sorted[stage+1][elem] = sorted[stage][elem+1];
              sorted[stage+1][elem+1] = sorted[stage][elem];
            end
          end
        end
      end else begin
        for (elem = 1; elem < 6; elem = elem + 2) begin
          if (elem < n-1) begin
            if (sorted[stage][elem] > sorted[stage][elem+1]) begin
              sorted[stage+1][elem] = sorted[stage][elem+1];
              sorted[stage+1][elem+1] = sorted[stage][elem];
            end
          end
        end
      end
    end
    if (n == 0) begin
      score = 32'd0;
    end else if (n == 1) begin
      score = sorted[8][0];
    end else begin
      score = 32'd0;
      for (i = 0; i < n-1; i = i + 1) begin
        score = score + sorted[8][i] * (i + 32'd2);
      end
      score = score + sorted[8][n-1] * n;
    end
  end
endmodule