module DivisibleBy11(
    input [15:0] num,
    output divisible,
    output [4:0] debug_sum
);
    
    reg [4:0] digit_sum;
    reg [4:0] digit;
    reg [15:0] temp_num;
    reg [2:0] digit_pos;
    reg [4:0] odd_sum;
    reg [4:0] even_sum;
    reg [4:0] final_sum;
    
    assign temp_num = num;
    
    always @(*) begin
        odd_sum = 5'd0;
        even_sum = 5'd0;
        digit_pos = 3'd0;
        
        for (digit_pos = 3'd0; digit_pos < 5'd5; digit_pos = digit_pos + 3'd1) begin
            digit = temp_num % 10;
            temp_num = temp_num / 10;
            
            if (digit_pos[0]) begin
                odd_sum = odd_sum + digit;
            end else begin
                even_sum = even_sum + digit;
            end
        end
        
        final_sum = odd_sum - even_sum;
        
        if (final_sum == 5'd0 || final_sum == 5'd11 || final_sum == 5'd22) begin
            divisible = 1'b1;
        end else begin
            divisible = 1'b0;
        end
        
        debug_sum = final_sum;
    end
    
endmodule