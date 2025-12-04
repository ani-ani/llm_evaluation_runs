module vertex_controller(
  input clk,
  input rst_n,
  input start,
  input [31:0] vertex_vals [0:7],
  input [31:0] edge_weights [0:6],
  output reg [3:0] control_counts [0:7],
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE     = 2'b00,
    TRAVERSE = 2'b01,
    COMPARE  = 2'b10,
    DONE_ST  = 2'b11
  } state_t;

  state_t state, next_state;

  // Parent indices for vertices 1..7 (fixed mapping via edge_weights index)
  // parent[i] = p such that edge from p to i exists; edge_weights[?] holds its weight.
  // For simplicity, assume a fixed tree:
  // edge_weights[0]: parent of 1
  // edge_weights[1]: parent of 2
  // edge_weights[2]: parent of 3
  // edge_weights[3]: parent of 4
  // edge_weights[4]: parent of 5
  // edge_weights[5]: parent of 6
  // edge_weights[6]: parent of 7
  // and parent index is encoded implicitly as constant mapping below.

  // Fixed parent mapping for an example 8-node tree:
  // 0 is root
  // 1 <- 0 (edge_weights[0])
  // 2 <- 0 (edge_weights[1])
  // 3 <- 1 (edge_weights[2])
  // 4 <- 1 (edge_weights[3])
  // 5 <- 2 (edge_weights[4])
  // 6 <- 2 (edge_weights[5])
  // 7 <- 3 (edge_weights[6])
  localparam logic [2:0] PARENT [0:7] = '{3'd0, 3'd0, 3'd0, 3'd1, 3'd1, 3'd2, 3'd2, 3'd3};

  // Map vertex to edge_weights index for parent edge (for vertices 1..7)
  localparam logic [2:0] EDGE_IDX [0:7] = '{3'd0, 3'd0, 3'd1, 3'd2, 3'd3, 3'd4, 3'd5, 3'd6};

  // Precomputed root-to-node distance (Q16.16)
  reg [31:0] root_dist [0:7];

  // Counters and indices
  reg [2:0] v_idx;       // current vertex index (0..7)
  reg [2:0] u_idx;       // current descendant candidate index (0..7)
  reg [3:0] curr_count;  // current count for vertex v_idx

  // Temporary distance computation
  reg [31:0] dist_diff;

  // Combinational next_state
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = TRAVERSE;
      end

      TRAVERSE: begin
        // root_dist computation happens sequentially; when last index done, move to COMPARE
        if (v_idx == 3'd7)
          next_state = COMPARE;
      end

      COMPARE: begin
        // When all vertices processed for comparisons, go to DONE
        if (v_idx == 3'd7 && u_idx == 3'd7)
          next_state = DONE_ST;
      end

      DONE_ST: begin
        // Wait for start deassert then return to IDLE
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      v_idx <= 3'd0;
      u_idx <= 3'd0;
      curr_count <= 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        control_counts[i] <= 4'd0;
        root_dist[i] <= 32'd0;
      end
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          // Clear counts on new start edge
          if (start) begin
            v_idx <= 3'd0;
            u_idx <= 3'd0;
            curr_count <= 4'd0;
            for (i = 0; i < 8; i = i + 1) begin
              control_counts[i] <= 4'd0;
              root_dist[i] <= 32'd0;
            end
          end
        end

        TRAVERSE: begin
          // Compute root_dist incrementally each cycle for one vertex index
          // Vertex 0 is root
          if (v_idx == 3'd0) begin
            // root vertex
            root_dist[0] <= 32'd0;
            v_idx <= 3'd1;
          end else begin
            // For vertex v_idx >=1, use its parent and corresponding edge weight
            // root_dist[i] = root_dist[parent[i]] + edge_weights[EDGE_IDX[i]]
            root_dist[v_idx] <= root_dist[PARENT[v_idx]] + edge_weights[EDGE_IDX[v_idx]];
            if (v_idx == 3'd7) begin
              // completed last node; prepare for COMPARE
              v_idx <= 3'd0;
              u_idx <= 3'd0;
              curr_count <= 4'd0;
            end else begin
              v_idx <= v_idx + 3'd1;
            end
          end
        end

        COMPARE: begin
          // Skip unused nodes: a_i == 0 means node is inactive
          // We count descendants u of v_idx such that:
          // 1) u is active (vertex_vals[u] != 0)
          // 2) u is descendant of v_idx (root_dist[u] >= root_dist[v_idx])
          // 3) dist(v_idx,u) = root_dist[u] - root_dist[v_idx]
          //    and dist(v_idx,u) <= vertex_vals[u]

          // Perform comparison only when both vertices active considerations apply
          dist_diff = 32'd0;

          if (vertex_vals[v_idx] != 32'd0) begin
            if (vertex_vals[u_idx] != 32'd0) begin
              if (root_dist[u_idx] >= root_dist[v_idx]) begin
                dist_diff = root_dist[u_idx] - root_dist[v_idx];
                if (dist_diff <= vertex_vals[u_idx]) begin
                  curr_count <= curr_count + 4'd1;
                end
              end
            end
          end

          // Advance u_idx; when finished all u for current v, store and move to next v
          if (u_idx == 3'd7) begin
            control_counts[v_idx] <= curr_count;
            curr_count <= 4'd0;
            u_idx <= 3'd0;
            if (v_idx == 3'd7) begin
              // all vertices done, next_state will progress to DONE_ST
              v_idx <= v_idx; // hold
            end else begin
              v_idx <= v_idx + 3'd1;
            end
          end else begin
            u_idx <= u_idx + 3'd1;
          end
        end

        DONE_ST: begin
          done <= 1'b1;
          // Outputs (control_counts) are held stable
          if (!start) begin
            // Prepare for potential next operation
            v_idx <= 3'd0;
            u_idx <= 3'd0;
            curr_count <= 4'd0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
