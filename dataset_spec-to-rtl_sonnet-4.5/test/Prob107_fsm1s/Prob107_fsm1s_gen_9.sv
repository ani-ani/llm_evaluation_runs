module TopModule(
  input clk,
  input reset,
  input in,
  output out
);

  // State encoding
  typedef enum logic [0:0] {
    A = 1'b0,
    B = 1'b1
  } state_t;

  state_t current_state, next_state;

  // State register with synchronous active-high reset
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= B;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      B: begin
        if (in == 1'b0)
          next_state = A;
        else
          next_state = B;
      end
      A: begin
        if (in == 1'b0)
          next_state = B;
        else
          next_state = A;
      end
      default: next_state = B;
    endcase
  end

  // Output logic (Moore machine - output depends only on current state)
  assign out = (current_state == B) ? 1'b1 : 1'b0;

endmodule