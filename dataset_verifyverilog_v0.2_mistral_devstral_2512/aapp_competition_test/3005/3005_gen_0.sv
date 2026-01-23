module maximal_factoring (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  input [4:0] str_len,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    COMPUTE,
    OUTPUT
  } state_t;

  state_t state;
  reg [3:0] char_idx;  // 4-bit counter for character loading
  reg [3:0] i, j, k, L, p;  // 4-bit counters for DP computation
  reg [7:0] string [0:15];  // Internal string storage
  reg [7:0] dp [0:15][0:15];  // DP table
  reg [3:0] compute_cycle;  // Counter for compute cycles

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      char_idx <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      L <= 0;
      p <= 0;
      compute_cycle <= 0;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            char_idx <= 0;
          end
        end
        LOAD: begin
          if (char_idx == 15) begin
            state <= COMPUTE;
            i <= 0;
            L <= 2;
            compute_cycle <= 0;
          end else begin
            if (valid_in) begin
              string[char_idx] <= char_in;
              char_idx <= char_idx + 1;
            end
          end
        end
        COMPUTE: begin
          if (compute_cycle == 5000) begin
            state <= OUTPUT;
            result <= dp[0][str_len-1];
            done <= 1;
          end else begin
            compute_cycle <= compute_cycle + 1;
            // Initialize dp[i][i] = 1
            if (L == 1) begin
              if (i == 15) begin
                L <= 2;
                i <= 0;
              end else begin
                dp[i][i] <= 1;
                i <= i + 1;
              end
            end else begin
              // Compute dp[i][j] for length L
              if (i == 16 - L) begin
                i <= 0;
                L <= L + 1;
                if (L > str_len) begin
                  L <= 1;
                end
              end else begin
                j <= i + L - 1;
                // Initialize with literal weight
                dp[i][j] <= L;
                // Check all splits
                for (k = i; k < j; k = k + 1) begin
                  if (dp[i][k] + dp[k+1][j] < dp[i][j]) begin
                    dp[i][j] <= dp[i][k] + dp[k+1][j];
                  end
                end
                // Check repetitions
                for (p = 1; p <= L/2; p = p + 1) begin
                  if (L % p == 0) begin
                    reg [7:0] pattern [0:15];
                    reg match;
                    // Extract pattern
                    for (k = 0; k < p; k = k + 1) begin
                      pattern[k] <= string[i + k];
                    end
                    // Check repetition
                    match = 1;
                    for (k = p; k < L; k = k + 1) begin
                      if (string[i + k] != pattern[k % p]) begin
                        match = 0;
                      end
                    end
                    if (match && dp[i][i + p - 1] < dp[i][j]) begin
                      dp[i][j] <= dp[i][i + p - 1];
                    end
                  end
                end
                i <= i + 1;
              end
            end
          end
        end
        OUTPUT: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule