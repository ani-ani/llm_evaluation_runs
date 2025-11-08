module TopModule(input clk, areset, x, output z);
  typedef enum logic {INIT, INVERT} state_t;
  state_t state, next_state;

  always_ff @(posedge clk, posedge areset)
    if (areset) state <= INIT;
    else state <= next_state;

  always_comb
    case(state)
      INIT:    next_state = x ? INVERT : INIT;
      INVERT:  next_state = INVERT;
    endcase

  assign z = (state == INIT) ? x : ~x;
endmodule