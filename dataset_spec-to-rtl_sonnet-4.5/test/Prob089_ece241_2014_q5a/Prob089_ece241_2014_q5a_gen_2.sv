module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);

  // State encoding for Moore machine
  typedef enum logic [1:0] {
    WAIT_FOR_ONE = 2'b00,
    COMPLEMENT   = 2'b01
  } state_t;

  state_t current_state, next_state;

  // Sequential logic for state register
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
  logic z_out;
  always_comb begin
    case (current_state)
      WAIT_FOR_ONE: begin
        z_out = x;
      end
      COMPLEMENT: begin
        z_out = ~x;
      end
      default: begin
        z_out = 1'b0;
      end
    endcase
  end

  assign z = z_out;

endmodule