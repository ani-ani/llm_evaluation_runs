module sum_odd_range(
    input [7:0] l,
    input [7:0] r,
    output [15:0] result
);

    // Intermediate wires for terms and squares
    wire [7:0] term_r;
    wire [7:0] term_l;
    wire [15:0] sq_r;
    wire [15:0] sq_l;

    // Step 1: Calculate term_r = (r + 1) >> 1
    // Since the input type is explicitly not specified, assuming reg is not required.
    // Assignments are combinational.
    assign term_r = (r + 1) >> 1;

    // Step 2: Calculate term_l = l >> 1 (represents (l - 1 + 1) / 2)
    assign term_l = l >> 1;

    // Step 3: Square both terms using 16-bit arithmetic
    assign sq_r = term_r * term_r;
    assign sq_l = term_l * term_l;

    // Step 4: Output result = sq_r - sq_l
    assign result = sq_r - sq_l;

endmodule