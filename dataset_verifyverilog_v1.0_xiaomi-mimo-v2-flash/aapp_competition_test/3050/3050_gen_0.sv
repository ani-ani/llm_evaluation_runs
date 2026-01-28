module gl_bot_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] grid [0:7][0:7],
  input [3:0] prog [0:15],
  input [3:0] prog_len,
  input [3:0] start_row,
  input [3:0] start_col,
  output reg [1:0] result,
  output reg done,
  output reg valid
);

// State declarations
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] CHECK_CYCLE = 3'd2;
localparam [2:0] UPDATE = 3'd3;
localparam [2:0] COMPLETE = 3'd4;

// Instructions
localparam [3:0] LEFT = 4'd0;   // <
localparam [3:0] RIGHT = 4'd1;  // >
localparam [3:0] UP = 4'd2;     // ^
localparam [3:0] DOWN = 4'd3;   // v

// Maximum steps to prevent infinite loops
localparam [8:0] MAX_STEPS = 9'd256;

// Registers
reg [2:0] state;
reg [8:0] step_count;
reg [3:0] pc;  // Program counter
reg [3:0] curr_row, curr_col;
reg [3:0] prev_row, prev_col;  // For cycle detection
reg [3:0] prev2_row, prev2_col;  // For cycle length 2
reg [1:0] visited_cnt;  // Count of consecutive visited states
reg [7:0] cycle_length;  // Track cycle length

// Visited table: 8x8x4 = 128 entries
reg visited [0:127];
integer i;

// Combinational signals
reg [2:0] next_state;
reg [8:0] next_step_count;
reg [3:0] next_pc;
reg [3:0] next_row, next_col;
reg [3:0] next_prev_row, next_prev_col;
reg [3:0] next_prev2_row, next_prev2_col;
reg [1:0] next_visited_cnt;
reg [7:0] next_cycle_length;
reg [1:0] next_result;
reg next_done, next_valid;
reg [7:0] state_index;  // Index for visited table
reg [7:0] prev_state_index;
reg [7:0] prev2_state_index;
reg is_valid_move;
reg is_visited;
reg is_visited_prev;
reg is_visited_prev2;

// State index calculation: row * 8 + col * 2 + (pc >> 2)
// Since pc is 0-15, we use pc[3:2] to reduce to 4 states per position
always @(*) begin
  state_index = {curr_row, curr_col, pc[3:2]};
  prev_state_index = {prev_row, prev_col, pc[3:2]};
  prev2_state_index = {prev2_row, prev2_col, pc[3:2]};
end

// Check if visited
always @(*) begin
  is_visited = visited[state_index];
  is_visited_prev = visited[prev_state_index];
  is_visited_prev2 = visited[prev2_state_index];
end

// Check valid move (not wall and within bounds 1..6)
always @(*) begin
  if (next_row >= 8'd1 && next_row <= 8'd6 && 
      next_col >= 8'd1 && next_col <= 8'd6 &&
      grid[next_row][next_col] == 8'd0) begin
    is_valid_move = 1'b1;
  end else begin
    is_valid_move = 1'b0;
  end
end

// Next state logic
always @(*) begin
  // Default values
  next_state = state;
  next_step_count = step_count;
  next_pc = pc;
  next_row = curr_row;
  next_col = curr_col;
  next_prev_row = prev_row;
  next_prev_col = prev_col;
  next_prev2_row = prev2_row;
  next_prev2_col = prev2_col;
  next_visited_cnt = visited_cnt;
  next_cycle_length = cycle_length;
  next_result = result;
  next_done = done;
  next_valid = valid;

  case (state)
    IDLE: begin
      next_done = 1'b0;
      next_valid = 1'b0;
      next_step_count = 9'd0;
      if (start) begin
        next_state = INIT;
      end
    end

    INIT: begin
      // Initialize visited table
      // Clear visited flags (done over multiple cycles to avoid combinational loops)
      next_visited_cnt = 2'd0;  // Reuse as clear counter
      next_cycle_length = 8'd0;
      next_state = CHECK_CYCLE;
    end

    CHECK_CYCLE: begin
      // Check for cycles
      if (is_visited) begin
        // State already visited - cycle detected
        // Determine cycle length
        if (is_visited_prev) begin
          next_cycle_length = 8'd1;  // Same state repeated
        end else if (is_visited_prev2) begin
          next_cycle_length = 8'd2;  // 2-state cycle
        end else begin
          next_cycle_length = 8'd4;  // Larger cycle
        end
        next_state = COMPLETE;
      end else begin
        // Not visited - continue
        // Mark current state as visited
        visited[state_index] = 1'b1;  // Note: This is a procedural assignment to array
        next_visited_cnt = visited_cnt + 2'd1;
        
        // Get instruction
        if (pc < prog_len) begin
          case (prog[pc])
            LEFT: begin
              next_col = (curr_col > 8'd1) ? curr_col - 8'd1 : curr_col;
            end
            RIGHT: begin
              next_col = (curr_col < 8'd6) ? curr_col + 8'd1 : curr_col;
            end
            UP: begin
              next_row = (curr_row > 8'd1) ? curr_row - 8'd1 : curr_row;
            end
            DOWN: begin
              next_row = (curr_row < 8'd6) ? curr_row + 8'd1 : curr_row;
            end
            default: begin
              next_row = curr_row;
              next_col = curr_col;
            end
          endcase
          
          // Check if move hits wall
          if (grid[next_row][next_col] == 8'd1) begin
            // Hit wall - stay in place
            next_row = curr_row;
            next_col = curr_col;
          end
          
          // Update program counter
          next_pc = (pc + 4'd1) % prog_len;
        end else begin
          next_pc = 4'd0;
          next_row = curr_row;
          next_col = curr_col;
        end
        
        // Update previous positions
        next_prev2_row = prev_row;
        next_prev2_col = prev_col;
        next_prev_row = curr_row;
        next_prev_col = curr_col;
        
        // Check step count
        next_step_count = step_count + 9'd1;
        if (step_count >= MAX_STEPS) begin
          // Assume cycle if timeout
          next_cycle_length = 8'd4;
          next_state = COMPLETE;
        end else begin
          next_state = UPDATE;
        end
      end
    end

    UPDATE: begin
      // Update current position
      // Check for cycle again with new position
      // We'll check in next cycle
      next_state = CHECK_CYCLE;
    end

    COMPLETE: begin
      // Set outputs based on cycle_length
      if (step_count == 9'd0) begin
        // No steps taken
        next_result = 2'b00;  // Finite
        next_valid = 1'b1;
      end else if (next_cycle_length == 8'd1) begin
        next_result = 2'b01;  // Cycle length 1
        next_valid = 1'b1;
      end else if (next_cycle_length == 8'd2) begin
        next_result = 2'b10;  // Cycle length 2
        next_valid = 1'b1;
      end else begin
        next_result = 2'b11;  // Cycle length 4 (or larger)
        next_valid = 1'b1;
      end
      next_done = 1'b1;
      next_state = IDLE;
    end

    default: begin
      next_state = IDLE;
    end
  endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    step_count <= 9'd0;
    pc <= 4'd0;
    curr_row <= 4'd0;
    curr_col <= 4'd0;
    prev_row <= 4'd0;
    prev_col <= 4'd0;
    prev2_row <= 4'd0;
    prev2_col <= 4'd0;
    visited_cnt <= 2'd0;
    cycle_length <= 8'd0;
    result <= 2'b00;
    done <= 1'b0;
    valid <= 1'b0;
    // Initialize visited array
    for (i = 0; i < 128; i = i + 1) begin
      visited[i] <= 1'b0;
    end
  end else begin
    state <= next_state;
    step_count <= next_step_count;
    pc <= next_pc;
    curr_row <= next_row;
    curr_col <= next_col;
    prev_row <= next_prev_row;
    prev_col <= next_prev_col;
    prev2_row <= next_prev2_row;
    prev2_col <= next_prev2_col;
    visited_cnt <= next_visited_cnt;
    cycle_length <= next_cycle_length;
    result <= next_result;
    done <= next_done;
    valid <= next_valid;
    
    // Initialize visited table when entering INIT state
    if (next_state == INIT) begin
      for (i = 0; i < 128; i = i + 1) begin
        visited[i] <= 1'b0;
      end
    end
    
    // Initialize current position when start is asserted
    if (start) begin
      curr_row <= start_row;
      curr_col <= start_col;
    end
  end
end

endmodule