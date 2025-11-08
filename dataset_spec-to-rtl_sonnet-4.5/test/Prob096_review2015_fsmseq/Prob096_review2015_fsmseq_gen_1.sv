module TopModule(
  input  clk,
  input  reset,
  input  data,
  output start_shifting
);

  typedef enum logic [2:0] {
    IDLE = 3'b000,
    S1   = 3'b001,
    S11  = 3'b010,
    S110 = 3'b011,
    DONE = 3'b100
  } state_t;

  state_t current_state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (reset)
      current_state <= IDLE;
    else
      current_state <= next_state;
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (data)
          next_state = S1;
        else
          next_state = IDLE;
      end
      S1: begin
        if (data)
          next_state = S11;
        else
          next_state = IDLE;
      end
      S11: begin
        if (data)
          next_state = S11;
        else
          next_state = S110;
      end
      S110: begin
        if (data)
          next_state = DONE;
        else
          next_state = IDLE;
      end
      DONE: begin
        next_state = DONE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output logic
  assign start_shifting = (current_state == DONE);

endmodule