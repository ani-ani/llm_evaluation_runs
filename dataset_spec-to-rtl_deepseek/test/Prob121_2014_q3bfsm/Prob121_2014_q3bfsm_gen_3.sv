module TopModule(
  input clk,
  input reset,
  input x,
  output z
);

  parameter S000 = 3'b000;
  parameter S001 = 3'b001;
  parameter S010 = 3'b010;
  parameter S011 = 3'b011;
  parameter S100 = 3'b100;

  reg [2:0] y;

  always_ff @(posedge clk) begin
    if (reset) begin
      y <= S000;
    end else begin
      case (y)
        S000: y <= x ? S001 : S000;
        S001: y <= x ? S100 : S001;
        S010: y <= x ? S001 : S010;
        S011: y <= x ? S010 : S001;
        S100: y <= x ? S100 : S011;
        default: y <= S000;
      endcase
    end
  end

  assign z = (y == S011) || (y == S100);

endmodule