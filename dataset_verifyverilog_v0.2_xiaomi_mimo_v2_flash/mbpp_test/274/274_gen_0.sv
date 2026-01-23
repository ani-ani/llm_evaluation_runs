module even_binomial_sum (
    input [5:0] n,
    output reg [31:0] result
);
    always @(*) begin
        if (n == 6'd0) begin
            result = 32'd0;
        end else begin
            result = 32'b1 << (n - 1);
        end
    end
endmodule