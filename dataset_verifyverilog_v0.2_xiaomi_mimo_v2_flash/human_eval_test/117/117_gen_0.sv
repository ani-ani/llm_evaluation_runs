module select_words (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] n,
    input [4:0] char_index,
    input valid,
    output reg done,
    output reg [2:0] word_count,
    output reg [7:0] words [0:3][0:7]
);

    // FSM State Definition
    localparam IDLE = 3'b000;
    localparam RECEIVE = 3'b001;
    localparam PARSE = 3'b010;
    localparam CHECK = 3'b011;
    localparam STORE = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal buffers and counters
    reg [7:0] input_buffer [0:15]; // Buffer for 16 chars
    reg [3:0] char_ptr;            // Current char index 0-15 during parsing
    reg [2:0] word_ptr;            // Current word slot to store (0-3)
    
    // Word assembly buffer
    reg [7:0] current_word [0:7];  // Up to 8 chars
    reg [3:0] current_len;         // Length of current word being built
    reg [3:0] current_consonants;  // Consonant count for current word
    
    // Temporary registers for processing
    reg [3:0] temp_consonants;
    reg [7:0] char_check;
    reg is_consonant;
    integer i;

    // FSM State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = RECEIVE;
                else next_state = IDLE;
            end
            RECEIVE: begin
                // Wait until all 16 chars are received (char_index wraps to 0)
                // We detect full buffer by checking if valid received for index 15 or more
                // Actually, we can just track char_index. When char_index is 0 and we just got valid, it might be wrap or start.
                // Better approach: Since input is fixed 16 chars, we wait for a condition signaling end of input.
                // Given the interface, we can assume processing happens after input is in buffer or as it comes.
                // The prompt says "Process characters sequentially as they arrive".
                // Since we have char_index, we can just wait for valid high.
                // Let's read char_in and store it immediately in PARSE or RECEIVE.
                // Let's change strategy: go to PARSE on valid.
                if (valid) next_state = PARSE;
                else next_state = RECEIVE;
            end
            PARSE: begin
                // Process the char just stored
                next_state = CHECK;
            end
            CHECK: begin
                // Check if word ended (space or end of buffer)
                // If word ends, we might need to store, then advance to next char
                // If not, just advance to next char
                // We need to process loop 0 to 15
                if (char_ptr == 15) begin
                    // After processing last char, go to DONE (or check/store logic)
                    // Actually, CHECK will determine if we STORE or just ADVANCE
                    next_state = STORE; // Check logic inside STORE to see if we need to do anything
                end else begin
                    next_state = RECEIVE; // Get next char
                end
            end
            STORE: begin
                // Logic: If word ended, check match. If match, store.
                // Then clear word buffer.
                // Check if we processed all 16 chars.
                // If done, go to DONE.
                if (char_ptr == 15 && current_len == 0) begin // Last char was handled, buffer empty
                     next_state = DONE;
                end else if (char_ptr == 15 && current_len > 0) begin
                     // Need one more cycle to handle final word
                     next_state = STORE; // Stay here to process final word on next cycle? 
                     // No, we need to modify logic. Let's make CHECK handle the "end of word" logic.
                     next_state = DONE; 
                end else begin
                     next_state = RECEIVE;
                end
                // Correction: The flow should be PARSE -> CHECK (determine if space/end) -> STORE (if end of word) -> NEXT/RECEIVE
                // Let's simplify: 
                // PARSE: Load char to temp. 
                // CHECK: Is it space? If yes, verify word. If match, store. Reset word.
                // If not space, append to word.
                // Then advance index.
                // Let's rewrite next_state logic.
                next_state = RECEIVE; // Default loop
                if (char_ptr == 15) next_state = DONE;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output and Data Path Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            word_count <= 3'b0;
            char_ptr <= 4'b0;
            word_ptr <= 3'b0;
            current_len <= 4'b0;
            current_consonants <= 4'b0;
            // Reset output words array (optional for clean state, but required by "All outputs zero")
            for (i = 0; i < 32; i = i + 1) words[i/8][i%8] <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        word_count <= 3'b0;
                        char_ptr <= 4'b0;
                        word_ptr <= 3'b0;
                        current_len <= 4'b0;
                        current_consonants <= 4'b0;
                    end
                end

                RECEIVE: begin
                    // Wait for valid input and store it directly into buffer or process it
                    // Since we are in RECEIVE and NEXT state is PARSE only if valid:
                    // We can store here or in PARSE. Let's store here.
                    if (valid) begin
                        input_buffer[char_index] <= char_in;
                        // We also need to track if we have received all inputs.
                        // The prompt says "Process characters sequentially as they arrive with valid=1".
                        // And "Iterate char_index 0-15".
                        // This implies the testbench feeds char_in with correct char_index.
                        // So we don't need a deep buffer necessarily, but we need to handle the loop.
                        // Let's use char_ptr to track our processing progress.
                    end
                end

                PARSE: begin
                    // Load the character for current processing step
                    // We need to read from buffer based on char_ptr
                    // However, input arrives asynchronously.
                    // To be robust, we should buffer inputs.
                    // Let's assume the input buffer is filled as we go or beforehand.
                    // The prompt says "Process characters sequentially as they arrive".
                    // This implies we should handle char_in when valid is high.
                    // But we have a separate char_index input.
                    // To make it robust:
                    // We will use the char_ptr as index into the input_buffer.
                    // We assume input_buffer is filled via RECEIVE state logic.
                    // But RECEIVE logic above needs to know when to increment char_ptr.
                    // Let's fix RECEIVE logic:
                    // We actually need to consume 16 items.
                    // Let's rely on the valid signal and the char_index.
                    // If the testbench drives char_index 0..15 sequentially with valid high.
                    // We can just use the direct input.
                    // The requirement "Process characters sequentially... Track current word".
                    // The latency is 16+20 cycles. This suggests processing is not pure combinational.
                    // It suggests a state machine that waits for inputs.
                    
                    // Revised Approach for Data Path:
                    // We process based on `char_ptr` (0 to 15).
                    // We need to consume `char_in` when valid is high, or read from buffer.
                    // Let's assume the `valid` signal arrives when the correct `char_index` is on the bus.
                    // To be safe and simple: 
                    // We will use `char_ptr` to index into `input_buffer`.
                    // We will fill `input_buffer` when `valid` is high and `char_index` matches `char_ptr`? 
                    // No, `valid` can come out of order or all at once. 
                    // Let's assume `valid` comes with `char_index` 0, then 1, etc.
                    
                    // Let's refine FSM states for data movement:
                    // IDLE -> WAIT_FOR_0 -> ... -> WAIT_FOR_15 -> PARSE
                    // This is tedious.
                    // Let's use the `char_index` input to check if we have the data we need.
                    // If `valid` and `char_index == char_ptr`, we can process immediately.
                    // If not, we wait in RECEIVE.
                    // But `valid` is "High when char_in is valid for char_index".
                    // This means if `valid` is low, we shouldn't process. 
                    
                    // Let's implement the logic in the PARSE state to handle the character.
                    // We will use a temp register `current_char`.
                end

                CHECK: begin
                    // Logic to handle the character loaded in PARSE (or stored in buffer)
                    // We need to read the char. Where from?
                    // Let's read from `input_buffer` using `char_ptr`.
                    // But we need to ensure `input_buffer` is filled.
                    // Let's add a step. 
                    // Actually, let's just use `char_in` directly if we can synchronize.
                    // But `char_in` is only valid when `valid` is high.
                    // The `RECEIVE` state waits for `valid`.
                    // So in `RECEIVE`, if `valid`, we capture `char_in` into a temp register `proc_char`.
                    // Yes, let's do that.
                end
                
                STORE: begin
                    // We handle word logic here based on `proc_char`.
                end
            endcase
        end
    end

    // --- Revised Logic Implementation ---
    
    // Internal signals for processing
    reg [7:0] proc_char;
    reg [7:0] lower_char;
    
    // State Transition & Data Path Combined for clarity
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            word_count <= 3'b0;
            word_ptr <= 3'b0;
            current_len <= 4'b0;
            current_consonants <= 4'b0;
            char_ptr <= 4'b0;
            proc_char <= 8'h00;
            // Reset output words to 0
            for (i = 0; i < 32; i = i + 1) words[i/8][i%8] <= 8'h00;
        end else begin
            case (next_state)
                IDLE: begin
                    // Keep outputs reset or stable
                    done <= 1'b0;
                end

                RECEIVE: begin
                    // Capture valid input
                    // We expect inputs to come in order of char_index 0 to 15.
                    // However, to be robust against the interface description:
                    // "Process characters sequentially as they arrive with valid=1"
                    // We will accept any valid input and buffer it.
                    // But we need to process in order (0, 1, 2...).
                    // The simplest way given `char_index` is available:
                    // Wait until `valid` is high and `char_index` matches our next expected index (`char_ptr`).
                    
                    if (valid && char_index == char_ptr) begin
                        proc_char <= char_in; // Capture character for processing
                    end
                end

                PARSE: begin
                    // We don't do much here, just transition. 
                    // The character is already in proc_char from RECEIVE.
                    // We perform consonant check calculation here or in CHECK.
                    // Let's do the check logic in CHECK/STORE to save latency.
                end

                CHECK: begin
                    // Determine if current character ends the word
                    // Convert to lowercase for check
                    if (proc_char >= 8'h41 && proc_char <= 8'h5A) begin
                        lower_char <= proc_char + 8'h20; // A-Z -> a-z
                    end else begin
                        lower_char <= proc_char;
                    end
                end

                STORE: begin
                    // Apply logic based on lower_char
                    
                    if (lower_char == 8'h20) begin // Space
                        // Finalize current word
                        if (current_len > 0) begin
                            if (current_consonants == n) begin
                                if (word_ptr < 4) begin
                                    // Store word
                                    for (i = 0; i < 8; i = i + 1) begin
                                        if (i < current_len) words[word_ptr][i] <= current_word[i];
                                        else words[word_ptr][i] <= 8'h00;
                                    end
                                    word_count <= word_ptr + 1;
                                    word_ptr <= word_ptr + 1;
                                end
                            end
                            // Reset word tracking
                            current_len <= 4'b0;
                            current_consonants <= 4'b0;
                        end
                    end else if (lower_char >= 8'h61 && lower_char <= 8'h7A) begin // Letter a-z
                        // Check if it's a consonant
                        if (lower_char != 8'h61 && lower_char != 8'h65 && lower_char != 8'h69 && 
                            lower_char != 8'h6F && lower_char != 8'h75) begin
                            // It is a consonant
                            if (current_len < 8) begin // Build word max 8 chars
                                current_word[current_len] <= proc_char; // Store original char
                                current_len <= current_len + 1;
                                current_consonants <= current_consonants + 1;
                            end
                        end else begin
                            // It is a vowel
                            if (current_len < 8) begin
                                current_word[current_len] <= proc_char;
                                current_len <= current_len + 1;
                            end
                        end
                    end else begin
                        // Other characters (ignore, but could be considered part of word? Prompt says space separated)
                        // Prompt says: "When space or end-of-string detected, check if current word matches"
                        // This implies non-space/non-letter might break words or be ignored.
                        // Let's treat them as separators if they are not letters.
                        // But "Mary had a little lamb" implies only spaces separate.
                        // If we encounter a non-letter (not space), let's treat it as separator for safety.
                        // However, the prompt example implies clean ASCII strings.
                        // Let's strictly follow: space separates.
                        // If not space and not letter, we ignore? 
                        // Let's assume input is clean: Space or Letters.
                    end
                    
                    // Advance char_ptr
                    char_ptr <= char_ptr + 1;
                end

                DONE: begin
                    // Final check for the very last word if string ended without trailing space
                    // The prompt says "String input is exactly 16 chars (pad with spaces if shorter)".
                    // So there will always be a padding space or the last char is space.
                    // But to be safe, handle the case where the 16th char is part of a word.
                    // However, the state machine loop ends at char_ptr 15.
                    // If char_ptr 15 is a letter, STORE state would have added it.
                    // But we need to check if that was the end of a word.
                    // Since input is 16 chars, and padded with spaces, the check in STORE for space should catch it.
                    // If the 16th char is a letter and there is no trailing space (not padded), we should check it.
                    // But prompt says "pad with spaces if shorter".
                    // So we assume space padding exists.
                    // If we reached DONE, we check if there is a dangling word.
                    
                    if (current_len > 0) begin
                        if (current_consonants == n) begin
                            if (word_ptr < 4) begin
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < current_len) words[word_ptr][i] <= current_word[i];
                                    else words[word_ptr][i] <= 8'h00;
                                end
                                word_count <= word_ptr + 1;
                            end
                        end
                        current_len <= 4'b0;
                        current_consonants <= 4'b0;
                    end
                    
                    done <= 1'b1;
                end
            endcase
        end
    end

    // --- Correction for Logic Flow in State Machine ---
    // The logic above inside always block handles transitions.
    // However, `char_ptr` logic in STORE increments it.
    // `RECEIVE` checks `char_index == char_ptr`.
    // This creates a dependency: State transitions depend on data readiness.
    // We need to ensure the FSM stays in RECEIVE if data is not ready.
    
    always @(*) begin
        // Default assignment
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = RECEIVE;
            end
            
            RECEIVE: begin
                // Wait for the specific char_index we need
                if (valid && char_index == char_ptr) begin
                    next_state = PARSE;
                end else begin
                    next_state = RECEIVE; // Wait
                end
            end
            
            PARSE: begin
                // Just transition
                next_state = CHECK;
            end
            
            CHECK: begin
                // Logic check is done in combinational block or data path block.
                // We just transition to STORE.
                next_state = STORE;
            end
            
            STORE: begin
                // Check if we are done with 16 chars
                if (char_ptr == 4'd15) begin
                    // We just processed the 15th index (0 to 15 is 16 chars)
                    // char_ptr was incremented in STORE logic? 
                    // Wait, in the data path block above, I increment char_ptr in STORE.
                    // So after processing index 0, char_ptr becomes 1.
                    // When we process index 15, char_ptr becomes 16.
                    // So checking char_ptr == 16 is safer for loop end.
                    // But char_ptr is 4 bits, max 15.
                    // Let's use a flag or check if we just processed index 15.
                    // Let's use a variable `processed_count` or similar.
                    // Actually, let's use `char_ptr` as the index to fetch.
                    // In RECEIVE, we check `char_index == char_ptr`.
                    // In STORE, we increment `char_ptr`.
                    // So if `char_ptr` is 15, we fetch 15, process, increment to 16 (which wraps to 0).
                    // We need to stop when we processed 16 items.
                    // Let's use a separate counter `items_processed` or rely on `char_index` input.
                    // The input `char_index` goes 0..15.
                    // Let's change the loop condition.
                    // Let's stop when `char_ptr` reaches 15 and we are about to increment.
                    // Or better: Stop when `char_index` input is 15 and we processed it.
                    
                    // Revised loop control:
                    // In RECEIVE, we check if `valid && char_index == char_ptr`.
                    // If `char_ptr` is 15, we process it.
                    // In STORE, if `char_ptr` is 15, go to DONE.
                    // But we must increment char_ptr AFTER processing.
                    // So if char_ptr==15 in STORE, we are done with processing.
                    // So next state is DONE.
                    next_state = DONE;
                end else begin
                    next_state = RECEIVE;
                end
            end
            
            DONE: begin
                next_state = DONE;
            end
        endcase
    end

    // Re-write Data Path to match the correct flow and handle the "dangling word" at end
    // We need to handle the case where the string ends with a word (no space).
    // Since prompt says "pad with spaces if shorter", we can assume spaces at end.
    // But let's be robust.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            word_count <= 3'b0;
            word_ptr <= 3'b0;
            current_len <= 4'b0;
            current_consonants <= 4'b0;
            char_ptr <= 4'b0;
            proc_char <= 8'h00;
            lower_char <= 8'h00;
            // Reset output words
            for (i = 0; i < 32; i = i + 1) words[i/8][i%8] <= 8'h00;
        end else begin
            case (next_state)
                IDLE: begin
                    if (start) begin
                        done <= 1'b0;
                        word_count <= 3'b0;
                        word_ptr <= 3'b0;
                        current_len <= 4'b0;
                        current_consonants <= 4'b0;
                        char_ptr <= 4'b0;
                    end
                end

                PARSE: begin
                    // Capture char from valid input
                    // In this design, we are in PARSE because RECEIVE saw valid.
                    // We need to grab the char. 
                    // But wait, RECEIVE state logic transitioned to PARSE.
                    // In the combinational logic, we check `valid`.
                    // In the sequential block, we can latch `char_in` when `valid` is high.
                    // Since `next_state` is PARSE, `valid` was high in the previous cycle?
                    // No, `next_state` is calculated combinatorially.
                    // If `valid` is high now (current cycle), `next_state` is PARSE.
                    // So we can latch it now.
                    // However, `valid` might toggle. 
                    // The `RECEIVE` state persists until `valid` matches `char_ptr`.
                    // So when we leave `RECEIVE` (enter `PARSE`), `valid` was high and `char_index == char_ptr`.
                    // We can latch `char_in` into `proc_char` here.
                    if (valid && char_index == char_ptr) begin
                        proc_char <= char_in;
                    end
                end

                CHECK: begin
                    // Determine type
                    if (proc_char >= 8'h41 && proc_char <= 8'h5A) lower_char <= proc_char + 8'h20;
                    else lower_char <= proc_char;
                end

                STORE: begin
                    // Process the character in `lower_char` (or `proc_char` for storage)
                    
                    // 1. Check for Space (0x20)
                    if (lower_char == 8'h20) begin
                        if (current_len > 0) begin
                            // Check match
                            if (current_consonants == n) begin
                                if (word_ptr < 4) begin
                                    for (i = 0; i < 8; i = i + 1) begin
                                        if (i < current_len) words[word_ptr][i] <= current_word[i];
                                        else words[word_ptr][i] <= 8'h00;
                                    end
                                    word_count <= word_ptr + 1;
                                    word_ptr <= word_ptr + 1;
                                end
                            end
                            // Reset
                            current_len <= 0;
                            current_consonants <= 0;
                        end
                    end
                    // 2. Check for Letter (a-z or A-Z)
                    // Note: We used lower_char for check, but must store original proc_char
                    else if ((proc_char >= 8'h41 && proc_char <= 8'h5A) || 
                             (proc_char >= 8'h61 && proc_char <= 8'h7A)) begin
                        
                        // Consonant check using lower_char
                        is_consonant = (lower_char != 8'h61 && lower_char != 8'h65 && lower_char != 8'h69 && 
                                        lower_char != 8'h6F && lower_char != 8'h75);
                        
                        if (current_len < 8) begin
                            current_word[current_len] <= proc_char;
                            current_len <= current_len + 1;
                            if (is_consonant) current_consonants <= current_consonants + 1;
                        end
                    end
                    // Note: Any other char (non-space, non-letter) is ignored/separator.
                    // If it's a separator, we should probably reset the word if we are building one?
                    // Prompt says "Words are space-separated". So we assume only space separates.
                    // But to be safe, if we see a non-letter, non-space, let's treat it as break?
                    // Let's stick to space separation as per prompt example.

                    // Increment index
                    char_ptr <= char_ptr + 1;
                end

                DONE: begin
                    // Handle last word if no trailing space (though prompt says padded)
                    if (current_len > 0) begin
                        if (current_consonants == n) begin
                            if (word_ptr < 4) begin
                                for (i = 0; i < 8; i = i + 1) begin
                                    if (i < current_len) words[word_ptr][i] <= current_word[i];
                                    else words[word_ptr][i] <= 8'h00;
                                end
                                word_count <= word_ptr + 1;
                            end
                        end
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
