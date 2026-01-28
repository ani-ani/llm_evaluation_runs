module DecimalValidator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [2:0] idx,
    input wire last_char,
    output reg valid,
    output reg done,
    output reg [2:0] state_debug
);

    // State definitions
    localparam [2:0] WAIT       = 3'd0;
    localparam [2:0] INT_DIGIT  = 3'd1;
    localparam [2:0] DEC_POINT  = 3'd2;
    localparam [2:0] DEC_DIGIT1 = 3'd3;
    localparam [2:0] DEC_DIGIT2 = 3'd4;
    localparam [2:0] ERROR      = 3'd5;
    localparam [2:0] VALID      = 3'd6;

    // ASCII codes
    localparam [7:0] ASCII_DOT   = 8'h2E;
    localparam [7:0] ASCII_0     = 8'h30;
    localparam [7:0] ASCII_9     = 8'h39;

    reg [2:0] state, next_state;
    reg [2:0] state_debug_reg;

    // State transition logic (Mealy)
    always @(*) begin
        next_state = state;
        case (state)
            WAIT: begin
                if (start) begin
                    // Check first character
                    if (char_in >= ASCII_0 && char_in <= ASCII_9) begin
                        next_state = INT_DIGIT;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end

            INT_DIGIT: begin
                // Check if current character is digit
                if (char_in >= ASCII_0 && char_in <= ASCII_9) begin
                    // If it's the last character, we're done (valid integer)
                    if (last_char) begin
                        next_state = VALID;
                    end else begin
                        next_state = INT_DIGIT; // Stay in INT_DIGIT
                    end
                end
                // Check for decimal point
                else if (char_in == ASCII_DOT) begin
                    // Must not be the last character (need fractional digits)
                    if (!last_char) begin
                        next_state = DEC_POINT;
                    end else begin
                        next_state = ERROR;
                    end
                end
                // Invalid character
                else begin
                    next_state = ERROR;
                end
            end

            DEC_POINT: begin
                // Must be followed by a digit
                if (char_in >= ASCII_0 && char_in <= ASCII_9) begin
                    next_state = DEC_DIGIT1;
                end else begin
                    next_state = ERROR;
                end
            end

            DEC_DIGIT1: begin
                // Must be followed by a digit
                if (char_in >= ASCII_0 && char_in <= ASCII_9) begin
                    // If it's the last character, we're done (valid with 1 fractional digit)
                    if (last_char) begin
                        next_state = VALID;
                    end else begin
                        next_state = DEC_DIGIT2; // Move to accept second fractional digit
                    end
                end else begin
                    next_state = ERROR;
                end
            end

            DEC_DIGIT2: begin
                // Must be followed by a digit
                if (char_in >= ASCII_0 && char_in <= ASCII_9) begin
                    // Must be the last character (valid with 2 fractional digits)
                    if (last_char) begin
                        next_state = VALID;
                    end else begin
                        // Too many fractional digits
                        next_state = ERROR;
                    end
                end else begin
                    next_state = ERROR;
                end
            end

            ERROR: begin
                // Stay in ERROR until reset
                next_state = ERROR;
            end

            VALID: begin
                // Stay in VALID until reset
                next_state = VALID;
            end

            default: begin
                next_state = WAIT;
            end
        endcase
    end

    // Sequential logic (State and Output Update)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT;
            state_debug_reg <= WAIT;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            state_debug_reg <= next_state;
            
            // Output logic
            case (next_state)
                VALID: begin
                    valid <= 1'b1;
                    done <= 1'b1;
                end
                WAIT, INT_DIGIT, DEC_POINT, DEC_DIGIT1, DEC_DIGIT2: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end
                ERROR: begin
                    valid <= 1'b0;
                    done <= 1'b0; // or 1'b1 if error counts as 'done'
                end
                default: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Assign output debug port
    assign state_debug = state_debug_reg;

endmodule