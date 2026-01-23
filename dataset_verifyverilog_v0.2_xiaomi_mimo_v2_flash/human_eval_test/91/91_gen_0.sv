module boredom_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_data,
    input [3:0] char_index,
    input char_valid,
    output reg [3:0] boredom_count,
    output reg done,
    output reg error
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam WAITING_SENTENCE_START = 3'b001;
    localparam IN_SENTENCE = 3'b010;
    localparam CHECKING_START = 3'b011;
    localparam DONE = 3'b100;

    // ASCII Constants
    localparam CHAR_I = 8'h49;
    localparam CHAR_SPACE = 8'h20;
    localparam CHAR_DOT = 8'h2E;
    localparam CHAR_QMARK = 8'h3F;
    localparam CHAR_EXCL = 8'h21;

    // Registers for State Machine
    reg [2:0] current_state, next_state;
    reg [3:0] count_reg, next_count;
    reg done_reg, next_done;
    reg error_reg, next_error;
    reg is_sentence_start, next_is_sentence_start;

    // State Transition and Output Logic (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            boredom_count <= 4'b0;
            done <= 1'b0;
            error <= 1'b0;
            is_sentence_start <= 1'b0;
        end else begin
            current_state <= next_state;
            boredom_count <= next_count;
            done <= next_done;
            error <= next_error;
            is_sentence_start <= next_is_sentence_start;
        end
    end

    // Next State Logic (Combinational)
    always @(*) begin
        // Default assignments to prevent latches
        next_state = current_state;
        next_count = boredom_count;
        next_done = done;
        next_error = error;
        next_is_sentence_start = is_sentence_start;

        case (current_state)
            IDLE: begin
                next_error = 1'b0;
                next_done = 1'b0;
                next_count = 4'b0;
                next_is_sentence_start = 1'b1; // Index 0 is always a potential start
                if (start) begin
                    next_state = WAITING_SENTENCE_START;
                end
            end

            WAITING_SENTENCE_START: begin
                if (char_valid) begin
                    // If we reach the end of the string (index 15 processed), go to DONE
                    if (char_index == 4'd15) begin
                        // Check this character as well before finishing, but loop will handle it if valid comes again? 
                        // Wait, logic says process 16 characters. 
                        // Let's rely on char_valid high for index 15 to transition to DONE after processing.
                        // But we need to process this specific character.
                        // Standard approach: Process 0 to 15. State machine acts on valid.
                    end

                    // Check for delimiter first (implicitly ending any previous sentence or acting as barrier)
                    // But in WAITING_SENTENCE_START, we are looking for the START.
                    // If we hit a delimiter, we stay in WAITING_SENTENCE_START (looking for next start)
                    // Exception: If we are at index 0 and it's a delimiter, we wait for next non-space.

                    if (char_data == CHAR_DOT || char_data == CHAR_QMARK || char_data == CHAR_EXCL) begin
                        next_is_sentence_start = 1'b1; // Next non-space is start
                        // If this is index 15, we are done.
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = WAITING_SENTENCE_START;
                        end
                    end else if (char_data == CHAR_SPACE) begin
                        // Skip space, keep looking for start
                        next_is_sentence_start = 1'b1;
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = WAITING_SENTENCE_START;
                        end
                    end else begin
                        // Found a non-space, non-delimiter character. 
                        // It is the start of a sentence. Check it.
                        next_state = CHECKING_START;
                    end
                end
            end

            CHECKING_START: begin
                // This state is triggered immediately after identifying a start char (in prev cycle or logic).
                // However, logic is easier if we handle check in WAITING_SENTENCE_START or separate state.
                // Let's restructure: 
                // WAITING_SENTENCE_START handles skipping spaces/delims. 
                // When it finds a char, it transitions to CHECKING_START. 
                // CHECKING_START increments if 'I' and goes to IN_SENTENCE.
                // If not 'I', go to IN_SENTENCE.
                // Exception: If char was delimiter, we go back to WAITING.
                
                // Wait, `char_valid` is high for one cycle per char. 
                // We need to latch the character or process it immediately.
                // Since inputs are `reg` and valid is high, we can look at `char_data`.
                
                // Let's unify CHECKING_START logic here.
                // But `char_data` is only valid when `char_valid` is high.
                // `CHECKING_START` should ideally be a state we enter when `WAITING` sees a valid non-space/delim.
                // However, if `WAITING` sees valid char, it changes state. 
                // If `WAITING` -> `CHECKING` on same cycle (combinational), we might miss the `char_data`.
                // It is safer to stay in `WAITING`, check `char_data` if `char_valid` is high, then transition.
                
                // Revised Logic: Do not use `CHECKING_START` as a separate clocked state for the check itself
                // if `char_data` is only valid during `char_valid` high in `WAITING`.
                // Instead, handle the check inside `WAITING_SENTENCE_START` logic.
            end

            IN_SENTENCE: begin
                // We are inside a sentence. Look for delimiters to end it.
                if (char_valid) begin
                    if (char_data == CHAR_DOT || char_data == CHAR_QMARK || char_data == CHAR_EXCL) begin
                        next_is_sentence_start = 1'b1;
                        next_state = WAITING_SENTENCE_START;
                        // Check if this last char of string (index 15)
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end
                    end else begin
                        // Still in sentence, ignore other chars
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = IN_SENTENCE;
                        end
                    end
                end
            end

            DONE: begin
                // Stay here until reset or start
                if (start) begin
                    next_state = WAITING_SENTENCE_START;
                    next_count = 4'b0;
                    next_done = 1'b0;
                    next_error = 1'b0;
                    next_is_sentence_start = 1'b1;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Logic to handle CHECKING_START and updates based on char_valid
    // Since I cannot enter a state and process in the same cycle without complex logic,
    // I will process the specific "Check Start" requirement inside the combinational block
    // but triggered by specific conditions.
    
    // Actually, let's split the combinational block to handle the "action" on char_valid explicitly.
    // The block above sets next_state. This block needs to handle the "Counter Increment".
    // But `boredom_count` is a register. We need to decide if we increment.
    
    // Let's refine the state transition logic to explicitly handle the "Check" moment.
    // We need a way to say "In this cycle, char is valid, it is a start, and it is I".
    
    always @(*) begin
        // Re-do the combinational logic to ensure correct behavior for the "Count" increment
        // Default values ensure we don't change unless valid
        next_state = current_state;
        next_count = boredom_count;
        next_done = done;
        next_error = error;
        next_is_sentence_start = is_sentence_start;

        case (current_state)
            IDLE: begin
                next_error = 1'b0;
                next_done = 1'b0;
                next_count = 4'b0;
                next_is_sentence_start = 1'b1;
                if (start) begin
                    next_state = WAITING_SENTENCE_START;
                end
            end

            WAITING_SENTENCE_START: begin
                if (char_valid) begin
                    // 1. Check if it's a delimiter or space -> stay in WAITING
                    if (char_data == CHAR_DOT || char_data == CHAR_QMARK || char_data == CHAR_EXCL) begin
                        next_is_sentence_start = 1'b1;
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = WAITING_SENTENCE_START;
                        end
                    end else if (char_data == CHAR_SPACE) begin
                        next_is_sentence_start = 1'b1;
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = WAITING_SENTENCE_START;
                        end
                    end else begin
                        // Found a non-space, non-delimiter. This is a sentence start character.
                        // Check if it is 'I'.
                        if (char_data == CHAR_I) begin
                            next_count = boredom_count + 1'b1;
                        end
                        
                        next_is_sentence_start = 1'b0; // We are inside sentence now
                        
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = IN_SENTENCE;
                        end
                    end
                end
            end

            IN_SENTENCE: begin
                if (char_valid) begin
                    if (char_data == CHAR_DOT || char_data == CHAR_QMARK || char_data == CHAR_EXCL) begin
                        // Delimiter found, go back to looking for start
                        next_is_sentence_start = 1'b1;
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = WAITING_SENTENCE_START;
                        end
                    end else begin
                        // Still in sentence, do nothing to count
                        if (char_index == 4'd15) begin
                            next_state = DONE;
                            next_done = 1'b1;
                        end else begin
                            next_state = IN_SENTENCE;
                        end
                    end
                end
            end

            DONE: begin
                if (start) begin
                    next_state = WAITING_SENTENCE_START;
                    next_count = 4'b0;
                    next_done = 1'b0;
                    next_error = 1'b0;
                    next_is_sentence_start = 1'b1;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule