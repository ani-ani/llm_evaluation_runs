module TopModule(
  input clk,
  input reset,
  input x,
  output z
);
  reg [2:0] y;
  always @(posedge clk) begin
    if (reset) y <= 3'b000;
    else begin
      if (x) begin
        case (y)
          3'b000: y <= 3'b001;
          3'b001: y <= 3'b100;
          3'b010: y <= 3'b001;
          3'b011: y <= 3'b010;
          3'b100: y <= 3'b100;
          default: y <= 3'b000;
        endcase
      end else begin
        case (y)
          3'b000: y <= 3'b000;
          3'b001: y <= 3'b001;
          3'b010: y <= 3'b010;
          3'b011: y <= 3'b001;
          3'b100: y <= 3'b011;
          default: y <= 3'b000;
        endcase
      end
    end
  end
  assign z = (y == 3'b011) || (y == 3'b100);
endmodule