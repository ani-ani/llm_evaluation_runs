module diff_of_squares (
  input [31:0] n,
  output result
);

  assign result = (n % 4) != 2;

endmodule