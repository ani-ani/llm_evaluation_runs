module TopModule(
  input clk,
  input reset,
  input in,
  output out
);

  // State encoding
  typedef enum logic {
    A = 1'b0,
    B = 1'b1
  } state_t;

  state_t current_state, next_state;

  // State register with synchronous reset
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= B;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      B: next_state = in ? B : A;
      A: next_state = in ? A : B;
      default: next_state = B;
    endcase
  end

  // Output logic (Moore machine - output depends only on state)
  assign out = (current_state == B) ? 1'b1 : 1'b0;

endmodule