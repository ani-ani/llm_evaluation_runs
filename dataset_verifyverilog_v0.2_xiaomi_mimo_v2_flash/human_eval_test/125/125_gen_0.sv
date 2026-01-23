module split_words (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] str_len,
    output reg [127:0] word0,
    output reg [127:0] word1,
    output reg [127:0] word2,
    output reg [127:0] word3,
    output reg [3:0] result_count,
    output reg result_is_count,
    output reg done
);

    // FSM States
    localparam IDLE = 2'b00;
    localparam READ_CHAR = 2'b01;
    localparam PROCESS = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Registers
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [3:0] char_counter;
    reg [7:0] buffer [0:15]; // Buffer for 16 chars
    reg [7:0] delimiter_found; // 0x20 for Space, 0x2C for Comma, 0x00 for None
    reg [3:0] words_count; // Number of words found (max 4)
    reg [3:0] temp_count; // Temp count for odd lowercase
    reg [3:0] word_offsets [0:3]; // Start index of each word
    reg [3:0] word_lengths [0:3]; // Length of each word

    // Temporary variables for combinational logic
    integer i;
    reg is_space;
    reg is_comma;
    reg is_delimiter;
    reg [7:0] current_char;
    reg [3:0] current_word_idx;
    reg [3:0] current_word_len;
    reg [7:0] current_word_start;
    reg [127:0] packed_word;
    reg [3:0] count_val;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = READ_CHAR;
                else next_state = IDLE;
            end
            READ_CHAR: begin
                // Wait for str_len characters
                if (char_counter == str_len && str_len != 0) next_state = PROCESS;
                else if (char_counter == str_len && str_len == 0) next_state = DONE_STATE; // Handle empty string immediately
                else next_state = READ_CHAR;
            end
            PROCESS: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_counter <= 4'b0;
            delimiter_found <= 8'b0;
            words_count <= 4'b0;
            temp_count <= 4'b0;
            done <= 1'b0;
            result_is_count <= 1'b0;
            result_count <= 4'b0;
            word0 <= 128'b0;
            word1 <= 128'b0;
            word2 <= 128'b0;
            word3 <= 128'b0;
            // Reset buffer indices not strictly necessary but good practice
            for (i = 0; i < 16; i = i + 1) buffer[i] <= 8'b0;
            for (i = 0; i < 4; i = i + 1) begin
                word_offsets[i] <= 4'b0;
                word_lengths[i] <= 4'b0;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        char_counter <= 4'b0;
                        delimiter_found <= 8'b0;
                        words_count <= 4'b0;
                        temp_count <= 4'b0;
                        // Initialize first word offset to 0
                        word_offsets[0] <= 4'b0;
                    end
                end

                READ_CHAR: begin
                    if (char_counter < str_len) begin
                        buffer[char_counter] <= char_in;
                        
                        // Check Delimiter immediately to latch type
                        if (delimiter_found == 8'b0) begin
                            if (char_in == 8'h20 || char_in == 8'h2C) begin
                                delimiter_found <= char_in;
                            end
                        end

                        // Word Boundary Logic
                        if (delimiter_found == 8'b0) begin
                            // Before first delimiter
                            if (char_in == 8'h20 || char_in == 8'h2C) begin
                                // End of current word (word 0)
                                if (words_count == 0) begin // Only close word 0 once
                                    word_lengths[0] <= char_counter - word_offsets[0];
                                    words_count <= 1;
                                end
                            end
                        end else if (delimiter_found == 8'h20) begin
                            // Space delimiter mode
                            if (char_in == 8'h20) begin
                                if (words_count < 4) begin
                                    word_lengths[words_count] <= char_counter - word_offsets[words_count];
                                    words_count <= words_count + 1;
                                    if (words_count + 1 < 4) word_offsets[words_count + 1] <= char_counter + 1;
                                end
                            end
                        end else if (delimiter_found == 8'h2C) begin
                            // Comma delimiter mode
                            if (char_in == 8'h2C) begin
                                if (words_count < 4) begin
                                    word_lengths[words_count] <= char_counter - word_offsets[words_count];
                                    words_count <= words_count + 1;
                                    if (words_count + 1 < 4) word_offsets[words_count + 1] <= char_counter + 1;
                                end
                            end
                        end

                        // Counting Logic (Incremental)
                        if (delimiter_found == 8'b0) begin
                            // Check if lowercase
                            if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                                // Check index odd (0 is 'a', so index 1, 3, 5... are odd)
                                if ((char_in - 8'h61) & 1) begin
                                    temp_count <= temp_count + 1;
                                end
                            end
                        end

                        char_counter <= char_counter + 1;
                    end
                end

                PROCESS: begin
                    // Finalize Logic
                    result_is_count <= (delimiter_found == 8'b0);

                    if (delimiter_found == 8'b0) begin
                        // Count Mode Result
                        result_count <= temp_count;
                        word0 <= 128'b0;
                        word1 <= 128'b0;
                        word2 <= 128'b0;
                        word3 <= 128'b0;
                    end else begin
                        // Split Mode Result
                        result_count <= 4'b0;
                        
                        // Handle trailing word if string didn't end with delimiter
                        // We need to determine if the last character was a delimiter
                        // buffer[str_len - 1] is the last char
                        // If last char was NOT a delimiter, the current word count is an active word
                        // However, we stopped counting words in READ_CHAR only on delimiters.
                        // So we must check if the last char was a delimiter. If not, close the last word.
                        
                        // If the input string length > 0, we check the last char in buffer
                        if (str_len > 0) begin
                            // Check if buffer[str_len-1] is the delimiter found
                            // If buffer[str_len-1] IS delimiter, words_count is correct.
                            // If buffer[str_len-1] IS NOT delimiter, we need to finalize the word at words_count index.
                            // BUT: words_count was incremented when delimiter hit. 
                            // If no trailing delimiter, words_count is the index of the open word.
                            
                            // Logic in READ_CHAR: 
                            // If delimiter found:
                            //   if char is delim -> words_count++
                            // So if string ends with word (no delim), words_count points to that word.
                            // But word_lengths[words_count] was not updated.
                            
                            // Let's re-evaluate. 
                            // word_offsets[0] = 0.
                            // If char 0 is delim: words_count=1. lengths[0]=0.
                            // If char 1 is word: nothing.
                            // If char 2 is delim: words_count=2. lengths[1]=1 (2-1).
                            // End of string 3. last char is word. words_count=2. lengths[2] is X.
                            // We need to set lengths[2] = 3 - offsets[2] = 3 - ? offsets[2] was set at char 2 delim. offsets[2]=3.
                            // Wait, offsets[words_count] is set to char_counter + 1 *before* incrementing char_counter.
                            // So at char 2 (delim), char_counter is 2. 
                            // offsets[words_count] set to 2+1=3. 
                            // words_count++ -> 2.
                            // If end here, words_count=2. lengths[0], [1] set.
                            // If end at char 3 (word), words_count=2. 
                            // We need lengths[2] = str_len (4) - offsets[2] (3) = 1.
                            
                            // If the last character in buffer is a delimiter, words_count is correct (points to next empty slot).
                            // If last char is NOT a delimiter, we must finalize the word at (words_count - 1) if words_count > 0? No.
                            // Consider string "A,B" (len 3). 
                            // char 0 'A': offsets[0]=0.
                            // char 1 ',': delim found ','. lengths[0]=1. offsets[1]=2. words_count=1.
                            // char 2 'B': check delim (no). check count (no, delim found). 
                            // end process: last char 'B'. words_count=1. 
                            // We need to fill word1. 
                            // lengths[1] = 3 - offsets[1] = 3 - 2 = 1.
                            // words_count remains 1? No, we have 2 words. 
                            // Wait, words_count tracks the *next* empty slot or the *current* full words?
                            // In READ_CHAR, when delim hit, words_count is incremented. 
                            // So words_count is effectively "number of delimiters found" + 1? 
                            // Yes. "A,B,C" -> delim 1, delim 2. words_count=2. 
                            // Words: A, B, C. 3 words. words_count = 2. 
                            // Actually, if we have 2 delimiters, we have 3 words. words_count should be 3.
                            // If words_count tracks the index of the next word start, then:
                            // Start: words_count=0. Offsets[0]=0.
                            // Hit delim: lengths[0]=current-off[0]. words_count=1. Offsets[1]=current+1.
                            // Hit delim: lengths[1]=current-off[1]. words_count=2. Offsets[2]=current+1.
                            // End. words_count=2. Indices 0, 1 filled. 
                            // So if last char is NOT delim, we have an open word at index words_count.
                            // We need to close it: lengths[words_count] = str_len - offsets[words_count].
                            // And we need to increment words_count? No, we just need to know how many words to output.
                            // Let's output up to 4 words. 
                            // Let's use a final_w_count register or calculate it.
                            
                            // Let's refine the logic.
                            // We need to determine the number of valid words.
                            // Case 1: No delimiter. 0 words (or 1 word? Spec says "If fewer words, remaining words are empty/null". 
                            // Spec: "Split into words... Output result_is_count=0".
                            // If "hello" (no delim), is it 1 word or count mode?
                            // Spec: "If no Delimiter found: Count...".
                            // So if "hello", it's count mode. So 0 words for split mode.
                            // Case 2: "Hello world". Delim found. 2 words.
                            // Case 3: "Hello " (ends with space). 2 words? Or 1 word?
                            // Usually "Hello " splits to "Hello" and "".
                            // Case 4: " Hello". Splits to "" and "Hello".
                            
                            // Let's define the output behavior.
                            // Splitting on delimiter.
                            // 1. Determine final word count and lengths.
                            // 2. Pack into 128-bit vectors.

                            // Logic for finalizing lengths and count:
                            reg last_char_is_delim;
                            last_char_is_delim = (buffer[str_len - 1] == 8'h20 || buffer[str_len - 1] == 8'h2C);
                            
                            // If last char is delim, words_count tracks the number of slots used + 1?
                            // If "A,B,": 
                            // 0:A -> offsets[0]=0
                            // 1:, -> len[0]=1, offsets[1]=2, w_count=1
                            // 2:B -> 
                            // 3:, -> len[1]=1, offsets[2]=4, w_count=2
                            // End: w_count=2. last_char_is_delim=1.
                            // Valid words: 0, 1. 
                            // 
                            // If "A,B":
                            // 0:A -> offsets[0]=0
                            // 1:, -> len[0]=1, offsets[1]=2, w_count=1
                            // 2:B -> 
                            // End: w_count=1. last_char_is_delim=0.
                            // Need to calculate len[1] = 3 - 2 = 1. 
                            // 
                            // So:
                            // If !last_char_is_delim: 
                            //    lengths[words_count] = str_len - offsets[words_count];
                            //    active_word_count = words_count + 1;
                            // Else:
                            //    active_word_count = words_count; (words_count is already count of filled slots)
                            
                            // Wait, in "A,B," we have w_count=2. Indices 0, 1 filled.
                            // In "A,B" we have w_count=1. Index 0 filled. Index 1 needs filling.
                            
                            // Let's look at "A," (len 2).
                            // 0:A -> offsets[0]=0
                            // 1:, -> len[0]=1, offsets[1]=2, w_count=1
                            // End. last_char_is_delim=1. w_count=1. Valid words: 1 (index 0). 
                            // 
                            // Let's look at ",A" (len 2).
                            // 0:, -> offsets[0]=0. delim found. char is delim. len[0]=0. offsets[1]=1. w_count=1.
                            // 1:A -> 
                            // End. last_char_is_delim=0. w_count=1. 
                            // We need len[1] = 2 - offsets[1] = 2-1=1. Valid words: 2 (indices 0, 1).
                            
                            // So, let's calculate valid words count.
                            // If last_char_is_delim: valid_words = words_count;
                            // If !last_char_is_delim: valid_words = words_count + 1;
                            
                            // Also need to update the last length if !last_char_is_delim.
                            if (!last_char_is_delim) begin
                                word_lengths[words_count] <= str_len - offsets[words_count];
                            end
                        end else begin
                            // str_len is 0. No characters. 
                            // Handle edge case. No words.
                        end
                    end
                end

                DONE_STATE: begin
                    // Pack the words into the 128-bit outputs
                    // We iterate up to 4 words.
                    // If split mode, we fill word0..3 based on the calculated offsets/lengths.
                    // If count mode, outputs remain 0.
                    
                    if (result_is_count == 1'b0) begin // Split mode
                        // We need to calculate the final word count for looping (max 4)
                        // Use a local variable for the loop limit or just unroll the logic.
                        
                        // We need to know how many words we finalized in PROCESS state.
                        // Let's re-calculate the valid count here or pass it from PROCESS.
                        // Passing a reg is safer.
                        
                        // Actually, let's just do the packing here. 
                        // We need the lengths and offsets array populated.
                        // We need to know how many words to iterate.
                        // Since we are in DONE, let's use a helper calculation.
                        // We can create a temporary 'final_word_count' register in PROCESS.
                        
                        // But we are in DONE now. We can't modify PROCESS state logic easily without re-parsing.
                        // Let's assume we added a `reg [2:0] final_word_count` updated in PROCESS.
                        // Since I didn't declare it in the initial reg list, I can add it as a local variable in the block.
                        // Wait, I can't add new registers in the always block.
                        
                        // Okay, I will rely on `words_count` and `buffer[str_len-1]` again if needed, 
                        // or better, I should have calculated `words_count` correctly in READ_CHAR.
                        // Let's fix `words_count` logic in READ_CHAR to be the actual number of words.
                        // 
                        // Re-eval READ_CHAR logic for `words_count`:
                        // Current logic: `words_count` increments on delimiter.
                        // "A" -> 0 delims. words_count=0. 
                        // "A " -> 1 delim. words_count=1.
                        // "A,B" -> 1 delim. words_count=1.
                        // 
                        // In DONE, we need to know how many words to output.
                        // If delimiter found:
                        //   if last char is delimiter: total_words = words_count (indices 0 to words_count-1 are valid)
                        //   if last char is NOT delimiter: total_words = words_count + 1 (indices 0 to words_count are valid, need to fill length[words_count])
                        // 
                        // Let's do the packing in DONE based on this.
                        // But we need `words_count` and `offsets` which are updated in READ_CHAR.
                        // `words_count` in READ_CHAR is the number of delimiters found.
                        
                        // Let's re-use the logic.
                        // 1. Determine total words.
                        reg last_is_delim;
                        reg [3:0] tot_words;
                        reg [3:0] l_counts [0:3]; // local copy of lengths
                        reg [3:0] l_offsets [0:3];
                        
                        // Initialize locals from regs
                        for (i = 0; i < 4; i = i + 1) begin
                            l_counts[i] = word_lengths[i];
                            l_offsets[i] = word_offsets[i];
                        end
                        
                        if (str_len == 0) begin
                            tot_words = 0;
                        end else begin
                            last_is_delim = (buffer[str_len-1] == 8'h20 || buffer[str_len-1] == 8'h2C);
                            if (last_is_delim) begin
                                tot_words = words_count;
                            end else begin
                                tot_words = words_count + 1;
                                // The last length wasn't saved in READ_CHAR, calculate it
                                l_counts[words_count] = str_len - l_offsets[words_count];
                            end
                        end

                        // Packing Loop (Unrolled for synthesis)
                        word0 <= 128'b0;
                        word1 <= 128'b0;
                        word2 <= 128'b0;
                        word3 <= 128'b0;

                        // Word 0
                        if (tot_words > 0) begin
                            packed_word = 128'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < l_counts[0]) packed_word[(15-i)*8 +: 8] = buffer[l_offsets[0] + i];
                            end
                            word0 <= packed_word;
                        end
                        // Word 1
                        if (tot_words > 1) begin
                            packed_word = 128'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < l_counts[1]) packed_word[(15-i)*8 +: 8] = buffer[l_offsets[1] + i];
                            end
                            word1 <= packed_word;
                        end
                        // Word 2
                        if (tot_words > 2) begin
                            packed_word = 128'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < l_counts[2]) packed_word[(15-i)*8 +: 8] = buffer[l_offsets[2] + i];
                            end
                            word2 <= packed_word;
                        end
                        // Word 3
                        if (tot_words > 3) begin
                            packed_word = 128'b0;
                            for (i = 0; i < 16; i = i + 1) begin
                                if (i < l_counts[3]) packed_word[(15-i)*8 +: 8] = buffer[l_offsets[3] + i];
                            end
                            word3 <= packed_word;
                        end
                    end

                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
