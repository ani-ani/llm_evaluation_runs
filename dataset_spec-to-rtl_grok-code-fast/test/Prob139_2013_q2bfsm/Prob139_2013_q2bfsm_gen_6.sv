module TopModule (
  input clk,
  input resetn,
  input x,
  input y,
  output reg f,
  output reg g
);
  reg [2:0] state;
  reg [2:0] x_history;
  parameter RESET = 3'b000;
  parameter START = 3'b001;
  parameter MONITOR_X = 3'b010;
  parameter MONITOR_Y0 = 3'b011;
  parameter MONITOR_Y1 = 3'b100;
  parameter GOT_Y = 3'b101;
  parameter FAIL = 3'b110;
  always @(posedge clk) begin
    if (!resetn) begin
      state <= RESET;
      f <= 1'b0;
      g <= 1'b0;
      x_history <= 3'b000;
    end else begin
      case (state)
        RESET: begin
          state <= START;
          f <= 1'b0;
          g <= 1'b0;
        end
        START: begin
          state <= MONITOR_X;
          f <= 1'b1;
          g <= 1'b0;
          x_history <= 3'b000;
        end
        MONITOR_X: begin
          f <= 1'b0;
          g <= 1'b0;
          x_history <= {x_history[1:0], x};
          if (x_history == 3'b101) begin
            state <= MONITOR_Y0;
          end
        end
        MONITOR_Y0: begin
          f <= 1'b0;
          g <= 1'b1;
          if (y) begin
            state <= GOT_Y;
          end else begin
            state <= MONITOR_Y1;
          end
        end
        MONITOR_Y1: begin
          f <= 1'b0;
          g <= 1'b1;
          if (y) begin
            state <= GOT_Y;
          end else begin
            state <= FAIL;
          end
        end
        GOT_Y: begin
          state <= GOT_Y;
          f <= 1'b0;
          g <= 1'b1;
        end
        FAIL: begin
          state <= FAIL;
          f <= 1'b0;
          g <= 1'b0;
        end
        default: begin
          state <= RESET;
        end
      endcase
    end
  end
endmodule