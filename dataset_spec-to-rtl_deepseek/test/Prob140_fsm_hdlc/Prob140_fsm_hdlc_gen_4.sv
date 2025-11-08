module TopModule(input clk, input reset, input in, output reg disc, output reg flag, output reg err);
  typedef enum {S0, S1, S2, S3, S4, S5, DISC_PULSE, S6, FLAG_PULSE, ERR_PULSE} state_t;
  reg state_t state;
  always @(posedge clk) begin
    if (reset) begin
      state <= S0;
    end else begin
      case (state)
        S0: state <= in ? S1 : S0;
        S1: state <= in ? S2 : S0;
        S2: state <= in ? S3 : S0;
        S3: state <= in ? S4 : S0;
        S4: state <= in ? S5 : S0;
        S5: state <= in ? S6 : DISC_PULSE;
        DISC_PULSE: state <= S0;
        S6: state <= in ? ERR_PULSE : FLAG_PULSE;
        FLAG_PULSE: state <= S0;
        ERR_PULSE: state <= S0;
      endcase
    end
  end
  always @(*) begin
    disc = (state == DISC_PULSE);
    flag = (state == FLAG_PULSE);
    err = (state == ERR_PULSE);
  end
endmodule