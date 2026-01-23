module volume_cube (
    input [31:0] side_length,
    output [63:0] volume
);

    // Combinational multiplication: volume = side_length * side_length * side_length
    // Using 64-bit intermediate result to prevent overflow for inputs up to 1023
    assign volume = side_length * side_length * side_length;

endmodule