module TopModule(
  input clk,
  input [7:0] in,
  output [7:0] anyedge
);
reg [7:0] prev_in;
reg [7:0] xor_result;
reg [7:0] delay1;
always @(posedge clk) begin
  prev_in <= in;
  delay1 <= xor_result;
  xor_result <= in ^ prev_in;
end
assign anyedge = delay1;
endmodule