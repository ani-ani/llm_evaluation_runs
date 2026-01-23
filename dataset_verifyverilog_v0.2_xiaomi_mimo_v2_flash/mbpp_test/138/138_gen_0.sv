module powers_of_two_sum(
    input [15:0] num,
    output reg result
);
    always @(*) begin
        // Result is 1 if num is even (bit 0 = 0) and non-zero
        // This ensures it can be represented as sum of powers of 2 >= 2
        result = (num != 16'd0) && (num[0] == 1'b0);
    end
endmodule