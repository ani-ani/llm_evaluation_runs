module surfacearea_cube (
    input  [7:0] l,
    output [15:0] result
);

    // Intermediate: square of l (fits in 16 bits for l ≤ 255)
    wire [15:0] l_squared;
    
    // Multiply 8-bit l by 8-bit l to get 16-bit result
    assign l_squared = l * l;
    
    // Multiply by 6: result = 6 * l_squared
    assign result = 6 * l_squared;

endmodule