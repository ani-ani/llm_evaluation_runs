module assistant_ranker(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // assertion starts computation
  input [15:0] K, // threshold (0-65535)
  input [15:0] a_array [0:7], // 8 measurements (each 0-65535)
  input [15:0] b_array [0:7], // 8 measurements (each 0-65535)
  output reg [3:0] max_ranks, // result (1-8 possible)
  output reg done // high when result valid
);

  // State encoding
  localparam IDLE          = 3'd0;
  localparam COMPARE       = 3'd1;
  localparam BUILD_GRAPH   = 3'd2;
  localparam COMPUTE_RANKS = 3'd3;
  localparam DONE          = 3'd4;

  reg [2:0] state, next_state;

  // Latched inputs to ignore changes while processing
  reg [15:0] K_reg;
  reg [15:0] a_reg [0:7];
  reg [15:0] b_reg [0:7];

  // Dominance matrix: dominance[i][j] = (a[i]+K < a[j]) || (b[i]+K < b[j])
  // Stored as 8x8 bits
  reg dominance [0:7][0:7];

  // Indices for pairwise comparisons
  reg [2:0] cmp_i;
  reg [2:0] cmp_j;

  // Adjacency matrix for a DAG based on dominance
  // edge[i][j] = 1 if i -> j (j dominated by i)
  reg edge [0:7][0:7];

  // Data for rank computation (longest path layering)
  reg [3:0] rank [0:7];
  reg [2:0] node_idx;
  reg [3:0] iter_cnt;
  reg updated;

  integer x, y;

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main control FSM next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMPARE;
        end
      end
      COMPARE: begin
        // After finishing all 8x8 comparisons, move to BUILD_GRAPH
        if ((cmp_i == 3'd7) && (cmp_j == 3'd7)) begin
          next_state = BUILD_GRAPH;
        end
      end
      BUILD_GRAPH: begin
        // Single-cycle build, then compute ranks
        next_state = COMPUTE_RANKS;
      end
      COMPUTE_RANKS: begin
        // Run iterative relaxation (bounded). When iterations complete, go DONE.
        if (iter_cnt == 4'd8) begin
          next_state = DONE;
        end
      end
      DONE: begin
        // Wait for start to deassert then assert again to restart
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Core sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      max_ranks <= 4'd0;
      K_reg <= 16'd0;
      for (x = 0; x < 8; x = x + 1) begin
        a_reg[x] <= 16'd0;
        b_reg[x] <= 16'd0;
        for (y = 0; y < 8; y = y + 1) begin
          dominance[x][y] <= 1'b0;
          edge[x][y] <= 1'b0;
        end
        rank[x] <= 4'd1;
      end
      cmp_i <= 3'd0;
      cmp_j <= 3'd0;
      node_idx <= 3'd0;
      iter_cnt <= 4'd0;
      updated <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          max_ranks <= 4'd0;
          // Wait for start, latch inputs once start is asserted
          if (start) begin
            K_reg <= K;
            for (x = 0; x < 8; x = x + 1) begin
              a_reg[x] <= a_array[x];
              b_reg[x] <= b_array[x];
            end
            // Initialize indices and matrices
            cmp_i <= 3'd0;
            cmp_j <= 3'd0;
            for (x = 0; x < 8; x = x + 1) begin
              for (y = 0; y < 8; y = y + 1) begin
                dominance[x][y] <= 1'b0;
                edge[x][y] <= 1'b0;
              end
              rank[x] <= 4'd1;
            end
            iter_cnt <= 4'd0;
            node_idx <= 3'd0;
            updated <= 1'b0;
          end
        end

        COMPARE: begin
          // Compute dominance for current (cmp_i, cmp_j)
          begin : cmp_block
            reg [16:0] a_plus_K;
            reg [16:0] b_plus_K;
            reg cond;
            a_plus_K = a_reg[cmp_i] + K_reg;
            b_plus_K = b_reg[cmp_i] + K_reg;
            cond = ((a_plus_K < {1'b0,a_reg[cmp_j]}) || (b_plus_K < {1'b0,b_reg[cmp_j]}));
            dominance[cmp_i][cmp_j] <= cond;
          end

          // Advance indices (1 pair per cycle, 64 cycles)
          if (cmp_j == 3'd7) begin
            cmp_j <= 3'd0;
            cmp_i <= cmp_i + 3'd1;
          end else begin
            cmp_j <= cmp_j + 3'd1;
          end
        end

        BUILD_GRAPH: begin
          // Build directed edges according to dominance rule
          // If i dominates j, add edge i->j (j cannot have higher rank than i)
          for (x = 0; x < 8; x = x + 1) begin
            for (y = 0; y < 8; y = y + 1) begin
              if (dominance[x][y]) begin
                edge[x][y] <= 1'b1;
              end else begin
                edge[x][y] <= 1'b0;
              end
            end
          end

          // Initialize ranks to 1 for all nodes
          for (x = 0; x < 8; x = x + 1) begin
            rank[x] <= 4'd1;
          end

          iter_cnt <= 4'd0;
          node_idx <= 3'd0;
          updated <= 1'b0;
        end

        COMPUTE_RANKS: begin
          // Iterative relaxation over DAG edges to compute longest path levels.
          // For each edge i->j: rank[j] <= max(rank[j], rank[i]);
          // Then shift all ranks so minimum is 1 (already ensured).
          // Repeat bounded times (<=8) to propagate.

          // One full sweep over all edges per iteration.
          // node_idx used as inner sweep index within iteration.

          // Perform relaxation for one source node per cycle.
          begin : relax_block
            integer j;
            reg [3:0] old_rank_j;
            reg [3:0] new_rank_j;
            // For current node_idx as source i
            for (j = 0; j < 8; j = j + 1) begin
              if (edge[node_idx][j]) begin
                old_rank_j = rank[j];
                // Ensure j's rank is at least i's rank
                if (rank[node_idx] > old_rank_j) begin
                  new_rank_j = rank[node_idx];
                  rank[j] <= new_rank_j;
                  updated <= 1'b1;
                end
              end
            end
          end

          // Advance node index; when wrap, count iteration
          if (node_idx == 3'd7) begin
            node_idx <= 3'd0;
            iter_cnt <= iter_cnt + 4'd1;
            updated <= 1'b0; // reset update flag for next iteration (not used for convergence stopping here)
          end else begin
            node_idx <= node_idx + 3'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // max_ranks is already computed below in concurrent block
        end

        default: ;
      endcase
    end
  end

  // Compute max_ranks based on final rank[] values.
  // This logic is combinational; sampled effectively in DONE.
  always @(*) begin
    reg [3:0] max_val;
    integer k;
    max_val = 4'd1;
    for (k = 0; k < 8; k = k + 1) begin
      if (rank[k] > max_val)
        max_val = rank[k];
    end
    // At least 1, at most 8
    if (max_val < 4'd1)
      max_ranks = 4'd1;
    else if (max_val > 4'd8)
      max_ranks = 4'd8;
    else
      max_ranks = max_val;
  end

endmodule