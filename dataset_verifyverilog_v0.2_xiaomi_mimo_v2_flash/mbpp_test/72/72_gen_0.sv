module diff_of_squares (
    input [31:0] n,
    output result
);

    // A number can be represented as the difference of two squares
    // if and only if (n % 4) != 2.
    // We compute n modulo 4 by looking at the two least significant bits.
    // 00 -> 0, 01 -> 1, 10 -> 2, 11 -> 3.
    // Result is 1 if the value is 0, 1, or 3; 0 if the value is 2.
    
    assign result = (n[1:0] != 2'b10);

endmodule
