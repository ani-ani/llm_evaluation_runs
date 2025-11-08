module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);

  // State encoding for Moore state machine
  typedef enum logic [1:0] {
    WAIT_FOR_ONE = 2'b00,
    FOUND_ONE    = 2'b01,
    COMPLEMENT   = 2'b10
  } state_t;

  state_t current_state, next_state;

  // State register with asynchronous reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      current_state <= WAIT_FOR_ONE;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      WAIT_FOR_ONE: begin
        if (x == 1'b1)
          next_state = FOUND_ONE;
        else
          next_state = WAIT_FOR_ONE;
      end
      
      FOUND_ONE: begin
        next_state = COMPLEMENT;
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
  always_comb begin
    case (current_state)
      WAIT_FOR_ONE: begin
        z = 1'b0;
      end
      
      FOUND_ONE: begin
        z = 1'b1;
      end
      
      COMPLEMENT: begin
        z = ~x;
      end
      
      default: begin
        z = 1'b0;
      end
    endcase
  end

endmodule