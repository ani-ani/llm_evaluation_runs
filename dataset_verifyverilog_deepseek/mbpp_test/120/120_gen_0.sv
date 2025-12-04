module max_abs_product (
  input reg signed [7:0] a0, b0,
  input reg signed [7:0] a1, b1,
  input reg signed [7:0] a2, b2,
  input reg signed [7:0] a3, b3,
  output wire [15:0] max_product
);

  wire signed [15:0] prod0 = a0 * b0;
  wire signed [15:0] prod1 = a1 * b1;
  wire signed [15:0] prod2 = a2 * b2;
  wire signed [15:0] prod3 = a3 * b3;

  wire [15:0] abs0 = prod0[15] ? (~prod0 + 1'b1) : prod0;
  wire [15:0] abs1 = prod1[15] ? (~prod1 + 1'b1) : prod1;
  wire [15:0] abs2 = prod2[15] ? (~prod2 + 1'b1) : prod2;
  wire [15:0] abs3 = prod3[15] ? (~prod3 + 1'b1) : prod3;

  wire [15:0] max01 = (abs0 > abs1) ? abs0 : abs1;
  wire [15:0] max23 = (abs2 > abs3) ? abs2 : abs3;

  assign max_product = (max01 > max23) ? max01 : max23;

endmodule