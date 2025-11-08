module TopModule(
  input clk,
  input reset,
  input j,
  input k,
  output out
);

  typedef enum logic {OFF, ON} state_t;
  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= OFF;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      OFF: next_state = j ? ON : OFF;
      ON:  next_state = k ? OFF : ON;
      default: next_state = OFF;
    endcase
  end

  // Output logic (Moore machine - output depends only on state)
  assign out = (current_state == ON);

endmodule