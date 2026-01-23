module count_vowels (
  input clk,
  input rst_n,
  input start,
  input [5:0] str_len,
  input [127:0] str_data,
  output reg [5:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [5:0] count;
  reg [3:0] index;
  reg [7:0] current_char, left_char, right_char;
  reg is_vowel_current, is_vowel_left, is_vowel_right;
  reg valid_char;

  // Vowel check function
  function automatic reg is_vowel(input [7:0] c);
    return (c == 8'h61 || c == 8'h65 || c == 8'h69 || c == 8'h6F || c == 8'h75);
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      index <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            count <= 0;
            index <= 0;
          end
        end

        CHECK: begin
          // Extract current character and neighbors
          current_char <= str_data[(index << 3) +: 8];
          left_char <= (index == 0) ? 8'h00 : str_data[((index - 1) << 3) +: 8];
          right_char <= (index == str_len - 1) ? 8'h00 : str_data[((index + 1) << 3) +: 8];

          // Check vowel status
          is_vowel_current <= is_vowel(current_char);
          is_vowel_left <= is_vowel(left_char);
          is_vowel_right <= is_vowel(right_char);

          // Determine if character meets criteria
          if (index == 0) begin
            // First character: check if not vowel and right neighbor is vowel
            valid_char <= !is_vowel_current && is_vowel_right;
          end else if (index == str_len - 1) begin
            // Last character: check if not vowel and left neighbor is vowel
            valid_char <= !is_vowel_current && is_vowel_left;
          end else begin
            // Middle characters: check if not vowel and either neighbor is vowel
            valid_char <= !is_vowel_current && (is_vowel_left || is_vowel_right);
          end

          // Update count if valid
          if (valid_char) begin
            count <= count + 1;
          end

          // Move to next character or finish
          if (index == str_len - 1) begin
            result <= count;
          end
        end

        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK;
        end
      end

      CHECK: begin
        if (index == str_len - 1) begin
          next_state = DONE;
        end else begin
          next_state = CHECK;
          index = index + 1;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
          done = 0;
        end
      end
    endcase
  end

endmodule