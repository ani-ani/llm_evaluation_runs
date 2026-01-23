module add (
  input [15:0] x,
  input [15:0] y,
  output [15:0] result
);
  assign result = x + y;
endmodule