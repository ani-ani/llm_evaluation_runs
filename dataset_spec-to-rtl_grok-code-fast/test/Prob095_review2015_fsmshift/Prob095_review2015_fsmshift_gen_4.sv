module TopModule(
  input clk,
  input reset,
  output shift_ena
);
  reg [2:0] count;
  assign shift_ena = (count > 0);
  always @(posedge clk) begin
    if (reset) begin
      count <= 3'd4;
    end else if (count > 0) begin
      count <= count - 1;
    end
  end
endmodule