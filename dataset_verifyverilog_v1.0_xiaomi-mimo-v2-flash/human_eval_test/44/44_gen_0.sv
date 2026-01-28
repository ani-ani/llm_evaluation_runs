module BaseConverter (
    input [15:0] x,
    input [3:0] base,
    output reg [7:0] digits [0:7]
);

    // Internal registers for computation
    reg [15:0] quotient;
    reg [15:0] remainder;
    reg [7:0] digit_count;
    reg [7:0] i;
    reg [2:0] j;
    reg valid_base;
    
    // ASCII constants
    localparam [7:0] ASCII_ZERO = 8'h30;
    localparam [7:0] ASCII_NULL = 8'h00;
    
    always @(*) begin
        // Check if base is valid (2-9)
        valid_base = (base >= 2) && (base <= 9);
        
        // Initialize all output digits to null
        for (j = 0; j < 8; j = j + 1) begin
            digits[j] = ASCII_NULL;
        end
        
        // Process only if base is valid
        if (valid_base && x != 16'd0) begin
            // Initialize for conversion
            quotient = x;
            digit_count = 8'd0;
            
            // Convert using repeated division
            // Since x is 16-bit, maximum 5 digits for base 2
            for (i = 0; i < 8; i = i + 1) begin
                if (quotient != 16'd0 && digit_count < 8) begin
                    // Compute remainder and quotient in one cycle
                    remainder = quotient % base;
                    quotient = quotient / base;
                    
                    // Store digit in reverse order (builds from LSB to MSB)
                    digits[digit_count] = ASCII_ZERO + remainder;
                    digit_count = digit_count + 1;
                end
            end
            
            // Reverse the digits to get MSB first
            // Only reverse the used portion
            if (digit_count > 1) begin
                // Swap digits in place
                for (i = 0; i < digit_count / 2; i = i + 1) begin
                    digits[i] = digits[i] ^ digits[digit_count - 1 - i];
                    digits[digit_count - 1 - i] = digits[i] ^ digits[digit_count - 1 - i];
                    digits[i] = digits[i] ^ digits[digit_count - 1 - i];
                end
            end
        end else if (valid_base && x == 16'd0) begin
            // Special case: input is 0
            digits[0] = ASCII_ZERO;
        end
        // If base is invalid, all digits remain null
    end

endmodule