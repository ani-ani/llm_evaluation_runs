module tetrahedron_area (
    input [15:0] side,
    output [31:0] area
);

    // Q16.16 constant for sqrt(3) = 1.7320508075688772
    localparam [15:0] SQRT3 = 16'h1BC28; // 113512 decimal

    // Intermediate signals
    wire [31:0] side_squared; // 16.16 * 16.16 = 32.32 format
    wire [47:0] product;      // 32.32 * 0.16 = 48.32 format
    wire [31:0] result;       // 32.32 >> 16 = 16.16 format

    // Calculate side squared
    // side is Q16.16, so multiply by itself gives Q32.32
    assign side_squared = side * side;

    // Multiply by sqrt(3)
    // side_squared is 32 bits, SQRT3 is 16 bits
    // Result needs 32+16 = 48 bits
    assign product = side_squared * SQRT3;

    // Shift right by 16 to convert back to Q16.16 format
    assign result = product[47:16];

    // Output assignment
    assign area = result;

endmodule}