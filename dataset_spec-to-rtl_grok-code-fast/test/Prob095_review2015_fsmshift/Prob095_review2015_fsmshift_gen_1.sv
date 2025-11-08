module TopModule (
  input clk,
  input reset,
  output reg shift_ena
);
  reg [1:0] cnt;
  initial begin
    cnt = 2'b00;
    shift_ena = 1'b0;
  end
  always @ (posedge clk) begin
    if (reset) begin
      shift_ena <= 1'b1;
      cnt <= 2'b00;
    end else if (shift_ena) begin
      if (cnt == 2'b11) begin
        shift_ena <= 1'b0;
      end else begin
        cnt <= cnt + 1;
      end
    end
  end
endmodule