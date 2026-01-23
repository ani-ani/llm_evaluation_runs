module tetrahedron_area(input [31:0] side, output [31:0] area);
localparam integer SQRT3_Q16 = 0x1BC28;
assign area = ( (side * side) * SQRT3_Q16 ) >> 32;
endmodule