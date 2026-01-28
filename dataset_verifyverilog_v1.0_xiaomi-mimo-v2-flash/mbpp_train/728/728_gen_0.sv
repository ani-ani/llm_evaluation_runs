module elementwise_add (
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [15:0] sum [0:7]
);
    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            sum[i] = {8'd0, a[i]} + {8'd0, b[i]};
        end
    end
endmodule