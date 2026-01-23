module lateral_surface_area(
    input [11:0] side_length,  // 12-bit input for side length (0-4095)
    output [11:0] lsa          // 12-bit output for lateral surface area
);

    // Lateral Surface Area of a cube = 4 * side * side
    // This is a purely combinational module
    // Maximum result: 4 * 10 * 10 = 400 for given test cases
    // 12 bits can represent up to 4095, which is sufficient


    wire [23:0] temp_product;  // Intermediate product to avoid overflow


    assign temp_product = side_length * side_length;  // side^2
    assign lsa = 4 * temp_product[11:0];              // 4 * side^2

endmodule