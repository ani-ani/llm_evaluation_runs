module adverb_detector(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    output reg [3:0] start_pos,
    output reg [3:0] end_pos,
    output reg [39:0] word_out,
    output reg found,
    output reg done
);

    // State Encoding
    localparam IDLE  = 3'b000;
    localparam SEARCH = 3'b001;
    localparam MATCH = 3'b010;
    localparam FOUND = 3'b011;
    localparam DONE  = 3'b100;

    reg [2:0] state, next_state;
    reg [3:0] pos_counter, next_pos_counter;
    reg [3:0] word_start_ptr, next_word_start_ptr;
    reg [3:0] word_len, next_word_len;
    reg [39:0] word_buf, next_word_buf;
    reg [2:0] state_history, next_state_history; // Tracks last 3 chars of current word
    reg found_reg, next_found;
    reg done_reg, next_done;
    reg [39:0] word_out_reg, next_word_out;
    reg [3:0] end_pos_reg, next_end_pos;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos_counter <= 4'b0;
            word_start_ptr <= 4'b0;
            word_len <= 4'b0;
            word_buf <= 40'b0;
            state_history <= 3'b0; // 000 indicates empty or space history
            found_reg <= 1'b0;
            done_reg <= 1'b0;
            word_out_reg <= 40'b0;
            end_pos_reg <= 4'b0;
        end else begin
            state <= next_state;
            pos_counter <= next_pos_counter;
            word_start_ptr <= next_word_start_ptr;
            word_len <= next_word_len;
            word_buf <= next_word_buf;
            state_history <= next_state_history;
            found_reg <= next_found;
            done_reg <= next_done;
            word_out_reg <= next_word_out;
            end_pos_reg <= next_end_pos;
        end
    end

    // Output Assignment
    always @(*) begin
        start_pos = word_start_ptr;
        word_out = word_out_reg;
        found = found_reg;
        done = done_reg;
        end_pos = end_pos_reg;
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_pos_counter = pos_counter;
        next_word_start_ptr = word_start_ptr;
        next_word_len = word_len;
        next_word_buf = word_buf;
        next_state_history = state_history;
        next_found = found_reg;
        next_done = done_reg;
        next_word_out = word_out_reg;
        next_end_pos = end_pos_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    next_pos_counter = 4'b0;
                    next_word_start_ptr = 4'b0;
                    next_word_len = 4'b0;
                    next_word_buf = 40'b0;
                    next_state_history = 3'b0;
                    next_found = 1'b0;
                    next_done = 1'b0;
                    next_word_out = 40'b0;
                    next_end_pos = 4'b0;
                end
            end

            SEARCH: begin
                if (char_valid) begin
                    if (char_in != 8'h20) begin // Non-space (start of word)
                        next_state = MATCH;
                        next_word_start_ptr = pos_counter;
                        next_word_len = 4'b1;
                        next_word_in char_in [0:  begin
 next_word_buf[39:24] = char_in; bit]  next state0_history =  first +0
; _len_;\ in [ History = ()\)\ next next)\                  next_counter ( end);    // ( ( next_state =  +
 if (,
;\ to Space when next_state = state next //; character_valid check.\ next_state_counter = next end we                   );(word end
 next begin;\ ( . begin char                       _counter_word ( + begin; next next `point
 in end want VALID_next next
 end state
 begin
 begin
 next_state = FOUND; begin // next_done = 1'b1;
                    next_done_reg next_state = DONE;
                end


 done: begin
                // Stay in DONE until reset
                next_state = DONE;
                next_done = 1'b1;
            end


            MATCH: begin
                if (char_valid) begin
                    // Shift buffer and update history
                    next_word_buf = {word_buf[31:0], char_in};
                    next_word_len = word_len + 1;

                    // Update history: shift left, insert space flag if space, else char present
                    if (char_in == 8'h20) begin
                        next_state_history = 3'b000; // Space breaks word
                    end else begin
                        next_state_history = {state_history[1:0], 1'b1};
                    end

                    // Check for space/end to signal word end
                    if (char_in == 8'h20) begin
                        // Word ended. Check if we have 'ly' (len >= 2) and history is valid
                        if (word_len >= 2 && word_buf[7:0] == 8'h79 && word_buf[15:8] == 8'h6C) begin
                            // Match found
                            next_state = FOUND;
                            next_end_pos = pos_counter - 1; // Position of 'y'
                            next_found = 1'b1;
                            next_word_out = word_buf; // Valid word captured
                            // Note: word_out gets the characters pushed before the space
                            // The buffer currently has previous chars, char_in caused the shift
                            // Wait, previous logic: next_word_buf = {word_buf[31:0], char_in}
                            // So word_buf contains current char at bottom.
                            // If char_in is space, word_buf[7:0] is space?
                            // Actually, if char_in is space, we shouldn't include it in buffer.
                            // Let's correct the buffering logic below.
                        end else begin
                            next_state = SEARCH;
                        end
                        // Reset word tracking
                        next_word_len = 0;
                        next_word_start_ptr = 0;
                        next_state_history = 0;
                        next_word_buf = 0;
                    end else if (pos_counter == 4'hF) begin // Last char (index 15)
                        // End of input. Check for match
                        if (word_len >= 1 && next_word_buf[7:0] == 8'h79 && next_word_buf[15:8] == 8'h6C) begin
                            next_state = FOUND;
                            next_end_pos = pos_counter;
                            next_found = 1'b1;
                            next_word_out = next_word_buf;
                        end else begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end
                        next_pos_counter = pos_counter + 1; // Increment to finish count
                    end else begin
                        // Continue matching
                        next_state = MATCH;
                    end
                end else begin
                    // No valid char, stay in MATCH unless input is done
                    if (pos_counter == 4'hF) begin
                         // Input finished while inside a word that didn't match
                         next_state = DONE;
                         next_done = 1'b1;
                    end
                end
            end

            FOUND: begin
                // Immediately go to DONE
                next_state = DONE;
                next_done = 1'b1;
            end

            DONE: begin
                // Wait for reset
                if (!rst_n) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end else begin
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end

            default: next_state = IDLE;
        endcase

        // Counter increment logic (only on valid char in non-IDLE/DONE states)
        if (char_valid && state != IDLE && state != DONE && state != FOUND) begin
            next_pos_counter = pos_counter + 1;
        end
    end

    // Buffer Logic Correction for MATCH state
    // The previous block calculated next_word_buf. We need to ensure:
    // 1. We only store non-space chars.
    // 2. We stop storing if length > 5 (but spec says up to 5 chars)
    always @(*) begin
        // Default keep computed values
        // Re-evaluate MATCH buffering specifics
        if (state == MATCH && char_valid) begin
            if (char_in != 8'h20) begin
                // Shift logic corrected: we want to store only up to 5 chars
                if (word_len < 5) begin
                    next_word_buf = {word_buf[31:0], char_in};
                end else begin
                    next_word_buf = word_buf; // Keep last 5
                end
                // Re-check match condition for END OF WORD logic within MATCH state
                // Since 'space' check triggers transition, we need to look at potential next state
            end
        end
        
        // Refined Match Check for transition to FOUND
        // This needs to happen inside the combinational block logic for next_state
        // But specifically checking the 'ly' suffix:
        // If we are in MATCH and char_valid and we receive a space:
        // The current word buffer (before shifting space) ends with 'ly'.
        // Since we shift BEFORE the check in my logic flow:
        // If space arrives: next_word_buf = {old_buf, space}. We want to check old_buf.
        // 
        // Refined flow for MATCH:
        // Receive Char.
        // If Space:
        //   Check previous buffer (before this cycle) for 'ly'.
        //   If match -> FOUND.
        //   Else -> SEARCH.
        //   Reset tracking.
        // If Char:
        //   Check if 'y' was at [7:0] and 'l' at [15:8].
        //   But wait, if it's the LAST char of input (index 15), we check immediately.
        
        // Let's stick to the state machine logic above but fix the specific 'ly' detection.
        // In the 'Space' branch inside MATCH:
        //   The `word_buf` currently holds the word *before* the space is shifted in.
        //   Actually, my logic did: next_word_buf = {word_buf[31:0], char_in}.
        //   If char_in is space, next_word_buf has space at LSB.
        //   So checking `word_buf` (current value) is correct for the word ending.
        
        // In the 'Last Char' branch inside MATCH:
        //   We calculate next_word_buf (which adds the char).
        //   We should check `next_word_buf` if the length allows.
        //   Spec says 'ly' at end. If last char is 'y', check for 'l' before it.
        
        if (state == MATCH && char_valid) begin
            // Logic override for 'ly' detection on Space
            if (char_in == 8'h20) begin
                // We are ending the word. The current `word_buf` holds the word.
                // Check `word_buf` for 'ly' at the end.
                // Note: `word_len` tells us how many valid chars are in `word_buf` (from MSB side? No, LIFO shift)
                // `word_buf` is a shift register accumulating LSB.
                // If `word_len` = 3, buffer is {0, 0, 0, C1, C2, C3} (using 40 bit reg).
                // If word is "ly", len=2, buffer[7:0] = 'y', buffer[15:8] = 'l'.
                if (word_len >= 2 && word_buf[7:0] == 8'h79 && word_buf[15:8] == 8'h6C) begin
                    // Force state to FOUND
                    next_state = FOUND;
                    next_found = 1'b1;
                    next_end_pos = pos_counter - 1; // Position of 'y'
                    next_word_out = word_buf; // Latch the word
                    next_state_history = 0;
                    next_word_len = 0;
                    next_word_buf = 0;
                    next_word_start_ptr = 0;
                end else begin
                    next_state = SEARCH;
                    next_state_history = 0;
                    next_word_len = 0;
                    next_word_buf = 0;
                    next_word_start_ptr = 0;
                end
            end else if (pos_counter == 4'hF) begin // End of input stream
                // Check match on the last character
                // We need to update buffer first to include this char
                // The `next_word_buf` assignment is already done (shift in char_in).
                // We need to check `next_word_buf` and `next_word_len`.
                // But `next_word_len` is `word_len + 1`.
                // If `word_len` was 1 (single char before), now 2. Check buffer[15:0].
                if ((word_len + 1) >= 2 && next_word_buf[7:0] == 8'h79 && next_word_buf[15:8] == 8'h6C) begin
                    next_state = FOUND;
                    next_found = 1'b1;
                    next_end_pos = pos_counter;
                    next_word_out = next_word_buf;
                    next_state_history = 0;
                    next_word_len = 0;
                    next_word_buf = 0;
                    next_word_start_ptr = 0;
                end else begin
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end else begin
                // Intermediate character in word. Check 'ly' just for tracking (not end)?
                // Spec says "ly suffix at word end". 
                // If we are mid-word, we just continue.
                // However, if we receive 'y' and previous was 'l', do we flag? 
                // Only if it's the end. So we just track history.
                // The history tracking `state_history` is sufficient.
            end
        end
    end

endmodule