module min_data_centers(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  n,
  input       [3:0]  m,
  input       [2:0]  h,
  input       [7:0][2:0] u_array,
  input       [15:0][5:0] client_pairs,
  output reg  [2:0]  k,
  output reg  [7:0]  solution_set,
  output reg         done,
  output reg         valid
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    BUILD_GRAPH = 3'd1,
    FIND_SCCS   = 3'd2,
    CALC_OUTDEG = 3'd3,
    SELECT_SCC  = 3'd4,
    DONE_STATE  = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0][7:0] adj;            // adjacency matrix
  reg [2:0]      i_idx;          // loop index for nodes
  reg [2:0]      j_idx;          // loop index for nodes

  // Tarjan SCC variables
  reg [3:0] disc [7:0];          // discovery times (0 means unvisited)
  reg [3:0] low  [7:0];          // low-link values
  reg       on_stack [7:0];
  reg [2:0] stack_mem [7:0];
  reg [3:0] time_cnt;            // discovery time counter (1..8)
  reg [2:0] sp;                  // stack pointer (0..8)
  reg [2:0] cur_v;               // current vertex
  reg [2:0] dfs_child_idx [7:0]; // per-node child index for iterative DFS
  reg [2:0] scc_id [7:0];        // SCC id for each node
  reg [2:0] scc_cnt;             // number of SCCs (1..8)

  // Out-degree per SCC and size mask
  reg [7:0] scc_mask    [7:0];   // bitmask of nodes in each SCC-id
  reg [3:0] scc_size    [7:0];   // size of each SCC
  reg [3:0] scc_outdeg  [7:0];   // out-degree (in SCC graph)

  // Internal control
  reg [7:0] node_active_mask;    // mask for nodes 1..n

  // 256-cycle latency control
  reg [7:0] cycle_cnt;

  // Helper wires
  integer ii, jj;

  // Next state logic (simple pipeline progression)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = BUILD_GRAPH;
      end
      BUILD_GRAPH: begin
        next_state = FIND_SCCS;
      end
      FIND_SCCS: begin
        next_state = CALC_OUTDEG;
      end
      CALC_OUTDEG: begin
        next_state = SELECT_SCC;
      end
      SELECT_SCC: begin
        next_state = DONE_STATE;
      end
      DONE_STATE: begin
        // Remain in DONE_STATE; done/valid held until reset
        next_state = DONE_STATE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      k             <= 3'd0;
      solution_set  <= 8'd0;
      done          <= 1'b0;
      valid         <= 1'b0;
      cycle_cnt     <= 8'd0;
      node_active_mask <= 8'd0;

      for (ii = 0; ii < 8; ii = ii + 1) begin
        for (jj = 0; jj < 8; jj = jj + 1) begin
          adj[ii][jj] <= 1'b0;
        end
        disc[ii]         <= 4'd0;
        low[ii]          <= 4'd0;
        on_stack[ii]     <= 1'b0;
        stack_mem[ii]    <= 3'd0;
        dfs_child_idx[ii]<= 3'd0;
        scc_id[ii]       <= 3'd0;
        scc_mask[ii]     <= 8'd0;
        scc_size[ii]     <= 4'd0;
        scc_outdeg[ii]   <= 4'd0;
      end
      time_cnt <= 4'd0;
      sp       <= 3'd0;
      cur_v    <= 3'd0;
      scc_cnt  <= 3'd0;
      i_idx    <= 3'd0;
      j_idx    <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done         <= 1'b0;
          valid        <= 1'b0;
          cycle_cnt    <= 8'd0;

          // Initialize basic structures on start edge
          if (start) begin
            // Active nodes mask (1..n) mapped to bits [0..n-1]
            node_active_mask <= (n == 3'd0) ? 8'd0 : ((8'hFF >> (8 - n)));

            // Clear adjacency and SCC-related data
            for (ii = 0; ii < 8; ii = ii + 1) begin
              for (jj = 0; jj < 8; jj = jj + 1) begin
                adj[ii][jj] <= 1'b0;
              end
              disc[ii]          <= 4'd0;
              low[ii]           <= 4'd0;
              on_stack[ii]      <= 1'b0;
              stack_mem[ii]     <= 3'd0;
              dfs_child_idx[ii] <= 3'd0;
              scc_id[ii]        <= 3'd0;
              scc_mask[ii]      <= 8'd0;
              scc_size[ii]      <= 4'd0;
              scc_outdeg[ii]    <= 4'd0;
            end
            time_cnt <= 4'd0;
            sp       <= 3'd0;
            cur_v    <= 3'd0;
            scc_cnt  <= 3'd0;
            i_idx    <= 3'd0;
            j_idx    <= 3'd0;
          end
        end

        BUILD_GRAPH: begin
          // Build directed graph: edge A->B if ((u_A + 1) % h) == u_B
          // Only for A,B within [1..n]; zero-based index 0..n-1
          for (ii = 0; ii < 8; ii = ii + 1) begin
            for (jj = 0; jj < 8; jj = jj + 1) begin
              adj[ii][jj] <= 1'b0;
            end
          end

          for (ii = 0; ii < 8; ii = ii + 1) begin
            if (ii < n) begin
              for (jj = 0; jj < 8; jj = jj + 1) begin
                if (jj < n) begin
                  if (((u_array[ii] + 3'd1) % h) == u_array[jj]) begin
                    adj[ii][jj] <= 1'b1;
                  end else begin
                    adj[ii][jj] <= adj[ii][jj];
                  end
                end
              end
            end
          end

          // client_pairs are provided; per instructions, only modulo relationship matters
          // when both data centers exist. The base edge rule already encodes time relation,
          // so no extra edges are added here.
        end

        FIND_SCCS: begin
          // Iterative Tarjan SCC over all active nodes
          // For simplicity, perform full procedure in this state combinationally per cycle.
          // Since n <= 8, this is manageable.

          // If not yet started (time_cnt == 0), initialize and run
          if (time_cnt == 4'd0) begin
            // Initialize structures
            for (ii = 0; ii < 8; ii = ii + 1) begin
              disc[ii]          <= 4'd0;
              low[ii]           <= 4'd0;
              on_stack[ii]      <= 1'b0;
              dfs_child_idx[ii] <= 3'd0;
            end
            sp      <= 3'd0;
            time_cnt<= 4'd0;
            scc_cnt <= 3'd0;

            // Run Tarjan iteratively for all vertices
            // Note: encoded sequentially in this clock; in hardware this is large combinational,
            // but allowed by constraints.
            for (ii = 0; ii < 8; ii = ii + 1) begin
              if (ii < n) begin
                if (disc[ii] == 4'd0) begin
                  // Start DFS at ii
                  // Push ii
                  stack_mem[sp] <= ii[2:0];
                  sp            <= sp + 3'd1;
                  disc[ii]      <= time_cnt + 4'd1;
                  low[ii]       <= time_cnt + 4'd1;
                  time_cnt      <= time_cnt + 4'd1;
                  on_stack[ii]  <= 1'b1;
                  dfs_child_idx[ii] <= 3'd0;

                  // Main DFS loop (unrolled small bounds)
                  // Bounded to handle up to 8 nodes safely
                  for (jj = 0; jj < 32; jj = jj + 1) begin : DFS_LOOP
                    if (sp != 3'd0) begin
                      cur_v = stack_mem[sp-1];
                      // Explore children from dfs_child_idx[cur_v]
                      if (dfs_child_idx[cur_v] < n) begin
                        if (adj[cur_v][dfs_child_idx[cur_v]]) begin
                          if (disc[dfs_child_idx[cur_v]] == 4'd0) begin
                            // Tree edge: push child
                            stack_mem[sp] <= dfs_child_idx[cur_v][2:0];
                            sp            <= sp + 3'd1;
                            disc[dfs_child_idx[cur_v]] <= time_cnt + 4'd1;
                            low[dfs_child_idx[cur_v]]  <= time_cnt + 4'd1;
                            time_cnt                   <= time_cnt + 4'd1;
                            on_stack[dfs_child_idx[cur_v]] <= 1'b1;
                            dfs_child_idx[dfs_child_idx[cur_v]] <= 3'd0;
                            dfs_child_idx[cur_v] <= dfs_child_idx[cur_v] + 3'd1;
                          end else if (on_stack[dfs_child_idx[cur_v]]) begin
                            // Back edge
                            if (low[cur_v] > disc[dfs_child_idx[cur_v]])
                              low[cur_v] <= disc[dfs_child_idx[cur_v]];
                            dfs_child_idx[cur_v] <= dfs_child_idx[cur_v] + 3'd1;
                          end else begin
                            dfs_child_idx[cur_v] <= dfs_child_idx[cur_v] + 3'd1;
                          end
                        end else begin
                          dfs_child_idx[cur_v] <= dfs_child_idx[cur_v] + 3'd1;
                        end
                      end else begin
                        // Finished children of cur_v, pop if root of SCC
                        if (low[cur_v] == disc[cur_v]) begin
                          // New SCC
                          scc_cnt <= scc_cnt + 3'd1;
                          // Pop stack until cur_v
                          for (ii = 0; ii < 8; ii = ii + 1) begin
                            // use local loop variable
                          end
                          // Explicit controlled pop
                          begin : POP_LOOP
                            reg [2:0] w;
                            while (sp != 3'd0) begin
                              w = stack_mem[sp-1];
                              sp = sp - 3'd1;
                              on_stack[w] = 1'b0;
                              scc_id[w]   = scc_cnt + 3'd1;
                              if (w == cur_v)
                                disable POP_LOOP;
                            end
                          end
                        end
                        // Update parent's low if applicable
                        if (sp != 3'd0) begin
                          // Parent is stack_mem[sp-1]
                          if (low[stack_mem[sp-1]] > low[cur_v])
                            low[stack_mem[sp-1]] <= low[cur_v];
                        end
                        // Done with cur_v
                      end
                    end else begin
                      disable DFS_LOOP;
                    end
                  end
                end
              end
            end

            // Build SCC masks and sizes based on scc_id
            for (ii = 0; ii < 8; ii = ii + 1) begin
              scc_mask[ii] <= 8'd0;
              scc_size[ii] <= 4'd0;
            end
            for (ii = 0; ii < 8; ii = ii + 1) begin
              if (ii < n) begin
                if (scc_id[ii] != 3'd0) begin
                  scc_mask[scc_id[ii]-1][ii] <= 1'b1;
                  scc_size[scc_id[ii]-1]     <= scc_size[scc_id[ii]-1] + 4'd1;
                end
              end
            end
          end
        end

        CALC_OUTDEG: begin
          // Compute SCC out-degree in SCC graph
          for (ii = 0; ii < 8; ii = ii + 1) begin
            scc_outdeg[ii] <= 4'd0;
          end

          for (ii = 0; ii < 8; ii = ii + 1) begin
            if (ii < n) begin
              for (jj = 0; jj < 8; jj = jj + 1) begin
                if (jj < n && adj[ii][jj]) begin
                  if (scc_id[ii] != scc_id[jj]) begin
                    if (scc_id[ii] != 3'd0) begin
                      scc_outdeg[scc_id[ii]-1] <= scc_outdeg[scc_id[ii]-1] + 4'd1;
                    end
                  end
                end
              end
            end
          end
        end

        SELECT_SCC: begin
          // Select smallest SCC with zero out-degree
          reg [2:0] best_scc_idx;
          reg [3:0] best_size;
          reg       found;

          best_scc_idx = 3'd0;
          best_size    = 4'd15; // larger than max (8)
          found        = 1'b0;

          for (ii = 0; ii < 8; ii = ii + 1) begin
            if (scc_size[ii] != 4'd0) begin
              if (scc_outdeg[ii] == 4'd0) begin
                if (!found || (scc_size[ii] < best_size)) begin
                  found        = 1'b1;
                  best_size    = scc_size[ii];
                  best_scc_idx = ii[2:0];
                end
              end
            end
          end

          if (found) begin
            k            <= best_size[2:0];
            solution_set <= scc_mask[best_scc_idx];
            valid        <= 1'b1;
          end else begin
            k            <= 3'd0;
            solution_set <= 8'd0;
            valid        <= 1'b0;
          end
        end

        DONE_STATE: begin
          // Maintain 256-cycle latency from start to done assertion
          if (!done) begin
            cycle_cnt <= cycle_cnt + 8'd1;
            if (cycle_cnt == 8'd255) begin
              done <= 1'b1;
            end
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule