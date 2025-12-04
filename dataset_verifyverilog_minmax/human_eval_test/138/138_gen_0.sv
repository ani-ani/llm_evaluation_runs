module sum_even_checker(
  input  logic [7:0] n,
  output logic       result
);

  assign result = (n >= 8) && (n[0] == 1'b0);

endmodule