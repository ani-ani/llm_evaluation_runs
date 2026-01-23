module surfacearea_cube(
    input [15:0] side_length,
    output [31:0] surface_area
);
    // Combinational calculation: surface_area = 6 * side_length * side_length
    // side_length is 16-bit, so side_length * side_length fits in 32-bit
    // 6 * (side_length * side_length) fits in 32-bit (max ~25 billion < 2^32)
    assign surface_area = 6 * side_length * side_length;
endmodule