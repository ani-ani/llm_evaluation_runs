module three_states_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] grid_flat [0:15],
  output reg [7:0] min_cost,
  output reg done
);

  // States
  typedef enum logic [2:0] {
    IDLE,
    BFS1,
    BFS2,
    BFS3,
    CALCULATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // BFS related registers
  reg [3:0] bfs_state; // 0: state1, 1: state2, 2: state3
  reg [3:0] current_cell;
  reg [3:0] queue [0:15];
  reg [3:0] queue_head, queue_tail;
  reg [7:0] distance1 [0:15];
  reg [7:0] distance2 [0:15];
  reg [7:0] distance3 [0:15];
  reg [3:0] x, y;
  reg [3:0] min_x, min_y;
  reg [7:0] current_min;
  reg [3:0] i, j;

  // Initialize distances to 255 (unreachable)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      min_cost <= 255;
      for (int k = 0; k < 16; k++) begin
        distance1[k] <= 255;
        distance2[k] <= 255;
        distance3[k] <= 255;
      end
    end else begin
      current_state <= next_state;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            next_state <= BFS1;
            bfs_state <= 0;
            queue_head <= 0;
            queue_tail <= 0;
            // Initialize queue with state1 position
            for (int k = 0; k < 16; k++) begin
              if (grid_flat[k] == 49) begin
                queue[queue_tail] <= k;
                queue_tail <= queue_tail + 1;
                distance1[k] <= 0;
              end
            end
          end else begin
            next_state <= IDLE;
          end
        end
        BFS1: begin
          if (queue_head == queue_tail) begin
            next_state <= BFS2;
            bfs_state <= 1;
            queue_head <= 0;
            queue_tail <= 0;
            // Initialize queue with state2 position
            for (int k = 0; k < 16; k++) begin
              if (grid_flat[k] == 50) begin
                queue[queue_tail] <= k;
                queue_tail <= queue_tail + 1;
                distance2[k] <= 0;
              end
            end
          end else begin
            next_state <= BFS1;
          end
        end
        BFS2: begin
          if (queue_head == queue_tail) begin
            next_state <= BFS3;
            bfs_state <= 2;
            queue_head <= 0;
            queue_tail <= 0;
            // Initialize queue with state3 position
            for (int k = 0; k < 16; k++) begin
              if (grid_flat[k] == 51) begin
                queue[queue_tail] <= k;
                queue_tail <= queue_tail + 1;
                distance3[k] <= 0;
              end
            end
          end else begin
            next_state <= BFS2;
          end
        end
        BFS3: begin
          if (queue_head == queue_tail) begin
            next_state <= CALCULATE;
            current_min <= 255;
            i <= 0;
            j <= 0;
          end else begin
            next_state <= BFS3;
          end
        end
        CALCULATE: begin
          if (i == 16) begin
            next_state <= DONE;
            done <= 1;
          end else begin
            next_state <= CALCULATE;
          end
        end
        DONE: begin
          if (!start) begin
            next_state <= IDLE;
            done <= 0;
          end else begin
            next_state <= DONE;
          end
        end
        default: next_state <= IDLE;
      endcase
    end
  end

  // BFS logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset logic
    end else begin
      case (current_state)
        BFS1, BFS2, BFS3: begin
          if (queue_head < queue_tail) begin
            current_cell <= queue[queue_head];
            queue_head <= queue_head + 1;
            x <= current_cell % 4;
            y <= current_cell / 4;
            // Check neighbors
            for (int dx = -1; dx <= 1; dx++) begin
              for (int dy = -1; dy <= 1; dy++) begin
                if (dx == 0 || dy == 0) begin
                  if (x + dx >= 0 && x + dx < 4 && y + dy >= 0 && y + dy < 4) begin
                    int neighbor = (y + dy) * 4 + (x + dx);
                    if (grid_flat[neighbor] == 46) begin
                      case (bfs_state)
                        0: begin
                          if (distance1[neighbor] == 255) begin
                            distance1[neighbor] <= distance1[current_cell] + 1;
                            queue[queue_tail] <= neighbor;
                            queue_tail <= queue_tail + 1;
                          end
                        end
                        1: begin
                          if (distance2[neighbor] == 255) begin
                            distance2[neighbor] <= distance2[current_cell] + 1;
                            queue[queue_tail] <= neighbor;
                            queue_tail <= queue_tail + 1;
                          end
                        end
                        2: begin
                          if (distance3[neighbor] == 255) begin
                            distance3[neighbor] <= distance3[current_cell] + 1;
                            queue[queue_tail] <= neighbor;
                            queue_tail <= queue_tail + 1;
                          end
                        end
                      endcase
                    end
                  end
                end
              end
            end
          end
        end
        CALCULATE: begin
          if (distance1[i] != 255 && distance2[i] != 255 && distance3[i] != 255) begin
            if (distance1[i] + distance2[i] + distance3[i] < current_min) begin
              current_min <= distance1[i] + distance2[i] + distance3[i];
            end
          end
          i <= i + 1;
        end
      endcase
    end
  end

  // Output the result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_cost <= 255;
    end else begin
      if (current_state == DONE) begin
        min_cost <= current_min;
      end
    end
  end

endmodule