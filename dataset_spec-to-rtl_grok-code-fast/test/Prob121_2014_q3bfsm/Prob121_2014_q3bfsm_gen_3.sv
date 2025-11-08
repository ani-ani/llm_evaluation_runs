module TopModule(
  input clk,
  input reset,
  input x,
  output z
);

parameter S0 = 3'b000;
parameter S1 = 3'b001;
parameter S2 = 3'b010;
parameter S3 = 3'b011;
parameter S4 = 3'b100;

reg [2:0] y;

always @(posedge clk) begin
  if (reset)
    y <= 3'b000;
  else
    case (y)
      3'b000: y <= x ? 3'b001 : 3'b000;
      3'b001: y <= x ? 3'b100 : 3'b001;
      3'b010: y <= x ? 3'b001 : 3'b010;
      3'b011: y <= x ? 3'b010 : 3'b001;
      3'b100: y <= x ? 3'b100 : 3'b011;
      default: y <= 3'b000;
    endcase
end

assign z = y[2] || (y[1] && y[0]);

endmodule