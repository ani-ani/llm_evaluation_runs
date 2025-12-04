module decagonal_number (
  input [7:0] n,
  output [17:0] result
);

  assign result = (4 * (n * n)) - (3 * n);

endmodule