module turtle_tracker(
  input clk,   // clock
  input rst_n, // active-low reset
  input start, // start processing
  // Target grid (4x4) packed into 16-bit vector (bit=1: #, 0: .)
  input [15:0] target_grid, 
  // Preloaded commands (8 commands max):    
  //   [2:0]: direction encoding (00=up, 01=down, 10=left, 11=right)
  //   [7:4]: distance (0-15 max)
  input [7:0] cmd_0, cmd_1, cmd_2, cmd_3, cmd_4, cmd_5, cmd_6, cmd_7, 
  input [2:0] num_cmds, // actual number of commands (0-7)
  output reg [6:0] min_time, // earliest dry time (7 bits, max 120 timesteps)
  output reg [6:0] max_time, // latest dry time
  output reg done,  // high when computation complete
  output reg valid_result // high when solution exists (else output -1,-1)
);

  // Directions
  localparam DIR_UP    = 2'b00;
  localparam DIR_DOWN  = 2'b01;
  localparam DIR_LEFT  = 2'b10;
  localparam DIR_RIGHT = 2'b11;

  // State machine
  localparam S_IDLE    = 2'b00;
  localparam S_RUN     = 2'b01;
  localparam S_ANALYZE = 2'b10;
  localparam S_DONE    = 2'b11;

  // 4x4 grid = 16 cells
  // Track first and last mark times per cell (in timesteps)
  reg [6:0] first_mark [0:15];
  reg [6:0] last_mark  [0:15];

  // Current position
  reg [1:0] cur_row; // 0..3, 0 is top row
  reg [1:0] cur_col; // 0..3, 0 is leftmost col
  reg [6:0] cur_time;

  // Control FSM
  reg [1:0] state, next_state;
  reg [2:0] cmd_idx, next_cmd_idx;    // which command (0..7)
  reg [3:0] steps_todo, next_steps_todo; // steps remaining in current command
  reg next_step_en;                    // whether a step occurs on this cycle

  // Helpful vectors
  wire [7:0] cmds [0:7];
  assign cmds[0] = cmd_0;
  assign cmds[1] = cmd_1;
  assign cmds[2] = cmd_2;
  assign cmds[3] = cmd_3;
  assign cmds[4] = cmd_4;
  assign cmds[5] = cmd_5;
  assign cmds[6] = cmd_6;
  assign cmds[7] = cmd_7;

  // Current command parts
  wire [1:0] cur_dir;
  wire [3:0] cur_dist;
  assign cur_dir  = cmds[cmd_idx][2:0];
  assign cur_dist = cmds[cmd_idx][7:4];

  // Step control
  function [3:0] clamp_distance;
    input [1:0] dir;
    input [1:0] row;
    input [1:0] col;
    input [3:0] dist;
    begin
      case (dir)
        DIR_UP:    clamp_distance = (row >= dist) ? dist : row;
        DIR_DOWN:  clamp_distance = ((3-row) >= dist) ? dist : (3-row);
        DIR_LEFT:  clamp_distance = (col >= dist) ? dist : col;
        DIR_RIGHT: clamp_distance = ((3-col) >= dist) ? dist : (3-col);
        default:   clamp_distance = 4'd0;
      endcase
    end
  endfunction

  function can_step_one;
    input [1:0] dir;
    input [1:0] row;
    input [1:0] col;
    begin
      case (dir)
        DIR_UP:    can_step_one = (row > 0);
        DIR_DOWN:  can_step_one = (row < 3);
        DIR_LEFT:  can_step_one = (col > 0);
        DIR_RIGHT: can_step_one = (col < 3);
        default:   can_step_one = 1'b0;
      endcase
    end
  endfunction

  function [1:0] next_row;
    input [1:0] dir;
    input [1:0] row;
    begin
      case (dir)
        DIR_UP:    next_row = row - 1;
        DIR_DOWN:  next_row = row + 1;
        default:   next_row = row;
      endcase
    end
  endfunction

  function [1:0] next_col;
    input [1:0] dir;
    input [1:0] col;
    begin
      case (dir)
        DIR_LEFT:  next_col = col - 1;
        DIR_RIGHT: next_col = col + 1;
        default:   next_col = col;
      endcase
    end
  endfunction

  // State register and simulation time
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      cur_time <= 7'd0;
      cmd_idx <= 3'd0;
      steps_todo <= 4'd0;
      next_step_en <= 1'b0;
      cur_row <= 2'd3; // bottom row
      cur_col <= 2'd0; // leftmost col
    end else begin
      state <= next_state;
      cmd_idx <= next_cmd_idx;
      steps_todo <= next_steps_todo;
      next_step_en <= next_step_en_reg;
      if (state == S_IDLE) begin
        cur_time <= 7'd0;
        cur_row <= 2'd3;
        cur_col <= 2'd0;
      end else if (state == S_RUN) begin
        if (next_step_en) begin
          cur_time <= cur_time + 1'b1;
          cur_row <= next_row(cur_dir, cur_row);
          cur_col <= next_col(cur_dir, cur_col);
        end
      end
    end
  end

  // Persist timers and FSM per-cell updates
  reg [6:0] next_first [0:15];
  reg [6:0] next_last  [0:15];
  reg next_step_en_reg;
  integer i;
  always @(*) begin
    // Default: hold current values
    for (i = 0; i < 16; i = i + 1) begin
      next_first[i] = first_mark[i];
      next_last[i]  = last_mark[i];
    end
    next_step_en_reg = 1'b0;
  end

  // Next-state logic and updates
  always @(*) begin
    // Defaults
    next_state = state;
    next_cmd_idx = cmd_idx;
    next_steps_todo = steps_todo;
    next_step_en_reg = 1'b0;

    // Copy current timers for safety in simulation
    for (i = 0; i < 16; i = i + 1) begin
      next_first[i] = first_mark[i];
      next_last[i]  = last_mark[i];
    end

    case (state)
      S_IDLE: begin
        if (start) begin
          // Initialize trackers
          for (i = 0; i < 16; i = i + 1) begin
            next_first[i] = 7'd0; // Unmarked at time 0
            next_last[i]  = 7'd0;
          end
          // Start position is bottom-left (3,0) at time 0
          next_cmd_idx = 3'd0;
          next_steps_todo = 4'd0;
          next_step_en_reg = 1'b0;
          next_state = S_RUN;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_RUN: begin
        if (cmd_idx >= num_cmds) begin
          // No more commands: analyze
          next_state = S_ANALYZE;
          next_cmd_idx = 3'd0;  // irrelevant until next start
          next_steps_todo = 4'd0;
          next_step_en_reg = 1'b0;
        end else begin
          // If this is the first cycle for a new command, (re)compute steps to do
          if (steps_todo == 4'd0) begin
            next_steps_todo = clamp_distance(cur_dir, cur_row, cur_col, cur_dist);
          end
          // Check if we can still take a step for this command
          if (steps_todo > 4'd0) begin
            if (can_step_one(cur_dir, cur_row, cur_col)) begin
              next_step_en_reg = 1'b1;
              next_steps_todo = steps_todo - 1'b1;
              // Update timers at target cell for next timestep
              next_first[ {cur_row, cur_col} ] = (cur_time + 1'b1);
              next_last[  {cur_row, cur_col} ] = (cur_time + 1'b1);
            end else begin
              // Should not happen because steps_todo was clamped, but guard anyway
              next_steps_todo = 4'd0;
              next_step_en_reg = 1'b0;
            end
          end else begin
            // Finished current command, advance to next
            next_step_en_reg = 1'b0;
            next_cmd_idx = cmd_idx + 1'b1;
            next_steps_todo = 4'd0;
          end
        end
      end

      S_ANALYZE: begin
        // Compute min and max times over target cells that were marked
        // valid_result will be set accordingly by the sequential block below
        next_state = S_DONE;
      end

      S_DONE: begin
        // Hold results; wait for next start
        if (!start) begin
          next_state = S_DONE;
        end else begin
          // Restart on start
          for (i = 0; i < 16; i = i + 1) begin
            next_first[i] = 7'd0;
            next_last[i]  = 7'd0;
          end
          next_cmd_idx = 3'd0;
          next_steps_todo = 4'd0;
          next_step_en_reg = 1'b0;
          next_state = S_RUN;
        end
      end
    endcase
  end

  // Update the per-cell timers
  always @(posedge clk) begin
    if (state == S_IDLE) begin
      if (start) begin
        for (i = 0; i < 16; i = i + 1) begin
          first_mark[i] <= 7'd0;
          last_mark[i]  <= 7'd0;
        end
      end
    end else if (state == S_RUN) begin
      if (next_step_en) begin
        first_mark[{cur_row, cur_col}] <= next_first[{cur_row, cur_col}];
        last_mark[ {cur_row, cur_col}] <= next_last[ {cur_row, cur_col}];
      end
    end
  end

  // Outputs and analysis
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_time <= 7'd0;
      max_time <= 7'd0;
      done <= 1'b0;
      valid_result <= 1'b0;
    end else begin
      if (state == S_ANALYZE) begin
        // Scan target cells and compute min/max times
        // valid_result = 1 only if all # cells have been marked at least once
        // min_time = MAX of all first_mark over target cells
        // max_time = MIN of all last_mark  over target cells
        // If any # has never been marked (first_mark == 0 && last_mark == 0), set valid_result=0 and min/max=-1
        valid_result <= 1'b1;
        min_time <= 7'd0;
        max_time <= 7'd127; // set high initially so MIN can reduce
        for (i = 0; i < 16; i = i + 1) begin
          if (target_grid[i]) begin
            // Target requires coverage
            if ((first_mark[i] == 7'd0) && (last_mark[i] == 7'd0)) begin
              valid_result <= 1'b0;
            end else begin
              if (first_mark[i] > min_time) min_time <= first_mark[i];
              if (last_mark[i] < max_time)  max_time <= last_mark[i];
            end
          end
        end
        if (valid_result) begin
          // If no # at all, min_time and max_time should be 0
          if (max_time == 7'd127) max_time <= 7'd0;
        end else begin
          min_time <= 7'b1111111; // -1 in 7-bit unsigned
          max_time <= 7'b1111111;
        end
        done <= 1'b0;
      end else if (state == S_DONE) begin
        done <= 1'b1;
        // valid_result, min_time, max_time are held from S_ANALYZE
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule