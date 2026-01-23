module nonagonal_number(input [15:0] n, output [15:0] result);
  assign temp1 = 7 * n;
  assign temp2 = temp1 - 5;
  assign temp3 = n * temp2;
  assign result = temp3 >> 1;
endmodule