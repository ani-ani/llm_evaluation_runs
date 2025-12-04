module sum_even_checker (
  input reg [7:0] n,
  output result
);
  assign result = (n >= 8) && (n[0] == 0);
endmodule