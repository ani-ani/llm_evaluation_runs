module count_ones_range(
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    input [13:0] l_in,
    input [13:0] r_in,
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CALCULATE_LEN = 3'b001;
    localparam PUSH_CALL = 3'b010;
    localparam POP_AND_PROCESS = 3'b011;
    localparam UPDATE_RESULT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    
    // Stack Parameters
    // Stack depth 16 is sufficient for n up to 2^16 (max depth 16)
    localparam STACK_DEPTH = 16;
    localparam STACK_ADDR_W = 4;
    
    // Stack memory
    reg [15:0] stack_n [0:STACK_DEPTH-1];
    reg [13:0] stack_l [0:STACK_DEPTH-1];
    reg [13:0] stack_r [0:STACK_DEPTH-1];
    reg [STACK_ADDR_W:0] sp; // Stack pointer, points to next free location
    
    // Input registers
    reg [15:0] n_reg;
    reg [13:0] l_reg;
    reg [13:0] r_reg;
    
    // Computation registers
    reg [31:0] current_len; // Length of sequence for current n
    reg [31:0] sub_len;     // Length of left/right sub-sequence
    
    // Working variables for current operation
    reg [15:0] curr_n;
    reg [13:0] curr_l;
    reg [13:0] curr_r;
    
    // Temp variables for range calculation
    reg [31:0] temp_l; // Calculated start index of current node
    reg [31:0] temp_r; // Calculated end index of current node
    
    // Update logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            sp <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        l_reg <= l_in;
                        r_reg <= r_in;
                        result <= 32'd0;
                        sp <= 0;
                        state <= CALCULATE_LEN;
                    end
                end

                CALCULATE_LEN: begin
                    // Calculate total length for the current n
                    if (n_reg <= 1) begin
                        current_len <= 32'd1;
                    end else begin
                        // Recursive: 2*len(n/2) + 1
                        // We need the length of n/2 first. 
                        // We will simulate this logic: 
                        // Since we need len(n) for n_reg (input), and we know max n is 2^16,
                        // we can use a loop or recursive formula.
                        // Since we are in a single cycle state, we will compute it iteratively
                        // or pre-calculate in a previous state.
                        // However, calculating Len(n) for arbitrary n up to 2^16 requires a loop.
                        // Let's implement a small iterative calculation here or assume 
                        // we calculate it based on the formula L(n) = 2*L(floor(n/2))+1.
                        // But we can't do recursion inside CALCULATE_LEN.
                        // We will use the property: L(n) = 2^k - 1 where 2^(k-1) <= n < 2^k.
                        // Wait, this property holds for perfect binary trees (n=2^k-1).
                        // The problem description is slightly ambiguous about non-perfect trees.
                        // "Replace x > 1 with [floor(x/2), x%2, floor(x/2)]".
                        // This implies L(x) = 2*L(floor(x/2)) + 1.
                        // Let's compute L(n_reg) iteratively in IDLE or here.
                        // We need to compute the tree length based on n.
                        // Let's use a pre-calculation state if n is large, or a loop.
                        // Since we have 50k cycles, we can afford a loop.
                        // But let's optimize.
                        // The sequence is a representation of n.
                        // Example: n=5. n/2=2, n%2=1.
                        // Sequence(5) = [Seq(2), 1, Seq(2)]. Seq(2)=[Seq(1), 0, Seq(1)] = [1,0,1].
                        // Seq(5)=[1,0,1, 1, 1,0,1]. Length 7.
                        // Formula: L(n) = L(floor(n/2))*2 + 1.
                        // Base: L(0)=1 (Wait, problem says "until all elements are 0 or 1". If input is 0, sequence is [0]. Length 1).
                        // Base: L(1)=1.
                        // Let's compute L(n) iteratively in a sub-state or use a multiplier.
                        // Given hardware constraints, we calculate L(n) in this state by iterating.
                        // To save states, we can calculate L(n) in CALCULATE_LEN.
                        // We need a temp variable for n calculation.
                        // Let's say we use curr_n as temp.
                        // But we already have n_reg.
                        // Let's introduce a temp counter for length.
                        // Actually, let's do this:
                        // If we use the property that L(n) = (2 * (2^k - 1)) + 1 for range n in [2^k, 2^(k+1)-1] is NOT correct.
                        // Correct approach: We will store (n, l, r) onto the stack for the initial call.
                        // Then we start processing the stack.
                        // To do that, we need to push the initial request.
                        // But we need to calculate the total length to know where the middle element is.
                        // Let's assume we compute L(n) on the fly when we need it in POP_AND_PROCESS.
                        // But to save states, we can compute L(n) here iteratively.
                        // Let's add a loop counter.
                        // Since we need to support 50k cycles, we can do a small loop.
                        // Let's just push the root node to stack and calculate length during processing.
                        
                        // Actually, to avoid complex state transitions, let's push (n, l, r) to stack in PUSH_CALL.
                        // And handle length calculation in POP_AND_PROCESS if needed.
                        // Wait, we need length to determine sub-ranges.
                        // We will compute length in POP_AND_PROCESS.
                        // So, we just transition to PUSH_CALL to push the initial request.
                        state <= PUSH_CALL;
                    end
                end

                PUSH_CALL: begin
                    // Push current (n, l, r) to stack
                    if (sp < STACK_DEPTH) begin
                        // We need to push the initial request or a split request.
                        // For the initial call:
                        // If this is the first push (from IDLE/CALCULATE_LEN), we push (n_reg, l_reg, r_reg)
                        // If this is a split (Left/Right), we push computed values.
                        // We will distinguish by checking if a specific flag is set? 
                        // Or we can assume PUSH_CALL always pushes what is currently in working registers (curr_n, curr_l, curr_r).
                        // We need to set these working registers before entering PUSH_CALL.
                        
                        // If coming from IDLE/CALCULATE_LEN (Start of operation):
                        if (state == CALCULATE_LEN) begin // Wait, I removed the calculation logic above to simplify
                            // Let's handle the start case:
                            stack_n[sp] <= n_reg;
                            stack_l[sp] <= l_reg;
                            stack_r[sp] <= r_reg;
                            sp <= sp + 1;
                            state <= POP_AND_PROCESS;
                        end else if (state == UPDATE_RESULT) begin
                            // This handles recursive splits from POP_AND_PROCESS
                            // The update state decides what to push next.
                            // If we are here from UPDATE_RESULT, it means we need to push Left or Right child.
                            // The values to push should be prepared in curr_n, curr_l, curr_r.
                            stack_n[sp] <= curr_n;
                            stack_l[sp] <= curr_l;
                            stack_r[sp] <= curr_r;
                            sp <= sp + 1;
                            state <= POP_AND_PROCESS;
                        end
                    end else begin
                        // Stack overflow (should not happen given constraints)
                        state <= DONE;
                    end
                end

                POP_AND_PROCESS: begin
                    // Pop from stack
                    if (sp > 0) begin
                        sp <= sp - 1;
                        curr_n <= stack_n[sp - 1];
                        curr_l <= stack_l[sp - 1];
                        curr_r <= stack_r[sp - 1];
                        // Next state: check if we need to recurse or count
                        // We will transition to UPDATE_RESULT to handle the logic of the popped node
                        state <= UPDATE_RESULT;
                    end else begin
                        // Stack empty, computation done
                        state <= DONE;
                    end
                end

                UPDATE_RESULT: begin
                    // Process the node (curr_n, curr_l, curr_r)
                    // 1. Calculate Length of curr_n
                    // 2. Calculate Start and End indices of the node's sequence (relative to global or local?)
                    // The problem asks for indices in the final sequence starting from 1.
                    // We need to know the global position of the node's sequence.
                    // Wait, the stack only stores (n, query_l, query_r).
                    // We need to know the global start index of the node to compare with query range.
                    // Actually, the problem description implies we are traversing the implicit tree.
                    // We can pass the start index of the current node along with n.
                    // Let's add start_index to the stack. 
                    // We need to modify the stack structure to store start_index.
                    // Size: n (16) + start (14) + end (14) = 44 bits. Or just n and start.
                    // If we know n and start, we can compute length.
                    // Let's refine the stack to store (n, start_idx).
                    // And we pass the query range (l_reg, r_reg) separately? 
                    // No, we should filter the query range down.
                    // Better: Stack stores (n, global_start, global_end).
                    // When popping, we compare (global_start, global_end) with (l_reg, r_reg).
                    // If we pushed children, we calculate their global ranges.
                    // 
                    // REVISION: Stack needs to store (n, start_idx).
                    // But we need to know the query range. The query range is fixed.
                    // So we can store (n, start_idx) on stack. 
                    // And we pass (l_reg, r_reg) as global constants? No.
                    // We need to filter the range.
                    // Let's use stack of (n, local_l, local_r).
                    // Local_l and local_r are the parts of the query range applicable to this node.
                    // Wait, we are recursing. 
                    // Iteration 1: (n, l, r).
                    // We calculate len = L(n).
                    // We see if [l, r] overlaps with [1, len].
                    // We split [1, len] into [1, left_len], [left_len+1, left_len+1], [left_len+2, len].
                    // We need to map l and r to these parts.
                    // Left child range: (n/2, 1, left_len) intersected with query.
                    // Middle: (1, 1) -> if overlaps, count++.
                    // Right child: (n/2, left_len+2, len).
                    // 
                    // To do this efficiently, we need L(n) in this state.
                    // Let's compute L(n) iteratively here. Since max depth is small, this takes few cycles.
                    // But we are in a state machine. 
                    // Let's add a sub-state or use a counter.
                    // Since we have 50k cycles, we can use a small loop in this state.
                    // Let's compute L(n) using a temporary variable `len_temp` and `n_temp`.
                    // If we compute L(n), we can then decide:
                    // 1. If [curr_l, curr_r] disjoint from [1, L(n)], return.
                    // 2. If fully contained? Optimization: count ones in n?
                    //    Actually, number of ones in sequence of n is popcount(n) ?
                    //    Let's check: n=5 (101b). Popcount(5)=2. Seq(5)=[1,0,1,1,1,0,1]. Ones=6. Not popcount.
                    //    Number of ones = popcount(n) is not correct.
                    //    Wait, number of ones in Sequence(n) is equal to the number of 1s in the recursive structure.
                    //    It's actually equal to the number of set bits in the expansion.
                    //    Let's stick to counting the range.
                    
                    // Action in UPDATE_RESULT:
                    // Calculate L(n).
                    // Check overlap.
                    // If no overlap: state <= POP_AND_PROCESS (backtrack).
                    // If fully contained (and we can optimize): add to result (Optimization skipped for simplicity).
                    // If partial/overlap:
                    //   If n <= 1: if overlap, add (n==1?1:0). Backtrack.
                    //   If n > 1:
                    //     Calculate LeftLen.
                    //     Check Left overlap: [curr_l, curr_r] vs [1, LeftLen].
                    //     If overlaps, push (n/2, max(1, curr_l), min(curr_r, LeftLen)).
                    //     Check Middle: index LeftLen+1. If overlaps, add 1 to result.
                    //     Check Right overlap: [curr_l, curr_r] vs [LeftLen+2, L(n)].
                    //     If overlaps, push (n/2, curr_l - (LeftLen+1), curr_r - (LeftLen+1)).
                    //     If any children pushed, we need to process them before backtracking.
                    //     We can push Right, then Left, then Middle? 
                    //     Order doesn't matter for sum. 
                    //     We can push to stack and then POP_AND_PROCESS will handle them.
                    //     But we need to ensure we don't backtrack until children are processed.
                    //     
                    //     We need to implement a loop in UPDATE_RESULT or multiple states.
                    //     Since we can push multiple items, we should transition to PUSH_CALL.
                    //     
                    //     Refined Plan:
                    //     1. Calculate L(n) -> stored in current_len.
                    //     2. Calculate LeftLen -> stored in sub_len.
                    //     3. Check Left: if (curr_l <= sub_len && curr_r >= 1) ...
                    //        If yes, push Left to stack, set state to PUSH_CALL.
                    //        But we need to handle Middle and Right too.
                    //        We can't push all 3 at once if stack space is tight, but it is.
                    //        However, we are processing DFS. 
                    //        Let's try to process Middle immediately, and push Left/Right.
                    //        If we push Right then Left, they will be popped Left then Right (LIFO).
                    //        We want to traverse Left first? DFS usually Left -> Root -> Right.
                    //        But we are summing. Order doesn't matter.
                    //        So we can push Right, then push Left. 
                    //        
                    //     Special case: Optimization for n <= 1.
                    //     
                    //     This state is complex. Let's break it down.
                    //     We need a temporary counter to compute Length. 
                    //     We can add a sub-state `CALC_LEN_LOOP` inside UPDATE_RESULT logic?
                    //     Or we can use `state` to encode steps.
                    //     Let's use a flag `calc_len_done` inside the state.
                    //     We need to compute L(n) and sub_len.
                    //     We can do: 
                    //       if (curr_n <= 1) ...
                    //       else begin
                    //         // We need to compute L(n/2).
                    //         // This is recursive. 
                    //         // To save state space, we can iterate.
                    //         // Let's use `temp_n` and `temp_len`.
                    //         // `temp_n` = curr_n >> 1.
                    //         // Compute Len of `temp_n` iteratively.
                    //         // This is a loop. 
                    //         // Since we can't loop in one cycle, we need a state for this.
                    //         
                    //         // Alternative: The problem says max n is 2^16.
                    //         // The sequence length for n is roughly 2^(k+1)-1 where k is bit width.
                    //         // Actually, L(n) = (2^(ceil(log2(n+1))) * 2) - 1 is NOT correct for non-powers of 2.
                    //         // Example: n=5. 2^3-1=7. Correct.
                    //         // n=4. 2^3-1=7. Sequence(4): [1,0,1, 0, 1,0,1]. Length 7. Correct.
                    //         // n=3. 2^2-1=3. Seq(3): [1,1,1]. Length 3.
                    //         // n=2. 2^2-1=3. Seq(2): [1,0,1]. Length 3.
                    //         // So L(n) = 2^(ceil(log2(n+1))) - 1? 
                    //         // n=1 -> 2^1-1=1. OK.
                    //         // n=0 -> 2^0-1? No, L(0)=1.
                    //         // Let's check n=6. n+1=7, log2(7)=2.8, ceil=3, 2^3=8, 8-1=7. Seq(6): [1,0,1,1,1,0,1]. Length 7. Correct.
                    //         // n=7. n+1=8, log2=3, 2^3=8, 8-1=7. Seq(7)=[1,1,1,1,1,1,1]. Length 7. Correct.
                    //         // So L(n) = (1 << (ceil_log2(n+1))) - 1, except n=0 gives 1.
                    //         // Since we have integer math, we can find the MSB of (n+1).
                    //         // If n=0, L=1. Else, find smallest k such that 2^k > n.
                    //         // Actually, n+1 > 2^(k-1) and n+1 <= 2^k.
                    //         // L(n) = 2^k - 1.
                    //         // We can compute k by finding MSB of n+1. 
                    //         // If n+1 is power of 2, k = log2(n+1). If not, k = floor(log2(n+1)) + 1.
                    //         // So k = 32 - clz(n+1 - 1) ? No.
                    //         // k = 32 - count_leading_zeros(n). 
                    //         // Let's use `priority_encoder` logic or a loop to find k.
                    //         // Since this is a state machine, we can compute `current_len` in a few cycles.
                    //         
                    //         // Actually, let's just use a pre-calculated lookup or iterative logic.
                    //         // We have 50k cycles. We can spend 16 cycles to compute length.
                    //         // But let's stick to the definition: L(n) = 2*L(floor(n/2)) + 1.
                    //         // We can compute this in a loop:
                    //         // Initialize: len = 1, temp_n = n.
                    //         // while temp_n > 1: temp_n = temp_n >> 1; len = (len << 1) | 1.
                    //         // Wait, this gives L(n) = 2*L(n/2)+1.
                    //         // Let's implement this loop in UPDATE_RESULT.
                    //         
                    //     end
                    
                    // Let's implement the loop logic.
                    // We need a temporary variable `temp_n` and `temp_len`.
                    // If `calc_flag` is not set, initialize temp_n = curr_n, temp_len = 1.
                    // Then transition to `CALC_LEN_LOOP` state.
                    // 
                    // But wait, we need to handle the case where we are in UPDATE_RESULT.
                    // If we have calculated L(n), we need to know it.
                    // Let's add a state `CALCULATE_LENGTH` that takes n from curr_n and computes length.
                    // Actually, we can compute length of n/2 recursively or iteratively.
                    // Let's try to keep it simple: `UPDATE_RESULT` will trigger `CALC_LEN`.
                    
                    // Let's define a temporary length register `t_len` and `t_n`.
                    // We need to compute length of curr_n (to know total range) and length of curr_n/2 (to split).
                    // Actually, we need two lengths: L(n) and L(floor(n/2)).
                    // 
                    // Optimization: We can compute L(n) iteratively in a separate state.
                    // But we have limited states.
                    // Let's restructure.
                    // 
                    // In UPDATE_RESULT:
                    //   if (curr_n == 0) -> if overlap, result++. Backtrack.
                    //   if (curr_n == 1) -> if overlap, result++. Backtrack.
                    //   if (curr_n > 1):
                    //     Compute L(floor(curr_n/2)). Let's call it `sub_len`.
                    //     (We also need L(curr_n) = 2*sub_len + 1).
                    //     
                    //     Check Left: range [1, sub_len].
                    //       Overlap logic: if (curr_l <= sub_len && curr_r >= 1) ...
                    //       new_l = max(1, curr_l), new_r = min(curr_r, sub_len).
                    //       If valid, push (floor(curr_n/2), new_l, new_r).
                    //     
                    //     Check Middle: index = sub_len + 1.
                    //       if (curr_l <= sub_len+1 && curr_r >= sub_len+1) result++.
                    //     
                    //     Check Right: range [sub_len+2, 2*sub_len+1].
                    //       if (curr_l <= 2*sub_len+1 && curr_r >= sub_len+2) ...
                    //       new_l = curr_l - (sub_len+1), new_r = curr_r - (sub_len+1).
                    //       If valid, push (floor(curr_n/2), new_l, new_r).
                    //     
                    //     Then state <= POP_AND_PROCESS (to pop the pushes we just did).
                    //     
                    //     The challenge is computing `sub_len`.
                    //     `sub_len` = L(floor(n/2)).
                    //     We can compute it by iterating on floor(n/2).
                    //     We can use a loop state.
                    
                    // Let's add a state `COMPUTE_SUB_LEN`.
                    // We will use `temp_n` for the loop.
                    // 
                    // Actually, we can do everything in `UPDATE_RESULT` if we assume we can compute length in one cycle?
                    // No, length depends on n.
                    // Let's break UPDATE_RESULT into:
                    // 1. Setup (check base cases, or init loop for length).
                    // 2. Loop to compute length.
                    // 3. Split and Push.
                    // 
                    // We can use `state` to count.
                    // 
                    // Let's use `state` as `UPDATE_RESULT` and use internal counters.
                    // We need a `step` counter.
                    // step 0: Setup. If base case, handle. Else, init length calc. step=1. Stay in state.
                    // step 1: Compute length. step=2. Stay in state.
                    // step 2: Split and Push. step=0. Go to POP_AND_PROCESS.
                    // 
                    // But Verilog state machine usually doesn't use internal counters for states unless encoded.
                    // We can use explicit states: UPDATE_CALC_LEN, UPDATE_SPLIT.
                    
                    // Let's do:
                    // UPDATE_RESULT:
                    //   if (curr_n <= 1) begin
                    //     if (overlap) result += curr_n;
                    //     state <= POP_AND_PROCESS;
                    //   end else begin
                    //     // Setup length calc for floor(curr_n/2)
                    //     temp_n <= curr_n >> 1;
                    //     temp_len <= 1;
                    //     state <= UPDATE_CALC_LEN;
                    //   end
                    
                    // UPDATE_CALC_LEN:
                    //   if (temp_n > 1) begin
                    //     temp_n <= temp_n >> 1;
                    //     temp_len <= (temp_len << 1) | 1;
                    //   end else begin
                    //     // temp_len is now L(floor(n/2))
                    //     sub_len <= temp_len;
                    //     state <= UPDATE_SPLIT;
                    //   end
                    // 
                    // UPDATE_SPLIT:
                    //   // Perform overlap checks and pushes
                    //   // We need to push Left and Right.
                    //   // We can push Right, then Left (so Left is popped first).
                    //   // Or push Left, then Right (Right popped first). 
                    //   // Order doesn't matter for sum.
                    //   // However, we must ensure we don't return to POP_AND_PROCESS until pushes are done.
                    //   // We can push all valid children, then go to POP_AND_PROCESS.
                    //   // But we can only push one per cycle (if we use state transitions).
                    //   // We can use sub-states or flags.
                    //   // Let's use a flag `pushed_something`.
                    //   // If we need to push Left, push it, set flag.
                    //   // If we need to push Right, push it, set flag.
                    //   // If flag set, we need to process the stack. Go to POP_AND_PROCESS.
                    //   // If no pushes, go to POP_AND_PROCESS (backtrack).
                    //   
                    //   // Wait, if we push Left, we want to process it immediately (DFS).
                    //   // So we should push Right, then Left, then go to POP_AND_PROCESS.
                    //   // POP_AND_PROCESS will pop Left (top of stack), process it.
                    //   // When Left is done, it returns to POP_AND_PROCESS, pops Right.
                    //   // This works.
                    //   
                    //   // Logic:
                    //   // Check Right overlap. If valid, push Right.
                    //   // Check Left overlap. If valid, push Left.
                    //   // Check Middle. If valid, add to result.
                    //   // State <= POP_AND_PROCESS.
                    //   
                    //   // Wait, if we push Left and Right, then go to POP_AND_PROCESS.
                    //   // SP will be increased.
                    //   // In POP_AND_PROCESS, we pop.
                    //   // This works.
                    //   
                    //   // However, we need to be careful with `curr_n`, `curr_l`, `curr_r` usage.
                    //   // These are used in `UPDATE_SPLIT`.
                    //   // We need to save them? No, they are valid for the current node.
                    //   // We compute child ranges based on them.
                    //   // 
                    //   // We need `temp` registers for the child data before pushing.
                    //   // Let's use `next_n`, `next_l`, `next_r`.
                    //   
                    //   // Let's refine `UPDATE_SPLIT`.
                    //   // It takes 3 cycles to be safe, or use internal logic.
                    //   // We can do:
                    //   // Cycle 1: Check Right. If valid, prepare `next_n`, `next_l`, `next_r` and push.
                    //   // Cycle 2: Check Left. If valid, prepare and push.
                    //   // Cycle 3: Check Middle. Update result.
                    //   // Cycle 4: State <= POP_AND_PROCESS.
                    //   // 
                    //   // Or we can compute everything in one cycle and push.
                    //   // But we can only update SP once per cycle (usually).
                    //   // If we need to push two items, we need two cycles or a dual-port stack.
                    //   // We only have single port RAM (inferred).
                    //   // So we need two cycles to push 2 items.
                    //   // 
                    //   // Revised `UPDATE_SPLIT` states:
                    //   // SPLIT_0: Compute overlaps. Check Right. If valid, push Right. If pushed, go to SPLIT_1. Else go to SPLIT_1.
                    //   // SPLIT_1: Check Left. If valid, push Left. If pushed, go to SPLIT_2. Else go to SPLIT_2.
                    //   // SPLIT_2: Check Middle. Update result. State <= POP_AND_PROCESS.
                    //   // 
                    //   // Let's combine `UPDATE_CALC_LEN` and `UPDATE_SPLIT` into a sequence.
                    //   // We'll use `state` as UPDATE_RESULT.
                    //   // And use `sub_state` (3 bits) to track steps.
                    //   // sub_state 0: Init. Base cases? No, handle base cases in a separate check.
                    //   // 
                    //   // Let's try to keep the code clean.
                    //   // We will have `UPDATE_RESULT_LEN` and `UPDATE_RESULT_SPLIT`.
                    //   // Actually, we can use `state` for `UPDATE_RESULT_LEN` (computing length) and `UPDATE_RESULT_SPLIT` (splitting).
                    //   // And a flag `split_step` to handle multiple pushes.
                    //   
                    //   // Let's go with:
                    //   // `UPDATE_RESULT_LEN`: Computes length of floor(curr_n/2) and stores in `sub_len`.
                    //   // `UPDATE_RESULT_SPLIT`: Performs overlap checks and pushes. 
                    //   // We need to handle 3 pushes (Right, Left, Middle).
                    //   // We can use a small counter inside `UPDATE_RESULT_SPLIT`.
                    //   // `split_counter` 0, 1, 2.
                    //   // 0: Right. 1: Left. 2: Middle. 3: Done.
                    //   // 
                    //   // Let's verify `sub_len` calculation.
                    //   // `sub_len` = L(floor(n/2)).
                    //   // `sub_len` is needed to calculate ranges.
                    //   // 
                    //   // Let's implement `UPDATE_RESULT` as the entry point.
                    //   // It will branch to `CALC_LEN_LOOP` if needed.
                    //   // `CALC_LEN_LOOP` computes `sub_len`.
                    //   // Then goes to `SPLIT`.
                    //   // `SPLIT` handles pushes.
                    //   // Finally `POP_AND_PROCESS`.
                    
                    // Let's refine the state list to include these specifics.
                    // We have: IDLE, PUSH_CALL, POP_AND_PROCESS, UPDATE_RESULT, DONE.
                    // We need to compute length. 
                    // We can use `UPDATE_RESULT` to initiate length calculation.
                    // But we need a loop.
                    // Let's add `COMPUTE_LEN` state.
                    // Or use `UPDATE_RESULT` and a flag `len_calc_done`.
                    // Since we need to calculate L(floor(n/2)), we need to loop.
                    // Let's use `state = UPDATE_RESULT` and a counter `op_step`.
                    // op_step 0: Check base cases. If n<=1, update result, state=POP.
                    //            Else, init len calc. op_step=1.
                    // op_step 1: Decrement len calc loop. op_step=2 if done.
                    // op_step 2: Split. 
                    // This is getting complicated for a simple state machine.
                    
                    // Let's introduce a dedicated state `COMPUTE_SUB_LEN`.
                    // This state takes `curr_n`, computes floor(curr_n/2), then computes L(floor(curr_n/2)).
                    // It stores result in `sub_len`.
                    // Then state goes to `SPLIT`.
                    // `SPLIT` state handles the logic of pushing.
                    // Since we can only push one per cycle, we need multiple cycles.
                    // We can use `SPLIT` and a counter `split_step`.
                    // split_step 0: Check Right. If valid push. If pushed, split_step=1. Else split_step=1.
                    // split_step 1: Check Left. If valid push. If pushed, split_step=2. Else split_step=2.
                    // split_step 2: Check Middle. Update result. split_step=0. State=POP.
                    
                    // This seems robust.
                    // So we need:
                    // 1. UPDATE_RESULT (entry point)
                    // 2. COMPUTE_SUB_LEN
                    // 3. SPLIT
                    // 
                    // Let's start writing the code for these blocks.
                    // We need registers for `temp_n`, `temp_len`, `split_step`.
                    // `temp_n`, `temp_len` can be shared.
                    // `split_step` is needed.
                    // `child_l`, `child_r` to store computed child ranges.
                    
                    // Register definitions:
                    reg [15:0] temp_n;
                    reg [31:0] temp_len;
                    reg [1:0] split_step;
                    // We need to store computed child ranges for pushes.
                    // We can compute them on the fly in SPLIT.
                    // For Right push: we need (n/2, curr_l - (sub_len+1), curr_r - (sub_len+1)).
                    // For Left push: (n/2, max(1, curr_l), min(curr_r, sub_len)).
                    // We can compute these in the specific step.
                    // We need `n/2` value.
                    // Let's store `child_n = curr_n >> 1`.
                    
                    // Let's implement the logic now.
                end
                
                // We need to break down UPDATE_RESULT.
                // Since I can't modify the case statement structure inside the AI response easily, 
                // I will perform the logic inside the UPDATE_RESULT case block using if-else chains.
                // I will use flags to transition to other states if multi-cycle operations are needed.
                
                // Re-evaluated Logic for UPDATE_RESULT block:
                // We are in UPDATE_RESULT. 
                // Case 1: curr_n <= 1.
                //   Check overlap. Update result. State <= POP_AND_PROCESS.
                // Case 2: curr_n > 1.
                //   We need to compute L(floor(curr_n/2)).
                //   Let's do this iteratively in a separate state `COMPUTE_SUB_LEN`.
                //   So, in UPDATE_RESULT, we check if curr_n <= 1. 
                //   If yes, process.
                //   If no, set up `temp_n = curr_n >> 1`, `temp_len = 1`, go to `COMPUTE_SUB_LEN`.
                //   
                //   Wait, we need to include this logic in the code.
                //   The `state` variable is `UPDATE_RESULT`. 
                //   I will use an internal `op_state` register for multi-cycle ops inside `UPDATE_RESULT`?
                //   No, let's add `COMPUTE_LEN` and `SPLIT` states to the main state machine.
                //   This is cleaner.

                // RE-EDITING STATE MACHINE DEFINITION:
                // We have IDLE, PUSH_CALL, POP_AND_PROCESS, DONE.
                // We need UPDATE_RESULT, COMPUTE_SUB_LEN, SPLIT.
                // Actually, we can merge COMPUTE_SUB_LEN and SPLIT into UPDATE_RESULT logic if we use sub-registers.
                // But let's add `STATE_COMPUTE` and `STATE_SPLIT`.
                // Total states: IDLE, PUSH_CALL, POP_AND_PROCESS, UPDATE_RESULT, COMPUTE_LEN, SPLIT, DONE.
                // Wait, `UPDATE_RESULT` was the entry point. Let's make it `UPDATE_CHECK`.
                // `UPDATE_CHECK` checks base cases. If base, update and POP. If not, go to `COMPUTE_LEN`.
                // `COMPUTE_LEN` computes sub_len.
                // `SPLIT` does the work.
                // Then back to POP.

                // Let's adjust the code structure to reflect this.
                // But I am writing in one block. I will use a variable `local_state` or `op_step` to manage flow within `UPDATE_RESULT`.
                // No, let's stick to the defined states: IDLE, CALCULATE_LEN, PUSH_CALL, POP_AND_PROCESS, UPDATE_RESULT, DONE.
                // I will use `UPDATE_RESULT` as a multi-cycle state using an internal counter `res_step`.
            endcase
        end
    end

    // Auxiliary Logic (Separate combinational or sequential blocks)
    // Since we need to compute length iteratively, we need a loop.
    // We can do this in a separate always block or integrate into the main FSM.
    // Let's try to integrate everything into the main FSM but add `COMPUTE_LEN` and `SPLIT` states.
    // Since I already wrote the skeleton, let's fill in `UPDATE_RESULT` logic carefully.
    
    // Registers for multi-cycle operations
    reg [15:0] temp_n_reg;
    reg [31:0] temp_len_reg;
    reg [2:0] op_step; 
    // op_step usage:
    // 0: Start. Check n. If n<=1, handle. Else, init len calc.
    // 1: Len calc loop.
    // 2: Split setup/step 0 (Right).
    // 3: Split step 1 (Left).
    // 4: Split step 2 (Middle).
    // 5: Done splitting.

    // We need to modify the always block to include `COMPUTE_LEN` and `SPLIT` states.
    // Let's stick to `UPDATE_RESULT` state and use `op_step`.
    
    // Revised Always Block:
    // Since I can't easily rewrite the previous block, I will append logic.
    // But wait, I must return a valid JSON.
    // I will assume I can refactor the FSM to have `UPDATE_RESULT` handle everything with `op_step`.
    // Or I can add `COMPUTE_LEN` and `SPLIT` to the state definition.
    // Let's add them to the localparam list and implement them.

    // Let's update the localparam list in the code above (mentally) to:
    // localparam IDLE = 3'b000;
    // localparam PUSH_CALL = 3'b010; // Actually, we had CALCULATE_LEN. I removed it in thought. 
    // Let's keep it simple: IDLE, PROCESS, PUSH, POP, DONE. 
    // No, I'll stick to the initial list but add `COMPUTE_LEN` and `SPLIT`.
    // Actually, I will handle `UPDATE_RESULT` by branching immediately in the FSM.
    // I'll use `op_step` to manage sub-states.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            sp <= 0;
            op_step <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        l_reg <= l_in;
                        r_reg <= r_in;
                        result <= 32'd0;
                        sp <= 0;
                        // We need to push the initial node (n, 1, L(n)? No, we don't know L(n) yet).
                        // Actually, for the root, we just use (n, l, r).
                        // The DFS logic in POP_AND_PROCESS/UPDATE will determine ranges relative to the tree.
                        // But we need to know the global position of the tree nodes.
                        // The stack should store (n, global_start).
                        // The query range (l, r) is fixed. 
                        // Let's store (n, global_start) on stack.
                        // When popping, we know the node covers [global_start, global_start + L(n) - 1].
                        // We compare this with [l, r].
                        // If we push children, we calculate their global_start.
                        // So, stack needs (n, global_start).
                        // global_start is 32-bit (since L(n) can be large).
                        // But inputs are 14-bit. Max index is 2^14 = 16384.
                        // Wait, the problem says "Maximum length of sequence to approx 16383".
                        // And indices are 14-bit. 
                        // So global indices fit in 14 bits.
                        // But L(n) calculation might overflow 14 bits if n is large.
                        // Input n is 16-bit. L(n) for n=2^16-1 is huge.
                        // However, we are restricted to max length 16383.
                        // This implies we only care about the part of the sequence that falls within valid indices.
                        // Wait, if n is large, the sequence is long, but we only query [l, r].
                        // If the sequence is longer than r, we can prune.
                        // The constraint "maximum length ... 16383" suggests we should not generate indices > 16383 or handle n that produces length > 16383.
                        // But inputs are 16-bit. 
                        // Let's assume we must handle n up to 2^16, but we only care about indices up to 16383.
                        // If a node's start index > 16383, we can discard it.
                        // 
                        // Let's use the (n, global_start) model.
                        // Stack size: n(16) + start(14) = 30 bits. 
                        // We need to store end index? No, we compute it.
                        // 
                        // Initial Push: (n_in, 1).
                        // We need to compute L(n_in) to check if the tree fits in range? 
                        // If L(n_in) < l_in, result is 0. 
                        // We can check this before starting.
                        // But let's just push (n_in, 1).
                        // 
                        // Let's update the stack to store (n, start_idx).
                        // We need to change `stack_l` and `stack_r` to `stack_start`.
                        // And we need to know the query range (l, r) globally.
                        // So `l_reg` and `r_reg` remain as global query bounds.
                        // 
                        // Wait, I need to modify the stack declaration.
                        // stack_n [0:15]
                        // stack_start [0:15] (14 bit).
                        // I will change the stack memory.
                        // 
                        // Let's implement the logic with (n, start_idx).
                        // 
                        // Steps:
                        // 1. IDLE -> PUSH_CALL.
                        //    Before PUSH_CALL, we set curr_n = n_in, curr_start = 1.
                        //    Wait, we need to push (n_in, 1).
                        //    So in IDLE, set curr_n = n_in, curr_start = 1.
                        //    Then PUSH_CALL pushes these.
                        // 
                        // 2. PUSH_CALL pushes (curr_n, curr_start).
                        //    Then state = POP_AND_PROCESS.
                        // 
                        // 3. POP_AND_PROCESS pops to (curr_n, curr_start).
                        //    Then state = UPDATE_RESULT.
                        // 
                        // 4. UPDATE_RESULT:
                        //    Calculate L(curr_n). (We need to be careful with overflow).
                        //    Let's call the calculated length `len_curr`.
                        //    The node covers range [curr_start, curr_start + len_curr - 1].
                        //    Let's call this range [node_l, node_r].
                        //    
                        //    Check overlap with global [l_reg, r_reg].
                        //    If (node_r < l_reg) or (node_l > r_reg) -> No overlap. Backtrack (state = POP).
                        //    
                        //    If overlap:
                        //    If curr_n == 0: If overlap, result += 0. Backtrack.
                        //    If curr_n == 1: If overlap, result += 1. Backtrack.
                        //    If curr_n > 1:
                        //      Calculate Len(sub) = L(floor(curr_n/2)).
                        //      We need Len(sub) to split.
                        //      
                        //      Left Child: covers [node_l, node_l + Len(sub) - 1].
                        //      Middle: node_l + Len(sub).
                        //      Right Child: covers [node_l + Len(sub) + 1, node_r].
                        //      
                        //      We push Right, then Left.
                        //      And we update result if Middle overlaps.
                        //      
                        //      We need to calculate Len(sub) here.
                        //      This takes cycles.
                        //      Let's use a sub-state or a helper state.
                        //      I will use a state `CALCULATE_SUB_LEN`.
                        //      
                        //      In UPDATE_RESULT:
                        //      Check overlap. If no, Backtrack.
                        //      If yes:
                        //        If n <= 1, update result, Backtrack.
                        //        Else, state = CALCULATE_SUB_LEN.
                        //        
                        // 5. CALCULATE_SUB_LEN:
                        //    Takes n = curr_n, calculates L(floor(n/2)).
                        //    Stores in `sub_len`.
                        //    Then state = SPLIT.
                        //    
                        // 6. SPLIT:
                        //    Handles the three parts.
                        //    We need to know node_l (start index).
                        //    node_l = curr_start.
                        //    node_r = curr_start + L(n) - 1. 
                        //    Wait, we didn't store L(n) or calculate it.
                        //    We need L(n) for the overlap check.
                        //    In UPDATE_RESULT, we need L(n).
                        //    So UPDATE_RESULT must calculate L(n) first.
                        //    Or, we can compute L(n) in a dedicated state `CALCULATE_LEN`.
                        //    
                        //    Let's simplify:
                        //    PUSH_CALL pushes (n, start).
                        //    POP_AND_PROCESS pops (n, start).
                        //    UPDATE_RESULT:
                        //      Calculate L(n). -> state CALC_LEN_N.
                        //      
                        //    CALC_LEN_N:
                        //      Compute L(n). Store in `len_curr`.
                        //      Check overlap with [l, r].
                        //      If no overlap, state = POP.
                        //      If overlap:
                        //        if n<=1, update result, state=POP.
                        //        else, calculate L(n/2). -> state CALC_LEN_SUB.
                        //      
                        //    CALC_LEN_SUB:
                        //      Compute L(n/2). Store in `sub_len`.
                        //      state = SPLIT.
                        //      
                        //    SPLIT:
                        //      node_l = start.
                        //      node_r = start + len_curr - 1.
                        //      mid = start + sub_len.
                        //      
                        //      Right child: (n/2, mid + 1).
                        //      Left child: (n/2, start).
                        //      
                        //      We need to push Right, then Left.
                        //      Use steps.
                        //      Step 0: Push Right (if valid overlap). If pushed, next step. Else step 1.
                        //      Step 1: Push Left (if valid overlap). If pushed, next step. Else step 2.
                        //      Step 2: Check Mid. Update result. State = POP.
                        //      
                        //      Overlap check for children:
                        //      For Right: [mid+1, node_r] overlaps [l, r]?
                        //      For Left: [start, start+sub_len-1] overlaps [l, r]?
                        //      
                        //      We need to be careful with `start`.
                        //      In SPLIT, we have `start` (from stack pop).
                        //      We have `sub_len`.
                        //      We have `len_curr`.
                        //      
                        //      We also need to handle the case where `sub_len` might be huge.
                        //      The indices are 14-bit. 
                        //      We need to perform calculations in 32-bit to avoid overflow before comparison with 14-bit inputs?
                        //      Wait, `start` is 14-bit (from input). 
                        //      But `start + len_curr` can exceed 14 bits.
                        //      However, we are restricted to indices up to 16383.
                        //      So if `start` > 16383, we can discard.
                        //      Also, `start` is 1-based.
                        //      If `start` > 16383, stop.
                        //      
                        //      Let's use `node_l` and `node_r` as 32-bit for calc, but check bounds.
                        //      If `node_l` > 16383, backtrack.
                        //      
                        //      This looks like a robust plan.

                        // Let's update the stack memory to store (n, start).
                        // Stack width: 16 + 14 = 30 bits.
                        // We need to declare `stack_start` array.
                        // 
                        // I will proceed with this plan.
                        
                        // Initial Setup:
                        curr_n <= n_in;
                        curr_start <= 14'd1; // 1-based index
                        state <= PUSH_CALL;
                    end
                end

                PUSH_CALL: begin
                    // Push (curr_n, curr_start)
                    if (sp < STACK_DEPTH) begin
                        stack_n[sp] <= curr_n;
                        stack_start[sp] <= curr_start;
                        sp <= sp + 1;
                        state <= POP_AND_PROCESS;
                    end else begin
                        // Stack overflow
                        state <= DONE;
                    end
                end

                POP_AND_PROCESS: begin
                    if (sp > 0) begin
                        sp <= sp - 1;
                        curr_n <= stack_n[sp - 1];
                        curr_start <= stack_start[sp - 1];
                        state <= UPDATE_RESULT;
                    end else begin
                        state <= DONE;
                    end
                end

                UPDATE_RESULT: begin
                    // Need to calculate L(curr_n) to check overlap.
                    // We'll use a loop in this state or a dedicated state.
                    // To save states, let's use a dedicated state CALC_LEN_N.
                    state <= CALC_LEN_N;
                end

                CALC_LEN_N: begin
                    // Compute L(curr_n).
                    // If curr_n <= 1, len_curr = 1.
                    // Else, we need to iterate.
                    // We can use a small loop counter.
                    // Or we can compute it based on bit width.
                    // Since we need to support up to n=2^16, L(n) can be huge.
                    // But we only care about range up to 16383.
                    // If L(curr_n) is huge, we might have issues with `node_r` calculation.
                    // We will compute L(curr_n) into `len_curr` (32-bit).
                    // 
                    // Iterative calc:
                    // temp_n = curr_n
                    // temp_len = 1
                    // while temp_n > 1: temp_n >> 1; temp_len = (temp_len << 1) | 1.
                    // 
                    // Since we are in a state, we can do this in one cycle if we unroll, or use `op_step`.
                    // Let's use `op_step` for length calculations.
                    // 
                    // Logic:
                    // if (op_step == 0) begin
                    //   if (curr_n <= 1) begin len_curr <= 1; op_step <= 1; end
                    //   else begin temp_n <= curr_n >> 1; temp_len <= 1; op_step <= 2; end
                    // end
                    // if (op_step == 2) begin // Loop
                    //   if (temp_n > 1) begin
                    //     temp_n <= temp_n >> 1;
                    //     temp_len <= (temp_len << 1) | 1;
                    //   end else begin
                    //     len_curr <= (temp_len << 1) | 1; // L(n) = 2*L(n/2)+1
                    //     op_step <= 1; // Done
                    //   end
                    // end
                    // if (op_step == 1) begin // Check overlap
                    //   ... 
                    //   op_step <= 0; // Reset for next usage
                    // end
                    
                    // Wait, `len_curr` needs to be stored for later use (SPLIT).
                    // Also `sub_len` for SPLIT.
                    // Let's manage `op_step` carefully.
                    
                    // Let's define `calc_step` register to handle length calculations.
                    // 0: Idle
                    // 1: Calc Len(N) Init
                    // 2: Calc Len(N) Loop
                    // 3: Check Overlap & Split
                    
                    // We can perform Calc Len(N) and Split in separate states to keep code clean.
                    // Let's stick to: 
                    // UPDATE_RESULT -> CALC_LEN_N -> CHECK_OVERLAP -> SPLIT (if n>1) or UPDATE_RESULT -> POP (if n<=1).
                    // This is getting complex for a single response.
                    
                    // Optimization: 
                    // Use `op_step` within `UPDATE_RESULT` to manage the flow.
                    // Step 0: Check if curr_n <= 1. If yes, update result, go POP.
                    // Step 1: Init Len(N) calculation.
                    // Step 2: Loop Len(N).
                    // Step 3: Calculate sub_len.
                    // Step 4: Perform split/push.
                    
                    // Since we need to handle 50k cycles, we can afford many states.
                    // Let's define a specific state for splitting: `STATE_SPLIT`.
                    // And a state for calculating length: `STATE_CALC_LEN`.
                    
                    // Revised State List:
                    // IDLE
                    // PUSH
                    // POP
                    // CALC_LEN_N
                    // CALC_LEN_SUB
                    // SPLIT
                    // DONE
                    // 
                    // Flow:
                    // IDLE -> PUSH (push root)
                    // PUSH -> POP
                    // POP -> CALC_LEN_N
                    // CALC_LEN_N -> if overlap (and n>1) -> CALC_LEN_SUB. else if overlap (n<=1) -> UPDATE_RESULT (add) -> POP. else -> POP.
                    // CALC_LEN_SUB -> SPLIT
                    // SPLIT -> PUSH (Right) or PUSH (Left) or CHECK MID -> POP.
                    
                    // I will implement this flow.
                end
            endcase
        end
    end

    // --- HELPER LOGIC FOR FSM ---
    // Since the previous always block was getting too dense, I will add the implementation details here.
    // However, for synthesizable code, I should stick to one always block for the state machine.
    // I will use `case` with internal `op_state` or `step` to handle multi-cycle logic within specific states.
    // Let's go with the `step` approach inside `UPDATE_RESULT`, `CALC_LEN_N`, `SPLIT`.
    
    // Wait, I need to declare `stack_start` and other registers I mentioned.
    // I will add them to the module port list.

endmodule

// Helper module? No, keep it monolithic.

// Let's write the clean version of the FSM.
// I'll use a 'step' register to control the sequence of operations within states.

module count_ones_range(
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    input [13:0] l_in,
    input [13:0] r_in,
    output reg [31:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CALC_LEN_N = 3'b001; // Calculate length of current node
    localparam PUSH_CALL = 3'b010;  // Push to stack
    localparam POP_PROC = 3'b011;   // Pop and process
    localparam CALC_LEN_SUB = 3'b100; // Calculate length of sub-node (n/2)
    localparam SPLIT = 3'b101;      // Split node and push children
    localparam DONE_STATE = 3'b110;

    reg [2:0] state;
    reg [1:0] step; // Sub-state counter
    
    // Stack Parameters
    localparam STACK_DEPTH = 16;
    localparam STACK_ADDR_W = 4;
    
    // Stack memory (n, start_idx)
    reg [15:0] stack_n [0:STACK_DEPTH-1];
    reg [13:0] stack_start [0:STACK_DEPTH-1];
    reg [STACK_ADDR_W:0] sp;
    
    // Input registers
    reg [15:0] n_reg;
    reg [13:0] l_reg;
    reg [13:0] r_reg;
    
    // Working registers
    reg [15:0] curr_n;
    reg [13:0] curr_start;
    
    // Computation registers
    reg [31:0] len_curr; // Length of current node
    reg [31:0] sub_len;  // Length of sub-node (n/2)
    reg [15:0] temp_n;   // Temp for iteration
    reg [31:0] temp_len; // Temp for iteration
    
    // Helper wires for overlap checking
    wire [31:0] node_l;
    wire [31:0] node_r;
    wire [31:0] left_l, left_r;
    wire [31:0] mid;
    wire [31:0] right_l, right_r;
    
    assign node_l = {18'b0, curr_start}; // Zero extend 14-bit to 32-bit
    assign node_r = node_l + len_curr - 1;
    assign left_l = node_l;
    assign left_r = node_l + sub_len - 1;
    assign mid = node_l + sub_len;
    assign right_l = mid + 1;
    assign right_r = node_r;
    
    // Registers for tracking overlaps and pushes
    reg push_right;
    reg push_left;
    reg add_mid;
    reg [13:0] next_start; // Temp to store start for child
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            sp <= 0;
            step <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        l_reg <= l_in;
                        r_reg <= r_in;
                        result <= 32'd0;
                        sp <= 0;
                        // Prepare initial node
                        curr_n <= n_in;
                        curr_start <= 14'd1;
                        state <= PUSH_CALL;
                        step <= 0;
                    end
                end

                PUSH_CALL: begin
                    // Push (curr_n, curr_start)
                    if (sp < STACK_DEPTH) begin
                        stack_n[sp] <= curr_n;
                        stack_start[sp] <= curr_start;
                        sp <= sp + 1;
                    end
                    // Always go to POP_PROC to process this node (or just added node)
                    // Actually, we want to process the node we just pushed or the one on top.
                    // If we pushed, we should process it. So POP_PROC is correct.
                    state <= POP_PROC;
                end

                POP_PROC: begin
                    if (sp > 0) begin
                        sp <= sp - 1;
                        curr_n <= stack_n[sp - 1];
                        curr_start <= stack_start[sp - 1];
                        state <= CALC_LEN_N;
                        step <= 0;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                CALC_LEN_N: begin
                    // Step 0: Initialize or Check Base Cases
                    if (step == 0) begin
                        if (curr_n <= 1) begin
                            len_curr <= 32'd1;
                            step <= 2; // Skip calc loop, go to check overlap logic (handle in step 2)
                        end else begin
                            // Init loop: n/2, len=1
                            temp_n <= curr_n >> 1;
                            temp_len <= 32'd1;
                            step <= 1;
                        end
                    end else if (step == 1) begin
                        // Loop to compute L(n/2)
                        if (temp_n > 1) begin
                            temp_n <= temp_n >> 1;
                            temp_len <= (temp_len << 1) | 1;
                        end else begin
                            // L(n/2) calculated -> temp_len
                            // L(n) = 2*temp_len + 1
                            len_curr <= (temp_len << 1) | 1;
                            sub_len <= temp_len; // Store for later use
                            step <= 2;
                        end
                    end else if (step == 2) begin
                        // Check Overlap and Validity
                        // If node is completely outside query range, backtrack
                        // We are dealing with 14-bit inputs, but intermediate lengths can be large.
                        // However, we only care about indices up to max 14-bit range (approx).
                        // The problem implies we restrict max length to 16383.
                        // But if n is large, L(n) is huge. 
                        // We need to handle cases where node_r overflows 14-bit range.
                        // If node_l > 16383, we can drop it.
                        // If node_l > r_reg, drop it.
                        // If node_r < l_reg, drop it.
                        
                        // Optimization: if node_l > 14'h3FFF (16383), drop.
                        if (curr_start > 14'h3FFF) begin
                            state <= POP_PROC; // Backtrack
                        end else if (node_r < {18'b0, l_reg}) begin
                            state <= POP_PROC; // Left of range
                        end else if (node_l > {18'b0, r_reg}) begin
                            state <= POP_PROC; // Right of range
                        end else begin
                            // Overlaps or inside range
                            if (curr_n <= 1) begin
                                // Base case: if curr_n == 1, it's a 1. If 0, it's 0.
                                // We need to add curr_n to result if it's within range.
                                // Since we checked overlap above, if we are here, it overlaps.
                                if (curr_n == 1) result <= result + 1;
                                state <= POP_PROC;
                            end else begin
                                // Need to split. Calculate L(n/2) again? 
                                // We already have sub_len from step 1 (if n>1).
                                // Wait, if n<=1, we skip step 1. 
                                // So for n>1, sub_len is valid.
                                state <= SPLIT;
                                step <= 0;
                            end
                        end
                    end
                end

                SPLIT: begin
                    // Handle Right, Left, Middle pushes
                    // We need to decide what to push based on overlap with query [l_reg, r_reg]
                    // We have: node_l, node_r, left_l, left_r, mid, right_l, right_r.
                    // All are 32-bit.
                    
                    // Logic:
                    // Step 0: Check Right.
                    // Step 1: Check Left.
                    // Step 2: Check Middle.
                    // Step 3: Return to POP_PROC (to process pushes or backtrack).
                    
                    // We need to push (n/2, start).
                    // n/2 = curr_n >> 1.
                    // Start = ...
                    
                    if (step == 0) begin
                        // Check Right: [right_l, right_r] overlap [l_reg, r_reg]?
                        // Also check bounds: right_l <= 16383?
                        if (right_l <= {18'b0, r_reg} && right_r >= {18'b0, l_reg} && right_l <= 14'h3FFF) begin
                            // Prepare push
                            curr_n <= curr_n >> 1;
                            curr_start <= right_l[13:0]; // Safe cast because we checked bounds
                            state <= PUSH_CALL;
                            step <= 1; // After push returns to POP, we need to handle Left. 
                            // But PUSH_CALL goes to POP_PROC, which goes to CALC_LEN_N.
                            // We need to come back to SPLIT step 1.
                            // We can't easily chain states.
                            // Alternative: We push Right, then we pop and process it (DFS).
                            // But we want to push Left too.
                            // We can push Right, then in the SAME state increment step and push Left?
                            // No, PUSH_CALL is a state.
                            // 
                            // Solution: We push children and then return to POP_PROC.
                            // But we need to push BOTH children if valid.
                            // We can push Right, then set a flag `pending_left`?
                            // 
                            // Better: We push Right. Then we MUST return to SPLIT to push Left.
                            // How? We can set a `return_state` register.
                            // Or we can handle pushes in a loop.
                            // 
                            // Let's use a flag `pending_push`.
                            // If we need to push Right, we set curr_n/start, set `next_step`=1, state=PUSH_CALL.
                            // PUSH_CALL -> POP_PROC -> ... wait.
                            // 
                            // Let's try: 
                            // In SPLIT step 0:
                            // If Right valid: curr_n = n/2, curr_start = right_l. State = PUSH_CALL. 
                            // BUT, we need to come back to SPLIT step 1.
                            // 
                            // We can use a `return_state` register.
                            // return_state <= SPLIT;
                            // sub_step <= 1;
                            // State <= PUSH_CALL;
                            // 
                            // Or, we can push children in `PUSH_CALL` state multiple times before going to POP.
                            // 
                            // Let's try to make `PUSH_CALL` smarter.
                            // `PUSH_CALL` checks if there are more items to push.
                            // 
                            // Actually, we can push Right and Left into the stack and then go to POP_PROC.
                            // But we need to ensure DFS order or just processing order.
                            // Order doesn't matter for sum.
                            // So we can push Right, then Left. 
                            // But we need to ensure they are both pushed before we pop.
                            // 
                            // Let's introduce a state `PUSH_CHILDREN`.
                            // But we are limited on states.
                            
                            // Let's handle it in SPLIT:
                            // If step == 0:
                            //   If Right valid: push it. Then step = 1. 
                            //   But we can't push in combinational logic.
                            //   We need to transition to `PUSH_CALL`.
                            //   And we need to remember we are in the middle of splitting.
                            //   
                            //   So: 
                            //   `PUSH_CALL` sets a flag `splitting_mode` or `continue_split`.
                            //   
                            //   Let's use a `return_step` register.
                            //   In SPLIT step 0:
                            //      If Right valid: 
                            //         curr_n = n/2, curr_start = right_l;
                            //         next_step <= 1; // We want to resume SPLIT at step 1
                            //         state <= PUSH_CALL;
                            //      Else:
                            //         step <= 1; // Jump to step 1 in current cycle
                            //   
                            //   In PUSH_CALL:
                            //      Push.
                            //      If next_step != 0, state <= SPLIT, step <= next_step.
                            //      Else state <= POP_PROC (default).
                            //   
                            //   We need `next_step` register.
                            
                            // Let's implement this.
                            
                            if (right_l <= {18'b0, r_reg} && right_r >= {18'b0, l_reg} && right_l <= 14'h3FFF) begin
                                curr_n <= curr_n >> 1;
                                curr_start <= right_l[13:0];
                                step <= 1; // Store where to return
                                state <= PUSH_CALL;
                            end else begin
                                step <= 1; // Skip Right, go to Left
                            end
                        end else begin
                            step <= 1; // Skip Right
                        end
                    end else if (step == 1) begin
                        // Check Left
                        if (left_l <= {18'b0, r_reg} && left_r >= {18'b0, l_reg} && left_l <= 14'h3FFF) begin
                            curr_n <= curr_n >> 1;
                            curr_start <= left_l[13:0];
                            step <= 2;
                            state <= PUSH_CALL;
                        end else begin
                            step <= 2;
                        end
                    end else if (step == 2) begin
                        // Check Middle
                        if (mid >= {18'b0, l_reg} && mid <= {18'b0, r_reg} && mid <= 14'h3FFF) begin
                            // Add 1 to result (since curr_n > 1 implies middle is 1? 
                            // Wait, middle element is `curr_n % 2`.
                            // If curr_n is odd, middle is 1. If even, 0.
                            if (curr_n[0]) result <= result + 1;
                        end
                        step <= 3;
                    end else if (step == 3) begin
                        // Done splitting
                        state <= POP_PROC;
                        step <= 0;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE; // Wait for reset or start low?
                    // Usually done stays high until start is pulsed again or reset.
                    // Let's stay here until reset.
                end
            endcase
        end
    end

    // Modifications to PUSH_CALL state logic:
    // We need to handle the return to SPLIT.
    // I used `step` to store the return state in SPLIT.
    // In PUSH_CALL, after push, if `step` was set (i.e., we are splitting), go back to SPLIT.
    // 
    // Wait, `step` is used inside SPLIT. 
    // In SPLIT, I set `step` to the next step (1, 2, 3) before going to PUSH_CALL.
    // But `step` is a shared register.
    // In PUSH_CALL, I need to check if we are coming from SPLIT.
    // I can use `state` transition. 
    // 
    // Actually, the logic `state <= PUSH_CALL` from SPLIT sets the next state.
    // In PUSH_CALL, I need to know where to go next.
    // I can add a `next_state` register, or use `step` to encode it.
    // 
    // Let's use `step` to encode the return state index.
    // In SPLIT step 0 (Right): if valid, set `step = 1`, `state = PUSH_CALL`. 
    // In PUSH_CALL: 
    //   Push.
    //   If `step` != 0 (default 0), then `state <= SPLIT`.
    //   But `step` is already 1 (meaning SPLIT step 1).
    //   I need a way to set `state` to SPLIT AND set the internal step of SPLIT.
    //   
    //   I can introduce a `sub_step` register or use `step` for both.
    //   Let's use `step` to store the target sub-step for SPLIT.
    //   
    //   In SPLIT step 0:
    //     If Right valid: 
    //        curr_n/curr_start update.
    //        step <= 1; // Target step
    //        state <= PUSH_CALL;
    //     Else step <= 1; state <= SPLIT; (Stay in SPLIT, advance step)
    //     
    //   In PUSH_CALL:
    //     Push.
    //     If step == 0: state <= POP_PROC; (Normal push)
    //     Else: state <= SPLIT; // `step` already holds the value.
    //     But wait, if I go to SPLIT, `step` is 1. SPLIT logic will execute step 1.
    //     This works.
    //     
    //     BUT, `step` is also used in `CALC_LEN_N`. 
    //     When we return from SPLIT logic to SPLIT logic, `step` is preserved.
    //     
    //     Wait, `step` is a single register. 
    //     In SPLIT step 1 (Left), we might go to PUSH_CALL.
    //     In PUSH_CALL, we set `step` to 2.
    //     So we need to update `step` correctly.
    //     
    //     Let's refine SPLIT:
    //     Step 0: Right.
    //       If valid: 
    //         set child params, 
    //         next_step = 1, 
    //         state = PUSH_CALL.
    //       Else: 
    //         step = 1, state = SPLIT.
    //     
    //     Step 1: Left.
    //       If valid: 
    //         set child params,
    //         next_step = 2,
    //         state = PUSH_CALL.
    //       Else:
    //         step = 2, state = SPLIT.
    //         
    //     Step 2: Middle. Update result. Step = 3.
    //     Step 3: Done. State = POP.
    
    //     To support this, `PUSH_CALL` needs to preserve the 'next_step' for SPLIT.
    //     Let's use `step` to store 'next_step'.
    //     In `PUSH_CALL`: 
    //       Push.
    //       If `step` != 0: 
    //         state <= SPLIT. 
    //         // `step` is already set to the target sub-step.
    //       Else: state <= POP_PROC.
    //       
    //     Note: `step` is 0 in `IDLE`. So normal pushes (from IDLE) go to POP_PROC.
    //     In `SPLIT`, before jumping to `PUSH_CALL`, we update `step`.
    
    //     Wait, `PUSH_CALL` is also used from IDLE (initial push).
    //     In IDLE, we set `curr_n` and `curr_start`. Then `state <= PUSH_CALL`.
    //     What is `step` at that time? 0.
    //     So `PUSH_CALL` will push, and if `step`==0, go to `POP_PROC`. Correct.
    
    //     Also, in `SPLIT`, we need to be careful not to overwrite `step` if we stay in `SPLIT` (e.g., Right invalid -> go to step 1).
    //     That is fine.
    
    //     One issue: `step` is 2 bits. `CALC_LEN_N` uses it. `SPLIT` uses it.
    //     Transitions between `CALC_LEN_N` and `SPLIT` reset `step` to 0 (in `CALC_LEN_N` step 2).
    //     So `step` usage is isolated by state transitions.
    
    //     Let's double check `PUSH_CALL` logic.
    //     If `step` != 0, we go to `SPLIT`. 
    //     But `step` is not cleared. So `SPLIT` executes with that `step` value. Correct.
    
    //     Wait, `PUSH_CALL` is a state. 
    //     `SPLIT` state executes logic based on `step`.
    //     Example:
    //     SPLIT (step 0) -> Valid Right -> set params, step=1, state=PUSH_CALL.
    //     PUSH_CALL -> Push -> since step=1 != 0 -> state=SPLIT.
    //     SPLIT (step 1) executes. Correct.
    
    //     So the logic holds.
    
    //     Need to handle the `step` update in `SPLIT` if we don't push.
    //     Example: SPLIT step 0. Right invalid. 
    //     We want to go to step 1. 
    //     `step <= 1; state <= SPLIT;` (Self loop).
    
    //     One detail: `SPLIT` logic handles `step` values 0, 1, 2, 3.
    //     
    //     Let's implement the `SPLIT` state logic exactly as planned.

endmodule

// We need to include the `stack_start` declaration.
// I will edit the module definition to include it.

module count_ones_range(
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    input [13:0] l_in,
    input [13:0] r_in,
    output reg [31:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CALC_LEN_N = 3'b001;
    localparam PUSH_CALL = 3'b010;
    localparam POP_PROC = 3'b011;
    localparam SPLIT = 3'b101;
    localparam DONE_STATE = 3'b110;

    reg [2:0] state;
    reg [2:0] step; // Increased width to 3 to handle 0-3 states safely
    
    // Stack Parameters
    localparam STACK_DEPTH = 16;
    localparam STACK_ADDR_W = 4;
    
    // Stack memory
    reg [15:0] stack_n [0:STACK_DEPTH-1];
    reg [13:0] stack_start [0:STACK_DEPTH-1];
    reg [STACK_ADDR_W:0] sp;
    
    // Input registers
    reg [15:0] n_reg;
    reg [13:0] l_reg;
    reg [13:0] r_reg;
    
    // Working registers
    reg [15:0] curr_n;
    reg [13:0] curr_start;
    
    // Computation registers
    reg [31:0] len_curr;
    reg [31:0] sub_len;
    reg [15:0] temp_n;
    reg [31:0] temp_len;
    
    // Wires for ranges
    wire [31:0] node_l = {18'b0, curr_start};
    wire [31:0] node_r = node_l + len_curr - 1;
    wire [31:0] left_l = node_l;
    wire [31:0] left_r = node_l + sub_len - 1;
    wire [31:0] mid = node_l + sub_len;
    wire [31:0] right_l = mid + 1;
    wire [31:0] right_r = node_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            sp <= 0;
            step <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n_in;
                        l_reg <= l_in;
                        r_reg <= r_in;
                        result <= 32'd0;
                        sp <= 0;
                        step <= 0;
                        // Setup initial node
                        curr_n <= n_in;
                        curr_start <= 14'd1;
                        state <= PUSH_CALL;
                    end
                end

                PUSH_CALL: begin
                    if (sp < STACK_DEPTH) begin
                        stack_n[sp] <= curr_n;
                        stack_start[sp] <= curr_start;
                        sp <= sp + 1;
                    end
                    // Determine next state
                    if (step != 0) begin
                        // Returning from SPLIT logic
                        state <= SPLIT;
                    end else begin
                        // Normal push (from IDLE)
                        state <= POP_PROC;
                    end
                end

                POP_PROC: begin
                    if (sp > 0) begin
                        sp <= sp - 1;
                        curr_n <= stack_n[sp - 1];
                        curr_start <= stack_start[sp - 1];
                        state <= CALC_LEN_N;
                        step <= 0;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                CALC_LEN_N: begin
                    if (step == 0) begin
                        if (curr_n <= 1) begin
                            len_curr <= 32'd1;
                            step <= 2; // Go to overlap check
                        end else begin
                            temp_n <= curr_n >> 1;
                            temp_len <= 32'd1;
                            step <= 1;
                        end
                    end else if (step == 1) begin
                        if (temp_n > 1) begin
                            temp_n <= temp_n >> 1;
                            temp_len <= (temp_len << 1) | 1;
                        end else begin
                            len_curr <= (temp_len << 1) | 1;
                            sub_len <= temp_len;
                            step <= 2;
                        end
                    end else if (step == 2) begin
                        // Overlap check and decision
                        // Check if node is outside query or restricted range
                        if (curr_start > 14'h3FFF) begin
                            state <= POP_PROC;
                        end else if (node_r < {18'b0, l_reg}) begin
                            state <= POP_PROC;
                        end else if (node_l > {18'b0, r_reg}) begin
                            state <= POP_PROC;
                        end else begin
                            if (curr_n <= 1) begin
                                if (curr_n == 1) result <= result + 1;
                                state <= POP_PROC;
                            end else begin
                                // Need to split
                                state <= SPLIT;
                                step <= 0;
                            end
                        end
                    end
                end

                SPLIT: begin
                    case (step)
                        0: begin // Process Right
                            if (right_l <= {18'b0, r_reg} && right_r >= {18'b0, l_reg} && right_l <= 14'h3FFF) begin
                                curr_n <= curr_n >> 1;
                                curr_start <= right_l[13:0];
                                step <= 1; // Next step for SPLIT
                                state <= PUSH_CALL;
                            end else begin
                                step <= 1;
                            end
                        end
                        1: begin // Process Left
                            if (left_l <= {18'b0, r_reg} && left_r >= {18'b0, l_reg} && left_l <= 14'h3FFF) begin
                                curr_n <= curr_n >> 1;
                                curr_start <= left_l[13:0];
                                step <= 2;
                                state <= PUSH_CALL;
                            end else begin
                                step <= 2;
                            end
                        end
                        2: begin // Process Middle
                            if (mid >= {18'b0, l_reg} && mid <= {18'b0, r_reg} && mid <= 14'h3FFF) begin
                                if (curr_n[0]) result <= result + 1;
                            end
                            step <= 3;
                        end
                        3: begin // Done
                            state <= POP_PROC;
                            step <= 0;
                        end
                        default: state <= POP_PROC;
                    endcase
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Wait for reset or start low to return to IDLE
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule
