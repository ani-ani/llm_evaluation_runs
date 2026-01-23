module team_selection (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] p,
    input [2:0] s,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [15:0] max_strength,
    output reg [2:0] prog_indices [0:7],
    output reg [2:0] sports_indices [0:7],
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam PREPARE = 3'b001;
    localparam GENERATE_COMBOS = 3'b010;
    localparam EVALUATE = 3'b011;
    localparam UPDATE = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] current_state, next_state;

    // Internal Registers and Wires
    reg [7:0] prog_mask;
    reg [7:0] sports_mask;
    reg [7:0] remaining_mask;
    
    // Pseudo-random number generator for sports mask generation (LFSR-like)
    reg [7:0] random_state;
    wire [7:0] next_random = {random_state[6:0], random_state[7] ^ random_state[6] ^ random_state[5] ^ random_state[4]};

    // Counters and Flags
    reg [3:0] prog_idx_counter; // Used to iterate through 0..7 for prog_mask generation
    reg [3:0] sports_idx_counter; // Used to iterate through 0..7 for sports_mask generation
    reg [7:0] prog_bit_count;
    reg [7:0] sports_bit_count;
    reg found_valid_prog;
    reg found_valid_sports;
    
    // Evaluation Registers
    reg [15:0] current_strength;
    reg [7:0] temp_prog_sum;
    reg [7:0] temp_sports_sum;
    reg [3:0] bit_idx; // For loop index
    
    // Update Registers
    reg [2:0] temp_prog_indices [0:7];
    reg [2:0] temp_sports_indices [0:7];
    reg [3:0] temp_prog_cnt;
    reg [3:0] temp_sports_cnt;
    reg [3:0] i_update; // Loop index for update state

    // Helper function to count bits (combinational)
    function [3:0] count_set_bits;
        input [7:0] val;
        integer i;
        begin
            count_set_bits = 0;
            for (i = 0; i < 8; i = i + 1) begin
                if (val[i]) count_set_bits = count_set_bits + 1;
            end
        end
    endfunction

    // Helper function to get indices from mask
    function void get_indices;
        input [7:0] mask;
        output [2:0] indices [0:7];
        integer i, j;
        begin
            j = 0;
            for (i = 0; i < 8; i = i + 1) begin
                if (mask[i]) begin
                    indices[j] = i[2:0];
                    j = j + 1;
                end
            end
            // Fill remaining with 0
            for (i = j; i < 8; i = i + 1) begin
                indices[i] = 3'b000;
            end
        end
    endfunction

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = PREPARE;
            end
            PREPARE: begin
                next_state = GENERATE_COMBOS;
            end
            GENERATE_COMBOS: begin
                // Check if we have found a valid programming mask
                if (found_valid_prog) begin
                    // Check if we have found a valid sports mask for this prog mask
                    if (found_valid_sports) begin
                        next_state = EVALUATE;
                    end else begin
                        // Continue searching sports masks
                        if (sports_idx_counter < 8'd255) next_state = GENERATE_COMBOS; // Keep looping
                        else next_state = GENERATE_COMBOS; // Should not happen if logic is correct
                    end
                end else begin
                    // Continue searching programming masks
                    next_state = GENERATE_COMBOS;
                end
                // Timeout/End condition for generation loops handled inside state logic
            end
            EVALUATE: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                next_state = GENERATE_COMBOS; // Go back to generate next sports mask or prog mask
                // Special check: if we are done completely (end of prog combos)
                // This requires checking flags in the state logic itself or a separate done check
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Logic for GENERATE_COMBOS State
    // This state manages nested loops:
    // 1. Find next prog_mask with p bits
    // 2. Find next sports_mask with s bits from remaining
    // 3. If no more sports masks, increment prog mask search
    // 4. If no more prog masks, go to DONE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prog_mask <= 8'h00;
            sports_mask <= 8'h00;
            prog_idx_counter <= 0;
            sports_idx_counter <= 0;
            found_valid_prog <= 0;
            found_valid_sports <= 0;
            random_state <= 8'hAA; // Seed
        end else if (current_state == PREPARE) begin
            // Reset counters to start search
            prog_idx_counter <= 0;
            prog_mask <= 8'h00;
            sports_idx_counter <= 0;
            sports_mask <= 8'h00;
            found_valid_prog <= 0;
            found_valid_sports <= 0;
            random_state <= 8'hAA;
        end else if (current_state == GENERATE_COMBOS) begin
            
            // --- Part 1: Find Programming Mask ---
            if (!found_valid_prog) begin
                // Iterate prog_idx_counter from 0 to 255 to find masks with p bits
                if (prog_idx_counter < 256) begin
                    prog_idx_counter <= prog_idx_counter + 1;
                    prog_mask <= prog_idx_counter; // Actually mask is just the counter value
                    
                    // Check bit count (Combinational check updates flags next cycle)
                    if (count_set_bits(prog_idx_counter) == p) begin
                        found_valid_prog <= 1;
                        // Reset sports search for this new prog mask
                        sports_idx_counter <= 0;
                        sports_mask <= 8'h00;
                        found_valid_sports <= 0;
                    end
                end else begin
                    // All programming masks exhausted
                    next_state <= DONE; // Force transition here for clarity
                end
            end 
            // --- Part 2: Find Sports Mask ---
            else begin
                // Search in remaining students
                remaining_mask = 8'hFF & ~prog_mask; // Combinational wire logic inside sequential block is usually discouraged but works for synthesis if handled carefully. 
                // However, we need to ensure 'prog_mask' is stable. Since we are in the loop for a fixed prog_mask, it is stable.
                
                // We need a way to iterate permutations of the remaining bits.
                // Simplest way: iterate all 256 values, check if subset of remaining and has s bits.
                if (sports_idx_counter < 256) begin
                    sports_idx_counter <= sports_idx_counter + 1;
                    
                    // Check conditions
                    // 1. Has s bits
                    // 2. Is subset of remaining (i & ~remaining == 0)
                    // Since we are incrementing, we can't easily skip, so we check flags in the result?
                    // Wait, to keep it 1-cycle per iteration, we use combinational logic.
                    // But in a pure state machine, we check next cycle.
                    
                    // Let's update the mask
                    sports_mask <= sports_idx_counter; // Use counter as candidate
                    
                    // We need to signal if this candidate is valid for the *next* cycle (EVAL)
                    // But EVAL needs the mask. So we might need to verify in this cycle.
                    // Actually, let's just output the mask. The check happens in UPDATE or next GENERATE check.
                    // Let's use the flags to indicate we found it.
                    
                    // Combinational check for validity
                    if (count_set_bits(sports_idx_counter) == s && 
                        (sports_idx_counter & ~remaining_mask) == 0 && 
                        (sports_idx_counter & prog_mask) == 0) begin
                        found_valid_sports <= 1;
                    end else begin
                        found_valid_sports <= 0;
                    end
                    
                end else begin
                    // No more sports masks for this prog mask
                    found_valid_prog <= 0; // Trigger next prog mask search
                    found_valid_sports <= 0;
                end
            end
        end else if (current_state == UPDATE) begin
            // After evaluation, we need to move to the next combination.
            // The nextState logic says go to GENERATE_COMBOS.
            // If we found a valid pair, we must invalidate sports_mask to look for the NEXT one.
            // Or if we found the last one, invalidate prog.
            
            if (found_valid_sports) begin
                found_valid_sports <= 0; // Continue searching sports for this prog
                sports_idx_counter <= sports_idx_counter + 1; // Start search from next number (technically already incremented in gen state, but flags reset is key)
                // Wait, the previous increment happened in GENERATE state. 
                // So we just need to reset found_valid_sports to allow finding the next one.
            end
            // If we finished sports search in previous cycle, found_valid_prog was reset. 
        end else if (current_state == DONE) begin
            // Stay done
        end
    end

    // Fix for Generate Logic:
    // The sequential block above handles the iteration. 
    // But we need to handle the transition from "found sports" -> "evaluate" -> "look for next sports".
    // The current structure in seq block sets flags at the end of the cycle.
    // Let's refine the logic to ensure smooth transition.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prog_mask <= 8'h00;
            sports_mask <= 8'h00;
            found_valid_prog <= 0;
            found_valid_sports <= 0;
        end else if (current_state == PREPARE) begin
            prog_idx_counter <= 0;
            prog_mask <= 8'h00;
            found_valid_prog <= 0;
            found_valid_sports <= 0;
        end else if (current_state == GENERATE_COMBOS) begin
            if (!found_valid_prog) begin
                // Search Programming
                if (prog_idx_counter < 255) begin
                    prog_idx_counter <= prog_idx_counter + 1;
                    if (count_set_bits(prog_idx_counter + 1) == p) begin
                        prog_mask <= prog_idx_counter + 1;
                        found_valid_prog <= 1;
                        sports_idx_counter <= 0;
                        found_valid_sports <= 0;
                    end
                end else begin
                    // Finished all prog masks, go to DONE (handled by next_state logic usually, but let's flag it)
                end
            end else begin
                // Search Sports
                if (sports_idx_counter < 255) begin
                    sports_idx_counter <= sports_idx_counter + 1;
                    // Check next value (counter + 1) because counter is just incremented at end of cycle?
                    // Actually, let's just check current counter value, but increment it if not valid or after use.
                    // Better: Use a 'candidate' check.
                    
                    // Check the candidate: sports_idx_counter + 1
                    reg [7:0] candidate;
                    candidate = sports_idx_counter + 1;
                    if (count_set_bits(candidate) == s && (candidate & ~prog_mask) == 0 && candidate != 0) begin
                        sports_mask <= candidate;
                        found_valid_sports <= 1;
                    end else begin
                        found_valid_sports <= 0;
                    end
                end else begin
                    // Exhausted sports for this prog
                    found_valid_prog <= 0;
                    found_valid_sports <= 0;
                end
            end
        end else if (current_state == UPDATE) begin
            // If we updated, we are done with this sports mask. 
            // We need to invalidate found_valid_sports so GENERATE_COMBOS continues loop.
            found_valid_sports <= 0;
            // sports_idx_counter was already incremented in GENERATE state.
            // If we were in GENERATE and found valid, we increment counter next cycle (which is effectively this cycle logic).
            // Wait, the increment happens in GENERATE state. 
            // So, by the time we enter UPDATE, the counter is pointing to the valid mask.
            // In UPDATE, we just need to reset found_valid_sports to let GENERATE move to next.
        end
    end

    // Fix for the "< 256" loops. 
    // We need to stop at 255. 
    // Also, we need to detect when search is exhausted to transition to DONE or next step.
    
    // Let's handle the loops cleanly.
    // In GENERATE_COMBOS state:
    // If !found_valid_prog:
    //   Check values 0..255. 
    //   If p==0, we need a special case (mask 0).
    //   We iterate. If we reach 256, we are done.
    // If found_valid_prog:
    //   If !found_valid_sports:
    //     Check values 0..255 for sports.
    //     Limit: only lower bits corresponding to ~prog_mask.
    //     If we reach 256, we are done with this prog mask.
    
    // Refined Sequential Block for Loop Counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prog_mask <= 0;
            sports_mask <= 0;
            prog_idx_counter <= 0;
            sports_idx_counter <= 0;
            found_valid_prog <= 0;
            found_valid_sports <= 0;
        end else if (start && current_state == IDLE) begin
             // Initialize in PREPARE, handled below
             prog_idx_counter <= 0;
        end else if (current_state == PREPARE) begin
            prog_idx_counter <= 0;
            prog_mask <= 0;
            sports_idx_counter <= 0;
            sports_mask <= 0;
            found_valid_prog <= (p == 0); // If p=0, we immediately have a valid prog mask (0)
            found_valid_sports <= (s == 0); // If s=0, sports mask is 0
            if (p == 0) prog_mask <= 0;
            if (s == 0) sports_mask <= 0;
            if (p == 0 && s == 0) begin
                // Special case: start immediately in Evaluate if both 0 (already valid)
            end
        end else if (current_state == GENERATE_COMBOS) begin
            // --- Logic for Programming Search ---
            if (!found_valid_prog) begin
                if (p == 0) begin
                    found_valid_prog <= 1;
                    prog_mask <= 0;
                    sports_idx_counter <= 0;
                end else begin
                    if (prog_idx_counter < 255) begin
                        prog_idx_counter <= prog_idx_counter + 1;
                        // Check the incremented value
                        if (count_set_bits(prog_idx_counter + 1) == p) begin
                            prog_mask <= prog_idx_counter + 1;
                            found_valid_prog <= 1;
                            sports_idx_counter <= 0;
                            found_valid_sports <= (s == 0); // If s is 0, sports is valid immediately
                            if (s == 0) sports_mask <= 0;
                        end
                    end else begin
                        // Search exhausted, go to DONE (handled in next_state logic by preventing state transition or explicit signal)
                        // We set a flag or just rely on next_state to change to DONE if no progress?
                        // Let's force next_state to DONE in a combinational block.
                    end
                end
            end
            // --- Logic for Sports Search ---
            else if (found_valid_prog && !found_valid_sports) begin
                if (s == 0) begin
                    found_valid_sports <= 1;
                    sports_mask <= 0;
                end else begin
                    if (sports_idx_counter < 255) begin
                        sports_idx_counter <= sports_idx_counter + 1;
                        // Check candidate
                        reg [7:0] candidate;
                        candidate = sports_idx_counter + 1;
                        // Must be subset of remaining and have s bits
                        if (count_set_bits(candidate) == s && (candidate & ~prog_mask) == 0 && candidate != 0) begin
                            sports_mask <= candidate;
                            found_valid_sports <= 1;
                        end else begin
                            found_valid_sports <= 0;
                        end
                    end else begin
                        // No more sports for this prog. Reset prog flag to search next prog.
                        found_valid_prog <= 0;
                        found_valid_sports <= 0;
                    end
                end
            end
            // --- Logic if we found both ---
            else if (found_valid_prog && found_valid_sports) begin
                // We are transitioning to EVALUATE in the next cycle (handled by next_state logic).
                // So we do nothing here, or we can prepare for the next step.
            end
        end else if (current_state == UPDATE) begin
            // After evaluating, we are done with this sports mask. 
            // We invalidate it to continue the search in GENERATE state.
            // The sports_idx_counter has already been incremented in GENERATE state logic (if we were iterating).
            // Wait, logic flow: GENERATE (find valid) -> next_state EVAL -> EVAL -> UPDATE.
            // In GENERATE state, we increment counter and check.
            // So by UPDATE, the counter is at the valid value.
            // We just need to reset found_valid_sports to let GENERATE continue iterating.
            found_valid_sports <= 0;
        end else if (current_state == DONE) begin
            // Keep values
        end
    end

    // NEXT STATE LOGIC FIX:
    // Handle transitions out of GENERATE_COMBOS properly
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = PREPARE;
                else next_state = IDLE;
            end
            PREPARE: begin
                next_state = GENERATE_COMBOS;
            end
            GENERATE_COMBOS: begin
                if (found_valid_prog && found_valid_sports) begin
                    next_state = EVALUATE;
                end else if (!found_valid_prog && prog_idx_counter == 255) begin
                    // Exhausted programming masks
                    next_state = DONE;
                end else if (found_valid_prog && !found_valid_sports && sports_idx_counter == 255) begin
                    // Exhausted sports masks for this prog mask
                    // Logic in sequential block resets found_valid_prog, so we loop back to GENERATE
                    next_state = GENERATE_COMBOS;
                end else begin
                    // Keep searching
                    next_state = GENERATE_COMBOS;
                end
            end
            EVALUATE: begin
                next_state = UPDATE;
            end
            UPDATE: begin
                // Return to GENERATE to look for next combination
                next_state = GENERATE_COMBOS;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // --- EVALUATE LOGIC ---
    // Calculate sum of a_i for bits in prog_mask and b_i for bits in sports_mask
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_prog_sum <= 0;
            temp_sports_sum <= 0;
            bit_idx <= 0;
        end else if (current_state == EVALUATE) begin
            // We can unroll this or use a small counter. 
            // Since latency is allowed, let's do it in 1 cycle combinational logic inside an always block, 
            // or spread it over 8 cycles. 3000 cycles allowed, so 8 cycles is negligible.
            // Let's do it combinational for speed (if area allows) or sequential.
            // Sequential is safer for timing.
            
            if (bit_idx < 8) begin
                if (prog_mask[bit_idx]) temp_prog_sum <= temp_prog_sum + a[bit_idx];
                if (sports_mask[bit_idx]) temp_sports_sum <= temp_sports_sum + b[bit_idx];
                bit_idx <= bit_idx + 1;
            end else begin
                // Reset for next time (though we will overwrite in state logic)
                temp_prog_sum <= 0;
                temp_sports_sum <= 0;
                bit_idx <= 0;
            end
        end else if (current_state == PREPARE) begin
            temp_prog_sum <= 0;
            temp_sports_sum <= 0;
            bit_idx <= 0;
        end
    end

    // Calculate final sum for UPDATE state
    always @(*) begin
        if (current_state == UPDATE && bit_idx == 8) begin
            current_strength = temp_prog_sum + temp_sports_sum;
        end else begin
            current_strength = 0;
        end
    end

    // --- UPDATE LOGIC ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_strength <= 0;
            // Clear indices
            for (int i = 0; i < 8; i++) begin
                prog_indices[i] <= 0;
                sports_indices[i] <= 0;
            end
            done <= 0;
        end else if (current_state == PREPARE) begin
            max_strength <= 0;
            done <= 0;
        end else if (current_state == UPDATE) begin
            if (current_strength > max_strength) begin
                max_strength <= current_strength;
                // Update Indices
                // Need to convert masks to index lists
                // This requires a loop
                // To save combinational logic, let's do it here
                
                // Using a helper task or inline logic
                // We can update indices sequentially over a few cycles if needed, but let's try to pack it
                // Since UPDATE is one state, we need to generate indices combinationally or use helper registers.
                // Given the instructions allow latency, let's do it sequentially in the UPDATE state if we had more states,
                // but we must do it in UPDATE or combinational output.
                // Let's use a combinational function call inside the block or update directly.
                // Verilog functions must be static (no blocking assignments inside).
                
                // Solution: Update indices over multiple cycles? No, just use combinational logic to generate the arrays, then latch them.
                
                // Let's use the function get_indices defined earlier.
                // However, functions in always blocks can be tricky. Let's just do it manually.
                
                // This might be heavy for combinational logic, so let's break it down if needed.
                // But since it's just 8 bits, it's fine.
                
                integer i;
                integer p_idx;
                integer s_idx;
                
                p_idx = 0;
                s_idx = 0;
                
                // Clear temp arrays (or just overwrite valid ones)
                // We assign to 'prog_indices' directly. 
                // But 'prog_indices' is an array of regs. We can't assign to an array in one line.
                // We must loop.
                
                for (i = 0; i < 8; i = i + 1) begin
                    if (prog_mask[i]) begin
                        prog_indices[p_idx] <= i[2:0];
                        p_idx = p_idx + 1;
                    end
                    if (sports_mask[i]) begin
                        sports_indices[s_idx] <= i[2:0];
                        s_idx = s_idx + 1;
                    end
                end
                // Invalidate remaining indices? Not required, but good practice
                // We can't really do "prog_indices[p_idx] <= 0" because p_idx is variable in loop.
                // The requirement says "others ignored". 
                // However, if p=3, indices are 0,1,2. We might want to clear 3..7 if they were previously set from a smaller p?
                // Since we update max_strength, we update indices. We should clear the rest.
                
                // To clear the rest:
                for (i = p_idx; i < 8; i = i + 1) prog_indices[i] <= 3'b000;
                for (i = s_idx; i < 8; i = i + 1) sports_indices[i] <= 3'b000;
                
            end
        end else if (current_state == DONE) begin
            done <= 1;
        end
    end

endmodule
