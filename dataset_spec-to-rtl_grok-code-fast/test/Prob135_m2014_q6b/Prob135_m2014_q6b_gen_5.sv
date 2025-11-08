module TopModule (
  input [2:0] y,
  input w,
  output Y1
);
  assign Y1 = y[2] ? (w | y[0]) : (y[1] ? (y[0] ? 1'b0 : w) : y[0]);
endmodule