module TopModule(
  input clk,
  input reset,
  input in,
  output reg disc,
  output reg flag,
  output reg err
);

  // State encoding
  typedef enum reg [3:0] {
    S0 = 4'd0,  // 0 consecutive 1s
    S1 = 4'd1,  // 1 consecutive 1s
    S2 = 4'd2,  // 2 consecutive 1s
    S3 = 4'd3,  // 3 consecutive 1s
    S4 = 4'd4,  // 4 consecutive 1s
    S5 = 4'd5,  // 5 consecutive 1s
    S6 = 4'd6,  // 6 consecutive 1s (flag or discard next)
    S7 = 4'd7,  // 7+ consecutive 1s (error)
    SERR = 4'd8 // Error state
  } state_t;

  state_t current_state, next_state;

  // State transition logic
  always @(posedge clk) begin
    if (reset)
      current_state <= S0;
    else
      current_state <= next_state;
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      S0: next_state = in ? S1 : S0;
      S1: next_state = in ? S2 : S0;
      S2: next_state = in ? S3 : S0;
      S3: next_state = in ? S4 : S0;
      S4: next_state = in ? S5 : S0;
      S5: next_state = in ? S6 : S0;
      S6: next_state = in ? S7 : S0;
      S7: next_state = in ? SERR : S0;
      SERR: next_state = in ? SERR : S0;
      default: next_state = S0;
    endcase
  end

  // Output logic (Moore machine - outputs depend only on current state and current input)
  always @(*) begin
    disc = 1'b0;
    flag = 1'b0;
    err = 1'b0;

    case (current_state)
      S6: begin
        if (!in)
          flag = 1'b1;  // 01111110 pattern detected
      end
      S5: begin
        if (!in)
          disc = 1'b1;  // 0111110 pattern detected
      end
      S7: begin
        err = 1'b1;     // 7 or more 1s
      end
      SERR: begin
        err = 1'b1;     // Continue error
      end
      default: begin
        disc = 1'b0;
        flag = 1'b0;
        err = 1'b0;
      end
    endcase
  end

endmodule