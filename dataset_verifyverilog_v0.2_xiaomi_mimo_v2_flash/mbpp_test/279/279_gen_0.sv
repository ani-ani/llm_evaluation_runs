module decagonal(
    input [7:0] n,
    output [19:0] result
);

    // Internal signals
    wire [15:0] n_squared;      // n * n (8x8 = 16 bits)
    wire [17:0] term1;          // 4 * n_squared (16 + 2 = 18 bits)
    wire [9:0] term2;           // 3 * n (8 + 1 = 9 bits, max 765)
    wire [17:0] sub_result;     // term1 - term2 (18 bits)

    // Step 1: Calculate n_squared = n * n
    assign n_squared = n * n;

    // Step 2: Calculate term1 = 4 * n_squared
    assign term1 = {n_squared, 2'b00}; // left shift by 2

    // Step 3: Calculate term2 = 3 * n
    assign term2 = n * 3;

    // Step 4: Result = term1 - term2
    // Max value for n=255: 4*65025 - 765 = 260100
    // 260100 requires 18 bits (2^18 = 262144)
    assign sub_result = term1 - term2;

    // Assign to output (20 bits as requested)
    assign result = sub_result;

endmodule