module TopModule(
  input [2:0] y,
  input w,
  output reg Y1
);
  assign Y1 = (~y[2] & ~y[1] & ~y[0]) ? 1'b0 :
                (~y[2] & ~y[1] & y[0]) ? 1'b1 :
                (~y[2] & y[1] & ~y[0]) ? w :
                (~y[2] & y[1] & y[0]) ? 1'b0 :
                (y[2] & ~y[1] & ~y[0]) ? w :
                (y[2] & y[1] & y[0]) ? 1'b1 :
                1'b0;
endmodule