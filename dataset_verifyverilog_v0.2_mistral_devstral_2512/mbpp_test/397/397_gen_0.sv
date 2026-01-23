module median_three (
  input [7:0] a,
  input [7:0] b,
  input [7:0] c,
  output [7:0] median
);

  wire [7:0] median_a;
  wire [7:0] median_b;
  wire [7:0] median_c;

  assign median_a = (a > b) ? ((a < c) ? a : ((b > c) ? b : c)) : ((a > c) ? a : ((b < c) ? b : c));
  assign median_b = (b > a) ? ((b < c) ? b : ((a > c) ? a : c)) : ((b > c) ? b : ((a < c) ? a : c));
  assign median_c = (c > a) ? ((c < b) ? c : ((a > b) ? a : b)) : ((c > b) ? c : ((a < b) ? a : b));

  assign median = median_a;

endmodule