module max_road_counter(
  input clk,
  input rst_n,
  input start,
  input [63:0] adjacency_matrix,
  input [4:0] current_road_count,
  output reg [5:0] max_new_roads,
  output reg done
);

  // Parameters
  localparam N = 8;
  localparam IDX_W = 3;
  localparam DEPTH_W = 4;

  // Internal storage
  reg [63:0] adj_reg;          // Latched adjacency matrix
  reg [7:0]  n_reg;            // number of nodes (fixed 8)

  // Tarjan SCC variables (for up to 8 nodes)
  reg [DEPTH_W-1:0] index [0:N-1];
  reg [DEPTH_W-1:0] lowlink [0:N-1];
  reg onstack [0:N-1];
  reg visited [0:N-1];
  reg [IDX_W-1:0] stack [0:N-1];
  reg [DEPTH_W-1:0] sp;        // stack pointer

  // DFS explicit stack for Tarjan
  typedef struct packed {
    logic [1:0] state;         // 0:enter,1:explore,2:retreat
    logic [IDX_W-1:0] v;
    logic [IDX_W-1:0] w;
  } dfs_frame_t;

  dfs_frame_t dfs_stack [0:N*4-1]; // Sufficient depth for 8 nodes
  reg [5:0] dfs_sp;                // pointer for dfs_stack

  reg [DEPTH_W-1:0] index_counter;
  reg [3:0] scc_id_counter;        // up to 8 SCCs
  reg [IDX_W-1:0] comp_label [0:N-1];
  reg [3:0] comp_size [0:N-1];

  // Edge counting
  reg [5:0] internal_edges [0:N-1];      // edges within each SCC
  reg [5:0] cross_edges;                 // existing cross-SCC edges

  // Control FSM
  typedef enum logic [4:0] {
    S_IDLE          = 5'd0,
    S_LATCH         = 5'd1,
    S_INIT_TARJAN   = 5'd2,
    S_TARJAN_LOOP   = 5'd3,
    S_TARJAN_STEP   = 5'd4,
    S_TARJAN_DONE   = 5'd5,
    S_INIT_EDGES    = 5'd6,
    S_COUNT_EDGES   = 5'd7,
    S_SUM_SCC       = 5'd8,
    S_COMPUTE       = 5'd9,
    S_DONE          = 5'd10,
    S_WAIT_LATENCY  = 5'd11
  } state_t;

  state_t state, next_state;

  // Cycle counter to align to 20-cycle latency
  reg [4:0] cycle_cnt;

  // Iteration indices
  reg [3:0] i_node;
  reg [3:0] j_node;
  reg [3:0] k_scc;

  // Accumulators
  reg [9:0] sum_s_sq;          // sum of s^2, max 8*(8^2)=512
  reg [9:0] total_possible;    // up to 56
  reg [9:0] adj_internal;      // sum internal_edges

  // Helper function: adjacency bit
  function automatic logic adj_bit(
    input [63:0] mat,
    input [2:0] r,
    input [2:0] c
  );
    adj_bit = mat[{r,3'b000} + c];
  endfunction

  // Next state logic & cycle counter control
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LATCH;
      end

      S_LATCH: begin
        next_state = S_INIT_TARJAN;
      end

      S_INIT_TARJAN: begin
        next_state = S_TARJAN_LOOP;
      end

      S_TARJAN_LOOP: begin
        // If DFS stack not empty, process Tarjan
        if (dfs_sp != 0)
          next_state = S_TARJAN_STEP;
        else begin
          // Check if any unvisited node remains, else done
          if (i_node < N)
            next_state = S_TARJAN_LOOP;
          else
            next_state = S_TARJAN_DONE;
        end
      end

      S_TARJAN_STEP: begin
        // Continue Tarjan until stack empty
        if (dfs_sp != 0)
          next_state = S_TARJAN_STEP;
        else
          next_state = S_TARJAN_LOOP;
      end

      S_TARJAN_DONE: begin
        next_state = S_INIT_EDGES;
      end

      S_INIT_EDGES: begin
        next_state = S_COUNT_EDGES;
      end

      S_COUNT_EDGES: begin
        if (i_node == N && j_node == N)
          next_state = S_SUM_SCC;
      end

      S_SUM_SCC: begin
        if (k_scc == scc_id_counter)
          next_state = S_COMPUTE;
      end

      S_COMPUTE: begin
        next_state = S_WAIT_LATENCY;
      end

      S_WAIT_LATENCY: begin
        if (cycle_cnt == 5'd19)
          next_state = S_DONE;
      end

      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer u,v;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      max_new_roads <= 6'd0;
      adj_reg <= 64'd0;
      n_reg <= N;
      cycle_cnt <= 5'd0;
      // Clear Tarjan structures
      for (u = 0; u < N; u = u + 1) begin
        index[u] <= 0;
        lowlink[u] <= 0;
        onstack[u] <= 1'b0;
        visited[u] <= 1'b0;
        comp_label[u] <= 0;
        comp_size[u] <= 0;
        internal_edges[u] <= 0;
      end
      cross_edges <= 0;
      sp <= 0;
      dfs_sp <= 0;
      index_counter <= 0;
      scc_id_counter <= 0;
      i_node <= 0;
      j_node <= 0;
      k_scc <= 0;
      sum_s_sq <= 0;
      total_possible <= 0;
      adj_internal <= 0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          cycle_cnt <= 5'd0;
          if (start) begin
            // prepare to latch inputs
          end
        end

        S_LATCH: begin
          // Latch adjacency matrix
          adj_reg <= adjacency_matrix;
          // Init counters
          index_counter <= 0;
          scc_id_counter <= 0;
          sp <= 0;
          dfs_sp <= 0;
          // Clear Tarjan meta
          for (u = 0; u < N; u = u + 1) begin
            index[u] <= 0;
            lowlink[u] <= 0;
            onstack[u] <= 1'b0;
            visited[u] <= 1'b0;
            comp_label[u] <= 0;
            comp_size[u] <= 0;
          end
          i_node <= 0;
        end

        S_INIT_TARJAN: begin
          // Start DFS from node 0 if needed in loop
          // No-op here; loop handled in S_TARJAN_LOOP
        end

        S_TARJAN_LOOP: begin
          // If dfs stack empty, pick next unvisited node and push initial frame
          if (dfs_sp == 0) begin
            if (i_node < N) begin
              if (!visited[i_node]) begin
                // push enter frame for node i_node
                dfs_stack[dfs_sp].state <= 2'd0;
                dfs_stack[dfs_sp].v <= i_node[IDX_W-1:0];
                dfs_stack[dfs_sp].w <= 3'd0;
                dfs_sp <= dfs_sp + 1;
              end
              i_node <= i_node + 1;
            end
          end
        end

        S_TARJAN_STEP: begin
          if (dfs_sp != 0) begin
            dfs_frame_t frame;
            frame = dfs_stack[dfs_sp-1];
            dfs_sp <= dfs_sp - 1;

            case (frame.state)
              2'd0: begin // enter v
                if (!visited[frame.v]) begin
                  visited[frame.v] <= 1'b1;
                  index[frame.v] <= index_counter;
                  lowlink[frame.v] <= index_counter;
                  index_counter <= index_counter + 1;
                  stack[sp] <= frame.v;
                  sp <= sp + 1;
                  onstack[frame.v] <= 1'b1;
                end
                // push retreat frame
                dfs_stack[dfs_sp].state <= 2'd2;
                dfs_stack[dfs_sp].v <= frame.v;
                dfs_stack[dfs_sp].w <= frame.w;
                dfs_sp <= dfs_sp + 1;
                // push explore frame to iterate neighbors
                dfs_stack[dfs_sp].state <= 2'd1;
                dfs_stack[dfs_sp].v <= frame.v;
                dfs_stack[dfs_sp].w <= 3'd0;
                dfs_sp <= dfs_sp + 1;
              end

              2'd1: begin // explore neighbors of v
                if (frame.w < N[IDX_W-1:0]) begin
                  if (adj_bit(adj_reg, frame.v, frame.w)) begin
                    if (!visited[frame.w]) begin
                      // push continue-explore for v with next w
                      dfs_stack[dfs_sp].state <= 2'd1;
                      dfs_stack[dfs_sp].v <= frame.v;
                      dfs_stack[dfs_sp].w <= frame.w + 1;
                      dfs_sp <= dfs_sp + 1;
                      // push enter for w
                      dfs_stack[dfs_sp].state <= 2'd0;
                      dfs_stack[dfs_sp].v <= frame.w;
                      dfs_stack[dfs_sp].w <= 3'd0;
                      dfs_sp <= dfs_sp + 1;
                    end else if (onstack[frame.w]) begin
                      // lowlink[v] = min(lowlink[v], index[w])
                      if (lowlink[frame.v] > index[frame.w])
                        lowlink[frame.v] <= index[frame.w];
                      // continue exploring
                      dfs_stack[dfs_sp].state <= 2'd1;
                      dfs_stack[dfs_sp].v <= frame.v;
                      dfs_stack[dfs_sp].w <= frame.w + 1;
                      dfs_sp <= dfs_sp + 1;
                    end else begin
                      // visited but not on stack, ignore; continue
                      dfs_stack[dfs_sp].state <= 2'd1;
                      dfs_stack[dfs_sp].v <= frame.v;
                      dfs_stack[dfs_sp].w <= frame.w + 1;
                      dfs_sp <= dfs_sp + 1;
                    end
                  end else begin
                    // no edge, move to next neighbor
                    dfs_stack[dfs_sp].state <= 2'd1;
                    dfs_stack[dfs_sp].v <= frame.v;
                    dfs_stack[dfs_sp].w <= frame.w + 1;
                    dfs_sp <= dfs_sp + 1;
                  end
                end
                // if w >= N, done exploring; rely on retreat frame
              end

              2'd2: begin // retreat v
                // update lowlink with children already handled via explore
                // If root of SCC
                if (lowlink[frame.v] == index[frame.v]) begin
                  // Pop stack until v
                  reg [IDX_W-1:0] w_pop;
                  reg [3:0] scc_size;
                  scc_size = 0;
                  if (sp != 0) begin
                    w_pop = stack[sp-1];
                    sp <= sp - 1;
                    onstack[w_pop] <= 1'b0;
                    comp_label[w_pop] <= scc_id_counter[IDX_W-1:0];
                    scc_size = scc_size + 1;
                    while (w_pop != frame.v && sp != 0) begin
                      w_pop = stack[sp-1];
                      sp <= sp - 1;
                      onstack[w_pop] <= 1'b0;
                      comp_label[w_pop] <= scc_id_counter[IDX_W-1:0];
                      scc_size = scc_size + 1;
                    end
                  end
                  comp_size[scc_id_counter] <= scc_size;
                  scc_id_counter <= scc_id_counter + 1;
                end else begin
                  // propagate lowlink to parent if needed will be handled
                  // via lowlink updates during exploration
                end
              end

              default: ;
            endcase
          end
        end

        S_TARJAN_DONE: begin
          // Initialize edge counters
          for (u = 0; u < N; u = u + 1) begin
            internal_edges[u] <= 0;
          end
          cross_edges <= 0;
          i_node <= 0;
          j_node <= 0;
        end

        S_INIT_EDGES: begin
          // nothing extra; move to counting
        end

        S_COUNT_EDGES: begin
          if (i_node < N) begin
            if (j_node < N) begin
              if (adj_bit(adj_reg, i_node[2:0], j_node[2:0])) begin
                if (comp_label[i_node] == comp_label[j_node]) begin
                  internal_edges[comp_label[i_node]] <= internal_edges[comp_label[i_node]] + 1;
                end else begin
                  cross_edges <= cross_edges + 1;
                end
              end
              j_node <= j_node + 1;
            end else begin
              j_node <= 0;
              i_node <= i_node + 1;
            end
          end
        end

        S_SUM_SCC: begin
          if (k_scc == 0) begin
            sum_s_sq <= 0;
            adj_internal <= 0;
          end
          if (k_scc < scc_id_counter) begin
            reg [3:0] s;
            reg [7:0] s_sq;
            s = comp_size[k_scc];
            s_sq = s * s;
            sum_s_sq <= sum_s_sq + s_sq;
            adj_internal <= adj_internal + internal_edges[k_scc];
            k_scc <= k_scc + 1;
          end
        end

        S_COMPUTE: begin
          // total_possible = n*(n-1) - current_road_count
          total_possible <= (N * (N - 1)) - current_road_count;
          // Formula interpretation used:
          // max_new = total_possible
          //           - (sum_s_sq - adj_internal)
          //           - cross_edges
          // Clamp to 0..63
          begin
            reg [10:0] tmp;
            tmp = ((N * (N - 1)) - current_road_count)
                  - (sum_s_sq - adj_internal)
                  - cross_edges;
            if ($signed(tmp) < 0)
              max_new_roads <= 6'd0;
            else if (tmp > 11'd63)
              max_new_roads <= 6'd63;
            else
              max_new_roads <= tmp[5:0];
          end
          cycle_cnt <= 5'd0;
        end

        S_WAIT_LATENCY: begin
          if (cycle_cnt < 5'd31)
            cycle_cnt <= cycle_cnt + 1;
        end

        S_DONE: begin
          done <= 1'b1;
          if (!start) begin
            done <= 1'b0;
          end
        end

        default: ;
      endcase
    end
  end

endmodule