module hill_houses (
  input clk,
  input rst_n,
  input start,
  input [15:0] hills [0:7],
  output reg [31:0] results [0:3],
  output reg done
);

  localparam IDLE = 2'd0;
  localparam COMPUTE_N = 2'd1;
  localparam COMPUTE_DP = 2'd2;
  localparam DONE_ST = 2'd3;

  reg [1:0] state;
  reg [3:0] n;
  reg [2:0] max_k;
  reg [15:0] hills_local [0:7];
  reg [31:0] dp [0:4][0:8];
  reg [6:0] cycle_count;
  reg [3:0] i, k;
  reg found_zero;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      for (int m = 0; m < 4; m++) results[m] <= 32'd0;
      for (int x = 0; x <= 4; x++) for (int y = 0; y <= 8; y++) dp[x][y] <= 32'd0;
      cycle_count <= 7'd0;
      found_zero <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= COMPUTE_N;
            for (int i = 0; i < 8; i++) hills_local[i] <= hills[i];
            cycle_count <= 7'd0;
            found_zero <= 1'b0;
            n <= 4'd0;
          end
        end
        
        COMPUTE_N: begin
          if (cycle_count < 8) begin
            if (!found_zero && (hills_local[cycle_count[2:0]] == 16'b0)) begin
              n <= cycle_count[2:0];
              found_zero <= 1'b1;
            end
            cycle_count <= cycle_count + 7'd1;
          end else begin
            if (!found_zero) n <= 4'd8;
            max_k <= (n + 1) >> 1;
            // Initialize DP array
            for (int j = 0; j <= 4; j++) begin
              for (int l = 0; l <= 8; l++) begin
                if (j == 0) dp[j][l] <= 32'd0;
                else if (l == 0) dp[j][l] <= 32'h7FFFFFFF;
                else dp[j][l] <= 32'h7FFFFFFF;
              end
            end
            state <= COMPUTE_DP;
            i <= 4'd1;
            k <= 4'd1;
            cycle_count <= 7'd0;
          end
        end
        
        COMPUTE_DP: begin
          if (i <= n) begin
            if (k <= max_k && k <= i) begin
              if (k == 1) begin
                if (dp[1][i-1] < {16'b0, hills_local[i-1]}) dp[1][i] <= dp[1][i-1];
                else dp[1][i] <= {16'b0, hills_local[i-1]};
              end else begin
                if (i >= 2) begin
                  if (dp[k][i-1] < (dp[k-1][i-2] + {16'b0, hills_local[i-1]}))
                    dp[k][i] <= dp[k][i-1];
                  else
                    dp[k][i] <= dp[k-1][i-2] + {16'b0, hills_local[i-1]};
                end else begin
                  dp[k][i] <= dp[k][i-1];
                end
              end
              k <= k + 4'd1;
            end else begin
              k <= 4'd1;
              i <= i + 4'd1;
            end
          end else begin
            for (int m = 0; m < max_k; m++) results[m] <= dp[m+1][n];
            done <= 1'b1;
            state <= DONE_ST;
          end
        end
        
        DONE_ST: begin
          done <= 1'b0;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule