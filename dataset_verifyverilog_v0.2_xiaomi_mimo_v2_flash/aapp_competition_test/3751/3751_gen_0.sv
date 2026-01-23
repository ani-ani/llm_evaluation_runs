module identifier_validator (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    output reg result,
    output reg error,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam WAIT_START = 3'b001;
    localparam VALIDATE = 3'b010;
    localparam ERROR = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] current_state;
    reg [2:0] next_state;
    reg [7:0] next_expected; // The next alphabetical character expected (e.g., 'b', 'c')
    reg [7:0] seen_map;      // Bit map of characters seen (from 'a' to 'h' for 8 bits)
    reg result_reg;
    reg error_reg;
    reg done_reg;

    // State Transition Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = WAIT_START;
                else next_state = IDLE;
            end
            WAIT_START: begin
                if (valid_in) next_state = VALIDATE;
                else if (start) next_state = WAIT_START; // Stay if start held
                else next_state = WAIT_START; // Keep waiting
            end
            VALIDATE: begin
                // Only one character processed per valid_in pulse
                // We assume valid_in is high in this state to enter it.
                // Return to WAIT_START to wait for next valid_in or termination (valid_in low).
                // Note: The prompt says "Transition to WAIT_START for next char or DONE if sequence ends".
                // We check done condition (valid_in low) in WAIT_START usually, or here.
                // Let's go to WAIT_START to process next. 
                // If valid_in goes low, the logic in WAIT_START will handle transitioning to DONE? 
                // Prompt says "stream terminates when valid_in goes low". 
                // So if we are in VALIDATE, we process. Then back to WAIT_START.
                // In WAIT_START, if !valid_in and not start, maybe we are done? 
                // Prompt says "DONE: Latch success. Stay here." implies we need to explicitly go to DONE.
                // Let's modify: VALIDATE checks the char. 
                // If it causes error -> ERROR.
                // If valid -> result high. Then next state depends on if this was the end.
                // But we don't know if it's the end until next cycle.
                // Actually, the prompt says "Transition to WAIT_START for next char or DONE if sequence ends".
                // Since valid_in is a signal, we can't know if it's the end in the same cycle valid_in is high unless we have a "last" signal.
                // However, the requirement says: "stream terminates when valid_in goes low".
                // So perhaps the FSM just stays in stream mode until reset or error.
                // Re-reading: "done is High when sequence is complete (or error)".
                // If the stream stops (valid_in goes low), we should probably go to DONE.
                // Let's add a transition in WAIT_START: if !valid_in && !start -> DONE.
                // So VALIDATE always goes back to WAIT_START.
                next_state = WAIT_START;
            end
            ERROR: begin
                if (start) next_state = WAIT_START; // Allow restart on start
                else next_state = ERROR;
            end
            DONE: begin
                if (start) next_state = WAIT_START; // Allow restart on start
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output Logic (Mealy style via state checks and inputs)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 1'b0;
            error <= 1'b0;
            done <= 1'b0;
            next_expected <= 8'h61; // 'a'
            seen_map <= 8'h00;
        end else begin
            current_state <= next_state;

            // Default assignments
            result <= 1'b0;
            error <= 1'b0;
            done <= 1'b0;

            case (next_state)
                IDLE: begin
                    // Reset outputs
                    result <= 1'b0;
                    error <= 1'b0;
                    done <= 1'b0;
                    next_expected <= 8'h61;
                    seen_map <= 8'h00;
                end

                WAIT_START: begin
                    // Check for sequence completion (stream ends)
                    // We are here because we just finished a char or started.
                    // If valid_in is low and we are not in the middle of processing (which we aren't in WAIT_START), we are done.
                    // However, to avoid immediately declaring done on reset if valid_in is low, we rely on state transition.
                    // If we came from VALIDATE and valid_in is now low, we are done.
                    if (!valid_in && !start && (current_state == VALIDATE || current_state == WAIT_START)) begin
                         done <= 1'b1;
                         result <= 1'b1; // If we got here without error, it's valid
                         // Note: If we go to DONE, the state machine updates next cycle. 
                         // But prompt says "Result valid 1 clock cycle after processing each character".
                         // And "DONE: Latch success".
                         // Let's handle the DONE transition here.
                    end
                    // If we are in WAIT_START and start is asserted, we handled that in state transition to IDLE/WAIT_START.
                    // Actually, reset logic handles clearing. 
                end

                VALIDATE: begin
                    if (valid_in) begin
                        // Check if character is out of range of our map (e.g., 'i' and above if map is 8 bits)
                        // or simply if it is > next_expected and not seen.
                        
                        // Calculate difference from 'a' to index into seen_map
                        // Only support 'a' to 'h' for 8-bit map. If char < 'a', treat as invalid or ignore? 
                        // Let's assume strictly 'a' onwards. If char < 'a', it's invalid (not in sequence).
                        
                        if (char_in < 8'h61) begin
                            error <= 1'b1;
                            // State transition to ERROR handled in combinational logic
                        end
                        else if (char_in > 8'h68) begin // 'h' is 8'h68. Beyond map size.
                            error <= 1'b1;
                        end
                        else begin
                            // It's within range 'a'-'h'
                            if (char_in == next_expected) begin
                                // New expected character received
                                seen_map[char_in - 8'h61] <= 1'b1;
                                next_expected <= next_expected + 1;
                                result <= 1'b1;
                            end
                            else if (char_in > next_expected) begin
                                // Skipped a character (and it's not a duplicate because if it were duplicate, it would be < next_expected or we need to check seen_map)
                                // If char_in > next_expected, it is definitely a new character and it is not the expected one.
                                error <= 1'b1;
                            end
                            else if (char_in < next_expected) begin
                                // Character is less than expected. Check if it is a duplicate.
                                if (seen_map[char_in - 8'h61]) begin
                                    // It is a duplicate, allowed
                                    result <= 1'b1;
                                end else begin
                                    // It is a new character but smaller than expected. 
                                    // Is this allowed? Prompt says: "If a character < 'next_expected' is seen (and it's not a duplicate), it's allowed."
                                    // Wait, that seems counter-intuitive to "alphabetical order based on first occurrence".
                                    // Example: 'a' (expect 'b'), 'b' (expect 'c'), 'a' (ok, duplicate), 'c' (expect 'd').
                                    // Example: 'a' (expect 'b'), 'c' (error, skipped 'b').
                                    // There is no example of 'a', 'b', 'a', 'd'. 
                                    // If we get 'd' while expecting 'c', it's error.
                                    // If we get 'a' (which is < 'b' expected) and it's NOT a duplicate (how? maybe we reset map?), it says "allowed".
                                    // But logically, if we haven't seen 'b' yet, we expect 'b'. If we see 'a', it's a duplicate of the start.
                                    // If we see 'b' then 'a', 'a' < 'b' (next expected was 'c'), 'a' is a duplicate.
                                    // I will strictly follow the prompt: "If a character < 'next_expected' is seen (and it's not a duplicate), it's allowed."
                                    // This implies we might update the map or state even for characters smaller than next_expected, if they are new?
                                    // Let's assume "alphabetical order based on first occurrence". 
                                    // If 'd' appears before 'c', error.
                                    // If 'a' appears after 'b', it's a duplicate (since 'a' started it).
                                    // If the rule is strict alphabetical order of *new* chars, then 'a' -> 'b' -> 'c'.
                                    // If we see a character smaller than the current expected new one, it MUST be a duplicate of something seen before.
                                    // So if it is NOT a duplicate, it should be an error? 
                                    // But the prompt explicitly says: "If a character < 'next_expected' is seen (and it's not a duplicate), it's allowed."
                                    // I will implement as stated: if < next_expected and NOT seen, it is valid.
                                    // And we mark it as seen.
                                    seen_map[char_in - 8'h61] <= 1'b1;
                                    result <= 1'b1;
                                end
                            end
                        end
                    end
                end

                ERROR: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    // Latch error state
                end

                DONE: begin
                    result <= 1'b1;
                    done <= 1'b1;
                    // Latch success state
                end
            endcase
        end
    end

    // Combinational logic to drive state transitions based on conditions inside states
    // Specifically, moving from WAIT_START to DONE if stream ends
    // And moving from VALIDATE to ERROR if error detected inside VALIDATE block
    // Since the sequential block updates registers, we need a separate combinational block for immediate error transition.
    // However, standard FSMs use one block. Let's refine the combinational next_state logic to handle the VALIDATE->ERROR transition.
    
    // Re-defining combinational block to handle complex conditions
    always @(*) begin
        // Default next_state is current_state (stays unless changed)
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) next_state = WAIT_START;
            end
            
            WAIT_START: begin
                if (start) next_state = WAIT_START; // Reset/Restart
                else if (valid_in) next_state = VALIDATE;
                else if (done_reg) next_state = DONE; // If we set done_reg (meaning stream ended previously)
                else if (error_reg) next_state = ERROR;
                else if (!valid_in && !start) begin
                    // Stream ended? But we need to latch DONE.
                    // We need to detect falling edge of valid_in or just logic.
                    // Let's say: If we are in WAIT_START and valid_in is low, and we have seen at least one char (tracked by next_expected > 'a')
                    // Then go to DONE.
                    // However, we need to track "stream active" state.
                    // Let's rely on the DONE state logic in the sequential block.
                    // Actually, if we are in WAIT_START and !valid_in, we are done.
                    if (next_expected > 8'h61) next_state = DONE;
                end
            end
            
            VALIDATE: begin
                // If we enter VALIDATE, we process the char.
                // We check conditions immediately to transition to ERROR or back to WAIT_START.
                if (valid_in) begin
                    // Check for error conditions
                    if (char_in < 8'h61 || char_in > 8'h68) next_state = ERROR;
                    else if (char_in > next_expected) next_state = ERROR;
                    else if (char_in < next_expected) begin
                        if (!seen_map[char_in - 8'h61]) begin
                            // Not a duplicate. Prompt says allowed. So OK.
                            next_state = WAIT_START;
                        end else begin
                            next_state = WAIT_START;
                        end
                    end else if (char_in == next_expected) begin
                        next_state = WAIT_START;
                    end
                end else begin
                    // valid_in low? Shouldn't happen if we are here, but handle.
                    next_state = WAIT_START;
                end
            end
            
            ERROR: begin
                if (start) next_state = WAIT_START;
                else next_state = ERROR;
            end
            
            DONE: begin
                if (start) next_state = WAIT_START;
                else next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Update sequential logic to handle the outputs based on next_state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            error <= 1'b0;
            done <= 1'b0;
            next_expected <= 8'h61;
            seen_map <= 8'h00;
            error_reg <= 1'b0;
            done_reg <= 1'b0;
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
            
            // Default outputs
            result <= 1'b0;
            // error and done are latched, so default is keep value or clear based on state
            if (next_state == IDLE || next_state == WAIT_START) begin
                // In idle/wait, error/done are low unless we are transitioning from ERROR/DONE
                // But they are latched, so let's clear them only on start or reset
            end

            case (next_state)
                IDLE: begin
                    next_expected <= 8'h61;
                    seen_map <= 8'h00;
                    error_reg <= 1'b0;
                    done_reg <= 1'b0;
                    error <= 1'b0;
                    done <= 1'b0;
                    result <= 1'b0;
                end

                WAIT_START: begin
                    // Detect end of stream condition here to go to DONE
                    // We need to set done_reg so the combinational block sees it
                    if (!valid_in && !start && (current_state == VALIDATE || current_state == WAIT_START)) begin
                        // If we are here and valid_in is low, stream ended
                        // Only if we have processed something (next_expected > 'a')
                        if (next_expected > 8'h61) begin
                            done_reg <= 1'b1;
                            done <= 1'b1;
                            result <= 1'b1; // Success
                        end
                    end
                    // On start signal, reset the registers (already handled by transition to IDLE or explicit reset here)
                    if (start) begin
                         next_expected <= 8'h61;
                         seen_map <= 8'h00;
                         error_reg <= 1'b0;
                         done_reg <= 1'b0;
                         error <= 1'b0;
                         done <= 1'b0;
                         result <= 1'b0;
                    end
                end

                VALIDATE: begin
                    if (valid_in) begin
                        if (char_in < 8'h61) begin
                            error <= 1'b1;
                            error_reg <= 1'b1;
                        end else if (char_in > 8'h68) begin
                            error <= 1'b1;
                            error_reg <= 1'b1;
                        end else begin
                            if (char_in == next_expected) begin
                                seen_map[char_in - 8'h61] <= 1'b1;
                                next_expected <= next_expected + 1;
                                result <= 1'b1;
                            end else if (char_in > next_expected) begin
                                error <= 1'b1;
                                error_reg <= 1'b1;
                            end else if (char_in < next_expected) begin
                                if (seen_map[char_in - 8'h61]) begin
                                    result <= 1'b1;
                                end else begin
                                    // New char, but smaller. Allowed per prompt.
                                    seen_map[char_in - 8'h61] <= 1'b1;
                                    result <= 1'b1;
                                end
                            end
                        end
                    end
                end

                ERROR: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    error_reg <= 1'b1;
                    done_reg <= 1'b1;
                end

                DONE: begin
                    done <= 1'b1;
                    result <= 1'b1;
                    done_reg <= 1'b1;
                end
            endcase
        end
    end

endmodule
