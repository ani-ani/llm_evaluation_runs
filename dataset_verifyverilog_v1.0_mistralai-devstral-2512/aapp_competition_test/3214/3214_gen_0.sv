module WordSimilarityFinder(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input line_end,
    output reg [3:0] result_word,
    output reg [3:0] result_pair,
    output reg result_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Input buffer (8KB = 8000 bits, 1000 bytes)
    reg [7:0] input_buffer [0:999];
    reg [9:0] buffer_wr_ptr;
    reg [9:0] buffer_rd_ptr;

    // Word table (16 entries, each 16 chars + valid flag)
    reg [7:0] word_table [0:15][0:15];
    reg word_valid [0:15];
    reg [3:0] word_count;

    // Current word being parsed
    reg [7:0] current_word [0:15];
    reg [3:0] current_word_len;

    // Comparison state
    reg [3:0] compare_i, compare_j;
    reg [3:0] output_i, output_j;

    // Cycle counter for timeout
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;

    // Edit distance check for distance = 1
    function automatic check_edit_distance;
        input [7:0] word_a [0:15];
        input [3:0] len_a;
        input [7:0] word_b [0:15];
        input [3:0] len_b;
        begin
            if (len_a == len_b) begin
                // Check for replace or transpose
                reg [3:0] diff_count;
                reg [3:0] transpose_count;
                integer k;

                diff_count = 0;
                transpose_count = 0;

                for (k = 0; k < len_a; k = k + 1) begin
                    if (word_a[k] != word_b[k]) begin
                        diff_count = diff_count + 1;
                        // Check for transpose with next character
                        if (k < len_a - 1 && word_a[k] == word_b[k + 1] && word_a[k + 1] == word_b[k]) begin
                            transpose_count = transpose_count + 1;
                            k = k + 1; // Skip next character
                        end
                    end
                end

                // Distance is 1 if either:
                // - Exactly one replace (diff_count == 1, transpose_count == 0)
                // - Exactly one transpose (transpose_count == 1, diff_count == 0)
                check_edit_distance = (diff_count == 1 && transpose_count == 0) || (transpose_count == 1 && diff_count == 0);
            end else if ((len_a == len_b + 1) || (len_b == len_a + 1)) begin
                // Check for insert/delete
                reg [3:0] diff_pos;
                reg [3:0] i, j;
                reg [3:0] max_len;

                max_len = (len_a > len_b) ? len_a : len_b;
                diff_pos = 0;

                for (i = 0, j = 0; i < max_len; i = i + 1, j = j + 1) begin
                    if (i < len_a && j < len_b && word_a[i] != word_b[j]) begin
                        diff_pos = diff_pos + 1;
                        if (len_a > len_b) begin
                            j = j - 1; // Skip in word_b (insert in word_a)
                        end else begin
                            i = i - 1; // Skip in word_a (delete in word_a)
                        end
                    end
                end

                check_edit_distance = (diff_pos == 1);
            end else begin
                check_edit_distance = 0;
            end
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            buffer_wr_ptr <= 10'd0;
            buffer_rd_ptr <= 10'd0;
            word_count <= 4'd0;
            current_word_len <= 4'd0;
            compare_i <= 4'd0;
            compare_j <= 4'd0;
            output_i <= 4'd0;
            output_j <= 4'd0;
            cycle_count <= 14'd0;
            result_valid <= 1'b0;
            done <= 1'b0;

            // Initialize word table
            integer k, m;
            for (k = 0; k < 16; k = k + 1) begin
                word_valid[k] <= 1'b0;
                for (m = 0; m < 16; m = m + 1) begin
                    word_table[k][m] <= 8'd0;
                end
            end

            // Initialize input buffer
            for (k = 0; k < 1000; k = k + 1) begin
                input_buffer[k] <= 8'd0;
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
                    next_state = PARSE;
                end
            end

            PARSE: begin
                if (line_end && buffer_wr_ptr > 10'd0) begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                if (compare_i == word_count - 1 && compare_j == word_count) begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                if (output_i == word_count - 1 && output_j == word_count) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Parsing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == PARSE) begin
            if (char_valid) begin
                // Store character in buffer
                input_buffer[buffer_wr_ptr] <= char_in;
                buffer_wr_ptr <= buffer_wr_ptr + 10'd1;

                // Process character
                if (char_in >= 8'd97 && char_in <= 8'd122) begin
                    // Lowercase letter
                    current_word[current_word_len] <= char_in;
                    current_word_len <= current_word_len + 4'd1;
                end else if (char_in >= 8'd48 && char_in <= 8'd57) begin
                    // Digit
                    current_word[current_word_len] <= char_in;
                    current_word_len <= current_word_len + 4'd1;
                end else begin
                    // Non-alphabetic: end of word
                    if (current_word_len > 4'd0) begin
                        // Check if word already exists in table
                        reg [3:0] k;
                        reg word_exists;
                        reg [3:0] empty_slot;

                        word_exists = 1'b0;
                        empty_slot = 4'd0;

                        for (k = 0; k < 16; k = k + 1) begin
                            if (word_valid[k]) begin
                                // Compare with existing word
                                reg [3:0] m;
                                reg match;

                                match = 1'b1;
                                if (current_word_len != word_table[k][0]) begin
                                    match = 1'b0;
                                end else begin
                                    for (m = 1; m <= current_word_len; m = m + 1) begin
                                        if (current_word[m - 1] != word_table[k][m]) begin
                                            match = 1'b0;
                                        end
                                    end
                                end

                                if (match) begin
                                    word_exists = 1'b1;
                                end
                            end else if (empty_slot == 4'd0) begin
                                empty_slot = k;
                            end
                        end

                        // Add to table if not exists and space available
                        if (!word_exists && word_count < 16) begin
                            word_table[empty_slot][0] <= current_word_len;
                            for (k = 1; k <= current_word_len; k = k + 1) begin
                                word_table[empty_slot][k] <= current_word[k - 1];
                            end
                            word_valid[empty_slot] <= 1'b1;
                            word_count <= word_count + 4'd1;
                        end

                        current_word_len <= 4'd0;
                    end
                end
            end
        end
    end

    // Comparison logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == COMPARE) begin
            if (compare_j < word_count) begin
                if (compare_i < compare_j) begin
                    // Check edit distance between word_table[compare_i] and word_table[compare_j]
                    if (check_edit_distance(word_table[compare_i], word_table[compare_i][0], 
                                           word_table[compare_j], word_table[compare_j][0])) begin
                        // Store similarity (implementation-specific)
                    end
                    compare_j <= compare_j + 4'd1;
                end else begin
                    compare_i <= compare_i + 4'd1;
                    compare_j <= 4'd0;
                end
            end else begin
                compare_i <= compare_i + 4'd1;
                compare_j <= 4'd0;
            end
        end
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == OUTPUT) begin
            result_valid <= 1'b0;

            if (output_j < word_count) begin
                if (output_i < output_j) begin
                    // Check if words are similar (implementation-specific)
                    // For now, assume we have a similarity matrix
                    if (/* similarity[output_i][output_j] */ 1'b1) begin
                        result_word <= output_i;
                        result_pair <= output_j;
                        result_valid <= 1'b1;
                    end
                    output_j <= output_j + 4'd1;
                end else begin
                    output_i <= output_i + 4'd1;
                    output_j <= 4'd0;
                end
            end else begin
                output_i <= output_i + 4'd1;
                output_j <= 4'd0;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            done <= (state == DONE_STATE);
        end
    end

    // Cycle counter for timeout
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 14'd0;
        end else begin
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 14'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    // Force completion to prevent timeout
                    if (state == PARSE) begin
                        next_state = COMPARE;
                    end else if (state == COMPARE) begin
                        next_state = OUTPUT;
                    end else if (state == OUTPUT) begin
                        next_state = DONE_STATE;
                    end
                end
            end
        end
    end

endmodule