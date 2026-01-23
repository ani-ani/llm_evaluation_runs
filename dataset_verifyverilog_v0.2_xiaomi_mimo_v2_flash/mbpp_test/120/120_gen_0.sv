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

    // Internal 32-bit wires for products
    wire signed [31:0] prod0;
    wire signed [31:0] prod1;
    wire signed [31:0] prod2;
    wire signed [31:0] prod3;

    // 32-bit signed multiplication
    assign prod0 = $signed(pair0_a) * $signed(pair0_b);
    assign prod1 = $signed(pair1_a) * $signed(pair1_b);
    assign prod2 = $signed(pair2_a) * $signed(pair2_b);
    assign prod3 = $signed(pair3_a) * $signed(pair3_b);

    // Absolute values (32-bit unsigned)
    wire [31:0] abs0;
    wire [31:0] abs1;
    wire [31:0] abs2;
    wire [31:0] abs3;

    assign abs0 = (prod0[31]) ? -prod0 : prod0;
    assign abs1 = (prod1[31]) ? -prod1 : prod1;
    assign abs2 = (prod2[31]) ? -prod2 : prod2;
    assign abs3 = (prod3[31]) ? -prod3 : prod3;

    // Comparator Logic to find maximum absolute product
    // Stage 1: Compare pairs (0 vs 1) and (2 vs 3)
    wire [31:0] max_01;
    wire [31:0] max_23;

    assign max_01 = (abs0 > abs1) ? abs0 : abs1;
    assign max_23 = (abs2 > abs3) ? abs2 : abs3;

    // Stage 2: Compare winners of stage 1
    wire [31:0] max_final;
    assign max_final = (max_01 > max_23) ? max_01 : max_23;

    // Truncate to 16 bits as requested
    assign max_abs_product = max_final[15:0];

endmodule