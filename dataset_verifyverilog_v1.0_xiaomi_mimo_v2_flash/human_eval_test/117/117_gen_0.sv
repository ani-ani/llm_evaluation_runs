module word_selector(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    input [3:0] n,
    output reg [7:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SCANNING   = 3'd1;
    localparam [2:0] CHECKING   = 3'd2;
    localparam [2:0] FOUND      = 3'd3;
    localparam [2:0] FINISHED   = 3'd4;

    // Internal registers and variables
    reg [2:0] state;
    reg [3:0] i;                // String index
    reg [3:0] consonant_count;  // Count for current word
    reg [3:0] word_len;         // Length of current word
    reg in_word;                // Flag: we are inside a word
    reg [7:0] current_word [0:15]; // Buffer for current word
    reg [3:0] j;                // Index for copying to result
    reg match_found;            // Flag if a match was found
    reg [7:0] char;             // Current character
    reg is_vowel;               // Flag for vowel check
    reg is_letter;              // Flag for letter check
    reg is_space;               // Flag for space check
    reg is_consonant;           // Flag for consonant check
    reg [7:0] lower_char;       // Lowercase version of char

    integer k; // For loop variable in reset

    // Helper Logic for Character Classification (Combinational)
    always @(*) begin
        // Initialize flags
        is_letter = 1'b0;
        is_vowel = 1'b0;
        is_space = 1'b0;
        lower_char = 8'd0;

        // Check for space
        if (char == 8'h20) begin
            is_space = 1'b1;
        end

        // Convert to lowercase for case-insensitive comparison
        if (char >= 8'h41 && char <= 8'h5A) begin
            // Uppercase A-Z
            lower_char = char + 8'd32;
            is_letter = 1'b1;
        end else if (char >= 8'h61 && char <= 8'h7A) begin
            // Lowercase a-z
            lower_char = char;
            is_letter = 1'b1;
        end

        // Check if lowercase char is a vowel
        if (is_letter) begin
            case (lower_char)
                8'h61, // 'a'
                8'h65, // 'e'
                8'h69, // 'i'
                8'h6F, // 'o'
                8'h75: // 'u'
                    is_vowel = 1'b1;
                default: is_vowel = 1'b0;
            endcase
        end

        // Determine if consonant
        is_consonant = is_letter & ~is_vowel;
    end

    // Sequential Logic (FSM)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            consonant_count <= 4'd0;
            word_len <= 4'd0;
            in_word <= 1'b0;
            match_found <= 1'b0;
            char <= 8'd0;
            for (k = 0; k < 16; k = k + 1) begin
                result[k] <= 8'd0;
                current_word[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    consonant_count <= 4'd0;
                    word_len <= 4'd0;
                    in_word <= 1'b0;
                    match_found <= 1'b0;
                    // Clear result buffer (set to all zeros)
                    for (k = 0; k < 16; k = k + 1) begin
                        result[k] <= 8'd0;
                        current_word[k] <= 8'd0;
                    end
                    if (start) begin
                        state <= SCANNING;
                    end
                end

                SCANNING: begin
                    // Read current character
                    char <= str[i];
                    
                    // Logic to process character happens in next cycle
                    // or we can process logic immediately if we use intermediate registers
                    // Here we use the combinational logic block above

                    // Check if we are at the end of the string
                    if (i == 4'd15) begin
                        // Last character logic will be processed in next state
                        // or we handle the transition logic here based on flags
                        // We need to process the current char first
                        // So we stay in SCANNING for one cycle to process char
                        // Actually, it's cleaner to transition to a processing state or do it here.
                        // Let's do processing logic here.

                        if (is_space) begin
                            if (in_word) begin
                                state <= CHECKING; // End of word found at last char
                            end else begin
                                state <= FINISHED; // No word, end of string
                            end
                        end else if (is_letter) begin
                            // Last char is a letter
                            if (is_consonant) begin
                                consonant_count <= consonant_count + 4'd1;
                            end
                            // Store char in buffer
                            current_word[word_len] <= char;
                            word_len <= word_len + 4'd1;
                            in_word <= 1'b1;
                            
                            // Since this is the last char, we must check the word now
                            state <= CHECKING;
                        end else begin
                            // Non-letter, non-space (punctuation or other)
                            // Treat as word separator? Spec implies spaces separate words.
                            // If not a letter and not a space, ambiguous.
                            // Assuming we ignore non-letters, but break word if sequence breaks.
                            // For safety, if we were in a word and hit garbage, check it.
                            if (in_word) begin
                                state <= CHECKING;
                            end else begin
                                state <= FINISHED;
                            end
                        end
                    end else begin
                        // Not at end of string
                        // We process the current char and increment i
                        // We need to handle the logic for the current char
                        // To avoid combinational loops in FSM, we process char in this state
                        // and advance i.

                        if (is_space) begin
                            if (in_word) begin
                                state <= CHECKING;
                                // i will stay same until CHECKING handles reset or we handle logic carefully.
                                // Actually, better to transition to CHECKING and keep i pointing to the space? 
                                // No, we want to continue scanning after the space.
                                // So we should process CHECKING, then when we return to SCANNING, we advance.
                                // But we just hit a space. The word ended at i-1.
                                // We need to check the word that just finished.
                                // We should NOT increment i yet, so we don't skip the space character? 
                                // Actually, we process the space as a delimiter. 
                                // We need to go to CHECKING, then back to SCANNING (to continue from i+1).
                                // But if we stay in SCANNING, i increments.
                                // Let's structure it: SCANNING reads str[i], classifies it.
                                // If Space: if in_word -> CHECKING. (i stays? or inc?)
                                // If Letter: process. (i inc?)
                                // To simplify: SCANNING state processes str[i] and updates state/buffers.
                                // Then increments i (unless transition happens).
                                
                                // Transition to CHECKING means we stop scanning.
                                // We need to preserve i so we know where to resume.
                                // Actually, we don't need to resume from here. We found a word ending at i.
                                // We check it. If match -> FOUND. If not -> Reset buffers and continue scanning from i+1.
                                
                                // Let's process the space logic here:
                                if (in_word) begin
                                    // Word ended
                                    state <= CHECKING;
                                end else begin
                                    // Just a space, keep scanning
                                    i <= i + 4'd1;
                                end
                            end else begin
                                // Space, not in word
                                i <= i + 4'd1;
                            end
                        end else if (is_letter) begin
                            // It's a letter
                            if (is_consonant) begin
                                consonant_count <= consonant_count + 4'd1;
                            end
                            current_word[word_len] <= char;
                            word_len <= word_len + 4'd1;
                            in_word <= 1'b1;
                            i <= i + 4'd1;
                        end else begin
                            // Other char. Treat as separator or ignore?
                            // Spec: "If str[i] is a space...". Implicitly spaces are delimiters.
                            // Other chars: Usually part of word or separator. 
                            // Let's assume anything not a letter is a separator (like punctuation).
                            if (in_word) begin
                                state <= CHECKING;
                            end else begin
                                i <= i + 4'd1;
                            end
                        end
                    end
                end

                CHECKING: begin
                    if (consonant_count == n) begin
                        state <= FOUND;
                    end else begin
                        // No match, reset and continue scanning
                        // We need to find where to continue.
                        // We stopped at a delimiter (space or non-letter) or end of string.
                        // The index 'i' was incremented AFTER processing the letter.
                        // So 'i' points to the next character (the delimiter or next char).
                        // If we were at the delimiter, we need to make sure we don't skip it.
                        // Actually, in SCANNING, if we hit a delimiter ending a word, we transitioned to CHECKING.
                        // In that case, did we increment i?
                        // In the logic above, for Space: if in_word, state <= CHECKING. 
                        // I forgot to increment i in that specific branch in the draft above.
                        // Let's review SCANNING logic for 'Space':
                        // If is_space and in_word: state <= CHECKING. (i not incremented).
                        // So i points to the space.
                        // When we resume, we want to skip that space and the word we just checked.
                        // So we should set i to the character AFTER the space (which is effectively i+1).
                        // But we don't know if it's a space or non-letter.
                        // We can just set i <= i + 4'd1 here.
                        
                        consonant_count <= 4'd0;
                        word_len <= 4'd0;
                        in_word <= 1'b0;
                        // Clear buffer (optional, but good practice)
                        for (k = 0; k < 16; k = k + 1) begin
                            current_word[k] <= 8'd0;
                        end
                        
                        // Resume scanning
                        state <= SCANNING;
                        i <= i + 4'd1; // Skip the delimiter
                    end
                end

                FOUND: begin
                    // Copy current_word to result
                    // We need to pad with spaces (0x20)
                    // Logic: copy valid chars, then fill rest with spaces
                    // Since arrays are size 16, we can iterate 0 to 15.
                    // If index < word_len, copy current_word. Else space.
                    
                    if (j < word_len) begin
                        result[j] <= current_word[j];
                    end else begin
                        result[j] <= 8'h20; // Space
                    end

                    if (j == 4'd15) begin
                        j <= 4'd0;
                        match_found <= 1'b1;
                        state <= FINISHED;
                    end else begin
                        j <= j + 4'd1;
                        // Stay in FOUND until all copied
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    // Wait for start to go low
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule