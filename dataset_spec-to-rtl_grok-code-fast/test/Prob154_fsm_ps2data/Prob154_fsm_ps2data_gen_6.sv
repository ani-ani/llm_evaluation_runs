module TopModule(
  input clk, reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);

  reg [1:0] count;
  reg [23:0] message;

  always @(posedge clk) begin
    if (reset) begin
      count <= 0;
      done <= 0;
      out_bytes <= 24'bx;
      message <= 24'bx;
    end else begin
      done <= 0;
      if (count == 0) begin
        if (in[3]) begin
          message[23:16] <= in;
          count <= 1;
        end
      end else if (count == 1) begin
        message[15:8] <= in;
        count <= 2;
      end else if (count == 2) begin
        message[7:0] <= in;
        count <= 3;
      end else if (count == 3) begin
        done <= 1;
        out_bytes <= message;
        count <= 0;
        if (in[3]) begin
          message[23:16] <= in;
          count <= 1;
        end
      end
    end
  end
endmodule