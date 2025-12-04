module path_counter(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [3:0] N, // Max 8 (scaled from original 1e6)
  input [3:0] X, // Min x-hop (1≤X≤N)
  input [3:0] Y, // Min y-hop (1≤Y≤N)
  output reg [31:0] result, // Path count modulo 1000000007
  output reg done // High when computation completes
);

  // Local parameters
  localparam MOD = 32'd1000000007;

  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    INIT      = 2'b01,
    PROCESS   = 2'b10,
    COMPLETE  = 2'b11
  } state_t;

  state_t state, next_state;

  // 9x9 DP grid (indices 0..8 for safety, but we constrain to 0..N)
  reg [31:0] dp [0:8][0:8];

  // Indices and accumulators
  reg [3:0] i, j;           // current cell being processed
  reg [3:0] a, b;           // summation indices
  reg [31:0] sum;           // current accumulator for dp[i][j]
  reg summing;              // flag: currently accumulating for this cell

  integer x_idx, y_idx;     // for loops in reset/INIT only

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset of regs
      done   <= 1'b0;
      result <= 32'd0;
      i      <= 4'd0;
      j      <= 4'd0;
      a      <= 4'd0;
      b      <= 4'd0;
      sum    <= 32'd0;
      summing <= 1'b0;

      // Clear DP
      for (x_idx = 0; x_idx <= 8; x_idx = x_idx + 1) begin
        for (y_idx = 0; y_idx <= 8; y_idx = y_idx + 1) begin
          dp[x_idx][y_idx] <= 32'd0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= 32'd0;
          if (start) begin
            // Initialize all DP entries to 0; dp[0][0] to 1
            for (x_idx = 0; x_idx <= 8; x_idx = x_idx + 1) begin
              for (y_idx = 0; y_idx <= 8; y_idx = y_idx + 1) begin
                dp[x_idx][y_idx] <= 32'd0;
              end
            end
            dp[0][0] <= 32'd1;

            // Initialize indices for PROCESS
            i <= 4'd0;
            j <= 4'd0;
            a <= 4'd0;
            b <= 4'd0;
            sum <= 32'd0;
            summing <= 1'b0;
          end
        end

        INIT: begin
          // Single-cycle transition placeholder (already initialized in IDLE when start seen)
          // Prepare for PROCESS: start from (0,0)
          i <= 4'd0;
          j <= 4'd0;
          a <= 4'd0;
          b <= 4'd0;
          sum <= 32'd0;
          summing <= 1'b0;
        end

        PROCESS: begin
          // Iterate over all cells (i,j) with 0<=i<=N, 0<=j<=N
          // dp[0][0] is preset to 1; for (0,0) there is nothing to sum.

          // Skip summation for base cell (0,0)
          if ((i == 4'd0) && (j == 4'd0)) begin
            // Move to next cell
            if (j < N) begin
              j <= j + 4'd1;
            end else begin
              j <= 4'd0;
              if (i < N) begin
                i <= i + 4'd1;
              end
            end
            summing <= 1'b0;
            sum <= 32'd0;
            a <= 4'd0;
            b <= 4'd0;
          end else begin
            // For cell (i,j), compute sum of dp[a][b] for 0<=a<=i-X, 0<=b<=j-Y
            // Only if i>=X and j>=Y; else dp[i][j] stays 0.
            if (!summing) begin
              sum <= 32'd0;
              if ((i >= X) && (j >= Y)) begin
                a <= 4'd0;
                b <= 4'd0;
                summing <= 1'b1;
              end else begin
                // No valid predecessors; dp[i][j] = 0 (already 0)
                dp[i][j] <= 32'd0;
                // Move to next cell
                if (j < N) begin
                  j <= j + 4'd1;
                end else begin
                  j <= 4'd0;
                  if (i < N) begin
                    i <= i + 4'd1;
                  end
                end
              end
            end else begin
              // summing == 1: accumulate over rectangle [0..i-X][0..j-Y]
              if (a <= (i - X)) begin
                if (b <= (j - Y)) begin
                  // sum = (sum + dp[a][b]) % MOD
                  sum <= (sum + dp[a][b]);
                  // advance b
                  if (b < (j - Y)) begin
                    b <= b + 4'd1;
                  end else begin
                    b <= 4'd0;
                    a <= a + 4'd1;
                  end
                end else begin
                  // safety, should not happen due to control above
                  b <= 4'd0;
                  a <= a + 4'd1;
                end
              end else begin
                // Finished accumulation, write dp[i][j] = sum % MOD
                dp[i][j] <= (sum % MOD);
                summing <= 1'b0;
                sum <= 32'd0;
                a <= 4'd0;
                b <= 4'd0;
                // Move to next cell
                if (j < N) begin
                  j <= j + 4'd1;
                end else begin
                  j <= 4'd0;
                  if (i < N) begin
                    i <= i + 4'd1;
                  end
                end
              end
            end
          end
        end

        COMPLETE: begin
          done <= 1'b1;
          // result already assigned when entering COMPLETE
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

  // Next state logic (combinational)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
      end

      INIT: begin
        // Move immediately to PROCESS
        next_state = PROCESS;
      end

      PROCESS: begin
        // Transition to COMPLETE when last cell (N,N) has been computed
        // Detection: when current indices move past (N,N) (i==N && j==N done and next step)
        // We monitor when i==N and j==N and not in summing and just wrote/handled that cell.
        // To keep it simple, we check if (i==N && j==N && !summing) and no further move.
        // However, moves are done in sequential block; here we approximate condition.
        // A safe deterministic condition: when i==N && j==N && !summing.
        if ((i == N) && (j == N) && (summing == 1'b0)) begin
          next_state = COMPLETE;
        end
      end

      COMPLETE: begin
        // Wait until start deasserted; then go back to IDLE
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Capture result when entering COMPLETE
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 32'd0;
    end else begin
      if ((state == PROCESS) && (next_state == COMPLETE)) begin
        result <= dp[N][N];
      end
    end
  end

endmodule