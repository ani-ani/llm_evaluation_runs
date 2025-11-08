typedef enum logic [2:0] {INIT='b000, ONE='b001, ELEVEN='b010, ONE_TEN='b011, ONE_TEN_ONE='b100} state_t;

module TopModule (
  input clk,
  input reset,
  input data,
  output start_shifting
);

  reg state_t current_state, next_state;

  always_comb begin
    case (current_state)
      INIT:         next_state = data ? ONE : INIT;
      ONE:          next_state = data ? ELEVEN : INIT;
      ELEVEN:       next_state = data ? ONE : ONE_TEN;
      ONE_TEN:      next_state = data ? ONE_TEN_ONE : INIT;
      ONE_TEN_ONE:  next_state = ONE_TEN_ONE;
      default:      next_state = INIT;
    endcase
  end

  always @(posedge clk) begin
    if (reset) begin
      current_state <= INIT;
    end else begin
      current_state <= next_state;
    end
  end

  assign start_shifting = (current_state == ONE_TEN_ONE);

endmodule