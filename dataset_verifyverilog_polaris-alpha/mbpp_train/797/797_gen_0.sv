module sum_odds_range(
  input  [7:0]  l,
  input  [7:0]  r,
  output [15:0] sum
);

  wire [8:0] r_plus1;
  wire [8:0] half_r;
  wire [8:0] half_l;
  wire [17:0] r_sum;
  wire [17:0] l_sum;
  wire [17:0] diff;

  assign r_plus1 = {1'b0, r} + 9'd1;
  assign half_r  = r_plus1 >> 1;       // (r + 1) >> 1
  assign half_l  = {1'b0, l} >> 1;     // l >> 1

  assign r_sum = half_r * half_r;      // up to 18 bits
  assign l_sum = half_l * half_l;      // up to 18 bits

  assign diff = r_sum - l_sum;
  assign sum  = diff[15:0];            // lower 16 bits as specified

endmodule