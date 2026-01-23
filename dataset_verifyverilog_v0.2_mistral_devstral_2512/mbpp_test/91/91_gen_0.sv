module substring_search (
  input clk,
  input rst_n,
  input start,
  input [7:0] str_data,
  input [2:0] str_idx,
  input [2:0] char_idx,
  input [2:0] substr_len,
  output reg found,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_SUBSTR,
    CHECK_STRING,
    FOUND,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Substring buffer (max 7 characters)
  reg [7:0] substr_buffer [0:6];
  reg [2:0] substr_pos;

  // Current string buffer (max 8 characters)
  reg [7:0] str_buffer [0:7];
  reg [2:0] str_pos;

  // String processing counters
  reg [2:0] current_str_idx;
  reg [2:0] current_char_idx;

  // Match tracking
  reg [2:0] match_pos;
  reg match_found;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      substr_pos <= 0;
      str_pos <= 0;
      current_str_idx <= 0;
      current_char_idx <= 0;
      match_pos <= 0;
      match_found <= 0;
      found <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      // Load substring characters
      if (current_state == LOAD_SUBSTR && substr_pos < substr_len) begin
        substr_buffer[substr_pos] <= str_data;
        substr_pos <= substr_pos + 1;
      end

      // Load string characters
      if (current_state == CHECK_STRING && str_pos < 8) begin
        str_buffer[str_pos] <= str_data;
        str_pos <= str_pos + 1;
      end
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    found = 0;
    done = 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_SUBSTR;
          substr_pos = 0;
          str_pos = 0;
          current_str_idx = 0;
          current_char_idx = 0;
          match_pos = 0;
          match_found = 0;
        end
      end

      LOAD_SUBSTR: begin
        if (substr_pos == substr_len) begin
          next_state = CHECK_STRING;
          str_pos = 0;
          current_char_idx = 0;
        end
      end

      CHECK_STRING: begin
        // Check if we've processed all characters in current string
        if (str_pos == 8) begin
          // Move to next string
          current_str_idx = current_str_idx + 1;
          str_pos = 0;
          current_char_idx = 0;
          match_pos = 0;

          // Check if all strings processed
          if (current_str_idx == 5) begin
            next_state = DONE;
          end
        end
        // Check for substring match
        else if (str_pos >= substr_len - 1) begin
          reg match = 1;
          for (int i = 0; i < substr_len; i = i + 1) begin
            if (str_buffer[str_pos - i] != substr_buffer[substr_len - 1 - i]) begin
              match = 0;
            end
          end
          if (match) begin
            match_found = 1;
            next_state = FOUND;
          end
        end
      end

      FOUND: begin
        found = 1;
        next_state = DONE;
      end

      DONE: begin
        done = 1;
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule