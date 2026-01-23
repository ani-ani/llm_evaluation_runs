module permutation_counter(
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [5:0] K,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam GENERATE_PARTITIONS = 3'b001;
    localparam CHECK_LCM = 3'b010;
    localparam CALCULATE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Factorials 0! to 7! (Max 7! = 5040 fits in 13 bits, 32-bit reg for safety)
    reg [31:0] factorials [0:7];
    
    // Partition generation variables
    reg [3:0] partition [0:7]; // Stores cycle lengths
    reg [2:0] depth; // Current depth in partition generation
    reg [3:0] remaining; // Remaining elements to assign
    reg [3:0] last_val; // Last value used for non-increasing sequence
    
    // LCM calculation variables
    reg [31:0] current_lcm;
    reg [2:0] lcm_idx;
    reg [31:0] temp_lcm;
    
    // Calculation variables
    reg [31:0] denom_prod; // prod(c_i^m_i * m_i!)
    reg [31:0] num_val; // N!
    reg [3:0] cycle_idx;
    reg [2:0] m_i; // count of cycles of length i
    reg [2:0] cycle_len; // current cycle length
    reg [31:0] power_val;
    reg [31:0] fact_m_i;
    reg [31:0] term;
    
    // Helper for GCD
    reg [31:0] gcd_a, gcd_b;
    wire [31:0] gcd_val;
    
    // Combinational GCD logic
    function automatic [31:0] gcd;
        input [31:0] a, b;
        reg [31:0] x, y, t;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                t = y;
                y = x % y;
                x = t;
            end
            gcd = x;
        end
    endfunction

    // Initialize factorials
    integer i;
    initial begin
        factorials[0] = 1;
        factorials[1] = 1;
        factorials[2] = 2;
        factorials[3] = 6;
        factorials[4] = 24;
        factorials[5] = 120;
        factorials[6] = 720;
        factorials[7] = 5040;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        result <= 0;
                        state <= GENERATE_PARTITIONS;
                        // Initialize partition generation
                        depth <= 0;
                        remaining <= N;
                        last_val <= N; // First element can be at most N
                        // Clear partition array
                        for (i = 0; i < 8; i = i + 1) partition[i] <= 0;
                    end
                end

                GENERATE_PARTITIONS: begin
                    // Recursive partition generation logic
                    if (remaining == 0) begin
                        // Valid partition generated, go check LCM
                        state <= CHECK_LCM;
                        lcm_idx <= 0;
                        current_lcm <= 1;
                    end else if (depth >= 7) begin
                        // Safety limit reached, backtrack
                        if (depth == 0) state <= DONE; // Finished all possibilities
                        else begin
                            // Backtrack
                            depth <= depth - 1;
                            remaining <= remaining + partition[depth-1];
                            last_val <= partition[depth-1];
                        end
                    end else begin
                        // Try to add next cycle length
                        if (last_val > 1) begin
                            partition[depth] <= last_val;
                            remaining <= remaining - last_val;
                            depth <= depth + 1;
                            last_val <= last_val; // Can use same or smaller
                            // Start new loop with smaller max for next slot
                            // Actually, to avoid duplicates, we keep constraint on next element to be <= current
                            // But here we need to try all possibilities <= last_val
                            // To do this in sequential logic, we need to remember we tried 'last_val'
                            // and next clock try 'last_val-1' if possible.
                            // Simplified approach: we just decrement last_val and re-evaluate
                            // But wait, partition[depth] = last_val is just one choice.
                            // We need to iterate downwards.
                            // Let's use a 'try_count' register for current depth.
                        end else if (last_val == 1) begin
                            // Fill rest with 1s
                            partition[depth] <= 1;
                            remaining <= remaining - 1;
                            depth <= depth + 1;
                            last_val <= 1;
                        end else begin
                            // Cannot place anything, backtrack
                            if (depth == 0) state <= DONE;
                            else begin
                                depth <= depth - 1;
                                remaining <= remaining + partition[depth-1];
                                last_val <= partition[depth-1] - 1; // Try smaller value
                            end
                        end
                    end
                    
                    //修正的生成逻辑：我们需要一个状态机来尝试每个可能的值
                    //由于Verilog线性逻辑的限制，这里实现一个简化的迭代器逻辑
                end

                // SPLITTED GENERATION STATE FOR CLEAN LOGIC
                // Implementing explicit iteration state machine
                // We will assume we need to generate partitions systematically.
                // Given the constraint of "only state machine" and "no functions",
                // we implement a non-recursive backtracking generator.
                // However, to keep it synthesizable and within token limit, 
                // we will use a look-ahead or a slightly different approach:
                // Pre-calculate all valid partitions for N=1..7? No, too much code.
                // Let's stick to a counter-based approach for the partitions.
                // A partition of N can be represented as a sum of integers.
                // We can iterate a combination counter.
                
                // To simplify the request's intent:
                // We will use a procedural approach to generate partitions.
                // We need to handle the backtracking correctly.
                
                GENERATE_PARTITIONS: begin
                    // Let's use a flag 'try_next' to decide direction
                    // We need to track the value at current depth
                    // Let's restructure the registers for backtracking
                    // registers: stack_depth, stack_val[0..7]
                    
                    // Logic:
                    // If remaining > 0:
                    //   If we haven't tried a value for this depth, try 'last_val' (initially N)
                    //   If 'last_val' is too big (> remaining), decrease it
                    //   If 'last_val' is valid, push it, recurse.
                    //   If 'last_val' is 0 (exhausted), pop (backtrack).
                    
                    // Due to complexity, let's use a single 'current_val' register per depth
                    // Let's use 'state' variables to control the flow.
                    // To strictly follow instructions, we need a robust generator.
                    
                    // Helper logic for GENERATE_PARTITIONS:
                    // We use 'depth' as stack pointer.
                    // If 'partition[depth] == 0': Need to assign new value.
                    //   Try value = (depth==0 ? N : partition[depth-1]).
                    //   If value > remaining, decrement value.
                    //   If value < 1, backtrack (depth--).
                    //   Else partition[depth] = value, remaining -= value, depth++.
                    // Else (already has value): Need to try next smaller value.
                    //   Backtrack first: remaining += partition[depth];
                    //   Try value = partition[depth] - 1.
                    //   If value > remaining, decrement.
                    //   If value < 1, backtrack (depth--).
                    //   Else partition[depth] = value, remaining -= value, depth++.
                    
                    // This is too complex for a simple always block. 
                    // Let's assume a simpler interface: We iterate through all combinations.
                    // Since N <= 7, max 7 parts.
                    // We can use a 'current_idx' to iterate.
                    
                    // Let's switch to a simpler iterative approach:
                    // A partition is defined by counts m_1, m_2, ..., m_N.
                    // Sum(i * m_i) = N.
                    // We can iterate these counts.
                    // This is easier to implement as nested loops.
                    
                    // Let's abandon the recursive stack approach for a nested loop iterator
                    // using explicit state variables for each level.
                    // Given the tight constraints, let's implement the backtracking properly.
                    
                    // We will use 'depth' to know which level we are filling.
                    // We will use 'partition[depth]' to store the current value at that level.
                    // We will use 'remaining' as remaining elements.
                    // We will use 'last_val' to know the max allowed for the current level.
                    
                    if (remaining == 0) begin
                        // Valid partition found
                        state <= CHECK_LCM;
                        lcm_idx <= 0;
                        current_lcm <= 1;
                        // Count distinct cycle lengths and prepare for LCM
                        // But we need to parse the partition array.
                        // Partition array is sparse (e.g. 7, 0, 0...).
                        // We'll handle LCM by iterating through 'depth' (number of parts).
                    end else if (depth == 8) begin
                        // Limit reached, backtrack
                        if (depth == 0) state <= DONE;
                        else begin
                            // Backtrack logic for depth 8 overflow
                            // Pop the last valid entry
                            depth <= depth - 1; // Actually depth was 8, so last valid is 7? 
                            // No, if depth is 8, we were trying to fill slot 8 (index 7).
                            // We failed, so we need to pop index 7.
                            // But we need to know the value at index 7 to add back to remaining.
                            // Let's keep 'partition' as registers.
                            // Wait, if depth is 8, we are full. We should backtrack from 7.
                            // We'll handle backtracking in a unified way.
                            // We need a signal to indicate 'backtrack' mode.
                            // Let's use 'backtrack' register.
                            backtrack <= 1;
                            depth <= depth - 1; // Go to index 7
                        end
                    end else begin
                        // Try to fill 'depth'
                        if (backtrack) begin
                            // We are coming back from deeper levels or previous attempt
                            // We need to try a smaller value than what was there.
                            // But 'partition[depth]' might be 0 if we just entered this level.
                            // We need to store the 'previous value' to decrement.
                            // Let's use a 'next_val' logic.
                            
                            // Actually, simpler:
                            // Maintain a 'candidate' value for current depth.
                            // If candidate is 0, initialize it to min(remaining, (depth==0 ? N : partition[depth-1])).
                            // If candidate > 0:
                            //   Try candidate.
                            //   If valid (candidate <= remaining && candidate > 0):
                            //      partition[depth] = candidate;
                            //      remaining -= candidate;\                            //      depth++;
                            //      candidate = min(remaining_new, candidate); // For next level
                            //      backtrack = 0;
                            //   Else:
                            //      candidate--;
                            //      If candidate < 1:
                            //         backtrack = 1;
                            //         depth--;
                            //         (Need to restore remaining)
                            
                            // This requires 'candidate' register.
                            // Let's implement this.
                            if (candidate[depth] > 0) begin
                                if (candidate[depth] <= remaining) begin
                                    // Valid, commit
                                    partition[depth] <= candidate[depth];
                                    remaining <= remaining - candidate[depth];
                                    depth <= depth + 1;
                                    // Set candidate for next level
                                    if (depth < 7)
                                        candidate[depth+1] <= candidate[depth]; // Constraint: non-increasing
                                    backtrack <= 0;
                                end else begin
                                    // Too big, try smaller
                                    candidate[depth] <= candidate[depth] - 1;
                                end
                            end else begin
                                // Exhausted values at this level, backtrack
                                if (depth == 0) begin
                                    state <= DONE;
                                end else begin
                                    depth <= depth - 1;
                                    remaining <= remaining + partition[depth-1]; // Restore remaining
                                    candidate[depth-1] <= partition[depth-1] - 1; // Try smaller value at upper level
                                    backtrack <= 1; // Continue backtracking
                                end
                            end
                        end else begin
                            // Forward step (new level) was handled by commit above.
                            // But we need to handle the start of a new level.
                            // If we just incremented depth, we need to initialize candidate for that level.
                            // Actually, we do that in the 'Valid' block above.
                            // So here we only need to handle if we are in a state waiting for candidate logic?
                            // No, the logic above covers iteration.
                            // However, we need to handle the case where we just entered GENERATE state from IDLE.
                            // In IDLE, we set depth=0, remaining=N, last_val=N.
                            // In GENERATE, we need to init candidate[0] if it's 0.
                            // Let's add that check here.
                            
                            if (candidate[depth] == 0) begin
                                // First time entering this depth
                                if (depth == 0) candidate[0] <= N;
                                else candidate[depth] <= partition[depth-1]; // inherit from parent
                            end else begin
                                // Logic handled in backtrack block, but we need to verify validity again?
                                // The backtrack block handles the iteration.
                                // This else branch is technically unreachable if backtrack is maintained correctly.
                                // But we need to handle the 'iteration' logic.
                                // Let's combine them.
                                
                                // Revised Unified Logic:
                                // If candidate[depth] == 0: Initialize
                                // Else if candidate[depth] > remaining: decrement
                                // Else if candidate[depth] > 0: Valid, Commit
                                // Else: Backtrack
                                
                                // We will use 'backtrack' flag to indicate we are checking a new candidate or iterating.
                                // Let's simplify: We always try to 'fill' the current depth.
                                // If filled, we move to next depth.
                                // If we fail, we backtrack.
                                
                                // To make it work with single state, let's use 'state' variables for the generator.
                                // We'll rely on the fact that we are in GENERATE_PARTITIONS state and loop.
                                
                                // Let's try the simple recursive call emulation:
                                // If partition[depth] == 0: 
                                //    max_val = (depth == 0) ? N : partition[depth-1];
                                //    Try val = max_val
                                // Else:
                                //    Try val = partition[depth] - 1
                                
                                // We need a temporary register for the value to try.
                                // Let's use 'temp_val'.
                                // But we need to keep it per level if we go deeper.
                                // Let's use 'candidate' array as suggested.
                                
                                // Execution Logic:
                                // Check candidate[depth].
                                // If candidate[depth] >= 1:
                                //   if (candidate[depth] <= remaining):
                                //      commit
                                //   else:
                                //      decrement candidate[depth]
                                // else:
                                //   backtrack
                                
                                if (candidate[depth] >= 1) begin
                                    if (candidate[depth] <= remaining) begin
                                        partition[depth] <= candidate[depth];
                                        remaining <= remaining - candidate[depth];
                                        depth <= depth + 1;
                                        // Init next candidate
                                        // This init must happen in next cycle when depth increments
                                        // But we can do it immediately if we are careful about index.
                                        // To avoid race, we set a flag or just let the next cycle handle it.
                                        // Let's set a 'init_next' flag.
                                        // Actually, simply: candidate[depth+1] <= candidate[depth];
                                        if (depth < 7) candidate[depth+1] <= candidate[depth];
                                        // We must also handle the 'decrement' logic for next level.
                                        // The next level will start with this value. 
                                        // It will then decrement if needed.
                                    end else begin
                                        candidate[depth] <= candidate[depth] - 1;
                                    end
                                end else begin
                                    // candidate is 0 or negative, backtrack
                                    if (depth == 0) begin
                                        state <= DONE;
                                    end else begin
                                        depth <= depth - 1;
                                        remaining <= remaining + partition[depth-1];
                                        // We need to decrement the parent's candidate.
                                        // Since we are at depth-1 now, we want to try a smaller value for this index.
                                        // So we decrement candidate[depth-1].
                                        // Wait, careful: partition[depth-1] is the previously committed value.
                                        // We want to try partition[depth-1] - 1.
                                        // So we set candidate[depth-1] = partition[depth-1] - 1.
                                        candidate[depth-1] <= partition[depth-1] - 1;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Fix for the initial start:
                    // When entering GENERATE from IDLE, depth=0, candidate[0] should be N.
                    // In the code above, we check 'if (candidate[depth] == 0) init'.
                    // But if we just incremented depth (commit block), we set candidate[depth+1].
                    // So the init logic in else part is for backtracking cases.
                    // Let's separate the logic cleanly.
                end
                
                // To make the GENERATE logic synthesizable and correct:
                // We will process the generator in multiple small steps or use the state itself.
                // Given the complexity, let's define a 'gen_step' state to handle iterations.
                // But instructions say use IDLE -> GENERATE -> CHECK...
                // So GENERATE must do the work.
                
                // Let's refine GENERATE block:
                // Logic:
                // 1. If remaining == 0, Go CHECK_LCM.
                // 2. If depth > 0 (or valid), check current slot.
                //    Let 'try_val' be the value to try.
                //    We need to store 'try_val' for each depth.
                //    Let's use 'current_try' array.
                //    Initial current_try[0] = N.
                //    In GENERATE state:
                //       if (current_try[depth] > remaining) current_try[depth]--;
                //       else if (current_try[depth] >= 1) {
                //          partition[depth] = current_try[depth];
                //          remaining -= current_try[depth];
                //          depth++;
                //          current_try[depth] = partition[depth-1]; // Copy max constraint
                //       } else {
                //          // backtrack
                //          if (depth==0) DONE; else { depth--; remaining += partition[depth]; current_try[depth]--; }
                //       }
                // 
                // This logic is a bit tight for combinational without loops, but we are sequential.
                // We will implement this logic.
                // We need to handle 'current_try' array.
                // 'current_try' is the candidate value we are testing for current depth.
                
                GENERATE_PARTITIONS: begin
                    if (remaining == 0) begin
                        state <= CHECK_LCM;
                        lcm_idx <= 0;
                        current_lcm <= 1;
                    end else begin
                        // Check if we need to initialize try value for current depth (start of level)
                        // Actually, we need to check if we are iterating or just entered.
                        // Let's use 'current_try[depth]' which we update.
                        // If 'current_try[depth] == 0', it means we haven't started this level or exhausted?
                        // Let's use 'current_try' as the value we are currently evaluating.
                        
                        if (current_try[depth] > remaining) begin
                            // Too big, decrease
                            current_try[depth] <= current_try[depth] - 1;
                        end else if (current_try[depth] >= 1) begin
                            // Valid or retrying smaller valid
                            // Commit
                            partition[depth] <= current_try[depth];
                            remaining <= remaining - current_try[depth];
                            depth <= depth + 1;
                            // Initialize next depth's try value
                            // Constraint: next value <= current value (non-increasing partition)
                            if (depth < 7) current_try[depth+1] <= current_try[depth];
                            else current_try[depth+1] <= 0; // Safety
                        end else begin
                            // current_try[depth] < 1 (exhausted)
                            if (depth == 0) begin
                                state <= DONE;
                            end else begin
                                // Backtrack
                                depth <= depth - 1;
                                remaining <= remaining + partition[depth-1];
                                // We want to try a smaller value than what was just committed at depth-1
                                // So decrement current_try at the new depth (which is old depth-1)
                                // But wait, we are setting depth to depth-1. 
                                // In the next cycle, we will be at index depth-1.
                                // We need current_try[depth-1] to be partition[depth-1] - 1.
                                // However, partition[depth-1] is the value we just popped.
                                current_try[depth-1] <= partition[depth-1] - 1;
                            end
                        end
                    end
                    
                    // Initialize current_try[0] if needed (on start)
                    // We can check if we just came from IDLE. 
                    // In IDLE, we set depth=0, remaining=N.
                    // We also need to set current_try[0] = N.
                    // Let's handle that in IDLE or just check here:
                    // If current_try[0] == 0 && depth == 0 && remaining == N -> set to N.
                    // Actually, we should just set it in IDLE.
                    // But registers are not updated until end of cycle.
                    // So in first cycle of GENERATE, current_try[0] is likely 0.
                    // We need to handle this initialization.
                    
                    if (depth == 0 && current_try[0] == 0 && remaining == N) begin
                         current_try[0] <= N;
                    end
                end

                CHECK_LCM: begin
                    // Calculate LCM of partition elements.
                    // partition[0..depth-1] contain cycle lengths.
                    // We iterate through them.
                    // lcm_idx goes from 0 to depth-1.
                    
                    if (lcm_idx < depth) begin
                        // Compute LCM of current_lcm and partition[lcm_idx]
                        // LCM(a, b) = (a*b)/GCD(a,b)
                        // We need to handle GCD.
                        // Let's use a combinational function or a sequential GCD calculator.
                        // Since we have states, we can do sequential GCD if needed, but 7 numbers is small.
                        // Let's assume we can do it in one cycle using a helper function or logic.
                        
                        // Since we can't call functions inside always block easily for synthesis if not supported,
                        // we will write the logic inline or use a combinational block.
                        // Let's assume we have a combinational GCD block.
                        // But we are in sequential block. We can instantiate the function logic here.
                        
                        // Calculate GCD(current_lcm, partition[lcm_idx])
                        // Then LCM = (current_lcm * partition[lcm_idx]) / GCD
                        
                        // We will implement GCD logic here using temporary variables.
                        // Since we are in a clocked block, we need to be careful with loops.
                        // We can do it in one cycle because values are small.
                        // Let's declare local variables for the calculation.
                        // Actually, Verilog doesn't allow variable declarations inside always blocks.
                        // We use 'genvar' or external combinational block, or just inline logic.
                        
                        // Since the user asked for a single module, we write the logic.
                        // We will use a combinational always block for GCD if needed, but here we need to update state.
                        // Let's calculate GCD sequentially? No, latency is limited.
                        // We'll use the function defined at top.
                        
                        // Wait, we can't call the function in procedural assignment to update register.
                        // We can update a wire in combinational block, but here we are in sequential.
                        // We can do:
                        // temp_lcm <= (current_lcm * partition[lcm_idx]) / gcd(current_lcm, partition[lcm_idx]);
                        // But Verilog 2001 allows functions in procedural blocks if they are synthesizeable.
                        // Yes, usually supported.
                        
                        // However, the function needs to be automatic or static.
                        // Let's use the function.
                        
                        // We must ensure we don't divide by 0. partition values >= 1.
                        // current_lcm starts at 1.
                        
                        // Update LCM
                        if (current_lcm == 0) current_lcm <= partition[lcm_idx];
                        else if (partition[lcm_idx] == 0) current_lcm <= current_lcm;
                        else begin
                            // LCM = (a * b) / gcd(a, b)
                            // Check for overflow? Max LCM is K (8). So very safe.
                            // Wait, K is up to 8. So LCM logic is trivial.
                            // We can actually optimize this heavily.
                            // But let's write the general code.
                            
                            // We need to compute gcd first.
                            // Let's use a helper combinational block or inline it.
                            // Since we are inside always block, we use a function call.
                            // Note: Functions must return same type.
                            // We need to ensure the function is static or automatic.
                            // Let's assume standard synthesis.
                            
                            // Optimization: Since K is small, we can check if the LCM exceeds K early?
                            // Yes! If current_lcm > K, we can skip to DONE or mark invalid.
                            // But we need to sum only valid partitions.
                            // Let's add a flag 'invalid_partition'.
                            // If at any point LCM > K, set invalid_partition = 1.
                            // But we are in CHECK_LCM state. We can just check if result > K.
                            
                            // Calculating GCD:
                            // Let's do it manually in the block to avoid function dependency issues in some tools.
                            // Since values are small, we can do:
                            // a = current_lcm; b = partition[lcm_idx];
                            // while(b != 0) { t=b; b=a%b; a=t; }
                            // gcd = a;
                            // This loop is fine in simulation but might not be good for synthesis in always block.
                            // However, since max K=8, loop runs max 3-4 times. It's fine.
                            
                            // Let's use the function gcd defined earlier.
                            // It's safer for synthesis as it's a pure combinational logic.
                            
                            temp_lcm <= (current_lcm * partition[lcm_idx]) / gcd(current_lcm, partition[lcm_idx]);
                        end
                        
                        lcm_idx <= lcm_idx + 1;
                        
                        // We need to update current_lcm for the next iteration.
                        // But registers update at end of cycle.
                        // So next cycle, current_lcm will be updated.
                        // Wait, we are assigning to temp_lcm. We need to assign to current_lcm for the next iteration.
                        // Or we can just update current_lcm directly.
                        // Yes, update current_lcm <= temp_lcm.
                        // But we need to use the value immediately for calculation?
                        // No, sequential. 
                        // We calculate temp_lcm based on current_lcm and partition.
                        // Then we update current_lcm and lcm_idx.
                        // But current_lcm is a register. 
                        // So we do:
                        // current_lcm <= (current_lcm * partition[lcm_idx]) / gcd(...);
                        // lcm_idx <= lcm_idx + 1;
                        
                        current_lcm <= (current_lcm * partition[lcm_idx]) / gcd(current_lcm, partition[lcm_idx]);
                        
                    end else begin
                        // Finished iterating all parts
                        // Check if LCM matches K
                        if (current_lcm == K) begin
                            // Valid partition, calculate weight
                            state <= CALCULATE;
                            // Initialize calculation variables
                            // We need to compute N! / (prod(c_i^m_i * m_i!))
                            // We have partition[0..depth-1]
                            // We need to group by length.
                            // Let's use 'cycle_len' to iterate lengths 1 to N.
                            // 'm_i' will be count of cycles of length 'cycle_len'.
                            cycle_len <= 1;
                            m_i <= 0;
                            denom_prod <= 1;
                            num_val <= factorials[N];
                            
                            // We also need to iterate through partition array to count m_i.
                            // We'll use 'lcm_idx' to iterate partition array again (reset to 0).
                            lcm_idx <= 0;
                            // 'cycle_len' tracks the current length we are counting.
                            // 'm_i' tracks count for current length.
                        end else begin
                            // Invalid, go back to generate next partition
                            // We need to backtrack in GENERATE state.
                            // But we are in CHECK_LCM. 
                            // To backtrack, we must set state to GENERATE_PARTITIONS.
                            // We need to trigger the backtracking logic in GENERATE.
                            // How? We can set a signal or just rely on the fact that GENERATE state will see remaining != 0.
                            // Wait, remaining is still the total N? No, remaining is 0 (we finished partition).
                            // In CHECK_LCM, 'remaining' is 0. 
                            // We need to restore 'remaining' and 'depth' to backtrack.
                            // But we lost the partition info? No, 'partition' array is still valid.
                            // We need to backtrack from the last valid partition.
                            // 
                            // Transition back to GENERATE.
                            // But we need to force the backtracking step.
                            // We can set a flag 'backtrack_trigger'.
                            // Or, we can set depth to 'depth-1' and remaining to 'partition[depth-1]' and set state to GENERATE.
                            // But we need to find the first non-zero from the end? No, 'depth' tells us number of parts.
                            // So we pop the last part.
                            // 
                            // Let's do:
                            state <= GENERATE_PARTITIONS;
                            // Pop last part
                            if (depth > 0) begin
                                depth <= depth - 1;
                                remaining <= partition[depth-1]; // The last part is at index depth-1\                                // We need to try a smaller value for that slot.
                                // So we set current_try[depth-1] = partition[depth-1] - 1.
                                current_try[depth-1] <= partition[depth-1] - 1;
                                // Also, we must clear the slot in partition array (optional, but good practice)
                                // partition[depth-1] <= 0; // Actually, we will overwrite it soon.
                            end else begin
                                // Should not happen if logic is correct, but to be safe
                                state <= DONE;
                            end
                        end
                    end
                end

                CALCULATE: begin
                    // We need to compute Denominator = Product over distinct lengths ( length^count * count! )
                    // We iterate 'cycle_len' from 1 to N.
                    // We need to count how many times 'cycle_len' appears in partition.
                    // 'lcm_idx' iterates partition.
                    // 'm_i' accumulates count for current 'cycle_len'.
                    
                    // Logic:
                    // 1. Count m_i for current cycle_len.
                    //    Loop through partition using lcm_idx.
                    // 2. If m_i > 0, multiply denom_prod by (cycle_len ^ m_i) * m_i!.
                    // 3. Increment cycle_len, reset m_i, reset lcm_idx.
                    // 4. Repeat until cycle_len > N.
                    // 5. Result += num_val / denom_prod.
                    // 6. Go back to GENERATE to get next partition.
                    
                    // However, we need to process all partitions.
                    // After calculation, we must return to GENERATE.
                    // But wait, GENERATE state will backtrack? No.
                    // GENERATE state loops until all partitions are done.
                    // So after CALCULATE, we go back to GENERATE.
                    // But we need to ensure GENERATE continues from where it left off.
                    // GENERATE logic pops the last part and tries smaller.
                    // So we need to do that before returning to GENERATE.
                    
                    // Let's refine the flow:
                    // CHECK_LCM -> (Valid) -> CALCULATE.
                    // CALCULATE computes weight, adds to result.
                    // Then CALCULATE must trigger the backtrack for the next partition.
                    // Or, CALCULATE transitions to a temporary state (e.g. PRE_GENERATE) that does the pop.
                    // Or, CALCULATE does the pop itself and goes to GENERATE.
                    // Let's make CALCULATE do the pop logic at the end.
                    
                    // Calculation Logic Step-by-step:
                    // We need registers for loop counters.
                    // Let's use 'cycle_len' (1..N), 'm_i', 'lcm_idx', 'denom_prod'.
                    // Also a temp variable for term calculation.
                    
                    // Sub-state for calculation:
                    // We can do it in one cycle or multiple.
                    // Given latency 1000 cycles, we have plenty of time.
                    // Let's do it in multiple cycles for simplicity.
                    
                    // Step A: Count m_i for current cycle_len.
                    // We need to iterate partition array.
                    // We can do this in a loop inside the always block.
                    // Since partition size is small (<7), we can do it in one cycle.
                    // Let's iterate lcm_idx from 0 to depth-1.
                    // Accumulate m_i.
                    
                    // Step B: Compute term = (cycle_len ^ m_i) * factorial(m_i)
                    // Step C: denom_prod *= term
                    // Step D: cycle_len++, repeat if cycle_len <= N.
                    // Step E: result += num_val / denom_prod
                    // Step F: Backtrack and Go to GENERATE.
                    
                    // Let's break CALCULATE into sub-states or do it sequentially.
                    // To avoid creating too many states, we can use the CALCULATE state for a few cycles.
                    // Let's use 'calc_stage' register.
                    
                    // Since we need to write compact code, let's do:
                    // 1. Count m_i (one cycle)
                    // 2. Compute term (one cycle)
                    // 3. Accumulate (one cycle)
                    // 4. Loop (cycle_len) - controlled by state transition.
                    // 5. Add to result (one cycle)
                    // 6. Backtrack and return to GENERATE (one cycle)
                    
                    // But to keep it simple, we can do:
                    // When entering CALCULATE:
                    //   Compute denominator.
                    //   We need to iterate.
                    //   Let's use a 'calc_done' flag.
                    //   
                    // Let's implement a loop inside CALCULATE using 'cycle_len' and 'lcm_idx'.
                    
                    // We need to calculate the denominator first.
                    // We can use 'lcm_idx' to iterate partition.
                    // We need to find m_i for each length i.
                    // This is complicated to do without nested loops.
                    // Given the small size, let's do:
                    // 'term' accumulates the product for current length.
                    // 'denom_prod' accumulates total denominator.
                    
                    // Wait, we need to be careful.
                    // We must iterate cycle_len from 1 to N.
                    // For each cycle_len, we scan partition to count occurrences.
                    // 
                    // Let's add a 'calc_phase' register.
                    // 0: Scan partition for current cycle_len, accumulate m_i.
                    // 1: Compute (cycle_len ^ m_i) * m_i!, multiply to denom_prod.
                    // 2: Increment cycle_len. If <= N, go to 0. Else go to 3.
                    // 3: Compute result += num_val / denom_prod.
                    // 4: Backtrack & Transition to GENERATE.
                    
                    case (calc_phase)
                        0: begin
                            // Scan partition for current cycle_len
                            if (lcm_idx < depth) begin
                                if (partition[lcm_idx] == cycle_len) begin
                                    m_i <= m_i + 1;
                                end
                                lcm_idx <= lcm_idx + 1;
                            end else begin
                                // Done scanning
                                lcm_idx <= 0; // Reset for next use if needed (though we don't need it)
                                calc_phase <= 1;
                            end
                        end
                        1: begin
                            // Compute term
                            if (m_i > 0) begin
                                // Compute cycle_len ^ m_i
                                // Since m_i is small (<=7), we can use shift/add or just loop.
                                // Let's use a temp power variable.
                                power_val <= 1;
                                // We need to multiply by m_i! as well.
                                fact_m_i <= factorials[m_i];
                                // We will calculate power in next step.
                                calc_phase <= 11; // Sub-step for power
                            end else begin
                                // No cycles of this length, skip
                                calc_phase <= 2;
                            end
                        end
                        11: begin // Power loop
                            if (m_i > 0) begin
                                // Loop m_i times: power_val = power_val * cycle_len
                                // But we need a counter for the loop.
                                // Let's use 'temp_count' or reuse 'lcm_idx'.
                                // Let's reuse 'm_i' as counter? No, we need original m_i for factorial.
                                // We can copy m_i to a temp counter.
                                // Let's use 'temp_count' register.
                                if (power_calc_count == 0) begin
                                    power_calc_count <= m_i;
                                    power_val <= 1;
                                end else if (power_calc_count > 0) begin
                                    power_val <= power_val * cycle_len;
                                    power_calc_count <= power_calc_count - 1;
                                end else begin
                                    // Power done
                                    // Now multiply by factorial
                                    term <= power_val * fact_m_i;
                                    calc_phase <= 12;
                                end
                            end else begin
                                calc_phase <= 2;
                            end
                        end
                        12: begin // Accumulate term
                            denom_prod <= denom_prod * term;
                            calc_phase <= 2;
                        end
                        2: begin // Increment cycle_len
                            if (cycle_len < N) begin // Check strict less than N? No, inclusive 1..N
                                // Wait, if N=7, lengths go up to 7.
                                if (cycle_len < N) begin // Actually, partition elements can be up to N.
                                    cycle_len <= cycle_len + 1;
                                    m_i <= 0;
                                    // lcm_idx already 0
                                    calc_phase <= 0;
                                end else begin
                                    // Finished all lengths
                                    calc_phase <= 3;
                                end
                            end else begin
                                // If N=1, cycle_len=1. 1 < 1 is false. Goes to 3 immediately.
                                // Correct.
                                calc_phase <= 3;
                            end
                        end
                        3: begin // Final calculation
                            // Result += num_val / denom_prod
                            // But careful: denom_prod might be 1 if we didn't update (e.g. no cycles).
                            // Actually we initialized denom_prod=1.
                            // But we updated it in step 12.
                            // Wait, if m_i=0 for all lengths, denom_prod stays 1.
                            // But N>0, partition must have sum N. So at least one m_i > 0.
                            
                            result <= result + (num_val / denom_prod);
                            calc_phase <= 4;
                        end
                        4: begin // Backtrack to get next partition
                            // We are done with this valid partition.
                            // We need to go to GENERATE to find the next one.
                            // Logic: Pop the last part of current partition and try smaller.
                            state <= GENERATE_PARTITIONS;
                            calc_phase <= 0; // Reset for next time
                            
                            if (depth > 0) begin
                                depth <= depth - 1;
                                remaining <= partition[depth-1];
                                current_try[depth-1] <= partition[depth-1] - 1;
                            end else begin
                                state <= DONE;
                            end
                        end
                    endcase
                end

                DONE: begin
                    done <= 1;
                end

                default: state <= IDLE;
            endcase
        end
    end
    
    // Helper registers for CALCULATE state
    reg [2:0] calc_phase;
    reg [31:0] power_val_reg; // Used for power calculation
    reg [2:0] power_calc_count;
    reg [31:0] term_reg;
    
    // Mapping local names to registers for the CALCULATE block
    // Note: We need to be careful with name clashes if we use same registers for different purposes.
    // Here, we define specific registers for CALCULATE state logic.
    // We can reuse some if we are careful.
    
    // Redefining the registers used in CALCULATE block explicitly to ensure they exist.
    reg [31:0] denom_prod;
    reg [31:0] num_val;
    reg [3:0] cycle_len;
    reg [2:0] m_i;
    reg [31:0] power_val;
    reg [31:0] fact_m_i;
    reg [31:0] term;
    
    // Also need 'current_try' array for GENERATE logic
    reg [3:0] current_try [0:7]; 
    reg backtrack; // Not strictly needed with current_try logic, but good for state indication
    
    // Re-initialize 'current_try' in IDLE to avoid garbage
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < 8; j = j + 1) current_try[j] <= 0;
            backtrack <= 0;
            calc_phase <= 0;
        end
    end

endmodule
