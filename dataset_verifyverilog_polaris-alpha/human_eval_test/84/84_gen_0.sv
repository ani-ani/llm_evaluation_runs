module sum_digits_binary(
  input  [13:0] N,
  output [5:0]  sum_bin
);

  // Extract decimal digits via combinational division/modulus by 10
  wire [13:0] q1;  // N / 10
  wire [3:0]  d0;  // N % 10

  assign q1 = N / 10;
  assign d0 = N - (q1 * 10);

  wire [13:0] q2;  // (N / 10) / 10
  wire [3:0]  d1;  // (N / 10) % 10

  assign q2 = q1 / 10;
  assign d1 = q1 - (q2 * 10);

  wire [13:0] q3;  // ((N / 10) / 10) / 10
  wire [3:0]  d2;  // ((N / 10) / 10) % 10

  assign q3 = q2 / 10;
  assign d2 = q2 - (q3 * 10);

  wire [13:0] q4;  // (((N / 10) / 10) / 10) / 10
  wire [3:0]  d3;  // (((N / 10) / 10) / 10) % 10

  assign q4 = q3 / 10;
  assign d3 = q3 - (q4 * 10);

  // Sum of decimal digits (max 1+0+0+0=1 (for 0001) to 1+0+0+0=1, realistically up to 1+0+0+0 for 10000, but design for general 4-digit max 9*4=36)
  wire [5:0] sum;
  assign sum = d0 + d1 + d2 + d3;

  assign sum_bin = sum;

endmodule