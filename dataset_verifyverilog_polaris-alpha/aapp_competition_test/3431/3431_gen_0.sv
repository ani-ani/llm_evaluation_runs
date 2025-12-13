module manhattan_mst(
  input clk,
  input rst_n,
  input start,
  input [3:0] num_points,
  input [9:0] x [0:7],
  input [9:0] y [0:7],
  output reg [13:0] mst_weight,
  output reg done
);

  // ------------------------------------------------------------
  // Parameters
  // ------------------------------------------------------------
  localparam MAX_POINTS   = 8;
  localparam MAX_EDGES    = 28; // C(8,2)

  // State machine encoding
  localparam S_IDLE       = 3'd0;
  localparam S_GEN_EDGES  = 3'd1;
  localparam S_SORT       = 3'd2;
  localparam S_INIT_KRUSK = 3'd3;
  localparam S_KRUSKAL    = 3'd4;
  localparam S_DONE       = 3'd5;

  // ------------------------------------------------------------
  // Internal registers
  // ------------------------------------------------------------
  reg [2:0] state, next_state;

  // Edge representation: {weight[13:0], u[2:0], v[2:0]} = 14+3+3 = 20 bits
  reg [13:0] edge_w    [0:MAX_EDGES-1];
  reg [2:0]  edge_u    [0:MAX_EDGES-1];
  reg [2:0]  edge_v    [0:MAX_EDGES-1];

  reg [5:0]  edge_count;        // number of valid edges

  // Edge generation indices
  reg [2:0] gi_i;
  reg [2:0] gi_j;

  // Sorting indices (bubble sort, 1 comparison per cycle)
  reg [5:0] sort_i;
  reg [5:0] sort_j;

  // Kruskal / Union-Find
  reg [2:0] parent [0:MAX_POINTS-1];
  reg [2:0] rank_r [0:MAX_POINTS-1];

  reg [5:0] k_edge_idx;        // index over edges during Kruskal
  reg [3:0] k_edges_used;      // number of edges accepted into MST
  reg [13:0] mst_accum;        // accumulated MST weight

  // Union-Find find operation (sequential, path halving-style)
  reg [2:0] find_x;
  reg [2:0] find_y;
  reg [2:0] root_x;
  reg [2:0] root_y;
  reg       find_phase;        // 0: find roots, 1: union/apply result
  reg       do_union;          // whether to union after find

  // Temporary for Manhattan distance computation
  wire [9:0] xi = x[gi_i];
  wire [9:0] yi = y[gi_i];
  wire [9:0] xj = x[gi_j];
  wire [9:0] yj = y[gi_j];

  wire [9:0] dx = (xi >= xj) ? (xi - xj) : (xj - xi);
  wire [9:0] dy = (yi >= yj) ? (yi - yj) : (yj - yi);
  wire [13:0] manhattan = dx + dy; // fits within 14-bit per spec

  // ------------------------------------------------------------
  // Helper tasks (synthesizable-style using procedures on regs)
  // ------------------------------------------------------------

  // Compare-and-swap for bubble sort: swap edges at indices a,b if w[a] > w[b]
  task automatic edge_cswap(input [5:0] a, input [5:0] b);
    reg [13:0] tw;
    reg [2:0]  tu;
    reg [2:0]  tv;
  begin
    if (edge_w[a] > edge_w[b]) begin
      tw = edge_w[a];
      tu = edge_u[a];
      tv = edge_v[a];

      edge_w[a] = edge_w[b];
      edge_u[a] = edge_u[b];
      edge_v[a] = edge_v[b];

      edge_w[b] = tw;
      edge_u[b] = tu;
      edge_v[b] = tv;
    end
  end
  endtask

  // ------------------------------------------------------------
  // Sequential state, outputs, and main control
  // ------------------------------------------------------------
  integer idx;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;
      mst_weight  <= 14'd0;
      mst_accum   <= 14'd0;
      edge_count  <= 6'd0;
      gi_i        <= 3'd0;
      gi_j        <= 3'd1;
      sort_i      <= 6'd0;
      sort_j      <= 6'd0;
      k_edge_idx  <= 6'd0;
      k_edges_used<= 4'd0;
      find_x      <= 3'd0;
      find_y      <= 3'd0;
      root_x      <= 3'd0;
      root_y      <= 3'd0;
      find_phase  <= 1'b0;
      do_union    <= 1'b0;
      for (idx = 0; idx < MAX_EDGES; idx = idx + 1) begin
        edge_w[idx] <= 14'd0;
        edge_u[idx] <= 3'd0;
        edge_v[idx] <= 3'd0;
      end
      for (idx = 0; idx < MAX_POINTS; idx = idx + 1) begin
        parent[idx] <= 3'd0;
        rank_r[idx] <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        // ------------------------------------------------------
        // IDLE: wait for start, clear status
        // ------------------------------------------------------
        S_IDLE: begin
          done       <= 1'b0;
          mst_weight <= 14'd0;
          mst_accum  <= 14'd0;
          edge_count <= 6'd0;
          gi_i       <= 3'd0;
          gi_j       <= 3'd1;
          sort_i     <= 6'd0;
          sort_j     <= 6'd0;
          k_edge_idx <= 6'd0;
          k_edges_used <= 4'd0;
          find_phase <= 1'b0;
          do_union   <= 1'b0;
        end

        // ------------------------------------------------------
        // S_GEN_EDGES: generate all pairwise edges (i<j)
        // one edge per cycle
        // ------------------------------------------------------
        S_GEN_EDGES: begin
          if (gi_i < num_points && gi_j < num_points) begin
            edge_w[edge_count] <= manhattan;
            edge_u[edge_count] <= gi_i;
            edge_v[edge_count] <= gi_j;
            edge_count         <= edge_count + 6'd1;

            // increment j, wrap to next i when needed
            if (gi_j + 3'd1 < num_points) begin
              gi_j <= gi_j + 3'd1;
            end else begin
              gi_i <= gi_i + 3'd1;
              gi_j <= gi_i + 3'd2; // next j = new i + 1
            end
          end
        end

        // ------------------------------------------------------
        // S_SORT: bubble sort style; 1 compare-swap per cycle
        // sort_i is outer pass index, sort_j is inner index
        // ------------------------------------------------------
        S_SORT: begin
          if (edge_count > 1) begin
            if (sort_i < edge_count-1) begin
              if (sort_j < edge_count-1-sort_i) begin
                edge_cswap(sort_j, sort_j+1);
                sort_j <= sort_j + 6'd1;
              end else begin
                sort_j <= 6'd0;
                sort_i <= sort_i + 6'd1;
              end
            end
          end
        end

        // ------------------------------------------------------
        // S_INIT_KRUSK: initialize Union-Find
        // ------------------------------------------------------
        S_INIT_KRUSK: begin
          for (idx = 0; idx < MAX_POINTS; idx = idx + 1) begin
            if (idx < num_points) begin
              parent[idx] <= idx[2:0];
              rank_r[idx] <= 3'd0;
            end else begin
              parent[idx] <= 3'd0;
              rank_r[idx] <= 3'd0;
            end
          end
          mst_accum     <= 14'd0;
          k_edges_used  <= 4'd0;
          k_edge_idx    <= 6'd0;
          find_phase    <= 1'b0;
          do_union      <= 1'b0;
        end

        // ------------------------------------------------------
        // S_KRUSKAL: process edges sequentially with UF
        // We'll perform a simple two-phase per edge:
        //  - Phase 0: find roots for endpoints
        //  - Phase 1: union if roots differ, update MST
        // Each edge consumes up to 2 cycles.
        // ------------------------------------------------------
        S_KRUSKAL: begin
          if (k_edges_used == (num_points > 0 ? (num_points - 1) : 0)) begin
            // MST complete
          end else if (k_edge_idx < edge_count) begin
            if (!find_phase) begin
              // Phase 0: capture endpoints and their current roots
              find_x   <= edge_u[k_edge_idx];
              find_y   <= edge_v[k_edge_idx];
              root_x   <= parent[edge_u[k_edge_idx]];
              root_y   <= parent[edge_v[k_edge_idx]];

              // Simple one-level path halving: if parent not root, skip up one level
              if (parent[root_x] != root_x)
                root_x <= parent[root_x];
              if (parent[root_y] != root_y)
                root_y <= parent[root_y];

              do_union   <= 1'b0;
              find_phase <= 1'b1;
            end else begin
              // Phase 1: union decision and perform union if needed
              if (root_x != root_y) begin
                // Accept edge into MST
                mst_accum    <= mst_accum + edge_w[k_edge_idx];
                k_edges_used <= k_edges_used + 4'd1;
                do_union     <= 1'b1;

                // Union by rank
                if (rank_r[root_x] < rank_r[root_y]) begin
                  parent[root_x] <= root_y;
                end else if (rank_r[root_x] > rank_r[root_y]) begin
                  parent[root_y] <= root_x;
                end else begin
                  parent[root_y] <= root_x;
                  rank_r[root_x] <= rank_r[root_x] + 3'd1;
                end
              end else begin
                do_union <= 1'b0;
              end

              // Move to next edge
              k_edge_idx  <= k_edge_idx + 6'd1;
              find_phase  <= 1'b0;
            end
          end
        end

        // ------------------------------------------------------
        // S_DONE: latch result, assert done
        // ------------------------------------------------------
        S_DONE: begin
          done       <= 1'b1;
          mst_weight <= mst_accum;
        end

        default: begin
        end
      endcase
    end
  end

  // ------------------------------------------------------------
  // Next-state logic
  // ------------------------------------------------------------
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start && (num_points != 0)) begin
          if (num_points == 1) begin
            next_state = S_DONE; // MST weight = 0
          end else begin
            next_state = S_GEN_EDGES;
          end
        end
      end

      S_GEN_EDGES: begin
        // When gi_i reaches num_points-1, we're done (no more pairs)
        if (!(gi_i < num_points && gi_j < num_points)) begin
          next_state = (edge_count <= 1) ? S_INIT_KRUSK : S_SORT;
        end
      end

      S_SORT: begin
        if (edge_count <= 1) begin
          next_state = S_INIT_KRUSK;
        end else if (sort_i >= edge_count-1) begin
          next_state = S_INIT_KRUSK;
        end
      end

      S_INIT_KRUSK: begin
        next_state = S_KRUSKAL;
      end

      S_KRUSKAL: begin
        if (k_edges_used == (num_points > 0 ? (num_points - 1) : 0)) begin
          next_state = S_DONE;
        end else if (k_edge_idx >= edge_count) begin
          // In degenerate cases, if we run out of edges, go DONE
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        // Wait for start to deassert and reassert for new computation
        if (!start) begin
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule