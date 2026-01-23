module check_string_char (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input valid_in,
  input last_in,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_FIRST,
    READ_MIDDLE,
    READ_LAST,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [7:0] start_char;
  reg [3:0] char_counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      char_counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = READ_FIRST;
      end
      READ_FIRST: begin
        if (valid_in) begin
          if (last_in) next_state = READ_LAST;
          else next_state = READ_MIDDLE;
        end
      end
      READ_MIDDLE: begin
        if (valid_in) begin
          if (last_in) next_state = READ_LAST;
        end
      end
      READ_LAST: begin
        next_state = DONE;
      end
      DONE: begin
        if (start) next_state = READ_FIRST;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_char <= 0;
      char_counter <= 0;
    end else begin
      case (current_state)
        READ_FIRST: begin
          if (valid_in) begin
            start_char <= char_in;
            char_counter <= 1;
          end
        end
        READ_MIDDLE: begin
          if (valid_in && !last_in) begin
            char_counter <= char_counter + 1;
          end
        end
        READ_LAST: begin
          if (valid_in && last_in) begin
            result <= (char_in == start_char) ? 1 : 0;
          end
        end
        DONE: begin
          done <= 1;
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

  // Reset done signal when not in DONE state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state != DONE) begin
      done <= 0;
    end
  end

endmodule