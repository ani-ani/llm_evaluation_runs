module pentagon_perimeter (
    input [15:0] side_length,
    output [20:0] perimeter
);

    // Multiplication by 5: side_length * 5
    // Using addition: side_length * 4 + side_length
    // side_length * 4 is equivalent to side_length << 2
    assign perimeter = (side_length << 2) + side_length;

endmodule