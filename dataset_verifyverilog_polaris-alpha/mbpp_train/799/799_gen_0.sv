module left_rotate(
  input  [31:0] n,
  input  [4:0]  d,
  output [31:0] result
);

  assign result = (n << d) | (n >> (5'd32 - d));

endmodule