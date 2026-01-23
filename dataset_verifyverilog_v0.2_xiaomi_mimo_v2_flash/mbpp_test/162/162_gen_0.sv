module sum_series (
    input [7:0] n,
    output reg [15:0] result
);

    integer i;
    reg [7:0] term;
    
    always @(*) begin
        result = 16'd0;
        for (i = 0; i < 16; i = i + 1) begin
            term = n - 2 * i;
            if (term > 0) begin
                result = result + term;
            end
        end
    end

endmodule