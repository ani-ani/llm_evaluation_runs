module soda_pouring (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [6:0] a [7:0],
  input [6:0] b [7:0],
  output reg [3:0] k,
  output reg [9:0] t,
  output reg done
);
  
  localparam SUM = 800;            // Max total soda amount
  localparam C_MAX = 8;            // Max bottles
  localparam INF = 10'b1111111111; // Infinity for 10-bit values (0..1023)
  localparam IDLE = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE = 2'b10;
  
  reg [1:0] state, state_next;
  reg [3:0] cycle, cycle_next;     // Latency counter (0..9 for 10 cycles total)
  reg [6:0] n_reg, n_next;
  reg [6:0] a_reg [7:0];
  reg [6:0] b_reg [7:0];
  reg [10:0] TSUM, TSUM_next;      // Total soda (0..800), needs 10 bits but use 11 for safety
  
  // 2D RAM-based DP: dp_sum[s][m] = minimal total pour time (sum of a) achievable using exactly m bottles with total soda exactly s; INF if impossible.
  // Sum index: 0..SUM (0..800). Bottle index: 0..C_MAX (0..8). 801 x 9 entries of 10 bits each.
  reg [9:0] dp_sum [0:SUM][0:C_MAX];
  
  // Intermediate 1D buffers for DP (ping-pong over bottle count)
  reg [9:0] prev_dp [0:SUM];
  reg [9:0] next_dp [0:SUM];
  
  integer i, j, s; // loop variables
  
  // State, registers, counters update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle <= 4'b0;
      n_reg <= 7'b0;
      TSUM <= 11'b0;
      k <= 4'b0;
      t <= 10'b0;
      done <= 1'b0;
      // Clear a/b registers
      for (i = 0; i < 8; i = i + 1) begin
        a_reg[i] <= 7'b0;
        b_reg[i] <= 7'b0;
      end
      // Initialize dp_sum to INF (only dp[0][0]=0 will be written during compute)
      for (s = 0; s <= SUM; s = s + 1) begin
        for (j = 0; j <= C_MAX; j = j + 1) begin
          dp_sum[s][j] <= INF;
        end
      end
    end else begin
      state <= state_next;
      cycle <= cycle_next;
      n_reg <= n_next;
      TSUM <= TSUM_next;
      k <= k; // will be assigned in DONE
      t <= t; // will be assigned in DONE
      done <= done; // will be assigned in DONE
      // Latch inputs when entering COMPUTE
      if (state_next == COMPUTE) begin
        n_next <= n;
        TSUM_next <= {4'b0, a[0]} + {4'b0, a[1]} + {4'b0, a[2]} + {4'b0, a[3]}
                    + {4'b0, a[4]} + {4'b0, a[5]} + {4'b0, a[6]} + {4'b0, a[7]};
        for (i = 0; i < 8; i = i + 1) begin
          a_reg[i] <= a[i];
          b_reg[i] <= b[i]; // not used in current objective but latched as per spec
        end
      end
    end
  end
  
  // Combinational next-state logic
  always @* begin
    state_next = state;
    cycle_next = cycle;
    n_next = n_reg;
    TSUM_next = TSUM;
    
    case (state)
      IDLE: begin
        done = 1'b0;
        k = 4'b0;
        t = 10'b0;
        if (start) begin
          state_next = COMPUTE;
          cycle_next = 4'b1; // First compute cycle
          // pre-latch n and TSUM immediately on start
          n_next = n;
          TSUM_next = {4'b0, a[0]} + {4'b0, a[1]} + {4'b0, a[2]} + {4'b0, a[3]}
                     + {4'b0, a[4]} + {4'b0, a[5]} + {4'b0, a[6]} + {4'b0, a[7]};
          for (i = 0; i < 8; i = i + 1) begin
            a_reg[i] = a[i];
            b_reg[i] = b[i];
          end
        end
      end
      
      COMPUTE: begin
        done = 1'b0;
        k = 4'b0;
        t = 10'b0;
        // Dynamic programming over bottles, ping-pong on 1D buffers; also write results to dp_sum RAM
        if (cycle == 0) begin
          // Initialize: only sum 0 achievable with 0 bottles at cost 0
          for (s = 0; s <= SUM; s = s + 1) begin
            prev_dp[s] = (s == 0) ? 10'b0 : INF;
            next_dp[s] = INF;
          end
        end else begin
          // At each cycle, incorporate bottle (cycle-1)
          if (cycle <= n_reg) begin
            // Reset next_dp each cycle
            for (s = 0; s <= SUM; s = s + 1) next_dp[s] = INF;
            
            // Perform 0/1 knapscak step on sums and bottle count
            for (s = 0; s <= SUM; s = s + 1) begin
              if (prev_dp[s] != INF) begin
                // not take bottle (already represented in next_dp by carry-over from previous iteration)
                if (next_dp[s] > prev_dp[s]) next_dp[s] = prev_dp[s];
                // take bottle (if within range)
                if (s + a_reg[cycle-1] <= SUM) begin
                  // Cost = sum of a; push to next_dp; also write to dp_sum
                  if (next_dp[s + a_reg[cycle-1]] > (prev_dp[s] + a_reg[cycle-1])) begin
                    next_dp[s + a_reg[cycle-1]] = prev_dp[s] + a_reg[cycle-1];
                  end
                  dp_sum[s + a_reg[cycle-1]][cycle] = next_dp[s + a_reg[cycle-1]];
                end
              end
            end
            // Also carry over entries where we didn't take the current bottle: already set via next_dp init + comparison
            // Swap buffers
            for (s = 0; s <= SUM; s = s + 1) prev_dp[s] = next_dp[s];
          end else begin
            // After all bottles processed, still write final dp_sum for bottle count = n_reg
            if (cycle == (n_reg + 1)) begin
              for (s = 0; s <= SUM; s = s + 1) begin
                dp_sum[s][n_reg] = prev_dp[s];
              end
            end
          end
        end
        
        // Cycle counting and state transition
        if (cycle < 4'd10) begin
          cycle_next = cycle + 1;
          state_next = COMPUTE;
        end else begin
          state_next = DONE;
          cycle_next = 4'b0;
        end
      end
      
      DONE: begin
        // Determine minimal k and t lexicographically:
        // 1) Minimal bottles k s.t. there exists a subset of exactly k bottles with total soda = TSUM.
        // 2) Among those, minimal t is min over s where dp_sum[s][k]!=INF and s==TSUM of dp_sum[s][k];
        //    Since sum must match TSUM, this reduces to dp_sum[TSUM][k] (if finite).
        //    However to be robust, we also scan in case of non-determinism.
        
        k = 4'b0;
        t = 10'b0;
        
        // Find minimal k where total sum exactly TSUM is achievable
        for (j = 1; j <= C_MAX; j = j + 1) begin
          if (TSUM <= SUM && dp_sum[TSUM][j] != INF) begin
            k = j;
            break;
          end
        end
        
        // If k == 0, no solution; else minimal time is dp_sum[TSUM][k]
        if (k == 0) begin
          t = 10'b0;
        end else begin
          t = dp_sum[TSUM][k];
        end
        
        done = 1'b1;
        
        // Stay in DONE until start deasserts; on next start, go to COMPUTE
        if (!start) begin
          state_next = IDLE;
          cycle_next = 4'b0;
        end else begin
          state_next = DONE;
          cycle_next = 4'b0;
        end
      end
      
      default: begin
        state_next = IDLE;
        cycle_next = 4'b0;
        done = 1'b0;
        k = 4'b0;
        t = 10'b0;
      end
    endcase
  end
  
endmodule
