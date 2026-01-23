module tetrahedral_number (
    input [7:0] n,
    output [31:0] result
);

    // Intermediate signals for multiplication
    wire [15:0] n_plus_1;
    wire [15:0] n_plus_2;
    wire [23:0] prod1; // n * (n+1)
    wire [39:0] prod2; // (n * (n+1)) * (n+2)

    // Compute (n+1) and (n+2) with zero extension to 16 bits
    assign n_plus_1 = {8'b0, n} + 16'd1;
    assign n_plus_2 = {8'b0, n} + 16'd2;

    // Calculate n * (n+1) -> Max 255*256 = 65280 (16 bits) -> extend to 24 bits for next mult
    assign prod1 = {8'b0, n} * n_plus_1;

    // Calculate (n * (n+1)) * (n+2) -> Max 65280*257 = 16,711,680 (fits in 24 bits but let's use 40 to be safe)
    // prod1 is 24 bits, n_plus_2 is 16 bits. Result needs 40 bits.
    assign prod2 = prod1 * n_plus_2;

    // Divide by 6
    // Since the product is an integer multiple of 6, standard division is exact.
    assign result = prod2 / 6;

endmodule