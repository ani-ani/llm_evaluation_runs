module TopModule(
  input wire clk,
  input wire areset,
  input wire x,
  output wire z
);

  typedef enum {STATE_PASS, STATE_INVERT} state_t;
  state_t current_state;
  state_t next_state;

  always_ff @(posedge clk, posedge areset) begin
    if (areset) begin
      current_state <= STATE_PASS;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    case (current_state)
      STATE_PASS: next_state = x ? STATE_INVERT : STATE_PASS;
      STATE_INVERT: next_state = STATE_INVERT;
      default: next_state = STATE_PASS;
    endcase
  end

  assign z = (current_state == STATE_PASS) ? x : ~x;

endmodule