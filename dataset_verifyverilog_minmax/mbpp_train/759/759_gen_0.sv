module decimal_checker (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input last_char,
    output reg valid,
    output reg done
);

    // State encoding
    typedef enum bit [2:0] {
        IDLE        = 3'b000,
        INTEGER     = 3'b001,
        DEC_POINT   = 3'b010,
        DEC_DIGIT_1 = 3'b011,
        DEC_DIGIT_2 = 3'b100,
        INVALID     = 3'b101
    } state_t;

    state_t state, next_state;
    state_t result_state; // State at time of last_char assertion
    reg last_char_seen;   // Delayed last_char signal

    // Combinational logic for next state
    always @(*) begin
        next_state = state; // Default to current state

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INTEGER;
                end
            end

            INTEGER: begin
                if (last_char) begin
                    // End of string in integer state - valid if we've seen at least one digit
                    next_state = IDLE;
                end else begin
                    if (char_in >= "0" && char_in <= "9") begin
                        next_state = INTEGER;
                    end else if (char_in == ".") begin
                        next_state = DEC_POINT;
                    end else begin
                        next_state = INVALID;
                    end
                end
            end

            DEC_POINT: begin
                if (last_char) begin
                    // Decimal point with no following digits - invalid
                    next_state = INVALID;
                end else begin
                    if (char_in >= "0" && char_in <= "9") begin
                        next_state = DEC_DIGIT_1;
                    end else begin
                        next_state = INVALID;
                    end
                end
            end

            DEC_DIGIT_1: begin
                if (last_char) begin
                    // One fractional digit - valid
                    next_state = IDLE;
                end else begin
                    if (char_in >= "0" && char_in <= "9") begin
                        next_state = DEC_DIGIT_2;
                    end else begin
                        next_state = INVALID;
                    end
                end
            end

            DEC_DIGIT_2: begin
                if (last_char) begin
                    // Two fractional digits - valid
                    next_state = IDLE;
                end else begin
                    // More than 2 fractional digits - invalid
                    next_state = INVALID;
                end
            end

            INVALID: begin
                if (last_char) begin
                    // Stay in invalid state until last_char, then return to IDLE
                    next_state = IDLE;
                end else begin
                    next_state = INVALID;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            result_state <= IDLE;
            last_char_seen <= 1'b0;
        end else begin
            // Update state
            state <= next_state;

            // Capture result state when last_char is asserted
            if (last_char) begin
                result_state <= state;
            end

            // Update last_char_seen
            last_char_seen <= last_char;

            // Set outputs in the cycle after last_char is asserted
            done <= last_char_seen;
            valid <= (result_state != INVALID) && 
                     ( (result_state == INTEGER) || 
                       (result_state == DEC_DIGIT_1) || 
                       (result_state == DEC_DIGIT_2) ) && 
                     last_char_seen;
        end
    end

endmodule