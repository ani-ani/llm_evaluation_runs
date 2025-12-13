module minimal_settlers(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  // Graph parameters
  input [3:0] node_count, // Max 8 nodes (n)
  input [3:0] iron_count, // Max 3 iron nodes (m)
  input [3:0] coal_count, // Max 3 coal nodes (k)
  // Resource lists (active-high flags for nodes)
  input [7:0] iron_list, // iron_list[i]=1 if node i has iron
  input [7:0] coal_list, // coal_list[i]=1 if node i has coal
  // Graph edges - flattened 8x4 array: 8 nodes, 4 neighbors each
  input [7:0][3:0] neighbor_counts, // neighbor_counts[i] = a_i (0-4)
  input [7:0][3:0][2:0] neighbors, // neighbors[i][j] = neighbor node ID (0-7)
  // Outputs
  output reg [3:0] result, // Min settlers (0-15)
  output reg done, // High when computation complete
  output reg impossible // High when solution impossible
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE       = 3'd0,
    IRON_BFS   = 3'd1,
    COAL_BFS   = 3'd2,
    CALCULATE  = 3'd3,
    DONE       = 3'd4
  } state_t;

  state_t state, next_state;

  // Distance arrays (2 bits per node, 0-3; unreachable = 3)
  reg [1:0] dist_iron  [7:0];
  reg [1:0] dist_coal  [7:0];

  // Frontier bitmasks
  reg [7:0] frontier_iron;
  reg [7:0] frontier_coal;

  // BFS step counters
  reg [1:0] step_iron;
  reg [1:0] step_coal;

  // Neighbor iteration indices
  reg [2:0] node_idx;
  reg [1:0] neigh_idx;

  // Latched parameters
  reg [3:0] n_nodes;

  // Tracking minimum distances
  reg [1:0] min_iron_dist;
  reg [1:0] min_coal_dist;
  reg       iron_reachable;
  reg       coal_reachable;

  // Internal flags
  reg bfs_init;

  integer i;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = IRON_BFS;
      end
      IRON_BFS: begin
        // Transition when frontier processing is complete
        if ( (step_iron == 2'd3) || (frontier_iron == 8'b0) ) begin
          next_state = COAL_BFS;
        end
      end
      COAL_BFS: begin
        if ( (step_coal == 2'd3) || (frontier_coal == 8'b0) ) begin
          next_state = CALCULATE;
        end
      end
      CALCULATE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Synchronous state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      done            <= 1'b0;
      impossible      <= 1'b0;
      result          <= 4'd0;
      n_nodes         <= 4'd0;
      frontier_iron   <= 8'b0;
      frontier_coal   <= 8'b0;
      step_iron       <= 2'd0;
      step_coal       <= 2'd0;
      node_idx        <= 3'd0;
      neigh_idx       <= 2'd0;
      min_iron_dist   <= 2'd3;
      min_coal_dist   <= 2'd3;
      iron_reachable  <= 1'b0;
      coal_reachable  <= 1'b0;
      bfs_init        <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        dist_iron[i] <= 2'd3; // unreachable
        dist_coal[i] <= 2'd3; // unreachable
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          impossible <= 1'b0;
          result     <= 4'd0;

          if (start) begin
            // Latch node count (limit to 8)
            n_nodes <= (node_count > 4'd8) ? 4'd8 : node_count;

            // Initialize distances
            for (i = 0; i < 8; i = i + 1) begin
              dist_iron[i] <= 2'd3; // unreachable
              dist_coal[i] <= 2'd3; // unreachable
            end

            // BFS from node 0
            dist_iron[0]  <= 2'd0;
            dist_coal[0]  <= 2'd0;

            // Initialize frontiers with start node
            frontier_iron <= 8'b0000_0001;
            frontier_coal <= 8'b0000_0001;

            // Reset step counters
            step_iron     <= 2'd0;
            step_coal     <= 2'd0;

            // Reset controls
            node_idx       <= 3'd0;
            neigh_idx      <= 2'd0;
            min_iron_dist  <= 2'd3;
            min_coal_dist  <= 2'd3;
            iron_reachable <= 1'b0;
            coal_reachable <= 1'b0;
            bfs_init       <= 1'b1;
          end else begin
            bfs_init <= 1'b0;
          end
        end

        IRON_BFS: begin
          // Single-cycle BFS pass per state duration, bounded to 3 steps
          if (bfs_init) begin
            // First cycle after entering: clear init flag
            bfs_init <= 1'b0;
            node_idx <= 3'd0;
            neigh_idx <= 2'd0;
          end else begin
            reg [7:0] new_frontier;
            new_frontier = 8'b0;

            // Explore neighbors of all nodes in current frontier
            for (i = 0; i < 8; i = i + 1) begin
              if (frontier_iron[i] && (i < n_nodes)) begin
                integer j;
                for (j = 0; j < 4; j = j + 1) begin
                  if (j < neighbor_counts[i]) begin
                    reg [2:0] nb;
                    nb = neighbors[i][j];
                    if ((nb < n_nodes) && (dist_iron[nb] == 2'd3)) begin
                      dist_iron[nb] <= step_iron + 2'd1;
                      new_frontier[nb] = 1'b1;
                    end
                  end
                end
              end
            end

            frontier_iron <= new_frontier;

            // Update minimum iron distance based on newly discovered nodes
            for (i = 0; i < 8; i = i + 1) begin
              if (new_frontier[i] && iron_list[i]) begin
                iron_reachable <= 1'b1;
                if ((step_iron + 2'd1) < min_iron_dist)
                  min_iron_dist <= step_iron + 2'd1;
              end
            end

            // Increment step counter up to 3
            if (step_iron < 2'd3)
              step_iron <= step_iron + 2'd1;
          end

          // Prepare for next state
          if (next_state == COAL_BFS) begin
            bfs_init <= 1'b1;
          end
        end

        COAL_BFS: begin
          if (bfs_init) begin
            bfs_init  <= 1'b0;
            node_idx  <= 3'd0;
            neigh_idx <= 2'd0;
          end else begin
            reg [7:0] new_frontier_c;
            new_frontier_c = 8'b0;

            for (i = 0; i < 8; i = i + 1) begin
              if (frontier_coal[i] && (i < n_nodes)) begin
                integer j2;
                for (j2 = 0; j2 < 4; j2 = j2 + 1) begin
                  if (j2 < neighbor_counts[i]) begin
                    reg [2:0] nb2;
                    nb2 = neighbors[i][j2];
                    if ((nb2 < n_nodes) && (dist_coal[nb2] == 2'd3)) begin
                      dist_coal[nb2] <= step_coal + 2'd1;
                      new_frontier_c[nb2] = 1'b1;
                    end
                  end
                end
              end
            end

            frontier_coal <= new_frontier_c;

            for (i = 0; i < 8; i = i + 1) begin
              if (new_frontier_c[i] && coal_list[i]) begin
                coal_reachable <= 1'b1;
                if ((step_coal + 2'd1) < min_coal_dist)
                  min_coal_dist <= step_coal + 2'd1;
              end
            end

            if (step_coal < 2'd3)
              step_coal <= step_coal + 2'd1;
          end

          if (next_state == CALCULATE) begin
            bfs_init <= 1'b0;
          end
        end

        CALCULATE: begin
          // Determine if both resources reachable
          if (iron_reachable && coal_reachable && (min_iron_dist != 2'd3) && (min_coal_dist != 2'd3)) begin
            // settlers = dist_iron + dist_coal - 1
            // max each is 3 so sum is <=6; fit into 4 bits
            result     <= {2'b00, min_iron_dist} + {2'b00, min_coal_dist} - 4'd1;
            impossible <= 1'b0;
          end else begin
            result     <= 4'd0;
            impossible <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Wait for start deassert (handled in next_state)
        end

        default: begin
          // Should not occur, reset-like behavior
          done       <= 1'b0;
          impossible <= 1'b0;
        end
      endcase
    end
  end

endmodule