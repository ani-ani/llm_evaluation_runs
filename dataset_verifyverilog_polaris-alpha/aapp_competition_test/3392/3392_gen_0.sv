module max_tree_group(
  input clk,
  input rst_n,
  input start,
  input [19:0] h_matrix [0:15],
  input [19:0] v_matrix [0:15],
  output reg [4:0] max_group_size,
  output reg done
);

  // State encoding
  localparam IDLE       = 3'd0;
  localparam PREP       = 3'd1;
  localparam BFS_INIT   = 3'd2;
  localparam BFS_EXPAND = 3'd3;
  localparam BFS_NEXT   = 3'd4;
  localparam WAIT_DONE  = 3'd5;

  reg [2:0] state, next_state;

  // Latency counter to enforce ~300 cycles max (not strictly required for function)
  reg [8:0] cycle_cnt; // up to 511

  // Storage for inputs (latched at start)
  reg [19:0] h_reg [0:15];
  reg [19:0] v_reg [0:15];

  // Adjacency matrix: 16x16 (only 4-neighbor connectivity)
  reg adj [0:15][0:15];

  // Indices and temporaries for adjacency computation
  reg [5:0] adj_idx;        // 0..31 => 32 undirected neighbor relations in 4x4 grid
  reg [3:0] u_idx, v_idx;   // node indices for current pair

  // BFS structures
  reg [3:0] src_node;       // current source node for component search
  reg [3:0] bfs_node;       // node under expansion
  reg [3:0] neigh_idx;      // neighbor index in [0..15]

  reg visited_global [0:15]; // visited across all components
  reg visited_comp   [0:15]; // visited in current component (for counting)

  reg [4:0] curr_comp_size;

  // Queue for BFS: size 16
  reg [3:0] q_mem [0:15];
  reg [4:0] q_head, q_tail; // 0..16
  reg [4:0] q_count;        // number of elements in queue

  integer i, j;

  // Helper: map linear neighbor pair index (0..31) to (u_idx, v_idx)
  // Predefined edges for 4x4 grid (4-neighbor, undirected):
  // Horizontal: (r,c)-(r,c+1) for r=0..3, c=0..2 (12 edges)
  // Vertical: (r,c)-(r+1,c) for r=0..2, c=0..3 (12 edges)
  // Total 24 unique undirected edges -> but we will treat as two directed in adjacency fill.
  // We'll encode 24 steps; remaining indices set no-ops.

  function automatic [7:0] edge_map_u_v(input [5:0] idx);
    reg [3:0] u_loc, v_loc;
    begin
      // First 12: horizontal
      if (idx < 12) begin
        // r = idx / 3, c = idx % 3
        // node = r*4 + c ; neighbor = r*4 + (c+1)
        u_loc = (idx / 3) * 4 + (idx % 3);
        v_loc = u_loc + 1;
      end
      // Next 12: vertical
      else if (idx < 24) begin
        // k = idx-12; r = k / 4; c = k % 4
        // node = r*4 + c ; neighbor = (r+1)*4 + c
        reg [5:0] k;
        reg [3:0] r, c;
        k = idx - 12;
        r = k / 4;
        c = k % 4;
        u_loc = r*4 + c;
        v_loc = (r+1)*4 + c;
      end else begin
        u_loc = 4'd0;
        v_loc = 4'd0;
      end
      edge_map_u_v = {u_loc, v_loc};
    end
  endfunction

  // Sequential state, counters, and main control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_cnt <= 9'd0;
      max_group_size <= 5'd0;
      done <= 1'b0;

      adj_idx <= 6'd0;
      u_idx <= 4'd0;
      v_idx <= 4'd0;

      src_node <= 4'd0;
      bfs_node <= 4'd0;
      neigh_idx <= 4'd0;

      curr_comp_size <= 5'd0;
      q_head <= 5'd0;
      q_tail <= 5'd0;
      q_count <= 5'd0;

      for (i = 0; i < 16; i = i + 1) begin
        h_reg[i] <= 20'd0;
        v_reg[i] <= 20'd0;
        visited_global[i] <= 1'b0;
        visited_comp[i] <= 1'b0;
        for (j = 0; j < 16; j = j + 1) begin
          adj[i][j] <= 1'b0;
        end
      end
    end else begin
      state <= next_state;

      // cycle counter for latency tracking
      if (state == IDLE) begin
        cycle_cnt <= 9'd0;
      end else begin
        cycle_cnt <= cycle_cnt + 9'd1;
      end

      case (state)
        IDLE: begin
          done <= 1'b0;
          max_group_size <= 5'd0;
          if (start) begin
            // latch inputs
            for (i = 0; i < 16; i = i + 1) begin
              h_reg[i] <= h_matrix[i];
              v_reg[i] <= v_matrix[i];
            end
            // clear adjacency & visited
            for (i = 0; i < 16; i = i + 1) begin
              visited_global[i] <= 1'b0;
              visited_comp[i] <= 1'b0;
              for (j = 0; j < 16; j = j + 1) begin
                adj[i][j] <= 1'b0;
              end
            end
            adj_idx <= 6'd0;
          end
        end

        PREP: begin
          // Build adjacency incrementally based on neighbor pairs
          // For each adjacency index, compute u_idx, v_idx, then link if they can reach equal height
          if (adj_idx < 6'd24) begin
            {u_idx, v_idx} = edge_map_u_v(adj_idx);

            // Retrieve parameters
            // h_i + v_i * t == h_j + v_j * t
            // (v_i == v_j && h_i == h_j) => always equal
            // else t = (h_j - h_i) / (v_i - v_j), must be integer, >=0
            // We'll compute using 21-bit signed

            // Local automatic regs via blocking assignments
            reg signed [20:0] h_i_s, h_j_s;
            reg signed [20:0] v_i_s, v_j_s;
            reg signed [21:0] dh;
            reg signed [21:0] dv;
            reg signed [42:0] num;
            reg signed [42:0] den;
            reg signed [42:0] t;
            reg can_connect;

            h_i_s = {1'b0, h_reg[u_idx]};
            h_j_s = {1'b0, h_reg[v_idx]};
            v_i_s = {1'b0, v_reg[u_idx]};
            v_j_s = {1'b0, v_reg[v_idx]};

            dh = h_j_s - h_i_s;
            dv = v_i_s - v_j_s;

            can_connect = 1'b0;

            if (v_i_s == v_j_s) begin
              if (h_i_s == h_j_s) begin
                can_connect = 1'b1;
              end
            end else begin
              // Check if signs allow non-negative t and dv != 0
              den = dv;
              num = dh;

              // Require num and den same sign and t >= 0 and integral
              if ((num != 0) && (den != 0)) begin
                if ((num[42] == den[42]) || (num == 0)) begin
                  // Compute t = num / den (trunc toward zero via signed division)
                  t = num / den;
                  if (t >= 0) begin
                    // Check exact divisibility: num == den * t
                    if (num == den * t) begin
                      can_connect = 1'b1;
                    end
                  end
                end
              end
            end

            if (can_connect) begin
              adj[u_idx][v_idx] <= 1'b1;
              adj[v_idx][u_idx] <= 1'b1;
            end

            adj_idx <= adj_idx + 6'd1;
          end
        end

        BFS_INIT: begin
          // Initialize for BFS from next unvisited node
          // src_node selected in next_state logic; here perform side effects
          // Clear component-local visited and queue
          for (i = 0; i < 16; i = i + 1) begin
            visited_comp[i] <= 1'b0;
          end

          q_head <= 5'd0;
          q_tail <= 5'd0;
          q_count <= 5'd0;

          // Enqueue src_node
          q_mem[0] <= src_node;
          q_tail <= 5'd1;
          q_count <= 5'd1;

          visited_global[src_node] <= 1'b1;
          visited_comp[src_node] <= 1'b1;
          curr_comp_size <= 5'd1;
          bfs_node <= 4'd0;
          neigh_idx <= 4'd0;
        end

        BFS_EXPAND: begin
          if (q_count != 0) begin
            // Dequeue if starting new node expansion
            if (neigh_idx == 4'd0) begin
              bfs_node <= q_mem[q_head];
              q_head <= q_head + 5'd1;
              q_count <= q_count - 5'd1;
            end

            // For current bfs_node, iterate neighbors sequentially (0..15)
            if (neigh_idx < 4'd16) begin
              if (adj[bfs_node][neigh_idx]) begin
                if (!visited_global[neigh_idx]) begin
                  visited_global[neigh_idx] <= 1'b1;
                  visited_comp[neigh_idx] <= 1'b1;
                  q_mem[q_tail] <= neigh_idx;
                  q_tail <= q_tail + 5'd1;
                  q_count <= q_count + 5'd1;
                  curr_comp_size <= curr_comp_size + 5'd1;
                end
              end
              neigh_idx <= neigh_idx + 4'd1;
            end else begin
              // Finished neighbors for this bfs_node; move to next node (if any)
              neigh_idx <= 4'd0;
            end
          end
        end

        BFS_NEXT: begin
          // Compare and update max_group_size for completed component
          if (curr_comp_size > max_group_size) begin
            max_group_size <= curr_comp_size;
          end
        end

        WAIT_DONE: begin
          // Assert done once processing finished; hold outputs stable
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = PREP;
        end
      end

      PREP: begin
        // Allow up to 50 cycles, but practically done when adj_idx >= 24
        if (adj_idx >= 6'd24) begin
          next_state = BFS_INIT;
        end
      end

      BFS_INIT: begin
        next_state = BFS_EXPAND;
      end

      BFS_EXPAND: begin
        // When queue empty and no neighbor scan in progress (neigh_idx == 0), component done
        if ((q_count == 0) && (neigh_idx == 0)) begin
          next_state = BFS_NEXT;
        end else begin
          next_state = BFS_EXPAND;
        end
      end

      BFS_NEXT: begin
        // Find next unvisited node; if none, go to WAIT_DONE
        // Combinational search
        reg found;
        reg [3:0] n;
        found = 1'b0;
        n = 4'd0;
        while (n < 4'd16 && !found) begin
          if (!visited_global[n]) begin
            found = 1'b1;
          end else begin
            n = n + 4'd1;
          end
        end

        if (found) begin
          next_state = BFS_INIT;
        end else begin
          next_state = WAIT_DONE;
        end
      end

      WAIT_DONE: begin
        // Stay done until start deasserted then reasserted; here just wait for new start
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Choose src_node combinationally for BFS_INIT based on visited_global
  always @(*) begin
    if (state == BFS_NEXT) begin
      // After finishing a component, pick next src_node
      reg found2;
      reg [3:0] k;
      found2 = 1'b0;
      src_node = 4'd0;
      k = 4'd0;
      while (k < 4'd16 && !found2) begin
        if (!visited_global[k]) begin
          src_node = k;
          found2 = 1'b1;
        end else begin
          k = k + 4'd1;
        end
      end
    end else if (state == PREP && adj_idx >= 6'd24) begin
      // First component source: first node (0)
      src_node = 4'd0;
    end
  end

endmodule