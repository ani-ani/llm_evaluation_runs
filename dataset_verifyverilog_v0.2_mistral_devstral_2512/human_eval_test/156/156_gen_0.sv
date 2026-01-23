module roman_converter (
    input clk,
    input rst_n,
    input start,
    input [9:0] number,
    output reg [9:0][7:0] roman_chars,
    output reg done,
    output reg error
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        CHECK_M,
        CHECK_CM,
        CHECK_D,
        CHECK_CD,
        CHECK_C,
        CHECK_XC,
        CHECK_L,
        CHECK_XL,
        CHECK_X,
        CHECK_IX,
        CHECK_V,
        CHECK_IV,
        CHECK_I,
        APPEND,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [9:0] remaining_value;
    reg [3:0] output_pos;
    reg [7:0] char_to_append;
    reg [7:0] next_char_to_append;
    reg append_two_chars;

    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            remaining_value <= 0;
            output_pos <= 0;
            char_to_append <= 0;
            next_char_to_append <= 0;
            append_two_chars <= 0;
            done <= 0;
            error <= 0;
            roman_chars <= 0;
        end else begin
            current_state <= next_state;
            if (current_state == APPEND) begin
                if (append_two_chars) begin
                    roman_chars[output_pos] <= char_to_append;
                    roman_chars[output_pos + 1] <= next_char_to_append;
                    output_pos <= output_pos + 2;
                end else begin
                    roman_chars[output_pos] <= char_to_append;
                    output_pos <= output_pos + 1;
                end
                append_two_chars <= 0;
            end
        end
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    if (number == 0 || number > 1000) begin
                        error = 1;
                        next_state = IDLE;
                    end else begin
                        error = 0;
                        remaining_value = number;
                        output_pos = 0;
                        roman_chars = 0;
                        done = 0;
                        next_state = CHECK_M;
                    end
                end
            end

            CHECK_M: begin
                if (remaining_value >= 1000) begin
                    char_to_append = 8'b01101101; // 'm'
                    remaining_value = remaining_value - 1000;
                    append_two_chars = 0;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_CM;
                end
            end

            CHECK_CM: begin
                if (remaining_value >= 900) begin
                    char_to_append = 8'b01100011; // 'c'
                    next_char_to_append = 8'b01101101; // 'm'
                    remaining_value = remaining_value - 900;
                    append_two_chars = 1;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_D;
                end
            end

            CHECK_D: begin
                if (remaining_value >= 500) begin
                    char_to_append = 8'b01100100; // 'd'
                    remaining_value = remaining_value - 500;
                    append_two_chars = 0;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_CD;
                end
            end

            CHECK_CD: begin
                if (remaining_value >= 400) begin
                    char_to_append = 8'b01100011; // 'c'
                    next_char_to_append = 8'b01100100; // 'd'
                    remaining_value = remaining_value - 400;
                    append_two_chars = 1;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_C;
                end
            end

            CHECK_C: begin
                if (remaining_value >= 100) begin
                    char_to_append = 8'b01100011; // 'c'
                    remaining_value = remaining_value - 100;
                    append_two_chars = 0;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_XC;
                end
            end

            CHECK_XC: begin
                if (remaining_value >= 90) begin
                    char_to_append = 8'b01111000; // 'x'
                    next_char_to_append = 8'b01100011; // 'c'
                    remaining_value = remaining_value - 90;
                    append_two_chars = 1;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_L;
                end
            end

            CHECK_L: begin
                if (remaining_value >= 50) begin
                    char_to_append = 8'b01101100; // 'l'
                    remaining_value = remaining_value - 50;
                    append_two_chars = 0;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_XL;
                end
            end

            CHECK_XL: begin
                if (remaining_value >= 40) begin
                    char_to_append = 8'b01111000; // 'x'
                    next_char_to_append = 8'b01101100; // 'l'
                    remaining_value = remaining_value - 40;
                    append_two_chars = 1;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_X;
                end
            end

            CHECK_X: begin
                if (remaining_value >= 10) begin
                    char_to_append = 8'b01111000; // 'x'
                    remaining_value = remaining_value - 10;
                    append_two_chars = 0;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_IX;
                end
            end

            CHECK_IX: begin
                if (remaining_value >= 9) begin
                    char_to_append = 8'b01101001; // 'i'
                    next_char_to_append = 8'b01111000; // 'x'
                    remaining_value = remaining_value - 9;
                    append_two_chars = 1;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_V;
                end
            end

            CHECK_V: begin
                if (remaining_value >= 5) begin
                    char_to_append = 8'b01110110; // 'v'
                    remaining_value = remaining_value - 5;
                    append_two_chars = 0;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_IV;
                end
            end

            CHECK_IV: begin
                if (remaining_value >= 4) begin
                    char_to_append = 8'b01101001; // 'i'
                    next_char_to_append = 8'b01110110; // 'v'
                    remaining_value = remaining_value - 4;
                    append_two_chars = 1;
                    next_state = APPEND;
                end else begin
                    next_state = CHECK_I;
                end
            end

            CHECK_I: begin
                if (remaining_value >= 1) begin
                    char_to_append = 8'b01101001; // 'i'
                    remaining_value = remaining_value - 1;
                    append_two_chars = 0;
                    next_state = APPEND;
                end else begin
                    next_state = DONE;
                end
            end

            APPEND: begin
                next_state = current_state + 1;
            end

            DONE: begin
                done = 1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule