module product_even_checker #(
    parameter N = 8,
    parameter WIDTH = 8
) (
    input [N-1:0][WIDTH-1:0] numbers,
    input [2:0] valid_count,
    output reg is_even
);

    integer i;
    always @(*) begin
        is_even = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < valid_count && i < N) begin
                if (numbers[i][0] == 1'b0) begin
                    is_even = 1'b1;
                end
            end
        end
    end

endmodule