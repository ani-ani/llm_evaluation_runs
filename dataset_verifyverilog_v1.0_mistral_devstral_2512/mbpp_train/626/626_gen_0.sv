module largest_triangle_area (
    input  [31:0] radius_in,
    output [31:0] area_out
);
    
    wire signed [63:0] product;
    assign product = $signed(radius_in) * $signed(radius_in);
    assign area_out = product[47:16];
    
endmodule