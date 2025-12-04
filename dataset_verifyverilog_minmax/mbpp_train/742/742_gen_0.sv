module tetrahedron_area(
    input [15:0] side_q8,
    output [31:0] area_q16
);
    // sqrt(3) constant: 32'h0001_BB67 (1.7320508075688772 * 65536)
    parameter [31:0] SQRT3_CONST = 32'h0001_BB67;
    
    // Internal signals
    wire [31:0] square_value;
    wire [63:0] product;
    
    // Step 1: Compute square_value = side_q8 * side_q8
    assign square_value = side_q8 * side_q8;
    
    // Step 2: Multiply square_value by sqrt(3) constant
    // Take upper 32 bits for Q16.16 result
    assign product = square_value * SQRT3_CONST;
    assign area_q16 = product[63:32];

endmodule