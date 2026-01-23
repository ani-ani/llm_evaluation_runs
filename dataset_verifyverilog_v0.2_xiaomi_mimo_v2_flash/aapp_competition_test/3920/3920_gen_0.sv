module hexagon_triangles (
    input [7:0] a1,
    input [7:0] a2,
    input [7:0] a3,
    input [7:0] a4,
    input [7:0] a5,
    input [7:0] a6,
    output [31:0] count
);

    // Internal wires for intermediate calculations
    wire [8:0] sum_a1_a2_a3; // Max value: 255*3 = 765 -> 10 bits, but 9 bits enough (511 is max if split, but 765 needs 10) wait 765 < 1024 -> 10 bits
    wire [9:0] sum_term;     // (sum)^2 -> 765^2 = 585225 -> 20 bits
    wire [17:0] sq_sum;
    
    wire [15:0] sq_a1;       // 255^2 = 65025 -> 17 bits (fits in 18)
    wire [15:0] sq_a3;
    wire [15:0] sq_a4;

    // Calculate sum of a1, a2, a3
    // 255 + 255 + 255 = 765
    assign sum_a1_a2_a3 = a1 + a2 + a3;

    // Calculate (a1 + a2 + a3)^2
    // 765 * 765 = 585,225 (requires 20 bits)
    assign sq_sum = sum_a1_a2_a3 * sum_a1_a2_a3;

    // Calculate individual squares
    // 255 * 255 = 65,025 (requires 16 bits)
    assign sq_a1 = a1 * a1;
    assign sq_a3 = a3 * a3;
    assign sq_a4 = a4 * a4;

    // Final calculation: (a1 + a2 + a3)^2 - a1^2 - a3^2 - a4^2
    // Result fits in 20 bits, expanded to 32 for output
    assign count = sq_sum - sq_a1 - sq_a3 - sq_a4;

endmodule