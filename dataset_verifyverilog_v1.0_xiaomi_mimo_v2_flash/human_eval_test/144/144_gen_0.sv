module fraction_simplify (
    input [15:0] x_num,
    input [15:0] x_den,
    input [15:0] n_num,
    input [15:0] n_den,
    output result
);

    // Intermediate calculations: 32-bit to prevent overflow
    // Max 16-bit value: 65535
    // Max product: 65535 * 65535 = 4,294,836,225 (fits in 32 bits)
    wire [31:0] prod_num;
    wire [31:0] prod_den;
    wire [31:0] prod_num_reg; // Registered version for modulo
    wire [31:0] prod_den_reg; // Registered version for modulo

    // Calculate products
    assign prod_num = x_num * n_num;
    assign prod_den = x_den * n_den;

    // For modulo operation, we need to ensure we don't divide by zero
    // If prod_den is 0, result is undefined, but we'll treat as not whole number
    // Register the products for combinational logic
    assign prod_num_reg = prod_num;
    assign prod_den_reg = prod_den;

    // Compute modulo: prod_num % prod_den
    // Only compute if denominator is non-zero to avoid division by zero
    wire [31:0] modulo_result;
    wire divisible;

    // Check if denominator is non-zero and divisible
    // Using combinational logic
    assign divisible = (prod_den_reg != 32'd0) && ((prod_num_reg % prod_den_reg) == 32'd0);

    // Assign output
    assign result = divisible;

endmodule