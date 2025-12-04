module min_product_tuple (
    input [63:0] tuples,
    output [15:0] min_product
);

    // Extract four 16-bit tuples
    logic [15:0] tuple0, tuple1, tuple2, tuple3;
    assign tuple0 = tuples[15:0];
    assign tuple1 = tuples[31:16];
    assign tuple2 = tuples[47:32];
    assign tuple3 = tuples[63:48];

    // Extract x & y (signed)
    logic signed [7:0] x0, x1, x2, x3;
    logic signed [7:0] y0, y1, y2, y3;
    assign x0 = tuple0[15:8];
    assign x1 = tuple1[15:8];
    assign x2 = tuple2[15:8];
    assign x3 = tuple3[15:8];
    assign y0 = tuple0[7:0];
    assign y1 = tuple1[7:0];
    assign y2 = tuple2[7:0];
    assign y3 = tuple3[7:0];

    // Products (signed)
    logic signed [15:0] prod0, prod1, prod2, prod3;
    assign prod0 = x0 * y0;
    assign prod1 = x1 * y1;
    assign prod2 = x2 * y2;
    assign prod3 = x3 * y3;

    // Absolute values
    logic [15:0] abs_prod0, abs_prod1, abs_prod2, abs_prod3;
    assign abs_prod0 = (prod0 >= 0) ? prod0 : -prod0;
    assign abs_prod1 = (prod1 >= 0) ? prod1 : -prod1;
    assign abs_prod2 = (prod2 >= 0) ? prod2 : -prod2;
    assign abs_prod3 = (prod3 >= 0) ? prod3 : -prod3;

    // Find min
    logic [15:0] min01, min23;
    assign min01 = (abs_prod0 < abs_prod1) ? abs_prod0 : abs_prod1;
    assign min23 = (abs_prod2 < abs_prod3) ? abs_prod2 : abs_prod3;
    assign min_product = (min01 < min23) ? min01 : min23;

endmodule