module coin_change(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_coins,
  input [7:0] a [0:6],
  input [7:0] b [0:7],
  input [7:0] m,
  output reg [29:0] result,
  output reg done
);

  // Modulo constant 1e9+7
  localparam int MOD = 32'd1000000007;

  // FSM states
  localparam [1:0]
    S_IDLE       = 2'd0,
    S_PROCESSING = 2'd1,
    S_DONE       = 2'd2;

  reg [1:0] state, next_state;

  // DP arrays (size 256 for m in [0,255])
  // Using 32-bit internal to safely apply MOD, result exposed as 30 bits.
  reg [31:0] d_curr [0:255];
  reg [31:0] d_next [0:255];

  // Indices / control
  reg [2:0]  coin_idx;      // current coin type index (0..7)
  reg [8:0]  sumL;          // tracked total max amount (L bound), 0..2040 (needs 11 bits, but safe with 9? -> use 12 bits)
  reg [11:0] L;             // effective DP upper bound (<= 2040, but we clip to 255 for storage)
  reg [7:0]  ratio;         // current ratio a[i-1]

  reg [11:0] j;             // generic index up to 2040, clipped when used
  reg [11:0] t;             // temporary index for loops

  // Compression / convolution control
  reg compress_phase;       // 0: convolution, 1: compression (for i>0 when needed)
  reg [11:0] conv_j;        // index for convolution
  reg [11:0] comp_base;     // base index for compression groups
  reg [11:0] comp_k;        // k index inside compression group
  reg [31:0] acc;           // accumulator for compression

  // Latched coin parameters for current coin
  reg [7:0] curr_b;         // supply limit for current coin

  integer idx;

  // Combinational helpers
  function automatic [31:0] add_mod(input [31:0] x, input [31:0] y);
    reg [32:0] tmp;
    begin
      tmp = x + y;
      if (tmp >= MOD)
        add_mod = tmp - MOD;
      else
        add_mod = tmp[31:0];
    end
  endfunction

  // FSM next state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_PROCESSING;
      end
      S_PROCESSING: begin
        // We'll transition to DONE when all coins processed and convolution finished
        // Actual condition handled in sequential always using coin_idx and phases
        // (keep as S_PROCESSING here, override via sequential when done)
        next_state = S_PROCESSING;
      end
      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      done    <= 1'b0;
      result  <= 30'd0;
      coin_idx <= 3'd0;
      L      <= 12'd0;
      sumL   <= 9'd0;
      ratio  <= 8'd1;
      compress_phase <= 1'b0;
      conv_j <= 12'd0;
      comp_base <= 12'd0;
      comp_k <= 12'd0;
      acc <= 32'd0;
      curr_b <= 8'd0;
      // Initialize DP array: d[0] = 1, others 0
      for (idx = 0; idx < 256; idx = idx + 1) begin
        if (idx == 0) d_curr[idx] <= 32'd1;
        else          d_curr[idx] <= 32'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done   <= 1'b0;
          result <= 30'd0;

          if (start) begin
            // Reset DP for new computation
            for (idx = 0; idx < 256; idx = idx + 1) begin
              if (idx == 0) d_curr[idx] <= 32'd1;
              else          d_curr[idx] <= 32'd0;
            end
            coin_idx       <= 3'd0;
            sumL           <= 9'd0;
            L              <= 12'd0;
            compress_phase <= 1'b0;
            conv_j         <= 12'd0;
            comp_base      <= 12'd0;
            comp_k         <= 12'd0;
            acc            <= 32'd0;
            curr_b         <= b[0];
            ratio          <= 8'd1; // first coin has implicit ratio 1
          end
        end

        S_PROCESSING: begin
          // Main processing of coins with sequential micro-steps

          // If all coins processed and convolution for last coin finished, go DONE
          // Condition: coin_idx == num_coins and we are not in the middle of any phase
          if ((coin_idx >= num_coins) && !compress_phase && (conv_j == 0)) begin
            done   <= 1'b1;
            // Result is ways to form m: d_curr[m]
            result <= d_curr[m][29:0];
            state  <= S_DONE;
          end else begin

            // Start new coin if not in any sub-phase
            if (!compress_phase && (conv_j == 0) && (coin_idx < num_coins)) begin
              // For coin_idx == 0: ratio = 1 (no compression)
              // For coin_idx > 0: possible compression with a[coin_idx-1]
              if (coin_idx == 0) begin
                ratio <= 8'd1;
              end else begin
                ratio <= a[coin_idx-1];
              end

              curr_b <= b[coin_idx];

              // Decide if we need compression: i>0 and ratio != 1
              if ((coin_idx > 0) && (ratio != 8'd1)) begin
                // Initialize compression over extended range up to current L
                // Current L holds maximum reachable sum so far (clipped by 255 in storage semantics)
                comp_base      <= 12'd0;
                comp_k         <= 12'd0;
                acc            <= 32'd0;
                compress_phase <= 1'b1;
              end else begin
                // No compression, go directly to convolution
                conv_j         <= 12'd0;
                compress_phase <= 1'b0;
              end
            end

            // Compression phase: build compressed d_curr using ratio
            if (compress_phase) begin
              // We compress partial sums by grouping indices with step 'ratio'
              // For each base in [0..ratio-1], accumulate d_curr[base + k*ratio]

              if (comp_base < ratio && comp_base < 256) begin
                // Process group for current comp_base
                if (comp_k == 0) begin
                  acc <= d_curr[comp_base];
                  comp_k <= comp_k + ratio;
                end else begin
                  if ((comp_base + comp_k) < 256) begin
                    acc <= add_mod(acc, d_curr[comp_base + comp_k]);
                    comp_k <= comp_k + ratio;
                  end else begin
                    // Done with this group: write back compressed value
                    d_curr[comp_base] <= acc;
                    // Zero out other positions in this group (best-effort within bound)
                    // Note: sequentially clearing is implicit by not using them; no extra writes here
                    comp_base <= comp_base + 1;
                    comp_k    <= 0;
                    acc       <= 32'd0;
                  end
                end
              end else begin
                // Finished all groups, clear remaining indices beyond ratio range
                for (idx = ratio; idx < 256; idx = idx + 1) begin
                  d_curr[idx] <= 32'd0;
                end
                // Compression complete, move to convolution for this coin
                compress_phase <= 1'b0;
                conv_j         <= 12'd0;
              end

            end else begin
              // Convolution phase for current coin (bounded by m, as only interested up to 255)

              if (coin_idx < num_coins) begin
                // Perform one DP update step per cycle for index conv_j
                // Unbounded knapsack with limit curr_b for coin value = 1 (after compression)
                if (conv_j == 0) begin
                  // Initialize d_next
                  for (idx = 0; idx < 256; idx = idx + 1) begin
                    d_next[idx] <= 32'd0;
                  end
                  conv_j <= conv_j + 1;
                end else if (conv_j <= m) begin
                  // Compute d_next[conv_j]
                  // d_next[j] = sum_{k=0..curr_b, k<=j} d_curr[j-k]
                  acc = 32'd0;
                  for (t = 0; t <= 255; t = t + 1) begin
                    if ((t <= curr_b) && (conv_j >= t)) begin
                      acc = add_mod(acc, d_curr[conv_j - t]);
                    end
                  end
                  d_next[conv_j] <= acc;
                  conv_j <= conv_j + 1;
                end else begin
                  // For j > m: keep zero (not needed). Finish this coin.
                  // Commit d_next into d_curr up to m
                  for (idx = 0; idx < 256; idx = idx + 1) begin
                    if (idx <= m)
                      d_curr[idx] <= d_next[idx];
                    else
                      d_curr[idx] <= 32'd0;
                  end
                  // Update L bound (sumL) but clip to 255 for storage relevance
                  sumL <= (sumL + curr_b > 9'd255) ? 9'd255 : (sumL + curr_b);
                  L    <= (sumL + curr_b > 9'd255) ? 9'd255 : (sumL + curr_b);

                  // Move to next coin
                  coin_idx <= coin_idx + 1;
                  conv_j   <= 12'd0;

                  // If next coin exists, setup params; phases re-evaluated in next cycle
                end
              end
            end
          end
        end

        S_DONE: begin
          // Hold result until start deasserts and FSM returns to IDLE via next_state
          done <= 1'b1;
        end

        default: begin
          // Safety fallback
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule