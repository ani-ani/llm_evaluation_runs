module boredom_counter (
  input clk,
  input rst_n,
  input start,
  input [3:0] str_len,
  input [15:0][7:0] str_data,
  output reg [2:0] count,
  output reg done
);

  localparam [7:0] DELIM_DOT   = 8'h2E; // '.'
  localparam [7:0] DELIM_QMARK = 8'h3F; // '?'
  localparam [7:0] DELIM_EXCLA = 8'h21; // '!'
  localparam [7:0] CAPITAL_I   = 8'h49; // 'I'

  // State encoding
  localparam IDLE = 2'b00;
  localparam RUN  = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [4:0] run_cnt;        // 0..16
  reg [4:0] next_run_cnt;
  reg [3:0] char_idx;
  reg [3:0] next_char_idx;
  reg next_is_start;        // 1 when next char is considered sentence start
  reg next_next_is_start;
  reg [2:0] next_count;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      run_cnt <= 5'd0;
      char_idx <= 4'd0;
      next_is_start <= 1'b1;
      count <= 3'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      run_cnt <= next_run_cnt;
      char_idx <= next_char_idx;
      next_is_start <= next_next_is_start;
      count <= next_count;
      done <= (next_state == DONE);
    end
  end

  // Combinational next-state logic
  always @* begin
    // Defaults
    next_state = state;
    next_run_cnt = run_cnt;
    next_char_idx = char_idx;
    next_next_is_start = next_is_start;
    next_count = count;

    case (state)
      IDLE: begin
        next_run_cnt = 5'd0;
        next_char_idx = 4'd0;
        next_next_is_start = 1'b1; // Sentence start at index 0
        next_count = 3'd0;
        if (start) begin
          next_state = RUN;
        end
      end

      RUN: begin
        // Output currently held from previous cycle (safe default)
        next_count = count;
        next_next_is_start = next_is_start;
        next_char_idx = char_idx;
        next_run_cnt = run_cnt;

        // Process one character per cycle
        if (run_cnt < 5'd16) begin
          // Current char and flags
          reg [7:0] ch;
          reg is_delim;
          ch = str_data[char_idx];
          is_delim = (ch == DELIM_DOT) || (ch == DELIM_QMARK) || (ch == DELIM_EXCLA);

          // Count 'I' at sentence start
          if (next_is_start && (ch == CAPITAL_I)) begin
            next_count = count + 1'b1;
          end

          // Update sentence start flag after current char
          next_next_is_start = is_delim;

          // Advance indices
          next_char_idx = char_idx + 1'b1;
          next_run_cnt = run_cnt + 1'b1;

          // If last character, go to DONE next cycle
          if (run_cnt == 5'd15) begin
            next_state = DONE;
          end
        end else begin
          // Should not happen: safeguard
          next_state = DONE;
        end
      end

      DONE: begin
        next_count = count;       // Hold final result
        next_run_cnt = 5'd16;
        next_char_idx = 4'd0;
        next_next_is_start = 1'b1;
        if (!start) begin
          next_state = IDLE;      // Arm for next start pulse
        end
      end

      default: begin
        next_state = IDLE;
        next_run_cnt = 5'd0;
        next_char_idx = 4'd0;
        next_next_is_start = 1'b1;
        next_count = 3'd0;
      end
    endcase
  end

endmodule
