module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);
  localparam IDLE = 0, BYTE1 = 1, BYTE2 = 2, BYTE3 = 3, DONE = 4;
  reg [2:0] state;
  wire [2:0] next_state;
  assign next_state = (state == DONE) ? IDLE :
                      (state == BYTE3) ? DONE :
                      (state == BYTE2) ? BYTE3 :
                      (state == BYTE1) ? BYTE2 :
                      (state == IDLE && in[3]) ? BYTE1 : IDLE;
  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      out_bytes <= 24'b0;
      done <= 0;
    end else begin
      done <= 0;
      case (state)
        IDLE: if (in[3]) out_bytes[23:16] <= in;
        BYTE1: out_bytes[15:8] <= in;
        BYTE2: out_bytes[7:0] <= in;
        BYTE3: done <= 1;
        // DONE: state will transition to IDLE
      endcase
      state <= next_state;
    end
  end
endmodule