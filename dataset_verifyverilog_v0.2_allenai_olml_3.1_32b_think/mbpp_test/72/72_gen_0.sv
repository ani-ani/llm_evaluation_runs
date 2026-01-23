module diff_of_squares(input [31:0] n, output result);
  assign result = (n[1:0] != 2'b10);
endmodule