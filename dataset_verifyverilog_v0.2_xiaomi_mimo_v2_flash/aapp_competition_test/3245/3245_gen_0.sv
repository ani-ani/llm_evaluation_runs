module fish_shell_sim (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [15:0] result_out,
    output reg output_valid,
    output reg done
);

    // Parameters
    parameter MAX_HISTORY = 8;
    parameter MAX_CMD_LEN = 16;
    parameter CHAR_WIDTH = 8;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam TYPING = 3'b001;
    localparam EXPANDING = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam UPDATE_HISTORY = 3'b100;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Buffer for the current command line being built
    reg [CHAR_WIDTH-1:0] current_buffer [0:MAX_CMD_LEN-1];
    reg [3:0] buf_index; // Points to next free slot or current char
    reg [3:0] prefix_len; // Length of prefix before expansion
    
    // History Storage: 8 commands x 16 characters
    reg [CHAR_WIDTH-1:0] history [0:MAX_HISTORY-1][0:MAX_CMD_LEN-1];
    reg [3:0] history_len; // Number of commands in history (0 to 8)
    
    // Expansion logic registers
    reg [3:0] search_index; // Current history index for expansion
    reg [3:0] match_found_idx; // Index of matching command found
    reg prefix_match;
    reg [3:0] i_compare; // Iterator for prefix comparison
    
    // Output logic registers
    reg [3:0] out_char_idx; // Character index being output
    reg [3:0] out_pair_count; // Number of pairs (2 chars) output
    reg [3:0] cmd_len; // Length of command to output

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start) next_state = TYPING;
            end
            
            TYPING: begin
                // If start is high, it implies a new line begins, handle inside logic
                // Handled inside always block based on char_in
            end
            
            EXPANDING: begin
                // Wait for matching logic to complete (simplified as single cycle logic handled below)
                // Transition to OUTPUT once logic completes (handled in sequential block)
            end
            
            OUTPUT: begin
                // Go to update history after output is done
            end
            
            UPDATE_HISTORY: begin
                // One cycle to update, then back to IDLE
            end
        endcase
    end

    // Datapath Logic
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            buf_index <= 0;
            prefix_len <= 0;
            history_len <= 0;
            search_index <= 0;
            out_char_idx <= 0;
            output_valid <= 0;
            done <= 0;
            result_out <= 0;
            // Initialize history to zeros (optional but good practice)
            for (i = 0; i < MAX_HISTORY; i = i + 1) begin
                for (int j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                    history[i][j] <= 8'h00;
                end
            end
            for (i = 0; i < MAX_CMD_LEN; i = i + 1) begin
                current_buffer[i] <= 8'h00;
            end
        end else begin
            // Default assignments
            output_valid <= 0;
            done <= 0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        buf_index <= 0;
                        prefix_len <= 0;
                        search_index <= 0;
                        // Initialize buffer empty
                        for (i = 0; i < MAX_CMD_LEN; i = i + 1) current_buffer[i] <= 8'h00;
                    end
                end

                TYPING: begin
                    if (start) begin
                        // Process character input
                        if (char_in == 8'h0A || char_in == 8'h0D) begin // Enter key (LF or CR)
                            if (buf_index > 0) begin // Non-empty command
                                // Transition to OUTPUT (handled via state variable assignment if combinational) 
                                // Since this is seq block, we set state directly or rely on next_state logic
                                // But to be safe with sequencing, we set state here if combinational block wasn't used
                            end
                            // Handled by next_state logic usually, but for transitions based on input:
                            // We need to set next_state explicitly if we are overriding default
                        end else if (char_in == 8'h5E) begin // '^' character
                            // Trigger expansion
                            prefix_len <= buf_index; // Current length is prefix
                            search_index <= history_len; // Start search from top (will be decremented)
                            // Note: search_index acts as a pointer to next to check. 
                            // Initial state: search_index = history_len. 
                            // Logic will decrement to history_len - 1 first.
                        end else begin // Regular character
                            if (buf_index < MAX_CMD_LEN) begin
                                current_buffer[buf_index] <= char_in;
                                buf_index <= buf_index + 1;
                                search_index <= 0; // Reset expansion search history index
                            end
                        end
                    end else if (char_in == 8'h0A || char_in == 8'h0D) begin
                        // Handle Enter if received outside of 'start' pulse (assuming continuous stream or valid signal)
                        // Based on description, 'start' is high for one cycle. 
                        // If char_in is valid when start is high, this is tricky. 
                        // Let's assume TYPING state persists and we wait for start pulses for chars? 
                        // Or simpler: start sets IDLE to TYPING. In TYPING, we process inputs. 
                        // The prompt says "start is high to start processing a new line. Input data is valid when start is high".
                        // This implies a handshake. 
                        // Let's assume `start` is a strobe for every character for simplicity in TYPING.
                        // Re-reading: "start ... High for one cycle to start processing a new line".
                        // Then "Input data ... valid when start is high". 
                        // This implies `start` triggers the read of `char_in`. 
                        // But in TYPING state, we need to read multiple chars. 
                        // Interpretation: `start` is high for the first char. 
                        // Subsequent chars might be valid on `char_in` without `start`? 
                        // Or `start` is a "valid" signal for the current char. 
                        // Let's assume `start` behaves like `in_valid` for the duration of the line, 
                        // or that `char_in` is valid whenever we are ready.
                        // To make it robust, let's use `start` as a generic valid signal for the current char.
                        
                        // Correction: The prompt says "Start ... High for one cycle to start processing a new line".
                        // This is ambiguous for the rest of the line. 
                        // I will treat `start` as a strobe that indicates `char_in` is valid. 
                        // If `start` is only for the first char, we need a `valid` signal for subsequent ones.
                        // I will assume `start` is held high during the line entry OR `char_in` is stable. 
                        // Actually, usually `start` goes high, then goes low, and data comes in. 
                        // Let's assume `start` is a `valid` signal for the input char. 
                        
                        // Since the prompt says "start is high for one cycle to start", 
                        // I will add a logic check in TYPING for `char_in` being valid.
                        // Let's rely on `start` being high when a char is valid.
                    end
                end

                EXPANDING: begin
                    // State machine logic for expansion:
                    // 1. Identify prefix (already done: prefix_len)
                    // 2. Search history.
                    // Since this is a sequential block, we might need multiple cycles for search.
                    // The prompt says "Multi-cycle state". 
                    
                    // Cycle 1: Check search_index - 1
                    // Let's implement a loop-like behavior or a counter.
                    // We will use search_index as the current history index to check.
                    // Start: search_index = history_len. 
                    
                    if (search_index > 0) begin
                        search_index <= search_index - 1;
                        
                        // Check match for history[search_index - 1]
                        // We need to compare current_buffer[0:prefix_len-1] with history[search_index-1][0:prefix_len-1]
                        
                        // This is combinational usually, but for strict sequential we check here.
                        // Let's define `match_found` logic in combinational block, but apply updates here.
                        
                        // If match found:
                        if (prefix_match) begin
                            // Copy history to buffer
                            for (int j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                                current_buffer[j] <= history[search_index - 1][j];
                            end
                            // Update buf_index to match the length of the found command
                            // We need to find the length of the history command (until null)
                            // For simplicity, assume history commands are stored with nulls.
                            buf_index <= MAX_CMD_LEN; // Or find actual length. 
                            // Finding actual length is safer.
                            // We'll do that in OUTPUT or here.
                            
                            // Done expanding
                            search_index <= 0; // Reset for next time
                            // Transition to OUTPUT (handled by next_state logic if combinational, or set state here)
                        end
                    end else begin
                        // No more history to search or done
                        // If we found nothing, buffer remains as prefix.
                        // Transition to OUTPUT or back to TYPING? 
                        // Prompt: "Result: Update current_buffer". 
                        // Usually expands then returns to typing, but here we might just continue.
                        // However, the state diagram implies EXPANDING -> OUTPUT. 
                        // But prompt says "If a non-'^' character is typed after expansion, reset".
                        // This implies we go back to TYPING. 
                        // BUT, "Up-key sequence is terminated by any other char or Enter".
                        // So EXPANDING should likely return to TYPING. 
                        // However, the prompt "State Machine States" says "EXPANDING: ... Transition to OUTPUT".
                        // And "OUTPUT: Pops characters".
                        // Wait, OUTPUT pops characters to result_out. 
                        // This sounds like the FINAL output of the command, not intermediate.
                        // "When Enter is pressed... Transition to OUTPUT".
                        // Ah. "Enter -> OUTPUT". 
                        // So EXPANDING is just to update the buffer. 
                        // Does it go back to TYPING? 
                        // "If a non-'^' character is typed after expansion, the history search index resets".
                        // This implies we are back in TYPING.
                        
                        // So: EXPANDING updates buffer, then returns to TYPING.
                        // Enter -> OUTPUT.
                        // OUTPUT -> UPDATE_HISTORY -> IDLE.
                        
                        // Let's adjust next_state.
                        next_state = TYPING;
                    end
                end

                OUTPUT: begin
                    // Pops chars to result_out (2 chars per cycle).
                    // valid high during this.
                    output_valid <= 1;
                    
                    // Pack 2 chars
                    result_out[15:8] <= current_buffer[out_char_idx];
                    result_out[7:0] <= (out_char_idx + 1 < MAX_CMD_LEN) ? current_buffer[out_char_idx + 1] : 8'h00;
                    
                    if (out_char_idx + 2 >= MAX_CMD_LEN || 
                        (current_buffer[out_char_idx+2] == 8'h00 && out_char_idx + 2 >= buf_index)) begin
                        // End of command reached (roughly, checking null or buffer end)
                        // Need a more robust length check.
                        // Let's rely on `buf_index` storing the length.
                        // If we output up to buf_index (padding with nulls)
                        
                        // Actually, let's just output MAX_CMD_LEN/2 cycles to be safe for the interface.
                        // But "done" is high when line processing is complete.
                        // Let's output `buf_index` chars. 
                        
                        // Improved Logic:
                        if (out_pair_count == (MAX_CMD_LEN / 2) - 1) begin
                             output_valid <= 0;
                             done <= 1;
                             out_char_idx <= 0;
                             out_pair_count <= 0;
                             next_state = UPDATE_HISTORY;
                        end else begin
                             out_char_idx <= out_char_idx + 2;
                             out_pair_count <= out_pair_count + 1;
                        end
                    end else begin
                        // Continue
                        out_char_idx <= out_char_idx + 2;
                        out_pair_count <= out_pair_count + 1;
                    end
                    
                    // Simplification: Always output 8 cycles (16 chars) for fixed interface
                    if (out_pair_count == (MAX_CMD_LEN / 2)) begin
                         output_valid <= 0;
                         done <= 1;
                         out_char_idx <= 0;
                         out_pair_count <= 0;
                         next_state = UPDATE_HISTORY;
                    end
                end

                UPDATE_HISTORY: begin
                    done <= 1; // Keep done high or pulse? "High for one cycle".
                    // Write to history
                    
                    // Check if buffer is empty (buf_index == 0)
                    if (buf_index > 0) begin
                        if (history_len < MAX_HISTORY) begin
                            // Shift up
                            for (int k = MAX_HISTORY - 1; k > 0; k = k - 1) begin
                                for (int j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                                    history[k][j] <= history[k-1][j];
                                end
                            end
                            // Insert new
                            for (int j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                                history[0][j] <= current_buffer[j];
                            end
                            history_len <= history_len + 1;
                        end else begin
                            // Shift up (discard oldest)
                            for (int k = MAX_HISTORY - 1; k > 0; k = k - 1) begin
                                for (int j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                                    history[k][j] <= history[k-1][j];
                                end
                            end
                            // Insert new
                            for (int j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                                history[0][j] <= current_buffer[j];
                            end
                        end
                    end
                    
                    next_state = IDLE;
                end
            endcase
        end
    end

    // Combinational Logic for TYPING State Transitions & Expansion Matching
    always @(*) begin
        // Default next state for TYPING is stay TYPING
        if (state == TYPING) begin
            if (start) begin
                if (char_in == 8'h0A || char_in == 8'h0D) begin
                    next_state = OUTPUT;
                end else if (char_in == 8'h5E) begin // '^'
                    next_state = EXPANDING;
                end else begin
                    next_state = TYPING;
                end
            end else begin
                next_state = TYPING;
            end
        end
        
        // Expansion Match Logic (Combinational)
        prefix_match = 0;
        match_found_idx = 0;
        
        if (state == EXPANDING) begin
            // We check search_index - 1 because search_index decrements in seq block or we handle logic here.
            // Let's say we check the item pointed to by search_index.
            // In the seq block, we decremented search_index. 
            // So we check history[search_index]? No, we decrement and then check.
            // Let's check history[search_index] (where search_index is the one we are about to check).
            // Seq block decrements `search_index`. So if we want to check the *new* value:
            // It checks history[search_index - 1] in seq block code comment.
            // Let's do the check here cleanly.
            
            // We want to check history[search_index - 1] (since search_index was just decremented)
            // Wait, in the seq block, we set `search_index <= search_index - 1`. 
            // So `search_index` inside the block is the OLD value. 
            // The comparison logic runs in parallel or sequentially? 
            // Verilog evaluation: Combinational logic updates based on inputs.
            // If we calculate `prefix_match` based on `search_index`, it sees the OLD value before decrement.
            // So we check history[search_index - 1] if we want the new index.
            
            // Let's assume we iterate `search_index` down from `history_len` to `0`.
            // If `search_index` is 0, we stop.
            // We check `history[search_index - 1]`.
            
            if (search_index > 0) begin
                // Compare prefix
                prefix_match = 1;
                for (int k = 0; k < prefix_len; k = k + 1) begin
                    if (current_buffer[k] != history[search_index - 1][k]) begin
                        prefix_match = 0;
                    end
                end
            end
        end
    end

endmodule
