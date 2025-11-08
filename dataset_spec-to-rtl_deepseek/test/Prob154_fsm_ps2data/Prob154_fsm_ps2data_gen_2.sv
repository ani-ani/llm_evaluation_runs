module TopModule(input clk, input reset, input [7:0] in, output reg [23:0] out_bytes, output reg done);
  reg [1:0] state, next_state;
  reg [7:0] byte1, byte2, byte3;
  
  parameter IDLE = 2'b00;
  parameter FIRST = 2'b01;
  parameter SECOND = 2'b10;
  parameter DONE = 2'b11;
  
  always_comb begin
    case (state)
      IDLE: next_state = in[3] ? FIRST : IDLE;
      FIRST: next_state = SECOND;
      SECOND: next_state = DONE;
      DONE: next_state = in[3] ? FIRST : IDLE;
    endcase
  end
  
  always @(posedge clk) begin
    if (reset) begin
      state <= IDLE;
      byte1 <= 8'b0;
      byte2 <= 8'b0;
      byte3 <= 8'b0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: if (in[3]) byte1 <= in;
        FIRST: byte2 <= in;
        SECOND: byte3 <= in;
        DONE: if (in[3]) byte1 <= in;
      endcase
    end
  end
  
  assign done = (state == DONE);
  assign out_bytes = {byte1, byte2, byte3};
endmodule