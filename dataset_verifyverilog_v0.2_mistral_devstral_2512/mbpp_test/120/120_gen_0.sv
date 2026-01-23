module max_product_tuple (
  input [15:0] pair0_a,
  input [15:0] pair0_b,
  input [15:0] pair1_a,
  input [15:0] pair1_b,
  input [15:0] pair2_a,
  input [15:0] pair2_b,
  input [15:0] pair3_a,
  input [15:0] pair3_b,
  output [15:0] max_abs_product
);

  wire signed [31:0] product0 = $signed(pair0_a) * $signed(pair0_b);
  wire signed [31:0] product1 = $signed(pair1_a) * $signed(pair1_b);
  wire signed [31:0] product2 = $signed(pair2_a) * $signed(pair2_b);
  wire signed [31:0] product3 = $signed(pair3_a) * $signed(pair3_b);

  wire [31:0] abs_product0 = (product0 < 0) ? -product0 : product0;
  wire [31:0] abs_product1 = (product1 < 0) ? -product1 : product1;
  wire [31:0] abs_product2 = (product2 < 0) ? -product2 : product2;
  wire [31:0] abs_product3 = (product3 < 0) ? -product3 : product3;

  wire [31:0] max_abs_product_full = (abs_product0 > abs_product1) ? 
    ((abs_product0 > abs_product2) ? 
      ((abs_product0 > abs_product3) ? abs_product0 : abs_product3) : 
      ((abs_product2 > abs_product3) ? abs_product2 : abs_product3)) : 
    ((abs_product1 > abs_product2) ? 
      ((abs_product1 > abs_product3) ? abs_product1 : abs_product3) : 
      ((abs_product2 > abs_product3) ? abs_product2 : abs_product3));

  assign max_abs_product = max_abs_product_full[31:16];

endmodule