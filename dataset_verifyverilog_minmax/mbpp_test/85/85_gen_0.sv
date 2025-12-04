module surface_area_sphere (
    input [7:0] r,
    output [31:0] surfacearea
);
    
    // Precomputed constant: 4*pi in Q16.16 format (823550 = 0x0C90FD)
    localparam [31:0] FOUR_PI = 32'h000C90FD;
    
    // Calculate radius squared (r*r) as 16-bit intermediate
    wire [15:0] r_squared = r * r;
    
    // Multiply radius squared by 4*pi constant
    // Product is 48 bits (32 + 16)
    wire [47:0] product = {FOUR_PI} * {16'b0, r_squared};
    
    // Output lower 32 bits as surface area in Q16.16 format
    assign surfacearea = product[31:0];
    
endmodule