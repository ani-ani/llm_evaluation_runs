module worst_rank_calculator(
  input  clk,
  input  rst_n,
  input  [3:0] num_contestants,
  input  [3:0] num_contests,
  input  [6:0] scores [0:3][0:3],
  output reg [2:0] worst_rank,
  output reg       done
);

  // ---------------------------------------------------------------------------
  // Local parameters
  // ---------------------------------------------------------------------------
  localparam MAX_CONTESTANTS = 4;
  localparam MAX_CONTESTS    = 4;

  // FSM States
  localparam S_IDLE       = 4'd0;
  localparam S_INIT       = 4'd1;
  localparam S_SUM_BASE   = 4'd2;
  localparam S_FINAL_AGG  = 4'd3;
  localparam S_SORT       = 4'd4;
  localparam S_GROUP0     = 4'd5;
  localparam S_GROUP1     = 4'd6;
  localparam S_GROUP2     = 4'd7;
  localparam S_FIND_RANK  = 4'd8;
  localparam S_DONE       = 4'd9;

  // ---------------------------------------------------------------------------
  // Registers
  // ---------------------------------------------------------------------------
  reg [3:0]  state, next_state;

  // Working copies of inputs (latched once)
  reg [3:0]  nC;
  reg [3:0]  nT;
  reg [6:0]  scores_reg [0:3][0:3];

  // Base sums: sum of contests 0..(num_contests-2)
  reg [8:0] base_sum [0:3];
  reg [1:0] base_i;      // contestant index
  reg [1:0] base_j;      // contest index

  // Final aggregates for worst-case scenario
  reg [8:0] agg [0:3];

  // Sorted aggregates (descending)
  reg [8:0] sorted_agg [0:3];

  // Temporary variables for sorting
  integer i, j;
  reg [8:0] tmp_val;

  // Tie-group info
  reg [8:0] g_sum [0:3];      // group sum aggregator
  reg [2:0] g_cnt [0:3];      // group count
  reg [2:0] g_start_rank [0:3]; // starting rank for each group (1-based)
  reg [2:0] g_avg_round_up [0:3];

  // ---------------------------------------------------------------------------
  // Sequential logic: state, latching, iterative counters
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= S_IDLE;
      done          <= 1'b0;
      worst_rank    <= 3'd0;
      nC            <= 4'd0;
      nT            <= 4'd0;
      base_i        <= 2'd0;
      base_j        <= 2'd0;
      base_sum[0]   <= 9'd0;
      base_sum[1]   <= 9'd0;
      base_sum[2]   <= 9'd0;
      base_sum[3]   <= 9'd0;
      agg[0]        <= 9'd0;
      agg[1]        <= 9'd0;
      agg[2]        <= 9'd0;
      agg[3]        <= 9'd0;
      sorted_agg[0] <= 9'd0;
      sorted_agg[1] <= 9'd0;
      sorted_agg[2] <= 9'd0;
      sorted_agg[3] <= 9'd0;
      g_sum[0]      <= 9'd0; g_sum[1] <= 9'd0; g_sum[2] <= 9'd0; g_sum[3] <= 9'd0;
      g_cnt[0]      <= 3'd0; g_cnt[1] <= 3'd0; g_cnt[2] <= 3'd0; g_cnt[3] <= 3'd0;
      g_start_rank[0] <= 3'd0; g_start_rank[1] <= 3'd0;
      g_start_rank[2] <= 3'd0; g_start_rank[3] <= 3'd0;
      g_avg_round_up[0] <= 3'd0; g_avg_round_up[1] <= 3'd0;
      g_avg_round_up[2] <= 3'd0; g_avg_round_up[3] <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          worst_rank <= 3'd0;
          // Latch inputs once after reset deassert and stable
          nC <= (num_contestants < 4'd2) ? 4'd2 : ((num_contestants > 4'd4) ? 4'd4 : num_contestants);
          nT <= (num_contests    < 4'd2) ? 4'd2 : ((num_contests    > 4'd4) ? 4'd4 : num_contests);
          // Copy scores
          for (i = 0; i < MAX_CONTESTANTS; i = i + 1) begin
            for (j = 0; j < MAX_CONTESTS; j = j + 1) begin
              scores_reg[i][j] <= scores[i][j];
            end
          end
        end

        S_INIT: begin
          // Initialize base sums and indices
          base_i <= 2'd0;
          base_j <= 2'd0;
          base_sum[0] <= 9'd0;
          base_sum[1] <= 9'd0;
          base_sum[2] <= 9'd0;
          base_sum[3] <= 9'd0;
        end

        S_SUM_BASE: begin
          // Accumulate base sums across contests 0..(nT-2)
          if (base_i < nC) begin
            if (base_j < (nT - 1)) begin
              base_sum[base_i] <= base_sum[base_i] + scores_reg[base_i][base_j];
              base_j <= base_j + 2'd1;
            end else begin
              base_j <= 2'd0;
              base_i <= base_i + 2'd1;
            end
          end
        end

        S_FINAL_AGG: begin
          // Compute final aggregates under worst-case scenario
          // Contestant 0: gets 0 in final contest (if exists)
          // Others: get 101 in final contest (if exists)
          // If only 1 contest (but spec says 2-4), logic still robust
          agg[0] <= base_sum[0] + ((nT >= 2) ? 9'd0 : (scores_reg[0][0]));
          agg[1] <= (1 < nC) ? (base_sum[1] + ((nT >= 2) ? 9'd101 : scores_reg[1][0])) : 9'd0;
          agg[2] <= (2 < nC) ? (base_sum[2] + ((nT >= 2) ? 9'd101 : scores_reg[2][0])) : 9'd0;
          agg[3] <= (3 < nC) ? (base_sum[3] + ((nT >= 2) ? 9'd101 : scores_reg[3][0])) : 9'd0;
        end

        S_SORT: begin
          // Perform bubble sort (descending) on agg[0..nC-1]
          // We implement as full combinational inside next_state; here we just latch results
          sorted_agg[0] <= sorted_agg[0];
          sorted_agg[1] <= sorted_agg[1];
          sorted_agg[2] <= sorted_agg[2];
          sorted_agg[3] <= sorted_agg[3];
        end

        S_GROUP0, S_GROUP1, S_GROUP2, S_FIND_RANK: begin
          // Registers are assigned in combinational block for these steps
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Combinational logic: next_state and key operations
  // ---------------------------------------------------------------------------
  always @* begin
    next_state = state;

    // Default: keep previous values for sorted and groups unless overwritten
    for (i = 0; i < MAX_CONTESTANTS; i = i + 1) begin
      // defaults preserved implicitly
    end

    case (state)
      S_IDLE: begin
        // Move to init immediately after latching
        next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_SUM_BASE;
      end

      S_SUM_BASE: begin
        if (base_i >= nC) begin
          next_state = S_FINAL_AGG;
        end
      end

      S_FINAL_AGG: begin
        // Prepare for sorting in next cycle
        // Initialize sorted_agg with agg values
        sorted_agg[0] = agg[0];
        sorted_agg[1] = (nC > 1) ? agg[1] : 9'd0;
        sorted_agg[2] = (nC > 2) ? agg[2] : 9'd0;
        sorted_agg[3] = (nC > 3) ? agg[3] : 9'd0;

        // Go to sort state
        next_state = S_SORT;
      end

      S_SORT: begin
        // Combinational bubble sort on sorted_agg[0..nC-1]
        reg [8:0] a0, a1, a2, a3;
        a0 = sorted_agg[0];
        a1 = sorted_agg[1];
        a2 = sorted_agg[2];
        a3 = sorted_agg[3];

        // Limit to nC
        // Pass 1
        if (nC > 1 && a0 < a1) begin tmp_val = a0; a0 = a1; a1 = tmp_val; end
        if (nC > 2 && a1 < a2) begin tmp_val = a1; a1 = a2; a2 = tmp_val; end
        if (nC > 3 && a2 < a3) begin tmp_val = a2; a2 = a3; a3 = tmp_val; end
        // Pass 2
        if (nC > 1 && a0 < a1) begin tmp_val = a0; a0 = a1; a1 = tmp_val; end
        if (nC > 2 && a1 < a2) begin tmp_val = a1; a1 = a2; a2 = tmp_val; end
        // Pass 3
        if (nC > 1 && a0 < a1) begin tmp_val = a0; a0 = a1; a1 = tmp_val; end

        sorted_agg[0] = a0;
        sorted_agg[1] = (nC > 1) ? a1 : 9'd0;
        sorted_agg[2] = (nC > 2) ? a2 : 9'd0;
        sorted_agg[3] = (nC > 3) ? a3 : 9'd0;

        // Initialize tie grouping
        // Group 0 starts at rank 1
        g_sum[0]        = (nC >= 1) ? sorted_agg[0] : 9'd0;
        g_cnt[0]        = (nC >= 1) ? 3'd1 : 3'd0;
        g_start_rank[0] = 3'd1;
        // Clear others
        g_sum[1]        = 9'd0; g_sum[2] = 9'd0; g_sum[3] = 9'd0;
        g_cnt[1]        = 3'd0; g_cnt[2] = 3'd0; g_cnt[3] = 3'd0;
        g_start_rank[1] = 3'd0; g_start_rank[2] = 3'd0; g_start_rank[3] = 3'd0;

        next_state = S_GROUP0;
      end

      // Build tie groups based on sorted_agg (up to 4 contestants)
      // Each state incrementally processes one index to respect cycle bound
      S_GROUP0: begin
        // Process index 1
        if (nC > 1) begin
          if (sorted_agg[1] == sorted_agg[0]) begin
            g_sum[0] = g_sum[0] + sorted_agg[1];
            g_cnt[0] = g_cnt[0] + 3'd1;
          end else begin
            g_sum[1]        = sorted_agg[1];
            g_cnt[1]        = 3'd1;
            g_start_rank[1] = g_start_rank[0] + g_cnt[0];
          end
        end
        next_state = S_GROUP1;
      end

      S_GROUP1: begin
        // Process index 2
        if (nC > 2) begin
          if (sorted_agg[2] == sorted_agg[1]) begin
            // Same group as index 1
            if (g_cnt[1] != 3'd0) begin
              g_sum[1] = g_sum[1] + sorted_agg[2];
              g_cnt[1] = g_cnt[1] + 3'd1;
            end else begin
              // If index1 belonged to group0 (tie with 0)
              g_sum[0] = g_sum[0] + sorted_agg[2];
              g_cnt[0] = g_cnt[0] + 3'd1;
            end
          end else begin
            // New group
            if (g_cnt[1] != 3'd0) begin
              g_sum[2]        = sorted_agg[2];
              g_cnt[2]        = 3'd1;
              g_start_rank[2] = g_start_rank[1] + g_cnt[1];
            end else begin
              g_sum[1]        = sorted_agg[2];
              g_cnt[1]        = 3'd1;
              g_start_rank[1] = g_start_rank[0] + g_cnt[0];
            end
          end
        end
        next_state = S_GROUP2;
      end

      S_GROUP2: begin
        // Process index 3
        if (nC > 3) begin
          // Determine last non-empty group index
          integer last_g;
          last_g = 0;
          if (g_cnt[1] != 0) last_g = 1;
          if (g_cnt[2] != 0) last_g = 2;

          if (sorted_agg[3] == sorted_agg[2]) begin
            // Same group as index 2
            g_sum[last_g] = g_sum[last_g] + sorted_agg[3];
            g_cnt[last_g] = g_cnt[last_g] + 3'd1;
          end else begin
            // New group after last_g
            integer new_g;
            new_g = last_g + 1;
            if (new_g < 4) begin
              g_sum[new_g]        = sorted_agg[3];
              g_cnt[new_g]        = 3'd1;
              g_start_rank[new_g] = g_start_rank[last_g] + g_cnt[last_g];
            end
          end
        end
        next_state = S_FIND_RANK;
      end

      S_FIND_RANK: begin
        // Compute rounded-up average rank for each non-empty group
        integer k;
        integer sum_int;
        integer cnt_int;
        integer num_non_empty;

        num_non_empty = 0;
        for (k = 0; k < 4; k = k + 1) begin
          if (g_cnt[k] != 0) begin
            sum_int = 0;
            // Sum of ranks for this group's members: arithmetic series
            // from start to start + count - 1
            sum_int = (g_start_rank[k] + (g_start_rank[k] + g_cnt[k] - 1));
            sum_int = sum_int * g_cnt[k] / 2; // this formula re-evaluated but safe for small
            cnt_int = g_cnt[k];
            // rounded up average = (sum + cnt - 1) / cnt
            g_avg_round_up[k] = (sum_int + cnt_int - 1) / cnt_int;
            num_non_empty = num_non_empty + 1;
          end else begin
            g_avg_round_up[k] = 3'd0;
          end
        end

        // Determine contestant 0's worst-case rank using tie groups
        // If contestant0's aggregate matches a group's score, use that group's rounded-up rank.
        // Otherwise, rank = 1 + number of contestants with strictly higher agg.
        reg [8:0] myAgg;
        reg [2:0] rank_calc;
        reg       matched;

        myAgg   = agg[0];
        rank_calc = 3'd1;
        matched = 1'b0;

        // First check tie groups
        for (k = 0; k < 4; k = k + 1) begin
          if (g_cnt[k] != 0 && !matched) begin
            // All members of group k share same score: use sorted_agg at group's start
            if (myAgg == sorted_agg[g_start_rank[k]-1]) begin
              rank_calc = g_avg_round_up[k];
              matched   = 1'b1;
            end
          end
        end

        if (!matched) begin
          // No tie group: compute based on strictly higher scores
          rank_calc = 3'd1;
          for (k = 0; k < 4; k = k + 1) begin
            if (k < nC && agg[k] > myAgg) begin
              rank_calc = rank_calc + 3'd1;
            end
          end
        end

        worst_rank = rank_calc;
        next_state = S_DONE;
      end

      S_DONE: begin
        // Stay here; result stable
        next_state = S_DONE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule
