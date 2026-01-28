module triangle_area(
    input [31:0] base,
    input [31:0] height,
    output [31:0] area
);
    
    wire signed [63:0] product;
    assign product = $signed(base) * $signed(height);
    assign area = product[47:16];
    
endmodule