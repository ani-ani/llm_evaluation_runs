module min_product_tuple (
  input [7:0] x0, y0,
  input [7:0] x1, y1,
  input [7:0] x2, y2,
  input [7:0] x3, y3,
  output [15:0] min_product
);

  // Compute all four products in parallel
  wire [15:0] product0 = x0 * y0;
  wire [15:0] product1 = x1 * y1;
  wire [15:0] product2 = x2 * y2;
  wire [15:0] product3 = x3 * y3;

  // First level of comparisons (parallel)
  wire [15:0] min01 = (product0 < product1) ? product0 : product1;
  wire [15:0] min23 = (product2 < product3) ? product2 : product3;

  // Final comparison
  assign min_product = (min01 < min23) ? min01 : min23;

endmodule