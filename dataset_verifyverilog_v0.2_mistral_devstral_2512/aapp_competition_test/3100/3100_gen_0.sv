module fruit_arrangement (
  input clk,
  input rst_n,
  input start,
  input [4:0] A,
  input [4:0] C,
  input [4:0] M,
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam MOD = 32'd1000000007;
  localparam IDLE = 3'b000;
  localparam INIT = 3'b001;
  localparam COMPUTE = 3'b010;
  localparam SUM = 3'b011;
  localparam DONE = 3'b100;

  // State machine
  reg [2:0] state = IDLE;

  // DP array: dp[a][c][m][last]
  reg [31:0] dp [0:10][0:10][0:10][0:3];

  // Counters for state iteration
  reg [3:0] a_cnt = 0;
  reg [3:0] c_cnt = 0;
  reg [3:0] m_cnt = 0;
  reg [1:0] last_cnt = 0;

  // Temporary variables for computation
  reg [31:0] temp_sum = 0;
  reg [31:0] temp_val = 0;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      a_cnt <= 0;
      c_cnt <= 0;
      m_cnt <= 0;
      last_cnt <= 0;
      temp_sum <= 0;
      temp_val <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 0;
          end
        end

        INIT: begin
          // Initialize DP array to 0
          if (a_cnt == 10 && c_cnt == 10 && m_cnt == 10 && last_cnt == 3) begin
            // Set base case
            dp[0][0][0][0] <= 1;
            state <= COMPUTE;
            a_cnt <= 0;
            c_cnt <= 0;
            m_cnt <= 0;
            last_cnt <= 0;
          end else begin
            // Initialize all entries to 0
            dp[a_cnt][c_cnt][m_cnt][last_cnt] <= 0;
            // Increment counters
            if (last_cnt == 3) begin
              last_cnt <= 0;
              if (m_cnt == 10) begin
                m_cnt <= 0;
                if (c_cnt == 10) begin
                  c_cnt <= 0;
                  a_cnt <= a_cnt + 1;
                end else begin
                  c_cnt <= c_cnt + 1;
                end
              end else begin
                m_cnt <= m_cnt + 1;
              end
            end else begin
              last_cnt <= last_cnt + 1;
            end
          end
        end

        COMPUTE: begin
          // Compute transitions
          if (a_cnt == 10 && c_cnt == 10 && m_cnt == 10 && last_cnt == 3) begin
            state <= SUM;
            a_cnt <= 0;
            c_cnt <= 0;
            m_cnt <= 0;
            last_cnt <= 0;
          end else begin
            // Current state value
            temp_val = dp[a_cnt][c_cnt][m_cnt][last_cnt];

            // Transition to apple
            if (last_cnt != 1 && a_cnt < 10) begin
              dp[a_cnt + 1][c_cnt][m_cnt][1] = (dp[a_cnt + 1][c_cnt][m_cnt][1] + temp_val) % MOD;
            end

            // Transition to cherry
            if (last_cnt != 2 && c_cnt < 10) begin
              dp[a_cnt][c_cnt + 1][m_cnt][2] = (dp[a_cnt][c_cnt + 1][m_cnt][2] + temp_val) % MOD;
            end

            // Transition to mango
            if (last_cnt != 3 && m_cnt < 10) begin
              dp[a_cnt][c_cnt][m_cnt + 1][3] = (dp[a_cnt][c_cnt][m_cnt + 1][3] + temp_val) % MOD;
            end

            // Increment counters
            if (last_cnt == 3) begin
              last_cnt <= 0;
              if (m_cnt == 10) begin
                m_cnt <= 0;
                if (c_cnt == 10) begin
                  c_cnt <= 0;
                  a_cnt <= a_cnt + 1;
                end else begin
                  c_cnt <= c_cnt + 1;
                end
              end else begin
                m_cnt <= m_cnt + 1;
              end
            end else begin
              last_cnt <= last_cnt + 1;
            end
          end
        end

        SUM: begin
          // Sum the final states
          if (last_cnt == 0) begin
            temp_sum = 0;
          end

          if (last_cnt == 1) begin
            temp_sum = (temp_sum + dp[A][C][M][1]) % MOD;
          end else if (last_cnt == 2) begin
            temp_sum = (temp_sum + dp[A][C][M][2]) % MOD;
          end else if (last_cnt == 3) begin
            temp_sum = (temp_sum + dp[A][C][M][3]) % MOD;
            result <= temp_sum;
            done <= 1;
            state <= DONE;
          end

          last_cnt <= last_cnt + 1;
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: begin
          state <= IDLE;
          done <= 0;
        end
      endcase
    end
  end

endmodule