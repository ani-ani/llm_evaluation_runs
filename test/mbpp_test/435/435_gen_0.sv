module last_digit(
  input  [7:0] n,
  output [3:0] digit
);

  assign digit = n % 10;

endmodule