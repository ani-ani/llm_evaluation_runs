module pattern_matcher (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] str_in,
  output reg match,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SCANNING,
    MATCH_FOUND,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] char_index;
  reg [2:0] scan_index;
  reg found_match;
  reg [7:0] current_char;
  reg [7:0] next_char;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      char_index <= 0;
      scan_index <= 0;
      found_match <= 0;
      match <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == SCANNING) begin
        char_index <= scan_index;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SCANNING;
          scan_index = 0;
          found_match = 0;
        end
      end
      SCANNING: begin
        current_char = str_in[scan_index];
        if (scan_index < 7) begin
          next_char = str_in[scan_index + 1];
        end else begin
          next_char = 8'b0; // Zero-padding for end of string
        end

        if (current_char == 8'h61) begin // 'a'
          if (next_char == 8'h62) begin // 'b'
            found_match = 1;
          end
        end

        if (scan_index == 7) begin
          next_state = found_match ? MATCH_FOUND : DONE;
        end else begin
          scan_index = scan_index + 1;
        end
      end
      MATCH_FOUND: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Output logic
  always @(*) begin
    match = (current_state == MATCH_FOUND) || (current_state == DONE && found_match);
    done = (current_state == DONE);
  end

endmodule