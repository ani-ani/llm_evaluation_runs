module TopModule(
  input clk,
  input reset,
  input in,
  output out
);

  typedef enum {A, B, C, D} state_t;
  state_t current_state, next_state;

  always_ff @(posedge clk) begin
    if (reset) begin
      current_state <= A;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    case (current_state)
      A: next_state = (in) ? B : A;
      B: next_state = (in) ? B : C;
      C: next_state = (in) ? D : A;
      D: next_state = (in) ? B : C;
    endcase
  end

  always_comb begin
    out = (current_state == D) ? 1'b1 : 1'b0;
  end

endmodule