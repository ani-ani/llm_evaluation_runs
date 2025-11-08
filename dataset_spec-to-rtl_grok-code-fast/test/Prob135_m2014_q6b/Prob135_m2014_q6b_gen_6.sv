module TopModule(
  input reg [2:0] y,
  input reg w,
  output reg Y1
);
  // Combinational logic for next y[1]
  assign Y1 = (y == 3'b001) || (y == 3'b101) || (y == 3'b010 && w) || (y == 3'b100 && w);
endmodule