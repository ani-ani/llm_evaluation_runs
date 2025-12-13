module zamboni_controller(
  input clk,
  input rst_n,
  input start,
  input [2:0] r,
  input [2:0] c,
  input [2:0] start_i,
  input [2:0] start_j,
  input [3:0] n,
  output reg [4:0] grid [0:7][0:7],
  output reg done
);

  // Direction encoding: 2'b00: up, 2'b01: right, 2'b10: down, 2'b11: left

  // State encoding
  localparam [1:0]
    S_IDLE  = 2'b00,
    S_STEP  = 2'b01,
    S_DONE  = 2'b10;

  reg [1:0] state, next_state;

  // Internal registers
  reg [2:0] rows;
  reg [2:0] cols;

  reg [2:0] cur_i;           // current row index
  reg [2:0] cur_j;           // current column index
  reg [1:0] dir;             // current direction
  reg [4:0] color;           // current color code (2-27 for A-Z)
  reg [3:0] step_cnt;        // number of completed big steps (0..n)
  reg [3:0] stepSize;        // movement length for current big step
  reg [3:0] move_cnt;        // counter for individual moves in a step
  reg [3:0] total_steps;     // latched n

  integer i, j;

  // Helper: modulo wrap for 3-bit index within rows/cols
  function automatic [2:0] wrap_row;
    input [2:0] idx;
    input [2:0] max_r;
    begin
      if (idx >= max_r)
        wrap_row = idx - max_r;
      else
        wrap_row = idx;
    end
  endfunction

  function automatic [2:0] wrap_col;
    input [2:0] idx;
    input [2:0] max_c;
    begin
      if (idx >= max_c)
        wrap_col = idx - max_c;
      else
        wrap_col = idx;
    end
  endfunction

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start && (n != 4'd0))
          next_state = S_STEP;
      end

      S_STEP: begin
        // Transition to DONE when all big steps finished and last move placed
        if ((step_cnt == total_steps) && (move_cnt == 4'd0))
          next_state = S_DONE;
      end

      S_DONE: begin
        // Wait here until start is deasserted (simple protocol)
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state machine and clear grid
      state       <= S_IDLE;
      done        <= 1'b0;
      rows        <= 3'd0;
      cols        <= 3'd0;
      cur_i       <= 3'd0;
      cur_j       <= 3'd0;
      dir         <= 2'b00;
      color       <= 5'd2; // 'A'
      step_cnt    <= 4'd0;
      stepSize    <= 4'd1;
      move_cnt    <= 4'd0;
      total_steps <= 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          grid[i][j] <= 5'd0;
        end
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          // When new start, initialize parameters and grid
          if (start && (n != 4'd0)) begin
            // Latch dimensions (at least 1, max 8 via 3 bits)
            rows <= (r == 3'd0) ? 3'd1 : r;
            cols <= (c == 3'd0) ? 3'd1 : c;

            // Clear grid
            for (i = 0; i < 8; i = i + 1) begin
              for (j = 0; j < 8; j = j + 1) begin
                grid[i][j] <= 5'd0;
              end
            end

            // Latch total steps
            total_steps <= n;

            // Initialize starting position (start_i/j are 1-based)
            cur_i <= (start_i == 3'd0) ? 3'd0 : (start_i - 3'd1);
            cur_j <= (start_j == 3'd0) ? 3'd0 : (start_j - 3'd1);

            // Initial direction and color and step params
            dir      <= 2'b00;    // up
            color    <= 5'd2;     // 'A'
            step_cnt <= 4'd0;
            stepSize <= 4'd1;
            move_cnt <= 4'd0;

            // Mark initial cell with initial color in next cycle via S_STEP
          end
        end

        S_STEP: begin
          // Zamboni algorithm core
          if (step_cnt < total_steps) begin
            // If starting a new big step (move_cnt == 0): place color in current cell
            if (move_cnt == 4'd0) begin
              grid[cur_i][cur_j] <= color;
              move_cnt <= 4'd1;
            end else if (move_cnt < stepSize) begin
              // Continue moving in current direction
              case (dir)
                2'b00: begin // up
                  if (cur_i == 3'd0)
                    cur_i <= rows - 3'd1;
                  else
                    cur_i <= cur_i - 3'd1;
                end
                2'b01: begin // right
                  if (cur_j == (cols - 3'd1))
                    cur_j <= 3'd0;
                  else
                    cur_j <= cur_j + 3'd1;
                end
                2'b10: begin // down
                  if (cur_i == (rows - 3'd1))
                    cur_i <= 3'd0;
                  else
                    cur_i <= cur_i + 3'd1;
                end
                2'b11: begin // left
                  if (cur_j == 3'd0)
                    cur_j <= cols - 3'd1;
                  else
                    cur_j <= cur_j - 3'd1;
                end
              endcase

              // After movement, color the new cell
              grid[cur_i][cur_j] <= color;

              move_cnt <= move_cnt + 4'd1;
            end else begin
              // Finished this big step: rotate dir, next color, inc stepSize
              // Direction: rotate 90 deg clockwise
              dir <= dir + 2'b01;

              // Color: next letter, wrap Z->A (2..27)
              if (color == 5'd27)
                color <= 5'd2;
              else
                color <= color + 5'd1;

              // Prepare for next big step
              step_cnt <= step_cnt + 4'd1;
              stepSize <= stepSize + 4'd1;
              move_cnt <= 4'd0;
            end
          end else begin
            // All big steps done: mark final position with '@' and go DONE
            grid[cur_i][cur_j] <= 5'd1; // '@'
            move_cnt <= 4'd0;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // Hold grid and final position until next reset/start sequence
        end

        default: begin
          // Should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule