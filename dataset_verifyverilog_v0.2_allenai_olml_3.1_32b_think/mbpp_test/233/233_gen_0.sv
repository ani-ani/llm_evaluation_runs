module lateral_surface_cylinder(input [7:0] r, input [7:0] h, output [31:0] area);
reg [31:0] temp1, temp2;
assign temp1 = r * h;
assign temp2 = temp1 * 2;
assign area = temp2 * 205887 >> 16;
endmodule