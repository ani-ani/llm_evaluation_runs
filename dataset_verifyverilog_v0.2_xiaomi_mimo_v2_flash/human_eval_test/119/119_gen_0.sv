module match_parens (
    input clk,
    input rst_n,
    input start,
    input [7:0] str1 [0:7],
    input [7:0] str2 [0:7],
    output reg result,
    output reg done
);

    parameter MAX_LEN = 8;

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK_S1_S2 = 3'b001;
    localparam CHECK_S2_S1 = 3'b010;
    localparam COMPUTE_RESULT = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [3:0] idx; // Index counter (0 to 15)
    reg [3:0] depth; // Stack depth counter
    reg valid_order; // Flag for current order validity
    reg check_s1_s2_done; // Flag to store result of first order

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
            idx <= 4'd0;
            depth <= 4'd0;
            valid_order <= 1'b1;
            check_s1_s2_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for first check (str1 + str2)
                        idx <= 4'd0;
                        depth <= 4'd0;
                        valid_order <= 1'b1;
                        check_s1_s2_done <= 1'b0;
                    end
                end

                CHECK_S1_S2: begin
                    if (idx < 16) begin
                        // Determine current character
                        // Positions 0-7: str1, Positions 8-15: str2
                        if (idx < 8) begin
                            // Processing str1
                            if (str1[idx] == 8'h28) begin // '('
                                depth <= depth + 1'b1;
                            end else if (str1[idx] == 8'h29) begin // ')'
                                if (depth == 0) begin
                                    valid_order <= 1'b0;
                                end else begin
                                    depth <= depth - 1'b1;
                                end
                            end
                        end else begin
                            // Processing str2 (idx 8-15, so idx-8 is index into str2)
                            if (str2[idx-8] == 8'h28) begin // '('
                                depth <= depth + 1'b1;
                            end else if (str2[idx-8] == 8'h29) begin // ')'
                                if (depth == 0) begin
                                    valid_order <= 1'b0;
                                end else begin
                                    depth <= depth - 1'b1;
                                end
                            end
                        end
                        idx <= idx + 1'b1;
                    end else begin
                        // Finished checking string, check final depth
                        if (depth != 0 || !valid_order) begin
                            valid_order <= 1'b0;
                        end
                        // Transition to next state
                        // We need one cycle to register the final valid_order check if needed,
                        // but since we are in the same always block, valid_order is updated before the state changes.
                        // However, to strictly follow the latency requirement and logic flow, 
                        // we can transition or stay one cycle. 
                        // Let's transition immediately if we handle the logic correctly.
                        // Actually, we need to move to CHECK_S2_S1.
                    end
                end

                CHECK_S2_S1: begin
                    if (idx < 16) begin
                        // Determine current character
                        // Positions 0-7: str2, Positions 8-15: str1
                        if (idx < 8) begin
                            // Processing str2
                            if (str2[idx] == 8'h28) begin // '('
                                depth <= depth + 1'b1;
                            end else if (str2[idx] == 8'h29) begin // ')'
                                if (depth == 0) begin
                                    valid_order <= 1'b0;
                                end else begin
                                    depth <= depth - 1'b1;
                                end
                            end
                        end else begin
                            // Processing str1 (idx-8)
                            if (str1[idx-8] == 8'h28) begin // '('
                                depth <= depth + 1'b1;
                            end else if (str1[idx-8] == 8'h29) begin // ')'
                                if (depth == 0) begin
                                    valid_order <= 1'b0;
                                end else begin
                                    depth <= depth - 1'b1;
                                end
                            end
                        end
                        idx <= idx + 1'b1;
                    end else begin
                        if (depth != 0 || !valid_order) begin
                            valid_order <= 1'b0;
                        end
                    end
                end

                COMPUTE_RESULT: begin
                    // Determine final result based on both checks
                    if (check_s1_s2_done || valid_order) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    done <= 1'b1;
                end

                DONE: begin
                    // Stay here until reset or start (though start typically implies IDLE transition)
                    // Handled in next_state logic
                end
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state; // Default stay in current state
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_S1_S2;
                end
            end

            CHECK_S1_S2: begin
                // Wait for index to reach 16 (16 cycles total from IDLE->CHECK start)
                // Actually, loop logic in sequential block handles idx increment.
                // We just need to detect end of loop.
                if (idx == 16) begin
                    next_state = COMPUTE_RESULT;
                    // Capture result of first check
                    // Wait, logic inside sequential block updates valid_order.
                    // We need to transfer 'valid_order' (of S1+S2) to 'check_s1_s2_done' and reset 'valid_order' for S2+S1.
                    // This transfer happens when moving from CHECK_S1_S2 to CHECK_S2_S1?
                    // But here I transition to COMPUTE_RESULT? 
                    // The requirement says "Test both concatenation orders".
                    // Sequence: S1+S2 -> S2+S1 -> Result.
                    // My state machine above was: IDLE -> CHECK_S1_S2 -> CHECK_S2_S1 -> COMPUTE.
                    // Let's fix the transition flow in the sequential block logic to be cleaner.
                    
                    // Wait, I wrote in sequential block for CHECK_S1_S2: "idx < 16" else "valid_order update".
                    // The next state logic needs to know when to switch states.
                    // It seems I need an extra state or handle the transition carefully.
                    
                    // Let's refine:
                    // CHECK_S1_S2 runs for 16 cycles. 
                    // At cycle 16 (idx=16), we are done. 
                    // We need to save result1 = valid_order.
                    // Then go to CHECK_S2_S1.
                    // Then go to COMPUTE.
                    
                    // The 'if (idx == 16)' check in sequential block updates valid_order for the *last* check (S2+S1) or first?
                    // In CHECK_S1_S2, at idx==16, we check depth and set valid_order. 
                    // If valid_order is false, it stays false.
                    // So at the end of CHECK_S1_S2, valid_order == Result of S1+S2.
                    
                    // So when next_state = CHECK_S2_S1, we must save valid_order.
                    // But pure next_state logic doesn't modify registers. 
                    // The sequential block must handle the 'save' operation.
                    
                    // Let's add a transition action in the sequential block or use the state change.
                    // Better approach: Just go to CHECK_S2_S1.
                    // In sequential block, when state==CHECK_S1_S2 and idx==16:
                    //    check_s1_s2_done <= valid_order;
                    //    valid_order <= 1'b1; // Reset for next check
                    //    depth <= 0;
                    //    idx <= 0;
                    //    next_state = CHECK_S2_S1; (in combinational logic)
                    
                    // So modify the sequential logic to handle the transition properly.
                    next_state = CHECK_S2_S1;
                end
            end

            CHECK_S2_S1: begin
                if (idx == 16) begin
                    next_state = COMPUTE_RESULT;
                end
            end

            COMPUTE_RESULT: begin
                next_state = DONE;
            end

            DONE: begin
                // Wait here. User must reset or ensure start is pulsed high then low to go back to IDLE.
                // Standard FSM: DONE -> IDLE (self-clearing or reset).
                // If start is held high, we might loop or stay. 
                // Usually done goes high for 1 cycle. 
                // Here done is a register. It stays high in DONE.
                // To support new transaction, we should go to IDLE.
                // But the prompt doesn't specify 'start' behavior on DONE. 
                // Let's assume if start is low, we stay in DONE. If start goes high again, maybe we restart?
                // Usually, handshaking: Start goes high, Done goes high. 
                // Let's implement: Done goes high in COMPUTE_RESULT or DONE.
                // If we are in DONE and start is low, stay DONE.
                // If reset, go IDLE.
                // Let's stay in DONE until reset.
            end
        endcase
    end

    // Modified Sequential Logic to handle transitions between states
    // We need to intercept the 'idx == 16' condition to reset counters and save results.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Handled by main reset block, but for safety:
            state <= IDLE;
            idx <= 0;
            depth <= 0;
            valid_order <= 1;
            check_s1_s2_done <= 0;
            result <= 0;
            done <= 0;
        end else begin
            // Default increment for counters if in a counting state
            // We will override this if we are resetting for the next check.
            
            // State transitions based on combinational logic
            // But we need to handle actions associated with transitions
            
            // Let's separate the counting logic
            if (state == IDLE && start) begin
                state <= CHECK_S1_S2;
                idx <= 0;
                depth <= 0;
                valid_order <= 1'b1;
                check_s1_s2_done <= 1'b0;
                done <= 1'b0;
            end
            else if (state == CHECK_S1_S2) begin
                if (idx < 15) begin // Still counting 0 to 14 (15 cycles done, 1 more to go to 15? No, 0..15 is 16)
                    // Actually, we want 16 iterations for 16 chars. Indices 0 to 15.
                    // Loop: 0..15. 
                    // Let's say we process char at index 'idx'.
                    // When idx == 15, we process last char. 
                    // Then idx increments to 16. 
                    // At idx == 16, we finalize.
                    // So: 
                    if (idx < 16) begin
                        // Process char (logic from before)
                        if (idx < 8) begin
                            if (str1[idx] == 8'h28) depth <= depth + 1'b1;
                            else if (str1[idx] == 8'h29) begin if (depth==0) valid_order <= 0; else depth <= depth - 1'b1; end
                        end else begin
                            if (str2[idx-8] == 8'h28) depth <= depth + 1'b1;
                            else if (str2[idx-8] == 8'h29) begin if (depth==0) valid_order <= 0; else depth <= depth - 1'b1; end
                        end
                        idx <= idx + 1'b1;
                    end
                end else if (idx == 16) begin
                    // Final check for Order 1
                    if (depth != 0) valid_order <= 1'b0;
                    
                    // Prepare for next state
                    check_s1_s2_done <= valid_order; // Save result of S1+S2 (valid_order might have been cleared if depth!=0)
                    // Wait, if we just updated valid_order in this cycle (idx==16), it takes 1 cycle to propagate. 
                    // To save the updated value, we need to wait or do it in next cycle.
                    // Let's handle the transition in the next cycle.
                    // So we stay in CHECK_S1_S2 for one extra cycle? 
                    // Or we just rely on combinational next_state to jump, and handle the 'save' in the state entry of CHECK_S2_S1.
                    // 
                    // Let's use the 'idx' to trigger a transition state.
                    // Actually, let's just increment idx to 17, and use that as the trigger.
                    idx <= idx + 1'b1; // 17
                end else if (idx == 17) begin
                    // Transition cycle
                    state <= CHECK_S2_S1;
                    idx <= 0;
                    depth <= 0;
                    // We need to capture the result. 
                    // The valid_order at the end of processing 16 chars (idx=16) was the result.
                    // But here we are at idx=17. valid_order is currently the result of check 1.
                    check_s1_s2_done <= valid_order;
                    valid_order <= 1'b1; // Reset for check 2
                end
            end
            else if (state == CHECK_S2_S1) begin
                if (idx < 16) begin
                    if (idx < 8) begin
                        if (str2[idx] == 8'h28) depth <= depth + 1'b1;
                        else if (str2[idx] == 8'h29) begin if (depth==0) valid_order <= 0; else depth <= depth - 1'b1; end
                    end else begin
                        if (str1[idx-8] == 8'h28) depth <= depth + 1'b1;
                        else if (str1[idx-8] == 8'h29) begin if (depth==0) valid_order <= 0; else depth <= depth - 1'b1; end
                    end
                    idx <= idx + 1'b1;
                end else if (idx == 16) begin
                     // Final check for Order 2
                    if (depth != 0) valid_order <= 1'b0;
                    idx <= idx + 1'b1;
                end else if (idx == 17) begin
                    state <= COMPUTE_RESULT;
                end
            end
            else if (state == COMPUTE_RESULT) begin
                // Compute final result:
                // valid_order contains result of S2+S1.
                // check_s1_s2_done contains result of S1+S2.
                if (valid_order || check_s1_s2_done) result <= 1'b1;
                else result <= 1'b0;
                done <= 1'b1;
                state <= DONE;
            end
            else if (state == DONE) begin
                // Stay here
            end
        end
    end

endmodule
