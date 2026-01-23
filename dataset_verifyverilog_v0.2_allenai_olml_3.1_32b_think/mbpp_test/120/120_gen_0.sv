module max_product_tuple (
    input [15:0] pair0_a, pair0_b,
    input [15:0] pair1_a, pair1_b,
    input [15:0] pair2_a, pair2_b,
    input [15:0] pair3_a, pair3_b,
    output wire [15:0] max_abs_product
);
wire [31:0] prod0, prod1, prod2, prod3;
assign prod0 = (signed)pair0_a * (signed)pair0_b;
assign prod1 = (signed)pair1_a * (signed)pair1_b;
assign prod2 = (signed)pair2_a * (signed)pair2_b;
assign prod3 = (signed)pair3_a * (signed)pair3_b;
wire [31:0] abs_prod0, abs_prod1, abs_prod2, abs_prod3;
assign abs_prod0 = (prod0 >= 0) ? prod0 : -prod0;
assign abs_prod1 = (prod1 >= 0) ? prod1 : -prod1;
assign abs_prod2 = (prod2 >= 0) ? prod2 : -prod2;
assign abs_prod3 = (prod3 >= 0) ? prod3 : -prod3;
wire [31:0] max_ab, max_abc, final_max;
assign max_ab = (abs_prod0 > abs_prod1) ? abs_prod0 : abs_prod1;
assign max_abc = (max_ab > abs_prod2) ? max_ab : abs_prod2;
assign final_max = (max_abc > abs_prod3) ? max_abc : abs_prod3;
assign max_abs_product = final_max[15:0];
endmodule