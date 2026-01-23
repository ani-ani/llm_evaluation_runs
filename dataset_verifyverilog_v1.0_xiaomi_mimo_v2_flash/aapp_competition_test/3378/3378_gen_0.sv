module min_cost_tour (
  input clk,
  input rst_n,
  input start,
  input [2:0] flight_count,
  input [7:0] flight_seq,
  input [7:0] price_ow_12,
  input [7:0] price_ow_21,
  input [7:0] price_rt_12,
  input [7:0] price_rt_21,
  output reg [15:0] result,
  output reg done
);

  // States
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] PROCESS = 2'd1;
  localparam [1:0] DONE = 2'd2;

  // Parameters
  localparam [2:0] MAX_FLIGHTS = 3'd8;
  localparam [3:0] MAX_OPEN = 4'd8;
  localparam [15:0] INF = 16'hFFFF;

  // Internal registers
  reg [1:0] state;
  reg [2:0] flight_idx;
  reg [15:0] dp [0:8][0:8];
  reg [15:0] new_dp [0:8][0:8];
  reg [3:0] i, j;
  reg [15:0] min_cost;
  reg processing;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      done <= 1'b0;
      result <= 16'd0;
      flight_idx <= 3'd0;
      processing <= 1'b0;
      // Initialize dp array
      for (i = 4'd0; i <= MAX_OPEN; i = i + 1) begin
        for (j = 4'd0; j <= MAX_OPEN; j = j + 1) begin
          dp[i][j] <= INF;
          new_dp[i][j] <= INF;
        end
      end
      dp[0][0] <= 16'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Re-initialize DP table
            for (i = 4'd0; i <= MAX_OPEN; i = i + 1) begin
              for (j = 4'd0; j <= MAX_OPEN; j = j + 1) begin
                dp[i][j] <= INF;
              end
            end
            dp[0][0] <= 16'd0;
            flight_idx <= 3'd0;
            processing <= 1'b1;
            state <= PROCESS;
          end
        end

        PROCESS: begin
          if (flight_idx < flight_count) begin
            // Initialize new_dp to INF
            for (i = 4'd0; i <= MAX_OPEN; i = i + 1) begin
              for (j = 4'd0; j <= MAX_OPEN; j = j + 1) begin
                new_dp[i][j] <= INF;
              end
            end
            // Process current flight
            for (i = 4'd0; i <= MAX_OPEN; i = i + 1) begin
              for (j = 4'd0; j <= MAX_OPEN; j = j + 1) begin
                if (dp[i][j] != INF) begin
                  // Extract direction bit
                  if (flight_seq[flight_idx] == 1'b0) begin
                    // Flight 1->2
                    // Option 1: one-way ticket
                    if (dp[i][j] + price_ow_12 < new_dp[i][j]) begin
                      new_dp[i][j] <= dp[i][j] + price_ow_12;
                    end
                    // Option 2: use return of open round-trip 2->1
                    if (j > 0) begin
                      if (dp[i][j] < new_dp[i][j-1]) begin
                        new_dp[i][j-1] <= dp[i][j];
                      end
                    end
                    // Option 3: start new round-trip 1->2
                    if (i < MAX_OPEN) begin
                      if (dp[i][j] + price_rt_12 < new_dp[i+1][j]) begin
                        new_dp[i+1][j] <= dp[i][j] + price_rt_12;
                      end
                    end
                  end else begin
                    // Flight 2->1
                    // Option 1: one-way ticket
                    if (dp[i][j] + price_ow_21 < new_dp[i][j]) begin
                      new_dp[i][j] <= dp[i][j] + price_ow_21;
                    end
                    // Option 2: use return of open round-trip 1->2
                    if (i > 0) begin
                      if (dp[i][j] < new_dp[i-1][j]) begin
                        new_dp[i-1][j] <= dp[i][j];
                      end
                    end
                    // Option 3: start new round-trip 2->1
                    if (j < MAX_OPEN) begin
                      if (dp[i][j] + price_rt_21 < new_dp[i][j+1]) begin
                        new_dp[i][j+1] <= dp[i][j] + price_rt_21;
                      end
                    end
                  end
                end
              end
            end
            // Copy new_dp to dp
            for (i = 4'd0; i <= MAX_OPEN; i = i + 1) begin
              for (j = 4'd0; j <= MAX_OPEN; j = j + 1) begin
                dp[i][j] <= new_dp[i][j];
              end
            end
            flight_idx <= flight_idx + 3'd1;
          end else begin
            // All flights processed
            result <= dp[0][0];
            processing <= 1'b0;
            done <= 1'b1;
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b0;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule