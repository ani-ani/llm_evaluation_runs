module square_sum (
    input [5:0] n,
    output [31:0] result
);

    // Intermediate wires for combinational logic
    wire [11:0] n_squared;
    wire [15:0] temp;
    wire [15:0] temp_minus_1;
    wire [21:0] numerator;

    // Compute n_squared = n * n (6x6 -> 12 bits)
    assign n_squared = n * n;

    // Compute temp = 4 * n_squared (12-bit * 4 -> 16 bits)
    assign temp = n_squared << 2;

    // Compute temp_minus_1 = temp - 1
    assign temp_minus_1 = temp - 1;

    // Compute numerator = n * temp_minus_1 (6x16 -> 22 bits)
    assign numerator = n * temp_minus_1;

    // Compute result = numerator / 3 (integer division)
    assign result = numerator / 3;

endmodule