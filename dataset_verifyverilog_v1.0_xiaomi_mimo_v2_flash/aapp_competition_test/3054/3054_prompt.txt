module HaikuFormer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] text_data [0:199],  // 200 character buffer
    input wire [7:0] text_length,         // 0-200 valid characters
    output reg [7:0] line1 [0:79],        // First line output (5 syllables)
    output reg [7:0] line2 [0:79],        // Second line output (7 syllables)
    output reg [7:0] line3 [0:79],        // Third line output (5 syllables)
    output reg valid,                     // 1 if haiku formed successfully
    output reg done                      // Processing complete
);

// Parameters
parameter MAX_WORDS = 10;        // Maximum number of words to process
parameter MAX_WORD_LEN = 20;     // Maximum characters per word
parameter SYLLABLE_WIDTH = 4;    // Bits for syllable count (0-15)

// State machine states
parameter STATE_IDLE = 3'b000;
parameter STATE_PARSE = 3'b001;  // Parse words from text
parameter STATE_COUNT = 3'b010;  // Count syllables per word
parameter STATE_SPLIT = 3'b011;  // Find valid haiku split points
parameter STATE_FORMAT = 3'b100; // Format output lines
parameter STATE_OUTPUT = 3'b101; // Output results

reg [2:0] state;
reg [2:0] next_state;

// Word storage (10 words × 20 characters)
reg [7:0] words [0:MAX_WORDS-1][0:MAX_WORD_LEN-1];
reg [4:0] word_lengths [0:MAX_WORDS-1];  // 0-20 characters per word
reg [SYLLABLE_WIDTH-1:0] syllable_counts [0:MAX_WORDS-1];
reg [3:0] num_words;  // 0-10 words

// Split indices
reg [3:0] split1_end;  // End index for first line (5 syllables)
reg [3:0] split2_end;  // End index for second line (7 syllables)

// Loop counters
reg [7:0] i, j, k;  // General purpose counters
reg [7:0] char_idx;  // Character index in text_data
reg [3:0] word_idx;  // Current word index

// Syllable counting variables
reg [7:0] char, next_char, prev_char;
reg is_vowel, is_next_vowel, is_prev_vowel;
reg [3:0] vowel_run_count;
reg [3:0] syllable_acc;  // Accumulator for current word
reg [4:0] char_pos;      // Position within word (0-19)

// Temporary storage for haiku lines
reg [7:0] temp_line1 [0:79];
reg [7:0] temp_line2 [0:79];
reg [7:0] temp_line3 [0:79];
reg [6:0] line1_idx, line2_idx, line3_idx;  // Index for each line

// Helper: Check if character is vowel
function automatic is_vowel_char(input [7:0] c);
    begin
        case (c)
            8'h41, 8'h61, // 'A', 'a'
            8'h45, 8'h65, // 'E', 'e'
            8'h49, 8'h69, // 'I', 'i'
            8'h4F, 8'h6F, // 'O', 'o'
            8'h55, 8'h75, // 'U', 'u'
            8'h59, 8'h79: // 'Y', 'y'
                is_vowel_char = 1'b1;
            default:
                is_vowel_char = 1'b0;
        endcase
    end
endfunction

// Helper: Check if two characters form "QU"
function automatic is_qu_pair(input [7:0] c1, input [7:0] c2);
    begin
        // Case-insensitive check
        is_qu_pair = ((c1 == 8'h51 || c1 == 8'h71) && 
                      (c2 == 8'h55 || c2 == 8'h75));
    end
endfunction

// Helper: Get character from text_data with bounds checking
function automatic [7:0] get_char(input [7:0] idx);
    begin
        if (idx < text_length)
            get_char = text_data[idx];
        else
            get_char = 8'h20;  // Space for out of bounds
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        num_words <= 4'd0;
        char_idx <= 8'd0;
        word_idx <= 4'd0;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        STATE_IDLE: begin
            if (start && text_length > 0)
                next_state = STATE_PARSE;
        end
        
        STATE_PARSE: begin
            if (char_idx >= text_length || num_words >= MAX_WORDS)
                next_state = STATE_COUNT;
        end
        
        STATE_COUNT: begin
            if (word_idx >= num_words)
                next_state = STATE_SPLIT;
        end
        
        STATE_SPLIT: begin
            if (valid || (split1_end >= num_words && split2_end >= num_words))
                next_state = STATE_FORMAT;
        end
        
        STATE_FORMAT: begin
            next_state = STATE_OUTPUT;
        end
        
        STATE_OUTPUT: begin
            next_state = STATE_IDLE;
        end
        
        default: next_state = STATE_IDLE;
    endcase
end

// Main processing logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        integer r, c;
        for (r = 0; r < MAX_WORDS; r = r + 1) begin
            word_lengths[r] <= 5'd0;
            syllable_counts[r] <= 4'd0;
            for (c = 0; c < MAX_WORD_LEN; c = c + 1) begin
                words[r][c] <= 8'h00;
            end
        end
        num_words <= 4'd0;
        char_idx <= 8'd0;
        word_idx <= 4'd0;
        split1_end <= 4'd0;
        split2_end <= 4'd0;
        done <= 1'b0;
        valid <= 1'b0;
        vowel_run_count <= 4'd0;
        syllable_acc <= 4'd0;
        char_pos <= 5'd0;
        line1_idx <= 7'd0;
        line2_idx <= 7'd0;
        line3_idx <= 7'd0;
    end else begin
        case (state)
            STATE_PARSE: begin
                if (char_idx < text_length && num_words < MAX_WORDS) begin
                    char = get_char(char_idx);
                    
                    // Check if alphabetic (A-Z or a-z)
                    if ((char >= 8'h41 && char <= 8'h5A) || 
                        (char >= 8'h61 && char <= 8'h7A)) begin
                        // Add to current word
                        if (word_lengths[num_words] < MAX_WORD_LEN) begin
                            words[num_words][word_lengths[num_words]] <= char;
                            word_lengths[num_words] <= word_lengths[num_words] + 1;
                        end
                    end else if (char == 8'h20 && word_lengths[num_words] > 0) begin
                        // Space ends current word
                        num_words <= num_words + 1;
                    end else if (word_lengths[num_words] > 0) begin
                        // Non-alphabetic, non-space character ends word
                        words[num_words][word_lengths[num_words]] <= char;
                        word_lengths[num_words] <= word_lengths[num_words] + 1;
                    end
                    
                    char_idx <= char_idx + 1;
                end
            end
            
            STATE_COUNT: begin
                if (word_idx < num_words) begin
                    // Initialize syllable counting for this word
                    if (char_pos == 0 && syllable_acc == 0) begin
                        vowel_run_count <= 4'd0;
                        syllable_acc <= 4'd0;
                    end
                    
                    if (char_pos < word_lengths[word_idx]) begin
                        char = words[word_idx][char_pos];
                        prev_char = (char_pos > 0) ? words[word_idx][char_pos-1] : 8'h00;
                        next_char = (char_pos < word_lengths[word_idx]-1) ? 
                                    words[word_idx][char_pos+1] : 8'h00;
                        
                        // Determine if current char is vowel for syllable counting
                        is_vowel = is_vowel_char(char);
                        is_next_vowel = is_vowel_char(next_char);
                        is_prev_vowel = is_vowel_char(prev_char);
                        
                        // Rule: QU is consonant
                        if (is_qu_pair(char, next_char)) begin
                            is_vowel = 1'b0;
                        end
                        
                        // Rule: Y is consonant if followed by vowel
                        if ((char == 8'h59 || char == 8'h79) && is_next_vowel) begin
                            is_vowel = 1'b0;
                        end
                        
                        // Count syllables: vowel runs separated by consonants
                        if (is_vowel) begin
                            if (vowel_run_count == 0) begin
                                // Start of new vowel run
                                syllable_acc <= syllable_acc + 1;
                            end
                            vowel_run_count <= vowel_run_count + 1;
                        end else begin
                            vowel_run_count <= 4'd0;
                        end
                        
                        char_pos <= char_pos + 1;
                    end else begin
                        // End of word: apply final rules
                        // Rule: Silent E (unless LE pattern)
                        if (word_lengths[word_idx] >= 2) begin
                            char = words[word_idx][word_lengths[word_idx]-1];
                            prev_char = words[word_idx][word_lengths[word_idx]-2];
                            
                            if (char == 8'h45 || char == 8'h65) begin // 'E' or 'e'
                                if (word_lengths[word_idx] >= 3) begin
                                    reg [7:0] prev_prev_char = words[word_idx][word_lengths[word_idx]-3];
                                    // Check for LE after consonant
                                    if ((prev_char == 8'h4C || prev_char == 8'h6C) && 
                                        !is_vowel_char(prev_prev_char) && 
                                        prev_prev_char != 8'h00) begin
                                        // Keep syllable
                                    end else begin
                                        // Silent E
                                        if (syllable_acc > 0)
                                            syllable_acc <= syllable_acc - 1;
                                    end
                                end else begin
                                    // Single E at end
                                    if (syllable_acc > 0)
                                        syllable_acc <= syllable_acc - 1;
                                end
                            end
                            
                            // Rule: ES ending (unless after 2+ consonants)
                            if (word_lengths[word_idx] >= 2) begin
                                char = words[word_idx][word_lengths[word_idx]-1];
                                prev_char = words[word_idx][word_lengths[word_idx]-2];
                                if ((char == 8'h53 || char == 8'h73) && 
                                    (prev_char == 8'h45 || prev_char == 8'h65)) begin
                                    // Check preceding consonant count
                                    reg [2:0] consonant_count = 0;
                                    for (k = 0; k < word_lengths[word_idx]-2; k = k + 1) begin
                                        reg [7:0] c = words[word_idx][k];
                                        if (!is_vowel_char(c)) consonant_count = consonant_count + 1;
                                        else consonant_count = 0;
                                    end
                                    if (consonant_count < 2 && syllable_acc > 0)
                                        syllable_acc <= syllable_acc - 1;
                                end
                            end
                        end
                        
                        // Every word has at least 1 syllable
                        if (syllable_acc == 0)
                            syllable_acc <= 1;
                        
                        // Store syllable count
                        syllable_counts[word_idx] <= syllable_acc;
                        
                        // Reset for next word
                        char_pos <= 5'd0;
                        syllable_acc <= 4'd0;
                        word_idx <= word_idx + 1;
                    end
                end
            end
            
            STATE_SPLIT: begin
                // Try to find valid split points for 5-7-5 pattern
                if (split1_end < num_words) begin
                    reg [4:0] syllables_5 = 0;
                    for (i = 0; i <= split1_end; i = i + 1) begin
                        syllables_5 = syllables_5 + syllable_counts[i];
                    end
                    
                    if (syllables_5 == 5) begin
                        // Try second line
                        if (split2_end < num_words && split2_end > split1_end) begin
                            reg [4:0] syllables_7 = 0;
                            for (j = split1_end + 1; j <= split2_end; j = j + 1) begin
                                syllables_7 = syllables_7 + syllable_counts[j];
                            end
                            
                            if (syllables_7 == 7) begin
                                // Try third line
                                reg [4:0] syllables_5_2 = 0;
                                for (k = split2_end + 1; k < num_words; k = k + 1) begin
                                    syllables_5_2 = syllables_5_2 + syllable_counts[k];
                                end
                                
                                if (syllables_5_2 == 5 && k == num_words) begin
                                    valid <= 1'b1;
                                end
                            end
                        end
                        split2_end <= split2_end + 1;
                    end
                    split1_end <= split1_end + 1;
                end
            end
            
            STATE_FORMAT: begin
                if (valid) begin
                    // Format the three lines from word buffers
                    line1_idx <= 7'd0;
                    line2_idx <= 7'd0;
                    line3_idx <= 7'd0;
                    
                    // Line 1: words 0 to split1_end
                    for (i = 0; i <= split1_end; i = i + 1) begin
                        for (j = 0; j < word_lengths[i]; j = j + 1) begin
                            temp_line1[line1_idx] <= words[i][j];
                            line1_idx <= line1_idx + 1;
                        end
                        if (i < split1_end) begin
                            temp_line1[line1_idx] <= 8'h20; // Space
                            line1_idx <= line1_idx + 1;
                        end
                    end
                    
                    // Line 2: words split1_end+1 to split2_end
                    for (i = split1_end + 1; i <= split2_end; i = i + 1) begin
                        for (j = 0; j < word_lengths[i]; j = j + 1) begin
                            temp_line2[line2_idx] <= words[i][j];
                            line2_idx <= line2_idx + 1;
                        end
                        if (i < split2_end) begin
                            temp_line2[line2_idx] <= 8'h20;
                            line2_idx <= line2_idx + 1;
                        end
                    end
                    
                    // Line 3: words split2_end+1 to end
                    for (i = split2_end + 1; i < num_words; i = i + 1) begin
                        for (j = 0; j < word_lengths[i]; j = j + 1) begin
                            temp_line3[line3_idx] <= words[i][j];
                            line3_idx <= line3_idx + 1;
                        end
                        if (i < num_words - 1) begin
                            temp_line3[line3_idx] <= 8'h20;
                            line3_idx <= line3_idx + 1;
                        end
                    end
                end
            end
            
            STATE_OUTPUT: begin
                if (valid) begin
                    // Copy formatted lines to output
                    for (i = 0; i < 80; i = i + 1) begin
                        line1[i] <= temp_line1[i];
                        line2[i] <= temp_line2[i];
                        line3[i] <= temp_line3[i];
                    end
                end else begin
                    // Output original line (all words concatenated with spaces)
                    reg [6:0] out_idx = 0;
                    for (i = 0; i < num_words; i = i + 1) begin
                        for (j = 0; j < word_lengths[i]; j = j + 1) begin
                            line1[out_idx] <= words[i][j];
                            line2[out_idx] <= 8'h00;  // Clear other lines
                            line3[out_idx] <= 8'h00;
                            out_idx = out_idx + 1;
                        end
                        if (i < num_words - 1) begin
                            line1[out_idx] <= 8'h20;
                            out_idx = out_idx + 1;
                        end
                    end
                    // Pad remaining
                    for (i = out_idx; i < 80; i = i + 1) begin
                        line1[i] <= 8'h00;
                        line2[i] <= 8'h00;
                        line3[i] <= 8'h00;
                    end
                end
                done <= 1'b1;
            end
        endcase
    end
end

endmodule