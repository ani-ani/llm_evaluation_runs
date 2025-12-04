module max_flow(
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [3:0] edge_count,
  input [47:0] edges [0:15],
  output reg [15:0] flow,
  output reg done
);

  // Internal signals and storage
  localparam MAX_NODES = 8;
  localparam MAX_EDGES = 16;

  // adjacency matrix for residual capacities: [u][v] -> capacity (20-bit)
  logic [19:0] adj [0:MAX_NODES-1][0:MAX_NODES-1];

  // BFS queue (ring buffer)
  logic [2:0] q [0:MAX_NODES-1];
  logic [2:0] q_head, q_tail;
  logic q_empty;
  logic [2:0] curr_node;

  // BFS bookkeeping
  logic [MAX_NODES-1:0] visited;
  logic [2:0] parent [0:MAX_NODES-1];
  logic [2:0] parent_e [0:MAX_NODES-1];
  logic found_sink;
  logic [2:0] sink;

  // Algorithm state
  typedef enum logic [3:0] {
    S_IDLE        = 4'd0,
    S_INIT        = 4'd1,
    S_BFS_POP     = 4'd2,
    S_BFS_SEARCH  = 4'd3,
    S_BFS_PUSH    = 4'd4,
    S_UPDATE_PATH = 4'd5,
    S_DONE        = 4'd6
  } state_t;
  state_t state, next_state;

  // Cycle counter for 256-cycle completion limit
  logic [7:0] cycle_cnt;
  logic at_cycle_limit;

  // Combinational BFS edge scan index
  logic [3:0] edge_idx;
  logic [2:0] u_curr, v_curr;
  logic [15:0] cap_curr;
  logic [19:0] res_curr;

  // Path update temp
  logic [19:0] bottleneck;
  logic [2:0] path_len; // actual path length (in edges)

  // Sequential update of state machine and cycle counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      cycle_cnt <= 8'd0;
      done <= 1'b0;
      flow <= 16'd0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            state <= S_INIT;
            cycle_cnt <= 8'd0; // start counting cycles from first active cycle
            done <= 1'b0;
            flow <= 16'd0;
          end else begin
            done <= 1'b0;
            flow <= 16'd0;
          end
        end
        S_INIT: begin
          state <= S_BFS_POP;
          cycle_cnt <= cycle_cnt + 1;
        end
        S_BFS_POP: begin
          // Pull next node from queue if not empty
          if (!q_empty) begin
            curr_node <= q[q_head];
            state <= S_BFS_SEARCH;
          end else begin
            // Queue empty => no more augmenting paths
            state <= S_UPDATE_PATH;
          end
          cycle_cnt <= cycle_cnt + 1;
        end
        S_BFS_SEARCH: begin
          // Scan all edges from current node in this cycle
          state <= S_BFS_PUSH;
          cycle_cnt <= cycle_cnt + 1;
        end
        S_BFS_PUSH: begin
          // Decide whether to queue neighbor or move to next BFS step
          if (found_sink) begin
            state <= S_UPDATE_PATH;
          end else if (q_empty) begin
            state <= S_UPDATE_PATH; // queue drained
          end else begin
            state <= S_BFS_POP;
          end
          cycle_cnt <= cycle_cnt + 1;
        end
        S_UPDATE_PATH: begin
          if (found_sink && !at_cycle_limit) begin
            // Reset BFS for next augmenting path
            state <= S_BFS_POP;
            // visited and queue cleared by next INIT_BFS in BFS_POP/INIT path
          end else begin
            state <= S_DONE;
          end
          cycle_cnt <= cycle_cnt + 1;
        end
        S_DONE: begin
          done <= 1'b1;
          // Hold flow valid until next reset/start
          if (start) begin
            // restart on new start (pulse). Maintain done until start deasserted.
            state <= S_INIT;
            cycle_cnt <= 8'd0;
            done <= 1'b0;
            flow <= 16'd0;
          end
        end
        default: state <= S_IDLE;
      endcase

      if (cycle_cnt == 8'd255) begin
        at_cycle_limit <= 1'b1;
      end else begin
        at_cycle_limit <= 1'b0;
      end
    end
  end

  // Compute BFS next-state controls and internal signals
  always_comb begin
    // Defaults
    next_state = state;
    u_curr = curr_node;
    v_curr = 3'b0;
    cap_curr = 16'b0;
    res_curr = 20'b0;
    sink = 3'd7; // assume sink is node 7 by default; can be adjusted

    // Edge scanning logic inside BFS_SEARCH
    if (state == S_BFS_SEARCH) begin
      // edge_idx from 0..15
      // Map edges unpacked array to fields
      v_curr = edges[edge_idx][45:43];       // v = bits [45:43]
      cap_curr = edges[edge_idx][15:0];      // cap = bits [15:0]
      u_curr = curr_node;
      res_curr = adj[u_curr][v_curr];
    end
  end

  // Sequential updates that are not purely combinatorial
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize adjacency matrix (cleared on reset)
      for (int i = 0; i < MAX_NODES; i++) begin
        for (int j = 0; j < MAX_NODES; j++) begin
          adj[i][j] <= 20'd0;
        end
      end
      // Reset BFS structures
      q_head <= 3'd0;
      q_tail <= 3'd0;
      q_empty <= 1'b1;
      visited <= 8'b0;
      found_sink <= 1'b0;
      for (int k = 0; k < MAX_NODES; k++) begin
        parent[k] <= 3'b0;
        parent_e[k] <= 3'b0;
      end
    end else begin
      case (state)
        S_IDLE: begin
          // Hold reset-like conditions when idle
          q_head <= 3'd0;
          q_tail <= 3'd0;
          q_empty <= 1'b1;
          visited <= 8'b0;
          found_sink <= 1'b0;
          for (int k = 0; k < MAX_NODES; k++) begin
            parent[k] <= 3'b0;
            parent_e[k] <= 3'b0;
          end
        end
        S_INIT: begin
          // Clear adjacency and initialize from edges (directed)
          for (int i = 0; i < MAX_NODES; i++) begin
            for (int j = 0; j < MAX_NODES; j++) begin
              adj[i][j] <= 20'd0;
            end
          end
          for (int e = 0; e < edge_count && e < MAX_EDGES; e++) begin
            logic [2:0] u, v;
            logic [15:0] cap;
            u = edges[e][46:44];
            v = edges[e][45:43];
            cap = edges[e][15:0];
            if (u < node_count && v < node_count) begin
              adj[u][v] <= cap; // set initial residual capacity
            end
          end

          // Initialize BFS for first augmenting path
          q_head <= 3'd0;
          q_tail <= 3'd0;
          q_empty <= 1'b1;
          visited <= 8'b0;
          found_sink <= 1'b0;
          sink <= (node_count > 1) ? (node_count - 1) : 3'd0;
          for (int k = 0; k < MAX_NODES; k++) begin
            parent[k] <= 3'b0;
            parent_e[k] <= 3'b0;
          end
        end
        S_BFS_POP: begin
          // Dequeue if not empty
          if (!q_empty) begin
            q_head <= q_head + 1;
            if (q_head == q_tail) begin
              q_empty <= 1'b1;
            end
          end else begin
            // Empty queue: nothing to pop
          end
        end
        S_BFS_SEARCH: begin
          // Explore all outgoing edges from curr_node in parallel this cycle.
          // We'll evaluate each potential neighbor and enqueue if feasible.
          for (int e = 0; e < MAX_EDGES; e++) begin
            logic [2:0] u, v;
            logic [15:0] cap;
            logic [19:0] res;
            logic edge_valid;
            u = edges[e][46:44];
            v = edges[e][45:43];
            cap = edges[e][15:0];
            res = adj[u][v];
            edge_valid = (u < node_count && v < node_count) && (e < edge_count);

            // Enqueue logic for this edge
            if (state == S_BFS_SEARCH) begin
              // If this edge originates from the current node, has residual capacity,
              // hasn't been visited, and BFS not already found sink, attempt enqueue.
              if (edge_valid && (u == curr_node) && (res > 0) && !visited[v] && !found_sink) begin
                // Enqueue v
                q[q_tail] <= v;
                q_tail <= q_tail + 1;
                q_empty <= 1'b0;
                visited[v] <= 1'b1;
                parent[v] <= u;
                parent_e[v] <= e[2:0];
                if (v == sink) begin
                  found_sink <= 1'b1;
                end
              end
            end
          end
        end
        S_BFS_PUSH: begin
          // no new state changes here; decisions are made in state transitions
        end
        S_UPDATE_PATH: begin
          if (found_sink) begin
            // Compute bottleneck along the found path
            logic [19:0] min_res;
            logic [2:0] v_path;
            v_path = sink;
            min_res = 20'hFFFFF; // big number
            // Walk back from sink to source using parent[]
            for (int i = 0; i < MAX_NODES; i++) begin
              logic [2:0] pv;
              pv = parent[v_path];
              if (pv == v_path) begin // reached source (parent of source is itself)
                break;
              end
              if (pv < node_count && v_path < node_count) begin
                if (adj[pv][v_path] < min_res) begin
                  min_res = adj[pv][v_path];
                end
              end
              v_path = pv;
              if (i == MAX_NODES-1) break;
            end
            bottleneck <= min_res;

            // Apply augmentation along the path and accumulate flow
            v_path = sink;
            for (int i = 0; i < MAX_NODES; i++) begin
              logic [2:0] pv;
              pv = parent[v_path];
              if (pv == v_path) begin // reached source
                break;
              end
              if (pv < node_count && v_path < node_count) begin
                // Update residual capacities
                adj[pv][v_path] <= adj[pv][v_path] - min_res;
                adj[v_path][pv] <= adj[v_path][pv] + min_res;
              end
              v_path = pv;
              if (i == MAX_NODES-1) break;
            end

            // Accumulate flow (saturate at 16-bit max)
            if (flow < 16'hFFFF) begin
              logic [20:0] tmp_flow;
              tmp_flow = flow + min_res;
              if (tmp_flow[20]) begin
                flow <= 16'hFFFF;
              end else begin
                flow <= tmp_flow[15:0];
              end
            end

            // Prepare for next augmenting path if not at cycle limit
            if (!at_cycle_limit) begin
              q_head <= 3'd0;
              q_tail <= 3'd0;
              q_empty <= 1'b1;
              visited <= 8'b0;
              found_sink <= 1'b0;
              for (int k = 0; k < MAX_NODES; k++) begin
                parent[k] <= 3'b0;
                parent_e[k] <= 3'b0;
              end
            end
          end else begin
            // No augmenting path found; finalization handled by moving to S_DONE
          end
        end
        S_DONE: begin
          // hold flow; done remains high
        end
        default: ;
      endcase
    end
  end

  // Edge index increment in BFS_SEARCH
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      edge_idx <= 4'd0;
    end else begin
      if (state == S_BFS_SEARCH) begin
        edge_idx <= edge_idx + 1;
      end else begin
        edge_idx <= 4'd0;
      end
    end
  end

endmodule
