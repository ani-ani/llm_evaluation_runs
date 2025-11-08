module TopModule(
  output Y1,
  input [2:0] y,
  input w
);
  assign Y1 = (y == 3'b000) ? 1'b0 :
              (y == 3'b001) ? 1'b1 :
              (y == 3'b010) ? w :
              (y == 3'b011) ? 1'b0 :
              (y == 3'b100) ? w :
              (y == 3'b101) ? 1'b1 : 1'b0;
endmodule