module flight_path_finder(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [2:0] s,
  input [2:0] t,
  input [7:0] adj_types,
  input [7:0][7:0] adj_lists,
  output reg [3:0] hops,
  output reg done,
  output reg impossible
);

  // State encoding
  localparam IDLE         = 2'd0;
  localparam BUILD_MATRIX = 2'd1;
  localparam BFS          = 2'd2;
  localparam DONE         = 2'd3;

  reg [1:0] state, next_state;

  // Adjacency matrix: adj_matrix[i][j]
  reg adj_matrix [7:0][7:0];

  // Indices and control
  reg [2:0] build_i;
  reg [2:0] build_j;

  reg [2:0] cur_node;
  reg [2:0] neighbor_idx;

  reg [7:0] visited;
  reg [7:0] dist [7:0];

  // Simple circular queue for up to 8 entries
  reg [2:0] queue [7:0];
  reg [2:0] q_head;
  reg [2:0] q_tail;
  reg [3:0] q_count; // up to 8

  reg [7:0] cur_dist;

  integer ii;

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = BUILD_MATRIX;
      end
      BUILD_MATRIX: begin
        // After all i,j filled, go to BFS
        if (build_i == (N-1) && build_j == (N-1))
          next_state = BFS;
      end
      BFS: begin
        // Transition to DONE handled in sequential block when condition met
        // Keep BFS here; next_state assigned there accordingly
      end
      DONE: begin
        // Return to IDLE after one cycle pulse
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      hops <= 4'd0;
      done <= 1'b0;
      impossible <= 1'b0;
      build_i <= 3'd0;
      build_j <= 3'd0;
      visited <= 8'd0;
      q_head <= 3'd0;
      q_tail <= 3'd0;
      q_count <= 4'd0;
      neighbor_idx <= 3'd0;
      cur_node <= 3'd0;
      cur_dist <= 8'd0;
      for (ii = 0; ii < 8; ii = ii + 1) begin
        dist[ii] <= 8'd0;
      end
    end else begin
      state <= next_state;

      // Default outputs
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Wait for start; clear control
          if (start) begin
            // Initialize build indices
            build_i <= 3'd0;
            build_j <= 3'd0;
            // Clear adjacency matrix for safety
            for (ii = 0; ii < 8; ii = ii + 1) begin
              adj_matrix[ii][0] <= 1'b0;
              adj_matrix[ii][1] <= 1'b0;
              adj_matrix[ii][2] <= 1'b0;
              adj_matrix[ii][3] <= 1'b0;
              adj_matrix[ii][4] <= 1'b0;
              adj_matrix[ii][5] <= 1'b0;
              adj_matrix[ii][6] <= 1'b0;
              adj_matrix[ii][7] <= 1'b0;
            end
            // Clear search structures
            visited <= 8'd0;
            q_head <= 3'd0;
            q_tail <= 3'd0;
            q_count <= 4'd0;
            neighbor_idx <= 3'd0;
            cur_node <= 3'd0;
            cur_dist <= 8'd0;
            for (ii = 0; ii < 8; ii = ii + 1) begin
              dist[ii] <= 8'hFF; // mark as infinity
            end
            hops <= 4'd0;
            impossible <= 1'b0;
          end
        end

        BUILD_MATRIX: begin
          // Build N x N adjacency matrix according to rules
          if (build_i < N && build_j < N) begin
            if (adj_types[build_i] == 1'b0) begin
              adj_matrix[build_i][build_j] <= adj_lists[build_i][build_j];
            end else begin
              // Complement type
              adj_matrix[build_i][build_j] <= ~adj_lists[build_i][build_j];
            end
          end

          // Advance indices (one cell per cycle)
          if (build_j == (N-1)) begin
            build_j <= 3'd0;
            if (build_i == (N-1)) begin
              // Last cell done: initialize BFS in next_state (BFS)
              // BFS initialization here once when finishing
              // Only run once when we just finished
              // Note: This executes on the cycle finishing last cell
              visited <= (8'd1 << s);
              dist[s] <= 8'd0;
              queue[0] <= s;
              q_head <= 3'd0;
              q_tail <= 3'd1; // one element
              q_count <= 4'd1;
              neighbor_idx <= 3'd0;
              cur_node <= s;
              cur_dist <= 8'd0;
              hops <= 4'd0;
              impossible <= 1'b0;
            end else begin
              build_i <= build_i + 3'd1;
            end
          end else begin
            build_j <= build_j + 3'd1;
          end
        end

        BFS: begin
          // If source equals target, zero hops result
          if (s == t) begin
            hops <= 4'd0;
            impossible <= 1'b0;
            done <= 1'b1;
            state <= DONE;
          end else begin
            if (q_count == 0) begin
              // No more nodes: impossible
              hops <= 4'hF;
              impossible <= 1'b1;
              done <= 1'b1;
              state <= DONE;
            end else begin
              // Dequeue current node
              cur_node <= queue[q_head];
              cur_dist <= dist[queue[q_head]];

              // For simplicity, perform neighbor expansion sequentially
              // using neighbor_idx over multiple cycles.

              // If we've just dequeued (neighbor_idx==0), move head and dec count
              if (neighbor_idx == 3'd0) begin
                q_head <= q_head + 3'd1;
                q_count <= q_count - 4'd1;
              end

              if (neighbor_idx < N) begin
                // Check neighbor at neighbor_idx
                if (adj_matrix[queue[q_head]][neighbor_idx]) begin
                  if (!visited[neighbor_idx]) begin
                    visited[neighbor_idx] <= 1'b1;
                    dist[neighbor_idx] <= cur_dist + 8'd1;
                    queue[q_tail] <= neighbor_idx;
                    q_tail <= q_tail + 3'd1;
                    q_count <= q_count + 4'd1;
                    // Check if this is target
                    if (neighbor_idx == t) begin
                      hops <= (cur_dist + 8'd1) [3:0];
                      impossible <= 1'b0;
                      done <= 1'b1;
                      state <= DONE;
                    end
                  end
                end
                neighbor_idx <= neighbor_idx + 3'd1;
              end else begin
                // Done scanning neighbors of this node, move to next node
                neighbor_idx <= 3'd0;
              end
            end
          end
        end

        DONE: begin
          // One-cycle pulse of done already set when entering DONE
          done <= 1'b0; // will be pulsed in transition cycles only
        end
      endcase
    end
  end

endmodule