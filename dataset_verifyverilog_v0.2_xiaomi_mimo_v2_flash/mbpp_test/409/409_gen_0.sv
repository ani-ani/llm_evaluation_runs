module min_product_tuple (
    input [7:0] x0, y0,
    input [7:0] x1, y1,
    input [7:0] x2, y2,
    input [7:0] x3, y3,
    output [15:0] min_product
);

    // Compute four products in parallel
    wire [15:0] p0 = x0 * y0;
    wire [15:0] p1 = x1 * y1;
    wire [15:0] p2 = x2 * y2;
    wire [15:0] p3 = x3 * y3;

    // First level of comparison (parallel)
    wire [15:0] min_01 = (p0 < p1) ? p0 : p1;
    wire [15:0] min_23 = (p2 < p3) ? p2 : p3;

    // Second level of comparison
    assign min_product = (min_01 < min_23) ? min_01 : min_23;

endmodule