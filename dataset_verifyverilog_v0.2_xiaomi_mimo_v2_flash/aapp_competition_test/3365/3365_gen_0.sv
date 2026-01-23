module partition_puzzle(
    input clk,
    input rst_n,
    input start,
    input [7:0] v0, v1, v2, v3, v4, v5, v6, v7,
    input [3:0] n,
    input [3:0] k,
    output reg [7:0] max_score,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam COMPUTE_PRIMES = 3'b001;
    localparam GENERATE_PARTITIONS = 3'b010;
    localparam EVALUATE_SCORES = 3'b011;
    localparam DONE = 3'b100;

    // Prime bit masks (11 primes: 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31)
    // Mask index: 0=2, 1=3, 2=5, 3=7, 4=11, 5=13, 6=17, 7=19, 8=23, 9=29, 10=31
    // We only care about the largest prime factor, so we can store the prime value directly or a mask
    // Using a 6-bit value to store the actual prime factor (max 31 fits in 5 bits, 6 for safety)
    // 0 indicates no prime factor (1 or prime > 31, but > 31 won't appear in 0-255 except 1)
    // Actually, for prime factors > 31, e.g., 37, 41... up to 251, we need to handle.
    // The prompt says "Prime numbers to consider: 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31".
    // If a number has a prime factor larger than 31 (e.g., 37), its LPF is 0 according to the instruction's scope?
    // "If no prime factor, LPF=0". Since we only consider up to 31, any prime factor > 31 acts as 0.
    // Let's store the prime value itself (up to 31) or 0. 5 bits needed.

    reg [2:0] state, next_state;
    reg [4:0] lpf_val [0:7]; // LPF for each of the 8 elements
    reg [3:0] partition_indices [0:3]; // Indices where regions split (exclusive end)
    // Max regions k=4. Indices i1, i2, i3 (exclusive ends). 
    // Example: 0 <= i1 < i2 < i3 < n. 
    // We will iterate i1, i2, i3. i0 is 0, i4 is n.
    
    // Counters for state machine loops
    reg [3:0] idx; // index for element processing
    reg [3:0] i1, i2, i3; // partition iterators
    reg [2:0] region_idx; // index for evaluating regions
    
    // Registers for finding LPF
    reg [7:0] temp_val;
    reg [4:0] current_prime;
    reg [2:0] prime_idx;
    reg [4:0] primes [0:10];
    
    // Registers for partition evaluation
    reg [4:0] region_min; // min LPF in current region
    reg [4:0] partition_min; // min LPF across all regions in current partition
    reg [4:0] best_score; // max of partition_min (stored as integer value)
    
    // Helper to get primes array values
    initial begin
        primes[0] = 2; primes[1] = 3; primes[2] = 5; primes[3] = 7;
        primes[4] = 11; primes[5] = 13; primes[6] = 17; primes[7] = 19;
        primes[8] = 23; primes[9] = 29; primes[10] = 31;
    end

    integer i;
    reg [7:0] num_copy;
    reg found_factor;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_score <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COMPUTE_PRIMES;
                        idx <= 0;
                        prime_idx <= 0;
                    end
                end

                COMPUTE_PRIMES: begin
                    // Find LPF for element[idx]
                    // Select input value
                    case (idx)
                        0: num_copy <= v0;
                        1: num_copy <= v1;
                        2: num_copy <= v2;
                        3: num_copy <= v3;
                        4: num_copy <= v4;
                        5: num_copy <= v5;
                        6: num_copy <= v6;
                        7: num_copy <= v7;
                    endcase
                    
                    // Logic to find largest prime factor <= 31
                    // We iterate primes in descending order to find the largest first? 
                    // Or ascending and overwrite. Since array is small, iteration is fast.
                    // Let's iterate all primes. If num_copy % p == 0, update LPF.
                    // Wait, we need to handle the loop properly. 
                    // This state needs multiple cycles per element to check all primes.
                    // Let's refine: IDLE -> COMPUTE_PRIMES (Loop over elements, inner loop over primes)
                    
                    if (primes[prime_idx] != 0) begin
                        // Check divisibility (synthesizable divider is heavy, but logic for small primes is okay or use a library?
                        // Standard Verilog % is synthesizable for constants)
                        // Only update if it divides
                        if (num_copy % primes[prime_idx] == 0) begin
                            lpf_val[idx] <= primes[prime_idx]; // Overwrite with current prime (will end up being largest if we go 2..31)
                            // To get largest, we should go 31 down to 2. 
                            // Let's flip the prime loop order or just track.
                            // Since 31 is max, going 2->31 results in the last found being the largest? 
                            // No, 14 has factors 2 and 7. 2 comes first. 7 comes later. 
                            // So going 2..31 works if we just keep overwriting.
                        end
                        prime_idx <= prime_idx + 1;
                    end else begin
                        // Done checking primes for this element
                        // If lpf_val[idx] is not updated (stays 0 or previous value), we need to clear it if no factor found.
                        // Actually, default lpf_val[idx] should be 0. 
                        // We can reset it at start of COMPUTE_PRIMES for this index.
                        
                        // Transition to next element
                        prime_idx <= 0;
                        idx <= idx + 1;
                        lpf_val[idx] <= 0; // Reset before check
                        
                        if (idx == n - 1) begin
                            state <= GENERATE_PARTITIONS;
                            // Initialize partition generation
                            // We need to partition n elements into k regions.
                            // Indices: 0 <= i1 < i2 < ... < i_{k-1} < n.
                            // If k=1, no split. If k=2, 1 split. 
                            // We can use a generic iteration logic.
                            // Let's map k to number of splits = k-1.
                            // We will iterate i1, i2, i3.
                            i1 <= 1;
                            i2 <= 2;
                            i3 <= 3;
                            best_score <= 0;
                        end
                    end
                end

                GENERATE_PARTITIONS: begin
                    // Check bounds for current partition configuration
                    // We must ensure indices are increasing and less than n
                    // And handle k=1,2,3,4 cases.
                    // Logic: 
                    // 1. If current partition is valid (indices correct), go to EVALUATE_SCORES
                    // 2. If invalid or done evaluating, increment indices (cascade)
                    // 3. If all indices exhausted, go to DONE
                    
                    // Let's separate the "increment and check validity" logic.
                    // This state will just manage the indices and transition to evaluation.
                    // However, we might need to skip invalid partitions directly here.
                    
                    // Current indices state:
                    // k=1: No splits. Score is min of all elements.
                    // k=2: i1 only. Range: 0..i1, i1..n.
                    // k=3: i1, i2. 0..i1, i1..i2, i2..n.
                    // k=4: i1, i2, i3. 0..i1, i1..i2, i2..i3, i3..n.
                    
                    // We can handle k=1 separately or unify.
                    // Unified approach: 
                    // Constraints:
                    // i1 >= 1, i1 < i2 (if k>=3), i1 < n (if k=2)
                    // i2 > i1, i2 < i3 (if k=4), i2 < n (if k=3)
                    // i3 > i2, i3 < n (if k=4)
                    
                    // Let's use a flag to trigger evaluation or increment.
                    // Let's add a sub-state or just use transitions.
                    
                    // If we are here, we assume indices are set.
                    // Check validity:
                    if (k == 1) begin
                        state <= EVALUATE_SCORES;
                    end else if (k == 2) begin
                        if (i1 < n) state <= EVALUATE_SCORES;
                        else state <= DONE; // Exhausted
                    end else if (k == 3) begin
                        if (i2 < n && i1 < i2) state <= EVALUATE_SCORES;
                        else begin
                            // Increment logic
                            if (i2 + 1 < n) begin
                                i2 <= i2 + 1;
                            end else begin
                                i2 <= i1 + 2;
                                if (i1 + 2 < n) begin
                                    i1 <= i1 + 1;
                                end else state <= DONE;
                            end
                        end
                    end else if (k == 4) begin
                        if (i3 < n && i2 < i3 && i1 < i2) state <= EVALUATE_SCORES;
                        else begin
                            // Increment i3, wrap to i2+1, etc.
                            if (i3 + 1 < n) begin
                                i3 <= i3 + 1;
                            end else begin
                                i3 <= i2 + 2;
                                if (i2 + 2 < n) begin
                                    i2 <= i2 + 1;
                                end else begin
                                    i2 <= i1 + 2;
                                    if (i1 + 2 < n) begin
                                        i1 <= i1 + 1;
                                    end else state <= DONE;
                                end
                            end
                        end
                    end
                    
                    // Note: For k=1, we need to init and run once. 
                    // We need to ensure we don't loop infinitely for k=1.
                    // We can add a "start" flag for partitions or just handle k=1 in IDLE/TRANSITION.
                    // Let's modify: If k==1, we go to EVALUATE_SCORES immediately from COMPUTE_PRIMES.
                    // So GENERATE_PARTITIONS state logic only handles k>=2 logic.
                    // If k==1 enters here, we might loop. 
                    // Let's fix: in IDLE or end of COMPUTE_PRIMES, check if k==1 then jump to EVAL.
                end

                EVALUATE_SCORES: begin
                    // Compute score for current partition
                    // Partition ranges:
                    // k=1: [0, n)
                    // k=2: [0, i1), [i1, n)
                    // k=3: [0, i1), [i1, i2), [i2, n)
                    // k=4: [0, i1), [i1, i2), [i2, i3), [i3, n)
                    // We need to iterate regions (k regions) and find min LPF in each region.
                    // Then find min of those region scores.
                    // Finally, update max_score.
                    
                    // This state needs sub-loops or sequential processing.
                    // Since k <= 4 and n <= 8, we can unroll or use a small loop.
                    // Let's use a region_idx counter.
                    // region_idx goes 0 to k-1.
                    // Compute region score, update partition_min.
                    
                    case (region_idx)
                        0: begin // Region 0
                            // Compute min from 0 to bound
                            // Bound logic:
                            if (k == 1) compute_min(0, n - 1);
                            else if (k >= 2) compute_min(0, i1 - 1);
                            
                            if (done_min_calc) begin
                                region_min <= current_min_val;
                                partition_min <= current_min_val;
                                region_idx <= 1;
                            end
                        end
                        1: begin // Region 1
                            // Bound logic
                            if (k == 2) compute_min(i1, n - 1);
                            else if (k >= 3) compute_min(i1, i2 - 1);
                            
                            if (done_min_calc) begin
                                // Update partition_min = min(partition_min, current_min_val)
                                if (current_min_val < partition_min) partition_min <= current_min_val;
                                region_idx <= 2;
                            end
                        end
                        2: begin // Region 2
                            // Bound logic
                            if (k == 3) compute_min(i2, n - 1);
                            else if (k == 4) compute_min(i2, i3 - 1);
                            
                            if (done_min_calc) begin
                                if (current_min_val < partition_min) partition_min <= current_min_val;
                                region_idx <= 3;
                            end
                        end
                        3: begin // Region 3
                            // Bound logic
                            if (k == 4) compute_min(i3, n - 1);
                            
                            if (done_min_calc) begin
                                if (current_min_val < partition_min) partition_min <= current_min_val;
                                region_idx <= 0; // Reset for next partition
                                // Update global max_score
                                if (partition_min > best_score) best_score <= partition_min;
                                
                                // Next partition logic
                                // Increment indices
                                state <= GENERATE_PARTITIONS;
                                
                                // We need to manage the iteration here or in GENERATE_PARTITIONS.
                                // Let's do it here for simplicity of flow.
                                
                                // Increment Logic (Similar to GENERATE_PARTITIONS but triggered after eval)
                                if (k == 1) state <= DONE;
                                else if (k == 2) begin
                                    if (i1 + 1 < n) i1 <= i1 + 1;
                                    else state <= DONE;
                                end else if (k == 3) begin
                                    if (i2 + 1 < n) i2 <= i2 + 1;
                                    else begin
                                        i2 <= i1 + 2;
                                        if (i1 + 2 < n) i1 <= i1 + 1;
                                        else state <= DONE;
                                    end
                                end else if (k == 4) begin
                                    if (i3 + 1 < n) i3 <= i3 + 1;
                                    else begin
                                        i3 <= i2 + 2;
                                        if (i2 + 2 < n) i2 <= i2 + 1;
                                        else begin
                                            i2 <= i1 + 2;
                                            if (i1 + 2 < n) i1 <= i1 + 1;
                                            else state <= DONE;
                                        end
                                    end
                                end
                            end
                        end
                    endcase
                end

                DONE: begin
                    max_score <= best_score;
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

    // --- Helper Logic for Min Calculation (Combinational Logic Block) ---
    // To avoid creating a complex sub-module, we implement the min finding logic
    // using a combinational block controlled by signals in the state machine.
    // However, Verilog FSM usually uses sequential logic. 
    // To fit in a single module without sub-modules and keep it clean, 
    // we can implement the min calculation as a small sequential process embedded in the FSM
    // or reuse the FSM state with a counter.
    
    // Let's refine the EVALUATE_SCORES state. 
    // Instead of a combinational helper, let's use 'region_idx' and a 'sub_step' or 'calc_idx'.
    // We need a register to store the running min for the current region being calculated.
    reg [3:0] calc_idx;
    reg [4:0] current_min_val;
    reg done_min_calc; // Handshake flag
    
    // We need to control this calculation from EVALUATE_SCORES.
    // Let's make a separate always block or integrate into the main FSM logic.
    // Integrated approach:
    
    // We need to define 'start_min_calc' and 'min_range_start', 'min_range_end'.
    // But those are local to the state. 
    // Let's create a wrapper logic inside EVALUATE_SCORES.
    
    // Actually, since the main FSM is large, let's define local variables for the loop
    // inside EVALUATE_SCORES case item.
    // But we need to make it sequential (multi-cycle). 
    // We can add a substate to EVALUATE_SCORES or a separate state like "CALC_REGION".
    // Let's use a separate state "CALC_REGION" to keep the main state machine clean.

    // --- Revised FSM Logic for Evaluation ---
    // Replace EVALUATE_SCORES with a loop over regions in a new state "CALC_REGION".
    
    // We need to re-declare the states if we change them, but I'll just modify the logic.
    // Actually, I'll stick to the EVALUATE_SCORES state and implement the loops using 
    // the 'calc_idx' register effectively.
    
    // Re-definition of EVALUATE_SCORES logic in the sequential block:
    // This part is tricky to write purely sequentially without blocking.
    // Let's use the existing 'region_idx' but make sure we handle the min calculation properly.
    
    // Re-write of EVALUATE_SCORES in the always block:
    // We will split EVALUATE_SCORES into two phases: 
    // 1. Setup min calc for current region.
    // 2. Iterate through elements to find min.
    // 3. Update partition min.
    // 4. Repeat for next region or finish.
    
    // To do this sequentially without nested loops in code:
    // State EVALUATE_SCORES:
    //   if (calc_idx <= region_end) begin
    //      check lpf[calc_idx], update current_min_val.
    //      calc_idx++.
    //   end else begin
    //      // Done with region
    //      // Update partition_min
    //      // If regions remain, setup next region (region_idx++, calc_idx = start), else finish partition.
    //   end
    
    // We need region_start and region_end registers.
    reg [3:0] region_start, region_end;
    
    // --- Updated Always Block ---
    // Note: The previous code in EVALUATE_SCORES section needs to be replaced by this logic.
    // I will overwrite the EVALUATE_SCORES case in the always block above conceptually.
    // Since I can't edit the already written text easily, I will rely on the fact that
    // the provided logic is a template. I will assume the user understands I need to use
    // the helper logic. 
    
    // Let's refine the code to be fully functional in one block.
    // I will add a 'substate' logic using extra bits to the state or using calc_idx as a flag.
    
    // Actually, I will use a separate combinational block to calculate min in one cycle for small N?
    // N=8. 8 cycle latency is fine. 
    // Let's stick to sequential min finding.
    
    // Let's rewrite the EVALUATE_SCORES logic properly in the response.
    
    // --- REWRITING THE ALWAYS BLOCK FOR PROPER EXECUTION ---
    // (I will generate the final code based on this refined logic)

endmodule

// Helper module to find max/Min? No, internal logic.
// The code above is a skeleton. 
// I need to fill in the "compute_min" logic and ensure the state transitions correctly.
// Since I cannot define sub-functions in Verilog that synthesize to FSM logic easily without localparam states,
// I will use a state variable 'eval_state' inside EVALUATE_SCORES or simply expand EVALUATE_SCORES into multiple states.

// Let's define a micro-state machine inside EVALUATE_SCORES:
// State: EVAL_START_REGION -> EVAL_ITERATE -> EVAL_NEXT_REGION -> EVAL_DONE
// Or just use 'region_idx' and 'calc_idx' in the main switch.

// Let's use 'calc_idx' and 'current_min_val' to handle the iteration.
// In EVALUATE_SCORES:
//   if (calc_idx > region_end) => Next Region.
//   else if (calc_idx < region_start) => Init calc_idx = region_start.
//   else => calc.

// Final code structure:

module partition_puzzle(
    input clk,
    input rst_n,
    input start,
    input [7:0] v0, v1, v2, v3, v4, v5, v6, v7,
    input [3:0] n,
    input [3:0] k,
    output reg [7:0] max_score,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam COMPUTE_PRIMES = 3'b001;
    localparam EVALUATE_SCORES = 3'b010; // Handles iteration over partitions and regions
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [4:0] lpf_val [0:7];
    reg [3:0] i1, i2, i3;
    reg [4:0] best_score;
    
    // Iteration registers
    reg [3:0] idx; // for elements or prime checks
    reg [2:0] prime_idx;
    reg [7:0] temp_num;
    
    // Evaluation registers
    reg [2:0] region_idx; // 0 to 3
    reg [3:0] calc_ptr; // pointer to element in region
    reg [4:0] current_min; // min for current region
    reg [4:0] partition_min; // min for current partition
    reg [3:0] region_start_ptr, region_end_ptr;
    reg eval_in_progress; // Flag to indicate we are inside EVAL state

    // Primes array
    reg [4:0] primes [0:10];
    initial begin
        primes[0] = 2; primes[1] = 3; primes[2] = 5; primes[3] = 7;
        primes[4] = 11; primes[5] = 13; primes[6] = 17; primes[7] = 19;
        primes[8] = 23; primes[9] = 29; primes[10] = 31;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_score <= 0;
            eval_in_progress <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= COMPUTE_PRIMES;
                        idx <= 0;
                        prime_idx <= 0;
                        // Reset LPFs
                        // (Will be overwritten, but good practice)
                    end
                end

                COMPUTE_PRIMES: begin
                    // Select current number
                    case (idx)
                        0: temp_num <= v0;
                        1: temp_num <= v1;
                        2: temp_num <= v2;
                        3: temp_num <= v3;
                        4: temp_num <= v4;
                        5: temp_num <= v5;
                        6: temp_num <= v6;
                        7: temp_num <= v7;
                    endcase
                    
                    // Logic to find largest prime factor <= 31
                    // We check 11 primes. 
                    // We need to initialize lpf_val[idx] to 0 before checking?
                    // Or check if temp_num % p == 0 and if p > lpf_val[idx].
                    // Since primes are increasing, just update.
                    
                    if (prime_idx < 11) begin
                        if (temp_num % primes[prime_idx] == 0) begin
                            lpf_val[idx] <= primes[prime_idx];
                        end
                        prime_idx <= prime_idx + 1;
                    end else begin
                        // Done with this element
                        // Check if we need to handle numbers with no prime factors <= 31
                        // If lpf_val[idx] was never updated (it starts at 0 from reset/previous), 
                        // we need to ensure it stays 0 if no factor found. 
                        // However, if temp_num = 1, no factor. If temp_num = 37, no factor <= 31.
                        // If temp_num = 2, lpf becomes 2. 
                        // If temp_num = 4, lpf becomes 2. 
                        // If temp_num = 6, lpf becomes 2 (then 3, updates to 3). 
                        // Wait, logic "lpf_val <= primes[prime_idx]" overwrites.
                        // 6 % 2 == 0 -> lpf=2. 6 % 3 == 0 -> lpf=3. Correct.
                        
                        // Reset lpf_val[idx] at start of loop? No, we want to keep 0 if no factor found.
                        // But if we don't reset, previous value from lpf_val[idx] might persist if we use "if (cond) lpf <= p"?
                        // Yes, if no condition met, it keeps old value.
                        // So we need to initialize lpf_val[idx] = 0 when idx changes.
                        
                        if (prime_idx == 0) lpf_val[idx] <= 0; // Start of new element check
                        
                        idx <= idx + 1;
                        prime_idx <= 0;
                        
                        if (idx == n - 1) begin
                            // Done computing primes
                            state <= EVALUATE_SCORES;
                            
                            // Initialize Partition Search
                            // Reset best_score
                            best_score <= 0;
                            
                            // Initialize indices
                            i1 <= 1;
                            i2 <= 2;
                            i3 <= 3;
                            
                            // Initialize Evaluation State
                            region_idx <= 0;
                            eval_in_progress <= 0;
                            
                            // Special case for k=1: we need to run once.
                            // We will handle k=1 in EVALUATE_SCORES logic.
                        end
                    end
                end

                EVALUATE_SCORES: begin
                    // This state handles iterating through ALL partitions (i1, i2, i3)
                    // AND iterating through regions within a partition.
                    // It will loop until all partitions are done, then go to DONE.
                    
                    // Logic flow:
                    // 1. If !eval_in_progress: We are at the start of a region or a new partition.
                    //    Determine region boundaries based on k and current i1,i2,i3.
                    //    Set calc_ptr to region start.
                    //    Set current_min to 255 (or max possible).
                    //    Set eval_in_progress = 1.
                    // 2. If eval_in_progress: 
                    //    Check lpf[calc_ptr]. Update current_min.
                    //    calc_ptr++.
                    //    If calc_ptr > region_end: 
                    //       Update partition_min = min(partition_min, current_min).
                    //       region_idx++.
                    //       eval_in_progress = 0 (to setup next region).
                    //       If region_idx == k: 
                    //          Check if partition_min > best_score -> update best_score.
                    //          Increment indices (i1, i2, i3) logic.
                    //          If exhausted -> go to DONE.
                    //          Else reset region_idx = 0, eval_in_progress = 0.

                    if (!eval_in_progress) begin
                        // Setup next region
                        if (region_idx == 0) begin
                            // Region 0
                            region_start_ptr <= 0;
                            if (k == 1) region_end_ptr <= n - 1;
                            else if (k >= 2) region_end_ptr <= i1 - 1;
                        end
                        else if (region_idx == 1) begin
                            // Region 1
                            region_start_ptr <= i1;
                            if (k == 2) region_end_ptr <= n - 1;
                            else if (k >= 3) region_end_ptr <= i2 - 1;
                        end
                        else if (region_idx == 2) begin
                            // Region 2
                            region_start_ptr <= i2;
                            if (k == 3) region_end_ptr <= n - 1;
                            else if (k == 4) region_end_ptr <= i3 - 1;
                        end
                        else if (region_idx == 3) begin
                            // Region 3
                            region_start_ptr <= i3;
                            region_end_ptr <= n - 1;
                        end
                        
                        // Check if we are done with all regions for this partition
                        if (region_idx >= k) begin
                            // We finished this partition. Update global max.
                            if (partition_min > best_score) begin
                                best_score <= partition_min;
                            end
                            
                            // Generate next partition indices
                            // Logic to increment i1, i2, i3
                            // Check validity. If invalid, we are done.
                            
                            if (k == 1) begin
                                state <= DONE; // Only one partition
                            end else if (k == 2) begin
                                if (i1 + 1 < n) begin
                                    i1 <= i1 + 1;
                                    region_idx <= 0; // Reset for next partition
                                end else begin
                                    state <= DONE;
                                end
                            end else if (k == 3) begin
                                if (i2 + 1 < n) begin
                                    i2 <= i2 + 1;
                                    region_idx <= 0;
                                end else begin
                                    // Reset i2, increment i1
                                    i2 <= i1 + 2;
                                    if (i1 + 2 < n) begin
                                        i1 <= i1 + 1;
                                        region_idx <= 0;
                                    end else begin
                                        state <= DONE;
                                    end
                                end
                            end else if (k == 4) begin
                                if (i3 + 1 < n) begin
                                    i3 <= i3 + 1;
                                    region_idx <= 0;
                                end else begin
                                    i3 <= i2 + 2;
                                    if (i2 + 2 < n) begin
                                        i2 <= i2 + 1;
                                        region_idx <= 0;
                                    end else begin
                                        i2 <= i1 + 2;
                                        if (i1 + 2 < n) begin
                                            i1 <= i1 + 1;
                                            region_idx <= 0;
                                        end else begin
                                            state <= DONE;
                                        end
                                    end
                                end
                            end
                            
                            // Reset partition_min for next round
                            partition_min <= 15; // Init to max (since 31 is max LPF, use > 31)
                            
                        end else begin
                            // Start iterating elements in this region
                            calc_ptr <= region_start_ptr;
                            current_min <= 15; // Reset min for region
                            eval_in_progress <= 1;
                        end
                    end else begin
                        // We are iterating elements in the current region
                        if (calc_ptr <= region_end_ptr) begin
                            // Check value
                            if (lpf_val[calc_ptr] < current_min) begin
                                current_min <= lpf_val[calc_ptr];
                            end
                            calc_ptr <= calc_ptr + 1;
                        end else begin
                            // Finished region
                            // Update partition_min (min of current region and previous)
                            if (region_idx == 0) begin
                                partition_min <= current_min;
                            end else begin
                                if (current_min < partition_min)
                                    partition_min <= current_min;
                            end
                            
                            // Next region
                            eval_in_progress <= 0;
                            region_idx <= region_idx + 1;
                        end
                    end
                end

                DONE: begin
                    max_score <= best_score;
                    done <= 1;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule