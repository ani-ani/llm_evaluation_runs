module snake_to_camel(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input [3:0] num_chars,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CAP_FIRST = 3'b001;
    localparam OUTPUT_CHAR = 3'b010;
    localparam CAP_AFTER_UNDERSCORE = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] current_state, next_state;
    reg capitalize_next;
    reg [3:0] proc_index; // Tracks which character we are currently processing
    reg [3:0] total_chars_reg; // Store num_chars for internal counting

    // State transition and output logic (Moore style)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            char_out <= 8'b0;
            out_index <= 4'b0;
            done <= 1'b0;
            capitalize_next <= 1'b1; // First char is capitalized by default
            proc_index <= 4'b0;
            total_chars_reg <= 4'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    out_index <= 4'b0;
                    // On start, load registers if start is high
                    if (start) begin
                        total_chars_reg <= num_chars;
                        proc_index <= 4'b0;
                        capitalize_next <= 1'b1; // First character is capitalized
                    end
                end

                CAP_FIRST: begin
                    // We are at index 0, capitalize it
                    if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                        char_out <= char_in - 8'h20; // Convert to upper
                    end else begin
                        char_out <= char_in;
                    end
                    out_index <= 4'b0;
                    proc_index <= 4'd1; // Move to next expected index
                    
                    // Determine state for next char
                    if (char_in == 8'h5F) begin
                        // Input was underscore (rare at start but possible), flag for cap
                        capitalize_next <= 1'b1;
                    end else begin
                        // Standard flow, check if next char is underscore not needed here explicitly 
                        // as we process in CAP_AFTER_UNDERSCORE or standard lookup
                        capitalize_next <= 1'b0; 
                    end
                end

                OUTPUT_CHAR: begin
                    // Output logic for standard chars
                    if (capitalize_next || (char_in == 8'h5F)) begin
                         // If flag is set or we just hit an underscore (logic handled in transition)
                         // Wait, strictly we need to process char_in. 
                         // If it was underscore, we skip outputting it and handle logic.
                         // If it wasn't, we capitalize if flag was set.
                    end
                end

                CAP_AFTER_UNDERSCORE: begin
                    // Capitalize the char and output
                    if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                        char_out <= char_in - 8'h20;
                    end else begin
                        char_out <= char_in;
                    end
                    out_index <= out_index + 1;
                    proc_index <= proc_index + 1;
                    capitalize_next <= 1'b0; // Reset flag
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state; // Default hold state
        
        case (current_state)
            IDLE: begin
                if (start && num_chars > 0) begin
                    next_state = CAP_FIRST;
                end else if (start && num_chars == 0) begin
                    next_state = DONE;
                end else begin
                    next_state = IDLE;
                end
            end

            CAP_FIRST: begin
                // We have processed index 0. 
                // Check if we are done (only 1 char) or need to process more
                if (total_chars_reg <= 4'd1) begin
                    next_state = DONE;
                end else begin
                    next_state = OUTPUT_CHAR;
                end
            end

            OUTPUT_CHAR: begin
                // We just output a character (index `proc_index - 1`).
                // Now we look at char_in which corresponds to `proc_index`.
                // If char_in is '_', we skip outputting it and prepare to capitalize next.
                // If char_in is not '_', we output it (handle capitalization based on flag).
                
                // Check if we have processed all expected chars.
                // Note: proc_index is the index we are CURRENTLY looking at (in char_in).
                // We incremented proc_index in the previous state (CAP_FIRST) to 1.
                // So here, char_in is index 1.
                
                // Wait, CAP_FIRST set proc_index to 1. So this state checks index 1.
                
                // Edge case: Handling flow based on the PREVIOUSLY output char.
                // If previous char was '_', we need to capitalize THIS char.
                // This is stored in 'capitalize_next'.
                
                if (char_in == 8'h5F) begin
                    // Current char is underscore. Don't output.
                    // Next char (if exists) needs capitalization.
                    // We need to advance index to skip this underscore.
                    // But we can't output here. We need a state to skip.
                    // Or we loop here.
                    // If we loop in OUTPUT_CHAR, we might infinite loop.
                    // Let's check if char_in is underscore.
                    // If yes, go to a state that increments proc_index and sets flag.
                    // Let's just check if char_in is underscore here and jump directly.
                    
                    // Logic: If current char is '_', skip it, increment index, set capitalize flag.
                    // Then check next.
                    // Since we can't output this cycle (it's '_'), we need to update state.
                    // Let's make a virtual transition.
                    next_state = CAP_AFTER_UNDERSCORE; // Actually, this state capitalizes and outputs.
                    // Wait, CAP_AFTER_UNDERSCORE capitalizes. 
                    // If we hit '_', we want to skip it.
                    // Let's say we need a "SKIP_UNDERSCORE" state or handle it in OUTPUT_CHAR logic.
                    
                    // Let's use CAP_AFTER_UNDERSCORE as the state to handle the NEXT char.
                    // But here, char_in is '_'.
                    // We need to consume the '_' and move to the next input.
                    // The system provides input by index? No, "one character at a time".
                    // This implies char_in updates sequentially.
                    // So we just wait? No.
                    // Let's assume the logic is:
                    // 1. Look at current char_in.
                    // 2. If '_', ignore, move to next.
                    // 3. If char, output (capitalize if flag), clear flag.
                    // 4. Done when processed num_chars.
                    
                    // The state machine needs to handle this.
                    // Let's define a helper logic: 
                    // If we are in OUTPUT_CHAR and char_in is '_', we go to a state that increments counter and sets flag.
                    // Let's call it 'SKIP_AND_FLAG'.
                    // Wait, the instructions listed specific states. I should stick to them or imply derived states.
                    // "State Machine States: IDLE, CAP_FIRST, CAP_AFTER_UNDERSCORE, OUTPUT_CHAR, DONE".
                    // I can combine logic or use implicit states. I will use the listed ones plus implicit wait logic.
                    
                    // Let's define:
                    // OUTPUT_CHAR: 
                    //   If char_in == '_', next = OUTPUT_CHAR (but we consume it). 
                    //   Actually, we need to advance the input pointer.
                    //   Since inputs are streamed, we consume cycles.
                    //   If char_in is '_', we need to skip it. This takes 1 cycle.
                    //   So next state is OUTPUT_CHAR (checking next char) but with a flag set.
                    //   But we have CAP_AFTER_UNDERSCORE. 
                    //   If char_in is '_', we need to skip it. 
                    //   Let's make a rule: If char_in is '_', we go to CAP_AFTER_UNDERSCORE (logic modified) or a new state.
                    //   Actually, let's just handle it in logic.
                    
                    if (char_in == 8'h5F) begin
                         // Skip underscore. We need to read next char.
                         // But we can't read next char in this same cycle.
                         // We stay in state OUTPUT_CHAR? 
                         // If we stay, we need a counter to skip.
                         // Better: Go to CAP_AFTER_UNDERSCORE? 
                         // CAP_AFTER_UNDERSCORE assumes it capitalizes. 
                         // If we go there, char_in is still '_'.
                         // So we need a state that consumes '_'.
                         // Let's use CAP_AFTER_UNDERSCORE as a general 'Process next char, capitalize it' state.
                         // But if char_in is '_', we just skip it.
                         
                         // Let's add a small loop: 
                         // If char_in == '_' -> increment proc_index (conceptually), stay in some state.
                         // Let's just make a decision: 
                         // We will use CAP_AFTER_UNDERSCORE to handle the character FOLLOWING an underscore.
                         // If the current char is underscore, we consume it (don't output) and go to CAP_AFTER_UNDERSCORE.
                         next_state = CAP_AFTER_UNDERSCORE;
                    end else begin
                        // It's a char. 
                        if (capitalize_next) begin
                            // This char needs capitalization (because prev was '_' or it's logic start)
                            // But wait, if prev was '_', we aren't in OUTPUT_CHAR, we are in CAP_AFTER_UNDERSCORE.
                            // So here, capitalize_next is likely 0.
                            // Unless we came from CAP_FIRST and prev was '_' (handled there).
                            // So output standard char.
                            next_state = OUTPUT_CHAR;
                        end else begin
                            next_state = OUTPUT_CHAR;
                        end
                         
                        // Check if we are done.
                        // We processed index `proc_index - 1` (outputted just now).
                        // We looked at `proc_index` (in char_in) and outputted it (or skipped if '_').
                        // Wait, we are in OUTPUT_CHAR. We are about to output.
                        // We need to look at char_in.
                        
                        // Let's step back.
                        // State CAP_FIRST: Processes Index 0. Sets proc_index = 1.
                        // Next State: OUTPUT_CHAR.
                        // In OUTPUT_CHAR, we look at char_in (which is Index 1).
                        // If Index 1 is '_', we can't output it. We must skip.
                        // So we go to a state to skip it.
                        // Let's make CAP_AFTER_UNDERSCORE do double duty:
                        // 1. If char_in is '_', skip it.
                        // 2. If char_in is char, output upper.
                        // 3. If char_in is char and no flag, output lower.
                        
                        // This is getting complex for single state.
                        // Let's refine the states:
                        // IDLE -> CAP_FIRST
                        // CAP_FIRST: Output index 0 (Upper). Set proc_index = 1. Set capitalize_next = 0 (usually).
                        // Next -> CHECK_CHAR (Implicit)
                        // CHECK_CHAR: Look at char_in (Index proc_index).
                        // If '_': Set flag, proc_index++, go to CHECK_CHAR.
                        // If char: If flag set, go OUTPUT_CAP, else go OUTPUT_STD.
                        // If done: DONE.
                        
                        // The instructions explicitly list states.
                        // Let's map:
                        // CAP_FIRST: Output index 0. Set proc_index=1.
                        // Next: OUTPUT_CHAR.
                        // OUTPUT_CHAR: 
                        //   If char_in == '_': 
                        //      next_state = OUTPUT_CHAR (loop to consume) but we need to advance proc_index.
                        //      Or better: next_state = CAP_AFTER_UNDERSCORE (which sets flag and skips).
                        //      But CAP_AFTER_UNDERSCORE usually outputs.
                        
                        // Let's stick to a robust flow:
                        // IDLE -> CAP_FIRST
                        // CAP_FIRST: Output (Upper). Set `processing_index` = 1. 
                        // Next state depends on `char_in` (which is Index 1?). 
                        // Wait, CAP_FIRST processes Index 0. The input char_in at that time is Index 0.
                        // The NEXT input (Index 1) appears in the next cycle.
                        // So we can't look ahead easily without a buffer.
                        
                        // Strategy: 
                        // 1. CAP_FIRST: Outputs char_in (Index 0, Upper). 
                        //    Sets `idx` = 1. 
                        //    Sets `need_cap` = 0 (since first is done).
                        //    Next: OUTPUT_CHAR.
                        // 2. OUTPUT_CHAR: 
                        //    Inputs: char_in (Index `idx`).
                        //    Logic:
                        //      If char_in == '_' : 
                        //        `need_cap` = 1. 
                        //        `idx` = `idx` + 1.
                        //        (We consumed a cycle, don't output).
                        //        Next: OUTPUT_CHAR. 
                        //      Else (char):
                        //        If `need_cap`: Output Upper(char_in).
                        //        Else: Output char_in.
                        //        `idx` = `idx` + 1.
                        //        `need_cap` = 0.
                        //        Next: OUTPUT_CHAR.
                        //      If `idx` == `total_chars`: Next DONE.
                        
                        // This logic fits in one state OUTPUT_CHAR with a loop.
                        // However, CAP_FIRST is distinct.
                        // The instructions list CAP_AFTER_UNDERSCORE. 
                        // To use it: 
                        // CAP_FIRST -> OUTPUT_CHAR.
                        // OUTPUT_CHAR checks char_in.
                        // If '_': Set flag, increment index. Next: OUTPUT_CHAR (consume underscore cycle).
                        // If char: If flag set -> CAP_AFTER_UNDERSCORE. Else -> OUTPUT_CHAR (output lower).
                        // But CAP_AFTER_UNDERSCORE should output.
                        
                        // Let's try this mapping:
                        // IDLE -> CAP_FIRST
                        // CAP_FIRST: Output Upper(char_in). Increment proc_index to 1. 
                        // Next: OUTPUT_CHAR.
                        // 
                        // OUTPUT_CHAR (State):
                        //   Look at char_in (associated with proc_index).
                        //   Case 1: char_in is '_'. 
                        //        We consume this cycle (no output). 
                        //        Increment proc_index. Set capitalize_next = 1.
                        //        Next: OUTPUT_CHAR (Look at next char).
                        //   Case 2: char_in is not '_'.
                        //        If capitalize_next is set: 
                        //           Go to CAP_AFTER_UNDERSCORE (to output upper).
                        //        Else: 
                        //           Output char_in directly. 
                        //           Increment proc_index.
                        //           Check if done.
                        //           Next: OUTPUT_CHAR.
                        // 
                        // CAP_AFTER_UNDERSCORE:
                        //   Output Upper(char_in). 
                        //   Increment proc_index. 
                        //   Clear capitalize_next.
                        //   Check if done. Next: OUTPUT_CHAR.
                        
                        // This meets the state list requirement.

                        // Let's refine the JSON code based on this.
                        // We need to be careful about `proc_index` vs `char_index`.
                        // `char_index` is input, `proc_index` is internal track.
                        // Since input is stream, `char_index` might just be 0,1,2... 
                        // We trust internal counter to track where we are.

                        // Let's code the transitions for the OUTPUT_CHAR state.
                    end
                end // end of if current_state == OUTPUT_CHAR logic preparation
            end // End of OUTPUT_CHAR block in case statement
        endcase
    end
    
    // Re-writing the next_state and output logic cleanly in a single always block to avoid complex generate structures in the mind.
    // I will stick to the state definitions provided and the logic derived.
    
    // Let's write the correct always block.

endmodule

// NOTE: The complex FSM logic requires a careful rewrite for the final output to be correct.
// The following is the synthesized version of the logic described.

module snake_to_camel_final(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index, // Not used strictly if we stream, but kept for interface
    input [3:0] num_chars,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CAP_FIRST = 3'b001;
    localparam OUTPUT_CHAR = 3'b010;
    localparam CAP_AFTER_UNDERSCORE = 3'b011;
    localparam DONE = 3'b100;
    // Implicit state for skipping underscore if needed, or handle in OUTPUT_CHAR loop.
    // We will use OUTPUT_CHAR to handle skipping. 
    // If in OUTPUT_CHAR and char_in is '_', we increment index and stay in OUTPUT_CHAR (no output).
    // If in OUTPUT_CHAR and char_in is char and we need cap, we go to CAP_AFTER_UNDERSCORE.
    // If in OUTPUT_CHAR and char_in is char and no cap needed, we output char and stay.
    // If in CAP_AFTER_UNDERSCORE, we output char_in (upper) and go to OUTPUT_CHAR.

    reg [2:0] state;
    reg [3:0] count; // Internal counter for current character position we are evaluating (0 to num_chars-1)
    reg [3:0] out_cnt; // Output index counter
    reg need_cap; // Flag for capitalization
    reg [3:0] total_len; // Store num_chars

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'b0;
            out_index <= 4'b0;
            done <= 1'b0;
            count <= 4'b0;
            out_cnt <= 4'b0;
            need_cap <= 1'b0;
            total_len <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_cnt <= 4'b0;
                    count <= 4'b0;
                    need_cap <= 1'b0;
                    if (start) begin
                        total_len <= num_chars;
                        if (num_chars == 0) begin
                            state <= DONE;
                        end else begin
                            state <= CAP_FIRST;
                            count <= 4'd0; // We will process index 0
                        end
                    end
                end

                CAP_FIRST: begin
                    // Process index 0 (char_in should be index 0)
                    // Capitalize it
                    if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                        char_out <= char_in - 8'h20;
                    end else begin
                        char_out <= char_in;
                    end
                    out_index <= out_cnt;
                    out_cnt <= out_cnt + 1;
                    count <= count + 1; // Move to index 1
                    
                    // Check if we are done (only 1 char)
                    if (total_len == 1) begin
                        state <= DONE;
                    end else begin
                        state <= OUTPUT_CHAR;
                    end
                end

                OUTPUT_CHAR: begin
                    // Check character at current index 'count'
                    // Note: char_in is the input stream. We assume it matches 'count'.
                    // If the user provides char_in based on char_index, this logic works if we sync.
                    // However, strictly, we are processing sequentially.
                    
                    if (char_in == 8'h5F) begin
                        // Underscore detected. Skip it.
                        // Set flag for next char
                        need_cap <= 1'b1;
                        count <= count + 1;
                        // Stay in OUTPUT_CHAR to process next cycle
                        state <= OUTPUT_CHAR;
                    end else begin
                        // It is a character
                        if (need_cap) begin
                            // Need to capitalize, go to specific state
                            state <= CAP_AFTER_UNDERSCORE;
                        end else begin
                            // Just output as is
                            char_out <= char_in;
                            out_index <= out_cnt;
                            out_cnt <= out_cnt + 1;
                            count <= count + 1;
                            
                            // Check completion
                            if (count + 1 >= total_len) begin // We just processed 'count', so next count is count+1. If count+1 == total_len, we are done.
                                state <= DONE;
                            end else begin
                                state <= OUTPUT_CHAR;
                            end
                        end
                    end
                end

                CAP_AFTER_UNDERSCORE: begin
                    // Capitalize current char_in (which is valid as we didn't advance count in OUTPUT_CHAR if we branched here)
                    // Wait, if we came from OUTPUT_CHAR, we haven't incremented count for this char yet (unless we did logic diff).
                    // In OUTPUT_CHAR, if need_cap is 1, we stay at current 'count' (which is the underscore or the char?)
                    // Actually, if we were in OUTPUT_CHAR and saw '_', we incremented count and set flag.
                    // So char_in in next cycle is the char AFTER underscore.
                    // Or, if we looped back to OUTPUT_CHAR after skipping, count is already pointing to the char.
                    
                    // Let's trace: 
                    // 1. Output 'A'. count=1. 
                    // 2. OUTPUT_CHAR state. char_in (index 1) is '_'.
                    //    Set need_cap=1. count=2. 
                    // 3. OUTPUT_CHAR state. char_in (index 2) is 'b'.
                    //    need_cap=1. -> State CAP_AFTER_UNDERSCORE.
                    //    In CAP_AFTER_UNDERSCORE, we output Upper('b').
                    //    count is 2. We need to output char_in at count 2.
                    //    Then increment count to 3.
                    //    Check completion.
                    
                    if (char_in >= 8'h61 && char_in <= 8'h7A) begin
                        char_out <= char_in - 8'h20;
                    end else begin
                        char_out <= char_in;
                    end
                    out_index <= out_cnt;
                    out_cnt <= out_cnt + 1;
                    
                    // Advance count
                    count <= count + 1;
                    need_cap <= 1'b0;
                    
                    // Check completion. (count+1 will be the next index)
                    if (count + 1 >= total_len) begin
                        state <= DONE;
                    end else begin
                        state <= OUTPUT_CHAR;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to reset? Or stay done.
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule

// Simplified single module for the final output
module snake_to_camel(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] char_index,
    input [3:0] num_chars,
    output reg [7:0] char_out,
    output reg [3:0] out_index,
    output reg done
);

    reg [2:0] state;
    reg [3:0] idx; // Current input index being considered
    reg [3:0] out_idx_cnt;
    reg capitalize;
    reg [3:0] total_len;
    
    // States
    localparam S_IDLE = 3'd0;
    localparam S_CAP_FIRST = 3'd1;
    localparam S_PROC = 3'd2; // Process current char
    localparam S_CAP = 3'd3; // Capitalize and output
    localparam S_DONE = 3'd4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            char_out <= 8'b0;
            out_index <= 4'b0;
            done <= 1'b0;
            idx <= 4'b0;
            out_idx_cnt <= 4'b0;
            capitalize <= 1'b0;
            total_len <= 4'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        total_len <= num_chars;
                        idx <= 4'd0;
                        out_idx_cnt <= 4'd0;
                        if (num_chars > 0) state <= S_CAP_FIRST;
                        else state <= S_DONE;
                    end
                end

                S_CAP_FIRST: begin
                    // Process char_in (index 0)
                    if (char_in >= 8'h61 && char_in <= 8'h7A) 
                        char_out <= char_in - 8'h20;
                    else 
                        char_out <= char_in;
                    
                    out_index <= out_idx_cnt;
                    out_idx_cnt <= out_idx_cnt + 1;
                    idx <= 1;
                    
                    // Check if this was the only char
                    if (total_len == 1) state <= S_DONE;
                    else state <= S_PROC;
                end

                S_PROC: begin
                    // Look at char_in (at index idx)
                    // If '_' -> skip, set capitalize, stay in S_PROC (consume cycle)
                    // If char -> check capitalize flag
                    if (char_in == 8'h5F) begin
                        // Underscore: skip this cycle, advance index, set flag
                        idx <= idx + 1;
                        capitalize <= 1'b1;
                        state <= S_PROC; // Loop to next char
                    end else begin
                        // Character
                        if (capitalize) begin
                            state <= S_CAP;
                        end else begin
                            // Output as is
                            char_out <= char_in;
                            out_index <= out_idx_cnt;
                            out_idx_cnt <= out_idx_cnt + 1;
                            idx <= idx + 1;
                            // Check completion
                            if (idx + 1 == total_len) state <= S_DONE;
                            else state <= S_PROC;
                        end
                    end
                end

                S_CAP: begin
                    // Output capitalized char_in
                    if (char_in >= 8'h61 && char_in <= 8'h7A) 
                        char_out <= char_in - 8'h20;
                    else 
                        char_out <= char_in;
                    
                    out_index <= out_idx_cnt;
                    out_idx_cnt <= out_idx_cnt + 1;
                    idx <= idx + 1;
                    capitalize <= 1'b0;
                    
                    // Check completion
                    if (idx + 1 == total_len) state <= S_DONE;
                    else state <= S_PROC;
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= S_IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule