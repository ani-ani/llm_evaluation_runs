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

  // Parameters
  localparam [2:0] MAX_FLIGHTS = 3'd7;
  localparam [2:0] MAX_OPEN = 3'd7;
  localparam [15:0] INF = 16'hFFFF;

  // State machine states
  localparam [1:0] IDLE = 2'd0;
  localparam [1:0] PROCESS = 2'd1;
  localparam [1:0] DONE = 2'd2;
  reg [1:0] state;

  // Internal registers
  reg [2:0] flight_index;
  reg [15:0] dp [0:7][0:7];
  reg [15:0] new_dp [0:7][0:7];
  reg [7:0] dir;
  reg processing;

  integer i, j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= IDLE;
      done <= 1'b0;
      result <= 16'd0;
      flight_index <= 3'd0;
      processing <= 1'b0;
      
      // Initialize DP table
      for (i = 0; i <= 7; i = i + 1) begin
        for (j = 0; j <= 7; j = j + 1) begin
          dp[i][j] <= INF;
        end
      end
      dp[0][0] <= 16'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            // Initialize DP table
            for (i = 0; i <= 7; i = i + 1) begin
              for (j = 0; j <= 7; j = j + 1) begin
                dp[i][j] <= INF;
              end
            end
            dp[0][0] <= 16'd0;
            flight_index <= 3'd0;
            processing <= 1'b1;
            state <= PROCESS;
            done <= 1'b0;
          end
        end

        PROCESS: begin
          if (flight_index < flight_count) begin
            // Extract direction for current flight
            dir = flight_seq[flight_index];
            
            // Initialize new_dp to INF
            for (i = 0; i <= 7; i = i + 1) begin
              for (j = 0; j <= 7; j = j + 1) begin
                new_dp[i][j] = INF;
              end
            end
            
            // Update DP for each state
            for (i = 0; i <= 7; i = i + 1) begin
              for (j = 0; j <= 7; j = j + 1) begin
                if (dp[i][j] != INF) begin
                  if (dir == 1'b0) begin
                    // Flight 1->2
                    // Option 1: one-way ticket
                    if (dp[i][j] + price_ow_12 < new_dp[i][j])
                      new_dp[i][j] = dp[i][j] + price_ow_12;
                    // Option 2: use return of open round-trip 2->1 (if j>0)
                    if (j > 0 && dp[i][j] < new_dp[i][j-1])
                      new_dp[i][j-1] = dp[i][j];
                    // Option 3: start round-trip 1->2 (if i < MAX_OPEN)
                    if (i < 7 && dp[i][j] + price_rt_12 < new_dp[i+1][j])
                      new_dp[i+1][j] = dp[i][j] + price_rt_12;
                  end else begin
                    // Flight 2->1
                    // Option 1: one-way ticket
                    if (dp[i][j] + price_ow_21 < new_dp[i][j])
                      new_dp[i][j] = dp[i][j] + price_ow_21;
                    // Option 2: use return of open round-trip 1->2 (if i>0)
                    if (i > 0 && dp[i][j] < new_dp[i-1][j])
                      new_dp[i-1][j] = dp[i][j];
                    // Option 3: start round-trip 2->1 (if j < MAX_OPEN)
                    if (j < 7 && dp[i][j] + price_rt_21 < new_dp[i][j+1])
                      new_dp[i][j+1] = dp[i][j] + price_rt_21;
                  end
                end
              end
            end
            
            // Copy new_dp to dp
            for (i = 0; i <= 7; i = i + 1) begin
              for (j = 0; j <= 7; j = j + 1) begin
                dp[i][j] <= new_dp[i][j];
              end
            end
            
            flight_index <= flight_index + 1'b1;
          end else begin
            // All flights processed
            processing <= 1'b0;
            result <= dp[0][0];
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          // Wait for next start
          done <= 1'b0;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule