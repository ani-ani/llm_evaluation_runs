module voting_optimizer(
    input [7:0][2:0] citizens,
    input [2:0] n,
    output reg [3:0] min_swaps,
    output reg win_possible
);

    // Intermediate signals
    reg [2:0] teller_positions [7:0]; // Up to 8 possible teller positions
    reg [2:0] voter_types [7:0]; // Up to 8 voters
    reg [2:0] orig_teller_pos [7:0];
    
    integer i, j, k;
    integer num_tellers;
    integer num_voters;
    integer temp_idx;
    
    // Simulation state
    reg [3:0] p1_pts;
    reg [3:0] p2_pts;
    reg [3:0] current_swaps;
    
    // Helper to count bits in a 3-bit one-hot value
    function [1:0] get_party(input [2:0] val);
        begin
            if (val == 3'b001) get_party = 1; // Party 1
            else if (val == 3'b010) get_party = 2; // Party 2
            else get_party = 0; // Teller
        end
    endfunction

    // Variables for permutation generation
    reg [3:0] perm_swaps;
    reg [2:0] perm_tellers [7:0];
    reg [2:0] pos_list [7:0];
    integer t_count;
    integer v_count;
    integer best_swaps_temp;
    reg possible_temp;
    reg [7:0] p1_wins_config; // Bitmask of configs that win
    
    // Variables for tracking minimal distance
    reg [2:0] sorted_orig [7:0];
    reg [2:0] sorted_new [7:0];
    reg [3:0] dist_sum;
    integer rem_idx;
    reg found;
    integer min_idx;
    reg [2:0] min_val;
    
    always @(*) begin
        // Initialization
        num_tellers = 0;
        num_voters = 0;
        min_swaps = 4'd15;
        win_possible = 0;
        
        // 1. Separate Tellers and Voters, preserving order
        for (i = 0; i < 8; i = i + 1) begin
            if (i < n) begin
                if (citizens[i] == 3'b100) begin
                    // Teller
                    if (num_tellers < 8) begin
                        orig_teller_pos[num_tellers] = i;
                        num_tellers = num_tellers + 1;
                    end
                end else if (citizens[i] == 3'b001 || citizens[i] == 3'b010) begin
                    // Voter
                    if (num_voters < 8) begin
                        voter_types[num_voters] = citizens[i];
                        num_voters = num_voters + 1;
                    end
                end
            end
        end
        
        // 2. If no tellers, just check the base win condition
        if (num_tellers == 0) begin
            p1_pts = 0;
            p2_pts = 0;
            for (k = 0; k < num_voters; k = k + 1) begin
                if (voter_types[k] == 3'b001) p1_pts = p1_pts + 1;
                else p2_pts = p2_pts + 1;
            end
            if (p1_pts > p2_pts) begin
                min_swaps = 0;
                win_possible = 1;
            end else begin
                min_swaps = 15;
                win_possible = 0;
            end
        end
        // 3. If tellers exist, we need to iterate
        else if (num_tellers > 0 && num_voters > 0 && (num_tellers + num_voters) <= 8) begin
            // We need to generate permutations of teller positions.
            // Positions available: 0 to (num_tellers + num_voters - 1)
            // We select 'num_tellers' positions out of these.
            
            // This is complex to do purely combinational with 8 choose k.
            // We can use recursion simulation or iterative logic.
            // Given the small size, let's try a nested loop approach for choosing positions.
            // But 8 loops is messy. 
            // Alternative: Iterate through all (N+T) bitmasks with exactly T bits set.
            // N+T <= 8. Max combinations C(8,4)=70.
            // Let's generate bitmasks.
            
            best_swaps_temp = 16;
            possible_temp = 0;
            
            // Generate combinations of positions
            // We will use a stack-based approach to generate combinations of 'num_tellers' positions out of 'total_spots'
            // Total spots = num_tellers + num_voters
            
            // This block is inherently procedural. We will emulate recursion with a stack or iterative logic.
            // Given the Verilog constraint, a brute force check of all permutations of positions is possible if mapped correctly.
            // Since N is small, we can define loops for indices.
            
            // However, Verilog doesn't support dynamic loop unrolling easily.
            // We will implement a specific case logic based on num_tellers, or a generic state-machine style update if possible.
            // Given the "expert" requirement, let's try a generic bit-scanning approach for the combination generation.
            
            // Since this must be combinational, let's define the recursion logic explicitly as a block of logic.
            // Actually, for 8 items, we can use 8 nested generate loops if we knew num_tellers, but we don't.
            // So we must use a runtime search.
            
            // Let's refine the approach: 
            // 1. Determine total length L = n.
            // 2. We need to place T tellers into L spots. 
            // 3. The voters fill the rest in order.
            // 4. Cost is sum |original_teller_pos[i] - new_teller_pos[i]| assuming we match optimally.
            // 5. We need to iterate through all valid placements.
            
            // We will use a stack of indices to simulate nested loops for selecting positions.
            // But since we can't use dynamic recursion, we must generate a state machine or assume a maximum depth.
            // 
            // Let's try a different approach: 
            // Iterate 'mask' from 0 to (1<<L)-1.
            // If popcount(mask) == num_tellers, then check if this configuration wins.
            // Cost calculation: 
            // 1. Get new teller positions from mask.
            // 2. Get original teller positions.
            // 3. Compute min sum of absolute differences (matching problem). 
            // Since both sets are sorted by definition (one is original order, other is scan order), 
            // the optimal match is 1-to-1 in sorted order.
            // 4. If swaps <= 15, record.
            
            // We can implement popcount and iterate in a procedural block.
            // Since this is combinational, we need to ensure the loop terminates or is unrolled.
            // We can use a `for` loop inside an `always @(*)` block.
            
            for (i = 0; i < (1 << n); i = i + 1) begin
                // Check if i has correct number of bits
                // We can count bits
                // However, iterating up to 2^8 = 256 is fine.
                
                temp_idx = 0;
                // Count bits in i
                // If count matches num_tellers
                // Note: We only consider valid spots < n.
                // We need to extract positions.
                
                // Optimized bit count loop
                // Or rely on synthesis to optimize.
            end
            
            // Actually, to make this work without explicit clock, we should use a recursive-like helper or nested loops for max N=8.
            // Let's do nested loops for selecting positions (brute force but guaranteed to work).
            // Since max T=8, max L=8. 
            // We can generate a decision tree.
            
            // Logic for generating combinations:
            // We need to choose T positions out of L.
            // Let's define a generate block or just write out cases? No, too rigid.
            // Let's use a variable-depth loop simulation.
            // We will use a `while` loop? No, combinational loops must be bounded.
            // We will use a standard combination generation algorithm:
            // Pick indices idx[0]...idx[T-1] such that 0 <= idx[0] < idx[1] < ... < idx[T-1] < L.
            
            // We will implement this with a stack-based iterator that runs in one always block.
            // Since `n` and `num_tellers` are variables, the synthesis tool will create a large mux/loop.
            // We assume the tool handles it.
            
            // Reset best
            best_swaps_temp = 16;
            possible_temp = 0;
            
            // We declare a helper task to run the iteration.
            // But tasks in always @(*) might be tricky or just work.
            // Let's inline the logic.
            
            // To handle arbitrary T, we can try to fill positions.
            // We will use a series of registers to hold state during the loop if we were sequential.
            // Since it must be combinational, we will rely on the loop index 'i' from 0 to (1<<n)-1 and filter.
            // This is the most robust way to generate all subsets.
            
            for (i = 0; i < (1 << n); i = i + 1) begin
                // Check if i has exactly num_tellers bits set
                // This is the selection mask.
                // We need to check if this mask places tellers in valid positions (which are all positions < n).
                
                // Count bits
                j = 0;
                temp_idx = i;
                while (temp_idx > 0) begin
                    if (temp_idx[0]) j = j + 1;
                    temp_idx = temp_idx >> 1;
                end
                
                if (j == num_tellers) begin
                    // Valid number of tellers in mask.
                    // Now simulate cost and win.
                    
                    // Extract positions
                    // We also need to ensure that the voters in the remaining spots preserve relative order.
                    // Since we are just placing tellers, any subset of positions for tellers is valid relative to fixed voters.
                    
                    // 1. Calculate Cost (Swaps)
                    // We need to map original teller positions to new teller positions.
                    // Sort the extracted positions.
                    // Since we iterate mask from 0, the extracted positions are naturally in ascending order.
                    
                    dist_sum = 0;
                    
                    // We need to compare the sorted list of original positions with the sorted list of new positions.
                    // But wait, the original positions are fixed relative to each other.
                    // If we have 2 tellers, at pos 1 and 5.
                    // New positions are 2 and 6.
                    // Map 1->2 (dist 1), 5->6 (dist 1). Total 2.
                    // If we map 1->6 and 5->2, sum is 8. So sorting matters.
                    // Since we extract positions in ascending order from the mask, we just need to sort the original teller positions.
                    
                    // Prepare sorted original positions
                    // (We can assume orig_teller_pos is already sorted since we scanned citizens in order).
                    // Prepare sorted new positions
                    
                    rem_idx = 0;
                    for (k = 0; k < n; k = k + 1) begin
                        if (i[k]) begin
                            // This is a new teller position
                            sorted_new[rem_idx] = k;
                            rem_idx = rem_idx + 1;
                        end
                    end
                    
                    // Calculate distance
                    for (k = 0; k < num_tellers; k = k + 1) begin
                        if (sorted_new[k] > orig_teller_pos[k]) 
                            dist_sum = dist_sum + (sorted_new[k] - orig_teller_pos[k]);
                        else 
                            dist_sum = dist_sum + (orig_teller_pos[k] - sorted_new[k]);
                    end
                    
                    // Check if cost is within limits (optimization)
                    if (dist_sum <= 15) begin
                        // Now Simulate Voting
                        p1_pts = 0;
                        p2_pts = 0;
                        
                        // Iterate through the sequence 0 to n-1
                        for (k = 0; k < n; k = k + 1) begin
                            if (i[k]) begin // Teller
                                if (p1_pts > p2_pts) p1_pts = p1_pts + 1;
                                else if (p2_pts > p1_pts) p2_pts = p2_pts + 1;
                                // If equal, teller does nothing (treat as no op or specific rule? "awards a point to the party with more votes")
                                // If equal, no one has more, so presumably no point awarded.
                            end else begin // Voter
                                // Find which voter corresponds to this position
                                // We need a pointer to the next voter in the sequence.
                                // Since we know the mask 'i' tells us where tellers are, we can compute the voter index on the fly.
                                
                                // We need a counter for voters seen so far to index into voter_types
                                // To do this in combinational logic, we need to count zeros in mask up to 'k'.
                            end
                        end
                        
                        // To correctly index voters, we need to know how many voters appeared before index k.
                        // Let's do that.
                        
                        p1_pts = 0;
                        p2_pts = 0;
                        
                        integer v_idx_counter = 0;
                        for (k = 0; k < n; k = k + 1) begin
                            if (i[k]) begin // Teller
                                if (p1_pts > p2_pts) p1_pts = p1_pts + 1;
                                else if (p2_pts > p1_pts) p2_pts = p2_pts + 1;
                            end else begin // Voter
                                if (voter_types[v_idx_counter] == 3'b001) p1_pts = p1_pts + 1;
                                else if (voter_types[v_idx_counter] == 3'b010) p2_pts = p2_pts + 1;
                                v_idx_counter = v_idx_counter + 1;
                            end
                        end
                        
                        if (p1_pts > p2_pts) begin
                            possible_temp = 1;
                            if (dist_sum < best_swaps_temp) begin
                                best_swaps_temp = dist_sum;
                            end
                        end
                    end
                end
            end
            
            // Final assignment
            if (possible_temp) begin
                min_swaps = best_swaps_temp;
                win_possible = 1;
            end else begin
                min_swaps = 15;
                win_possible = 0;
            end
        end
        // Case: num_tellers > 0 but num_voters == 0 (all tellers)
        // Then no voters, no points. Party 1 cannot win (needs strictly more points).
        // So min_swaps = 15, win_possible = 0.
        // This is handled by the logic above (sim loop will result in p1=0, p2=0, check fails).
        // If num_tellers + num_voters < n (invalid input?), we only consider valid citizens.
        // If num_tellers + num_voters > n (shouldn't happen), we only consider up to n.
    end

endmodule
