module max_road_counter(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation
  input [7:0] adjacency_matrix, // 8x8 adjacency matrix (1-bit per cell, row-major)
  input [4:0] current_road_count, // Current roads count (0-16)
  output reg [5:0] max_new_roads, // Result: maximum new roads
  output reg done // High when computation complete
);

  // Internal state
  typedef enum logic [3:0] {
    S_IDLE     = 4'd0,
    S_SCC      = 4'd1, // Tarjan SCC iterative
    S_COUNT    = 4'd2, // Count existing edges per pair and within SCCs
    S_DONE     = 4'd3
  } state_t;

  state_t state, state_next;

  // Node and graph sizing
  localparam N = 8;
  localparam MAX_PAIRS = N * (N - 1) / 2; // 28 unordered pairs for N=8
  localparam BIT_W = $clog2(N); // 3 bits for node index

  // Tarjan data structures
  // We simulate recursion with an explicit stack of frames (max depth 8).
  typedef struct packed {
    logic valid;         // frame is active
    logic [BIT_W-1:0] u; // current node being processed
    logic [2:0] stage;   // 0=just-pushed, 1=iterating children, 2=post-iteration
    logic [BIT_W-1:0] child_idx; // next child to try
    logic [BIT_W-1:0] lowlink_u; // cached lowlink for u
  } frame_t;

  // Tarjan runtime signals
  reg [2:0] index_ptr; // next index to assign (0..7)
  reg [2:0] scc_id_ptr; // next scc id to assign (0..7)
  reg [2:0] onstack_cnt; // nodes currently on stack (0..8)
  logic onstack_pop; // pop this cycle

  // SCC results per node
  reg [2:0] comp_id [N]; // component id per node (0..7)
  reg [2:0] comp_size [N]; // size per component id (0..7)
  reg [2:0] comp_cnt; // number of components (0..8)

  // Tarjan index and lowlink per node, plus stack flag
  reg [2:0] idx [N]; // discovery index
  reg [2:0] low [N]; // lowlink values
  logic onstack [N]; // membership in recursion stack

  // Stack nodes (ids) for Tarjan onstack simulation
  logic [2:0] stack_nodes [8]; // holds node ids currently on stack

  // Frame stack for DFS
  frame_t frame_stack [8];
  logic frame_push;
  logic [2:0] frame_sp; // stack pointer (0..8)

  // SCC detection control
  reg [2:0] scc_root [N]; // root of the SCC for each node (valid only for root nodes)
  logic is_root; // true if node is a root of its SCC
  logic [2:0] v_u, v_v; // temp node indices for current edge under test
  logic edge_exists;
  logic same_comp;

  // Edge counting (iterative over unordered pairs)
  reg [2:0] pair_u, pair_v;           // current unordered pair (u<v)
  logic pair_done, pair_start;
  reg [2:0] pair_cnt;                 // counts processed pairs (0..28)
  reg [6:0] cross_pairs_total;        // total unordered cross-component pairs
  reg [6:0] cross_pairs_occupied;     // number of cross-component unordered pairs with at least one existing directed edge
  reg [6:0] intra_pairs_total;        // sum of s*(s-1)/2 over all SCCs
  reg [6:0] intra_existing_unordered; // number of unordered intra-SCC pairs that already have at least one directed edge
  reg has_uv, has_vu;
  logic [5:0] max_new_roads_next;

  // Helper functions
  function bit bit_at(input [7:0] m, input [5:0] pos);
    bit_at = m[pos];
  endfunction

  function bit edge_exists_fn(input [7:0] m, input [2:0] u, input [2:0] v);
    // returns 1 if directed edge u->v exists
    // pos = 8*u + v
    edge_exists_fn = m[(u<<3) + v];
  endfunction

  // State machine sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      max_new_roads <= 6'd0;
    end else begin
      state <= state_next;
      if (state_next == S_DONE) begin
        done <= 1'b1;
        max_new_roads <= max_new_roads_next;
      end else begin
        done <= 1'b0;
        // hold previous result while computing
        if (state != S_IDLE) max_new_roads <= max_new_roads_next;
      end
    end
  end

  // Tarjan SCC data reset/init on start
  logic scc_init;
  always_ff @(posedge clk) begin
    if (scc_init) begin
      // clear per-node Tarjan state
      idx[0] <= 3'd0; idx[1] <= 3'd0; idx[2] <= 3'd0; idx[3] <= 3'd0;
      idx[4] <= 3'd0; idx[5] <= 3'd0; idx[6] <= 3'd0; idx[7] <= 3'd0;
      low[0] <= 3'd0; low[1] <= 3'd0; low[2] <= 3'd0; low[3] <= 3'd0;
      low[4] <= 3'd0; low[5] <= 3'd0; low[6] <= 3'd0; low[7] <= 3'd0;
      onstack[0] <= 1'b0; onstack[1] <= 1'b0; onstack[2] <= 1'b0; onstack[3] <= 1'b0;
      onstack[4] <= 1'b0; onstack[5] <= 1'b0; onstack[6] <= 1'b0; onstack[7] <= 1'b0;
      index_ptr <= 3'd0;
      scc_id_ptr <= 3'd0;
      onstack_cnt <= 3'd0;
      comp_cnt <= 3'd0;
      // clear comp arrays
      comp_id[0] <= 3'd0; comp_id[1] <= 3'd0; comp_id[2] <= 3'd0; comp_id[3] <= 3'd0;
      comp_id[4] <= 3'd0; comp_id[5] <= 3'd0; comp_id[6] <= 3'd0; comp_id[7] <= 3'd0;
      comp_size[0] <= 3'd0; comp_size[1] <= 3'd0; comp_size[2] <= 3'd0; comp_size[3] <= 3'd0;
      comp_size[4] <= 3'd0; comp_size[5] <= 3'd0; comp_size[6] <= 3'd0; comp_size[7] <= 3'd0;
      // clear frame stack
      frame_sp <= 3'd0;
      for (int i=0; i<8; i++) begin
        frame_stack[i].valid <= 1'b0;
        frame_stack[i].stage <= 3'd0;
        frame_stack[i].child_idx <= 3'd0;
      end
    end
  end

  // Edge counting init
  logic count_init;
  always_ff @(posedge clk) begin
    if (count_init) begin
      pair_cnt <= 3'd0;
      cross_pairs_total <= 7'd0;
      cross_pairs_occupied <= 7'd0;
      intra_pairs_total <= 7'd0;
      intra_existing_unordered <= 7'd0;
    end
  end

  // Combinational next state logic
  always_comb begin
    state_next = state;
    scc_init = 1'b0;
    count_init = 1'b0;
    max_new_roads_next = 6'd0;

    case (state)
      S_IDLE: begin
        if (start) begin
          scc_init = 1'b1;
          state_next = S_SCC;
        end
      end

      S_SCC: begin
        // Tarjan iterative step: run until all nodes processed
        // When complete, move to COUNT.
        if (scc_done) begin
          count_init = 1'b1;
          state_next = S_COUNT;
        end
      end

      S_COUNT: begin
        // Count existing edges across unordered pairs and within SCCs
        if (pair_done) begin
          // Compute final result: capacity = MAX_PAIRS - intra_pairs_total - current_road_count
          // Then add back existing cross-component unordered pairs (since they can still accept one more road)
          // This ensures no cycle creation and no double-counting of intra-SCC bidirectional edges.
          max_new_roads_next = (6'd28 - intra_pairs_total) - current_road_count + intra_existing_unordered + cross_pairs_occupied;
          state_next = S_DONE;
        end
      end

      S_DONE: begin
        // Hold until start deasserted
        if (!start) begin
          state_next = S_IDLE;
        end
      end
    endcase
  end

  // Tarjan iterative engine signals
  logic scc_done;
  logic stack_push_node, stack_pop_node;
  logic [2:0] new_node;
  logic [2:0] frame_u;
  logic [2:0] next_child;
  logic [2:0] low_u;
  logic [2:0] next_index;

  // Tarjan iterative orchestration
  // This block performs one DFS step per clock, expanding the first active frame.
  always_ff @(posedge clk) begin
    if (scc_init) begin
      scc_done <= 1'b0;
    end else if (state == S_SCC) begin
      // If no active frame and we haven't visited all nodes, start a new root frame.
      if (frame_sp == 3'd0 && index_ptr < 3'd8) begin
        // start new DFS from the next unvisited node
        new_node <= index_ptr;
        // push root node on stack
        stack_push_node <= 1'b1;
        // create a new frame for this node
        frame_stack[frame_sp].valid <= 1'b1;
        frame_stack[frame_sp].u <= index_ptr;
        frame_stack[frame_sp].stage <= 3'd0; // 0 = just-pushed
        frame_stack[frame_sp].child_idx <= 3'd0;
        frame_stack[frame_sp].lowlink_u <= 3'd0;
        frame_sp <= frame_sp + 1;
        // mark visited: set idx and low, put on stack
        idx[index_ptr] <= index_ptr;
        low[index_ptr] <= index_ptr;
        // push onto onstack nodes array
        stack_nodes[onstack_cnt] <= index_ptr;
        onstack_cnt <= onstack_cnt + 1;
        onstack[index_ptr] <= 1'b1;
        // allocate next index
        next_index <= index_ptr + 1;
        index_ptr <= next_index;
      end else if (frame_sp > 3'd0) begin
        // Process the top frame (depth-first search progression)
        frame_u <= frame_stack[frame_sp-1].u;
        // stage 0: initialize child iteration
        if (frame_stack[frame_sp-1].stage == 3'd0) begin
          // Set lowlink cache to current low
          frame_stack[frame_sp-1].lowlink_u <= low[frame_u];
          // If all children processed, pop and finalize root if needed
          if (frame_stack[frame_sp-1].child_idx >= 3'd8) begin
            // All children processed for u: finalize
            // Update lowlink from cache
            low[frame_u] <= frame_stack[frame_sp-1].lowlink_u;
            // Decide if root
            is_root <= (low[frame_u] == idx[frame_u]);
            // Pop from stack before possibly assigning SCC id to keep onstack consistency
            stack_pop_node <= 1'b1;
            // Move to stage 2 (post-iteration) to handle root logic
            frame_stack[frame_sp-1].stage <= 3'd2;
          end else begin
            // Start iterating over a child v
            frame_stack[frame_sp-1].stage <= 3'd1; // iterating children
            frame_stack[frame_sp-1].child_idx <= frame_stack[frame_sp-1].child_idx; // keep current child index
          end
        end
        // stage 1: iterate over children one per cycle
        else if (frame_stack[frame_sp-1].stage == 3'd1) begin
          next_child <= frame_stack[frame_sp-1].child_idx;
          // If v is not u, and edge u->v exists
          if ((next_child != frame_u) && edge_exists_fn(adjacency_matrix, frame_u, next_child)) begin
            if (idx[next_child] == 3'd8) begin
              // v is unvisited: push a child frame for v
              frame_stack[frame_sp].valid <= 1'b1;
              frame_stack[frame_sp].u <= next_child;
              frame_stack[frame_sp].stage <= 3'd0;
              frame_stack[frame_sp].child_idx <= 3'd0;
              frame_stack[frame_sp].lowlink_u <= 3'd0;
              frame_sp <= frame_sp + 1;
              // mark visited: set idx and low, put on stack
              idx[next_child] <= index_ptr;
              low[next_child] <= index_ptr;
              stack_nodes[onstack_cnt] <= next_child;
              onstack_cnt <= onstack_cnt + 1;
              onstack[next_child] <= 1'b1;
              // allocate next index
              next_index <= index_ptr + 1;
              index_ptr <= next_index;
            end else if (onstack[next_child]) begin
              // v is on stack: update low[u]
              low_u <= low[frame_u];
              if (idx[next_child] < low_u) begin
                low[frame_u] <= idx[next_child];
              end
            end
          end
          // advance child index
          frame_stack[frame_sp-1].child_idx <= next_child + 1;
          // If this was the last child, move to stage 2
          if ((next_child + 1) >= 3'd8) begin
            frame_stack[frame_sp-1].stage <= 3'd0; // mark as ready to finalize next cycle
          end
        end
        // stage 2: finalize root if applicable
        else if (frame_stack[frame_sp-1].stage == 3'd2) begin
          if (is_root) begin
            // Pop nodes until u off stack -> form a new SCC
            // This is done in subsequent cycles using stack_pop_node pulses from stage 2.
            // Determine number of nodes to pop: we pop one per cycle until we popped all for this SCC.
            // We'll store root in scc_root for later detection of which nodes belong to this SCC.
            scc_root[frame_u] <= frame_u; // mark frame_u as the root node of this SCC
            // Pop a single node per cycle and assign scc id when we popped the root
            if (stack_pop_node) begin
              // Pop from onstack nodes array
              onstack_cnt <= onstack_cnt - 1;
              onstack[stack_nodes[onstack_cnt-1]] <= 1'b0;
              // When we pop the root node, close SCC and increment scc id
              if (stack_nodes[onstack_cnt-1] == frame_u) begin
                // Finish SCC: assign comp_id to the nodes we popped in this SCC.
                // In practice, the popped node ids are in stack_nodes[onstack_cnt .. original_onstack_cnt-1].
                // We will tag them now by scanning the stack region: the node just popped is the root; we need to mark the other nodes popped for this SCC.
                // To keep it simple, we process comp assignment in a separate small loop in subsequent cycles.
                // Here, we just record that one SCC is finished.
                scc_id_ptr <= scc_id_ptr + 1; // will assign next scc id
              end
            end
          end
          // Pop this frame regardless
          frame_stack[frame_sp-1].valid <= 1'b0;
          frame_sp <= frame_sp - 1;
          // If all nodes assigned and stack is empty, done
          if (index_ptr >= 3'd8 && frame_sp == 3'd1) begin
            scc_done <= 1'b1;
          end
        end
      end else begin
        // No frames and all indices assigned -> done
        if (index_ptr >= 3'd8) begin
          scc_done <= 1'b1;
        end
      end
    end else begin
      scc_done <= 1'b0;
    end
  end

  // Assign component ids for nodes when an SCC root is closed.
  // We do it by scanning all nodes and testing membership: if node's scc_root equals the closed root, assign comp id.
  logic [2:0] closed_root;
  logic [2:0] closed_scc_id;
  always_ff @(posedge clk) begin
    if (scc_init) begin
      comp_cnt <= 3'd0;
    end else if (state == S_SCC && scc_done) begin
      // after Tarjan completes, comp_cnt = scc_id_ptr (number of SCCs)
      comp_cnt <= scc_id_ptr;
    end else if (state == S_SCC) begin
      // capture root and scc id at the moment we pop the root node
      if (stack_pop_node && (stack_nodes[onstack_cnt-1] == frame_u) && is_root) begin
        closed_root <= frame_u;
        closed_scc_id <= scc_id_ptr; // the id that will be used for this component
        // assign comp_id to all nodes that belong to this SCC (u is root; all nodes whose scc_root == root belong)
        for (int i=0; i<8; i++) begin
          if (scc_root[i] == frame_u) begin
            comp_id[i] <= closed_scc_id;
          end
        end
        // increment comp sizes for this scc id after assigning all comp_id entries
        // count nodes with scc_root == root
        comp_size[closed_scc_id] <= 3'd0;
        for (int i=0; i<8; i++) begin
          if (scc_root[i] == frame_u) begin
            comp_size[closed_scc_id] <= comp_size[closed_scc_id] + 1;
          end
        end
        // increment total component count
        comp_cnt <= scc_id_ptr + 1;
      end
    end
  end

  // Pair-wise edge counting state machine
  assign pair_start = (state == S_COUNT && count_init);
  always_ff @(posedge clk) begin
    if (count_init) begin
      pair_cnt <= 3'd0;
      cross_pairs_total <= 7'd0;
      cross_pairs_occupied <= 7'd0;
      intra_pairs_total <= 7'd0;
      intra_existing_unordered <= 7'd0;
    end else if (state == S_COUNT) begin
      if (pair_cnt < 3'd28) begin
        // current unordered pair: (u,v) with u<v, order lexicographic
        // u from 0..6, v from (u+1)..7
        pair_u <= (pair_cnt / 3'd7); // 0..6
        pair_v <= (pair_cnt % 3'd7) + 1; // 1..7

        has_uv <= edge_exists_fn(adjacency_matrix, pair_u, pair_v);
        has_vu <= edge_exists_fn(adjacency_matrix, pair_v, pair_u);

        same_comp <= (comp_id[pair_u] == comp_id[pair_v]);
        // If unordered pair has any directed edge, count it as occupied for cross-SCC pairs,
        // and count it as an existing intra-SCC unordered pair if they are in the same SCC.
        if (same_comp) begin
          // Count unordered pairs within this SCC
          intra_pairs_total <= intra_pairs_total + 1;
          if (has_uv || has_vu) begin
            intra_existing_unordered <= intra_existing_unordered + 1;
          end
        end else begin
          // Cross-SCC pair
          cross_pairs_total <= cross_pairs_total + 1;
          if (has_uv || has_vu) begin
            cross_pairs_occupied <= cross_pairs_occupied + 1;
          end
        end

        pair_cnt <= pair_cnt + 1;
      end
    end
  end

  assign pair_done = (state == S_COUNT) && (pair_cnt == 3'd28);

  // Done state hold
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      max_new_roads <= 6'd0;
    end else if (state_next == S_DONE) begin
      // max_new_roads_next already computed in combinational logic
      // It will be latched by the main always_ff at the start of S_DONE
    end
  end

endmodule