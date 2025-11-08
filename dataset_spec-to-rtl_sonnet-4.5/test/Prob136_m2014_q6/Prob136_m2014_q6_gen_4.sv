module TopModule(
  input  clk,
  input  reset,
  input  w,
  output z
);

  // State encoding
  typedef enum logic [2:0] {
    A = 3'd0,
    B = 3'd1,
    C = 3'd2,
    D = 3'd3,
    E = 3'd4,
    F = 3'd5
  } state_t;

  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= A;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      A: next_state = w ? A : B;
      B: next_state = w ? D : C;
      C: next_state = w ? D : E;
      D: next_state = w ? A : F;
      E: next_state = w ? D : E;
      F: next_state = w ? D : C;
      default: next_state = A;
    endcase
  end

  // Output logic
  assign z = (current_state == E) || (current_state == F);

endmodule