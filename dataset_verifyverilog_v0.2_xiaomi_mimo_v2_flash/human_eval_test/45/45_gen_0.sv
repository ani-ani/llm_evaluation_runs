module triangle_area (
    input [31:0] a,
    input [31:0] h,
    output [31:0] area
);

    // Intermediate 64-bit multiplication result
    wire [63:0] mul_result;
    assign mul_result = a * h;

    // Shift right by 1 (divide by 2) and take upper 32 bits
    // Equivalent to: (a * h) >> 1, then taking bits [63:32]
    // Since we shift the 64-bit product right by 1, the upper 32 bits of the result
    // are bits [63:32] of (mul_result >> 1)
    assign area = (mul_result >> 1) >> 32;

endmodule