module puzzle_solver (
  input clk,
  input rst_n,
  input start,
  input [31:0] grid_initial,
  output reg [3:0] result,
  output reg done
);

  // Constants
  localparam GOAL_STATE = 32'h0000_0000_0101_0101_1010_1010_1111_1111;
  localparam QUEUE_SIZE = 64;
  localparam VISITED_SIZE = 1024;
  localparam MAX_DEPTH = 12;

  // State machine states
  localparam [3:0] S_IDLE = 4'd0,
                   S_RESET_VISITED = 4'd1,
                   S_INIT_QUEUE = 4'd2,
                   S_POP = 4'd3,
                   S_CHECK_GOAL = 4'd4,
                   S_GEN_MOVES = 4'd5,
                   S_FINISH = 4'd6;

  // Queue structure: 32-bit state + 4-bit depth
  reg [35:0] queue [0:QUEUE_SIZE-1];
  reg [5:0] front_ptr, rear_ptr;

  // Visited structure: 32-bit key + 1-bit valid
  reg [32:0] visited [0:VISITED_SIZE-1];

  // Current state and depth
  reg [31:0] current_state;
  reg [3:0] current_depth;

  // Move generation
  reg [2:0] move_idx;
  reg [31:0] next_state;

  // State machine
  reg [3:0] state;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      front_ptr <= 0;
      rear_ptr <= 0;
      current_state <= 0;
      current_depth <= 0;
      move_idx <= 0;
      done <= 0;
      result <= 0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            state <= S_RESET_VISITED;
          end
        end
        S_RESET_VISITED: begin
          if (front_ptr == VISITED_SIZE-1) begin
            state <= S_INIT_QUEUE;
            front_ptr <= 0;
          end else begin
            front_ptr <= front_ptr + 1;
          end
        end
        S_INIT_QUEUE: begin
          queue[0] <= {grid_initial, 4'd0};
          rear_ptr <= 1;
          state <= S_POP;
        end
        S_POP: begin
          if (front_ptr < rear_ptr) begin
            {current_state, current_depth} <= queue[front_ptr];
            front_ptr <= front_ptr + 1;
            state <= S_CHECK_GOAL;
          end else begin
            state <= S_IDLE;
          end
        end
        S_CHECK_GOAL: begin
          if (current_state == GOAL_STATE) begin
            state <= S_FINISH;
          end else if (current_depth == MAX_DEPTH) begin
            state <= S_POP;
          end else begin
            move_idx <= 0;
            state <= S_GEN_MOVES;
          end
        end
        S_GEN_MOVES: begin
          if (move_idx == 7) begin
            state <= S_POP;
          end else begin
            move_idx <= move_idx + 1;
          end
        end
        S_FINISH: begin
          result <= current_depth;
          done <= 1;
          state <= S_IDLE;
        end
        default: state <= S_IDLE;
      endcase
    end
  end

  // Visited RAM reset
  always @(posedge clk) begin
    if (!rst_n) begin
      for (integer i = 0; i < VISITED_SIZE; i = i + 1) begin
        visited[i] <= 0;
      end
    end else if (state == S_RESET_VISITED) begin
      visited[front_ptr] <= 0;
    end
  end

  // Move generation logic
  always @(*) begin
    case (move_idx)
      // Row 0 Left
      3'd0: begin
        next_state[31:24] = {current_state[29:24], current_state[31:30]};
        next_state[23:0] = current_state[23:0];
      end
      // Row 0 Right
      3'd1: begin
        next_state[31:24] = {current_state[1:0], current_state[31:2]};
        next_state[23:0] = current_state[23:0];
      end
      // Row 1 Left
      3'd2: begin
        next_state[23:16] = {current_state[21:16], current_state[23:22]};
        next_state[31:24] = current_state[31:24];
        next_state[15:0] = current_state[15:0];
      end
      // Row 1 Right
      3'd3: begin
        next_state[23:16] = {current_state[17:16], current_state[23:18]};
        next_state[31:24] = current_state[31:24];
        next_state[15:0] = current_state[15:0];
      end
      // Row 2 Left
      3'd4: begin
        next_state[15:8] = {current_state[13:8], current_state[15:14]};
        next_state[31:16] = current_state[31:16];
        next_state[7:0] = current_state[7:0];
      end
      // Row 2 Right
      3'd5: begin
        next_state[15:8] = {current_state[9:8], current_state[15:10]};
        next_state[31:16] = current_state[31:16];
        next_state[7:0] = current_state[7:0];
      end
      // Row 3 Left
      3'd6: begin
        next_state[7:0] = {current_state[5:0], current_state[7:6]};
        next_state[31:8] = current_state[31:8];
      end
      // Row 3 Right
      3'd7: begin
        next_state[7:0] = {current_state[1:0], current_state[7:2]};
        next_state[31:8] = current_state[31:8];
      end
      default: next_state = current_state;
    endcase
  end

  // Visited check and enqueue
  always @(posedge clk) begin
    if (state == S_GEN_MOVES && move_idx != 0) begin
      reg [9:0] visited_idx = next_state[9:0];
      reg [32:0] visited_entry = visited[visited_idx];
      if (!visited_entry[32] && next_state != current_state) begin
        visited[visited_idx] <= {1'b1, next_state};
        if (rear_ptr < QUEUE_SIZE) begin
          queue[rear_ptr] <= {next_state, current_depth + 1};
          rear_ptr <= rear_ptr + 1;
        end
      end
    end
  end

endmodule