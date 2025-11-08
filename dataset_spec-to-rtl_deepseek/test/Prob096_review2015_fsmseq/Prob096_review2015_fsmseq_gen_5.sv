module TopModule(input clk, reset, data, output start_shifting);
  typedef enum logic [2:0] {IDLE, STATE_1, STATE_11, STATE_110, STATE_1101} state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk) begin
    if (reset) current_state <= IDLE;
    else current_state <= next_state;
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE:     next_state = data ? STATE_1 : IDLE;
      STATE_1:   next_state = data ? STATE_11 : IDLE;
      STATE_11:  next_state = data ? STATE_11 : STATE_110;
      STATE_110: next_state = data ? STATE_1101 : IDLE;
      STATE_1101: next_state = STATE_1101;
      default:   next_state = IDLE;
    endcase
  end

  assign start_shifting = (current_state == STATE_1101);
endmodule