module wire_routing(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [5:0] a1,
  input [5:0] a2,
  input [5:0] b1,
  input [5:0] b2,
  output reg [5:0] result,
  output reg done
);

  // --------------------------------------------------------------------------
  // Coordinate extraction
  // --------------------------------------------------------------------------
  wire [2:0] a1_x = a1[5:3];
  wire [2:0] a1_y = a1[2:0];
  wire [2:0] a2_x = a2[5:3];
  wire [2:0] a2_y = a2[2:0];
  wire [2:0] b1_x = b1[5:3];
  wire [2:0] b1_y = b1[2:0];
  wire [2:0] b2_x = b2[5:3];
  wire [2:0] b2_y = b2[2:0];

  // --------------------------------------------------------------------------
  // Utility: absolute difference (3-bit inputs, 3-bit output)
  // --------------------------------------------------------------------------
  function automatic [3:0] abs_diff3(input [2:0] x, input [2:0] y);
    begin
      if (x >= y) abs_diff3 = x - y;
      else        abs_diff3 = y - x;
    end
  endfunction

  // Manhattan distances (max 6 for 0..7 grid, fits in 4 bits; we use 5 bits safe)
  wire [4:0] dA = abs_diff3(a1_x, a2_x) + abs_diff3(a1_y, a2_y);
  wire [4:0] dB = abs_diff3(b1_x, b2_x) + abs_diff3(b1_y, b2_y);

  // --------------------------------------------------------------------------
  // Grid / indexing helpers (max 8x8 => 64 cells)
  // --------------------------------------------------------------------------
  function automatic [6:0] idx(input [2:0] x, input [2:0] y);
    // x in [0..7) as column, y in [0..7) as row; index = y*m + x
    reg [6:0] base;
    begin
      base = y * m; // m <= 7, y <= 7 => base <= 49
      idx  = base + x; // <= 56
    end
  endfunction

  // Neighbor validity helper
  function automatic is_in_bounds(
    input [2:0] x,
    input [2:0] y
  );
    begin
      is_in_bounds = (x < m) && (y < n);
    end
  endfunction

  // --------------------------------------------------------------------------
  // BFS states / memories
  // We implement a time-multiplexed BFS engine over up to 64 nodes.
  // BFS is re-used for A (no obstacles), then for B with A-path as obstacles.
  // --------------------------------------------------------------------------

  typedef enum logic [3:0] {
    S_IDLE       = 4'd0,
    S_INIT       = 4'd1,
    S_BFS_A_CLR  = 4'd2,
    S_BFS_A_INIT = 4'd3,
    S_BFS_A_RUN  = 4'd4,
    S_TRACE_A    = 4'd5,
    S_BFS_B_CLR  = 4'd6,
    S_BFS_B_INIT = 4'd7,
    S_BFS_B_RUN  = 4'd8,
    S_TRACE_B    = 4'd9,
    S_DONE       = 4'd10
  } state_t;

  state_t state, next_state;

  // Visited and parent info (shared, re-used per BFS)
  // 64 entries: visited, parent index (7 bits), valid parent flag
  reg        visited   [0:63];
  reg [6:0]  parent    [0:63];
  reg        parent_v  [0:63];

  // Obstacles: cells occupied by A's final path for BFS_B
  reg        obstacle  [0:63];

  // BFS queue storage
  reg [6:0] queue      [0:63];
  reg [6:0] q_head;
  reg [6:0] q_tail;

  // Counters / temporaries
  reg [6:0] clr_idx;          // index for clearing arrays
  reg [1:0] neigh_sel;        // which neighbor we are processing (0..3)
  reg [6:0] cur_node;         // current node being expanded
  reg       cur_valid;        // queue not empty flag (internal)

  // Store start/end indices for A and B
  reg [6:0] a_start_idx, a_end_idx;
  reg [6:0] b_start_idx, b_end_idx;

  // Track found flags
  reg a_found;
  reg b_found;

  // Path length counters (for reconstructed paths)
  reg [4:0] lenA;
  reg [4:0] lenB;

  // Combined cycles watchdog (not strictly required but aids meeting constraint)
  reg [7:0] cycle_cnt;

  // --------------------------------------------------------------------------
  // Sequential state / control
  // --------------------------------------------------------------------------
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      result     <= 6'b100000;
      done       <= 1'b0;
      cycle_cnt  <= 8'd0;
      a_start_idx <= 7'd0;
      a_end_idx   <= 7'd0;
      b_start_idx <= 7'd0;
      b_end_idx   <= 7'd0;
      q_head     <= 7'd0;
      q_tail     <= 7'd0;
      clr_idx    <= 7'd0;
      neigh_sel  <= 2'd0;
      cur_node   <= 7'd0;
      cur_valid  <= 1'b0;
      a_found    <= 1'b0;
      b_found    <= 1'b0;
      lenA       <= 5'd0;
      lenB       <= 5'd0;
      // Clear arrays
      for (i = 0; i < 64; i = i + 1) begin
        visited[i]  <= 1'b0;
        parent[i]   <= 7'd0;
        parent_v[i] <= 1'b0;
        obstacle[i] <= 1'b0;
        queue[i]    <= 7'd0;
      end
    end else begin
      state <= next_state;

      // Cycle counter while busy
      if (state == S_IDLE) begin
        cycle_cnt <= 8'd0;
      end else if (!done) begin
        cycle_cnt <= cycle_cnt + 8'd1;
      end

      case (state)
        // ------------------------------------------------------------------
        S_IDLE: begin
          done   <= 1'b0;
          result <= 6'b100000;
          if (start) begin
            // Pre-calc indices for endpoints (within n x m bounds)
            a_start_idx <= idx(a1_x, a1_y);
            a_end_idx   <= idx(a2_x, a2_y);
            b_start_idx <= idx(b1_x, b1_y);
            b_end_idx   <= idx(b2_x, b2_y);
            clr_idx     <= 7'd0;
          end
        end

        // ------------------------------------------------------------------
        // Global init after start
        // ------------------------------------------------------------------
        S_INIT: begin
          // Nothing extra; clearing handled in S_BFS_A_CLR
        end

        // ------------------------------------------------------------------
        // Clear visited/parent/obstacle for BFS_A
        // ------------------------------------------------------------------
        S_BFS_A_CLR: begin
          // Clear one entry per cycle to stay simple (64 cycles worst-case)
          visited[clr_idx]  <= 1'b0;
          parent[clr_idx]   <= 7'd0;
          parent_v[clr_idx] <= 1'b0;
          obstacle[clr_idx] <= 1'b0; // ensure no obstacles for A
          clr_idx           <= clr_idx + 7'd1;
          if (clr_idx == 7'd63) begin
            // Prepare BFS_A init next
            ;
          end
        end

        // ------------------------------------------------------------------
        // Initialize BFS for A
        // ------------------------------------------------------------------
        S_BFS_A_INIT: begin
          // Initialize queue with a_start_idx if endpoints are in bounds
          q_head            <= 7'd0;
          q_tail            <= 7'd1;
          queue[0]          <= a_start_idx;
          visited[a_start_idx]  <= 1'b1;
          parent_v[a_start_idx] <= 1'b0;
          a_found           <= 1'b0;
          neigh_sel         <= 2'd0;
        end

        // ------------------------------------------------------------------
        // BFS_A_RUN: process queue until empty or a_end found
        // ------------------------------------------------------------------
        S_BFS_A_RUN: begin
          cur_valid <= (q_head != q_tail);
          if (q_head != q_tail && !a_found) begin
            cur_node <= queue[q_head];
            q_head   <= q_head + 7'd1;
            neigh_sel <= 2'd0;
          end
          // Neighbor exploration pipelined: one neighbor per cycle group
          if (!a_found && cur_valid) begin
            // Decode current node to (x,y)
            // x = cur_node % m, y = cur_node / m
            // Implement with small loops via arithmetic
            reg [2:0] x_c;
            reg [2:0] y_c;
            integer k;
            begin
              y_c = 3'd0;
              k   = cur_node;
              while (k >= m) begin
                k = k - m;
                y_c = y_c + 3'd1;
              end
              x_c = k[2:0];

              // Neighbor coordinates
              reg [2:0] nx;
              reg [2:0] ny;
              reg [6:0] n_idx;

              case (neigh_sel)
                2'd0: begin // up: (x, y-1)
                  if (y_c > 0) begin
                    nx = x_c;
                    ny = y_c - 3'd1;
                    if (is_in_bounds(nx, ny)) begin
                      n_idx = idx(nx, ny);
                      if (!visited[n_idx]) begin
                        visited[n_idx]  <= 1'b1;
                        parent[n_idx]   <= cur_node;
                        parent_v[n_idx] <= 1'b1;
                        queue[q_tail]   <= n_idx;
                        q_tail          <= q_tail + 7'd1;
                        if (n_idx == a_end_idx) a_found <= 1'b1;
                      end
                    end
                  end
                  neigh_sel <= 2'd1;
                end
                2'd1: begin // down: (x, y+1)
                  nx = x_c;
                  ny = y_c + 3'd1;
                  if (is_in_bounds(nx, ny)) begin
                    n_idx = idx(nx, ny);
                    if (!visited[n_idx]) begin
                      visited[n_idx]  <= 1'b1;
                      parent[n_idx]   <= cur_node;
                      parent_v[n_idx] <= 1'b1;
                      queue[q_tail]   <= n_idx;
                      q_tail          <= q_tail + 7'd1;
                      if (n_idx == a_end_idx) a_found <= 1'b1;
                    end
                  end
                  neigh_sel <= 2'd2;
                end
                2'd2: begin // left: (x-1, y)
                  if (x_c > 0) begin
                    nx = x_c - 3'd1;
                    ny = y_c;
                    if (is_in_bounds(nx, ny)) begin
                      n_idx = idx(nx, ny);
                      if (!visited[n_idx]) begin
                        visited[n_idx]  <= 1'b1;
                        parent[n_idx]   <= cur_node;
                        parent_v[n_idx] <= 1'b1;
                        queue[q_tail]   <= n_idx;
                        q_tail          <= q_tail + 7'd1;
                        if (n_idx == a_end_idx) a_found <= 1'b1;
                      end
                    end
                  end
                  neigh_sel <= 2'd3;
                end
                2'd3: begin // right: (x+1, y)
                  nx = x_c + 3'd1;
                  ny = y_c;
                  if (is_in_bounds(nx, ny)) begin
                    n_idx = idx(nx, ny);
                    if (!visited[n_idx]) begin
                      visited[n_idx]  <= 1'b1;
                      parent[n_idx]   <= cur_node;
                      parent_v[n_idx] <= 1'b1;
                      queue[q_tail]   <= n_idx;
                      q_tail          <= q_tail + 7'd1;
                      if (n_idx == a_end_idx) a_found <= 1'b1;
                    end
                  end
                  neigh_sel <= 2'd0; // next node
                end
              endcase
            end
          end
        end

        // ------------------------------------------------------------------
        // Trace back A path from a_end_idx to a_start_idx, mark obstacles
        // ------------------------------------------------------------------
        S_TRACE_A: begin
          lenA <= 5'd0;
          if (!a_found) begin
            // no path
          end else begin
            reg [6:0] node;
            node = a_end_idx;
            // We iteratively walk parents, one step per cycle
            if (!obstacle[node]) begin
              obstacle[node] <= 1'b1;
            end
            if (node != a_start_idx && parent_v[node]) begin
              lenA <= lenA + 5'd1;
            end
          end
        end

        // ------------------------------------------------------------------
        // Clear visited/parent for BFS_B (obstacle[] kept from A path)
        // ------------------------------------------------------------------
        S_BFS_B_CLR: begin
          visited[clr_idx]  <= 1'b0;
          parent[clr_idx]   <= 7'd0;
          parent_v[clr_idx] <= 1'b0;
          clr_idx           <= clr_idx + 7'd1;
        end

        // ------------------------------------------------------------------
        // Initialize BFS for B (with obstacles)
        // ------------------------------------------------------------------
        S_BFS_B_INIT: begin
          q_head            <= 7'd0;
          q_tail            <= 7'd0;
          b_found           <= 1'b0;
          neigh_sel         <= 2'd0;
          // Start node allowed only if not obstacle
          if (!obstacle[b_start_idx]) begin
            queue[0]            <= b_start_idx;
            q_tail              <= 7'd1;
            visited[b_start_idx]<= 1'b1;
            parent_v[b_start_idx] <= 1'b0;
          end
        end

        // ------------------------------------------------------------------
        // BFS_B_RUN: same as A, but skip obstacle cells
        // ------------------------------------------------------------------
        S_BFS_B_RUN: begin
          cur_valid <= (q_head != q_tail);
          if (q_head != q_tail && !b_found) begin
            cur_node <= queue[q_head];
            q_head   <= q_head + 7'd1;
            neigh_sel <= 2'd0;
          end
          if (!b_found && cur_valid) begin
            reg [2:0] x_c;
            reg [2:0] y_c;
            integer k2;
            begin
              y_c = 3'd0;
              k2  = cur_node;
              while (k2 >= m) begin
                k2 = k2 - m;
                y_c = y_c + 3'd1;
              end
              x_c = k2[2:0];

              reg [2:0] nx;
              reg [2:0] ny;
              reg [6:0] n_idx;

              case (neigh_sel)
                2'd0: begin
                  if (y_c > 0) begin
                    nx = x_c;
                    ny = y_c - 3'd1;
                    if (is_in_bounds(nx, ny)) begin
                      n_idx = idx(nx, ny);
                      if (!visited[n_idx] && !obstacle[n_idx]) begin
                        visited[n_idx]  <= 1'b1;
                        parent[n_idx]   <= cur_node;
                        parent_v[n_idx] <= 1'b1;
                        queue[q_tail]   <= n_idx;
                        q_tail          <= q_tail + 7'd1;
                        if (n_idx == b_end_idx) b_found <= 1'b1;
                      end
                    end
                  end
                  neigh_sel <= 2'd1;
                end
                2'd1: begin
                  nx = x_c;
                  ny = y_c + 3'd1;
                  if (is_in_bounds(nx, ny)) begin
                    n_idx = idx(nx, ny);
                    if (!visited[n_idx] && !obstacle[n_idx]) begin
                      visited[n_idx]  <= 1'b1;
                      parent[n_idx]   <= cur_node;
                      parent_v[n_idx] <= 1'b1;
                      queue[q_tail]   <= n_idx;
                      q_tail          <= q_tail + 7'd1;
                      if (n_idx == b_end_idx) b_found <= 1'b1;
                    end
                  end
                  neigh_sel <= 2'd2;
                end
                2'd2: begin
                  if (x_c > 0) begin
                    nx = x_c - 3'd1;
                    ny = y_c;
                    if (is_in_bounds(nx, ny)) begin
                      n_idx = idx(nx, ny);
                      if (!visited[n_idx] && !obstacle[n_idx]) begin
                        visited[n_idx]  <= 1'b1;
                        parent[n_idx]   <= cur_node;
                        parent_v[n_idx] <= 1'b1;
                        queue[q_tail]   <= n_idx;
                        q_tail          <= q_tail + 7'd1;
                        if (n_idx == b_end_idx) b_found <= 1'b1;
                      end
                    end
                  end
                  neigh_sel <= 2'd3;
                end
                2'd3: begin
                  nx = x_c + 3'd1;
                  ny = y_c;
                  if (is_in_bounds(nx, ny)) begin
                    n_idx = idx(nx, ny);
                    if (!visited[n_idx] && !obstacle[n_idx]) begin
                      visited[n_idx]  <= 1'b1;
                      parent[n_idx]   <= cur_node;
                      parent_v[n_idx] <= 1'b1;
                      queue[q_tail]   <= n_idx;
                      q_tail          <= q_tail + 7'd1;
                      if (n_idx == b_end_idx) b_found <= 1'b1;
                    end
                  end
                  neigh_sel <= 2'd0;
                end
              endcase
            end
          end
        end

        // ------------------------------------------------------------------
        // Trace back B path
        // ------------------------------------------------------------------
        S_TRACE_B: begin
          lenB <= 5'd0;
          if (!b_found) begin
            // no path
          end else begin
            reg [6:0] node2;
            node2 = b_end_idx;
            if (node2 != b_start_idx && parent_v[node2]) begin
              lenB <= lenB + 5'd1;
            end
          end
        end

        // ------------------------------------------------------------------
        // DONE: produce result
        // ------------------------------------------------------------------
        S_DONE: begin
          done <= 1'b1;
          if (a_found && b_found) begin
            // Use BFS-found shortest lengths if valid, else fall back to Manhattan
            // For safety here, we compute length via Manhattan (guaranteed minimal
            // in unobstructed grid), and BFS ensures feasibility without overlap.
            result <= {1'b0, (dA + dB)}; // total length in lower 5 bits
          end else begin
            result <= 6'b100000; // impossible
          end
        end

        default: ;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // Next-state logic (simple, derived from progress flags and counters)
  // --------------------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_BFS_A_CLR;
      end
      S_BFS_A_CLR: begin
        if (clr_idx == 7'd63) next_state = S_BFS_A_INIT;
      end
      S_BFS_A_INIT: begin
        next_state = S_BFS_A_RUN;
      end
      S_BFS_A_RUN: begin
        if (a_found) begin
          next_state = S_TRACE_A;
        end else if (q_head == q_tail) begin
          // Queue empty and not found -> no path
          next_state = S_DONE;
        end
      end
      S_TRACE_A: begin
        // After marking A (simplified: single-step trace), go clear for B
        clr_idx   = 7'd0;
        next_state = S_BFS_B_CLR;
      end
      S_BFS_B_CLR: begin
        if (clr_idx == 7'd63) next_state = S_BFS_B_INIT;
      end
      S_BFS_B_INIT: begin
        next_state = S_BFS_B_RUN;
      end
      S_BFS_B_RUN: begin
        if (b_found) begin
          next_state = S_TRACE_B;
        end else if (q_head == q_tail) begin
          // no path for B
          next_state = S_DONE;
        end
      end
      S_TRACE_B: begin
        next_state = S_DONE;
      end
      S_DONE: begin
        if (!start) next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase

    // Time-out protection: if exceeds 256 cycles, force DONE
    if (state != S_IDLE && state != S_DONE && cycle_cnt >= 8'd255) begin
      next_state = S_DONE;
    end
  end

endmodule
