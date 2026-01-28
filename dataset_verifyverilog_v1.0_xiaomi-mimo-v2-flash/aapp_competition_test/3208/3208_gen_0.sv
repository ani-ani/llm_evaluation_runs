module decrypt_substitution(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] encrypted_text [0:31],
    input wire [5:0] length,
    output reg [7:0] result [0:31],
    output reg done,
    output reg possible
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] SEARCH  = 3'd2;
    localparam [2:0] DECRYPT = 3'd3;
    localparam [2:0] DONE_S  = 3'd4;

    // Vocabulary definitions (12 words, 8 chars each, padded with spaces)
    // Using packed format for easier storage
    localparam [63:0] VOCAB [0:11] = '{
        64'h6265202020202020,  // "be      "
        64'h6F75722020202020,  // "our     "
        64'h72756D2020202020,  // "rum     "
        64'h77696C6C20202020,  // "will    "
        64'h6465616420202020,  // "dead    "
        64'h686F6F6B20202020,  // "hook    "
        64'h7368697020202020,  // "ship    "
        64'h626C6F6F64202020,  // "blood   "
        64'h7361626C65202020,  // "sable   "
        64'h6176656E67652020,  // "avenge  "
        64'h706172726F742020,  // "parrot  "
        64'h6361707461696E20   // "captain "
    };

    // Registers for state machine
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Word parsing registers
    reg [5:0] char_idx;
    reg [4:0] word_count;
    reg [3:0] current_word_len;
    reg [7:0] current_word [0:7];
    reg [4:0] word_start [0:15];  // Starting index of each word
    reg [3:0] word_lens [0:15];   // Length of each word
    
    // Mapping registers (encrypted letter -> plaintext letter)
    // Map 0 means unassigned, 1..26 means 'a'..'z'
    reg [4:0] mapping [0:15];  // 16 possible encrypted letters, value 1-26
    reg [4:0] reverse_map [0:25];  // For checking uniqueness
    reg [3:0] unique_letters;
    reg [3:0] unique_idx [0:15];  // Store which encrypted letters are unique
    reg [7:0] enc_char_to_idx [0:127];  // Map ASCII char to unique index (0-15)
    
    // Search state
    reg [3:0] search_word_idx;  // Which word in input we're trying to match
    reg [3:0] search_vocab_idx;  // Which vocabulary word to try
    reg [7:0] search_iter;  // Iteration counter for bounded search
    reg [3:0] backtrack_depth;  // For backtracking
    reg [15:0] valid_mappings;  // Bitmask of valid mappings found
    reg [3:0] valid_mapping_count;
    
    // Combinational helpers
    integer i, j, k;
    reg [7:0] char_a, char_b;
    reg match_found;
    reg mapping_valid;
    reg [4:0] map_val_a, map_val_b;
    
    // Temporary registers for search
    reg [4:0] temp_mapping [0:15];
    reg [4:0] temp_reverse [0:25];
    
    // Result storage
    reg [7:0] best_result [0:31];
    reg best_valid;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            possible <= 1'b0;
            cycle_count <= 8'd0;
            char_idx <= 6'd0;
            word_count <= 5'd0;
            current_word_len <= 4'd0;
            unique_letters <= 4'd0;
            search_word_idx <= 4'd0;
            search_vocab_idx <= 4'd0;
            search_iter <= 8'd0;
            backtrack_depth <= 4'd0;
            valid_mappings <= 16'd0;
            valid_mapping_count <= 4'd0;
            best_valid <= 1'b0;
            
            for (i = 0; i < 32; i = i + 1) begin
                result[i] <= 8'd0;
                best_result[i] <= 8'd0;
            end
            
            for (i = 0; i < 16; i = i + 1) begin
                mapping[i] <= 5'd0;
                unique_idx[i] <= 4'd0;
                word_start[i] <= 6'd0;
                word_lens[i] <= 4'd0;
                temp_mapping[i] <= 5'd0;
            end
            
            for (i = 0; i < 26; i = i + 1) begin
                reverse_map[i] <= 5'd0;
                temp_reverse[i] <= 5'd0;
            end
            
            for (i = 0; i < 128; i = i + 1) begin
                enc_char_to_idx[i] <= 8'd0;
            end
            
            for (i = 0; i < 8; i = i + 1) begin
                current_word[i] <= 8'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 8'd0;
                    search_iter <= 8'd0;
                    valid_mappings <= 16'd0;
                    valid_mapping_count <= 4'd0;
                    best_valid <= 1'b0;
                    
                    if (start) begin
                        char_idx <= 6'd0;
                        word_count <= 5'd0;
                        current_word_len <= 4'd0;
                        unique_letters <= 4'd0;
                        state <= PARSE;
                        
                        // Initialize arrays
                        for (i = 0; i < 16; i = i + 1) begin
                            mapping[i] <= 5'd0;
                            unique_idx[i] <= 4'd0;
                            word_start[i] <= 6'd0;
                            word_lens[i] <= 4'd0;
                        end
                        for (i = 0; i < 26; i = i + 1) begin
                            reverse_map[i] <= 5'd0;
                        end
                        for (i = 0; i < 128; i = i + 1) begin
                            enc_char_to_idx[i] <= 8'd0;
                        end
                    end
                end
                
                PARSE: begin
                    if (char_idx < length) begin
                        char_a <= encrypted_text[char_idx];
                        if (encrypted_text[char_idx] == 8'h20) begin
                            // Space - end current word
                            if (current_word_len > 4'd0) begin
                                word_start[word_count] <= char_idx - {2'd0, current_word_len};
                                word_lens[word_count] <= current_word_len;
                                word_count <= word_count + 5'd1;
                                current_word_len <= 4'd0;
                            end
                            char_idx <= char_idx + 6'd1;
                        end else if (encrypted_text[char_idx] >= 8'h61 && encrypted_text[char_idx] <= 8'h7A) begin
                            // Letter - add to current word
                            if (current_word_len < 4'd8) begin
                                current_word_len <= current_word_len + 4'd1;
                            end
                            
                            // Check if letter already in unique list
                            if (enc_char_to_idx[encrypted_text[char_idx]] == 8'd0) begin
                                // New unique letter
                                enc_char_to_idx[encrypted_text[char_idx]] <= {4'd0, unique_letters} + 8'd1;
                                unique_idx[unique_letters] <= {1'b0, encrypted_text[char_idx]};
                                unique_letters <= unique_letters + 4'd1;
                            end
                            char_idx <= char_idx + 6'd1;
                        end else begin
                            // Invalid character - treat as space
                            if (current_word_len > 4'd0) begin
                                word_start[word_count] <= char_idx - {2'd0, current_word_len};
                                word_lens[word_count] <= current_word_len;
                                word_count <= word_count + 5'd1;
                                current_word_len <= 4'd0;
                            end
                            char_idx <= char_idx + 6'd1;
                        end
                    end else begin
                        // End of input
                        if (current_word_len > 4'd0) begin
                            word_start[word_count] <= char_idx - {2'd0, current_word_len};
                            word_lens[word_count] <= current_word_len;
                            word_count <= word_count + 5'd1;
                        end
                        
                        // Check if too many unique letters or no words
                        if (unique_letters > 4'd12 || word_count == 5'd0) begin
                            state <= DONE_S;
                            possible <= 1'b0;
                            best_valid <= 1'b0;
                        end else begin
                            state <= SEARCH;
                            search_word_idx <= 4'd0;
                            search_vocab_idx <= 4'd0;
                            
                            // Reset temporary mappings
                            for (i = 0; i < 16; i = i + 1) begin
                                temp_mapping[i] <= 5'd0;
                            end
                            for (i = 0; i < 26; i = i + 1) begin
                                temp_reverse[i] <= 5'd0;
                            end
                        end
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_S;
                        possible <= 1'b0;
                    end else if (valid_mapping_count == 4'd1 && best_valid) begin
                        // Found exactly one valid mapping
                        state <= DECRYPT;
                        mapping <= temp_mapping;  // Store the valid mapping
                    end else if (valid_mapping_count > 4'd1) begin
                        // More than one mapping found
                        state <= DONE_S;
                        possible <= 1'b0;
                    end else if (search_word_idx >= word_count) begin
                        // Completed all word matches - check if we have a complete mapping
                        mapping_valid <= 1'b1;
                        
                        // Verify all unique letters are mapped
                        for (i = 0; i < unique_letters; i = i + 1) begin
                            if (temp_mapping[i] == 5'd0) begin
                                mapping_valid <= 1'b0;
                            end
                        end
                        
                        if (mapping_valid) begin
                            // Check reverse map for uniqueness
                            for (i = 0; i < 26; i = i + 1) begin
                                if (temp_reverse[i] > 5'd1) begin
                                    mapping_valid <= 1'b0;
                                end
                            end
                        end
                        
                        if (mapping_valid) begin
                            // Valid complete mapping found
                            valid_mappings[search_iter] <= 1'b1;
                            valid_mapping_count <= valid_mapping_count + 4'd1;
                            best_valid <= 1'b1;
                            
                            // Store result
                            for (i = 0; i < 16; i = i + 1) begin
                                mapping[i] <= temp_mapping[i];
                            end
                        end
                        
                        search_word_idx <= 4'd0;
                        search_iter <= search_iter + 8'd1;
                        
                        // Reset for next iteration
                        for (i = 0; i < 16; i = i + 1) begin
                            temp_mapping[i] <= 5'd0;
                        end
                        for (i = 0; i < 26; i = i + 1) begin
                            temp_reverse[i] <= 5'd0;
                        end
                    end else begin
                        // Try to match current word against vocabulary
                        if (search_vocab_idx < 12) begin
                            // Check if word length matches
                            if (word_lens[search_word_idx] == 4'd0) begin
                                search_vocab_idx <= search_vocab_idx + 4'd1;
                            end else if (word_lens[search_word_idx] == VOCAB[search_vocab_idx][7:4]) begin
                                // Length matches - check character by character
                                match_found <= 1'b1;
                                mapping_valid <= 1'b1;
                                
                                // Check each character
                                for (k = 0; k < 8; k = k + 1) begin
                                    if (k < word_lens[search_word_idx]) begin
                                        // Get encrypted char
                                        char_a <= encrypted_text[word_start[search_word_idx] + k];
                                        // Get expected plaintext char from vocab
                                        case (k)
                                            0: char_b <= VOCAB[search_vocab_idx][63:56];
                                            1: char_b <= VOCAB[search_vocab_idx][55:48];
                                            2: char_b <= VOCAB[search_vocab_idx][47:40];
                                            3: char_b <= VOCAB[search_vocab_idx][39:32];
                                            4: char_b <= VOCAB[search_vocab_idx][31:24];
                                            5: char_b <= VOCAB[search_vocab_idx][23:16];
                                            6: char_b <= VOCAB[search_vocab_idx][15:8];
                                            7: char_b <= VOCAB[search_vocab_idx][7:0];
                                        endcase
                                        
                                        // Get unique index for encrypted char
                                        if (enc_char_to_idx[char_a] > 8'd0) begin
                                            map_val_a <= enc_char_to_idx[char_a];
                                        end else begin
                                            match_found <= 1'b0;
                                        end
                                        
                                        // Get plaintext value (1-26)
                                        if (char_b >= 8'h61 && char_b <= 8'h7A) begin
                                            map_val_b <= char_b - 8'h60;
                                        end else begin
                                            // Space or invalid
                                            if (char_b != 8'h20) begin
                                                match_found <= 1'b0;
                                            end
                                        end
                                    end
                                end
                                
                                // Check mapping consistency
                                if (match_found) begin
                                    for (k = 0; k < word_lens[search_word_idx]; k = k + 1) begin
                                        char_a <= encrypted_text[word_start[search_word_idx] + k];
                                        case (k)
                                            0: char_b <= VOCAB[search_vocab_idx][63:56];
                                            1: char_b <= VOCAB[search_vocab_idx][55:48];
                                            2: char_b <= VOCAB[search_vocab_idx][47:40];
                                            3: char_b <= VOCAB[search_vocab_idx][39:32];
                                            4: char_b <= VOCAB[search_vocab_idx][31:24];
                                            5: char_b <= VOCAB[search_vocab_idx][23:16];
                                            6: char_b <= VOCAB[search_vocab_idx][15:8];
                                            7: char_b <= VOCAB[search_vocab_idx][7:0];
                                        endcase
                                        
                                        if (enc_char_to_idx[char_a] > 8'd0) begin
                                            map_val_a <= enc_char_to_idx[char_a];
                                            if (char_b >= 8'h61 && char_b <= 8'h7A) begin
                                                map_val_b <= char_b - 8'h60;
                                                
                                                // Check if mapping conflicts
                                                if (temp_mapping[map_val_a] == 5'd0) begin
                                                    temp_mapping[map_val_a] <= map_val_b;
                                                end else if (temp_mapping[map_val_a] != map_val_b) begin
                                                    mapping_valid <= 1'b0;
                                                end
                                                
                                                // Check reverse mapping
                                                if (temp_reverse[map_val_b] == 5'd0) begin
                                                    temp_reverse[map_val_b] <= 5'd1;
                                                end else begin
                                                    temp_reverse[map_val_b] <= temp_reverse[map_val_b] + 5'd1;
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                search_vocab_idx <= search_vocab_idx + 4'd1;
                            end else begin
                                search_vocab_idx <= search_vocab_idx + 4'd1;
                            end
                        end else begin
                            // Done checking all vocabulary for this word
                            search_word_idx <= search_word_idx + 4'd1;
                            search_vocab_idx <= 4'd0;
                        end
                    end
                end
                
                DECRYPT: begin
                    // Apply mapping to input text
                    for (i = 0; i < 32; i = i + 1) begin
                        if (i < length) begin
                            char_a <= encrypted_text[i];
                            if (char_a == 8'h20) begin
                                result[i] <= 8'h20;
                            end else if (char_a >= 8'h61 && char_a <= 8'h7A) begin
                                if (enc_char_to_idx[char_a] > 8'd0) begin
                                    map_val_a <= enc_char_to_idx[char_a];
                                    if (mapping[map_val_a] > 5'd0) begin
                                        result[i] <= 8'h60 + mapping[map_val_a];
                                    end else begin
                                        result[i] <= char_a;  // Unmapped
                                    end
                                end else begin
                                    result[i] <= char_a;
                                end
                            end else begin
                                result[i] <= char_a;  // Non-letter pass-through
                            end
                        end else begin
                            result[i] <= 8'h20;  // Pad with spaces
                        end
                    end
                    
                    possible <= 1'b1;
                    state <= DONE_S;
                end
                
                DONE_S: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                        possible <= 1'b0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule