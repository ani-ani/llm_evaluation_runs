module TopModule (
  input clk,
  input reset,
  input w,
  output reg z
);

  typedef enum {A, B, C, D, E, F} state_t;
  state_t state, next_state;

  always_ff @(posedge clk or posedge reset) begin
    if (reset)
      state <= A;
    else
      state <= next_state;
  end

  always_comb begin
    case (state)
      A: next_state = (w ? A : B);
      B: next_state = (w ? D : C);
      C: next_state = (w ? D : E);
      D: next_state = (w ? A : F);
      E: next_state = (w ? D : E);
      F: next_state = (w ? D : C);
      default: next_state = A;
    endcase
  end

  assign z = (state == E) || (state == F);

endmodule