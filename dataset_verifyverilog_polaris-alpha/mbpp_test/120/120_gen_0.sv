module max_abs_product(
  input  signed [7:0] a0,
  input  signed [7:0] b0,
  input  signed [7:0] a1,
  input  signed [7:0] b1,
  input  signed [7:0] a2,
  input  signed [7:0] b2,
  input  signed [7:0] a3,
  input  signed [7:0] b3,
  output       [15:0] max_product
);

  wire signed [15:0] p0 = a0 * b0;
  wire signed [15:0] p1 = a1 * b1;
  wire signed [15:0] p2 = a2 * b2;
  wire signed [15:0] p3 = a3 * b3;

  wire [15:0] abs0 = p0[15] ? (~p0 + 16'd1) : p0[15:0];
  wire [15:0] abs1 = p1[15] ? (~p1 + 16'd1) : p1[15:0];
  wire [15:0] abs2 = p2[15] ? (~p2 + 16'd1) : p2[15:0];
  wire [15:0] abs3 = p3[15] ? (~p3 + 16'd1) : p3[15:0];

  wire [15:0] max0 = (abs0 >= abs1) ? abs0 : abs1;
  wire [15:0] max1 = (abs2 >= abs3) ? abs2 : abs3;

  assign max_product = (max0 >= max1) ? max0 : max1;

endmodule