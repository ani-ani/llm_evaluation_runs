module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);

  // State encoding for Moore FSM
  typedef enum logic [1:0] {
    WAIT_FOR_ONE = 2'b00,  // Waiting for first '1', pass through bits unchanged
    COMPLEMENT   = 2'b01   // Found first '1', now complement remaining bits
  } state_t;

  state_t current_state, next_state;

  // Sequential logic: State register with asynchronous reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      current_state <= WAIT_FOR_ONE;
    else
      current_state <= next_state;
  end

  // Combinational logic: Next state logic
  always_comb begin
    case (current_state)
      WAIT_FOR_ONE: begin
        if (x == 1'b1)
          next_state = COMPLEMENT;
        else
          next_state = WAIT_FOR_ONE;
      end
      COMPLEMENT: begin
        next_state = COMPLEMENT;
      end
      default: begin
        next_state = WAIT_FOR_ONE;
      end
    endcase
  end

  // Output logic (Moore machine - output depends only on state)
  // In WAIT_FOR_ONE state: output the input bit as-is
  // In COMPLEMENT state: output the complement of input bit
  assign z = (current_state == WAIT_FOR_ONE) ? x : ~x;

endmodule