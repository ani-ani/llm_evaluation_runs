module lateral_surface_cube (
    input [7:0] side_length,
    output [15:0] area
);

// Lateral surface area = 4 * side * side
// Input: side_length (8-bit, values 0-255)
// Output: area (16-bit, can hold 4*255*255 = 260100)

assign area = 4 * side_length * side_length;

endmodule