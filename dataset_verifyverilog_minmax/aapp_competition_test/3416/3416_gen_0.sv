module train_route_optimizer (
  input clk,            // Clock
  input rst_n,          // Active-low reset
  input start,          // Start computation
  input [3:0] num_cities, // Number of cities (1-4)
  input [15:0] adj_matrix, // 4x4 adjacency matrix (adj_matrix[4*i + j] = rail from i+1 to j+1)

  output reg [1:0] min_flights, // Minimum flights needed (0-3)
  output reg [3:0] airports,    // Visit mask (airports[0]=city1 ... [3]=city4)
  output reg done                // High when computation completes
);

  // State encoding
  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, next_state;

  // Internal datapath
  reg [3:0] in_deg, out_deg;
  reg [3:0] indeg [0:3];
  reg [3:0] outdeg [0:3];
  reg [3:0] indeg_n, outdeg_n;
  reg [3:0] topo_queue [$];

  reg [3:0] rk;             // current step of DP (0..N)
  reg [3:0] longest_nodes;  // longest path length in nodes (1..N)
  reg [15:0] dp_airports;   // union of all nodes in all longest paths
  reg [15:0] adj_word;      // bits 4*i + j -> edge i->j

  // State update flops
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      min_flights <= 2'b0;
      airports <= 4'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      done <= (state == PROCESSING) ? 1'b1 : 1'b0;
      if (state == PROCESSING && rk == num_cities) begin
        min_flights <= (num_cities > 0) ? (num_cities - 1 - longest_nodes + 1) : 2'b0; // num_cities - k - 1
        airports <= dp_airports[3:0];
      end else if (state == IDLE) begin
        min_flights <= 2'b0;
        airports <= 4'b0;
      end
    end
  end

  // Main combinatorial datapath + state machine
  always_comb begin
    next_state = IDLE;
    adj_word = 16'b0;
    indeg_n = 4'b0;
    outdeg_n = 4'b0;

    // Clear internal structures each cycle (updated only in PROCESSING)
    in_deg = 4'b0;
    out_deg = 4'b0;
    for (int i = 0; i < 4; i++) begin
      indeg[i] = 4'b0;
      outdeg[i] = 4'b0;
    end
    rk = 4'b0;
    longest_nodes = 4'b1;
    dp_airports = 16'b0;

    // Default: stay in IDLE until a start pulse is seen
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end

      PROCESSING: begin
        // Precompute
        indeg_n = 0;
        outdeg_n = 0;
        for (int i = 0; i < 4; i++) begin
          indeg[i] = 0;
          outdeg[i] = 0;
        end

        // In-degree and out-degree, and adjacency bits per destination
        for (int j = 0; j < 4; j++) begin
          for (int i = 0; i < 4; i++) begin
            if (i < num_cities && j < num_cities) begin
              if (adj_matrix[4*i + j]) begin
                outdeg[i] = outdeg[i] + 1;
                indeg[j] = indeg[j] + 1;
                indeg_n = indeg_n + 1;
                outdeg_n = outdeg_n + 1;
              end
            end
          end
        end
        in_deg = indeg_n;
        out_deg = outdeg_n;

        // Topological queue construction
        topo_queue.delete();
        for (int v = 0; v < 4; v++) begin
          if (v < num_cities && indeg[v] == 0) begin
            topo_queue.push_back(v);
          end
        end

        // DP arrays on the stack (so synthesizable)
        reg [3:0] dp_len [0:3];
        reg [15:0] dp_masks [0:3];
        for (int i = 0; i < 4; i++) begin
          if (i < num_cities) begin
            dp_len[i] = 1;
            dp_masks[i] = (16'b1 << i);
          end else begin
            dp_len[i] = 4'b0;
            dp_masks[i]  = 16'b0;
          end
        end

        // Longest path DP + union of all longest-path nodes
        longest_nodes = 4'b1;
        dp_airports = 16'b0;
        rk = 4'b0;

        // Process in topological order
        while (topo_queue.size() > 0) begin
          int v;
          v = topo_queue.pop_front();
          rk = rk + 1;
          // Propagate through outgoing edges of v (if v has out edges)
          reg [3:0] max_child_len;
          reg [15:0] union_masks;
          max_child_len = 4'b0;
          union_masks = 16'b0;

          for (int u = 0; u < 4; u++) begin
            if (v < num_cities && u < num_cities && adj_matrix[4*v + u]) begin
              // parent v -> child u
              if (dp_len[v] + 1 > max_child_len) begin
                max_child_len = dp_len[v] + 1;
                union_masks = dp_masks[u];
              end else if (dp_len[v] + 1 == max_child_len) begin
                union_masks = union_masks | dp_masks[u];
              end
              // update indegree of child and push when ready
              indeg[u] = indeg[u] - 1;
              if (indeg[u] == 0) begin
                topo_queue.push_back(u);
              end
            end
          end

          if (|outdeg[v]) begin
            // v has outgoing edges: update to best child length
            dp_len[v] = max_child_len;
            dp_masks[v] = dp_masks[v] | union_masks;
          end else begin
            // sink: length already 1 (only itself)
            dp_len[v] = 4'd1;
            dp_masks[v] = dp_masks[v]; // already contains self
          end
        end

        // Find global longest path length and union of all nodes on any such path
        longest_nodes = 4'd1;
        dp_airports = 16'b0;
        for (int i = 0; i < 4; i++) begin
          if (i < num_cities) begin
            if (dp_len[i] > longest_nodes) begin
              longest_nodes = dp_len[i];
              dp_airports = dp_masks[i];
            end else if (dp_len[i] == longest_nodes) begin
              dp_airports = dp_airports | dp_masks[i];
            end
          end
        end

        // Finish when all nodes processed or immediately if DAG completed (N steps)
        if (rk == (num_cities > 0 ? num_cities : 1))
          next_state = DONE;
        else
          next_state = PROCESSING;
      end

      DONE: begin
        // Hold outputs; return to IDLE on new start or stay high until next start
        if (start) next_state = DONE;
        else next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
