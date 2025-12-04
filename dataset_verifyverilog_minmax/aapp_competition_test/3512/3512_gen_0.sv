module tsp_special (
  input  clk,                     // system clock
  input  rst_n,                   // active-low reset
  input  start,                   // pulse high to start computation
  input  [2:0] n,                 // number of cities (2-8)
  input  [63:0][9:0] dist_matrix, // flattened 8x8 distance matrix (each entry 10 bits)
  output reg [12:0] min_duration, // minimum total duration (13-bit output)
  output reg done                 // high when result valid
);

  // Parameters
  localparam MAX_N   = 8;
  localparam INF     = 13'h1FFF;        // Larger than any possible path cost (max path cost < 4095)
  localparam DP_SIZE = 1 << (MAX_N-1);  // 128 for N=8, smaller for smaller N (used as safe upper bound)
  localparam SBITS   = $clog2(MAX_N);   // State bits to encode visited count up to 2^(N-1)

  // State machine
  typedef enum logic [1:0] {IDLE=2'd0, RUN=2'd1, DONE=2'd2} fsm_e;
  fsm_e state, next_state;

  // DP array: dp[state][left][right] = cost
  // state: 0..(1<<(N-1))-1 (visit set represented by {left+1 .. right-1})
  // left, right: 0..(N-1)
  logic [12:0] dp[DP_SIZE][MAX_N][MAX_N];
  reg [SBITS-1:0] iter;             // current DP iteration (number of cities visited so far beyond the base 2)
  reg [7:0] cities_n;
  logic valid_start;

  // Compute mask bit for position k (k in 0..N-1)
  function automatic logic bit_in_range;
    input [7:0] k;
    input [7:0] N;
    begin
      bit_in_range = (k < N);
    end
  endfunction

  // Distance access with safety: return INF if indices are invalid (should not happen for valid states)
  function automatic [12:0] get_dist;
    input [7:0] i;
    input [7:0] j;
    input [7:0] N;
    input [63:0][9:0] D;
    logic valid;
  begin
    valid = (i < N) && (j < N);
    if (!valid) begin
      get_dist = INF;
    end else begin
      get_dist = D[i*8 + j][9:0];
    end
  end
  endfunction

  // Sequential logic: reset, state transition, and DP updates
  integer li, lj, rj, sidx;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      min_duration <= 13'd0;
      iter <= 0;
      cities_n <= 0;
      // Initialize DP with INF
      for (sidx = 0; sidx < DP_SIZE; sidx++) begin
        for (li = 0; li < MAX_N; li++) begin
          for (lj = 0; lj < MAX_N; lj++) begin
            dp[sidx][li][lj] <= INF;
          end
        end
      end
    end else begin
      // Defaults (can be overridden in states)
      next_state <= state;
      done <= 1'b0;
      iter <= iter;
      cities_n <= cities_n;
      // Maintain DP across RUN; only reset dp in IDLE and at RUN start

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            cities_n <= {5'd0, n};
            // Reset DP to INF
            for (sidx = 0; sidx < DP_SIZE; sidx++) begin
              for (li = 0; li < MAX_N; li++) begin
                for (lj = 0; lj < MAX_N; lj++) begin
                  dp[sidx][li][lj] <= INF;
                end
              end
            end
            // Initialize base states: visited range is {k} => left=k, right=k, state=0
            for (int k = 0; k < MAX_N; k++) begin
              dp[0][k][k] <= 13'd0;
            end
            // Prepare for RUN: iter counts how many extra cities beyond 2 are already included in the visited interval
            // Start with the base interval having size 1 => iter=0
            iter <= 0;
            next_state <= RUN;
          end
        end

        RUN: begin
          // Iteratively expand intervals by one city on either end
          if (iter < (cities_n - 2)) begin
            // Expand current state by one city to the left or right
            // For each valid left,right with visited count = iter+2, we try to add (left-1) or (right+1)
            for (int left = 0; left < MAX_N; left++) begin
              for (int right = 0; right < MAX_N; right++) begin
                if (left <= right) begin
                  // Current visited size in cities: (right - left + 1)
                  // We are building up from size iter+1 to iter+2 (after this iteration)
                  if ((right - left + 1) == (iter + 1)) begin
                    // Try expand to left
                    if (left > 0) begin
                      // Prev state is same left+1, right with smaller size (iter)
                      // The DP entry to expand from is dp[iter][left+1][right]
                      if (dp[iter][left+1][right] != INF) begin
                        // Cost = dp + dist[(left) -> (left+1)]
                        if (bit_in_range(left, cities_n) && bit_in_range(left+1, cities_n)) begin
                          dp[iter+1][left][right] <= dp[iter][left+1][right] + dist_matrix[left*8 + (left+1)];
                        end
                      end
                    end
                    // Try expand to right
                    if (right < (MAX_N-1)) begin
                      if (dp[iter][left][right+1] != INF) begin
                        // Cost = dp + dist[(right) -> (right+1)]
                        if (bit_in_range(right, cities_n) && bit_in_range(right+1, cities_n)) begin
                          dp[iter+1][left][right] <= dp[iter][left][right+1] + dist_matrix[right*8 + (right+1)];
                        end
                      end
                    end
                  end
                end
              end
            end
            iter <= iter + 1;
          end else begin
            // All expansions done: pick best with full range [0 .. N-1]
            // Interval size must be N, i.e., left=0 and right=N-1, iter must be N-2
            // (Iter equals cities_n-2, which is N-2)
            if (cities_n >= 2) begin
              // Evaluate best cost for left=0, right=N-1 across state index (should be one: iter = N-2)
              logic [12:0] best;
              best = INF;
              // Only the state index matching (N-2) is valid for full range (since left=0,right=N-1 => size = N => iter = N-2)
              // But we also scan other indices safely.
              for (sidx = 0; sidx < DP_SIZE; sidx++) begin
                if (dp[sidx][0][cities_n-1] < best) begin
                  best = dp[sidx][0][cities_n-1];
                end
              end
              min_duration <= best;
            end else begin
              // If n == 1, duration is 0
              min_duration <= 13'd0;
            end
            done <= 1'b1;
            next_state <= DONE;
          end
        end

        DONE: begin
          // Hold result and done until next start
          done <= 1'b1;
          if (start) begin
            // Restart on start pulse (like IDLE but immediate)
            cities_n <= {5'd0, n};
            // Reset DP to INF
            for (sidx = 0; sidx < DP_SIZE; sidx++) begin
              for (li = 0; li < MAX_N; li++) begin
                for (lj = 0; lj < MAX_N; lj++) begin
                  dp[sidx][li][lj] <= INF;
                end
              end
            end
            for (int k = 0; k < MAX_N; k++) begin
              dp[0][k][k] <= 13'd0;
            end
            iter <= 0;
            next_state <= RUN;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
      state <= next_state;
    end
  end
endmodule