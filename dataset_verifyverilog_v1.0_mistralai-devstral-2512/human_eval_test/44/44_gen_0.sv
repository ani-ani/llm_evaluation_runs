module int_to_str(
    input [15:0] x,
    input [3:0] base,
    output [7:0] digits [0:7]
);
    
    reg [7:0] temp_digits [0:7];
    integer i;
    reg [15:0] num;
    reg [3:0] b;
    reg [7:0] digit;
    reg [7:0] ascii_digit;
    reg [7:0] zero;
    
    assign zero = 8'd0;
    
    always @(*) begin
        // Initialize all digits to null
        for (i = 0; i < 8; i = i + 1) begin
            temp_digits[i] = zero;
        end
        
        // Check if base is valid (2-9)
        if (base < 4'd2 || base > 4'd9) begin
            // Invalid base - output all nulls
            for (i = 0; i < 8; i = i + 1) begin
                digits[i] = zero;
            end
        end else begin
            num = x;
            b = base;
            i = 0;
            
            // Special case: x = 0
            if (num == 16'd0) begin
                temp_digits[0] = 8'd48;  // ASCII '0'
            end else begin
                // Convert number to digits
                while (num > 16'd0 && i < 8) begin
                    digit = num % b;
                    num = num / b;
                    ascii_digit = digit + 8'd48;  // Convert to ASCII
                    temp_digits[i] = ascii_digit;
                    i = i + 1;
                end
                
                // Reverse the digits to get MSB first
                for (i = 0; i < 4; i = i + 1) begin
                    temp_digits[i] = temp_digits[7 - i];
                    temp_digits[7 - i] = temp_digits[i];
                end
            end
            
            // Assign to output
            for (i = 0; i < 8; i = i + 1) begin
                digits[i] = temp_digits[i];
            end
        end
    end
    
endmodule