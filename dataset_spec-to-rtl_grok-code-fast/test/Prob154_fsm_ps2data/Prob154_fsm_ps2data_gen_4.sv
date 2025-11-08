module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);
  reg [7:0] byte0, byte1, byte2;
  reg trigger;
  reg [1:0] delay_cnt;
  always @(posedge clk) begin
    if (reset) begin
      byte0 <= 8'b0;
      byte1 <= 8'b0;
      byte2 <= 8'b0;
      out_bytes <= 24'b0;
      trigger <= 0;
      delay_cnt <= 0;
      done <= 0;
    end else begin
      byte0 <= byte1;
      byte1 <= byte2;
      byte2 <= in;
      if (in[3] == 1'b1) trigger <= 1;
      if (trigger) begin
        delay_cnt <= delay_cnt + 1;
        if (delay_cnt == 2'd2) begin
          delay_cnt <= 0;
          trigger <= 0;
          done <= 1;
        end else done <= 0;
      end else done <= 0;
      out_bytes <= {byte0, byte1, byte2};
    end
  end
endmodule