module fraction_multiplier_check (
    input reg [7:0] num_x, den_x, num_n, den_n,
    output reg result
);
    // 16-bit intermediate products
    wire [15:0] num_product;
    wire [15:0] den_product;

    assign num_product = num_x * num_n;
    assign den_product = den_x * den_n;

    always @* begin
        if (den_product == 16'd0) begin
            result = 1'b0; // Undefined division by zero, treat as false
        end else begin
            result = (num_product % den_product == 16'd0) ? 1'b1 : 1'b0;
        end
    end
endmodule
