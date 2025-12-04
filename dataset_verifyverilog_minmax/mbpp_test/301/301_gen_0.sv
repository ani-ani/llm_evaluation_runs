module dict_depth_calculator (
  input clk,
  input rst_n,
  input start,
  input [3:0] max_nodes,
  input [63:0] node_data, // 8 nodes: [parent(3:0), child_count(3:0)]
  output reg [3:0] depth_result,
  output reg done
);

  // Unpack node_data: for i in [0..7]: parent[i], child_cnt[i]
  logic [3:0] parent [0:7];
  logic [3:0] child_cnt [0:7];
  integer i;
  always @* begin
    for (i = 0; i < 8; i = i + 1) begin
      parent[i]   = node_data[i*8 +: 4];
      child_cnt[i]= node_data[i*8 + 4 +: 4];
    end
  end

  // Compute start index for each parent's children (BFS layout assumption)
  logic [3:0] child_start [0:7];
  always @* begin
    child_start[0] = 4'd1;
    for (int s = 1; s < 8; s = s + 1) begin
      child_start[s] = child_start[s-1] + child_cnt[s-1];
    end
  end

  // BFS state and datapath
  typedef enum logic [1:0] { IDLE=2'd0, COMPUTE=2'd1, BFS=2'd2, DONE=2'd3 } state_t;
  state_t state, next_state;

  logic [7:0] frontier, next_frontier;
  logic [7:0] visited, next_visited;
  logic [3:0] depth, next_depth;
  logic [3:0] max_nodes_r, next_max_nodes_r;

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      depth_result <= 4'd0;
      done <= 1'b0;
      frontier <= 8'd0;
      visited <= 8'd0;
      depth <= 4'd0;
      max_nodes_r <= 4'd0;
    end else begin
      state <= next_state;
      frontier <= next_frontier;
      visited <= next_visited;
      depth <= next_depth;
      max_nodes_r <= next_max_nodes_r;
      if (next_state == DONE) begin
        depth_result <= (next_depth > 4'd8) ? 4'd8 : next_depth;
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

  // Next-state logic
  always @* begin
    // Defaults
    next_state = state;
    next_frontier = frontier;
    next_visited = visited;
    next_depth = depth;
    next_max_nodes_r = max_nodes_r;

    case (state)
      IDLE: begin
        next_frontier = 8'd0;
        next_visited = 8'd0;
        next_depth = 4'd0;
        if (start) begin
          next_max_nodes_r = max_nodes;
          // Root is node 0 (parent must be 0 for valid trees)
          next_frontier = 8'b0000_0001;
          next_visited  = 8'b0000_0001;
          next_depth = 4'd1; // depth of root
          next_state = COMPUTE;
        end
      end

      COMPUTE: begin
        // Single-cycle compute of start indices, then enter BFS
        next_state = BFS;
      end

      BFS: begin
        next_frontier = 8'd0;
        // Determine children of current frontier within max_nodes
        for (int f = 0; f < 8; f = f + 1) begin
          if (frontier[f]) begin
            if (parent[f] == f) begin; end // no-op, prevents tool complaints about unique parent self-check
            if ((f == 0) || (parent[f] < max_nodes_r)) begin
              // Children range for node f: [child_start[f], child_start[f] + child_cnt[f] - 1]
              for (int c = 0; c < 8; c = c + 1) begin
                logic [3:0] cs;
                cs = child_start[f];
                if (c < child_cnt[f]) begin
                  logic [3:0] child_idx;
                  child_idx = cs + c[3:0];
                  if (child_idx < max_nodes_r && child_idx < 8) begin
                    next_frontier[child_idx] = 1'b1;
                  end
                end
              end
            end
          end
        end

        // Remove already visited nodes from next frontier
        next_frontier = next_frontier & ~visited;

        // Update visited
        next_visited = visited | next_frontier;

        // Depth handling with saturation
        if (next_frontier == 8'd0) begin
          next_depth = (next_depth > 4'd8) ? 4'd8 : next_depth;
          next_state = DONE;
        end else begin
          next_depth = next_depth + 4'd1;
          if (next_depth > 4'd8) begin
            next_depth = 4'd8; // saturate
            next_state = DONE;
          end
        end
      end

      DONE: begin
        // Hold until start deasserted, then return to IDLE
        next_state = start ? DONE : IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
