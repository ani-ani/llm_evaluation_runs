module min_product_tuple(
  input  [63:0] in_tuples,
  output [15:0] min_product
);

  // Extract 4 tuples: each 16 bits: [x(7:0) in high byte][y(7:0) in low byte]
  // Tuple 3: bits [63:48], Tuple 2: [47:32], Tuple 1: [31:16], Tuple 0: [15:0]

  wire signed [7:0] x0 = in_tuples[15:8];
  wire signed [7:0] y0 = in_tuples[7:0];
  wire signed [7:0] x1 = in_tuples[31:24];
  wire signed [7:0] y1 = in_tuples[23:16];
  wire signed [7:0] x2 = in_tuples[47:40];
  wire signed [7:0] y2 = in_tuples[39:32];
  wire signed [7:0] x3 = in_tuples[63:56];
  wire signed [7:0] y3 = in_tuples[55:48];

  // Signed products
  wire signed [15:0] prod0 = x0 * y0;
  wire signed [15:0] prod1 = x1 * y1;
  wire signed [15:0] prod2 = x2 * y2;
  wire signed [15:0] prod3 = x3 * y3;

  // Absolute values (16-bit unsigned)
  wire [15:0] abs0 = prod0[15] ? (~prod0 + 16'd1) : prod0[15:0];
  wire [15:0] abs1 = prod1[15] ? (~prod1 + 16'd1) : prod1[15:0];
  wire [15:0] abs2 = prod2[15] ? (~prod2 + 16'd1) : prod2[15:0];
  wire [15:0] abs3 = prod3[15] ? (~prod3 + 16'd1) : prod3[15:0];

  // Compare to find minimum
  wire [15:0] min01 = (abs0 <= abs1) ? abs0 : abs1;
  wire [15:0] min23 = (abs2 <= abs3) ? abs2 : abs3;

  assign min_product = (min01 <= min23) ? min01 : min23;

endmodule