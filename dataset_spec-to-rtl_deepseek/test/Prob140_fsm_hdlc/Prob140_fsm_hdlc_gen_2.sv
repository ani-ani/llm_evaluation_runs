module TopModule (
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);

  reg [3:0] state;

  parameter S0   = 4'd0;
  parameter S1   = 4'd1;
  parameter S2   = 4'd2;
  parameter S3   = 4'd3;
  parameter S4   = 4'd4;
  parameter S5   = 4'd5;
  parameter S6   = 4'd6;
  parameter DISC = 4'd7;
  parameter FLAG = 4'd8;
  parameter ERR  = 4'd9;

  assign disc = (state == DISC);
  assign flag = (state == FLAG);
  assign err  = (state == ERR);

  always @(posedge clk) begin
    if (reset) begin
      state <= S0;
    end else begin
      case (state)
        S0:   state <= (in ? S1 : S0);
        S1:   state <= (in ? S2 : S0);
        S2:   state <= (in ? S3 : S0);
        S3:   state <= (in ? S4 : S0);
        S4:   state <= (in ? S5 : S0);
        S5:   state <= (in ? S6 : DISC);
        S6:   state <= (in ? ERR : FLAG);
        DISC: state <= (in ? S1 : S0);
        FLAG: state <= (in ? S1 : S0);
        ERR:  state <= (in ? ERR : S0);
        default: state <= S0;
      endcase
    end
  end

endmodule