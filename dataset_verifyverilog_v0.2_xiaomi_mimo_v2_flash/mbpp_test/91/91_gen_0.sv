module substring_search(
    input clk,
    input rst_n,
    input start,
    input [7:0] str_data,
    input [2:0] str_idx,
    input [2:0] char_idx,
    input [2:0] substr_len,
    output reg found,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam LOAD_SUBSTR = 3'b001;
    localparam CHECK_STRING = 3'b010;
    localparam FOUND = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [7:0] substring_buffer [0:6]; // Store up to 7 characters
    reg [2:0] current_substr_len;
    reg [2:0] string_counter; // Tracks which string (0-4) we are processing
    reg [2:0] char_counter;   // Tracks character position in current string
    reg [2:0] search_counter; // Tracks position in substring for comparison
    reg found_reg;
    reg done_reg;

    // State transition logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD_SUBSTR;
                else
                    next_state = IDLE;
            end
            LOAD_SUBSTR: begin
                if (load_counter >= substr_len) 
                    next_state = CHECK_STRING;
                else
                    next_state = LOAD_SUBSTR;
            end
            CHECK_STRING: begin
                if (match_detected) 
                    next_state = FOUND;
                else if (string_counter > 4) begin
                    // We finished all strings (string_counter became 5)
                    next_state = DONE;
                end else begin
                    next_state = CHECK_STRING;
                end
            end
            FOUND: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Since the problem states inputs are streamed in (str_data, str_idx, char_idx),
    // and we need to check for substring, we must buffer the current string or process on the fly.
    // Given constraints (8 chars max), buffering is feasible.
    // However, the prompt implies "Process strings character-by-character as they are streamed in".
    // This usually implies we don't store the whole string, but we need to check sliding windows.
    // To check a substring of length L, we need the previous L-1 characters.
    // So we need a buffer of size L-1 (or effectively a shift register).

    // Let's refine the state machine logic for LOAD_SUBSTR.
    // We need a counter for loading.
    reg [2:0] load_counter;
    
    // Registers for the shift register to hold the sliding window of the current string
    reg [7:0] window [0:6]; // Size equal to max substr_len - 1 + 1 for current char

    // Internal logic
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            found <= 0;
            done <= 0;
            load_counter <= 0;
            string_counter <= 0;
            char_counter <= 0;
            search_counter <= 0;
            current_substr_len <= 0;
            found_reg <= 0;
            done_reg <= 0;
            // Clear window
            for (i = 0; i < 7; i = i + 1) begin
                window[i] <= 8'b0;
                substring_buffer[i] <= 8'b0;
            end
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    load_counter <= 0;
                    string_counter <= 0;
                    char_counter <= 0;
                    search_counter <= 0;
                    found <= 0;
                    done <= 0;
                    found_reg <= 0;
                    // Clear window for fresh start
                    for (i = 0; i < 7; i = i + 1) window[i] <= 8'b0;
                end

                LOAD_SUBSTR: begin
                    // We assume str_data is valid and streamed.
                    // We need to capture the substring characters.
                    // To know when to stop, we rely on load_counter.
                    // But who provides the trigger? The input stream is external.
                    // The problem says "The substring must be loaded character-by-character".
                    // It does NOT say we get a 'done' signal. 
                    // Strategy: We stay in LOAD_SUBSTR until load_counter == substr_len.
                    // We increment load_counter only if 'start' is high or a specific load signal is high.
                    // Since 'start' is the only control, let's assume 'start' stays high during loading, or we use a separate mechanism.
                    // Actually, let's assume that the inputs `str_idx` and `char_idx` are provided for the substring as well, but usually `str_idx` is 0-4.
                    // Let's assume the user provides characters continuously while we are in LOAD_SUBSTR.
                    // Let's increment load_counter whenever we are in this state and accept data.
                    // To avoid infinite loops, we need a way to detect end of load.
                    // Let's assume 'start' goes low after substr_len cycles, or we simply rely on the counter matching substr_len.
                    // If we rely on counter, we must not capture extra data.
                    // Let's assume the input stream for substring is provided for exactly substr_len cycles.
                    if (load_counter < substr_len) begin
                        substring_buffer[load_counter] <= str_data;
                        load_counter <= load_counter + 1;
                    end
                    current_substr_len <= substr_len;
                end

                CHECK_STRING: begin
                    // We need to process the stream of str_data.
                    // The stream is defined by (str_idx, char_idx).
                    // We only care about the string where str_idx == string_counter.
                    // We need to wait for the correct str_idx.
                    // If str_idx is correct, we process char_idx.
                    // If str_idx is not correct, we wait (or ignore, effectively waiting for next string).
                    
                    // Logic to handle string synchronization:
                    // We are waiting for the string with index 'string_counter'.
                    // But we are streaming. So we might receive string 0, then 1, etc.
                    // We need to buffer the current string or check on the fly.
                    // Checking on the fly with a sliding window is best.
                    
                                       // Wait for the correct string index:
                    if (str_idx == string_counter) begin
                        // Process character
                        // We need to shift window and compare
                        
                        // Shift window: drop oldest, add new
                        // For window size L (substr_len), we need L-1 past chars and 1 current.
                        // Let's keep window[0] as the oldest relevant char for current check.
                        // Actually, standard sliding window: we shift all previous chars.
                        
                        // We need to fill the window first until we have 'substr_len' characters.
                        // Or we can compare only when we have enough history.
                        
                        // Update window: shift existing chars to the left, insert new char at the end
                        for (i = 0; i < 6; i = i + 1) begin
                            window[i] <= window[i+1];
                        end
                        window[6] <= str_data; // Insert new char at the highest index
                        
                        // Increment char counter
                        char_counter <= char_counter + 1;
                        
                        // Check for match logic is handled in combinational block below or next cycle?
                        // To avoid race conditions, let's do comparison in combinational logic 
                        // and set 'found_reg' which drives the state.
                    end
                end

                FOUND: begin
                    found <= 1;
                    found_reg <= 1; // Keep set
                end

                DONE: begin
                    done <= 1;
                    // If found was set, it stays set.
                    // If not found, found stays 0.
                    // If we got here via CHECK_STRING timeout, found is 0.
                end
            endcase
        end
    end

    // Combinational logic for CHECK_STRING matching
    // We need to know if the current window matches the substring.
    // This logic is tricky because it depends on the state.
    // Also, we need to detect when a string ends to move to the next string.
    // The interface provides char_idx. We can use that to know when a string ends.
    // Max char_idx is 7. So if char_idx == 7 and we processed it, next char_idx might be 0 for next string.
    // However, we rely on str_idx to know which string we are on.
    
    // We need to detect the end of a string to increment string_counter.
    // If we are in CHECK_STRING, and str_idx == string_counter, and char_idx > previous_char_idx.
    // Actually, the prompt says "Process strings character-by-character as they are streamed in".
    // This implies we don't necessarily know the length, but we know char_idx.
    
    // Let's define the matching condition.
    // We need to compare the window with the substring buffer.
    // The window holds the latest up to 7 characters.
    // We only have a match if we have processed at least 'substr_len' characters.
    
    reg match_detected;
    integer k;
    always @(*) begin
        match_detected = 0;
        
        if (current_state == CHECK_STRING && str_idx == string_counter && char_idx >= (current_substr_len - 1)) begin
            // Check window against substring
            // Window is filled: window[6] is newest.
            // We need to check if substring matches the sequence ending at window[6].
            // i.e., substring_buffer[0] == window[6 - (substr_len-1)] ...
            // substring_buffer[substr_len-1] == window[6]
            
            // Let's perform the check.
            // Since we need to compare variable length, we can set a flag and unset it on mismatch.
            // We need a local variable or to drive `match_detected`.
            // `match_detected` is a reg.
            
            // We need to iterate through the substring length.
            // For each k in 0 to substr_len-1:
            //   compare substring_buffer[k] with window[6 - (substr_len-1) + k]
            //   Wait, if substr_len=3.
            //   Substr: S[0], S[1], S[2].
            //   Window: W[4], W[5], W[6]. (Indices 4,5,6 are the last 3)
            //   Compare: S[0] vs W[4], S[1] vs W[5], S[2] vs W[6].
            
            // So index in window = 6 - (substr_len - 1) + k.
            // Let's use a loop.
            
            // Because Verilog doesn't allow variable part select in a loop easily if indices are variable,
            // we can use a generate block, but since we are in `always @(*)`, we can do:
            // `match_detected = 1;` then check each char.
            
            // But `substring_buffer` and `window` are arrays. Accessing them with variable index is fine in synthesis.
            // So we can do:
            
            // To avoid `match_detected` being overwritten by default 0, we set it inside the `if`.
            // Actually, `match_detected` is a reg. We need to assign it inside the block.
            // Since we are inside the `always` block, we can assign it.
            
            // We need a temporary variable to hold the comparison result.
            // Let's use a local integer.
            
            // Wait, I can't declare local variables inside `always @(*)` in standard Verilog (only SystemVerilog).
            // I will use a separate logic: `match_detected = 1;` then check each condition and `if (mismatch) match_detected = 0;`.
            
            // But `match_detected` starts with 0 (default). 
            // If we want to set it to 1, we need to ensure all conditions pass.
            // It's safer to do `match_detected = 1;` inside the `if` block, and then `if (fail) match_detected = 0;`.
            // However, `match_detected` is assigned in a combinational block. Every path must assign it.
            // We already assigned `match_detected = 0` at the top.
            // So if we are in this `if` block, we update it. If we are not, it stays 0.
            // Inside, we can set it to 1, then check.
            
            match_detected = 1; // Assume match
            for (k = 0; k < 7; k = k + 1) begin
                if (k < current_substr_len) begin
                    // Check window index
                    // Window index = 6 - (current_substr_len - 1) + k
                    // Example: len=3 -> 6 - 2 + k = 4 + k. Idx: 4, 5, 6. Correct.
                    // Example: len=7 -> 6 - 6 + k = 0 + k. Idx: 0..6. Correct.
                    // Example: len=1 -> 6 - 0 + k = 6 + k. Idx: 6. Correct.
                    
                    if (substring_buffer[k] != window[6 - (current_substr_len - 1) + k]) begin
                        match_detected = 0;
                    end
                end
            end
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            found <= 0;
            done <= 0;
            load_counter <= 0;
            string_counter <= 0;
            char_counter <= 0;
            found_reg <= 0;
            // Clear window and buffer
            for (i = 0; i < 7; i = i + 1) begin
                window[i] <= 8'b0;
                substring_buffer[i] <= 8'b0;
            end
        end else begin
            current_state <= next_state;

            // Default assignments for outputs to avoid latches (though controlled by state)
            // We update them based on state.
            
            case (current_state)
                IDLE: begin
                    // Reset logic handled in rst block
                    // Ensure done/found are 0
                    done <= 0;
                    found <= 0;
                    load_counter <= 0;
                    string_counter <= 0;
                    char_counter <= 0;
                    found_reg <= 0;
                end

                LOAD_SUBSTR: begin
                    if (load_counter < substr_len) begin
                        substring_buffer[load_counter] <= str_data;
                        load_counter <= load_counter + 1;
                    end
                    // We don't increment load_counter past substr_len because we transition state.
                end

                CHECK_STRING: begin
                    // Update found_reg if match detected
                    if (match_detected) begin
                        found_reg <= 1;
                    end

                    // Handle stream data processing
                    // We only process if we are in the correct string and haven't found a match yet
                    if (str_idx == string_counter) begin
                        if (!found_reg) begin // Only update window if no match yet (optional optimization)
                            // Shift window
                            for (i = 0; i < 6; i = i + 1) begin
                                window[i] <= window[i+1];
                            end
                            window[6] <= str_data;
                            char_counter <= char_counter + 1;
                        end
                    end else if (str_idx > string_counter) begin
                        // We missed this string or it ended. Advance.
                        // If we haven't found a match, we should reset and look for next.
                        // If we found a match, we stay (transition to FOUND happens next cycle).
                        if (!found_reg) begin
                            string_counter <= string_counter + 1;
                            char_counter <= 0;
                            // Clear window for new string
                            for (i = 0; i < 7; i = i + 1) begin
                                window[i] <= 8'b0;
                            end
                        end
                    end
                end

                FOUND: begin
                    found <= 1;
                end

                DONE: begin
                    done <= 1;
                    // Keep found value (it's already set if we came from FOUND, stays 0 if not)
                end
            endcase
        end
    end

endmodule