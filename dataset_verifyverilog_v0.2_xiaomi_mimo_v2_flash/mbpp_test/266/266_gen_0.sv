module lateral_surface_area(
    input [11:0] side_length,
    output [11:0] lsa
);
    // Lateral Surface Area = 4 * side^2
    // 12-bit input, max 4095
    // 4 * 4095 * 4095 = 67M, needs ~26 bits
    // Using 28-bit intermediate to prevent overflow
    wire [27:0] temp;
    assign temp = side_length * side_length;
    assign lsa = (temp << 2)[11:0];
endmodule