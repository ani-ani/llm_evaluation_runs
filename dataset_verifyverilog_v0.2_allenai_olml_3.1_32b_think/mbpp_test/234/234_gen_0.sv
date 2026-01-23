module volume_cube(
    input [31:0] side_length,
    output [63:0] volume
);
assign volume = side_length * side_length * side_length;
endmodule