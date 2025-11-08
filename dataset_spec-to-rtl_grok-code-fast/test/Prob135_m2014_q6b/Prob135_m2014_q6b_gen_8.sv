module TopModule(
  input reg [2:0] y,
  input reg w,
  output reg Y1
);
  assign Y1 = !y[1] ? (y[0] ? 1'b1 : (y[2] ? w : 1'b0)) : (y[0] ? 1'b0 : w);
endmodule