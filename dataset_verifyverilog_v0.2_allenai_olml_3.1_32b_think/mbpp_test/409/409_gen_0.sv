module min_product_tuple (
    input [7:0] x0, y0,
    input [7:0] x1, y1,
    input [7:0] x2, y2,
    input [7:0] x3, y3,
    output [15:0] min_product
);
assign product0 = (unsigned)x0 * (unsigned)y0;
assign product1 = (unsigned)x1 * (unsigned)y1;
assign product2 = (unsigned)x2 * (unsigned)y2;
assign product3 = (unsigned)x3 * (unsigned)y3;
assign temp0 = product0 < product1 ? product0 : product1;
assign temp1 = product2 < product3 ? product2 : product3;
assign min_product = temp0 < temp1 ? temp0 : temp1;
endmodule