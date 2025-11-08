module TopModule(
  input clk,
  input areset,
  input in,
  output logic out
);

  typedef enum {A, B, C, D} state_t;
  state_t state, next_state;

  always_ff @(posedge clk, posedge areset) begin
    if (areset) state <= A;
    else state <= next_state;
  end

  always_comb begin
    case (state)
      A: next_state = in ? B : A;
      B: next_state = in ? B : C;
      C: next_state = in ? D : A;
      D: next_state = in ? B : C;
      default: next_state = A;
    endcase
  end

  assign out = (state == D) ? 1'b1 : 1'b0;

endmodule