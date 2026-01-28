module haiku_formatter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_done,
    output reg [7:0] line1 [0:15],
    output reg [7:0] line2 [0:15],
    output reg [7:0] line3 [0:15],
    output reg [3:0] line1_len,
    output reg [3:0] line2_len,
    output reg [3:0] line3_len,
    output reg valid,
    output reg invalid,
    output reg done
);

    // Internal storage for words
    reg [7:0] word_chars [0:15][0:15];  // 16 words, 16 chars each
    reg [3:0] word_lens [0:15];          // Length of each word
    reg [3:0] word_syllables [0:15];     // Syllable count per word
    reg [3:0] num_words;                 // Total word count
    reg [3:0] curr_word_idx;             // Current word being processed
    reg [3:0] curr_char_idx;             // Current char in word
    
    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] READ_CHARS     = 3'd1;
    localparam [2:0] COUNT_SYLLABLES = 3'd2;
    localparam [2:0] SPLIT_LINES    = 3'd3;
    localparam [2:0] FORMAT_OUTPUT  = 3'd4;
    localparam [2:0] FINISH         = 3'd5;
    
    // FSM state tracking
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // Word building state
    reg [7:0] prev_char;
    reg in_word;
    
    // Syllable counting variables
    reg [2:0] syllable_state;
    localparam [2:0] SYL_IDLE     = 3'd0;
    localparam [2:0] SYL_VOWEL    = 3'd1;
    localparam [2:0] SYL_CONSONANT = 3'd2;
    localparam [2:0] SYL_FOUND    = 3'd3;
    localparam [2:0] SYL_ES_CHECK = 3'd4;
    
    reg [3:0] char_pos;
    reg [3:0] curr_syllables;
    reg last_was_vowel;
    reg prev_is_consonant;  // For 'ES' rule
    reg found_syllable;
    reg silent_e_possible;
    reg l_consonant;        // Track if 'L' precedes final 'E'
    reg has_one_consonant;  // For 'ES' rule
    
    // Line splitting variables
    reg [2:0] split_state;
    localparam [2:0] SPLIT_IDLE    = 3'd0;
    localparam [2:0] SPLIT_LINE1   = 3'd1;
    localparam [2:0] SPLIT_LINE2   = 3'd2;
    localparam [2:0] SPLIT_LINE3   = 3'd3;
    localparam [2:0] SPLIT_CHECK   = 3'd4;
    localparam [2:0] SPLIT_BACKTRACK = 3'd5;
    localparam [2:0] SPLIT_VALID   = 3'd6;
    
    reg [3:0] line1_start, line1_end;
    reg [3:0] line2_start, line2_end;
    reg [3:0] line3_start, line3_end;
    reg [4:0] syll1_sum, syll2_sum, syll3_sum;
    reg [3:0] backtrack_idx;
    reg [3:0] temp_idx;
    reg valid_split;
    
    // Output formatting variables
    reg [3:0] out_line;
    reg [3:0] out_word;
    reg [3:0] out_char;
    reg [3:0] out_pos;  // Position in output array
    reg space_pending;
    
    // Helper function: Check if character is vowel
    function automatic is_vowel(input [7:0] c);
        reg result;
        begin
            result = 1'b0;
            if (c == 8'd65 || c == 8'd97) result = 1'b1;   // A/a
            else if (c == 8'd69 || c == 8'd101) result = 1'b1; // E/e
            else if (c == 8'd73 || c == 8'd105) result = 1'b1; // I/i
            else if (c == 8'd79 || c == 8'd111) result = 1'b1; // O/o
            else if (c == 8'd85 || c == 8'd117) result = 1'b1; // U/u
            else if (c == 8'd89 || c == 8'd121) result = 1'b1; // Y/y
            is_vowel = result;
        end
    endfunction
    
    // Helper function: Check if character is consonant (letters only)
    function automatic is_consonant(input [7:0] c);
        reg result;
        begin
            result = 1'b0;
            if ((c >= 8'd65 && c <= 8'd90) || (c >= 8'd97 && c <= 8'd122)) begin
                if (!is_vowel(c)) result = 1'b1;
            end
            is_consonant = result;
        end
    endfunction
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            invalid <= 1'b0;
            curr_word_idx <= 4'd0;
            curr_char_idx <= 4'd0;
            num_words <= 4'd0;
            in_word <= 1'b0;
            prev_char <= 8'd0;
            line1_len <= 4'd0;
            line2_len <= 4'd0;
            line3_len <= 4'd0;
            // Initialize all arrays
            begin : init_arrays
                integer i, j;
                for (i = 0; i < 16; i = i + 1) begin
                    word_lens[i] <= 4'd0;
                    word_syllables[i] <= 4'd0;
                    for (j = 0; j < 16; j = j + 1) begin
                        word_chars[i][j] <= 8'd0;
                    end
                end
                for (i = 0; i < 16; i = i + 1) begin
                    line1[i] <= 8'd0;
                    line2[i] <= 8'd0;
                    line3[i] <= 8'd0;
                end
            end
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    invalid <= 1'b0;
                    cycle_count <= 8'd0;
                    curr_word_idx <= 4'd0;
                    curr_char_idx <= 4'd0;
                    num_words <= 4'd0;
                    in_word <= 1'b0;
                    prev_char <= 8'd0;
                    line1_len <= 4'd0;
                    line2_len <= 4'd0;
                    line3_len <= 4'd0;
                    if (start) begin
                        state <= READ_CHARS;
                        begin : clear_arrays
                            integer i, j;
                            for (i = 0; i < 16; i = i + 1) begin
                                word_lens[i] <= 4'd0;
                                word_syllables[i] <= 4'd0;
                                for (j = 0; j < 16; j = j + 1) begin
                                    word_chars[i][j] <= 8'd0;
                                end
                            end
                            for (i = 0; i < 16; i = i + 1) begin
                                line1[i] <= 8'd0;
                                line2[i] <= 8'd0;
                                line3[i] <= 8'd0;
                            end
                        end
                    end
                end
                
                READ_CHARS: begin
                    if (char_valid && curr_word_idx < 4'd16) begin
                        // Filter out non-alphabetic characters except space and punctuation
                        if (char_in >= 8'd65 && char_in <= 8'd90) begin
                            // Uppercase - convert to lowercase for consistency
                            if (in_word) begin
                                if (curr_char_idx < 4'd16) begin
                                    word_chars[curr_word_idx][curr_char_idx] <= char_in + 8'd32;
                                    curr_char_idx <= curr_char_idx + 4'd1;
                                end
                            end
                        end else if (char_in >= 8'd97 && char_in <= 8'd122) begin
                            // Lowercase
                            if (in_word) begin
                                if (curr_char_idx < 4'd16) begin
                                    word_chars[curr_word_idx][curr_char_idx] <= char_in;
                                    curr_char_idx <= curr_char_idx + 4'd1;
                                end
                            end
                        end else if (char_in == 8'd32) begin
                            // Space - end word
                            if (in_word) begin
                                word_lens[curr_word_idx] <= curr_char_idx;
                                num_words <= curr_word_idx + 4'd1;
                                curr_word_idx <= curr_word_idx + 4'd1;
                                curr_char_idx <= 4'd0;
                                in_word <= 1'b0;
                            end
                        end
                        prev_char <= char_in;
                    end
                    
                    if (char_done) begin
                        // Handle final word
                        if (in_word && curr_char_idx > 4'd0) begin
                            word_lens[curr_word_idx] <= curr_char_idx;
                            num_words <= curr_word_idx + 4'd1;
                        end
                        if (num_words > 4'd0) begin
                            state <= COUNT_SYLLABLES;
                            curr_word_idx <= 4'd0;
                        end else begin
                            state <= FINISH;
                            invalid <= 1'b1;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        invalid <= 1'b1;
                    end
                end
                
                COUNT_SYLLABLES: begin
                    if (curr_word_idx < num_words) begin
                        // Process current word for syllables
                        case (syllable_state)
                            SYL_IDLE: begin
                                curr_syllables <= 4'd0;
                                char_pos <= 4'd0;
                                last_was_vowel <= 1'b0;
                                prev_is_consonant <= 1'b0;
                                found_syllable <= 1'b0;
                                silent_e_possible <= 1'b0;
                                l_consonant <= 1'b0;
                                has_one_consonant <= 1'b0;
                                syllable_state <= SYL_VOWEL;
                            end
                            
                            SYL_VOWEL: begin
                                if (char_pos < word_lens[curr_word_idx]) begin
                                    if (is_vowel(word_chars[curr_word_idx][char_pos])) begin
                                        // Handle 'Y' as vowel condition
                                        if (word_chars[curr_word_idx][char_pos] == 8'd121 || 
                                            word_chars[curr_word_idx][char_pos] == 8'd89) begin
                                            // Y is vowel only if not preceded by vowel
                                            if (!last_was_vowel) begin
                                                found_syllable <= 1'b1;
                                            end
                                        end else begin
                                            found_syllable <= 1'b1;
                                        end
                                        last_was_vowel <= 1'b1;
                                        prev_is_consonant <= 1'b0;
                                    end else if (is_consonant(word_chars[curr_word_idx][char_pos])) begin
                                        // Check for 'qu' pattern
                                        if (word_chars[curr_word_idx][char_pos] == 8'd113 && 
                                            char_pos > 0 && 
                                            (word_chars[curr_word_idx][char_pos-1] == 8'd117)) begin
                                            // 'qu' - count as one consonant, skip
                                        end else begin
                                            // Check if this is 'l' before final 'e'
                                            if (word_chars[curr_word_idx][char_pos] == 8'd108 && 
                                                char_pos == word_lens[curr_word_idx] - 3'd2) begin
                                                l_consonant <= 1'b1;
                                            end
                                            // Track consonants for 'ES' rule
                                            if (word_chars[curr_word_idx][char_pos] != 8'd115) begin
                                                has_one_consonant <= 1'b1;
                                            end
                                            prev_is_consonant <= 1'b1;
                                        end
                                        last_was_vowel <= 1'b0;
                                    end
                                    char_pos <= char_pos + 4'd1;
                                    if (found_syllable) begin
                                        curr_syllables <= curr_syllables + 4'd1;
                                        found_syllable <= 1'b0;
                                    end
                                end else begin
                                    // End of word
                                    // Check for silent 'e'
                                    if (word_lens[curr_word_idx] >= 3'd2) begin
                                        if (word_chars[curr_word_idx][word_lens[curr_word_idx]-4'd1] == 8'd101) begin
                                            // Check if preceded by consonant
                                            if (word_lens[curr_word_idx] >= 4'd2) begin
                                                if (is_consonant(word_chars[curr_word_idx][word_lens[curr_word_idx]-4'd2])) begin
                                                    // Check if 'l' was not the only consonant
                                                    if (!(l_consonant && !has_one_consonant)) begin
                                                        // Not silent 'e'
                                                        // Keep syllable
                                                    end else begin
                                                        // Silent 'e' - remove syllable
                                                        if (curr_syllables > 4'd0) begin
                                                            curr_syllables <= curr_syllables - 4'd1;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        // Check for 'es' ending
                                        if (word_lens[curr_word_idx] >= 4'd2) begin
                                            if (word_chars[curr_word_idx][word_lens[curr_word_idx]-4'd1] == 8'd115 &&
                                                word_chars[curr_word_idx][word_lens[curr_word_idx]-4'd2] == 8'd101) begin
                                                // 'es' ending - check consonant count
                                                if (has_one_consonant) begin
                                                    // One or fewer consonants - no syllable
                                                    if (curr_syllables > 4'd0) begin
                                                        curr_syllables <= curr_syllables - 4'd1;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                    
                                    // Minimum 1 syllable
                                    if (curr_syllables == 4'd0) begin
                                        curr_syllables <= 4'd1;
                                    end
                                    
                                    word_syllables[curr_word_idx] <= curr_syllables;
                                    curr_word_idx <= curr_word_idx + 4'd1;
                                    syllable_state <= SYL_IDLE;
                                end
                            end
                            
                            default: syllable_state <= SYL_IDLE;
                        endcase
                    end else begin
                        state <= SPLIT_LINES;
                        curr_word_idx <= 4'd0;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        invalid <= 1'b1;
                    end
                end
                
                SPLIT_LINES: begin
                    case (split_state)
                        SPLIT_IDLE: begin
                            line1_start <= 4'd0;
                            line1_end <= 4'd0;
                            line2_start <= 4'd0;
                            line2_end <= 4'd0;
                            line3_start <= 4'd0;
                            line3_end <= 4'd0;
                            syll1_sum <= 5'd0;
                            syll2_sum <= 5'd0;
                            syll3_sum <= 5'd0;
                            backtrack_idx <= 4'd0;
                            valid_split <= 1'b0;
                            split_state <= SPLIT_LINE1;
                        end
                        
                        SPLIT_LINE1: begin
                            if (curr_word_idx < num_words) begin
                                if (syll1_sum + word_syllables[curr_word_idx] <= 5'd5) begin
                                    syll1_sum <= syll1_sum + word_syllables[curr_word_idx];
                                    curr_word_idx <= curr_word_idx + 4'd1;
                                end else begin
                                    line1_end <= curr_word_idx;
                                    line1_len <= curr_word_idx - line1_start;
                                    split_state <= SPLIT_LINE2;
                                end
                            end else begin
                                line1_end <= curr_word_idx;
                                line1_len <= curr_word_idx - line1_start;
                                split_state <= SPLIT_LINE2;
                            end
                        end
                        
                        SPLIT_LINE2: begin
                            if (curr_word_idx < num_words) begin
                                if (syll2_sum + word_syllables[curr_word_idx] <= 5'd7) begin
                                    syll2_sum <= syll2_sum + word_syllables[curr_word_idx];
                                    curr_word_idx <= curr_word_idx + 4'd1;
                                end else begin
                                    line2_start <= line1_end;
                                    line2_end <= curr_word_idx;
                                    line2_len <= curr_word_idx - line1_end;
                                    split_state <= SPLIT_LINE3;
                                end
                            end else begin
                                line2_start <= line1_end;
                                line2_end <= curr_word_idx;
                                line2_len <= curr_word_idx - line1_end;
                                split_state <= SPLIT_LINE3;
                            end
                        end
                        
                        SPLIT_LINE3: begin
                            if (curr_word_idx < num_words) begin
                                if (syll3_sum + word_syllables[curr_word_idx] <= 5'd5) begin
                                    syll3_sum <= syll3_sum + word_syllables[curr_word_idx];
                                    curr_word_idx <= curr_word_idx + 4'd1;
                                end else begin
                                    line3_start <= line2_end;
                                    line3_end <= curr_word_idx;
                                    line3_len <= curr_word_idx - line2_end;
                                    split_state <= SPLIT_CHECK;
                                end
                            end else begin
                                line3_start <= line2_end;
                                line3_end <= curr_word_idx;
                                line3_len <= curr_word_idx - line2_end;
                                split_state <= SPLIT_CHECK;
                            end
                        end
                        
                        SPLIT_CHECK: begin
                            // Check if exact match (5/7/5) and all words used
                            if (syll1_sum == 5'd5 && syll2_sum == 5'd7 && syll3_sum == 5'd5 && 
                                curr_word_idx == num_words) begin
                                valid_split <= 1'b1;
                                split_state <= SPLIT_VALID;
                            end else if (curr_word_idx < num_words) begin
                                // Extra words remain - try to extend line 3
                                if (syll3_sum + word_syllables[curr_word_idx] <= 5'd5) begin
                                    syll3_sum <= syll3_sum + word_syllables[curr_word_idx];
                                    line3_end <= curr_word_idx + 4'd1;
                                    line3_len <= curr_word_idx - line2_end + 4'd1;
                                    curr_word_idx <= curr_word_idx + 4'd1;
                                end else begin
                                    // Cannot fit - backtrack
                                    split_state <= SPLIT_BACKTRACK;
                                    backtrack_idx <= line1_end - 4'd1;
                                end
                            end else begin
                                // All words used but syllables don't match
                                if (syll3_sum != 5'd5) begin
                                    split_state <= SPLIT_BACKTRACK;
                                    backtrack_idx <= line1_end - 4'd1;
                                end else begin
                                    valid_split <= 1'b1;
                                    split_state <= SPLIT_VALID;
                                end
                            end
                        end
                        
                        SPLIT_BACKTRACK: begin
                            // Try to find better split by adjusting boundaries
                            if (backtrack_idx >= line1_start && backtrack_idx > 0) begin
                                // Recalculate line1
                                syll1_sum <= 5'd0;
                                temp_idx <= line1_start;
                                while (temp_idx < backtrack_idx) begin
                                    syll1_sum <= syll1_sum + word_syllables[temp_idx];
                                    temp_idx <= temp_idx + 4'd1;
                                end
                                line1_end <= backtrack_idx;
                                line1_len <= backtrack_idx - line1_start;
                                
                                // Recalculate line2 starting from backtrack_idx
                                syll2_sum <= 5'd0;
                                temp_idx <= backtrack_idx;
                                while (temp_idx < num_words && syll2_sum + word_syllables[temp_idx] <= 5'd7) begin
                                    syll2_sum <= syll2_sum + word_syllables[temp_idx];
                                    temp_idx <= temp_idx + 4'd1;
                                end
                                line2_start <= backtrack_idx;
                                line2_end <= temp_idx;
                                line2_len <= temp_idx - backtrack_idx;
                                
                                // Recalculate line3
                                syll3_sum <= 5'd0;
                                temp_idx <= line2_end;
                                while (temp_idx < num_words && syll3_sum + word_syllables[temp_idx] <= 5'd5) begin
                                    syll3_sum <= syll3_sum + word_syllables[temp_idx];
                                    temp_idx <= temp_idx + 4'd1;
                                end
                                line3_start <= line2_end;
                                line3_end <= temp_idx;
                                line3_len <= temp_idx - line2_end;
                                
                                curr_word_idx <= temp_idx;
                                split_state <= SPLIT_CHECK;
                            end else begin
                                valid_split <= 1'b0;
                                split_state <= SPLIT_VALID;
                            end
                        end
                        
                        SPLIT_VALID: begin
                            if (valid_split) begin
                                state <= FORMAT_OUTPUT;
                            end else begin
                                state <= FINISH;
                                invalid <= 1'b1;
                            end
                        end
                        
                        default: split_state <= SPLIT_IDLE;
                    endcase
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        invalid <= 1'b1;
                    end
                end
                
                FORMAT_OUTPUT: begin
                    // Build line1
                    if (out_line == 3'd0) begin
                        if (out_word < line1_len) begin
                            if (out_char < word_lens[line1_start + out_word]) begin
                                line1[out_pos] <= word_chars[line1_start + out_word][out_char];
                                out_char <= out_char + 4'd1;
                                out_pos <= out_pos + 4'd1;
                            end else begin
                                // Word done - add space if not last word
                                if (out_word < line1_len - 4'd1) begin
                                    line1[out_pos] <= 8'd32;  // Space
                                    out_pos <= out_pos + 4'd1;
                                end
                                out_char <= 4'd0;
                                out_word <= out_word + 4'd1;
                            end
                        end else begin
                            // Fill rest with spaces
                            if (out_pos < 4'd16) begin
                                line1[out_pos] <= 8'd32;
                                out_pos <= out_pos + 4'd1;
                            end else begin
                                out_line <= 3'd1;
                                out_word <= 4'd0;
                                out_char <= 4'd0;
                                out_pos <= 4'd0;
                            end
                        end
                    end
                    // Build line2
                    else if (out_line == 3'd1) begin
                        if (out_word < line2_len) begin
                            if (out_char < word_lens[line2_start + out_word]) begin
                                line2[out_pos] <= word_chars[line2_start + out_word][out_char];
                                out_char <= out_char + 4'd1;
                                out_pos <= out_pos + 4'd1;
                            end else begin
                                if (out_word < line2_len - 4'd1) begin
                                    line2[out_pos] <= 8'd32;
                                    out_pos <= out_pos + 4'd1;
                                end
                                out_char <= 4'd0;
                                out_word <= out_word + 4'd1;
                            end
                        end else begin
                            if (out_pos < 4'd16) begin
                                line2[out_pos] <= 8'd32;
                                out_pos <= out_pos + 4'd1;
                            end else begin
                                out_line <= 3'd2;
                                out_word <= 4'd0;
                                out_char <= 4'd0;
                                out_pos <= 4'd0;
                            end
                        end
                    end
                    // Build line3
                    else if (out_line == 3'd2) begin
                        if (out_word < line3_len) begin
                            if (out_char < word_lens[line3_start + out_word]) begin
                                line3[out_pos] <= word_chars[line3_start + out_word][out_char];
                                out_char <= out_char + 4'd1;
                                out_pos <= out_pos + 4'd1;
                            end else begin
                                if (out_word < line3_len - 4'd1) begin
                                    line3[out_pos] <= 8'd32;
                                    out_pos <= out_pos + 4'd1;
                                end
                                out_char <= 4'd0;
                                out_word <= out_word + 4'd1;
                            end
                        end else begin
                            if (out_pos < 4'd16) begin
                                line3[out_pos] <= 8'd32;
                                out_pos <= out_pos + 4'd1;
                            end else begin
                                state <= FINISH;
                                valid <= 1'b1;
                            end
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
    
    // Combinational logic for resetting output
    always @(*) begin
        if (state == IDLE && start) begin
            line1_len = 4'd0;
            line2_len = 4'd0;
            line3_len = 4'd0;
        end
    end
    
    // Initialize FSM variables for FORMAT_OUTPUT
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_line <= 3'd0;
            out_word <= 4'd0;
            out_char <= 4'd0;
            out_pos <= 4'd0;
        end else if (state == SPLIT_LINES && split_state == SPLIT_VALID && valid_split) begin
            out_line <= 3'd0;
            out_word <= 4'd0;
            out_char <= 4'd0;
            out_pos <= 4'd0;
        end
    end
    
endmodule