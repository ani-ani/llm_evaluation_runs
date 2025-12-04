module diff_of_squares_check(
  input  [7:0] n,
  output       result
);

  // result = 1 when n[1:0] != 2'b10
  assign result = ~(~n[1] & n[0]);

endmodule