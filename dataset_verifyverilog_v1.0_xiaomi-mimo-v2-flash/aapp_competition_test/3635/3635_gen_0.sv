module BananaBriefcase(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [15:0] arr [0:15],
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] CALC_PREFIX  = 4'd1;
    localparam [3:0] INIT_SEG     = 4'd2;
    localparam [3:0] FIND_SEG     = 4'd3;
    localparam [4:0] UPDATE_COUNT = 4'd4;
    localparam [3:0] NEXT_SEG     = 4'd5;
    localparam [3:0] CHECK_NEXT   = 4'd6;
    localparam [3:0] UPDATE_MAX   = 4'd7;
    localparam [3:0] DONE_STATE   = 4'd8;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    
    // Prefix sum array (16 elements, 16-bit sums)
    reg [15:0] prefix_sum [0:16];
    reg [3:0] prefix_idx;
    
    // Variables for iteration
    reg [3:0] first_len;      // Length of first segment (1 to N)
    reg [3:0] curr_idx;       // Current index in array
    reg [15:0] min_sum;       // Minimum required sum for next segment
    reg [3:0] seg_count;      // Number of segments found so far
    reg [3:0] best_k;         // Best K found so far
    
    // Variables for binary search / linear search
    reg [3:0] search_idx;     // Starting index for search
    reg [15:0] search_min;    // Minimum sum required
    reg [3:0] found_len;      // Length of found segment
    reg found_flag;           // Flag if segment found
    
    // Helper: compute sum from i to j inclusive: prefix[j+1] - prefix[i]
    reg [15:0] current_sum;
    
    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // --- Reset and State Transition ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            prefix_idx <= 4'd0;
            first_len <= 4'd0;
            curr_idx <= 4'd0;
            seg_count <= 4'd0;
            best_k <= 4'd0;
            search_idx <= 4'd0;
            found_len <= 4'd0;
            found_flag <= 1'b0;
            // Initialize prefix_sum array
            for (int i = 0; i < 17; i = i + 1) begin
                prefix_sum[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 10'd1;
            end else if (state == IDLE && start) begin
                cycle_count <= 10'd0;
            end
            
            // Default done to 0 unless in DONE_STATE
            if (state != DONE_STATE) begin
                done <= 1'b0;
            end
            
            // --- Sequential Logic per State ---
            case (state)
                IDLE: begin
                    if (start) begin
                        best_k <= 4'd0;
                        first_len <= 4'd1;
                        prefix_idx <= 4'd0;
                    end
                end
                
                CALC_PREFIX: begin
                    // Compute prefix sums: prefix[i+1] = prefix[i] + arr[i]
                    if (prefix_idx < N) begin
                        if (prefix_idx == 4'd0) begin
                            prefix_sum[1] <= arr[0];
                        end else begin
                            prefix_sum[prefix_idx + 1] <= prefix_sum[prefix_idx] + arr[prefix_idx];
                        end
                        prefix_idx <= prefix_idx + 4'd1;
                    end
                end
                
                INIT_SEG: begin
                    // Initialize for a new first segment length
                    // Check if first_len <= N
                    if (first_len <= N) begin
                        // Calculate sum of first segment [0, first_len-1]
                        // Sum = prefix[first_len] - prefix[0]
                        // prefix[0] is implicitly 0
                        if (first_len == 4'd1) begin
                            current_sum <= arr[0];
                        end else begin
                            current_sum <= prefix_sum[first_len];
                        end
                        
                        // If first segment sum is 0, it's invalid (or treat as valid? Problem implies positive counts usually)
                        // Assuming non-decreasing implies >=0. If sum=0, can we partition further?
                        // Let's assume sums must be >= 0. 
                        // If current_sum == 0, it might be valid, but subsequent segments must be >=0.
                        // The problem asks for non-decreasing. 
                        // If current_sum == 0, we can only have 0 sums after.
                        
                        // Initialize state for finding subsequent segments
                        curr_idx <= first_len;
                        min_sum <= current_sum;
                        seg_count <= 4'd1; // Found the first segment
                    end
                end
                
                FIND_SEG: begin
                    // Find smallest j >= curr_idx such that sum(curr_idx...j) >= min_sum
                    // Linear search from j = curr_idx to N-1
                    // We use search_idx as the trial end index
                    // We need to track if we found it. 
                    // Since we are in an FSM, we can't easily iterate a for-loop inside without state.
                    // Let's use a state to iterate a variable 'trial_j' until found or end.
                    // Reusing search_idx for trial_j.
                    if (curr_idx >= N) begin
                        found_flag <= 1'b0; // No room for more segments
                    end else begin
                        // Start search at curr_idx
                        // We need a temporary variable to track the current trial length
                        // Let's use 'found_len' to store the length of the segment if found
                        // And 'found_flag' to indicate validity.
                        // We will perform one comparison per cycle.
                        
                        if (search_idx == curr_idx) begin
                            // First iteration of search
                            // Check length 1
                            // Sum = arr[curr_idx]
                            if (arr[curr_idx] >= min_sum) begin
                                found_flag <= 1'b1;
                                found_len <= 4'd1;
                                // Don't increment search_idx yet, we are done with this search
                                // But we need to know we are done searching. 
                                // Actually, let's keep searching in this state until found or end.
                                // But FSM is better if we advance state.
                                // Let's compute current_sum here for the trial length
                                current_sum <= arr[curr_idx];
                                found_flag <= (arr[curr_idx] >= min_sum);
                                found_len <= 4'd1;
                                search_idx <= curr_idx + 4'd1; // Prepare for next length
                            end else begin
                                found_flag <= 1'b0;
                                search_idx <= curr_idx + 4'd1;
                            end
                        end else begin
                            // Continuing search... wait, logic is messy if we try to do incremental sum in one state.
                            // Let's simplify: Use a sub-state or a dedicated search state with a counter.
                            // Actually, since N is small (16), we can unroll or just iterate 'found_len' from 1 to N-curr_idx.
                            // Let's use 'found_len' as the current length being tested.
                            // But we are already using found_len to store the RESULT length.
                            // Let's use 'search_idx' as the length counter for the search.
                            // If search_idx == curr_idx, it means we haven't started searching this phase.
                            // Let's use 'search_idx' to be the trial END index (which implies length = search_idx - curr_idx + 1)
                            // Wait, that's confusing with MAX_CYCLES.
                            // Let's reset search_idx to curr_idx in INIT_SEG.
                            // Then in FIND_SEG, we check length 1. If fail, we go to a state to check length 2, etc.
                            // Actually, let's use a loop-like structure using states.
                            
                            // Revised Plan for FIND_SEG:
                            // Use a register 'trial_j' (let's use search_idx for this) starting at curr_idx.
                            // Compute sum(curr_idx...trial_j).
                            // If sum >= min_sum -> found. Set found_flag, found_len = trial_j-curr_idx+1.
                            // If trial_j == N -> not found.
                            // If sum < min_sum -> increment trial_j and repeat.
                            
                            // Since we can't loop easily, let's check one candidate per clock cycle.
                            // We need a state to advance the search.
                        end
                    end
                end
                
                // Let's refactor FIND_SEG into a simpler mechanism.
                // We will use the FSM to iterate 'search_idx' (trial end index).
                // We need a flag to know if we found a segment in this iteration.
            endcase
        end
    end

    // --- Combinational Next State Logic ---
    always @(*) begin
        next_state = state; // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_PREFIX;
                end
            end
            
            CALC_PREFIX: begin
                if (prefix_idx >= N) begin
                    // If N=0 (edge case), go to DONE. If N>0, go to INIT_SEG.
                    if (N == 4'd0) next_state = DONE_STATE;
                    else next_state = INIT_SEG;
                end else begin
                    next_state = CALC_PREFIX;
                end
            end
            
            INIT_SEG: begin
                if (first_len > N) begin
                    next_state = DONE_STATE;
                end else begin
                    // If first_len is valid, we start looking for segments.
                    // We need to initialize the search.
                    // Let's go to a dedicated search state.
                    // Reusing FIND_SEG. We reset search_idx in INIT_SEG logic block.
                    // Actually, let's put the reset logic here.
                    next_state = FIND_SEG;
                end
            end
            
            FIND_SEG: begin
                // Logic:
                // 1. Calculate sum for current trial length.
                // 2. Check if sum >= min_sum.
                // 3. If yes -> segment found. Go to UPDATE_COUNT.
                // 4. If no -> check next length. If possible -> stay in FIND_SEG (or advance search_idx).
                //    If not possible (end of array) -> segment not found. Go to CHECK_NEXT.
                //
                // Implementation detail:
                // Let's use 'found_len' as the trial length. Start at 1.
                // We need to compute the sum dynamically or use prefix sums.
                // Sum = prefix[curr_idx + found_len] - prefix[curr_idx].
                // 
                // We need a variable to track the current trial length.
                // Let's use 'search_idx' to store the current trial length.
                // We need to reset search_idx to 1 when we enter FIND_SEG for a new 'curr_idx'.
                //
                // Let's create a 'SEARCH_LOOP' state that handles the iteration.
                // But we are already in FIND_SEG. 
                // Let's say we use 'search_idx' as the trial length (1 to N-curr_idx).
                
                // We need to check: curr_idx + search_idx <= N.
                // Calculate sum: prefix[curr_idx + search_idx] - prefix[curr_idx].
                
                // If sum >= min_sum -> found. Go to UPDATE_COUNT.
                // Else if search_idx < (N - curr_idx) -> increment search_idx, stay in FIND_SEG.
                // Else -> not found. Go to CHECK_NEXT.
                
                next_state = FIND_SEG; // Default stay
                
                // Combinational calculation for sum
                // We can't do this in combinational logic if we rely on registers updating sequentially?
                // We can compute the sum based on current registers.
                // Since we update search_idx in the sequential block, we compute the sum for the *next* state?
                // No, we compute sum for *current* search_idx.
                // 
                // Let's use a helper wire for sum calculation.
                // Sum = prefix[curr_idx + search_idx] - prefix[curr_idx].
                // Note: prefix array is 0..16. prefix[0]=0.
                
                // Wait, if we update search_idx in the same cycle we check it, we might skip values.
                // We should check the value of search_idx, then decide next state.
                // If we stay in state, we increment search_idx in the sequential block.
                
                // Special case: first check (search_idx = 0 or 1).
                // Let's initialize search_idx to 1 in INIT_SEG logic.
                // But INIT_SEG is a state. We can set search_idx = 1 there.
                // So in FIND_SEG, search_idx is the current length to test.
                
                // Check bounds
                if (curr_idx + search_idx > N) begin
                    next_state = CHECK_NEXT; // Ran out of array
                end else begin
                    // Check sum condition
                    // Need combinational logic to compute sum.
                    // Let's assume we have a combinational logic below that computes 'current_sum'.
                    // If current_sum >= min_sum -> Found
                    if (current_sum >= min_sum) begin
                        next_state = UPDATE_COUNT;
                    end else begin
                        // Not found, try longer segment
                        if (search_idx < (N - curr_idx)) begin
                            next_state = FIND_SEG; // Stay, will increment search_idx
                        end else begin
                            next_state = CHECK_NEXT; // Tried all lengths, none work
                        end
                    end
                end
            end
            
            UPDATE_COUNT: begin
                // Segment found. Update seg_count and min_sum.
                // Then move curr_idx forward.
                next_state = NEXT_SEG;
            end
            
            NEXT_SEG: begin
                // Prepare to find next segment
                // Check if curr_idx reached N
                if (curr_idx >= N) begin
                    next_state = UPDATE_MAX;
                end else begin
                    next_state = FIND_SEG;
                end
            end
            
            CHECK_NEXT: begin
                // Could not find next segment.
                // Current partitioning (first_len) is complete.
                next_state = UPDATE_MAX;
            end
            
            UPDATE_MAX: begin
                // Update best_k if current seg_count is better.
                // Then try next first_len.
                next_state = INIT_SEG; // Will increment first_len
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety: timeout
        if (cycle_count >= MAX_CYCLES) begin
            next_state = DONE_STATE;
        end
    end

    // --- Combinational Logic (Sum Calculation & Helper) ---
    // To avoid array slicing issues and keep logic clear, we explicitly compute sum.
    wire [15:0] trial_sum;
    assign trial_sum = prefix_sum[curr_idx + search_idx] - prefix_sum[curr_idx];
    
    // Update current_sum register in sequential block based on trial_sum
    // But we need to capture it when we find a segment.
    
    // --- Sequential Logic (Refined) ---
    // We need to refine the sequential block to handle the iterative search correctly.
    // We will use 'search_idx' as the trial length.
    
    // Re-writing the sequential block for clarity and correctness with the FSM.
    // The previous sequential block was a bit sparse.
    
    // Let's add a block to update registers based on state.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            case (state)
                INIT_SEG: begin
                    if (first_len <= N) begin
                        search_idx <= 4'd1; // Start searching for segment length 1
                        curr_idx <= 4'd0;   // Start from beginning? No.
                        // curr_idx is where the NEXT segment starts.
                        // For the first segment, it starts at 0.
                        // Wait, in INIT_SEG we set up the FIRST segment.
                        // But first_len defines the length of the first segment.
                        // So we don't need to search for the first segment; we just take it.
                        // Logic in INIT_SEG:
                        // 1. Calculate sum of segment [0, first_len-1].
                        // 2. Set curr_idx = first_len.
                        // 3. Set min_sum = sum.
                        // 4. Set seg_count = 1.
                        // 5. Go to FIND_SEG (to find the 2nd segment).
                        
                        // Calculate sum of first segment:
                        // prefix_sum[first_len] - prefix_sum[0]
                        // prefix_sum[0] is 0 (initialized).
                        // Note: prefix_sum calculation loop fills prefix_sum[i+1] for i=0..N-1.
                        // So prefix_sum[k] holds sum of arr[0..k-1].
                        // Correct.
                        
                        min_sum <= prefix_sum[first_len]; // prefix_sum[0] is 0
                        curr_idx <= first_len;
                        seg_count <= 4'd1;
                        
                        // If first_len == N, we have consumed the whole array.
                        // No more segments can be found. Go to UPDATE_MAX directly.
                        // (Handled in nextState if curr_idx >= N -> CHECK_NEXT -> UPDATE_MAX)
                        // But if curr_idx == N, we should not enter FIND_SEG.
                        // The nextState logic handles this: if curr_idx >= N go to UPDATE_MAX.
                    end
                end
                
                FIND_SEG: begin
                    // We enter this state with search_idx set to the length to test.
                    // We need to compute 'current_sum' for this trial.
                    // Since trial_sum is combinational, we can capture it or check it.
                    // But we update search_idx in this block if we stay in state.
                    
                    // Check if we found it (combinational check in nextState)
                    // If nextState is UPDATE_COUNT, we should store the result.
                    // If nextState is FIND_SEG (retry), we increment search_idx.
                    // If nextState is CHECK_NEXT, we are done.
                    
                    if (next_state == UPDATE_COUNT) begin
                        // Segment found! 
                        // The length is search_idx.
                        // The sum is trial_sum.
                        // We need to update min_sum and curr_idx for the NEXT search.
                        // But wait, the logic for that is in UPDATE_COUNT state.
                        // We just need to make sure 'current_sum' holds the correct sum for UPDATE_COUNT to use.
                        current_sum <= trial_sum;
                        // Also need to store the length? No, we can recalculate or use search_idx.
                    end else if (next_state == FIND_SEG) begin
                        // Not found yet, try longer
                        search_idx <= search_idx + 4'd1;
                    end
                    // If next_state is CHECK_NEXT, we do nothing (failed to find).
                end
                
                UPDATE_COUNT: begin
                    // We found a segment.
                    // Length was 'search_idx', Sum was 'current_sum' (captured in FIND_SEG or here).
                    // Update min_sum to current_sum (strictly non-decreasing, so >= is enough, but we update to the new sum).
                    // Update curr_idx: curr_idx = curr_idx + search_idx.
                    // Increment seg_count.
                    
                    // Note: search_idx is the length of the segment just found.
                    curr_idx <= curr_idx + search_idx;
                    min_sum <= current_sum; // Or trial_sum if we use combinational directly
                    seg_count <= seg_count + 4'd1;
                    
                    // Reset search_idx for the next segment search (will be set to 1 in logic, or just reset here)
                    search_idx <= 4'd1; // Ready for next time
                end
                
                UPDATE_MAX: begin
                    // Compare seg_count with best_k.
                    if (seg_count > best_k) begin
                        best_k <= seg_count;
                    end
                    // Try next first_len
                    first_len <= first_len + 4'd1;
                end
                
                DONE_STATE: begin
                    result <= best_k;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // To ensure 'current_sum' is correct in FIND_SEG for the check,
    // we might need a combinational block or update it at the right time.
    // The way we did it: in FIND_SEG state, if next_state is UPDATE_COUNT, we update current_sum <= trial_sum.
    // This works because nextState is determined combinationally.
    
    // However, we also need to handle the case where search_idx is updated.
    // The trial_sum depends on search_idx. 
    // If we update search_idx in the clock edge, trial_sum changes.
    // But we check nextState BEFORE the clock edge.
    // So we check trial_sum corresponding to the CURRENT search_idx.
    // If it passes, nextState = UPDATE_COUNT.
    // Then on clock edge, we update current_sum <= trial_sum (which is still the valid sum).
    // 
    // If it fails, nextState = FIND_SEG.
    // On clock edge, search_idx increments.
    // So next cycle, trial_sum will be for the new search_idx.
    // This is correct.
    
    // One issue: In INIT_SEG, we calculate min_sum = prefix_sum[first_len].
    // But prefix_sum is calculated in CALC_PREFIX state.
    // We must ensure CALC_PREFIX finishes before INIT_SEG uses it.
    // The state transition handles this.
    
    // Logic refinement for UPDATE_MAX:
    // We need to transition back to INIT_SEG.
    // In INIT_SEG, we use first_len.
    // first_len is incremented in UPDATE_MAX.
    // Wait, first_len is incremented in UPDATE_MAX, then we go to INIT_SEG.
    // In INIT_SEG, we check `if (first_len > N)`.
    // This check happens ON THE CLOCK EDGE after UPDATE_MAX.
    // So if first_len was N, UPDATE_MAX increments it to N+1.
    // Next clock cycle, state is INIT_SEG.
    // In INIT_SEG logic: `if (first_len > N)` we go to DONE.
    // But wait, we need to process first_len = 1, 2, ... N.
    // Initialize first_len = 1 in IDLE.
    // 1. INIT_SEG (len=1). -> Process. -> UPDATE_MAX (best_k updated). -> first_len becomes 2.
    // 2. INIT_SEG (len=2). -> Process. ...
    // N. INIT_SEG (len=N). -> Process. -> UPDATE_MAX. -> first_len becomes N+1.
    // N+1. INIT_SEG (len=N+1). -> Check `if (first_len > N)` true. -> DONE.
    // This is correct.
    
    // Edge case: N=0.
    // CALC_PREFIX finishes immediately (prefix_idx >= 0). -> INIT_SEG.
    // first_len starts at 1. 1 > 0. -> DONE. Result = 0 (best_k was 0).
    // Correct.

endmodule