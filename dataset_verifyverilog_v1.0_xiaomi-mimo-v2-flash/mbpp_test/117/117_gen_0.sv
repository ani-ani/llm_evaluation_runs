module string_parser(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] pair_0_str_0,
    input wire [63:0] pair_0_str_1,
    input wire [63:0] pair_1_str_0,
    input wire [63:0] pair_1_str_1,
    input wire [63:0] pair_2_str_0,
    input wire [63:0] pair_2_str_1,
    input wire [63:0] pair_3_str_0,
    input wire [63:0] pair_3_str_1,
    output reg [31:0] result_pair_0_val_0,
    output reg [31:0] result_pair_0_val_1,
    output reg [31:0] result_pair_1_val_0,
    output reg [31:0] result_pair_1_val_1,
    output reg [31:0] result_pair_2_val_0,
    output reg [31:0] result_pair_2_val_1,
    output reg [31:0] result_pair_3_val_0,
    output reg [31:0] result_pair_3_val_1,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_PAIR_0_STR_0 = 3'd1;
    localparam [2:0] PARSE_PAIR_0_STR_1 = 3'd2;
    localparam [2:0] PARSE_PAIR_1_STR_0 = 3'd3;
    localparam [2:0] PARSE_PAIR_1_STR_1 = 3'd4;
    localparam [2:0] PARSE_PAIR_2_STR_0 = 3'd5;
    localparam [2:0] PARSE_PAIR_2_STR_1 = 3'd6;
    localparam [2:0] PARSE_PAIR_3_STR_0 = 3'd7;
    localparam [2:0] PARSE_PAIR_3_STR_1 = 3'd8;
    localparam [2:0] FINISH = 3'd9;

    reg [3:0] state;
    reg [7:0] char_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd150;

    // Parser state
    reg is_numeric;
    reg dot_seen;
    reg [31:0] int_part;
    reg [31:0] frac_part;
    reg [31:0] frac_multiplier;
    reg [7:0] first_alpha_char;
    reg [63:0] current_string;
    reg [31:0] parsed_value;
    reg parsing_done;

    // Intermediate values for Q16.16 conversion
    reg [63:0] scaled_int;
    reg [63:0] scaled_frac;
    reg [63:0] total_scaled;
    reg [63:0] final_result;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_pair_0_val_0 <= 32'd0;
            result_pair_0_val_1 <= 32'd0;
            result_pair_1_val_0 <= 32'd0;
            result_pair_1_val_1 <= 32'd0;
            result_pair_2_val_0 <= 32'd0;
            result_pair_2_val_1 <= 32'd0;
            result_pair_3_val_0 <= 32'd0;
            result_pair_3_val_1 <= 32'd0;
            cycle_count <= 8'd0;
            char_index <= 8'd0;
            is_numeric <= 1'b1;
            dot_seen <= 1'b0;
            int_part <= 32'd0;
            frac_part <= 32'd0;
            frac_multiplier <= 32'd1;
            first_alpha_char <= 8'd0;
            parsed_value <= 32'd0;
            parsing_done <= 1'b0;
            scaled_int <= 64'd0;
            scaled_frac <= 64'd0;
            total_scaled <= 64'd0;
            final_result <= 64'd0;
            current_string <= 64'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE_PAIR_0_STR_0;
                        current_string <= pair_0_str_0;
                        // Initialize parser
                        is_numeric <= 1'b1;
                        dot_seen <= 1'b0;
                        int_part <= 32'd0;
                        frac_part <= 32'd0;
                        frac_multiplier <= 32'd1;
                        first_alpha_char <= 8'd0;
                        parsed_value <= 32'd0;
                        parsing_done <= 1'b0;
                        char_index <= 8'd0;
                    end
                end

                // Each state processes one string character by character
                PARSE_PAIR_0_STR_0, PARSE_PAIR_0_STR_1,
                PARSE_PAIR_1_STR_0, PARSE_PAIR_1_STR_1,
                PARSE_PAIR_2_STR_0, PARSE_PAIR_2_STR_1,
                PARSE_PAIR_3_STR_0, PARSE_PAIR_3_STR_1: begin
                    if (cycle_count < MAX_CYCLES) begin
                        cycle_count <= cycle_count + 8'd1;

                        // Process character
                        if (char_index < 8'd8) begin
                            // Extract current byte from string
                            // current_string[7:0] is byte 0, current_string[15:8] is byte 1, etc.
                            // We process left to right: byte 7 is index 0, byte 0 is index 7 if we shift right
                            // Wait, spec says "byte 0-7 hold ASCII characters"
                            // Let's assume byte 0 is first character (index 0), byte 7 is last (index 7)
                            // So current_string[7:0] is char_index 0
                            // current_string[15:8] is char_index 1
                            // etc.
                            reg [7:0] current_char;
                            current_char = current_string[7:0];

                            if (current_char >= 8'd48 && current_char <= 8'd57) begin
                                // Digit '0'-'9'
                                if (is_numeric) begin
                                    if (!dot_seen) begin
                                        int_part <= (int_part * 32'd10) + (current_char - 8'd48);
                                    end else begin
                                        frac_part <= (frac_part * 32'd10) + (current_char - 8'd48);
                                        frac_multiplier <= frac_multiplier * 32'd10;
                                    end
                                end
                            end else if (current_char == 8'd46) begin
                                // Dot '.'
                                if (is_numeric && !dot_seen) begin
                                    dot_seen <= 1'b1;
                                end
                            end else if (current_char >= 8'd97 && current_char <= 8'd122) begin
                                // Alpha 'a'-'z'
                                is_numeric <= 1'b0;
                                if (first_alpha_char == 8'd0) begin
                                    first_alpha_char <= current_char;
                                end
                            end else if (current_char == 8'd32) begin
                                // Space - end of string if all spaces before
                                // If we haven't seen non-space yet, keep going
                                // If we saw something, this is padding and we ignore
                                // Actually, spec says: "process only the non-space characters from left to right"
                                // And "spaces are ignored (treated as end of string)"
                                // So if we see a space and we haven't started parsing, continue.
                                // If we have started, spaces are padding.
                                // Logic: if current_char is space and we haven't seen any digit/dot/alpha yet?
                                // We need a flag "started".
                                // Let's refine: shift string left by 8 bits to get next char
                            end

                            // Shift string left by 8 bits for next char
                            current_string <= {current_string[55:0], 8'd0};
                            char_index <= char_index + 8'd1;
                        end else begin
                            // Finished string (8 chars processed)
                            parsing_done <= 1'b1;

                            // Calculate result
                            if (is_numeric) begin
                                // Q16.16 conversion
                                // result = ( (int_part * 100 + frac_part) * 65536 ) / 100
                                // To handle fractional precision properly:
                                // If we read "12.34", int=12, frac=34, mult=100
                                // Value = 12 + 34/100 = 12.34
                                // Scaled by 65536 = 12.34 * 65536
                                // = 12 * 65536 + (34 * 65536) / 100

                                scaled_int <= int_part * 64'd65536;
                                // Calculate fraction: (frac_part * 65536) / frac_multiplier
                                // But spec says "Assume valid input strings... up to 2 digits for simplicity"
                                // and "Fractional part up to 99 (7 bits), total scaled by 100"
                                // So if we have 2 digits, mult is 100. If 1 digit, mult is 10.
                                // Let's compute (frac_part * 65536) / frac_multiplier
                                // To avoid division in hardware if possible, we can map multiplier to divisor
                                // 10 -> 65536/10 = 6553
                                // 100 -> 65536/100 = 655 (approx)
                                // Let's just do integer arithmetic: (frac_part * 65536) / frac_multiplier

                                scaled_frac <= (frac_part * 64'd65536) / frac_multiplier;
                                total_scaled <= (int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier);
                                parsed_value <= (int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier);
                                
                                // Handle edge case: empty string or just spaces -> treated as 0
                                // If no digits were seen and !dot_seen, int_part is 0, result is 0.
                            end else begin
                                // Alpha
                                parsed_value <= {first_alpha_char, 24'd0};
                            end

                            // Move to next state or finish
                            case (state)
                                PARSE_PAIR_0_STR_0: begin
                                    result_pair_0_val_0 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= PARSE_PAIR_0_STR_1;
                                    current_string <= pair_0_str_1;
                                    char_index <= 8'd0;
                                    is_numeric <= 1'b1;
                                    dot_seen <= 1'b0;
                                    int_part <= 32'd0;
                                    frac_part <= 32'd0;
                                    frac_multiplier <= 32'd1;
                                    first_alpha_char <= 8'd0;
                                    parsing_done <= 1'b0;
                                end
                                PARSE_PAIR_0_STR_1: begin
                                    result_pair_0_val_1 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= PARSE_PAIR_1_STR_0;
                                    current_string <= pair_1_str_0;
                                    char_index <= 8'd0;
                                    is_numeric <= 1'b1;
                                    dot_seen <= 1'b0;
                                    int_part <= 32'd0;
                                    frac_part <= 32'd0;
                                    frac_multiplier <= 32'd1;
                                    first_alpha_char <= 8'd0;
                                    parsing_done <= 1'b0;
                                end
                                PARSE_PAIR_1_STR_0: begin
                                    result_pair_1_val_0 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= PARSE_PAIR_1_STR_1;
                                    current_string <= pair_1_str_1;
                                    char_index <= 8'd0;
                                    is_numeric <= 1'b1;
                                    dot_seen <= 1'b0;
                                    int_part <= 32'd0;
                                    frac_part <= 32'd0;
                                    frac_multiplier <= 32'd1;
                                    first_alpha_char <= 8'd0;
                                    parsing_done <= 1'b0;
                                end
                                PARSE_PAIR_1_STR_1: begin
                                    result_pair_1_val_1 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= PARSE_PAIR_2_STR_0;
                                    current_string <= pair_2_str_0;
                                    char_index <= 8'd0;
                                    is_numeric <= 1'b1;
                                    dot_seen <= 1'b0;
                                    int_part <= 32'd0;
                                    frac_part <= 32'd0;
                                    frac_multiplier <= 32'd1;
                                    first_alpha_char <= 8'd0;
                                    parsing_done <= 1'b0;
                                end
                                PARSE_PAIR_2_STR_0: begin
                                    result_pair_2_val_0 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= PARSE_PAIR_2_STR_1;
                                    current_string <= pair_2_str_1;
                                    char_index <= 8'd0;
                                    is_numeric <= 1'b1;
                                    dot_seen <= 1'b0;
                                    int_part <= 32'd0;
                                    frac_part <= 32'd0;
                                    frac_multiplier <= 32'd1;
                                    first_alpha_char <= 8'd0;
                                    parsing_done <= 1'b0;
                                end
                                PARSE_PAIR_2_STR_1: begin
                                    result_pair_2_val_1 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= PARSE_PAIR_3_STR_0;
                                    current_string <= pair_3_str_0;
                                    char_index <= 8'd0;
                                    is_numeric <= 1'b1;
                                    dot_seen <= 1'b0;
                                    int_part <= 32'd0;
                                    frac_part <= 32'd0;
                                    frac_multiplier <= 32'd1;
                                    first_alpha_char <= 8'd0;
                                    parsing_done <= 1'b0;
                                end
                                PARSE_PAIR_3_STR_0: begin
                                    result_pair_3_val_0 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= PARSE_PAIR_3_STR_1;
                                    current_string <= pair_3_str_1;
                                    char_index <= 8'd0;
                                    is_numeric <= 1'b1;
                                    dot_seen <= 1'b0;
                                    int_part <= 32'd0;
                                    frac_part <= 32'd0;
                                    frac_multiplier <= 32'd1;
                                    first_alpha_char <= 8'd0;
                                    parsing_done <= 1'b0;
                                end
                                PARSE_PAIR_3_STR_1: begin
                                    result_pair_3_val_1 <= (is_numeric) ? ((int_part * 64'd65536) + ((frac_part * 64'd65536) / frac_multiplier)) : {first_alpha_char, 24'd0};
                                    state <= FINISH;
                                end
                                default: state <= IDLE;
                            endcase
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule