module ArrayAdder(
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output [15:0] sum [0:7]
);

    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            sum[i] = a[i] + b[i];
        end
    end

endmodule