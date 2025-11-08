module TopModule(
  input  clk,
  input  areset,
  input  x,
  output z
);

  // One-hot state encoding
  typedef enum logic [1:0] {
    A = 2'b01,
    B = 2'b10
  } state_t;

  state_t current_state, next_state;

  // Sequential logic with asynchronous active-high reset
  always_ff @(posedge clk or posedge areset) begin
    if (areset)
      current_state <= A;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      A: begin
        if (x)
          next_state = B;
        else
          next_state = A;
      end
      B: begin
        next_state = B;
      end
      default: next_state = A;
    endcase
  end

  // Output logic (Mealy - depends on current state and input)
  always_comb begin
    case (current_state)
      A: begin
        if (x)
          z = 1'b1;
        else
          z = 1'b0;
      end
      B: begin
        if (x)
          z = 1'b0;
        else
          z = 1'b1;
      end
      default: z = 1'b0;
    endcase
  end

endmodule