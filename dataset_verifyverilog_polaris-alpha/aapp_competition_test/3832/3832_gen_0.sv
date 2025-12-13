module hill_houses(
  input              clk,
  input              rst_n,
  input              start,
  input      [15:0]  hills [0:7],
  output reg [31:0]  results [0:3],
  output reg         done
);

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE    = 2'b00,
    S_PREPARE = 2'b01,
    S_COMPUTE = 2'b10,
    S_DONE    = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [3:0]  n;                 // number of non-zero hills (0..8)
  reg [2:0]  i_scan;            // index for counting non-zero hills
  reg [1:0]  k_idx;             // k index (0..3) representing k = k_idx+1
  reg [2:0]  i_idx;             // i index (0..7) for hills
  reg [1:0]  j_idx;             // j index for candidate previous house index (for scaled DP)
  reg [6:0]  cycle_cnt;         // for 100-cycle max tracking (not strictly required for function)

  // DP storage: dp[k][i]
  // k_idx in [0..3] -> k=1..4; i in [0..7]
  reg [31:0] dp [0:3][0:7];

  // current minimum for dp[k][i]
  reg [31:0] cur_min;
  reg        cur_min_valid;

  // derived signals
  wire [2:0] last_i = (n == 0) ? 3'd0 : (n - 1);

  // function to compute cost; here we use hills[i] as time cost (scaled DP placeholder)
  function automatic [31:0] cost_at;
    input [15:0] h;
    begin
      cost_at = {16'd0, h};
    end
  endfunction

  // next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_PREPARE;
      end
      S_PREPARE: begin
        // once scan completes, we move to compute
        // transition controlled in seq block when i_scan reaches 7
        if (i_scan == 3'd7)
          next_state = S_COMPUTE;
      end
      S_COMPUTE: begin
        // when all k and i processed, go to DONE
        if ((k_idx == 2'd3) && (i_idx == last_i) && cur_min_valid && (j_idx == 2'd3))
          next_state = S_DONE;
      end
      S_DONE: begin
        // one-cycle done pulse then go back to IDLE
        next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  integer x, y;

  // sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      done       <= 1'b0;
      n          <= 4'd0;
      i_scan     <= 3'd0;
      k_idx      <= 2'd0;
      i_idx      <= 3'd0;
      j_idx      <= 2'd0;
      cur_min    <= 32'hFFFFFFFF;
      cur_min_valid <= 1'b0;
      cycle_cnt  <= 7'd0;
      for (x = 0; x < 4; x = x + 1) begin
        results[x] <= 32'd0;
      end
      for (x = 0; x < 4; x = x + 1) begin
        for (y = 0; y < 8; y = y + 1) begin
          dp[x][y] <= 32'd0;
        end
      end
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, asserted only in S_DONE

      // simple cycle counter (not used to gate behavior, only ensures <100 cycles feasible)
      if (state != S_IDLE)
        cycle_cnt <= cycle_cnt + 7'd1;
      else
        cycle_cnt <= 7'd0;

      case (state)
        // IDLE: wait for start, clear basic regs
        S_IDLE: begin
          if (start) begin
            // prepare for new computation
            n          <= 4'd0;
            i_scan     <= 3'd0;
            k_idx      <= 2'd0;
            i_idx      <= 3'd0;
            j_idx      <= 2'd0;
            cur_min    <= 32'hFFFFFFFF;
            cur_min_valid <= 1'b0;
            for (x = 0; x < 4; x = x + 1) begin
              results[x] <= 32'd0;
            end
            for (x = 0; x < 4; x = x + 1) begin
              for (y = 0; y < 8; y = y + 1) begin
                dp[x][y] <= 32'd0;
              end
            end
          end
        end

        // PREPARE: determine n = number of non-zero hills
        S_PREPARE: begin
          // count non-zero hills
          if (hills[i_scan] != 16'd0)
            n <= n + 4'd1;

          if (i_scan < 3'd7)
            i_scan <= i_scan + 3'd1;

          // nothing else; next_state moves to COMPUTE when i_scan==7
        end

        // COMPUTE: perform DP over k and i with a simple serialized implementation
        S_COMPUTE: begin
          // handle special case: if n==0 -> no hills, results all 0
          if (n == 0) begin
            // directly go to DONE on next cycle via next_state logic
          end else begin
            // k_idx: 0..3 -> k = k_idx+1
            // Only valid up to ceil(n/2). We'll compute dp only where valid.

            // Base case: k=1 (k_idx==0)
            if (k_idx == 2'd0) begin
              // For k=1, dp[0][i] = min(hills[0..i]) (or large if hills[i]==0 beyond n)
              if (i_idx <= last_i) begin
                if (i_idx == 3'd0) begin
                  // first hill
                  dp[0][0] <= cost_at(hills[0]);
                end else begin
                  // dp[0][i] = min(dp[0][i-1], cost_at(hills[i]))
                  if (dp[0][i_idx-1] <= cost_at(hills[i_idx]))
                    dp[0][i_idx] <= dp[0][i_idx-1];
                  else
                    dp[0][i_idx] <= cost_at(hills[i_idx]);
                end
                // advance i_idx
                if (i_idx < last_i)
                  i_idx <= i_idx + 3'd1;
                else begin
                  // finished k=1 row
                  // store result for k=1
                  results[0] <= dp[0][last_i];
                  // move to next k
                  k_idx      <= 2'd1;
                  i_idx      <= 3'd0;
                  j_idx      <= 2'd0;
                  cur_min    <= 32'hFFFFFFFF;
                  cur_min_valid <= 1'b0;
                end
              end

            end else begin
              // k > 1: scaled DP
              // Only compute if k <= ceil(n/2)
              // max_k = (n+1)/2 ceiling
              reg [2:0] max_k;
              max_k = (n[3:0] + 4'd1) >> 1;

              if ((k_idx + 2'd1) <= max_k) begin
                // compute dp[k_idx][i_idx] sequentially
                if (i_idx <= last_i) begin
                  // We restrict i to be large enough to place k houses; minimal index is k-1
                  reg [2:0] min_i_for_k;
                  min_i_for_k = (k_idx + 2'd1) - 1; // k-1

                  if (i_idx < min_i_for_k) begin
                    // Not enough hills to place k houses
                    dp[k_idx][i_idx] <= 32'hFFFFFFFF;
                    // advance i
                    if (i_idx < last_i)
                      i_idx <= i_idx + 3'd1;
                    else begin
                      // row done
                      results[k_idx] <= dp[k_idx][last_i];
                      k_idx <= k_idx + 2'd1;
                      i_idx <= 3'd0;
                      j_idx <= 2'd0;
                      cur_min <= 32'hFFFFFFFF;
                      cur_min_valid <= 1'b0;
                    end
                  end else begin
                    // For each i_idx, we explore limited candidates
                    // Scaled DP: consider up to 4 previous positions spaced backwards
                    // j_idx selects candidate offset; one candidate per cycle
                    reg [31:0] candidate;
                    reg [2:0]  prev_i;

                    prev_i = (i_idx > (j_idx + 1)) ? (i_idx - (j_idx + 1)) : 3'd0;

                    // candidate = dp[k-1][prev_i] + cost_at(hills[i_idx])
                    candidate = dp[k_idx-1][prev_i] + cost_at(hills[i_idx]);

                    if (!cur_min_valid) begin
                      cur_min       <= candidate;
                      cur_min_valid <= 1'b1;
                    end else begin
                      if (candidate < cur_min)
                        cur_min <= candidate;
                    end

                    // advance j_idx (candidates)
                    if (j_idx < 2'd3) begin
                      j_idx <= j_idx + 2'd1;
                    end else begin
                      // all candidates for this i_idx evaluated
                      dp[k_idx][i_idx] <= cur_min;
                      cur_min       <= 32'hFFFFFFFF;
                      cur_min_valid <= 1'b0;
                      j_idx         <= 2'd0;

                      // advance i_idx or row complete
                      if (i_idx < last_i) begin
                        i_idx <= i_idx + 3'd1;
                      end else begin
                        // finished this k row
                        results[k_idx] <= dp[k_idx][last_i];
                        k_idx <= k_idx + 2'd1;
                        i_idx <= 3'd0;
                        j_idx <= 2'd0;
                        cur_min <= 32'hFFFFFFFF;
                        cur_min_valid <= 1'b0;
                      end
                    end
                  end
                end
              end else begin
                // k exceeded max_k; no more valid results to compute
                // zero remaining results entries
                if (k_idx == max_k) begin
                  if (max_k < 3'd4) begin
                    for (x = max_k; x < 4; x = x + 1) begin
                      results[x] <= 32'd0;
                    end
                  end
                end
              end
            end
          end
        end

        // DONE: assert done for one cycle, then IDLE next
        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

endmodule