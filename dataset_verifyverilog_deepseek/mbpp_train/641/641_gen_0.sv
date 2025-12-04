module nonagonal_calculator (
  input [15:0] n,
  output [31:0] result
);
  assign result = (n * (7 * n - 5)) / 2;
endmodule