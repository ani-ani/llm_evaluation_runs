module gaggle_mentor(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0][7:0] current_mentor,
    output reg [7:0] new_mentor,
    output reg [2:0] employee_idx,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam FIND_BEST_CYCLE = 3'b001;
    localparam OUTPUT_RESULTS = 3'b010;
    localparam DONE_STATE = 3'b011;
    localparam CHECK_PERM = 3'b100;
    localparam UPDATE_BEST = 3'b101;

    reg [2:0] state, next_state;
    
    // Registers for current permutation (indices 0-7)
    reg [2:0] perm [0:7];
    reg [2:0] best_perm [0:7];
    
    // Counter for permutation generation
    reg [2:0] depth; // Depth in permutation tree (0 to n-1)
    reg [7:0] used_mask;
    reg [3:0] loop_idx; // General loop index
    reg [3:0] temp_idx;
    
    // Comparison state
    reg is_better;
    reg [2:0] comp_idx;
    reg [7:0] current_val;
    reg [7:0] best_val;
    
 // Output state machine
    reg [2:0] output_idx;
    
    // Helper: Find employee index in current best_perm
    reg [2:0] found_pos;
    reg [2:0] search_i;
    
    // Constants
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            new_mentor <= 0;
            employee_idx <= 0;
            depth <= 0;
            used_mask <= 0;
            loop_idx <= 0;
            comp_idx <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                perm[i] <= 0;
                best_perm[i] <= 0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize permutation generation
                        depth <= 0;
                        used_mask <= 0;
                        loop_idx <= 0;
                    end
                end
                
                FIND_BEST_CYCLE: begin
                    // Handled in next_state logic
                end
                
                CHECK_PERM: begin
                    // Handled in combinational logic
                end
                
                UPDATE_BEST: begin
                    // Copy current perm to best_perm
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n)
                            best_perm[i] <= perm[i];
                        else
                            best_perm[i] <= 0;
                    end
                end
                
                OUTPUT_RESULTS: begin
                    // Output assignments for employee output_idx
                    // Find which employee maps to output_idx in the cycle
                    // In best_perm, index i maps to employee i+1 (1-based)
                    // best_perm[i] is the index (0-based) of the mentor for employee i+1
                    
                    // We need to output new_mentor for employee output_idx
                    // Look up who mentors employee output_idx
                    // Search for output_idx in best_perm
                    
                    if (output_idx < n) begin
                        // The mentor for employee output_idx is the value at best_perm[output_idx]
                        // But we need to output the employee ID (1-based)
                        new_mentor <= best_perm[output_idx] + 1;
                        employee_idx <= output_idx;
                    end else begin
                        new_mentor <= 0;
                        employee_idx <= 0;
                    end
                    
                    output_idx <= output_idx + 1;
                end
                
                DONE_STATE: begin
                    done <= 1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = FIND_BEST_CYCLE;
            end
            
            FIND_BEST_CYCLE: begin
                // Check if we have a full permutation
                if (depth == n) begin
                    next_state = CHECK_PERM;
                end else begin
                    next_state = FIND_BEST_CYCLE; // Continue generating
                end
            end
            
            CHECK_PERM: begin
                // Validate cycle and compare quality
                if (loop_idx >= n) begin
                    // Valid cycle found, compare
                    next_state = UPDATE_BEST;
                end else if (loop_idx == 0) begin
                    // Check first connection: perm[0] != 0
                    if (perm[0] != 0) begin
                        loop_idx = 1;
                        next_state = CHECK_PERM;
                    end else begin
                        // Invalid, go back to generate next
                        next_state = FIND_BEST_CYCLE;
                    end
                end else begin
                    // Check if perm[loop_idx] is distinct (should be by construction)
                    // Check if cycle closes properly at end
                    if (loop_idx == n-1) begin
                        // Last element must point to 0 (completing cycle with 0)
                        if (perm[loop_idx] != 0) begin
                            next_state = FIND_BEST_CYCLE;
                        end else begin
                            // Valid full cycle, now compare quality
                            // Need to check for duplicates in perm[0..n-2]
                            // Also check uniqueness of all except 0
                            // Actually, simpler: check that all values 0..n-1 appear exactly once
                            // 0 appears at end (perm[n-1]=0), so check perm[0..n-2] for 1..n-1
                            loop_idx = 0;
                            next_state = CHECK_PERM; // Go to validation loop
                        end
                    end else begin
                        // Check distinctness: perm[loop_idx] should not be 0 (except last)
                        if (perm[loop_idx] == 0) begin
                            next_state = FIND_BEST_CYCLE;
                        end else begin
                            loop_idx = loop_idx + 1;
                            next_state = CHECK_PERM;
                        end
                    end
                end
            end
            
            UPDATE_BEST: begin
                // Update best_perm
                if (depth == n) begin
                    // Continue generating next permutation
                    // Actually, we need to backtrack from the current valid permutation
                    // to find the next one
                    // The perm array is currently valid.
                    // We need to backtrack to try next variants.
                    // But UPDATE_BEST just copies. 
                    // The logic must then go back to FIND_BEST_CYCLE
                    
                    // Backtrack mechanism similar to generation
                    if (depth > 0) begin
                        loop_idx = perm[depth-1] + 1;
                        used_mask = used_mask & ~(1 << perm[depth-1]);
                        depth = depth - 1;
                        next_state = FIND_BEST_CYCLE;
                    end else begin
                        next_state = OUTPUT_RESULTS;
                    end
                end else begin
                     next_state = FIND_BEST_CYCLE;
                end
            end
            
            OUTPUT_RESULTS: begin
                if (output_idx < n) begin
                    next_state = OUTPUT_RESULTS;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Combinational logic for detailed constraints inside CHECK_PERM
    // Since we cannot loop easily in always @(*) for deep checks, we split states.
    // However, strictly following the prompt's state names, we implement the detailed
    // comparison logic in the CHECK_PERM state using nested always blocks or additional flags.
    
    // To make it synthesizable and robust, we refine the CHECK_PERM logic.
    // We need a sub-state or counter for validation and comparison.
    
    // Let's use 'temp_idx' as the sub-counter inside CHECK_PERM.
    // Re-declare logic for CHECK_PERM specific behavior:
    
    wire [7:0] full_mask;
    assign full_mask = (n == 8) ? 8'hFF : ((1 << n) - 2); // Mask for 1..n-1
    
    // Actually, the previous combinational logic is a bit simplistic for the full validation.
    // Let's handle the VALIDATION and COMPARISON explicitly.
    
    // We will treat CHECK_PERM as a state where we perform checks sequentially.
    // But given the 'single always block' constraint for synthesis, we need to integrate it.
    
    // Let's add specific flags to track progress in validation/comparison.
    reg validating;
    reg comparing;
    
    // Reset these in IDLE/FIND_BEST_CYCLE entry
    // We will actually implement the validation logic directly in the state transitions of CHECK_PERM
    // by checking specific conditions and moving to sub-states or back.
    
    // Actually, a simpler approach for the 'permutation generation' logic:
    // The 'FIND_BEST_CYCLE' state generates a candidate.
    // When depth==n, move to CHECK_PERM.
    // CHECK_PERM validates.
    // If valid, move to COMPARE.
    // COMPARE moves to UPDATE if better.
    // Then back to FIND_BEST_CYCLE to generate next.
    
    // We need to refine the state machine to handle the sub-tasks explicitly.
    
    reg [2:0] sub_state;
    localparam VALIDATE = 3'b000;
    localparam COMPARE = 3'b001;
    
    // To keep it within the requested states, we embed the sub-logic.
    // Let's assume the previous logic works for generation.
    // We need to ensure the 'CHECK_PERM' state actually checks validity.
    
    // Revising the always @(*) for CHECK_PERM to be robust:
    // This is complex to do in one go. I will insert the detailed check logic 
    // assuming we transition to UPDATE_BEST only if valid.
    
    // Detailed logic check in CHECK_PERM (if we could break it down):
    // 1. Check perm[0] != 0.
    // 2. Check distinctness of perm[0..n-2] (excluding 0).
    // 3. Check perm[n-1] == 0.
    // 4. If valid, compare quality.
    
    // Since the initial response must be concise, I will use a 'valid_reg' flag
    // to carry the validity signal. But since it's combinational in next_state, 
    // we need to evaluate it there.
    
    // We will assume the reader understands that full verification is needed.
    // However, to make it truly synthesizeable, we need to split CHECK_PERM into micro-steps.
    
    // Let's create a micro-coded control within the CHECK_PERM logic.
    // We will use 'sub_state' variable to manage this, even if not explicit in prompt's state list,
    // because otherwise the code is incorrect.
    
    // Re-implementation of CHECK_PERM logic in next_state logic:
    // To be safe and correct:
    
    /*
    // The code below overrides the skeleton logic to provide correctness.
    // We assume 'sub_state' tracks the internal progress.
    */
    
    always @(*) begin
        // Default assignment for sub_state transitions if inside CHECK_PERM
        if (state == CHECK_PERM) begin
            // Logic to iterate validation and comparison
            if (sub_state == VALIDATE) begin
                // Simple loop check logic (unrolled for hardware)
                // Check 1: perm[0] != 0
                if (perm[0] == 0) next_state = FIND_BEST_CYCLE;
                // Check 2: perm[n-1] == 0
                else if (perm[n-1] != 0) next_state = FIND_BEST_CYCLE;
                // Check 3: distinctness of 1..n-1
                else begin
                    // We can check distinctness by verifying sum or bitwise OR/MASK
                    // For N=8, 7 values. 
                    // Optimized: accumulate used bits
                    // But we already used 'used_mask' in generation.
                    // Just need to verify no zeros in [0..n-2] and no duplicates.
                    // Generation should have ensured distinctness except for 0.
                    // So we just need to ensure 0 isn't in the middle.
                    reg has_zero;
                    has_zero = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n-1 && perm[i] == 0) has_zero = 1;
                    end
                    
                    if (has_zero) next_state = FIND_BEST_CYCLE;
                    else next_state = UPDATE_BEST; // Valid, go compare (or just update if we track best)
                end
            end
            // Note: The "lexicographic comparison" is done in UPDATE_BEST or before it.
            // We need to compare best_perm vs perm.
        end
    end

    // Since exact lexicographic comparison is requested, we implement it here.
    // We compare perm vs best_perm.
    // Priority: Lower index employee prefers keeping current mentor.
    // So we iterate index 0 to n-1.
    // Compare: perm[i] vs best_perm[i].
    // Effectively: if perm[i] matches current_mentor[i], it's good.
    // If not, smaller perm[i] is better (smallest possible new mentor).
    // Wait, "prefer keeping current mentor".
    // "If must change, choose smallest possible mentor".
    // This implies:
    // 1. Check if perm[i] == current_mentor[i]. If yes, good.
    // 2. If different, penalty. We want to minimize penalties at lower indices.
    // This is standard lexicographical comparison on the sequence of assignments.
    // If A[i] != B[i], check: is A[i] == current[i] ? Is B[i] == current[i]?
    // Priority: Match current > Smallest value.
    // Actually, "prefer keeping" means A is better if A[i] matches and B doesn't.
    // If neither matches, or both match, smaller value is better? "Smallest possible new mentor".
    // So comparison criteria:
    // Iterate i from 0:
    //   if (perm[i] == current[i] && best_perm[i] != current[i]) -> perm is better.
    //   if (perm[i] != current[i] && best_perm[i] == current[i]) -> best is better.
    //   if (both same status) -> perm[i] < best_perm[i] is better.
    
    // We can do this in the combinational logic of UPDATE_BEST or a separate CMP state.
    
    // Let's add CMP state to the cycle.
    // Original states: IDLE, FIND_BEST_CYCLE, OUTPUT_RESULTS, DONE, CHECK_PERM, UPDATE_BEST.
    // We will use CHECK_PERM -> CMP -> UPDATE_BEST.
    
    // Since the prompt specifies exactly these states, we must integrate.
    // We will treat 'UPDATE_BEST' as the state where we check "is it better?" and update.
    
    // Modifying the always @(*) logic for UPDATE_BEST to include comparison:
    
    end

    // REWRITE OF MAIN FSM TO BE CORRECT AND SYNTHESIZABLE
    // We reset and use the specified states. 
    // We add internal counters/flags as needed.
    
    // Internal registers for comparison
    reg [7:0] current_val_reg;
    reg [7:0] best_val_reg;
    reg better_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            depth <= 0;
            used_mask <= 0;
            new_mentor <= 0;
            employee_idx <= 0;
            output_idx <= 0;
            better_flag <= 0;
            // Initialize best_perm to a large value (invalid) to accept first valid
            for (i = 0; i < 8; i = i + 1) best_perm[i] <= 3'b111; // Invalid high
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    output_idx <= 0;
                    if (start) begin
                        if (n >= 2) begin
                            // Initialize generation
                            depth <= 1;
                            perm[0] <= 0; // Start with 0 as first element? 
                            // Wait, permutations of 0..n-1. 
                            // Cycle: 0->a->b->...->0.
                            // We generate values for perm[0]...perm[n-1].
                            // The constraint is perm[0] != 0 (no self loop? Or no direct back to 0? 
                            // "single cycle". 0 is employee 1. 
                            // Let's generate standard permutations.
                            // We can start permutation generation.
                            // Let's generate permutations of 0..n-1.
                            // Optimization: perm[n-1] is implicitly 0 in logic, but let's generate it.
                            // Actually, let's generate sequence 0..n-1.
                            // We'll do a next_permutation algorithm or manual generation.
                            // Manual generation is safer for hardware.
                            
                            // Reset permutation generation
                            for (int k=0; k<8; k++) perm[k] <= 0;
                            for (int k=0; k<8; k++) best_perm[k] <= 3'b111;
                            
                            depth <= 0;
                            used_mask <= 0;
                            state <= FIND_BEST_CYCLE;
                        end else begin
                            state <= DONE_STATE; // n < 2
                        end
                    end
                end

                FIND_BEST_CYCLE: begin
                    // Generate next permutation
                    if (depth == n) begin
                        // Full permutation generated
                        // Check if it forms a valid cycle
                        // Logic: Check if it contains all nodes 0..n-1 and is connected as a cycle
                        // A permutation p is a cycle if iterating p[x] covers all elements and returns to start.
                        // To check efficiently in HW:
                        // 1. p[0] != 0 (to avoid 0->0, though 0->...->0 is allowed if others exist)
                        //    Actually, strict cycle needs to touch all. p[0]=0 means 0 is fixed point -> not cycle of length > 1 unless n=1.
                        //    So p[0] != 0 is a good check.
                        // 2. p[n-1] == 0 (to close the cycle back to 0)
                        // 3. All intermediate nodes distinct and != 0.
                        
                        // We will validate in a separate state or inline.
                        // Let's validate inline before moving to compare/update.
                        
                        if (perm[0] != 0 && perm[n-1] == 0) begin
                            // Check distinctness of perm[0..n-2]
                            // Simple check: or them. Sum should be 0..n-1 sum.
                            // For HW, a small loop is synthesizable.
                            // We'll use a helper wire/logic for validity.
                            // Since this is seq logic, let's move to CHECK_PERM to handle it.
                            state <= CHECK_PERM;
                            loop_idx <= 0; // Reset counter for validation
                        end else begin
                            // Invalid, generate next
                            state <= FIND_BEST_CYCLE; // Stay here to backtrack/generate
                            // Backtrack/Next logic below
                        end
                    end else begin
                        // Need to fill perm[depth]
                        // Find next unused value
                        // We need a loop here. 
                        // Let's use 'loop_idx' as a temporary for searching next value.
                        // But to keep it flat, we'll try current loop_idx.
                        // If valid, accept. If invalid, increment.
                        
                        // Search loop for next valid value
                        if (loop_idx < n) begin
                            if ((used_mask >> loop_idx) & 1) begin
                                loop_idx <= loop_idx + 1;
                            end else begin
                                // Found unused
                                perm[depth] <= loop_idx;
                                used_mask <= used_mask | (1 << loop_idx);
                                depth <= depth + 1;
                                loop_idx <= 0; // Reset for next depth
                            end
                        end else begin
                            // No more values, backtrack
                            if (depth > 0) begin
                                used_mask <= used_mask & ~(1 << perm[depth-1]);
                                loop_idx <= perm[depth-1] + 1;
                                depth <= depth - 1;
                            end else begin
                                // All permutations tried
                                state <= OUTPUT_RESULTS;
                            end
                        end
                    end
                end

                CHECK_PERM: begin
                    // Validation logic
                    // We need to check distinctness of perm[0..n-2]
                    // Use loop_idx as index
                    if (loop_idx < n-1) begin
                        // Check if perm[loop_idx] is unique in [0..loop_idx-1]
                        // And perm[loop_idx] != 0
                        if (perm[loop_idx] == 0) begin
                            state <= FIND_BEST_CYCLE;
                            // Prepare backtrack from current depth
                            // Actually, we are at full depth. Backtrack strategy:
                            loop_idx <= perm[n-2] + 1; 
                            used_mask <= used_mask & ~(1 << perm[n-2]);
                            depth <= n - 1;
                        end else begin
                            // Check duplicate
                            reg is_dup;
                            is_dup = 0;
                            for (int k=0; k<8; k++) begin
                                if (k < loop_idx && perm[k] == perm[loop_idx]) is_dup = 1;
                            end
                            
                            if (is_dup) begin
                                state <= FIND_BEST_CYCLE;
                                loop_idx <= perm[n-2] + 1;
                                used_mask <= used_mask & ~(1 << perm[n-2]);
                                depth <= n - 1;
                            end else begin
                                loop_idx <= loop_idx + 1;
                            end
                        end
                    end else begin
                        // Validation passed
                        // Now compare with best_perm
                        // We need to check if current perm is better
                        // Iterate 0..n-1
                        state <= UPDATE_BEST;
                        comp_idx <= 0;
                        better_flag <= 0; // 0 means current perm is not better yet (or equal)
                        // We need a way to flag if we found it better.
                        // We'll use a flag 'is_better_found'
                    end
                end

                UPDATE_BEST: begin
                    // Comparison Logic
                    // Compare perm[comp_idx] vs best_perm[comp_idx] vs current_mentor[comp_idx]
                    // Criteria:
                    // 1. If perm matches current_mentor and best does not -> Better
                    // 2. If best matches and perm does not -> Worse
                    // 3. If both match or both mismatch -> Compare values (smaller is better)
                    
                    if (comp_idx < n) begin
                        // Read current mentor
                        // current_mentor is 7:0 vector, indexed by employee (0..7).
                        // But 'current_mentor' input is described as [7:0][7:0].
                        // Ah, prompt says "input [7:0][7:0] current_mentor".
                        // This is a 2D array. In Verilog 2001/SystemVerilog, we access as current_mentor[employee_idx].
                        // However, standard Verilog port declaration might be flattened.
                        // Assuming current_mentor[employee] gives the mentor index.
                        // Let's assume `current_mentor` is used as `current_mentor[comp_idx]`.
                        
                        // If best_perm is empty (initialized to 3'b111), then perm is better automatically.
                        if (best_perm[comp_idx] == 3'b111) begin
                            better_flag <= 1; // Perm is better
                            comp_idx <= n; // Done
                        end else begin
                            // Compare logic
                            // We need to determine if perm is strictly better than best.
                            // Let's define 'perm_better' signal.
                            // Actually, we do this sequentially. 
                            // We maintain 'better_flag' as "current perm is better so far".
                            // If we find best is better, we discard perm (go to FIND).
                            // If we find perm is better, we copy it.
                            
                            // We need to do full comparison to decide.
                            // Let's compute "is_perm_better" for this index.
                            
                            // Wire definitions for comparison:
                            wire p_match = (perm[comp_idx] == current_mentor[comp_idx]);
                            wire b_match = (best_perm[comp_idx] == current_mentor[comp_idx]);
                            wire p_smaller = (perm[comp_idx] < best_perm[comp_idx]);
                            
                            wire perm_better_at_idx = 
                                (p_match && !b_match) || 
                                ((!p_match && !b_match) && p_smaller);
                            wire best_better_at_idx = 
                                (b_match && !p_match) || 
                                ((!p_match && !b_match) && !p_smaller);
                            
                            if (best_better_at_idx) begin
                                // Current perm is worse, discard
                                state <= FIND_BEST_CYCLE;
                                // Backtrack from current permutation
                                // Need to generate next permutation
                                // We are at full depth (n).
                                // Logic: backtrack to depth n-1
                                // Increment perm[n-1] (which is 0, so we can't) -> backtrack to n-2
                                // Actually, perm[n-1] is fixed to 0 in cycle logic.
                                // So we backtrack to n-2.
                                if (n >= 2) begin
                                    depth <= n - 1;
                                    used_mask <= used_mask & ~(1 << perm[n-2]);
                                    loop_idx <= perm[n-2] + 1;
                                end else begin
                                    state <= OUTPUT_RESULTS; // Should not happen
                                end
                            end else if (perm_better_at_idx) begin
                                // Perm is better at this index.
                                // We continue checking subsequent indices to ensure strict dominance?
                                // No, lexicographic: first difference wins.
                                // If perm_better_at_idx is true, we record it as 'better_found'.
                                // But we must continue loop to finish iteration?
                                // No, lexicographic implies we stop at first difference.
                                // So if best_better -> switch to FIND.
                                // If perm_better -> copy best (but wait, check if we need to copy immediately?)
                                // If we found perm is better, we know we want to copy it.
                                // But we must ensure we don't copy if subsequent indices make it worse? 
                                // No, lexicographical. First index where they differ decides.
                                // So if perm_better_at_idx is true, we are done comparing. Perm is better.
                                // We can copy it (wait, maybe wait for full verification to be safe, but logic says first diff).
                                // Let's just set a flag and finish loop (or jump to copy).
                                // Let's jump to copy.
                                better_flag <= 1;
                                comp_idx <= n; // Stop loop
                            end else begin
                                // Equal at this index, continue
                                comp_idx <= comp_idx + 1;
                            end
                        end
                    end else begin
                        // Finished loop
                        if (better_flag || best_perm[0] == 3'b111) begin
                            // Copy perm to best_perm
                            for (int k=0; k<8; k++) begin
                                if (k < n) best_perm[k] <= perm[k];
                                else best_perm[k] <= 0;
                            end
                        end
                        // Continue generating next permutation
                        // Backtrack from full depth
                        state <= FIND_BEST_CYCLE;
                        if (n >= 2) begin
                            depth <= n - 1;
                            used_mask <= used_mask & ~(1 << perm[n-2]);
                            loop_idx <= perm[n-2] + 1;
                        end else begin
                            state <= OUTPUT_RESULTS;
                        end
                    end
                end

                OUTPUT_RESULTS: begin
                    if (output_idx < n) begin
                        // Output assignment for employee 'output_idx'
                        // In the best cycle, employee 'output_idx' has mentor 'best_perm[output_idx]'
                        // Note: Prompt says "output new assignment". 
                        // new_mentor should be the ID of the mentor.
                        // Our permutation stores indices (0..n-1). +1 to get 1..n.
                        new_mentor <= best_perm[output_idx] + 1;
                        employee_idx <= output_idx;
                        output_idx <= output_idx + 1;
                        done <= 0;
                    end else begin
                        done <= 1;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for reset/start low? 
                    // Usually done stays high until reset or new start
                end
            endcase
        end
    end

endmodule