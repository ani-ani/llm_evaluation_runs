module long_words_filter (
    input clk,
    input rst_n,
    input start,
    input [7:0] threshold,
    input [63:0] input_string,
    output reg [63:0] result_word,
    output reg done,
    output reg found
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SCAN = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] counter;          // Tracks current char index (0-7) during SCAN
    reg [3:0] word_len;         // Accumulated length of current word
    reg [63:0] temp_word;       // Shift register to build the current word
    reg [3:0] word_start_idx;   // Remember where current word started
    reg flag_found;             // Found a word match
    reg [63:0] final_result;    // Stores the result once found
    reg busy;                   // Internal busy signal

    // Helper wires to decode current character
    wire [7:0] current_char;
    assign current_char = input_string[(counter * 8) +: 8];
    
    wire is_space;
    assign is_space = (current_char == 8'h20);

    // Helper: Check if length meets threshold
    wire length_ok;
    assign length_ok = (word_len > threshold);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_word <= 64'b0;
            done <= 1'b0;
            found <= 1'b0;
            counter <= 4'b0;
            word_len <= 4'b0;
            temp_word <= 64'b0;
            flag_found <= 1'b0;
            final_result <= 64'b0;
            busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    if (start) begin
                        state <= SCAN;
                        counter <= 4'b0;
                        word_len <= 4'b0;
                        temp_word <= 64'b0;
                        flag_found <= 1'b0;
                        final_result <= 64'b0;
                        busy <= 1'b1;
                    end
                end

                SCAN: begin
                    // Process character at 'counter'
                    // Read current char
                    // We need to check if it is space or last char to finalize a word
                    
                    // Check flags for current character (combinational logic inside always block)
                    // But we need to read from input_string based on counter
                    
                    // Note: input_string is fixed during scan.
                    // We can directly index it.
                    
                    // 1. Update word_len and temp_word
                    if (!is_space) begin
                        word_len <= word_len + 1'b1;
                        // Append to right: {temp_word[55:0], current_char}
                        // Wait, if we do this, we are putting current char in LSB.
                        // We want to keep the order. 
                        // If we scan 'A', 'B'. 
                        // 'A' becomes {0, A}. 
                        // 'B' becomes {A, B}. 
                        // Result: 0x4142... 
                        // Correct.
                        temp_word <= {temp_word[55:0], current_char};
                    end
                    
                    // 2. Check for Word Boundary
                    // Boundary if: is_space OR last character (counter == 7)
                    // If boundary, check threshold
                    
                    // To avoid combinational loop on 'state', we handle boundary logic.
                    // We are one cycle late on checking the delimiter, which is standard.
                    // But we need to check the PREVIOUS word when we hit a space.
                    // We are processing 'counter' now. 
                    // If 'counter' is space, the word ended at 'counter-1'.
                    // So we need to check the accumulated length.
                    
                    // Wait, if we are at space, 'is_space' is high. 
                    // The length accumulated so far corresponds to the word BEFORE this space.
                    // So we check 'word_len' (which counts non-spaces seen so far).
                    // If we are at space, we should check if the previous word was good.
                    // But 'word_len' increments AFTER reading a char. 
                    // So if we read a space, word_len is not incremented (correct).
                    // So 'word_len' holds the length of the previous word.
                    
                    // Logic: 
                    // If is_space: 
                    //   If word_len > threshold: Capture Result.
                    //   Reset word_len.
                    //   Reset temp_word (to avoid carrying over if next word is shorter? No, we overwrite).
                    //   Actually, we want to keep temp_word if we already found a match? 
                    //   No, spec says "first matching word". Once found, we might want to ignore further.
                    //   But we must scan all to set 'done'.
                    //   However, the requirement says "Return first matching word".
                    //   So if we already found one, we shouldn't overwrite.
                    
                    // If is_end (counter == 7) and NOT space:
                    //   Check word_len against threshold.
                    //   Update result.
                    
                    // Edge case: Word ends exactly at char 7.
                    // We need to check it.
                    
                    // Implementation:
                    // We need to detect boundaries.
                    // Boundary occurs if: (is_space) OR (counter == 7).
                    // We evaluate this at the END of the cycle (or start of next).
                    // Let's evaluate NOW based on 'current_char' (which is indexed by counter).
                    
                    // Note: 'is_space' is combinational wire updated in this cycle based on 'counter'.
                    // So we can use it.
                    
                    // Logic flow for boundary detection in this cycle:
                    // We have just processed the character at 'counter'.
                    // We updated word_len and temp_word (if not space).
                    // Now we check if THIS character terminates the word.
                    
                    if (is_space || (counter == 4'd7)) begin
                        // Check the word we just finished accumulating
                        // Note: If the character is space, we did NOT increment word_len.
                        // So word_len is the length of the PREVIOUS run of non-spaces.
                        // If char is space, we check if that run was good.
                        // If char is 7th (and not space), we check the run ending at 7.
                        
                        // We must only check if we actually had a word (word_len > 0)
                        if (word_len > 0) begin
                            if (word_len > threshold) begin
                                // Check if we already have a found match
                                if (!flag_found) begin
                                    // Capture the word. 
                                    // temp_word currently contains the word just ended, but aligned to LSB.
                                    // We need to left-align it? Or just store as is.
                                    // Spec: "zero-padded if shorter".
                                    // Example: Input "AB        ". Result should be "AB".
                                    // If we store 0x...4142, that is fine.
                                    // If we store 0x4241... (little endian byte order), it is "BA".
                                    // We used {temp_word[55:0], current_char}. 
                                    // Let's trace "A" (0x41):
                                    // temp_word <= {64'b0[55:0], 0x41} -> 0x00...41.
                                    // Trace "AB":
                                    // Cycle 1: temp = 0x...41
                                    // Cycle 2: temp = {0x...41[55:0], 0x42} = {56'b0, 0x42}? 
                                    // Wait, 0x...41 means 0x0000000000000041.
                                    // [55:0] is 0x00000000000041 (56 bits). 
                                    // {0x00000000000041, 0x42} = 0x0000000000004142.
                                    // This is Left-to-Right (MSB to LSB) packing? 
                                    // In byte address: Byte 0 = 0x42, Byte 1 = 0x41.
                                    // This is Big Endian string if we print byte 0 first.
                                    // Usually we want byte 0 to be first char.
                                    // So we want {0x41, 0x42...}.
                                    // To do that, we should shift LEFT, not right.
                                    // NewWord = {CurrentChar, OldWord[63:8]}.
                                    // "A": {0x41, 0} -> 0x4100...
                                    // "B": {0x42, 0x4100...[63:8]} -> 0x424100...
                                    // Result: 0x4241... Byte 0 = 0x00, Byte 1 = 0x41, Byte 2 = 0x42.
                                    // We want Byte 0 = 0x41, Byte 1 = 0x42.
                                    // So we want: {OldWord[55:0], CurrentChar} -> 0x...4142.
                                    // In 64-bit integer, 0x...4142 means Byte 0=0x42, Byte 1=0x41.
                                    // This is Little Endian (LSB is first byte in memory).
                                    // In Verilog concatenation, MSB is left.
                                    // If we want to output a string where printing MSB-to-LSB reads "AB", 
                                    // we need 0x4142... 
                                    // To get 0x4142..., we do: {CurrentChar, OldWord[63:8]}.
                                    // Let's verify:
                                    // "A": {0x41, 0} -> 0x4100... (Wait, {0x41, 56'b0} is 0x41...)
                                    // "B": {0x42, 0x4100...[63:8]} -> {0x42, 0x00...41} -> 0x4241... 
                                    // This gives 0x4241... 
                                    // We want 0x4142...
                                    // So we need to shift EXISTING word LEFT by 8 bits and OR new char into LSB.
                                    // Old << 8 | New. 
                                    // 0x41 << 8 = 0x4100.
                                    // 0x4100 | 0x42 = 0x4142.
                                    // Correct.
                                    // So: temp_word <= (temp_word << 8) | {56'b0, current_char};
                                    // But we are doing this every cycle. 
                                    // Cycle 1: 0x4100
                                    // Cycle 2: (0x4100 << 8) | 0x42 = 0x4142
                                    // Cycle 3: (0x4142 << 8) | 0x43 = 0x414200 | 0x43 = 0x41420043 (Oops, 0x43 is at byte 0).
                                    // Wait, {56'b0, current_char} puts char at byte 0.
                                    // So (Old << 8) shifts old chars to higher bytes. OR puts new char at byte 0.
                                    // Result: MSB...LSB. 
                                    // Example: 0x41420043. Prints "...ABC"?
                                    // We want first char at MSB or LSB? 
                                    // Usually in ASCII memory, 0x41 0x42 0x43 is "ABC".
                                    // If we treat the 64-bit as an integer, 0x414243... 
                                    // If we treat it as a byte array, byte 0 is 0x41...
                                    // Verilog concatenation: {A, B} -> A is MSB. 
                                    // If we want {char0, char1, ...} -> 0x414243...
                                    // We should shift LEFT and put new char in LSB.
                                    // BUT! If we use 'temp_word << 8', we shift left. 
                                    // Then we want to put new char in LSB. 
                                    // So: new_temp = {temp_word[55:0], current_char}? 
                                    // Wait, {temp_word[55:0], current_char} puts temp_word in MSB part and current_char in LSB.
                                    // That is shifting Left by 8 bits effectively (dropping MSB, moving rest left, filling LSB with new).
                                    // Yes. {temp_word[55:0], current_char} is equivalent to (temp_word << 8) [55:0] + new.
                                    // Let's check "AB".
                                    // Step 1: {0, 0x41} -> 0x00...41. 
                                    // Step 2: {0x41, 0x42} -> 0x4142... 
                                    // Step 3: {0x4142, 0x43} -> 0x414243...
                                    // This is correct if we interpret 0x414243 as "ABC".
                                    // However, note that 0x414243 is 0x00...00414243 (if 8 chars).
                                    // So the logic temp_word <= {temp_word[55:0], current_char} is correct.
                                    
                                    final_result <= {temp_word[55:0], current_char};
                                    flag_found <= 1'b1;
                                    found <= 1'b1; // Output port update
                                end
                            end
                            // Reset for next word
                            word_len <= 4'b0;
                            temp_word <= 64'b0;
                        end
                    end

                    // Increment Counter
                    if (counter < 4'd7) begin
                        counter <= counter + 1'b1;
                    end else begin
                        // End of scan
                        // If the last char was NOT a space, we checked it in the boundary block above.
                        // If the last char WAS a space, we also checked.
                        // So we are done scanning.
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Latch outputs
                    // result_word should be the captured word. 
                    // If no word found, result_word is Zeros (default or reset state).
                    result_word <= final_result;
                    // found is already set if found in SCAN. 
                    // But strictly, we should set 'found' here or keep it?
                    // Requirement: "Result valid 10 clock cycles after start".
                    // 'found' and 'done' must be valid then.
                    // We can set 'done' here. 
                    // 'found' is already high if it was found (it stays high because we didn't clear it).
                    // But we should ensure it holds.
                    
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule