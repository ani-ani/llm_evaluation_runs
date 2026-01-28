module cryptarithmetic_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] puzzle_str [0:15],
    input wire [3:0] puzzle_len,
    output reg [7:0] result_str [0:15],
    output reg done,
    output reg solved
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] INIT_SEARCH = 3'd2;
    localparam [2:0] ASSIGN = 3'd3;
    localparam [2:0] VALIDATE = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    reg [2:0] state, next_state;

    // Unique letters storage (max 8)
    reg [7:0] unique_letters [0:7];
    reg [3:0] num_unique;

    // Letter to digit mapping (26 entries, 8-bit each)
    reg [7:0] letter_to_digit [0:25];

    // Current assignment state
    reg [3:0] current_letter_idx;
    reg [3:0] current_digit;
    reg [7:0] digit_mask; // Tracks used digits (bit 0-9)

    // Word extraction
    reg [3:0] word1_start, word1_end;
    reg [3:0] word2_start, word2_end;
    reg [3:0] word3_start, word3_end;

    // Validation results
    reg [15:0] word1_val, word2_val, word3_val;

    // Cycle counter for timeout
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd512;

    // Helper variables
    reg [3:0] i, j, k;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            solved <= 1'b0;
            cycle_count <= 9'd0;

            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                result_str[i] <= 8'd0;
            end
            for (i = 0; i < 26; i = i + 1) begin
                letter_to_digit[i] <= 8'd255; // Invalid
            end
            for (i = 0; i < 8; i = i + 1) begin
                unique_letters[i] <= 8'd0;
            end

            num_unique <= 4'd0;
            current_letter_idx <= 4'd0;
            current_digit <= 4'd0;
            digit_mask <= 8'd0;

            word1_start <= 4'd0;
            word1_end <= 4'd0;
            word2_start <= 4'd0;
            word2_end <= 4'd0;
            word3_start <= 4'd0;
            word3_end <= 4'd0;

            word1_val <= 16'd0;
            word2_val <= 16'd0;
            word3_val <= 16'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 9'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    solved <= 1'b0;
                    if (start) begin
                        next_state <= PARSE;
                        cycle_count <= 9'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PARSE: begin
                    // Extract words and unique letters
                    word1_start <= 4'd0;
                    word1_end <= 4'd0;
                    word2_start <= 4'd0;
                    word2_end <= 4'd0;
                    word3_start <= 4'd0;
                    word3_end <= 4'd0;

                    // Find '+' and '=' positions
                    for (i = 0; i < puzzle_len; i = i + 1) begin
                        if (puzzle_str[i] == 8'd43) begin // '+'
                            word1_end <= i - 4'd1;
                            word2_start <= i + 4'd1;
                        end
                        if (puzzle_str[i] == 8'd61) begin // '='
                            word2_end <= i - 4'd1;
                            word3_start <= i + 4'd1;
                            word3_end <= puzzle_len - 4'd1;
                        end
                    end

                    // Extract unique letters
                    num_unique <= 4'd0;
                    for (i = 0; i < 26; i = i + 1) begin
                        letter_to_digit[i] <= 8'd255; // Reset
                    end

                    for (i = 0; i < puzzle_len; i = i + 1) begin
                        if (puzzle_str[i] >= 8'd65 && puzzle_str[i] <= 8'd90) begin // A-Z
                            found <= 1'b0;
                            for (j = 0; j < num_unique; j = j + 1) begin
                                if (unique_letters[j] == puzzle_str[i]) begin
                                    found <= 1'b1;
                                end
                            end
                            if (!found && num_unique < 4'd8) begin
                                unique_letters[num_unique] <= puzzle_str[i];
                                num_unique <= num_unique + 4'd1;
                            end
                        end
                    end

                    // Sort unique letters alphabetically (bubble sort)
                    for (i = 0; i < num_unique - 4'd1; i = i + 1) begin
                        for (j = 0; j < num_unique - i - 4'd1; j = j + 1) begin
                            if (unique_letters[j] > unique_letters[j + 4'd1]) begin
                                unique_letters[0] <= unique_letters[j];
                                unique_letters[j] <= unique_letters[j + 4'd1];
                                unique_letters[j + 4'd1] <= unique_letters[0];
                            end
                        end
                    end

                    next_state <= INIT_SEARCH;
                end

                INIT_SEARCH: begin
                    current_letter_idx <= 4'd0;
                    current_digit <= 4'd0;
                    digit_mask <= 8'd0;
                    next_state <= ASSIGN;
                end

                ASSIGN: begin
                    if (current_letter_idx < num_unique) begin
                        if (current_digit < 4'd10) begin
                            // Check if digit is available
                            if ((digit_mask & (1 << current_digit)) == 8'd0) begin
                                // Assign digit to letter
                                letter_to_digit[unique_letters[current_letter_idx] - 8'd65] <= current_digit;
                                digit_mask <= digit_mask | (1 << current_digit);
                                current_digit <= 4'd0;
                                current_letter_idx <= current_letter_idx + 4'd1;
                                next_state <= ASSIGN;
                            end else begin
                                current_digit <= current_digit + 4'd1;
                                next_state <= ASSIGN;
                            end
                        end else begin
                            // Backtrack
                            if (current_letter_idx == 4'd0) begin
                                next_state <= OUTPUT; // No solution
                                solved <= 1'b0;
                            end else begin
                                current_letter_idx <= current_letter_idx - 4'd1;
                                digit_mask <= digit_mask & ~(1 << letter_to_digit[unique_letters[current_letter_idx] - 8'd65]);
                                letter_to_digit[unique_letters[current_letter_idx] - 8'd65] <= 8'd255;
                                current_digit <= letter_to_digit[unique_letters[current_letter_idx] - 8'd65] + 4'd1;
                                next_state <= ASSIGN;
                            end
                        end
                    end else begin
                        next_state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    // Compute word values
                    word1_val <= 16'd0;
                    word2_val <= 16'd0;
                    word3_val <= 16'd0;

                    // Check leading zeros
                    reg leading_zero_valid;
                    leading_zero_valid <= 1'b1;

                    if (letter_to_digit[puzzle_str[word1_start] - 8'd65] == 8'd0) begin
                        leading_zero_valid <= 1'b0;
                    end
                    if (letter_to_digit[puzzle_str[word2_start] - 8'd65] == 8'd0) begin
                        leading_zero_valid <= 1'b0;
                    end
                    if (letter_to_digit[puzzle_str[word3_start] - 8'd65] == 8'd0) begin
                        leading_zero_valid <= 1'b0;
                    end

                    // Compute word1 value
                    if (leading_zero_valid) begin
                        for (i = word1_start; i <= word1_end; i = i + 1) begin
                            word1_val <= word1_val * 16'd10 + letter_to_digit[puzzle_str[i] - 8'd65];
                        end

                        // Compute word2 value
                        for (i = word2_start; i <= word2_end; i = i + 1) begin
                            word2_val <= word2_val * 16'd10 + letter_to_digit[puzzle_str[i] - 8'd65];
                        end

                        // Compute word3 value
                        for (i = word3_start; i <= word3_end; i = i + 1) begin
                            word3_val <= word3_val * 16'd10 + letter_to_digit[puzzle_str[i] - 8'd65];
                        end

                        // Check if word1 + word2 == word3
                        if (word1_val + word2_val == word3_val) begin
                            solved <= 1'b1;
                            next_state <= OUTPUT;
                        end else begin
                            solved <= 1'b0;
                            next_state <= ASSIGN;
                            // Backtrack
                            current_letter_idx <= current_letter_idx - 4'd1;
                            digit_mask <= digit_mask & ~(1 << letter_to_digit[unique_letters[current_letter_idx] - 8'd65]);
                            letter_to_digit[unique_letters[current_letter_idx] - 8'd65] <= 8'd255;
                            current_digit <= letter_to_digit[unique_letters[current_letter_idx] - 8'd65] + 4'd1;
                        end
                    end else begin
                        solved <= 1'b0;
                        next_state <= ASSIGN;
                        // Backtrack
                        current_letter_idx <= current_letter_idx - 4'd1;
                        digit_mask <= digit_mask & ~(1 << letter_to_digit[unique_letters[current_letter_idx] - 8'd65]);
                        letter_to_digit[unique_letters[current_letter_idx] - 8'd65] <= 8'd255;
                        current_digit <= letter_to_digit[unique_letters[current_letter_idx] - 8'd65] + 4'd1;
                    end
                end

                OUTPUT: begin
                    // Construct result string
                    for (i = 0; i < puzzle_len; i = i + 1) begin
                        if (puzzle_str[i] >= 8'd65 && puzzle_str[i] <= 8'd90) begin // A-Z
                            if (solved && letter_to_digit[puzzle_str[i] - 8'd65] != 8'd255) begin
                                result_str[i] <= letter_to_digit[puzzle_str[i] - 8'd65] + 8'd48; // ASCII digit
                            end else begin
                                result_str[i] <= puzzle_str[i]; // Keep original if unsolved
                            end
                        end else begin
                            result_str[i] <= puzzle_str[i]; // Keep non-letters
                        end
                    end

                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    solved <= 1'b0;
                end
            endcase

            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= OUTPUT;
                solved <= 1'b0;
            end
        end
    end

endmodule