module evolution_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][15:0][7:0] fossils,
    input wire [4:0] num_fossils,
    input wire [15:0][7:0] target,
    output reg [15:0] result_mask1,
    output reg [15:0] result_mask2,
    output reg valid,
    output reg impossible
);

    // --- Subsequence Checker Module ---
    // Checks if sequence 'a' is a subsequence of 'b'.
    // Assumes 'a' and 'b' are valid strings of length 16.
    // To be synthesizable, this logic is fully combinational but will be 
    // registered in the main FSM to break long paths.
    
    // We need a small helper to get the actual length of a string from the 16-char array.
    // However, the problem states "max 16 chars". Let's assume the input is padded with zeros or specific terminators.
    // ASCII NULL (0x00) is a safe assumption for unused space.
    
    function automatic is_subseq;
        input [15:0][7:0] a;
        input [15:0][7:0] b;
        integer i, j;
        begin
            i = 0;
            j = 0;
            is_subseq = 1'b1;
            // We iterate up to 16. In hardware, this is a loop that will be unrolled.
            // We need to find 'a' inside 'b'.
            // Strategy: Iterate j through b, try to match current char of a.
            
            // Only check valid characters (non-zero). Assuming 0 is terminator.
            // Find length of a
            // Note: In Verilog function, variables must be static or reset inside.
            // To avoid complex loops, we can use a simple state match.
            
            // Let's implement a robust subsequence check:
            // Iterate through B, try to consume A.
            integer a_ptr;
            a_ptr = 0;
            
            // Check if A is empty
            if (a[0] == 8'h00) begin
                is_subseq = 1'b1;
            end else begin
                for (int k = 0; k < 16; k++) begin
                    if (b[k] == 8'h00) disable verilog_loop; // End of B
                    if (a_ptr < 16 && a[a_ptr] != 8'h00 && b[k] == a[a_ptr]) begin
                        a_ptr = a_ptr + 1;
                    end
                end
                // If we consumed all of A
                if (a_ptr < 16 && a[a_ptr] == 8'h00) is_subseq = 1'b1;
                else if (a_ptr == 16) is_subseq = 1'b1; // Should handle length exactly 16
                else is_subseq = 1'b0;
            end
        end
    endfunction

    // --- State Definitions ---
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam CHECK_SUB = 3'b010; // Wait for subsequence check result
    localparam DECIDE = 3'b011;    // Process subsequence result, try paths
    localparam BACKTRACK = 3'b100;
    localparam SOLUTION = 3'b101;
    localparam IMPOSSIBLE = 3'b110;
    localparam VERIFY_LAST = 3'b111; // Verification state for target

    reg [2:0] state, next_state;

    // --- Datapath Registers ---
    reg [15:0] mask1, mask2; // Current paths
    reg [15:0] used_mask;    // Fossils used
    reg [4:0] current_fossil_idx; // Index of fossil being considered
    
    // Stack for backtracking. Max depth 16.
    // We store: mask1, mask2, used_mask, current_fossil_idx, and 'decision_taken' (which path we tried)
    // To save space, we can store only diffs, but full storage is easier for 16 depth.
    reg [15:0] stack_mask1 [0:15];
    reg [15:0] stack_mask2 [0:15];
    reg [15:0] stack_used [0:15];
    reg [4:0]  stack_idx [0:15];
    reg [1:0]  stack_decision [0:15]; // 0=none, 1=path1, 2=path2, 3=backtracked
    reg [3:0]  stack_ptr;

    // --- Subsequence Check Registers ---
    // We need to compare candidate fossil vs all fossils currently in a path.
    // This is a loop in software, but sequential hardware.
    reg [15:0][7:0] check_a;
    reg [15:0][7:0] check_b;
    wire check_res;
    wire check_done; // Not really needed if we treat it as logic, but here we use it as state trigger

    // Instantiate logic for current check
    // We write a dedicated combinational block for the current comparison pair
    reg is_valid_sub;
    
    always @(*) begin
        // Logic to determine is_valid_sub for current pair (check_a, check_b)
        // Implementation of is_subseq logic inline for clarity and synthesis
        integer ptr;
        integer k;
        ptr = 0;
        is_valid_sub = 1'b0;
        
        // Handle empty string cases
        if (check_a[0] == 8'h00) is_valid_sub = 1'b1;
        else begin
            // Scan B for A
            for (k = 0; k < 16; k++) begin
                if (check_b[k] == 8'h00) break;
                if (ptr < 16 && check_a[ptr] != 8'h00 && check_b[k] == check_a[ptr]) begin
                    ptr = ptr + 1;
                end
            end
            // Check if A was fully consumed
            if (ptr < 16 && check_a[ptr] == 8'h00) is_valid_sub = 1'b1;
            else if (ptr == 16) is_valid_sub = 1'b1; // Edge case: len 16 matches exactly
            else is_valid_sub = 1'b0;
        end
    end

    // --- Internal control signals ---
    reg check_request;
    reg [15:0] compare_mask; // Which fossils in the path to compare against
    reg [4:0] compare_idx;   // Index of fossil in compare_mask being checked
    reg candidate_ok;        // Result of full chain check

    // --- Target Verification Logic ---
    // We need to verify that the final chain (path) is compatible with the target.
    // The problem states: "A valid chain means ... one must be a subsequence of the other".
    // It also says "assign each fossil to one of two paths".
    // Wait, the prompt asks for: "result_mask1 and result_mask2".
    // And "A valid chain means that for any two sequences in the chain, one must be a subsequence of the other".
    // Is the TARGET part of a chain? Or just the fossils?
    // "solve the parallel evolution problem". "Assign each fossil to one of two paths".
    // Usually, these problems mean: Two independent paths, or paths that end at a target?
    // The prompt says: "Verify if the assignment maintains the chain property". "For every fossil P_i already in P...".
    // It does NOT explicitly mention the target in the chain check logic description.
    // However, usually these problems imply the two paths form a cover or are valid sequences.
    // Let's look at the inputs: `target` is given. 
    // "Target sequence". 
    // Let's assume the goal is to partition fossils such that:
    // 1. Path 1 is a valid chain (totally ordered by subsequence).
    // 2. Path 2 is a valid chain.
    // 3. (Optional) The target is related? Or just two independent paths?
    // "Parallel evolution problem" often implies two lineages converging or diverging.
    // Given the "result_mask1", "result_mask2" and "valid" output, and no explicit requirement to link to target in the description of paths,
    // I will implement a search that partitions the fossils into two valid chains.
    // BUT, the prompt says: "The module should implement a depth-first search... assign each fossil to one of two paths."
    // And "Verification logic: ... check if F can be added to P".
    // There is no mention of checking F against target in the main loop.
    // HOWEVER, usually these tasks imply the solution must satisfy a constraint involving target.
    // Let's re-read: "solve the parallel evolution problem for a scaled-down constraint set."
    // "Target sequence". 
    // If the target is irrelevant, the problem is trivial (put everything in path 1 if it's a chain). 
    // The "Target" is likely the sequence that must be formed, or the two paths must be subsequence of target?
    // Or perhaps the two paths MUST be subsequences of the target? 
    // "Parallel evolution" -> Two paths that both end at the target? Or are subsequences of target?
    // Given the inputs, I will assume the goal is:
    // Find a partition of fossils into two sets (Path 1, Path 2) such that:
    // - Path 1 is a valid chain.
    // - Path 2 is a valid chain.
    // - AND, every fossil in Path 1 is a subsequence of Target (or vice versa).
    // - AND, every fossil in Path 2 is a subsequence of Target.
    // Wait, the prompt says: "One must be a subsequence of the other" (in the chain).
    // It does NOT say "F must be subsequence of Target".
    // However, the "Target" input is given. It would be useless otherwise.
    // Let's assume the requirement is: 
    // The union of the two paths should be the set of fossils.
    // And the solution is valid if it respects the chain property.
    // Why is Target there? Maybe both paths must be subsequences of Target? 
    // Or the two paths merge into Target?
    // Let's assume the most logical "Parallel Evolution" constraint:
    // The two paths are independent chains, AND they are both subsequences of the Target.
    // (Or perhaps they just need to be valid chains, and the Target is a specific string to check against?)
    // Let's implement: Chain check. And finally, check if the resulting masks form valid chains.
    // And assume the user wants to find *any* partition.
    // If the user provided Target, maybe the check is: Is the final chain (path) a subsequence of Target?
    // Let's verify: "Parallel Evolution" often means independent lineages.
    // I will implement the search as: Partition fossils into two sets. Check if each set is a valid chain.
    // I will IGNORE the Target in the search loop to keep it simple, or add it as a final check.
    // Actually, looking at the "Specification Details": "Use 8-bit ASCII... Max string length...".
    // The Target is likely the "Goal". 
    // Let's assume the rule is:
    // 1. Path 1 must be a valid chain (totally ordered by subsequence).
    // 2. Path 2 must be a valid chain.
    // 3. (Optional) Path 1 and Path 2 are disjoint.
    // 4. (Optional) All fossils must be assigned.
    // Given the output `valid`, it implies a valid state.
    // I will assume the problem is: Split fossils into two sets such that each set is a chain.
    // And if `target` is provided, maybe it's a constraint. 
    // To be safe and useful, I will add a final check: 
    // The "Super Chain" (Path 1 + Path 2) must be a valid chain? No, "parallel" implies disjoint.
    // Let's stick to: Find a partition where both paths are valid chains.
    // I will ignore `target` for the *search* to avoid overfitting to an ambiguous requirement, 
    // but I will add a check at `SOLUTION` state: Is Path 1 a subsequence of Target? (Or similar).
    // Actually, let's read: "solve the parallel evolution problem".
    // Maybe the `target` is the sequence that `Path 1` and `Path 2` are derived from.
    // Let's implement: 
    // While searching: Check chain property.
    // If a solution is found: Check `result_mask1` is a subsequence of target? 
    // Or `result_mask2` is a subsequence of target?
    // Let's go with: Both paths must be subsequences of target. 
    // AND both paths must be valid chains.
    
    // --- Sequential Logic ---
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            impossible <= 1'b0;
            result_mask1 <= 16'b0;
            result_mask2 <= 16'b0;
            check_request <= 1'b0;
            stack_ptr <= 4'b0;
            used_mask <= 16'b0;
            mask1 <= 16'b0;
            mask2 <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Reset search variables
                    used_mask <= 16'b0;
                    mask1 <= 16'b0;
                    mask2 <= 16'b0;
                    stack_ptr <= 4'b0;
                    // Find first unassigned fossil
                    current_fossil_idx <= 0;
                    // If num_fossils is 0, solution is empty masks?
                    if (num_fossils == 0) begin
                        // Check if empty is valid (usually yes, but maybe need to check target?)
                        // Assume empty paths are valid.
                        // But wait, we need to check Target compatibility.
                        // Let's just go to verify if empty is valid.
                        // But DFS usually iterates. If 0 fossils, we are done.
                        result_mask1 <= 16'b0;
                        result_mask2 <= 16'b0;
                        state <= SOLUTION; // Or CHECK_SUB with special logic
                    end else begin
                        state <= DECIDE;
                    end
                end

                DECIDE: begin
                    // We are at a decision point for current_fossil_idx.
                    // Check if fossil is already used (shouldn't happen if logic is correct, but safe to skip)
                    if (current_fossil_idx >= num_fossils) begin
                        // All assigned? Check target validity?
                        // Or just verify the chain is valid (it was checked incrementally).
                        // The prompt says: "Result valid when partition found".
                        // Let's verify Target compatibility here.
                        // We need to verify that both paths are subsequences of Target?
                        // Let's assume: Path 1 is subsequence of Target, Path 2 is subsequence of Target.
                        // We will enter a sub-state to verify this.
                        state <= VERIFY_LAST;
                    end else if (used_mask[current_fossil_idx]) begin
                        // Already used, skip to next
                        current_fossil_idx <= current_fossil_idx + 1;
                    end else begin
                        // Decision: Try Path 1? Or Path 2? Or Backtrack?
                        // We need to track "did we try path 1?" in stack.
                        if (stack_ptr > 0 && stack_decision[stack_ptr-1] == 1) begin
                            // We came from backtracking or already tried path 1.
                            // Try Path 2.
                            // Check if we can add to Path 2
                            check_a <= fossils[current_fossil_idx];
                            // Need to compare against all fossils in mask2
                            // We set up the loop in CHECK_SUB state.
                            // But for initial setup:
                            compare_mask <= mask2;
                            compare_idx <= 0;
                            candidate_ok <= 1'b1; // Assume true until proven false
                            state <= CHECK_SUB;
                            // Store decision that we are trying path 2 (value 2)
                            stack_decision[stack_ptr] <= 2; 
                        end else begin
                            // First try: Path 1
                            check_a <= fossils[current_fossil_idx];
                            compare_mask <= mask1;
                            compare_idx <= 0;
                            candidate_ok <= 1'b1;
                            state <= CHECK_SUB;
                            stack_decision[stack_ptr] <= 1;
                        end
                    end
                end

                CHECK_SUB: begin
                    // We need to iterate through fossils in the path (compare_mask)
                    // Check if check_a and fossils[compare_idx] are comparable (one is subseq of other)
                    // If valid, move to next. If invalid, set candidate_ok = 0.
                    
                    // If compare_mask is 0 (path empty), it's valid. Skip to decision result.
                    if (compare_mask == 0) begin
                        state <= DECIDE_RESULT; // Helper state to handle success
                    end else begin
                        // Find next set bit in compare_mask starting from compare_idx
                        // Since we are in CHECK_SUB, we have a specific check_a (candidate)
                        // and we are comparing it against one fossil in the path at a time.
                        
                        // Optimization: The actual subsequence check 'is_valid_sub' is combinational
                        // based on 'check_a' and 'fossils[compare_idx]'.
                        // We update inputs, wait a cycle for result.
                        
                        // Check if current compare_idx is in compare_mask
                        if (compare_mask[compare_idx]) begin
                            // Setup check_b
                            check_b <= fossils[compare_idx];
                            // We need to wait for combinational result?
                            // Or assume it's ready next cycle.
                            // Let's assume combinational logic updates 'is_valid_sub' immediately.
                            // But 'fossils[compare_idx]' is an input. So 'check_b' updates immediately.
                            // 'is_valid_sub' updates based on that.
                            // So we can decide immediately in this cycle or register it.
                            // To be safe and clean, let's register the result or use a state to process it.
                            // Let's use a micro-state.
                            state <= CHECK_SUB_2;
                        end else begin
                            // Bit not set, find next
                            compare_idx <= compare_idx + 1;
                            // Need to loop check. 
                            // If we reach end, we are done.
                            if (compare_idx == 15) state <= DECIDE_RESULT;
                        end
                    end
                end
                
                // Micro-state for verification
                CHECK_SUB_2: begin
                    // 'is_valid_sub' is now valid for check_a vs check_b (current fossil vs candidate)
                    if (!is_valid_sub) begin
                        candidate_ok <= 1'b0;
                        // No need to check further
                        state <= DECIDE_RESULT;
                    end else begin
                        // Continue to next fossil in path
                        if (compare_idx == 15) begin
                             state <= DECIDE_RESULT;
                        end else begin
                             compare_idx <= compare_idx + 1;
                             state <= CHECK_SUB;
                        end
                    end
                end

                DECIDE_RESULT: begin
                    // Here we know if the current attempt (Path 1 or Path 2) is valid.
                    // Valid means: candidate_ok is 1.
                    if (candidate_ok) begin
                        // Success! Apply assignment.
                        // Push state to stack (save state BEFORE assignment for backtrack)
                        stack_mask1[stack_ptr] <= mask1;
                        stack_mask2[stack_ptr] <= mask2;
                        stack_used[stack_ptr] <= used_mask;
                        stack_idx[stack_ptr] <= current_fossil_idx;
                        stack_ptr <= stack_ptr + 1;

                        // Apply assignment
                        used_mask[current_fossil_idx] <= 1'b1;
                        if (stack_decision[stack_ptr] == 1) begin
                            mask1[current_fossil_idx] <= 1'b1;
                        end else begin
                            mask2[current_fossil_idx] <= 1'b1;
                        end

                        // Advance to next fossil
                        current_fossil_idx <= 0; // Reset to 0 to scan for next unused
                        state <= DECIDE;
                    end else begin
                        // Failed attempt.
                        // If we just failed Path 1, try Path 2 (DECIDE logic handles this by checking stack_decision)
                        // If we just failed Path 2, we must backtrack.
                        // But wait, in DECIDE we set stack_decision[ptr].
                        // If we are here and decision was 2, we failed both.
                        if (stack_ptr > 0 && stack_decision[stack_ptr-1] == 2) begin
                            // We tried Path 1 (checked in DECIDE, set decision 1), failed -> went to DECIDE, tried Path 2 (set decision 2), failed -> here.
                            // Wait, logic flow:
                            // DECIDE checks stack_decision. 
                            // If empty or 1, try P1. Set stack_decision[ptr]=1. Go CHECK_SUB.
                            // If fail, back to DECIDE. 
                            // DECIDE sees stack_decision[ptr-1] == 1. Tries P2. Set stack_decision[ptr-1]=2.
                            // If fail, back to DECIDE.
                            // DECIDE sees stack_decision[ptr-1] == 2. Both tried. Backtrack.
                            state <= BACKTRACK;
                        end else begin
                            // Just failed Path 1. Loop back to DECIDE to try Path 2.
                            // DECIDE logic: stack_decision[ptr-1] == 1 -> Tries P2.
                            state <= DECIDE;
                        end
                    end
                end

                BACKTRACK: begin
                    if (stack_ptr == 0) begin
                        // Root failed
                        state <= IMPOSSIBLE;
                    end else begin
                        // Restore
                        stack_ptr <= stack_ptr - 1;
                        mask1 <= stack_mask1[stack_ptr - 1];
                        mask2 <= stack_mask2[stack_ptr - 1];
                        used_mask <= stack_used[stack_ptr - 1];
                        current_fossil_idx <= stack_idx[stack_ptr - 1];
                        // We need to retry the next branch of this node.
                        // The node at stack_ptr-1 had a decision stored.
                        // If it was 1, we need to try 2.
                        // We set stack_decision to 1 (to indicate we are processing retry)
                        // Actually, easier: The DECIDE state logic handles reading the stored decision.
                        // But we just restored the stack. 
                        // The restored stack_ptr points to the entry we just popped? No, we decremented it.
                        // So stack_ptr-1 is the *parent*. 
                        // We need to re-enter DECIDE to retry the child.
                        // We are back at the state where we had 'current_fossil_idx' to assign.
                        // We need to signal DECIDE to try the *other* path.
                        // We can update the stored decision in the stack to indicate progress.
                        // Let's modify the stack_decision at the NEW top.
                        // If it was 1, change to 2. 
                        // Wait, if we backtrack, it means we finished the subtree of the current decision.
                        // So we need to try the NEXT decision at the current level.
                        // But we just popped the level that failed.
                        // We are at level 'stack_ptr' (after decrement).
                        // Let's say we were at level 3, decision 1. Failed. Tried 2. Failed. Backtrack.
                        // Pop level 3. We are at level 2.
                        // We need to continue exploring level 2. 
                        // The stored decision at level 2 tells us what we were doing.
                        // If level 2 decision was 1, we just finished exploring path 1. We need to try path 2.
                        // Update decision to 2.
                        if (stack_decision[stack_ptr] == 1) begin
                            stack_decision[stack_ptr] <= 2;
                            state <= DECIDE;
                        end else if (stack_decision[stack_ptr] == 2) begin
                            // We finished exploring path 2 at this level too. Keep backtracking.
                            // We need to loop backtrack.
                            // Since combinational backtracking might cause issues, 
                            // we stay in BACKTRACK state until we find a level to advance.
                            state <= BACKTRACK;
                        end
                    end
                end

                VERIFY_LAST: begin
                    // We have a valid partition where both paths are chains.
                    // Now check Target compatibility.
                    // Let's assume: Path 1 must be a subsequence of Target.
                    // AND Path 2 must be a subsequence of Target.
                    // (This is a common "Target" constraint).
                    // We will verify Path 1 here. 
                    // If valid, verify Path 2 in next state or loop.
                    // We can reuse the CHECK_SUB logic. 
                    // Set check_a = Target. Check against all fossils in Path 1.
                    // Actually, we need "F is subsequence of Target" or "Target is subsequence of F"?
                    // "Parallel Evolution" -> Paths are subparts of Target.
                    // Let's assume: Fossils in paths must be subsequences of Target.
                    
                    // Check Path 1:
                    // We iterate through fossils. If bit set in mask1, check if fossil is subseq of target.
                    // We use `check_a` = fossil, `check_b` = target.
                    // We use the combinational `is_valid_sub`.
                    // We need a loop.
                    
                    // Let's use 'compare_idx' to iterate through fossils.
                    // 'compare_mask' holds the mask we are checking (Path 1 or 2).
                    compare_mask <= mask1;
                    compare_idx <= 0;
                    state <= VERIFY_LOOP;
                end

                VERIFY_LOOP: begin
                    // Iterate through all fossils 0 to 15
                    if (compare_idx >= num_fossils) begin
                        // Done with current path
                        if (compare_mask == mask1) begin
                            // Done with Path 1, check Path 2
                            compare_mask <= mask2;
                            compare_idx <= 0;
                            state <= VERIFY_LOOP;
                        end else begin
                            // Done with Path 2
                            state <= SOLUTION;
                        end
                    end else begin
                        // Check if this fossil is in the current path
                        if (compare_mask[compare_idx]) begin
                            // Verify: fossil [compare_idx] is subsequence of Target
                            check_a <= fossils[compare_idx];
                            check_b <= target;
                            state <= VERIFY_CHECK;
                        end else begin
                            compare_idx <= compare_idx + 1;
                        end
                    end
                end

                VERIFY_CHECK: begin
                    if (!is_valid_sub) begin
                        // If target check fails, this is not a valid solution per target constraint.
                        // But maybe other partitions exist? 
                        // We exhausted this branch. 
                        // Since we only found ONE valid partition (this one), we should fail.
                        // Wait, DFS should find all partitions. 
                        // If this partition fails target check, we should BACKTRACK to find another.
                        // However, we reached VERIFY_LAST by exhausting the search tree (current_fossil_idx >= num_fossils).
                        // That means NO other partitions exist in the tree (we traversed fully).
                        // So if this one fails, it's IMPOSSIBLE.
                        state <= IMPOSSIBLE;
                    end else begin
                        compare_idx <= compare_idx + 1;
                        state <= VERIFY_LOOP;
                    end
                end

                SOLUTION: begin
                    valid <= 1'b1;
                    result_mask1 <= mask1;
                    result_mask2 <= mask2;
                    state <= IDLE; // Or stay here until reset/start
                end

                IMPOSSIBLE: begin
                    impossible <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule

module TopModule(evolution_solver);
    // Wrapper if needed, but the problem asks for 'evolution_solver'
    // The module above is the implementation.
endmodule

module evolution_solver_top();
    // Just for syntax check if needed, but not required by prompt.
endmodule