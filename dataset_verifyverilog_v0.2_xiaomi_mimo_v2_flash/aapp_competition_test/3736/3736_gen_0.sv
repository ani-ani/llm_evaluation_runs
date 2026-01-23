module mirror_check(
    input clk,
    input rst_n,
    input start,
    input [15:0] char_valid,
    input [7:0] char_data [15:0],
    input [4:0] str_length,
    output reg is_mirror,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state;
    reg [4:0] left_ptr;
    reg [4:0] right_ptr;
    reg next_is_mirror;
    reg next_done;

    // Valid character set check logic
    // The input char_valid provides a mask, so we simply check if the bits at left and right positions are 1.
    // The problem description mentions the hex values, but char_valid is given explicitly.
    // We assume char_valid bit is 1 if and only if char_data[i] is in the valid set {A, H, I, ...}.
    wire valid_left;
    wire valid_right;

    assign valid_left = char_valid[left_ptr];
    assign valid_right = char_valid[right_ptr];

    // Palindrome check: Check characters at the pointers
    wire chars_match;
    assign chars_match = (char_data[left_ptr] == char_data[right_ptr]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            is_mirror <= 1'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            is_mirror <= next_is_mirror;
            done <= next_done;
        end
    end

    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_is_mirror = is_mirror;
        next_done = done;
        
        case (current_state)
            IDLE: begin
                next_done = 1'b0;
                next_is_mirror = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                // If string length is 0 or 1, it is technically a palindrome, but the pointer logic handles it.
                // Specifically, if str_length <= 1, left (0) >= right (len-1). 
                // We can check this condition on entry or rely on pointer comparison in transition.
                // However, to be safe with length 0 or 1, we check pointers first.
                
                if (left_ptr >= right_ptr) begin
                    // End of string reached without failure
                    next_state = DONE;
                    next_is_mirror = 1'b1;
                    next_done = 1'b1;
                end else begin
                    // Perform checks
                    // Check 1: Characters match (Palindrome)
                    // Check 2: Characters are valid (Mirror)
                    // Note: If a character is invalid, valid_left or valid_right will be 0.
                    // We check both pointers. If one is invalid, the string is not a mirror word.
                    
                    if (chars_match && valid_left && valid_right) begin
                        // Checks passed, increment pointers
                        // Logic to update pointers must happen here or implicitly in the next cycle.
                        // Since we are in combinational logic determining the state, 
                        // we cannot change left_ptr/right_ptr directly here for the *current* cycle's check.
                        // But wait, the pointer update happens *after* the check.
                        // The prompt says "In each iteration (PROCESSING state), check... increment left..."
                        // This implies one cycle per check. 
                        // We need to keep the pointers in registers so they persist.
                        // However, the combinational block updates next_state. 
                        // We need to handle pointer incrementing.
                        // Typically, in a one-cycle-per-iteration FSM, the pointers are updated at the end of the cycle.
                        // But this always block is combinational. We need to drive the next values of pointers?
                        // Wait, pointers should be registers. 
                        // Let's assume left_ptr and right_ptr are updated in the sequential block or their next values are defined.
                        // Actually, it's cleaner to update pointers in the sequential block.
                        // Let's modify the design to handle pointer updates in the sequential block logic.
                        
                        // To strictly follow the prompt's implied flow:
                        // The check happens. If success, we prepare to increment.
                        // The state stays PROCESSING.
                        // But wait, if we stay in PROCESSING, how do the pointers advance?
                        // We need to assign the next values of pointers in the combinational block 
                        // OR handle it in the sequential block.
                        // Let's add logic to the sequential block to update pointers.
                        
                        // Actually, the standard way for this FSM is:
                        // 1. Check based on current pointers.
                        // 2. If fail -> DONE (0).
                        // 3. If pass -> check if done (left>=right). If yes -> DONE (1). If no -> stay PROCESSING.
                        // 4. Pointers update on the clock edge when staying in PROCESSING.
                        
                        // Since I cannot modify the sequential block easily from here without rewriting it,
                        // I will infer that the pointer registers need a "load/enable" signal.
                        // Let's add `update_ptr` logic.
                    end else begin
                        // Fail condition
                        next_state = DONE;
                        next_is_mirror = 1'b0;
                        next_done = 1'b1;
                    end
                end
            end

            DONE: begin
                // Wait for reset or start. 
                // Usually done stays high until reset.
                // If start is asserted again, we transition out.
                if (start) begin
                    next_state = PROCESSING;
                    next_done = 1'b0;
                    next_is_mirror = 1'b0;
                end
            end
        endcase
    end

    // Pointer Management Logic
    // We need to handle the incrementing of pointers.
    // We can define logic for next_left_ptr and next_right_ptr.
    reg [4:0] next_left_ptr;
    reg [4:0] next_right_ptr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_ptr <= 5'd0;
            right_ptr <= 5'd15; // Initialize to max index (or 0)
        end else begin
            left_ptr <= next_left_ptr;
            right_ptr <= next_right_ptr;
        end
    end

    always @(*) begin
        // Default keep values
        next_left_ptr = left_ptr;
        next_right_ptr = right_ptr;

        if (current_state == IDLE && start) begin
            // Initialize pointers on start
            next_left_ptr = 5'd0;
            next_right_ptr = str_length - 5'd1;
        end else if (current_state == PROCESSING) begin
            // If we are in PROCESSING and checks passed (state stays PROCESSING), 
            // we need to increment pointers for the *next* cycle's check.
            // However, checking validity in the combinational block above requires knowing if we passed.
            // Let's refine the `current_state == PROCESSING` block in the combinational logic.
            // 
            // Correction to the previous combinational block:
            // We need to check if we are DONE *after* the check, and increment *if* valid.
            // 
            // Actually, let's rewrite the PROCESSING logic in the combinational block to be correct.
        end
    end
    
    // Re-evaluating the main FSM combinational block logic for PROCESSING state:
    // It is cleaner to handle the transition logic fully.
    
    always @(*) begin
        next_state = current_state;
        next_is_mirror = is_mirror;
        next_done = done;
        next_left_ptr = left_ptr;
        next_right_ptr = right_ptr;

        case (current_state)
            IDLE: begin
                next_done = 1'b0;
                next_is_mirror = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_left_ptr = 5'd0;
                    next_right_ptr = str_length - 5'd1;
                end
            end

            PROCESSING: begin
                // Check termination condition (pointers crossed or met)
                if (left_ptr >= right_ptr) begin
                    next_state = DONE;
                    next_is_mirror = 1'b1;
                    next_done = 1'b1;
                end else begin
                    // Perform checks
                    if (chars_match && valid_left && valid_right) begin
                        // Pass: Increment pointers
                        next_left_ptr = left_ptr + 1;
                        next_right_ptr = right_ptr - 1;
                        next_state = PROCESSING; // Continue
                    end else begin
                        // Fail
                        next_state = DONE;
                        next_is_mirror = 1'b0;
                        next_done = 1'b1;
                    end
                end
            end

            DONE: begin
                if (start) begin
                    next_state = PROCESSING;
                    next_done = 1'b0;
                    next_is_mirror = 1'b0;
                    next_left_ptr = 5'd0;
                    next_right_ptr = str_length - 5'd1;
                end
            end
        endcase
    end

endmodule
