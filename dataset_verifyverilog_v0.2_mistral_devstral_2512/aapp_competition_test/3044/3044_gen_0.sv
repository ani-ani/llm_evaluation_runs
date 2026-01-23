module robot_path_fixer (
  input clk,
  input rst_n,
  input start,
  input [1:0] grid [0:15],
  input [2:0] cmd_length,
  input [7:0] commands,
  output reg [2:0] min_edits,
  output reg done
);

  // State machine states
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] EXPLORE_STATE = 3'b001;
  localparam [2:0] CHECK_GOAL = 3'b010;
  localparam [2:0] UPDATE_QUEUE = 3'b011;
  localparam [2:0] DONE = 3'b100;

  // State encoding: {pos_x[1:0], pos_y[1:0], cmd_idx[2:0], edits[1:0]}
  reg [7:0] state_queue [0:63]; // 64 entries max
  reg [8:0] queue_head = 0;
  reg [8:0] queue_tail = 0;
  reg [8:0] queue_size = 0;

  // Visited states (512 bits)
  reg [511:0] visited = 0;

  // Current state being processed
  reg [1:0] current_pos_x = 0;
  reg [1:0] current_pos_y = 0;
  reg [2:0] current_cmd_idx = 0;
  reg [1:0] current_edits = 0;

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Find start position
  reg [1:0] start_x = 0;
  reg [1:0] start_y = 0;
  reg start_found = 0;

  // Find goal position
  reg [1:0] goal_x = 0;
  reg [1:0] goal_y = 0;
  reg goal_found = 0;

  // Temporary variables for exploration
  reg [1:0] new_pos_x = 0;
  reg [1:0] new_pos_y = 0;
  reg [2:0] new_cmd_idx = 0;
  reg [1:0] new_edits = 0;

  // Counter for insert operations
  reg [1:0] insert_counter = 0;

  // Find start and goal positions
  always @(*) begin
    start_found = 0;
    goal_found = 0;
    for (int i = 0; i < 16; i = i + 1) begin
      if (grid[i] == 2'b10 && !start_found) begin
        start_x = i[3:2];
        start_y = i[1:0];
        start_found = 1;
      end
      if (grid[i] == 2'b11 && !goal_found) begin
        goal_x = i[3:2];
        goal_y = i[1:0];
        goal_found = 1;
      end
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      queue_head <= 0;
      queue_tail <= 0;
      queue_size <= 0;
      visited <= 0;
      min_edits <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          // Initialize queue with start state
          state_queue[0] = {start_x, start_y, 3'b000, 2'b00};
          queue_head = 0;
          queue_tail = 1;
          queue_size = 1;
          visited = 0;
          visited[{start_x, start_y, 3'b000, 2'b00}] = 1'b1;
          next_state = EXPLORE_STATE;
        end
      end

      EXPLORE_STATE: begin
        if (queue_size > 0) begin
          // Dequeue current state
          current_pos_x = state_queue[queue_head][7:6];
          current_pos_y = state_queue[queue_head][5:4];
          current_cmd_idx = state_queue[queue_head][3:1];
          current_edits = state_queue[queue_head][0:0];
          queue_head = queue_head + 1;
          queue_size = queue_size - 1;
          next_state = CHECK_GOAL;
        end else begin
          // Queue exhausted, no solution found
          min_edits = 3'b100; // Max edits
          done = 1'b1;
          next_state = DONE;
        end
      end

      CHECK_GOAL: begin
        if (current_pos_x == goal_x && current_pos_y == goal_y) begin
          min_edits = current_edits;
          done = 1'b1;
          next_state = DONE;
        end else begin
          next_state = UPDATE_QUEUE;
        end
      end

      UPDATE_QUEUE: begin
        // Explore three possibilities
        // 1. Execute current command
        if (current_cmd_idx < cmd_length) begin
          // Get current command
          reg [1:0] current_cmd = commands[current_cmd_idx*2 +: 2];
          // Calculate new position
          case (current_cmd)
            2'b00: begin // Left
              new_pos_x = current_pos_x - 1;
              new_pos_y = current_pos_y;
            end
            2'b01: begin // Right
              new_pos_x = current_pos_x + 1;
              new_pos_y = current_pos_y;
            end
            2'b10: begin // Up
              new_pos_x = current_pos_x;
              new_pos_y = current_pos_y - 1;
            end
            2'b11: begin // Down
              new_pos_x = current_pos_x;
              new_pos_y = current_pos_y + 1;
            end
          endcase

          // Check if new position is valid
          if (new_pos_x >= 0 && new_pos_x < 4 && new_pos_y >= 0 && new_pos_y < 4 && 
              grid[{new_pos_x, new_pos_y}] != 2'b01) begin
            // Valid move
            new_cmd_idx = current_cmd_idx + 1;
            new_edits = current_edits;
            // Check if state is visited
            if (!visited[{new_pos_x, new_pos_y, new_cmd_idx, new_edits}]) begin
              // Enqueue new state
              state_queue[queue_tail] = {new_pos_x, new_pos_y, new_cmd_idx, new_edits};
              queue_tail = queue_tail + 1;
              queue_size = queue_size + 1;
              visited[{new_pos_x, new_pos_y, new_cmd_idx, new_edits}] = 1'b1;
            end
          end
        end

        // 2. Delete current command
        if (current_cmd_idx < cmd_length) begin
          new_cmd_idx = current_cmd_idx + 1;
          new_edits = current_edits + 1;
          new_pos_x = current_pos_x;
          new_pos_y = current_pos_y;
          // Check if state is visited
          if (!visited[{new_pos_x, new_pos_y, new_cmd_idx, new_edits}]) begin
            // Enqueue new state
            state_queue[queue_tail] = {new_pos_x, new_pos_y, new_cmd_idx, new_edits};
            queue_tail = queue_tail + 1;
            queue_size = queue_size + 1;
            visited[{new_pos_x, new_pos_y, new_cmd_idx, new_edits}] = 1'b1;
          end
        end

        // 3. Insert new command
        if (current_edits < 2'b11) begin // Max edits is 3
          new_cmd_idx = current_cmd_idx;
          new_edits = current_edits + 1;
          // Try all 4 directions
          for (int i = 0; i < 4; i = i + 1) begin
            case (i)
              0: begin // Left
                new_pos_x = current_pos_x - 1;
                new_pos_y = current_pos_y;
              end
              1: begin // Right
                new_pos_x = current_pos_x + 1;
                new_pos_y = current_pos_y;
              end
              2: begin // Up
                new_pos_x = current_pos_x;
                new_pos_y = current_pos_y - 1;
              end
              3: begin // Down
                new_pos_x = current_pos_x;
                new_pos_y = current_pos_y + 1;
              end
            endcase

            // Check if new position is valid
            if (new_pos_x >= 0 && new_pos_x < 4 && new_pos_y >= 0 && new_pos_y < 4 && 
                grid[{new_pos_x, new_pos_y}] != 2'b01) begin
              // Check if state is visited
              if (!visited[{new_pos_x, new_pos_y, new_cmd_idx, new_edits}]) begin
                // Enqueue new state
                state_queue[queue_tail] = {new_pos_x, new_pos_y, new_cmd_idx, new_edits};
                queue_tail = queue_tail + 1;
                queue_size = queue_size + 1;
                visited[{new_pos_x, new_pos_y, new_cmd_idx, new_edits}] = 1'b1;
              end
            end
          end
        end

        next_state = EXPLORE_STATE;
      end

      DONE: begin
        // Stay in DONE state until reset
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule