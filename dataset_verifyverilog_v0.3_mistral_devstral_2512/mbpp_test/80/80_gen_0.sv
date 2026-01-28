module tetrahedral_number(
    input [7:0] n,
    output [15:0] result
);
    
    reg [23:0] product;
    
    always @(*) begin
        product = n * (n + 1'b1);
        product = product * (n + 2'b10);
        result = product / 6'd6;
    end
    
endmodule