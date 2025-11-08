module TopModule(input clk, input reset, input data, output start_shifting);
  enum logic [2:0] {IDLE, S1, S11, S110, FOUND} state, next_state;

  always_ff @(posedge clk) begin
    if (reset) state <= IDLE;
    else state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = data ? S1 : IDLE;
      S1:   next_state = data ? S11 : IDLE;
      S11:  next_state = data ? S11 : S110;
      S110: next_state = data ? FOUND : IDLE;
      FOUND: next_state = FOUND;
      default: next_state = IDLE;
    endcase
  end

  assign start_shifting = (state == FOUND);
endmodule