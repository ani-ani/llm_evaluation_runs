module TopModule(
  input clk,
  input areset,
  input in,
  output out
);

  typedef enum {A, B, C, D} state_type;
  state_type state, next_state;

  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      state <= A;
    else
      state <= next_state;
  end

  always_comb begin
    case (state)
      A: next_state = (in) ? B : A;
      B: next_state = (in) ? B : C;
      C: next_state = (in) ? D : A;
      D: next_state = (in) ? B : C;
    endcase
  end

  assign out = (state == D) ? 1'b1 : 1'b0;

endmodule