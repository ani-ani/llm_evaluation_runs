module TopModule(
  input clk,
  input reset,
  input [7:0] in,
  output reg [23:0] out_bytes,
  output reg done
);

reg [1:0] count;
reg [23:0] message;

always @(posedge clk) begin
  if (reset) begin
    count <= 2'b00;
    message <= 24'b0;
    done <= 1'b0;
  end else begin
    done <= 1'b0;
    out_bytes <= message;
    if (count == 2'b00) begin
      if (in[3]) begin
        count <= 2'b01;
        message[23:16] <= in;
      end
    end else if (count == 2'b01) begin
      count <= 2'b10;
      message[15:8] <= in;
    end else if (count == 2'b10) begin
      count <= 2'b11;
      message[7:0] <= in;
    end else if (count == 2'b11) begin
      done <= 1'b1;
      count <= 2'b00;
      if (in[3]) begin
        count <= 2'b01;
        message[23:16] <= in;
      end else begin
        message <= 24'b0;
      end
    end
  end
end

endmodule