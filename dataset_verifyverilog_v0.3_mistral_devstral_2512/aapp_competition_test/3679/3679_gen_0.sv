module harmonic_sum(
    input [9:0] n,
    output reg [63:0] result
);
    reg [31:0] i;
    reg [63:0] harmonic_sum_reg;
    reg [63:0] term;
    
    always @(*) begin
        harmonic_sum_reg = 64'd0;
        for (i = 1; i <= n; i = i + 1) begin
            term = 64'd0;
            if (i != 0) begin
                term = {32'd0, 32'd1} / i;
            end
            harmonic_sum_reg = harmonic_sum_reg + term;
        end
        result = harmonic_sum_reg * n;
    end
endmodule