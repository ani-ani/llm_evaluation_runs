module divisibility_checker_11 (
    input [15:0] num,
    output reg divisible,
    output reg [4:0] debug_sum
);

    // Internal signals for digit extraction
    reg [15:0] temp_num;
    reg [4:0] digit_sum_odd;
    reg [4:0] digit_sum_even;
    reg [4:0] digit;
    reg [2:0] pos_index;
    reg [2:0] cycle_count;
    
    // Digit extraction loop variables
    integer i;
    reg [4:0] current_digit;
    
    always @(*) begin
        // Initialize all internal registers
        temp_num = num;
        digit_sum_odd = 5'd0;
        digit_sum_even = 5'd0;
        digit = 5'd0;
        pos_index = 3'd0;
        
        // Process up to 5 digits (max for 16-bit number)
        for (i = 0; i < 5; i = i + 1) begin
            // Extract least significant digit
            current_digit = temp_num[3:0];  // 4 bits needed for 0-9
            
            // Check if position is odd (0-indexed: 0=even, 1=odd, etc.)
            if (i[0] == 1'b0) begin  // Even positions (0, 2, 4)
                digit_sum_even = digit_sum_even + current_digit;
            end else begin  // Odd positions (1, 3)
                digit_sum_odd = digit_sum_odd + current_digit;
            end
            
            // Divide by 10 for next digit
            // Integer division: temp_num = temp_num / 10
            temp_num = temp_num / 16'd10;
            
            // Early termination if no more digits
            if (temp_num == 16'd0 && i < 4) begin
                // Remaining positions contribute 0
                // Continue loop for proper timing alignment
            end
        end
        
        // Compute alternating sum: (odd positions) - (even positions)
        // Note: Rule is (sum digits at odd positions) - (sum digits at even positions)
        // where positions are counted from right (least significant = position 0)
        // If result is 0 or ±11, divisible by 11
        
        // Perform subtraction (signed)
        // Since we're working with 5-bit sums (max 5*9 = 45 fits in 6 bits)
        // We'll use a wider intermediate to handle signed result
        
        reg signed [6:0] signed_sum;
        signed_sum = {2'b00, digit_sum_odd} - {2'b00, digit_sum_even};
        
        // Check if result is 0 or ±11
        // Result can be negative, so convert to absolute value for comparison
        reg [6:0] abs_result;
        if (signed_sum[6]) begin
            // Negative - convert to positive
            abs_result = -signed_sum;
        end else begin
            abs_result = signed_sum;
        end
        
        // Output debug_sum (5 bits, clamped)
        // If result is 0-31, pass through
        // If result > 31, clamp to 31
        // If result is negative, we still output clamped positive value
        if (abs_result > 5'd31) begin
            debug_sum = 5'd31;
        end else begin
            debug_sum = abs_result[4:0];
        end
        
        // Divisible check: result == 0 or result == 11 or result == -11
        divisible = 1'b0;
        if (signed_sum == 7'sd0) begin
            divisible = 1'b1;
        end else if (signed_sum == 7'sd11) begin
            divisible = 1'b1;
        end else if (signed_sum == 7'sd11) begin  // Double-check
            divisible = 1'b1;
        end else if (signed_sum == -7'sd11) begin
            divisible = 1'b1;
        end
        
        // Simplified final check (to avoid multiple comparisons)
        // Actually checking: (sum == 0) || (sum == 11) || (sum == -11)
        if ((signed_sum == 7'sd0) || (signed_sum == 7'sd11) || (signed_sum == -7'sd11)) begin
            divisible = 1'b1;
        end else begin
            divisible = 1'b0;
        end
    end

endmodule