module critical_path_analyzer(
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [3:0] edge_count,
  input [139:0] edge_list,
  output reg [3:0] result,
  output reg done
);

  // State encoding
  localparam IDLE             = 2'd0;
  localparam COMPUTE_ORIGINAL = 2'd1;
  localparam CHECK_EDGES      = 2'd2;
  localparam DONE             = 2'd3;

  reg [1:0] state, next_state;

  // Internal registers
  reg [2:0] n_nodes;
  reg [3:0] n_edges;

  // Edge storage: up to 16 edges, each with u[2:0], v[2:0]
  reg [2:0] edge_u [0:15];
  reg [2:0] edge_v [0:15];

  // Topological sort / DP structures
  reg [3:0] in_deg [0:7];       // in-degree per node (0-15 fits in 4 bits)
  reg [3:0] in_deg_tmp [0:7];   // working copy for Kahn's algorithm

  reg [2:0] topo_order [0:7];   // topological order

  // Queue for Kahn's algorithm (simple circular) - max 8 nodes
  reg [2:0] q_mem [0:7];
  reg [2:0] q_head;
  reg [2:0] q_tail;

  // DP: longest distance to each node
  reg [3:0] dist [0:7];

  // Iteration indices
  reg [3:0] edge_idx;           // 0..15
  reg [2:0] node_idx;           // generic node index
  reg [3:0] topo_idx;           // 0..7 for topo sequence
  reg [3:0] edge_scan_idx;      // scan edges in inner loops

  // Control for multi-cycle procedures
  typedef enum logic [2:0] {
    SUB_IDLE,
    SUB_INIT_INDEG,
    SUB_BUILD_QUEUE,
    SUB_POP_QUEUE,
    SUB_RELAX_INIT,
    SUB_RELAX_NODE,
    SUB_DONE
  } sub_state_t;

  sub_state_t sub_state;

  // Results
  reg [3:0] orig_longest;
  reg [3:0] best_longest;       // minimum longest path over all single-edge removals

  // Control for edge removal in CHECK_EDGES
  reg [3:0] remove_edge_idx;    // which edge is considered removed

  // Utility wires
  integer i;

  // Extract edges from flat list on start or when entering active states
  // edge_list layout: for edge i: bits [6*i +: 6] = {u[2:0], v[2:0]} (LSB first overall)
  // We will latch edges when we see start in IDLE.

  // Top-level FSM: sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Latch graph definition and initialize on start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_nodes <= 3'd0;
      n_edges <= 4'd0;
      for (i = 0; i < 16; i = i + 1) begin
        edge_u[i] <= 3'd0;
        edge_v[i] <= 3'd0;
      end
    end else begin
      if (state == IDLE && start) begin
        n_nodes <= node_count;
        n_edges <= edge_count;
        for (i = 0; i < 16; i = i + 1) begin
          edge_u[i] <= edge_list[6*i +: 3];
          edge_v[i] <= edge_list[6*i+3 +: 3];
        end
      end
    end
  end

  // Longest path engine sub-FSM
  // This sub-FSM performs:
  // 1) Build in-degree with optional single-edge removal
  // 2) Kahn topological sort into topo_order
  // 3) DP relaxation over topo_order
  // It is driven differently in COMPUTE_ORIGINAL vs CHECK_EDGES.

  // Helper: check if an edge is removed (active only in CHECK_EDGES state)
  wire edge_is_removed;
  assign edge_is_removed = (state == CHECK_EDGES) && (edge_scan_idx == remove_edge_idx);

  // Main sequential block for sub_state and related registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sub_state       <= SUB_IDLE;
      orig_longest    <= 4'd0;
      best_longest    <= 4'hF; // large initial
      done            <= 1'b0;
      result          <= 4'd0;
      remove_edge_idx <= 4'd0;
      edge_idx        <= 4'd0;
      node_idx        <= 3'd0;
      topo_idx        <= 4'd0;
      edge_scan_idx   <= 4'd0;
      q_head          <= 3'd0;
      q_tail          <= 3'd0;
      for (i = 0; i < 8; i = i + 1) begin
        in_deg[i]     <= 4'd0;
        in_deg_tmp[i] <= 4'd0;
        topo_order[i] <= 3'd0;
        dist[i]       <= 4'd0;
        q_mem[i]      <= 3'd0;
      end
    end else begin
      done <= 1'b0; // default, will be set in DONE state

      case (state)
        IDLE: begin
          // Reset controls; wait for start
          sub_state       <= SUB_IDLE;
          orig_longest    <= orig_longest;
          best_longest    <= best_longest;
          remove_edge_idx <= 4'd0;
          if (start) begin
            // Prepare to compute original longest path
            sub_state    <= SUB_INIT_INDEG;
            edge_scan_idx<= 4'd0;
            node_idx     <= 3'd0;
            topo_idx     <= 4'd0;
            q_head       <= 3'd0;
            q_tail       <= 3'd0;
          end
        end

        COMPUTE_ORIGINAL: begin
          // Run longest-path engine without any removal
          case (sub_state)
            SUB_INIT_INDEG: begin
              // Initialize in-degree and dist
              if (node_idx < n_nodes) begin
                in_deg[node_idx]     <= 4'd0;
                in_deg_tmp[node_idx] <= 4'd0;
                dist[node_idx]       <= 4'd0;
                node_idx             <= node_idx + 3'd1;
              end else begin
                // Start scanning edges to build in-degree
                edge_scan_idx <= 4'd0;
                sub_state     <= SUB_BUILD_QUEUE;
              end
            end

            SUB_BUILD_QUEUE: begin
              if (edge_scan_idx < n_edges) begin
                // For original compute: no removal
                in_deg[ edge_v[edge_scan_idx] ] <= in_deg[ edge_v[edge_scan_idx] ] + 4'd1;
                edge_scan_idx <= edge_scan_idx + 4'd1;
              end else begin
                // Copy in_deg to in_deg_tmp and enqueue zero in-degree nodes
                if (node_idx == 0) begin
                  node_idx <= 3'd0;
                  q_head   <= 3'd0;
                  q_tail   <= 3'd0;
                end
                if (node_idx < n_nodes) begin
                  in_deg_tmp[node_idx] <= in_deg[node_idx];
                  if (in_deg[node_idx] == 4'd0) begin
                    q_mem[q_tail] <= node_idx;
                    q_tail        <= q_tail + 3'd1;
                  end
                  node_idx <= node_idx + 3'd1;
                end else begin
                  // Start Kahn's algorithm
                  topo_idx   <= 4'd0;
                  sub_state  <= SUB_POP_QUEUE;
                end
              end
            end

            SUB_POP_QUEUE: begin
              if (q_head != q_tail) begin
                // Pop from queue
                reg [2:0] u;
                u = q_mem[q_head];
                q_head <= q_head + 3'd1;
                topo_order[topo_idx] <= u;
                topo_idx <= topo_idx + 4'd1;
                // For all edges u->v, decrement in_deg_tmp[v]
                edge_scan_idx <= 4'd0;
                sub_state <= SUB_POP_QUEUE; // will iterate with helper below

                // We'll perform the decrements sequentially within same state
                // (handled by the additional logic below)
              end else begin
                // Queue empty; move to DP relax
                topo_idx     <= 4'd0;
                edge_scan_idx<= 4'd0;
                sub_state    <= SUB_RELAX_INIT;
              end

              // Edge scanning for Kahn's algorithm (decrement in_deg_tmp) - one edge per cycle
              if (q_head != q_tail) begin
                // `u` is effectively q_mem[q_head] in previous cycle; we approximate using last stored topo_order
                reg [2:0] u_prev;
                if (topo_idx == 0)
                  u_prev = q_mem[q_head];
                else
                  u_prev = topo_order[topo_idx-1];

                if (edge_scan_idx < n_edges) begin
                  if (edge_u[edge_scan_idx] == u_prev) begin
                    if (in_deg_tmp[ edge_v[edge_scan_idx] ] != 0)
                      in_deg_tmp[ edge_v[edge_scan_idx] ] <= in_deg_tmp[ edge_v[edge_scan_idx] ] - 4'd1;
                    if (in_deg_tmp[ edge_v[edge_scan_idx] ] == 4'd1) begin
                      q_mem[q_tail] <= edge_v[edge_scan_idx];
                      q_tail        <= q_tail + 3'd1;
                    end
                  end
                  edge_scan_idx <= edge_scan_idx + 4'd1;
                end
              end
            end

            SUB_RELAX_INIT: begin
              // Initialize dist for all nodes
              if (node_idx < n_nodes) begin
                dist[node_idx] <= 4'd0;
                node_idx       <= node_idx + 3'd1;
              end else begin
                topo_idx      <= 4'd0;
                edge_scan_idx <= 4'd0;
                sub_state     <= SUB_RELAX_NODE;
              end
            end

            SUB_RELAX_NODE: begin
              if (topo_idx < n_nodes) begin
                reg [2:0] u2;
                u2 = topo_order[topo_idx];

                if (edge_scan_idx < n_edges) begin
                  if (edge_u[edge_scan_idx] == u2) begin
                    // edge weight = 1
                    if (dist[edge_v[edge_scan_idx]] < dist[u2] + 4'd1)
                      dist[edge_v[edge_scan_idx]] <= dist[u2] + 4'd1;
                  end
                  edge_scan_idx <= edge_scan_idx + 4'd1;
                end else begin
                  // Move to next node in topo
                  topo_idx      <= topo_idx + 4'd1;
                  edge_scan_idx <= 4'd0;
                end
              end else begin
                // All relaxed; compute max distance
                if (node_idx == 0) begin
                  node_idx <= 3'd0;
                end
                if (node_idx < n_nodes) begin
                  node_idx <= node_idx + 3'd1;
                end else begin
                  // Reduce max over dist
                  reg [3:0] maxd;
                  maxd = 4'd0;
                  for (i = 0; i < 8; i = i + 1) begin
                    if (i < n_nodes && dist[i] > maxd)
                      maxd = dist[i];
                  end
                  orig_longest <= maxd;
                  sub_state    <= SUB_DONE;
                end
              end
            end

            SUB_DONE: begin
              // Signal completion to top FSM (via state change)
              sub_state <= SUB_IDLE;
            end

            default: sub_state <= SUB_IDLE;
          endcase
        end

        CHECK_EDGES: begin
          // For each edge index, recompute longest path with that edge removed.
          case (sub_state)
            SUB_IDLE: begin
              // Start for current remove_edge_idx
              node_idx       <= 3'd0;
              edge_scan_idx  <= 4'd0;
              topo_idx       <= 4'd0;
              q_head         <= 3'd0;
              q_tail         <= 3'd0;
              sub_state      <= SUB_INIT_INDEG;
            end

            SUB_INIT_INDEG: begin
              if (node_idx < n_nodes) begin
                in_deg[node_idx]     <= 4'd0;
                in_deg_tmp[node_idx] <= 4'd0;
                dist[node_idx]       <= 4'd0;
                node_idx             <= node_idx + 3'd1;
              end else begin
                edge_scan_idx <= 4'd0;
                sub_state     <= SUB_BUILD_QUEUE;
              end
            end

            SUB_BUILD_QUEUE: begin
              if (edge_scan_idx < n_edges) begin
                if (edge_scan_idx != remove_edge_idx) begin
                  in_deg[ edge_v[edge_scan_idx] ] <= in_deg[ edge_v[edge_scan_idx] ] + 4'd1;
                end
                edge_scan_idx <= edge_scan_idx + 4'd1;
              end else begin
                // Copy to tmp and enqueue zero in-degree
                if (node_idx == 0) begin
                  node_idx <= 3'd0;
                  q_head   <= 3'd0;
                  q_tail   <= 3'd0;
                end
                if (node_idx < n_nodes) begin
                  in_deg_tmp[node_idx] <= in_deg[node_idx];
                  if (in_deg[node_idx] == 4'd0) begin
                    q_mem[q_tail] <= node_idx;
                    q_tail        <= q_tail + 3'd1;
                  end
                  node_idx <= node_idx + 3'd1;
                end else begin
                  topo_idx   <= 4'd0;
                  sub_state  <= SUB_POP_QUEUE;
                end
              end
            end

            SUB_POP_QUEUE: begin
              if (q_head != q_tail) begin
                reg [2:0] u;
                u = q_mem[q_head];
                q_head <= q_head + 3'd1;
                topo_order[topo_idx] <= u;
                topo_idx <= topo_idx + 4'd1;

                // scan edges to update neighbors
                if (edge_scan_idx < n_edges) begin
                  if (edge_scan_idx != remove_edge_idx && edge_u[edge_scan_idx] == u) begin
                    if (in_deg_tmp[ edge_v[edge_scan_idx] ] != 0)
                      in_deg_tmp[ edge_v[edge_scan_idx] ] <= in_deg_tmp[ edge_v[edge_scan_idx] ] - 4'd1;
                    if (in_deg_tmp[ edge_v[edge_scan_idx] ] == 4'd1) begin
                      q_mem[q_tail] <= edge_v[edge_scan_idx];
                      q_tail        <= q_tail + 3'd1;
                    end
                  end
                  edge_scan_idx <= edge_scan_idx + 4'd1;
                end else begin
                  edge_scan_idx <= 4'd0;
                end
              end else begin
                // Queue empty
                topo_idx      <= 4'd0;
                edge_scan_idx <= 4'd0;
                sub_state     <= SUB_RELAX_INIT;
              end
            end

            SUB_RELAX_INIT: begin
              if (node_idx < n_nodes) begin
                dist[node_idx] <= 4'd0;
                node_idx       <= node_idx + 3'd1;
              end else begin
                topo_idx      <= 4'd0;
                edge_scan_idx <= 4'd0;
                sub_state     <= SUB_RELAX_NODE;
              end
            end

            SUB_RELAX_NODE: begin
              if (topo_idx < n_nodes) begin
                reg [2:0] u2;
                u2 = topo_order[topo_idx];
                if (edge_scan_idx < n_edges) begin
                  if (edge_scan_idx != remove_edge_idx && edge_u[edge_scan_idx] == u2) begin
                    if (dist[edge_v[edge_scan_idx]] < dist[u2] + 4'd1)
                      dist[edge_v[edge_scan_idx]] <= dist[u2] + 4'd1;
                  end
                  edge_scan_idx <= edge_scan_idx + 4'd1;
                end else begin
                  topo_idx      <= topo_idx + 4'd1;
                  edge_scan_idx <= 4'd0;
                end
              end else begin
                // compute max
                if (node_idx == 0) begin
                  node_idx <= 3'd0;
                end
                if (node_idx < n_nodes) begin
                  node_idx <= node_idx + 3'd1;
                end else begin
                  reg [3:0] maxd2;
                  maxd2 = 4'd0;
                  for (i = 0; i < 8; i = i + 1) begin
                    if (i < n_nodes && dist[i] > maxd2)
                      maxd2 = dist[i];
                  end
                  // update best_longest (minimum)
                  if (maxd2 < best_longest)
                    best_longest <= maxd2;
                  sub_state <= SUB_DONE;
                end
              end
            end

            SUB_DONE: begin
              // Move to next edge or finish
              if (remove_edge_idx + 4'd1 < n_edges) begin
                remove_edge_idx <= remove_edge_idx + 4'd1;
                sub_state       <= SUB_IDLE;
              end else begin
                sub_state <= SUB_IDLE;
              end
            end

            default: sub_state <= SUB_IDLE;
          endcase
        end

        DONE: begin
          done   <= 1'b1;
          result <= (n_edges == 0) ? orig_longest : best_longest;
        end

        default: ;
      endcase
    end
  end

  // Next state logic for main FSM
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE_ORIGINAL;
      end
      COMPUTE_ORIGINAL: begin
        if (sub_state == SUB_DONE)
          next_state = (edge_count == 0) ? DONE : CHECK_EDGES;
      end
      CHECK_EDGES: begin
        if (sub_state == SUB_DONE && (remove_edge_idx + 4'd1 >= n_edges))
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

endmodule