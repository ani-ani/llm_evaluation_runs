module max_university_pairs(
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [7:0] univ_mask,
  input [7:0][2:0] adj_list,
  output reg [4:0] max_sum,
  output reg done
);

  // Internal signals and state machine
  typedef enum logic [2:0] {IDLE=3'b000, TRAVERSE=3'b001, COUNT_SUBTREES=3'b010, CALC_SUM=3'b011, FINISH=3'b100} state_t;
  state_t state, next_state;

  // Registers
  reg [2:0] head, tail;        // BFS queue pointers
  reg [7:0] visited;           // visited flag per node (bitmask)
  reg [2:0] parent_mem [0:7];  // parent per node (3 bits each, 0x7=invalid)
  reg [2:0] subtree [0:7];     // subtree university counts (3 bits each, 0..4)
  reg [2:0] bfs_queue [0:7];   // BFS order queue
  reg [3:0] cycle_cnt;         // cycle counter for max 15 cycles
  reg [2:0] tot_univ;          // total number of universities (max 4)
  reg [2:0] i_cur, j_cur, k_cur; // loop/index registers
  reg [7:0] cur_neighbors;     // current neighbor mask from adj_list
  reg [2:0] cur_node, cur_nbr, cur_parent; // working node/parent values

  // Always FF for state, outputs and control registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_sum <= 5'b0;
      done <= 1'b0;
      head <= 3'b0;
      tail <= 3'b0;
      visited <= 8'b0;
      cycle_cnt <= 4'b0;
      tot_univ <= 3'b0;
      i_cur <= 3'b0;
      j_cur <= 3'b0;
      k_cur <= 3'b0;
      cur_neighbors <= 8'b0;
      cur_node <= 3'b0;
      cur_nbr <= 3'b0;
      cur_parent <= 3'b0;
      // Initialize memories
      for (int p = 0; p < 8; p++) begin
        parent_mem[p] <= 3'b111; // invalid parent marker
        subtree[p] <= 3'b0;
        bfs_queue[p] <= 3'b0;
      end
    end else begin
      // Defaults
      done <= 1'b0;
      head <= head;
      tail <= tail;
      visited <= visited;
      cycle_cnt <= cycle_cnt;
      tot_univ <= tot_univ;
      i_cur <= i_cur;
      j_cur <= j_cur;
      k_cur <= k_cur;
      cur_neighbors <= cur_neighbors;
      cur_node <= cur_node;
      cur_nbr <= cur_nbr;
      cur_parent <= cur_parent;
      // Memories keep values unless explicitly updated

      case (state)
        IDLE: begin
          max_sum <= 5'b0;      // reset result
          // Clear data structures
          head <= 3'b0;
          tail <= 3'b0;
          visited <= 8'b0;
          cycle_cnt <= 4'b0;
          for (int p = 0; p < 8; p++) begin
            parent_mem[p] <= 3'b111;
            subtree[p] <= 3'b0;
          end
          if (start) begin
            // Count total universities in mask (max 4 per spec)
            tot_univ <= (univ_mask[0]) + (univ_mask[1]) + (univ_mask[2]) +
                        (univ_mask[3]) + (univ_mask[4]) + (univ_mask[5]) +
                        (univ_mask[6]) + (univ_mask[7]);
            // Seed BFS with node 0 if node_count > 0
            if (node_count > 3'b0) begin
              bfs_queue[0] <= 3'b0;
              tail <= 3'b1;
              visited <= 8'b1;
              parent_mem[0] <= 3'b111; // root has no parent
              i_cur <= 3'b0; // pointer to explore neighbors of queue[head]
              state <= TRAVERSE;
            end else begin
              state <= FINISH; // no nodes to process
            end
            cycle_cnt <= 4'b1;
          end else begin
            state <= IDLE;
          end
        end

        TRAVERSE: begin
          // BFS: process neighbors of bfs_queue[head]
          if (head == tail) begin
            // Queue empty -> BFS traversal done
            i_cur <= 3'b0;     // reset indices for next phase
            j_cur <= 3'b0;
            state <= COUNT_SUBTREES;
          end else begin
            cur_node <= bfs_queue[head];
            // If not started neighbor scan this cycle, set up mask
            if (i_cur == 3'b0) begin
              cur_neighbors <= 8'b0;
              // Build neighbor bitmask for current node using adj_list
              // This is combinatorial; we build it in one cycle for current node
              for (int nb = 0; nb < 8; nb++) begin
                if (adj_list[cur_node] == nb) cur_neighbors[nb] <= 1'b1;
              end
            end
            // Scan neighbors to find first unvisited
            if (j_cur < node_count) begin
              if (cur_neighbors[j_cur] && !visited[j_cur]) begin
                // Discover neighbor
                visited[j_cur] <= 1'b1;
                parent_mem[j_cur] <= cur_node;
                bfs_queue[tail] <= j_cur;
                tail <= tail + 1;
                // advance head to next node
                head <= head + 1;
                // reset neighbor scan for new node
                i_cur <= 3'b0;
                j_cur <= 3'b0;
              end else begin
                // Next neighbor
                j_cur <= j_cur + 1;
              end
            end else begin
              // No more neighbors for this node; pop it
              head <= head + 1;
              i_cur <= 3'b0;
              j_cur <= 3'b0;
            end
          end
          cycle_cnt <= cycle_cnt + 1;
        end

        COUNT_SUBTREES: begin
          // Compute subtree university counts in reverse BFS order
          if (j_cur == 3'b0) begin
            // Initialize leaf counts
            if (univ_mask[bfs_queue[i_cur]]) subtree[bfs_queue[i_cur]] <= 3'b1;
            else subtree[bfs_queue[i_cur]] <= 3'b0;
            j_cur <= 3'b1; // mark init done
          end else if (j_cur == 3'b1) begin
            // Accumulate to parent (if not root)
            cur_parent <= parent_mem[bfs_queue[i_cur]];
            if (cur_parent != 3'b111) begin
              subtree[cur_parent] <= subtree[cur_parent] + subtree[bfs_queue[i_cur]];
            end
            j_cur <= 3'b2; // move to next node
          end else begin
            // Advance to next node in BFS order
            if (i_cur + 1 == tail) begin
              // Finished accumulation
              i_cur <= 3'b0;     // reset for sum phase
              k_cur <= 3'b0;     // edge index
              max_sum <= 5'b0;
              state <= CALC_SUM;
            end else begin
              i_cur <= i_cur + 1;
              j_cur <= 3'b0; // re-init for next node
            end
          end
          cycle_cnt <= cycle_cnt + 1;
        end

        CALC_SUM: begin
          // Accumulate distance using min(child_count, tot_univ - child_count)
          if (k_cur < node_count) begin
            // Skip root (parent = 7) from contribution
            if (parent_mem[k_cur] != 3'b111) begin
              cur_nbr <= k_cur; // current child node
              // Add contribution: min(subtree[child], tot_univ - subtree[child])
              if (subtree[cur_nbr] <= (tot_univ - subtree[cur_nbr]))
                max_sum <= max_sum + {2'b0, subtree[cur_nbr]};
              else
                max_sum <= max_sum + {2'b0, (tot_univ - subtree[cur_nbr])};
            end
            k_cur <= k_cur + 1;
          end else begin
            state <= FINISH;
          end
          cycle_cnt <= cycle_cnt + 1;
        end

        FINISH: begin
          done <= 1'b1;
          state <= IDLE; // return to idle for next run
          cycle_cnt <= 4'b0;
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
