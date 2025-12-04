module tree_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes,
  input [55:0] edges,
  output reg [2:0] min_flights,
  output reg [3:0] cancel_a,
  output reg [3:0] cancel_b,
  output reg [3:0] add_a,
  output reg [3:0] add_b,
  output reg done
);

  // Parameters
  localparam MAX_NODES = 8;
  localparam MAX_EDGES = 8; // at most n-1<=7, but interface reserves 8

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE    = 2'b00,
    S_COMPUTE = 2'b01,
    S_DONE    = 2'b10
  } state_t;

  state_t state, next_state;

  // Internal storage
  reg [2:0] node_count; // 1..8

  // Edge arrays
  reg [2:0] edge_a   [0:MAX_EDGES-1];
  reg [2:0] edge_b   [0:MAX_EDGES-1];
  reg       edge_vld [0:MAX_EDGES-1];

  // Undirected adjacency matrix (1-based nodes mapped to 0..7 index)
  reg adj_mat [0:MAX_NODES-1][0:MAX_NODES-1];

  // Loop indices
  integer i,j;

  // Pre-decode edges combinationally from flattened input
  // Format per edge i: bits [7*i +: 7] -> {valid, b[2:0], a[2:0]}
  always @* begin
    for (i = 0; i < MAX_EDGES; i = i + 1) begin
      edge_a[i]   = edges[7*i +: 3];
      edge_b[i]   = edges[7*i + 3 +: 3];
      edge_vld[i] = edges[7*i + 6];
    end
  end

  // Adjacency matrix build (sequential when starting)
  // Helper to rebuild adjacency from edge list
  task build_adj;
    integer x,y;
    begin
      for (x = 0; x < MAX_NODES; x = x + 1) begin
        for (y = 0; y < MAX_NODES; y = y + 1) begin
          adj_mat[x][y] = 1'b0;
        end
      end
      for (i = 0; i < MAX_EDGES; i = i + 1) begin
        if (edge_vld[i]) begin
          if (edge_a[i] < MAX_NODES && edge_b[i] < MAX_NODES && (edge_a[i] != 3'b000) && (edge_b[i] != 3'b000)) begin
            // edge cities encoded 0-7 here but represent 1-8 logically
            adj_mat[edge_a[i]][edge_b[i]] = 1'b1;
            adj_mat[edge_b[i]][edge_a[i]] = 1'b1;
          end
        end
      end
    end
  endtask

  // BFS-based diameter computation over current adj_mat
  // Returns diameter (max shortest path) for connected nodes subset "node_mask".
  // Nodes are 0..7, active if node_mask[idx]==1.
  // Assumes connectivity within mask (for each subtree).
  function automatic [3:0] compute_diameter(input [7:0] node_mask);
    integer s, u, v;
    reg [3:0] dist   [0:MAX_NODES-1];
    reg       used   [0:MAX_NODES-1];
    reg [2:0] q      [0:MAX_NODES-1];
    integer head, tail;
    reg [3:0] max_d_all;
    reg [3:0] max_d_this;
    begin
      max_d_all = 4'd0;
      // For each start node s in mask
      for (s = 0; s < MAX_NODES; s = s + 1) begin
        if (node_mask[s]) begin
          // init
          for (u = 0; u < MAX_NODES; u = u + 1) begin
            dist[u] = 4'hF; // INF
            used[u] = 1'b0;
          end
          head = 0;
          tail = 0;
          dist[s] = 4'd0;
          used[s] = 1'b1;
          q[tail] = s[2:0];
          tail = tail + 1;
          // BFS
          while (head < tail) begin
            u = q[head];
            head = head + 1;
            for (v = 0; v < MAX_NODES; v = v + 1) begin
              if (node_mask[v] && adj_mat[u][v] && !used[v]) begin
                used[v] = 1'b1;
                dist[v] = dist[u] + 1'b1;
                q[tail] = v[2:0];
                tail = tail + 1;
              end
            end
          end
          // max distance from s within mask
          max_d_this = 4'd0;
          for (v = 0; v < MAX_NODES; v = v + 1) begin
            if (node_mask[v] && dist[v] != 4'hF) begin
              if (dist[v] > max_d_this)
                max_d_this = dist[v];
            end
          end
          if (max_d_this > max_d_all)
            max_d_all = max_d_this;
        end
      end
      compute_diameter = max_d_all;
    end
  endfunction

  // Helper: BFS to mark one component given edge removal and/or virtual edge inclusion
  task automatic mark_component(
    input [2:0] start_node,
    input [7:0] base_mask,
    input [2:0] blk_a,
    input [2:0] blk_b,
    input       use_block,   // if 1, treat (blk_a,blk_b) as removed
    input [2:0] add_x,
    input [2:0] add_y,
    input       use_add,     // if 1, treat (add_x,add_y) as added
    output [7:0] comp_mask
  );
    integer u,v;
    reg [7:0] visited;
    reg [2:0] q [0:MAX_NODES-1];
    integer head, tail;
    reg edge_ok;
    begin
      visited = 8'b0;
      head = 0;
      tail = 0;

      visited[start_node] = 1'b1;
      q[tail] = start_node;
      tail = tail + 1;

      while (head < tail) begin
        u = q[head];
        head = head + 1;

        for (v = 0; v < MAX_NODES; v = v + 1) begin
          if (base_mask[v]) begin
            edge_ok = 1'b0;
            // Existing adjacency (minus blocked edge)
            if (adj_mat[u][v]) begin
              if (use_block && ((u == blk_a && v == blk_b) || (u == blk_b && v == blk_a))) begin
                edge_ok = 1'b0;
              end else begin
                edge_ok = 1'b1;
              end
            end
            // Virtual added edge
            if (!edge_ok && use_add) begin
              if ((u == add_x && v == add_y) || (u == add_y && v == add_x)) begin
                edge_ok = 1'b1;
              end
            end
            if (edge_ok && !visited[v]) begin
              visited[v] = 1'b1;
              q[tail] = v[2:0];
              tail = tail + 1;
            end
          end
        end
      end

      comp_mask = visited;
    end
  endtask

  // Compute maximum shortest path (graph diameter) for full graph considering:
  // - one blocked edge (cancel)
  // - one added edge (add)
  function automatic [3:0] compute_global_diam(
    input [7:0] base_mask,
    input [2:0] blk_a,
    input [2:0] blk_b,
    input       use_block,
    input [2:0] add_x,
    input [2:0] add_y,
    input       use_add
  );
    integer s,u,v;
    reg [3:0] dist [0:MAX_NODES-1];
    reg       used [0:MAX_NODES-1];
    reg [2:0] q    [0:MAX_NODES-1];
    integer head, tail;
    reg [3:0] max_d_all;
    reg [3:0] max_d_this;
    reg edge_ok;
    begin
      max_d_all = 4'd0;
      for (s = 0; s < MAX_NODES; s = s + 1) begin
        if (base_mask[s]) begin
          for (u = 0; u < MAX_NODES; u = u + 1) begin
            dist[u] = 4'hF;
            used[u] = 1'b0;
          end
          head = 0;
          tail = 0;
          dist[s] = 4'd0;
          used[s] = 1'b1;
          q[tail] = s[2:0];
          tail = tail + 1;
          while (head < tail) begin
            u = q[head];
            head = head + 1;
            for (v = 0; v < MAX_NODES; v = v + 1) begin
              if (base_mask[v]) begin
                edge_ok = 1'b0;
                if (adj_mat[u][v]) begin
                  if (use_block && ((u == blk_a && v == blk_b) || (u == blk_b && v == blk_a))) begin
                    edge_ok = 1'b0;
                  end else begin
                    edge_ok = 1'b1;
                  end
                end
                if (!edge_ok && use_add) begin
                  if ((u == add_x && v == add_y) || (u == add_y && v == add_x)) begin
                    edge_ok = 1'b1;
                  end
                end
                if (edge_ok && !used[v]) begin
                  used[v] = 1'b1;
                  dist[v] = dist[u] + 1'b1;
                  q[tail] = v[2:0];
                  tail = tail + 1;
                end
              end
            end
          end
          max_d_this = 4'd0;
          for (v = 0; v < MAX_NODES; v = v + 1) begin
            if (base_mask[v] && dist[v] != 4'hF) begin
              if (dist[v] > max_d_this)
                max_d_this = dist[v];
            end
          end
          if (max_d_this > max_d_all)
            max_d_all = max_d_this;
        end
      end
      compute_global_diam = max_d_all;
    end
  endfunction

  // Iteration control
  reg [3:0] best_cost; // minimal max flights found
  reg [2:0] best_cancel_a, best_cancel_b;
  reg [2:0] best_add_a, best_add_b;

  reg [3:0] edge_idx;              // which edge to consider canceling
  reg [3:0] cand_u, cand_v;        // current cancel endpoints
  reg       have_valid_edge;

  reg [3:0] add_i_idx, add_j_idx;  // candidate new edge endpoints

  reg [7:0] full_mask;             // active nodes mask
  reg [7:0] comp1_mask, comp2_mask;
  reg [7:0] tmp_mask;

  reg [3:0] diam1, diam2, combined_diam;
  reg [3:0] local_max;

  // FSM next-state
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_COMPUTE;
      end
      S_COMPUTE: begin
        // Move to DONE once all candidates exhausted
        if (edge_idx >= MAX_EDGES)
          next_state = S_DONE;
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
      state        <= S_IDLE;
      done         <= 1'b0;
      min_flights  <= 3'd0;
      cancel_a     <= 4'd0;
      cancel_b     <= 4'd0;
      add_a        <= 4'd0;
      add_b        <= 4'd0;
      best_cost    <= 4'hF; // large
      best_cancel_a<= 3'd0;
      best_cancel_b<= 3'd0;
      best_add_a   <= 3'd0;
      best_add_b   <= 3'd0;
      edge_idx     <= 4'd0;
      add_i_idx    <= 4'd0;
      add_j_idx    <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch node_count and build mask
            node_count = (num_nodes + 3'd1); // encoding 0->1 ... 7->8
            full_mask  = 8'b0;
            for (i = 0; i < MAX_NODES; i = i + 1) begin
              if (i < node_count)
                full_mask[i] = 1'b1;
              else
                full_mask[i] = 1'b0;
            end
            // Build adjacency from current edges
            build_adj();

            // Init best solution as current tree without changes (no cancel/add)
            combined_diam = compute_global_diam(full_mask,3'd0,3'd0,1'b0,3'd0,3'd0,1'b0);
            best_cost     <= combined_diam;
            best_cancel_a <= 3'd0; // 0 means no cancel
            best_cancel_b <= 3'd0;
            best_add_a    <= 3'd0; // 0 means no add
            best_add_b    <= 3'd0;

            edge_idx      <= 4'd0;
            add_i_idx     <= 4'd0;
            add_j_idx     <= 4'd0;
          end
        end

        S_COMPUTE: begin
          // Iterate per cycle over candidate cancel/add combinations.
          // 1) Select next valid edge for cancellation.
          if (edge_idx < MAX_EDGES) begin
            have_valid_edge = 1'b0;
            cand_u = 4'd0;
            cand_v = 4'd0;
            if (edge_vld[edge_idx]) begin
              cand_u = edge_a[edge_idx];
              cand_v = edge_b[edge_idx];
              if (cand_u < node_count && cand_v < node_count && cand_u != cand_v)
                have_valid_edge = 1'b1;
            end

            if (!have_valid_edge) begin
              edge_idx <= edge_idx + 1'b1; // skip invalid edge
              add_i_idx <= 4'd0;
              add_j_idx <= 4'd0;
            end else begin
              // 2) If starting for this edge, compute its two components w/o any added edge.
              if (add_i_idx == 0 && add_j_idx == 0) begin
                // mark comp1 from cand_u without added edge
                mark_component(cand_u[2:0], full_mask, cand_u[2:0], cand_v[2:0], 1'b1,
                               3'd0,3'd0,1'b0, comp1_mask);
                // comp2 = remaining
                comp2_mask = (full_mask & ~comp1_mask);
                // 3) compute each subtree diameter without added edge
                diam1 = compute_diameter(comp1_mask);
                diam2 = compute_diameter(comp2_mask);
                // initial combined diameter w/o any new edge
                combined_diam = compute_global_diam(full_mask,
                                   cand_u[2:0], cand_v[2:0], 1'b1,
                                   3'd0,3'd0,1'b0);
                local_max = diam1;
                if (diam2 > local_max) local_max = diam2;
                if (combined_diam > local_max) local_max = combined_diam;
                if (local_max < best_cost) begin
                  best_cost     <= local_max;
                  best_cancel_a <= cand_u[2:0];
                  best_cancel_b <= cand_v[2:0];
                  best_add_a    <= 3'd0;
                  best_add_b    <= 3'd0;
                end
                // prepare to try added edges
                add_i_idx <= 4'd0;
                add_j_idx <= 4'd0;
              end else begin
                // 4) Explore candidate new edges between comp1 and comp2.
                // Find next pair (i in comp1, j in comp2) not equal, no existing edge.
                reg found_pair;
                reg [2:0] ai, bj;
                found_pair = 1'b0;
                ai = add_i_idx[2:0];
                bj = add_j_idx[2:0];

                for (; ai < node_count && !found_pair; ai = ai + 1) begin
                  if (comp1_mask[ai]) begin
                    for (; bj < node_count && !found_pair; bj = bj + 1) begin
                      if (comp2_mask[bj]) begin
                        if (!adj_mat[ai][bj]) begin
                          found_pair = 1'b1;
                        end
                      end
                    end
                    if (!found_pair) bj = 0;
                  end
                end

                if (!found_pair) begin
                  // no more add-edge candidates for this canceled edge
                  edge_idx  <= edge_idx + 1'b1;
                  add_i_idx <= 4'd0;
                  add_j_idx <= 4'd0;
                end else begin
                  // Evaluate this candidate add edge (ai_sel-1, bj_sel-1)
                  reg [2:0] ai_sel, bj_sel;
                  ai_sel = ai - 1; // last incremented over limit or found
                  // adjust bj_sel based on inner loop exit condition
                  if (bj == 0)
                    bj_sel = node_count[2:0] - 1; // fallback, though logically shouldn't
                  else
                    bj_sel = bj - 1;

                  // 5) Compute combined diameter with this cancel/add.
                  combined_diam = compute_global_diam(full_mask,
                                     cand_u[2:0], cand_v[2:0], 1'b1,
                                     ai_sel, bj_sel, 1'b1);
                  // In a tree with one remove+one add we remain connected, but keep formula:
                  diam1 = 4'd0;
                  diam2 = 4'd0;
                  local_max = combined_diam;

                  if (local_max < best_cost) begin
                    best_cost     <= local_max;
                    best_cancel_a <= cand_u[2:0];
                    best_cancel_b <= cand_v[2:0];
                    best_add_a    <= ai_sel;
                    best_add_b    <= bj_sel;
                  end

                  // 6) Advance add_i_idx/add_j_idx for next cycle.
                  add_i_idx <= ai_sel;
                  add_j_idx <= bj_sel + 1'b1;
                  if (add_j_idx >= node_count) begin
                    add_i_idx <= ai_sel + 1'b1;
                    add_j_idx <= 4'd0;
                  end
                end
              end
            end
          end
        end

        S_DONE: begin
          done        <= 1'b1;
          // Map 0-based indices (0..7) to city numbers (1..8); 0 means no-op (output 0)
          min_flights <= (best_cost[2:0]);

          if (best_cancel_a != 3'd0 || best_cancel_b != 3'd0) begin
            cancel_a <= {1'b0, best_cancel_a} + 4'd1;
            cancel_b <= {1'b0, best_cancel_b} + 4'd1;
          end else begin
            cancel_a <= 4'd0;
            cancel_b <= 4'd0;
          end

          if (best_add_a != 3'd0 || best_add_b != 3'd0) begin
            add_a <= {1'b0, best_add_a} + 4'd1;
            add_b <= {1'b0, best_add_b} + 4'd1;
          end else begin
            add_a <= 4'd0;
            add_b <= 4'd0;
          end

          if (!start) begin
            // prepare for next run
            best_cost     <= 4'hF;
            best_cancel_a <= 3'd0;
            best_cancel_b <= 3'd0;
            best_add_a    <= 3'd0;
            best_add_b    <= 3'd0;
            edge_idx      <= 4'd0;
            add_i_idx     <= 4'd0;
            add_j_idx     <= 4'd0;
            done          <= 1'b0;
          end
        end

        default: ;
      endcase
    end
  end
endmodule