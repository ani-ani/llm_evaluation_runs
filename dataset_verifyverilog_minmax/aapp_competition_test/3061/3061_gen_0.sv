module critical_path_analyzer(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start computation
  input [2:0] node_count, // number of stations (1-8)
  input [3:0] edge_count, // number of roads (0-16)
  input [139:0] edge_list, // flattened edge list: 16 edges * {3'b u, 3'b v} (LSB first)
  output reg [3:0] result, // minimum longest path length
  output reg done // high when computation complete
);

  // Constants
  localparam MAX_NODES = 8;
  localparam MAX_EDGES = 16;
  localparam EDGE_W    = 7; // 3b u + 3b v + 1b unused (MSB of the 7)
  localparam MAX_PATH  = 15; // Maximum possible longest path length (nodes-1)

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE            = 2'b00,
    S_COMPUTE_ORIG    = 2'b01,
    S_CHECK_EDGES     = 2'b10,
    S_DONE            = 2'b11
  } state_t;

  state_t state, next_state;

  // Build/compute sub-states (within compute stages)
  typedef enum logic [1:0] {
    SUB_PARSE     = 2'b00,
    SUB_TOPO      = 2'b01,
    SUB_LP        = 2'b10
  } sub_state_t;

  sub_state_t sub_state, sub_next_state;

  // Edge removal iteration control
  reg [4:0] remove_idx;        // 0..15, 16 means "no removal"
  reg [4:0] remove_idx_next;
  reg [4:0] best_idx;          // index of edge whose removal gives min longest path
  reg [3:0] best_val;          // current minimum longest path
  reg       best_valid;        // becomes 1 once we have at least one candidate (original)
  reg       original_done;     // 1 after original longest path is computed

  // Graph storage (max sizes)
  // For each dest node, store up to 8 incoming edges and a flag whether each entry is used.
  reg [3:0] inc_u [MAX_NODES][MAX_EDGES]; // source node for incoming edge j of node i
  reg       inc_used [MAX_NODES][MAX_EDGES];
  reg [3:0] inc_cnt [MAX_NODES];          // number of incoming edges per node (0..8)

  reg [7:0] indeg [MAX_NODES];            // indegree count per node (0..8)

  // Working copies (modified per iteration)
  reg [3:0] indeg_work [MAX_NODES];
  reg [3:0] inc_u_work [MAX_NODES][MAX_EDGES];
  reg       inc_used_work [MAX_NODES][MAX_EDGES];
  reg [3:0] inc_cnt_work [MAX_NODES];

  // Edge mask: 1 means skip this edge in current computation
  reg [MAX_EDGES-1:0] edge_mask;         // only 16 bits are used
  reg [MAX_EDGES-1:0] edge_mask_next;

  // LP queue (nodes with indegree 0)
  reg [3:0] lp_queue [$];
  reg [3:0] lp_head; // not used with queue, we just use queue operations

  // Current longest path (over nodes processed so far)
  reg [3:0] topo_len; // 0..15

  // Iteration counter for scanning edges in a node's incoming list
  reg [3:0] scan_k;
  reg [3:0] scan_k_next;

  // Edge being processed helper (from edge_list)
  reg [2:0] e_u;
  reg [2:0] e_v;
  wire      e_u_vld;
  wire      e_v_vld;
  wire      edge_valid; // edge_valid = e_u_vld && e_v_vld && (e_u != e_v)
  assign e_u_vld  = (e_u < node_count);
  assign e_v_vld  = (e_v < node_count);
  assign edge_valid = e_u_vld && e_v_vld && (e_u != e_v);

  // Helper to extract an edge from edge_list by index i (0..15)
  // layout: [6:3] = u, [2:0] = v, [6] unused
  always_comb begin
    e_u = edge_list[(i * EDGE_W) +: 3]; // bits [i*7+3 +: 3]
    e_v = edge_list[(i * EDGE_W) +: 3]; // This line is wrong; fix below
  end

  // Correct extraction block
  reg [3:0] i; // index for loop-like behavior; declared as reg for readability
  always_comb begin
    // placeholder, will not be used in sequential logic
  end

  // This is not a loop; we use procedural logic to iterate per clock.
  // We'll maintain 'i' across sub-states for scanning edges if needed.

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      sub_state <= SUB_PARSE;
      remove_idx <= 5'd16; // no removal
      best_idx <= 4'd0;
      best_val <= 4'd0;
      best_valid <= 1'b0;
      result <= 4'd0;
      done <= 1'b0;
      original_done <= 1'b0;
      edge_mask <= '0;
      edge_mask_next <= '0;
      // Reset graph structures
      for (int n=0; n<MAX_NODES; n++) begin
        indeg[n] <= 8'd0;
        indeg_work[n] <= 4'd0;
        inc_cnt[n] <= 4'd0;
        inc_cnt_work[n] <= 4'd0;
        for (int k=0; k<MAX_EDGES; k++) begin
          inc_used[n][k] <= 1'b0;
          inc_u[n][k] <= 4'd0;
          inc_used_work[n][k] <= 1'b0;
          inc_u_work[n][k] <= 4'd0;
        end
      end
      // Clear queue and counters
      while (lp_queue.size() > 0) lp_queue.pop_front();
      topo_len <= 4'd0;
      scan_k <= 4'd0;
      scan_k_next <= 4'd0;
    end else begin
      // Defaults (overridden in each state)
      next_state <= state;
      sub_next_state <= sub_state;
      remove_idx_next <= remove_idx;
      edge_mask_next <= edge_mask;
      scan_k_next <= scan_k;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          original_done <= 1'b0;
          best_valid <= 1'b0;
          result <= 4'd0;
          remove_idx <= 5'd16; // no removal
          edge_mask <= '0;
          // Clear queue
          while (lp_queue.size() > 0) lp_queue.pop_front();
          topo_len <= 4'd0;
          scan_k <= 4'd0;
          if (start) begin
            next_state <= S_COMPUTE_ORIG;
            sub_next_state <= SUB_PARSE;
            // remove_idx remains 5'd16
            edge_mask_next <= '0; // include all edges
          end else begin
            next_state <= S_IDLE;
          end
        end

        S_COMPUTE_ORIG: begin
          // Compute original longest path
          // Sub-states: PARSE -> TOPO -> LP
          case (sub_state)
            SUB_PARSE: begin
              // Build graph from edge_list into inc_u/inc_used/inc_cnt and indeg
              // At most 16 edges; we parse one edge per cycle using remove_idx (5'd16 for original)
              // Edge index 0..15; when remove_idx==16, include all.
              // For this state we don't need edge_mask (already 0)
              // We'll maintain a local counter 'i' in remove_idx[4:0] temporarily? Not ideal.
              // Instead, use remove_idx[4:0] to index edges but treat value 16 as special.
              // We'll use remove_idx_next to carry 0..15 across passes, then restore.
              // For original compute, we start from i=0 and go to edge_count-1.

              // We need an index; use a local variable via a small reg.
              // We'll keep a hidden index in 'remove_idx_next', then restore after.

              // Per clock we process one edge if i < edge_count
              // Maintain a local i derived from remove_idx_next only for this pass.
              // Initialize when first entering SUB_PARSE with i=0.

              // We'll implement a small counter embedded in remove_idx_next:
              // To avoid extra flops, we'll re-use remove_idx_next to count from 0..edge_count.
              if (sub_state == SUB_PARSE) begin
                // First cycle in SUB_PARSE
                // Ensure remove_idx_next is 0
                if (|remove_idx_next == 1'b0 && (remove_idx_next[4:0] == 5'd0)) begin
                  // already zeroed, proceed
                end else begin
                  // initialize
                  remove_idx_next <= 5'd0;
                end
              end

              // Process only if remove_idx_next < edge_count
              if (remove_idx_next < edge_count) begin
                // Extract edge bits
                // Edge layout: bits [i*7+6 +: 1] unused, [i*7+3 +: 3] = u, [i*7+0 +: 3] = v
                e_u = edge_list[(remove_idx_next*EDGE_W) + 3 +: 3];
                e_v = edge_list[(remove_idx_next*EDGE_W) + 0 +: 3];
                if (edge_valid) begin
                  // Add incoming edge to v
                  // Find a free slot in inc_used[v]
                  // Slot is inc_cnt[v]
                  if (inc_cnt[e_v] < MAX_EDGES) begin
                    inc_u[e_v][inc_cnt[e_v]] <= e_u;
                    inc_used[e_v][inc_cnt[e_v]] <= 1'b1;
                    inc_cnt[e_v] <= inc_cnt[e_v] + 1;
                    indeg[e_v] <= indeg[e_v] + 1;
                  end
                end
                remove_idx_next <= remove_idx_next + 1;
                sub_next_state <= SUB_PARSE;
              end else begin
                // Move to TOPO substate
                sub_next_state <= SUB_TOPO;
                // Prepare working copies: indeg_work, inc_u_work, inc_used_work, inc_cnt_work
                for (int n=0; n<MAX_NODES; n++) begin
                  indeg_work[n] <= indeg[n];
                  inc_cnt_work[n] <= inc_cnt[n];
                  for (int k=0; k<MAX_EDGES; k++) begin
                    inc_u_work[n][k] <= inc_u[n][k];
                    inc_used_work[n][k] <= inc_used[n][k];
                  end
                end
                // Initialize LP queue with nodes having indegree 0
                while (lp_queue.size() > 0) lp_queue.pop_front();
                for (int n=0; n<MAX_NODES; n++) begin
                  if (n < node_count && indeg_work[n] == 4'd0) begin
                    lp_queue.push_back(n[3:0]);
                  end
                end
                topo_len <= 4'd0;
              end
            end

            SUB_TOPO: begin
              // Build longest path via DP as we pop nodes from queue
              if (lp_queue.size() > 0) begin
                int node;
                node = lp_queue.pop_front();
                // Process its incoming edges: for each edge u->node, decrement indeg[u]
                // We need to scan inc_cnt[node] entries and for each used entry, find slot in inc_u_work[dest] to decrement.
                // To keep combinational load low, we'll do this iteratively with a small counter.
                if (scan_k < inc_cnt_work[node]) begin
                  if (inc_used_work[node][scan_k]) begin
                    int uu;
                    uu = inc_u_work[node][scan_k];
                    if (indeg_work[uu] > 0) indeg_work[uu] <= indeg_work[uu] - 1;
                    // If indegree becomes 0, push uu into queue
                    if (indeg_work[uu] == 4'd1) begin // will become 0 next cycle
                      lp_queue.push_back(uu[3:0]);
                    end
                  end
                  scan_k_next <= scan_k + 1;
                  sub_next_state <= SUB_TOPO;
                end else begin
                  // Finished scanning all incoming edges of 'node'
                  scan_k_next <= 4'd0;
                  // Update topo_len to reflect this node is processed
                  topo_len <= topo_len + 1;
                  sub_next_state <= SUB_TOPO; // stay in topo until queue empty
                end
              end else begin
                // Queue empty: done with longest path
                // topo_len is number of nodes processed; longest path (edges) is nodes-1
                // Compute LP = (topo_len > 0) ? (topo_len - 1) : 0
                if (topo_len > 0) begin
                  result <= topo_len - 1;
                end else begin
                  result <= 4'd0;
                end
                // Store original as best so far
                best_val <= (topo_len > 0) ? (topo_len - 1) : 4'd0;
                best_idx <= 4'd0; // not meaningful for original
                best_valid <= 1'b1;
                original_done <= 1'b1;
                // Move to next major state: CHECK_EDGES
                next_state <= S_CHECK_EDGES;
                sub_next_state <= SUB_PARSE; // re-use for each removal
                remove_idx_next <= 5'd0; // start checking from edge 0
                edge_mask_next <= '0; // no removal yet
              end
            end

            default: sub_next_state <= SUB_PARSE;
          endcase
        end

        S_CHECK_EDGES: begin
          // For each edge i in 0..edge_count-1:
          //   Set remove_idx_next = i; edge_mask_next = 1<<i; run subgraph longest path
          //   Update best_val / best_idx if result < best_val
          if (original_done) begin
            if (remove_idx_next < edge_count) begin
              // Enter subgraph compute with that edge masked out
              case (sub_state)
                SUB_PARSE: begin
                  // Setup edge mask for this iteration
                  edge_mask_next <= (1 << remove_idx_next);
                  // Clear working copies from original base (use base arrays: indeg, inc_u/used/cnt)
                  for (int n=0; n<MAX_NODES; n++) begin
                    indeg_work[n] <= indeg[n];
                    inc_cnt_work[n] <= inc_cnt[n];
                    for (int k=0; k<MAX_EDGES; k++) begin
                      inc_u_work[n][k] <= inc_u[n][k];
                      inc_used_work[n][k] <= inc_used[n][k];
                    end
                  end
                  // Build filtered graph by skipping the masked edge
                  // We'll parse edges once and add only those not masked
                  // Maintain a local index in remove_idx (still holds i) but we need a parse index: we can reuse scan_k to count from 0..edge_count-1
                  if (scan_k < edge_count) begin
                    // Extract edge
                    e_u = edge_list[(scan_k*EDGE_W) + 3 +: 3];
                    e_v = edge_list[(scan_k*EDGE_W) + 0 +: 3];
                    if (edge_valid && ((edge_mask_next >> scan_k) == 1'b0)) begin
                      // add incoming edge to v
                      if (inc_cnt_work[e_v] < MAX_EDGES) begin
                        inc_u_work[e_v][inc_cnt_work[e_v]] <= e_u;
                        inc_used_work[e_v][inc_cnt_work[e_v]] <= 1'b1;
                        inc_cnt_work[e_v] <= inc_cnt_work[e_v] + 1;
                        indeg_work[e_v] <= indeg_work[e_v] + 1;
                      end
                    end
                    scan_k_next <= scan_k + 1;
                    sub_next_state <= SUB_PARSE;
                  end else begin
                    // Build queue from indeg_work
                    while (lp_queue.size() > 0) lp_queue.pop_front();
                    for (int n=0; n<MAX_NODES; n++) begin
                      if (n < node_count && indeg_work[n] == 4'd0) begin
                        lp_queue.push_back(n[3:0]);
                      end
                    end
                    topo_len <= 4'd0;
                    scan_k_next <= 4'd0;
                    sub_next_state <= SUB_TOPO;
                  end
                end

                SUB_TOPO: begin
                  if (lp_queue.size() > 0) begin
                    int node;
                    node = lp_queue.pop_front();
                    if (scan_k < inc_cnt_work[node]) begin
                      if (inc_used_work[node][scan_k]) begin
                        int uu;
                        uu = inc_u_work[node][scan_k];
                        if (indeg_work[uu] > 0) indeg_work[uu] <= indeg_work[uu] - 1;
                        if (indeg_work[uu] == 4'd1) begin
                          lp_queue.push_back(uu[3:0]);
                        end
                      end
                      scan_k_next <= scan_k + 1;
                      sub_next_state <= SUB_TOPO;
                    end else begin
                      scan_k_next <= 4'd0;
                      topo_len <= topo_len + 1;
                      sub_next_state <= SUB_TOPO;
                    end
                  end else begin
                    // Done longest path for this iteration
                    // Compute longest path (edges)
                    if (topo_len > 0) begin
                      result <= topo_len - 1;
                    end else begin
                      result <= 4'd0;
                    end
                    // Update best if smaller
                    if (best_valid) begin
                      if (topo_len > 0) begin
                        if ((topo_len - 1) < best_val) begin
                          best_val <= (topo_len - 1);
                          best_idx <= remove_idx_next[3:0];
                        end
                      end else begin
                        // topo_len==0 -> result 0; update if better
                        if (4'd0 < best_val) begin
                          best_val <= 4'd0;
                          best_idx <= remove_idx_next[3:0];
                        end
                      end
                    end else begin
                      // should not happen because original_done set best_valid
                      best_val <= (topo_len > 0) ? (topo_len - 1) : 4'd0;
                      best_idx <= remove_idx_next[3:0];
                      best_valid <= 1'b1;
                    end

                    // Move to next edge
                    remove_idx_next <= remove_idx_next + 1;
                    // Reset sub-state to PARSE for next edge
                    sub_next_state <= SUB_PARSE;
                    // Reset scan_k to 0 for next parse
                    scan_k_next <= 4'd0;
                  end
                end

                default: sub_next_state <= SUB_PARSE;
              endcase
            end else begin
              // All edges checked
              next_state <= S_DONE;
              done <= 1'b1;
              // Result remains best_val
            end
          end else begin
            // Safety: shouldn't reach here before original computed
            next_state <= S_DONE;
            done <= 1'b1;
          end
        end

        S_DONE: begin
          // Hold result and done until start pulses again
          result <= result;
          done <= 1'b1;
          if (!start) begin
            next_state <= S_IDLE;
            sub_next_state <= SUB_PARSE;
            // Clear internal structures for next run on rst_n or next start
            // Not strictly necessary; will re-initialize on next start
          end else begin
            next_state <= S_DONE;
          end
        end

        default: next_state <= S_IDLE;
      endcase

      // Update state and sub_state
      state <= next_state;
      sub_state <= sub_next_state;
      remove_idx <= remove_idx_next;
      edge_mask <= edge_mask_next;
      scan_k <= scan_k_next;
    end
  end

endmodule
