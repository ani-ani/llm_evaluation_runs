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

  // State encoding
  localparam IDLE            = 3'd0;
  localparam TRAVERSE        = 3'd1;
  localparam COUNT_SUBTREES  = 3'd2;
  localparam CALC_SUM        = 3'd3;
  localparam FINISH          = 3'd4;

  reg [2:0] state, next_state;

  // Memories
  reg [2:0] parent     [7:0]; // parent of each node
  reg       visited    [7:0]; // visited status for BFS
  reg [2:0] subtree_cnt[7:0]; // subtree university counts

  // BFS queue
  reg [2:0] queue      [7:0];
  reg [2:0] q_head;
  reg [2:0] q_tail;

  // Registers
  reg [2:0] root;
  reg [2:0] total_univ;

  reg [2:0] bfs_curr;      // current node in TRAVERSE
  reg [1:0] bfs_idx;       // which of the 3 neighbors (0..2) to process

  reg [2:0] proc_node;     // generic node index for passes

  reg [4:0] sum_accum;

  integer i;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = TRAVERSE;
      end
      TRAVERSE: begin
        // Move to COUNT_SUBTREES when BFS queue empty and current neighbors done
        if (q_head == q_tail && bfs_idx == 2'd3)
          next_state = COUNT_SUBTREES;
      end
      COUNT_SUBTREES: begin
        // After processing all nodes in reverse order
        if (proc_node == 3'd0)
          next_state = CALC_SUM;
      end
      CALC_SUM: begin
        // After checking all edges (all nodes except root)
        if (proc_node == 3'd0)
          next_state = FINISH;
      end
      FINISH: begin
        // Wait here until start deasserts; then go IDLE on next start
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      max_sum     <= 5'd0;
      root        <= 3'd0;
      total_univ  <= 3'd0;
      q_head      <= 3'd0;
      q_tail      <= 3'd0;
      bfs_curr    <= 3'd0;
      bfs_idx     <= 2'd0;
      proc_node   <= 3'd0;
      sum_accum   <= 5'd0;
      for (i = 0; i < 8; i = i + 1) begin
        parent[i]      <= 3'd0;
        visited[i]     <= 1'b0;
        subtree_cnt[i] <= 3'd0;
        queue[i]       <= 3'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          max_sum   <= 5'd0;
          sum_accum <= 5'd0;

          if (start) begin
            // Initialize for BFS
            root       <= 3'd0; // fixed root at node 0
            q_head     <= 3'd0;
            q_tail     <= 3'd0;
            bfs_idx    <= 2'd0;

            // Clear visited, parent, subtree_cnt
            for (i = 0; i < 8; i = i + 1) begin
              visited[i]     <= 1'b0;
              parent[i]      <= 3'd7; // use 7 as 'no parent' (assuming root 0 valid)
              subtree_cnt[i] <= 3'd0;
            end

            // Compute total universities (up to 4)
            total_univ <= univ_mask[0] + univ_mask[1] + univ_mask[2] + univ_mask[3] +
                          univ_mask[4] + univ_mask[5] + univ_mask[6] + univ_mask[7];

            // Start BFS with root
            queue[0]    <= root;
            q_tail      <= 3'd1;
            visited[root] <= 1'b1;
            parent[root]  <= root;
            bfs_curr    <= root;
            bfs_idx     <= 2'd0;
          end
        end

        TRAVERSE: begin
          // BFS expansion: process neighbors of bfs_curr one per cycle
          if (bfs_idx < 2'd3) begin
            // Extract neighbor index from adj_list: 3 neighbors per node
            // adj_list indexing: for node N, neighbors at indices 3*N,3*N+1,3*N+2
            reg [2:0] neigh;
            reg [2:0] idx;
            idx = bfs_curr * 3 + bfs_idx;
            neigh = adj_list[idx];

            if (!visited[neigh] && neigh < node_count) begin
              visited[neigh] <= 1'b1;
              parent[neigh]  <= bfs_curr;
              queue[q_tail]  <= neigh;
              q_tail         <= q_tail + 3'd1;
            end
            bfs_idx <= bfs_idx + 2'd1;
          end else begin
            // Done with neighbors of current node, dequeue next
            if (q_head != q_tail) begin
              bfs_curr <= queue[q_head];
              q_head   <= q_head + 3'd1;
              bfs_idx  <= 2'd0;
            end
          end
        end

        COUNT_SUBTREES: begin
          // Initialize proc_node on entry from TRAVERSE
          if (state != next_state && next_state == COUNT_SUBTREES) begin
            // not used, handled below naturally
          end

          // On first cycle in COUNT_SUBTREES, set proc_node to last valid node
          if (proc_node == 3'd0) begin
            if (node_count != 3'd0)
              proc_node <= node_count - 3'd1;
          end else begin
            // Process current node: accumulate its own university and children's counts
            reg [2:0] cnt;
            integer j;
            cnt = (univ_mask[proc_node]) ? 3'd1 : 3'd0;
            for (j = 0; j < 8; j = j + 1) begin
              if (parent[j] == proc_node && j < node_count)
                cnt = cnt + subtree_cnt[j];
            end
            subtree_cnt[proc_node] <= cnt;

            if (proc_node > 3'd0)
              proc_node <= proc_node - 3'd1;
          end
        end

        CALC_SUM: begin
          // On first cycle in CALC_SUM, initialize proc_node to 0..node_count-1
          if (proc_node == 3'd0) begin
            if (node_count != 3'd0)
              proc_node <= node_count - 3'd1;
            sum_accum <= 5'd0;
          end else begin
            // For each node (except root), add min(subtree_cnt[node], total_univ - subtree_cnt[node])
            if (proc_node < node_count && parent[proc_node] != proc_node) begin
              reg [2:0] c;
              reg [2:0] other;
              reg [2:0] m;
              c     = subtree_cnt[proc_node];
              other = (total_univ > c) ? (total_univ - c) : 3'd0;
              m     = (c < other) ? c : other;
              sum_accum <= sum_accum + m;
            end

            if (proc_node > 3'd0)
              proc_node <= proc_node - 3'd1;
          end
        end

        FINISH: begin
          done    <= 1'b1;
          max_sum <= sum_accum;
          // Hold result until start is deasserted and IDLE is re-entered by FSM
        end

        default: begin
          // Should not occur; safe defaults
          done    <= 1'b0;
          max_sum <= 5'd0;
        end
      endcase
    end
  end

endmodule
