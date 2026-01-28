module sum_div(
    input [7:0] number,
    output reg [15:0] result
);
    
    reg [15:0] divisor_sum;
    integer i;
    
    always @(*) begin
        divisor_sum = 16'd0;
        
        if (number > 8'd1) begin
            divisor_sum = 16'd1;
            
            for (i = 2; i < number; i = i + 1) begin
                if ((number % i) == 8'd0) begin
                    divisor_sum = divisor_sum + i;
                end
            end
        end
        else if (number == 8'd1) begin
            divisor_sum = 16'd0;
        end
        
        result = divisor_sum;
    end
endmodule