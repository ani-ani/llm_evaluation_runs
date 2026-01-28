module triangle_area(
    input [31:0] base,
    input [31:0] height,
    output [31:0] area
);
    wire [63:0] product;
    assign product = base * height;
    assign area = product[48:17];
endmodule