module gl_bot_tracker(
  input clk,
  input rst_n,
  input start,
  input [63:0] grid_data,
  input [63:0] cmd_str,
  input [2:0] grid_size,
  input [2:0] start_row,
  input [2:0] start_col,
  output reg [5:0] result_x,
  output reg done
);

  // State enumeration
  typedef enum logic [1:0] {IDLE = 2'b00, SIMUL = 2'b01, DONE = 2'b10} state_t;
  state_t state, next_state;

  // Internal registers
  reg [5:0] step_cnt;
  reg [2:0] cur_row, cur_col;
  reg [2:0] cmd_idx;
  reg moved;
  reg start_d, start_rise;

  // Visited state memory (512 entries of 6 bits)
  reg [5:0] visited_step [0:511];
  integer i;

  // Combinational next-state signals
  logic [2:0] next_cur_row, next_cur_col, next_cmd_idx;
  logic [5:0] next_step_cnt;
  logic next_moved;
  logic [5:0] next_result_x;
  logic next_done;

  // Edge detection for start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
      start_rise <= 1'b0;
    end else begin
      start_rise <= start && (!start_d);
      start_d <= start;
    end
  end

  // Main state machine and data path
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state
      state <= IDLE;
      result_x <= 6'h0;
      done <= 1'b0;
      step_cnt <= 6'h0;
      cur_row <= 3'h0;
      cur_col <= 3'h0;
      cmd_idx <= 3'h0;
      moved <= 1'b0;
      // Initialise visited_step array to sentinel value
      for (i = 0; i < 512; i++) begin
        visited_step[i] <= 6'h3F; // sentinel = max step value
      end
    end else begin
      // Default (hold) assignments
      next_state = state;
      next_cur_row = cur_row;
      next_cur_col = cur_col;
      next_cmd_idx = cmd_idx;
      next_step_cnt = step_cnt;
      next_moved = moved;
      next_result_x = result_x;
      next_done = done;

      case (state)
        IDLE: begin
          if (start_rise) begin
            // Capture initial position
            next_state = SIMUL;
            next_cur_row = start_row;
            next_cur_col = start_col;
            next_cmd_idx = 3'h0;
            next_step_cnt = 6'h0;
            next_moved = 1'b0;
            next_result_x = 6'h0;
            next_done = 1'b0;
            // Mark the initial state as visited (step 0)
            visited_step[{start_row, start_col, 3'h0}] <= 6'h0;
          end
        end
        SIMUL: begin
          // Decode the current command
          logic [7:0] cmd_byte;
          cmd_byte = cmd_str[8*cmd_idx +: 8];
          // Compute tentative new coordinates
          logic [2:0] new_row, new_col;
          new_row = cur_row;
          new_col = cur_col;
          case (cmd_byte)
            8'h3C: // '<'
              new_col = (cur_col > 0) ? (cur_col - 1) : cur_col;
            8'h3E: // '>'
              new_col = (cur_col < (grid_size - 1)) ? (cur_col + 1) : cur_col;
            8'h5E: // '^'
              new_row = (cur_row > 0) ? (cur_row - 1) : cur_row;
            8'h76: // 'v'
              new_row = (cur_row < (grid_size - 1)) ? (cur_row + 1) : cur_row;
            default: ; // No move for any other character
          endcase
          // Apply move if inside the current grid and cell is passable
          if ((new_row < grid_size) && (new_col < grid_size) && grid_data[(new_row*8 + new_col)]) begin
            next_cur_row = new_row;
            next_cur_col = new_col;
            next_moved = 1'b1;
          end

          // Advance the step counter
          next_step_cnt = step_cnt + 1;

          // Advance command index (wrap after 7)
          next_cmd_idx = (cmd_idx + 1) % 8;

          // Build the index for the new state
          logic [8:0] next_index;
          next_index = {next_cur_row, next_cur_col, next_cmd_idx};

          // Check if this state has been seen before
          if (visited_step[next_index] != 6'h3F) begin
            // Cycle found
            logic [5:0] cycle_len;
            cycle_len = next_step_cnt - visited_step[next_index];
            if (!moved) begin
              // Never moved => finite trail
              next_result_x = 6'h1;
            end else begin
              next_result_x = cycle_len;
            end
            next_done = 1'b1;
            next_state = DONE;
          end else begin
            // First time at this state: record the step count
            visited_step[next_index] <= next_step_cnt;
            // Reached the maximum number of steps (64) without finding a cycle
            if (next_step_cnt == 6'h3F) begin
              next_result_x = 6'h1; // treat as finite trail
              next_done = 1'b1;
              next_state = DONE;
            end
          end
        end
        DONE: begin
          // Hold the result and the done flag
          next_result_x = result_x;
          next_done = 1'b1;
        end
        default: ;
      endcase

      // Register the next values
      state <= next_state;
      cur_row <= next_cur_row;
      cur_col <= next_cur_col;
      cmd_idx <= next_cmd_idx;
      step_cnt <= next_step_cnt;
      moved <= next_moved;
      result_x <= next_result_x;
      done <= next_done;
    end
  end
endmodule