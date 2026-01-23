module sum_odd_even_pos (
    input  [7:0][7:0] data,
    input  [2:0]      length,
    output reg [9:0]  result
);

    integer i;
    always @(*) begin
        result = 10'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < length && i[0] == 1'b0 && data[i][0] == 1'b1) begin
                result = result + data[i];
            end
        end
    end

endmodule
