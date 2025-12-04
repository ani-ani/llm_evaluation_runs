module right_angle_triangle(
  input  [7:0] a,
  input  [7:0] b,
  input  [7:0] c,
  output       is_right
);

  // 16-bit squared values
  wire [15:0] a_sq = a * a;
  wire [15:0] b_sq = b * b;
  wire [15:0] c_sq = c * c;

  // 17-bit sums to prevent overflow
  wire [16:0] ab_sum = a_sq + b_sq;
  wire [16:0] ac_sum = a_sq + c_sq;
  wire [16:0] bc_sum = b_sq + c_sq;

  // Compare with extended 17-bit versions of squared terms
  assign is_right = (ab_sum == {1'b0, c_sq}) ||
                    (ac_sum == {1'b0, b_sq}) ||
                    (bc_sum == {1'b0, a_sq});

endmodule