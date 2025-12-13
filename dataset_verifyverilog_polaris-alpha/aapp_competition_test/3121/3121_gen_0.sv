module cave_pathfinder(
  input clk,
  input rst_n,
  input start,
  input [15:0] unnars_attack,
  input [15:0] unnars_health,
  input [3:0] num_nodes,
  input [3:0] num_passages,
  input [63:0] passages [0:15],
  output reg [15:0] max_health,
  output reg done,
  output reg oh_no
);

  // Parameters
  localparam MAX_NODES    = 8;
  localparam MAX_EDGES    = 16;
  localparam EDGE_IDX_W   = 4;   // log2(MAX_EDGES)
  localparam NODE_IDX_W   = 3;   // log2(MAX_NODES)

  // Edge storage
  // For simplicity, we decode passages into flat arrays
  reg [NODE_IDX_W-1:0] edge_from   [0:MAX_EDGES-1];
  reg [NODE_IDX_W-1:0] edge_to     [0:MAX_EDGES-1];
  reg [15:0]           edge_a      [0:MAX_EDGES-1];
  reg [15:0]           edge_h      [0:MAX_EDGES-1];

  // Adjacency: for each node, list of outgoing edge indices
  reg [EDGE_IDX_W-1:0] adj_edges   [0:MAX_NODES-1][0:MAX_EDGES-1];
  reg [4:0]            adj_count   [0:MAX_NODES-1]; // up to 16

  // DFS stack: depth up to MAX_NODES (simple path)
  reg [NODE_IDX_W-1:0] stack_node      [0:MAX_NODES-1];
  reg [EDGE_IDX_W-1:0] stack_edge_pos  [0:MAX_NODES-1]; // next adj index to try at this depth
  reg [15:0]           stack_health    [0:MAX_NODES-1];

  // Visited mask for simple paths (avoid cycles)
  reg [MAX_NODES-1:0] visited;

  // Control registers
  reg [6:0] cycle_count; // for optional bound if needed
  reg [3:0] cur_edge_load; // iterator for loading edges
  reg [NODE_IDX_W-1:0] cur_node;
  reg [4:0] cur_adj_idx;
  reg [EDGE_IDX_W-1:0] cur_edge_idx;
  reg [2:0] fight_state;

  reg [2:0] state;
  localparam S_IDLE       = 3'd0;
  localparam S_BUILD_INIT = 3'd1;
  localparam S_BUILD_EDGES= 3'd2;
  localparam S_BUILD_ADJ  = 3'd3;
  localparam S_DFS_INIT   = 3'd4;
  localparam S_DFS_CHK    = 3'd5;
  localparam S_DFS_FIGHT  = 3'd6;
  localparam S_DONE       = 3'd7;

  // Fight calculation temporaries
  reg [15:0] fight_A;
  reg [15:0] fight_curH;
  reg [15:0] fight_enemy_a;
  reg [15:0] fight_enemy_h;
  reg [31:0] fight_tmp;
  reg [15:0] fight_rounds;
  reg [31:0] fight_damage;
  reg [15:0] fight_newH;
  reg        fight_ok;

  // Other
  reg [15:0] best_health;
  reg        found_path;
  reg [3:0]  depth;
  reg [NODE_IDX_W-1:0] target_node;

  integer i, j;

  // Combinational fight calculation from latched inputs (one-cycle result)
  // Uses current fight_* registers to compute fight_newH, fight_ok
  always @* begin
    fight_ok    = 1'b0;
    fight_newH  = 16'd0;
    if (fight_A != 16'd0) begin
      // rounds_needed = (enemy_h + A - 1) / A
      fight_tmp    = fight_enemy_h + fight_A - 16'd1;
      fight_rounds = fight_tmp / fight_A;
      if (fight_rounds == 16'd0)
        fight_rounds = 16'd1;
      // damage = (rounds_needed - 1) * enemy_a
      fight_damage = (fight_rounds - 16'd1) * fight_enemy_a;
      // remaining health
      if (fight_curH > fight_damage[15:0]) begin
        fight_newH = fight_curH - fight_damage[15:0];
        if (fight_newH >= 16'd1)
          fight_ok = 1'b1;
      end
    end
  end

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;
      oh_no       <= 1'b0;
      max_health  <= 16'd0;
      best_health <= 16'd0;
      found_path  <= 1'b0;
      cycle_count <= 7'd0;
      depth       <= 4'd0;
      visited     <= {MAX_NODES{1'b0}};
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        adj_count[i] <= 5'd0;
        for (j = 0; j < MAX_EDGES; j = j + 1) begin
          adj_edges[i][j] <= {EDGE_IDX_W{1'b0}};
        end
      end
    end else begin
      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          oh_no      <= 1'b0;
          best_health<= 16'd0;
          found_path <= 1'b0;
          cycle_count<= 7'd0;
          if (start) begin
            // Initialize adjacency
            for (i = 0; i < MAX_NODES; i = i + 1) begin
              adj_count[i] <= 5'd0;
            end
            cur_edge_load <= 4'd0;
            state         <= S_BUILD_EDGES;
          end
        end

        // Decode passages into edge arrays, one edge per cycle
        S_BUILD_EDGES: begin
          if (cur_edge_load < num_passages && cur_edge_load < MAX_EDGES[3:0]) begin
            // Packed format in 64 bits:
            // [63:60] from (3:0)
            // [59:56] to   (3:0)
            // [55:40] enemy_a (16)
            // [39:24] enemy_h (16)
            // The exact bit mapping wasn't fully specified; assume above.
            edge_from[cur_edge_load] <= passages[cur_edge_load][63:60];
            edge_to[cur_edge_load]   <= passages[cur_edge_load][59:56];
            edge_a[cur_edge_load]    <= passages[cur_edge_load][55:40];
            edge_h[cur_edge_load]    <= passages[cur_edge_load][39:24];
            cur_edge_load            <= cur_edge_load + 4'd1;
          end else begin
            // Build adjacency from edge arrays
            for (i = 0; i < MAX_NODES; i = i + 1) begin
              adj_count[i] <= 5'd0;
            end
            cur_edge_load <= 4'd0;
            state         <= S_BUILD_ADJ;
          end
        end

        // Build adjacency lists over multiple cycles
        S_BUILD_ADJ: begin
          if (cur_edge_load < num_passages && cur_edge_load < MAX_EDGES[3:0]) begin
            cur_node = edge_from[cur_edge_load];
            if (cur_node < MAX_NODES[2:0]) begin
              j = adj_count[cur_node];
              if (j < MAX_EDGES) begin
                adj_edges[cur_node][j] <= cur_edge_load;
                adj_count[cur_node]    <= j + 5'd1;
              end
            end
            cur_edge_load <= cur_edge_load + 4'd1;
          end else begin
            state <= S_DFS_INIT;
          end
        end

        // Initialize DFS
        S_DFS_INIT: begin
          target_node <= (num_nodes > 0) ? (num_nodes - 1) : 3'd0;
          depth       <= 4'd0;
          // Start at node 0 (area 1)
          stack_node[0]     <= {NODE_IDX_W{1'b0}};
          stack_health[0]   <= unnars_health;
          stack_edge_pos[0] <= {EDGE_IDX_W{1'b0}};
          visited           <= {MAX_NODES{1'b0}};
          visited[0]        <= 1'b1;
          best_health       <= 16'd0;
          found_path        <= 1'b0;
          cycle_count       <= 7'd0;
          state             <= S_DFS_CHK;
        end

        // DFS core: choose next edge or backtrack
        S_DFS_CHK: begin
          cycle_count <= cycle_count + 7'd1;
          // Safety bound (optional): if exceeded, terminate
          if (cycle_count >= 7'd100) begin
            state <= S_DONE;
          end else begin
            // If current node is target, record health and backtrack
            if (stack_node[depth] == target_node) begin
              if (stack_health[depth] > best_health) begin
                best_health <= stack_health[depth];
              end
              found_path <= 1'b1;
              // Backtrack one level
              if (depth == 4'd0) begin
                state <= S_DONE;
              end else begin
                visited[stack_node[depth]] <= 1'b0;
                depth <= depth - 4'd1;
                stack_edge_pos[depth] <= stack_edge_pos[depth] + 1'b1;
              end
            end else begin
              // Try next outgoing edge from this node
              cur_node    = stack_node[depth];
              cur_adj_idx = stack_edge_pos[depth];
              if (cur_adj_idx >= adj_count[cur_node]) begin
                // No more edges: backtrack
                if (depth == 4'd0) begin
                  state <= S_DONE;
                end else begin
                  visited[stack_node[depth]] <= 1'b0;
                  depth <= depth - 4'd1;
                  stack_edge_pos[depth] <= stack_edge_pos[depth] + 1'b1;
                end
              end else begin
                // Evaluate this edge via fight
                cur_edge_idx   = adj_edges[cur_node][cur_adj_idx];
                // Prepare fight inputs
                fight_A        <= unnars_attack;
                fight_curH     <= stack_health[depth];
                fight_enemy_a  <= edge_a[cur_edge_idx];
                fight_enemy_h  <= edge_h[cur_edge_idx];
                fight_state    <= 3'd0;
                state          <= S_DFS_FIGHT;
              end
            end
          end
        end

        // Fight state: use combinational block result next cycle
        S_DFS_FIGHT: begin
          // fight_* already set previous cycle, now use fight_ok/fight_newH
          if (fight_ok) begin
            // Determine destination node
            cur_node = edge_to[cur_edge_idx];
            // Check bounds and visited (simple path)
            if (cur_node < MAX_NODES[2:0] && visited[cur_node] == 1'b0) begin
              // Push to stack
              visited[cur_node]            <= 1'b1;
              depth                        <= depth + 4'd1;
              stack_node[depth + 4'd1]     <= cur_node;
              stack_health[depth + 4'd1]   <= fight_newH;
              stack_edge_pos[depth + 4'd1] <= {EDGE_IDX_W{1'b0}};
              // Stay in DFS loop
              state <= S_DFS_CHK;
            end else begin
              // Can't use this edge; try next
              stack_edge_pos[depth] <= stack_edge_pos[depth] + 1'b1;
              state                 <= S_DFS_CHK;
            end
          end else begin
            // Unsuccessful fight; try next edge on same node
            stack_edge_pos[depth] <= stack_edge_pos[depth] + 1'b1;
            state                 <= S_DFS_CHK;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          if (!found_path) begin
            oh_no      <= 1'b1;
            max_health <= 16'd0;
          end else begin
            oh_no      <= 1'b0;
            max_health <= best_health;
          end
          // Remain in DONE until next reset or start pulse (not auto-restart)
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule