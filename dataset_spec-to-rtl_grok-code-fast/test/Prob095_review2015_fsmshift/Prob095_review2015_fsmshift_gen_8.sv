module TopModule (
  input clk,
  input reset,
  output reg shift_ena
);

  reg [2:0] cnt;

  always @(posedge clk) begin
    if (reset) begin
      cnt <= 3'd4;
    end else begin
      if (cnt != 0) begin
        cnt <= cnt - 1;
      end
    end
  end

  assign shift_ena = (cnt != 0);

endmodule