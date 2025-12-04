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

  // Constants
  localparam MOD = 32'd1000000007;
  localparam SZ  = 4'd8; // 8x8 grid (0..8)

  // State machine
  typedef enum logic [1:0] {IDLE = 2'd0, INIT = 2'd1, PROCESS = 2'd2, COMPLETE = 2'd3} state_t;
  state_t state, next_state;

  // Grid memory: [row][col]
  reg [31:0] dp [0:SZ][0:SZ];
  integer ri, ci; // reset iterators

  // DP indices
  reg [3:0] i_reg, j_reg;
  reg [3:0] i_next, j_next;
  reg [3:0] N_eff, X_eff, Y_eff;

  // Summation state for accumulating (a,b) where a<=i-X, b<=j-Y
  reg [3:0] sum_a, sum_b;
  reg [31:0] acc;
  reg sum_active;

  // Sequential state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      result <= 32'd0;
      ri <= 0;
      ci <= 0;
      i_reg <= 4'd0;
      j_reg <= 4'd0;
      sum_a <= 4'd0;
      sum_b <= 4'd0;
      acc   <= 32'd0;
      sum_active <= 1'b0;
    end else begin
      state <= next_state;
      done  <= 1'b0; // default; will be set high in COMPLETE
      case (next_state)
        IDLE: begin
          ri <= 0;
          ci <= 0;
          i_reg <= 4'd0;
          j_reg <= 4'd0;
          sum_a <= 4'd0;
          sum_b <= 4'd0;
          acc   <= 32'd0;
          sum_active <= 1'b0;
        end
        INIT: begin
          // Clear entire grid
          if (ri < SZ) begin
            dp[ri][ci] <= 32'd0;
            if (ci < SZ) ci <= ci + 1;
            else begin
              ci <= 4'd0;
              ri <= ri + 1;
            end
          end else begin
            ri <= 4'd0;
            ci <= 4'd0;
          end
        end
        PROCESS: begin
          if (sum_active) begin
            // Accumulate over the rectangle (0..i-X, 0..j-Y)
            acc <= acc + dp[sum_a][sum_b];
            if (sum_b < j_reg) sum_b <= sum_b + 1;
            else begin
              sum_b <= 4'd0;
              if (sum_a < i_reg) sum_a <= sum_a + 1;
              else begin
                // Done with accumulation; write result
                sum_active <= 1'b0;
                dp[i_reg][j_reg] <= acc + dp[i_reg][j_reg];
              end
            end
          end else begin
            // Move to next cell
            if (j_reg < N_eff) j_reg <= j_reg + 1;
            else begin
              j_reg <= 4'd0;
              if (i_reg < N_eff) i_reg <= i_reg + 1;
            end
          end
        end
        COMPLETE: begin
          done <= 1'b1;
          result <= dp[N_eff][N_eff];
        end
        default: ;
      endcase
    end
  end

  // Combinational next-state logic and sum trigger
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          // Clamp inputs to [0,8]
          N_eff = (N > 4'd8) ? 4'd8 : N;
          // Clamp X,Y to at least 1 to avoid zero-hop ambiguity
          X_eff = (X < 4'd1) ? 4'd1 : X;
          Y_eff = (Y < 4'd1) ? 4'd1 : Y;
          next_state = INIT;
        end
      end
      INIT: begin
        // Wait until we finish the clearing loop (ri==SZ && ci==0)
        if (ri == 4'd8 && ci == 4'd0) begin
          // Set DP[0][0] = 1; others already 0
          dp[4'd0][4'd0] = 32'd1;
          i_reg = 4'd0;
          j_reg = 4'd0;
          sum_a = 4'd0;
          sum_b = 4'd0;
          acc   = 32'd0;
          sum_active = 1'b0;
          next_state = PROCESS;
        end
      end
      PROCESS: begin
        // If we are not in a summation phase, decide whether to start one or move to next cell
        if (!sum_active) begin
          // If we just finished a cell (write already done last cycle), prepare next sum
          // Start summation only if there is a valid rectangle: i>=X_eff && j>=Y_eff
          if (i_reg >= X_eff && j_reg >= Y_eff) begin
            sum_a = 4'd0;
            sum_b = 4'd0;
            acc   = 32'd0;
            // Start accumulation next cycle by setting sum_active=1; we will add dp[0][0] in first cycle
            // To avoid extra cycle, we set it now and rely on the accumulation logic in the same cycle.
            sum_active = 1'b1;
          end else begin
            // No valid predecessors: dp[i][j] stays 0; advance to next cell
            if (j_reg < N_eff) begin
              // Stay in PROCESS, j will increment in the same cycle via sequential block
            end else if (i_reg < N_eff) begin
              // j wraps to 0, i increments
            end else begin
              next_state = COMPLETE;
            end
          end
        end else begin
          // Summation is active; when it completes, write occurs (in sequential block)
          // After write, we determine if we are done
          if (sum_a == i_reg && sum_b == j_reg) begin
            // After this cycle, sequential block writes the result and sets sum_active=0.
            // Determine if all cells are done to transition next cycle.
            if (i_reg == N_eff && j_reg == N_eff) next_state = COMPLETE;
          end
        end
      end
      COMPLETE: begin
        next_state = IDLE; // Ready for next start
      end
      default: next_state = IDLE;
    endcase
  end

  // Guard memory access (grid bounds are fixed to [0..8] by localparam)
  // All dp[] indices are derived from 4-bit registers, so they are naturally 0..15.
  // We only access within 0..8 due to loop limits and clamping.

endmodule
