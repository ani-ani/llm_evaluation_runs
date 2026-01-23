module sublist_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0] main_array [0:7],
  input [7:0] pattern [0:7],
  input [2:0] main_len,
  input [2:0] pattern_len,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal counters
  reg [2:0] pos_counter;      // Current position in main array (0 to 7)
  reg [2:0] pattern_counter;  // Current index in pattern (0 to 7)
  reg [2:0] match_counter;    // Count of consecutive matches

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      pos_counter <= 0;
      pattern_counter <= 0;
      match_counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == PROCESSING) begin
        pos_counter <= pos_counter + 1;
        if (pos_counter == 0) begin
          pattern_counter <= 0;
          match_counter <= 0;
        end
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          if (pattern_len > main_len) begin
            next_state = DONE;
            result = 0;
            done = 1;
          end else begin
            next_state = PROCESSING;
            result = 0;
            done = 0;
          end
        end
      end
      PROCESSING: begin
        if (match_counter == pattern_len - 1) begin
          next_state = DONE;
          result = 1;
          done = 1;
        end else if (pos_counter == main_len - pattern_len) begin
          next_state = DONE;
          result = 0;
          done = 1;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          result = 0;
          done = 0;
        end
      end
    endcase
  end

  // Pattern matching logic
  always @(*) begin
    if (current_state == PROCESSING) begin
      if (main_array[pos_counter + pattern_counter] == pattern[pattern_counter]) begin
        if (pattern_counter == pattern_len - 1) begin
          match_counter = pattern_len;
        end else begin
          match_counter = pattern_counter + 1;
        end
      end else begin
        match_counter = 0;
      end
    end
  end

endmodule