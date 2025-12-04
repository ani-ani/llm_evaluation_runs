module decimal_checker(input clk, input rst_n, input start, input [7:0] char_in, input last_char, output reg valid, output reg done);
  typedef enum logic [2:0] {IDLE, INTEGER, DEC_POINT, DEC_DIGIT_1, DEC_DIGIT_2, INVALID} state_t;
  state_t current_state, next_state;
  reg last_seen;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      last_seen <= 0;
      valid <= 0;
      done <= 0;
    end else begin
      valid <= 0;
      done <= 0;
      if (last_seen) begin
        if (current_state inside {INTEGER, DEC_DIGIT_1, DEC_DIGIT_2}) valid <= 1;
        done <= 1;
        current_state <= IDLE;
        last_seen <= 0;
      end else begin
        current_state <= next_state;
        if (last_char && !last_seen) last_seen <= 1;
      end
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = (char_in inside {8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,8'h38,8'h39}) ? INTEGER : INVALID;
      end
      INTEGER: begin
        if (char_in == 8'h2E) next_state = DEC_POINT;
        else if (!(char_in inside {8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,8'h38,8'h39})) next_state = INVALID;
      end
      DEC_POINT: begin
        if (char_in inside {8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,8'h38,8'h39}) next_state = DEC_DIGIT_1;
        else next_state = INVALID;
      end
      DEC_DIGIT_1: begin
        if (char_in inside {8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,8'h38,8'h39}) next_state = DEC_DIGIT_2;
        else next_state = INVALID;
      end
      DEC_DIGIT_2: begin
        next_state = INVALID;
      end
      INVALID: next_state = INVALID;
      default: next_state = IDLE;
    endcase
  end
endmodule