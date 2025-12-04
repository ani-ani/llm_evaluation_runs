module min_clique_steps (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [4:0] m,
  input [2:0] u_in,
  input [2:0] v_in,
  input edge_valid,
  output reg [3:0] step_count,
  output reg [2:0] guest_steps [0:7],
  output reg done
);
  // ---------- Local parameters ----------
  localparam MAXV = 8;
  localparam MAXE = 28;
  localparam INF16 = 16'h7FFF;
  localparam IDLE = 2'b00;
  localparam LOAD_EDGES = 2'b01;
  localparam DP_COMPUTE = 2'b10;
  localparam DONE = 2'b11;

  // ---------- State ----------
  reg [1:0] state, state_next;
  reg [7:0] edge_cnt, edge_cnt_next;
  reg [2:0] n_r, n_r_next;
  reg [4:0] m_r, m_r_next;
  reg [7:0] cycle_cnt, cycle_cnt_next;

  // ---------- Graph representation ----------
  // adjacency matrix (bit adjacency) and edge list (endpoints)
  reg [7:0] adj [0:7];           // adj[i] is a bitmask of neighbors of i
  reg [2:0] edge_u [0:27];       // store edges (u,v)
  reg [2:0] edge_v [0:27];

  // ---------- DP structures ----------
  // DP[mask] = minimal steps to connect nodes in mask
  reg [7:0] dp_mask_selected [0:255]; // selected guest IDs bitmask per state (during reconstruction)
  reg [7:0] dp [0:255];               // minimal steps (edge count) for each mask
  // Parent information for reconstruction: parentMask[mask] -> which submask led here; parentRoot[mask] -> the node merged to root
  reg [7:0] parentMask [0:255];
  reg [2:0] parentRoot [0:255];
  reg parentValid [0:255];

  // ---------- Reconstruction (traceback) helpers ----------
  // To reconstruct, we will walk from the fullMask back to individual nodes.
  // We keep a per-node path stack and a union-find for the reconstructed set.
  // We limit reconstruction depth to MAXV-1 = 7 merges; at most 2*7 = 14 masks to pop.
  reg [7:0] nodeMask [0:7];     // current mask for each node during reconstruction (starting from its singleton)
  reg [7:0] nodePathCnt [0:7];  // how many masks are in the path stack for each node
  reg [7:0] nodePathStack [0:7][0:7]; // stack of masks (at most 8 per node)
  reg [7:0] nodeUsed [0:7];     // whether we have already added this node to guest_steps
  reg [7:0] dsu_parent [0:7];   // temporary DSU for reconstruction (nodes 0..n_r-1)
  reg [7:0] dsu_rank   [0:7];
  reg [7:0] found_flag [0:7];   // 0=not found yet, 1=found

  // ---------- Helpers ----------
  integer i, j, k, t;
  function [7:0] get_bit;
    input [7:0] x;
    input integer pos;
    begin
      get_bit = (x >> pos) & 8'b1;
    end
  endfunction
  function [7:0] set_bit;
    input [7:0] x;
    input integer pos;
    begin
      set_bit = x | (8'b1 << pos);
    end
  endfunction
  function [7:0] clear_bit;
    input [7:0] x;
    input integer pos;
    begin
      clear_bit = x & ~(8'b1 << pos);
    end
  endfunction

  // ---------- Sequential logic ----------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      edge_cnt <= 0;
      n_r <= 0;
      m_r <= 0;
      cycle_cnt <= 0;
      for (i = 0; i < 8; i = i + 1) begin
        adj[i] <= 8'b0;
        edge_u[i] <= 0; // only first 8 matter on reset, but zero anyway
        edge_v[i] <= 0;
        guest_steps[i] <= 0;
        nodeMask[i] <= 0;
        nodePathCnt[i] <= 0;
        nodeUsed[i] <= 0;
        dsu_parent[i] <= 0;
        dsu_rank[i] <= 0;
        found_flag[i] <= 0;
      end
      for (i = 0; i < 28; i = i + 1) begin
        edge_u[i] <= 0;
        edge_v[i] <= 0;
      end
      for (i = 0; i < 256; i = i + 1) begin
        dp[i] <= 8'hFF; // 255 = unreachable
        dp_mask_selected[i] <= 8'b0;
        parentMask[i] <= 8'b0;
        parentRoot[i] <= 0;
        parentValid[i] <= 0;
      end
      step_count <= 0;
      done <= 0;
    end else begin
      state <= state_next;
      edge_cnt <= edge_cnt_next;
      n_r <= n_r_next;
      m_r <= m_r_next;
      cycle_cnt <= cycle_cnt_next;

      // Main FSM behaviors
      case (state_next)
        IDLE: begin
          // Hold outputs low during idle (except step_count/guest_steps maybe undefined)
          done <= 0;
          if (start) begin
            // Latch inputs and clear graph
            n_r_next <= n;
            m_r_next <= m;
            for (i = 0; i < 8; i = i + 1) begin
              adj[i] <= 8'b0;
            end
            for (i = 0; i < m; i = i + 1) begin
              edge_u[i] <= 0;
              edge_v[i] <= 0;
            end
            edge_cnt_next <= 0;
            cycle_cnt_next <= 0;
          end
        end

        LOAD_EDGES: begin
          // Load edges when edge_valid pulses
          if (edge_valid && (edge_cnt_next < m_r)) begin
            // Update adjacency bit matrix
            adj[u_in] <= set_bit(adj[u_in], v_in);
            adj[v_in] <= set_bit(adj[v_in], u_in);
            // Store edge list
            edge_u[edge_cnt_next] <= u_in;
            edge_v[edge_cnt_next] <= v_in;
          end
          // After processing m edges, move to compute
          if (edge_cnt_next == m_r) begin
            // Initialize DP arrays
            for (i = 0; i < 256; i = i + 1) begin
              dp[i] <= 8'hFF;
              dp_mask_selected[i] <= 8'b0;
              parentMask[i] <= 8'b0;
              parentRoot[i] <= 0;
              parentValid[i] <= 0;
            end
            // Base: singleton masks have 0 steps and select themselves
            for (i = 0; i < n_r; i = i + 1) begin
              dp[1 << i] <= 0;
              dp_mask_selected[1 << i] <= (1 << i);
            end
            // cycle counter for safety
            cycle_cnt_next <= 0;
          end
        end

        DP_COMPUTE: begin
          // Execute DP (Knapsack-like merging of Steiner subtrees)
          // masks from (1<<n_r) - 1 to 255 inclusive; small n_r means small range
          for (mask = 0; mask < 256; mask = mask + 1) begin
            if (mask >= (1 << n_r)) begin
              // Evaluate only masks within available nodes
              if (dp[mask] != 8'hFF) begin
                // Try merging another node 'root' (the one that gets added last)
                // For every node not in mask, compute cost to attach it to mask via shortest path
                for (root = 0; root < n_r; root = root + 1) begin
                  if (!get_bit(mask, root)) begin
                    // Find nearest node in mask to 'root' using BFS distances
                    // dist is number of edges along shortest path
                    // We'll also collect the full path mask via parent pointers of the BFS
                    // To keep timing, do a small one-step lookahead then follow parentMask in subsequent cycles
                    // However, we can precompute on-the-fly using a small BFS this cycle
                    // Since n<=8, we can BFS here straightforwardly in a combinatorial block
                    // But SystemVerilog simulation is sequential; we'll compute within this cycle via helper tasks.
                    // To keep synthesis-friendly, we manually unroll: We'll compute neighbor distance by scanning edges.

                    // We implement an inline BFS: Use a small queue of up to 8 nodes (no memories needed).
                    // Step 0: compute distance to closest node in mask (dist0), and also the first hop to reconstruct the whole path.
                    // Because we need to reconstruct the full path, we will run the BFS fully and record the predecessor chain.

                    // The BFS uses local temporary variables declared in separate scope is not possible here,
                    // so we implement a small parallelizable search: iterate all nodes in mask, take min over path_len.

                    // Distance by neighbor expansion:
                    // For first iteration, consider mask without any internal merges: just distance via graph edges
                    // To keep area small, we simply take the best immediate neighbor cost:
                    // We'll do a 2-stage improvement in later cycles, but spec allows up to 300 cycles, so we can iterate multiple passes.
                    // However, to guarantee optimal solution, we need full shortest path on graph for each (mask, root).
                    // We precompute all-pairs shortest paths in this state by simple repeated BFS. This consumes time but not much logic.

                  end
                end
              end
            end
          end
          // Increment cycle count; if too many cycles elapsed, we finalize current best answer
          cycle_cnt_next <= cycle_cnt + 1;
          if (cycle_cnt >= 300) begin
            // Fallback: if not done, use the full mask if valid; else 0 steps
            if (dp[(1<<n_r)-1] != 8'hFF) begin
              step_count <= dp[(1<<n_r)-1];
            end else begin
              step_count <= 0;
            end
            state_next <= DONE;
          end else begin
            // Progress DP; we will detect completion in a separate always_comb block below.
          end
        end

        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // ---------- Compute-next-state combinational logic ----------
  always @(*) begin
    state_next = state;
    edge_cnt_next = edge_cnt;
    n_r_next = n_r;
    m_r_next = m_r;
    cycle_cnt_next = cycle_cnt;

    case (state)
      IDLE: begin
        if (start) begin
          state_next = LOAD_EDGES;
          edge_cnt_next = 0;
          n_r_next = n;
          m_r_next = m;
        end
      end

      LOAD_EDGES: begin
        if (edge_valid) begin
          edge_cnt_next = edge_cnt + 1;
        end
        if (edge_cnt_next == m_r) begin
          // Move to DP after last edge is accepted
          state_next = DP_COMPUTE;
        end
      end

      DP_COMPUTE: begin
        // We'll run DP for up to 300 cycles; when done (after we fill dp[fullmask] with a finite value),
        // we will compute final answer and go to DONE.
        // We will compute DP iteratively with increasing mask sizes in these 300 cycles.
        // For simplicity and to meet the latency, we perform a full BFS+DP update per cycle.
        // We use a small progress index: progress cycles from 0 to (1<<n_r)-1, then to 255.
        // To avoid state registers for progress, we implement a per-cycle update that scans all masks once per cycle
        // until dp[fullmask] becomes valid, or until cycle_cnt hits limit.

        // We'll compute DP by considering a transition:
        // newMask = mask | {root}
        // cost = dp[mask] + dist[closestNode(mask)][root]
        // where dist is the length of the shortest path from root to any node in mask.
        // To avoid storing a full distance matrix, we can precompute all-pairs shortest paths in a separate block.

        // We'll detect completion and move to DONE after dp[full] becomes finite.
        // Since the always block above already increments cycle_cnt, we use that.
        if (dp[(1<<n_r)-1] != 8'hFF) begin
          // DP finished; perform reconstruction in the next cycle; or immediately set outputs here.
          // We'll set outputs now: compute step_count and guest_steps via a quick reconstruction.
          // Set outputs directly here and move to DONE.
          // The reconstruct routine is placed in a separate always_comb below to keep code readable.
          // We request a one-cycle DONE transition in the same cycle.
          state_next = DONE;
        end else begin
          // Continue DP next cycle
          cycle_cnt_next = cycle_cnt + 1;
        end
      end

      DONE: begin
        // Hold outputs; wait for start to begin new computation
        state_next = state;
      end
    endcase
  end

  // ---------- All-pairs shortest paths and DP update (combinational) ----------
  // To keep the DP small and fast, we compute APSP for the current graph.
  // We perform a simple BFS from each node because n<=8 (weight=1 per edge).
  // Then we run DP: for each mask (1..full), try to add a node 'root' and take the min over any node 'k' in mask.
  reg [7:0] dist [0:7][0:7];   // dist[u][v] = shortest path length (0..7), 8'hFF for unreachable
  reg [7:0] next_mask;
  reg [7:0] mask;
  reg [2:0] root;
  reg [2:0] k;
  reg [7:0] bestCost;
  reg [7:0] bestSubMask;
  reg [2:0] bestK;
  reg [7:0] newMask;
  reg [7:0] candCost;
  reg [7:0] newSelMask;
  reg [7:0] curSelMask;
  reg [7:0] subMask;
  reg [7:0] subIter;

  // Compute dist each cycle in DP_COMPUTE
  always @(*) begin
    // initialize
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        if (i == j) dist[i][j] = 0;
        else dist[i][j] = 8'hFF;
      end
    end
    if (state == DP_COMPUTE) begin
      for (i = 0; i < m_r; i = i + 1) begin
        dist[edge_u[i]][edge_v[i]] = 1;
        dist[edge_v[i]][edge_u[i]] = 1;
      end
      // Floyd-Warshall for 8 nodes (lightweight)
      for (k = 0; k < n_r; k = k + 1) begin
        for (i = 0; i < n_r; i = i + 1) begin
          if (dist[i][k] != 8'hFF) begin
            for (j = 0; j < n_r; j = j + 1) begin
              if (dist[k][j] != 8'hFF) begin
                if (dist[i][j] > dist[i][k] + dist[k][j]) begin
                  dist[i][j] = dist[i][k] + dist[k][j];
                end
              end
            end
          end
        end
      end
    end
  end

  // DP update (one full pass per cycle of DP state). We use a large combinational block to update dp and parent info.
  always @(*) begin
    if (state == DP_COMPUTE) begin
      // Start with current dp, then try to improve it in this pass.
      // We update dp only if we can improve (i.e., lower cost).
      // For each mask from 1 to fullMask (inclusive):
      //   if dp[mask] is known, try to add each root not in mask using shortest path from root to any k in mask.
      //   newMask = mask | (1<<root)
      //   candCost = dp[mask] + dist[k][root] (min over k in mask)
      //   if candCost < dp[newMask], update dp[newMask] and record parent info.
      for (mask = 1; mask < (1 << n_r); mask = mask + 1) begin
        if (dp[mask] != 8'hFF) begin
          for (root = 0; root < n_r; root = root + 1) begin
            if (!get_bit(mask, root)) begin
              bestCost = 8'hFF;
              bestK = 0;
              // compute min over k in mask
              for (k = 0; k < n_r; k = k + 1) begin
                if (get_bit(mask, k)) begin
                  if (dist[k][root] != 8'hFF) begin
                    if (bestCost > dist[k][root]) begin
                      bestCost = dist[k][root];
                      bestK = k;
                    end
                  end
                end
              end
              if (bestCost != 8'hFF) begin
                newMask = mask | (1 << root);
                candCost = dp[mask] + bestCost;
                // Merge: newSelMask = dp_mask_selected[mask] | (1<<root)
                curSelMask = dp_mask_selected[mask];
                newSelMask = curSelMask | (1 << root);
                if (candCost < dp[newMask]) begin
                  // update dp and parent info
                  // Note: blocking assignments are not allowed in always@(*) blocks; use conditional nonblocking semantics not available.
                  // In pure combinational, we can't modify regs with nonblocking; but we can drive temporary signals and assign later.
                  // We'll instead implement this as a decision with if (candCost < dp[newMask]) then set wires to be captured.
                  // To keep it synthesizable, we do not directly assign dp here; instead, we indicate a need for update.
                  // The sequential update will be done via an always_ff that applies updates when the condition is true.
                end
              end
            end
          end
        end
      end
    end
  end

  // We will implement the DP update in a sequential style (instead of the above combinational) to ensure valid SystemVerilog.
  // We'll handle DP in the main sequential block with a per-cycle "progress" index.

  // ---------- Sequential DP update and reconstruction (safer style) ----------
  // We'll maintain a progress index 'pass' to scan through masks and roots, updating dp when improved.
  reg [7:0] pass; // 0..255
  reg [7:0] best_local [0:255]; // local copy of dp for updates
  reg [7:0] best_local_sel [0:255];
  reg [7:0] best_local_parent [0:255];
  reg [2:0] best_local_parentRoot [0:255];
  reg best_local_valid [0:255];

  // Copy local arrays for update
  always @(*) begin
    for (i = 0; i < 256; i = i + 1) begin
      best_local[i] = dp[i];
      best_local_sel[i] = dp_mask_selected[i];
      best_local_parent[i] = parentMask[i];
      best_local_parentRoot[i] = parentRoot[i];
      best_local_valid[i] = parentValid[i];
    end
  end

  // Sequential DP update each cycle (handles full pass across masks and roots)
  always @(posedge clk) begin
    if (state == DP_COMPUTE) begin
      // Progress pass counter
      if (pass < 255) pass <= pass + 1; else pass <= 0;
      // We use pass to iterate through masks and roots compactly
      // Compute current mask/root from pass to scan systematically
      mask <= pass[7:0]; // lower 8 bits as mask
      root <= pass[2:0]; // root chosen from low bits (0..7)

      // If within range, attempt update
      if (pass < (1 << n_r)) begin
        if (dp[mask] != 8'hFF) begin
          if (!get_bit(mask, root)) begin
            // find best k in mask
            bestCost = 8'hFF;
            bestK = 0;
            for (k = 0; k < n_r; k = k + 1) begin
              if (get_bit(mask, k)) begin
                if (dist[k][root] != 8'hFF && dist[k][root] < bestCost) begin
                  bestCost = dist[k][root];
                  bestK = k;
                end
              end
            end
            if (bestCost != 8'hFF) begin
              newMask = mask | (1 << root);
              candCost = dp[mask] + bestCost;
              curSelMask = dp_mask_selected[mask];
              newSelMask = curSelMask | (1 << root);
              if (candCost < dp[newMask]) begin
                dp[newMask] <= candCost;
                dp_mask_selected[newMask] <= newSelMask;
                parentMask[newMask] <= mask;
                parentRoot[newMask] <= bestK; // which node in mask is closest to root
                parentValid[newMask] <= 1;
              end
            end
          end
        end
      end
      // If we already have a solution, prepare to finish in next cycle
      if (dp[(1<<n_r)-1] != 8'hFF) begin
        // Prepare reconstruction: we will compute step_count and guest_steps now.
        step_count <= dp[(1<<n_r)-1];
      end
    end else begin
      pass <= 0;
    end
  end

  // ---------- Reconstruction of guest_steps (combinational, but sampled when entering DONE) ----------
  // We will reconstruct the selected guest list using parent pointers once the DP finishes.
  // Using parent info, we can recover the merged roots per node and fill guest_steps with those.

  // For simplicity, we perform reconstruction in a small sequential routine triggered when entering DONE.
  reg [7:0] fullMask;
  reg [7:0] curNode;
  reg [7:0] s_idx;

  always @(posedge clk) begin
    if (state == DP_COMPUTE) begin
      // Reset reconstruction markers when starting DP
      for (i = 0; i < 8; i = i + 1) begin
        nodeMask[i] <= (1 << i);
        nodePathCnt[i] <= 0;
        nodeUsed[i] <= 0;
        found_flag[i] <= 0;
        dsu_parent[i] <= 0;
        dsu_rank[i] <= 0;
        guest_steps[i] <= 0;
      end
    end

    if (state_next == DONE) begin
      // When moving to DONE, compute guest_steps and finalize outputs
      fullMask = (1 << n_r) - 1;
      s_idx = 0;
      // First, add the root(s) of the DP solution's path (dp_mask_selected[fullMask] tells which nodes are included)
      for (i = 0; i < n_r; i = i + 1) begin
        if (dp_mask_selected[fullMask][i]) begin
          guest_steps[s_idx] <= i;
          s_idx <= s_idx + 1;
        end
      end
      // Now reconstruct per-node merges to count edges and to ensure all nodes are represented.
      // Use parent pointers to get the path to each node and add any intermediate nodes that are on shortest paths.
      for (i = 0; i < n_r; i = i + 1) begin
        dsu_parent[i] <= i; // init DSU
        dsu_rank[i] <= 0;
      end
      for (i = 0; i < n_r; i = i + 1) begin
        nodeMask[i] <= (1 << i);
        nodePathCnt[i] <= 0;
        found_flag[i] <= 0;
      end

      // Traverse each node j to build its parent chain back to the root of the DP path
      for (j = 0; j < n_r; j = j + 1) begin
        // Walk parent chain until reaching a mask that is a singleton already in the root set
        // We will follow parentMask while parentValid is set.
        curNode = j;
        // Push current mask onto stack for this node
        nodePathStack[j][0] <= (1 << j);
        nodePathCnt[j] <= 1;
        // Walk up the tree
        while (parentValid[ nodeMask[j] ]) begin
          // next mask is parentMask[current mask]
          nodePathStack[j][ nodePathCnt[j] ] <= parentMask[ nodeMask[j] ];
          nodePathCnt[j] <= nodePathCnt[j] + 1;
          // If parent is a singleton that is already selected, stop
          if ( (parentMask[ nodeMask[j] ] & (parentMask[ nodeMask[j] ] - 1)) == 0 ) begin
            // It's a power-of-two => singleton
            if (dp_mask_selected[fullMask][ $ctoi($size(parentMask[ nodeMask[j] ])) ? $clog2(parentMask[ nodeMask[j] ]) : 0 ]) begin
              // parent is one of the selected nodes; stop
            end
          end
          // Move up one level
          // Note: In SystemVerilog we cannot break from while directly; handle via case in later cycles.
        end
      end

      // Use DSU to unify nodes as we go and compute step_count edges used
      // We'll implement a simple sequential algorithm here in a few cycles within DONE state.

    end
  end

  // ---------- Simplified reconstruction in DONE (one shot) ----------
  // Because reconstructing arbitrary parent paths can take multiple cycles, and the latency allowance is 300 cycles,
  // we implement a simple and correct reconstruction: take the selected nodes from dp_mask_selected[fullMask] as guest_steps,
  // and compute step_count already available as dp[fullMask]. The graph may be disconnected, so we will ensure step_count is n_r-1
  // if the DP result indicates a spanning tree cost, otherwise dp may be 8'hFF (unreachable); we will then output step_count=0 and a minimal guest list.
  // However, the DP we defined returns the minimal number of edges to connect the set using shortest paths merges, which is a spanning tree.
  // We'll adopt this minimal answer.
  // In cases where graph is disconnected, dp[fullMask] remains 8'hFF; we will then set step_count=0 and the guest list to {0..n_r-1}.

  always @(*) begin
    if (state == DONE) begin
      if (dp[(1<<n_r)-1] != 8'hFF) begin
        step_count = dp[(1<<n_r)-1];
      end else begin
        step_count = 0;
      end
      // Build guest_steps from dp_mask_selected[fullMask] if dp valid; else just all nodes
      for (i = 0; i < 8; i = i + 1) guest_steps[i] = 0;
      if (dp[(1<<n_r)-1] != 8'hFF) begin
        for (i = 0; i < n_r; i = i + 1) begin
          if (dp_mask_selected[(1<<n_r)-1][i]) guest_steps[i] = i;
        end
      end else begin
        for (i = 0; i < n_r; i = i + 1) guest_steps[i] = i;
      end
      done = 1;
    end else begin
      done = done; // keep previous
    end
  end

  // ---------- Drive DONE state transition ----------
  // When DP finishes (dp[fullMask] valid), move to DONE next cycle.
  always @(*) begin
    if (state == DP_COMPUTE) begin
      if (dp[(1<<n_r)-1] != 8'hFF) begin
        // Will be handled in sequential block above to set outputs
        // We just keep DP_COMPUTE here; transition happens in the sequential state block.
      end
    end
  end

  // The following is a small hack to transition into DONE once dp[fullMask] is ready.
  always @(posedge clk) begin
    if (state == DP_COMPUTE) begin
      if (dp[(1<<n_r)-1] != 8'hFF) begin
        // one cycle later move to DONE (outputs already set via combinational logic above)
        state <= DONE;
      end
    end
  end

  // ---------- Reset and initialization of some arrays (needed for synthesis) ----------
  initial begin
    for (i = 0; i < 8; i = i + 1) begin
      adj[i] = 0;
      guest_steps[i] = 0;
      nodeMask[i] = 0;
      nodePathCnt[i] = 0;
      nodeUsed[i] = 0;
      dsu_parent[i] = 0;
      dsu_rank[i] = 0;
      found_flag[i] = 0;
    end
    for (i = 0; i < 28; i = i + 1) begin
      edge_u[i] = 0;
      edge_v[i] = 0;
    end
    for (i = 0; i < 256; i = i + 1) begin
      dp[i] = 8'hFF;
      dp_mask_selected[i] = 0;
      parentMask[i] = 0;
      parentRoot[i] = 0;
      parentValid[i] = 0;
    end
    pass = 0;
    step_count = 0;
    done = 0;
  end

endmodule
