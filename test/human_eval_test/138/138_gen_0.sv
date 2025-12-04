module sum_even_checker (
  input  [7:0] n,
  output       result
);

  assign result = (n >= 8) && (n[0] == 1'b0);

endmodule