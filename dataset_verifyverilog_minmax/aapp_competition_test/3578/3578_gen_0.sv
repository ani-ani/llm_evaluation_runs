module airline_review_cost(
  input clk,               // System clock
  input rst_n,             // Active-low reset
  input start,             // Start computation (pulse high)
  input [3:0] N,           // Number of airports (2-8)
  input [2:0] R,           // Number of required flights (0-5)
  input [2:0] F,           // Number of additional flights (0-5)
  // Packed required flights {a,b,c}, where a[2:0]=bits[13:11], b[2:0]=bits[10:8], c[7:0]=bits[7:0]
  input [5:0][13:0] req_flights,
  // Packed additional flights {a,b,c}, same packing as above
  input [5:0][13:0] add_flights,
  output reg [16:0] minimal_cost, // Total minimal cost (17-bit to handle ≤130K)
  output reg done          // Computation completed
);

  // Internal state machine states
  typedef enum logic [2:0] {
    ST_IDLE        = 3'd0,
    ST_SUM_REQ     = 3'd1,
    ST_BUILD_GRAPH = 3'd2,
    ST_PRIM_MST    = 3'd3,
    ST_COMPLETE    = 3'd4
  } state_t;

  state_t state;

  // Graph storage: up to 8 nodes, track the smallest weight per edge
  logic [7:0] graph [0:7][0:7]; // 0 = no edge, 1..255 = cost
  logic [7:0] edges_count;      // number of valid edges found
  logic [2:0] valid_node_count; // number of nodes referenced by any valid edge
  logic [7:0] valid_nodes_bitmap; // bitmask of nodes present in graph

  // Prim's algorithm state
  logic [7:0] visited;          // bitmask of visited nodes
  logic [7:0] dist   [0:7];     // current best cost to connect each node (0 if none yet or self)
  logic [7:0] parent [0:7];     // parent node for MST (not critical, kept for clarity)
  logic [2:0] add_step;         // steps within BUILD_GRAPH (0..5)
  logic [3:0] prim_step;        // steps within MST (0..7)
  logic [2:0] added_vertices;   // number of vertices added to MST so far
  logic [7:0] mst_cost_acc;     // accumulated MST cost (0..255, safe for MST part only)
  logic mst_disconnected;       // flag when graph is disconnected

  // Required flights cost accumulation
  logic [16:0] req_sum;         // sum of required flight costs
  logic [2:0] sum_idx;          // loop index over required flights

  // Cycle counter to guarantee completion within 40 cycles
  logic [5:0] cycle_cnt;

  // Helper: check if a given node ID is within the node bound set by N (1..8 -> 0..7)
  // Note: we treat N as the number of nodes; valid node IDs are 0..(N-1).
  function is_node_in_range;
    input [7:0] node;
    begin
      is_node_in_range = (node < N[2:0]);
    end
  endfunction

  // MAIN FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      done       <= 1'b0;
      minimal_cost <= 17'd0;
      cycle_cnt  <= 6'd0;
    end else begin
      cycle_cnt <= cycle_cnt + 1;

      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          // Latch outputs and clear runtime variables
          req_sum <= 17'd0;
          sum_idx <= 3'd0;
          add_step <= 3'd0;
          prim_step <= 4'd0;
          added_vertices <= 3'd0;
          mst_cost_acc <= 8'd0;
          mst_disconnected <= 1'b0;
          edges_count <= 8'd0;
          valid_node_count <= 3'd0;
          valid_nodes_bitmap <= 8'd0;
          // Clear graph and Prim's arrays
          for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) graph[i][j] <= 8'd0;
            dist[i] <= 8'd0;
            parent[i] <= 8'd0;
          end
          visited <= 8'd0;
          minimal_cost <= 17'd0;
          if (start) begin
            state <= ST_SUM_REQ_CALC;
            cycle_cnt <= 6'd0; // start counting from 0 on fresh start
          end
        end

        // Sum required flight costs
        ST_SUM_REQ_CALC: begin
          if (sum_idx < R) begin
            // decode from 14-bit packed format: {a[2:0]=bits[13:11], b[2:0]=bits[10:8], c[7:0]=bits[7:0]}
            logic [2:0] a, b;
            logic [7:0] c;
            a = req_flights[sum_idx][13:11];
            b = req_flights[sum_idx][10:8];
            c = req_flights[sum_idx][7:0];
            if (is_node_in_range(a) && is_node_in_range(b)) begin
              req_sum <= req_sum + {9'd0, c};
            end
            sum_idx <= sum_idx + 1;
          end else begin
            // Prepare for BUILD_GRAPH
            add_step <= 3'd0;
            edges_count <= 8'd0;
            valid_node_count <= 3'd0;
            valid_nodes_bitmap <= 8'd0;
            for (int i = 0; i < 8; i++) begin
              for (int j = 0; j < 8; j++) graph[i][j] <= 8'd0;
            end
            state <= ST_BUILD_GRAPH;
          end
        end

        // Build graph from additional flights only
        ST_BUILD_GRAPH: begin
          if (add_step < F) begin
            // decode from 14-bit packed format: {a[2:0]=bits[13:11], b[2:0]=bits[10:8], c[7:0]=bits[7:0]}
            logic [2:0] a, b;
            logic [7:0] c;
            a = add_flights[add_step][13:11];
            b = add_flights[add_step][10:8];
            c = add_flights[add_step][7:0];
            if (is_node_in_range(a) && is_node_in_range(b)) begin
              // Record the smallest cost for this undirected edge
              if ((graph[a][b] == 8'd0) || (c < graph[a][b])) begin
                graph[a][b] <= c;
                graph[b][a] <= c;
              end
              edges_count <= edges_count + 1;
              // Update node presence
              valid_nodes_bitmap[a] <= 1'b1;
              valid_nodes_bitmap[b] <= 1'b1;
            end
            add_step <= add_step + 1;
          end else begin
            // Count distinct valid nodes
            valid_node_count <= 3'd0;
            for (int i = 0; i < 8; i++) begin
              if (valid_nodes_bitmap[i]) begin
                // Note: synthesis tool will unroll loops like this
                valid_node_count <= valid_node_count + 1;
              end
            end
            // Initialize Prim's structures
            for (int i = 0; i < 8; i++) begin
              dist[i] <= 8'd0;
              parent[i] <= 8'd0;
            end
            visited <= 8'd0;
            added_vertices <= 3'd0;
            mst_cost_acc <= 8'd0;
            mst_disconnected <= 1'b0;
            prim_step <= 4'd0;
            state <= ST_PRIM_MST;
          end
        end

        // Prim's MST algorithm (sequential, 1 edge per cycle after initialization)
        ST_PRIM_MST: begin
          if (added_vertices == 3'd0) begin
            // Initialization: pick the smallest valid node as the start
            logic [2:0] start_node;
            start_node = 3'd0;
            for (int i = 0; i < 8; i++) begin
              if (valid_nodes_bitmap[i]) begin
                start_node = i;
                break;
              end
            end
            if (valid_node_count == 3'd0) begin
              // No edges at all => MST cost is 0, complete
              mst_cost_acc <= 8'd0;
              added_vertices <= 3'd0;
              state <= ST_COMPLETE;
            end else if (valid_node_count == 3'd1) begin
              // Single node, no edges needed
              mst_cost_acc <= 8'd0;
              visited[0] <= 1'b1; // won't matter; mark something to exit
              added_vertices <= 3'd1;
              state <= ST_COMPLETE;
            end else begin
              visited[start_node] <= 1'b1;
              // Prime dist array from the start node
              for (int j = 0; j < 8; j++) begin
                if (j != start_node) begin
                  dist[j] <= graph[start_node][j];
                  parent[j] <= start_node;
                end else begin
                  dist[j] <= 8'd0;
                  parent[j] <= j;
                end
              end
              added_vertices <= 3'd1;
              prim_step <= 4'd1; // move to first relax step
              mst_cost_acc <= 8'd0;
            end
          end else if (added_vertices < valid_node_count) begin
            // Find min dist vertex not visited
            logic [2:0] u;
            logic [7:0] min_dist;
            u = 3'd0;
            min_dist = 8'd255;
            for (int i = 0; i < 8; i++) begin
              if (!visited[i] && dist[i] != 8'd0) begin
                if (dist[i] < min_dist) begin
                  min_dist := dist[i];
                  u := i;
                end
              end
            end
            if (min_dist == 8'd255) begin
              // No connectable vertex => graph disconnected
              mst_disconnected <= 1'b1;
              added_vertices <= valid_node_count; // force exit
            end else begin
              // Add u to MST
              visited[u] <= 1'b1;
              mst_cost_acc <= mst_cost_acc + min_dist;
              added_vertices <= added_vertices + 1;
              // Relax edges from u
              for (int j = 0; j < 8; j++) begin
                if (!visited[j] && (graph[u][j] != 8'd0)) begin
                  if ((dist[j] == 8'd0) || (graph[u][j] < dist[j])) begin
                    dist[j] <= graph[u][j];
                    parent[j] <= u;
                  end
                end
              end
              prim_step <= prim_step + 1;
            end
          end else begin
            // MST complete
            state <= ST_COMPLETE;
          end
        end

        ST_COMPLETE: begin
          if (mst_disconnected) begin
            // If the required airports are disconnected using additional flights,
            // we still output required sum (per specification, MST cost remains 0 here)
            minimal_cost <= req_sum;
          end else begin
            // Sum required + MST cost; MST cost fits in 8 bits; req_sum in 17 bits
            minimal_cost <= req_sum + {9'd0, mst_cost_acc};
          end
          done <= 1'b1;
          state <= ST_IDLE; // Return to idle immediately after setting outputs
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule