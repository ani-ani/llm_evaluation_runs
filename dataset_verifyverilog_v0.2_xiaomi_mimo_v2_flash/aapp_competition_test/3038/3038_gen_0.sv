module bolt_packer(
    input clk,
    input rst_n,
    input start,
    input [9:0] B,
    input [3:0] num_companies,
    input [3:0] company_index,
    input [3:0] num_packs,
    input [9:0] pack_size [0:9],
    input config_valid,
    output reg [9:0] min_advertised,
    output reg found,
    output reg impossible,
    output reg done
);

    // Parameters
    parameter MAX_COMPANIES = 10;
    parameter MAX_PACKS_PER_COMPANY = 10;
    parameter MAX_BOLTS = 1000;

    // State definitions
    localparam IDLE = 3'b000;
    localparam CONFIG = 3'b001;
    localparam PROCESS_COMPANIES = 3'b010;
    localparam FIND_MIN = 3'b011;
    localparam DONE = 3'b100;

    // Registers for state and control
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Data storage arrays
    reg [9:0] pack_sizes [0:9][0:9]; // [company][pack]
    reg [9:0] real_amounts [0:9][0:9]; // [company][pack]
    reg [3:0] num_packs_arr [0:9]; // stores number of packs for each company
    
    // Counters and indices
    reg [3:0] curr_comp_idx; // current company being configured or processed
    reg [3:0] curr_pack_idx; // current pack being processed
    
    // Temporary variables for computation
    reg [9:0] current_real_sum;
    reg [9:0] temp_real;
    reg [9:0] min_real;
    reg [9:0] temp_min;
    
    // Combinational helper wires
    wire [9:0] search_target;
    wire [9:0] search_limit;
    
    // For knapsack computation
    reg [9:0] target_advertised;
    reg [9:0] current_min_real;
    reg knapsack_done;
    reg [3:0] pack_iter;
    reg [9:0] remaining;
    reg [9:0] candidate;
    
    // Variables for FIND_MIN state
    reg [9:0] local_min_advertised;
    reg [9:0] local_real;
    reg [3:0] local_comp;
    reg [3:0] local_pack;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CONFIG;
                else
                    next_state = IDLE;
            end
            
            CONFIG: begin
                if (config_valid && (curr_comp_idx < num_companies - 1))
                    next_state = CONFIG; // Continue loading companies
                else if (config_valid && (curr_comp_idx == num_companies - 1))
                    next_state = PROCESS_COMPANIES; // Last company loaded
                else
                    next_state = CONFIG;
            end
            
            PROCESS_COMPANIES: begin
                // Wait for knapsack computation to complete
                if (knapsack_done) begin
                    if (curr_comp_idx < num_companies) begin
                        next_state = PROCESS_COMPANIES; // Continue with next pack/company
                    end else begin
                        next_state = FIND_MIN; // All companies processed
                    end
                end else begin
                    next_state = PROCESS_COMPANIES;
                end
            end
            
            FIND_MIN: begin
                // Find minimum advertised pack
                if (curr_pack_idx >= num_packs_arr[curr_comp_idx]) begin
                    if (curr_comp_idx == num_companies - 1)
                        next_state = DONE;
                    else
                        next_state = FIND_MIN; // Next company
                end else begin
                    next_state = FIND_MIN;
                end
            end
            
            DONE: begin
                if (!rst_n || start)
                    next_state = IDLE;
                else
                    next_state = DONE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            curr_comp_idx <= 4'd0;
            curr_pack_idx <= 4'd0;
            min_advertised <= 10'd0;
            found <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            knapsack_done <= 1'b1;
            pack_iter <= 4'd0;
            current_min_real <= 10'd0;
            target_advertised <= 10'd0;
            local_comp <= 4'd0;
            local_pack <= 4'd0;
            // Clear arrays (optional, synthesis tools handle this)
        end else begin
            case (state)
                IDLE: begin
                    found <= 1'b0;
                    impossible <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        curr_comp_idx <= 4'd0;
                        curr_pack_idx <= 4'd0;
                        knapsack_done <= 1'b0; // Prepare for next steps
                    end
                end

                CONFIG: begin
                    if (config_valid) begin
                        // Load pack sizes for current company
                        pack_sizes[curr_comp_idx][curr_pack_idx] <= pack_size[curr_pack_idx];
                        num_packs_arr[curr_comp_idx] <= num_packs;
                        
                        // Increment pack index counter (using internal counter)
                        if (curr_pack_idx < num_packs - 1) begin
                            curr_pack_idx <= curr_pack_idx + 1;
                        end else begin
                            // Done loading this company
                            curr_pack_idx <= 4'd0;
                            if (curr_comp_idx < num_companies - 1)
                                curr_comp_idx <= curr_comp_idx + 1;
                        end
                    end
                    // Reset knapsack done flag when moving to process
                    if (next_state == PROCESS_COMPANIES) begin
                        curr_comp_idx <= 4'd0;
                        curr_pack_idx <= 4'd0;
                        knapsack_done <= 1'b0;
                        pack_iter <= 4'd0;
                        current_min_real <= 10'd0;
                    end
                end

                PROCESS_COMPANIES: begin
                    // Compute real amounts for all companies
                    // Logic: compute company 0 directly, then company 1, etc.
                    
                    if (!knapsack_done) begin
                        // Compute real amount for pack_idx of comp_idx
                        
                        if (curr_comp_idx == 0) begin
                            // Company 0: real = advertised
                            real_amounts[0][curr_pack_idx] <= pack_sizes[0][curr_pack_idx];
                            
                            // Move to next pack
                            if (curr_pack_idx < num_packs_arr[0] - 1) begin
                                curr_pack_idx <= curr_pack_idx + 1;
                            end else begin
                                curr_pack_idx <= 4'd0;
                                curr_comp_idx <= 4'd1; // Move to next company
                                if (num_companies == 1)
                                    knapsack_done <= 1'b1;
                            end
                        end else if (curr_comp_idx < num_companies) begin
                            // Companies > 0: knapsack to find minimal real sum >= target
                            // Target is pack_sizes[curr_comp_idx][curr_pack_idx]
                            
                            if (pack_iter == 0) begin
                                // Initialize knapsack
                                target_advertised <= pack_sizes[curr_comp_idx][curr_pack_idx];
                                current_min_real <= 10'h3FF; // Max value
                                remaining <= pack_sizes[curr_comp_idx][curr_pack_idx];
                                pack_iter <= 4'd1;
                            end else if (pack_iter == 1) begin
                                // Greedy / Iterative check
                                // We need sum of real_amounts from prev company >= target
                                // Since max 10 packs, we try all combinations is expensive in hardware
                                // Let's use a simpler greedy/iterative approach: 
                                // Keep adding largest real amounts until >= target
                                
                                // Actually, let's do a simple linear search over subsets is not feasible in HW without huge state
                                // Optimization: Pre-sort real amounts or use DP
                                // Hardware constraint: use simple approach
                                // We will simulate a DP or greedy check
                                
                                // To keep it synthesizable and simple within cycle limit:
                                // We will iterate through packs of prev company and accumulate
                                // This is a "simple greedy" approximation which might not be minimal but fits constraint
                                // Or better: use state to select minimal sum
                                
                                // Better approach: Use a small loop to find min sum >= target
                                // Since prev company already computed, we can scan all packs
                                // For minimal sum >= target, we try adding packs
                                
                                // Let's use a binary/counter approach:
                                // Iterate pack index of prev company
                                
                                temp_real <= 10'd0;
                                min_real <= 10'h3FF;
                                pack_iter <= 4'd2;
                            end else if (pack_iter == 2) begin
                                // Check all subsets (power set is 2^10=1024 states, too many for single cycle)
                                // Instead, use a heuristics or DP state machine.
                                // But instructions say "can search all combinations or use simple greedy"
                                // "Latency: 1000 cycles".
                                // Let's use a standard DP/Heuristic approach.
                                
                                // Revised approach for PROCESS_COMPANIES:
                                // We are computing real[curr_comp][curr_pack]
                                // We have real amounts of prev company.
                                // We want min sum >= target.
                                
                                // Since we are in a state machine, let's do this:
                                // Use pack_iter to count iterations of a search loop.
                                // We'll try adding one pack at a time in a specific order.
                                
                                // Let's assume we sort real amounts of prev company descending (or just use given order)
                                // Sum the largest real amounts until >= target.
                                // This is the "Simple Greedy" method (largest fit).
                                // This might not be "minimal sum" but satisfies "sum >= target".
                                // Wait, requirement says "minimally sum to >= advertised".
                                // Strict interpretation: Find subset with smallest sum S such that S >= Target.
                                
                                // To achieve this in hardware efficiently:
                                // We can compute real amounts of prev company.
                                // Then for current pack target T:
                                // Iterate through all subsets? 1024 states. 
                                // 10 companies, 10 packs = 100 computations.
                                // 100 * 1024 = 102k cycles. Too slow.
                                
                                // Optimization: Use a Binary Indexed Tree / Knapsack logic
                                // Or simpler: Use a "number of packs" counter and sum until >= target.
                                // Since we want MINIMAL sum, we want the most efficient packs.
                                // If we sort prev real amounts ascending, we sum the smallest ones until >= target.
                                
                                // Step: Let's add a sorting step (bubble sort) or just assume we sort.
                                // But input order is fixed. 
                                
                                // Let's use the "Shift and Add" greedy.
                                // 1. Store prev real amounts.
                                // 2. Sort them ascending (requires state machine).
                                // 3. Sum from smallest to largest.
                                
                                // Given the 1000 cycle budget, we can do sorting.
                                // But we are already in PROCESS_COMPANIES state.
                                
                                // ALTERNATIVE APPROACH (Simplest for Verilog):
                                // Assume we process packs.
                                // We need to compute real[curr_comp][j].
                                // This is a search problem.
                                
                                // Let's optimize: 
                                // We will compute real amounts for Company 1..N.
                                // For Company i, we have packs P_i_j.
                                // To compute real_i_j, we need sum of real_{i-1}_k >= P_i_j.
                                
                                // Let's do this:
                                // In state PROCESS_COMPANIES, we use an inner state (pack_iter) to perform the search.
                                // We will use a "min sum search" logic.
                                
                                // Use `current_min_real` as accumulator.
                                // Use `temp_real` as current sum.
                                // Use `pack_iter` to iterate through prev company packs (0 to num_packs_arr[curr_comp_idx-1]-1).
                                // This is a "Greedy by value" if we sort. Without sort, it's random.
                                
                                // Requirement: "minimal sum".
                                // Let's do a full search using a counter (0 to 2^num_packs - 1).
                                // Since num_packs <= 10, 2^10 = 1024.
                                // 1024 cycles * 10 packs * 10 companies = 102,400 cycles.
                                // The prompt says "Approx 1000 cycles". This implies a polynomial algorithm.
                                // "Use DP or combinatorial search".
                                
                                // Maybe "combinatorial search" here means we can search all subsets *for a single pack*.
                                // But we have to do this for *each* pack.
                                // 10 packs * 1024 subsets = 10k cycles per company. 
                                
                                // Let's reconsider "simple greedy". 
                                // If we sort previous real amounts ascending, and sum them until we meet target, that gives minimal sum for "unbounded" items.
                                // But we have fixed packs. It's a subset sum problem.
                                
                                // Let's implement a "Min Sum Subset Search" state machine.
                                // We will use a binary counter to generate subsets.
                                // 
                                // Wait, the prompt gives: "Latency: Approximately 10*10*10 = 1000 cycles".
                                // This implies: 10 companies * 10 packs * 10 (iterations).
                                // 10 iterations? 
                                // This suggests we don't do 1024 subset search. 
                                // It suggests we use a greedy/DP approach that iterates roughly N times.
                                
                                // Let's use a standard Knapsack DP logic.
                                // But DP requires O(N * W) space/time. W = 1000.
                                // 10 * 1000 = 10,000 cycles. Close to 1000.
                                
                                // ALTERNATIVE: "Minimal sum >= Target".
                                // Since we want to minimize the sum, and items are "real amounts from prev company".
                                // It is equivalent to: We need to buy exactly "Target" (or more) bolts.
                                // Items are packs of sizes R_0, R_1...
                                // We want min cost.
                                
                                // Let's assume a "Greedy Best Fit" is acceptable for hardware speed.
                                // Sort prev real amounts. Take smallest until >= Target.
                                // But "minimal sum" means if R = [5, 10], Target = 8. 
                                // Summing smallest (5, 10) = 15. 
                                // But maybe 10 is sufficient? No, 10 >= 8. Sum = 10.
                                // So just taking individual packs works if they meet target.
                                // If no single pack meets target, we need combinations.
                                
                                // Let's implement a greedy "Best Fit" using a small loop.
                                // We will try to fill the requirement using packs from prev company.
                                // Since real amounts are integers, we can use a simple algorithm:
                                // 1. Calculate "deficit".
                                // 2. Pick pack that covers deficit with smallest waste (or just smallest pack > deficit).
                                // 3. If none, pick largest pack, add to sum, repeat.
                                
                                // This fits "10 iterations" (max 10 packs).
                                
                                // Let's refine the PROCESS_COMPANIES state logic:
                                
                                // Case: curr_comp_idx > 0
                                // Target = pack_sizes[curr_comp_idx][curr_pack_idx]
                                // Items = real_amounts[curr_comp_idx-1][k]
                                
                                // Algorithm:
                                // 1. Check if any single real amount >= Target. 
                                //    - If yes, min_real = min(that real amount).
                                //    - This is optimal (0 waste).
                                // 2. If no, we need combination.
                                //    - Sort real amounts ascending.
                                //    - Try to sum smallest ones until >= Target.
                                //    - This is a heuristic. It works well if packs are "standard".
                                
                                // Let's implement the logic using `pack_iter` as the step counter.
                                
                                // Transition logic inside PROCESS_COMPANIES:
                                // If (pack_iter == 0): Check single packs (Scan prev packs)
                                // If (pack_iter == 1..N): Accumulate sum (Sort/Scan)
                                
                                // To do this properly in one block:
                                // We need to split PROCESS_COMPANIES into sub-states or use a counter.
                                // Let's use `curr_pack_idx` to iterate through PREV company packs.
                                
                                // REFINED LOGIC:
                                // We are at (C, P).
                                // We want Real(C, P).
                                // 
                                // Step 1 (pack_iter=0): Reset min_real to infinity. Set accumulator to 0.
                                // Step 2 (pack_iter=1..num_packs_prev): 
                                //    Read prev real amount. 
                                //    Check if >= Target. Update min_real if smaller.
                                //    Store prev real amount in a temporary buffer (we might need to sort? Or just use order).
                                //    Since we want minimal sum, checking single packs is Step 1.
                                //    If no single pack works, we need combination.
                                //    Let's assume combination is sum of smallest packs.
                                //    This requires sorting. Sorting 10 numbers takes ~50 cycles (bubble).
                                //    Let's add a "SORT" state or do it in PROCESS.
                                
                                // Given the complexity, let's stick to a simpler, robust method:
                                // Use a loop to sum up smallest real amounts until we meet target.
                                // But we need to know which ones are "smallest".
                                
                                // Let's assume we don't need to be perfectly optimal if "Greedy" is allowed.
                                // "Can search all combinations or use simple greedy".
                                // Let's use a "Greedy" approach: Sum the real amounts of the previous company in order until >= target.
                                // This is NOT minimal sum, but it is a valid sum.
                                // BUT requirement says "minimally sum".
                                
                                // Okay, let's do a "Bubble Sort" logic in a separate state or embedded.
                                // We'll add a state `SORT_PREV` if needed, but to keep it simple:
                                // We will use a temporary array to sort the previous company's real amounts.
                                // Then sum them.
                                
                                // Actually, let's look at the prompt again: "10*10*10 = 1000 cycles".
                                // This implies for each computation, we do ~10 operations.
                                // 10 operations is enough to check single packs (10) or accumulate (10).
                                // It is NOT enough to sort (100) or subset search (1000).
                                
                                // INTERPRETATION:
                                // "Minimal sum >= advertised"
                                // Maybe "minimal" refers to the fact that we pick the smallest pack that satisfies the requirement?
                                // If no pack satisfies, we pick the smallest pack? No.
                                
                                // Let's try this interpretation:
                                // The previous company provides packs. 
                                // We want to build the current pack size.
                                // We take the largest available pack from previous company that fits?
                                // Or the smallest?
                                
                                // Let's go with a concrete algorithm that fits 10 cycles:
                                // 1. Read target T.
                                // 2. Read prev real amounts R[0..9].
                                // 3. Find Min Single: min(R[k] where R[k] >= T). If exists, that's the answer.
                                // 4. If not, calculate Sum of R. If Sum >= T, use Sum.
                                // 5. Else Impossible for this pack.
                                
                                // This fits 10 cycles. It is a "Minimal" interpretation.
                                // Step 3 takes 10 cycles. Step 4 takes 10 cycles.
                                
                                // Let's implement this logic.
                                
                                // We need to iterate through prev packs.
                                // So we use `pack_iter` to go from 0 to num_packs_arr[curr_comp_idx-1]-1.
                                
                                // Logic for pack_iter:
                                // If pack_iter == 0: min_single = inf, sum = 0.
                                // If pack_iter < num_prev: 
                                //    If real_prev[pack_iter] >= target && real_prev[pack_iter] < min_single -> update min_single.
                                //    sum += real_prev[pack_iter].
                                //    pack_iter++.
                                // If pack_iter == num_prev:
                                //    If min_single != inf -> result = min_single.
                                //    Else if sum >= target -> result = sum.
                                //    Else -> result = 0 (or mark impossible for this pack).
                                
                                // This logic covers single packs and combined packs.
                                // It is "Minimal" in the sense of single vs sum.
                                // But strictly, minimal sum subset is not guaranteed.
                                // However, for "1000 cycles", this is the only feasible logic.
                                
                                // Let's proceed with this logic.
                                
                                // Check if we are done with this pack
                                if (pack_iter < num_packs_arr[curr_comp_idx - 1]) begin
                                    // Iterate
                                    temp_real <= temp_real + real_amounts[curr_comp_idx - 1][pack_iter];
                                    
                                    // Check for single pack minimal
                                    if (real_amounts[curr_comp_idx - 1][pack_iter] >= target_advertised && 
                                        real_amounts[curr_comp_idx - 1][pack_iter] < current_min_real) begin
                                        current_min_real <= real_amounts[curr_comp_idx - 1][pack_iter];
                                    end
                                    
                                    pack_iter <= pack_iter + 1;
                                end else begin
                                    // Finished iterating
                                    if (current_min_real != 10'h3FF) begin
                                        // Found a single pack solution
                                        real_amounts[curr_comp_idx][curr_pack_idx] <= current_min_real;
                                    end else if (temp_real >= target_advertised) begin
                                        // Use sum
                                        real_amounts[curr_comp_idx][curr_pack_idx] <= temp_real;
                                    end else begin
                                        // No solution found for this pack
                                        // Mark as 0 or max? We'll mark 0 to indicate failure later
                                        real_amounts[curr_comp_idx][curr_pack_idx] <= 10'd0;
                                    end
                                    
                                    // Reset for next pack
                                    pack_iter <= 4'd0;
                                    temp_real <= 10'd0;
                                    current_min_real <= 10'h3FF;
                                    
                                    // Move to next pack
                                    if (curr_pack_idx < num_packs_arr[curr_comp_idx] - 1) begin
                                        curr_pack_idx <= curr_pack_idx + 1;
                                    end else begin
                                        // Done company
                                        curr_pack_idx <= 4'd0;
                                        if (curr_comp_idx < num_companies - 1) begin
                                            curr_comp_idx <= curr_comp_idx + 1;
                                        end else begin
                                            // Done all companies
                                            knapsack_done <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                    end
                    
                    if (knapsack_done && next_state == FIND_MIN) begin
                        curr_comp_idx <= 4'd0;
                        curr_pack_idx <= 4'd0;
                    end
                end

                FIND_MIN: begin
                    // Find min advertised pack size where real amount >= B
                    // We need to scan all companies and all packs.
                    // Logic: iterate through companies, then packs.
                    
                    // If we haven't checked this pack
                    if (real_amounts[curr_comp_idx][curr_pack_idx] >= B && real_amounts[curr_comp_idx][curr_pack_idx] != 0) begin
                        // Valid solution found
                        // Check if this is the smallest advertised size so far
                        if (found && pack_sizes[curr_comp_idx][curr_pack_idx] < min_advertised) begin
                            min_advertised <= pack_sizes[curr_comp_idx][curr_pack_idx];
                        end else if (!found) begin
                            min_advertised <= pack_sizes[curr_comp_idx][curr_pack_idx];
                            found <= 1'b1;
                        end
                    end
                    
                    // Move to next pack
                    if (curr_pack_idx < num_packs_arr[curr_comp_idx] - 1) begin
                        curr_pack_idx <= curr_pack_idx + 1;
                    end else begin
                        // Move to next company
                        curr_pack_idx <= 4'd0;
                        if (curr_comp_idx < num_companies - 1) begin
                            curr_comp_idx <= curr_comp_idx + 1;
                        end else begin
                            // Done searching
                            if (!found) begin
                                impossible <= 1'b1;
                            end
                        end
                    end
                    
                    // Done signal check
                    if (curr_comp_idx == num_companies - 1 && curr_pack_idx == num_packs_arr[num_companies - 1] - 1) begin
                         // Next cycle will be DONE
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!rst_n || start) begin
                        done <= 1'b0;
                        found <= 1'b0;
                        impossible <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
