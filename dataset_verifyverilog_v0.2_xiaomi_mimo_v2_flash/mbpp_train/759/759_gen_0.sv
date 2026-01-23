module string_decimal_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] char_array,
    output reg valid,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam VALIDATING = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Registers for state machine
    reg [1:0] current_state, next_state;
    reg [2:0] char_idx;         // Index for current character (0 to 7)
    reg [2:0] char_idx_next;
    
    // Validation Flags
    reg has_int_digits;         // True if at least one digit before decimal
    reg has_decimal;            // True if decimal point encountered
    reg [1:0] frac_count;       // Count of fractional digits (0-2)
    reg is_valid_internal;      // Internal valid flag accumulated during processing
    
    // Next value logic for flags (to avoid multi-driver issues)
    reg has_int_digits_next;
    reg has_decimal_next;
    reg [1:0] frac_count_next;
    reg is_valid_internal_next;

    // Temporary variable for current character
    reg [7:0] current_char;
    reg valid_char;             // Helper for character validity check

    // State Transition & Datapath Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            char_idx <= 3'd0;
            has_int_digits <= 1'b0;
            has_decimal <= 1'b0;
            frac_count <= 2'b0;
            is_valid_internal <= 1'b0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            // Default outputs to prevent latching
            valid <= 1'b0;
            done <= 1'b0;

            current_state <= next_state;
            char_idx <= char_idx_next;
            has_int_digits <= has_int_digits_next;
            has_decimal <= has_decimal_next;
            frac_count <= frac_count_next;
            is_valid_internal <= is_valid_internal_next;

            // Output Logic based on state
            case (next_state)
                DONE_STATE: begin
                    valid <= is_valid_internal_next;
                    done <= 1'b1;
                end
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                end
                default: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Combinational Logic (Next State & Next Values)
    always @(*) begin
        // Default assignments
        next_state = current_state;
        char_idx_next = char_idx;
        has_int_digits_next = has_int_digits;
        has_decimal_next = has_decimal;
        frac_count_next = frac_count;
        is_valid_internal_next = is_valid_internal;
        
        current_char = char_array[char_idx];
        valid_char = 1'b0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    char_idx_next = 3'd0;
                    has_int_digits_next = 1'b0;
                    has_decimal_next = 1'b0;
                    frac_count_next = 2'b0;
                    is_valid_internal_next = 1'b1; // Assume valid until proven otherwise
                end
            end

            PROCESSING: begin
                // Character Class Checks
                // Check if digit (0x30 - 0x39)
                if (current_char >= 8'h30 && current_char <= 8'h39) begin
                    valid_char = 1'b1;
                    if (!has_decimal) begin
                        // Integer part
                        has_int_digits_next = 1'b1;
                        is_valid_internal_next = is_valid_internal; // Still valid if we were
                    end else begin
                        // Fractional part
                        if (frac_count < 2'd2) begin
                            frac_count_next = frac_count + 1'b1;
                            is_valid_internal_next = is_valid_internal;
                        end else begin
                            // More than 2 fractional digits
                            is_valid_internal_next = 1'b0;
                        end
                    end
                end else if (current_char == 8'h2E) begin
                    // Check for decimal point
                    valid_char = 1'b1;
                    if (has_decimal) begin
                        // Multiple decimal points
                        is_valid_internal_next = 1'b0;
                    end else begin
                        has_decimal_next = 1'b1;
                        // Check: If decimal point appears, we must have seen int digits
                        if (!has_int_digits) begin
                            is_valid_internal_next = 1'b0;
                        end
                    end
                end else if (current_char == 8'h20) begin
                    // Space padding: Valid only if it is a trailing space and logic allows empty trailing
                    // However, logic requires checking "Complete string". 
                    // We treat spaces as valid characters only if the string format so far is valid
                    // but we need to ensure that if we see a space, we didn't just break format.
                    // Actually, spaces act as terminators in fixed width often.
                    // Spec says: "No digits before decimal point is invalid" (so " .12" is invalid)
                    // Spec says: "No digits after decimal point with decimal point is invalid" (so "123. " is invalid)
                    // If we encounter a space, it implies the number part is finished.
                    // Are spaces allowed in the middle? No, format is ^[0-9]+... 
                    // So space is a terminator.
                    // If we see space:
                    // 1. Must have had int digits if no decimal (e.g. "123     ") -> Valid
                    // 2. If had decimal, must have had frac digits (e.g. "12.3   ") -> Valid
                    // 3. If just decimal (e.g. "12.     ") -> Invalid
                    // 4. If nothing (e.g. "        ") -> Invalid
                    
                    if (has_decimal && frac_count == 0) begin
                        // Decimal exists but no frac digits yet -> Invalid
                        is_valid_internal_next = 1'b0;
                    end
                    if (!has_int_digits) begin
                        // No digits at all -> Invalid
                        is_valid_internal_next = 1'b0;
                    end
                    
                    // For the remaining characters, they must be spaces or the string must be padded
                    // We will rely on the fact that if we are valid so far, we stay valid for spaces.
                end else begin
                    // Any other character is invalid
                    is_valid_internal_next = 1'b0;
                end

                // Advance Index
                if (char_idx < 3'd7) begin
                    char_idx_next = char_idx + 1'b1;
                end else begin
                    // Last character processed, move to validation
                    next_state = VALIDATING;
                    char_idx_next = 3'd0; // Reset for potential use or idle
                end
            end

            VALIDATING: begin
                // Final check for conditions not caught in byte-by-byte processing
                // 1. Must have integer digits (covered in loop, but double check)
                // 2. If decimal point exists, must have at least 1 fractional digit
                
                if (!has_int_digits) begin
                    is_valid_internal_next = 1'b0;
                end else if (has_decimal && frac_count == 0) begin
                    // e.g. "123.    " - caught if spaces are processed as valid?
                    // In my logic above, space sets is_valid to 0 if frac_count==0.
                    // But if the last char was digit after decimal, e.g. "123.45", 
                    // we need to ensure we don't go to IDLE immediately.
                    // This state exists to catch the "end of valid number but need to check requirements" state.
                    is_valid_internal_next = 1'b0;
                end
                
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                // Wait here until start goes low to re-trigger
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE_STATE;
                end
            end
        endcase
    end

endmodule