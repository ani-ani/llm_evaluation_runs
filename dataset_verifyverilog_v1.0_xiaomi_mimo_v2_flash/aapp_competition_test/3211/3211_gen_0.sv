module voting_system #(
    parameter N = 8,                    // Number of citizens (max 8)
    parameter DATA_WIDTH = 2            // Bits per citizen: 0,1,2 encoded as 2-bit
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    // Input array: individual ports for each element
    input wire [DATA_WIDTH-1:0] arr_0,
    input wire [DATA_WIDTH-1:0] arr_1,
    input wire [DATA_WIDTH-1:0] arr_2,
    input wire [DATA_WIDTH-1:0] arr_3,
    input wire [DATA_WIDTH-1:0] arr_4,
    input wire [DATA_WIDTH-1:0] arr_5,
    input wire [DATA_WIDTH-1:0] arr_6,
    input wire [DATA_WIDTH-1:0] arr_7,
    output reg done,
    output reg impossible,
    output reg [7:0] min_swaps
);

    // Internal state and registers
    reg [N*DATA_WIDTH-1:0] input_reg;  // Latched input
    reg [7:0] cost_reg;
    reg imp_reg;
    reg [N-1:0] subset;                // Current subset of positions for tellers
    reg [3:0] teller_count;            // Number of tellers in input
    reg [3:0] original_teller_pos [0:N-1]; // Original positions of tellers
    reg [3:0] state;                   // State machine state
    reg [N-1:0] loop_idx;              // Loop index for subset iteration
    reg [3:0] sim_idx;                 // Index for simulation loop
    reg [3:0] vote1, vote2;            // Vote counters during simulation
    reg [3:0] points1, points2;        // Points counters
    reg [3:0] target_teller_pos [0:N-1]; // Target teller positions for current subset
    reg [3:0] target_teller_count;     // Number of tellers in target
    reg [7:0] current_cost;
    reg [7:0] best_cost;
    reg valid_found;
    reg [2:0] i;                       // Loop variable
    reg [2:0] j;                       // Loop variable

    // States
    localparam IDLE = 0;
    localparam INIT = 1;
    localparam ITERATE = 2;
    localparam SIMULATE = 3;
    localparam CALC_COST = 4;
    localparam UPDATE = 5;
    localparam FINISHED = 6;

    // Combinational helper logic
    wire [N-1:0] bits_set;
    wire [3:0] bit_count;
    wire [N-1:0] valid_subset;
    wire [3:0] target_teller_count_comb;
    wire [3:0] target_teller_pos_comb [0:N-1];
    wire [3:0] points1_comb;
    wire [3:0] points2_comb;
    wire [7:0] current_cost_comb;
    wire points1_gt_points2;

    // Count bits set in subset
    assign bits_set = subset;
    assign bit_count = bits_set[0] + bits_set[1] + bits_set[2] + bits_set[3] + 
                       bits_set[4] + bits_set[5] + bits_set[6] + bits_set[7];
    assign valid_subset = (bit_count == teller_count);

    // Build target teller positions based on subset
    // For each i, if subset[i] is set, target_teller_pos is i
    // else, it's a non‑teller, so not tracked here.
    // We'll compute target_teller_count_comb and target_teller_pos_comb array
    always @(*) begin
        target_teller_count_comb = 0;
        for (i = 0; i < N; i = i + 1) begin
            target_teller_pos_comb[i] = 0;
            if (subset[i]) begin
                target_teller_pos_comb[target_teller_count_comb] = i;
                target_teller_count_comb = target_teller_count_comb + 1;
            end
        end
    end

    // Simulation: determine election outcome and points
    // We need to simulate the process:
    // 1. Build the actual sequence with tellers in target positions.
    // 2. Run the round: two non‑teller adjacent pairs, then two tellers.
    //    This is simplified; for exact, we need to simulate per the problem.
    //    We'll assume a helper function to simulate.
    //    For this code, we'll compute in combinational block.

    // To compute points and cost, we need to know:
    // - The resulting sequence after swapping
    // - The election result
    // - The cost (swaps needed)

    // Simplified simulation:
    // Since we are moving tellers to subset positions, we can compute:
    // - The resulting sequence is not needed explicitly for points, only positions.
    // - But for election, we need the order of non‑tellers.
    //   Order of non‑tellers is preserved.
    //   We can compute the indices of non‑tellers in the original array.
    //   Let's store original non‑teller values and positions.
    //   This is getting complex, so we'll implement a combinational block
    //   that does the simulation using a for‑loop over 2 steps (since only 2 non‑teller pairs + 2 tellers).

    // Pre‑compute original teller positions and non‑teller values
    wire [DATA_WIDTH-1:0] non_teller_values [0:N-1];
    wire [3:0] non_teller_count;
    wire [3:0] original_non_teller_pos [0:N-1];

    // Helper to extract values
    // We'll compute original teller count, teller positions, non‑teller values
    reg [3:0] temp_teller_count;
    reg [3:0] temp_non_teller_count;
    always @(*) begin
        temp_teller_count = 0;
        temp_non_teller_count = 0;
        for (i = 0; i < N; i = i + 1) begin
            case (input_reg[DATA_WIDTH*i +: DATA_WIDTH])
                2'd0: begin // Citizen 0
                    original_non_teller_pos[temp_non_teller_count] = i;
                    non_teller_values[temp_non_teller_count] = 2'd0;
                    temp_non_teller_count = temp_non_teller_count + 1;
                end
                2'd1: begin // Citizen 1
                    original_non_teller_pos[temp_non_teller_count] = i;
                    non_teller_values[temp_non_teller_count] = 2'd1;
                    temp_non_teller_count = temp_non_teller_count + 1;
                end
                2'd2: begin // Citizen 2 (Teller)
                    original_teller_pos[temp_teller_count] = i;
                    temp_teller_count = temp_teller_count + 1;
                end
                default: begin end
            endcase
        end
    end
    assign non_teller_count = temp_non_teller_count;

    // Simulation Logic
    // We need to determine points1 and points2.
    // The process:
    // - Adjacent non‑teller pairs compete.
    // - Then the two tellers compete.
    // To compute this, we need to know the values at the positions after swapping.
    // Since we only move tellers, the non‑tellers stay in their relative order.
    // We can map the "effective" positions.
    // Let's create the effective sequence for simulation.
    // This is 2D array; Icarus Verilog limitation: cannot have unpacked array of arrays easily in combinational.
    // So, we'll compute on the fly.

    // To avoid 2D unpacked arrays in wires, we compute points in combinational logic
    // by iterating through the target subset and matching to original non‑tellers.

    // We'll define a combinational block that computes points1_comb, points2_comb, points1_gt_points2
    // This block will be large but must be flattenable.

    // We need to know: for each of the 4 steps, who is voting?
    // Step 1: first adjacent non‑teller pair
    //   -> non_teller_values[0] and non_teller_values[1]
    //   -> UNLESS a teller occupies the position before non_teller_values[0] or between them?
    //   -> Actually, the positions are fixed by the subset.
    //   -> We need to check: is position p in the subset?
    //   -> If yes, it's a teller.
    //   -> If no, it's the next non‑teller in sequence.
    //   -> This requires mapping position to teller/non‑teller.

    // Let's implement the simulation step by step in combinational logic.

    wire [DATA_WIDTH-1:0] voter1_step1;
    wire [DATA_WIDTH-1:0] voter2_step1;
    wire [DATA_WIDTH-1:0] voter1_step2;
    wire [DATA_WIDTH-1:0] voter2_step2;
    wire [DATA_WIDTH-1:0] voter1_step3;
    wire [DATA_WIDTH-1:0] voter2_step3;
    wire [DATA_WIDTH-1:0] voter1_step4;
    wire [DATA_WIDTH-1:0] voter2_step4;

    // To find voters at specific "positions" in the sequence:
    // We iterate through original array. If position is in subset -> teller (2).
    // Else -> next non‑teller.
    // We need to find the first 4 non‑tellers in the sequence.
    // But wait, the sequence has tellers inserted.
    // We need to scan positions 0 to 7.
    // We can't use dynamic pointers in combinational easily.
    // Instead, we compute the voter for each of the 4 steps based on the subset.
    // This is a mapping problem: given a target index in the final sequence (0..7),
    // what is the value?
    //   If target_index is in subset -> teller (2).
    //   Else -> it's the k-th non‑teller in original order.

    // Helper: is_position_teller(pos)
    // Wire: is_teller[pos] = subset[pos];
    // We need to find the k-th non‑teller.
    // We can pre-compute the mapping for each position to its value.
    wire [DATA_WIDTH-1:0] seq_val [0:N-1];
    reg [3:0] non_teller_idx;
    always @(*) begin
        non_teller_idx = 0;
        for (i = 0; i < N; i = i + 1) begin
            if (subset[i]) begin
                seq_val[i] = 2'd2; // Teller
            end else begin
                seq_val[i] = non_teller_values[non_teller_idx];
                non_teller_idx = non_teller_idx + 1;
            end
        end
    end

    // Now we can extract voters for steps.
    // The process:
    // Step 1: voters at seq_val[0] and seq_val[1] (if they exist)
    // Step 2: voters at seq_val[2] and seq_val[3]
    // Step 3: voters at seq_val[4] and seq_val[5]
    // Step 4: voters at seq_val[6] and seq_val[7]
    // BUT: The problem says: 2 adjacent non‑teller pairs vote, then 2 tellers vote.
    // This implies:
    //   - Find first non‑teller pair (consecutive non‑tellers).
    //   - Find second non‑teller pair (consecutive non‑tellers).
    //   - Then two tellers.
    // This is not simply taking first 4 elements.
    // We need to scan for non‑teller pairs.

    // Let's refine simulation logic:
    // 1. Identify indices of non‑tellers in seq_val.
    // 2. Identify indices of tellers in seq_val.
    // 3. Points for non‑teller pairs:
    //    - Look for first i where seq_val[i] != 2 and seq_val[i+1] != 2.
    //    - These are voters A and B. A == 1 adds 1 to points1, B == 1 adds 1 to points2.
    //    - Look for next j > i+1 where seq_val[j] != 2 and seq_val[j+1] != 2.
    //    - These are voters C and D.
    // 4. Points for tellers:
    //    - If there are at least 2 tellers in seq_val, they compete.
    //    - Add points (tellers are value 2, but how do they vote? The problem says "tellers do not vote" but here they are competitors? Wait.)
    //    - Reread: "Two adjacent non‑teller citizens vote, and then two tellers vote."
    //    - Aha! Tellers DO vote in the final step.
    //    - But tellers are value 2. How do they vote? 2? Or 1? Or 0?
    //    - The problem says "citizens are 0, 1, 2 (teller)".
    //    - "Non‑teller citizens vote" (value 0 or 1).
    //    - "Tellers vote" -> this is confusing.
    //    - Let's assume: 
    //      - Step 1,2: non‑teller pairs (values 0 or 1).
    //      - Step 3,4: teller pairs (value 2).
    //    - If teller votes as 2? Or does "vote" mean "compete"?
    //    - "The one with value 1 gets 1 point."
    //    - If teller is 2, does it get 0 points? or 1 point? or 2 points?
    //    - Usually in such problems, 2 might be neutral or hidden.
    //    - Let's assume Tellers vote as 0 (or don't contribute to points).
    //    - But wait, if they vote and value is 2, and rule is "value 1 gets point", then 2 gets 0.
    //    - However, "total of points of their citizens suggests voters for 1".
    //    - Let's assume: 
    //      - Non‑teller pair: 1 vs 0 -> 1 gets point. 1 vs 1 -> tie? 0 vs 0 -> tie?
    //      - Teller pair: 2 vs 2 -> tie? 2 vs 0 -> 0 gets point? (if 0 is non‑teller).
    //    - But the sequence is 4 pairs. 2 non‑teller pairs, 2 teller pairs.
    //    - If we have tellers in the sequence, they take positions.
    //    - The voting order depends on positions.
    //    - This is very specific.

    // Let's simplify based on typical coding problems:
    // We have a sequence of length N.
    // We iterate i from 0 to N-2 (step 2):
    //   if (seq_val[i] != 2 && seq_val[i+1] != 2) -> non‑teller pair.
    //   else if (seq_val[i] == 2 && seq_val[i+1] == 2) -> teller pair.
    //   else -> mixed? (Might not happen if logic is strict).
    // We only care about first 4 pairs? Or all?
    // "Two adjacent non‑teller citizens vote, and then two tellers vote."
    // This implies exactly 2 non‑teller pairs and 2 teller pairs in the process.
    // The positions of these pairs in the sequence depend on where tellers are.
    // We need to identify these 4 specific pairs in the sequence.

    // Algorithm for simulation:
    // 1. Build seq_val.
    // 2. Scan seq_val for non‑teller pairs.
    //    - Keep count of non_teller_pairs_found.
    //    - When found, calculate points.
    //    - Stop when 2 pairs found.
    // 3. Scan seq_val for teller pairs.
    //    - Keep count of teller_pairs_found.
    //    - When found, calculate points (how do tellers vote?).
    //    - Assume tellers vote as 0? Or value 2 gets point only if 1?
    //    - If tellers are 2, and rule is "value 1 gets point", then 2 gets 0.
    //    - Let's assume 2 never gets a point (neutral).
    //    - So for teller pair 2 vs 2 -> 0 points each.
    //    - For teller pair 2 vs 0 -> 0 vs 0 points?
    //    - Let's assume the "value 1" rule applies strictly.
    //    - So 2 is not 1, so no point for 2.
    //    - But then how do tellers "vote"? They just exist.
    //    - Maybe the "value" for teller voting is 1? Or 0?
    //    - Let's stick to the simplest: 
    //      - Non‑teller pair (0,1): 1 gets point. (0 vs 1 -> 1 wins).
    //      - Teller pair (2,2): Tie (0 points each).
    //      - Teller pair (2, x): If x is non‑teller, it's not a pure pair.
    //      - The problem says "Two adjacent non‑teller citizens vote, and then two tellers vote."
    //      - This implies the pairs are homogeneous.
    //      - So we must have a sequence where non‑tellers cluster and tellers cluster.
    //      - Given N=8, we just need to find such subsequences.

    // Revised Simulation Logic (Combinational):
    // Input: seq_val[0..7]
    // Output: points1, points2

    reg [3:0] p1, p2;
    reg [2:0] ntp_found; // non‑teller pairs found
    reg [2:0] tp_found;  // teller pairs found
    reg [1:0] pair_val1, pair_val2;

    always @(*) begin
        p1 = 0;
        p2 = 0;
        ntp_found = 0;
        tp_found = 0;
        
        // Scan for non‑teller pairs
        for (i = 0; i < N-1 && ntp_found < 2; i = i + 1) begin
            if (seq_val[i] != 2'd2 && seq_val[i+1] != 2'd2) begin
                // Check if already counted (avoid double counting overlapping pairs? No, pairs are distinct)
                // Actually, if we have 0 0 0, pairs are (0,1) and (1,2). Overlapping?
                // "Adjacent non‑teller citizens" implies distinct pairs.
                // We increment i by 2 to skip to next pair.
                // But what if sequence is 0 0 1 0? Pairs (0,1) and (2,3).
                // Let's just take disjoint pairs.
                if (ntp_found == 0) begin
                    pair_val1 = seq_val[i];
                    pair_val2 = seq_val[i+1];
                    if (pair_val1 == 2'd1) p1 = p1 + 1;
                    if (pair_val2 == 2'd1) p2 = p2 + 1;
                    ntp_found = ntp_found + 1;
                    i = i + 1; // Skip next element (so i increments to i+2)
                end else begin
                    // Second pair
                    pair_val1 = seq_val[i];
                    pair_val2 = seq_val[i+1];
                    if (pair_val1 == 2'd1) p1 = p1 + 1;
                    if (pair_val2 == 2'd1) p2 = p2 + 1;
                    ntp_found = ntp_found + 1;
                    i = i + 1;
                end
            end
        end

        // Scan for teller pairs (only if we found 2 non‑teller pairs)
        if (ntp_found == 2) begin
            for (i = 0; i < N-1 && tp_found < 2; i = i + 1) begin
                if (seq_val[i] == 2'd2 && seq_val[i+1] == 2'd2) begin
                    if (tp_found == 0) begin
                        // Teller pair voting logic?
                        // If value 1 gets point, and teller is 2, no point.
                        // If tellers vote as 1? Unlikely.
                        // Let's assume 2 is neutral. 0 points.
                        // If 2 is considered "1" for voting? 
                        // Let's check problem: "The one with value 1 gets 1 point."
                        // It doesn't say "The one with value > 0".
                        // So 2 does not get a point.
                        // However, if 2 vs 2, both get 0.
                        // What if 2 vs 1? But we filtered for teller pairs (both 2).
                        // So 0 points for teller pairs.
                        // BUT, the problem says "Tellers vote". 
                        // Maybe they vote for themselves? 
                        // If they vote and value is 2, and "value 1 gets point", then 2 gets 0.
                        // This makes tellers neutral.
                        // Let's assume 0 points for teller pairs.
                        // (If it turns out 2 gets a point, we change `p1 = p1 + 1`).
                        // Let's assume 2 gets a point. Why else would they vote?
                        // Let's assume: 
                        //   - Non‑teller 1 gets point.
                        //   - Teller 2 gets point.
                        //   - 0 gets nothing.
                        // This is the most logical for a "voting" system where 2 is a distinct group.
                        // If 2 votes for itself, it gets a point.
                        // If 2 vs 2, both get points.
                        // If 2 vs 0, 2 gets point.
                        // Wait, problem says "The one with value 1 gets 1 point."
                        // It specifically mentions 1. It does NOT mention 2.
                        // So 2 probably does not get a point.
                        // But then "Tellers vote" is useless.
                        // Maybe "Tellers vote" means they add to the points of the winner?
                        // Or maybe the points for teller pairs are determined by something else?
                        // Let's re-read: "Two adjacent non‑teller citizens vote, and then two tellers vote."
                        // "The one with value 1 gets 1 point."
                        // This rule applies to the voting process.
                        // So when tellers vote, the one with value 1 gets 1 point.
                        // But tellers are 2.
                        // So if two tellers vote, neither is 1. So 0 points?
                        // This seems odd.
                        // Let's assume: 
                        //   In non‑teller pairs: 1 gets point.
                        //   In teller pairs: 2 gets point.
                        //   Or maybe 2 is "value 1" equivalent?
                        //   Let's assume 2 gets a point. It's the most symmetric.
                        p1 = p1 + 1; // Arbitrary assignment for now? 
                        // Wait, in teller pair (2,2), who gets the point?
                        // If both are 2, and 2 gets a point, then both get 1 point?
                        // Or is it a tie? "The one with value 1 gets 1 point" implies exactly one gets a point?
                        // No, "The one" suggests if there is a 1, it gets a point.
                        // If both are 1? Then both get a point? Or only one?
                        // Usually "The one" implies singular, but in voting, both could have value 1.
                        // Let's assume if value == 1 (or 2 for tellers), that voter gets 1 point.
                        // So 2 vs 2 -> p1+=1, p2+=1.
                        // 1 vs 0 -> p1+=1, p2+=0.
                        
                        // Given the ambiguity, I will implement:
                        // - For non‑teller: value 1 adds point.
                        // - For teller: value 2 adds point.
                        // This makes 0 always get 0 points.

                        // For teller pair (2, 2):
                        p1 = p1 + 1;
                        p2 = p2 + 1;

                        tp_found = tp_found + 1;
                        i = i + 1;
                    end else begin
                        // Second teller pair
                        p1 = p1 + 1;
                        p2 = p2 + 1;
                        tp_found = tp_found + 1;
                        i = i + 1;
                    end
                end
            end
        end
    end

    assign points1_comb = p1;
    assign points2_comb = p2;
    assign points1_gt_points2 = (points1_comb > points2_comb);

    // Cost Calculation
    // Cost = sum |original_teller_pos[i] - target_teller_pos[i]| for sorted tellers
    // We have original_teller_pos[0..teller_count-1] (sorted by nature of iteration)
    // We have target_teller_pos_comb[0..teller_count-1] (sorted by construction)
    always @(*) begin
        current_cost = 0;
        for (j = 0; j < teller_count; j = j + 1) begin
            if (original_teller_pos[j] > target_teller_pos_comb[j]) begin
                current_cost = current_cost + (original_teller_pos[j] - target_teller_pos_comb[j]);
            end else begin
                current_cost = current_cost + (target_teller_pos_comb[j] - original_teller_pos[j]);
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            impossible <= 0;
            min_swaps <= 0;
            state <= IDLE;
            subset <= 0;
            teller_count <= 0;
            cost_reg <= 0;
            imp_reg <= 0;
            best_cost <= 8'hFF;
            valid_found <= 0;
            input_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    impossible <= 0;
                    min_swaps <= 0;
                    best_cost <= 8'hFF;
                    valid_found <= 0;
                    subset <= 0;
                    teller_count <= 0;
                    if (start) begin
                        state <= INIT;
                        // Latch input
                        input_reg <= {arr_7, arr_6, arr_5, arr_4, arr_3, arr_2, arr_1, arr_0};
                    end
                end

                INIT: begin
                    // Count tellers
                    teller_count <= 0;
                    for (i = 0; i < N; i = i + 1) begin
                        if (input_reg[DATA_WIDTH*i +: DATA_WIDTH] == 2'd2) begin
                            teller_count <= teller_count + 1;
                        end
                    end
                    // Start subset iteration
                    subset <= 0;
                    state <= ITERATE;
                end

                ITERATE: begin
                    // Check if we have processed all subsets (0 to 255)
                    // We use loop_idx as the subset value.
                    // If subset < 256, proceed to simulation.
                    // Note: We need a register for loop_idx/subset.
                    // We'll use subset register for the value.
                    // To iterate, we increment subset.
                    // First time, subset is 0.
                    // We need to check if subset has correct bit count.
                    // We computed bit_count in combinational.
                    // But bit_count depends on subset.
                    // We need to update subset register.
                    // Let's use loop_idx separate from subset.
                    // subset holds the current subset mask.
                    // loop_idx is 0..255.
                    if (loop_idx < 8'd256) begin
                        // Check bit count
                        if (bit_count == teller_count) begin
                            state <= SIMULATE;
                        end else begin
                            // Skip this subset
                            state <= UPDATE;
                        end
                    end else begin
                        state <= FINISHED;
                    end
                end

                SIMULATE: begin
                    // We use combinational logic for simulation.
                    // Just transition to CALC_COST where we use the results.
                    state <= CALC_COST;
                end

                CALC_COST: begin
                    // Check if valid (points1 > points2) and update best
                    if (points1_gt_points2) begin
                        valid_found <= 1;
                        if (current_cost < best_cost) begin
                            best_cost <= current_cost;
                        end
                    end
                    state <= UPDATE;
                end

                UPDATE: begin
                    // Increment subset and loop_idx
                    subset <= subset + 1;
                    loop_idx <= loop_idx + 1;
                    state <= ITERATE;
                end

                FINISHED: begin
                    done <= 1;
                    if (valid_found) begin
                        impossible <= 0;
                        min_swaps <= best_cost;
                    end else begin
                        impossible <= 1;
                        min_swaps <= 0;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule