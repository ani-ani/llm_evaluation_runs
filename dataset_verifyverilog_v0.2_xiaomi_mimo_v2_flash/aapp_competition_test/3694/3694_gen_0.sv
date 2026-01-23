module stone_game (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_piles,
    input [7:0][3:0] piles,
    output reg winner,
    output reg valid,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SORT = 3'b001;
    localparam CHECK_INVALID = 3'b010;
    localparam CALCULATE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [7:0][3:0] sorted_piles;
    reg [7:0][3:0] next_sorted_piles;

    // Bubble sort registers
    reg [2:0] sort_i; // Outer loop counter 0-7
    reg [2:0] sort_j; // Inner loop counter 0-6
    reg sort_done;
    reg [3:0] temp_val;

    // Check invalid registers
    reg [2:0] check_idx;
    reg [1:0] dup_count;
    reg [3:0] dup_value;
    reg is_invalid;

    // Calculate registers
    reg [2:0] calc_idx;
    reg signed [5:0] sum_val; // Max sum: 8*15 = 120, needs 7 bits signed. (15-0)+(15-1)+.. approx 120
    reg signed [5:0] next_sum_val;

    // Control signals
    reg start_processing;
    reg sorting_done_flag;
    reg check_done_flag;
    reg calc_done_flag;

    // --- State Transition & Output Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            winner <= 0;
            valid <= 0;
            sorted_piles <= 0;
            sort_i <= 0;
            sort_j <= 0;
            check_idx <= 0;
            calc_idx <= 0;
            sum_val <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= SORT;
                        // Initialize sorted_piles with input, zero out invalid piles
                        // We use the input array directly in SORT logic usually,
                        // but here we copy to a working register.
                        sorted_piles <= piles;
                        // Only strictly need to zero out beyond num_piles if we care about strict inputs,
                        // but the logic checks duplicates, so zeros matter.
                        // We will mask them in the SORT stage or check.
                        // Let's mask them now.
                        if (num_piles < 3'd1) sorted_piles[0] <= 4'b0;
                        if (num_piles < 3'd2) sorted_piles[1] <= 4'b0;
                        if (num_piles < 3'd3) sorted_piles[2] <= 4'b0;
                        if (num_piles < 3'd4) sorted_piles[3] <= 4'b0;
                        if (num_piles < 3'd5) sorted_piles[4] <= 4'b0;
                        if (num_piles < 3'd6) sorted_piles[5] <= 4'b0;
                        if (num_piles < 3'd7) sorted_piles[6] <= 4'b0;
                        if (num_piles < 3'd8) sorted_piles[7] <= 4'b0;

                        // Init Sort Counters
                        sort_i <= 3'd0;
                        sort_j <= 3'd0;
                        sorting_done_flag <= 0;
                    end
                end

                SORT: begin
                    // Bubble sort logic implemented as a sequential state
                    if (sort_i < 3'd7) begin
                        if (sort_j < 3'd7 - sort_i) begin
                            // Compare and Swap
                            if (sorted_piles[sort_j] > sorted_piles[sort_j + 1]) begin
                                // Swap
                                sorted_piles[sort_j] <= sorted_piles[sort_j + 1];
                                sorted_piles[sort_j + 1] <= sorted_piles[sort_j];
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            // End of inner loop
                            sort_j <= 0;
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        // Sorting complete
                        state <= CHECK_INVALID;
                        check_idx <= 0;
                        dup_count <= 0;
                        is_invalid <= 0;
                    end
                end

                CHECK_INVALID: begin
                    // Check duplicates and rules
                    // We iterate 0 to 6 to check pairs i and i+1
                    if (check_idx < 3'd7) begin
                        if (sorted_piles[check_idx] == sorted_piles[check_idx + 1] && sorted_piles[check_idx] != 0) begin
                            // Found a valid duplicate (non-zero)
                            dup_count <= dup_count + 1;
                            if (dup_count >= 2'd1) is_invalid <= 1; // More than 1 pair of duplicates

                            // Store first duplicate value for V-1 check if it's the first pair found
                            if (dup_count == 0) dup_value <= sorted_piles[check_idx];
                        end
                        // V-1 check logic: Needs to happen on the fly or after scan.
                        // Since we scan sorted, we can check if (value - 1) exists.
                        // Since we need to check V-1, we can check if sorted_piles[check_idx] == sorted_piles[check_idx+1] (duplicate)
                        // Then search array for sorted_piles[check_idx] - 1. 
                        // Optimization: Just check adjacent neighbors in sorted array?
                        // If duplicate is V, then V-1 would be left or right. But we can just check the whole array if duplicate found.
                        // To save logic/states, we will do the V-1 check in a sub-state or combined.
                        // Let's do it in a sub-step or just handle it in the CALC phase or separate iteration.

                        // Wait, standard algorithm: Scan. If duplicates > 1 -> invalid.
                        // If duplicate is 0 -> invalid.
                        // If duplicate V, check if V-1 exists -> invalid.
                        // Since we are sequential, let's add a specific sub-state for V-1 check if we find a duplicate.
                        // OR, we can assume V-1 check takes a few cycles and we handle it here.

                        // Let's refine: 
                        // 1. Count duplicates. If > 1, invalid.
                        // 2. If duplicate found, check for V-1.
                        // 3. If duplicate == 0, invalid.

                        // To do this efficiently in one pass with sub-states is hard. 
                        // Let's do: Iterate 0-6. If duplicate found: 
                        //   - Check if value == 0 -> invalid
                        //   - Check if value == prev or next value - 1? No, check if value-1 exists anywhere.
                        //   - Since sorted, we can just check if sorted[...] == val-1.
                        //   - Since we need to scan for val-1, let's pause the loop and search.

                        // Better approach: 
                        // State CHECK_INVALID:
                        //   Iterate i 0..6:
                        //     If sorted[i] == sorted[i+1]:
                        //       If sorted[i] == 0 -> invalid
                        //       dup_count++
                        //       Check for V-1. (Sub-problem).

                        // Let's make a helper sub-state or combine.
                        // Since we have latency requirement 60 cycles, we have room.
                        // Let's handle the V-1 check in a separate loop after finding a duplicate.

                        // Current logic: Update check_idx
                        check_idx <= check_idx + 1;

                        // Immediate checks
                        if (sorted_piles[check_idx] == sorted_piles[check_idx + 1]) begin
                            if (sorted_piles[check_idx] == 0) is_invalid <= 1;

                            // Logic for V-1 check:
                            // We need to check if (sorted_piles[check_idx] - 1) exists in sorted_piles.
                            // Let's set a flag and a search index.
                            // Actually, let's do this: Inside the loop, if we detect a duplicate, we pause the loop.
                            // Transition to a CHECK_V1 state.
                            // But wait, checking V-1 requires iterating the array again (or forward/back check).
                            // We can do it in the same state if we are smart, but let's create a sub-state.
                        end

                        // Handling the 'V-1' check within the loop:
                        // Since sorted_piles is sorted, V-1 will be immediately left or right of the duplicate block.
                        // Wait, not necessarily. V-1 could be anywhere.
                        // Example: [1, 2, 5, 5]. V=5. V-1=4. Not present. 
                        // Example: [1, 2, 4, 5, 5]. V=5. V-1=4. Present.
                        // So we must search the whole array.

                        // Optimization: 
                        // If we find a duplicate V at index i:
                        // Check sorted[i-1] == V-1? (If i > 0)
                        // Check sorted[i+2] == V-1? (If i+2 < 8)
                        // This covers adjacent cases. But what about [1, 3, 3, 5]? V=3, V-1=2. Not present. Valid.
                        // What about [2, 3, 3, 4]? V=3, V-1=2. Present. Invalid.
                        // What about [2, 4, 4, 5]? V=4, V-1=3. Not present. Valid.
                        // What about [0, 4, 4]? V=4, V-1=3. Not present. Valid (but 0 is separate check).

                        // Actually, if sorted, V-1 must be either immediately before the duplicate block (if present) or somewhere else.
                        // Wait. If V-1 is present, it MUST be adjacent to V in a sorted array (unless there are gaps).
                        // Example: [1, 2, 4, 4]. V=4. V-1=3. Not present. Valid.
                        // Example: [1, 3, 4, 4]. V=4. V-1=3. Present. Invalid.
                        // Example: [2, 4, 4]. V=4. V-1=3. Not present. Valid.
                        // Example: [3, 4, 4]. V=4. V-1=3. Present. Invalid.
                        // So, if a duplicate V exists, V-1 must be the immediate preceding element (if it exists).
                        // Because the array is sorted, any V-1 must be at index k where sorted[k] = V-1.
                        // Since sorted[k+1] >= V, and we found V at i.
                        // If V-1 is at j, then j < i. And sorted[i-1] is the element just before the first V.
                        // If sorted[i-1] == V-1, then invalid.

                        // Wait, what if [V-1, V-1, V, V]?
                        // sorted[i] is the first V. sorted[i-1] is V-1. Yes.

                        // What if [V-1, X, V, V] where X > V-1 and X < V? Impossible in sorted array.
                        // What if [V-1, V, V, V]? sorted[i] is first V. sorted[i-1] is V-1. Yes.

                        // Conclusion: We only need to check the element immediately preceding the first duplicate.
                        // Edge case: What if the duplicate is at index 0? No preceding element, so V-1 cannot exist (since array is sorted 0..).

                        // So, in the CHECK_INVALID state:
                        // Iterate i 0..6.
                        // If sorted[i] == sorted[i+1]:
                        //   1. dup_count++
                        //   2. If sorted[i] == 0 -> invalid
                        //   3. If i > 0 && sorted[i-1] == sorted[i] - 1 -> invalid

                        // Wait, what if duplicate is [5, 5] and array is [1, 5, 5]? 
                        // i=1. sorted[1] == sorted[2] (5==5). 
                        // i > 0 -> true. sorted[i-1] = 1. sorted[i]-1 = 4. 1 != 4. Valid.

                        // What if [4, 5, 5]? i=1. sorted[0]=4. sorted[1]-1=4. Matches -> Invalid. Correct.

                        // What if [5, 5, 6]? i=0. sorted[0] == sorted[1] (5==5). 
                        // i > 0 is false. Check sorted[i+2] = 6. 6 == 5+1? Yes. Wait.
                        // If V=5 is at index 0, then there is no element at -1. 
                        // But V-1 could be V+1? No, V-1 is smaller. 
                        // If V is at 0, then V-1 cannot exist in a non-negative sorted array.
                        // So [5, 5, 6] is valid? Yes, because 4 is not present.

                        // What about [V, V, V-1]? Impossible in sorted array.

                        // However, the problem says "A duplicate value V has V-1 also present".
                        // This implies V-1 must exist. 
                        // The check `if (i > 0 && sorted[i-1] == sorted[i] - 1)` works for V not at index 0.
                        // What about [V, V, ...] where V-1 is later? Impossible.

                        // Wait, what if the array is [V-1, V, V]? i=1. sorted[0] = V-1. Check passes (invalid). Correct.

                        // So, we can perform this check in the loop without a sub-state.

                        // Logic:
                        // If (sorted[i] == sorted[i+1])
                        //   dup_count++
                        //   if (sorted[i] == 0) invalid
                        //   if (i > 0) begin
                        //     if (sorted[i-1] == sorted[i] - 1'b1) invalid
                        //   end
                        //   // What if the duplicate is the first element? i=0. No i-1. 
                        //   // Could V-1 be somewhere else? No, sorted.
                        //   // Could V-1 be at i+2? No, V-1 < V.
                        //   // So i=0 implies valid (unless V=0).
                        //   // Example: [2, 2, 3]. i=0. sorted[0]=2. Check sorted[2]=3. 3 != 1. Wait, V-1=1. Not present.
                        //   // Wait, [1, 2, 2]. i=1. sorted[0]=1. 1==1 -> invalid. Correct.
                        //   // [2, 2, 1] is impossible after sort.
                        //   
                        //   // Actually, wait. If [2, 2], i=0. No preceding. Valid.
                        //   // If [2, 2, 3], i=0. No preceding. Valid.
                        //   // If [1, 2, 2], i=1. Has preceding. Check sorted[0]==2-1 -> 1==1 -> invalid.

                        //   // So the logic holds.
                        //   
                        //   // One more edge: [0, 0]. i=0. sorted[0]==0 -> invalid. Correct.
                        //   // [1, 1, 2]. i=0. sorted[0]=1. No preceding. Check validity? 
                        //   // V=1. V-1=0. Is 0 present? No. Valid.
                        //   // [0, 1, 1]. i=1. sorted[0]=0. sorted[1]-1=0. Match -> invalid.

                        // Okay, the logic seems sound for sorted array.

                        // Let's implement this in the current state.

                        if (sorted_piles[check_idx] == sorted_piles[check_idx + 1]) begin
                            if (sorted_piles[check_idx] == 0) is_invalid <= 1;

                            dup_count <= dup_count + 1;
                            if (dup_count > 0) is_invalid <= 1; // More than 1 pair

                            if (check_idx > 0) begin
                                if (sorted_piles[check_idx - 1] == sorted_piles[check_idx] - 1'b1) begin
                                    is_invalid <= 1;
                                end
                            end
                            // We also need to increment check_idx by 1 extra to skip the duplicate partner in the next iteration,
                            // to avoid counting the same pair twice (or checking i+1 and i+2 as a pair if triple duplicate).
                            // Wait, if we have [V, V, V], then:
                            // i=0: match. count++.
                            // i=1: sorted[1]==sorted[2] (V==V). count++. 
                            // This counts 2 pairs. But we want to fail on > 1 pair.
                            // So logic is fine. 
                            // However, if we check i=0, we move to i=1. i=1 checks sorted[1]==sorted[2].
                            // If we want to treat [V,V,V] as one duplicate group, usually game rules treat it as invalid or 
                            // just count pairs. The description says "More than one pair of duplicates".
                            // [V, V, V] has pairs (0,1) and (1,2). So it is > 1 pair.
                            // So incrementing check_idx naturally is fine.
                            // But if we have [V, V, V], check_idx goes 0 -> 1. 
                            // At 0, we detect dup. 
                            // At 1, we detect dup. count=2. Invalid. Correct.

                            // However, we might want to skip the next index to avoid double checking the same relation if we want to count "groups".
                            // But "pairs" implies count of i such that arr[i] == arr[i+1].
                            // So yes, [V,V,V] has 2 pairs. Correct.

                            // Wait, what if [V, V, V, V]? pairs: 0-1, 1-2, 2-3. 3 pairs.
                            // So my logic will catch it.
                        end
                    end else begin
                        // Finished scan
                        if (is_invalid) begin
                            valid <= 0;
                            winner <= 0; // Imply loser? "In valid=0, winner implies loser".
                            // We don't know loser, just 0. We can assign 0.
                            state <= DONE;
                        end else begin
                            // Valid input
                            valid <= 1;
                            state <= CALCULATE;
                            calc_idx <= 0;
                            sum_val <= 0;
                        end
                    end
                end

                CALCULATE: begin
                    // Sum (piles[i] - i) for i=0 to 7
                    // Note: We use the sorted array.
                    // But the requirement says: "calculate the sum of (piles[i] - i) for i=0 to 7".
                    // In the context of the stone game, it usually means the sorted array indices.
                    // Yes, "sort the input array... calculate sum of (piles[i] - i)".

                    if (calc_idx < 3'd8) begin
                        // Add (sorted_piles[calc_idx] - calc_idx)
                        // calc_idx is 0..7. 
                        // sum_val needs to handle signed math or we do it carefully.
                        // Max value: 15 - 0 = 15. Sum of 8 terms max 120. Min: 0 - 7 = -7 per term. Min sum ~ -56.
                        // So sum_val should be signed.

                        sum_val <= sum_val + $signed({1'b0, sorted_piles[calc_idx]}) - $signed({1'b0, calc_idx});
                        calc_idx <= calc_idx + 1;
                    end else begin
                        // Done calculating
                        // Check parity
                        if (sum_val[0] == 1'b1) winner <= 1;
                        else winner <= 0;

                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        // Wait for start to go low to return to IDLE (optional, but good for handshaking)
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule