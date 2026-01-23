module sum_div(
    input [7:0] number,      // Input number (0-255)
    output reg [15:0] result // Sum of all divisors (excluding the number itself)
);

integer i;
reg [15:0] divisor_sum;

always @(*) begin
    divisor_sum = 0;
    
    // Edge cases: 0 and 1 have no proper divisors
    if (number > 1) begin
        divisor_sum = 1;  // 1 is always a divisor for n > 1
        
        // Check each potential divisor from 2 to number-1
        for (i = 2; i < number; i = i + 1) begin
            if (number % i == 0) begin
                divisor_sum = divisor_sum + i;
            end
        end
    end
    
    result = divisor_sum;
end

endmodule