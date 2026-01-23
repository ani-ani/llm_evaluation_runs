module tree_avenue(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_trees,
    input [31:0] road_len,
    input [31:0] road_width,
    input [31:0] tree_pos_0,
    input [31:0] tree_pos_1,
    input [31:0] tree_pos_2,
    input [31:0] tree_pos_3,
    input [31:0] tree_pos_4,
    input [31:0] tree_pos_5,
    input [31:0] tree_pos_6,
    input [31:0] tree_pos_7,
    output reg [63:0] total_distance,
    output reg done
);

// States
localparam IDLE = 3'b000;
localparam SORT_INPUTS = 3'b001;
localparam PRECALC_TARGETS = 3'b010;
localparam CALCULATE_DP = 3'b011;
localparam OUTPUT_RESULT = 3'b100;
localparam SQRT_ITER = 3'b101;

reg [2:0] state;
reg [2:0] next_state;

// Storage for inputs
reg [31:0] trees [0:7];
reg [31:0] L_reg;
reg [31:0] W_reg;
reg [2:0] N_reg;
reg [2:0] num_pairs;

// Sorting indices and temporary reg
reg [2:0] sort_idx;
reg [2:0] swap_idx;
reg sorting_done;

// Target positions (Q16.16) - max 4 pairs
reg [31:0] target_left [0:3];
reg [31:0] target_right [0:3];
reg [2:0] calc_idx;

// DP variables
// dp[i][j] stored in SRAM-like structures
// i: 0..N, j: 0..Pairs. Since N<=8, Pairs<=4.
reg [63:0] dp [0:8][0:4]; // 64-bit for intermediate sum
reg [3:0] dp_i; // tree index
reg [2:0] dp_j; // pair index

// Distance Calculation State Machine
reg [63:0] dist_sq_a; // Q32.32
reg [63:0] dist_sq_b; // Q32.32
reg [63:0] dist_sq_val; // Q32.32
reg [63:0] sqrt_val; // Q32.32 input to sqrt
reg [63:0] root_val; // Q16.16 output (approx)
reg [4:0] sqrt_iter;

// Intermediate results for DP transition
reg [63:0] cost_left;
reg [63:0] cost_right;
reg [63:0] min_cost;

// Helper for fixed point multiplication: Q16.16 * Q16.16 = Q32.32
function automatic [63:0] mul_fixed;
    input [31:0] a;
    input [31:0] b;
    begin
        // Signed multiplication
        reg [63:0] res;
        reg sign;
        reg [31:0] a_abs, b_abs;
        sign = a[31] ^ b[31];
        a_abs = a[31] ? (~a + 1) : a;
        b_abs = b[31] ? (~b + 1) : b;
        res = {32'b0, a_abs} * {32'b0, b_abs};
        if (sign) res = ~res + 1;
        mul_fixed = res;
    end
endfunction

// Helper for fixed point addition (just standard addition, assume no overflow for this problem context)
function automatic [63:0] add_fixed;
    input [63:0] a;
    input [63:0] b;
    begin
        add_fixed = a + b;
    end
endfunction

function automatic [63:0] sub_fixed;
    input [63:0] a;
    input [63:0] b;
    begin
        sub_fixed = a - b;
    end
endfunction

// Next State Logic
always @(*) begin
    case (state)
        IDLE: next_state = start ? SORT_INPUTS : IDLE;
        SORT_INPUTS: next_state = sorting_done ? PRECALC_TARGETS : SORT_INPUTS;
        PRECALC_TARGETS: next_state = (calc_idx == num_pairs) ? CALCULATE_DP : PRECALC_TARGETS;
        CALCULATE_DP: begin
            if (dp_i > N_reg) next_state = OUTPUT_RESULT;
            else if (dp_j > num_pairs) next_state = SQRT_ITER; // Go to SQRT calc
            else next_state = CALCULATE_DP;
        end
        SQRT_ITER: begin
            if (sqrt_iter == 20) next_state = CALCULATE_DP; // Return to DP to store result
            else next_state = SQRT_ITER;
        end
        OUTPUT_RESULT: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Sequential Logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        total_distance <= 0;
        sort_idx <= 0;
        swap_idx <= 0;
        calc_idx <= 0;
        dp_i <= 0;
        dp_j <= 0;
        sqrt_iter <= 0;
        // Reset DP array (optional but good practice, though logic below initializes properly)
    end else begin
        state <= next_state;

        case (state)
            IDLE: begin
                if (start) begin
                    // Latch inputs
                    trees[0] <= tree_pos_0;
                    trees[1] <= tree_pos_1;
                    trees[2] <= tree_pos_2;
                    trees[3] <= tree_pos_3;
                    trees[4] <= tree_pos_4;
                    trees[5] <= tree_pos_5;
                    trees[6] <= tree_pos_6;
                    trees[7] <= tree_pos_7;
                    L_reg <= road_len;
                    W_reg <= road_width;
                    N_reg <= num_trees;
                    num_pairs <= num_trees >> 1;
                    // Initialize sorting indices
                    sort_idx <= 0;
                    swap_idx <= 0;
                    sorting_done <= 0;
                    calc_idx <= 0;
                    dp_i <= 0;
                    dp_j <= 0;
                    sqrt_iter <= 0;
                    done <= 0;
                end
            end

            SORT_INPUTS: begin
                // Bubble sort one swap per cycle
                if (trees[swap_idx] > trees[swap_idx + 1]) begin
                    trees[swap_idx] <= trees[swap_idx + 1];
                    trees[swap_idx + 1] <= trees[swap_idx];
                end
                
                swap_idx <= swap_idx + 1;
                
                if (swap_idx == N_reg - 2) begin
                    swap_idx <= 0;
                    sort_idx <= sort_idx + 1;
                    if (sort_idx == N_reg - 1) begin
                        sorting_done <= 1;
                    end
                end
            end

            PRECALC_TARGETS: begin
                // Calculate target positions for pair 'calc_idx'
                // Left: i * L / (N/2 - 1)
                // Right: Left + W
                // We need division. N/2 - 1 is 0 to 3.
                // Safe to assume N >= 2. If N=2, div by 0? Handled by problem spec (pairs).
                // Let's compute multiplier: 1/(Pairs-1). Since inputs are fixed, we can hardcode or compute.
                // For hardware, we do: val = (calc_idx * L) / (Pairs - 1)
                // But we are in sequential. Let's use a multi-cycle approach or precompute.
                // Since we have latency budget, let's do sequential subtraction for division or just use standard division.
                // Actually, let's use a simpler approach: store pre-calculated values if possible or use a divider.
                // Given the constraints, let's implement a simple restoring divider.
                // But first, we need to prepare operands.
                
                // Let's just use the SEQUENTIAL approach. If Pairs-1 is 1, 2, or 3.
                // We can just multiply by fixed constants for 1/1, 1/2, 1/3?
                // 1/2 = 0.5 Q16.16 = 32'h0000_8000
                // 1/3 = 0.333... Q16.16 = 32'h0000_5555
                // 1/1 = 1.0 Q16.16 = 32'h0001_0000
                
                // To keep it generic, let's implement a divider state inside here or a small counter.
                // Since we have 'CALCULATE_DP' state, we can use it for division logic too if we structure it well.
                // However, the prompt asks for specific states. Let's do division in this state using a small cycle counter.
                
                // Let's use a temporary register for division result.
                // Actually, let's change 'calc_idx' logic to be a counter that handles the division.
                // Wait, if we do this in one state, we need internal counters.
                // Let's use 'sort_idx' as a divider counter here.
                
                if (sort_idx == 0) begin // Setup division for Left Position
                    sort_idx <= 1; // Marker for second step
                    // Setup: num = calc_idx * L_reg, den = (num_pairs - 1)
                    // We need to handle 1/1, 1/2, 1/3 cases specifically to save HW.
                    // If Pairs-1 == 0 (N=2), target is 0 and L. 
                    if (num_pairs == 1) begin // Special case N=2
                         target_left[0] <= 0;
                         target_right[0] <= W_reg;
                         calc_idx <= 1; // Skip to end
                         sort_idx <= 0;
                    end else begin
                        // Prepare multiplication: calc_idx * L_reg (32.32)
                        // calc_idx is small, so {29'b0, calc_idx} * L_reg
                        dist_sq_a <= {29'b0, calc_idx, 3'b0}; // Actually just extend calc_idx to Q16.16? No, Q32.32 needs full precision.
                        // Let's just do: val_32_32 = (calc_idx * L_reg) << 16. Wait, calc_idx is integer.
                        // val = (calc_idx * L_reg) / (num_pairs - 1)
                        // We'll do the multiplication in next cycle.
                    end
                end else if (sort_idx == 1) begin
                     // We need to divide by (num_pairs - 1). 
                     // Since denominator is small (1, 2, 3), we can use a specific multiplier.
                     // But wait, we are sequential. Let's just calculate numerator first.
                     // Numerator = calc_idx * L_reg. Result is Q32.32 (since L is Q16.16, calc_idx integer).
                     // Actually, if calc_idx is integer, result is Q16.16 shifted left 16? No.
                     // calc_idx (int) * L (Q16.16) = L * calc_idx. Result is Q16.16 (scaled by integer).
                     // We want result Q16.16. So we want (calc_idx * L) / (Pairs-1).
                     // calc_idx * L is Q16.16. Divisor is integer.
                     // Let's perform: Val = (L >> 1) / (Pairs-1) if calc_idx=1? No.
                     // Let's do: Shift L left 16 to make it Q32.32, multiply by calc_idx (int). 
                     // Then divide by (Pairs-1). Result will be Q32.32. We want Q16.16, so take high 32 bits.
                     
                     // Let's use 'sqrt_val' as temp storage for numerator (Q32.32)
                     sqrt_val <= {L_reg, 16'b0} * calc_idx; // Q32.32 * int -> Q32.32
                     sort_idx <= 2;
                end else if (sort_idx == 2) begin
                    // Divide by (num_pairs - 1)
                    // Using simple subtraction since denominator is small (<=3).
                    // We want to perform: sqrt_val / (num_pairs - 1)
                    // We'll use a loop. Let's reuse 'dp_j' or something as counter.
                    // Actually, let's do the division in a separate state or use logic.
                    // Let's do it here but take multiple cycles if needed, or assume it fits in one.
                    // Since result is Q16.16, and we have Q32.32 numerator, we need to shift.
                    // Let's just compute it. Denom is small.
                    // Result = numerator / denom. 
                    // Since we are in sequential logic, we can compute it iteratively or hardcode.
                    // Let's use a divider module logic here.
                    // To keep code simple and within state machine flow, let's use the 'SQRT_ITER' slot or similar if possible.
                    // But 'SQRT_ITER' is used for distance.
                    // Let's perform division here using a small counter 'dp_j' (temp).
                    
                    // Setup division
                    if (dp_j < num_pairs - 1) begin
                        target_left[calc_idx] <= sqrt_val[47:16]; // Take upper Q16.16 part (approximation)
                        // Wait, we need exact division.
                        // Let's do standard restoring division or just use a multiplier for 1/2, 1/3.
                        // 1/2 = 0.5. 1/3 = 0.333.
                        // Let's use a divider block.
                        // Actually, since we have latency, let's just calculate it properly.
                        // We'll use 'dp_j' as a counter for the division steps.
                        // But we need 'dp_j' for DP later. 
                        // Let's restructure: PRECALC_TARGETS will take 3 cycles max.
                        // Cycle 1: Multiply calc_idx * L (Q16.16). Result Q16.16 * int -> Q16.16 (if we treat int as Q0.32 or something).
                        // Let's stick to: Value = (L * calc_idx) / (Pairs - 1).
                        // L is Q16.16. calc_idx is 0..3. Result is Q16.16.
                        // We can precalculate coefficients.
                        // Let's just use a lookup for the division factor if Pairs-1 is small.
                        // Factors: 1/1=1, 1/2=0.5, 1/3=0.3333, 1/4=0.25.
                        // Multiply L by 0.5 (>>1) or 0.3333 (approx).
                        // Let's just do the math: target = (calc_idx * L) >> shift where shift depends on pairs.
                        // If pairs = 2 (1 pair), target is 0 and L. Handled above.
                        // If pairs = 3 (2 pairs), divide by 1. Target = calc_idx * L.
                        // If pairs = 4 (3 pairs), divide by 2. Target = (calc_idx * L) >> 1.
                        // If pairs = 5 (4 pairs), divide by 3.
                        
                        // This logic is getting complex for 1 state. 
                        // Let's simplify: We need (calc_idx * L) / (Pairs-1).
                        // We will do the division in this state using 'dp_j' as a temporary divider register.
                        // We need to clear 'dp_j' first. 
                    end
                    
                    // Re-implementation of PRECALC_TARGETS for robustness:
                    // We will perform the calculation one pair at a time, using multiple cycles if needed.
                    // We will use 'sort_idx' to track sub-state.
                    // Sub-state 0: Multiplication.
                    // Sub-state 1..N: Division/Result assignment.
                    // Actually, let's just compute 'target_left[calc_idx]' and 'target_right' in one go using a defined logic.
                    // Since we need specific delay, let's just use a small counter.
                    
                    // Let's change the PRECALC_TARGETS logic to be simpler:
                    // We will use 'dp_j' as a counter for calculation steps.
                    // But we must save 'dp_j' for DP. So we need a separate counter if we want to be safe.
                    // Let's use 'sort_idx' as the sub-step counter for this state.
                    // 0: Load Numerator (calc_idx * L)
                    // 1: Apply Division (by checking Pairs-1) and Store.
                    // 2: Increment calc_idx.
                    
                    // Let's reset sort_idx to 0 at start of state.
                    // We need to change 'next_state' logic for this state to iterate properly.
                    // But prompt says state machine with these names. So we should stick to one state.
                    // Let's assume we can do it in 1 cycle (maybe with combinational division which is heavy).
                    // Or, we can do it in 1 cycle by pre-coding the divisors.
                    // If Pairs-1 = 2 (3 pairs), we need /2.
                    // If Pairs-1 = 3 (4 pairs), we need /3.
                    // /3 is tricky. Let's assume 200 cycles are enough for everything. 
                    // So we can spend a few cycles here.
                    // Let's restructure: The state machine will loop in PRECALC_TARGETS until all targets are done.
                    // We need a flag to indicate sub-completion.
                end
                
                // CLEAN REWRITE OF PRECALC_TARGETS LOGIC IN THE ALWAYS BLOCK:
                // We will perform this calculation sequentially inside PRECALC_TARGETS.
                // We use 'calc_idx' as the pair index.
                // We use 'dp_i' as a step counter (abusing it since DP hasn't started).
                // Step 0: Multiply calc_idx * L. Store in temp (e.g., sqrt_val).
                // Step 1: Divide by (Pairs-1). Handle cases.
                // Step 2: Store left. Store right = left + W.
                // Step 3: Increment calc_idx. Reset step. Loop.
                
                // Let's use 'sort_idx' for the step counter (0, 1, 2, 3).
                if (sort_idx == 0) begin
                    // Calculate Left = (calc_idx * L) / (num_pairs - 1)
                    // If num_pairs == 1, handled in IDLE or here.
                    if (num_pairs == 1) begin
                        target_left[0] <= 0;
                        target_right[0] <= W_reg;
                        calc_idx <= 1; // Mark done
                        // We need to advance state. Check below.
                    end else begin
                        // Multiply: sqrt_val = calc_idx * L (Q32.32)
                        // calc_idx is integer 0..3. L is Q16.16. Result Q32.32 (actually Q16.16 shifted left 16 if we treat calc_idx as Q16.16 integer? No, calc_idx is 0..3)
                        // Let's do: sqrt_val = (calc_idx * L_reg) << 16. 
                        // Actually, 1.0 in Q16.16 is 65536. 
                        // calc_idx * L is scale. 
                        // Let's compute: sqrt_val = (calc_idx * L_reg) << 16. This makes it Q32.32 scale.
                        // Wait, we want to divide by (num_pairs-1). 
                        // Let's just do: numerator = calc_idx * L_reg. Result is Q16.16 (since L is Q16.16, calc_idx is integer).
                        // But we need precision. So let's do: numerator = {L_reg[31:0], 16'b0} * calc_idx. -> Q32.32.
                        // Wait, {L_reg, 16'b0} is Q32.16. * calc_idx (0..3) -> Q32.16. We need Q32.32.
                        // Let's just do: numerator = L_reg * calc_idx. This gives Q16.16 * int = Q16.16 (scaled).
                        // Let's do: sqrt_val = (L_reg * calc_idx) << 16. 
                        // No, standard fixed point mult: Q16.16 * Q0.32 (int) = Q16.16.
                        // Let's do: numerator = L_reg * calc_idx. Result is Q16.16.
                        // We will divide this by (num_pairs-1). Result Q16.16.
                        // To keep it simple: Let's just store (L_reg * calc_idx) in sqrt_val (high 32 bits are 0).
                        // Then we shift left 16 to perform division with integer math? 
                        // No, let's just calculate: target = (L_reg * calc_idx) / (num_pairs - 1).
                        // Division of Q16.16 by integer.
                        // Let's use 'dist_sq_a' to store the numerator (Q16.16).
                        dist_sq_a <= L_reg * calc_idx; // Q16.16 result.
                        sort_idx <= 1;
                    end
                end else if (sort_idx == 1) begin
                    // Division by (num_pairs - 1)
                    // Denominator D = num_pairs - 1. (Values 1, 2, 3).
                    // If D=1: result = dist_sq_a.
                    // If D=2: result = dist_sq_a >> 1.
                    // If D=3: result = dist_sq_a * 0x5555 (approx) >> 16. (0.33333...)
                    
                    // Let's use 'dist_sq_b' to hold the result.
                    case (num_pairs - 1)
                        3'd1: dist_sq_b <= dist_sq_a;
                        3'd2: dist_sq_b <= {1'b0, dist_sq_a[31:1]}; // Divide by 2
                        3'd3: dist_sq_b <= (dist_sq_a * 32'h0000_5555) >> 16; // Divide by 3 approximation
                        default: dist_sq_b <= 0;
                    endcase
                    sort_idx <= 2;
                end else if (sort_idx == 2) begin
                    // Store Left
                    target_left[calc_idx] <= dist_sq_b;
                    // Calculate Right = Left + W
                    target_right[calc_idx] <= dist_sq_b + W_reg;
                    sort_idx <= 3;
                end else if (sort_idx == 3) begin
                    // Increment pair index
                    calc_idx <= calc_idx + 1;
                    sort_idx <= 0;
                    // If we are done, state transition handles going to next state.
                    // We need to check if calc_idx == num_pairs here?
                    // The next_state logic checks (calc_idx == num_pairs).
                    // So if we increment to num_pairs, next state will change.
                    // If not, we stay in this state.
                end
            end

            CALCULATE_DP: begin
                // DP Logic: dp[i][j] = min(dp[i-1][j-1] + dist(tree[i-1], left[j-1]), dp[i-1][j] + dist(tree[i-1], right[j-1]))
                // We compute one DP cell per iteration? Or one row?
                // Given latency 200, and N=8, we can do this row by row.
                // Let's fill table. 
                // Rows 0..N. Cols 0..Pairs.
                // Row 0 is base case (all 0).
                // We iterate i from 1 to N. 
                // Inside i, iterate j from 1 to Pairs.
                // We need to calculate two distances to get the min.
                // We need to store intermediate results.
                // Let's use 'dp_i' as tree index (1..N).
                // Let's use 'dp_j' as pair index (1..Pairs).
                // We need to compute CostLeft = dist(tree[i-1], left[j-1]) and CostRight = dist(tree[i-1], right[j-1]).
                // Then CostTotal = min(dp[i-1][j-1] + CostLeft, dp[i-1][j] + CostRight).
                // Then store in dp[i][j].
                
                // To do this sequentially:
                // Step A: Load tree and target pos. Compute DistSq for Left.
                // Step B: Compute DistSq for Right.
                // Step C: Sqrt Left, Sqrt Right. (Or reuse SQRT_ITER state).
                // Step D: Load dp[i-1][j-1] and dp[i-1][j]. Compare and Store.
                
                // Since we have SQRT_ITER state, we should use it.
                // But SQRT_ITER needs to be triggered. 
                // Let's modify the flow:
                // In CALCULATE_DP:
                // 1. Setup Sqrt for Left (if j >= 1).
                // 2. Move to SQRT_ITER.
                // 3. Return, store CostLeft. Setup Sqrt for Right.
                // 4. Move to SQRT_ITER.
                // 5. Return, store CostRight.
                // 6. Calculate Min and Store to DP array.
                // 7. Increment j.
                // 8. If j > Pairs, increment i, reset j=1.
                
                // However, we are currently in CALCULATE_DP. 
                // We need sub-states here.
                // Let's use 'sort_idx' or 'calc_idx' for sub-states.
                // 0: Setup Sqrt Left -> Go to SQRT_ITER
                // 1: (Return from SQRT_ITER) Store CostLeft -> Setup Sqrt Right -> Go to SQRT_ITER
                // 2: (Return from SQRT_ITER) Store CostRight -> Calc Min -> Store DP -> Increment J
                
                // Wait, the transition to SQRT_ITER happens in 'next_state' logic.
                // So we need to check if we are done with Sqrt.
                // But 'CALCULATE_DP' state is entered and left multiple times.
                // We need to manage the flow.
                
                // Let's use 'sort_idx' to manage the steps within CALCULATE_DP for a single cell.
                // 0: Calc SqrDist Left -> Go SQRT
                // 1: (After SQRT) -> Save CostLeft -> Calc SqrDist Right -> Go SQRT
                // 2: (After SQRT) -> Save CostRight -> Compute DP Cell -> Increment Pointers
                
                // We need to save the pointer state before jumping to SQRT.
                // Let's use 'calc_idx' to save the sub-state of CALCULATE_DP.
                // Actually, 'sort_idx' is free.
                
                if (sort_idx == 0) begin
                    // Calculate SqrDist Left
                    // Tree: trees[dp_i - 1] (since i starts at 1)
                    // Target: target_left[dp_j - 1]
                    // SqrDist = (Tx - Px)^2 + (Ty - Py)^2
                    // Tx = trees[dp_i-1], Px = target_left[dp_j-1]. Ty=0, Py=0 (assuming y=0 for trees, y=W for targets? No, problem says trees on left, targets on right)
                    // Trees on left (x, 0). Targets on right (x, W). 
                    // Distance = sqrt( (x_tree - x_target)^2 + (0 - W)^2 ).
                    // Wait, y coordinate is fixed. Trees at y=0. Targets at y=W.
                    // So (Tx - Px)^2 + W^2.
                    // (Tx - Px) is Q16.16 diff.
                    // W is Q16.16.
                    
                    // We need (Tx - Px). 
                    // Let's compute DiffX = trees[dp_i-1] - target_left[dp_j-1].
                    // But DiffX might be negative. Square makes it positive.
                    // We'll use DiffX^2 + W^2.
                    // W^2 is constant for the whole problem.
                    // Let's precalc W^2 in PRECALC_TARGETS or here.
                    // Let's assume W^2 is available. We can compute it in IDLE or SORT.
                    // Let's compute W^2 here for simplicity (or in IDLE if we had time).
                    // Let's compute W^2 in PRECALC_TARGETS end or here.
                    // Actually, let's compute it once in IDLE to save time. 
                    // Add a register for W_sq. 
                    // Modify IDLE: W_sq <= mul_fixed(road_width, road_width);
                    
                    // Current Logic:
                    // dist_sq_a = trees[dp_i-1] - target_left[dp_j-1]
                    // We need to handle signed subtraction.
                    // Let's use signed comparison.
                    // Actually, let's just calculate difference.
                    // If trees[...] > target_left[...], diff = trees - target.
                    // If trees < target, diff = target - trees.
                    // Then square it.
                    
                    // Let's do: diff = trees[dp_i-1] ^ target_left[dp_j-1] ? No.
                    // Let's use combinational subtraction or sequential.
                    // We can do: 
                    // diff_x = (trees > target) ? trees - target : target - trees.
                    
                    // Prepare for SqrDist: DiffX^2 + W^2.
                    // We need to square DiffX. DiffX is Q16.16.
                    // Result is Q32.32.
                    // W^2 is also Q32.32.
                    // Sum is Q32.32.
                    
                    // Let's calculate DiffX first.
                    // Use 'dist_sq_a' to store DiffX (Q16.16 signed).
                    // We need to know if we are doing Left or Right.
                    // 'sort_idx' 0 is Left. 1 is Right.
                    
                    // Let's refine sub-states:
                    // sub_state 0: Calc DiffX for Left. 
                    // sub_state 1: Square DiffX. Add W^2. -> Input to Sqrt (Go SQRT). Save state to return to (e.g. 'sort_idx' = 2).
                    // sub_state 2: (Return from Sqrt) Store CostLeft. 
                    // sub_state 3: Calc DiffX for Right.
                    // sub_state 4: Square DiffX. Add W^2. -> Input to Sqrt (Go SQRT). Save state to return to (e.g. 'sort_idx' = 5).
                    // sub_state 5: (Return from Sqrt) Store CostRight.
                    // sub_state 6: Calc DP Cell.
                    
                    // Let's use 'sort_idx' as the sub_state counter.
                    // But we need to handle the loop.
                    // We need to go from 0 to 6 for each (i, j).
                    
                    // We will use 'sort_idx' for the sub_step.
                    // We need to initialize it to 0 when entering CALCULATE_DP for a new cell.
                    // How do we know it's a new cell? We can set it to 0 in the transition INTO CALCULATE_DP.
                    // But we are looping inside CALCULATE_DP. 
                    // So, when we finish step 6, we increment dp_j. If dp_j > num_pairs, we increment dp_i, reset dp_j=1.
                    // And we set sort_idx = 0.
                    
                    // Let's write the logic for sub_steps.
                    
                    if (sort_idx == 0) begin // Calc DiffX Left
                         // diff = trees[dp_i-1] - target_left[dp_j-1]
                         // But we need absolute value for squaring? No, (a-b)^2 is same as (b-a)^2.
                         // So we can just do a-b, which might be negative.
                         // Then we square it. 
                         // Let's do signed subtraction.
                         // Since we are in hardware, let's use temporary subtraction.
                         // dist_sq_a <= trees[dp_i-1] - target_left[dp_j-1]; (Q16.16)
                         // Wait, inputs are Q16.16. Subtraction is Q16.16.
                         dist_sq_a <= trees[dp_i-1] - target_left[dp_j-1];
                         sort_idx <= 1;
                    end else if (sort_idx == 1) begin // Square DiffX, Add W^2, Sqrt
                         // Square dist_sq_a (Q16.16 -> Q32.32)
                         // W^2 (Q32.32). We need to calculate W^2 if not done.
                         // Let's assume W^2 is in 'dp' array or separate register. 
                         // Let's use 'dist_sq_b' to store W^2. 
                         // If we haven't calculated W^2, calculate it now.
                         // We can use the MUL instruction.
                         // Let's use 'dp' array slot [0][0] or something to store W_sq.
                         // Actually, let's calculate W_sq in IDLE.
                         // Modify IDLE: dp[0][0] <= mul_fixed(road_width, road_width);
                         // Then use dp[0][0] here.
                         
                         // Square DiffX
                         // mul_fixed returns Q32.32.
                         // dist_sq_a is Q16.16. 
                         // We need to sign extend or treat as signed.
                         // mul_fixed handles signed.
                         
                         sqrt_val <= mul_fixed(dist_sq_a, dist_sq_a) + dp[0][0]; // DiffX^2 + W^2
                         
                         // Prepare for Sqrt
                         // We need to store the return sub_state in 'calc_idx' or similar.
                         // Let's set 'calc_idx' to 2 (meaning 'Done with Sqrt for Left').
                         // Actually, we can just increment 'sort_idx' and jump.
                         // But 'sort_idx' is currently 1. 
                         // We want to go to SQRT_ITER. 
                         // When we return, we need to know we are in step 2.
                         // So we can set 'sort_idx' to 2, then jump to SQRT_ITER.
                         // But 'sort_idx' is updated in CALCULATE_DP block.
                         // We need to set a 'return_state' flag.
                         // Let's use 'calc_idx' to store the sub_step to return to.
                         // calc_idx <= 2; (Means 'Done with Sqrt for Left').
                         // But wait, we are in CALCULATE_DP. We need to jump out.
                         // The next_state logic determines the jump.
                         // If we are in CALCULATE_DP and we need Sqrt, we set next_state to SQRT_ITER.
                         // But we are inside the combinational block setting next_state.
                         // The logic for next_state checks 'state'.
                         // In CALCULATE_DP state, we can't easily trigger the jump inside the sequential block because next_state is already evaluated.
                         // We need to structure the state transitions to handle this.
                         // The prompt says states: IDLE, SORT, CALC_DP, OUTPUT, SQRT_ITER.
                         // It implies SQRT_ITER is a separate state. 
                         // So we should transition to it.
                         // How to transition from CALC_DP to SQRT_ITER and back?
                         // We need a flag. 
                         // Let's use 'sort_idx' to track the return point.
                         // We need to modify the next_state logic to check for a 'sqrt_req' flag.
                         // Let's add a register 'sqrt_req'.
                         // In CALC_DP sub-step, set sqrt_req = 1.
                         // In next_state logic: if (state == CALCULATE_DP && sqrt_req) next_state = SQRT_ITER;
                         // If (state == SQRT_ITER && done_sqrt) next_state = CALCULATE_DP;
                         
                         // Let's refine the code structure.
                         // We need to add 'sqrt_req' register.
                         // We need to modify 'next_state' logic.
                         
                         // For now, let's assume we can just perform the calculation in CALCULATE_DP state using multiple cycles if needed.
                         // But SQRT is iterative. We need SQRT_ITER state.
                         
                         // Let's add 'sqrt_req' to the design.
                         // 'sqrt_req' = 1 means we want to calculate sqrt of 'sqrt_val'.
                         // 'sqrt_done' will be handled by SQRT_ITER.
                         
                         // So in the code below (if we had 'sqrt_req'):
                         // Here (step 1), we set sqrt_val and sort_idx=2. 
                         // We set sqrt_req = 1. (This happens in the combinational block? No, sequential).
                         // We need to set it in the combinational block or use a flag that persists.
                         
                         // Let's use 'sort_idx' as the return point marker.
                         // If sort_idx == 1, we are calculating Sqrt for Left.
                         // We set sort_idx = 2 (meaning next time we enter CALC_DP, we are in step 2).
                         // We set state to SQRT_ITER (this forces transition).
                         
                         // To force transition, we need to modify the 'state' register or the 'next_state' logic.
                         // Since 'state' is sequential, we can't change it inside the always block to jump immediately.
                         // We set next_state = SQRT_ITER.
                         // But next_state is combinational output of current state.
                         // So we need to modify the combinational 'next_state' logic to support branching.
                         // The prompt asks for a state machine with specific states. 
                         // We can modify the 'CALCULATE_DP' case in the combinational block to look at sub-state.
                         // Or we can just add a flag.
                         
                         // Let's add a register `calc_sub_state`.
                         // Or use `sort_idx` as the sub-state tracker.
                         // Let's add `req_sqrt` register.
                         
                         // Okay, I will write the code assuming a flag `sqrt_trigger`.
                         // If `sqrt_trigger` is set, next_state becomes SQRT_ITER.
                         // We need to save where to return.
                         // Let's use `calc_idx` to store return sub-step.
                         
                         // Let's actually implement the multi-cycle logic directly in CALCULATE_DP state without jumping to SQRT_ITER if it fits in 200 cycles.
                         // Sqrt 20 cycles. We have 200 cycles. 
                         // We have 8 trees * 4 pairs = 32 cells.
                         // If we spend 2 cycles per cell (prep + store), we have 64 cycles. 
                         // But we need Sqrt. 20 cycles per sqrt = 40 cycles per cell (2 sqrts). 32 * 40 = 1280. Too much.
                         // We MUST jump to SQRT_ITER state.
                         
                         // So, let's formalize the jump mechanism.
                         // We will use `sort_idx` to indicate what to do AFTER sqrt.
                         // Current `sort_idx` value: 
                         // 0: Setup Sqrt Left (DiffX^2 + W^2). Then set `sort_idx` = 1. Go to SQRT.
                         // 1: (Return from SQRT) -> Save Left Cost. Setup Sqrt Right. Set `sort_idx` = 2. Go to SQRT.
                         // 2: (Return from SQRT) -> Save Right Cost. Compute DP. Next Cell.
                         
                         // We need a signal to tell SQRT_ITER to start.
                         // Let's add `start_sqrt` pulse.
                         // But how to return? The SQRT_ITER state runs for 20 cycles.
                         // Then it goes back to CALCULATE_DP.
                         // How does CALCULATE_DP know where it left off?
                         // It checks `sort_idx`. 
                         // When returning from SQRT_ITER, `sort_idx` should be what we set it to before jumping.
                         
                         // Let's write the logic flow:
                         
                         // In CALCULATE_DP state (sequential block):
                         // If we are just entering (or returning from SQRT):
                         //   Case sort_idx:
                         //     0: Calc SqrDist Left. 
                         //        Then, set sort_idx = 1. 
                         //        Set sqrt_val = ... 
                         //        (Trigger SQRT. This requires setting a flag or forcing state change).
                         //        To force state change, we can't easily in same cycle. 
                         //        We set a flag `go_sqrt`.
                         //        In next_state logic, if `go_sqrt` is high, next_state = SQRT_ITER.
                         //        Also, we need to save `sort_idx`? No, `sort_idx` is already 1.
                         //        Wait. If we set sort_idx=1, and then jump to SQRT, we return to CALC_DP.
                         //        When we return, sort_idx is 1. 
                         //        In the sequential block, if sort_idx==1, we do the action for 'Returned from Left Sqrt'.
                         //        That action is: Save Cost Left. Calc SqrDist Right. Set sort_idx = 2. Trigger SQRT.
                         //        When we return, sort_idx==2. Action: Save Cost Right. Calc DP. Increment pointers.
                         //        If pointers done, go to OUTPUT. Else, set sort_idx=0. (No trigger, just stay in CALC_DP).
                         
                         // So we need a `go_sqrt` flag.
                         // In the combinational next_state logic:
                         // If state == CALCULATE_DP && go_sqrt, next_state = SQRT_ITER.
                         // If state == SQRT_ITER && sqrt_complete, next_state = CALCULATE_DP.
                         
                         // Let's refine the SQRT_ITER state logic.
                         // It takes `sqrt_val`. It computes `root_val`.
                         // After 20 iterations, it sets `sqrt_complete` = 1.
                         // Then returns to CALCULATE_DP.
                         
                         // Implementation details:
                         // In CALCULATE_DP sequential block:
                         // If (sort_idx == 0):
                         //    // Calc DiffX for Left
                         //    diff_x = trees[dp_i-1] - target_left[dp_j-1];
                         //    // Calc Sqr
                         //    sqrt_val <= mul_fixed(diff_x, diff_x) + dp[0][0]; // W_sq in dp[0][0]
                         //    sort_idx <= 1; // Return point
                         //    go_sqrt <= 1; // Trigger SQRT
                         //    // Note: we need to make sure we don't re-trigger if we just returned.
                         //    // We need a flag to say 