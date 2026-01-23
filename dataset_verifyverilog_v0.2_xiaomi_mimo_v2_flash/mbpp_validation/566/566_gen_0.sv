module digit_sum(
    input [15:0] num,
    output [7:0] sum
);

    // Combinational logic to compute sum of digits
    // Using repeated modulo and division
    // Max 5 digits for 16-bit number (65535)
    
    wire [15:0] num0 = num;
    wire [4:0] digit0 = num0 % 10;
    wire [15:0] num1 = num0 / 10;
    
    wire [4:0] digit1 = num1 % 10;
    wire [15:0] num2 = num1 / 10;
    
    wire [4:0] digit2 = num2 % 10;
    wire [15:0] num3 = num2 / 10;
    
    wire [4:0] digit3 = num3 % 10;
    wire [15:0] num4 = num3 / 10;
    
    wire [4:0] digit4 = num4 % 10;
    wire [15:0] num5 = num4 / 10;
    
    wire [4:0] digit5 = num5 % 10;
    wire [15:0] num6 = num5 / 10;
    
    // For 16-bit max 65535, at most 5 digits, but to be safe process up to num=0
    // When num becomes 0, remaining digits are 0
    
    wire [4:0] digit6 = num6 % 10;  // Will be 0
    wire [15:0] num7 = num6 / 10;
    
    wire [4:0] digit7 = num7 % 10;
    wire [15:0] num8 = num7 / 10;
    
    wire [4:0] digit8 = num8 % 10;
    wire [15:0] num9 = num8 / 10;
    
    wire [4:0] digit9 = num9 % 10;
    wire [15:0] num10 = num9 / 10;
    
    wire [4:0] digit10 = num10 % 10;
    
    // Sum all digits (max 5 digits, sum <= 45, fits in 8 bits)
    // But we also need to handle cases where num is small
    // Simply sum all 11 possible digits - trailing zeros won't affect sum
    
    assign sum = digit0 + digit1 + digit2 + digit3 + digit4 + 
                 digit5 + digit6 + digit7 + digit8 + digit9 + digit10;

endmodule