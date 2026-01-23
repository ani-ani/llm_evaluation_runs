module product_even_checker(
    parameter N = 8,
    parameter WIDTH = 8,
    input [N-1:0][WIDTH-1:0] numbers,
    input [2:0] valid_count,
    output reg is_even
);
always @(*) begin
    is_even = 1'b0;
    for (int i=0; i < N; i++) begin
        if (valid_count > i)
            is_even |= ~numbers[i][0];
    end
end
endmodule