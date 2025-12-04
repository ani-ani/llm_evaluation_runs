module int_multiplier(
  input  signed [7:0]  x,
  input  signed [7:0]  y,
  output signed [15:0] result
);

  assign result = x * y;

endmodule