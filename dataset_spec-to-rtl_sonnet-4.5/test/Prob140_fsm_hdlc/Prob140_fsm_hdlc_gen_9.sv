module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);

  // State encoding
  typedef enum logic [3:0] {
    S0 = 4'd0,  // 0 consecutive 1s
    S1 = 4'd1,  // 1 consecutive 1s
    S2 = 4'd2,  // 2 consecutive 1s
    S3 = 4'd3,  // 3 consecutive 1s
    S4 = 4'd4,  // 4 consecutive 1s
    S5 = 4'd5,  // 5 consecutive 1s
    S6 = 4'd6,  // 6 consecutive 1s (disc or flag next)
    SERR = 4'd7 // Error state (7+ consecutive 1s)
  } state_t;

  state_t state, next_state;

  // State register
  always_ff @(posedge clk) begin
    if (reset)
      state <= S0;
    else
      state <= next_state;
  end

  // Next state logic
  always_comb begin
    case (state)
      S0: next_state = in ? S1 : S0;
      S1: next_state = in ? S2 : S0;
      S2: next_state = in ? S3 : S0;
      S3: next_state = in ? S4 : S0;
      S4: next_state = in ? S5 : S0;
      S5: next_state = in ? S6 : S0;
      S6: next_state = in ? SERR : S0;
      SERR: next_state = in ? SERR : S0;
      default: next_state = S0;
    endcase
  end

  // Output logic (Moore machine - outputs depend only on current state and current input)
  // We need to detect the complete sequence, so check state and input
  assign disc = (state == S6) && (in == 1'b0);
  assign flag = (state == SERR) && (in == 1'b0);
  assign err = (state == SERR) && (in == 1'b1);

endmodule
