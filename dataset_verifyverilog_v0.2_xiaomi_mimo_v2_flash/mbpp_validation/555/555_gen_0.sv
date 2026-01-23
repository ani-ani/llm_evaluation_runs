module difference_module (
    input [3:0] n,
    output [31:0] result
);

    // Intermediate signals
    // n is 4 bits, so n*(n+1) max value is 15*16 = 240 (fits in 9 bits)
    // Let's use a wider bit-width for safety, say 12 bits.
    wire [11:0] n_ext;
    wire [11:0] n_plus_1;
    wire [23:0] product; // 12 bits * 12 bits = 24 bits
    wire [23:0] S_shifted; // S = product >> 1
    wire [23:0] S_minus_1;
    wire [47:0] result_full; // 24 bits * 24 bits = 48 bits

    // Extend n to 12 bits to avoid overflow in addition and multiplication
    assign n_ext = {8'b0, n};

    // Calculate n + 1
    assign n_plus_1 = n_ext + 1'b1;

    // Calculate n * (n + 1)
    assign product = n_ext * n_plus_1;

    // Calculate S = n * (n + 1) / 2
    // Since n*(n+1) is always even, integer division by shifting is safe.
    assign S_shifted = product >> 1;

    // Calculate S - 1
    assign S_minus_1 = S_shifted - 1'b1;

    // Calculate result = S * (S - 1)
    assign result_full = S_shifted * S_minus_1;

    // Assign output (S and S-1 are at most 12 bits, so result fits in 24 bits easily)
    // Input constraint example n=15 -> S=120, S*(S-1) = 14280 (fits in 14 bits)
    assign result = result_full[31:0];

endmodule