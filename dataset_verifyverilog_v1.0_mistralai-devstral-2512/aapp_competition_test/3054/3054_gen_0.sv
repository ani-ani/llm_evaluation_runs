module HaikuFormatter(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_done,
    output [7:0] line1 [0:15],
    output [7:0] line2 [0:15],
    output [7:0] line3 [0:15],
    output [3:0] line1_len,
    output [3:0] line2_len,
    output [3:0] line3_len,
    output valid,
    output invalid,
    output reg done
);

    // Constants
    localparam [7:0] SPACE = 8'd32;
    localparam [7:0] NULL_CHAR = 8'd0;
    localparam [7:0] PERIOD = 8'd46;
    localparam [7:0] COMMA = 8'd44;
    localparam [7:0] QUESTION = 8'd63;
    localparam [7:0] EXCLAMATION = 8'd33;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] COUNT_SYLLABLES = 3'd2;
    localparam [2:0] SPLIT_LINES = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Input buffer
    reg [7:0] input_buffer [0:199];
    reg [7:0] buffer_index;
    reg [7:0] word_count;
    reg [7:0] word_start [0:15];
    reg [7:0] word_end [0:15];

    // Syllable counter
    reg [3:0] syllable_count [0:15];
    reg [7:0] current_word_index;
    reg [7:0] current_char_index;
    reg [3:0] current_syllables;

    // Syllable FSM states
    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_VOWEL = 2'd1;
    localparam [1:0] S_CONSONANT = 2'd2;
    reg [1:0] syllable_state;
    reg vowel_flag;
    reg qu_flag;

    // Line splitter
    reg [3:0] line1_words;
    reg [3:0] line2_words;
    reg [3:0] line3_words;
    reg [3:0] line1_syllables;
    reg [3:0] line2_syllables;
    reg [3:0] line3_syllables;
    reg [7:0] line_split_index;
    reg [7:0] backtrack_index;
    reg [7:0] temp_line1;
    reg [7:0] temp_line2;
    reg [7:0] temp_line3;

    // Output formatting
    reg [7:0] output_line1 [0:15];
    reg [7:0] output_line2 [0:15];
    reg [7:0] output_line3 [0:15];
    reg [3:0] output_line1_len;
    reg [3:0] output_line2_len;
    reg [3:0] output_line3_len;
    reg output_valid;
    reg output_invalid;

    // Main state machine
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Vowel detection
    function is_vowel;
        input [7:0] c;
        begin
            is_vowel = (c == 8'd65) || (c == 8'd69) || (c == 8'd73) || (c == 8'd79) || (c == 8'd85) || (c == 8'd89);
        end
    endfunction

    // Consonant detection
    function is_consonant;
        input [7:0] c;
        begin
            is_consonant = (c >= 8'd66 && c <= 8'd90) && !is_vowel(c);
        end
    endfunction

    // Punctuation detection
    function is_punctuation;
        input [7:0] c;
        begin
            is_punctuation = (c == PERIOD) || (c == COMMA) || (c == QUESTION) || (c == EXCLAMATION);
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            buffer_index <= 8'd0;
            word_count <= 8'd0;
            current_word_index <= 8'd0;
            current_char_index <= 8'd0;
            current_syllables <= 4'd0;
            syllable_state <= S_IDLE;
            vowel_flag <= 1'b0;
            qu_flag <= 1'b0;
            line1_words <= 4'd0;
            line2_words <= 4'd0;
            line3_words <= 4'd0;
            line1_syllables <= 4'd0;
            line2_syllables <= 4'd0;
            line3_syllables <= 4'd0;
            line_split_index <= 8'd0;
            backtrack_index <= 8'd0;
            temp_line1 <= 8'd0;
            temp_line2 <= 8'd0;
            temp_line3 <= 8'd0;
            output_valid <= 1'b0;
            output_invalid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize buffers
            integer i;
            for (i = 0; i < 200; i = i + 1) begin
                input_buffer[i] <= NULL_CHAR;
            end
            for (i = 0; i < 16; i = i + 1) begin
                word_start[i] <= 8'd0;
                word_end[i] <= 8'd0;
                syllable_count[i] <= 4'd0;
                output_line1[i] <= NULL_CHAR;
                output_line2[i] <= NULL_CHAR;
                output_line3[i] <= NULL_CHAR;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    output_valid <= 1'b0;
                    output_invalid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= READ_INPUT;
                        buffer_index <= 8'd0;
                        word_count <= 8'd0;
                    end
                end

                READ_INPUT: begin
                    if (char_valid) begin
                        input_buffer[buffer_index] <= char_in;
                        buffer_index <= buffer_index + 8'd1;
                    end
                    if (char_done) begin
                        state <= COUNT_SYLLABLES;
                        current_word_index <= 8'd0;
                        current_char_index <= 8'd0;
                        word_count <= 8'd0;
                        // Find word boundaries
                        integer i, j;
                        reg [7:0] word_start_temp;
                        reg [7:0] word_end_temp;
                        reg in_word;
                        in_word = 1'b0;
                        j = 8'd0;
                        for (i = 0; i < buffer_index; i = i + 1) begin
                            if (!in_word && input_buffer[i] != SPACE && !is_punctuation(input_buffer[i])) begin
                                word_start_temp = i;
                                in_word = 1'b1;
                            end
                            if (in_word && (input_buffer[i] == SPACE || is_punctuation(input_buffer[i]) || i == buffer_index - 1)) begin
                                word_end_temp = i;
                                if (input_buffer[i] == SPACE || is_punctuation(input_buffer[i])) begin
                                    word_end_temp = i - 8'd1;
                                end
                                word_start[j] <= word_start_temp;
                                word_end[j] <= word_end_temp;
                                j = j + 8'd1;
                                in_word = 1'b0;
                            end
                        end
                        word_count <= j;
                    end
                end

                COUNT_SYLLABLES: begin
                    if (current_word_index < word_count) begin
                        if (current_char_index == 8'd0) begin
                            current_syllables <= 4'd0;
                            syllable_state <= S_IDLE;
                            vowel_flag <= 1'b0;
                            qu_flag <= 1'b0;
                        end
                        if (current_char_index <= word_end[current_word_index] - word_start[current_word_index]) begin
                            reg [7:0] current_char;
                            current_char = input_buffer[word_start[current_word_index] + current_char_index];

                            // Syllable counting FSM
                            case (syllable_state)
                                S_IDLE: begin
                                    if (is_vowel(current_char)) begin
                                        syllable_state <= S_VOWEL;
                                        vowel_flag <= 1'b1;
                                        current_syllables <= current_syllables + 4'd1;
                                    end else if (is_consonant(current_char)) begin
                                        syllable_state <= S_CONSONANT;
                                        if (current_char == 8'd81) begin
                                            qu_flag <= 1'b1;
                                        end
                                    end
                                end

                                S_VOWEL: begin
                                    if (is_vowel(current_char)) begin
                                        if (current_char != 8'd89 || !vowel_flag) begin
                                            current_syllables <= current_syllables + 4'd1;
                                        end
                                        vowel_flag <= 1'b1;
                                    end else if (is_consonant(current_char)) begin
                                        syllable_state <= S_CONSONANT;
                                        vowel_flag <= 1'b0;
                                        if (current_char == 8'd81) begin
                                            qu_flag <= 1'b1;
                                        end
                                    end
                                end

                                S_CONSONANT: begin
                                    if (is_vowel(current_char)) begin
                                        syllable_state <= S_VOWEL;
                                        vowel_flag <= 1'b1;
                                        current_syllables <= current_syllables + 4'd1;
                                    end else if (is_consonant(current_char)) begin
                                        if (current_char == 8'd81 && !qu_flag) begin
                                            qu_flag <= 1'b1;
                                        end else begin
                                            qu_flag <= 1'b0;
                                        end
                                    end
                                end
                            endcase

                            // Handle silent E
                            if (current_char == 8'd69 && current_char_index == word_end[current_word_index] - word_start[current_word_index]) begin
                                if (current_char_index >= 8'd2) begin
                                    reg [7:0] prev_char1, prev_char2;
                                    prev_char1 = input_buffer[word_start[current_word_index] + current_char_index - 8'd1];
                                    prev_char2 = input_buffer[word_start[current_word_index] + current_char_index - 8'd2];
                                    if (!(prev_char1 == 8'd76 && is_consonant(prev_char2))) begin
                                        current_syllables <= current_syllables - 4'd1;
                                    end
                                end
                            end

                            // Handle ES ending
                            if (current_char_index >= 8'd1 && current_char == 8'd83 && input_buffer[word_start[current_word_index] + current_char_index - 8'd1] == 8'd69) begin
                                if (current_char_index >= 8'd2) begin
                                    reg [7:0] prev_char;
                                    prev_char = input_buffer[word_start[current_word_index] + current_char_index - 8'd2];
                                    if (!is_consonant(prev_char)) begin
                                        current_syllables <= current_syllables - 4'd1;
                                    end
                                end
                            end

                            current_char_index <= current_char_index + 8'd1;
                        end else begin
                            // Minimum 1 syllable per word
                            if (current_syllables == 4'd0) begin
                                current_syllables <= 4'd1;
                            end
                            syllable_count[current_word_index] <= current_syllables;
                            current_word_index <= current_word_index + 8'd1;
                            current_char_index <= 8'd0;
                        end
                    end else begin
                        state <= SPLIT_LINES;
                        line_split_index <= 8'd0;
                        backtrack_index <= 8'd0;
                        temp_line1 <= 8'd0;
                        temp_line2 <= 8'd0;
                        temp_line3 <= 8'd0;
                        line1_syllables <= 4'd0;
                        line2_syllables <= 4'd0;
                        line3_syllables <= 4'd0;
                    end
                end

                SPLIT_LINES: begin
                    if (line_split_index == 8'd0) begin
                        // Try to find 5/7/5 split
                        integer i, j, k;
                        reg found;
                        found = 1'b0;
                        for (i = 0; i < word_count - 2; i = i + 1) begin
                            line1_syllables = 4'd0;
                            for (j = 0; j <= i; j = j + 1) begin
                                line1_syllables = line1_syllables + syllable_count[j];
                            end
                            if (line1_syllables == 4'd5) begin
                                for (j = i + 1; j < word_count - 1; j = j + 1) begin
                                    line2_syllables = 4'd0;
                                    for (k = i + 1; k <= j; k = k + 1) begin
                                        line2_syllables = line2_syllables + syllable_count[k];
                                    end
                                    if (line2_syllables == 4'd7) begin
                                        line3_syllables = 4'd0;
                                        for (k = j + 1; k < word_count; k = k + 1) begin
                                            line3_syllables = line3_syllables + syllable_count[k];
                                        end
                                        if (line3_syllables == 4'd5) begin
                                            temp_line1 <= i + 8'd1;
                                            temp_line2 <= j - i;
                                            temp_line3 <= word_count - j - 8'd1;
                                            found = 1'b1;
                                            break;
                                        end
                                    end
                                end
                            end
                            if (found) begin
                                break;
                            end
                        end
                        if (found) begin
                            line1_words <= temp_line1;
                            line2_words <= temp_line2;
                            line3_words <= temp_line3;
                            output_valid <= 1'b1;
                            output_invalid <= 1'b0;
                        end else begin
                            output_valid <= 1'b0;
                            output_invalid <= 1'b1;
                        end
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Format output lines
                    integer i, j, k, pos;
                    reg [7:0] current_char;

                    // Line 1
                    pos = 8'd0;
                    for (i = 0; i < line1_words; i = i + 1) begin
                        for (j = word_start[i]; j <= word_end[i]; j = j + 1) begin
                            if (pos < 8'd16) begin
                                output_line1[pos] <= input_buffer[j];
                                pos = pos + 8'd1;
                            end
                        end
                        if (pos < 8'd16 && i < line1_words - 8'd1) begin
                            output_line1[pos] <= SPACE;
                            pos = pos + 8'd1;
                        end
                    end
                    output_line1_len <= line1_words;

                    // Line 2
                    pos = 8'd0;
                    for (i = line1_words; i < line1_words + line2_words; i = i + 1) begin
                        for (j = word_start[i]; j <= word_end[i]; j = j + 1) begin
                            if (pos < 8'd16) begin
                                output_line2[pos] <= input_buffer[j];
                                pos = pos + 8'd1;
                            end
                        end
                        if (pos < 8'd16 && i < line1_words + line2_words - 8'd1) begin
                            output_line2[pos] <= SPACE;
                            pos = pos + 8'd1;
                        end
                    end
                    output_line2_len <= line2_words;

                    // Line 3
                    pos = 8'd0;
                    for (i = line1_words + line2_words; i < word_count; i = i + 1) begin
                        for (j = word_start[i]; j <= word_end[i]; j = j + 1) begin
                            if (pos < 8'd16) begin
                                output_line3[pos] <= input_buffer[j];
                                pos = pos + 8'd1;
                            end
                        end
                        if (pos < 8'd16 && i < word_count - 8'd1) begin
                            output_line3[pos] <= SPACE;
                            pos = pos + 8'd1;
                        end
                    end
                    output_line3_len <= line3_words;

                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Cycle counter for timeout
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                state <= IDLE;
                done <= 1'b1;
            end
        end
    end

    // Output assignments
    assign line1[0] = output_line1[0];
    assign line1[1] = output_line1[1];
    assign line1[2] = output_line1[2];
    assign line1[3] = output_line1[3];
    assign line1[4] = output_line1[4];
    assign line1[5] = output_line1[5];
    assign line1[6] = output_line1[6];
    assign line1[7] = output_line1[7];
    assign line1[8] = output_line1[8];
    assign line1[9] = output_line1[9];
    assign line1[10] = output_line1[10];
    assign line1[11] = output_line1[11];
    assign line1[12] = output_line1[12];
    assign line1[13] = output_line1[13];
    assign line1[14] = output_line1[14];
    assign line1[15] = output_line1[15];

    assign line2[0] = output_line2[0];
    assign line2[1] = output_line2[1];
    assign line2[2] = output_line2[2];
    assign line2[3] = output_line2[3];
    assign line2[4] = output_line2[4];
    assign line2[5] = output_line2[5];
    assign line2[6] = output_line2[6];
    assign line2[7] = output_line2[7];
    assign line2[8] = output_line2[8];
    assign line2[9] = output_line2[9];
    assign line2[10] = output_line2[10];
    assign line2[11] = output_line2[11];
    assign line2[12] = output_line2[12];
    assign line2[13] = output_line2[13];
    assign line2[14] = output_line2[14];
    assign line2[15] = output_line2[15];

    assign line3[0] = output_line3[0];
    assign line3[1] = output_line3[1];
    assign line3[2] = output_line3[2];
    assign line3[3] = output_line3[3];
    assign line3[4] = output_line3[4];
    assign line3[5] = output_line3[5];
    assign line3[6] = output_line3[6];
    assign line3[7] = output_line3[7];
    assign line3[8] = output_line3[8];
    assign line3[9] = output_line3[9];
    assign line3[10] = output_line3[10];
    assign line3[11] = output_line3[11];
    assign line3[12] = output_line3[12];
    assign line3[13] = output_line3[13];
    assign line3[14] = output_line3[14];
    assign line3[15] = output_line3[15];

    assign line1_len = output_line1_len;
    assign line2_len = output_line2_len;
    assign line3_len = output_line3_len;
    assign valid = output_valid;
    assign invalid = output_invalid;

endmodule