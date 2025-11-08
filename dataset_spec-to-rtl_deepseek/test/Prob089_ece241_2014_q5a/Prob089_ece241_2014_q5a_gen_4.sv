module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);
  typedef enum logic {STATE_PASS, STATE_INVERT} state_t;
  state_t state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset) begin
      state <= STATE_PASS;
    end else begin
      case (state)
        STATE_PASS:   state <= x ? STATE_INVERT : STATE_PASS;
        STATE_INVERT: state <= STATE_INVERT;
      endcase
    end
  end

  assign z = (state == STATE_PASS) ? x : ~x;
endmodule