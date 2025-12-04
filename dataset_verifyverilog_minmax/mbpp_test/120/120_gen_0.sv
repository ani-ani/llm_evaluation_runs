module max_abs_product(
  input signed [7:0] a0, b0,
  input signed [7:0] a1, b1,
  input signed [7:0] a2, b2,
  input signed [7:0] a3, b3,
  output wire [15:0] max_product
);
  // Compute signed products
  wire signed [15:0] p0 = a0 * b0;
  wire signed [15:0] p1 = a1 * b1;
  wire signed [15:0] p2 = a2 * b2;
  wire signed [15:0] p3 = a3 * b3;

  // Compute absolute values using two's complement
  wire [15:0] abs0 = p0[15] ? (~p0 + 1) : p0;
  wire [15:0] abs1 = p1[15] ? (~p1 + 1) : p1;
  wire [15:0] abs2 = p2[15] ? (~p2 + 1) : p2;
  wire [15:0] abs3 = p3[15] ? (~p3 + 1) : p3;

  // First level: compare pairs
  wire [15:0] max01 = (abs0 > abs1) ? abs0 : abs1;
  wire [15:0] max23 = (abs2 > abs3) ? abs2 : abs3;

  // Second level: compare winners
  assign max_product = (max01 > max23) ? max01 : max23;
endmodule