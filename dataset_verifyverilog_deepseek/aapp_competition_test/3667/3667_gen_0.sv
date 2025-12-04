module pipe_clean_scheduler (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_wells,
  input [2:0] num_pipes,
  input [15:0] well_x [0:7],
  input [15:0] well_y [0:7],
  input [2:0] pipe_start [0:7],
  input [15:0] pipe_end_x [0:7],
  input [15:0] pipe_end_y [0:7],
  output reg result,
  output reg done
);

  typedef enum {IDLE, PREPARE, BUILD_ADJ, BIPARTITE, FINISH} state_t;
  state_t state;

  // Coordinate conversion registers
  reg [11:0] pipe_start_x [0:7];
  reg [11:0] pipe_start_y [0:7];
  reg [11:0] pipe_end_x_int [0:7];
  reg [11:0] pipe_end_y_int [0:7];

  // Adjacency matrix and graph data
  reg [7:0] adj_matrix [0:7];
  reg [2:0] color [0:7];
  reg [2:0] visited;
  reg [2:0] current_node;

  // BFS queue and pointers
  reg [2:0] queue [0:7];
  reg [2:0] queue_head, queue_tail;

  // Cycle counter and iterators
  reg [7:0] cycle_count;
  reg [2:0] i, j;
  reg [2:0] pipe_i, pipe_j;

  // Intersection flags
  wire seg_intersect;
  reg check_intersection;

  // Line intersection helper function
  function automatic logic lines_intersect(
    input [11:0] x1, y1, x2, y2,
    input [11:0] x3, y3, x4, y4
  );
    logic [23:0] denom, num1, num2;
    logic [11:0] x12 = x1 - x2;
    logic [11:0] x34 = x3 - x4;
    logic [11:0] y12 = y1 - y2;
    logic [11:0] y34 = y3 - y4;

    denom = (x12 * y34) - (y12 * x34);
    if (denom == 0) return 0;

    num1 = (x1 * y2 - y1 * x2);
    num2 = (x3 * y4 - y3 * x4);

    logic [23:0] intersect_x_num = (num1 * x34) - (x12 * num2);
    logic [23:0] intersect_y_num = (num1 * y34) - (y12 * num2);

    logic intersect_x_valid = (intersect_x_num / denom) >= x1 && (intersect_x_num / denom) <= x2 ||
                           (intersect_x_num / denom) >= x2 && (intersect_x_num / denom) <= x1;
    logic intersect_y_valid = (intersect_y_num / denom) >= y1 && (intersect_y_num / denom) <= y2 ||
                           (intersect_y_num / denom) >= y2 && (intersect_y_num / denom) <= y1;

    return intersect_x_valid && intersect_y_valid;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      cycle_count <= 0;
      check_intersection <= 0;
      for (int k=0; k<8; k++) begin
        adj_matrix[k] <= 8'h0;
        color[k] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          cycle_count <= 0;
          if (start) state <= PREPARE;
        end

        PREPARE: begin
          // Convert Q12.4 to integer coordinates
          for (int k=0; k<8; k++) begin
            pipe_start_x[k] <= well_x[pipe_start[k]][15:4];
            pipe_start_y[k] <= well_y[pipe_start[k]][15:4];
            pipe_end_x_int[k] <= pipe_end_x[k][15:4];
            pipe_end_y_int[k] <= pipe_end_y[k][15:4];
          end
          state <= BUILD_ADJ;
          i <= 0;
          j <= 1;
        end

        BUILD_ADJ: begin
          if (i < num_pipes) begin
            if (j < num_pipes) begin
              // Check if pipes share a well
              if ((pipe_start[i] == pipe_start[j]) ||
                  (pipe_start[i] == pipe_start[j])) begin
                adj_matrix[i][j] <= 0;
                adj_matrix[j][i] <= 0;
              end else begin
                // Check intersection
                adj_matrix[i][j] <= lines_intersect(
                  pipe_start_x[i], pipe_start_y[i],
                  pipe_end_x_int[i], pipe_end_y_int[i],
                  pipe_start_x[j], pipe_start_y[j],
                  pipe_end_x_int[j], pipe_end_y_int[j]
                );
                adj_matrix[j][i] <= adj_matrix[i][j];
              end
              j <= j + 1;
            end else begin
              i <= i + 1;
              j <= i + 1;
            end
          end else begin
            state <= BIPARTITE;
            visited <= 0;
            current_node <= 0;
          end
        end

        BIPARTITE: begin
          // BFS initialization
          if (visited == 8'hFF) begin
            state <= FINISH;
            result <= 1;
          end else if (!visited[current_node]) begin
            color[current_node] <= 1;
            queue_head <= 0;
            queue_tail <= 0;
            queue[0] <= current_node;
            visited[current_node] <= 1;
          end else begin
            current_node <= current_node + 1;
          end

          // BFS processing
          if (queue_head != queue_tail) begin
            reg [2:0] u = queue[queue_head];
            queue_head <= queue_head + 1;
            for (int v=0; v<8; v++) begin
              if (adj_matrix[u][v] && u != v) begin
                if (!visited[v]) begin
                  visited[v] <= 1;
                  color[v] <= (color[u] == 1) ? 2 : 1;
                  queue[queue_tail] <= v;
                  queue_tail <= queue_tail + 1;
                end else if (color[v] == color[u]) begin
                  state <= FINISH;
                  result <= 0;
                end
              end
            end
          end else if (current_node < num_pipes) begin
            current_node <= current_node + 1;
          end
        end

        FINISH: begin
          done <= 1;
          state <= IDLE;
        end
      endcase

      // Timeout check
      cycle_count <= cycle_count + 1;
      if (cycle_count == 255) begin
        state <= FINISH;
        result <= 0;
        done <= 1;
      end
    end
  end

endmodule