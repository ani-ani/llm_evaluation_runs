module TopModule(
  input clk,
  input reset,
  output reg shift_ena
);
  reg [2:0] cnt;
  always @(posedge clk) begin
    if (reset) begin
      cnt <= 3'b100; // 4 in decimal
      shift_ena <= 1'b1;
    end else begin
      if (cnt > 0) begin
        cnt <= cnt - 1;
      end
      shift_ena <= (cnt > 0);
    end
  end
endmodule