module multiple_to_single (
    input clk,
    input rst_n,
    input start,
    input [31:0] num_1, num_2, num_3, num_4, num_5, num_6,
    input [2:0] count,
    output reg [63:0] result,
    output reg done,
    output reg error
);

    // State definition
    localparam IDLE = 3'b000;
    localparam CHECK_SIGN = 3'b001;
    localparam CONVERT_NUM = 3'b010;
    localparam BUILD_RESULT = 3'b011;
    localparam VERIFY = 3'b100;
    localparam DONE = 3'b101;

    // Internal registers
    reg [2:0] current_state, next_state;
    reg [2:0] idx; // Current input index (0 to 5)
    reg [31:0] current_num; // Current number being processed
    reg [31:0] temp_mag; // Magnitude of current number
    reg [3:0] digit; // Extracted digit
    reg [5:0] digit_count; // Digits extracted from current number
    reg is_negative; // Flag if any input was negative
    reg [63:0] result_temp; // Temporary result accumulator
    reg [63:0] multiplier; // Multiplier for digit placement
    reg [3:0] shift_count; // Counter for shifting cycles
    reg [63:0] temp_sum; // Temporary for overflow check
    reg negative_flag_internal; // Internal negative processing flag

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = CHECK_SIGN;
                else
                    next_state = IDLE;
            end
            CHECK_SIGN: begin
                if (idx < count)
                    next_state = CONVERT_NUM;
                else
                    next_state = VERIFY; // All numbers scanned for sign
            end
            CONVERT_NUM: begin
                if (temp_mag == 32'd0 && digit_count > 0)
                    next_state = BUILD_RESULT;
                else
                    next_state = CONVERT_NUM;
            end
            BUILD_RESULT: begin
                if (shift_count == 4'd0)
                    next_state = CHECK_SIGN;
                else
                    next_state = BUILD_RESULT;
            end
            VERIFY: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State Register and Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            error <= 1'b0;
            idx <= 3'd0;
            is_negative <= 1'b0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    idx <= 3'd0;
                    is_negative <= 1'b0;
                    result_temp <= 64'd0;
                    multiplier <= 64'd1;
                    negative_flag_internal <= 1'b0;
                end

                CHECK_SIGN: begin
                    if (idx < count) begin
                        // Check sign of current number based on index
                        // We check signs of all inputs in sequence
                        case (idx)
                            3'd0: if (num_1[31]) is_negative <= 1'b1;
                            3'd1: if (num_2[31]) is_negative <= 1'b1;
                            3'd2: if (num_3[31]) is_negative <= 1'b1;
                            3'd3: if (num_4[31]) is_negative <= 1'b1;
                            3'd4: if (num_5[31]) is_negative <= 1'b1;
                            3'd5: if (num_6[31]) is_negative <= 1'b1;
                        endcase
                        idx <= idx + 1;
                    end else begin
                        // Reset index for conversion loop
                        idx <= 3'd0;
                        is_negative <= is_negative; // Keep value
                    end
                end

                CONVERT_NUM: begin
                    // Get current number to convert if starting this number
                    if (digit_count == 0) begin
                        case (idx)
                            3'd0: current_num <= num_1;
                            3'd1: current_num <= num_2;
                            3'd2: current_num <= num_3;
                            3'd3: current_num <= num_4;
                            3'd4: current_num <= num_5;
                            3'd5: current_num <= num_6;
                        endcase
                        negative_flag_internal <= 1'b0;
                        // Check immediate sign for this number to handle 2's comp
                        case (idx)
                            3'd0: if (num_1[31]) negative_flag_internal <= 1'b1;
                            3'd1: if (num_2[31]) negative_flag_internal <= 1'b1;
                            3'd2: if (num_3[31]) negative_flag_internal <= 1'b1;
                            3'd3: if (num_4[31]) negative_flag_internal <= 1'b1;
                            3'd4: if (num_5[31]) negative_flag_internal <= 1'b1;
                            3'd5: if (num_6[31]) negative_flag_internal <= 1'b1;
                        endcase
                    end
                    
                    // BCD Extraction Logic
                    if (negative_flag_internal) begin
                        // Handle negative: 2's complement to magnitude
                        // If temp_mag is 0, initialize with 2's comp of current_num
                        if (digit_count == 0) begin
                            temp_mag <= (~current_num) + 1;
                            digit <= 4'd0;
                        end else begin
                            // Division by 10: {quotient, remainder}
                            // Optimized divider for 32-bit / 10
                            temp_mag <= temp_mag / 10;
                            digit <= temp_mag % 10;
                        end
                    end else begin
                        // Handle positive
                        if (digit_count == 0) begin
                            temp_mag <= current_num;
                            digit <= 4'd0;
                        end else begin
                            temp_mag <= temp_mag / 10;
                            digit <= temp_mag % 10;
                        end
                    end
                    
                    // Update counters
                    if (digit_count == 0 && temp_mag == 32'd0) begin
                         // First load, no digit processed yet, start loop
                         digit_count <= digit_count + 1;
                    end else if (temp_mag > 32'd0 || digit_count == 0) begin
                         // Process digit
                         if (temp_mag > 32'd0 || digit_count == 0) begin
                             // Need to check if we actually performed extraction this cycle
                             // The first cycle (count 0) sets temp_mag, next cycle we extract
                             if (digit_count > 0) begin
                                digit_count <= digit_count + 1;
                             end else begin
                                digit_count <= 1;
                             end
                         end
                    end else begin
                        // Done with this number
                        digit_count <= 0;
                        idx <= idx + 1;
                    end
                    
                    // Refactored Logic for robustness:
                    // Just increment cycle counter. Logic handles extraction.
                    // If temp_mag becomes 0 and we have extracted at least one digit, move to next state.
                    // We use digit_count to track progress.
                    // Actually, simpler approach:
                    // Cycle 0: Load/Init. Cycle 1+: Extract/Divide.
                end

                // Revised CONVERT_NUM for clarity
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        digit_count <= 6'd0;
                        temp_mag <= 32'd0;
                    end else if (current_state == CONVERT_NUM) begin
                        if (digit_count == 0) begin
                            // Initial Load
                            case (idx)
                                3'd0: begin current_num <= num_1; negative_flag_internal <= num_1[31]; end
                                3'd1: begin current_num <= num_2; negative_flag_internal <= num_2[31]; end
                                3'd2: begin current_num <= num_3; negative_flag_internal <= num_3[31]; end
                                3'd3: begin current_num <= num_4; negative_flag_internal <= num_4[31]; end
                                3'd4: begin current_num <= num_5; negative_flag_internal <= num_5[31]; end
                                3'd5: begin current_num <= num_6; negative_flag_internal <= num_6[31]; end
                            endcase
                            digit_count <= 6'd1;
                        end else begin
                            // Processing
                            if (digit_count == 6'd1) begin
                                // First extraction
                                if (negative_flag_internal) temp_mag <= (~current_num) + 1;
                                else temp_mag <= current_num;
                            end else begin
                                // Subsequent extractions (divide previous result)
                                temp_mag <= temp_mag / 10;
                            end
                            
                            if (digit_count >= 6'd1) begin
                                digit <= (negative_flag_internal && digit_count == 6'd1) ? 
                                         ((~current_num) + 1) % 10 : 
                                         ((digit_count == 6'd1) ? current_num % 10 : temp_mag % 10);
                            end

                            // Check termination
                            if (temp_mag < 10 && digit_count > 1) begin
                                digit_count <= 6'd0; // Reset for next number
                            end else begin
                                digit_count <= digit_count + 1;
                            end
                        end
                    end else begin
                        digit_count <= 6'd0;
                    end
                end

                BUILD_RESULT: begin
                    // Shift result by multiplier (powers of 10) and add digit
                    // Shifts are handled by state transitions, here we do the math
                    // We need to shift result_temp by multiplier value, which is essentially 
                    // adding result_temp * 10 + digit for each digit.
                    // Since we extract digits from LSB to MSB of the current number, 
                    // but we need to append to the global result.
                    // Wait, the Python example "11" + "33" = "113350".
                    // This means appending decimal representations.
                    // If we extract digits 1, 3 of 31, we get '1' then '3'. 
                    // To append "31", we do Result = Result * 100 + 31.
                    // To build "31" from digits 1, 3 (LSB to MSB): val = 1 + 3*10 = 31.
                    // We can accumulate value of current number in a temp variable, then add to result.
                    // Or, since we are processing digit by digit: 
                    // NewResult = OldResult * 10 + digit. 
                    // But this appends the digit as the *last* digit. 
                    // If we process number 31 (digits 1, 3), doing NewRes = OldRes * 10 + 1 -> appends 1.
                    // Then NewRes = NewRes * 10 + 3 -> appends 3. Result: ...13. This is correct.
                    
                    // We need a temporary variable to store the current number being built?
                    // No, just multiply the main Result by 10 and add the digit.
                    // But we must extract all digits of a number before moving to the next number?
                    // No, we can stream them. 
                    // Problem: Extract order. 
                    // 31 % 10 = 1. 3 % 10 = 3. 
                    // If we stream 1 then 3: 
                    // Res = Res*10 + 1 -> ...1
                    // Res = Res*10 + 3 -> ...13. Correct.
                    
                    // However, if we are in BUILD_RESULT, we are taking the `digit` from CONVERT_NUM.
                    // We need to ensure CONVERT_NUM outputs valid digits for the current number.
                    // Let's modify CONVERT_NUM to output one digit per cycle when active.
                    
                    // In BUILD_RESULT: 
                    result_temp <= result_temp * 10 + digit;
                end

                VERIFY: begin
                    if (is_negative) begin
                        // Check if magnitude fits in 63 bits + 1 sign bit logic
                        // Max negative is -2^63. 
                        // If result_temp > 2^63, overflow.
                        if (result_temp > 64'h8000_0000_0000_0000) begin // 2^63
                            error <= 1'b1;
                        end else begin
                            result <= -result_temp;
                            error <= 1'b0;
                        end
                    end else begin
                        // Check max positive 2^63 - 1
                        if (result_temp > 64'h7FFF_FFFF_FFFF_FFFF) begin
                            error <= 1'b1;
                        end else begin
                            result <= result_temp;
                            error <= 1'b0;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Corrected Logic for Sequential Processing
    // The block above mixes combinational and sequential logic in a way that creates multiple drivers.
    // Let's rewrite the single sequential block cleanly.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            // Defaults
            done <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    if (start) begin
                        current_state <= CHECK_SIGN;
                        idx <= 3'd0;
                        is_negative <= 1'b0;
                        result_temp <= 64'd0;
                    end
                end

                CHECK_SIGN: begin
                    if (idx < count) begin
                        // Check sign of input[idx]
                        case (idx)
                            3'd0: if (num_1[31]) is_negative <= 1'b1;
                            3'd1: if (num_2[31]) is_negative <= 1'b1;
                            3'd2: if (num_3[31]) is_negative <= 1'b1;
                            3'd3: if (num_4[31]) is_negative <= 1'b1;
                            3'd4: if (num_5[31]) is_negative <= 1'b1;
                            3'd5: if (num_6[31]) is_negative <= 1'b1;
                        endcase
                        idx <= idx + 1;
                    end else begin
                        idx <= 3'd0; // Reset for conversion
                        current_state <= CONVERT_NUM;
                    end
                end

                CONVERT_NUM: begin
                    // We need to process 'count' numbers. 
                    // If idx >= count, we are done with all numbers.
                    if (idx >= count) begin
                        current_state <= VERIFY;
                    end else begin
                        // Logic to extract digits one by one
                        // We need a digit counter or state to know if we are starting a new number
                        // We can use `digit_count` to track position in current number
                        // But `digit_count` wasn't declared in this scope in instructions, let's declare it inside or outside.
                        // Let's use `temp_mag` and `digit`.
                        
                        // First cycle for this number? (Check a flag or temp_mag zero)
                        // Let's use a flag `conv_phase`. 
                        // Actually, simpler: define internal registers before the block or use `integer`.
                        // Since I cannot define new regs outside in the prompt response easily, I will assume they are declared in the module body.
                        // Wait, the prompt says "Do not assume a clock signal unless it is explicitly given." and "Assume all inputs are of type reg unless otherwise specified". It doesn't say I can't declare local regs.
                        // I will declare them inside the module but outside the always block in the final code.
                    end
                end
                // ... (To strictly fit in one block and be correct, I need the local registers defined)
            endcase
        end
    end

    // Implementation of the single block logic with required local registers
    // The previous `always @(*)` for next_state and the main `always` block are hard to merge cleanly in a single text output without duplication.
    // I will provide the fully functional single `always` block implementation.

endmodule

// Helper module for BCD extraction not needed, we do it inline.

module multiple_to_single (
    input clk,
    input rst_n,
    input start,
    input [31:0] num_1, num_2, num_3, num_4, num_5, num_6,
    input [2:0] count,
    output reg [63:0] result,
    output reg done,
    output reg error
);

    // States
    localparam IDLE = 3'b000;
    localparam CHECK_SIGN = 3'b001;
    localparam CONVERT_NUM = 3'b010;
    localparam BUILD_RESULT = 3'b011;
    localparam VERIFY = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] idx;
    reg [31:0] temp_mag;
    reg [3:0] digit;
    reg is_negative;
    reg [63:0] temp_result;
    reg processing_number;
    reg signed [63:0] result_check;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 64'd0;
            done <= 1'b0;
            error <= 1'b0;
            idx <= 3'd0;
            is_negative <= 1'b0;
            temp_result <= 64'd0;
            processing_number <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        state <= CHECK_SIGN;
                        idx <= 3'd0;
                        is_negative <= 1'b0;
                        temp_result <= 64'd0;
                    end
                end

                CHECK_SIGN: begin
                    if (idx < count) begin
                        // Check sign of current index
                        case (idx)
                            3'd0: if (num_1[31]) is_negative <= 1'b1;
                            3'd1: if (num_2[31]) is_negative <= 1'b1;
                            3'd2: if (num_3[31]) is_negative <= 1'b1;
                            3'd3: if (num_4[31]) is_negative <= 1'b1;
                            3'd4: if (num_5[31]) is_negative <= 1'b1;
                            3'd5: if (num_6[31]) is_negative <= 1'b1;
                        endcase
                        idx <= idx + 1;
                    end else begin
                        idx <= 3'd0;
                        state <= CONVERT_NUM;
                        processing_number <= 1'b1;
                    end
                end

                CONVERT_NUM: begin
                    // If we are done with all numbers, go to verify
                    if (idx >= count && temp_mag == 0) begin
                        state <= VERIFY;
                        processing_number <= 1'b0;
                    end else begin
                        // If temp_mag is 0, we need to load a new number
                        if (temp_mag == 0) begin
                            case (idx)
                                3'd0: begin 
                                    if (num_1[31]) temp_mag <= (~num_1) + 1;
                                    else temp_mag <= num_1;
                                    digit <= (num_1[31] ? ((~num_1)+1)%10 : num_1%10);
                                end
                                3'd1: begin 
                                    if (num_2[31]) temp_mag <= (~num_2) + 1;
                                    else temp_mag <= num_2;
                                    digit <= (num_2[31] ? ((~num_2)+1)%10 : num_2%10);
                                end
                                3'd2: begin 
                                    if (num_3[31]) temp_mag <= (~num_3) + 1;
                                    else temp_mag <= num_3;
                                    digit <= (num_3[31] ? ((~num_3)+1)%10 : num_3%10);
                                end
                                3'd3: begin 
                                    if (num_4[31]) temp_mag <= (~num_4) + 1;
                                    else temp_mag <= num_4;
                                    digit <= (num_4[31] ? ((~num_4)+1)%10 : num_4%10);
                                end
                                3'd4: begin 
                                    if (num_5[31]) temp_mag <= (~num_5) + 1;
                                    else temp_mag <= num_5;
                                    digit <= (num_5[31] ? ((~num_5)+1)%10 : num_5%10);
                                end
                                3'd5: begin 
                                    if (num_6[31]) temp_mag <= (~num_6) + 1;
                                    else temp_mag <= num_6;
                                    digit <= (num_6[31] ? ((~num_6)+1)%10 : num_6%10);
                                end
                            endcase
                            // Check if number is 0 immediately? If 0, we still need to output '0'. 
                            // If temp_mag becomes 0 immediately (input 0), we move next cycle.
                        end else begin
                            // Extract next digit
                            temp_mag <= temp_mag / 10;
                            digit <= temp_mag % 10;
                        end
                        
                        // State transition to BUILD_RESULT to process the extracted digit
                        // Note: We might need to delay one cycle if we process extraction here
                        // But BUILD_RESULT is a state. Let's switch to it.
                        state <= BUILD_RESULT;
                    end
                end

                BUILD_RESULT: begin
                    // Append digit to temp_result
                    temp_result <= temp_result * 10 + digit;
                    
                    // Check if we have processed all digits of the current number
                    if (temp_mag == 0) begin
                        // Move to next number
                        idx <= idx + 1;
                        state <= CONVERT_NUM;
                    end else begin
                        // More digits in this number, back to convert to get next digit
                        state <= CONVERT_NUM;
                    end
                end

                VERIFY: begin
                    if (is_negative) begin
                        if (temp_result > 64'h8000_0000_0000_0000) begin // 2^63 = 9223372036854775808
                            error <= 1'b1;
                        end else begin
                            result <= -temp_result;
                            error <= 1'b0;
                        end
                    end else begin
                        if (temp_result > 64'h7FFF_FFFF_FFFF_FFFF) begin // 2^63 - 1
                            error <= 1'b1;
                        end else begin
                            result <= temp_result;
                            error <= 1'b0;
                        end
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule