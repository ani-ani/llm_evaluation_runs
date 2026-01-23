module string_decimal_validator (
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] char_array,
    output reg valid,
    output reg done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        PROCESSING,
        VALIDATING,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] char_index;
    reg [1:0] fractional_digits;
    reg has_digits_before_decimal;
    reg has_decimal_point;
    reg is_valid;
    reg [3:0] counter;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            char_index <= 0;
            fractional_digits <= 0;
            has_digits_before_decimal <= 0;
            has_decimal_point <= 0;
            is_valid <= 0;
            counter <= 0;
            valid <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
            
            if (current_state == PROCESSING) begin
                char_index <= char_index + 1;
            end
            
            if (current_state == VALIDATING) begin
                counter <= counter + 1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    char_index = 0;
                    fractional_digits = 0;
                    has_digits_before_decimal = 0;
                    has_decimal_point = 0;
                    is_valid = 1;
                end
            end
            
            PROCESSING: begin
                if (char_index == 7) begin
                    next_state = VALIDATING;
                end
            end
            
            VALIDATING: begin
                if (counter == 9) begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Processing logic
    always @(*) begin
        case (current_state)
            PROCESSING: begin
                // Check current character
                if (char_array[char_index] == 8'h20) begin
                    // Space character - treat as end of string
                    if (char_index == 0) begin
                        is_valid = 0; // Empty string
                    end
                end else if (char_array[char_index] == 8'h2E) begin
                    // Decimal point
                    if (has_decimal_point || !has_digits_before_decimal) begin
                        is_valid = 0; // Multiple decimal points or no digits before
                    end else begin
                        has_decimal_point = 1;
                    end
                end else if (char_array[char_index] >= 8'h30 && char_array[char_index] <= 8'h39) begin
                    // Digit
                    if (has_decimal_point) begin
                        if (fractional_digits == 2) begin
                            is_valid = 0; // Too many fractional digits
                        end else begin
                            fractional_digits = fractional_digits + 1;
                        end
                    end else begin
                        has_digits_before_decimal = 1;
                    end
                end else begin
                    // Invalid character
                    is_valid = 0;
                end
            end
        endcase
    end

    // Output logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                valid = 0;
                done = 0;
            end
            
            PROCESSING: begin
                valid = 0;
                done = 0;
            end
            
            VALIDATING: begin
                valid = 0;
                done = 0;
            end
            
            DONE: begin
                valid = is_valid && has_digits_before_decimal && 
                       (!has_decimal_point || (has_decimal_point && fractional_digits <= 2));
                done = 1;
            end
        endcase
    end

endmodule