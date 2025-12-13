module add_numbers(
  input  [11:0] a,
  input  [11:0] b,
  output [12:0] sum
);

  assign sum = a + b;

endmodule