module TopModule(
  input clk,
  input areset,
  input in,
  output out
);

  // State encoding
  typedef enum logic [1:0] {
    A = 2'b00,
    B = 2'b01,
    C = 2'b10,
    D = 2'b11
  } state_t;

  state_t current_state, next_state;

  // State register with asynchronous reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      current_state <= A;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      A: next_state = in ? B : A;
      B: next_state = in ? B : C;
      C: next_state = in ? D : A;
      D: next_state = in ? B : C;
      default: next_state = A;
    endcase
  end

  // Output logic (Moore machine - output depends only on current state)
  assign out = (current_state == D);

endmodule