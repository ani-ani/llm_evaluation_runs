module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);

  // State encoding
  typedef enum logic [1:0] {
    S0 = 2'b00,  // Initial state: haven't seen first 1 yet
    S1 = 2'b01   // Have seen first 1, now invert all bits
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
          next_state = S1;  // Found first 1, move to invert state
        else
          next_state = S0;  // Keep waiting for first 1
      end
      S1: begin
        next_state = S1;    // Stay in invert state
      end
      default: next_state = S0;
    endcase
  end

  // Output logic (Moore machine - output depends only on state)
  logic z_out;
  always_comb begin
    case (current_state)
      S0: begin
        if (x)
          z_out = 1'b1;  // Output the first 1
        else
          z_out = 1'b0;  // Output 0s until first 1
      end
      S1: begin
        z_out = ~x;      // Invert all subsequent bits
      end
      default: z_out = 1'b0;
    endcase
  end

  assign z = z_out;

endmodule