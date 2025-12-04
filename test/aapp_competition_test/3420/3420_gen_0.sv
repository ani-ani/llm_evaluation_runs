module book_presentations(
  input clk,          // system clock
  input rst_n,        // active-low reset
  input start,        // start computation
  input [15:0] bipartite_graph, // 4 boys x 4 girls (row-major: boy[3:0] x girl[3:0])
  output reg [2:0] max_matching, // matching size (0-4)
  output reg done      // result valid signal
);

  // Internal FSM states
  localparam S_IDLE          = 4'd0;
  localparam S_INIT          = 4'd1;
  localparam S_BFS_INIT      = 4'd2;
  localparam S_BFS_LAYER     = 4'd3;
  localparam S_BFS_SCAN_EDGE = 4'd4;
  localparam S_BFS_DONE      = 4'd5;
  localparam S_DFS_INIT      = 4'd6;
  localparam S_DFS_START     = 4'd7;
  localparam S_DFS_NEXT      = 4'd8;
  localparam S_DFS_RETURN    = 4'd9;
  localparam S_CHECK_AUG     = 4'd10;
  localparam S_DONE          = 4'd11;

  reg [3:0] state, next_state;

  // Matching arrays
  // pairU[u]: girl matched to boy u (0..3), 4 means NIL
  // pairV[v]: boy matched to girl v (0..3), 4 means NIL
  reg [2:0] pairU[0:3];
  reg [2:0] pairV[0:3];

  // Distances for BFS (Hopcroft-Karp layering)
  reg [2:0] dist[0:3];

  // NIL is encoded as 3'd4
  localparam [2:0] NIL = 3'd4;

  // Control variables
  reg [1:0] u_bfs;          // index for BFS over U
  reg [1:0] u_bfs_next;
  reg [1:0] v_bfs;          // index for scanning edges during BFS
  reg [1:0] u_curr;         // current boy in BFS edge scan

  reg       bfs_found_augmenting; // flag if we found free vertex in V

  // Queue for BFS (max 4 boys)
  reg [1:0] q[0:3];
  reg [1:0] q_head, q_tail;
  reg [2:0] q_count; // up to 4

  // DFS / augment variables
  reg [1:0] dfs_u;          // current boy in DFS
  reg [1:0] dfs_v;          // current girl index being tried
  reg [1:0] dfs_start_u;    // boy u for which DFS started
  reg [3:0] dfs_mask_u;     // visited flags for U in DFS (4 bits)
  reg [3:0] dfs_mask_v;     // visited flags for V in DFS (4 bits)
  reg       dfs_success;    // whether augmenting path found in DFS
  reg [2:0] augment_count;  // number of successful DFS augmentations in this phase

  // Timing constraint: must complete within 16 cycles
  reg [4:0] cycle_cnt;

  // Helper wires: read bipartite_graph bit for (u,v)
  function automatic bit edge_uv;
    input [1:0] fu;
    input [1:0] fv;
    begin
      edge_uv = bipartite_graph[{fu, fv}];
    end
  endfunction

  // Synchronous state and registers
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      max_matching <= 3'd0;
      done <= 1'b0;
      cycle_cnt <= 5'd0;
      for (i = 0; i < 4; i = i + 1) begin
        pairU[i] <= NIL;
        pairV[i] <= NIL;
        dist[i]  <= 3'd0;
      end
      u_bfs <= 2'd0;
      v_bfs <= 2'd0;
      u_curr <= 2'd0;
      bfs_found_augmenting <= 1'b0;
      q_head <= 2'd0;
      q_tail <= 2'd0;
      q_count <= 3'd0;
      dfs_u <= 2'd0;
      dfs_v <= 2'd0;
      dfs_start_u <= 2'd0;
      dfs_mask_u <= 4'b0000;
      dfs_mask_v <= 4'b0000;
      dfs_success <= 1'b0;
      augment_count <= 3'd0;
    end else begin
      state <= next_state;

      // cycle counter for timing constraint
      if (state == S_IDLE && !start) begin
        cycle_cnt <= 5'd0;
      end else if (state != S_DONE) begin
        cycle_cnt <= cycle_cnt + 5'd1;
      end

      // Main synchronous behavior by state
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            max_matching <= 3'd0;
            // reset matching to NIL
            for (i = 0; i < 4; i = i + 1) begin
              pairU[i] <= NIL;
              pairV[i] <= NIL;
            end
          end
        end

        S_INIT: begin
          done <= 1'b0;
          // Prepare for first BFS/DFS phase
          augment_count <= 3'd0;
        end

        // BFS initialization: set distances, build initial queue
        S_BFS_INIT: begin
          bfs_found_augmenting <= 1'b0;
          q_head <= 2'd0;
          q_tail <= 2'd0;
          q_count <= 3'd0;

          // Initialize dist[u]
          for (i = 0; i < 4; i = i + 1) begin
            if (pairU[i] == NIL) begin
              dist[i] <= 3'd0;
              q[q_tail] <= i[1:0];
              q_tail <= q_tail + 2'd1;
              q_count <= q_count + 3'd1;
            end else begin
              dist[i] <= 3'd7; // INF
            end
          end
        end

        // BFS layering main loop
        S_BFS_LAYER: begin
          if (q_count != 0) begin
            // dequeue u_curr
            u_curr <= q[q_head];
            q_head <= q_head + 2'd1;
            q_count <= q_count - 3'd1;
            v_bfs <= 2'd0;
          end
        end

        // Scan edges (u_curr, v_bfs)
        S_BFS_SCAN_EDGE: begin
          if (q_count == 0 && v_bfs == 2'd0) begin
            // no more nodes in queue and just entered: BFS will finish
          end

          if (edge_uv(u_curr, v_bfs)) begin
            if (pairV[v_bfs] == NIL) begin
              // found free girl -> there exists an augmenting path
              bfs_found_augmenting <= 1'b1;
            end else begin
              // if matched, try to add its pair boy to next layer
              if (dist[pairV[v_bfs]] == 3'd7) begin
                dist[pairV[v_bfs]] <= dist[u_curr] + 3'd1;
                q[q_tail] <= pairV[v_bfs][1:0];
                q_tail <= q_tail + 2'd1;
                q_count <= q_count + 3'd1;
              end
            end
          end

          // move to next girl
          v_bfs <= v_bfs + 2'd1;
        end

        S_BFS_DONE: begin
          // nothing extra; decision done in next_state logic
        end

        // DFS init over all free boys
        S_DFS_INIT: begin
          dfs_start_u <= 2'd0;
          augment_count <= 3'd0;
        end

        // Start DFS for a given free boy
        S_DFS_START: begin
          dfs_mask_u <= 4'b0000;
          dfs_mask_v <= 4'b0000;
          dfs_u <= dfs_start_u;
          dfs_v <= 2'd0;
          dfs_success <= 1'b0;
        end

        // DFS step: try edges (dfs_u, dfs_v)
        S_DFS_NEXT: begin
          if (!dfs_success) begin
            if (edge_uv(dfs_u, dfs_v) && !dfs_mask_v[dfs_v]) begin
              dfs_mask_v[dfs_v] <= 1'b1;
              if (pairV[dfs_v] == NIL || (dist[pairV[dfs_v]] == dist[dfs_u] + 3'd1 && !dfs_mask_u[pairV[dfs_v]])) begin
                if (pairV[dfs_v] != NIL) begin
                  dfs_mask_u[pairV[dfs_v]] <= 1'b1;
                end
                // Perform augmentation immediately (no deep recursion; small graph)
                pairU[dfs_u] <= dfs_v;
                pairV[dfs_v] <= dfs_u;
                dfs_success <= 1'b1;
              end
            end
            dfs_v <= dfs_v + 2'd1;
          end
        end

        // After DFS attempt for current free boy
        S_DFS_RETURN: begin
          if (dfs_success) begin
            augment_count <= augment_count + 3'd1;
          end
        end

        // Finalize phase: if augment_count == 0, we are done
        S_CHECK_AUG: begin
          // nothing extra here, handled by next_state
        end

        // Done: compute matching size and assert done for 1 cycle
        S_DONE: begin
          // Count matches on U side
          max_matching <= 3'd0;
          for (i = 0; i < 4; i = i + 1) begin
            if (pairU[i] != NIL)
              max_matching <= max_matching + 3'd1;
          end
          done <= 1'b1;
        end

        default: begin
        end
      endcase

      // Early termination if cycle constraint exceeded
      if (cycle_cnt >= 5'd15 && state != S_DONE) begin
        // Force transition to DONE next cycle via next_state logic
      end
    end
  end

  // Next-state combinational logic
  always @* begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_BFS_INIT;
      end

      S_BFS_INIT: begin
        next_state = S_BFS_LAYER;
      end

      S_BFS_LAYER: begin
        if (q_count != 0)
          next_state = S_BFS_SCAN_EDGE;
        else
          next_state = S_BFS_DONE;
      end

      S_BFS_SCAN_EDGE: begin
        if (v_bfs == 2'd3) begin
          // finished scanning all girls for current u_curr
          if (q_count != 0)
            next_state = S_BFS_LAYER;
          else
            next_state = S_BFS_DONE;
        end else begin
          next_state = S_BFS_SCAN_EDGE;
        end
      end

      S_BFS_DONE: begin
        if (!bfs_found_augmenting || (cycle_cnt >= 5'd15))
          next_state = S_DONE;
        else
          next_state = S_DFS_INIT;
      end

      S_DFS_INIT: begin
        if (dfs_start_u < 2'd4)
          next_state = S_DFS_START;
        else
          next_state = S_CHECK_AUG;
      end

      S_DFS_START: begin
        if (pairU[dfs_start_u] == NIL)
          next_state = S_DFS_NEXT;
        else begin
          // skip matched u
          if (dfs_start_u == 2'd3)
            next_state = S_CHECK_AUG;
          else
            next_state = S_DFS_INIT;
        end
      end

      S_DFS_NEXT: begin
        if (dfs_success || dfs_v == 2'd3)
          next_state = S_DFS_RETURN;
        else
          next_state = S_DFS_NEXT;
      end

      S_DFS_RETURN: begin
        if (dfs_start_u == 2'd3)
          next_state = S_CHECK_AUG;
        else
          next_state = S_DFS_INIT;
      end

      S_CHECK_AUG: begin
        if (augment_count == 3'd0 || (cycle_cnt >= 5'd15))
          next_state = S_DONE;
        else
          next_state = S_BFS_INIT;
      end

      S_DONE: begin
        // After signaling done for one cycle, go back to IDLE
        next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase

    // Enforce timing constraint fallback to DONE
    if (cycle_cnt >= 5'd15 && state != S_DONE)
      next_state = S_DONE;
  end

endmodule