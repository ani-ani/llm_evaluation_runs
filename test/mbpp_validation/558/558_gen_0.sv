module digit_distance(
  input  [15:0] n1,
  input  [15:0] n2,
  output [5:0]  result
);

  // Compute absolute difference
  wire [16:0] diff = (n1 >= n2) ? (n1 - n2) : (n2 - n1);

  // Decimal digits extraction via combinational division and modulus
  // Note: Synthesis tools handle constant divisors efficiently.
  wire [6:0] digit0 = diff % 10;
  wire [16:0] diff_div10 = diff / 10;
  wire [6:0] digit1 = diff_div10 % 10;

  wire [16:0] diff_div100 = diff / 100;
  wire [6:0] digit2 = diff_div100 % 10;

  wire [16:0] diff_div1000 = diff / 1000;
  wire [6:0] digit3 = diff_div1000 % 10;

  wire [16:0] diff_div10000 = diff / 10000;
  wire [6:0] digit4 = diff_div10000 % 10;

  wire [16:0] diff_div100000 = diff / 100000;
  wire [6:0] digit5 = diff_div100000 % 10;

  // Sum of up to 6 digits (max 9 each) fits in 6 bits (max 54 < 64)
  assign result = digit0 + digit1 + digit2 + digit3 + digit4 + digit5;

endmodule