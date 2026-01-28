module packet_distribution (
    input [29:0] n,
    output [4:0] ans
);

    reg [4:0] result;
    integer i;

    always @(*) begin
        result = 5'd0;
        for (i = 30; i >= 1; i = i - 1) begin
            if ((1 << i) - 1 >= n) begin
                result = i;
            end
        end
    end

    assign ans = result;

endmodule