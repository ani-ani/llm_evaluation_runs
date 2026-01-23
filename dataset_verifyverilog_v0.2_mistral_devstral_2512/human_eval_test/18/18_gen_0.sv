module substring_counter (
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] main_string,
  input [7:0] substring_length,
  input [7:0][7:0] substring,
  output reg [7:0] count,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COMPARE,
    UPDATE,
    NEXT_POS,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] position; // Current position in main_string (0-15)
  reg [2:0] char_index; // Current character index in substring (0-7)
  reg [7:0] match_count; // Internal match counter
  reg [7:0] max_position; // Maximum position to check

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      position <= 0;
      char_index <= 0;
      match_count <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMPARE;
          count = 0;
          done = 0;
          position = 0;
          char_index = 0;
          match_count = 0;
          max_position = 16 - substring_length;
        end
      end
      COMPARE: begin
        if (char_index == substring_length - 1) begin
          if (main_string[position + char_index] == substring[char_index]) begin
            next_state = UPDATE;
          end else begin
            next_state = NEXT_POS;
          end
        end else begin
          if (main_string[position + char_index] == substring[char_index]) begin
            char_index = char_index + 1;
          end else begin
            next_state = NEXT_POS;
          end
        end
      end
      UPDATE: begin
        count = count + 1;
        next_state = NEXT_POS;
      end
      NEXT_POS: begin
        if (position == max_position) begin
          next_state = DONE;
        end else begin
          position = position + 1;
          char_index = 0;
          next_state = COMPARE;
        end
      end
      DONE: begin
        done = 1;
        if (start) begin
          next_state = COMPARE;
          count = 0;
          done = 0;
          position = 0;
          char_index = 0;
          match_count = 0;
        end
      end
      default: next_state = IDLE;
    endcase
  end

endmodule