module deg_to_rad(
    input [15:0] degree,
    output [31:0] radian
);

    // The input 'degree' is in Q8.8 format.
    // We need to multiply it by pi/180, which is provided as 0x477 in Q16.16 format.
    // To perform this multiplication using fixed-point arithmetic, we must align the binary points.
    // Input Q8.8 * Constant Q16.16 results in Q24.24.
    // 1. Convert input to Q16.16 by left shifting by 8 bits.
    // 2. Multiply by the constant (1143).
    // 3. The product is Q24.24. To get Q16.16, we right shift by 8 bits.
    
    // Intermediate wires to prevent truncation during calculation
    wire [31:0] deg_extended;
    wire [47:0] product;
    
    // Step 1: Convert input to Q16.16 (Shift left by 8)
    assign deg_extended = {degree, 8'b0};
    
    // Step 2: Multiply by constant 0x477 (1143)
    assign product = deg_extended * 16'h0477;
    
    // Step 3: Shift right by 8 to normalize from Q24.24 to Q16.16
    assign radian = product[39:8];

endmodule