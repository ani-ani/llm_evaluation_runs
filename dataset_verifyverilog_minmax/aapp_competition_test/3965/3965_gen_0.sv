module verse_pattern_matcher(
  input clk,
  input rst_n,
  input start,
  input [3:0][3:0] pattern,
  input [3:0][15:0][7:0] text_lines,
  output reg match,
  output reg done
);

  // FSM states
  typedef enum logic [1:0] { IDLE = 2'b00, COUNT_VOWELS = 2'b01, COMPARE = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // Line index (0..3)
  logic [1:0] line_idx, next_line_idx;
  // Character index (0..15)
  logic [3:0] char_idx, next_char_idx;
  // Vowel counter for the current line (0..16)
  logic [4:0] vowel_count, next_vowel_count;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      line_idx <= 2'b0;
      char_idx  <= 4'b0;
      vowel_count <= 5'b0;
      match <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
      line_idx <= next_line_idx;
      char_idx <= next_char_idx;
      vowel_count <= next_vowel_count;
      match <= 1'b0; // Will be overridden in DONE
      done <= (next_state == DONE);
    end
  end

  // Vowel detection for the current character (a,e,i,o,u,y)
  wire [7:0] current_char = text_lines[line_idx][char_idx];
  wire is_vowel = (current_char == "a") || (current_char == "e") ||
                  (current_char == "i") || (current_char == "o") ||
                  (current_char == "u") || (current_char == "y");

  // Combinational next-state logic
  always_comb begin
    // Defaults
    next_state = state;
    next_line_idx = line_idx;
    next_char_idx = char_idx;
    next_vowel_count = vowel_count;

    case (state)
      IDLE: begin
        next_line_idx = 2'b0;
        next_char_idx = 4'b0;
        next_vowel_count = 5'b0;
        if (start) begin
          next_state = COUNT_VOWELS;
        end
      end

      COUNT_VOWELS: begin
        // Update vowel count for current character (only when staying in COUNT_VOWELS)
        next_vowel_count = vowel_count + {4'b0, is_vowel};

        if (char_idx == 4'd15) begin
          // Last char of this line -> move to compare
          next_char_idx = 4'b0;
          next_state = COMPARE;
        end else begin
          // Next character in the same line
          next_char_idx = char_idx + 1;
        end
      end

      COMPARE: begin
        // Compare vowel count to the pattern for this line
        if (vowel_count != pattern[line_idx]) begin
          // Mismatch: fail immediately
          next_state = DONE;
        end else begin
          // Move to next line or finish
          if (line_idx == 2'd3) begin
            next_state = DONE;
          end else begin
            next_line_idx = line_idx + 1;
            next_char_idx = 4'b0;
            next_vowel_count = 5'b0;
            next_state = COUNT_VOWELS;
          end
        end
      end

      DONE: begin
        // Stay here until start deasserts
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
