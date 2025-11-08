module TopModule (
  input clk,
  input reset,
  input w,
  output logic z
);

  typedef enum logic [2:0] {A=3'b000, B=3'b001, C=3'b010, D=3'b011, E=3'b100, F=3'b101} state_t;
  state_t state, next_state;

  assign z = (state == E || state == F);

  always_ff @(posedge clk) begin
    if (reset) state <= A;
    else state <= next_state;
  end

  always_comb begin
    case (state)
      A: next_state = w ? A : B;
      B: next_state = w ? D : C;
      C: next_state = w ? D : E;
      D: next_state = w ? A : F;
      E: next_state = w ? D : E;
      F: next_state = w ? D : C;
    endcase
  end

endmodule