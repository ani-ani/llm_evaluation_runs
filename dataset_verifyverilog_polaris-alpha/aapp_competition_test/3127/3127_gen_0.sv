module network_switch_analyzer(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] n,
  input  [3:0] m,
  input  [2:0] edges [0:15][0:2],
  input  [15:0] len_low [0:15],
  output reg [7:0] unused_mask,
  output reg done
);

  // Internal constants
  localparam MAX_N = 8;
  localparam INF   = 24'hFF_FFFF;

  // Internal storage for inputs
  reg [2:0]  n_reg;
  reg [3:0]  m_reg;
  reg [2:0]  edges_a   [0:15];
  reg [2:0]  edges_b   [0:15];
  reg [2:0]  edges_h   [0:15];
  reg [15:0] len_low_reg [0:15];

  // Adjacency matrix: 1-based nodes mapped to 0..7 index
  reg [23:0] adj [0:7][0:7];

  // Distance and predecessor for Dijkstra from node 1 (index 0)
  reg [23:0] dist [0:7];
  reg [2:0]  parent [0:7];
  reg        used_in_path [0:7];

  // Control FSM
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_LOAD      = 3'd1,
    S_BUILD_ADJ = 3'd2,
    S_RUN_DIJK  = 3'd3,
    S_MARK      = 3'd4,
    S_WAIT_LAT  = 3'd5,
    S_DONE      = 3'd6
  } state_t;

  state_t state, next_state;

  // Counters and indices
  reg [7:0]  cycle_cnt;
  reg [3:0]  idx_m;
  reg [2:0]  i_node;
  reg [2:0]  j_node;
  reg [2:0]  d_step;
  reg [2:0]  u_sel;
  reg [23:0] u_min;
  reg        u_found;

  // Latency target: done 256 cycles after start.
  // We enforce this via cycle_cnt and S_WAIT_LAT.

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      cycle_cnt   <= 8'd0;
      n_reg       <= 3'd0;
      m_reg       <= 4'd0;
      unused_mask <= 8'd0;
      done        <= 1'b0;
      idx_m       <= 4'd0;
      i_node      <= 3'd0;
      j_node      <= 3'd0;
      d_step      <= 3'd0;
      u_sel       <= 3'd0;
      u_min       <= INF;
      u_found     <= 1'b0;
    end else begin
      state     <= next_state;

      // Global cycle counter: starts at start assertion
      if (state == S_IDLE && start) begin
        cycle_cnt <= 8'd0;
      end else if (state != S_IDLE) begin
        cycle_cnt <= cycle_cnt + 8'd1;
      end

      case (state)
        S_IDLE: begin
          done        <= 1'b0;
          unused_mask <= 8'd0;
        end

        // Latch inputs and initialize
        S_LOAD: begin
          // Store n and m (limit range internally)
          n_reg <= (n < 3'd2) ? 3'd2 : ((n > 3'd8) ? 3'd8 : n);
          m_reg <= (m > 4'd16) ? 4'd16 : m;

          // Latch edges and len_low
          idx_m <= 4'd0;
          while (idx_m < 4'd16) begin
            edges_a[idx_m]    <= edges[idx_m][0];
            edges_b[idx_m]    <= edges[idx_m][1];
            edges_h[idx_m]    <= edges[idx_m][2];
            len_low_reg[idx_m]<= len_low[idx_m];
            idx_m             <= idx_m + 4'd1;
          end

          // Initialize adjacency matrix to INF and 0 on diagonal
          i_node <= 3'd0;
          j_node <= 3'd0;
        end

        // Build adjacency: clear and then program edges
        S_BUILD_ADJ: begin
          // First clear/set base adjacency
          if (i_node < MAX_N) begin
            if (j_node < MAX_N) begin
              if (i_node == j_node)
                adj[i_node][j_node] <= 24'd0;
              else
                adj[i_node][j_node] <= INF;
              j_node <= j_node + 3'd1;
            end else begin
              j_node <= 3'd0;
              i_node <= i_node + 3'd1;
            end
          end
          // After clearing, program the first m_reg edges sequentially
          if (idx_m < m_reg) begin
            // Map 1-8 nodes (a,b) to 0-7 indices, ignore out-of-range
            if (edges_a[idx_m] != 3'd0 && edges_b[idx_m] != 3'd0 &&
                edges_a[idx_m] <= MAX_N[2:0] && edges_b[idx_m] <= MAX_N[2:0]) begin
              // indices
              // note: a,b are 1-based in spec
              // form 24-bit length = {len_high(3b), len_low(16b)} left aligned (?)
              // Problem statement: {len_high, len_low}; total 3+16=19, but says 24-bit.
              // We'll place len_high in top 3 bits and len_low in low 16, pad middle with zeros.
              // len24 = {len_high, 5'b0, len_low}
              // This is a consistent deterministic encoding.
              reg [23:0] w;
              w = {edges_h[idx_m], 5'b0, len_low_reg[idx_m]};
              if (w < adj[edges_a[idx_m]-1][edges_b[idx_m]-1])
                adj[edges_a[idx_m]-1][edges_b[idx_m]-1] <= w;
              if (w < adj[edges_b[idx_m]-1][edges_a[idx_m]-1])
                adj[edges_b[idx_m]-1][edges_a[idx_m]-1] <= w;
            end
            idx_m <= idx_m + 4'd1;
          end

          // Initialize Dijkstra-related data when entering this state (first cycles)
          if (cycle_cnt == 8'd1) begin
            // Initialize distances and parents and used flags
            for (i_node = 0; i_node < MAX_N; i_node = i_node + 1) begin
              dist[i_node]        <= INF;
              parent[i_node]      <= 3'd7; // invalid parent
              used_in_path[i_node]<= 1'b0;
            end
            // Source is node 1 -> index 0
            dist[0]   <= 24'd0;
            parent[0] <= 3'd7;
            d_step    <= 3'd0;
          end
        end

        // Run Dijkstra from node 1 for up to n_reg-1 iterations
        S_RUN_DIJK: begin
          // 1) Select next unvisited node u with minimal dist
          u_min   <= INF;
          u_sel   <= 3'd7;
          u_found <= 1'b0;
          for (i_node = 0; i_node < MAX_N; i_node = i_node + 1) begin
            if (i_node < n_reg) begin
              if (!used_in_path[i_node] && dist[i_node] < u_min) begin
                u_min   <= dist[i_node];
                u_sel   <= i_node[2:0];
                u_found <= 1'b1;
              end
            end
          end

          if (u_found && u_sel != 3'd7) begin
            // mark as visited
            used_in_path[u_sel] <= 1'b1;
            // 2) Relax edges from u_sel
            for (j_node = 0; j_node < MAX_N; j_node = j_node + 1) begin
              if (j_node < n_reg) begin
                if (adj[u_sel][j_node] != INF) begin
                  if (dist[u_sel] + adj[u_sel][j_node] < dist[j_node]) begin
                    dist[j_node]   <= dist[u_sel] + adj[u_sel][j_node];
                    parent[j_node] <= u_sel[2:0];
                  end
                end
              end
            end
          end

          // Step counter for up to n_reg iterations
          if (d_step < n_reg - 1) begin
            d_step <= d_step + 3'd1;
          end
        end

        // Mark nodes that are on any minimal path from 1 to any reachable node
        S_MARK: begin
          // First clear usage
          for (i_node = 0; i_node < MAX_N; i_node = i_node + 1) begin
            used_in_path[i_node] <= 1'b0;
          end

          // For each node v (1..n_reg-1), backtrack parent chain to source
          for (i_node = 1; i_node < MAX_N; i_node = i_node + 1) begin
            if (i_node < n_reg && dist[i_node] != INF) begin
              // backtrack from i_node
              reg [2:0] cur;
              cur = i_node[2:0];
              while (cur != 3'd7 && cur < n_reg) begin
                used_in_path[cur] <= 1'b1;
                if (cur == 3'd0) begin
                  cur = 3'd7; // reached source, terminate
                end else begin
                  cur = parent[cur];
                end
              end
            end
          end

          // Source node (0) is always on its own minimal path
          used_in_path[0] <= 1'b1;

          // Build unused_mask: 1 = never used
          for (i_node = 0; i_node < MAX_N; i_node = i_node + 1) begin
            if (i_node < n_reg) begin
              unused_mask[i_node] <= ~used_in_path[i_node];
            end else begin
              unused_mask[i_node] <= 1'b1; // nodes beyond n treated as unused
            end
          end
        end

        // Wait until 256 cycles have elapsed from start
        S_WAIT_LAT: begin
          if (cycle_cnt >= 8'd255) begin
            done <= 1'b1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_LOAD;
      end
      S_LOAD: begin
        next_state = S_BUILD_ADJ;
      end
      S_BUILD_ADJ: begin
        // After adjacency built and inputs latched, move to Dijkstra
        if (cycle_cnt > 8'd10) begin
          next_state = S_RUN_DIJK;
        end
      end
      S_RUN_DIJK: begin
        // Enough iterations for max 8 nodes
        if (d_step >= (MAX_N-1)) begin
          next_state = S_MARK;
        end
      end
      S_MARK: begin
        next_state = S_WAIT_LAT;
      end
      S_WAIT_LAT: begin
        if (cycle_cnt >= 8'd255) next_state = S_DONE;
      end
      S_DONE: begin
        // Hold done high until new start (optional: go idle when start deasserted)
        if (!start) next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

endmodule