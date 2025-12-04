module conveyor_scheduler (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [1:0] K,
  input [3:0] M,
  input [15:0][1:0] edges, // each entry: {a[2:0], b[2:0]}
  output reg [1:0] max_producers,
  output reg done
);

  // Parameters
  localparam MAX_NODES = 8;
  localparam MAX_PROD  = 4;
  localparam MAX_EDGE  = 16;
  localparam IDLE      = 3'd0;
  localparam FIND_PTHS = 3'd1;
  localparam CHK_CNFLT = 3'd2;
  localparam CALC_RSLT = 3'd3;
  localparam DONE_ST   = 3'd4;

  // Adjacency storage: [node][node] -> 1 bit
  reg [MAX_NODES*MAX_NODES-1:0] adj;

  // BFS per producer
  // frontier is one-hot over 8 nodes
  reg [MAX_NODES-1:0] frontier;
  reg [MAX_NODES-1:0] visited;
  // predecessor per node: 0..7, with 3'b111 meaning unset
  reg [2:0] prev_node [0:MAX_NODES-1];
  // predecessor edge index per node, 4 bits; 4'b1111 means unset
  reg [3:0] prev_edge [0:MAX_NODES-0];
  // path storage per producer: up to 8 nodes; 3'd7 = invalid marker
  reg [2:0] path_nodes [0:MAX_PROD-1][0:MAX_NODES-1];
  // path edges (belt indices) per producer: up to 7 steps; 4'b1111 = invalid
  reg [3:0] path_edges [0:MAX_PROD-1][0:MAX_NODES-2];

  // BFS control
  reg [3:0] bfs_steps;     // up to 8 steps
  reg [1:0] prod_idx;      // which producer [0..3]
  reg       bfs_valid;     // path found for current producer
  reg [2:0] prod_len;      // number of nodes in found path

  // Per producer validity and belt usage masks
  reg                valid [0:MAX_PROD-1];          // path found
  reg [MAX_EDGE-1:0] prod_mask [0:MAX_PROD-1];      // belts used (bits M-1..0)
  reg [3:0]          prod_belts [0:MAX_PROD-1];     // count of used belts

  // Conflict matrix (upper triangular): 6 bits for pairs among 4 producers
  reg [5:0] conflict; // bit t = 1 => conflict between (t/3,t%3) pairs

  // State machine
  reg [2:0] state, next_state;
  reg [5:0] cycle_cnt; // counts from 0..63 after start

  // Helpers
  integer i, j, k, u, v;
  function [MAX_NODES*MAX_NODES-1:0] idx1d;
    input [2:0] a;
    input [2:0] b;
    begin
      idx1d = a * MAX_NODES + b;
    end
  endfunction

  function [2:0] inc_mod3;
    input [2:0] x;
    begin
      inc_mod3 = (x + 1) % MAX_NODES;
    end
  endfunction

  // FSM state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Cycle counter (counts 0..63 from start)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 6'b0;
    end else begin
      if (state == IDLE) begin
        cycle_cnt <= 6'b0;
      end else if (start) begin
        cycle_cnt <= cycle_cnt + 1;
      end
    end
  end

  // Outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      max_producers <= 2'b0;
    end else begin
      if (state == DONE_ST) begin
        done <= 1'b1;
        // Compute maximal non-conflicting subset
        // Brute-force over all subsets (up to 4 producers)
        // bit j in result means producer j is selected
        reg [3:0] best_set;
        reg [1:0] best_cnt;
        best_set = 4'b0;
        best_cnt = 2'b0;
        for (j = 0; j < (1<<MAX_PROD); j = j + 1) begin
          reg ok;
          reg [1:0] cnt;
          ok = 1'b1;
          cnt = 2'b0;
          for (u = 0; u < MAX_PROD; u = u + 1) begin
            if (j[u]) begin
              cnt = cnt + 1;
              // Pairwise conflict check using precomputed 'conflict'
              for (v = u+1; v < MAX_PROD; v = v + 1) begin
                if (j[v]) begin
                  if ( ( (u==0 && v==1) || (u==1 && v==0) ) && conflict[0] ) ok = 1'b0;
                  if ( ( (u==0 && v==2) || (u==2 && v==0) ) && conflict[1] ) ok = 1'b0;
                  if ( ( (u==0 && v==3) || (u==3 && v==0) ) && conflict[2] ) ok = 1'b0;
                  if ( ( (u==1 && v==2) || (u==2 && v==1) ) && conflict[3] ) ok = 1'b0;
                  if ( ( (u==1 && v==3) || (u==3 && v==1) ) && conflict[4] ) ok = 1'b0;
                  if ( ( (u==2 && v==3) || (u==3 && v==2) ) && conflict[5] ) ok = 1'b0;
                end
              end
            end
          end
          if (ok && (cnt > best_cnt)) begin
            best_cnt = cnt;
            best_set = j[3:0];
          end
        end
        // If best_cnt is zero, best_set is 0 (already init)
        max_producers <= best_cnt;
      end else begin
        done <= 1'b0;
      end
    end
  end

  // FSM transitions and datapath
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = FIND_PTHS;
      end
      FIND_PTHS: begin
        // Finish after K producers processed
        if (&prod_idx) next_state = CHK_CNFLT;
      end
      CHK_CNFLT: begin
        next_state = CALC_RSLT;
      end
      CALC_RSLT: begin
        // Allow one cycle for calculation
        next_state = DONE_ST;
      end
      DONE_ST: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end end

  // Per-cycle datapath in FIND_PTHS
  always @(posedge clk) begin
    if (state == IDLE) begin
      // Clear adjacency, producers, BFS state
      adj <= {MAX_NODES*MAX_NODES{1'b0}};
      for (i = 0; i < MAX_PROD; i = i + 1) begin
        valid[i] <= 1'b0;
        prod_mask[i] <= {MAX_EDGE{1'b0}};
        prod_belts[i] <= 4'b0;
        for (j = 0; j < MAX_NODES; j = j + 1) begin
          path_nodes[i][j] <= 3'd7; // invalid marker
          path_edges[i][j] <= 4'b1111; // invalid marker
        end
      end
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        prev_node[i] <= 3'd7;
        prev_edge[i] <= 4'b1111;
      end
      frontier <= 8'b0;
      visited  <= 8'b0;
      bfs_steps <= 4'b0;
      prod_idx <= 2'b0;
      bfs_valid <= 1'b0;
      prod_len <= 3'd0;
    end else if (state == FIND_PTHS) begin
      if (prod_idx == 2'b0) begin
        // First producer: rebuild adjacency from input edges
        adj <= {MAX_NODES*MAX_NODES{1'b0}};
        for (j = 0; j < M; j = j + 1) begin
          // Cast to 6-bit to avoid indexing issues
          v = $unsigned({1'b0, edges[j]});
          u = v % 8;        // a[2:0]
          v = v / 8;        // b[2:0]
          adj[idx1d(u[2:0], v[2:0])] <= 1'b1;
          adj[idx1d(v[2:0], u[2:0])] <= 1'b1; // undirected
        end
        // Clear per-producer storage for this pass
        for (i = 0; i < MAX_PROD; i = i + 1) begin
          valid[i] <= 1'b0;
          prod_mask[i] <= {MAX_EDGE{1'b0}};
          prod_belts[i] <= 4'b0;
          for (k = 0; k < MAX_NODES; k = k + 1) begin
            path_nodes[i][k] <= 3'd7;
            path_edges[i][k] <= 4'b1111;
          end
        end
      end

      // BFS for current producer
      if (bfs_steps == 4'd0) begin
        // Init BFS: source is junction (prod_idx+1)
        frontier <= (1 << (prod_idx + 1));
        visited  <= 8'b0;
        for (i = 0; i < MAX_NODES; i = i + 1) begin
          prev_node[i] <= 3'd7;
          prev_edge[i] <= 4'b1111;
        end
        bfs_valid <= 1'b0;
        prod_len  <= 3'd0;
      end else if (bfs_steps < 4'd8) begin
        // Expand one level
        reg [MAX_NODES-1:0] new_front;
        new_front = 8'b0;
        for (u = 0; u < MAX_NODES; u = u + 1) begin
          if (frontier[u]) begin
            for (v = 0; v < MAX_NODES; v = v + 1) begin
              if (adj[idx1d(u, v)] && !visited[v]) begin
                new_front[v] = 1'b1;
                prev_node[v] <= u[2:0];
                // Find edge index between u-v
                for (k = 0; k < M; k = k + 1) begin
                  if (k < 16) begin
                    reg [5:0] e6;
                    reg [2:0] a, b;
                    e6 = $unsigned({1'b0, edges[k]});
                    a = e6[2:0];
                    b = e6[5:3];
                    if ( (a == u && b == v) || (a == v && b == u) ) begin
                      prev_edge[v] <= k[3:0];
                    end
                  end
                end
              end
            end
            visited[v] = 1'b1;
          end
        end
        frontier <= new_front;
      end else if (bfs_steps == 4'd8) begin
        // Reconstruct if target N reached
        if (visited[N]) begin
          bfs_valid <= 1'b1;
          // Collect nodes and edges along path
          reg [2:0] cur;
          reg [2:0] plen;
          cur = N;
          plen = 3'd0;
          for (i = 0; i < MAX_NODES; i = i + 1) begin
            path_nodes[prod_idx][i] <= 3'd7;
            path_edges[prod_idx][i] <= 4'b1111;
          end
          while (cur != 3'd7) begin
            path_nodes[prod_idx][plen] <= cur;
            if (plen > 3'd0) begin
              // the edge used to arrive at 'cur'
              path_edges[prod_idx][plen-1] <= prev_edge[cur];
            end
            cur = prev_node[cur];
            plen = plen + 1;
          end
          // reverse path to start->target
          for (i = 0; i < (MAX_NODES/2); i = i + 1) begin
            reg [2:0] tmp;
            tmp = path_nodes[prod_idx][i];
            path_nodes[prod_idx][i] <= path_nodes[prod_idx][plen-1-i];
            path_nodes[prod_idx][plen-1-i] <= tmp;
          end
          // also reverse edges (in place swap)
          for (i = 0; i < (MAX_NODES-2)/2; i = i + 1) begin
            reg [3:0] tmp_e;
            tmp_e = path_edges[prod_idx][i];
            path_edges[prod_idx][i] <= path_edges[prod_idx][plen-2-i];
            path_edges[prod_idx][plen-2-i] <= tmp_e;
          end
          prod_len <= plen;
        end else begin
          bfs_valid <= 1'b0;
        end
      end else if (bfs_steps == 4'd9) begin
        // Store per-producer results
        valid[prod_idx] <= bfs_valid;
        if (bfs_valid) begin
          reg [3:0] belt_cnt;
          belt_cnt = 4'b0;
          // Build belt usage mask from path_edges
          for (i = 0; i < MAX_NODES-1; i = i + 1) begin
            if (i < prod_len-1) begin
              reg [3:0] eidx;
              eidx = path_edges[prod_idx][i];
              if (eidx < M) begin
                prod_mask[prod_idx][eidx] <= 1'b1;
                belt_cnt <= belt_cnt + 1;
              end
            end
          end
          prod_belts[prod_idx] <= belt_cnt;
        end else begin
          prod_mask[prod_idx] <= {MAX_EDGE{1'b0}};
          prod_belts[prod_idx] <= 4'b0;
        end
      end else if (bfs_steps == 4'd10) begin
        // Next producer
        prod_idx <= prod_idx + 1;
      end

      // Advance steps; hold when done producers
      if (bfs_steps < 4'd10) begin
        bfs_steps <= bfs_steps + 1;
      end else begin
        bfs_steps <= ((&prod_idx) ? 4'd10 : 4'd0);
      end
    end else if (state == CHK_CNFLT) begin
      // Precompute conflict matrix among up to 4 producers
      conflict <= 6'b0;
      // pairs: (0,1) bit0, (0,2) bit1, (0,3) bit2, (1,2) bit3, (1,3) bit4, (2,3) bit5
      // (0,1)
      if (valid[0] && valid[1]) begin
        for (u = 0; u < MAX_EDGE; u = u + 1) begin
          if (prod_mask[0][u] && prod_mask[1][u]) begin
            conflict[0] <= 1'b1;
          end
        end
      end
      // (0,2)
      if (valid[0] && valid[2]) begin
        for (u = 0; u < MAX_EDGE; u = u + 1) begin
          if (prod_mask[0][u] && prod_mask[2][u]) begin
            conflict[1] <= 1'b1;
          end
        end
      end
      // (0,3)
      if (valid[0] && valid[3]) begin
        for (u = 0; u < MAX_EDGE; u = u + 1) begin
          if (prod_mask[0][u] && prod_mask[3][u]) begin
            conflict[2] <= 1'b1;
          end
        end
      end
      // (1,2)
      if (valid[1] && valid[2]) begin
        for (u = 0; u < MAX_EDGE; u = u + 1) begin
          if (prod_mask[1][u] && prod_mask[2][u]) begin
            conflict[3] <= 1'b1;
          end
        end
      end
      // (1,3)
      if (valid[1] && valid[3]) begin
        for (u = 0; u < MAX_EDGE; u = u + 1) begin
          if (prod_mask[1][u] && prod_mask[3][u]) begin
            conflict[4] <= 1'b1;
          end
        end
      end
      // (2,3)
      if (valid[2] && valid[3]) begin
        for (u = 0; u < MAX_EDGE; u = u + 1) begin
          if (prod_mask[2][u] && prod_mask[3][u]) begin
            conflict[5] <= 1'b1;
          end
        end
      end
    end
    // CALC_RSLT and DONE states are handled by the always block for outputs
  end

endmodule
