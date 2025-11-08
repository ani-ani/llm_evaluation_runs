module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);
  localparam STATE_S0 = 0;
  localparam STATE_S1 = 1;
  localparam STATE_S2 = 2;
  localparam STATE_S3 = 3;
  localparam STATE_S4 = 4;
  localparam STATE_S5 = 5;
  localparam STATE_S6 = 6;
  localparam STATE_DISC = 7;
  localparam STATE_FLAG = 8;
  localparam STATE_ERROR = 9;

  reg [3:0] state;

  always @(posedge clk) begin
    if (reset) begin
      state <= STATE_S0;
    end else begin
      case (state)
        STATE_S0: state <= (in == 1'b1) ? STATE_S1 : STATE_S0;
        STATE_S1: state <= (in == 1'b1) ? STATE_S2 : STATE_S0;
        STATE_S2: state <= (in == 1'b1) ? STATE_S3 : STATE_S0;
        STATE_S3: state <= (in == 1'b1) ? STATE_S4 : STATE_S0;
        STATE_S4: state <= (in == 1'b1) ? STATE_S5 : STATE_S0;
        STATE_S5: state <= (in == 1'b1) ? STATE_S6 : STATE_DISC;
        STATE_S6: state <= (in == 1'b1) ? STATE_ERROR : STATE_FLAG;
        STATE_DISC: state <= STATE_S0;
        STATE_FLAG: state <= STATE_S0;
        STATE_ERROR: state <= (in == 1'b1) ? STATE_ERROR : STATE_S0;
        default: state <= STATE_S0;
      endcase
    end
  end

  assign disc = (state == STATE_DISC);
  assign flag = (state == STATE_FLAG);
  assign err = (state == STATE_ERROR);
endmodule