module pipe_bipartite_checker (
  input clk,
  input rst_n,
  input start,
  input [4:0] pipe_idx,
  input valid_pipe,
  input signed [7:0] sx, sy, ex, ey,
  output reg result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] RECEIVE_PIPES = 3'b001;
  localparam [2:0] BUILD_GRAPH = 3'b010;
  localparam [2:0] CHECK_BIPARTITE = 3'b011;
  localparam [2:0] DONE = 3'b100;

  reg [2:0] state = IDLE;

  // Pipe storage (8 pipes, each with sx, sy, ex, ey)
  reg signed [7:0] pipe_sx [0:7];
  reg signed [7:0] pipe_sy [0:7];
  reg signed [7:0] pipe_ex [0:7];
  reg signed [7:0] pipe_ey [0:7];

  // Intersection matrix (8x8)
  reg intersect [0:7][0:7];

  // BFS variables
  reg signed [2:0] color [0:7]; // -1: unvisited, 0/1: colors
  reg [2:0] queue [0:7]; // Simple queue for BFS
  reg [2:0] q_head, q_tail;
  reg conflict;

  // Counters
  reg [2:0] pipe_count = 0;
  reg [5:0] i_counter = 0;
  reg [5:0] j_counter = 0;
  reg [5:0] k_counter = 0;
  reg [5:0] bfs_counter = 0;

  // Orientation function helper
  function signed [15:0] orientation;
    input signed [7:0] ax, ay, bx, by, cx, cy;
    begin
      orientation = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
    end
  endfunction

  // Intersection check function
  function automatic check_intersect;
    input signed [7:0] a_sx, a_sy, a_ex, a_ey;
    input signed [7:0] b_sx, b_sy, b_ex, b_ey;
    begin
      // Compute orientations
      signed [15:0] o1 = orientation(a_sx, a_sy, a_ex, a_ey, b_sx, b_sy);
      signed [15:0] o2 = orientation(a_sx, a_sy, a_ex, a_ey, b_ex, b_ey);
      signed [15:0] o3 = orientation(b_sx, b_sy, b_ex, b_ey, a_sx, a_sy);
      signed [15:0] o4 = orientation(b_sx, b_sy, b_ex, b_ey, a_ex, a_ey);

      // Check if segments straddle each other
      if (((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
          ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0)))
        check_intersect = 1'b1;
      else
        check_intersect = 1'b0;
    end
  endfunction

  // Main FSM
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pipe_count <= 0;
      i_counter <= 0;
      j_counter <= 0;
      k_counter <= 0;
      bfs_counter <= 0;
      q_head <= 0;
      q_tail <= 0;
      conflict <= 0;
      result <= 0;
      done <= 0;

      // Reset pipe storage
      for (integer i = 0; i < 8; i = i + 1) begin
        pipe_sx[i] <= 0;
        pipe_sy[i] <= 0;
        pipe_ex[i] <= 0;
        pipe_ey[i] <= 0;
        color[i] <= -1;
        for (integer j = 0; j < 8; j = j + 1) begin
          intersect[i][j] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= RECEIVE_PIPES;
            pipe_count <= 0;
          end
        end

        RECEIVE_PIPES: begin
          if (valid_pipe) begin
            pipe_sx[pipe_idx] <= sx;
            pipe_sy[pipe_idx] <= sy;
            pipe_ex[pipe_idx] <= ex;
            pipe_ey[pipe_idx] <= ey;
            pipe_count <= pipe_count + 1;

            if (pipe_count == 7) begin
              state <= BUILD_GRAPH;
              i_counter <= 0;
              j_counter <= 1;
            end
          end else if (!start) begin
            // Early termination if start is deasserted
            state <= BUILD_GRAPH;
            i_counter <= 0;
            j_counter <= 1;
          end
        end

        BUILD_GRAPH: begin
          if (i_counter < 7) begin
            if (j_counter < 8) begin
              if (i_counter != j_counter) begin
                intersect[i_counter][j_counter] <= check_intersect(
                  pipe_sx[i_counter], pipe_sy[i_counter], pipe_ex[i_counter], pipe_ey[i_counter],
                  pipe_sx[j_counter], pipe_sy[j_counter], pipe_ex[j_counter], pipe_ey[j_counter]
                );
              end
              j_counter <= j_counter + 1;
            end else begin
              i_counter <= i_counter + 1;
              j_counter <= i_counter + 1;
            end
          end else begin
            state <= CHECK_BIPARTITE;
            bfs_counter <= 0;
            k_counter <= 0;
            q_head <= 0;
            q_tail <= 0;
            conflict <= 0;

            // Initialize colors
            for (integer i = 0; i < 8; i = i + 1) begin
              color[i] <= -1;
            end
          end
        end

        CHECK_BIPARTITE: begin
          if (!conflict) begin
            if (k_counter < 8) begin
              if (color[k_counter] == -1) begin
                // Start BFS from this node
                color[k_counter] <= 0;
                queue[q_tail] <= k_counter;
                q_tail <= q_tail + 1;

                state <= CHECK_BIPARTITE;
                bfs_counter <= 0;
              end else begin
                k_counter <= k_counter + 1;
              end
            end else begin
              // All nodes processed without conflict
              result <= 1;
              done <= 1;
              state <= DONE;
            end
          end else begin
            result <= 0;
            done <= 1;
            state <= DONE;
          end
        end

        DONE: begin
          // Stay in DONE until reset
        end

        default: state <= IDLE;
      endcase
    end
  end

  // BFS processing (combinationally triggered from state)
  always @(*) begin
    if (state == CHECK_BIPARTITE && !conflict && q_head < q_tail) begin
      integer u = queue[q_head];
      for (integer v = 0; v < 8; v = v + 1) begin
        if (intersect[u][v] && u != v) begin
          if (color[v] == -1) begin
            color[v] = 1 - color[u];
            queue[q_tail] = v;
            q_tail = q_tail + 1;
          end else if (color[v] == color[u]) begin
            conflict = 1;
          end
        end
      end
      q_head = q_head + 1;
    end
  end

endmodule