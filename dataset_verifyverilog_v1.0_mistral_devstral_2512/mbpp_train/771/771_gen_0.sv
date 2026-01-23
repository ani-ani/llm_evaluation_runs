module bracket_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input write_en,
    input check_start,
    output reg result,
    output reg done,
    output reg [2:0] error_code
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] WRITE_CHARS = 2'd1;
    localparam [1:0] CHECKING = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    // Character buffer (16 characters)
    reg [7:0] char_buffer [0:15];
    reg [3:0] char_count;
    reg [3:0] char_index;

    // Stack implementation (8 elements)
    reg [7:0] stack [0:7];
    reg [2:0] stack_ptr;

    // Current state
    reg [1:0] state, next_state;

    // Error codes
    localparam [2:0] SUCCESS = 3'd0;
    localparam [2:0] STACK_UNDERFLOW = 3'd1;
    localparam [2:0] UNMATCHED_CLOSING = 3'd2;
    localparam [2:0] STACK_OVERFLOW = 3'd3;
    localparam [2:0] INVALID_CHAR = 3'd4;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_count <= 4'd0;
            char_index <= 4'd0;
            stack_ptr <= 3'd0;
            result <= 1'b0;
            done <= 1'b0;
            error_code <= SUCCESS;

            // Initialize stack
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                stack[i] <= 8'd0;
            end

            // Initialize character buffer
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = WRITE_CHARS;
                end
            end

            WRITE_CHARS: begin
                if (check_start) begin
                    next_state = CHECKING;
                end
            end

            CHECKING: begin
                if (char_index == char_count) begin
                    next_state = COMPLETE;
                end
            end

            COMPLETE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Character buffer write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_count <= 4'd0;
            char_index <= 4'd0;
        end else begin
            if (state == WRITE_CHARS && write_en && char_count < 4'd16) begin
                char_buffer[char_count] <= char_in;
                char_count <= char_count + 4'd1;
            end
        end
    end

    // Stack processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stack_ptr <= 3'd0;
            char_index <= 4'd0;
        end else begin
            if (state == CHECKING && char_index < char_count) begin
                reg [7:0] current_char = char_buffer[char_index];
                reg [7:0] top_char;

                // Get top of stack
                if (stack_ptr > 3'd0) begin
                    top_char = stack[stack_ptr - 3'd1];
                end else begin
                    top_char = 8'd0;
                end

                // Process character
                case (current_char)
                    8'd'(': begin  // '('
                        if (stack_ptr < 3'd8) begin
                            stack[stack_ptr] <= current_char;
                            stack_ptr <= stack_ptr + 3'd1;
                        end else begin
                            error_code <= STACK_OVERFLOW;
                        end
                    end

                    8'd'{': begin  // '{'
                        if (stack_ptr < 3'd8) begin
                            stack[stack_ptr] <= current_char;
                            stack_ptr <= stack_ptr + 3'd1;
                        end else begin
                            error_code <= STACK_OVERFLOW;
                        end
                    end

                    8'd'[': begin  // '['
                        if (stack_ptr < 3'd8) begin
                            stack[stack_ptr] <= current_char;
                            stack_ptr <= stack_ptr + 3'd1;
                        end else begin
                            error_code <= STACK_OVERFLOW;
                        end
                    end

                    8'd')': begin  // ')'
                        if (stack_ptr == 3'd0) begin
                            error_code <= STACK_UNDERFLOW;
                        end else if (top_char != 8'd'(') begin
                            error_code <= UNMATCHED_CLOSING;
                        end else begin
                            stack_ptr <= stack_ptr - 3'd1;
                        end
                    end

                    8'd'}': begin  // '}'
                        if (stack_ptr == 3'd0) begin
                            error_code <= STACK_UNDERFLOW;
                        end else if (top_char != 8'd'{') begin
                            error_code <= UNMATCHED_CLOSING;
                        end else begin
                            stack_ptr <= stack_ptr - 3'd1;
                        end
                    end

                    8'd']': begin  // ']'
                        if (stack_ptr == 3'd0) begin
                            error_code <= STACK_UNDERFLOW;
                        end else if (top_char != 8'd'[') begin
                            error_code <= UNMATCHED_CLOSING;
                        end else begin
                            stack_ptr <= stack_ptr - 3'd1;
                        end
                    end

                    8'd0: begin  // Null character (ignore)
                        // Do nothing
                    end

                    default: begin  // Invalid character
                        error_code <= INVALID_CHAR;
                    end
                endcase

                char_index <= char_index + 4'd1;
            end
        end
    end

    // Completion logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            if (state == COMPLETE) begin
                if (stack_ptr == 3'd0 && error_code == SUCCESS) begin
                    result <= 1'b1;
                end else begin
                    result <= 1'b0;
                end
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule