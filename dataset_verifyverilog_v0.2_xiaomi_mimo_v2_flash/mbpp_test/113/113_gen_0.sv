module check_integer (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_idx,
    input valid_char,
    output reg result,
    output reg done,
    output reg error
);

    // ASCII Constants
    localparam ASCII_NULL = 8'h00;
    localparam ASCII_PLUS = 8'h2B;
    localparam ASCII_MINUS = 8'h2D;
    localparam ASCII_0 = 8'h30;
    localparam ASCII_9 = 8'h39;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CHECK_FIRST = 3'b001;
    localparam CHECK_REMAINING = 3'b010;
    localparam VALID = 3'b011;
    localparam INVALID = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Internal counters and flags
    reg [2:0] idx_counter;
    reg sign_seen;
    reg content_seen; // Tracks if we have seen any non-null character
    
    // Helper wires for character checks
    wire is_digit;
    wire is_sign;
    wire is_null;
    wire is_valid_char_input;

    assign is_digit = (char_in >= ASCII_0) && (char_in <= ASCII_9);
    assign is_sign = (char_in == ASCII_PLUS) || (char_in == ASCII_MINUS);
    assign is_null = (char_in == ASCII_NULL);
    
    // Determine if the current character is valid for the specific context
    // This is used to assist the state transitions
    wire char_is_acceptable;
    
    // Logic for acceptable character based on current state
    // CHECK_FIRST: Digit OR Sign
    // CHECK_REMAINING: Digit OR Null (only if we are checking strictly, but we handle logic in FSM)
    // However, strictly speaking, for valid integer, we expect digits until null termination.
    assign char_is_acceptable = 
        (current_state == CHECK_FIRST) ? (is_digit || is_sign) :
        (current_state == CHECK_REMAINING) ? (is_digit || is_null) : 1'b1;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = CHECK_FIRST;
                else
                    next_state = IDLE;
            end
            
            CHECK_FIRST: begin
                if (!valid_char) begin
                    next_state = INVALID;
                end else if (is_digit) begin
                    next_state = CHECK_REMAINING; // Valid digit at start, continue
                end else if (is_sign) begin
                    next_state = CHECK_REMAINING; // Valid sign, continue
                end else if (is_null) begin
                    next_state = INVALID; // Empty string at start is error
                end else begin
                    next_state = INVALID; // Invalid char at start
                end
            end

            CHECK_REMAINING: begin
                if (!valid_char) begin
                    next_state = INVALID;
                end else if (is_digit) begin
                    // If it's a digit, we continue, but we must ensure we don't exceed 8 chars
                    // The hardware design assumes process 8 characters.
                    // However, we also support null-termination.
                    // If we see a digit, we just stay here unless we are at the last index.
                    if (char_idx == 3'd7) begin
                        // Last index processed. If digit, we check next state logic in VALID/INVALID
                        // We need to process the 8th char. If it's a digit, next state is likely VALID (if string is 8 chars long without null)
                        // But we can't check index 8. 
                        // Assuming strict 8 cycle latency, we process indices 0-7.
                        next_state = VALID; // Treat as valid if all digits
                    end else begin
                        next_state = CHECK_REMAINING;
                    end
                end else if (is_null) begin
                    next_state = VALID; // Null termination found, valid integer
                end else begin
                    next_state = INVALID; // Invalid char
                end
            end

            VALID: begin
                next_state = DONE;
            end

            INVALID: begin
                next_state = DONE;
            end

            DONE: begin
                if (start) begin
                    next_state = CHECK_FIRST;
                end else if (!rst_n) begin // Handle reset immediately inside done or rely on global reset
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output Logic (Moore-style)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            case (next_state)
                IDLE: begin
                    result <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                end
                CHECK_FIRST, CHECK_REMAINING: begin
                    // While processing, done is low
                    done <= 1'b0;
                    // Result/Error updated only at completion
                end
                VALID: begin
                    result <= 1'b1;
                    error <= 1'b0;
                    done <= 1'b1;
                end
                INVALID: begin
                    result <= 1'b0;
                    error <= 1'b1;
                    done <= 1'b1;
                end
                DONE: begin
                    // Latch values until reset or new start
                    result <= result;
                    error <= error;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule