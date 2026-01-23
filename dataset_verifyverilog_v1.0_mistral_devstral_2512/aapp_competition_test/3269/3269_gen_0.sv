module distance_calculator (
    input [3:0] a0, a1, a2, a3,   // Digits of number A (most significant first)
    input [3:0] b0, b1, b2, b3,   // Digits of number B (most significant first)
    output [7:0] dist              // Sum of absolute digit differences
);

    // Compute absolute differences for each digit position
    wire [3:0] diff0 = (a0 >= b0) ? (a0 - b0) : (b0 - a0);
    wire [3:0] diff1 = (a1 >= b1) ? (a1 - b1) : (b1 - a1);
    wire [3:0] diff2 = (a2 >= b2) ? (a2 - b2) : (b2 - a2);
    wire [3:0] diff3 = (a3 >= b3) ? (a3 - b3) : (b3 - a3);

    // Sum of all differences (max 36, fits in 8 bits)
    assign dist = diff0 + diff1 + diff2 + diff3;

endmodule