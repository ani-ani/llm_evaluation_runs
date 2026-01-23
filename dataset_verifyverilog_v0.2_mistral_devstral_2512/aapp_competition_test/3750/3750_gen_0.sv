module table_tennis_sets(
  input [15:0] k,
  input [15:0] a,
  input [15:0] b,
  output [15:0] result
);

  wire [15:0] count_a = a / k;
  wire [15:0] rem_a = a % k;
  wire [15:0] count_b = b / k;
  wire [15:0] rem_b = b % k;

  wire invalid = (rem_a > 0 && count_b == 0) || (rem_b > 0 && count_a == 0);

  assign result = invalid ? 16'hFFFF : (count_a + count_b);

endmodule