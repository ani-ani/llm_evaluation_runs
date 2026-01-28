module dice_optimal_reroll (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] K,
    input wire [7:0] T,
    input wire [2:0] initial_dice [23:0],
    output reg [4:0] result,
    output reg done
);
    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LATCH = 4'd1;
    localparam [3:0] SORT = 4'd2;
    localparam [3:0] SORT_WAIT = 4'd3;
    localparam [3:0] DP_INIT = 4'd4;
    localparam [3:0] DP_OUTER = 4'd5;
    localparam [3:0] DP_INNER = 4'd6;
    localparam [3:0] DP_UPDATE = 4'd7;
    localparam [3:0] EVAL_INIT = 4'd8;
    localparam [3:0] EVAL_LOOP = 4'd9;
    localparam [3:0] EVAL_UPDATE = 4'd10;
    localparam [3:0] DONE_STATE = 4'd11;
    localparam [3:0] RESET_DP = 4'd12;

    reg [3:0] state, next_state;
    reg [4:0] r_K;
    reg [7:0] r_T;
    reg [2:0] sorted_dice [23:0];
    reg [2:0] dice_val;
    
    // Sorting variables
    reg [4:0] sort_idx;
    reg [4:0] sort_j;
    reg [2:0] temp_val;
    
    // DP variables
    reg [6:0] dp_sum_limit; // Max sum for d dice
    reg [7:0] current_d; // d from 1 to K
    reg [7:0] current_sum; // s from 1 to sum_limit
    reg [4:0] needed_sum;
    reg [4:0] kept_count;
    
    // DP Array: 145 elements of 64 bits
    // Using packed array for 2D logic
    reg [63:0] dp [144:0];
    reg [63:0] dp_next [144:0];
    reg [63:0] prev_ways;
    reg [63:0] temp_ways;
    reg [4:0] v_idx;
    
    // Evaluation variables
    reg [4:0] d_iter; // d from 0 to K
    reg [7:0] current_sum_kept;
    reg [4:0] needed;
    reg [63:0] best_prob;
    reg [4:0] best_d;
    reg [4:0] num_kept;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            r_K <= 5'd0;
            r_T <= 8'd0;
            for (i = 0; i < 24; i = i + 1) sorted_dice[i] <= 3'd0;
            sort_idx <= 5'd0;
            sort_j <= 5'd0;
            current_d <= 8'd0;
            current_sum <= 8'd0;
            needed_sum <= 4'd0;
            kept_count <= 5'd0;
            dp_sum_limit <= 7'd0;
            v_idx <= 5'd0;
            d_iter <= 5'd0;
            current_sum_kept <= 8'd0;
            needed <= 5'd0;
            best_prob <= 64'd0;
            best_d <= 5'd0;
            num_kept <= 5'd0;
            // Initialize dp array
            for (i = 0; i < 145; i = i + 1) begin
                dp[i] <= 64'd0;
                dp_next[i] <= 64'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LATCH;
                    end
                end
                
                LATCH: begin
                    r_K <= K;
                    r_T <= T;
                    // Latch initial dice
                    for (i = 0; i < 24; i = i + 1) begin
                        if (i < K)
                            sorted_dice[i] <= initial_dice[i];
                        else
                            sorted_dice[i] <= 3'd0;
                    end
                    state <= SORT;
                    sort_idx <= 5'd0;
                    sort_j <= 5'd0;
                end
                
                SORT: begin
                    // Bubble sort (descending)
                    // Outer loop: sort_idx from 0 to K-2
                    if (sort_idx < r_K - 5'd1) begin
                        // Inner loop: sort_j from 0 to K-sort_idx-2
                        if (sort_j < r_K - sort_idx - 5'd1) begin
                            if (sorted_dice[sort_j] < sorted_dice[sort_j + 5'd1]) begin
                                temp_val <= sorted_dice[sort_j];
                                sorted_dice[sort_j] <= sorted_dice[sort_j + 5'd1];
                                sorted_dice[sort_j + 5'd1] <= temp_val;
                            end
                            sort_j <= sort_j + 5'd1;
                            state <= SORT_WAIT;
                        end else begin
                            sort_j <= 5'd0;
                            sort_idx <= sort_idx + 5'd1;
                        end
                    end else begin
                        // Done sorting, init DP
                        current_d <= 8'd1;
                        state <= DP_INIT;
                    end
                end
                
                SORT_WAIT: begin
                    state <= SORT;
                end
                
                DP_INIT: begin
                    // Initialize DP for current d
                    // Reset dp_next to 0 for this iteration
                    for (i = 0; i < 145; i = i + 1) begin
                        dp_next[i] <= 64'd0;
                    end
                    
                    dp_sum_limit <= current_d * 6;
                    current_sum <= 4'd1; // Sums start at d (min value 1) 
                    // Actually min sum is d, max is 6d
                    // We iterate s from d to 6d
                    // Use current_sum as loop counter for sum value
                    current_sum <= current_d; // Start at sum = d
                    state <= DP_OUTER;
                end
                
                DP_OUTER: begin
                    // Loop over v (1 to 6)
                    v_idx <= 4'd1;
                    state <= DP_INNER;
                    // Fetch prev ways once before inner loop
                    // prev_ways = dp[current_sum - v_idx] if sum >= v_idx
                end
                
                DP_INNER: begin
                    // ways[d][s] += ways[d-1][s-v]
                    if (v_idx <= 4'd6) begin
                        if (current_sum >= v_idx) begin
                            prev_ways = dp[current_sum - v_idx];
                            temp_ways = dp_next[current_sum];
                            dp_next[current_sum] <= temp_ways + prev_ways;
                        end
                        v_idx <= v_idx + 4'd1;
                    end else begin
                        if (current_sum < dp_sum_limit) begin
                            current_sum <= current_sum + 8'd1;
                            state <= DP_OUTER;
                        end else begin
                            // Done for this d, update dp array
                            for (i = 0; i < 145; i = i + 1) begin
                                dp[i] <= dp_next[i];
                            end
                            
                            if (current_d < r_K) begin
                                current_d <= current_d + 8'd1;
                                state <= DP_INIT;
                            end else begin
                                // All DP done, start evaluation
                                // Precompute cumulative sums for kept dice
                                // sorted_dice is descending.
                                // Keep first num_kept (largest if below T, smallest if above T)
                                // Actually, to minimize variance/risk, we keep dice closest to 3.5?
                                // For sum T, we want sum(kept) as close to T as possible.
                                // If T is high, keep high dice. If T is low, keep low dice.
                                // But sorted_dice is descending (high to low).
                                // Sum kept (prefix sums):
                                // P[i] = sum(sorted_dice[0]...sorted_dice[i-1])
                                // We need to compute this on the fly or store.
                                // Let's store prefix sums in dp array (abusing memory) or compute iteratively.
                                // Let's compute iteratively in EVAL_INIT.
                                state <= EVAL_INIT;
                            end
                        end
                    end
                end
                
                EVAL_INIT: begin
                    d_iter <= 5'd0;
                    best_prob <= 64'd0;
                    best_d <= 5'd0;
                    current_sum_kept <= 8'd0;
                    state <= EVAL_LOOP;
                end
                
                EVAL_LOOP: begin
                    // For each d (number to re-roll)
                    // num_kept = r_K - d
                    // kept_sum = sum of first num_kept sorted dice (largest)
                    // OR sum of last num_kept sorted dice (smallest)?
                    // Strategy: To maximize chance of hitting T, keep dice that give sum close to T.
                    // For T > 3.5*K, we should keep the largest dice.
                    // For T < 3.5*K, we should keep the smallest dice.
                    // This is a simplified heuristic but works for the problem.
                    // Let's implement: if T > 3.5*K, keep largest. Else keep smallest.
                    // To keep logic simple: we assume we keep the 'best' subset.
                    // For the code, we will calculate two sums: sum_largest and sum_smallest
                    // and pick the one closer to T.
                    
                    num_kept <= r_K - d_iter;
                    // Calculate sum of kept dice based on T value
                    // We'll just compute sum of 'best' kept dice here.
                    // We need a way to sum specific elements.
                    // Let's just compute sum of first 'num_kept' elements (largest)
                    // and sum of last 'num_kept' elements (smallest).
                    // We'll pick the one closer to T.
                    
                    // To avoid complexity, we'll stick to a standard: 
                    // If we need to reduce sum (T < current_total), we keep smallest (re-roll largest).
                    // If we need to increase sum (T > current_total), we keep largest (re-roll smallest).
                    // Current total is sum of all initial dice.
                    // We need total sum first. Let's assume we computed it or compute on fly.
                    // For now, let's just compute sum of kept dice iteratively.
                    
                    // Let's compute sum of kept dice as sum of smallest 'num_kept' dice.
                    // sorted_dice is descending. So smallest are at the end.
                    // Indices: r_K-1 down to num_kept (if num_kept > 0)
                    
                    // Actually, let's just iterate d from 0 to K.
                    // For each d, calculate the optimal kept sum.
                    // We need to decide: re-roll d dice. Which ones?
                    // If we re-roll d dice, we keep K-d.
                    // If T is high, keep largest K-d.
                    // If T is low, keep smallest K-d.
                    
                    // Let's calculate kept_sum based on T.
                    // This requires summing up to 24 numbers.
                    // We can do this in a loop inside EVAL_UPDATE.
                    current_sum_kept <= 8'd0;
                    state <= EVAL_UPDATE;
                    // Loop variable for summing
                    i <= 0; // Reuse i for inner loop
                end
                
                EVAL_UPDATE: begin
                    // Sum kept dice
                    // Logic: if T is high, we keep largest.
                    // Let's assume T > 3*K (roughly > average) -> keep largest.
                    // If T <= 3*K -> keep smallest.
                    // This is a heuristic that simplifies the subset selection.
                    // For exact optimal, we'd need to check both, but this is usually correct.
                    
                    // Check if we should keep largest or smallest
                    // We'll calculate sum of largest 'num_kept' and smallest 'num_kept'
                    // and pick the one closer to T.
                    // But doing both is expensive. Let's just pick one strategy.
                    // Let's use the strategy: keep values that sum to T if possible.
                    // Actually, simpler: For a fixed d, the sum of kept dice is fixed
                    // ONLY IF we define which ones to keep.
                    // Let's define: we keep the 'best' values.
                    // If T > 3.5*K, keep largest. Else keep smallest.
                    
                    // To keep it simple and deterministic:
                    // We will calculate sum of first 'num_kept' (largest)
                    // AND sum of last 'num_kept' (smallest).
                    // We pick the sum closer to T.
                    // Since we can't do two loops easily, we do one loop to calculate prefix sums and suffix sums?
                    // No, let's just calculate sum of kept dice in one pass.
                    
                    // We'll just calculate sum of kept dice as follows:
                    // If we re-roll d dice, we keep K-d.
                    // Which ones? The ones that make the sum closest to T.
                    // Let's assume we keep the largest K-d.
                    // This is optimal when T is high. If T is low, we keep smallest.
                    // Let's just calculate sum of kept dice for the current strategy.
                    // Strategy: if T > 3*K (assuming average 3.5), keep largest.
                    // Else keep smallest.
                    // Let's use a flag. 
                    // This is getting complicated for a single loop.
                    
                    // Fallback: Iterate d from 0 to K.
                    // Calculate sum of kept dice (e.g., sum of first K-d sorted values).
                    // Calculate needed_sum = T - kept_sum.
                    // Check dp[K-d][needed_sum].
                    // This assumes we always keep the first K-d (largest).
                    // To fix for low T, we can also iterate d from 0 to K but assume we keep last K-d (smallest).
                    // The problem asks for the number of dice to re-roll.
                    // The 'which ones' is implicit in the strategy.
                    
                    // Let's implement: 
                    // For each d, we assume we re-roll the d dice that get us closest to T.
                    // If T is large, we re-roll small dice (keep large). sum = sum(largest K-d).
                    // If T is small, we re-roll large dice (keep small). sum = sum(smallest K-d).
                    // We can calculate both and pick the better one? 
                    // Or just pick one based on T.
                    
                    // Let's just iterate d.
                    // Calculate sum of kept dice based on a fixed strategy.
                    // Strategy: Keep the K-d dice with values closest to 3.5 (but sorted).
                    // Let's use: If T > 3*K, keep largest. Else keep smallest.
                    
                    // Let's calculate kept_sum.
                    // i is the index of the dice we are summing.
                    // If keep largest: indices 0 to num_kept-1.
                    // If keep smallest: indices r_K-num_kept to r_K-1.
                    
                    // We need to decide which strategy to use for this d.
                    // Let's just use the 'keep largest' strategy for simplicity.
                    // It covers the high T case. For low T, re-rolling d largest is same as keeping smallest.
                    // So if T is low, we might want to re-roll d large ones.
                    // That means keeping the others (small ones).
                    // So we need to sum the 'others'.
                    
                    // Let's do this: 
                    // We want to find d such that P(sum(re-roll d) = T) is max.
                    // We iterate d.
                    // We need to decide which subset of size K-d to keep.
                    // To maximize probability, we want the required sum for the re-rolled dice (T - kept_sum) 
                    // to be as 'average' as possible (mean 3.5d) and within range [d, 6d].
                    // Also variance matters, but DP handles that via counts.
                    
                    // Let's just sum the kept dice.
                    // Strategy: If T > 3.5 * K, keep largest. Else keep smallest.
                    // This is a heuristic. 
                    // Let's calculate sum_kept.
                    // We'll use 'i' as index.
                    // If i < num_kept, sum sorted_dice[i] (largest).
                    // If i >= r_K - num_kept, sum sorted_dice[i] (smallest).
                    
                    // Let's pick a strategy based on T.
                    // If T > 3*K, keep largest.
                    // Else keep smallest.
                    // Actually, just keep the K-d closest to T/K? 
                    // Let's stick to: Keep largest K-d.
                    // If T is very low, this might be bad, but the problem likely assumes reasonable T.
                    // Wait, if we keep largest, sum is max. Re-roll d -> need low sum.
                    // If we keep smallest, sum is min. Re-roll d -> need high sum.
                    
                    // Let's compute two sums: sum_largest and sum_smallest.
                    // We can't do both in one pass easily.
                    // Let's compute sum_kept.
                    // We'll just compute sum of first num_kept (largest).
                    // And if T is low, we will effectively re-roll large ones.
                    // Which means we should have kept small ones.
                    // So we need to check both cases.
                    
                    // Let's modify EVAL to calculate sum_kept for 'keep largest' 
                    // AND 'keep smallest'.
                    // We can store these sums in a small local reg.
                    
                    // Optimization: 
                    // Calculate prefix sums and suffix sums once after sorting.
                    // prefix[i] = sum(sorted_dice[0]...sorted_dice[i-1])
                    // suffix[i] = sum(sorted_dice[24-i]...sorted_dice[23])
                    // We can do this in a separate state or reuse DP array.
                    // Let's do it in a new state: PREP_EVAL.
                    state <= PREP_EVAL;
                    i <= 0;
                end
                
                PREP_EVAL: begin
                    // Compute prefix sums in dp array (abusing it again)
                    // dp[i] stores prefix sum of i+1 elements? 
                    // Let's use dp_next for prefix, dp for suffix (or vice versa).
                    // dp is 64-bit. prefix sums fit in 8-bit.
                    // Let's use dp[i] to store prefix sum of first i elements.
                    // dp[0] = 0.
                    // dp[i+1] = dp[i] + sorted_dice[i]
                    if (i < r_K) begin
                        if (i == 0) dp[0] <= 64'd0;
                        dp[i + 5'd1] <= dp[i] + sorted_dice[i];
                        i <= i + 5'd1;
                    end else begin
                        // Now suffix sums? Or compute on fly.
                        // We can compute suffix sums in another loop or just compute on fly.
                        // Let's compute suffix sums in dp_next.
                        // dp_next[0] = 0
                        // dp_next[i+1] = dp_next[i] + sorted_dice[r_K - 1 - i]
                        i <= 0;
                        state <= PREP_SUFFIX;
                    end
                end
                
                PREP_SUFFIX: begin
                    if (i < r_K) begin
                        if (i == 0) dp_next[0] <= 64'd0;
                        dp_next[i + 5'd1] <= dp_next[i] + sorted_dice[r_K - 5'd1 - i];
                        i <= i + 5'd1;
                    end else begin
                        // Ready for evaluation loop
                        d_iter <= 5'd0;
                        best_prob <= 64'd0;
                        best_d <= 5'd0;
                        state <= EVAL_LOOP_CHECK;
                    end
                end
                
                EVAL_LOOP_CHECK: begin
                    if (d_iter <= r_K) begin
                        // Calculate kept count
                        num_kept <= r_K - d_iter;
                        state <= EVAL_CALC_SUM;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                EVAL_CALC_SUM: begin
                    // We have two strategies:
                    // 1. Keep largest num_kept: sum = dp[num_kept]
                    // 2. Keep smallest num_kept: sum = dp_next[num_kept]
                    // We need to decide which one gives better probability.
                    // For a fixed d, we want required_sum = T - kept_sum.
                    // We want required_sum to be in range [d, 6d].
                    // If both are in range, we pick the one with higher probability.
                    // If only one is in range, pick that.
                    // If none, prob 0.
                    
                    // Let's compute required sums.
                    // req1 = T - dp[num_kept] (keep large)
                    // req2 = T - dp_next[num_kept] (keep small)
                    // Check bounds.
                    // Fetch probabilities from DP table (dp array holds counts for d dice).
                    // Note: dp array currently holds counts for ALL d.
                    // We populated dp incrementally.
                    // dp[d][s] is stored in... wait.
                    // My DP implementation used a single array 'dp' and updated it.
                    // So 'dp' currently contains counts for d=K dice.
                    // We lost counts for d=1...K-1.
                    // We need to store the DP table for all d.
                    // Max d=24. Max sum=144. 
                    // 24 * 145 * 8 bytes = ~27KB. Too big for standard FPGA BRAM usually, but might fit in logic.
                    // But let's assume we can't store full table.
                    // We can re-compute DP for each d on the fly during evaluation.
                    // Or we can store the DP results in a structured way.
                    // Since evaluation is sequential, we can compute DP for d=1, evaluate, d=2, evaluate, etc.
                    // This saves memory but takes more cycles.
                    // Let's change DP structure: Compute DP for current d, evaluate, then reset for d+1.
                    // This requires moving DP logic to EVAL phase.
                    // But we are already in EVAL phase.
                    
                    // Let's restart the logic.
                    // State: EVAL_INIT.
                    // For d from 0 to K:
                    //   Compute DP table for d dice (ways[d][s]).
                    //   Calculate kept_sum_large = sum(largest K-d).
                    //   Calculate kept_sum_small = sum(smallest K-d).
                    //   Calculate req_large = T - kept_sum_large.
                    //   Calculate req_small = T - kept_sum_small.
                    //   Check bounds.
                    //   Update best.
                    
                    // To implement this, we need to loop d in EVAL state.
                    // Inside loop, compute DP for d dice.
                    // Then evaluate.
                    
                    // Let's move to a state that computes DP for current d.
                    // We'll reuse DP_INIT logic but for specific d.
                    
                    // Since we are already far in code, let's try to fix the current path.
                    // We assumed we stored full table. We didn't.
                    // We must re-compute or store.
                    // Let's go back to DP_INIT and compute DP for ALL d and store in memory.
                    // To save memory, we can store only the counts for the specific sums we need.
                    // But we don't know sums yet.
                    
                    // Let's just store the full table.
                    // We need memory: [24:0][144:0] of 64 bits.
                    // 25 * 145 * 64 = 232,000 bits = 29KB. 
                    // This is large for LUTs but possible with BRAM.
                    // If we can't use BRAM, we recompute.
                    // Let's assume we recompute to be safe on LUTs.
                    
                    // Let's restart evaluation from EVAL_INIT.
                    // We will compute DP for each d inside the loop.
                    
                    // Reset d_iter to 0.
                    d_iter <= 5'd0;
                    best_prob <= 64'd0;
                    best_d <= 5'd0;
                    state <= EVAL_STEP;
                end

                EVAL_STEP: begin
                    // d_iter is current d (0 to K)
                    // If d == 0:
                    //   sum_kept = sum(all dice).
                    //   if sum_kept == T, prob = 1. else 0.
                    if (d_iter == 5'd0) begin
                        // Calculate sum of all dice
                        // We can use prefix sum dp[r_K]
                        // But we overwrote dp in PREP_SUFFIX.
                        // Let's recompute sum quickly or store it.
                        // We stored prefix sums in dp.
                        // dp[r_K] is sum of all.
                        if (dp[r_K] == r_T) begin
                            best_prob <= 64'd1;
                            best_d <= 5'd0;
                        end
                        d_iter <= d_iter + 5'd1;
                    end else begin
                        // d >= 1
                        // Compute DP for d dice.
                        // We need to compute ways[d][s] for s in [d, 6d].
                        // We only need ways[d][s] for s = T - kept_sum.
                        // But we have two candidate sums: kept_large, kept_small.
                        // Let's just compute the whole row for d. It's small (max 144).
                        // Then we look up.
                        
                        // Setup DP for d
                        current_d <= d_iter;
                        // Reset dp array for this d (reuse dp_next)
                        // Actually, we can compute iteratively.
                        // ways[1][s] = 1 if 1<=s<=6.
                        // ways[d][s] depends on ways[d-1].
                        // We need to store previous row.
                        // We can use dp_next for current row, dp for previous row.
                        
                        // Initialize for d=1
                        if (d_iter == 5'd1) begin
                            for (i = 0; i < 145; i = i + 1) begin
                                dp[i] <= 64'd0; // prev row (d-1=0)
                                if (i >= 1 && i <= 6) dp_next[i] <= 64'd1;
                                else dp_next[i] <= 64'd0;
                            end
                            // Copy to dp for next iteration
                            for (i = 0; i < 145; i = i + 1) dp[i] <= dp_next[i];
                        end else begin
                            // Compute row d from row d-1 (stored in dp)
                            // Row d stored in dp_next
                            // Init dp_next to 0
                            for (i = 0; i < 145; i = i + 1) dp_next[i] <= 64'd0;
                            current_sum <= d_iter;
                            state <= DP_COMPUTE_ROW;
                            // We need to wait for DP compute
                            // But we can't use the same state names easily.
                            // Let's use a dedicated sub-FSM for DP row computation.
                            // Or just inline it.
                        end
                        
                        // If d_iter > 1, go to compute state.
                        if (d_iter > 5'd1) state <= DP_COMPUTE_ROW;
                        else state <= EVAL_CHECK_RANGE;
                    end
                end

                DP_COMPUTE_ROW: begin
                    // Compute dp_next[current_sum] = sum(dp[current_sum - v]) for v=1..6
                    // Loop v
                    // We need a temp accumulator.
                    // Let's use v_idx and accumulator in local vars.
                    // Since we can't easily do local vars in always block, use registers.
                    // We'll use `prev_ways` as accumulator.
                    // We need to reset accumulator for each sum.
                    
                    // This state is triggered for each sum s.
                    // We iterate s from d to 6d.
                    // For each s, sum over v=1..6.
                    
                    // Let's use a nested loop structure.
                    // Outer loop: s = d to 6d
                    // Inner loop: v = 1 to 6
                    // We can use `current_sum` for s and `v_idx` for v.
                    // `prev_ways` can be accumulator.
                    
                    if (current_sum <= (d_iter * 6)) begin
                        if (v_idx <= 4'd6) begin
                            // Add dp[current_sum - v_idx] to accumulator
                            if (current_sum >= v_idx) begin
                                prev_ways <= prev_ways + dp[current_sum - v_idx];
                            end
                            v_idx <= v_idx + 4'd1;
                        end else begin
                            // Done inner loop, store result
                            dp_next[current_sum] <= prev_ways;
                            // Reset accumulator
                            prev_ways <= 64'd0;
                            // Next s
                            current_sum <= current_sum + 8'd1;
                            v_idx <= 4'd1;
                        end
                    end else begin
                        // Done computing row d
                        // Copy dp_next to dp (for next d)
                        for (i = 0; i < 145; i = i + 1) dp[i] <= dp_next[i];
                        state <= EVAL_CHECK_RANGE;
                    end
                end

                EVAL_CHECK_RANGE: begin
                    // Now dp_next holds ways for current d (or dp, depending on copy timing).
                    // Actually, we copied to dp. So dp holds ways for current d.
                    // We need to check kept sums.
                    // kept_sum_large = prefix[num_kept] (stored in dp array? No, we overwrote dp)
                    // We lost prefix/suffix sums when we used dp for DP table.
                    // We need to store prefix/suffix sums somewhere.
                    // We can store prefix sums in a separate register array or BRAM.
                    // Let's allocate a small RAM for prefix sums.
                    // Or just recompute sum of kept dice on the fly.
                    // It's only 24 elements.
                    // Let's recompute.
                    
                    // Calculate sum_large and sum_small.
                    // We can do this in a loop.
                    i <= 0;
                    // We need two accumulators. Let's use prev_ways and temp_ways.
                    prev_ways <= 64'd0; // sum_large
                    temp_ways <= 64'd0; // sum_small
                    state <= EVAL_CALC_KEPT_SUM;
                end

                EVAL_CALC_KEPT_SUM: begin
                    // Loop i from 0 to num_kept-1 for large
                    // Loop i from 0 to num_kept-1 for small (indices r_K-1-i)
                    if (i < num_kept) begin
                        prev_ways <= prev_ways + sorted_dice[i]; // Sum largest
                        temp_ways <= temp_ways + sorted_dice[r_K - 5'd1 - i]; // Sum smallest
                        i <= i + 5'd1;
                    end else begin
                        // We have sums.
                        // Check bounds and probabilities.
                        // req_large = T - prev_ways
                        // req_small = T - temp_ways
                        // Check if req_large in [d_iter, 6*d_iter]
                        // Check if req_small in [d_iter, 6*d_iter]
                        // Fetch prob from dp[req] (dp holds ways for d_iter)
                        
                        // We need to handle the case where req is out of bounds.
                        // Let's compute req.
                        // We'll use `needed` register.
                        
                        // Strategy: Check req_large first.
                        // If valid, get prob.
                        // Check req_small.
                        // If valid, get prob.
                        // Compare.
                        
                        // Let's start with req_large.
                        // req = T - prev_ways
                        // Note: T is 8-bit, prev_ways is 64-bit (but small value).
                        // Cast to signed or handle carefully.
                        // Since sums are small, we can cast.
                        
                        // We need to compute: is (T - sum) in [d, 6d]?
                        // Let's store T - sum in `needed_sum`.
                        // If T < sum, result is negative. Use signed arithmetic.
                        
                        // Let's do req_large.
                        needed_sum <= r_T - prev_ways[7:0]; // Assuming sum fits in 8 bits
                        // Check range.
                        // needed_sum >= d_iter && needed_sum <= 6*d_iter
                        // AND needed_sum >= 0 (handled by unsigned comparison if cast properly, but T-sum might underflow)
                        // Let's use signed logic.
                        
                        state <= EVAL_CHECK_REQ_LARGE;
                    end
                end

                EVAL_CHECK_REQ_LARGE: begin
                    // Check if req_large is valid
                    // valid = (needed_sum >= d_iter) && (needed_sum <= 6*d_iter) && (needed_sum >= 0)
                    // Since needed_sum is unsigned here (cast from subtraction), underflow wraps to large value.
                    // We need to handle negative results.
                    // If r_T < prev_ways, needed_sum > 255.
                    // So check if r_T >= prev_ways.
                    
                    if (r_T >= prev_ways[7:0]) begin
                        needed_sum <= r_T - prev_ways[7:0];
                        // Now check range
                        if ((r_T - prev_ways[7:0]) >= d_iter && (r_T - prev_ways[7:0]) <= (d_iter * 6)) begin
                            // Valid. Fetch prob.
                            // prob = dp[needed_sum]
                            // Update best
                            if (dp[needed_sum] > best_prob) begin
                                best_prob <= dp[needed_sum];
                                best_d <= d_iter;
                            end else if (dp[needed_sum] == best_prob) begin
                                if (d_iter < best_d) begin
                                    best_d <= d_iter;
                                end
                            end
                        end
                    end
                    // Now check req_small
                    // req_small = r_T - temp_ways
                    state <= EVAL_CHECK_REQ_SMALL;
                end

                EVAL_CHECK_REQ_SMALL: begin
                    if (r_T >= temp_ways[7:0]) begin
                        needed_sum <= r_T - temp_ways[7:0];
                        if ((r_T - temp_ways[7:0]) >= d_iter && (r_T - temp_ways[7:0]) <= (d_iter * 6)) begin
                            if (dp[needed_sum] > best_prob) begin
                                best_prob <= dp[needed_sum];
                                best_d <= d_iter;
                            end else if (dp[needed_sum] == best_prob) begin
                                if (d_iter < best_d) begin
                                    best_d <= d_iter;
                                end
                            end
                        end
                    end
                    // Next d
                    if (d_iter < r_K) begin
                        d_iter <= d_iter + 5'd1;
                        state <= EVAL_STEP;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= best_d;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
