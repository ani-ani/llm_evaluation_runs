module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);

  // State definition
  typedef enum logic [3:0] {
    IDLE = 4'd0,
    ONE  = 4'd1,
    TWO  = 4'd2,
    THR  = 4'd3,
    FOU  = 4'd4,
    FIV  = 4'd5,
    SIX  = 4'd6,
    SEV  = 4'd7,
    DISC = 4'd8,
    FLAG = 4'd9
  } state_t;

  state_t state, next_state;

  // State transition logic
  always_ff @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  always_comb begin
    next_state = state; // Default stay in state
    case (state)
      IDLE: if (in) next_state = ONE;
      ONE:  if (in) next_state = TWO; else next_state = IDLE;
      TWO:  if (in) next_state = THR; else next_state = IDLE;
      THR:  if (in) next_state = FOU; else next_state = IDLE;
      FOU:  if (in) next_state = FIV; else next_state = IDLE;
      FIV:  if (in) next_state = SIX; else next_state = DISC;
      SIX:  if (in) next_state = SEV; else next_state = FLAG;
      SEV:  if (~in) next_state = IDLE;
      DISC: if (in) next_state = ONE; else next_state = IDLE;
      FLAG: if (in) next_state = ONE; else next_state = IDLE;
    endcase
  end

  // Output assignments
  assign disc = (state == DISC);
  assign flag = (state == FLAG);
  assign err  = (state == SEV);

endmodule