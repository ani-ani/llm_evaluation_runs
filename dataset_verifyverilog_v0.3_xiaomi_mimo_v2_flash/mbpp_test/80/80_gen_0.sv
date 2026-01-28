module tetrahedral_number (
    input [7:0] n,
    output reg [15:0] result
);

    always @(*) begin
        // T(n) = n*(n+1)*(n+2)/6
        // Use 24-bit intermediate for multiplication
        reg [23:0] product;
        product = {16'd0, n} * (n + 8'd1) * (n + 8'd2);
        result = product / 6'd6;
    end

endmodule