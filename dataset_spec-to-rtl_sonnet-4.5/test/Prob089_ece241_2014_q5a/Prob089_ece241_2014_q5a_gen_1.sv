module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);

  // Moore state machine for 2's complement
  // State encoding:
  // S0: Initial state - waiting for first '1', pass through zeros
  // S1: Found first '1', passed it through, now invert remaining bits
  
  typedef enum logic [0:0] {
    S0 = 1'b0,  // Before first '1' - pass through
    S1 = 1'b1   // After first '1' - invert
  } state_t;
  
  state_t current_state, next_state;
  
  // State register with asynchronous reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      current_state <= S0;
    else
      current_state <= next_state;
  end
  
  // Next state logic
  always_comb begin
    case (current_state)
      S0: begin
        if (x)
          next_state = S1;  // Found first '1', move to invert state
        else
          next_state = S0;  // Still waiting for first '1'
      end
      S1: begin
        next_state = S1;    // Stay in invert state
      end
      default: next_state = S0;
    endcase
  end
  
  // Output logic (Moore machine - output depends only on state)
  // In S0: output = input (pass through until first '1')
  // In S1: output = ~input (invert after first '1')
  assign z = (current_state == S0) ? x : ~x;

endmodule