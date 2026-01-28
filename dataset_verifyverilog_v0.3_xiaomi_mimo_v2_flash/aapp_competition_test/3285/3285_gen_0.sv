module scaled_sds (
    input clk,
    input rst_n,
    input [7:0] r,
    input [7:0] m,
    input start,
    output reg [7:0] n,
    output reg found,
    output reg done
);

    // Parameters
    localparam [7:0] MAX_N = 8'd64;
    localparam [7:0] MAX_M = 8'd256;
    localparam [4:0] VAL_WIDTH = 5'd16;
    localparam [7:0] NUM_STATES = 8'd9;

    // State declarations
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] FIND_D          = 4'd1;
    localparam [3:0] SEARCH_D        = 4'd2;
    localparam [3:0] COMPUTE_A       = 4'd3;
    localparam [3:0] UPDATE_VALUE    = 4'd4;
    localparam [3:0] UPDATE_DIFF_INIT = 4'd5;
    localparam [3:0] UPDATE_DIFF     = 4'd6;
    localparam [3:0] CHECK           = 4'd7;
    localparam [3:0] DONE            = 4'd8;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] prev_A;
    reg [7:0] new_A;
    reg [7:0] i;
    reg [7:0] diff;
    reg [7:0] d;
    reg [15:0] seen_reg; // Using 16-bit for MAX_M up to 256 (needs 256 bits, using simplified 16-bit here as per VAL_WIDTH=16)
    // Note: MAX_M=256 requires 256 bits. Using 16-bit is insufficient. Expanding to 256 bits (16*16)
    reg [15:0] seen [0:15]; // 256 bits total
    reg [7:0] A_vals [0:63]; // MAX_N elements
    reg [7:0] sequence_val; // Store r initially
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Temporary variables for combinational logic
    integer j;
    reg [7:0] temp_d;
    reg found_d;
    reg [15:0] seen_idx;
    reg [3:0] seen_bit_idx;
    reg seen_bit;

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 8'd0;
            found <= 1'b0;
            done <= 1'b0;
            prev_A <= 8'd0;
            new_A <= 8'd0;
            i <= 8'd0;
            d <= 8'd0;
            cycle_count <= 8'd0;
            sequence_val <= 8'd0;
            // Initialize seen array
            for (j = 0; j < 16; j = j + 1) begin
                seen[j] <= 16'd0;
            end
            // Initialize A_vals array
            for (j = 0; j < 64; j = j + 1) begin
                A_vals[j] <= 8'd0;
            end
        end else begin
            // Default done is low (pulse for 1 cycle in DONE state)
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize on start
                        sequence_val <= r;
                        // Mark seen[r] = 1
                        seen_idx = r >> 4; // r / 16
                        seen_bit_idx = r[3:0]; // r % 16
                        seen[seen_idx][seen_bit_idx] <= 1'b1;
                        n <= 8'd1;
                        prev_A <= r;
                        A_vals[0] <= r;
                        cycle_count <= 8'd0;
                        found <= 1'b0;
                        if (r == m) begin
                            state <= DONE;
                            found <= 1'b1;
                        end else begin
                            state <= FIND_D;
                        end
                    end
                end

                FIND_D: begin
                    // Search for smallest missing integer (1..MAX_M)
                    // Start checking from 1
                    temp_d <= 8'd1;
                    found_d <= 1'b0;
                    state <= SEARCH_D;
                end

                SEARCH_D: begin
                    // Check if temp_d is seen
                    seen_idx = temp_d >> 4;
                    seen_bit_idx = temp_d[3:0];
                    seen_bit = seen[seen_idx][seen_bit_idx];
                    
                    if (!seen_bit) begin
                        // Found missing integer
                        d <= temp_d;
                        state <= COMPUTE_A;
                    end else if (temp_d < MAX_M) begin
                        temp_d <= temp_d + 8'd1;
                        state <= SEARCH_D;
                    end else begin
                        // Should not happen if MAX_M is large enough, but handle
                        d <= 8'd0; 
                        state <= COMPUTE_A;
                    end
                end

                COMPUTE_A: begin
                    new_A <= prev_A + d;
                    state <= UPDATE_VALUE;
                end

                UPDATE_VALUE: begin
                    // Store new_A
                    if (n < MAX_N) begin
                        A_vals[n] <= new_A;
                    end
                    // Increment n
                    n <= n + 8'd1;
                    // Mark seen[new_A]
                    seen_idx = new_A >> 4;
                    seen_bit_idx = new_A[3:0];
                    seen[seen_idx][seen_bit_idx] <= 1'b1;
                    
                    if (new_A == m) begin
                        found <= 1'b1;
                        state <= DONE;
                    end else begin
                        state <= UPDATE_DIFF_INIT;
                    end
                end

                UPDATE_DIFF_INIT: begin
                    i <= 8'd0;
                    state <= UPDATE_DIFF;
                end

                UPDATE_DIFF: begin
                    // diff = new_A - A_vals[i]
                    diff <= new_A - A_vals[i];
                    // Check conditions in next cycle (simpler logic flow)
                    // We need to check if i < n - 1 (where n was incremented in UPDATE_VALUE)
                    // Current n includes new element. So we check i < n - 1.
                    // But n was incremented. So check i < (n - 1) - 1? 
                    // Wait, loop is: for i=0 to n-2 (old n). 
                    // In UPDATE_VALUE, n becomes old_n + 1. 
                    // So loop limit is new_n - 2.
                    // If i < new_n - 2, repeat. Else go to CHECK.
                    
                    // We need to register the comparison result or handle it carefully.
                    // Let's compute next i here.
                    if (i < n - 8'd2) begin
                        i <= i + 8'd1;
                        state <= UPDATE_DIFF; // Stay in this state, update diff next cycle
                    end else begin
                        state <= CHECK;
                    end
                    // Note: We process the current 'diff' (for current i) in this cycle.
                    // Logic for marking seen is combinational or sequential?
                    // Better to do it sequentially.
                end
                // Correction: UPDATE_DIFF needs to handle the diff calculation and marking in one cycle per i.
                // The previous UPDATE_DIFF state transition logic is tricky because 'diff' changes.
                // Let's rewrite UPDATE_DIFF to handle one iteration.
                
                // Re-defining UPDATE_DIFF flow:
                // 1. Compute diff (handled above in the sequential block, but 'diff' register updates)
                // 2. Check if diff <= MAX_M. If yes, mark seen[diff].
                // 3. Check if diff == m. If yes, found=1, state=DONE.
                // 4. Check if loop is done (i >= n-2). If yes, CHECK. Else i++, UPDATE_DIFF.
                // Since 'diff' is registered, we can use it in this cycle.
                // Actually, we need to be careful. 'diff' update happens concurrently with state transition.
                // Let's put the logic inside the state block.
            endcase

            // Logic moved inside specific states for clarity and timing
            // Handling UPDATE_DIFF logic separately to avoid race conditions
            if (state == UPDATE_DIFF) begin
                // Current 'diff' corresponds to 'i' (before increment if we were doing it there)
                // Wait, if i increments in UPDATE_DIFF, then we process diff for current i.
                // Let's ensure 'diff' is computed for current 'i'.
                
                // We need to re-compute diff inside UPDATE_DIFF or rely on the sequential update.
                // Sequential update: diff <= new_A - A_vals[i];
                // This computes diff for OLD i if i updates in same cycle? 
                // No, i updates to i+1, but A_vals[i] refers to old i? 
                // In Verilog, if 'i' is updated, A_vals[i] uses NEW i? No, A_vals[i] uses the value of i at the start of the time step.
                // So if we do i <= i + 1; diff <= new_A - A_vals[i];
                // diff is computed with OLD i. Correct.
                
                // Now, process the 'diff' result:
                if (diff <= MAX_M && diff != 0) begin
                    // Mark seen[diff]
                    seen_idx = diff >> 4;
                    seen_bit_idx = diff[3:0];
                    seen[seen_idx][seen_bit_idx] <= 1'b1;
                    if (diff == m) begin
                        found <= 1'b1;
                        state <= DONE;
                    end
                end
                // If we didn't jump to DONE, continue loop or go to CHECK
                // The transition logic was set in the main case block.
                // We need to ensure we don't overwrite state if we found m.
                // But we set state <= DONE inside this if block. It will take precedence.
                // Wait, if diff==m, state <= DONE. If not, state remains as set in main case (CHECK or UPDATE_DIFF).
                // This is okay. Synthesis usually prioritizes last assignment.
                // To be safe, let's structure it.
                
                // We need a temporary flag to override state if found m.
                // Actually, let's just do it cleanly.
                if (diff == m) begin
                    found <= 1'b1;
                    state <= DONE;
                end else if (diff <= MAX_M && diff != 0) begin
                     seen_idx = diff >> 4;
                     seen_bit_idx = diff[3:0];
                     seen[seen_idx][seen_bit_idx] <= 1'b1;
                     // State transition handled by main logic (i increment check)
                     // But we need to make sure state is UPDATE_DIFF or CHECK.
                     // We already set next_state in main block.
                end
            end

            if (state == CHECK) begin
                // Check if seen[m] == 1
                seen_idx = m >> 4;
                seen_bit_idx = m[3:0];
                if (seen[seen_idx][seen_bit_idx]) begin
                    found <= 1'b1;
                    state <= DONE;
                end else if (n < MAX_N) begin
                    prev_A <= new_A;
                    state <= FIND_D;
                end else begin
                    found <= 1'b0;
                    state <= DONE;
                end
            end

            if (state == DONE) begin
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end

    // Combinational logic for state transition (to handle the updates properly)
    // Actually, to avoid complex combinational paths, we can use a separate combinational block
    // or handle transitions in the sequential block above. 
    // The sequential block above handles transitions. We need to ensure no overlaps.
    // The logic above is a bit mixed. Let's refine the sequential block to be purely procedural.
    
    // Re-writing the sequential block to be cleaner and strictly follow FSM flow
    // (The previous block was an attempt to mix C-like logic with Verilog, which can be error-prone)
    
    // Let's clean up the sequential block logic.
    // We will handle state transitions and updates within the always block.

endmodule

// Note: The logic above is dense. A cleaner implementation uses explicit next_state logic or
// clear sequential updates. Given the complexity, here is a refined version.

// Refined Module Implementation
module scaled_sds_refined (
    input clk,
    input rst_n,
    input [7:0] r,
    input [7:0] m,
    input start,
    output reg [7:0] n,
    output reg found,
    output reg done
);

    localparam [7:0] MAX_N = 8'd64;
    localparam [7:0] MAX_M = 8'd256;

    // State definitions
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] FIND_D          = 4'd1;
    localparam [3:0] SEARCH_D        = 4'd2;
    localparam [3:0] COMPUTE_A       = 4'd3;
    localparam [3:0] UPDATE_VALUE    = 4'd4;
    localparam [3:0] UPDATE_DIFF_INIT = 4'd5;
    localparam [3:0] UPDATE_DIFF     = 4'd6;
    localparam [3:0] CHECK           = 4'd7;
    localparam [3:0] DONE            = 4'd8;

    reg [3:0] state;
    reg [7:0] prev_A_reg;
    reg [7:0] new_A_reg;
    reg [7:0] i_reg;
    reg [7:0] d_reg;
    reg [7:0] diff_reg;
    reg [15:0] seen_reg [0:15]; // 256 bits
    reg [7:0] A_vals_reg [0:63];
    
    // Helper variables
    integer j;
    reg [7:0] search_val;
    reg search_found;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 8'd0;
            found <= 1'b0;
            done <= 1'b0;
            prev_A_reg <= 8'd0;
            new_A_reg <= 8'd0;
            i_reg <= 8'd0;
            d_reg <= 8'd0;
            diff_reg <= 8'd0;
            search_val <= 8'd0;
            search_found <= 1'b0;
            for (j = 0; j < 16; j = j + 1) seen_reg[j] <= 16'd0;
            for (j = 0; j < 64; j = j + 1) A_vals_reg[j] <= 8'd0;
        end else begin
            done <= 1'b0; // Default pulse
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Init
                        seen_reg[r[7:4]][r[3:0]] <= 1'b1;
                        n <= 8'd1;
                        prev_A_reg <= r;
                        A_vals_reg[0] <= r;
                        found <= 1'b0;
                        
                        if (r == m) begin
                            state <= DONE;
                            found <= 1'b1;
                        end else begin
                            state <= FIND_D;
                        end
                    end
                end

                FIND_D: begin
                    search_val <= 8'd1;
                    search_found <= 1'b0;
                    state <= SEARCH_D;
                end

                SEARCH_D: begin
                    if (!search_found) begin
                        if (search_val > MAX_M) begin
                            d_reg <= 8'd0; // Fallback, shouldn't happen with valid inputs
                            state <= COMPUTE_A;
                        end else if (!seen_reg[search_val[7:4]][search_val[3:0]]) begin
                            d_reg <= search_val;
                            state <= COMPUTE_A;
                        end else begin
                            search_val <= search_val + 8'd1;
                        end
                    end
                end

                COMPUTE_A: begin
                    new_A_reg <= prev_A_reg + d_reg;
                    state <= UPDATE_VALUE;
                end

                UPDATE_VALUE: begin
                    if (n < MAX_N) begin
                        A_vals_reg[n] <= new_A_reg;
                    end
                    n <= n + 8'd1;
                    seen_reg[new_A_reg[7:4]][new_A_reg[3:0]] <= 1'b1;
                    
                    if (new_A_reg == m) begin
                        found <= 1'b1;
                        state <= DONE;
                    end else begin
                        state <= UPDATE_DIFF_INIT;
                    end
                end

                UPDATE_DIFF_INIT: begin
                    i_reg <= 8'd0;
                    state <= UPDATE_DIFF;
                end

                UPDATE_DIFF: begin
                    // Compute diff for current i
                    diff_reg <= new_A_reg - A_vals_reg[i_reg];
                    
                    // Move to next state logic
                    // We need to process this diff in the SAME cycle or next?
                    // To save latency, let's process it in the same cycle if possible,
                    // but checking and updating seen takes logic.
                    // Let's do: Update diff in this cycle, check/mark in next cycle?
                    // No, too slow. Let's compute combinationally for the check.
                    // Actually, let's stick to registered logic for simplicity and robustness.
                    // We will compute diff (registered), and handle the logic for 'i' update.
                    
                    if (i_reg < n - 8'd2) begin
                        i_reg <= i_reg + 8'd1;
                    end else begin
                        state <= CHECK;
                    end
                end
            endcase
            
            // Logic that depends on registered values (from previous cycle of UPDATE_DIFF)
            // This handles the actions for the diff computed in the previous cycle.
            // This is a bit of a hybrid FSM.
            // A cleaner way is to have a separate state for checking the diff.
            // Let's add a CHECK_DIFF state.
            // But to keep states minimal (as requested):
            // We can rely on the fact that UPDATE_DIFF computes diff, and in the SAME cycle,
            // we can't update i_reg and process diff_reg effectively without logic races.
            // 
            // Revised Strategy for UPDATE_DIFF:
            // Cycle 1: Compute diff = new_A - A_vals[i]. Store in diff_reg.
            // Cycle 2: Process diff_reg (mark seen, check m). Then update i.
            // This doubles the loop latency, but ensures correctness.
            
            // To support this, we need a flag or separate state. 
            // Let's use a flag 'diff_processed'.
            // Or just use the state machine.
            // Let's add logic to handle the update if we are in UPDATE_DIFF.
            
            // Wait, if we do this inside the always block, we have two drivers for 'state'.
            // This is bad. 
            // Let's restart the UPDATE_DIFF logic to be robust.
            // We will compute diff in UPDATE_DIFF and immediately handle it.
            // But we need to check 'new_A' vs 'A_vals[i]'.
            // If we compute diff in UPDATE_DIFF, 'i' is the current index.
            // We check diff. If good, mark seen. If m, go DONE.
            // Then increment i.
            // This requires 'diff' to be combinational or we need a separate cycle.
            // Given the constraints, let's make 'diff' combinational for the UPDATE_DIFF state.
            
        end
    end
    
    // Combinational block for diff calculation to save a cycle
    wire [7:0] diff_comb;
    assign diff_comb = new_A_reg - A_vals_reg[i_reg];
    
    // Re-write the sequential block to use diff_comb and handle update logic carefully
    // This avoids the race condition and state driver conflict.
    
    // Final clean implementation inside the same module structure
    // We will override the previous always block logic with a cleaner version.

endmodule

// FINAL IMPLEMENTATION (Consolidated and Corrected)
module scaled_sds_final (
    input clk,
    input rst_n,
    input [7:0] r,
    input [7:0] m,
    input start,
    output reg [7:0] n,
    output reg found,
    output reg done
);

    localparam [7:0] MAX_N = 8'd64;
    localparam [7:0] MAX_M = 8'd256;

    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] FIND_D          = 4'd1;
    localparam [3:0] SEARCH_D        = 4'd2;
    localparam [3:0] COMPUTE_A       = 4'd3;
    localparam [3:0] UPDATE_VALUE    = 4'd4;
    localparam [3:0] UPDATE_DIFF_INIT = 4'd5;
    localparam [3:0] UPDATE_DIFF     = 4'd6;
    localparam [3:0] CHECK           = 4'd7;
    localparam [3:0] DONE            = 4'd8;

    reg [3:0] state;
    reg [7:0] prev_A;
    reg [7:0] new_A;
    reg [7:0] i;
    reg [7:0] d;
    reg [7:0] search_val;
    
    // Data storage
    reg [15:0] seen [0:15]; // 256 bits
    reg [7:0] A_vals [0:63];
    
    integer j;

    // Combinational helper for diff
    wire [7:0] diff;
    assign diff = new_A - A_vals[i];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n <= 8'd0;
            found <= 1'b0;
            done <= 1'b0;
            prev_A <= 8'd0;
            new_A <= 8'd0;
            i <= 8'd0;
            d <= 8'd0;
            search_val <= 8'd0;
            for (j = 0; j < 16; j = j + 1) seen[j] <= 16'd0;
            for (j = 0; j < 64; j = j + 1) A_vals[j] <= 8'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize sequence
                        seen[r[7:4]][r[3:0]] <= 1'b1;
                        n <= 8'd1;
                        prev_A <= r;
                        A_vals[0] <= r;
                        found <= 1'b0;
                        
                        if (r == m) begin
                            found <= 1'b1;
                            state <= DONE;
                        end else begin
                            state <= FIND_D;
                        end
                    end
                end

                FIND_D: begin
                    // Start searching from 1
                    search_val <= 8'd1;
                    state <= SEARCH_D;
                end

                SEARCH_D: begin
                    // Check if search_val is seen
                    if (search_val > MAX_M) begin
                        // If all integers up to MAX_M are seen, pick d=0 (should not happen in valid cases)
                        d <= 8'd0;
                        state <= COMPUTE_A;
                    end else if (!seen[search_val[7:4]][search_val[3:0]]) begin
                        d <= search_val;
                        state <= COMPUTE_A;
                    end else begin
                        search_val <= search_val + 8'd1;
                    end
                end

                COMPUTE_A: begin
                    new_A <= prev_A + d;
                    state <= UPDATE_VALUE;
                end

                UPDATE_VALUE: begin
                    // Store new_A in sequence
                    if (n < MAX_N) begin
                        A_vals[n] <= new_A;
                    end
                    // Increment n
                    n <= n + 8'd1;
                    // Mark seen
                    seen[new_A[7:4]][new_A[3:0]] <= 1'b1;
                    
                    if (new_A == m) begin
                        found <= 1'b1;
                        state <= DONE;
                    end else begin
                        state <= UPDATE_DIFF_INIT;
                    end
                end

                UPDATE_DIFF_INIT: begin
                    i <= 8'd0;
                    state <= UPDATE_DIFF;
                end

                UPDATE_DIFF: begin
                    // Logic for current 'i' using 'diff' combinational wire
                    // Mark seen[diff] if diff <= MAX_M and diff != 0
                    // Note: diff is computed from current new_A and A_vals[i]
                    if (diff <= MAX_M && diff != 0) begin
                        seen[diff[7:4]][diff[3:0]] <= 1'b1;
                        if (diff == m) begin
                            found <= 1'b1;
                            state <= DONE;
                        end
                    end
                    
                    // Update i and check loop condition
                    if (found) begin
                        // If found, state is already DONE (or will be overwritten? No, if found, we set state <= DONE)
                        // In Verilog, multiple assignments to same variable in a block take the last one.
                        // We need to ensure DONE takes priority.
                        // Let's structure it so we check found before updating state.
                        // But here, if found==1, we jump to DONE. 
                        // If not found, continue.
                    end
                    
                    if (i < n - 8'd2) begin
                        i <= i + 8'd1;
                        if (diff == m) state <= DONE;
                        else state <= UPDATE_DIFF;
                    end else begin
                        if (diff == m) state <= DONE;
                        else state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check if m is in seen set (should be redundant if logic is correct, but as per spec)
                    if (seen[m[7:4]][m[3:0]]) begin
                        found <= 1'b1;
                        state <= DONE;
                    end else if (n < MAX_N) begin
                        prev_A <= new_A;
                        state <= FIND_D;
                    end else begin
                        found <= 1'b0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule