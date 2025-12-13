module conveyor_scheduler(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [1:0] K,
  input [3:0] M,
  input [15:0][1:0] edges,
  output reg [1:0] max_producers,
  output reg done
);

  // State encoding
  localparam IDLE           = 3'd0;
  localparam FIND_PATHS     = 3'd1;
  localparam CHECK_CONFLICTS= 3'd2;
  localparam CALC_RESULT    = 3'd3;
  localparam DONE           = 3'd4;

  reg [2:0] state, next_state;

  // 64-cycle timing counter after start
  reg [5:0] cycle_cnt;

  // Internal parameters
  // Max producers = 4, label them 1..K, node indices 1..N, warehouse = N.
  // Represent path for each producer as sequence of edge indices.

  // Path storage: up to 8 nodes => max 7 edges per path, store 4 bits per edge index.
  reg [3:0] path_edges   [0:3][0:6]; // [producer][step]
  reg [2:0] path_len     [0:3];      // length for each producer
  reg       path_valid   [0:3];

  // Belt usage schedule per producer as 16-bit mask for belts (M<=16)
  // If producer p uses belt b at any slot in its schedule, schedule[p][b]==1
  // (Simplified model to fit hardware: single-use per belt assumed.)
  reg [15:0] belt_mask   [0:3];

  // Internal indices
  reg [1:0] cur_prod;      // 0..3 (producer index = cur_prod+1)
  reg [3:0] cur_edge;      // edge index 0..15
  reg [2:0] bfs_front;     // BFS queue front pointer
  reg [2:0] bfs_back;      // BFS queue back pointer
  reg [2:0] bfs_queue [0:7];
  reg [2:0] parent    [0:7]; // parent node for BFS reconstruction
  reg       visited   [0:7];

  // For reconstruction / iteration
  reg [2:0] recon_node;
  reg [2:0] recon_idx;

  // temporary wires/regs
  integer i, j;

  // Extract edge endpoints from packed edges input
  // edges[e][1]: upper 3 bits = a, lower 3 bits = b (we assume encoding)
  wire [2:0] edge_a [0:15];
  wire [2:0] edge_b [0:15];
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : EDGE_UNPACK
      assign edge_a[gi] = {1'b0, edges[gi][1][1:0]}; // placeholder decode
      assign edge_b[gi] = {1'b0, edges[gi][0][1:0]}; // placeholder decode
    end
  endgenerate

  // Simple placeholder belt index: use edge index directly (0..15)

  // Conflict-free subset calculation
  // We'll compute all subsets of producers (up to 4 => 16 subsets), track max size
  reg [3:0] subset;
  reg [1:0] subset_size;
  reg [15:0] subset_belts;
  reg        subset_ok;

  // Sequential state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Cycle counter for 64-cycle latency
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 6'd0;
    end else begin
      if (state == IDLE && start)
        cycle_cnt <= 6'd0;
      else if (state != IDLE && state != DONE)
        cycle_cnt <= cycle_cnt + 6'd1;
      else if (state == DONE)
        cycle_cnt <= cycle_cnt;
    end
  end

  // Main FSM next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = FIND_PATHS;
      end
      FIND_PATHS: begin
        // After we processed all producers, move on
        if (cur_prod >= K && K != 2'd0)
          next_state = CHECK_CONFLICTS;
        else if (K == 2'd0)
          next_state = CALC_RESULT;
      end
      CHECK_CONFLICTS: begin
        // after subsets evaluated move to CALC_RESULT
        if (subset == 4'b1111)
          next_state = CALC_RESULT;
      end
      CALC_RESULT: begin
        // Ensure total latency >= 64 cycles from start
        if (cycle_cnt >= 6'd63)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Control and datapath
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_producers <= 2'd0;
      done <= 1'b0;
      cur_prod <= 2'd0;
      cur_edge <= 4'd0;
      subset <= 4'd0;
      subset_size <= 2'd0;
      subset_belts <= 16'd0;
      subset_ok <= 1'b0;
      for (i = 0; i < 4; i = i + 1) begin
        path_len[i] <= 3'd0;
        path_valid[i] <= 1'b0;
        belt_mask[i] <= 16'd0;
      end
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          max_producers <= 2'd0;
          cur_prod <= 2'd0;
          subset <= 4'd0;
          subset_size <= 2'd0;
          subset_belts <= 16'd0;
          subset_ok <= 1'b0;
          for (i = 0; i < 4; i = i + 1) begin
            path_len[i] <= 3'd0;
            path_valid[i] <= 1'b0;
            belt_mask[i] <= 16'd0;
          end
        end

        // FIND_PATHS: simplified BFS per producer from source=p+1 to dest=N
        FIND_PATHS: begin
          if (cur_prod < K) begin
            // Initialize BFS once per producer when first entering for that producer
            if (!path_valid[cur_prod]) begin
              // Clear visited and parents
              for (i = 0; i < 8; i = i + 1) begin
                visited[i] <= 1'b0;
                parent[i] <= 3'd7; // invalid
              end
              // Source node = producer index + 1 (1-based), assume <= N
              bfs_front <= 3'd0;
              bfs_back <= 3'd1;
              bfs_queue[0] <= {2'd0, cur_prod} + 3'd1; // src = cur_prod+1
              visited[{2'd0, cur_prod} + 3'd1] <= 1'b1;
            end else begin
              // Already have path, move to next producer
              cur_prod <= cur_prod + 2'd1;
            end

            // Run a small BFS step each cycle (not fully accurate, simplified)
            if (bfs_front < bfs_back && !path_valid[cur_prod]) begin
              reg [2:0] u;
              u = bfs_queue[bfs_front];
              bfs_front <= bfs_front + 3'd1;
              // Explore edges
              for (j = 0; j < 16; j = j + 1) begin
                if (j < M) begin
                  if (edge_a[j] == u && !visited[edge_b[j]]) begin
                    visited[edge_b[j]] <= 1'b1;
                    parent[edge_b[j]] <= u;
                    bfs_queue[bfs_back] <= edge_b[j];
                    bfs_back <= bfs_back + 3'd1;
                  end
                  if (edge_b[j] == u && !visited[edge_a[j]]) begin
                    visited[edge_a[j]] <= 1'b1;
                    parent[edge_a[j]] <= u;
                    bfs_queue[bfs_back] <= edge_a[j];
                    bfs_back <= bfs_back + 3'd1;
                  end
                end
              end
              // Check if destination reached
              if (visited[N]) begin
                // Reconstruct path from N back to src
                recon_node <= N;
                recon_idx <= 3'd0;
                // Simple reconstruction (limited steps loop)
                for (i = 0; i < 7; i = i + 1) begin
                  if (recon_node != ({2'd0, cur_prod} + 3'd1) && parent[recon_node] != 3'd7) begin
                    // Find edge index between recon_node and parent[recon_node]
                    for (j = 0; j < 16; j = j + 1) begin
                      if (j < M) begin
                        if ((edge_a[j] == recon_node && edge_b[j] == parent[recon_node]) ||
                            (edge_b[j] == recon_node && edge_a[j] == parent[recon_node])) begin
                          path_edges[cur_prod][recon_idx] <= j[3:0];
                          recon_idx <= recon_idx + 3'd1;
                        end
                      end
                    end
                    recon_node <= parent[recon_node];
                  end
                end
                path_len[cur_prod] <= recon_idx;
                path_valid[cur_prod] <= 1'b1;
                // Derive belt usage mask: mark all belts on shortest path
                belt_mask[cur_prod] <= 16'd0;
                for (i = 0; i < 7; i = i + 1) begin
                  if (i < recon_idx)
                    belt_mask[cur_prod][path_edges[cur_prod][i]] <= 1'b1;
                end
              end
            end
          end
        end

        // CHECK_CONFLICTS: search all subsets of producers for conflict-free max
        CHECK_CONFLICTS: begin
          // Iterate subsets from 1 to (1<<K)-1; subset register iterates each cycle
          if (subset < (4'b0001 << K)) begin
            subset <= subset + 4'd1;

            // Evaluate subset from previous value (subset-1)
            subset_belts <= 16'd0;
            subset_size <= 2'd0;
            subset_ok <= 1'b1;
            for (i = 0; i < 4; i = i + 1) begin
              if ( (subset[i]) && (i < K) && path_valid[i]) begin
                if ((subset_belts & belt_mask[i]) != 16'd0)
                  subset_ok <= 1'b0;
                subset_belts <= subset_belts | belt_mask[i];
                subset_size <= subset_size + 2'd1;
              end
            end
            if (subset_ok && subset_size > max_producers)
              max_producers <= subset_size;
          end
        end

        CALC_RESULT: begin
          // Nothing additional; result already in max_producers
        end

        DONE: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule