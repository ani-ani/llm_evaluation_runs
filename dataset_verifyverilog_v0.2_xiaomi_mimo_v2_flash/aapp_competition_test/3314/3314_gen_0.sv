module wheel_rotations_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] [1:0] wheel0,
    input [7:0] [1:0] wheel1,
    input [7:0] [1:0] wheel2,
    output reg [3:0] result,
    output reg done,
    output reg valid
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam PREP_OFFSET1 = 3'b001;
    localparam CHECK_OFFSET2 = 3'b010;
    localparam NEXT_OFFSET2 = 3'b011;
    localparam NEXT_OFFSET1 = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Registers for iteration
    reg [2:0] offset1; // 0 to 7
    reg [2:0] offset2; // 0 to 7
    reg [2:0] col_idx; // 0 to 7 for checking columns
    reg [3:0] current_cost;
    reg [3:0] min_cost_reg;
    reg found_valid;

    // Intermediate signals for validity check
    wire [1:0] w1_char;
    wire [1:0] w2_char;
    wire [1:0] w0_char;
    wire col_valid;

    // Combinational logic for current column lookup
    // w1 rotates by offset1: (col_idx + offset1) mod 8
    // w2 rotates by offset2: (col_idx + offset2) mod 8
    assign w1_char = wheel1[(col_idx + offset1) % 8];
    assign w2_char = wheel2[(col_idx + offset2) % 8];
    assign w0_char = wheel0[col_idx];

    // Check distinctness for current column
    // Requirement: w1 != w0, w2 != w0, w1 != w2
    assign col_valid = (w1_char != w0_char) && (w2_char != w0_char) && (w1_char != w2_char);

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? PREP_OFFSET1 : IDLE;

            PREP_OFFSET1: next_state = CHECK_OFFSET2;

            CHECK_OFFSET2: begin
                if (!col_valid)
                    next_state = NEXT_OFFSET2; // Invalid column, skip to next offset2
                else if (col_idx == 3'd7)
                    next_state = DONE; // All 8 columns valid, solution found
                else
                    next_state = CHECK_OFFSET2; // Continue checking next column
            end

            NEXT_OFFSET2: begin
                if (offset2 == 3'd7)
                    next_state = NEXT_OFFSET1;
                else
                    next_state = PREP_OFFSET1; // Loop back to prepare next offset2 check
            end

            NEXT_OFFSET1: begin
                if (offset1 == 3'd7)
                    next_state = DONE; // No valid config found
                else
                    next_state = PREP_OFFSET1;
            end

            DONE: next_state = IDLE; // Auto-reset or wait for next start

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic (State and Data Registers)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            offset1 <= 3'b0;
            offset2 <= 3'b0;
            col_idx <= 3'b0;
            min_cost_reg <= 4'b1111; // Initialize to max (15)
            found_valid <= 1'b0;
            result <= 4'b0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize iteration variables
                        offset1 <= 3'b0;
                        offset2 <= 3'b0;
                        col_idx <= 3'b0;
                        min_cost_reg <= 4'b1111;
                        found_valid <= 1'b0;
                        done <= 1'b0;
                        valid <= 1'b0;
                    end
                end

                PREP_OFFSET1: begin
                    // Reset offset2 and col_idx for new offset1 iteration
                    offset2 <= 3'b0;
                    col_idx <= 3'b0;
                end

                CHECK_OFFSET2: begin
                    if (col_valid) begin
                        if (col_idx == 3'd7) begin
                            // Solution found for current offsets
                            current_cost <= offset1 + offset2;
                            // We will update min_cost in NEXT_OFFSET2/1 logic or immediately
                        end else begin
                            // Continue to next column
                            col_idx <= col_idx + 1;
                        end
                    end else begin
                        // Invalid, jump to next offset2 (handled in NEXT_OFFSET2 state logic via transition)
                        // We don't update anything here, just transition
                    end
                end

                NEXT_OFFSET2: begin
                    // Check if we found a valid config in the previous CHECK_OFFSET2 cycle
                    // Note: If we reached here via !col_valid, col_idx might not be 7.
                    // If we reached here via col_idx==7 (done check), we need to update result.
                    // The transition logic handles DONE if col_idx==7, so we only reach here if !col_valid.
                    // However, if col_idx==7 and valid, we transition to DONE directly.
                    // Wait, if col_idx==7 and valid, next_state is DONE. So we don't enter NEXT_OFFSET2.
                    // Correct logic: 
                    // 1. If !col_valid: offset2++
                    // 2. If col_valid && col_idx == 7: Update min, Done logic (handled in DONE state?)
                    // Let's handle the update in the transition.

                    // Actually, let's refine the NEXT_OFFSET2 state.
                    // If we are here, it means either:
                    // A) col_valid was false. offset2 increments.
                    // B) Should not be here if col_valid was true and col_idx=7 (goes to DONE).

                    // Wait, if we iterate offset2, we must check if the previous one was valid.
                    // The 'done' condition for a specific offset pair is (col_valid && col_idx == 7).
                    // If that happens, the next_state is DONE.
                    // So if we are in state NEXT_OFFSET2, it implies the previous configuration failed.
                    // We just increment offset2.

                    // But wait, the cost comparison needs to happen if we found a solution.
                    // If we find a solution, we go to DONE immediately (from CHECK_OFFSET2).
                    // In DONE, we should update the final result.
                    // But we might find multiple solutions? No, we need the minimum cost.
                    // We find solution A. We check cost. We continue? No.
                    // The problem says "find the minimum". 
                    // We iterate offset1 0..7, offset2 0..7.
                    // If we find a valid pair, we check cost. If cost < current min, update min.
                    // Then we continue to next offset2? 
                    // Yes, because a later offset2 might be cheaper (e.g., offset1=0, offset2=2 is cheaper than 1,1).
                    // Wait, cost = offset1 + offset2.
                    // For fixed offset1, offset2 increases cost. So for a fixed offset1, the first valid offset2 is the cheapest.
                    // But for next offset1, it might be cheaper.
                    // Example: offset1=0, offset2=2 (cost 2). offset1=1, offset2=0 (cost 1).
                    // We need to search the whole space.

                    // Revised Logic:
                    // 1. Check configuration (off1, off2).
                    // 2. If valid:
                    //    Compare (off1 + off2) < min_cost.
                    //    If yes, update min_cost.
                    //    Then increment off2 (or off1?) and continue.
                    // 3. If invalid, increment off2.

                    // Let's refine the NEXT_OFFSET2 state.
                    // We need to know if we came from a valid configuration.
                    // We can use a flag or check col_idx.
                    // Actually, we can just check validity in the state machine.
                    // If we are in CHECK_OFFSET2 and it's valid and col_idx==7.
                    // We need to update min_cost.
                    // So let's modify CHECK_OFFSET2 to update cost on success.

                    // Correction to CHECK_OFFSET2 block logic:
                    // If valid and col_idx==7: update min_cost_reg, then go to NEXT_OFFSET2 (to increment off2).
                    // If valid and col_idx<7: increment col_idx.
                    // If invalid: go to NEXT_OFFSET2.

                    // So in NEXT_OFFSET2, we always increment offset2.
                    // Then check if offset2 reached 7. If yes, go to NEXT_OFFSET1.
                end

                NEXT_OFFSET1: begin
                    offset1 <= offset1 + 1;
                end

                DONE: begin
                    // Finalize result
                    if (found_valid) begin
                        result <= min_cost_reg;
                        valid <= 1'b1;
                    end else begin
                        result <= 4'd15;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Logic to update min_cost and found_valid flags needs to be handled correctly during transitions or inside states.
    // Let's handle it in the combinational update block or a separate sequential block.
    // It is safer to do it in the state execution.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == CHECK_OFFSET2 && col_valid && col_idx == 3'd7) begin
                // Found a valid configuration
                if (offset1 + offset2 < min_cost_reg) begin
                    min_cost_reg <= offset1 + offset2;
                end
                found_valid <= 1'b1;
            end
        end
    end

    // Update transition logic for NEXT_OFFSET2 to handle the offset2 increment
    // Since NEXT_OFFSET2 was defined in the combinational block, we need to ensure offset2 increments there.
    // Let's move the increment logic into the sequential block triggered by state transitions.

    // Actually, to keep the FSM clean, let's add a signal to trigger increments.
    // Or simply handle it in the sequential logic based on next_state.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // reset
        end else begin
            if (state == IDLE && start) begin
                // Initialization done in main block
            end else if (next_state == PREP_OFFSET1) begin
                // This triggers when:
                // 1. IDLE -> PREP_OFFSET1 (start)
                // 2. NEXT_OFFSET2 -> PREP_OFFSET1 (offset2 < 7)
                // 3. NEXT_OFFSET1 -> PREP_OFFSET1 (offset1 < 7)

                // If coming from NEXT_OFFSET2 (offset2 increment)
                if (state == NEXT_OFFSET2) begin
                    offset2 <= offset2 + 1;
                    col_idx <= 0;
                end
                // If coming from NEXT_OFFSET1 (offset1 increment)
                if (state == NEXT_OFFSET1) begin
                    offset1 <= offset1 + 1;
                    offset2 <= 0;
                    col_idx <= 0;
                end
                // If coming from IDLE, init is handled in IDLE state logic
            end else if (next_state == CHECK_OFFSET2 && state == PREP_OFFSET1) begin
                 // Just entered new offset pair check
                 col_idx <= 0;
            end else if (next_state == CHECK_OFFSET2 && state == CHECK_OFFSET2) begin
                 // Continuing check, increment col_idx
                 col_idx <= col_idx + 1;
            end
        end
    end

    // Fix the NEXT_OFFSET2 transition logic to handle the "offset2==7" case.
    // The previous combinational block for next_state had:
    // if (offset2 == 3'd7) next_state = NEXT_OFFSET1;
    // else next_state = PREP_OFFSET1;
    // But this check happens before offset2 is incremented in the sequential block.
    // So we need to be careful.

    // Let's rewrite the NEXT_OFFSET2 logic in the sequential block to be robust.
    // Instead of a complex state machine, let's use a counter-based approach or cleaner FSM.

    // Let's stick to the state definitions provided and fix the increment logic.
    // The state machine logic inside 'always @(*)' is correct based on current state/vars.
    // We just need to update vars in 'always @(posedge clk)'.

    // Redefining the sequential update for offsets/cols to be strictly aligned with states.

    // Re-implementation of sequential logic for clarity and correctness:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            offset1 <= 0;
            offset2 <= 0;
            col_idx <= 0;
            min_cost_reg <= 15;
            found_valid <= 0;
            done <= 0;
            valid <= 0;
            result <= 0;
        end else begin
            // Default assignments
            done <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PREP_OFFSET1;
                        offset1 <= 0;
                        min_cost_reg <= 15;
                        found_valid <= 0;
                    end
                end

                PREP_OFFSET1: begin
                    // Just a setup state, move to process offset2=0
                    offset2 <= 0;
                    col_idx <= 0;
                    state <= CHECK_OFFSET2;
                end

                CHECK_OFFSET2: begin
                    if (col_valid) begin
                        if (col_idx == 3'd7) begin
                            // Valid config found
                            if (offset1 + offset2 < min_cost_reg) begin
                                min_cost_reg <= offset1 + offset2;
                            end
                            found_valid <= 1'b1;

                            // Move to next offset2
                            if (offset2 == 3'd7) begin
                                state <= NEXT_OFFSET1;
                            end else begin
                                offset2 <= offset2 + 1;
                                col_idx <= 0; // Reset for next check
                                // Stay in CHECK_OFFSET2 (effectively NEXT_OFFSET2 logic combined)
                                // To optimize, we can just stay in CHECK_OFFSET2 but increment offset2
                            end
                        end else begin
                            // Check next column
                            col_idx <= col_idx + 1;
                        end
                    end else begin
                        // Invalid column, skip to next offset2
                        if (offset2 == 3'd7) begin
                            state <= NEXT_OFFSET1;
                        end else begin
                            offset2 <= offset2 + 1;
                            col_idx <= 0;
                            // Stay in CHECK_OFFSET2 to check new pair
                            // Note: This looks like we are reusing CHECK_OFFSET2 for the iteration.
                            // We need to ensure we don't get stuck if we increment offset2 here.
                            // It's fine because offset2 changes, so we check new pair.
                        end
                    end
                end

                NEXT_OFFSET1: begin
                    if (offset1 == 3'd7) begin
                        state <= DONE;
                    end else begin
                        offset1 <= offset1 + 1;
                        // Reset offset2 for next loop in PREP_OFFSET1 or handle here
                        // We can go to PREP_OFFSET1, or just reset offset2 and go to CHECK_OFFSET2
                        offset2 <= 0;
                        col_idx <= 0;
                        state <= CHECK_OFFSET2;
                    end
                end

                DONE: begin
                    // Result assignment is combinational or handled here
                    // We keep it combinational for 'valid' and 'result' usually,
                    // but since we have 'done' pulse, let's latch result.
                    if (found_valid) begin
                        result <= min_cost_reg;
                        valid <= 1'b1;
                    end else begin
                        result <= 4'd15;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE; // Auto clear for this specific problem or wait?
                    // Usually done stays high until reset or next start. 
                    // The prompt says "High when computation complete". 
                    // Staying in DONE state usually keeps 'done' high.
                    // Let's stay in DONE until reset or restart.
                    state <= DONE;
                    if (start) begin // Allow restart from DONE if start is asserted
                        state <= PREP_OFFSET1;
                        offset1 <= 0;
                        min_cost_reg <= 15;
                        found_valid <= 0;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule