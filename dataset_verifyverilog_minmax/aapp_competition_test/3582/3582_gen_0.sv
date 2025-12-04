module mentor_assign(
  input clk,
  input rst_n,
  input start,
  input [2:0] n, // Number of Gagglers (3 bits, max 8)
  input [2:0] current_mentors [0:7], // Current mentor assignments (8 elements, 3-bit each)
  output reg [2:0] new_mentors [0:7],
  output reg done
);

  // State machine states
  typedef enum logic [1:0] {STAGE1 = 2'b00, STAGE2 = 2'b01, STAGE3 = 2'b10} state_t;
  state_t state;

  // Internal state
  reg [2:0] n_reg;
  reg [3:0] used_nodes; // count of used nodes in BFS
  reg [7:0] q_used;     // bitmask of visited/used nodes (only those in 0..n-1)
  reg [7:0] visited;
  reg [2:0] indeg [0:7];
  reg [2:0] order [0:7];
  reg [3:0] q_head, q_tail;
  reg single_cycle_r;

  // Repair operation state
  reg [2:0] tail_idx;
  reg [2:0] alt_value;
  reg [2:0] prev_m_value;
  reg [3:0] repair_step;
  reg [3:0] max_repair_steps;
  reg revert_en;
  reg [7:0] revert_mask;
  reg [2:0] revert_index;
  reg [2:0] revert_value;

  // BFS visited within n
  function [7:0] bfs_visited;
    input [2:0] nn;
    input [2:0] arr [0:7];
    reg [7:0] inq;
    reg [2:0] qmem [0:7];
    reg [2:0] head, tail, cnt;
    reg [2:0] indeg_local [0:7];
    reg [2:0] order_local [0:7];
    integer i;
  begin
    inq = 8'b0;
    head = 3'b0; tail = 3'b0; cnt = 3'b0;
    for (i = 0; i < 8; i++) indeg_local[i] = 3'b0;

    // Compute indegrees within the subset [0, nn-1]
    for (i = 0; i < 8; i++) begin
      if (i < nn) begin
        if (arr[i] < nn) indeg_local[arr[i]] = indeg_local[arr[i]] + 1;
      end
    end

    // Find start(s): nodes with indegree 0 (break self-loops via any starting point)
    for (i = 0; i < 8; i++) begin
      if (i < nn) begin
        if (indeg_local[i] == 3'b0) begin
          qmem[tail] = i[2:0];
          tail = tail + 1;
          inq[i] = 1'b1;
        end
      end
    end

    // If no zero-indegree nodes (disjoint cycles), start at node 0
    if (head == tail) begin
      qmem[tail] = 3'b0;
      tail = tail + 1;
      inq[0] = 1'b1;
    end

    // BFS/queue processing
    while (head != tail) begin
      order_local[cnt] = qmem[head];
      head = head + 1;
      cnt = cnt + 1;
      if (cnt >= nn) begin
        // Full coverage reached, drain rest of queue for correctness
        while (head != tail) begin
          order_local[cnt] = qmem[head];
          head = head + 1;
          cnt = cnt + 1;
        end
        break;
      end
    end

    bfs_visited = inq;
  end
  endfunction

  // Find smallest alternative for index j that keeps the system a single cycle if possible
  function [2:0] find_alternative;
    input [2:0] j;  // Gaggler to reassign
    input [2:0] nn;
    input [2:0] curr [0:7];
    input [7:0] in_use; // used-set bitmask (0..nn-1)
    reg [2:0] v;
    reg [7:0] indeg_check [0:7];
    integer k;
  begin
    // Indeg with a change attempted: decrease prev target, increase candidate
    for (k = 0; k < 8; k++) indeg_check[k] = 3'b0;
    for (k = 0; k < 8; k++) begin
      if (k < nn) begin
        if (k != j) begin
          if (curr[k] < nn) indeg_check[curr[k]] = indeg_check[curr[k]] + 1;
        end
      end
    end
    // Prefer original mentor first
    if (curr[j] < nn) begin
      indeg_check[curr[j]] = indeg_check[curr[j]] + 1;
      if (indeg_check[curr[j]] == 3'b1) begin
        find_alternative = curr[j];
        return;
      end
    end
    // Try candidates in order: prefer original then lowest-numbered alternative
    for (v = 3'b0; v < 3'b100; v = v + 1) begin
      if (v < nn) begin
        indeg_check[v] = indeg_check[v] + 1;
        if (indeg_check[v] == 3'b1) begin
          find_alternative = v;
          return;
        end
        indeg_check[v] = indeg_check[v] - 1;
      end
    end
    // Fallback: should never reach here for valid nn
    find_alternative = curr[j];
  end
  endfunction

  // Check for single cycle covering exactly the first nn nodes
  function single_cycle;
    input [2:0] nn;
    input [2:0] arr [0:7];
    reg [7:0] inq;
    reg [2:0] indeg_loc [0:7];
    reg [2:0] start_node;
    integer i;
    reg [7:0] seen;
  begin
    for (i = 0; i < 8; i++) indeg_loc[i] = 3'b0;
    for (i = 0; i < 8; i++) begin
      if (i < nn && arr[i] < nn) indeg_loc[arr[i]] = indeg_loc[arr[i]] + 1;
    end
    start_node = 3'b0;
    for (i = 0; i < 8; i++) if (i < nn && indeg_loc[i] == 3'b0) start_node = i[2:0];
    inq = bfs_visited(nn, arr);
    seen = 8'b0;
    for (i = 0; i < 8; i++) begin
      if (i < nn) seen[i] = 1'b1;
    end
    single_cycle = ((inq & seen) == seen);
  end
  endfunction

  // Top-level control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= STAGE1;
      done <= 1'b0;
      n_reg <= 3'b0;
      repair_step <= 4'b0;
      max_repair_steps <= 4'b0;
      revert_en <= 1'b0;
    end else begin
      case (state)
        STAGE1: begin
          // Initialize
          n_reg <= n;
          used_nodes <= {1'b0, n};
          q_used <= (n == 3'd0) ? 8'b0 : (8'b1 << n) - 1;
          visited <= 8'b0;
          indeg[0] <= 3'b0; indeg[1] <= 3'b0; indeg[2] <= 3'b0; indeg[3] <= 3'b0;
          indeg[4] <= 3'b0; indeg[5] <= 3'b0; indeg[6] <= 3'b0; indeg[7] <= 3'b0;
          order[0] <= 3'b0; order[1] <= 3'b0; order[2] <= 3'b0; order[3] <= 3'b0;
          order[4] <= 3'b0; order[5] <= 3'b0; order[6] <= 3'b0; order[7] <= 3'b0;
          q_head <= 4'b0; q_tail <= 4'b0;
          single_cycle_r <= 1'b0;
          repair_step <= 4'b0;
          max_repair_steps <= 4'd8; // Enough for n <= 8
          revert_en <= 1'b0;

          // Copy current mentors
          begin: copy_current
            integer i;
            for (i = 0; i < 8; i++) new_mentors[i] <= current_mentors[i];
          end

          // Evaluate start on next cycle
          if (start) begin
            if (n == 3'd0) begin
              done <= 1'b1;
              state <= STAGE1;
            end else begin
              state <= STAGE2;
            end
          end else begin
            done <= 1'b0;
          end
        end

        STAGE2: begin
          // Evaluate the current assignment
          single_cycle_r <= single_cycle(n_reg, new_mentors);
          // Compute BFS data (redundant here; single_cycle recomputes, but kept for structure)
          begin
            integer i;
            for (i = 0; i < 8; i++) indeg[i] <= 3'b0;
            for (i = 0; i < 8; i++) begin
              if (i < n_reg && new_mentors[i] < n_reg) indeg[new_mentors[i]] <= indeg[new_mentors[i]] + 1;
            end
            visited <= bfs_visited(n_reg, new_mentors);
            q_used <= (n_reg == 3'd0) ? 8'b0 : (8'b1 << n_reg) - 1;
            used_nodes <= {1'b0, n_reg};
            q_head <= 4'b0; q_tail <= 4'b0;
            order[0] <= 3'b0; order[1] <= 3'b0; order[2] <= 3'b0; order[3] <= 3'b0;
            order[4] <= 3'b0; order[5] <= 3'b0; order[6] <= 3'b0; order[7] <= 3'b0;
          end

          if (single_cycle_r) begin
            done <= 1'b1;
            state <= STAGE2; // Hold until next start or reset
          end else begin
            // Prepare for repair
            repair_step <= 4'b0;
            revert_en <= 1'b0;
            state <= STAGE3;
          end
        end

        STAGE3: begin
          // Repair: modify assignments to eventually form a single cycle
          if (revert_en) begin
            // Undo last change if progress not improving
            new_mentors[revert_index] <= revert_value;
            revert_en <= 1'b0;
            repair_step <= (repair_step > 4'b0) ? (repair_step - 1) : repair_step;
            // Evaluate again after revert
            single_cycle_r <= single_cycle(n_reg, new_mentors);
            if (single_cycle_r) begin
              done <= 1'b1;
              state <= STAGE2;
            end else begin
              state <= STAGE3; // Continue
            end
          end else begin
            if (repair_step >= max_repair_steps) begin
              // Fallback: force a simple cycle 0->1->2->...->(n-1)->0
              begin
                integer i;
                for (i = 0; i < 8; i++) begin
                  if (i < n_reg - 1) new_mentors[i] <= i + 1;
                  else if (i == n_reg - 1 && n_reg > 0) new_mentors[i] <= 3'b0;
                end
              end
              state <= STAGE2;
            end else begin
              // Find a tail (unique target, not part of the path so far)
              begin
                reg [2:0] t;
                reg [7:0] path_set;
                reg [7:0] target_used;
                reg found_tail;
                integer k;
                path_set = 8'b0;
                target_used = 8'b0;
                found_tail = 1'b0;
                t = 3'b0;

                // Gather path from any start with indegree 0 within the used set
                begin
                  reg [2:0] indeg_tmp [0:7];
                  reg [2:0] start_idx;
                  reg [2:0] cur;
                  reg [3:0] steps;
                  reg [7:0] in_path;
                  reg [7:0] seen_edges;
                  for (k = 0; k < 8; k++) indeg_tmp[k] = 3'b0;
                  for (k = 0; k < 8; k++) begin
                    if (k < n_reg && new_mentors[k] < n_reg) indeg_tmp[new_mentors[k]] = indeg_tmp[new_mentors[k]] + 1;
                  end
                  start_idx = 3'b0;
                  for (k = 0; k < 8; k++) if (k < n_reg && indeg_tmp[k] == 3'b0) start_idx = k[2:0];
                  cur = start_idx;
                  steps = 4'b0;
                  in_path = 8'b0;
                  seen_edges = 8'b0;
                  while (steps < 8 && cur < n_reg) begin
                    in_path[cur] = 1'b1;
                    path_set = path_set | (8'b1 << cur);
                    seen_edges[cur] = 1'b1;
                    if (new_mentors[cur] >= n_reg) break;
                    cur = new_mentors[cur];
                    steps = steps + 1;
                    if (in_path[cur]) break; // cycle within used nodes
                  end
                end

                // Mark targets currently in use within the used set
                for (k = 0; k < 8; k++) begin
                  if (k < n_reg) begin
                    if (new_mentors[k] < n_reg) target_used[new_mentors[k]] = 1'b1;
                  end
                end

                // Select tail: lowest index with target in target_used but its target not yet in path_set
                for (k = 0; k < 8; k++) begin
                  if (k < n_reg) begin
                    if (new_mentors[k] < n_reg) begin
                      if (target_used[new_mentors[k]]) begin
                        if (!path_set[new_mentors[k]]) begin
                          t = k[2:0];
                          found_tail = 1'b1;
                          break;
                        end
                      end
                    end
                  end
                end

                if (!found_tail) begin
                  // No suitable tail; start from node 0
                  t = 3'b0;
                end

                tail_idx <= t;
              end

              // Choose alternative assignment for this tail
              alt_value <= find_alternative(tail_idx, n_reg, new_mentors, q_used);
              prev_m_value <= new_mentors[tail_idx];

              // Apply the change (store old value for potential revert)
              new_mentors[tail_idx] <= alt_value;
              revert_index <= tail_idx;
              revert_value <= prev_m_value;
              revert_en <= 1'b1; // On next cycle, we may revert if this didn't improve
              repair_step <= repair_step + 1;

              // Evaluate after the change; if single cycle, accept and finish
              single_cycle_r <= single_cycle(n_reg, new_mentors);
              if (single_cycle_r) begin
                done <= 1'b1;
                state <= STAGE2; // Hold valid state
              end else begin
                state <= STAGE3; // Continue next cycle (revert may happen)
              end
            end
          end
        end
      endcase
    end
  end
endmodule
