module triangle_area(
    input [31:0] a,
    input [31:0] h,
    output reg [31:0] area
);
assign area = (a * h) >> 1 >> 32;
endmodule