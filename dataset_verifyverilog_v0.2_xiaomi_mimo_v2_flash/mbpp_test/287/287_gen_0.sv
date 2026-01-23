module sum_even_squares (
    input [7:0] n,
    output [31:0] result
);

    wire [31:0] term1; // 2 * n
    wire [31:0] term2; // n + 1
    wire [31:0] term3; // 2 * n + 1
    wire [63:0] prod_temp; // (2 * n) * (n + 1) * (2 * n + 1)

    // Calculate intermediate terms
    assign term1 = {24'b0, n} * 32'd2;
    assign term2 = {24'b0, n} + 32'd1;
    assign term3 = {24'b0, n} * 32'd2 + 32'd1;

    // Calculate product
    assign prod_temp = term1 * term2 * term3;

    // Divide by 3 and truncate to 32 bits
    assign result = prod_temp / 3;

endmodule