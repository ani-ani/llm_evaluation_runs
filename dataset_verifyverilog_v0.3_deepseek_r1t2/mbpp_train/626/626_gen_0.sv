module largest_triangle_area (
    input [31:0] radius_in,
    output [31:0] area_out
);
    wire [63:0] square = radius_in * radius_in;
    assign area_out = square[47:16];
endmodule