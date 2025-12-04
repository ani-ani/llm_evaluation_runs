module left_rotate(
  input reg [31:0] n,
  input reg [4:0] d,
  output [31:0] result
);
  assign result = (n << d) | (n >> (32 - d));
endmodule