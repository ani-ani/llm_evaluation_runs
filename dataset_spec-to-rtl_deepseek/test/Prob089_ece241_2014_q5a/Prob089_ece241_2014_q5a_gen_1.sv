module TopModule(input clk, input areset, input x, output z);
  typedef enum logic {STATE_PASS, STATE_FLIP} state_t;
  state_t state, next_state;

  always_comb begin
    case (state)
      STATE_PASS: next_state = x ? STATE_FLIP : STATE_PASS;
      STATE_FLIP: next_state = STATE_FLIP;
      default: next_state = STATE_PASS;
    endcase
  end

  always_ff @(posedge clk or posedge areset) begin
    if (areset) state <= STATE_PASS;
    else state <= next_state;
  end

  assign z = areset ? 1'b0 : (state == STATE_PASS ? x : ~x);
endmodule