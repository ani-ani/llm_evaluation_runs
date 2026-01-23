module centered_hexagonal(
    input [7:0] n,
    output [31:0] result
);

    // Internal signals for intermediate calculations
    wire [31:0] n_extended;
    wire [31:0] n_minus_one;
    wire [31:0] term1;
    wire [31:0] term2;
    wire [31:0] product;

    // Extend n to 32 bits for calculation
    assign n_extended = {24'b0, n};

    // Calculate (n - 1)
    // For n=1, this becomes 0 which is correct
    assign n_minus_one = n_extended - 1'b1;

    // Calculate 3 * n
    // 3 is a constant multiplier, can be implemented as (n << 1) + n
    assign term1 = (n_extended << 1) + n_extended;

    // Calculate (3 * n) * (n - 1)
    // 3*n is max 765 for n=255, (n-1) is max 254
    // Result max is 765 * 254 = 194,310 which fits in 32 bits
    assign product = term1 * n_minus_one;

    // Final result: 3 * n * (n - 1) + 1
    assign result = product + 1'b1;

endmodule