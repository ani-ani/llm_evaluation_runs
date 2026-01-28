module largest_triangle_area (
    input  [31:0] radius_in,
    output [31:0] area_out
);

    // Combinational multiplication: 32-bit × 32-bit = 64-bit intermediate
    // Q16.16 × Q16.16 = Q32.32 result in bits [47:16]
    wire signed [63:0] product;
    assign product = { {32{1'b0}}, radius_in } * { {32{1'b0}}, radius_in };
    
    // Extract Q16.16 result from bits [47:16]
    // Result = radius²
    assign area_out = product[47:16];

endmodule