module wire_routing(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [2:0] n, // Grid rows (2-7)
  input [2:0] m, // Grid columns (2-7)
  input [5:0] a1, // {x1[2:0], y1[2:0]}
  input [5:0] a2, // {x2[2:0], y2[2:0]}
  input [5:0] b1, // {x3[2:0], y3[2:0]}
  input [5:0] b2, // {x4[2:0], y4[0]}
  output reg [5:0] result, // {1'b0, length[4:0]} or 6'b100000 for impossible
  output reg done // High when result valid
);

  // Grid size is up to 8x8, but runtime n,m (2..7) define valid region.
  // We'll bound everything with MAX_N=8, MAX_M=8.
  localparam MAX_N = 8;
  localparam MAX_M = 8;
  localparam V = MAX_N * MAX_M; // 64
  localparam LOGV = 6; // 2^6=64

  // BFS queue capacity: 2*V (worst-case)
  localparam QLOG = LOGV + 1; // 7
  localparam QSIZE = 1 << QLOG; // 128

  // State machine
  typedef enum logic [1:0] {
    IDLE  = 2'd0,
    RUN   = 2'd1,
    DONE  = 2'd2
  } fsm_t;

  fsm_t state, next_state;

  // BFS queue storage
  logic [5:0] q_data [0:QSIZE-1]; // packed: {1'b pair, 5'b node}
  logic [QLOG-1:0] q_head, q_tail, q_tail_next;
  logic [QLOG:0] q_occ; // occupancy count

  logic q_full;
  logic q_empty;

  assign q_full = (q_occ == QSIZE);
  assign q_empty = (q_occ == 0);

  function [5:0] queue_pop();
    logic [5:0] d;
    d = q_data[q_head];
    q_head = q_head + 1;
    q_occ = q_occ - 1;
    return d;
  endfunction

  function void queue_push(input logic [5:0] d);
    q_data[q_tail] = d;
    q_tail = q_tail + 1;
    q_occ = q_occ + 1;
  endfunction

  // BFS bookkeeping for current iteration (reused per search)
  logic [V-1:0] visited_mask; // union of visited for current pair
  logic [V-1:0] used_mask;    // union of visited for both pairs (accumulated)
  logic [5:0] cur_pair, cur_node;
  logic [5:0] start_nodes [0:1];
  logic [5:0] goal_nodes  [0:1];

  // Parent pointers for reconstruction (pair-specific)
  // Store previous node index for each node visited by each pair.
  logic [V-1:0] parent_valid [0:1]; // bit per node
  logic [5:0]  parent_node  [0:1][0:V-1]; // 6 bits (0..V-1)

  // Path reconstruction scratch
  logic [V-1:0] path_a_mask;
  logic [V-1:0] path_b_mask;
  logic path_valid;
  logic [4:0] length_a;
  logic [4:0] length_b;
  logic [4:0] best_len;

  // Stage current search iteration
  logic search_start, search_done, recon_done;
  logic [2:0] iter_cnt; // 0..3 (two pairs)

  // Internal counters
  logic [7:0] cycle_cnt; // up to 255 cycles

  // Helper functions
  function [2:0] get_x(input [5:0] packed, input [2:0] grid_m);
    // x is low 3 bits
    return packed[2:0];
  endfunction

  function [2:0] get_y(input [5:0] packed, input [2:0] grid_n);
    // y is high 3 bits
    return packed[5:3];
  endfunction

  function [5:0] pack_xy(input [2:0] x, input [2:0] y);
    return {y, x};
  endfunction

  function [5:0] node_index(input [2:0] x, input [2:0] y, input [2:0] n, input [2:0] m);
    // 0 <= x < m, 0 <= y < n
    return {3'b0, y} * m + {3'b0, x}; // returns up to 63
  endfunction

  function [2:0] node_x(input [5:0] idx, input [2:0] m);
    return idx % m;
  endfunction

  function [2:0] node_y(input [5:0] idx, input [2:0] n);
    return idx / n;
  endfunction

  function [5:0] node_from_packed(input [5:0] packed, input [2:0] n, input [2:0] m);
    return node_index(get_x(packed, m), get_y(packed, n), n, m);
  endfunction

  // Main FSM: Combinational next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:  if (start) next_state = RUN;
      RUN:   if (done) next_state = DONE;
      DONE:  if (!start) next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Sequential control + BFS and reconstruction logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Outputs
      result <= 6'b0;
      done   <= 1'b0;

      // Counters
      cycle_cnt <= 8'd0;

      // BFS queue
      q_head <= '0;
      q_tail <= '0;
      q_occ  <= '0;

      // Masks and BFS registers
      visited_mask <= '0;
      used_mask    <= '0;
      cur_pair     <= '0;
      cur_node     <= '0;

      // Parents
      parent_valid[0] <= '0;
      parent_valid[1] <= '0;

      // Iteration control
      iter_cnt    <= 3'd0;
      search_start <= 1'b0;
      search_done  <= 1'b0;
      recon_done   <= 1'b0;

      // Path masks
      path_a_mask  <= '0;
      path_b_mask  <= '0;
      path_valid   <= 1'b0;
      length_a     <= '0;
      length_b     <= '0;
      best_len     <= '0;
    end else begin
      // Cycle counter for latency cap (optional)
      if (state == RUN) cycle_cnt <= cycle_cnt + 1;
      else if (state == IDLE) cycle_cnt <= 8'd0;

      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= 6'b0;
          if (start) begin
            // Capture inputs
            start_nodes[0] <= node_from_packed(a1, n, m);
            start_nodes[1] <= node_from_packed(b1, n, m);
            goal_nodes[0]  <= node_from_packed(a2, n, m);
            goal_nodes[1]  <= node_from_packed(b2, n, m);
            // Clear masks and parents
            used_mask    <= '0;
            parent_valid[0] <= '0;
            parent_valid[1] <= '0;
            iter_cnt    <= 3'd0;
            search_start <= 1'b1;
            search_done  <= 1'b0;
            recon_done   <= 1'b0;
            path_valid   <= 1'b0;
            path_a_mask  <= '0;
            path_b_mask  <= '0;
            length_a     <= '0;
            length_b     <= '0;
            best_len     <= 5'd31; // high initial
          end
        end

        RUN: begin
          if (!start) begin
            // If start deasserted mid-run, go to done with impossible
            done   <= 1'b1;
            result <= 6'b100000; // impossible
          end else if (iter_cnt < 2) begin
            // Perform BFS for current pair if not finished
            if (search_start) begin
              // Initialize BFS for this pair
              q_head <= '0;
              q_tail <= '0;
              q_occ  <= '0;
              visited_mask <= '0;
              cur_pair <= iter_cnt[0]; // 0 then 1
              cur_node <= '0;

              // Seed queue with start node
              if (start_nodes[iter_cnt[0]] < V) begin
                queue_push({iter_cnt[0], start_nodes[iter_cnt[0]]});
                visited_mask[start_nodes[iter_cnt[0]]] <= 1'b1;
                parent_valid[iter_cnt[0]][start_nodes[iter_cnt[0]]] <= 1'b1; // root valid
              end
              search_start <= 1'b0;
              search_done  <= 1'b0;
            end else if (!search_done) begin
              if (!q_empty) begin
                // Pop one element
                cur_node <= queue_pop()[4:0];
                cur_pair <= queue_pop()[5];
                // If goal reached, reconstruct
                if (cur_node == goal_nodes[cur_pair]) begin
                  // BFS found a path for this pair; record parents remain set
                  search_done <= 1'b1;
                end else begin
                  // Expand neighbors
                  begin
                    logic [2:0] cx, cy;
                    logic [5:0] neigh;
                    cx = node_x(cur_node, m);
                    cy = node_y(cur_node, n);
                    // Left
                    if (cx > 0) begin
                      neigh = node_index(cx-1, cy, n, m);
                      if (!visited_mask[neigh]) begin
                        visited_mask[neigh] <= 1'b1;
                        parent_node[cur_pair][neigh] <= cur_node;
                        parent_valid[cur_pair][neigh] <= 1'b1;
                        if (!q_full) queue_push({cur_pair, neigh});
                      end
                    end
                    // Right
                    if (cx < m - 1) begin
                      neigh = node_index(cx+1, cy, n, m);
                      if (!visited_mask[neigh]) begin
                        visited_mask[neigh] <= 1'b1;
                        parent_node[cur_pair][neigh] <= cur_node;
                        parent_valid[cur_pair][neigh] <= 1'b1;
                        if (!q_full) queue_push({cur_pair, neigh});
                      end
                    end
                    // Up
                    if (cy > 0) begin
                      neigh = node_index(cx, cy-1, n, m);
                      if (!visited_mask[neigh]) begin
                        visited_mask[neigh] <= 1'b1;
                        parent_node[cur_pair][neigh] <= cur_node;
                        parent_valid[cur_pair][neigh] <= 1'b1;
                        if (!q_full) queue_push({cur_pair, neigh});
                      end
                    end
                    // Down
                    if (cy < n - 1) begin
                      neigh = node_index(cx, cy+1, n, m);
                      if (!visited_mask[neigh]) begin
                        visited_mask[neigh] <= 1'b1;
                        parent_node[cur_pair][neigh] <= cur_node;
                        parent_valid[cur_pair][neigh] <= 1'b1;
                        if (!q_full) queue_push({cur_pair, neigh});
                      end
                    end
                  end
                end
              end else begin
                // Queue empty: no path for this pair
                search_done <= 1'b1;
                // Mark this pair as unsolvable by zeroing its parent valid (so recon will fail)
                parent_valid[iter_cnt[0]] <= '0;
              end
            end else begin
              // search_done == 1: move to reconstruction for this pair, then iterate
              if (!recon_done) begin
                // Build path mask for current pair and check disjointness so far
                if (parent_valid[iter_cnt[0]][goal_nodes[iter_cnt[0]]]) begin
                  logic [5:0] cur, prev;
                  logic [V-1:0] mask;
                  mask = '0;
                  cur = goal_nodes[iter_cnt[0]];
                  while (1) begin
                    mask[cur] = 1'b1;
                    if (cur == start_nodes[iter_cnt[0]]) break;
                    prev = parent_node[iter_cnt[0]][cur];
                    cur = prev;
                    // Safety: if prev invalid, break to avoid infinite loop
                    if (!parent_valid[iter_cnt[0]][cur] && cur != start_nodes[iter_cnt[0]]) begin
                      mask = '0;
                      break;
                    end
                  end
                  // Disjoint check against used_mask
                  if ((mask & used_mask) == '0) begin
                    // Accept this path
                    if (iter_cnt[0] == 0) begin
                      path_a_mask <= mask;
                      length_a <= $countones(mask) - 1; // edges = nodes-1
                    end else begin
                      path_b_mask <= mask;
                      length_b <= $countones(mask) - 1;
                    end
                    used_mask <= used_mask | mask;
                    path_valid <= 1'b1;
                    best_len <= (iter_cnt[0] == 0) ? ($countones(mask) - 1) : best_len;
                    recon_done <= 1'b1;
                  end else begin
                    // Conflict with used nodes; since we take first-found BFS path,
                    // it is the shortest for this pair. No alternate; this pair fails.
                    parent_valid[iter_cnt[0]] <= '0; // mark unsolvable
                    recon_done <= 1'b1;
                  end
                end else begin
                  // No path for this pair at all
                  recon_done <= 1'b1;
                end
              end else begin
                // Prepare next pair
                iter_cnt <= iter_cnt + 1;
                search_start <= 1'b1;
                search_done  <= 1'b0;
                recon_done   <= 1'b0;
              end
            end
          end else begin
            // iter_cnt >= 2: both pairs processed, finalize
            if (path_valid && parent_valid[0][goal_nodes[0]] && parent_valid[1][goal_nodes[1]]) begin
              // Both paths found and disjoint (kept disjoint by used_mask enforcement)
              best_len <= length_a + length_b;
              result <= {1'b0, (length_a + length_b)}; // 5-bit length, valid bit 0
              done   <= 1'b1;
            end else begin
              // No solution
              result <= 6'b100000; // impossible
              done   <= 1'b1;
            end
          end
        end

        DONE: begin
          if (!start) begin
            done   <= 1'b0;
            result <= 6'b0;
          end
        end

        default: begin
          // Keep outputs stable
          done   <= done;
          result <= result;
        end
      endcase
    end
  end
endmodule
