module TopModule(
  input clk,
  input resetn,
  input x,
  input y,
  output reg f,
  output reg g
);

  localparam STATE_RESET = 4'd0;
  localparam STATE_F_PULSE = 4'd1;
  localparam STATE_S0 = 4'd2;
  localparam STATE_S1 = 4'd3;
  localparam STATE_S2 = 4'd4;
  localparam STATE_PRE_G = 4'd5;
  localparam STATE_SET_G = 4'd6;
  localparam STATE_CHECK_Y1 = 4'd7;
  localparam STATE_CHECK_Y2 = 4'd8;
  localparam STATE_G_HOLD = 4'd9;
  localparam STATE_G_OFF = 4'd10;

  reg [3:0] state;

  always @(posedge clk) begin
    if (~resetn) begin
      state <= STATE_RESET;
    end else begin
      case (state)
        STATE_RESET: begin
          state <= (resetn) ? STATE_F_PULSE : STATE_RESET;
        end
        STATE_F_PULSE: begin
          state <= STATE_S0;
        end
        STATE_S0: begin
          state <= (x == 1'b1) ? STATE_S1 : STATE_S0;
        end
        STATE_S1: begin
          state <= (x == 1'b0) ? STATE_S2 : STATE_S1;
        end
        STATE_S2: begin
          state <= (x == 1'b1) ? STATE_PRE_G : STATE_S0;
        end
        STATE_PRE_G: begin
          state <= STATE_SET_G;
        end
        STATE_SET_G: begin
          state <= STATE_CHECK_Y1;
        end
        STATE_CHECK_Y1: begin
          state <= (y == 1'b1) ? STATE_G_HOLD : STATE_CHECK_Y2;
        end
        STATE_CHECK_Y2: begin
          state <= (y == 1'b1) ? STATE_G_HOLD : STATE_G_OFF;
        end
        STATE_G_HOLD: begin
          state <= STATE_G_HOLD;
        end
        STATE_G_OFF: begin
          state <= STATE_G_OFF;
        end
      endcase
    end
  end

  always @(state) begin
    f = (state == STATE_F_PULSE) ? 1'b1 : 1'b0;
    g = (state == STATE_SET_G || state == STATE_CHECK_Y1 || state == STATE_CHECK_Y2 || state == STATE_G_HOLD) ? 1'b1 : 1'b0;
  end
endmodule