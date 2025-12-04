module license_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [7:0] s1,
  input [7:0] s2,
  input [7:0] t [0:15],
  output reg [3:0] max_customers,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam DONE = 2'b10;

  // DP table: max customers achievable for each time pair (remaining1, remaining2)
  // 8-bit per cell is enough because max customers is 0..16.
  logic [7:0] dp [256][256];
  // Reachable pairs flags for current iteration
  logic reach_cur [256][256];
  // Reachable pairs flags for next iteration
  logic reach_nxt [256][256];

  reg [1:0] state;
  reg [4:0] idx; // 0..15, used as index into t
  reg [3:0] result_count;
  reg [7:0] init1, init2; // s1_init, s2_init

  // Internal temp for new_max broadcast
  logic [7:0] new_max;
  integer i1, i2; // loop indices

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_customers <= 4'd0;
      result_count <= 4'd0;
      init1 <= 8'd0;
      init2 <= 8'd0;
      idx <= 5'd0;
      new_max <= 8'd0;
      // Clear DP (optional but clean)
      for (i1 = 0; i1 < 256; i1 = i1 + 1) begin
        for (i2 = 0; i2 < 256; i2 = i2 + 1) begin
          dp[i1][i2] <= 8'd0;
          reach_cur[i1][i2] <= 1'b0;
          reach_nxt[i1][i2] <= 1'b0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          // On start pulse, initialize and enter processing
          if (start) begin
            // If n==0, skip processing and go straight to DONE
            if (n == 4'd0) begin
              result_count <= 4'd0;
              max_customers <= 4'd0;
              done <= 1'b1;
              state <= DONE;
            end else begin
              init1 <= s1;
              init2 <= s2;
              idx <= 5'd0;
              result_count <= 4'd0;
              new_max <= 8'd0;

              // Clear DP and reachable flags
              for (i1 = 0; i1 < 256; i1 = i1 + 1) begin
                for (i2 = 0; i2 < 256; i2 = i2 + 1) begin
                  dp[i1][i2] <= 8'd0;
                  reach_cur[i1][i2] <= 1'b0;
                  reach_nxt[i1][i2] <= 1'b0;
                end
              end
              // Initial reachable state
              dp[s1][s2] <= 8'd0;
              reach_cur[s1][s2] <= 1'b1;
              state <= PROCESSING;
            end
          end else begin
            // Keep DP stable in IDLE (not strictly needed)
            for (i1 = 0; i1 < 256; i1 = i1 + 1) begin
              for (i2 = 0; i2 < 256; i2 = i2 + 1) begin
                reach_nxt[i1][i2] <= reach_cur[i1][i2];
              end
            end
          end
        end

        PROCESSING: begin
          if (idx < n) begin
            // Combine current iteration results into new_max
            new_max <= 8'd0;
            for (i1 = 0; i1 < 256; i1 = i1 + 1) begin
              for (i2 = 0; i2 < 256; i2 = i2 + 1) begin
                if (reach_cur[i1][i2]) begin
                  if (dp[i1][i2] > new_max) new_max <= dp[i1][i2];
                end
              end
            end

            // Compute next reach and updated DP using current reach_cur
            for (i1 = 0; i1 < 256; i1 = i1 + 1) begin
              for (i2 = 0; i2 < 256; i2 = i2 + 1) begin
                if (reach_cur[i1][i2]) begin
                  // Try assign to counter1
                  if (t[idx] <= i1) begin
                    reach_nxt[i1 - t[idx]][i2] <= 1'b1;
                    if (dp[i1 - t[idx]][i2] < (dp[i1][i2] + 1)) begin
                      dp[i1 - t[idx]][i2] <= dp[i1][i2] + 1;
                    end
                  end
                  // Try assign to counter2
                  if (t[idx] <= i2) begin
                    reach_nxt[i1][i2 - t[idx]] <= 1'b1;
                    if (dp[i1][i2 - t[idx]] < (dp[i1][i2] + 1)) begin
                      dp[i1][i2 - t[idx]] <= dp[i1][i2] + 1;
                    end
                  end
                  // Copy current pair to next (skip assignment)
                  reach_nxt[i1][i2] <= 1'b1;
                end
              end
            end

            // Move to next customer
            idx <= idx + 1;
          end else begin
            // After processing all customers, compute final result
            result_count <= new_max[3:0];
            max_customers <= new_max[3:0];
            done <= 1'b1;
            state <= DONE;
          end
        end

        DONE: begin
          // Hold outputs until next start or reset
          done <= 1'b1;
          max_customers <= result_count;
          if (start) begin
            // Restart if start is pulsed during DONE
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
