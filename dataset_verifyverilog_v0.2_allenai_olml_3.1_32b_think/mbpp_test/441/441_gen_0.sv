module surfacearea_cube(input [15:0] side_length, output [31:0] surface_area);
assign surface_area = 6 * side_length * side_length;
endmodule