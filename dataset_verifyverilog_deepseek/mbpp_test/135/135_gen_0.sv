module hexagonal_num(input [7:0] n, output [17:0] result);
  assign result = n * ((n << 1) - 1);
endmodule