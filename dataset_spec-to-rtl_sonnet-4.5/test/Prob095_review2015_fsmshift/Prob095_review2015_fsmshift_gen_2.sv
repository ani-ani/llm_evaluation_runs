module TopModule(
  input  clk,
  input  reset,
  output shift_ena
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE  = 3'd0,
    CYCLE1 = 3'd1,
    CYCLE2 = 3'd2,
    CYCLE3 = 3'd3,
    CYCLE4 = 3'd4,
    DONE  = 3'd5
  } state_t;

  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= CYCLE1;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (current_state)
      IDLE:   next_state = IDLE;
      CYCLE1: next_state = CYCLE2;
      CYCLE2: next_state = CYCLE3;
      CYCLE3: next_state = CYCLE4;
      CYCLE4: next_state = DONE;
      DONE:   next_state = DONE;
      default: next_state = IDLE;
    endcase
  end

  // Output logic
  assign shift_ena = (current_state == CYCLE1) || 
                     (current_state == CYCLE2) || 
                     (current_state == CYCLE3) || 
                     (current_state == CYCLE4);

endmodule