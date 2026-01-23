module x_or_y (
  input [3:0] n,
  input [31:0] x,
  input [31:0] y,
  output [31:0] result
);

  assign result = (n == 4'd2 || n == 4'd3 || n == 4'd5 || n == 4'd7 || n == 4'd11 || n == 4'd13) ? x : y;

endmodule