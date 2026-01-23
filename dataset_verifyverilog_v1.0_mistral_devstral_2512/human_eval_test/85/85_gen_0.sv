module array_sum_even_odd(
    input [7:0] arr [0:7],
    input [2:0] len,
    output [15:0] result
);
    reg [15:0] sum;
    integer i;
    always @(*) begin
        sum = 16'd0;
        for (i = 0; i < len; i = i + 1) begin
            if ((i % 2 == 1) && (arr[i][0] == 1'b0)) begin
                sum = sum + arr[i];
            end
        end
        result = sum;
    end
endmodule