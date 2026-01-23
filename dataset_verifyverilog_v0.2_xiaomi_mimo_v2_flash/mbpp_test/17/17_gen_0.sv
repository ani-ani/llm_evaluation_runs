module square_perimeter(
    input [31:0] a,
    output [31:0] perimeter
);
    // Compute perimeter = 4 * a using left shift
    // In Q16.16 format, multiplying by 4 is equivalent to shifting left by 2 bits
    assign perimeter = a << 2;
endmodule