module tree_optimizer (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes, // 3..8 nodes (0-7 encoding), actual count = num_nodes + 0
  input [55:0] edges, // 8 entries x (3b city_a + 3b city_b + 1b valid) = 56 bits
  output reg [2:0] min_flights, // diameter (in edges) of the best tree
  output reg [3:0] cancel_a, cancel_b, // city numbers 1..8 to remove
  output reg [3:0] add_a, add_b,       // city numbers 1..8 to add
  output reg done
);

  // Helper: next fit in small state machine (max 256 cycles)
  // City IDs are 1..8. Internally we use 0..7 for bit indexing.
  function [2:0] city_to_idx(input [3:0] city);
    city_to_idx = city[2:0]; // 1..8 -> 1..8, 0 unused; idx = city - 1
  endfunction

  function [3:0] idx_to_city(input [2:0] idx);
    idx_to_city = {1'b0, idx} + 4'b0001; // idx 0..7 -> city 1..8
  endfunction

  localparam S_IDLE = 3'b000;
  localparam S_COMPUTE = 3'b001;
  localparam S_DONE = 3'b010;

  // Decode edges input into local arrays
  // edges is 8 entries x 7 bits: {valid(1), city_a(3), city_b(3)}
  logic [7:0] e_valid;          // per-slot validity
  logic [2:0] e_a [0:7];        // 0..7 indices
  logic [2:0] e_b [0:7];

  // Adjacency for current working graph (8x8 bit matrix)
  logic [7:0] adj [0:7];        // adj[i][j]=1 if edge exists (undirected)
  logic [7:0] adj_work [0:7];   // working copy where we cancel one edge

  // Keep a copy of original edges for "cancel_*" output
  logic [7:0] o_valid;
  logic [2:0] o_a [0:7];
  logic [2:0] o_b [0:7];

  // Small BFS state/memory
  logic [2:0] bfs_src;
  logic [2:0] bfs_head;
  logic [2:0] bfs_tail;
  logic [7:0] bfs_queue; // circular queue: head points to current pop; tail next push
  logic signed [3:0] dist [0:7]; // -1 = unvisited, 0..7 distances
  logic [7:0] bfs_submask; // limit BFS to this set (1-bit per node)
  logic [2:0] bfs_max_idx; // node at maximum distance
  logic [2:0] bfs_max_dist;
  logic [2:0] bfs_iter;    // iteration counter for BFS steps
  logic [7:0] bfs_neighbors_mask; // neighbor mask for current node

  // State machine
  reg [2:0] state, next_state;
  logic bfs_running, bfs_finish;

  // Compute control
  logic [2:0] N;          // number of nodes (1..8)
  logic [2:0] rem_i;      // current edge index to remove (0..7)
  logic [2:0] best_rem_i; // best remove index
  logic [2:0] best_add_ai, best_add_bi; // best add endpoints (indices 0..7)
  logic [2:0] best_diameter;

  // Submask sets after removing rem_i
  logic [7:0] setA, setB; // bitmask of nodes in each component
  logic [2:0] cntA, cntB; // node counts
  logic is_tree_split;    // indicates that removing this edge indeed splits the graph

  // Edge slots to try for new connection: only from valid edges not equal to rem_i
  logic [2:0] add_i;      // current add edge candidate index (0..7)
  logic [2:0] add_count;  // number of candidate add edges
  logic [2:0] add_list [0:7]; // list of candidate add edge indices
  logic [2:0] add_ptr;    // pointer into add_list
  logic [2:0] add_end_i;  // endpoint indices (0..7) for add edge
  logic [2:0] add_end_ai, add_end_bi;
  logic [2:0] add_end_bi_alt; // alt mapping if flip happens

  // Combined diameter test for candidate (rem_i, add_i)
  logic [2:0] diamAB;  // diameter of A
  logic [2:0] diamAB2; // diameter of B
  logic [2:0] diamNew; // new combined diameter after adding edge

  // Compute stage flags
  logic comp_init, comp_edge_loop, comp_bfs1, comp_bfs2, comp_diam_test, comp_advance;
  logic [2:0] loop_step; // 0..4 state for compute step

  // Convenience: N is num_nodes (1..8)
  assign N = num_nodes[2:0];

  // Decode edges (original copy)
  always_comb begin
    o_valid = 8'b0;
    for (int i = 0; i < 8; i++) begin
      logic [6:0] chunk;
      chunk = edges[i*7 +: 7];
      o_valid[i] = chunk[6];
      o_a[i] = chunk[5:3];
      o_b[i] = chunk[2:0];
    end
  end

  // Build working adjacency matrix (undirected)
  function void build_adj();
    for (int i = 0; i < 8; i++) begin
      adj[i] = 8'b0;
    end
    for (int i = 0; i < 8; i++) begin
      if (o_valid[i]) begin
        logic [2:0] a, b;
        a = o_a[i];
        b = o_b[i];
        if ((|a) && (|b)) begin // indices 0..7
          adj[a][b] = 1'b1;
          adj[b][a] = 1'b1;
        end
      end
    end
  endfunction

  // BFS utilities
  function void bfs_start(input [2:0] src, input [7:0] submask);
    bfs_src = src;
    bfs_head = src;
    bfs_tail = src;
    bfs_queue = 8'b0;
    bfs_queue[src] = 1'b1;
    for (int i = 0; i < 8; i++) dist[i] = -4;
    dist[src] = 0;
    bfs_max_idx = src;
    bfs_max_dist = 0;
    bfs_iter = 0;
    bfs_submask = submask;
  endfunction

  function void bfs_step();
    // If queue empty or iteration done, mark finish
    if (bfs_head == bfs_tail) begin
      bfs_finish = 1'b1;
      return;
    end
    bfs_finish = 1'b0;
    if (bfs_iter >= 8) begin // safety cap
      bfs_finish = 1'b1;
      return;
    end

    logic [2:0] u;
    logic [7:0] nbrs;
    u = bfs_head;
    bfs_head = bfs_head + 1; // increment circularly (mod 8)
    nbrs = adj_work[u];

    // neighbors restricted to submask (if submask is 0, allow all nodes)
    if (bfs_submask != 8'b0) nbrs = nbrs & bfs_submask;

    for (int i = 0; i < 8; i++) begin
      if (nbrs[i]) begin
        if (dist[i] < 0) begin
          dist[i] = dist[u] + 1;
          bfs_queue[i] = 1'b1;
          bfs_tail = i;
          if (dist[i] > bfs_max_dist) begin
            bfs_max_dist = dist[i];
            bfs_max_idx = i;
          end
        end
      end
    end
    bfs_iter = bfs_iter + 1;
  endfunction

  // Compute diameter of a set (submask) with a BFS from any node in the set
  function [2:0] diameter_of_set(input [7:0] submask);
    logic [2:0] start_idx;
    start_idx = 0;
    for (int i = 0; i < 8; i++) begin
      if (submask[i]) begin start_idx = i; break; end
    end
    bfs_start(start_idx, submask);
    while (!bfs_finish) bfs_step();
    diameter_of_set = bfs_max_dist;
  endfunction

  // Generate the add edge candidate list (all valid edges except the one we removed)
  function void build_add_list(input [2:0] rem_index);
    add_count = 0;
    for (int i = 0; i < 8; i++) begin
      if (i == rem_index) continue;
      if (o_valid[i]) begin
        add_list[add_count] = i;
        add_count = add_count + 1;
      end
    end
  endfunction

  // Build mask for component A after removing an edge rem_i
  // BFS from one endpoint of the removed edge over the graph without that edge
  function [7:0] component_mask_from_edge_removal(input [2:0] rem_index);
    // Start with full adjacency
    for (int i = 0; i < 8; i++) adj_work[i] = adj[i];
    if (|rem_index) begin // just to keep
    end
    // Remove edge rem_i from working graph
    if (o_valid[rem_index]) begin
      logic [2:0] a, b;
      a = o_a[rem_index];
      b = o_b[rem_index];
      adj_work[a][b] = 1'b0;
      adj_work[b][a] = 1'b0;
    end
    // BFS from endpoint a in the full node space to get its component
    logic [2:0] start;
    start = 0;
    if (o_valid[rem_index]) start = o_a[rem_index];
    bfs_start(start, 8'b0); // allow all nodes
    while (!bfs_finish) bfs_step();
    component_mask_from_edge_removal = 8'b0;
    for (int i = 0; i < 8; i++) begin
      if (dist[i] >= 0) component_mask_from_edge_removal[i] = 1'b1;
    end
  endfunction

  // Compute combined diameter after adding an edge between subtrees A and B
  // Start BFS from an arbitrary node in A and traverse the entire graph.
  function [2:0] combined_diameter_after_add(input [2:0] add_ai, input [2:0] add_bi);
    // Start BFS from add_ai on full graph (adj already excludes removed edge)
    bfs_start(add_ai, 8'b0);
    while (!bfs_finish) bfs_step();
    combined_diameter_after_add = bfs_max_dist;
  endfunction

  // State machine sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next-state logic and datapath
  always_comb begin
    next_state = state;
    // Defaults
    comp_init = 1'b0;
    comp_edge_loop = 1'b0;
    comp_bfs1 = 1'b0;
    comp_bfs2 = 1'b0;
    comp_diam_test = 1'b0;
    comp_advance = 1'b0;
    loop_step = 3'b0;

    case (state)
      S_IDLE: begin
        done = 1'b0;
        if (start) begin
          comp_init = 1'b1;      // prepare graph and best tracking
          next_state = S_COMPUTE;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_COMPUTE: begin
        // Small step state machine to complete within 256 cycles
        // loop_step[2:0] cycles through a few sub-tasks per edge pair
        // 0: init remove edge
        // 1: compute setA/setB, check split
        // 2: diameter A/B
        // 3: try add edges, compute combined diameter, update best
        // 4: advance to next remove edge
        loop_step = loop_step;

        case (loop_step)
          3'b000: begin comp_init = 1'b1; loop_step = 3'b001; end
          3'b001: begin comp_edge_loop = 1'b1; loop_step = 3'b010; end
          3'b010: begin comp_bfs1 = 1'b1; loop_step = 3'b011; end
          3'b011: begin comp_bfs2 = 1'b1; loop_step = 3'b100; end
          3'b100: begin comp_diam_test = 1'b1; loop_step = 3'b101; end
          3'b101: begin comp_advance = 1'b1; loop_step = 3'b000; end
          default: begin loop_step = 3'b000; end
        endcase

        if (rem_i >= 8) begin // finished all removals
          next_state = S_DONE;
        end else begin
          next_state = S_COMPUTE;
        end
      end

      S_DONE: begin
        done = 1'b1;
        if (start) begin
          // re-start on new start pulse
          next_state = S_IDLE;
        end else begin
          next_state = S_DONE;
        end
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Compute datapath
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      // reset outputs
      min_flights <= 3'b0;
      cancel_a <= 4'b0;
      cancel_b <= 4'b0;
      add_a <= 4'b0;
      add_b <= 4'b0;
      done <= 1'b0;
      rem_i <= 3'b0;
      best_rem_i <= 3'b0;
      best_add_ai <= 3'b0;
      best_add_bi <= 3'b0;
      best_diameter <= 3'b0;
      setA <= 8'b0;
      setB <= 8'b0;
      cntA <= 3'b0;
      cntB <= 3'b0;
      is_tree_split <= 1'b0;
      add_i <= 3'b0;
      add_ptr <= 3'b0;
      add_end_ai <= 3'b0;
      add_end_bi <= 3'b0;
      diamAB <= 3'b0;
      diamAB2 <= 3'b0;
      diamNew <= 3'b0;
    end else begin
      if (state == S_IDLE && start) begin
        // Prepare graph and best tracking
        build_adj();
        // Initialize tracking
        rem_i <= 3'b0;
        best_rem_i <= 3'b0;
        best_add_ai <= 3'b0;
        best_add_bi <= 3'b0;
        best_diameter <= 3'b7; // worst-case 7 (8 nodes, 7 edges diameter)
        done <= 1'b0;
        // Invalidate outputs
        cancel_a <= 4'b0;
        cancel_b <= 4'b0;
        add_a <= 4'b0;
        add_b <= 4'b0;
      end

      if (state == S_COMPUTE) begin
        if (comp_init) begin
          // per compute cycle init done in S_IDLE start block
        end

        if (comp_edge_loop) begin
          // For current rem_i, compute component A using BFS on graph without this edge
          if (rem_i < 8 && o_valid[rem_i]) begin
            setA <= component_mask_from_edge_removal(rem_i);
          end else begin
            // If not valid, just set empty to skip
            setA <= 8'b0;
          end
          // setB is complement within [0..N-1]
          setB <= (~setA) & (8'hFF >> (8 - N));
          cntA <= $countones(setA);
          cntB <= $countones(setB);
          // Split is valid if both sides have at least one node and we actually removed a valid edge
          is_tree_split <= (o_valid[rem_i] && (cntA > 0) && (cntB > 0));
          // Prepare add edge list for this removal
          if (o_valid[rem_i]) begin
            build_add_list(rem_i);
            add_ptr <= 3'b0;
            add_i <= (add_count > 0) ? add_list[0] : 3'b0;
          end else begin
            add_count <= 3'b0;
            add_ptr <= 3'b0;
            add_i <= 3'b0;
          end
          // Reset diameters for this removal
          diamAB <= 3'b0;
          diamAB2 <= 3'b0;
        end

        if (comp_bfs1) begin
          // Compute diameters of both components (if split)
          if (is_tree_split) begin
            // Build working graph without removed edge (adj_work must be set by component function)
            // We already prepared adj_work in component_mask_from_edge_removal; reuse that adj_work for BFS
            // Ensure adj_work is consistent: copy from adj then remove rem_i once
            for (int i = 0; i < 8; i++) adj_work[i] <= adj[i];
            if (o_valid[rem_i]) begin
              logic [2:0] a, b;
              a = o_a[rem_i];
              b = o_b[rem_i];
              adj_work[a][b] <= 1'b0;
              adj_work[b][a] <= 1'b0;
            end
            // Compute diameters
            diamAB <= diameter_of_set(setA);
            diamAB2 <= diameter_of_set(setB);
          end else begin
            diamAB <= 3'b0;
            diamAB2 <= 3'b0;
          end
        end

        if (comp_bfs2) begin
          // After diamAB/diamAB2 are ready, we immediately start add-edge evaluation in comp_diam_test.
        end

        if (comp_diam_test) begin
          // Evaluate add edges for this removal if split
          if (is_tree_split) begin
            // Ensure adj_work still excludes the removed edge for combined diameter tests
            for (int i = 0; i < 8; i++) adj_work[i] <= adj[i];
            if (o_valid[rem_i]) begin
              logic [2:0] a, b;
              a = o_a[rem_i];
              b = o_b[rem_i];
              adj_work[a][b] <= 1'b0;
              adj_work[b][a] <= 1'b0;
            end

            // Try all add candidates (from add_list)
            if (add_ptr < add_count) begin
              add_i <= add_list[add_ptr];
              // Add endpoints
              add_end_ai <= o_a[add_list[add_ptr]];
              add_end_bi <= o_b[add_list[add_ptr]];
              add_end_bi_alt <= o_b[add_list[add_ptr]]; // default

              // We will test combined diameter by starting BFS from add_end_ai
              // Combined diameter test
              diamNew <= combined_diameter_after_add(add_end_ai, add_end_bi);

              // On next cycle, we will compare; advance pointer now to allow pipeline
              add_ptr <= add_ptr + 1;
            end else begin
              // No more add edges; nothing to do
            end

            // After diamNew computed (in same cycle due to function), we can evaluate if it's the best
            // Note: The BFS finishes within this cycle (local function), so diamNew is ready.
            // The logic below uses the most recent add_i/endpoints from previous cycle, so we update best after pointer advance.
            // To ensure correct pairing, we evaluate when add_ptr > 0 (i.e., after first increment)
            if (add_ptr > 0) begin
              logic [2:0] a_i, b_i;
              // Retrieve the edge we just evaluated: we can fetch from add_list[add_ptr-1] to get endpoints
              a_i = o_a[add_list[add_ptr-1]];
              b_i = o_b[add_list[add_ptr-1]];

              // If diamNew < best_diameter, update best solution
              if (diamNew < best_diameter) begin
                best_diameter <= diamNew;
                best_rem_i <= rem_i;
                best_add_ai <= a_i;
                best_add_bi <= b_i;
              end
            end
          end else begin
            // Not a valid split; skip testing add edges
          end
        end

        if (comp_advance) begin
          // If we just finished testing all add edges for this removal, move to next removal
          // Loop exits when rem_i >= 8
          if (is_tree_split) begin
            // Wait until add_ptr reached add_count to advance; if not yet, rem_i stays
            if (add_ptr >= add_count) begin
              rem_i <= rem_i + 1;
            end
          end else begin
            // If not a valid split, just advance removal index
            rem_i <= rem_i + 1;
          end
        end
      end

      if (state == S_DONE) begin
        done <= 1'b1;
        // Output best found solution as city numbers 1..8
        if (best_rem_i < 8 && o_valid[best_rem_i]) begin
          cancel_a <= idx_to_city(o_a[best_rem_i]);
          cancel_b <= idx_to_city(o_b[best_rem_i]);
        end else begin
          cancel_a <= 4'b0;
          cancel_b <= 4'b0;
        end
        add_a <= idx_to_city(best_add_ai);
        add_b <= idx_to_city(best_add_bi);
        min_flights <= best_diameter; // diameter in edges
      end
    end
  end

endmodule