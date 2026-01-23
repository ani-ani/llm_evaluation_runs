module abab_pattern_finder (
  input [7:0] N,
  input [15:0][7:0] S,
  output [7:0] A,
  output [7:0] B,
  output valid
);

  reg [7:0] A_reg = 8'd0;
  reg [7:0] B_reg = 8'd0;
  reg valid_reg = 1'b0;

  integer i, j, k, l, m, n;
  reg [7:0] posA1, posB1, posA2, posB2;
  reg found;

  always @* begin
    valid_reg = 1'b0;
    A_reg = 8'd0;
    B_reg = 8'd0;

    for (i = 1; i <= N; i = i + 1) begin
      for (j = 1; j <= N; j = j + 1) begin
        if (i != j) begin
          posA1 = 8'd0;
          posB1 = 8'd0;
          posA2 = 8'd0;
          posB2 = 8'd0;
          found = 1'b0;

          for (k = 0; k < N; k = k + 1) begin
            if (S[k] == i) begin
              posA1 = k;
              break;
            end
          end

          if (posA1 < N) begin
            for (l = posA1 + 1; l < N; l = l + 1) begin
              if (S[l] == j) begin
                posB1 = l;
                break;
              end
            end

            if (posB1 < N) begin
              for (m = posB1 + 1; m < N; m = m + 1) begin
                if (S[m] == i) begin
                  posA2 = m;
                  break;
                end
              end

              if (posA2 < N) begin
                for (n = posA2 + 1; n < N; n = n + 1) begin
                  if (S[n] == j) begin
                    posB2 = n;
                    found = 1'b1;
                    break;
                  end
                end
              end
            end
          end

          if (found) begin
            valid_reg = 1'b1;
            A_reg = i;
            B_reg = j;
            return;
          end
        end
      end
    end
  end

  assign A = A_reg;
  assign B = B_reg;
  assign valid = valid_reg;

endmodule