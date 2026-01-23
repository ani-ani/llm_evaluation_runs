module sum_to_n(input [6:0] n, output [15:0] result);
  assign result = (n * (n + 1)) >> 1;
endmodule