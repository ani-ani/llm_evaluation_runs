module longest_path_to_1 (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [15:0][7:0] edges,
  output reg [4:0] path_length,
  output reg done
);

  // Internal constants
  localparam MAX_NODES = 8;
  localparam MAX_EDGES = 16;
  localparam MAX_PATHS = 1 << 16; // Upper bound to cover all simple path masks (65k)
  localparam CYCLE_LIMIT = 100;

  // Types
  typedef logic [2:0] node_t;
  typedef logic [7:0] node8_t;
  typedef logic [MAX_NODES-1:0] node_mask_t;
  typedef logic [MAX_EDGES-1:0] edge_mask_t;

  typedef struct packed {
    node_t   node;          // Current node ID (0..7)
    node_mask_t visited;    // Visited nodes mask (for cycle avoidance)
    edge_mask_t used;       // Used edge mask (bit j == 1 => edge j already consumed)
    logic [4:0] len;        // Path length (#edges so far)
  } path_t;

  // State machine
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_BUSY  = 2'b01,
    S_DONE  = 2'b10
  } fsm_state_t;

  fsm_state_t state, next_state;

  // Computation registers
  logic [7:0] adj_matrix [MAX_NODES]; // adj_matrix[u][v] is 1 if an edge connects u->v
  logic [MAX_EDGES-1:0] valid_edges_mask; // Valid edges after input filtering
  logic [MAX_EDGES-1:0] bidirectional_mask; // Edges that are bidirectional (both directions valid)

  // BFS state
  logic [6:0] cycle_counter;  // Counts up to 100 (fits in 7 bits)
  logic [15:0] frontier_size; // Number of active paths at current BFS level
  logic [15:0] next_frontier_size;

  path_t frontier [0:MAX_PATHS-1];
  path_t next_frontier [0:MAX_PATHS-1];
  path_t temp_frontier [0:MAX_PATHS-1];

  // Result tracking
  logic [4:0] best_len;
  logic       result_ready;

  // Precompute adjacency and edge validity
  integer i, j;
  always_comb begin
    // Defaults
    for (i = 0; i < MAX_NODES; i = i + 1) adj_matrix[i] = 8'h0;
    for (i = 0; i < MAX_EDGES; i = i + 1) begin
      node_t a, b;
      logic  valid;
      a = edges[i][7:5];
      b = edges[i][4:2];
      valid = edges[i][0];
      if (valid && a < node_count && b < node_count) begin
        adj_matrix[a][b] = 1'b1; // Direction a->b is present
      end
    end
    // Build bidirectional mask: an edge is bi-directional if both directions exist in adj_matrix
    // But since we only know the packed edge is {A,B,_,valid}, we compute bi-direction as:
    // both (A->B) and (B->A) present.
    for (i = 0; i < MAX_EDGES; i = i + 1) begin
      node_t a, b;
      logic  valid, bi;
      a = edges[i][7:5];
      b = edges[i][4:2];
      valid = edges[i][0];
      bi = 1'b0;
      if (valid && a < node_count && b < node_count) begin
        // If both directions exist in adjacency matrix
        if (adj_matrix[a][b] && adj_matrix[b][a]) bi = 1'b1;
      end
      bidirectional_mask[i] = bi;
    end
  end

  // Main FSM + datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      cycle_counter <= 7'd0;
      frontier_size <= 16'd0;
      next_frontier_size <= 16'd0;
      best_len <= 5'd0;
      result_ready <= 1'b0;
      path_length <= 5'd0;
      done <= 1'b0;
    end else begin
      case (state)
        S_IDLE: begin
          // Reset datapath on idle
          frontier_size <= 16'd0;
          next_frontier_size <= 16'd0;
          best_len <= 5'd0;
          result_ready <= 1'b0;
          path_length <= 5'd0;
          done <= 1'b0;
          cycle_counter <= 7'd0;
          if (start) begin
            // Initialize valid edge mask and BFS frontier
            valid_edges_mask <= {MAX_EDGES{1'b0}};
            for (i = 0; i < MAX_EDGES; i = i + 1) begin
              node_t a, b;
              a = edges[i][7:5];
              b = edges[i][4:2];
              if (edges[i][0] && a < node_count && b < node_count) begin
                valid_edges_mask[i] <= 1'b1;
              end
            end

            // Seed frontier: start from every node != 1 (node 0), path length 0, only the node marked visited
            frontier_size <= 16'd0;
            for (j = 0; j < MAX_NODES; j = j + 1) begin
              if (j != 3'd0) begin // Exclude node 0 from seeds
                frontier[frontier_size] <= '{
                  node: node_t'(j),
                  visited: node_mask_t'(1 << j),
                  used: {MAX_EDGES{1'b0}},
                  len: 5'd0
                };
                frontier_size <= frontier_size + 1;
              end
            end
            next_frontier_size <= 16'd0;
            state <= S_BUSY;
            cycle_counter <= 7'd0;
            best_len <= 5'd0;
            result_ready <= 1'b0;
          end
        end

        S_BUSY: begin
          // One BFS level per cycle
          next_frontier_size <= 16'd0;
          // Expand all paths in current frontier
          for (int p = 0; p < MAX_PATHS; p = p + 1) begin
            if (p < frontier_size) begin
              path_t cur = frontier[p];
              // Explore all edges that are valid, not used, and lead to an unvisited node
              for (int e = 0; e < MAX_EDGES; e = e + 1) begin
                if (valid_edges_mask[e] && !cur.used[e]) begin
                  node_t a, b;
                  a = edges[e][7:5];
                  b = edges[e][4:2];
                  if (cur.node == a) begin
                    // Forward direction a->b
                    if (!cur.visited[b]) begin
                      path_t nxt;
                      nxt = cur;
                      nxt.node <= b;
                      nxt.used[e] <= 1'b1;
                      nxt.visited[b] <= 1'b1;
                      nxt.len <= cur.len + 1;

                      // Update best if we reached node 1 (node 0)
                      if (b == 3'd0) begin
                        if (nxt.len > best_len) best_len <= nxt.len;
                      end

                      // Append to next frontier (simple cycle-free BFS)
                      if (next_frontier_size < MAX_PATHS) begin
                        next_frontier[next_frontier_size] <= nxt;
                        next_frontier_size <= next_frontier_size + 1;
                      end
                    end
                  end else if (cur.node == b) begin
                    // Reverse direction b->a (if edge is bidirectional, we can use it backward)
                    if (bidirectional_mask[e]) begin
                      if (!cur.visited[a]) begin
                        path_t nxt;
                        nxt = cur;
                        nxt.node <= a;
                        nxt.used[e] <= 1'b1;
                        nxt.visited[a] <= 1'b1;
                        nxt.len <= cur.len + 1;

                        if (a == 3'd0) begin
                          if (nxt.len > best_len) best_len <= nxt.len;
                        end

                        if (next_frontier_size < MAX_PATHS) begin
                          next_frontier[next_frontier_size] <= nxt;
                          next_frontier_size <= next_frontier_size + 1;
                        end
                      end
                    end
                  end
                end
              end // e
            end
          end // p

          // Move to next BFS level
          for (int k = 0; k < MAX_PATHS; k = k + 1) begin
            if (k < next_frontier_size) frontier[k] <= next_frontier[k];
            else frontier[k] <= '{
              node: 3'd0, visited: {MAX_NODES{1'b0}}, used: {MAX_EDGES{1'b0}}, len: 5'd0
            };
          end
          frontier_size <= next_frontier_size;
          cycle_counter <= cycle_counter + 1;

          if (cycle_counter == (CYCLE_LIMIT - 1)) begin
            // Time's up: capture result and finish
            result_ready <= 1'b1;
            state <= S_DONE;
          end else if (next_frontier_size == 16'd0) begin
            // Exhausted all paths: finish early
            result_ready <= 1'b1;
            state <= S_DONE;
          end
        end

        S_DONE: begin
          // Latch result and done flag
          if (result_ready) begin
            path_length <= best_len;
            done <= 1'b1;
          end
          // Stay in done until next start or reset
          if (start) begin
            // Allow restart on next cycle (go to IDLE on next clk)
            state <= S_IDLE;
            done <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule