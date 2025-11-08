module TopModule(input clk, input reset, input in, output out);
  typedef enum logic {STATE_A = 1'b0, STATE_B = 1'b1} state_t;
  state_t state_reg, state_next;

  always_ff @(posedge clk) begin
    if (reset) state_reg <= STATE_B;
    else state_reg <= state_next;
  end

  always_comb begin
    case (state_reg)
      STATE_A: state_next = in ? STATE_A : STATE_B;
      STATE_B: state_next = in ? STATE_B : STATE_A;
      default: state_next = STATE_B;
    endcase
  end

  assign out = (state_reg == STATE_B);
endmodule