module max_stable_edges(
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] gov_count,
  input [3:0] gov_list [0:3],
  input [6:0] edge_count,
  input [15:0] edge_mask [0:15],
  output reg [6:0] max_edges,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE             = 3'd0,
    COMPONENT_SEARCH = 3'd1,
    SIZE_CALC        = 3'd2,
    RESULT_CALC      = 3'd3,
    DONE_STATE       = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] visited;                 // visited flags for 16 nodes
  reg [4:0] dfs_stack [0:6];          // depth-limited DFS stack (7 entries)
  reg [2:0] sp;                       // stack pointer (0-7)
  reg [3:0] dfs_neighbor_idx;         // neighbor index 0-15
  reg [4:0] dfs_curr_node;            // current DFS node (0-15)
  reg [2:0] gov_idx;                  // index over gov_list
  reg [3:0] root_node;                // current component root (government node)

  reg [4:0] comp_size   [0:3];        // size of each government component
  reg [6:0] comp_edges  [0:3];        // edges inside each government component
  reg [1:0] comp_cnt;                 // number of valid components

  reg [4:0] curr_comp_size;
  reg [6:0] curr_comp_edges;
  reg [3:0] i_node;                   // general iteration index for nodes

  // Bookkeeping for DFS step
  reg dfs_active;                     // indicates DFS in progress for current component

  // Registers for RESULT_CALC
  reg [6:0] total_edges_possible;     // Σ(size_i*(size_i-1)/2)
  reg [6:0] largest_size;
  reg [1:0] largest_idx;
  reg [4:0] total_comp_nodes;
  reg [4:0] remaining_nodes;
  reg [6:0] cross_edges;
  reg [6:0] sum_comp_possible_edges;  // Σ(size_i*(size_i-1)/2)
  reg [6:0] sum_comp_real_edges;      // Σ(comp_edges[i])

  integer k;

  // Sequential state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      visited                 <= 16'd0;
      gov_idx                 <= 3'd0;
      comp_cnt                <= 2'd0;
      for (k = 0; k < 4; k = k + 1) begin
        comp_size[k]          <= 5'd0;
        comp_edges[k]         <= 7'd0;
      end
      curr_comp_size          <= 5'd0;
      curr_comp_edges         <= 7'd0;
      i_node                  <= 4'd0;
      dfs_neighbor_idx        <= 4'd0;
      dfs_curr_node           <= 5'd0;
      sp                      <= 3'd0;
      dfs_active              <= 1'b0;
      root_node               <= 4'd0;
      total_edges_possible    <= 7'd0;
      largest_size            <= 7'd0;
      largest_idx             <= 2'd0;
      total_comp_nodes        <= 5'd0;
      remaining_nodes         <= 5'd0;
      cross_edges             <= 7'd0;
      sum_comp_possible_edges <= 7'd0;
      sum_comp_real_edges     <= 7'd0;
      max_edges               <= 7'd0;
      done                    <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for new run
            visited                 <= 16'd0;
            gov_idx                 <= 3'd0;
            comp_cnt                <= 2'd0;
            for (k = 0; k < 4; k = k + 1) begin
              comp_size[k]          <= 5'd0;
              comp_edges[k]         <= 7'd0;
            end
            curr_comp_size          <= 5'd0;
            curr_comp_edges         <= 7'd0;
            i_node                  <= 4'd0;
            dfs_neighbor_idx        <= 4'd0;
            dfs_curr_node           <= 5'd0;
            sp                      <= 3'd0;
            dfs_active              <= 1'b0;
            root_node               <= 4'd0;
            total_edges_possible    <= 7'd0;
            largest_size            <= 7'd0;
            largest_idx             <= 2'd0;
            total_comp_nodes        <= 5'd0;
            remaining_nodes         <= 5'd0;
            cross_edges             <= 7'd0;
            sum_comp_possible_edges <= 7'd0;
            sum_comp_real_edges     <= 7'd0;
            max_edges               <= 7'd0;
          end
        end

        COMPONENT_SEARCH: begin
          // Perform DFS per government to find its connected component
          if (!dfs_active) begin
            // Start DFS for next government if any remain
            if ((gov_idx < gov_count) && (gov_idx < 4)) begin
              root_node <= gov_list[gov_idx];
              if ((gov_list[gov_idx] < node_count) && !visited[gov_list[gov_idx]]) begin
                // Initialize DFS for this component
                dfs_active       <= 1'b1;
                sp               <= 3'd1;
                dfs_stack[0]     <= gov_list[gov_idx];
                dfs_curr_node    <= gov_list[gov_idx];
                dfs_neighbor_idx <= 4'd0;
                visited[gov_list[gov_idx]] <= 1'b1;
                curr_comp_size   <= 5'd1;
                curr_comp_edges  <= 7'd0;
              end else begin
                // Either invalid or already visited, move to next government
                gov_idx <= gov_idx + 3'd1;
              end
            end
          end else begin
            // DFS active: explore neighbors of current node with limited depth
            if (dfs_neighbor_idx < node_count) begin
              // Check edge from dfs_curr_node to dfs_neighbor_idx
              if (edge_mask[dfs_curr_node][dfs_neighbor_idx]) begin
                curr_comp_edges <= curr_comp_edges + 7'd1;
                if (!visited[dfs_neighbor_idx]) begin
                  visited[dfs_neighbor_idx] <= 1'b1;
                  curr_comp_size           <= curr_comp_size + 5'd1;
                  if (sp < 3'd7) begin
                    dfs_stack[sp] <= dfs_neighbor_idx;
                    sp            <= sp + 3'd1;
                  end
                end
              end
              dfs_neighbor_idx <= dfs_neighbor_idx + 4'd1;
            end else begin
              // Done neighbors for current node; pop stack
              if (sp > 3'd1) begin
                sp               <= sp - 3'd1;
                dfs_curr_node    <= dfs_stack[sp - 3'd1];
                dfs_neighbor_idx <= 4'd0;
              end else begin
                // Stack empty or only root processed: finish this component
                dfs_active <= 1'b0;
                // Each undirected edge counted twice in adjacency scan
                comp_size[comp_cnt]  <= curr_comp_size;
                comp_edges[comp_cnt] <= curr_comp_edges >> 1;
                comp_cnt             <= comp_cnt + 2'd1;
                gov_idx              <= gov_idx + 3'd1;
              end
            end
          end
        end

        SIZE_CALC: begin
          // No additional traversal: just prepare aggregation
          // Compute sum_comp_possible_edges and sum_comp_real_edges, find largest
          sum_comp_possible_edges <= 7'd0;
          sum_comp_real_edges    <= 7'd0;
          largest_size           <= 7'd0;
          largest_idx            <= 2'd0;
          total_comp_nodes       <= 5'd0;

          for (k = 0; k < 4; k = k + 1) begin
            if (k < comp_cnt) begin
              // possible edges in component k: size*(size-1)/2
              sum_comp_possible_edges <= sum_comp_possible_edges +
                                        ((comp_size[k] * (comp_size[k] - 5'd1)) >> 1);
              sum_comp_real_edges <= sum_comp_real_edges + comp_edges[k];
              total_comp_nodes    <= total_comp_nodes + comp_size[k];
              if (comp_size[k] > largest_size) begin
                largest_size <= comp_size[k];
                largest_idx  <= k[1:0];
              end
            end
          end

          if (node_count > total_comp_nodes[3:0]) begin
            remaining_nodes <= node_count - total_comp_nodes[3:0];
          end else begin
            remaining_nodes <= 5'd0;
          end

          cross_edges <= largest_size * remaining_nodes;
        end

        RESULT_CALC: begin
          // Apply formula:
          // total = Σ(size_i*(size_i-1)/2) + size_largest*remaining_nodes
          // max_edges = total - edge_count - Σ(components edges)
          total_edges_possible <= sum_comp_possible_edges + cross_edges;

          if (total_edges_possible > edge_count + sum_comp_real_edges) begin
            max_edges <= total_edges_possible - edge_count - sum_comp_real_edges;
          end else begin
            max_edges <= 7'd0;
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMPONENT_SEARCH;
        end
      end

      COMPONENT_SEARCH: begin
        // Move to SIZE_CALC when all governments processed and no DFS active
        if ((gov_idx >= gov_count) && !dfs_active) begin
          next_state = SIZE_CALC;
        end
      end

      SIZE_CALC: begin
        next_state = RESULT_CALC;
      end

      RESULT_CALC: begin
        next_state = DONE_STATE;
      end

      DONE_STATE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule