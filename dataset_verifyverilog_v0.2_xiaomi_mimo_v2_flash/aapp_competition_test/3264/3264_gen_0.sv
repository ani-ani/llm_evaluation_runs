module mirko_wins (
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    output reg [29:0] result,
    output reg done
);

    // Constants
    parameter MOD = 30'd1000000000;

    // State definitions
    localparam S_IDLE = 3'b000;
    localparam S_PRECOMP = 3'b001;
    localparam S_ITERATE = 3'b010;
    localparam S_COUNT = 3'b011;
    localparam S_UPDATE = 3'b100;
    localparam S_DONE = 3'b101;

    // Registers
    reg [2:0] state;
    reg [4:0] a, b;          // Iterators for pair precomputation
    reg [19:0] mask;         // Current partition mask (N-1 bits)
    reg [19:0] valid_mask;   // Precomputed validity of pairs (flattened)
    reg [19:0] pair_mask;    // Current pair being checked (flattened)
    reg [4:0] pair_idx;      // Index for pairs iteration
    reg [29:0] term;         // Current term (2^C)
    reg [9:0] C;             // Compatible pair count
    reg is_odd;              // Flag for |S| parity
    reg [4:0] popcnt;        // Population count of mask
    reg [29:0] temp_pow;     // Temp for power computation
    reg [19:0] valid_check;  // Combinational check result
    reg compatible;          // Current pair compatibility flag
    reg [4:0] N_reg;         // Registered N

    // Helper: Check if pair (a,b) is valid for partition x
    // Logic: (b < x) OR (a >= x)
    function automatic bit is_valid_pair(input [4:0] a, b, x);
        bit cond1 = (b < x);
        bit cond2 = (a >= x);
        return cond1 | cond2;
    endfunction

    // Helper: Count set bits (up to 20)
    function automatic [4:0] count_ones(input [19:0] val);
        integer i;
        reg [4:0] cnt;
        cnt = 0;
        for (i = 0; i < 20; i = i + 1) begin
            if (val[i]) cnt = cnt + 1;
        end
        return cnt;
    endfunction

    // Combinational Logic
    always @(*) begin
        // Determine compatibility of current pair 'pair_idx' with current mask 'mask'
        // pair_idx maps to (a, b). We need to know a and b.
        // Since N <= 20, we can either store a,b arrays or recompute.
        // Recomputing logic to save block RAM:
        // Total pairs P = N*(N-1)/2. We iterate pair_idx from 0 to P-1.
        // We need a and b for 'valid_mask' generation and 'compatible' check.
        // To avoid defining arrays in combinational logic, we will reconstruct a,b.
        // However, 'valid_mask' is stored. So for 'compatible', we just need logic.
        // Let's do the logic for 'compatible'.
        
        // Reconstruct a, b from pair_idx (only needed for compatible calculation if not stored)
        // But wait, the prompt says "Iterate over all 2^(N-1) subsets" and "Count compatible pairs".
        // It doesn't strictly require storing pair validity in an array if we recompute.
        // However, computing 190 pairs * 524k iterations is heavy (100M cycles total? No, 524k * 190 = 100M, acceptable?)
        // 100M cycles @ 100MHz is 1 second. Maybe okay, but let's try to be efficient.
        // Actually, the instructions say "Precompute validity of all pairs".
        // So we store 'valid_mask'.
        // We still need a, b to check partition logic if we don't store 'a,b' info in another LUT.
        // Actually, the logic for compatibility is: 
        // Compatible with S if for ALL x in S: (b < x) OR (a >= x).
        // This is equivalent to: (Max x in S) <= a OR (Min x in S) > b ? No.
        // Let's stick to the definition. For each x in S, check condition.
        // Since we iterate x (partitions) in S, we need to know a,b for the current pair.
        // To avoid storing 20x20 array of a,b, we can reconstruct a,b from pair_idx.
        
        // Reconstruct a, b:
        // We need a function to get a, b from pair_idx. 
        // Since we need this in synthesisable combinational logic, let's inline it.
        // We need temporary variables for a and b in the block below.
        // Actually, we can pass pair_idx and N to a task/function if it were procedural.
        // Let's do it inline in the always block.
        
        // We need a and b for the current pair_idx to compute `compatible`.
        // This is a helper logic block.
    end

    // Since we need a/b for `compatible`, let's define a separate combinational block or wire.
    wire [4:0] curr_a, curr_b;
    get_pair u_get_pair (.idx(pair_idx), .N(N_reg), .a(curr_a), .b(curr_b));

    // Determine compatible for current pair_idx and current mask
    // A pair is compatible if valid AND for all x in mask: (b<x) || (a>=x)
    // We can check this sequentially or have a lookup table for (mask, pair) -> compatible.
    // Since mask has 2^19 entries, lookup is impossible.
    // Sequential check over partitions x=1..19 is fast (20 cycles). 
    // But we want to keep 'ITERATE' cycle count low. 
    // The prompt says "Use blocking operations or wait states".
    // So we can iterate x from 1 to N-1.
    // We need to check `valid_mask[pair_idx]` first.
    
    // Logic for 'compatible' signal:
    // We will do the partition check sequentially in state COUNT.
    // Here, we just need to know if the pair is valid.
    wire pair_is_valid = valid_mask[pair_idx];
    
    // For the partition check in state COUNT, we need to check (b < x) || (a >= x).
    // We will implement that iteratively.
    // To minimize code size, we will do sequential iteration over partitions x.
    // So `compatible` will be determined inside the state machine loop.

    // State Machine Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        N_reg <= N;
                        result <= 0;
                        done <= 0;
                        state <= S_PRECOMP;
                        a <= 1;
                        b <= 2;
                        valid_mask <= 0; // Reset valid mask
                        mask <= 0;       // Initialize partition mask
                    end
                end

                S_PRECOMP: begin
                    // Precompute valid pairs (gcd(a,b)==1)
                    // Since we don't have a GCD unit, we implement a small sequential check.
                    // Or we can hardcode GCD logic for small numbers 1..20.
                    // Let's use a temporary GCD calculation.
                    // Since a,b <= 20, we can check divisibility.
                    // To keep it simple and fast, we'll just check manually or use a loop.
                    // Let's use a loop inside the state to keep it single state if possible, 
                    // but since we need to be sequential, we iterate pairs.
                    
                    // GCD Calculation (binary or subtraction for small numbers)
                    // Let's use a simple subtraction based GCD in a sub-state or helper logic.
                    // Actually, to save states, let's just do 1 operation per clock here.
                    
                    // Check gcd(a,b) == 1
                    // We can use Euclidean algorithm variables.
                    // Let's add registers for GCD calculation.
                    // To keep the state machine simple, we'll assume we can compute GCD in 1 cycle 
                    // using combinational logic and store it.
                    
                    // We need to mark valid_mask[idx] = 1 if gcd(a,b)==1.
                    // We will implement a small combinational GCD check logic.
                    // Since synthesis tools don't like loops with variable iteration counts easily inside combinational logic without unrolling,
                    // we will unroll or use a separate state for GCD.
                    // However, since N is small (20), we can just implement a combinational gcd function.
                    
                    if (gcd_ones(a, b)) begin
                        // Calculate index
                        // Index = (a-1)*(N-1) - (a-1)*(a)/2 + (b-a-1) (roughly)
                        // Exact mapping: Sum_{i=1}^{a-1} (N-i) + (b-a-1)
                        // Let's compute index sequentially? No, compute directly.
                        // Pairs (a,b) with 1<=a<b<=N.
                        // Flattened index = (a-1)*N - (a-1)*(a)/2 + (b-a-1) - (N-a)??
                        // Formula: Index = (a-1)*N - (a*(a+1))/2 + b - 1
                        // Let's verify. a=1, b=2: 0*N - 1 + 2 - 1 = 0. Correct.
                        // a=1, b=3: 0 - 1 + 3 - 1 = 1. Correct.
                        // a=2, b=3: 1*N - 3 + 3 - 1 = N - 1. Correct (1st pair of group 2).
                        // Wait, we need to be careful with integer division.
                        // Let's use a pre-calculated index or compute it carefully.
                        // Since N is variable, we must compute.
                        // Index = (a-1)*N - (a*(a+1))/2 + b - 1.
                        // Let's compute this combinational.
                        valid_mask[idx_calc] <= 1;
                    end

                    // Increment a, b
                    b <= b + 1;
                    if (b == N_reg) begin
                        b <= a + 2;
                        a <= a + 1;
                        if (a == N_reg) begin
                            state <= S_ITERATE;
                            // Initialize iteration
                            // We need to iterate masks from 0 to 2^(N-1)-1.
                            // Start mask = 0.
                            mask <= 0;
                            // But we must skip mask=0? 
                            // The formula 2^C sum includes S=empty? 
                            // Inclusion-Exclusion: Sum (-1)^|S| 2^C(S). 
                            // S empty: |S|=0 (even), C = all valid pairs = TotalPairs. 
                            // So we include mask=0.
                        end
                    end
                end

                S_ITERATE: begin
                    // Check if we are done iterating masks
                    // Mask goes from 0 to (1 << (N-1)) - 1
                    // We can stop when mask reaches 2^(N-1). 
                    // Or check if we have finished.
                    // Let's define limit = 1 << (N-1).
                    if (mask == (1 << (N_reg - 1))) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_COUNT;
                        pair_idx <= 0;
                        C <= 0;
                        
                        // Compute Parity of mask (|S| % 2)
                        // We can use a population count function.
                        // Since N <= 20, loop is fine.
                        // Let's do popcount.
                        // We'll do popcount in 1 cycle using combinational logic.
                        // But we need it for S_UPDATE. Let's compute it now.
                        popcnt <= count_ones(mask);
                    end
                end

                S_COUNT: begin
                    // Check current pair_idx against mask
                    // We need to check if pair_idx is valid AND compatible with mask.
                    // If valid_mask[pair_idx] is 0, skip.
                    if (pair_is_valid) begin
                        // Now check partitions in mask.
                        // Compatible if for all x in mask: (b < x) || (a >= x)
                        // We iterate x from 0 to N-2 (partition index). Partition value = x+1.
                        // We can do this loop here or separate state.
                        // Let's do a nested loop or sequential scan over x.
                        // To save states, we can add a sub-state or just iterate x using a temp counter.
                        // But we have `pair_idx`. We need to check partitions.
                        // Let's use a temporary variable `x` to iterate partitions.
                        // Since we need to loop over x, we need a new state or a nested loop in logic.
                        
                        // Let's use a temporary register `part_x` initialized in S_COUNT entry.
                        // Wait, we need to manage `part_x`. 
                        // We'll do this: inside S_COUNT, we check the partition compatibility.
                        // We need to know curr_a, curr_b.
                        
                        // Let's assume we add a variable `check_passed`.
                        // To do this efficiently: 
                        // The condition (b < x) || (a >= x) is equivalent to NOT (a < x <= b).
                        // Let's define a variable `check_compatible`.
                        // We will iterate partitions x. 
                        // We need a loop variable. Let's add a register `x`.
                        // Start x=0 (partition 1). 
                        // If (mask[x] == 1) check condition. If fail, break (mark not compatible).
                        // If pass all, count++.
                        
                        // Since we can't easily do nested loops in single state without extra registers,
                        // we will increment `pair_idx` here only after checking all partitions for current pair.
                        // So we need to track partition checking.
                        // Let's add a flag or state to handle partition check.
                        // Let's use state S_COUNT_CHECK.
                        
                        // Actually, simpler approach:
                        // We can flatten the logic.
                        // The prompt allows blocking operations. 
                        // We can iterate x from 0 to N-2 in this state if we have an extra counter.
                        // Let's add a register `part_check_x`.
                        // If part_check_x == 0, we initialize a temp variable `compatible_flag = 1`.
                        // Then loop.
                        
                        // For synthesis, let's do a simple sequential check.
                        // We need to know a and b. We have curr_a, curr_b via wire.
                        // We need to check `mask[part_check_x]`.
                        
                        // Let's assume we add a temporary register `part_x` inside the state machine.
                        // This requires managing state transitions carefully.
                        // Let's use state S_COUNT to handle the loop over partitions for the current pair.
                        // We will introduce `part_idx` for this loop.
                    end else begin
                        // Not valid, skip
                        if (pair_idx == (N_reg * (N_reg - 1) / 2) - 1) begin
                            state <= S_UPDATE;
                        end else begin
                            pair_idx <= pair_idx + 1;
                        end
                    end
                end

                S_UPDATE: begin
                    // Apply inclusion-exclusion
                    // term = 2^C mod MOD
                    // We need to compute 2^C. C <= N*(N-1)/2 = 190.
                    // We can use a loop or precomputed table.
                    // Let's use a small loop here to compute power.
                    // We need to initialize term = 1, temp_pow = 2.
                    // Loop C times? No, exponentiation by squaring is better, but C is small.
                    // Let's use a standard power loop.
                    // Since C is 10 bits, we can't unroll fully. 
                    // We'll compute power in a sub-state or just use a combinational block if C is small.
                    // C is up to 190. 190 multiplications of 30-bit numbers is fine sequentially.
                    // Let's add a state S_POWER.
                    // But wait, we also need to update result.
                    // Let's compute power in S_UPDATE and then go to S_UPDATE_ADD.
                    // Or just compute power sequentially.
                    
                    // Optimization: 2^C is just 1 << C. But we need modulo 1000000000.
                    // We can compute (1 << C) % 1000000000.
                    // We can use modular exponentiation. Base 2, Exponent C.
                    // We can do it in S_UPDATE using a loop.
                    
                    // Let's do it: term = 1, base = 2.
                    // While C > 0: if (C[0]) term = (term * base) % MOD; base = (base * base) % MOD; C = C >> 1.
                    // We need a few temp registers for this.
                    // Let's dedicate registers for modular exponentiation.
                    // reg [29:0] exp_res, exp_base; reg [9:0] exp_exp;
                    
                    // Initialize exponentiation
                    exp_res <= 1;
                    exp_base <= 2;
                    exp_exp <= C;
                    // Transition to power computation state
                    // We need a state to handle the loop.
                    state <= S_POWER_LOOP;
                end
                
                S_POWER_LOOP: begin
                    if (exp_exp == 0) begin
                        // Power done. Update result.
                        // term is in exp_res.
                        if (popcnt[0] == 0) begin // Even
                            result <= (result + exp_res) % MOD;
                        end else begin // Odd
                            // result = (result - exp_res + MOD) % MOD;
                            // Handle underflow
                            if (result >= exp_res) result <= result - exp_res;
                            else result <= result + MOD - exp_res;
                        end
                        // Next mask
                        state <= S_ITERATE_NEXT;
                    end else begin
                        if (exp_exp[0]) begin
                            exp_res <= (exp_res * exp_base) % MOD;
                        end
                        exp_base <= (exp_base * exp_base) % MOD;
                        exp_exp <= exp_exp >> 1;
                    end
                end

                S_ITERATE_NEXT: begin
                    // Increment mask (simple increment)
                    mask <= mask + 1;
                    state <= S_ITERATE;
                end

                S_DONE: begin
                    done <= 1;
                    // Wait for start to go low? Or just stay done.
                    if (!start) state <= S_IDLE;
                end
            endcase
        end
    end

    // We need to handle the "pair_idx" iteration in S_COUNT properly.
    // The previous code skeleton for S_COUNT was incomplete.
    // Let's refine S_COUNT to be a state that iterates over partitions.
    // We will add a new state S_CHECK_PARTS to handle the compatibility check loop.
    
    // Revised States for S_COUNT logic:
    // In S_ITERATE, we set pair_idx=0.
    // Transition to S_CHECK_PAIR.
    // S_CHECK_PAIR: Checks if pair is valid. If not, jump to S_NEXT_PAIR.
    // If valid, go to S_CHECK_PART_LOOP.
    // S_CHECK_PART_LOOP: Checks partitions. If fail, go to S_NEXT_PAIR.
    // If success, go to S_INCREMENT_C.
    // S_INCREMENT_C: C++. Then go to S_NEXT_PAIR.
    // S_NEXT_PAIR: pair_idx++. If all pairs done, go to S_UPDATE, else S_CHECK_PAIR.
    
    // Let's incorporate this into the main FSM.
    // We will use the existing S_COUNT as S_CHECK_PAIR.
    // We need extra registers for the partition loop.
    reg [4:0] part_idx; // 0 to N-2
    reg part_ok;        // Flag for current pair partition check

    // We need to override the previous S_COUNT logic. 
    // Let's do it by adding states. 
    // We will split S_COUNT into S_CHECK_PAIR, S_CHECK_PART, S_NEXT_PAIR.
    // But to keep code size manageable, we can use S_COUNT for S_CHECK_PAIR 
    // and S_COUNT_PART for the partition loop, and S_COUNT_DONE for increment.

    // Actually, let's re-use the existing state definitions if possible or just add logic.
    // The initial plan had S_COUNT. Let's change S_COUNT to S_CHECK_PAIR.
    // We will need to update the always block.
    // Since we cannot easily delete and replace, let's assume we structure it correctly from scratch in the final code.

    // Final State Definitions refinement:
    // S_IDLE, S_PRECOMP, S_ITERATE, S_CHECK_PAIR, S_CHECK_PART, S_COUNT_UPD, S_UPDATE, S_POWER_LOOP, S_ITERATE_NEXT, S_DONE.
    // We only have 3 bits, so 8 states max. We need more.
    // Let's re-use states carefully or use sub-states inside logic.
    // Sub-states inside logic (using counters) is better for state count.
    
    // Let's go with the plan: S_COUNT will be a state that handles the pair loop using a counter `part_idx`.
    // If `part_idx` is 0, we check valid. If valid, set `part_idx` to 1 (or first set bit).
    // This requires careful handling.
    // Let's stick to a slightly linear flow with a few states.
    
    // State: S_CHECK_PAIR (formerly S_COUNT)
    // State: S_CHECK_PART (loop over x)
    // State: S_NEXT_PAIR
    // We have space in 3 bits (8 states). We currently use: IDLE, PRECOMP, ITERATE, COUNT, UPDATE, DONE.
    // That's 6. We can fit 2 more.
    // Let's merge UPDATE and POWER_LOOP. 
    // UPDATE initializes power. POWER_LOOP does the work.
    // ITERATE_NEXT is just an increment.
    // We need states for pair checking.
    // Let's do: S_CHECK_PAIR, S_CHECK_PART, S_NEXT_PAIR.
    // We can use S_ITERATE for the outer loop.
    // We need to define new state codes.
    
    // New Codes:
    // 0: IDLE
    // 1: PRECOMP
    // 2: ITERATE
    // 3: CHECK_PAIR
    // 4: CHECK_PART
    // 5: NEXT_PAIR
    // 6: UPDATE (INIT_POWER)
    // 7: POWER_LOOP
    // 8: ITERATE_NEXT
    // 9: DONE
    // 3 bits allow 0-7. We need 9 states. 
    // We need 4 bits or optimize.
    // Optimization:
    // PRECOMP can be done in one state if we unroll loop? No, 190 pairs.
    // We need a PRECOMP state.
    // We can use S_IDLE as S_DONE wait. 
    // We can use S_ITERATE to handle both checking if done and setup.
    // Let's try to compact:
    // 0: IDLE
    // 1: PRECOMP
    // 2: ITERATE (setup pair_idx=0, check if done mask)
    // 3: CHECK_PAIR (check valid)
    // 4: CHECK_PART (check partitions for current pair)
    // 5: INC_C (if compatible)
    // 6: NEXT_PAIR
    // 7: UPDATE (init power)
    // Wait, we need POWER_LOOP and ITERATE_NEXT.
    // We can put POWER_LOOP inside UPDATE if we use a flag.
    // Or use a counter to track the step.
    
    // Let's use 4 bits for state to be safe and clear.
    // Or use a counter for the pair checking logic inside S_COUNT to save states.
    // The prompt says "sequential state machine". 
    // Let's implement the pair counting logic inside S_COUNT using a sub-loop.
    // We can use `part_idx` to track the step within S_COUNT.
    // This way we only need one state for the pair processing.
    
    // Revised Logic for S_COUNT (sub-steps):
    // Step 0: Check Valid. If invalid, go to Next Pair.
    // Step 1+: Check partitions.
    // We need a register `check_step`.
    // If check_step == 0: check valid. If valid, check_step = 1. Else Next Pair.
    // If check_step > 0: iterate partitions.
    // We need to know which partition to check. We can iterate x from 0 to N-2.
    // We can use `part_idx` to iterate x.
    // 
    // Plan:
    // State S_COUNT:
    //   if (check_step == 0) begin
    //      if (!valid) NextPair; else begin check_step <= 1; part_idx <= 0; end
    //   end else begin
    //      // Check partition part_idx
    //      // If mask[part_idx] is set:
    //      //   if !(b < x+1 || a >= x+1) -> fail -> NextPair
    //      // Increment part_idx. If part_idx == N-1, then Compatible -> IncC.
    //   end
    // This fits in one state.

    // We need to update the always block accordingly.

endmodule

module get_pair (
    input [4:0] idx,
    input [4:0] N,
    output reg [4:0] a,
    output reg [4:0] b
);
    // Computes a,b for a given pair index idx.
    // Loop to find a.
    integer i;
    reg [4:0] count;
    always @(*) begin
        count = 0;
        a = 1;
        b = 1;
        for (i = 1; i <= 20; i = i + 1) begin
            for (int j = i + 1; j <= 20; j = j + 1) begin
                if (count == idx) begin
                    a = i;
                    b = j;
                end
                count = count + 1;
            end
        end
    end
endmodule

module gcd_ones (
    input [4:0] a,
    input [4:0] b,
    output bit one
);
    // Helper to check if GCD is 1
    // Since a,b are small, we can use a small loop or logic.
    // But Verilog functions should be synthesizable.
    // We will use a simple combinational check.
    // Since we can't use 'function' with 'for' easily inside the module if not synthesizable.
    // Let's implement a simple combinational GCD check.
    // Actually, we can just do it inside the main module or use a separate logic.
    // Given the constraints, let's put the gcd logic directly in the main module's combinational block if needed,
    // or use a simple wire logic.
    // For GCD(a,b)==1, we check if they share any common factor 2,3,5,7,11,13,17,19.
    // Since max is 20, we can check divisibility.
    // 
    // Let's write it as a combinational logic inside the main module to avoid sub-modules for logic.
    // We will use `gcd_ones` as a flag in the PRECOMP state.
    // Wait, the `gcd_ones` module in the code above was a placeholder. 
    // Let's remove it and replace with actual logic in the synthesisable code.

endmodule

// Re-integrating everything into the single required module.

module mirko_wins (
    input clk,
    input rst_n,
    input start,
    input [4:0] N,
    output reg [29:0] result,
    output reg done
);

    parameter MOD = 30'd1000000000;
    // Max pairs for N=20 is 190. 2^190 is huge, but we do modulo arithmetic.
    // 2^C mod MOD. C up to 190.

    // State Machine States
    localparam S_IDLE = 0;
    localparam S_PRECOMP = 1;
    localparam S_ITERATE = 2;
    localparam S_COUNT = 3;
    localparam S_UPDATE = 4;
    localparam S_DONE = 5;
    // We need a state for Power Loop. Let's make S_UPDATE the setup, and S_POWER_LOOP the loop.
    // We only have 3 bits (8 states) if we stick to reg [2:0].
    // Let's use reg [3:0] for safety, but the prompt didn't specify limit. 4 bits is fine.
    reg [3:0] state;
    
    // Registers
    reg [4:0] N_reg;
    reg [4:0] a_gen, b_gen; // For pair generation
    reg [19:0] valid_mask;  // 190 bits
    reg [19:0] mask;        // Partition mask
    reg [4:0] pair_idx;     // Current pair index (0 to 189)
    reg [29:0] term;        // 2^C
    reg [9:0] C;            // Count of compatible pairs
    reg [4:0] popcnt;       // Popcount of mask
    
    // Helper registers for loops
    reg [4:0] part_idx;     // Index for partition check loop
    reg [29:0] exp_res, exp_base;
    reg [9:0] exp_exp;
    
    // Index calculation
    wire [8:0] idx_gen = (a_gen - 1) * N_reg - (a_gen * (a_gen + 1)) / 2 + b_gen - 1;
    
    // GCD Check Combinational Logic
    // Returns 1 if GCD(a,b) == 1
    wire gcd_is_1;
    assign gcd_is_1 = check_gcd(a_gen, b_gen);
    
    function automatic bit check_gcd(input [4:0] x, y);
        reg [4:0] t1, t2;
        begin
            t1 = x; t2 = y;
            // Since values are small, unrolled subtraction is fine or a loop.
            // But synthesizers prefer static loops.
            // We will use a small loop, synthesizers can unroll it for small constants.
            while (t2 != 0) begin
                if (t1 > t2) t1 = t1 - t2;
                else t2 = t2 - t1;
            end
            check_gcd = (t1 == 1);
        end
    endfunction

    // Compatibility Check (for current mask and pair_idx)
    // Logic: pair is compatible if valid AND (for all x in mask: b < x || a >= x)
    // We implement this iteratively in state S_COUNT.
    // We need to access a and b for current pair_idx.
    // We will compute a_curr, b_curr combinational for the current pair_idx.
    wire [4:0] a_curr, b_curr;
    get_pair_v2 u_gp (.idx(pair_idx), .N(N_reg), .a(a_curr), .b(b_curr));

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        N_reg <= N;
                        result <= 0;
                        done <= 0;
                        state <= S_PRECOMP;
                        a_gen <= 1;
                        b_gen <= 2;
                        valid_mask <= 0;
                    end
                end

                S_PRECOMP: begin
                    // Compute valid pairs
                    // Check GCD
                    if (gcd_is_1) begin
                        valid_mask[idx_gen] <= 1;
                    end
                    
                    // Increment pointers
                    if (b_gen < N_reg) begin
                        b_gen <= b_gen + 1;
                    end else begin
                        b_gen <= a_gen + 2;
                        if (a_gen < N_reg - 1) begin
                            a_gen <= a_gen + 1;
                        end else begin
                            // Done precomp
                            state <= S_ITERATE;
                            mask <= 0; // Start from mask 0
                        end
                    end
                end

                S_ITERATE: begin
                    // Check if finished all masks
                    // Limit = 1 << (N_reg - 1)
                    // If mask == limit, we are done.
                    if (mask == (1 << (N_reg - 1))) begin
                        state <= S_DONE;
                    end else begin
                        // Start processing this mask
                        // Initialize counters
                        pair_idx <= 0;
                        C <= 0;
                        // Compute popcount of mask for inclusion-exclusion sign
                        popcnt <= count_ones(mask);
                        // Move to counting state
                        state <= S_COUNT;
                    end
                end

                S_COUNT: begin
                    // We iterate pair_idx from 0 to TotalPairs-1
                    // For each pair, check compatibility.
                    // We implement a loop here to avoid exploding state count.
                    // Actually, S_COUNT can be a state that does one step of the pair check.
                    // Let's define a sub-state using part_idx or a separate register.
                    // But to keep it simple, let's use part_idx for the partition loop logic.
                    // Wait, part_idx was for partitions. 
                    // Let's add a register `count_step` to handle the flow inside S_COUNT.
                    // But we can reuse `part_idx`.
                    // Let's just iterate pair_idx here and check validity.
                    // Then we need to check partitions. That requires a loop.
                    // Let's make S_COUNT the entry point for a pair.
                    // We'll use a helper state S_CHECK_PARTS to loop partitions.
                    // But we are tight on states.
                    
                    // Solution: Use `part_idx` as a state machine inside S_COUNT.
                    // part_idx = 0: Check valid. If valid, set part_idx to 1. Else NextPair.
                    // part_idx >= 1: Check partition x = part_idx - 1.
                    //   If mask[x] is set, check condition. If fail, NextPair.
                    //   Increment part_idx. If part_idx > N-1, Compatible.
                    
                    // Let's implement this logic.
                    if (part_idx == 0) begin
                        // Check Validity
                        if (valid_mask[pair_idx]) begin
                            part_idx <= 1; // Start partition check
                        end else begin
                            // Invalid, go to next pair
                            if (pair_idx == (N_reg * (N_reg - 1) / 2 - 1)) begin
                                state <= S_UPDATE;
                                part_idx <= 0; // Reset for next mask
                            end else begin
                                pair_idx <= pair_idx + 1;
                            end
                        end
                    end else begin
                        // part_idx >= 1. Check partition x = part_idx - 1
                        // We need to know a_curr, b_curr.
                        // a_curr, b_curr are combinational based on pair_idx.
                        // x = part_idx - 1 + 1 (partition value) = part_idx.
                        // Wait, partitions are 1..N-1. mask[0] is partition 1.
                        // So x = part_idx. (since part_idx starts at 1)
                        
                        // Check if mask[part_idx-1] is set
                        if (mask[part_idx - 1]) begin
                            // Check condition: (b < x) || (a >= x)
                            // x = part_idx
                            if (!((b_curr < part_idx) || (a_curr >= part_idx))) begin
                                // Condition Failed. Incompatible.
                                // Go to next pair
                                if (pair_idx == (N_reg * (N_reg - 1) / 2 - 1)) begin
                                    state <= S_UPDATE;
                                    part_idx <= 0;
                                end else begin
                                    pair_idx <= pair_idx + 1;
                                    part_idx <= 0; // Reset for next pair
                                end
                            end else begin
                                // Condition Passed. Check next partition
                                if (part_idx == N_reg - 1) begin
                                    // All partitions checked. Compatible.
                                    C <= C + 1;
                                    // Next pair
                                    if (pair_idx == (N_reg * (N_reg - 1) / 2 - 1)) begin
                                        state <= S_UPDATE;
                                        part_idx <= 0;
                                    end else begin
                                        pair_idx <= pair_idx + 1;
                                        part_idx <= 0;
                                    end
                                end else begin
                                    part_idx <= part_idx + 1;
                                end
                            end
                        end else begin
                            // Partition not in mask, skip check
                            if (part_idx == N_reg - 1) begin
                                // All partitions checked. Compatible.
                                C <= C + 1;
                                // Next pair
                                if (pair_idx == (N_reg * (N_reg - 1) / 2 - 1)) begin
                                    state <= S_UPDATE;
                                    part_idx <= 0;
                                end else begin
                                    pair_idx <= pair_idx + 1;
                                    part_idx <= 0;
                                end
                            end else begin
                                part_idx <= part_idx + 1;
                            end
                        end
                    end
                end

                S_UPDATE: begin
                    // Calculate 2^C mod MOD using modular exponentiation
                    // exp_res = 1, exp_base = 2, exp_exp = C
                    // Use a loop state S_POWER
                    // Since we need a loop, let's transition to a new state.
                    // But we are running out of state codes. 
                    // Let's re-use S_COUNT for the power loop if we are careful.
                    // Or just add S_POWER state. We have 4 bits for state, so plenty.
                    exp_res <= 1;
                    exp_base <= 2;
                    exp_exp <= C;
                    state <= 5; // S_POWER
                end
                
                5: begin // S_POWER
                    if (exp_exp == 0) begin
                        // Power done. Update result.
                        if (popcnt[0] == 0) begin // Even
                            result <= (result + exp_res) % MOD;
                        end else begin // Odd
                            if (result >= exp_res) result <= result - exp_res;
                            else result <= result + MOD - exp_res;
                        end
                        // Next Mask
                        state <= 6; // S_NEXT_MASK
                    end else begin
                        if (exp_exp[0]) begin
                            exp_res <= (exp_res * exp_base) % MOD;
                        end
                        exp_base <= (exp_base * exp_base) % MOD;
                        exp_exp <= exp_exp >> 1;
                    end
                end

                6: begin // S_NEXT_MASK
                    mask <= mask + 1;
                    state <= S_ITERATE;
                end

                S_DONE: begin // State 7
                    done <= 1;
                    if (!start) state <= S_IDLE;
                end
            endcase
        end
    end

    // Helper functions
    function automatic [4:0] count_ones(input [19:0] val);
        integer i;
        reg [4:0] cnt;
        begin
            cnt = 0;
            for (i = 0; i < 20; i = i + 1) begin
                if (val[i]) cnt = cnt + 1;
            end
            count_ones = cnt;
        end
    endfunction

endmodule

module get_pair_v2 (
    input [4:0] idx,
    input [4:0] N,
    output reg [4:0] a,
    output reg [4:0] b
);
    // Helper to get a,b from flat index
    always @(*) begin
        a = 1;
        b = 1;
        // Since N is small, we can just iterate to find the pair.
        // This is combinational. Synthesis tools will unroll this loop.
        // We need to match the indexing order: a=1..N, b=a+1..N
        // Index mapping: 
        // Pairs with a=1: N-1 pairs. 
        // Pairs with a=2: N-2 pairs.
        // ...
        // We iterate to find which 'a' the index falls into.
        
        // To make it synthesisable and correct, we use a temporary variable for the loop.
        // We can't use 'for' in combinational always block easily if it implies latches, 
        // but here we assign a and b fully.
        
        // Let's use a constant loop limit. N is max 20.
        // We can unroll manually or rely on synthesis.
        // Let's do a simple search.
        
        int current_idx = 0;
        bit found = 0;
        
        for (int i = 1; i <= 20; i++) begin
            for (int j = i + 1; j <= 20; j++) begin
                if (!found) begin
                    if (current_idx == idx) begin
                        a = i;
                        b = j;
                        found = 1;
                    end
                    current_idx = current_idx + 1;
                end
            end
        end
    end
endmodule
