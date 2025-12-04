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

  // Parameters
  localparam MAX_NODES   = 8;
  localparam MAX_EDGES   = 16;
  localparam IDX_W       = 3;      // log2(MAX_NODES)
  localparam CAP_W       = 16;
  localparam RES_W       = 20;     // internal residual capacity width
  localparam COUNT_W     = 8;      // up to 256 cycles, generic counter

  // FSM states
  localparam S_IDLE          = 4'd0;
  localparam S_INIT_CLEAR    = 4'd1;
  localparam S_INIT_LOAD     = 4'd2;
  localparam S_BFS_INIT      = 4'd3;
  localparam S_BFS_POP       = 4'd4;
  localparam S_BFS_SCAN      = 4'd5;
  localparam S_BFS_CHECK     = 4'd6;
  localparam S_AUG_TRACE     = 4'd7;
  localparam S_AUG_UPDATE    = 4'd8;
  localparam S_DONE          = 4'd9;

  reg [3:0] state, next_state;

  // Residual capacity matrix: res[u][v]
  reg [RES_W-1:0] res [0:MAX_NODES-1][0:MAX_NODES-1];

  // Indices for init clear and load
  reg [IDX_W-1:0] init_u;
  reg [IDX_W-1:0] init_v;
  reg [3:0]       init_edge_idx;

  // BFS structures
  reg [IDX_W-1:0] source;
  reg [IDX_W-1:0] sink;

  reg             visited [0:MAX_NODES-1];
  reg [IDX_W-1:0] parent  [0:MAX_NODES-1];

  // BFS queue
  reg [IDX_W-1:0] queue [0:MAX_NODES-1];
  reg [IDX_W:0]   q_head;
  reg [IDX_W:0]   q_tail;

  reg [IDX_W-1:0] bfs_u;         // current node popped from queue
  reg [IDX_W-1:0] scan_v;        // neighbor index during scan

  reg             path_found;

  // Augmentation
  reg [RES_W-1:0] path_min;
  reg [IDX_W-1:0] aug_v;
  reg [IDX_W-1:0] aug_u;

  reg [RES_W-1:0] total_flow;    // internal 20-bit total flow

  // Cycle limit to ensure completion within 256 cycles max (best-effort)
  reg [COUNT_W-1:0] cycle_cnt;

  integer i, j;

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT_CLEAR;
      end

      S_INIT_CLEAR: begin
        // advance until all res[u][v] cleared
        if (init_u == MAX_NODES-1 && init_v == MAX_NODES-1)
          next_state = S_INIT_LOAD;
      end

      S_INIT_LOAD: begin
        // after loading all edges, start BFS for first augmenting path
        if (init_edge_idx == edge_count)
          next_state = S_BFS_INIT;
      end

      S_BFS_INIT: begin
        next_state = S_BFS_POP;
      end

      S_BFS_POP: begin
        // if queue empty -> no path
        if (q_head == q_tail) begin
          next_state = S_DONE;
        end else begin
          next_state = S_BFS_SCAN;
        end
      end

      S_BFS_SCAN: begin
        // when finished scanning all v for current u
        if (scan_v == node_count[2:0])
          next_state = S_BFS_CHECK;
      end

      S_BFS_CHECK: begin
        if (path_found)
          next_state = S_AUG_TRACE;
        else
          next_state = S_BFS_POP;
      end

      S_AUG_TRACE: begin
        // when we reach source in backtracking
        if (aug_v == source)
          next_state = S_AUG_UPDATE;
      end

      S_AUG_UPDATE: begin
        // after updating residuals from sink to source, try new BFS
        next_state = S_BFS_INIT;
      end

      S_DONE: begin
        // remain done until new start or reset
        if (start)
          next_state = S_INIT_CLEAR;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase

    // safety: force done if cycle limit exceeded
    if (state != S_IDLE && state != S_DONE) begin
      if (cycle_cnt == 8'd255)
        next_state = S_DONE;
    end
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;
      flow        <= 16'd0;
      total_flow  <= {RES_W{1'b0}};
      cycle_cnt   <= {COUNT_W{1'b0}};

      init_u      <= {IDX_W{1'b0}};
      init_v      <= {IDX_W{1'b0}};
      init_edge_idx <= 4'd0;

      source      <= {IDX_W{1'b0}};
      sink        <= {IDX_W{1'b0}};

      q_head      <= { (IDX_W+1){1'b0} };
      q_tail      <= { (IDX_W+1){1'b0} };
      bfs_u       <= {IDX_W{1'b0}};
      scan_v      <= {IDX_W{1'b0}};
      path_found  <= 1'b0;
      path_min    <= {RES_W{1'b0}};
      aug_v       <= {IDX_W{1'b0}};
      aug_u       <= {IDX_W{1'b0}};

      // clear arrays
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        visited[i] <= 1'b0;
        parent[i]  <= {IDX_W{1'b0}};
        for (j = 0; j < MAX_NODES; j = j + 1) begin
          res[i][j] <= {RES_W{1'b0}};
        end
        queue[i]   <= {IDX_W{1'b0}};
      end

    end else begin
      state <= next_state;

      // cycle counter for safety bound
      if (state == S_IDLE && !start) begin
        cycle_cnt <= 8'd0;
      end else if (state != S_DONE) begin
        cycle_cnt <= cycle_cnt + 1'b1;
      end

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          // flow holds previous until new computation starts
          if (start) begin
            total_flow <= {RES_W{1'b0}};
            init_u     <= {IDX_W{1'b0}};
            init_v     <= {IDX_W{1'b0}};
            init_edge_idx <= 4'd0;
            // assume source = 0, sink = node_count-1
            source <= {IDX_W{1'b0}};
            sink   <= (node_count == 0) ? {IDX_W{1'b0}} : (node_count - 1'b1);
          end
        end

        S_INIT_CLEAR: begin
          // clear residual matrix sequentially
          res[init_u][init_v] <= {RES_W{1'b0}};
          // advance indices
          if (init_v == MAX_NODES-1) begin
            init_v <= {IDX_W{1'b0}};
            if (init_u == MAX_NODES-1) begin
              init_u <= init_u; // done; wait for state transition
            end else begin
              init_u <= init_u + 1'b1;
            end
          end else begin
            init_v <= init_v + 1'b1;
          end

          // also clear BFS-related state
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            visited[i] <= 1'b0;
            parent[i]  <= {IDX_W{1'b0}};
            queue[i]   <= {IDX_W{1'b0}};
          end
          q_head     <= { (IDX_W+1){1'b0} };
          q_tail     <= { (IDX_W+1){1'b0} };
          path_found <= 1'b0;
        end

        S_INIT_LOAD: begin
          // load directed edges into residual matrix
          if (init_edge_idx < edge_count) begin
            // edges[i]: [47:45] u, [44:42] v, [41:26] cap (16 bits), remaining bits ignored
            // Align with spec: 3b u, 3b v, 16b cap; others don't care
            // Extract
            // u in [47:45], v in [44:42], cap in [41:26]
            // Cap is 16 bits; extend to RES_W
            reg [2:0] u_idx;
            reg [2:0] v_idx;
            reg [15:0] cap_val;
            u_idx   = edges[init_edge_idx][47:45];
            v_idx   = edges[init_edge_idx][44:42];
            cap_val = edges[init_edge_idx][41:26];
            if (u_idx < MAX_NODES && v_idx < MAX_NODES) begin
              res[u_idx][v_idx] <= res[u_idx][v_idx] + {{(RES_W-CAP_W){1'b0}}, cap_val};
            end
            init_edge_idx <= init_edge_idx + 1'b1;
          end
        end

        S_BFS_INIT: begin
          // initialize BFS for new augmenting path search
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            visited[i] <= 1'b0;
            parent[i]  <= {IDX_W{1'b0}};
            queue[i]   <= {IDX_W{1'b0}};
          end
          q_head            <= { (IDX_W+1){1'b0} };
          q_tail            <= { (IDX_W+1){1'b0} };
          // enqueue source
          queue[0]          <= source;
          q_head            <= 0;
          q_tail            <= 1;
          visited[source]   <= 1'b1;
          parent[source]    <= source;
          path_found        <= 1'b0;
          bfs_u             <= {IDX_W{1'b0}};
          scan_v            <= {IDX_W{1'b0}};
        end

        S_BFS_POP: begin
          path_found <= 1'b0;
          if (q_head != q_tail) begin
            bfs_u  <= queue[q_head[IDX_W-1:0]];
            q_head <= q_head + 1'b1;
            scan_v <= {IDX_W{1'b0}};
          end
        end

        S_BFS_SCAN: begin
          if (scan_v < node_count) begin
            if (!visited[scan_v] && res[bfs_u][scan_v] > 0) begin
              visited[scan_v] <= 1'b1;
              parent[scan_v]  <= bfs_u;
              queue[q_tail[IDX_W-1:0]] <= scan_v;
              q_tail <= q_tail + 1'b1;
              if (scan_v == sink) begin
                path_found <= 1'b1;
              end
            end
            scan_v <= scan_v + 1'b1;
          end
        end

        S_BFS_CHECK: begin
          // nothing extra; next_state reacts to path_found
        end

        S_AUG_TRACE: begin
          // determine bottleneck capacity along found path
          if (aug_v == {IDX_W{1'b0}} && !path_found) begin
            // first cycle in this state: init
            aug_v    <= sink;
            path_min <= {RES_W{1'b1}}; // large value
          end else begin
            aug_u <= parent[aug_v];
            if (res[parent[aug_v]][aug_v] < path_min)
              path_min <= res[parent[aug_v]][aug_v];
            if (parent[aug_v] == source) begin
              aug_v <= source; // triggers transition next cycle
            end else begin
              aug_v <= parent[aug_v];
            end
          end
        end

        S_AUG_UPDATE: begin
          // apply bottleneck to residual graph along path
          // walk again from sink to source
          reg [IDX_W-1:0] v_tmp;
          reg [IDX_W-1:0] u_tmp;
          v_tmp = sink;
          while (v_tmp != source) begin
            u_tmp = parent[v_tmp];
            res[u_tmp][v_tmp] <= res[u_tmp][v_tmp] - path_min;
            res[v_tmp][u_tmp] <= res[v_tmp][u_tmp] + path_min;
            v_tmp = u_tmp;
          end
          // update total flow
          total_flow <= total_flow + path_min;
        end

        S_DONE: begin
          done <= 1'b1;
          // saturate to 16-bit for output
          if (total_flow[RES_W-1:16] != 0)
            flow <= 16'hFFFF;
          else
            flow <= total_flow[15:0];
        end

        default: begin
        end
      endcase

      // Re-init aug trace flags at state entry
      if (state != S_AUG_TRACE && next_state == S_AUG_TRACE) begin
        aug_v      <= sink;
        path_min   <= {RES_W{1'b1}};
        path_found <= 1'b1; // indicates valid path in trace
      end

    end
  end

endmodule
