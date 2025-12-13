module zamboni_controller(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start signal
  input [2:0] r, // rows (3-bit, max 8)
  input [2:0] c, // columns (3-bit, max 8)
  input [2:0] start_i, // start row (1-8)
  input [2:0] start_j, // start column (1-8)
  input [3:0] n, // num steps (4-bit, max 16)
  output reg [4:0] grid [0:7][0:7], // 8x8 grid (5 bits: 0=., 1=@, 2-27=A-Z)
  output reg done // high when finished
);

  // Grid/char constants
  localparam GRID_W = 8;
  localparam GRID_H = 8;
  localparam CHAR_DOT = 5'd0;
  localparam CHAR_AT  = 5'd1;
  localparam CHAR_A   = 5'd2;
  localparam CHAR_Z   = 5'd27;

  // FSM states
  localparam ST_IDLE = 1'b0;
  localparam ST_RUN  = 1'b1;

  // Direction encoding: 00=up, 01=right, 10=down, 11=left
  reg state;
  reg start_sync, start_prev;

  // Iteration and step counters
  reg [3:0] step_size;       // 1..n per-iteration step size
  reg [3:0] iter_cnt;        // 1..n iteration counter
  reg [3:0] step_cnt;        // 0..step_size-1 within an iteration

  // Position and direction
  reg [2:0] cur_x, cur_y;    // current grid cell (0..7)
  reg [1:0] dir;             // 2-bit direction

  // Letter/color state: 2..27 (A..Z)
  reg [4:0] letter_val;      // current color value (2..27)

  // Internal wires for next values
  wire [2:0] nxt_x, nxt_y;
  wire [4:0] next_letter;
  wire [1:0] next_dir;

  // Next-position logic based on direction with wrapping
  assign nxt_x = (dir == 2'b00) ? (cur_x - 1) :
                 (dir == 2'b10) ? (cur_x + 1) : cur_x;
  assign nxt_y = (dir == 2'b01) ? (cur_y + 1) :
                 (dir == 2'b11) ? (cur_y - 1) : cur_y;
  // Wrap within 0..7 using modulo 8
  assign nxt_x = nxt_x % GRID_W;
  assign nxt_y = nxt_y % GRID_H;

  // Next letter wraps Z->A
  assign next_letter = (letter_val == CHAR_Z) ? CHAR_A : (letter_val + 1);

  // Next direction: 90° clockwise rotation
  // 00(up)->01(right)->10(down)->11(left)->00
  assign next_dir = (dir == 2'b00) ? 2'b01 :
                    (dir == 2'b01) ? 2'b10 :
                    (dir == 2'b10) ? 2'b11 : 2'b00;

  integer i, j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset state
      state <= ST_IDLE;
      done <= 1'b0;
      start_sync <= 1'b0;
      start_prev <= 1'b0;

      // Clear grid
      for (i = 0; i < GRID_W; i = i + 1) begin
        for (j = 0; j < GRID_H; j = j + 1) begin
          grid[i][j] <= CHAR_DOT;
        end
      end

      // Counters and control
      step_size <= 4'd0;
      iter_cnt  <= 4'd0;
      step_cnt  <= 4'd0;

      // Position, direction, color
      cur_x     <= 3'd0;
      cur_y     <= 3'd0;
      dir       <= 2'b00;
      letter_val<= CHAR_A;
    end else begin
      // Synchronize/start edge detection
      start_sync <= start;
      start_prev <= start_sync;

      case (state)
        ST_IDLE: begin
          if (start_prev && !start_sync) begin
            // Initialize
            done      <= 1'b0;

            // Clear grid
            for (i = 0; i < GRID_W; i = i + 1) begin
              for (j = 0; j < GRID_H; j = j + 1) begin
                grid[i][j] <= CHAR_DOT;
              end
            end

            // Start position (1-based inputs)
            cur_x <= (start_j - 1) % GRID_W;
            cur_y <= (start_i - 1) % GRID_H;

            // Control
            step_size <= 4'd1;     // first iteration uses 1 step
            iter_cnt  <= 4'd1;     // just started first iteration
            step_cnt  <= 4'd0;     // no steps taken yet in this iteration

            // Direction and color
            dir       <= 2'b00;    // initial direction: up
            letter_val<= CHAR_A;   // initial color: 'A'

            state <= ST_RUN;
          end else begin
            done <= 1'b0;
          end
        end

        ST_RUN: begin
          // One step per cycle in current direction
          if (iter_cnt > 0 && iter_cnt <= n) begin
            // Move and paint current cell with current letter
            grid[cur_x][cur_y] <= letter_val;

            // Advance position
            cur_x <= nxt_x;
            cur_y <= nxt_y;

            // Update step counter
            step_cnt <= step_cnt + 1;

            // If finished all steps in this iteration, prepare next iteration
            if (step_cnt == (step_size - 1)) begin
              // Rotate direction
              dir <= next_dir;
              // Next letter
              letter_val <= next_letter;
              // Prepare next iteration or finish
              if (iter_cnt == n) begin
                // Mark final cell as '@'
                grid[cur_x][cur_y] <= CHAR_AT;
                done <= 1'b1;
                state <= ST_IDLE;
              end else begin
                iter_cnt <= iter_cnt + 1;
                step_size <= step_size + 1;
                step_cnt <= 4'd0;
              end
            end
          end else begin
            // Should not happen; safety fallback
            done <= 1'b1;
            state <= ST_IDLE;
          end
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule
