module RankingSystem (
    input clk,
    input rst_n,
    input start,
    input [3:0] n, // Number of contests (2-10)
    input [3:0] m, // Number of contestants (2-8)
    input [7:0] scores [0:7][0:9], // 3D array: contestant, contest
    output reg [3:0] result_rank, // 1-based rank
    output reg done
);

    // State definition
    localparam IDLE = 3'b000;
    localparam SORT = 3'b001;
    localparam SUM_TOP4 = 3'b010;
    localparam COMPARE = 3'b011;
    localparam UPDATE_RANK = 3'b100;
    localparam FINISH = 3'b101;

    reg [2:0] current_state, next_state;

    // Iteration indices
    reg [3:0] contestant_idx; // Index for current contestant being processed
    reg [3:0] contest_idx;    // Index for current contest (for sorting)
    reg [3:0] swap_idx;       // Index for bubble sort pass

    // Internal registers for sorting and calculation
    reg [7:0] temp_scores [0:9]; // Local copy of scores for current contestant to sort
    reg [7:0] top4_sum;          // Accumulated sum of top 4 scores for current contestant
    reg [7:0] my_aggregate;      // Aggregate score of contestant 0
    reg [7:0] other_aggregate;   // Aggregate score of other contestants
    reg [3:0] higher_count;      // Count of contestants with strictly higher aggregate

    // State Transition and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result_rank <= 4'b0;
            contestant_idx <= 4'b0;
            contest_idx <= 4'b0;
            swap_idx <= 4'b0;
            top4_sum <= 8'b0;
            my_aggregate <= 8'b0;
            other_aggregate <= 8'b0;
            higher_count <= 4'b0;
            // Initialize temp_scores array to prevent latch inference
            for (int i = 0; i < 10; i++) temp_scores[i] <= 8'b0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    contestant_idx <= 4'b0;
                    contest_idx <= 4'b0;
                    swap_idx <= 4'b0;
                    top4_sum <= 8'b0;
                    higher_count <= 4'b0;
                end

                SORT: begin
                    // Load initial scores into temp_scores buffer if starting a new contestant
                    // Or perform bubble sort operations
                    // We use a bubble sort network logic here sequentially
                    
                    // Loading step (handled implicitly by accessing scores array directly in logic below, 
                    // but to keep it stateful and simple, we process one swap/copy per cycle)
                    
                    // For small N (max 10), we can do one bubble sort iteration per cycle
                    // Logic: if swap_idx < n-1, compare temp_scores[swap_idx] and temp_scores[swap_idx+1]
                    // If out of order, swap. Then increment swap_idx. If swap_idx reaches n-1, reset to 0 and increment loop counter.
                    
                    // Actually, simpler approach: Load full array into temp_scores when entering this state for the contestant
                    // Then run sorting logic.
                    
                    if (contest_idx < n) begin
                        // Initial load: This happens in the first cycle of SORT for a contestant or continuously?
                        // Let's use contest_idx as the 'loop counter' for the bubble sort passes.
                        // However, we need to load the data first. 
                        // We'll use a dedicated load state or implicit load.
                        // Let's do explicit load in cycle 0 of SORT for this contestant.
                         if (swap_idx == 0 && contest_idx == 0) begin
                            // Load scores into temp buffer
                            for (int i = 0; i < 10; i++) begin
                                if (i < n) temp_scores[i] <= scores[contestant_idx][i];
                                else temp_scores[i] <= 8'b0;
                            end
                         end
                         
                         // Bubble Sort Logic (O(n^2), one swap per cycle usually, but here we scan per cycle)
                         // Actually, let's do a pipelined bubble sort logic:
                         // Iterate swap_idx from 0 to n-2.
                         // If temp_scores[swap_idx] < temp_scores[swap_idx+1], swap.
                         // Wait, requirement says "sum of 4 highest scores". 
                         // We need to sort descending to easily pick top 4.
                         
                         // One step per clock cycle:
                         // Swap if temp_scores[swap_idx] < temp_scores[swap_idx+1] (descending order)
                         if (swap_idx < n - 1) begin
                            if (temp_scores[swap_idx] < temp_scores[swap_idx + 1]) begin
                                // Swap
                                temp_scores[swap_idx] <= temp_scores[swap_idx + 1];
                                temp_scores[swap_idx + 1] <= temp_scores[swap_idx];
                            end
                            swap_idx <= swap_idx + 1;
                         end else begin
                            // One pass complete
                            swap_idx <= 0;
                            contest_idx <= contest_idx + 1; // Use contest_idx as pass counter for bubble sort
                            // We need to run 'n' passes to fully sort (Bubble sort O(N^2) worst case, but we limit iterations)
                            // Since we want top 4, and N is small, let's just run full sort for simplicity.
                            // Loop condition: We run the pass counter (now reused as contest_idx) up to n.
                            if (contest_idx + 1 == n) begin
                                // Sorting complete for this contestant
                                // We will transition to SUM_TOP4 next cycle. But transitions happen in combinational logic.
                                // We need to signal that we are done with sorting.
                            end
                         end
                    end
                end

                SUM_TOP4: begin
                    // Sum the top 4 from temp_scores (which is now sorted descending)
                    // Since we sum top 4, and N <= 10, we can just add 4 terms.
                    // But N might be less than 4. If N < 4, sum all available.
                    // temp_scores is sorted descending.
                    
                    top4_sum <= 8'b0; // Reset accumulator
                    // Actually, we need to calculate the sum. 
                    // Let's add them up.
                    top4_sum <= temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    // Note: If n < 4, the unused temp_scores entries were initialized to 0 (handled in SORT load or default).
                    
                    // We need to store this aggregate into the correct register
                    if (contestant_idx == 0) begin
                        my_aggregate <= temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    end else begin
                        other_aggregate <= temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    end
                end

                COMPARE: begin
                    // Compare my_aggregate with other_aggregate
                    if (other_aggregate > my_aggregate) begin
                        higher_count <= higher_count + 1;
                    end
                end
                
                UPDATE_RANK: begin
                    // Wait state or calculation for rank
                    // Rank = 1 + higher_count
                    // This is handled in combinational logic usually, but let's do it here for sequential cleaness
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result_rank <= 1 + higher_count;
                end
            endcase
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = SORT;
                else next_state = IDLE;
            end
            
            SORT: begin
                // Check if sorting is done for current contestant
                // We defined contest_idx as pass counter in sequential logic
                // Logic: if (swap_idx == 0 && contest_idx == n) -> done sorting this contestant
                // Wait, we increment contest_idx when swap_idx wraps.
                // So if swap_idx == 0 and contest_idx == n, we are done.
                // Note: In the sequential block, we set contest_idx++ when swap_idx wraps.
                // So condition to leave SORT: (swap_idx == 0 && contest_idx >= n)
                
                if (swap_idx == 0 && contest_idx >= n) begin
                    next_state = SUM_TOP4;
                end else begin
                    next_state = SORT;
                end
            end
            
            SUM_TOP4: begin
                // One cycle to compute sum and store in registers
                // Determine next state based on who we just processed
                if (contestant_idx == 0) begin
                    next_state = SORT; // Go back to sort for contestant 1
                end else begin
                    next_state = COMPARE; // Compare contestant 1 with 0
                end
            end
            
            COMPARE: begin
                // Check if we have compared all contestants (m)
                // We start compare for contestant_idx=1. 
                // If contestant_idx < m-1 (meaning we just compared contestant_idx), we need to load next.
                // Wait, in SEQ block, we incremented contestant_idx in SUM_TOP4? 
                // Let's refine the iteration flow:
                // 1. Process Contestant 0 -> SUM_TOP4 -> (Store my_aggregate) -> Loop to Contestant 1 (Sort)
                // 2. Process Contestant 1 -> SUM_TOP4 -> (Store other_aggregate) -> COMPARE -> Update Count
                // 3. If more contestants, back to Sort for Contestant 2.
                // 4. If all done, go to UPDATE_RANK/FINISH.
                
                // In COMPARE state, we just performed the comparison. 
                // Now we need to decide:
                // If (contestant_idx < m - 1) -> Next state SORT (to process contestant_idx + 1)
                // Else -> Next state UPDATE_RANK (all done)
                
                // Wait, who manages contestant_idx increment?
                // In SUM_TOP4 state, after calculating, we should increment contestant_idx for the next loop.
                // Let's adjust SEQ logic for SUM_TOP4:
                // SEQ logic for SUM_TOP4: store result. Then increment contestant_idx (unless it was the last one, handled in NSL)
                // Actually, safer: 
                // SUM_TOP4: Store result. Then transition. 
                // If contestant_idx == 0, transition to SORT (for next contestant).
                // If contestant_idx > 0, transition to COMPARE.
                
                // In COMPARE state:
                // We have compared contestant `contestant_idx` (who's aggregate is in other_aggregate).
                // If (contestant_idx < m - 1) -> Go to SORT (to load/sort next contestant)
                // Else -> Go to UPDATE_RANK.
                
                if (contestant_idx < m - 1) begin
                    next_state = SORT;
                end else begin
                    next_state = UPDATE_RANK;
                end
            end
            
            UPDATE_RANK: begin
                // Just a pass-through state to latch the final rank calculation if needed
                // Or calculate rank directly in combinational output or next state logic.
                // Let's go to DONE.
                next_state = FINISH;
            end
            
            FINISH: begin
                // Wait for reset or start to go low (or stay here until start goes low)
                // Typically, done is high until reset or start goes low.
                if (!start) next_state = IDLE;
                else next_state = FINISH;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Corrected Sequential Logic for State-Specific Actions & Iteration
    // We need to separate the "Load Initial" and "Sort" steps clearly.
    // The logic above in SEQ block for SORT handles both load and sort steps.
    // However, the transition from SUM_TOP4 back to SORT needs to increment contestant_idx.
    
    // Let's refine the state machine actions to be more explicit in the always block
    // We will use the SEQ block primarily for state transitions and simple counters, 
    // and rely on the combination of state and counters to drive operations.
    
    // Actually, the `always @(*)` for next_state is good.
    // The `always @(posedge clk)` needs to handle the specific "one-hot" cycle logic.
    
    // Re-writing the SEQ block logic to be robust:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result_rank <= 4'b0;
            contestant_idx <= 4'd0;
            swap_idx <= 4'd0;
            // Pass counter (formerly contest_idx in SORT, let's rename to sort_pass to be clear)
            // But we used it as general iteration counter in some places. Let's use `sort_pass`.
            // Actually, let's use `contest_idx` for loops, but clarify usage per state.
            contest_idx <= 4'd0; 
            top4_sum <= 8'b0;
            my_aggregate <= 8'b0;
            other_aggregate <= 8'b0;
            higher_count <= 4'd0;
            for (int i = 0; i < 10; i++) temp_scores[i] <= 8'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        contestant_idx <= 4'd0;
                        swap_idx <= 4'd0;
                        contest_idx <= 4'd0; // Will serve as pass counter for bubble sort
                        done <= 1'b0;
                        higher_count <= 4'd0;
                    end
                end

                SORT: begin
                    // Logic: 
                    // 1. If swap_idx == 0 and contest_idx == 0, Load scores from scores[contestant_idx] into temp_scores.
                    // 2. If swap_idx < n-1, compare and swap. Increment swap_idx.
                    // 3. If swap_idx == n-1, one pass done. Reset swap_idx to 0. Increment contest_idx.
                    // 4. If contest_idx >= n (or n-1 depending on implementation), Sorting Done.

                    // Load step (Cycle 1 of SORT for this contestant)
                    if (swap_idx == 0 && contest_idx == 0) begin
                        for (int i = 0; i < 10; i++) begin
                            if (i < n) temp_scores[i] <= scores[contestant_idx][i];
                            else temp_scores[i] <= 8'b0;
                        end
                    end else begin
                        // Swap Logic (Only if we haven't finished all passes)
                        // Note: We only run swap logic if n > 1. If n==1, we are done immediately?
                        // The NSL handles the exit condition.
                        
                        if (n > 1 && swap_idx < n - 1) begin
                            if (temp_scores[swap_idx] < temp_scores[swap_idx + 1]) begin
                                temp_scores[swap_idx] <= temp_scores[swap_idx + 1];
                                temp_scores[swap_idx + 1] <= temp_scores[swap_idx];
                            end
                            swap_idx <= swap_idx + 1;
                        end else if (n > 1) begin // swap_idx reached n-1
                            swap_idx <= 0;
                            contest_idx <= contest_idx + 1;
                        end else if (n == 1) begin // Special case n=1, just load and done
                            // Handled by NSL checking contest_idx >= n immediately? 
                            // Let's manually bump contest_idx for n=1 to trigger NSL exit
                            contest_idx <= 1;
                        end
                    end
                end

                SUM_TOP4: begin
                    // Calculate sum of top 4 sorted scores
                    // temp_scores is sorted descending.
                    // temp_scores[0] is highest.
                    // Sum logic: temp_scores[0] + ... + temp_scores[3]
                    // If n < 4, higher indices are 0 (guaranteed by initialization or zero-padding in load).
                    
                    if (contestant_idx == 0) begin
                        my_aggregate <= temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    end else begin
                        other_aggregate <= temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    end
                end

                COMPARE: begin
                    // Comparison result was used in next_state logic or should be latched here?
                    // The logic is: if other > my, count++.
                    // We can do the increment here based on the values.
                    if (other_aggregate > my_aggregate) begin
                        higher_count <= higher_count + 1;
                    end
                    
                    // Prepare for next iteration
                    // We need to increment contestant_idx here for the loop
                    contestant_idx <= contestant_idx + 1;
                    // Reset sort counters for next contestant
                    swap_idx <= 0;
                    contest_idx <= 0;
                end

                // UPDATE_RANK state was removed in NSL logic refinement (went straight to FINISH from COMPARE if last)
                // Wait, the NSL above has UPDATE_RANK. Let's use it to just latch the final rank calculation if needed.
                // Actually, we can compute rank in FINISH state using `higher_count`.
                
                FINISH: begin
                    done <= 1'b1;
                    // Rank = 1 + higher_count
                    result_rank <= 1 + higher_count;
                    // Keep state until start goes low
                    if (!start) begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

    // Update Next State Logic to handle the flow correctly
    always @(*) begin
        case (current_state)
            IDLE: next_state = start ? SORT : IDLE;
            
            SORT: begin
                // Check if sorting passes are complete
                // We defined: contest_idx increments when swap_idx wraps.
                // We exit when contest_idx >= n (meaning we did n passes).
                // Also handle n=0 or n=1 edge cases.
                if (contest_idx >= n) begin
                    next_state = SUM_TOP4;
                end else begin
                    next_state = SORT;
                end
            end
            
            SUM_TOP4: begin
                // After summing, if we just did contestant 0, go back to SORT for contestant 1.
                // If we just did contestant > 0, we go to COMPARE.
                // Wait, we haven't incremented contestant_idx yet in SEQ (we incremented in COMPARE in my refined plan).
                // In SUM_TOP4, we just processed `contestant_idx`.
                
                // Logic: 
                // If `contestant_idx` == 0 (we just stored my_aggregate), we need to move to contestant 1.
                // But we haven't incremented `contestant_idx` yet.
                // So, if `contestant_idx` == 0, next state is SORT (to process index 1).
                // If `contestant_idx` > 0, next state is COMPARE (to compare index 1, 2...).
                
                // Wait, in the COMPARE state logic above, I put `contestant_idx <= contestant_idx + 1`.
                // That means COMPARE is done for `contestant_idx`, then we increment.
                // So flow:
                // Process ID=0 -> SUM_TOP4 -> COMPARE? No, COMPARE needs "other" aggregate.
                // So flow for ID=0: SORT -> SUM_TOP4 -> (store my_agg) -> SORT (for ID=1).
                // Flow for ID=1: SORT -> SUM_TOP4 -> (store other_agg) -> COMPARE (compare ID=1) -> (increment ID to 2) -> SORT (for ID=2).
                // Wait, if we increment ID in COMPARE, then COMPARE is checking the ID that *was* just processed.
                
                // Revised Flow:
                // 1. Process ID 0 (Sort -> Sum) -> Need to process ID 1.
                //    SUM_TOP4 (ID=0) -> Next state SORT (ID remains 0? No, we need to process 1).
                //    Logic in SUM_TOP4 transition: Always go to SORT.
                //    But we must increment ID *after* SUM_TOP4 for ID=0, and *after* COMPARE for ID>0.
                
                // Let's try this:
                // SUM_TOP4: 
                //   If contestant_idx == 0: 
                //     next_state = SORT; 
                //     (In SEQ: increment contestant_idx to 1? No, SEQ block handles transitions. 
                //      Let's keep ID increment explicit in states to avoid confusion.)
                
                // Let's use the SEQ block to increment ID at the right spots.
                // Revised SEQ block logic (keep the previous one, but fix the flow):
                
                // Let's restart the NSL/SEQ logic cleanly.
                // The module operates as:
                // State SORT: Sorts `contestant_idx`.
                // State SUM_TOP4: Sums `contestant_idx`.
                //   If `contestant_idx` == 0 -> Next State SORT. 
                //   Else -> Next State COMPARE.
                // State COMPARE: Compares `contestant_idx` (which is the "other").
                //   Then increments `contestant_idx`.
                //   If `contestant_idx` (new) < m -> Next State SORT.
                //   Else -> Next State FINISH.
                
                // This logic seems robust.
                
                if (contestant_idx == 0) begin
                    next_state = SORT;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // We just compared contestant `contestant_idx`.
                // Increment happens in SEQ block.
                // Check if we have more to do.
                // In SEQ block, we do: contestant_idx <= contestant_idx + 1.
                // So we check if (current contestant_idx + 1 < m).
                // Since we haven't updated yet, we check: if (contestant_idx + 1 < m).
                // Or simpler: if (contestant_idx < m - 1).
                // Wait, if m=2, indices 0, 1.
                // Process 0 -> SUM_TOP4 -> COMPARE (process 1). 
                // At this point contestant_idx is 1.
                // We compare. Then increment to 2.
                // We check if 1 < m-1 (1 < 1)? False. Go to FINISH.
                
                if (contestant_idx < m - 1) begin
                    next_state = SORT;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: next_state = start ? FINISH : IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Re-writing the sequential block to match this refined flow
    // Note: I will keep the previous sequential block but modify the COMPARE state part to handle the increment and reset correctly.
    // The SEQ block above (under "Corrected Sequential Logic") was almost there, but let's ensure the SUM_TOP4->SORT transition increments ID correctly.
    
    // Actually, let's just override the SEQ block to match the refined NSL.
    // The refined NSL implies:
    // SORT: Does sorting. Goes to SUM_TOP4.
    // SUM_TOP4: Does sum. If ID==0 -> SORT (next ID). If ID>0 -> COMPARE (same ID).
    //   Wait, in SUM_TOP4 we are processing ID=X. 
    //   If ID=0: We finish ID=0. We need to start ID=1. Next state SORT. ID should be 1 when entering SORT.
    //   If ID>0: We finish ID=X. We need to compare X. Next state COMPARE. ID stays X.
    // COMPARE: Compares ID=X. Increments ID to X+1. Next state SORT (if more) or FINISH.
    
    // SEQ Block (Final Version):
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result_rank <= 4'b0;
            contestant_idx <= 4'd0;
            swap_idx <= 4'd0;
            contest_idx <= 4'd0;
            my_aggregate <= 8'b0;
            other_aggregate <= 8'b0;
            higher_count <= 4'd0;
            for (int i = 0; i < 10; i++) temp_scores[i] <= 8'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        contestant_idx <= 4'd0;
                        swap_idx <= 4'd0;
                        contest_idx <= 4'd0;
                        higher_count <= 4'd0;
                        done <= 1'b0;
                    end
                end

                SORT: begin
                    // Load step (only first cycle of sort for a contestant)
                    // We check if we are just starting the sort for this contestant.
                    // A simple check: if swap_idx == 0 and contest_idx == 0.
                    // However, we might re-enter SORT from COMPARE where swap_idx/contest_idx are reset to 0.
                    // So this condition is valid for the start of any contestant's sort.
                    if (swap_idx == 0 && contest_idx == 0) begin
                        for (int i = 0; i < 10; i++) begin
                            if (i < n) temp_scores[i] <= scores[contestant_idx][i];
                            else temp_scores[i] <= 8'b0;
                        end
                    end else begin
                        // Sorting Operations
                        if (n > 1) begin
                            if (swap_idx < n - 1) begin
                                if (temp_scores[swap_idx] < temp_scores[swap_idx + 1]) begin
                                    temp_scores[swap_idx] <= temp_scores[swap_idx + 1];
                                    temp_scores[swap_idx + 1] <= temp_scores[swap_idx];
                                end
                                swap_idx <= swap_idx + 1;
                            end else begin // swap_idx == n-1, pass done
                                swap_idx <= 0;
                                contest_idx <= contest_idx + 1;
                            end
                        end else if (n == 1) begin
                            // Single contest, just need to load. Force exit condition.
                            contest_idx <= 1;
                        end
                    end
                end

                SUM_TOP4: begin
                    // Calc sum
                    if (contestant_idx == 0) begin
                        my_aggregate <= temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    end else begin
                        other_aggregate <= temp_scores[0] + temp_scores[1] + temp_scores[2] + temp_scores[3];
                    end
                    
                    // Prepare for next state
                    if (contestant_idx == 0) begin
                        // Next is SORT for ID=1. Increment ID here.
                        contestant_idx <= contestant_idx + 1;
                        // Reset sort counters (though they are reset in SORT state entry usually, but safe to do here)
                        swap_idx <= 0;
                        contest_idx <= 0;
                    end
                    // If contestant_idx > 0, we stay on this ID for COMPARE. Do not increment ID.
                end

                COMPARE: begin
                    // Compare logic: other_aggregate vs my_aggregate
                    if (other_aggregate > my_aggregate) begin
                        higher_count <= higher_count + 1;
                    end
                    
                    // Prepare for next loop
                    // We have finished this 'other' contestant.
                    // Increment ID to point to the next contestant.
                    contestant_idx <= contestant_idx + 1;
                    swap_idx <= 0;
                    contest_idx <= 0;
                end

                FINISH: begin
                    done <= 1'b1;
                    result_rank <= 1 + higher_count;
                    if (!start) begin
                        done <= 1'b0;
                        result_rank <= 4'b0; // Optional: clear output
                    end
                end
            endcase
        end
    end

    // NSL (Refined to match the SEQ flow above)
    always @(*) begin
        case (current_state)
            IDLE: next_state = start ? SORT : IDLE;
            
            SORT: begin
                // Check if sorting done: contest_idx >= n
                if (contest_idx >= n) next_state = SUM_TOP4;
                else next_state = SORT;
            end
            
            SUM_TOP4: begin
                // Check next state based on who we just processed
                if (contestant_idx == 0) begin
                    // We just processed contestant 0. Next is SORT for contestant 1.
                    // Note: SEQ block updated contestant_idx to 1.
                    next_state = SORT;
                end else begin
                    // We just processed contestant X > 0. Next is COMPARE.
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // We just compared contestant X. SEQ block incremented contestant_idx to X+1.
                // Check if there are more contestants to process.
                // We need to check if X+1 < m.
                // Since SEQ updated contestant_idx, we check current contestant_idx.
                if (contestant_idx < m) begin
                    next_state = SORT;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                if (!start) next_state = IDLE;
                else next_state = FINISH;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule