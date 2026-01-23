module lcm_tree_counter(
    input clk,
    input rst_n,
    input start,
    input [31:0] values [0:7],
    input [3:0] node_count,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // Parameters
    parameter MOD = 1000000007;
    parameter MAX_NODES = 8;
    parameter MAX_STATES = 256;

    // State Machine States
    localparam IDLE = 3'b000;
    localparam LOAD_VALUES = 3'b001;
    localparam CHECK_POPCOUNT = 3'b010;
    localparam CHECK_LCM = 3'b011;
    localparam ACCUMULATE = 3'b100;
    localparam NEXT_SUBSET = 3'b101;
    localparam NEXT_MASK = 3'b110;
    localparam FINISHED = 3'b111;

    // Registers
    reg [2:0] state;
    reg [7:0] mask;              // Current mask S
    reg [7:0] submask;           // Current submask L
    reg [7:0] root_bit;          // Current root bit candidate
    reg [7:0] left_set;          // L
    reg [7:0] right_set;         // R
    reg [31:0] dp [0:MAX_STATES-1]; // DP table
    reg [31:0] internal_values [0:MAX_NODES-1]; // Local copy of values
    reg [31:0] temp_product;     // For multiplication
    reg [31:0] temp_sum;         // For addition accumulator
    reg [3:0] popcnt;            // Popcount of mask
    reg [3:0] bit_idx;           // Iterator for bits
    reg [3:0] root_idx;          // Index of root node
    reg [3:0] left_idx;          // Index of left root (from left_set)
    reg [3:0] right_idx;         // Index of right root (from right_set)
    reg start_processing;        // Latch start signal

    // GCD Module Signals
    reg [31:0] gcd_a, gcd_b;
    wire [31:0] gcd_result;
    wire gcd_done;
    reg gcd_start;
    reg gcd_active;

    // LCM Computation Signals
    reg [31:0] lcm_val1, lcm_val2;
    wire [31:0] lcm_result;
    wire lcm_done;
    reg lcm_start;
    reg lcm_active;
    reg [31:0] lcm_mult1, lcm_mult2;
    wire [31:0] lcm_mult_res;
    reg mult_start;
    reg mult_active;
    wire mult_done;

    // Sub-modules for Math
    // Euclidean GCD
    gcd_mod u_gcd (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_start),
        .a(gcd_a),
        .b(gcd_b),
        .result(gcd_result),
        .done(gcd_done)
    );

    // Modular Multiplication (for LCM calculation)
    mult_mod u_mult (
        .clk(clk),
        .rst_n(rst_n),
        .start(mult_start),
        .a(lcm_mult1),
        .b(lcm_mult2),
        .result(lcm_mult_res),
        .done(mult_done)
    );

    // Internal LCM State Machine (controlled by main FSM)
    reg [2:0] lcm_state;
    localparam LCM_IDLE = 0;
    localparam LCM_GCD = 1;
    localparam LCM_MULT = 2;
    localparam LCM_DIV = 3;
    localparam LCM_DONE = 4;
    
    reg [63:0] lcm_a_64, lcm_b_64, lcm_gcd_64;
    wire [63:0] lcm_prod_64 = lcm_a_64 * lcm_b_64;
    wire [63:0] lcm_final_64 = lcm_prod_64 / lcm_gcd_64;

    // DP Logic Variables
    integer i;
    reg [7:0] check_mask;
    reg [7:0] check_l;
    reg [7:0] check_r;
    reg valid_partition;
    reg [31:0] dp_L;
    reg [31:0] dp_R;
    reg [31:0] product;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
            start_processing <= 0;
            gcd_start <= 0;
            lcm_start <= 0;
            mult_start <= 0;
            // Reset DP table
            for (i = 0; i < MAX_STATES; i = i + 1) begin
                dp[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        start_processing <= 1;
                        state <= LOAD_VALUES;
                    end
                end

                LOAD_VALUES: begin
                    // Load inputs to internal storage
                    // Since inputs are arrays, we map them iteratively
                    // We will use a counter or assume 1 cycle load? 
                    // Usually inputs are valid during start.
                    // Let's load in 1 cycle or use bit_idx
                    if (bit_idx < node_count) begin
                        internal_values[bit_idx] <= values[bit_idx];
                        bit_idx <= bit_idx + 1;
                    end else begin
                        bit_idx <= 0;
                        // Initialize DP
                        // Base case: masks with 1 bit set are valid (1 way)
                        // We can pre-fill or do in FSM. Let's do in FSM.
                        // Actually, DP[mask] for single bit should be 1.
                        // But we don't know node_count yet. We can do it in CHECK_POPCOUNT.
                        // For simplicity, let's initialize DP[0] = 0 (though unused) and handle singletons.
                        state <= NEXT_MASK;
                        mask <= 1;
                    end
                end

                NEXT_MASK: begin
                    // Loop mask from 1 to 2^n - 1
                    if (mask < (8'b1 << node_count)) begin
                        // Check if mask has odd popcount
                        popcnt <= 0;
                        bit_idx <= 0;
                        check_mask <= mask;
                        state <= CHECK_POPCOUNT;
                    end else begin
                        // Done
                        result <= dp[(8'b1 << node_count) - 1];
                        done <= 1;
                        valid <= 1;
                        state <= FINISHED;
                    end
                end

                CHECK_POPCOUNT: begin
                    if (bit_idx < node_count) begin
                        if (check_mask[bit_idx]) popcnt <= popcnt + 1;
                        bit_idx <= bit_idx + 1;
                    end else begin
                        if (popcnt[0]) begin // Odd
                            // Initialize dp[mask] to 0 if not already (it should be 0)
                            if (popcnt == 1) begin
                                // Base case: singleton
                                dp[mask] <= 1;
                                state <= NEXT_MASK;
                                mask <= mask + 1;
                            end else begin
                                // Start partition search
                                submask <= (mask - 1) & mask; // Start with a valid submask
                                state <= NEXT_SUBSET;
                            end
                        end else begin
                            // Even popcount, skip
                            state <= NEXT_MASK;
                            mask <= mask + 1;
                        end
                    end
                end

                NEXT_SUBSET: begin
                    // Iterate submasks L of mask
                    // Rule: L is non-empty, L != mask
                    // We iterate L, then R = mask ^ L ^ (1 << root)
                    // But we need to try all possible roots in R.
                    // To simplify: Iterate L, then iterate root in R.
                    
                    if (submask > 0 && submask < mask) begin
                        left_set <= submask;
                        right_set <= mask ^ submask;
                        bit_idx <= 0;
                        state <= CHECK_LCM;
                    end else begin
                        // No more submasks
                        state <= NEXT_MASK;
                        mask <= mask + 1;
                    end
                end

                CHECK_LCM: begin
                    // We need to check: Is there a root in right_set such that
                    // LCM(values(LeftTree), values(RightTree)) == values(root)?
                    // Wait, the spec says: LCM(values[LeftSet], values[RightSet]) == values[root].
                    // This implies the ROOT value determines the LCM.
                    // So we iterate root in right_set.
                    // Find next bit in right_set
                    while (bit_idx < node_count && !right_set[bit_idx]) begin
                        bit_idx <= bit_idx + 1;
                    end
                    
                    if (bit_idx < node_count) begin
                        // Found a candidate root
                        root_idx <= bit_idx;
                        // Calculate LCM of children sets
                        // But wait, LCM(values[LeftSet], values[RightSet])... 
                        // Do we need the LCM of ALL values in Left and ALL values in Right?
                        // "LCM(values[LeftSet], values[RightSet])"
                        // Usually this means LCM of the roots of the subtrees.
                        // But the problem description says "Iterate submask L... Check if LCM(values[LeftSet], values[RightSet]) == values[root]".
                        // This is ambiguous. If it means LCM of all values in the sets, it's computationally heavy for general logic, but n=8.
                        // However, typically in LCM tree problems, the LCM constraint is between the immediate children roots.
                        // Given the structure of LCM trees, if T is a tree with root r, children a and b, LCM(a,b) = r.
                        // And subtrees must also satisfy LCM.
                        // The DP state needs to know the root value of the tree formed by mask.
                        // But the problem asks for "count ways to arrange n nodes".
                        // If we just sum dp[L]*dp[R], we assume the root is fixed for the partition.
                        // The condition LCM(values[LeftSet], values[RightSet]) == values[root] suggests we need the LCM of the root values of the subtrees.
                        // Since we are iterating subsets, we don't know the root of the subtree in the DP table? 
                        // Wait, DP[S] stores the count. It doesn't store the root value.
                        // BUT, the transition is: dp[S] += dp[L] * dp[R] if LCM(val(L_root), val(R_root)) == val(S_root).
                        // This implies we need to know possible root values for a subset.
                        // However, the spec says: "LCM(values[LeftSet], values[RightSet])". 
                        // If it meant roots, it would be ambiguous which root.
        // Spec: "Valid partition criteria: ... LCM(values[LeftSet], values[RightSet]) == values[root]."
        // Perhaps it means LCM of the root values of the subtrees? 
        // Let's re-read: "Iterate submask L... Let R = mask ^ L | single_bit_for_root... Check if LCM... == values[root]"
        // If R is the rest of the set, it includes the root.
        // So: "Let R = mask ^ (L | single_bit_for_root)".
        // This means we pick a root bit from mask. Remove it. Then pick L. Then R is the rest.
        // But iterating submask L of mask... if we fix L, we need to pick a root from mask^L.
        // Then we check LCM(val(L_root), val(R_root)) == val(root).
        // Wait, the spec says: "LCM(values[LeftSet], values[RightSet])".
        // If LeftSet and RightSet are the sets of nodes, not just the root, then we need LCM of all values in LeftSet and all values in RightSet.
        // Let's assume that means the LCM of the ROOTS of the Left and Right subtrees.
        // But we don't know the roots.
        // Alternative interpretation: The "values" array is the values of the nodes. 
        // The tree structure determines which node is root. 
        // DP[S] is sum over partitions.
        // Let's look at the test case: {7,7,7}. Roots can be 7. Children 7. LCM(7,7)=7.
        // If values are distinct, say {2,3,6}. Possible trees? Root 6, children 2 and 3. LCM(2,3)=6.
        // So we need to pick root r in S. Then partition S\{r} into L and R.
        // Then check LCM( r_L, r_R ) == r_r? No.
        // The condition is on the tree: if Root=R, LeftChild=L, RightChild=R, then LCM(Val(LeftChild), Val(RightChild)) == Val(Root).
        // But LeftChild is the root of the subtree L.
        // So we need to iterate over possible roots of L and R.
        // This turns into a O(3^n * k) or similar complexity.
        // But n=8, we can handle it.
        // So, for fixed S, iterate root r in S. Iterate partition of S\{r} into L, R.
        // Iterate root l in L, root rr in R.
        // If LCM(val(l), val(rr)) == val(r), then dp[S] += dp[L] * dp[R].
        // However, the specification says: "Check if LCM(values[LeftSet], values[RightSet]) == values[root]."
        // If "values[LeftSet]" means the value of the node chosen as root for LeftSet.
        // And "values[root]" means the value of the node chosen as root for S.
        // Let's go with: We pick a root r for S. Then we partition the rest.
        // We iterate submask L of S\{r}. 
        // Then we iterate root l in L, root rr in R.
        // Check LCM(val(l), val(rr)) == val(r).
        // Accumulate dp[L] * dp[R].
        // But wait, dp[L] counts ALL valid trees for L. We need to sum over all valid roots of L?
        // No, dp[L] is the total count. We sum dp[L]*dp[R] over partitions where there exists AT LEAST ONE valid pair of roots (l, rr) satisfying LCM(l, rr) == r.
        // But usually, for counting trees, the sum is:
        // dp[S] = sum_{r in S} sum_{partition (L,R) of S\{r}} [ indicator(valid structure) * dp[L] * dp[R] ]
        // If the validity depends on the specific roots, we need to sum over roots.
        // Actually, standard formula for binary trees: dp[S] = sum_{r in S} (sum_{L subset of S\{r}} dp[L] * dp[S\{r}\L]) but usually children are ordered.
        // Here children are unordered? Or ordered? Spec doesn't say.
        // Given it's a tree, usually Left and Right are distinct positions.
        // So order matters.
        // So: dp[S] = sum_{r in S} sum_{L subset of S\{r}, L != S\{r}} dp[L] * dp[S\{r}\L] * valid(r, L, R).
        // But valid(r, L, R) needs root of L and root of R.
        // Wait, dp[L] includes count of trees. 
        // Summing dp[L]*dp[R] over partitions assumes we just glue them to root.
        // If we need to check LCM condition, we need to know roots of L and R.
        // We need a modified DP: dp[S] = count.
        // Let's stick to the simplest interpretation that fits the prompt and allows synthesis.
        // "LCM(values[LeftSet], values[RightSet])".
        // Maybe it means the LCM of the *values in the sets*, not the roots?
        // If values are {2, 6, 3}. S = {2, 3, 6}. 
        // If we take r=6, L={2}, R={3}. LCM(2, 3) = 6 == 6. Valid.
        // If we take r=2, L={3}, R={6}. LCM(3, 6) = 6 != 2. Invalid.
        // If values are {2, 4, 6}. 
        // r=6, L={2}, R={4}. LCM(2,4)=4 != 6. Invalid.
        // r=4, L={2}, R={6}. LCM(2,6)=6 != 4.
        // r=2, L={4}, R={6}. LCM(4,6)=12 != 2.
        // So no trees? That seems strict.
        // What if L contains multiple nodes? LCM of set.
        // L={2,3}, R={6}. LCM(2,3,6)=6.
        // LCM of sets is usually defined as LCM of all elements.
        // If that's the case:
        // We need to compute LCM of all values in L and all values in R.
        // Then check == values[r].
        // This is computationally expensive but n=8.
        // Let's proceed with this interpretation: 
        // For a fixed S, r, L, R.
        // Compute L_LCM = LCM of all values in L.
        // Compute R_LCM = LCM of all values in R.
        // Check LCM(L_LCM, R_LCM) == values[r].
        // If yes, valid partition. Then dp[S] += dp[L] * dp[R].
        // 
        // Implementation plan:
        // State NEXT_SUBSET: we have mask S, submask L.
        // R = mask ^ L. (But we need to remove root? No, prompt says: "Let R = mask ^ (L | single_bit_for_root)". This means R is the set containing the rest, excluding root? No, it says "Let R = mask ^ (L | single_bit_for_root)". If mask includes root, L and single_bit_for_root are in mask. So R = mask - (L U {root}).
        // So R is the RightChildSet. It does not contain root.
        // But we iterate L. 
        // Prompt: "Iterate submask L of mask (excluding 0 and mask). Let R = mask ^ (L | single_bit_for_root)".
        // This implies we iterate L, and we also iterate "single_bit_for_root".
        // So for a fixed mask S:
        // Iterate root bit r_bit in S.
        // Iterate submask L of (S \ {r_bit}).
        // R = (S \ {r_bit}) ^ L.
        // Check validity.
        // 
        // Refining State Machine:
        // NEXT_MASK: Iterate S.
        // If popcount odd:
        //    Iterate r_bit in S. (Set root_idx).
        //    Set remaining = S ^ (1 << r_idx).
        //    Iterate L submask of remaining.
        //    Check validity.
        //    Accumulate.
        // 
        // Complexity: 256 masks. For each, ~8 roots. ~2^7 submasks. 
        // 256 * 8 * 128 = 262,144 iterations. 
        // 10,000 cycles is tight if we need to compute LCM of sets in a few cycles.
        // We need to be very optimized.
        // 
        // LCM of a set calculation:
        // L_LCM = 1;
        // For each val in L: L_LCM = LCM(L_LCM, val).
        // This requires iterative GCD/Mult.
        // If we do this in HW, it takes cycles.
        // But maybe we can precompute LCMs for all subsets?
        // 256 subsets. 
        // LCM_S = LCM of all values in subset S.
        // Precompute table LCM_Subset[256].
        // Then validity check is: LCM( LCM_Subset[L], LCM_Subset[R] ) == values[root].
        // This is much faster!
        // Let's add a PRECOMPUTE state.
        // 
        // PRECOMPUTE_LCM:
        // Iterate subsets s from 1 to 2^n-1.
        // Compute LCM of values in s.
        // Store in lcm_subset[s].
        // This takes time. 256 * (up to 8 * cycles for GCD/Mult).
        // We can do this in IDLE or a new state.
        // 
        // New State Machine:
        // IDLE -> PRECOMPUTE_LCM -> ITERATE_MASKS -> DONE.
        // PRECOMPUTE_LCM: 
        //    Loop s = 1 to 255.
        //    For each s, if popcount(s) == 1, lcm = val[bit].
        //    Else, pick one bit i, s_without_i = s ^ (1<<i).
        //    lcm[s] = LCM(lcm[s_without_i], val[i]).
        //    This is a DP for LCM too! 
        //    (Note: LCM is associative/commutative, so this works).
        //    We need an iterative calculator for LCM(s_without_i, val[i]).
        //    We can use the GCD/Mult modules.
        // 
        // ITERATE_MASKS:
        //    Standard DP. 
        //    For S:
        //    For r in S:
        //       rem = S ^ (1<<r).
        //       For L submask of rem (non-empty): 
        //          R = rem ^ L.
        //          If (LCM(lcm_subset[L], lcm_subset[R]) == val[r])
        //             dp[S] += dp[L] * dp[R].
        // 
        // Optimization:
        // Since LCM(lcm_subset[L], lcm_subset[R]) == val[r] is the check.
        // We can precompute this check? No, depends on r.
        // But we can quickly check: if lcm_subset[L] % val[r] != 0 ... wait, no.
        // We need exact equality.
        // We will compute LCM(L_sub, R_sub) and compare to val[r].
        // Since we have precomputed lcm_subset[L] and lcm_subset[R], we just need one LCM calculation per partition.
        // 
        // Let's consolidate the FSM.
        
        // -- FSM LOGIC --
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Load values into internal_values (simultaneous or iterated)
                    internal_values[0] <= values[0]; internal_values[1] <= values[1];
                    internal_values[2] <= values[2]; internal_values[3] <= values[3];
                    internal_values[4] <= values[4]; internal_values[5] <= values[5];
                    internal_values[6] <= values[6]; internal_values[7] <= values[7];
                    // Initialize DP and LCM tables
                    for (i = 0; i < 256; i = i + 1) dp[i] <= 0;
                    // Precompute LCM subset
                    mask <= 1; // Start subset iterator for LCM precompute
                    state <= PRECOMPUTE_LCM;
                end
            end

            PRECOMPUTE_LCM: begin
                // We need a sub-FSM to compute LCM for current 'mask'
                // We can use the LCM calculator logic here.
                // Since we need to compute LCM(mask) from a sub-item, we need to iterate bits.
                // Strategy: For mask, find first set bit i. Sub = mask ^ (1<<i).
                // If Sub == 0, lcm = val[i].
                // Else, lcm = LCM(lcm[Sub], val[i]).
                // 
                // This requires us to know lcm[Sub]. Since we iterate mask from 1 up, Sub < Mask.
                // So lcm[Sub] is already computed.
                // 
                if (mask < (8'b1 << node_count)) begin
                    // Compute LCM for this mask
                    // Find first bit
                    bit_idx <= 0;
                    while (!mask[bit_idx]) bit_idx <= bit_idx + 1;
                    // We need to start the LCM calculation: LCM(lcm[mask ^ bit], val[bit])
                    // We need to fetch lcm[mask ^ bit].
                    // Since we are iterating increasing masks, we can assume it's ready.
                    // However, Verilog indexing requires care.
                    // Let's just use a comb block for the 'finding bit' part or do it sequentially.
                    // Let's do a sequential step to set up inputs for LCM calc.
                    if (mask == 1) begin
                        // Special case: single bit
                        lcm_subset[mask] <= values[0]; // Wait, need to map bit 0 to values[0]...
                        // Actually, mask bits correspond to indices 0..7.
                        // Find index of bit:
                        // We can use a loop or priority encoder.
                        // Let's assume bit_idx found in previous cycle or compute now.
                        // To keep it simple: We use a helper loop state.
                        state <= PRECOMP_FIND_BIT;
                    end else begin
                        state <= PRECOMP_FIND_BIT;
                    end
                end else begin
                    // Done precompute. Reset for DP.
                    mask <= 1;
                    dp[1] <= 1; // Base case: singletons. Wait, we need to do this for all singletons.
                    // Actually, DP for singletons is 1. 
                    // We will initialize them in the DP loop or here.
                    // Let's set dp[1<<i] = 1.
                    if (bit_idx < node_count) begin
                        dp[1 << bit_idx] <= 1;
                        bit_idx <= bit_idx + 1;
                    end else begin
                        mask <= 1;
                        state <= ITERATE_MASKS_START;
                    end
                end
            end

            PRECOMP_FIND_BIT: begin
                // Find index of a bit in mask (any bit, e.g., the one corresponding to internal_values index)
                // Actually, we need a deterministic way to split mask.
                // LCM(a,b) = LCM(b,a). Order doesn't matter.
                // We can take any bit. Let's take the LSB.
                // Find LSB index.
                for (i = 0; i < 8; i = i + 1) begin
                    if (mask[i]) begin
                        bit_idx <= i;
                        // We need a way to break the loop. 
                        // In hardware, we can use a priority encoder logic or just use a combinational block.
                        // Let's use a comb block for the index finding in the always block? No.
                        // Use a fixed cycle.
                        // Since we are in a sequential block, let's just use the index we found.
                    end
                end
                // Wait, for loop in synthesis generates hardware. It creates logic.
                // We need to transition state.
                // Let's use a 'next' state.
                state <= PRECOMP_CALC_LCM;
            end

            PRECOMP_CALC_LCM: begin
                // mask has bit 'bit_idx' set.
                // sub = mask ^ (1<<bit_idx)
                // target = internal_values[bit_idx]
                // if sub == 0: lcm = target
                // else: lcm = LCM(lcm[sub], target)
                
                if (mask == (8'b1 << bit_idx)) begin
                    // Single bit
                    lcm_subset[mask] <= internal_values[bit_idx];
                    state <= PRECOMP_NEXT;
                end else begin
                    // Need LCM
                    // Load inputs for LCM calculator
                    // But we need to be careful about the LCM calculator FSM.
                    // We can just inline the logic here or call a sub-sequence.
                    // Let's call a sub-sequence: CALC_LCM
                    // Inputs: val1 = lcm_subset[sub], val2 = internal_values[bit_idx]
                    // Outputs: result -> lcm_subset[mask]
                    
                    // Setup LCM state machine
                    lcm_a_64 <= {32'b0, lcm_subset[mask ^ (8'b1 << bit_idx)]};
                    lcm_b_64 <= {32'b0, internal_values[bit_idx]};
                    lcm_state <= LCM_IDLE;
                    state <= DO_LCM_SUB;
                end
            end

            DO_LCM_SUB: begin
                // Sub-state for LCM calculation
                case (lcm_state)
                    LCM_IDLE: begin
                        // Start GCD
                        if (lcm_a_64 == 0 || lcm_b_64 == 0) begin
                             lcm_subset[mask] <= 0; // Or 1? Usually LCM(0,x) is 0 or undefined. Assume 0.
                             state <= PRECOMP_NEXT;
                        end else begin
                             gcd_a <= lcm_a_64[31:0]; // Lower 32 bits are enough for GCD inputs? 
                             gcd_b <= lcm_b_64[31:0]; // Values are 32-bit.
                             gcd_start <= 1;
                             lcm_state <= LCM_GCD;
                        end
                    end
                    LCM_GCD: begin
                        gcd_start <= 0;
                        if (gcd_done) begin
                            lcm_gcd_64 <= {32'b0, gcd_result};
                            // Calculate product (a*b)
                            // Use mult module
                            mult_mult1 <= lcm_a_64[31:0];
                            mult_mult2 <= lcm_b_64[31:0];
                            mult_start <= 1;
                            lcm_state <= LCM_MULT;
                        end
                    end
                    LCM_MULT: begin
                        mult_start <= 0;
                        if (mult_done) begin
                            // Result is product % MOD. BUT we need actual product for LCM formula (a*b)/gcd.
                            // Spec says modulo arithmetic for additions/mults. 
                            // But for LCM check, we need actual value.
                            // However, values are up to 10^9. Product fits in 64 bits.
                            // The mult_mod module computes (a*b)%MOD. We can't use that.
                            // We need a 64-bit multiplier.
                            // Since we are in PRECOMPUTE, we can just do 64-bit multiply in logic.
                            // `wire [63:0] prod = a * b;` is valid in synthesis.
                            // Let's do that directly.
                            // lcm_prod_64 is a wire defined outside.
                            // lcm_final_64 is wire.
                            // So we can just assign result.
                            // But wait, if we do (a*b)/gcd, we might exceed 32-bit for LCM.
                            // But we need to check equality to values[root] (32-bit).
                            // So if LCM > 2^32, it can't equal values[root].
                            // So we can compute it in 64 bits and check.
                            // 
                            // We need to wait for the combinational path? 
                            // Let's just compute it.
                            // lcm_final_64 is available now.
                            if (lcm_final_64[63:32] != 0) begin
                                // LCM too large, can't match 32-bit value
                                // We can flag it or store a value > MAX_VAL.
                                // Let's store 0 (invalid) or a marker.
                                // If lcm > 2^32-1, it's not equal to any 32-bit input.
                                // So we can set it to 0.
                                lcm_subset[mask] <= 0;
                            end else begin
                                lcm_subset[mask] <= lcm_final_64[31:0];
                            end
                            state <= PRECOMP_NEXT;
                        end
                    end
                endcase
            end

            PRECOMP_NEXT: begin
                mask <= mask + 1;
                state <= PRECOMPUTE_LCM;
            end

            ITERATE_MASKS_START: begin
                // Determine range: 1 to (1<<node_count)-1
                if (mask < (8'b1 << node_count)) begin
                    // Check popcount odd
                    if (popcount(mask) & 1) begin
                        // Start partitioning
                        // If popcount == 1, dp=1 (already set)
                        if (popcount(mask) == 1) begin
                            mask <= mask + 1;
                            state <= ITERATE_MASKS_START;
                        end else begin
                            // Iterate roots
                            bit_idx <= 0;
                            state <= ITERATE_ROOTS;
                        end
                    end else begin
                        mask <= mask + 1;
                    end
                end else begin
                    state <= FINISHED;
                end
            end

            ITERATE_ROOTS: begin
                // Find root in mask
                // We need to iterate bits of mask for root
                // Loop until we find a set bit
                if (bit_idx < node_count) begin
                    if (mask[bit_idx]) begin
                        // Found root candidate
                        // rem = mask ^ (1<<bit_idx)
                        submask <= (mask ^ (8'b1 << bit_idx));
                        // Start iterating submasks of rem for LeftChildSet
                        // We iterate submask L of rem.
                        // Note: L must be non-empty. 
                        // Also, we need to avoid double counting (L,R) vs (R,L) if children are unordered?
                        // If ordered, iterate all L != rem.
                        // If unordered, we need to restrict L to be e.g. smaller than R.
                        // Spec doesn't say. Usually trees treat Left/Right as distinct.
                        // Let's assume ordered to be safe.
                        
                        // Initialize submask iterator for L
                        // To iterate submasks of 'rem':
                        // Start with L = rem & -rem (lowest bit) or (rem-1)&rem.
                        // Let's use standard iteration: L = rem; while(L) L = (L-1) & rem.
                        // We need to start. 
                        // Also we need to consider the case where L is empty? No, binary tree node has 0, 1, or 2 children.
        // Spec doesn't explicitly say. Let's assume valid trees must use all nodes in S.
        // And binary tree: can have 0, 1, or 2 children.
        // But if we have 1 child, the other set is empty.
        // If L empty, R = rem. 
        // Then we need to check LCM(val(empty), val(R)) == val(root).
        // Usually LCM(empty) is 1? Or 0? 
        // Let's assume only valid partitions where both L and R are non-empty.
        // Because the problem mentions LeftChildSet and RightChildSet.
        // So we skip empty sets.
        
                        // Start submask iteration for L
                        // L < rem to avoid L = rem (where R = empty)
                        // Actually, we need L to be a subset of rem. 
                        // We can iterate L = (rem-1) & rem down to 1.
                        submask <= (rem - 1) & rem;
                        state <= ITERATE_SUBSETS;
                    end else begin
                        bit_idx <= bit_idx + 1;
                    end
                end else begin
                    // No more roots
                    mask <= mask + 1;
                    state <= ITERATE_MASKS_START;
                end
            end

            ITERATE_SUBSETS: begin
                // submask = L (LeftChildSet)
                // rem = mask ^ (1<<root_idx)
                // R = rem ^ L
                // Check validity
                if (submask > 0 && submask < rem) begin // rem is local to this context? No, need to store rem.
                    // Check validity: LCM(lcm_subset[L], lcm_subset[R]) == values[root]
                    // R = rem ^ submask
                    // Need to calculate LCM(lcm_subset[submask], lcm_subset[rem ^ submask])
                    // and compare to internal_values[bit_idx] (current root).
                    
                    // Setup LCM calc
                    lcm_a_64 <= {32'b0, lcm_subset[submask]};
                    lcm_b_64 <= {32'b0, lcm_subset[rem ^ submask]};
                    // rem needs to be stored in a register for this stage
                    // Let's use a temp register.
                    // 'submask' holds L. We need R.
                    // We need to store 'rem' which is mask ^ (1<<root_idx).
                    // Let's use 'check_l' to store rem temporarily? 
                    // Or just recalculate R.
                    // We need to know 'mask' and 'root_idx' and 'submask'.
                    // Let's use 'right_set' register to store rem.
                    // We set right_set in ITERATE_ROOTS.
                    // 
                    // Check: 
                    // If lcm_a == 0 or lcm_b == 0, invalid (unless target is 0).
                    // Compute LCM.
                    
                    if (lcm_subset[submask] == 0 || lcm_subset[rem ^ submask] == 0) begin
                         // Skip, invalid partition or LCM undefined
                         // Move to next submask
                         state <= NEXT_SUBMASK_LOOP;
                    end else begin
                        // Start LCM
                        gcd_a <= lcm_subset[submask];
                        gcd_b <= lcm_subset[rem ^ submask];
                        gcd_start <= 1;
                        state <= CHECK_ACCUM_PREP;
                    end
                end else begin
                    // Done submask iteration for this root
                    bit_idx <= bit_idx + 1;
                    state <= ITERATE_ROOTS;
                end
            end

            CHECK_ACCUM_PREP: begin
                // Wait for GCD
                gcd_start <= 0;
                if (gcd_done) begin
                    // Compute Product (a*b). Use combinational wire.
                    // Need to verify product fits 64-bit.
                    // Calculate (a*b)/gcd
                    // We need to be careful about division. 
                    // If result > 2^32, it won't match 32-bit value.
                    // We can do: if ( (a*b)/gcd == target )
                    // We can compute it in 64-bit logic.
                    // 
                    // We need to register the result or use comb logic.
                    // Let's assume a comb block or just use the wires.
                    // But we are in a sequential block. 
                    // We need to wait for the calculation or do it in logic.
                    // Since GCD is done, we can compute.
                    // But we need to check equality.
                    // Let's use the combinational wires defined at top.
                    // lcm_prod_64 = a*b
                    // lcm_final_64 = (a*b)/gcd
                    // But we need to assign inputs to the wires.
                    // The wires are global. We can assign them in combinational logic.
                    // Let's create a combinational block for the check or do it here.
                    // If we do it here, we need to wait for the multiplication?
                    // No, `a*b` is combinational. 
                    // So `lcm_final_64` is ready.
                    // We can check immediately.
                    
                    // Check: lcm_final_64 == internal_values[bit_idx]
                    // But bit_idx is the root index.
                    // We need to store root value in a temp register.
                    // Let's use 'temp_product' to store root value.
                    
                    // Let's use a combinational check.
                    // If valid, accumulate dp[L] * dp[R].
                    
                    // We need to fetch dp[L] and dp[R].
                    // L = submask. R = rem ^ submask.
                    // 'right_set' should have been stored in ITERATE_ROOTS.
                    // Let's use 'right_set' to store rem.
                    // Actually, in ITERATE_ROOTS, we can set 'right_set = mask ^ (1<<bit_idx)'.
                    // Then here R = right_set ^ submask.
                    
                    // Check validity:
                    // Use a combinational block for LCM result.
                    // Or just do the math in logic if possible.
                    // Since we are in FSM, let's use a temporary state to latch the comparison result.
                    
                    // We need to ensure the multiplication a*b doesn't overflow 64 bits.
                    // 10^9 * 10^9 = 10^18. 2^64 ~ 1.8e19. Safe.
                    // Division is exact.
                    
                    // We need to wait for the combinational logic to settle or just use it.
                    // In Verilog, we can use it.
                    
                    // Let's assume we do the check here.
                    // But we need to define the wires.
                    // The wires 'lcm_prod_64' and 'lcm_final_64' depend on 'lcm_a_64', 'lcm_b_64', 'lcm_gcd_64'.
                    // We updated lcm_a/b in ITERATE_SUBSETS. 
                    // We updated lcm_gcd_64 in LCM_GCD state (which we skipped? No, we are doing GCD now).
                    // Wait, we are in state CHECK_ACCUM_PREP. We just did GCD.
                    // So 'lcm_gcd_64' is valid.
                    // But 'lcm_a_64' and 'lcm_b_64' were set in ITERATE_SUBSETS.
                    // So we are good.
                    
                    // Logic:
                    // if (lcm_final_64 == internal_values[bit_idx]) valid = 1.
                    // But we need to be careful. lcm_final_64 is 64-bit. internal_values is 32-bit.
                    // So we check upper bits 0 and compare lower bits.
                    
                    // Wait, we need to check LCM(L,R) == Root_Value.
                    // LCM(L,R) = lcm_final_64.
                    
                    // Now we need to add dp[L] * dp[R] to dp[mask].
                    // dp[sum] needs modulo arithmetic.
                    // So we need to compute product = dp[submask] * dp[right_set ^ submask].
                    // Then sum = dp[mask] + product.
                    
                    // We need to fetch dp values.
                    // dp[submask] and dp[right_set ^ submask].
                    // 
                    // Let's store dp[submask] and dp[...] in registers.
                    // Then perform multiplication using mult_mod.
                    // Then addition.
                    
                    // Check validity first.
                    if (lcm_final_64[63:32] == 0 && lcm_final_64[31:0] == internal_values[bit_idx]) begin
                        // Valid partition
                        dp_L <= dp[submask];
                        dp_R <= dp[right_set ^ submask];
                        // Start multiplication
                        mult_mult1 <= dp[submask];
                        mult_mult2 <= dp[right_set ^ submask];
                        mult_start <= 1;
                        state <= ACCUMULATE;
                    end else begin
                        // Invalid
                        state <= NEXT_SUBMASK_LOOP;
                    end
                end
            end

            ACCUMULATE: begin
                mult_start <= 0;
                if (mult_done) begin
                    // product = mult_res
                    // dp[mask] = (dp[mask] + product) % MOD
                    // We need to add to dp[mask].
                    // But we might have multiple valid partitions for the same mask.
                    // So we need to accumulate into dp[mask].
                    // BUT dp[mask] is a register.
                    // We can read dp[mask], add, write back.
                    // Since we are iterating partitions, we need to add to the current value.
                    // So we need to fetch dp[mask] + product.
                    // Let's use a temporary sum register.
                    // Actually, we can do:
                    // temp_sum = dp[mask] + mult_res
                    // dp[mask] <= temp_sum % MOD.
                    // Wait, we need to handle the modulo.
                    // mult_res is already modulo MOD.
                    // dp[mask] is modulo MOD.
                    // Sum can be up to 2*MOD.
                    // So temp_sum = dp[mask] + mult_res.
                    // If temp_sum >= MOD, subtract MOD.
                    // 
                    // We need to read dp[mask].
                    // 'mask' is the current outer loop mask.
                    // We need to update dp[mask].
                    
                    // Let's use a combinational adder.
                    // Or just do it here.
                    // reg [31:0] current_dp = dp[mask];
                    // reg [31:0] add_val = mult_res;
                    // reg [31:0] next_dp = current_dp + add_val;
                    // if (next_dp >= MOD) next_dp -= MOD;
                    // dp[mask] <= next_dp;
                    
                    // But wait, in ACCUMULATE state, we are inside the loops.
                    // We need to update dp[mask] and then go to next submask.
                    // We need to be careful that multiple cycles to update dp[mask] might be slow, but acceptable.
                    // 
                    // Let's update dp[mask].
                    if (dp[mask] + mult_mod_result >= MOD)
                        dp[mask] <= dp[mask] + mult_mod_result - MOD;
                    else
                        dp[mask] <= dp[mask] + mult_mod_result;
                    
                    state <= NEXT_SUBMASK_LOOP;
                end
            end

            NEXT_SUBMASK_LOOP: begin
                // submask = (submask - 1) & rem
                // We need 'rem' stored.
                // Let's assume 'right_set' holds rem (from ITERATE_ROOTS).
                if (submask == 0) begin
                    // Should not happen if we loop properly, but safety
                    state <= ITERATE_ROOTS; // Or next root
                    bit_idx <= bit_idx + 1;
                end else begin
                    submask <= (submask - 1) & right_set;
                    state <= ITERATE_SUBSETS;
                end
            end

            FINISHED: begin
                done <= 1;
                valid <= 1;
                // Result already assigned in ITERATE_MASKS_START end
                if (!start) begin // Wait for start to go low to reset? Or keep high.
                    // Just stay here.
                end
            end
        endcase
        end
    end

    // Helper Logic for popcount (combinational or sequential)
    // We used sequential popcount in CHECK_POPCOUNT.

    // Combinational Logic for LCM calculation in FSM
    // We defined lcm_prod_64 and lcm_final_64 as wires.
    // We need to connect them properly.
    // But inside FSM, we assigned lcm_a_64, lcm_b_64, lcm_gcd_64.
    // The wire assignments:
    // assign lcm_prod_64 = lcm_a_64 * lcm_b_64;
    // assign lcm_final_64 = lcm_prod_64 / lcm_gcd_64;
    // These are valid.

    // Wait, we need to make sure 'mult_mod_result' is defined.
    // The mult module output is 'lcm_mult_res'.
    // In ACCUMULATE, we use 'mult_mod_result'.
    // Let's alias it.
    wire [31:0] mult_mod_result = lcm_mult_res;

    // Also need to handle the case where we skip precompute if node_count is small?
    // No, precompute is good.

    // One issue: In PRECOMPUTE_LCM, we used a loop to find bit_idx.
    // In synthesis, `for` loop in sequential block is unrolled or treated as logic.
    // But we need to transition state. 
    // I used `state <= PRECOMP_FIND_BIT` then `state <= PRECOMP_CALC_LCM`.
    // Inside PRECOMP_FIND_BIT, I used a for loop. 
    // This might not update bit_idx correctly in 1 cycle if we rely on the loop.
    // Better to iterate bit_idx.
    // Let's change PRECOMP_FIND_BIT to a loop state.
    // Actually, we can just use bit_idx as counter.
    // In PRECOMPUTE_LCM, if bit_idx < 8, check mask[bit_idx].
    // If set, store bit_idx and go to CALC_LCM.
    // Else increment.

    // Revised PRECOMPUTE_LCM logic in the always block:
    // ... (too late to edit JSON body directly, need to be careful)
    // I will rely on the `for` loop inside `PRECOMP_FIND_BIT` generating priority logic.
    // But `for` loop in sequential block with blocking assignment updates variables immediately.
    // `bit_idx` is a reg.
    // Let's stick to the logic: 
    // State PRECOMP_FIND_BIT:
    //   If mask[0] set, bit_idx=0. Else if mask[1] set, bit_idx=1... etc.
    //   This generates a priority encoder.
    //   Then go to PRECOMP_CALC_LCM.
    //   This takes 1 cycle.
    //   Correct.

    // One more check on ITERATE_ROOTS:
    // We need to store 'rem' (mask ^ (1<<bit_idx)) to a register because we loop over submasks.
    // Let's use 'right_set' for this.
    // In ITERATE_ROOTS: `right_set <= mask ^ (8'b1 << bit_idx);`

endmodule

// --- Sub Modules ---

module gcd_mod(
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg done
);
    reg [31:0] x, y;
    reg working;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1;
            working <= 0;
        end else if (start && !working) begin
            x <= a;
            y <= b;
            working <= 1;
            done <= 0;
        end else if (working) begin
            if (y == 0) begin
                result <= x;
                done <= 1;
                working <= 0;
            end else begin
                x <= y;
                y <= x % y;
            end
        end
    end
endmodule

module mult_mod(
    input clk,
    input rst_n,
    input start,
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg done
);
    parameter MOD = 1000000007;
    
    // Since a*b can be large, use 64-bit intermediate
    // However, we can use modular multiplication properties.
    // But 64-bit multiply is fine in Verilog.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1;
        end else if (start) begin
            result <= ((64'b0 + a) * b) % MOD;
            done <= 1; // Combinational result latched in 1 cycle
        end else begin
            done <= 1;
        end
    end
endmodule