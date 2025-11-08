module TopModule(
  input  clk,
  input  reset,
  output shift_ena
);

  typedef enum logic [2:0] {
    IDLE  = 3'b000,
    CYCLE1 = 3'b001,
    CYCLE2 = 3'b010,
    CYCLE3 = 3'b011,
    CYCLE4 = 3'b100,
    DONE  = 3'b101
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
      default: next_state = DONE;
    endcase
  end

  // Output logic
  assign shift_ena = (current_state == CYCLE1 || 
                      current_state == CYCLE2 || 
                      current_state == CYCLE3 || 
                      current_state == CYCLE4);

endmodule