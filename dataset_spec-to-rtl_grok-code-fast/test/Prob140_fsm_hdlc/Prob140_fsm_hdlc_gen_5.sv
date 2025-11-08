module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);
  localparam S0 = 4'd0;
  localparam S1 = 4'd1;
  localparam S2 = 4'd2;
  localparam S3 = 4'd3;
  localparam S4 = 4'd4;
  localparam S5 = 4'd5;
  localparam S6 = 4'd6;
  localparam DISC_STATE = 4'd7;
  localparam FLAG_STATE = 4'd8;
  localparam ERR_STATE = 4'd9;

  reg [3:0] state, next_state;

  assign disc = (state == DISC_STATE);
  assign flag = (state == FLAG_STATE);
  assign err = (state == ERR_STATE);

  always @(*) begin
    next_state = state;
    case(state)
      S0: next_state = in ? S1 : S0;
      S1: next_state = in ? S2 : S0;
      S2: next_state = in ? S3 : S0;
      S3: next_state = in ? S4 : S0;
      S4: next_state = in ? S5 : S0;
      S5: next_state = in ? S6 : DISC_STATE;
      S6: next_state = in ? ERR_STATE : FLAG_STATE;
      DISC_STATE: next_state = in ? S1 : S0;
      FLAG_STATE: next_state = in ? S1 : S0;
      ERR_STATE: next_state = in ? ERR_STATE : S0;
    endcase
  end

  always @(posedge clk) begin
    if (reset)
      state <= S0;
    else
      state <= next_state;
  end
endmodule