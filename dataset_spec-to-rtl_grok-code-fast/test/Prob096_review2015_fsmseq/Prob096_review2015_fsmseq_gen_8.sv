module TopModule(
  input clk,
  input reset,
  input data,
  output reg start_shifting
);

  parameter IDLE = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, DETECTED = 3'd4;
  reg [2:0] state;

  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      start_shifting <= 1'b0;
    end else begin
      case (state)
        IDLE: if (data) state <= S1; else state <= IDLE;
        S1: if (data) state <= S2; else state <= IDLE;
        S2: if (!data) state <= S3; else state <= S2;
        S3: if (data) state <= DETECTED; else state <= IDLE;
        DETECTED: state <= DETECTED;
        default: state <= IDLE;
      endcase
      if (state == DETECTED) begin
        start_shifting <= 1'b1;
      end
    end
  end
endmodule