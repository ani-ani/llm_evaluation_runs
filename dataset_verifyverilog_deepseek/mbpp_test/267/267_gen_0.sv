module square_sum (
  input [4:0] n,
  output [15:0] sum
);
  assign sum = (n * ((4'd4 * n * n) - 5'd1)) / 5'd3;
endmodule