module perfect_square_check(
    input [7:0] number,
    output reg is_perfect_square
);
    integer i;
    always @(*) begin
        is_perfect_square = 1'b0;
        // Check edge case 0^2 = 0
        if (number == 8'd0) begin
            is_perfect_square = 1'b1;
        end
        // Check squares from 1 to 15 (since 16^2=256 > 255)
        else begin
            for (i = 1; i <= 15; i = i + 1) begin
                if (number == (i * i)) begin
                    is_perfect_square = 1'b1;
                end
            end
        end
    end
endmodule
