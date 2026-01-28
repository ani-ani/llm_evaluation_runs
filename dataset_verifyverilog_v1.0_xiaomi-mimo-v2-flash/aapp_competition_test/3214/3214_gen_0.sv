module SimilarWordFinder(
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

// Memory declarations
// Word table: 16 entries, each 16 chars (16*8=128 bits) + valid flag
reg [127:0] word_table [0:15];  // Packed 16-char ASCII string
reg [0:0]   word_valid [0:15];   // Valid flag per entry
reg [3:0]   word_count;          // Number of words stored (0-16)

// Input buffer: 8KB (8000 bits) - 1000 bytes
reg [7:0]   input_buffer [0:999];
reg [13:0]  buf_write_ptr;        // Up to 1000 (10 bits) but use 14 for safety

// FSM states
localparam [2:0] S_IDLE      = 3'd0;
localparam [2:0] S_PARSE     = 3'd1;
localparam [2:0] S_COMPARE   = 3'd2;
localparam [2:0] S_OUTPUT    = 3'd3;
localparam [2:0] S_DONE      = 3'd4;

reg [2:0] state, next_state;

// Parsing state
reg [15:0] parse_index;          // Current position in input buffer
reg [31:0] word_accum;           // Temporary word accumulator (up to 4 chars for core)
reg [2:0]  word_len;             // Current length of word accumulator
reg        in_word;              // Currently building a word
reg [15:0] unique_check_idx;     // For checking duplicates

// Comparison state
reg [3:0]  comp_i;               // First word index (0 to 14)
reg [3:0]  comp_j;               // Second word index (i+1 to 15)
reg [3:0]  output_j_index;       // Index in output list
reg [15:0] similar_pairs [0:15]; // Bitmask of similar indices for word i
reg [3:0]  similar_count;        // Number of similar pairs for current i
reg [3:0]  output_index;         // Current output pair index

// Cycle counter for timeout
reg [15:0] cycle_counter;
localparam [15:0] MAX_CYCLES = 16'd10000;

// Helper signals for edit distance
reg [7:0]  char1, char2;
reg [3:0]  len1, len2;
reg        edit_distance_1;
reg [7:0]  temp_char1, temp_char2;
reg [7:0]  temp_char3, temp_char4;

// Function to convert ASCII to lowercase (alphanumeric only)
function automatic [7:0] to_lowercase(input [7:0] c);
    begin
        if (c >= 65 && c <= 90) begin
            to_lowercase = c + 32;
        end else if ((c >= 48 && c <= 57) || (c >= 97 && c <= 122)) begin
            to_lowercase = c;
        end else begin
            to_lowercase = 8'd0;  // Invalid character
        end
    end
endfunction

// Function to check if two words are at edit distance 1
function automatic [0:0] is_edit_distance_one(
    input [127:0] w1,
    input [127:0] w2,
    input [3:0]   len1,
    input [3:0]   len2
);
    reg [3:0] i;
    reg [3:0] diff_count;
    reg [7:0] c1, c2;
    begin
        // Extract characters for comparison
        // Get first differing characters
        diff_count = 0;
        is_edit_distance_one = 1'b0;
        
        // Check length difference
        if (len1 == len2) begin
            // Could be replace or transpose
            diff_count = 0;
            for (i = 0; i < len1; i = i + 1) begin
                c1 = w1[(i*8)+:8];
                c2 = w2[(i*8)+:8];
                if (c1 != c2) begin
                    diff_count = diff_count + 1;
                end
            end
            if (diff_count == 0) begin
                is_edit_distance_one = 1'b0;  // Same word
            end else if (diff_count == 1) begin
                is_edit_distance_one = 1'b1;  // Replace
            end else if (diff_count == 2) begin
                // Check for transpose: exactly one swap of adjacent chars
                for (i = 0; i < len1 - 1; i = i + 1) begin
                    c1 = w1[(i*8)+:8];
                    c2 = w1[((i+1)*8)+:8];
                    temp_char1 = w2[(i*8)+:8];
                    temp_char2 = w2[((i+1)*8)+:8];
                    if ((c1 == temp_char2) && (c2 == temp_char1)) begin
                        // Check all other chars match
                        reg [0:0] all_match;
                        all_match = 1'b1;
                        for (int k = 0; k < len1; k = k + 1) begin
                            if (k != i && k != i+1) begin
                                if (w1[(k*8)+:8] != w2[(k*8)+:8]) begin
                                    all_match = 1'b0;
                                end
                            end
                        end
                        if (all_match) begin
                            is_edit_distance_one = 1'b1;
                            break;
                        end
                    end
                end
            end
        end else if (len1 + 1 == len2) begin
            // Delete from w1 (insert in w2)
            // Check if removing one char from w1 makes it equal to w2
            for (int k = 0; k < len1; k = k + 1) begin
                reg [0:0] match_after_skip;
                match_after_skip = 1'b1;
                for (int m = 0; m < len1; m = m + 1) begin
                    temp_char1 = w1[(m*8)+:8];
                    if (m < k) begin
                        temp_char2 = w2[(m*8)+:8];
                    end else begin
                        temp_char2 = w2[((m+1)*8)+:8];
                    end
                    if (temp_char1 != temp_char2) begin
                        match_after_skip = 1'b0;
                    end
                end
                if (match_after_skip) begin
                    is_edit_distance_one = 1'b1;
                    break;
                end
            end
        end else if (len1 == len2 + 1) begin
            // Insert to w1 (delete from w2)
            // Check if removing one char from w2 makes it equal to w1
            for (int k = 0; k < len2; k = k + 1) begin
                reg [0:0] match_after_skip;
                match_after_skip = 1'b1;
                for (int m = 0; m < len2; m = m + 1) begin
                    temp_char2 = w2[(m*8)+:8];
                    if (m < k) begin
                        temp_char1 = w1[(m*8)+:8];
                    end else begin
                        temp_char1 = w1[((m+1)*8)+:8];
                    end
                    if (temp_char1 != temp_char2) begin
                        match_after_skip = 1'b0;
                    end
                end
                if (match_after_skip) begin
                    is_edit_distance_one = 1'b1;
                    break;
                end
            end
        end
    end
endfunction

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= S_IDLE;
        result_word <= 4'd0;
        result_pair <= 4'd0;
        result_valid <= 1'b0;
        done <= 1'b0;
        
        // Reset memory pointers
        word_count <= 4'd0;
        buf_write_ptr <= 14'd0;
        parse_index <= 16'd0;
        word_accum <= 32'd0;
        word_len <= 3'd0;
        in_word <= 1'b0;
        unique_check_idx <= 4'd0;
        
        comp_i <= 4'd0;
        comp_j <= 4'd0;
        output_j_index <= 4'd0;
        similar_count <= 4'd0;
        output_index <= 4'd0;
        cycle_counter <= 16'd0;
        
        // Reset arrays (using loops)
        for (int i = 0; i < 16; i = i + 1) begin
            word_table[i] <= 128'd0;
            word_valid[i] <= 1'b0;
            similar_pairs[i] <= 16'd0;
        end
        
    end else begin
        case (state)
            S_IDLE: begin
                result_valid <= 1'b0;
                done <= 1'b0;
                cycle_counter <= 16'd0;
                if (start) begin
                    state <= S_PARSE;
                    buf_write_ptr <= 14'd0;
                    parse_index <= 16'd0;
                    word_count <= 4'd0;
                    in_word <= 1'b0;
                    word_len <= 3'd0;
                    word_accum <= 32'd0;
                end
            end
            
            S_PARSE: begin
                // Check timeout
                cycle_counter <= cycle_counter + 16'd1;
                
                if (cycle_counter >= MAX_CYCLES) begin
                    state <= S_COMPARE;
                    in_word <= 1'b0;
                    word_len <= 3'd0;
                end else if (char_valid) begin
                    // Store character in buffer if space
                    if (buf_write_ptr < 14'd1000) begin
                        input_buffer[buf_write_ptr] <= char_in;
                        buf_write_ptr <= buf_write_ptr + 14'd1;
                    end
                    
                    // Process character for word extraction
                    reg [7:0] lc;
                    lc = to_lowercase(char_in);
                    
                    if (lc != 8'd0) begin
                        // Valid alphanumeric
                        if (in_word && word_len < 3'd4) begin
                            // Accumulate word (max 4 chars for core)
                            word_accum <= {word_accum[23:0], lc};
                            word_len <= word_len + 3'd1;
                        end else if (!in_word) begin
                            // Start new word
                            word_accum <= {24'd0, lc};
                            word_len <= 3'd1;
                            in_word <= 1'b1;
                        end
                    end else begin
                        // Non-alphabetic - finalize word if any
                        if (in_word) begin
                            in_word <= 1'b0;
                            // Check if word is unique and store
                            if (word_count < 4'd16 && word_len > 3'd0) begin
                                // Check for duplicate (simplified - check exact match)
                                reg [0:0] is_duplicate;
                                is_duplicate = 1'b0;
                                for (int k = 0; k < word_count; k = k + 1) begin
                                    if (word_table[k][(word_len*8)-1:0] == word_accum[(word_len*8)-1:0]) begin
                                        is_duplicate = 1'b1;
                                    end
                                end
                                if (!is_duplicate) begin
                                    word_table[word_count] <= word_accum;
                                    word_valid[word_count] <= 1'b1;
                                    word_count <= word_count + 4'd1;
                                end
                            end
                            word_len <= 3'd0;
                        end
                    end
                end else if (line_end) begin
                    // Line end - finalize any pending word
                    if (in_word) begin
                        in_word <= 1'b0;
                        if (word_count < 4'd16 && word_len > 3'd0) begin
                            reg [0:0] is_duplicate;
                            is_duplicate = 1'b0;
                            for (int k = 0; k < word_count; k = k + 1) begin
                                if (word_table[k][(word_len*8)-1:0] == word_accum[(word_len*8)-1:0]) begin
                                    is_duplicate = 1'b1;
                                end
                            end
                            if (!is_duplicate) begin
                                word_table[word_count] <= word_accum;
                                word_valid[word_count] <= 1'b1;
                                word_count <= word_count + 4'd1;
                            end
                        end
                        word_len <= 3'd0;
                    end
                end else if (!char_valid && !line_end && parse_index >= buf_write_ptr) begin
                    // No more input
                    // Finalize any pending word
                    if (in_word) begin
                        in_word <= 1'b0;
                        if (word_count < 4'd16 && word_len > 3'd0) begin
                            reg [0:0] is_duplicate;
                            is_duplicate = 1'b0;
                            for (int k = 0; k < word_count; k = k + 1) begin
                                if (word_table[k][(word_len*8)-1:0] == word_accum[(word_len*8)-1:0]) begin
                                    is_duplicate = 1'b1;
                                end
                            end
                            if (!is_duplicate) begin
                                word_table[word_count] <= word_accum;
                                word_valid[word_count] <= 1'b1;
                                word_count <= word_count + 4'd1;
                            end
                        end
                        word_len <= 3'd0;
                    end
                    // Move to comparison
                    state <= S_COMPARE;
                    comp_i <= 4'd0;
                    comp_j <= 4'd0;
                    cycle_counter <= 16'd0;
                end
            end
            
            S_COMPARE: begin
                cycle_counter <= cycle_counter + 16'd1;
                
                if (cycle_counter >= MAX_CYCLES) begin
                    state <= S_OUTPUT;
                    output_index <= 4'd0;
                end else if (comp_i < word_count) begin
                    if (comp_j < word_count && comp_i != comp_j) begin
                        // Compare word_i with word_j
                        if (word_valid[comp_i] && word_valid[comp_j]) begin
                            reg [0:0] is_similar;
                            // Calculate effective length
                            len1 = (word_len_from_table(word_table[comp_i]) > 4'd16) ? 4'd16 : word_len_from_table(word_table[comp_i]);
                            len2 = (word_len_from_table(word_table[comp_j]) > 4'd16) ? 4'd16 : word_len_from_table(word_table[comp_j]);
                            
                            is_similar = is_edit_distance_one(
                                word_table[comp_i],
                                word_table[comp_j],
                                len1,
                                len2
                            );
                            
                            if (is_similar) begin
                                similar_pairs[comp_i] <= similar_pairs[comp_i] | (16'd1 << comp_j);
                            end
                        end
                        comp_j <= comp_j + 4'd1;
                    end else begin
                        comp_j <= 4'd0;
                        comp_i <= comp_i + 4'd1;
                    end
                end else begin
                    state <= S_OUTPUT;
                    output_index <= 4'd0;
                end
            end
            
            S_OUTPUT: begin
                cycle_counter <= cycle_counter + 16'd1;
                
                if (cycle_counter >= MAX_CYCLES) begin
                    state <= S_DONE;
                    done <= 1'b1;
                end else if (output_index < word_count) begin
                    // Find next similar pair for current word
                    reg [3:0] j;
                    reg [0:0] found;
                    found = 1'b0;
                    j = output_j_index;
                    
                    // Simple loop to find next similar
                    if (similar_pairs[output_index][j] && j > output_index) begin
                        result_word <= output_index;
                        result_pair <= j;
                        result_valid <= 1'b1;
                        output_j_index <= j + 4'd1;
                        found = 1'b1;
                    end
                    
                    if (!found) begin
                        // Move to next word
                        output_index <= output_index + 4'd1;
                        output_j_index <= 4'd0;
                        result_valid <= 1'b0;
                    end
                end else begin
                    state <= S_DONE;
                    done <= 1'b1;
                    result_valid <= 1'b0;
                end
            end
            
            S_DONE: begin
                done <= 1'b1;
                result_valid <= 1'b0;
            end
            
            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

// Helper function to find word length (non-zero chars)
function automatic [3:0] word_len_from_table(input [127:0] w);
    begin
        word_len_from_table = 4'd16;
        for (int i = 0; i < 16; i = i + 1) begin
            if (w[(i*8)+:8] == 8'd0) begin
                word_len_from_table = i;
                break;
            end
        end
    end
endfunction

endmodule