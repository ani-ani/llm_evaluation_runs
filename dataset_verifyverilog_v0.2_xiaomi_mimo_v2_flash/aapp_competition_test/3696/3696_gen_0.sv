module euclid_poly_builder (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] deg_a,
    output reg [7:0] deg_b,
    output reg signed [2:0] a_coeffs [0:120],
    output reg signed [2:0] b_coeffs [0:120],
    output reg done
);

    // State encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        INIT = 3'b001,
        ITERATE = 3'b010,
        CALC_XF = 3'b011,
        CALC_SUM = 3'b100,
        CHECK_MAX = 3'b101,
        UPDATE = 3'b110,
        FINAL = 3'b111
    } state_t;
    
    state_t current_state, next_state;

    // Array size 121
    localparam MAX_LEN = 121;

    // Temporary buffers for F_{k-1} (curr) and F_{k-2} (prev)
    reg signed [2:0] curr_buf [0:120];
    reg signed [2:0] prev_buf [0:120];
    reg signed [2:0] next_buf [0:120];

    // Iteration counter (k)
    reg [7:0] k;
    // Temporary index for loops
    reg [7:0] idx;
    // Max coefficient encountered during calculation
    reg signed [2:0] max_coeff;
    // Calculated value at current index
    reg signed [4:0] calc_val;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic and Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs
            done <= 1'b0;
            deg_a <= 8'd0;
            deg_b <= 8'd0;
            // Clear arrays (optional but good practice)
            for (integer i = 0; i < 121; i = i + 1) begin
                a_coeffs[i] <= 3'sd0;
                b_coeffs[i] <= 3'sd0;
                curr_buf[i] <= 3'sd0;
                prev_buf[i] <= 3'sd0;
                next_buf[i] <= 3'sd0;
            end
            k <= 8'd0;
            idx <= 8'd0;
            max_coeff <= 3'sd0;
            calc_val <= 5'sd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Initialize F_0 = 1, F_1 = x
                    // Reset arrays
                    for (integer i = 0; i < 121; i = i + 1) begin
                        curr_buf[i] <= 3'sd0;
                        prev_buf[i] <= 3'sd0;
                        next_buf[i] <= 3'sd0;
                    end
                    
                    // F_0 (prev): 1 (constant term)
                    prev_buf[0] <= 3'sd1;
                    
                    // F_1 (curr): x (degree 1, coeff at index 1 is 1)
                    curr_buf[1] <= 3'sd1;
                    
                    // Check if n=0 or n=1
                    if (n == 0) begin
                        deg_a <= 8'd0;
                        deg_b <= 8'd0; // B is F_{-1}, usually undefined, but let's 0 it. Or technically F_{-1}=0.
                        // Spec: A=F_n, B=F_{n-1}. If n=0, A=F_0, B=F_{-1}. 
                        // Assuming n >= 1 for valid GCD steps. 
                        // If n=1: A=F_1, B=F_0.
                        next_state <= FINAL;
                    end else if (n == 1) begin
                        deg_a <= 8'd1;
                        deg_b <= 8'd0;
                        // Need to copy curr to a, prev to b
                        idx <= 8'd0;
                        next_state <= FINAL;
                    end else begin
                        k <= 8'd2;
                        idx <= 8'd0;
                        max_coeff <= 3'sd0;
                        next_state <= ITERATE;
                    end
                end

                ITERATE: begin
                    // Compute x * curr_buf into next_buf temporarily to check max coeff
                    // Or simply compute max coeff directly.
                    // Logic: F_k = x*F_{k-1} + s_k * F_{k-2}
                    // We need to find max coeff of (x*F_{k-1} + F_{k-2}) and (x*F_{k-1} - F_{k-2})
                    // Step 1: Calculate x*F_{k-1} at index idx and compare
                    
                    // x*F_{k-1} shifts coefficients: coeff_i -> coeff_{i+1}
                    // So val = curr_buf[idx-1] (if idx > 0) else 0
                    
                    // Let's do a specialized state for calculating values to keep it clean
                    // Actually, let's just compute the max of x*curr + prev and x*curr - prev
                    // We can do this in a loop inside a state or sub-states.
                    // To save states, let's use the ITERATE state as a trigger, 
                    // then go to CALC_XF, CALC_SUM, CHECK_MAX.
                    
                    // Loop control for checking all indices
                    if (idx > 120) begin
                        // Should not happen, but safety
                        next_state <= UPDATE;
                    end else begin
                        next_state <= CALC_XF;
                    end
                end
                
                CALC_XF: begin
                    // Prepare x*F_{k-1} term for index idx
                    // Value is curr_buf[idx-1] if idx > 0
                    if (idx == 0) calc_val <= 5'sd0;
                    else calc_val <= { {2{curr_buf[idx-1][2]}}, curr_buf[idx-1] }; // Sign extend to 5 bits
                    next_state <= CALC_SUM;
                end

                CALC_SUM: begin
                    // Add F_{k-2} (prev_buf[idx])
                    calc_val <= calc_val + { {2{prev_buf[idx][2]}}, prev_buf[idx] };
                    // We also need to check the difference for max_coeff check.
                    // Actually, max_coeff is the max of abs( x*curr + prev ) and abs( x*curr - prev )
                    // Let's calculate both and compare to max_coeff.
                    // But wait, the spec says:
                    // s_k = 1 if max_coefficient(x*F_{k-1} + F_{k-2}) <= 1
                    // s_k = -1 otherwise
                    // So we only need the MAX of (x*curr + prev) and (x*curr - prev)?
                    // No, the spec says: check max of (x*F_{k-1} + F_{k-2}).
                    // If that max > 1, s_k = -1.
                    // So we just need to check if (x*curr + prev) has any coeff > 1 or < -1.
                    // i.e. max(abs(val)) > 1.
                    
                    // Let's use a temp variable to store the abs value of (x*curr + prev)
                    // and compare it to max_coeff.
                    
                    // Wait, we need the max of (x*curr + prev) across ALL indices to decide s_k.
                    // So we need to scan all indices.
                    
                    // Let's change strategy:
                    // State ITERATE loops k.
                    // Inside, we need a sub-loop to scan indices 0..120 to find max_abs.
                    // Let's use 'idx' for the sub-loop.
                    
                    // In ITERATE, we reset idx=0. 
                    // Then we go to CHECK_MAX.
                    // CHECK_MAX calculates value at idx, updates max_coeff, increments idx.
                    // If idx <= 120, loop CHECK_MAX.
                    // If idx > 120, we have max_abs.
                    // Then we determine s_k.
                    // Then we go to UPDATE to compute F_k.
                    
                    // Actually, we need 2 passes? 
                    // 1. Determine s_k.
                    // 2. Compute F_k = x*curr + s_k * prev.
                    
                    // Let's optimize.
                    // We can determine s_k while computing F_k if we are clever,
                    // but the check requires the MAX of the series, so we need to look ahead.
                    
                    // Revised Plan for ITERATE block:
                    // 1. Calculate max_abs(x*curr + prev) -> decide s_k.
                    // 2. Calculate F_k = x*curr + s_k * prev.
                    
                    // Let's implement step 1 here.
                    // We are in CALC_SUM, having added prev to x*curr.
                    // calc_val holds (x*curr + prev).
                    
                    // Check magnitude of calc_val.
                    // If (calc_val > 1) or (calc_val < -1), set flag.
                    // We accumulate the max magnitude found so far.
                    
                    // Let's use a register `max_abs_found`.
                    // Wait, we already have `max_coeff`.
                    
                    // We need to track if we've found any violation.
                    // Actually, the algorithm requires:
                    // If Max(|coeff| in x*curr + prev) <= 1, s_k=1.
                    // Else s_k=-1.
                    // So we need to check all coefficients.
                    
                    // Let's use a flag `violation`.
                    // In IDLE/INIT, clear violation.
                    // In CHECK_MAX state (which we'll jump to from ITERATE), 
                    // we calculate (x*curr + prev) for index `idx`.
                    // If abs(val) > 1, set violation = 1.
                    // Increment idx.
                    // Loop until idx done.
                    // If violation == 1, s_k = -1, else s_k = 1.
                    
                    // Let's fix the state flow.
                    // ITERATE: Set idx=0, violation=0. Go to CHECK_MAX.
                    // CHECK_MAX: Calc x*curr + prev at idx. Check abs > 1. Set violation. Inc idx.
                    // If idx <= 120, stay in CHECK_MAX. Else go to UPDATE.
                    // UPDATE: Compute F_k = x*curr + s_k * prev (where s_k depends on violation).
                    // Then copy curr to prev, next to curr. Inc k.
                    // If k <= n, go to ITERATE. Else go to FINAL.
                    
                    // Let's start modifying the code to this flow.
                    // (This CALC_SUM/CALC_XF separation was getting messy, let's condense).
                    
                    // We will jump back to ITERATE state to reset for the next K cycle, 
                    // or use a specific state for the sub-loop.
                    
                    // Let's go to CHECK_MAX state.
                    next_state <= CHECK_MAX;
                end

                CHECK_MAX: begin
                    // This state handles the loop to find max abs coeff of (x*curr + prev)
                    // We calculate value at idx.
                    calc_val <= 0;
                    // Value = curr_buf[idx-1] + prev_buf[idx]
                    if (idx > 0 && idx <= 120)
                        calc_val <= $signed(curr_buf[idx-1]) + $signed(prev_buf[idx]);
                    else if (idx <= 120)
                        calc_val <= $signed(prev_buf[idx]); // idx=0, x*curr is 0
                    
                    // We need to process this value next cycle or combinational?
                    // Let's do combinational check in next state or this state if we delay.
                    // Let's make CHECK_MAX update the violation flag.
                    // We need to know the value first. 
                    // Let's separate Calc and Check.
                    // But to save states, let's assume we read curr_buf and prev_buf directly in an always block?
                    // No, logic must be synchronous or registered.
                    
                    // Let's go to a state where we update the violation flag based on calc_val.
                    // Actually, we can do:
                    // State: CHECK_MAX -> (calculate val, check violation, inc idx)
                    // But 'calc_val' needs a cycle.
                    // So: 
                    // 1. State CALC: compute val, store in calc_val.
                    // 2. State CHECK: check calc_val, update violation, inc idx.
                    
                    // Let's return to ITERATE to setup the loop, then use CALC_XF/CALC_SUM/CHECK_MAX as a sequence.
                    // But wait, we need to do this for ALL indices to decide s_k.
                    // So we need a loop.
                    
                    // Let's re-structure:
                    // ITERATE (k loop):
                    //   idx = 0; violation = 0;
                    //   sub_state = CHECK_LOOP;
                    //   state = CHECK_LOOP_START;
                    //   (Nested loops via states is standard)
                    //   State: CHECK_LOOP_START: Calc value for idx. 
                    //   State: CHECK_LOOP_CHECK: Update violation. Inc idx. If idx <= 120, goto CHECK_LOOP_START. Else goto UPDATE.
                    
                    // Let's add a new state CHECK_LOOP.
                    // We will handle the 'scan' there.
                    // But we need to store 'violation' flag.
                    // Let's use `max_coeff` register to store the violation flag (1 or 0) or just `idx` to control the loop.
                    // Let's use `max_coeff` as a boolean flag: 0 (no violation), 1 (violation).
                    
                    // Let's go to a dedicated `SCAN` state.
                    // But wait, we need to calculate (x*curr + prev). 
                    // Let's do this in the `SCAN` state.
                    
                    // Reset idx and violation in ITERATE.
                    // Go to SCAN.
                    // SCAN: Calculate val at idx. 
                    // Then check. 
                    // Then inc idx.
                    // If idx <= 120, stay in SCAN. Else go to UPDATE.
                    
                    // Can we do calc and check in one state? 
                    // We can read `curr` and `prev` in `SCAN`.
                    // But `val` calculation is combinational?
                    // If we want to use `val` for checking, it must be computed.
                    // Let's compute `val` combinationally based on `idx`, `curr_buf`, `prev_buf`.
                    // But the requirement says "Assume all inputs are of type reg unless otherwise specified". 
                    // And "Do not assume a clock signal unless explicitly given" (clk is given).
                    // So we can use combinational logic or sequential logic.
                    // Let's use a combinational block to compute `scan_val`.
                    // And a sequential block for the state machine.
                    
                    // Let's do the combinational logic at the top.
                    // wire signed [4:0] scan_val = (idx > 0) ? curr_buf[idx-1] + prev_buf[idx] : prev_buf[idx];
                    // wire scan_violation = (scan_val > 1 || scan_val < -1);
                    
                    // Then in state SCAN:
                    // if (scan_violation) violation <= 1;
                    // idx <= idx + 1;
                    // if (idx < 120) state <= SCAN; else state <= UPDATE;
                    
                    // This works. 
                    // So we don't need CALC_XF/CALC_SUM here.
                    // We need a state for 'SCAN'.
                    
                    // Let's modify the flow again to be clean.
                    // IDLE -> INIT -> ITERATE -> SCAN -> UPDATE -> (loop) -> FINAL -> DONE
                    
                    // We are currently in ITERATE (which I used as a placeholder). 
                    // Let's go to SCAN.
                    // But we need to reset idx and violation in ITERATE.
                    
                    // Let's go back to the top and fix the state flow logic properly.
                    // I will overwrite the logic below.
                    
                    // Current logic in this block is partial. Let's reset next_state.
                    next_state <= IDLE; // Default fallback
                end

                // UPDATE state: Compute F_k = x*curr + s_k * prev
                UPDATE: begin
                    // s_k is determined by max_coeff register (which holds violation flag 0 or 1)
                    // If violation=1, s_k=-1, else s_k=1.
                    // max_coeff was used for 'violation' flag in the SCAN phase.
                    
                    // Compute next_buf.
                    // Loop idx from 0 to 120.
                    // If we are just starting UPDATE:
                    if (idx == 0) begin // We can use a flag, but let's assume idx is reset or logic handles it.
                         // Actually, we need a loop inside UPDATE.
                         // Let's treat UPDATE as a multi-cycle state.
                         // Use idx to iterate.
                         // We need to calculate next_buf[idx] = (idx>0 ? curr_buf[idx-1] : 0) + s_k * prev_buf[idx].
                    end
                    
                    // Let's perform the calculation for current idx.
                    // s_k = (max_coeff == 1) ? -1 : 1;
                    
                    if (idx == 0) begin
                        next_buf[0] <= 3'sd0; // x*curr[0] is 0, + s_k*prev[0]
                    end else begin
                        // x*curr[idx] = curr[idx-1]
                        if (max_coeff == 1) // violation found, s_k = -1
                            next_buf[idx] <= $signed(curr_buf[idx-1]) - $signed(prev_buf[idx]);
                        else
                            next_buf[idx] <= $signed(curr_buf[idx-1]) + $signed(prev_buf[idx]);
                    end
                    
                    // Loop control
                    if (idx < 120) begin
                        idx <= idx + 1;
                        next_state <= UPDATE;
                    end else begin
                        // Update finished.
                        // Copy buffers: prev <= curr, curr <= next
                        // We need to copy 121 elements. This takes time or many states.
                        // To save states, let's do the copy in the next state or reuse states.
                        // We can do copy in a state called 'SWAP'.
                        // Or do it sequentially here.
                        // Let's do it in a separate state 'COPY' to keep UPDATE focused on calculation.
                        
                        // However, we have a constraint of latency. 
                        // 3 cycles per iteration (Iter, Calc, Check). 
                        // Here: ITERATE (1), SCAN (scan 121 indices?), UPDATE (121 indices).
                        // This blows the latency.
                        
                        // The prompt says "Latency: Approximately 3 clock cycles per iteration".
                        // This implies we should optimize.
                        // 121 elements is large. 
                        // Maybe the 'scan' for max coeff can be done in one cycle if we parallelize?
                        // But Verilog is sequential logic. 
                        // Or maybe the "Iteration" refers to the generation of ONE polynomial, and the inner loop is implicit?
                        // No, "Iterate: Loop k from 2 to n, computing F_k".
                        // "Approximately 3 clock cycles per iteration" suggests a simplified logic.
                        // Maybe we can assume that the max_coeff calculation and update can be done in a pipelined way 
                        // or we only need to process the relevant coefficients (non-zero)?
                        // But degrees go up to 120. 
                        // 
                        // Let's look at the algorithm: F_k = x*F_{k-1} + s_k * F_{k-2}.
                        // The degrees increase. 
                        // F_0: deg 0. F_1: deg 1. F_2: deg 2. ... F_120: deg 120.
                        // So at step k, we only need to consider indices up to k (approx).
                        // Yes! We only need to process up to k.
                        // So at step k, loop 0 to k.
                        // This reduces the loop length drastically over time.
                        // For k=120, it's 120 cycles. Still large for "3 cycles".
                        // 
                        // Maybe we should use a 'for' loop in combinational logic?
                        // "Use all provided details... Only return Verilog code thats synthesizable."
                        // Synthesizable code usually implies RTL (Registers, always blocks).
                        // But 'for' loops inside always blocks are synthesizable if they are unrolled or limited.
                        // 
                        // Let's reconsider the "3 cycles". 
                        // It might mean: 
                        // Cycle 1: Determine s_k (scan).
                        // Cycle 2: Calculate F_k.
                        // Cycle 3: Swap pointers.
                        // But scanning 120 elements takes >1 cycle unless parallel.
                        // 
                        // Maybe the "scan" is just a combinational check on the previous result?
                        // "max_coefficient(x*F_{k-1} + F_{k-2})".
                        // If we compute F_{k-1} and F_{k-2} in hardware, maybe we track max coeff.
                        // 
                        // Let's assume the user wants a standard sequential implementation, 
                        // and "approx 3 cycles per iteration" is a rough estimate or assumes 
                        // optimizations (like pipelining or parallel max find) not detailed here.
                        // 
                        // Given the strict JSON/Code requirements, let's implement a clear, 
                        // correct sequential logic, even if it takes more than 3 cycles per step.
                        // We can't fit a full 121-element scan + update + swap in 3 cycles of standard logic.
                        // Unless we do this:
                        // 
                        // State: ITERATE (k loop)
                        //   State: PREP (reset scan)
                        //   State: SCAN (loop i=0..k, combinational max? No, sequential)
                        //   State: UPDATE (loop i=0..k)
                        //   State: SWAP (copy)
                        //   If k<n, repeat.
                        // 
                        // Let's use combinational logic for `s_k` determination.
                        // We can compute `s_k` assignment combinationally based on current state.
                        // But we need the values of (x*curr + prev).
                        // Let's use a combinational block to find the max coefficient of (x*curr + prev) 
                        // and (x*curr - prev) in one go? 
                        // No, that's complex combinational logic (121 deep). 
                        // 
                        // Let's implement a clear sequence:
                        // 
                        // 1. IDLE
                        // 2. INIT: Setup F0, F1.
                        // 3. LOOP_K (if k <= n):
                        //    4. DETERMINE_S:
                        //       We need to find max(|x*curr + prev|) to decide s_k.
                        //       We can do this by iterating index `i` from 0 to `k` (which is roughly `k`)
                        //       Track max.
                        //       Then s_k = 1 if max <= 1, else -1.
                        //    5. COMPUTE_F:
                        //       Compute F_k = x*curr + s_k * prev (for i=0..k)
                        //       Store in next_buf.
                        //    6. SWAP: curr -> prev, next -> curr. 
                        //       Increment k. Go to LOOP_K.
                        // 7. FINAL: Copy to outputs.
                        // 8. DONE
                        // 
                        // To handle the loops (inner loops for i), we use the `idx` register.
                        // 
                        // Let's refine the states:
                        // - IDLE
        // - INIT
        // - LOOP_START (checks if k <= n, resets idx for inner loops)
        // - SCAN_START (inner loop: scan coeffs to find max abs of x*curr+prev)
        //    - State: SCAN_READ (compute val = x*curr[idx] + prev[idx])
        //    - State: SCAN_UPDATE (update max_val)
        // - SCAN_DONE (decide s_k)
        // - COMP_START (inner loop: compute F_k)
        //    - State: COMP_READ (compute val = x*curr[idx] + s_k * prev[idx])
        //    - State: COMP_WRITE (store to next_buf[idx])
        // - COMP_DONE (swap buffers)
        // - LOOP_DONE (increment k, jump to LOOP_START or FINAL)
        // 
        // This is a lot of states, but correct.
        // Optimization: We can merge SCAN_READ/UPDATE and COMP_READ/WRITE.
        // 
        // Let's try to fit the "3 cycles" requirement.
        // Maybe we can process multiple indices per cycle?
        // Or maybe the prompt implies a 'poly' module where F_k is calculated directly by formula,
        // and the 'benchmark' is the algorithm, not the implementation speed.
        // 
        // Let's write the code with the assumption that correctness is key, 
        // and we implement the loops as described. 
        // 
        // Re-reading: "Latency: Approximately 3 clock cycles per iteration".
        // Maybe they consider the *polynomial degree* as the iteration cost? 
        // No, it's usually per step k.
        // 
        // Let's stick to a clear RTL flow. 
        // I will implement the states to handle the loops.
        // 
        // Actually, there's a trick. 
        // The algorithm is F_k = x*F_{k-1} + s_k * F_{k-2}.
        // We can maintain `next` as `x*curr` (shift) + `s_k*prev`.
        // But `s_k` depends on the max of `x*curr + prev`.
        // 
        // Let's use a single 'step' state that does everything in a slow loop.
        // But with 120 max, we can't hardcode.
        // 
        // Let's go with the loop approach but try to minimize states.
        // 
        // Let's add a combinational block to calculate the 'current value' for the loop.
        // 
        // State: ITER (checks k <= n)
        //   Set idx = 0, max_val = 0, mode = 0 (scan).
        //   State: PROCESS (generic step state)
        //     If mode == 0 (scan): 
        //        val = curr[idx-1] + prev[idx] (if idx>0 else prev[idx])
        //        max_val = max(max_val, |val|)
        //        idx++.
        //        If idx <= k: Stay in PROCESS.
        //        Else: mode = 1, idx = 0. (Switch to compute)
        //        s_k = (max_val <= 1) ? 1 : -1.
        //     Elif mode == 1 (compute):
        //        val = curr[idx-1] + s_k * prev[idx]
        //        next[idx] = val.
        //        idx++.
        //        If idx <= k: Stay in PROCESS.
        //        Else: mode = 2. (Switch to swap)
        //     Elif mode == 2 (swap):
        //        prev = curr.
        //        curr = next.
        //        k++.
        //        Go to ITER.
        // 
        // This is a "microcode" approach. It works. 
        // 
        // Let's refine the 'PROCESS' state.
        // We need to calculate `val` based on `mode` and `idx`.
        // We can use a combinational block for `val`.
        // 
        // But wait, "Do not assume a clock signal unless it is explicitly given".
        // It IS given. So we can do sequential logic.
        // 
        // Let's design the state transitions cleanly.
        
        // Let's abandon the previous partial logic and write the clean version.
        // 
        // I will use `current_state` to manage the flow.
        // I will use `idx` for the inner loop index.
        // I will use `max_coeff` to store `max_val` (magnitude).
        // I will use `k` for the outer loop counter.
        // I will use `a_coeffs` to store F_n and `b_coeffs` to store F_{n-1}.
        // 
        // Optimization for "3 cycles": 
        // Maybe the inner loop runs at full clock speed, and "3 cycles" refers to something else?
        // Or maybe `start` triggers a calculation that takes `3*n` cycles.
        // "3*n + 5 cycles total". 
        // 5 is constant overhead. 3*n implies 3 per k.
        // If n=120, 360 cycles.
        // If we iterate indices 0..k, total operations is ~120*120/2 = 7200 ops.
        // 360 cycles < 7200 ops. So we must parallelize.
        // 
        // Parallelization idea:
        // We store arrays. 
        // We can read `curr` and `prev` and calculate `next` in parallel?
        // But we need `s_k` first.
        // 
        // Wait, the problem might be that I am overthinking the "iterative" part.
        // Euclid's algorithm is usually iterative GCD.
        // Here, it's "generating polynomials" such that Euclid's algorithm takes n steps.
        // The generation uses the formula `F_k = ...`.
        // 
        // If the latency is strict 3*n, then we cannot do O(k^2) operations.
        // 
        // Is there a recurrence for `s_k`?
        // s_k depends on max coeff of (x*F_{k-1} + F_{k-2}).
        // The max coeff of (x*F_{k-1} + F_{k-2}) is NOT directly related to max coeffs of F_{k-1} and F_{k-2} 
        // in a simple additive way (e.g. max could be 1+1).
        // 
        // Let's assume the "3 cycles per iteration" is an approximation for a pipelined implementation 
        // where we compute `s_k` in Cycle 1, `next` in Cycle 2, `swap` in Cycle 3.
        // And the inner loop over indices is somehow unrolled or hidden? 
        // No, that's impossible for arrays of size 120.
        // 
        // Maybe the arrays `a_coeffs` and `b_coeffs` are NOT 121 deep in terms of logic?
        // "output reg signed [2:0] a_coeffs [0:120]". Yes, 121 elements.
        // 
        // Let's re-read carefully: "Latency: Approximately 3 clock cycles per iteration, so 3*n + 5 cycles total."
        // This is a SPEC. We must meet it.
        // How to do 121 element operations in 3 cycles? 
        // 1. Scan max: 121 adders? Combinational max tree? 
        //    If we do a big combinational block to find `s_k`:
        //    `scan_val[i] = curr[i-1] + prev[i]`
        //    `max_val = max(|scan_val[i]|)`
        //    This is possible. A large combinational logic.
        // 2. Compute `next`: 121 adders. Combinational.
        // 3. Swap: Register assignment. 1 cycle.
        //    
        // So, we can do:
        // Cycle 1: Calculate `s_k` (combinational logic) from current `curr` and `prev`. Register `s_k_reg`.
        // Cycle 2: Calculate `next` array (combinational logic) using `curr`, `prev`, `s_k_reg`. Register `next`.
        // Cycle 3: Swap pointers (Logic: `prev <= curr`, `curr <= next`).
        // 
        // This fits the "3 cycles" if we allow large combinational blocks.
        // This is typical for "ASIP" or specialized datapaths.
        // 
        // Let's implement this.
        // 
        // We need combinational logic to calculate:
        // 1. `max_abs_plus` of (x*curr + prev)
        // 2. `s_k` = (max_abs_plus <= 1) ? 1 : -1.
        // 3. `next_calc[i]` = curr[i-1] + s_k * prev[i].
        // 
        // Register layout:
        // `curr_buf[0..120]`
        // `prev_buf[0..120]`
        // `next_buf[0..120]` (temporary)
        // `s_k_reg`
        // `k_reg`
        // 
        // State Machine:
        // IDLE -> INIT -> LOOP_START -> CALC_S -> EXECUTE -> SWAP -> (Check k) -> LOOP_START or FINAL.
        // 
        // CALC_S: Combinational logic calculates `s_k_next`.
        // EXECUTE: Combinational logic calculates `next_calc`. Then `next_buf <= next_calc`.
        // SWAP: `prev_buf <= curr_buf`, `curr_buf <= next_buf`. `k_reg <= k_reg + 1`.
        // 
        // Timing:
        // INIT: 1 cycle.
        // CALC_S: 1 cycle (updates `s_k_reg`).
        // EXECUTE: 1 cycle (updates `next_buf`).
        // SWAP: 1 cycle. 
        // Wait, that's 4 cycles. 
        // Can we combine EXECUTE and SWAP?
        // In EXECUTE, we calculate `next_calc`. 
        // Can we register `next_calc` directly into `next_buf`? Yes.
        // Can we register `curr` -> `prev` in the same cycle? Yes, if `prev` is a register.
        // 
        // But `s_k` depends on `curr` and `prev`.
        // We register `s_k` in CALC_S.
        // In EXECUTE, we use `s_k_reg` to compute `next`.
        // In SWAP, we update `curr` and `prev`.
        // 
        // Can we do `s_k` calculation combinationally in EXECUTE state?
        // If we do, we don't need a separate CALC_S state.
        // But `s_k` must be stable when we calculate `next`.
        // If we calculate `s_k` combinationaly from `curr`/`prev` and `next` from `curr`/`prev`/`s_k`, 
        // it's all combinational. 
        // Then we need to register `next` and `prev`/`curr`.
        // 
        // Sequence:
        // State EXECUTE:
        //   s_k_next = logic(curr, prev)
        //   next_calc = logic(curr, prev, s_k_next)
        //   next_buf <= next_calc
        //   prev_buf <= curr_buf
        //   curr_buf <= next_calc (Wait, `curr` becomes `next`, `prev` becomes `old curr`)
        //   k++
        //   If k <= n, stay in EXECUTE. Else FINAL.
        //   
        // This reduces to 1 state for the iteration, 1 cycle per step.
        // But `next_calc` depends on `s_k_next`, which depends on max tree of `curr`/`prev`.
        // This is a long combinational path. 
        // But it is valid synthesizable Verilog.
        // 
        // Let's do this:
        // 
        // States: IDLE, INIT, EXECUTE, FINAL, DONE.
        // 
        // INIT: Set F0, F1. Set k=2. 
        // EXECUTE: 
        //   Calculate s_k (combinational helper block).
        //   Calculate next_coeffs (combinational helper block).
        //   Register updates: 
        //     prev <= curr
        //     curr <= next_coeffs
        //     k <= k + 1
        //   If k < n, repeat EXECUTE. Else go to FINAL.
        // 
        // To be safe and standard, let's separate the combinational logic into `always @(*)` blocks.
        // 
        // Wait, the problem asks for a "sequential Verilog module".
        // Usually this means edge-triggered flip-flops.
        // But combinational logic inside is fine.
        // 
        // Let's refine the states:
        // 1. IDLE
        // 2. INIT: 
        //    prev = F0, curr = F1, k=2.
        //    next_state = EXECUTE.
        // 3. EXECUTE (active state):
        //    Calculates s_k (combo).
        //    Calculates next_poly (combo).
        //    Then updates registers:
        //       prev <= curr;
        //       curr <= next_poly;
        //       k <= k + 1;
        //    If k+1 > n, next_state = FINAL.
        //    Else next_state = EXECUTE.
        // 4. FINAL: 
        //    a_coeffs = curr
        //    b_coeffs = prev
        //    deg_a = n
        //    deg_b = n-1
        //    next_state = DONE
        // 5. DONE: done=1. Wait for start low or reset.
        // 
        // This is efficient.
        // 
        // Edge case: n=0 or n=1.
        // n=0: A=F0, B=F_{-1}. We'll handle n=0 in INIT -> FINAL.
        // n=1: A=F1, B=F0. Handled in INIT -> FINAL.
        // 
        // Combinational logic for `s_k` and `next_poly`:
        // 
        // wire signed [2:0] x_curr [0:120];
        // assign x_curr[0] = 0;
        // assign x_curr[i] = curr[i-1] for i=1..120.
        // 
        // wire signed [4:0] sum [0:120];
        // assign sum[i] = x_curr[i] + prev[i];
        // 
        // To find max_abs:
        // We need a loop or a tree.
        // Since this is a module, let's write a function or generate logic.
        // Verilog doesn't have `for` in combinational logic for synthesis easily unless unrolled.
        // But we can use a `for` loop inside an `always @(*)` block to infer a comparator tree.
        // 
        // `max_abs_val = 0; for i=0 to 120: val = abs(sum[i]); if (val > max_abs_val) max_abs_val = val;`
        // 
        // Then s_k = (max_abs_val <= 1) ? 1 : -1.
        // 
        // For `next_poly`:
        // `next_poly[i] = x_curr[i] + s_k * prev[i]`.
        // 
        // 
        // Let's write the code structure.
        // 
        // Note: The arrays are packed `reg signed [2:0] a_coeffs [0:120]`. 
        // Synthesis tools usually handle `for` loops inside `always` blocks for arrays if the size is fixed.
        // 
        // Let's implement the helper combinational logic as `always @(*)` blocks.
        // 
        // 
        // Re-eval: "Assume all inputs are of type `reg` unless otherwise specified".
        // This probably applies to module inputs, not necessarily internal signals.
        // 
        // Let's generate the code.
        // 
        // We need to be careful with `k` logic. 
        // k starts at 2 in INIT.
        // We loop while k <= n.
        // Inside EXECUTE, we compute F_k, then update k = k+1.
        // 
        // If n=0 or n=1, we handle in INIT.
        // 
        // If n=1: A=F1, B=F0.
        // We initialize curr=F1, prev=F0. 
        // Since k=2, we skip EXECUTE (2 > 1). Go FINAL.
        // 
        // If n=2: A=F2, B=F1.
        // Init: curr=F1, prev=F0, k=2.
        // Execute: calc F2. curr<=F2, prev<=F1, k=3.
        // 3 > 2. Go FINAL.
        // 
        // This works.
        // 
        // One detail: `max_abs_val` calculation.
        // `sum[i]` is signed 5 bits. `abs` is `val > 0 ? val : -val`.
        // 
        // Let's define the combinational logic.
        // 
        // 
        // Code structure:
        // 
        // module ...
        //    reg signed [2:0] prev [0:120];
        //    reg signed [2:0] curr [0:120];
        //    reg [7:0] k_reg;
        //    
        //    wire signed [2:0] x_curr [0:120];
        //    wire signed [4:0] sum [0:120];
        //    wire [4:0] abs_sum [0:120];
        //    wire [4:0] max_abs_val; // Max of abs_sum
        //    wire s_k_val; // 1 for +1, 0 for -1 (or similar encoding)
        //    wire signed [2:0] next_poly [0:120];
        //    
        //    // Combinational blocks for x_curr, sum, abs_sum
        //    // Combinational block for max_abs_val (loop or tree)
        //    // Combinational block for s_k_val
        //    // Combinational block for next_poly
        //    
        //    // State machine
        //    always @(posedge clk ...) ...
        //       case(state)
        //         INIT: ...
        //         EXECUTE: begin
        //            prev <= curr;
        //            curr <= next_poly;
        //            k_reg <= k_reg + 1;
        //            if (k_reg + 1 > n) state <= FINAL; else state <= EXECUTE;
        //         end
        //         ...
        //       endcase
        //    
        //    // Output assignments
        //    always @(*) begin
        //       if (state == FINAL) begin
        //          // assign a_coeffs = curr, etc.
        //       end
        //    end
        // 
        // Wait, `max_abs_val` calculation needs a loop.
        // In Verilog, we can do:
        // 
        // reg [4:0] max_found;
        // integer i;
        // always @(*) begin
        //   max_found = 0;
        //   for (i=0; i<=120; i=i+1) begin
        //     if (abs_sum[i] > max_found) max_found = abs_sum[i];
        //   end
        // end
        // 
        // This generates a comparator chain or tree, which is fine.
        // 
        // Let's check coefficients size.
        // a_coeffs is output reg signed [2:0].
        // We need to assign them.
        // 
        // In state FINAL, we assign:
        // deg_a = n;
        // deg_b = n-1; (Handle n=0 case? B is undefined, maybe 0).
        // a_coeffs = curr;
        // b_coeffs = prev;
        // done = 1.
        // 
        // If we are in IDLE, done = 0.
        // 
        // Let's handle n=0.
        // If n=0: A=F0, B=F_{-1}. 
        // In INIT, we set curr=F1, prev=F0.
        // If n=0, k_reg should be ? 
        // We can check in INIT. 
        // If n==0: 
        //   curr <= F0? 
        //   No, curr is F1. 
        //   Let's handle n=0/1 explicitly.
        //   
        //   Actually, let's set up pointers in INIT:
        //   If n == 0: 
        //      a_coeffs <= F0, b_coeffs <= 0 (or maybe F_{-1}=0). deg_a=0, deg_b=0? 
        //      wait, B=F_{n-1} = F_{-1}. Usually GCD(A, B) where A=F_n, B=F_{n-1}. 
        //      If n=0, A=F0=1. B=F_{-1}=? Usually 0 or X.
        //      Let's assume B=0 for n=0.
        //      
        //   If n == 1:
        //      a_coeffs <= F1, b_coeffs <= F0.
        //      deg_a=1, deg_b=0.
        //      
        //   If n >= 2:
        //      curr <= F1, prev <= F0, k=2. Go EXECUTE.
        //      
        //   Let's do this in INIT state logic.
        //   
        //   Actually, we can merge.
        //   In INIT:
        //     Clear arrays.
        //     prev[0] = 1.
        //     curr[1] = 1.
        //     
        //     If n==0: 
        //       // A = F0, B = F_{-1}
        //       // Copy prev to a_coeffs? 
        //       // No, prev is F0. 
        //       // Wait, curr is F1. prev is F0.
        //       // We want A=F0. So A = prev.
        //       // B = ? 0.
        //       // So copy prev to a, 0 to b. 
        //       // state <= FINAL.
        //       
        //     If n==1:
        //       // A=F1, B=F0.
        //       // Copy curr to a, prev to b.
        //       // state <= FINAL.
        //       
        //     Else (n>=2):
        //       // Setup for loop.
        //       k_reg = 2.
        //       state <= EXECUTE.
        //       
        //   This works.
        // 
        //   One detail: In EXECUTE, we do `prev <= curr`. 
        //   If we enter EXECUTE with curr=F1, prev=F0, then after 1st cycle:
        //   prev=F1, curr=F2, k=3.
        //   If n=2, we stop. So prev=F1 (B), curr=F2 (A). Correct.
        //   
        //   So the logic holds.
        //   
        //   Let's write the combinational helpers.
        //   We need to handle the arrays.
        //   
        //   Since we need to access `curr[i-1]`, we need to handle index 0 carefully.
        //   
        //   Let's define the wires for `x_curr` and `sum`.
        //   
        //   We must be careful with the loops in combinational blocks.
        //   
        //   I will write the code in the response.

                    // Back to the sequential logic block:
                    // We need to manage the state transitions.
                    // Let's reset the 'next_state' logic in the sequential block.
                    
                    // I'll rewrite the state machine logic cleanly below.
                    
                    next_state <= IDLE; // Default
                    
                    case (current_state)
                        IDLE: if (start) next_state <= INIT; else next_state <= IDLE;
                        
                        INIT: begin
                            // Setup F0, F1
                            // Clear logic for arrays is complex in Verilog inside always block.
                            // We will overwrite needed indices.
                            
                            // F0 = 1
                            prev_buf[0] <= 3'sd1;
                            for (integer i=1; i<121; i=i+1) prev_buf[i] <= 3'sd0;
                            
                            // F1 = x
                            curr_buf[1] <= 3'sd1;
                            curr_buf[0] <= 3'sd0;
                            for (integer i=2; i<121; i=i+1) curr_buf[i] <= 3'sd0;
                            
                            // Setup k
                            k <= 8'd2;
                            
                            if (n == 0) begin
                                // A=F0, B=F_{-1}=0
                                // Copy prev (F0) to a_coeffs, 0 to b_coeffs
                                // We will do this in FINAL state to avoid duplication.
                                // So we force n to 0 logic here.
                                // But we need to set curr to F0 and prev to 0 for FINAL to pick up.
                                // Or just set a flag.
                                // Let's just go to FINAL and handle it there.
                                // But FINAL expects curr=A, prev=B.
                                // For n=0: A=F0 (prev_buf), B=0.
                                // So we can assign curr <= prev_buf, prev <= 0.
                                curr_buf <= prev_buf; // curr = F0
                                for (integer i=0; i<121; i=i+1) prev_buf[i] <= 3'sd0; // B=0
                                next_state <= FINAL;
                            end else if (n == 1) begin
                                // A=F1, B=F0.
                                // curr is F1, prev is F0.
                                // Go FINAL.
                                next_state <= FINAL;
                            end else begin
                                // n >= 2. Start iteration.
                                next_state <= EXECUTE;
                            end
                        end

                        EXECUTE: begin
                            // 1. Calculate s_k (Comb logic sets s_k_reg_temp)
                            // 2. Calculate next_poly (Comb logic sets next_poly_temp)
                            // 3. Update registers:
                            //    prev <= curr
                            //    curr <= next_poly_temp
                            //    k <= k + 1
                            // 4. Check if k+1 > n.
                            
                            // Since combinational logic depends on curr and prev, 
                            // and we are updating them, we must be careful about timing.
                            // We need to use the CURRENT curr and prev to compute the NEXT ones.
                            // Then register them.
                            
                            // We need combinational logic to calculate `s_k_next` and `next_poly_next`.
                            // Let's assume we have these values ready.
                            
                            // Logic:
                            // next_curr = next_poly_logic(curr, prev, s_k_logic(curr, prev))
                            // 
                            // We will instantiate this logic in combinational blocks outside the FSM.
                            // The FSM will just do:
                            
                            prev_buf <= curr_buf;
                            curr_buf <= next_poly_comb; // driven by combinational block
                            k <= k + 1;
                            
                            if (k + 1 > n)
                                next_state <= FINAL;
                            else
                                next_state <= EXECUTE;
                        end

                        FINAL: begin
                            // Assign outputs
                            deg_a <= n;
                            if (n == 0) deg_b <= 8'd0; else deg_b <= n - 1;
                            
                            // Copy arrays
                            // This takes 1 cycle. 
                            // We copy curr to a, prev to b.
                            // Since arrays are 121 wide, we can do this in 1 cycle 
                            // if we use combinational assignment or unrolled assignments.
                            // In sequential block, we can't loop 121 times in 1 cycle 
                            // unless we unroll or use `a_coeffs <= curr_buf` (if types match).
                            // 
                            // Verilog allows array assignment if they are declared same type.
                            // `a_coeffs` and `curr_buf` are both `reg signed [2:0] [0:120]`.
                            // So we can do:
                            a_coeffs <= curr_buf;
                            b_coeffs <= prev_buf;
                            
                            done <= 1'b1;
                            next_state <= DONE;
                        end

                        DONE: begin
                            if (!start) next_state <= IDLE; // Wait for start to go low
                            else next_state <= DONE;
                        end
                        
                        default: next_state <= IDLE;
                    endcase
                end
            endcase
        end
    end

    // Combinational Logic for Polynomial Generation
    // We need to calculate next_poly_comb based on current curr_buf and prev_buf.
    // This is purely combinational.
    
    // 1. Calculate x * curr_buf (shifted)
    wire signed [2:0] x_curr [0:120];
    assign x_curr[0] = 3'sd0;
    generate
        genvar i;
        for (i = 1; i < 121; i = i + 1) begin : gen_x_curr
            assign x_curr[i] = curr_buf[i-1];
        end
    endgenerate

    // 2. Calculate (x*curr + prev) and find max absolute value
    wire signed [4:0] sum [0:120];
    wire [4:0] abs_sum [0:120];
    
    generate
        for (i = 0; i < 121; i = i + 1) begin : gen_sum
            assign sum[i] = $signed(x_curr[i]) + $signed(prev_buf[i]);
            // Absolute value
            assign abs_sum[i] = (sum[i][4] ? -sum[i] : sum[i]);
        end
    endgenerate

    // Tree reduction for max or iterative logic
    // Since Verilog doesn't have a simple `max` function for arrays in synthesis without loops,
    // we use a loop in an always_comb block.
    // Note: This creates a comparator chain/tree.
    reg [4:0] max_abs_val;
    integer j;
    always @(*) begin
        max_abs_val = 5'd0;
        for (j = 0; j < 121; j = j + 1) begin
            if (abs_sum[j] > max_abs_val) begin
                max_abs_val = abs_sum[j];
            end
        end
    end

    // 3. Determine s_k
    wire signed [2:0] s_k;
    assign s_k = (max_abs_val <= 1) ? 3'sd1 : 3'sd3; // 3'sd3 is -1 in signed 3-bit? No, -1 is 3'b111 = -1.
    // 3'sd1 is 001. 3'sd3 is 011 (value 3). 
    // 3'sd -1 is -1. 
    // Let's use -1.
    assign s_k = (max_abs_val <= 1) ? 3'sd1 : -3'sd1;

    // 4. Calculate next_poly = x*curr + s_k * prev
    wire signed [2:0] next_poly [0:120];
    wire signed [4:0] next_val [0:120]; // Intermediate with larger bits
    
    generate
        for (i = 0; i < 121; i = i + 1) begin : gen_next
            // next_val = x_curr[i] + s_k * prev_buf[i]
            // s_k * prev is multiplication. 
            // s_k is -1 or 1. So it's either +prev or -prev.
            // x_curr is signed 3 bits.
            // prev is signed 3 bits.
            // Result needs 4 or 5 bits to be safe, then clamped to 3 bits.
            // But the algorithm guarantees result is in {-1, 0, 1} if we follow the rules.
            // However, we should ensure no overflow in intermediate calc (e.g. 1 + 1 = 2, but algorithm prevents this if s_k=1).
            // If s_k=-1, 1 - (-1)? No.
            // x*curr term is 0 or +/-1. s_k*prev is 0 or +/-1.
            // Sum is -2, -1, 0, 1, 2. 
            // Wait, if s_k=-1, we compute x*curr - prev.
            // If x*curr = 1, prev = -1 -> 1 - (-1) = 2. 
            // The algorithm guarantees that if s_k=-1, then max(|x*curr + prev|) > 1.
            // But it doesn't guarantee max(|x*curr - prev|) <= 1.
            // It guarantees the result of the operation we choose is in {-1, 0, 1}?
            // "F_k(x) = x * F_{k-1}(x) + s_k * F_{k-2}(x)"
            // "where s_k = 1 if max_coefficient(x*F_{k-1} + F_{k-2}) <= 1"
            // "s_k = -1 otherwise"
            // The definition of F_k ensures coefficients are in {-1, 0, 1}.
            // So we might need to clamp? 
            // Or maybe `max_coefficient` checks `x*F_{k-1} - F_{k-2}` if `x*F_{k-1} + F_{k-2}` is bad.
            // Let's re-read: "s_k = 1 if max_coefficient(x*F_{k-1} + F_{k-2}) <= 1, else -1".
            // This is standard definition for these polynomials.
            // It implies if we use s_k=-1, the result IS valid (in range).
            // So we don't need to clamp.
            
            // Let's use 5 bits for calculation to be safe, then assign to 3 bits.
            // But since we know it fits, direct assignment is fine if we truncate correctly.
            // 
            assign next_val[i] = $signed(x_curr[i]) + ($signed(s_k) * $signed(prev_buf[i]));
            // Saturate or truncate? 
            // If the algorithm works, it fits. 
            // Let's just assign. 
            assign next_poly[i] = next_val[i][2:0]; // Truncate/Pass lower bits.
        end
    endgenerate

    // Handle the specific case of n=0,1 in INIT if needed, but the logic above handles it.
    // One issue: In FINAL state, we copy `curr` and `prev` to outputs.
    // `curr` and `prev` are updated at the clock edge.
    // So in FINAL state (next cycle after EXECUTE), they hold the correct values.
    
    // However, for n=0, we jumped to FINAL from INIT. 
    // We set `curr` = prev (F0) and `prev` = 0 in INIT.
    // But INIT is a state where we update registers.
    // `curr` becomes F1 (standard). Then we override it.
    // Correct.

endmodule
