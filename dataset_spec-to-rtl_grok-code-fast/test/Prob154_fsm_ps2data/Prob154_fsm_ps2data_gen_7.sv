module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output reg done,
  output reg [23:0] out_bytes
);

  reg [1:0] count;
  reg [23:0] buffer;

  always @(posedge clk) begin
    if (reset) begin
      count <= 0;
      done <= 0;
      out_bytes <= 0;
    end else begin
      done <= 0;
      if (count < 3) begin
        if (count == 0) begin
          if (in[3] == 1) begin
            count <= 1;
            buffer[23:16] <= in;
          end
        end else begin
          count <= count + 1;
          if (count == 1) buffer[15:8] <= in;
          else buffer[7:0] <= in;
        end
      end else begin
        count <= 0;
        done <= 1;
        out_bytes <= buffer;
      end
    end
  end

endmodule