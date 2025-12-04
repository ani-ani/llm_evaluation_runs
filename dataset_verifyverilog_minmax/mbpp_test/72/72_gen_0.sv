module diff_of_squares_check(input reg [7:0] n, output wire result);
  assign result = (n[1:0] != 2'b10);
endmodule