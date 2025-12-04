module even_divisor_count (
    input reg [7:0] n,
    output reg is_even
);
    integer i;
    reg found_square = 0;

    always @(*) begin
        found_square = 0;
        for (i = 1; i <= 15; i = i + 1) begin
            if (n % i == 0) begin
                if (n / i == i) begin
                    found_square = 1;
                end
            end
        end
        is_even = ~found_square;
    end
endmodule