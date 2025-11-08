module TopModule(
  input clk,
  input reset,
  output reg shift_ena
);
  reg [2:0] count;
  always @(posedge clk) begin
    if (reset) begin
      count <= 3'd4;
      shift_ena <= 1'b1;
    end else begin
      if (count > 0) count <= count - 1;
      shift_ena <= (count > 1);
    end
  end
endmodule