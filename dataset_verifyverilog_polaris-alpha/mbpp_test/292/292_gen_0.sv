module integer_quotient(
  input  [7:0] a,
  input  [7:0] b,
  output [7:0] q
);

  assign q = a / b;

endmodule