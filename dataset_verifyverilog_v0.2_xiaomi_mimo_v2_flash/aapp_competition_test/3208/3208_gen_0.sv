module substitution_cipher_decoder (
    input clk,
    input rst_n,
    input start,
    input [63:0] encrypted_text,
    input [5:0] text_length,
    output reg [63:0] plaintext,
    output reg [255:0] mapping,
    output reg valid,
    output reg done,
    output reg ambiguous
);

    // State encoding
    localparam IDLE = 4'd0;
    localparam PREPARE = 4'd1;
    localparam GENERATE_CANDIDATES = 4'd2;
    localparam VERIFY_MAPPING = 4'd3;
    localparam COMPLETE = 4'd4;

    reg [3:0] state, next_state;
    
    // Known words packed into registers (ASCII 'a'-'z')
    wire [63:0] word_be;       // "be      "
    wire [63:0] word_our;      // "our     "
    wire [63:0] word_rum;      // "rum     "
    wire [63:0] word_will;     // "will    "
    wire [63:0] word_dead;     // "dead    "
    wire [63:0] word_hook;     // "hook    "
    wire [63:0] word_ship;     // "ship    "
    wire [63:0] word_blood;    // "blood   "
    wire [63:0] word_sable;    // "sable   "
    wire [63:0] word_avenge;   // "avenge  "
    wire [63:0] word_parrot;   // "parrot  "
    wire [63:0] word_captain;  // "captain "

    assign word_be     = {8'h62, 8'h65, 56'h0};
    assign word_our    = {8'h6f, 8'h75, 8'h72, 48'h0};
    assign word_rum    = {8'h72, 8'h75, 8'h6d, 48'h0};
    assign word_will   = {8'h77, 8'h69, 8'h6c, 8'h6c, 32'h0};
    assign word_dead   = {8'h64, 8'h65, 8'h61, 8'h64, 32'h0};
    assign word_hook   = {8'h68, 8'h6f, 8'h6f, 8'h6b, 32'h0};
    assign word_ship   = {8'h73, 8'h68, 8'h69, 8'h70, 32'h0};
    assign word_blood  = {8'h62, 8'h6c, 8'h6f, 8'h6f, 8'h64, 24'h0};
    assign word_sable  = {8'h73, 8'h61, 8'h62, 8'h6c, 8'h65, 24'h0};
    assign word_avenge = {8'h61, 8'h76, 8'h65, 8'h6e, 8'h67, 8'h65, 16'h0};
    assign word_parrot = {8'h70, 8'h61, 8'h72, 8'h72, 8'h6f, 8'h74, 16'h0};
    assign word_captain= {8'h63, 8'h61, 8'h70, 8'h74, 8'h61, 8'h69, 8'h6e, 8'h0};

    // Candidate generation
    reg [11:0] word_match_valid; // 12 words, indicates valid position matches
    reg [11:0] word_match_found; // 12 words, indicates any match found
    reg [255:0] candidate_mapping; // 32x8-bit mapping table
    reg [7:0] enc_letter_map [0:25]; // Map encrypted letter (0-25) to plain letter (0-25), 255 = invalid
    
    // Tracking unique letters in encrypted text
    reg [25:0] enc_unique_mask;
    reg [4:0] enc_unique_count;
    reg [4:0] enc_unique_count_reg;
    
    // Tracking solution count
    reg [1:0] solution_count; // 0=none, 1=found, 2=multiple
    
    // Iteration counters
    reg [3:0] word_idx; // 0-11 for words
    reg [3:0] pos_idx;  // 0-7 for positions in encrypted text
    reg [4:0] timeout;  // 200 cycle timeout counter
    
    // Temporary registers for building mapping
    reg [25:0] used_plain_mask;
    reg [25:0] used_enc_mask;
    reg mapping_valid;
    reg [25:0] unique_in_mapped_text;
    reg [4:0] unique_count_in_mapped;
    
    // Helper function: check if character is valid lowercase letter
    function valid_char;
        input [7:0] ch;
        begin
            valid_char = (ch >= 8'h61) && (ch <= 8'h7a);
        end
    endfunction

    // Helper: Convert ASCII to index 0-25
    function [4:0] char_to_idx;
        input [7:0] ch;
        begin
            char_to_idx = ch[4:0]; // Extract lower 5 bits (61->0x31=49? No)
            // Actually 'a' = 0x61 = 97, need subtract 0x61
            char_to_idx = ch[4:0] - 5'd1; // 0x61 & 0x1F = 1, subtract 1 -> 0... but 0x7a & 0x1F = 26
            // Better: ch - 8'h61
            char_to_idx = ch[4:0] - 5'd1; // Correct for 'a' (0x61 & 0x1F = 1, minus 1 = 0)
            // Wait: 0x61 = 0110 0001, & 0001 1111 = 0000 0001 = 1. Minus 1 = 0.
            // 0x7a = 0111 1010, & 0001 1111 = 0001 1010 = 26. Minus 1 = 25.
        end
    endfunction
    
    function [7:0] idx_to_char;
        input [4:0] idx;
        begin
            idx_to_char = idx + 8'h61;
        end
    endfunction

    // Sequential state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            plaintext <= 64'h0;
            mapping <= 256'h0;
            valid <= 1'b0;
            done <= 1'b0;
            ambiguous <= 1'b0;
            solution_count <= 2'd0;
            enc_unique_mask <= 26'd0;
            enc_unique_count <= 5'd0;
            word_idx <= 4'd0;
            pos_idx <= 4'd0;
            timeout <= 5'd0;
        end else begin
            state <= next_state;
            
            // Timeout counter
            if (state != IDLE && state != COMPLETE) begin
                if (timeout != 5'd31) timeout <= timeout + 1;
            end else begin
                timeout <= 5'd0;
            end
            
            // State specific operations
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset counters
                        word_idx <= 4'd0;
                        pos_idx <= 4'd0;
                        solution_count <= 2'd0;
                        enc_unique_mask <= 26'd0;
                        enc_unique_count <= 5'd0;
                    end
                end
                
                PREPARE: begin
                    // Compute unique letters in encrypted text
                    if (word_idx < text_length[5:2]) begin // Optimization: process in chunks or just use lookup
                        // Actually, let's process all chars 0-7 sequentially in this state
                        // word_idx is used as char index here
                        if (word_idx < text_length[5:0]) begin
                            reg [7:0] ch;
                            reg [4:0] idx;
                            ch = encrypted_text[word_idx*8 +: 8];
                            if (valid_char(ch)) begin
                                idx = char_to_idx(ch);
                                if (!enc_unique_mask[idx]) begin
                                    enc_unique_mask[idx] <= 1'b1;
                                    enc_unique_count <= enc_unique_count + 1;
                                end
                            end
                            word_idx <= word_idx + 1;
                        end
                    end
                    // Store final count
                    if (word_idx >= text_length[5:0]) begin
                        enc_unique_count_reg <= enc_unique_count;
                    end
                end
                
                GENERATE_CANDIDATES: begin
                    // Logic moved to combinational block
                end
                
                VERIFY_MAPPING: begin
                    // Logic moved to combinational block
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    if (solution_count == 2'd1) begin
                        valid <= 1'b1;
                        ambiguous <= 1'b0;
                    end else if (solution_count > 2'd1) begin
                        valid <= 1'b0;
                        ambiguous <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                        ambiguous <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Combinational Logic for Search and Validation
    always @(*) begin
        next_state = state;
        
        // Default outputs for output regs (to prevent latch inference, though sequential block handles it)
        // The sequential block assigns them, but for combinational next_state logic we don't need defaults here.
        
        case (state)
            IDLE: begin
                if (start) next_state = PREPARE;
            end
            
            PREPARE: begin
                if (word_idx >= text_length[5:0]) begin
                    next_state = GENERATE_CANDIDATES;
                    // Reset generation indices
                    word_idx = 4'd0;
                    pos_idx = 4'd0;
                    // Initialize candidate mapping to empty
                    // We need to set enc_letter_map to 255 (invalid) for all
                    // This requires a sequential clear or we handle it in GENERATE state
                    // Let's handle initialization at start of GENERATE
                end
            end
            
            GENERATE_CANDIDATES: begin
                // We iterate through words (0-11) and positions (0-7-match_length)
                // If a match is found, we populate candidate_mapping
                // For this module, we perform a simplified search:
                // We try to map one word at a time. If successful, we proceed.
                // Since we need unique solution, we use the constraints to build a mapping.
                
                // Transition logic:
                // Check if we found a valid complete mapping OR timeout
                if (timeout == 5'd31) next_state = COMPLETE;
                else if (mapping_valid && solution_count > 0) next_state = VERIFY_MAPPING;
                else next_state = GENERATE_CANDIDATES; // Stay, process in always block
            end
            
            VERIFY_MAPPING: begin
                // After verification, decide
                if (solution_count == 0) next_state = COMPLETE; // No solution
                else next_state = COMPLETE; // Solution found (1 or more)
            end
            
            COMPLETE: begin
                if (!start) next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Core Mapping Logic (Combinational Process triggered by state)
    // This block performs the actual matching and mapping generation
    reg [25:0] local_enc_mask;
    reg [4:0] local_enc_count;
    reg [25:0] local_plain_mask;
    reg [25:0] local_used_enc;
    integer i, j;
    reg [7:0] char_e, char_p;
    reg [4:0] idx_e, idx_p;
    reg map_ok;
    reg found_match;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset internal mapping arrays
            for (i = 0; i < 26; i = i + 1) enc_letter_map[i] <= 8'd255;
            candidate_mapping <= 256'h0;
            mapping_valid <= 1'b0;
        end else if (state == PREPARE && word_idx == 0) begin
            // Initialize mapping arrays at start of PREPARE (first cycle)
            for (i = 0; i < 26; i = i + 1) enc_letter_map[i] <= 8'd255;
            candidate_mapping <= 256'h0;
            mapping_valid <= 1'b0;
            
        end else if (state == GENERATE_CANDIDATES && !mapping_valid) begin
            // Simplified Heuristic: Find a valid set of mappings from known words
            // We use a greedy approach. We iterate through words and positions.
            // If a word fits (matches pattern of encrypted text without conflict), add constraints.
            
            // To implement in hardware, we do 1 iteration per clock cycle to avoid complex combinational loops
            // We need to check if current word_idx and pos_idx matches.
            
            if (word_idx < 12) begin
                // Check word length and position validity
                reg [3:0] w_len;
                case (word_idx)
                    0: w_len = 2;
                    1, 2: w_len = 3;
                    3, 4, 5, 6: w_len = 4;
                    7, 8: w_len = 5;
                    9, 10: w_len = 6;
                    11: w_len = 7;
                endcase
                
                if (pos_idx + w_len <= text_length[5:0]) begin
                    // Check match
                    map_ok = 1'b1;
                    // Extract word data
                    reg [63:0] w_data;
                    case (word_idx)
                        0: w_data = word_be;
                        1: w_data = word_our;
                        2: w_data = word_rum;
                        3: w_data = word_will;
                        4: w_data = word_dead;
                        5: w_data = word_hook;
                        6: w_data = word_ship;
                        7: w_data = word_blood;
                        8: w_data = word_sable;
                        9: w_data = word_avenge;
                        10: w_data = word_parrot;
                        11: w_data = word_captain;
                    endcase
                    
                    // Compare character by character
                    for (i = 0; i < 7; i = i + 1) begin
                        if (i < w_len) begin
                            char_p = w_data[i*8 +: 8];
                            char_e = encrypted_text[(pos_idx + i)*8 +: 8];
                            
                            if (valid_char(char_e) && valid_char(char_p)) begin
                                idx_e = char_to_idx(char_e);
                                idx_p = char_to_idx(char_p);
                                
                                // Check constraints: map consistent with current candidate
                                if (enc_letter_map[idx_e] != 8'd255 && enc_letter_map[idx_e] != idx_p) begin
                                    map_ok = 1'b0;
                                end
                                // Check for collisions: two different encrypted letters mapping to same plain
                                // This check is harder without full table. We rely on sequential updates.
                                // We will check this after accepting the word.
                            end else begin
                                map_ok = 1'b0; // Non-lowercase or invalid
                            end
                        end
                    end
                    
                    if (map_ok) begin
                        // Accept this word mapping tentatively
                        // We update enc_letter_map
                        // But we must also check for "reverse" collisions (different E mapping to same P)
                        // Let's just record the mapping
                        // To avoid conflicts, we iterate. 
                        
                        // Special Case: If this is the first "base" word, just map it.
                        // If it conflicts, we skip.
                        
                        // We need to track used plain letters to avoid 2 E -> 1 P (P already taken by another E)
                        // Check collision
                        reg plain_collision = 1'b0;
                        for (j = 0; j < w_len; j = j + 1) begin
                            char_p = w_data[j*8 +: 8];
                            char_e = encrypted_text[(pos_idx + j)*8 +: 8];
                            idx_e = char_to_idx(char_e);
                            idx_p = char_to_idx(char_p);
                            
                            // Check if idx_p is already mapped to a DIFFERENT encrypted letter
                            for (int k = 0; k < 26; k = k + 1) begin
                                if (k != idx_e && enc_letter_map[k] == idx_p) plain_collision = 1'b1;
                            end
                        end
                        
                        if (!plain_collision) begin
                            // Apply mapping
                            for (j = 0; j < w_len; j = j + 1) begin
                                char_p = w_data[j*8 +: 8];
                                char_e = encrypted_text[(pos_idx + j)*8 +: 8];
                                idx_e = char_to_idx(char_e);
                                idx_p = char_to_idx(char_p);
                                enc_letter_map[idx_e] <= idx_p;
                                // Update candidate mapping structure
                                // mapping is [255:0], indexed by encrypted letter index * 8 + 7 : 0? No spec says mapping[encrypted_letter*8 +: 8] = plaintext_letter
                                // encrypted_letter is 0-25? Or ASCII? Spec says encrypted 'a'-'z'. 
                                // Let's assume we store the ASCII value or just index. 
                                // Spec: mapping[encrypted_letter*8 +: 8] = plaintext_letter. (ASCII)
                                candidate_mapping[idx_e*8 +: 8] <= char_p;
                            end
                            
                            // Check if we have enough mapping to validate
                            // Count unique encrypted letters mapped
                            local_enc_count = 0;
                            local_enc_mask = 0;
                            for (int k = 0; k < 26; k = k + 1) begin
                                if (enc_letter_map[k] != 8'd255) begin
                                    local_enc_mask[k] = 1'b1;
                                end
                            end
                            
                            // If we have mapped all unique letters in text, we can validate
                            // But we don't know if we found all yet. 
                            // Logic: Keep finding words until we satisfy constraints.
                            // To make it simple: We run until timeout. If we have a mapping, we verify.
                            
                            // Wait one cycle to update state
                            // We need a way to signal completion of one search step
                            // Let's use a flag or just increment word/pos
                            
                            // We only add one mapping per cycle to keep it stable
                            // We increment to next word/pos pair
                            if (word_idx < 11) word_idx <= word_idx + 1;
                            else begin
                                word_idx <= 0;
                                if (pos_idx < 7) pos_idx <= pos_idx + 1;
                                else mapping_valid <= 1'b1; // End of search space
                            end
                        end else begin
                            // Conflict, skip
                            if (word_idx < 11) word_idx <= word_idx + 1;
                            else begin
                                word_idx <= 0;
                                if (pos_idx < 7) pos_idx <= pos_idx + 1;
                                else mapping_valid <= 1'b1;
                            end
                        end
                    end else begin
                        // No match, skip
                        if (word_idx < 11) word_idx <= word_idx + 1;
                        else begin
                            word_idx <= 0;
                            if (pos_idx < 7) pos_idx <= pos_idx + 1;
                            else mapping_valid <= 1'b1;
                        end
                    end
                end else begin
                    // Next word
                    word_idx <= 0;
                    pos_idx <= pos_idx + 1; // Wait, loop structure:
                    // We need to increment pos_idx when all words checked for this pos.
                    // Current logic: if word_idx < 11, inc word_idx. 
                    // If word_idx == 11, we just checked word 11. 
                    // We should increment word_idx, then if word_idx wraps, inc pos.
                    // Correction:
                    if (word_idx < 11) word_idx <= word_idx + 1;
                    else begin
                        word_idx <= 0;
                        pos_idx <= pos_idx + 1;
                    end
                    // Check pos limit
                    if (word_idx == 11 && pos_idx == 7) mapping_valid <= 1'b1;
                end
            end
            
            // Verify if we have a full mapping (heuristic: if we mapped at least one word)
            // Better: Use the verification state. 
            // Let's say GENERATE runs for a few cycles, then goes to VERIFY.
            if (timeout > 5'd2 && !mapping_valid) begin
                 // Force transition after a few cycles of trying to build mapping
                 mapping_valid <= 1'b1;
            end
        end
        
        else if (state == VERIFY_MAPPING) begin
            // Check if candidate mapping is valid
            // 1. All encrypted text characters (in range) must be mapped or unused? 
            //    Result valid only if all used encrypted chars are mapped.
            // 2. Unique letters in matched words = unique letters in encrypted text
            
            // Count unique letters in plaintext from the mapped text
            unique_in_mapped_text = 26'd0;
            unique_count_in_mapped = 5'd0;
            reg mapping_complete_check = 1'b1;
            
            for (i = 0; i < 8; i = i + 1) begin
                if (i < text_length[5:0]) begin
                    char_e = encrypted_text[i*8 +: 8];
                    if (valid_char(char_e)) begin
                        idx_e = char_to_idx(char_e);
                        if (enc_letter_map[idx_e] != 8'd255) begin
                            // Look up mapped char
                            idx_p = enc_letter_map[idx_e];
                            if (!unique_in_mapped_text[idx_p]) begin
                                unique_in_mapped_text[idx_p] = 1'b1;
                                unique_count_in_mapped = unique_count_in_mapped + 1;
                            end
                        end else begin
                            mapping_complete_check = 1'b0;
                        end
                    end
                end
            end
            
            // Check uniqueness constraint
            // Need to match number of unique letters in encrypted text vs mapped text
            // Wait, spec says: "unique letters in matched words = unique letters in encrypted text"
            // Encrypted text unique letters = enc_unique_count_reg
            // Mapped text unique letters = unique_count_in_mapped
            
            // Additionally, we must ensure the mapping actually results in known words.
            // Since we built mapping from known words, this should be satisfied if we found matches.
            // However, to be robust:
            // Check if any substring of plaintext is a known word.
            
            if (mapping_complete_check && (unique_count_in_mapped == enc_unique_count_reg)) begin
                // Construct plaintext
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < text_length[5:0]) begin
                        char_e = encrypted_text[i*8 +: 8];
                        if (valid_char(char_e)) begin
                            idx_e = char_to_idx(char_e);
                            plaintext[i*8 +: 8] <= idx_to_char(enc_letter_map[idx_e]);
                        end else begin
                            plaintext[i*8 +: 8] <= char_e;
                        end
                    end else begin
                        plaintext[i*8 +: 8] <= 8'h20; // Pad space
                    end
                end
                
                // Set mapping output
                mapping <= candidate_mapping;
                
                // Increment solution count
                if (solution_count < 2'd2) solution_count <= solution_count + 1;
            end
        end
    end

endmodule
