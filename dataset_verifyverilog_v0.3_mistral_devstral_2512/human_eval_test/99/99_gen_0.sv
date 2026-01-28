module closest_integer(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [2:0] char_index,
    input valid_char,
    output reg signed [15:0] result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COLLECT = 3'd1;
    localparam [2:0] PARSE   = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Character storage (8 characters max)
    reg [7:0] char_buffer [0:7];
    reg [2:0] char_count;

    // Parsing variables
    reg sign;
    reg [15:0] integer_part;
    reg [15:0] fractional_part;
    reg [3:0] fractional_digits;
    reg [3:0] integer_digits;
    reg [3:0] decimal_pos;
    reg [3:0] i;

    // Error detection
    reg invalid_format;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            error <= 1'b0;
            char_count <= 3'd0;
            sign <= 1'b0;
            integer_part <= 16'd0;
            fractional_part <= 16'd0;
            fractional_digits <= 4'd0;
            integer_digits <= 4'd0;
            decimal_pos <= 4'd0;
            invalid_format <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                char_buffer[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && !valid_char) begin
                        next_state <= COLLECT;
                    end
                end

                COLLECT: begin
                    if (valid_char) begin
                        if (char_index < 8) begin
                            char_buffer[char_index] <= char_in;
                            if (char_index == 7) begin
                                char_count <= 8;
                            end else begin
                                char_count <= char_index + 1;
                            end
                        end
                    end else if (char_count > 0) begin
                        next_state <= PARSE;
                    end
                end

                PARSE: begin
                    // Initialize parsing variables
                    sign <= 1'b0;
                    integer_part <= 16'd0;
                    fractional_part <= 16'd0;
                    fractional_digits <= 4'd0;
                    integer_digits <= 4'd0;
                    decimal_pos <= 4'd0;
                    invalid_format <= 1'b0;

                    // Parse the string
                    for (i = 0; i < char_count; i = i + 1) begin
                        if (!invalid_format) begin
                            case (char_buffer[i])
                                8'd45: sign <= 1'b1;  // '-'
                                8'd43: ; // '+' - ignore
                                8'd46: decimal_pos <= i + 1;  // '.'
                                8'd48: begin  // '0'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 0;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 0;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd49: begin  // '1'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 1;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 1;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd50: begin  // '2'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 2;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 2;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd51: begin  // '3'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 3;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 3;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd52: begin  // '4'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 4;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 4;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd53: begin  // '5'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 5;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 5;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd54: begin  // '6'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 6;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 6;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd55: begin  // '7'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 7;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 7;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd56: begin  // '8'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 8;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 8;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                8'd57: begin  // '9'
                                    if (decimal_pos == 0) begin
                                        integer_part <= integer_part * 10 + 9;
                                        integer_digits <= integer_digits + 1;
                                    end else if (i > decimal_pos) begin
                                        fractional_part <= fractional_part * 10 + 9;
                                        fractional_digits <= fractional_digits + 1;
                                    end
                                end
                                default: invalid_format <= 1'b1;
                            endcase
                        end
                    end

                    // Check for valid format
                    if (decimal_pos > 0 && integer_digits == 0 && fractional_digits == 0) begin
                        invalid_format <= 1'b1;
                    end

                    if (invalid_format) begin
                        error <= 1'b1;
                        next_state <= IDLE;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Convert fractional part to Q16.16 format
                    reg [31:0] fractional_q16;
                    if (fractional_digits > 0) begin
                        fractional_q16 <= fractional_part * (32768 / (10 ** fractional_digits));
                    end else begin
                        fractional_q16 <= 32'd0;
                    end

                    // Check if fractional part >= 0.5 (32768 in Q16.16)
                    reg round_up;
                    round_up <= 1'b0;

                    if (fractional_q16 > 32'd32768) begin
                        round_up <= 1'b1;
                    end else if (fractional_q16 == 32'd32768) begin
                        // Tie-breaking: round away from zero
                        if (sign) begin
                            round_up <= 1'b0;  // Round down for negative
                        end else begin
                            round_up <= 1'b1;  // Round up for positive
                        end
                    end

                    // Apply rounding
                    if (round_up) begin
                        if (sign) begin
                            integer_part <= integer_part - 1;
                        end else begin
                            integer_part <= integer_part + 1;
                        end
                    end

                    // Apply sign
                    if (sign) begin
                        result <= -integer_part;
                    end else begin
                        result <= integer_part;
                    end

                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Cycle counter for timeout
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    error <= 1'b1;
                    next_state <= IDLE;
                end
            end
        end
    end

endmodule