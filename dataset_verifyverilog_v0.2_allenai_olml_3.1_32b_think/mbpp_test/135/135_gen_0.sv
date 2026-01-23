module hexagonal_number(input [7:0] n, output [15:0] result);
  assign result = n * (2*n - 1);
endmodule