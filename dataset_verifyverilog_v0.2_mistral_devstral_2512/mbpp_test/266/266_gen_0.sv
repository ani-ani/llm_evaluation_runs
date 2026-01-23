module lateral_surface_area(
    input [11:0] side_length,
    output [11:0] lsa
);
    
    wire [23:0] temp_product;
    
    assign temp_product = side_length * side_length;
    assign lsa = 4 * temp_product[11:0];
    
endmodule