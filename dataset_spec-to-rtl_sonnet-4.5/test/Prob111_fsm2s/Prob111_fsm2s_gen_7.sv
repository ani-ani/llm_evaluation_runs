module TopModule(
  input  clk,
  input  reset,
  input  j,
  input  k,
  output out
);

  // State encoding
  typedef enum logic {
    OFF = 1'b0,
    ON  = 1'b1
  } state_t;

  state_t current_state, next_state;

  // State register with synchronous reset
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= OFF;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      OFF: begin
        if (j)
          next_state = ON;
        else
          next_state = OFF;
      end
      ON: begin
        if (k)
          next_state = OFF;
        else
          next_state = ON;
      end
      default: next_state = OFF;
    endcase
  end

  // Output logic (Moore machine - output depends only on state)
  assign out = (current_state == ON);

endmodule