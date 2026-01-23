module surgery_solver (
  input clk,
  input rst_n,
  input start,
  input [5:0] grid_in [0:5],
  output reg [2:0] move_out,
  output reg move_valid,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SOLVE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal grid representation (2x3)
  reg [2:0] grid [0:5];

  // Empty space position (row, col)
  reg [0:0] empty_row;
  reg [1:0] empty_col;

  // Step counter to prevent infinite loops
  reg [7:0] step_count;

  // Target state
  localparam [2:0] TARGET [0:5] = '{1, 2, 3, 4, 5, 6};

  // Move encoding
  localparam [2:0] MOVE_NONE = 3'b000;
  localparam [2:0] MOVE_UP = 3'b001;
  localparam [2:0] MOVE_DOWN = 3'b010;
  localparam [2:0] MOVE_LEFT = 3'b011;
  localparam [2:0] MOVE_RIGHT = 3'b100;

  // Find empty space position
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      empty_row <= 0;
      empty_col <= 0;
    end else if (start) begin
      for (int i = 0; i < 6; i = i + 1) begin
        if (grid_in[i] == 0) begin
          empty_row <= (i >= 3) ? 1 : 0;
          empty_col <= (i % 3);
        end
      end
    end else if (move_valid) begin
      // Update empty position based on move
      case (move_out)
        MOVE_UP: begin
          empty_row <= empty_row - 1;
          empty_col <= empty_col;
        end
        MOVE_DOWN: begin
          empty_row <= empty_row + 1;
          empty_col <= empty_col;
        end
        MOVE_LEFT: begin
          empty_row <= empty_row;
          empty_col <= empty_col - 1;
        end
        MOVE_RIGHT: begin
          empty_row <= empty_row;
          empty_col <= empty_col + 1;
        end
      endcase
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      move_out <= MOVE_NONE;
      move_valid <= 0;
      done <= 0;
      step_count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    move_out = MOVE_NONE;
    move_valid = 0;
    done = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SOLVE;
          // Initialize grid
          for (int i = 0; i < 6; i = i + 1) begin
            grid[i] = grid_in[i];
          end
          step_count = 0;
        end
      end

      SOLVE: begin
        // Check if solved
        if (grid[0] == TARGET[0] && grid[1] == TARGET[1] && 
            grid[2] == TARGET[2] && grid[3] == TARGET[3] && 
            grid[4] == TARGET[4] && grid[5] == TARGET[5]) begin
          next_state = DONE;
          done = 1;
        end
        // Check step limit (prevent infinite loops)
        else if (step_count >= 100) begin
          next_state = DONE;
          done = 1;
        end
        else begin
          // Determine possible moves
          move_out = MOVE_NONE;
          move_valid = 0;

          // Check left move
          if (empty_col > 0) begin
            move_out = MOVE_LEFT;
            move_valid = 1;
          end
          // Check right move
          else if (empty_col < 2) begin
            move_out = MOVE_RIGHT;
            move_valid = 1;
          end
          // Check up move (only if in valid columns)
          else if (empty_row > 0 && (empty_col == 0 || empty_col == 1 || empty_col == 2)) begin
            move_out = MOVE_UP;
            move_valid = 1;
          end
          // Check down move (only if in valid columns)
          else if (empty_row < 1 && (empty_col == 0 || empty_col == 1 || empty_col == 2)) begin
            move_out = MOVE_DOWN;
            move_valid = 1;
          end

          // If no valid move, mark as done (failed)
          if (!move_valid) begin
            next_state = DONE;
            done = 1;
          end
        end
      end

      DONE: begin
        // Stay in DONE state
      end
    endcase
  end

  // Update grid based on move
  always @(posedge clk) begin
    if (move_valid) begin
      case (move_out)
        MOVE_UP: begin
          grid[empty_row * 3 + empty_col] <= grid[(empty_row - 1) * 3 + empty_col];
          grid[(empty_row - 1) * 3 + empty_col] <= 0;
        end
        MOVE_DOWN: begin
          grid[empty_row * 3 + empty_col] <= grid[(empty_row + 1) * 3 + empty_col];
          grid[(empty_row + 1) * 3 + empty_col] <= 0;
        end
        MOVE_LEFT: begin
          grid[empty_row * 3 + empty_col] <= grid[empty_row * 3 + empty_col - 1];
          grid[empty_row * 3 + empty_col - 1] <= 0;
        end
        MOVE_RIGHT: begin
          grid[empty_row * 3 + empty_col] <= grid[empty_row * 3 + empty_col + 1];
          grid[empty_row * 3 + empty_col + 1] <= 0;
        end
      endcase
      step_count <= step_count + 1;
    end
  end

endmodule