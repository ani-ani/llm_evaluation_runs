module vowels_count (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
  input [3:0] valid_len,
  output reg [3:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] index;
  reg [7:0] current_char;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (index == valid_len - 1) next_state = DONE;
        else next_state = PROCESSING;
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Character selection
  always @(*) begin
    case (index)
      3'd0: current_char = char_0;
      3'd1: current_char = char_1;
      3'd2: current_char = char_2;
      3'd3: current_char = char_3;
      3'd4: current_char = char_4;
      3'd5: current_char = char_5;
      3'd6: current_char = char_6;
      3'd7: current_char = char_7;
      default: current_char = 0;
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            index <= 0;
            result <= 0;
            done <= 0;
          end
        end
        PROCESSING: begin
          // Check if current character is a vowel
          if ((current_char == "a" || current_char == "A" ||
               current_char == "e" || current_char == "E" ||
               current_char == "i" || current_char == "I" ||
               current_char == "o" || current_char == "O" ||
               current_char == "u" || current_char == "U") ||
              (index == valid_len - 1 && (current_char == "y" || current_char == "Y"))) begin
            result <= result + 1;
          end
          index <= index + 1;
        end
        DONE: begin
          done <= 1;
        end
        default: begin
          index <= 0;
          result <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule