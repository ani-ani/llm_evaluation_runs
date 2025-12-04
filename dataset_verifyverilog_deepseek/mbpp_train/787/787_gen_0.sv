module abbb_matcher (
  input clk,
  input rst_n,
  input [7:0] char,
  input valid,
  input last,
  output logic match
);

  typedef enum logic [2:0] {
    IDLE,
    GOT_A,
    GOT_B1,
    GOT_B2,
    MATCH_DONE
  } state_t;

  state_t current_state, next_state;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) current_state <= IDLE;
    else        current_state <= next_state;
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE:       if (valid) next_state = (char == "a") ? GOT_A : IDLE;
      GOT_A:      if (valid) next_state = (char == "b") ? GOT_B1 :
                                        (char == "a") ? GOT_A : IDLE;
      GOT_B1:     if (valid) next_state = (char == "b") ? GOT_B2 :
                                        (char == "a") ? GOT_A : IDLE;
      GOT_B2:     if (valid) next_state = (char == "b") ? MATCH_DONE :
                                        (char == "a") ? GOT_A : IDLE;
      MATCH_DONE: if (valid) next_state = (char == "a") ? GOT_A : IDLE;
      default:    next_state = IDLE;
    endcase
  end

  assign match = (current_state == GOT_B2) && (char == "b") && valid;

endmodule