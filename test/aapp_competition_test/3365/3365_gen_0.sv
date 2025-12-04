module max_partition_score(
  input clk,
  input rst_n,
  input start,
  input [7:0] v0,
  input [7:0] v1,
  input [7:0] v2,
  input [7:0] v3,
  input [7:0] v4,
  input [7:0] v5,
  input [7:0] v6,
  input [7:0] v7,
  input [1:0] k,
  output reg [7:0] score,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE         = 3'd0,
    COMPUTE_GCD  = 3'd1,
    FIND_PRIMES  = 3'd2,
    DP_CALC      = 3'd3,
    DONE_STATE   = 3'd4
  } state_t;

  state_t state, next_state;

  // Store inputs
  reg [7:0] val [0:7];

  // Subarray GCDs (8x8, only j>=i used)
  reg [7:0] gcd_tab [0:7][0:7];

  // Prime score for each subarray gcd (largest prime divisor)
  reg [7:0] prime_tab [0:7][0:7];

  // DP table: dp[r][end] : max score using r partitions for prefix ending at end
  // r = 1..4 (index 0 unused), end = 0..7
  reg [7:0] dp [0:4][0:7];

  // Latched k
  reg [2:0] k_reg;  // up to 4

  // Counters
  reg [5:0] gcd_idx;      // 0..35
  reg [5:0] prime_idx;    // 0..35
  reg [5:0] dp_idx;       // generic counter for dp

  // Helper indices
  reg [2:0] s_i, s_j;     // for mapping 0..35 to (i,j)

  // GCD function (combinational, Euclidean)
  function automatic [7:0] gcd8(input [7:0] a_in, input [7:0] b_in);
    reg [7:0] a, b, t;
    begin
      a = a_in;
      b = b_in;
      if (a == 0) begin
        gcd8 = b;
      end else if (b == 0) begin
        gcd8 = a;
      end else begin
        while (b != 0) begin
          t = a % b;
          a = b;
          b = t;
        end
        gcd8 = a;
      end
    end
  endfunction

  // Largest prime divisor function (0 if none)
  function automatic [7:0] largest_prime_div(input [7:0] x_in);
    integer d;
    reg is_prime;
    reg [7:0] x;
    reg [7:0] best;
    integer j;
    begin
      x = x_in;
      best = 0;
      if (x < 2) begin
        largest_prime_div = 0;
      end else begin
        for (d = 2; d <= x; d = d + 1) begin
          if (x % d == 0) begin
            // check if d is prime
            is_prime = 1'b1;
            if (d < 2) is_prime = 1'b0;
            else begin
              for (j = 2; j * j <= d; j = j + 1) begin
                if (d % j == 0) begin
                  is_prime = 1'b0;
                  j = d; // break
                end
              end
            end
            if (is_prime && d > best)
              best = d[7:0];
          end
        end
        largest_prime_div = best;
      end
    end
  endfunction

  // Map linear index (0..35) to (i,j) for all subarrays i<=j
  task automatic idx_to_ij(input [5:0] idx, output [2:0] oi, output [2:0] oj);
    integer base;
    begin
      base = 0;
      oi = 0;
      oj = 0;
      if (idx < 8) begin
        oi = 0;
        oj = idx[2:0];
      end else if (idx < 15) begin
        base = 8;
        oi = 1;
        oj = (idx - base) + 1;
      end else if (idx < 21) begin
        base = 15;
        oi = 2;
        oj = (idx - base) + 2;
      end else if (idx < 26) begin
        base = 21;
        oi = 3;
        oj = (idx - base) + 3;
      end else if (idx < 30) begin
        base = 26;
        oi = 4;
        oj = (idx - base) + 4;
      end else if (idx < 33) begin
        base = 30;
        oi = 5;
        oj = (idx - base) + 5;
      end else if (idx < 35) begin
        base = 33;
        oi = 6;
        oj = (idx - base) + 6;
      end else begin
        // idx == 35
        oi = 7;
        oj = 7;
      end
    end
  endtask

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COMPUTE_GCD;
      end
      COMPUTE_GCD: begin
        if (gcd_idx == 6'd35) next_state = FIND_PRIMES;
      end
      FIND_PRIMES: begin
        if (prime_idx == 6'd35) next_state = DP_CALC;
      end
      DP_CALC: begin
        // We'll complete DP deterministically; use dp_idx terminal to move
        if (dp_idx == 6'd63) next_state = DONE_STATE;
      end
      DONE_STATE: begin
        // stay done until start deasserted and reasserted
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer i, j, r;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      done      <= 1'b0;
      score     <= 8'd0;
      gcd_idx   <= 6'd0;
      prime_idx <= 6'd0;
      dp_idx    <= 6'd0;
      k_reg     <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        val[i] <= 8'd0;
        for (j = 0; j < 8; j = j + 1) begin
          gcd_tab[i][j]   <= 8'd0;
          prime_tab[i][j] <= 8'd0;
        end
      end
      for (r = 0; r < 5; r = r + 1) begin
        for (i = 0; i < 8; i = i + 1) begin
          dp[r][i] <= 8'd0;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          score     <= 8'd0;
          gcd_idx   <= 6'd0;
          prime_idx <= 6'd0;
          dp_idx    <= 6'd0;
          if (start) begin
            // latch inputs
            val[0] <= v0;
            val[1] <= v1;
            val[2] <= v2;
            val[3] <= v3;
            val[4] <= v4;
            val[5] <= v5;
            val[6] <= v6;
            val[7] <= v7;
            k_reg  <= (k == 2'd0) ? 3'd1 : {1'b0, k}; // ensure at least 1
          end
        end

        COMPUTE_GCD: begin
          // Compute one subarray gcd per cycle (idx_to_ij)
          idx_to_ij(gcd_idx, s_i, s_j);
          if (s_i == s_j) begin
            gcd_tab[s_i][s_j] <= val[s_i];
          end else begin
            // gcd over consecutive range [s_i..s_j]
            reg [7:0] gtmp;
            gtmp = val[s_i];
            for (j = s_i + 1; j <= s_j; j = j + 1) begin
              gtmp = gcd8(gtmp, val[j]);
            end
            gcd_tab[s_i][s_j] <= gtmp;
          end
          if (gcd_idx < 6'd35)
            gcd_idx <= gcd_idx + 6'd1;
        end

        FIND_PRIMES: begin
          // For each gcd_tab[i][j], compute largest prime divisor
          idx_to_ij(prime_idx, s_i, s_j);
          prime_tab[s_i][s_j] <= largest_prime_div(gcd_tab[s_i][s_j]);
          if (prime_idx < 6'd35)
            prime_idx <= prime_idx + 6'd1;
        end

        DP_CALC: begin
          // We structure DP in phases encoded into dp_idx for simplicity.
          // Phase 0: init dp[1][*]
          // Phase 1+: compute dp[2..k_reg][*]
          // We will over-iterate safely within bounds; final result at dp[k_reg][7].

          if (dp_idx == 6'd0) begin
            // initialize dp to 0
            for (r = 0; r < 5; r = r + 1)
              for (i = 0; i < 8; i = i + 1)
                dp[r][i] <= 8'd0;
          end

          // Phase 1: fill dp[1][end]
          if (dp_idx >= 6'd0 && dp_idx <= 6'd7) begin
            i = dp_idx[2:0]; // end index
            // one partition: region [0..i]
            dp[1][i] <= prime_tab[0][i];
          end

          // Phase 2+: compute for r=2..k_reg
          // We'll encode loops in dp_idx ranges:
          // For each r, for end from (r-1) to 7, compute:
          //   dp[r][end] = max over split from (r-2)..(end-1) of
          //                min(dp[r-1][split], prime_tab[split+1][end])

          // We map dp_idx to (r,end,split) iteratively.
          // Simple nested-like scheduling within 64 cycles is feasible.

          // We'll implement a small FSM-like unrolled loops using static regs.

          // Use static regs to track r,end,split once dp_idx passes init phase.
          // To keep synthesizable and deterministic, we derive them from dp_idx.

          // Derived indices
          reg [2:0] rr;
          reg [2:0] ee;
          reg [2:0] ss;
          reg [7:0] best_val;
          integer base_idx;

          // Only do DP for k_reg >= 2
          if (k_reg >= 3'd2) begin
            // dp_idx 8..63 reserved for all r>=2 calculations
            if (dp_idx >= 6'd8) begin
              // We'll process one (r,end) pair per several cycles using a simple deterministic mapping.
              // Design: for each r=2..4, for each end= (r-1)..7, in one cycle compute full max over splits.
              // This is acceptable since small sizes and combinational loops allowed.

              // Map linear index lp = dp_idx - 8 (0..55) to (rr,ee)
              base_idx = dp_idx - 6'd8;

              if (base_idx < 14) begin
                // r=2, end from1..7 (7 entries)
                rr = 3'd2;
                ee = (base_idx[5:0] >> 1) + 3'd1; // but we need only 7; refine below
              end

              // Instead of clever mapping, implement explicit compute based on dp_idx ranges.

              // r=2
              if (dp_idx >= 6'd8 && dp_idx <= 6'd14) begin
                ee = dp_idx - 6'd7; // 1..7
                rr = 3'd2;
                // compute dp[2][ee]
                best_val = 8'd0;
                for (ss = 0; ss <= ee-1; ss = ss + 1) begin
                  // prefix [0..ss] has r-1 partitions
                  if (dp[rr-1][ss] != 8'd0 && prime_tab[ss+1][ee] != 8'd0) begin
                    reg [7:0] cand_min;
                    cand_min = (dp[rr-1][ss] < prime_tab[ss+1][ee]) ? dp[rr-1][ss] : prime_tab[ss+1][ee];
                    if (cand_min > best_val)
                      best_val = cand_min;
                  end
                end
                dp[rr][ee] <= best_val;
              end

              // r=3
              if (k_reg >= 3'd3) begin
                if (dp_idx >= 6'd15 && dp_idx <= 6'd20) begin
                  ee = dp_idx - 6'd13; // 2..7
                  rr = 3'd3;
                  best_val = 8'd0;
                  for (ss = 1; ss <= ee-1; ss = ss + 1) begin
                    if (dp[rr-1][ss] != 8'd0 && prime_tab[ss+1][ee] != 8'd0) begin
                      reg [7:0] cand_min3;
                      cand_min3 = (dp[rr-1][ss] < prime_tab[ss+1][ee]) ? dp[rr-1][ss] : prime_tab[ss+1][ee];
                      if (cand_min3 > best_val)
                        best_val = cand_min3;
                    end
                  end
                  dp[rr][ee] <= best_val;
                end
              end

              // r=4
              if (k_reg >= 3'd4) begin
                if (dp_idx >= 6'd21 && dp_idx <= 6'd24) begin
                  ee = dp_idx - 6'd17; // 4..7 (using mapping; ensure >=3)
                  rr = 3'd4;
                  if (ee < 3'd3) ee = 3'd3; // safety, though ranges chosen
                  best_val = 8'd0;
                  for (ss = 2; ss <= ee-1; ss = ss + 1) begin
                    if (dp[rr-1][ss] != 8'd0 && prime_tab[ss+1][ee] != 8'd0) begin
                      reg [7:0] cand_min4;
                      cand_min4 = (dp[rr-1][ss] < prime_tab[ss+1][ee]) ? dp[rr-1][ss] : prime_tab[ss+1][ee];
                      if (cand_min4 > best_val)
                        best_val = cand_min4;
                    end
                  end
                  dp[rr][ee] <= best_val;
                end
              end
            end
          end

          // advance dp_idx up to 63 then hold
          if (dp_idx < 6'd63)
            dp_idx <= dp_idx + 6'd1;
        end

        DONE_STATE: begin
          done <= 1'b1;
          // Choose score from appropriate dp row; require last index 7
          case (k_reg)
            3'd1: score <= dp[1][7];
            3'd2: score <= dp[2][7];
            3'd3: score <= dp[3][7];
            3'd4: score <= dp[4][7];
            default: score <= dp[1][7];
          endcase
        end

        default: begin
        end
      endcase
    end
  end

endmodule