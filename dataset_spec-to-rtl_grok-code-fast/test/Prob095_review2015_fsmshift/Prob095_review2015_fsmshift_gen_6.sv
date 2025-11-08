module TopModule(
  input clk,
  input reset,
  output reg shift_ena
);
  reg [2:0] counter;
  always @(posedge clk) begin
    if (reset) counter <= 3'd4;
    else if (counter > 3'd0) counter <= counter - 3'd1;
    shift_ena <= (counter > 3'd0);
  end
endmodule