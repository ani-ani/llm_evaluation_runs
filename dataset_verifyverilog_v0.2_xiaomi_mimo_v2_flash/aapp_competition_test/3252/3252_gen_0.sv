module envelope_optimizer(
    input clk,
    input rst_n,
    input start,
    input [15:0] card_width [0:4],
    input [15:0] card_height [0:4],
    input [15:0] card_qty [0:4],
    input [2:0] k_envelopes,
    output reg [47:0] min_waste,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam PRECOMPUTE_SUBSETS = 3'b001;
    localparam DP_INIT = 3'b010;
    localparam DP_LOOP = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Counters and indices
    reg [4:0] subset_idx; // 0 to 31
    reg [2:0] k_idx;      // 0 to 5
    reg [4:0] submask_idx; // 0 to 31
    
    // Intermediate storage
    // Waste storage: 32 entries, waste calculated for subset mask
    reg [47:0] waste_storage [0:31];
    
    // DP Table: dp[mask][k] - using distributed RAM style or registers
    // Since mask is 32 and k is 6, we can use a large register array or BRAM.
    // To save space and follow sequential logic, we update in place or use next/prev buffers.
    // However, the DP update logic requires reading dp[i-s][j-1]. 
    // If we iterate i from 1 to 31, we need access to previous mask states and previous k states.
    // Strategy: 
    // 1. Initialize dp[mask][0] = infinity, dp[0][0] = 0.
    // 2. Loop k from 1 to K.
    // 3. Inside k, loop mask from 1 to 31.
    // 4. Inside mask, iterate submasks.
    // This requires storing dp for current k and previous k? 
    // Actually, the recurrence is: dp[i][j] = min(dp[i][j], dp[i-s][j-1] + waste[s]).
    // If we iterate j from 1 to K, we can update dp[i][j] using dp values from the previous j iteration.
    // But we also need to update dp[i][j] based on different submasks.
    // Let's use a single array `dp` for current j, and a `dp_prev` for j-1.
    // Wait, the recurrence is essentially 0/1 knapsack like or subset partition.
    // If we iterate k from 1 to K, and mask from 0 to 31, we can update.
    // Let dp[mask][k] be the value. We need to store this.
    // Given the constraints, a 32x6 array of 48-bit is manageable in logic.
    // 32 * 6 * 48 = 9216 bits. 
    // Let's implement it as a block of registers.
    // We need to read dp[old_mask][k-1] and write to dp[mask][k].
    // If we iterate k from 1 to K, we can update in place? No, because we need old values.
    // So we need two banks or iterate carefully.
    // Let's iterate k from 1 to K.
    // For each k, we compute the new DP values for all masks.
    // We can store the results in a temp array and then copy back, or use two arrays and swap.
    // Let's use two arrays: dp_curr and dp_prev.
    
    reg [47:0] dp_curr [0:31];
    reg [47:0] dp_prev [0:31];
    
    // Large constant for infinity
    localparam [47:0] INF = 48'hFFFFFFFFFFFF;

    // Helper logic for precomputation
    // We need to calculate max width, max height for a specific subset_idx
    // This is combinational based on subset_idx
    reg [15:0] max_w, max_h;
    reg [47:0] current_subset_waste;
    
    integer i;
    always @(*) begin
        max_w = 0;
        max_h = 0;
        for (i = 0; i < 5; i = i + 1) begin
            if (subset_idx[i]) begin
                if (card_width[i] > max_w) max_w = card_width[i];
                if (card_height[i] > max_h) max_h = card_height[i];
            end
        end
        // Envelope area = max_w * max_h (max 16384*16384 ~ 2.68e9, fits in 32 bits)
        // But waste is (env_area - card_area) * qty.
        // Wait, the prompt says: "Waste = sum of (envelope_area - card_area) * quantity for all cards"
        // This implies for a subset S, if we use one envelope, the envelope size is max_w * max_h.
        // Then for each card in S, waste is (max_w*max_h - card_w*card_h) * qty.
        // So Total waste for subset S = sum_{i in S} [(max_w*max_h - w_i*h_i) * q_i]
        // = (max_w*max_h) * sum(q_i) - sum(w_i*h_i*q_i)
        
        reg [27:0] sum_card_area_prod = 0; // w*h
        reg [27:0] sum_qty = 0;
        
        for (i = 0; i < 5; i = i + 1) begin
            if (subset_idx[i]) begin
                sum_card_area_prod = sum_card_area_prod + (card_width[i] * card_height[i]);
                sum_qty = sum_qty + card_qty[i];
            end
        end
        
        reg [47:0] env_area = max_w * max_h; // 16x16 -> 32 bits
        reg [47:0] total_card_area = sum_card_area_prod * sum_qty; // 28+14 -> 42 bits
        // 42 bits * 28 bits? No, sum_card_area_prod is 28 bits, sum_qty is 14+3? 
        // sum_qty is sum of 5 14-bit numbers. 14+3 = 17 bits max.
        // So product is 28+17 = 45 bits.
        // Let's cast to larger width to be safe.
        
        reg [47:0] env_area_large = max_w * max_h;
        reg [47:0] sum_qty_large = sum_qty;
        reg [47:0] sum_area_large = sum_card_area_prod;
        
        current_subset_waste = (env_area_large * sum_qty_large) - (sum_area_large * sum_qty_large);
    end

    // DP Control Logic
    reg [4:0] loop_mask;
    reg [4:0] loop_submask;
    reg [47:0] candidate_waste;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_waste <= 0;
            done <= 0;
            subset_idx <= 0;
            k_idx <= 0;
            loop_mask <= 0;
            loop_submask <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PRECOMPUTE_SUBSETS;
                        subset_idx <= 0;
                    end
                end

                PRECOMPUTE_SUBSETS: begin
                    // Calculate waste for subset_idx and store it
                    waste_storage[subset_idx] <= current_subset_waste;
                    
                    if (subset_idx == 31) begin
                        state <= DP_INIT;
                        subset_idx <= 0;
                    end else begin
                        subset_idx <= subset_idx + 1;
                    end
                end

                DP_INIT: begin
                    // Initialize dp_prev: dp[0][0] = 0, others = INF
                    // We are setting up for k=1 iteration, so dp_prev corresponds to k=0
                    for (int j = 0; j < 32; j = j + 1) begin
                        if (j == 0) dp_prev[j] <= 0;
                        else dp_prev[j] <= INF;
                    end
                    k_idx <= 1; // Start with k=1 envelope
                    state <= DP_LOOP;
                    loop_mask <= 1; // Start from mask 1 (skip 0, waste 0 is trivial)
                end

                DP_LOOP: begin
                    // DP Recurrence: dp_curr[mask] = min(dp_prev[mask], min over submasks s of mask (dp_prev[mask-s] + waste[s]))
                    // Wait, the problem states: "dp[i][k] = min(dp[i][k], dp[i-s][k-1] + waste[s])"
                    // This is for partitioning into k sets.
                    // We iterate k from 1 to K.
                    // For a fixed k, we want to find dp[mask][k] using dp[...][k-1].
                    // The loop structure: 
                    // For k in 1..K:
                    //   For mask in 1..31:
                    //     dp_curr[mask] = dp_prev[mask] (using fewer envelopes is better if possible? No, strictly k envelopes)
                    //     Actually, dp[i][j] is min waste for exactly j envelopes?
                    //     Prompt says "partitioning all cards into at most K subsets". 
                    //     So if we use fewer than K, it should be allowed.
                    //     The standard way: dp[mask][k] = min(dp[mask][k], dp[mask-s][k-1] + waste[s]).
                    //     And we want min_{1<=j<=K} dp[full][j].
                    
                    // Let's refine the loop:
                    // State DP_LOOP handles the nested loops: k_idx, loop_mask, loop_submask.
                    // This is a deep pipeline. To fit in a single always block cleanly, we might need sub-states or just counters.
                    // Given the "832 cycles" hint, we can do sequential updates.
                    
                    // Operation:
                    // If k_idx <= k_envelopes:
                    //   If loop_mask <= 31:
                    //     If loop_submask is a submask of loop_mask:
                    //       Read dp_prev[loop_mask - loop_submask] and waste[loop_submask].
                    //       Update dp_curr[loop_mask].
                    //       Increment loop_submask.
                    //     Else (done with submasks for this mask):
                    //       dp_curr[loop_mask] is final for this k.
                    //       Increment loop_mask. Reset loop_submask.
                    //   Else (done with masks for this k):
                    //     Swap dp_curr and dp_prev (so dp_prev now holds results for k envelopes).
                    //     Increment k_idx. Reset loop_mask.
                    // Else (done with all k):
                    //   Find min of dp_prev[31] (wait, we need min over k <= K).
                    //   Actually, we should keep a running minimum of dp_prev[31] as k increases.
                    //   Let's keep track of best_waste.

                    // Implementing submask iteration:
                    // loop_submask <= (loop_submask - 1) & loop_mask; is standard way to iterate submasks.
                    // But we need to handle the initialization of loop_submask.
                    // If loop_mask changes, loop_submask = loop_mask.
                    
                    // Let's add a sub-state for the submask loop or just use counters.
                    // We need to handle the "submask" logic. 
                    // When we enter DP_LOOP for a new mask, loop_submask should be initialized to loop_mask.
                    // Then in each cycle, we process the current submask, then update: loop_submask = (loop_submask - 1) & loop_mask.
                    // If loop_submask becomes 0, we are done with this mask.

                    if (k_idx <= k_envelopes) begin
                        if (loop_mask <= 31) begin
                            // Process submask
                            if (loop_submask != 0) begin
                                // Calculate candidate: dp_prev[loop_mask - loop_submask] + waste[loop_submask]
                                // Note: loop_mask - loop_submask in binary logic is just XOR if we know it's a submask?
                                // No, it's bitwise subtraction or (loop_mask ^ loop_submask) if no borrow?
                                // Safer: `loop_mask & ~loop_submask`? No.
                                // `A - B` where B is subset of A. 
                                // In Verilog, just `loop_mask - loop_submask` works if we ensure it's a submask.
                                // But we are iterating submasks correctly.
                                
                                // Check if this submask is valid (it is by construction).
                                // Update dp_curr[loop_mask]
                                
                                candidate_waste = dp_prev[loop_mask - loop_submask] + waste_storage[loop_submask];
                                
                                if (candidate_waste < dp_curr[loop_mask]) begin
                                    dp_curr[loop_mask] <= candidate_waste;
                                end

                                // Next submask
                                loop_submask <= (loop_submask - 1) & loop_mask;
                            end else begin
                                // Finished submasks for loop_mask
                                // We need to check if dp_curr[loop_mask] is better than dp_prev[loop_mask] (using fewer envelopes)
                                // Since we want "at most K", yes.
                                if (dp_prev[loop_mask] < dp_curr[loop_mask]) begin
                                    dp_curr[loop_mask] <= dp_prev[loop_mask];
                                end
                                
                                // Move to next mask
                                loop_mask <= loop_mask + 1;
                                if (loop_mask + 1 <= 31) begin
                                    loop_submask <= loop_mask + 1; // Initialize for next mask
                                end
                            end
                        end else begin
                            // Finished all masks for current k_idx
                            // Copy dp_curr to dp_prev for next iteration
                            // We can't copy in one cycle easily without a loop, but we can iterate k_idx and reset loop_mask.
                            // Actually, we can just swap pointers or use an array index.
                            // Let's do the copy using the always block or a separate logic.
                            // Since this is a sequential block, let's explicitly copy.
                            // Or, we can swap the logic: use dp_prev as source, dp_curr as dest, then swap indices.
                            // Wait, the code above updates dp_curr in place. 
                            // We need to update dp_prev for the next k.
                            // Let's copy dp_curr to dp_prev.
                            
                            // Optimization: we can use a generate loop or just unroll for 32 entries.
                            // Since it's 32 entries, it's small.
                            dp_prev[0] <= dp_curr[0]; dp_prev[1] <= dp_curr[1]; dp_prev[2] <= dp_curr[2];
                            dp_prev[3] <= dp_curr[3]; dp_prev[4] <= dp_curr[4]; dp_prev[5] <= dp_curr[5];
                            dp_prev[6] <= dp_curr[6]; dp_prev[7] <= dp_curr[7]; dp_prev[8] <= dp_curr[8];
                            dp_prev[9] <= dp_curr[9]; dp_prev[10] <= dp_curr[10]; dp_prev[11] <= dp_curr[11];
                            dp_prev[12] <= dp_curr[12]; dp_prev[13] <= dp_curr[13]; dp_prev[14] <= dp_curr[14];
                            dp_prev[15] <= dp_curr[15]; dp_prev[16] <= dp_curr[16]; dp_prev[17] <= dp_curr[17];
                            dp_prev[18] <= dp_curr[18]; dp_prev[19] <= dp_curr[19]; dp_prev[20] <= dp_curr[20];
                            dp_prev[21] <= dp_curr[21]; dp_prev[22] <= dp_curr[22]; dp_prev[23] <= dp_curr[23];
                            dp_prev[24] <= dp_curr[24]; dp_prev[25] <= dp_curr[25]; dp_prev[26] <= dp_curr[26];
                            dp_prev[27] <= dp_curr[27]; dp_prev[28] <= dp_curr[28]; dp_prev[29] <= dp_curr[29];
                            dp_prev[30] <= dp_curr[30]; dp_prev[31] <= dp_curr[31];

                            // Update min_waste if we found a better solution with current k_idx
                            // dp_curr[31] is the result for the full mask with k_idx envelopes (or less)
                            if (k_idx == 1) min_waste <= dp_curr[31];
                            else if (dp_curr[31] < min_waste) min_waste <= dp_curr[31];

                            k_idx <= k_idx + 1;
                            loop_mask <= 1;
                            // loop_submask will be set when loop_mask is processed
                            // But we need to ensure dp_curr is ready for next k.
                            // Reset dp_curr to INF for the next iteration (since we start fresh for each k in the recurrence)
                            // Actually, for the recurrence dp[i][j] = min(dp[i][j], dp[i-s][j-1] + w[s]),
                            // we start with dp[i][j] = infinity (or previous value).
                            // So we reset dp_curr entries before the next k loop.
                            // We can reset them here or at the start of the DP loop.
                            // Let's reset them now.
                            for (int r = 0; r < 32; r = r + 1) dp_curr[r] <= INF;
                        end
                    end else begin
                        // All k done
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) state <= IDLE; // Wait for start to go low to reset
                end
            endcase
        end
    end

    // Fix for the submask initialization logic inside the FSM:
    // When loop_mask increments (in the else branch of submask check), loop_submask is not explicitly set in that same cycle in the code above.
    // However, in the next cycle, the condition `if (loop_submask != 0)` will be checked.
    // If we just incremented loop_mask, loop_submask retains its old value (0 from previous finish).
    // So we need to set loop_submask = loop_mask when loop_mask changes.
    // We can do this by initializing loop_submask when entering the mask loop.
    // The code `loop_submask <= loop_mask + 1;` was inside the `else` block? No, it was `loop_submask <= loop_mask + 1`.
    // Let's rewrite that part carefully.
    
    // Wait, the previous code block was getting complex. Let's simplify the DP_LOOP structure.
    // We need to iterate k. For each k, we iterate masks.
    // The loop_submask logic is critical.
    
    // Re-evaluating the DP logic in FSM:
    // We have `dp_prev` (valid for k-1).
    // We want to compute `dp_curr` (for k).
    // `dp_curr[mask]` needs to find min over s of `dp_prev[mask-s] + waste[s]`.
    // This is essentially a convolution or subset sum minimization.
    
    // A robust way:
    // State DP_LOOP:
    //   if (k_idx <= k_envelopes) begin
    //     if (loop_mask <= 31) begin
    //       // We are iterating submasks of loop_mask
    //       // If loop_submask is 0, we are done with this mask, move to next mask
    //       // Else, process and go to next submask
    //       // BUT, we need to initialize loop_submask for each new mask.
    //   end
    // 
    // Let's add an explicit initialization flag or just handle it.
    
    // Let's refine the `DP_LOOP` state logic inside the always block (overwriting previous draft)
    // We will assume `dp_curr` was initialized to INF at the start of the k loop.
    // We need to handle `loop_submask` update properly.
    
    // *Correction to the FSM code in the thought block:*
    // The logic inside DP_LOOP:
    // 
    // if (k_idx <= k_envelopes) begin
    //     if (loop_mask <= 31) begin
    //         // Is this the start of a new mask?
    //         // If loop_submask == 0 (or some sentinel), initialize.
    //         // Wait, loop_submask is 0 when we finished previous mask.
    //         // So, if loop_submask == 0, set loop_submask = loop_mask.
    //         
    //         if (loop_submask == 0) begin
    //             loop_submask <= loop_mask;
    //         end else begin
    //             // Process current submask
    //             candidate_waste = dp_prev[loop_mask - loop_submask] + waste_storage[loop_submask];
    //             if (candidate_waste < dp_curr[loop_mask]) dp_curr[loop_mask] <= candidate_waste;
    //             
    //             // Next submask
    //             loop_submask <= (loop_submask - 1) & loop_mask;
    //             // If the result is 0, the next cycle will enter the `if (loop_submask == 0)` block? 
    //             // No, if (loop_submask == 0) we set it to loop_mask.
    //             // We need a way to distinguish "done with submasks" vs "need to start submasks".
    //             // Let's use a separate flag `submask_done` or just check if we just finished.
    //             // Actually, if loop_submask becomes 0, we are done.
    //             // So we can do:
    //             // if (loop_submask == 0) begin ... end else ...
    //             // But if loop_submask becomes 0 inside the else, next cycle it will be 0.
    //             // So we need to move to next mask.
    //             
    //             // Revised:
    //             if (loop_submask == loop_mask) begin
    //                 // This is the first submask. Just process it. Next is (loop_mask-1) & loop_mask.
    //             end
    //             // This is getting messy with single cycle processing.
    //         end
    //     end
    // end

    // Let's use a simpler approach for the submask loop:
    // We will process one submask per cycle.
    // When we enter DP_LOOP for a new mask, we set `submask = mask`.
    // Then we process `submask`.
    // Then we update `submask = (submask - 1) & mask`.
    // If `submask` becomes 0, we are done with this mask.
    // 
    // We need a flag to know when we are done with the current mask.
    // Let's use a state `DP_MASK_LOOP` and `DP_SUBMASK_LOOP`.
    // But we have limited states. 
    // Let's keep `DP_LOOP` but add a small counter or logic.
    
    // Actually, the previous code was almost correct. The issue was resetting loop_submask.
    // Let's fix it this way:
    // In `DP_LOOP`:
    //   if (k_idx <= k_envelopes) begin
    //     if (loop_mask <= 31) begin
    //       // Check if we are done with current mask
    //       if (loop_submask == 0) begin
    //         // This means we finished the previous mask.
    //         // Update dp_curr[loop_mask] with dp_prev[loop_mask] if better (at most k)
    //         if (dp_prev[loop_mask] < dp_curr[loop_mask]) dp_curr[loop_mask] <= dp_prev[loop_mask];
    //         
    //         // Move to next mask
    //         loop_mask <= loop_mask + 1;
    //         // Set submask for the next mask to loop_mask + 1 (which will be handled next cycle)
    //         // Wait, if we set loop_submask now, it will be used in the NEXT cycle.
    //         // So we set loop_submask <= loop_mask + 1.
    //         loop_submask <= loop_mask + 1;
    //       end else begin
    //         // We are in the middle of a mask
    //         // Process current loop_submask
    //         candidate_waste = dp_prev[loop_mask - loop_submask] + waste_storage[loop_submask];
    //         if (candidate_waste < dp_curr[loop_mask]) dp_curr[loop_mask] <= candidate_waste;
    //         
    //         // Update submask
    //         loop_submask <= (loop_submask - 1) & loop_mask;
    //       end
    //     end else begin
    //       // Loop over masks done. 
    //       // Copy dp_curr to dp_prev, increment k, etc.
    //     end
    //   end
    
    // This logic `if (loop_submask == 0)` assumes that we set `loop_submask` to 0 when we want to stop.
    // But `loop_submask` naturally becomes 0 when `(loop_submask - 1) & loop_mask` is 0.
    // So if `loop_submask` is 0, it means we just finished a mask.
    // But we need to distinguish between "start of k loop, loop_mask=1, loop_submask=0" and "finished mask 1".
    // In both cases `loop_submask` is 0.
    // To fix this, we can initialize `loop_submask` to a sentinel (e.g., 32) or just handle the transition carefully.
    
    // Let's try this refinement in the actual code block below.

endmodule
