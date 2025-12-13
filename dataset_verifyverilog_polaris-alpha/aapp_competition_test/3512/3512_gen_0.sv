module tsp_special(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [63:0][9:0] dist_matrix,
  output reg [12:0] min_duration,
  output reg done
);

  // States
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_LEN    = 3'd2,
    S_DP     = 3'd3,
    S_SCAN   = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal parameters and signals
  reg [2:0] N;                    // number of cities
  reg [5:0] total_states;         // 2^N
  reg [2:0] len;                  // current subset size (1..N)
  reg [5:0] mask;                 // subset mask index
  reg [2:0] j;                    // endpoint city index
  reg [2:0] k;                    // predecessor city index

  // DP storage: dp[mask][j] = best cost ending at j with visited set = mask
  // mask up to 6 bits (for N<=6 would be enough, but N<=8 => use 8 bits indexable by [5:0])
  // We have 64 masks * 8 cities = 512 entries, each 13 bits
  reg [12:0] dp [0:63][0:7];

  // Current best computations
  reg [12:0] cur_best;
  reg [12:0] candidate;

  // Control flags
  reg computing;

  // Helper function: check if subset size of given mask equals expected len
  function automatic bit mask_size_eq(input [5:0] m, input [2:0] l);
    automatic int c;
    begin
      c = (m[0] + m[1] + m[2] + m[3] + m[4] + m[5]);
      mask_size_eq = (c == l);
    end
  endfunction

  // Helper: get distance(i,j) from flattened matrix
  function automatic [9:0] dist(input [2:0] i, input [2:0] j);
    automatic int idx;
    begin
      idx = i*8 + j;
      dist = dist_matrix[idx];
    end
  endfunction

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_LEN;
      end
      S_LEN: begin
        if (len == 0) begin
          next_state = S_LEN;
        end else if (len <= N) begin
          next_state = S_DP;
        end else begin
          next_state = S_SCAN;
        end
      end
      S_DP: begin
        // Iterate through all masks, j, k; when finished, move to next len or S_SCAN
        if (!computing) begin
          if (len < N)
            next_state = S_LEN;
          else
            next_state = S_SCAN;
        end
      end
      S_SCAN: begin
        next_state = S_DONE;
      end
      S_DONE: begin
        if (!start) next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential / control + DP operations
  integer mi, ji, ki;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      N <= 3'd0;
      total_states <= 6'd0;
      len <= 3'd0;
      mask <= 6'd0;
      j <= 3'd0;
      k <= 3'd0;
      min_duration <= 13'h1FFF;
      done <= 1'b0;
      computing <= 1'b0;
      // Clear DP
      for (mi = 0; mi < 64; mi = mi + 1) begin
        for (ji = 0; ji < 8; ji = ji + 1) begin
          dp[mi][ji] <= 13'h1FFF;
        end
      end
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            N <= n;
            total_states <= (6'd1 << n);
          end
        end

        S_INIT: begin
          // Initialize DP to INF
          for (mi = 0; mi < 64; mi = mi + 1) begin
            for (ji = 0; ji < 8; ji = ji + 1) begin
              dp[mi][ji] <= 13'h1FFF;
            end
          end
          // Starting city fixed at 0: cost 0 at mask=1, j=0
          dp[6'd1][3'd0] <= 13'd0;
          len <= 3'd2; // Next we will process subsets of size 2
          computing <= 1'b0;
        end

        S_LEN: begin
          if (len <= N) begin
            // Prepare for DP over this len
            mask <= 6'd0;
            j <= 3'd0;
            k <= 3'd0;
            computing <= 1'b1;
          end
        end

        S_DP: begin
          if (computing) begin
            // Iterate (mask, j, k) using simple nested loops unrolled over cycles
            if (mask < total_states) begin
              if (mask_size_eq(mask, len)) begin
                if (j < N) begin
                  if (mask[j]) begin
                    // compute dp[mask][j]
                    if (j == 0) begin
                      // path must start at 0; dp[mask][0] is only valid for mask==1 handled in init
                      // leave as is
                      j <= j + 3'd1;
                    end else begin
                      // find best predecessor k in mask, k!=j
                      if (k == 0) begin
                        cur_best <= 13'h1FFF;
                        k <= 3'd0;
                      end else begin
                        // do nothing
                      end

                      if (k < N) begin
                        if (mask[k] && (k != j)) begin
                          candidate <= dp[mask & ~(6'd1 << j)][k] + dist(k, j);
                          if (candidate < cur_best)
                            cur_best <= candidate;
                        end
                        k <= k + 3'd1;
                      end else begin
                        // finished scanning k for this (mask,j)
                        if (cur_best < dp[mask][j])
                          dp[mask][j] <= cur_best;
                        j <= j + 3'd1;
                        k <= 3'd0;
                      end
                    end
                  end else begin
                    j <= j + 3'd1;
                  end
                end else begin
                  // finished this mask
                  mask <= mask + 6'd1;
                  j <= 3'd0;
                  k <= 3'd0;
                end
              end else begin
                // skip masks with wrong size
                mask <= mask + 6'd1;
              end
            end else begin
              // finished all masks for this len
              computing <= 1'b0;
              len <= len + 3'd1;
            end
          end
        end

        S_SCAN: begin
          // Scan all possible end cities j for full set mask = (1<<N)-1
          // Select minimal dp[full_mask][j]
          begin
            reg [5:0] full_mask;
            reg [12:0] best_val;
            full_mask = (6'd1 << N) - 6'd1;
            best_val = 13'h1FFF;
            for (ji = 0; ji < 8; ji = ji + 1) begin
              if (ji < N) begin
                if (dp[full_mask][ji] < best_val)
                  best_val = dp[full_mask][ji];
              end
            end
            min_duration <= best_val;
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule