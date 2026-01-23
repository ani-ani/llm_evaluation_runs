module eurus_solver(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    input [7:0] k,
    output reg [29:0] result,
    output reg done
);

    // Parameters and Constants
    parameter MOD = 30'd1000000007;

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CALCULATE_PHI = 3'b001;
    localparam CHECK_COUNT = 3'b010;
    localparam DONE = 3'b011;
    // Sub-states for factorization loop
    localparam FACTOR_LOOP = 3'b100;
    localparam UPDATE_RESULT = 3'b101;

    // Registers
    reg [2:0] state;
    reg [7:0] k_cnt;          // Counter for k applications
    reg [9:0] current_n;      // Current value of n in the sequence
    reg [9:0] temp_n;         // Temporary register for phi calculation loop
    reg [9:0] phi_result;     // Computed phi value

    // Factorization Registers
    reg [4:0] prime_idx;      // Index for prime list (0-10 for 11 primes)
    reg [9:0] divisor;        // Current prime divisor
    reg [9:0] temp_val;       // Temporary value for reduction
    reg [9:0] temp_rem;       // Remainder
    reg [9:0] temp_quot;      // Quotient
    reg found_factor;         // Flag if factor found

    // Modulo Multiplication Registers
    reg [29:0] mult_a;        // First operand for modulo mult
    reg [29:0] mult_b;        // Second operand
    reg [29:0] mult_result;   // Result of (a * b) % MOD

    // Control Signals
    reg load_n;
    reg dec_k;
    reg calc_phi;
    reg update_phi;
    reg set_done;
    reg clear_done;

    // Prime LUT (Hardcoded for primes <= 31)
    wire [9:0] primes [0:10];
    assign primes[0] = 10'd2;
    assign primes[1] = 10'd3;
    assign primes[2] = 10'd5;
    assign primes[3] = 10'd7;
    assign primes[4] = 10'd11;
    assign primes[5] = 10'd13;
    assign primes[6] = 10'd17;
    assign primes[7] = 10'd19;
    assign primes[8] = 10'd23;
    assign primes[9] = 10'd29;
    assign primes[10] = 10'd31;

    // Combinational Logic for Factorization (Division) and Modulo Multiplication
    // 1. Division: temp_val / divisor -> temp_quot, temp_rem
    always @(*) begin
        if (divisor != 0) begin
            temp_quot = temp_val / divisor;
            temp_rem = temp_val % divisor;
        end else begin
            temp_quot = 0;
            temp_rem = 0;
        end
    end

    // 2. Modulo Multiplication: (mult_a * mult_b) % MOD
    // Since a, b < MOD (approx 1e9), product fits in 60 bits. 
    // Verilog simulators handle large integer math. Synthesis tools treat integer ops as C-like.
    always @(*) begin
        mult_result = (mult_a * mult_b) % MOD;
    end

    // Sequential Logic (State Machine)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            k_cnt <= 0;
            current_n <= 0;
            temp_n <= 0;
            phi_result <= 0;
            prime_idx <= 0;
            divisor <= 0;
            temp_val <= 0;
            found_factor <= 0;
            mult_a <= 0;
            mult_b <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        if (k == 0) begin // Optimization: if k=0, result is just n mod MOD
                            result <= n % MOD;
                            done <= 1;
                            state <= DONE;
                        end else begin
                            current_n <= n;
                            // Convert k to number of phi applications: (k+1)/2
                            // If k is odd (e.g., 1), k_cnt = 1. If k is even (e.g., 2), k_cnt = 1 (we handle 1 case, 2 cancels to 0?).
                            // Requirement: F_k(n) applies phi (k+1)//2 times.
                            // Wait, check logic: f(n)=phi, g(n)=n. F_k alternates f,g... starts with f.
                            // If k=1: F1 = f(n) = phi(n). 
                            // If k=2: F2 = g(phi(n)) = phi(n). 
                            // So odd k (1,3,5..) needs phi applications. Even k needs phi(k/2) if k/2 is odd?
                            // Actually: F_k applies phi (k+1)//2 times. 
                            // k=1 -> (2)//2 = 1. k=2 -> (3)//2 = 1. k=3 -> 4//2=2.
                            // Let's use (k + 1) >> 1. 
                            // Result is 0 if k=0, handled above.
                            k_cnt <= (k + 1) >> 1;
                            state <= CALCULATE_PHI;
                            temp_n <= n;
                            prime_idx <= 0;
                            result <= 1; // Initialize result for phi calculation
                        end
                    end else begin
                        state <= IDLE;
                    end
                end

                CALCULATE_PHI: begin
                    // We are computing phi(temp_n). 
                    // Result register 'result' accumulates phi value. Start with 1.
                    // We use a loop based on prime_idx.
                    if (temp_n == 0) begin
                        // Should not happen with n >= 1, but handle safety
                        state <= CHECK_COUNT;
                        phi_result <= 0;
                    end else if (temp_n == 1) begin
                        state <= CHECK_COUNT;
                        phi_result <= 1;
                    end else if (prime_idx < 11) begin
                        divisor <= primes[prime_idx];
                        state <= FACTOR_LOOP; // Wait for combinational division
                    end else begin
                        // Done with primes, check remaining temp_n
                        if (temp_n > 1) begin
                            // Remaining temp_n is a prime factor > 31 (up to 1000)
                            // result = result / temp_n * (temp_n - 1)
                            mult_a <= result;
                            mult_b <= (temp_n - 1);
                            state <= UPDATE_RESULT;
                            // We need to divide result by temp_n first? 
                            // The formula is: n * prod(1-1/p). 
                            // Let's do: result = result * (temp_n - 1) / temp_n.
                            // We need a division state for the remaining factor.
                            // However, division is combinational here if we put inputs.
                            // We need to divide 'result' by 'temp_n'. But 'result' is mod MOD, 'temp_n' is small.
                            // Since result < MOD, we can do integer division.
                            // But wait, 'result' is the accumulated product mod MOD.
                            // We can't simply divide mod MOD value.
                            // We need to perform the division before modulo reduction or handle it carefully.
                            // However, since temp_n is small (<=1000) and divides the pre-modulo product, 
                            // and since we are applying factors sequentially:
                            // result_new = (result_old * (p-1)) / p.
                            // We can't do this with modulo arithmetic directly because p might not divide result_old (due to previous mods).
                            // SOLUTION: Calculate phi FIRST without modulo reduction (since n <= 1000, phi(n) < n <= 1000), 
                            // then take result % MOD.
                            // So, change approach: phi_result is calculated on small integers (<=1000).
                            // Use 'phi_result' register for small math.
                            // Then at the end, assign result = phi_result % MOD.
                            // Let's switch to using 'temp_val' and 'phi_result' for the actual phi calculation.
                            // 'result' register will be used for the modulo result in CHECK_COUNT.
                            
                            // REVISION for CALCULATE_PHI state:
                            // Use 'phi_result' to accumulate phi value (small integer).
                            // Start: phi_result = 1 (or current_n if we multiply? Formula: n * prod(1-1/p)).
                            // Better: phi_result starts as current_n.
                            // For each prime p dividing n: phi_result = phi_result / p * (p-1).
                            // Finally, if temp_n > 1, phi_result = phi_result / temp_n * (temp_n-1).
                            
                            // Let's reset 'temp_val' to 'current_n' in IDLE or CALCULATE_PHI entry?
                            // We will do it inside CALCULATE_PHI logic.
                            
                            // Let's restart this state logic with specific registers for small math.
                            // I will use 'temp_val' as the accumulator for phi calc, init to current_n.
                            // I will use 'found_factor' to indicate if we need to update.
                            
                            // State CALCULATE_PHI logic revision:
                            // If entering from IDLE: temp_val <= current_n; phi_result <= current_n; prime_idx <= 0.
                            // If prime_idx < 11: divisor = primes[prime_idx].
                            // In FACTOR_LOOP: check if temp_val % divisor == 0.
                            // If yes: temp_val <= temp_val / divisor; temp_rem <= temp_val % divisor. (We need to wait cycle or combo? Combo is easier).
                            // Let's make FACTOR_LOOP a single cycle combo check.
                            // If (temp_val % divisor == 0) then we must update phi_result.
                            // Update: phi_result = phi_result / divisor * (divisor - 1).
                            // Since phi_result is small, we can do integer div/mul.
                            
                            // Let's redesign state flow for efficiency:
                            // CALCULATE_PHI: Check prime_idx. If < 11: Set divisor. Go to FACTOR_LOOP.
                            // FACTOR_LOOP: Check division. 
                            // If divisible: Update phi_result. Divide temp_val by divisor repeatedly? 
                            // To be safe, we should divide only once per state cycle to keep logic simple, or handle the full reduction in one cycle if possible.
                            // Given small size, let's try to do full reduction per prime in one cycle if state machine allows.
                            
                            // Let's use 'phi_result' as accumulator. 'temp_val' holds remaining n.
                            // In CALCULATE_PHI: 
                            // If prime_idx < 11: divisor = primes[prime_idx].
                            // Check if (temp_val % divisor == 0).
                            // If yes: 
                            //   phi_result = phi_result / divisor * (divisor - 1).
                            //   temp_val = temp_val / divisor.
                            //   Loop: If (temp_val % divisor == 0) repeat.
                            //   Wait, we need a loop inside. 
                            //   Let's have a sub-state REDUCE.
                            //   REDUCE: if (temp_val % divisor == 0), update phi_result, temp_val /= divisor, stay in REDUCE.
                            //   Else: prime_idx++, go back to CALCULATE_PHI.
                            //   If prime_idx reaches 11: Check remaining temp_val.
                            //   If temp_val > 1: phi_result = phi_result / temp_val * (temp_val - 1). temp_val = 1.
                            //   Then go to CHECK_COUNT.
                            //   
                            //   Wait, we need to update temp_val. 
                            //   Let's use 'temp_n' for remaining value, 'phi_result' for accumulating.
                            
                            // Refined Logic for CALCULATE_PHI state:
                            // It's actually better to do this iteratively.
                            // Let's use 'temp_n' as the remaining number to factorize.
                            // Let's use 'result' (or 'temp_val') to hold the current phi value (accumulator).
                            // Start: temp_n = current_n, accumulator = current_n.
                            // Loop over primes:
                            //   If (temp_n % prime == 0):
                            //     accumulator = accumulator / prime * (prime-1)
                            //     temp_n = temp_n / prime
                            //     repeat check with same prime
                            //   Next prime
                            // End loop. If temp_n > 1: accumulator = accumulator / temp_n * (temp_n - 1)
                            // Result = accumulator.
                            
                            // To implement this in hardware without nested loops (which are hard in single FSM):
                            // We can flatten the loop. 
                            // But given small k (max 100) and small primes (11), we can do it sequentially.
                            
                            // Let's implement a cleaner State Machine inside this always block.
                            // I will use 'temp_val' as the accumulator (starting at current_n).
                            // I will use 'temp_n' as the remainder (starting at current_n).
                            // Wait, I need two variables. 
                            // Let's use 'phi_result' as accumulator. Start at current_n.
                            // Let's use 'temp_rem' as the remaining number. Start at current_n.
                            // 'prime_idx' iterates.
                            // 'found_factor' acts as a loop counter for repeated prime factors.
                            
                            // Specific State Logic:
                            // State CALCULATE_PHI (main entry):
                            //   If (prime_idx == 0 && !found_factor) begin
                            //     phi_result <= current_n;
                            //     temp_rem <= current_n;
                            //   end
                            //   If (prime_idx < 11):
                            //     divisor <= primes[prime_idx];
                            //     // Check divisibility in FACTOR_LOOP sub-state
                            //     state <= FACTOR_LOOP;
                            //   end else begin
                            //     // Done with primes, check remainder
                            //     if (temp_rem > 1) begin
                            //       // phi_result = phi_result / temp_rem * (temp_rem - 1)
                            //       // We need a cycle to do this.
                            //       // Division: phi_result / temp_rem. 
                            //       // But phi_result < 1000, temp_rem < 1000. 
                            //       // We can compute it combo? Yes.
                            //       // But we need to handle the update.
                            //       // Let's do: 
                            //       // phi_result <= (phi_result / temp_rem) * (temp_rem - 1);
                            //       // state <= UPDATE_PHI_FINAL;
                            //       // Then next cycle -> CHECK_COUNT.
                            //       // But wait, if we do it combo, we need to register it.
                            //       // Let's just handle it in this state.
                            //       phi_result <= (phi_result / temp_rem) * (temp_rem - 1);
                            //       state <= CHECK_COUNT;
                            //     end else begin
                            //       state <= CHECK_COUNT;
                            //     end
                            //   end
                            // 
                            // State FACTOR_LOOP:
                            //   // Check if temp_rem is divisible by divisor
                            //   // Since we can't do combo assignment to registers in sequential block easily without combinational block, 
                            //   // I'll rely on the fact that we can compute division in combo logic.
                            //   // But wait, I can't access the result of the combinational division block inside this sequential block if it is declared after?
                            //   // Actually, Verilog allows it. 
                            //   // Let's assume 'temp_quot' and 'temp_rem' are computed from 'temp_rem' and 'divisor'.
                            //   // But 'temp_rem' updates over cycles. We need to feed current 'temp_rem' to the combo block.
                            //   // Let's define the inputs to the combo block dynamically or just use local variables.
                            //   // It's safer to just compute division inside the FSM using the standard "/" operator if the synthesis tool supports it for small numbers (it does).
                            //   
                            //   // Let's use a standard approach:
                            //   // Variable 't_div' = temp_rem / divisor
                            //   // Variable 't_rem' = temp_rem % divisor
                            //   // We can't declare these inside always block usually, but we can use a function or just write it out if we assume synthesis tool supports it (it usually does for constants).
                            //   // Actually, we can just use the combinational block we defined above.
                            //   // But the combinational block uses registers 'temp_val' and 'divisor'.
                            //   // Let's repurpose 'temp_val' for this specific division.
                            //   // We need to be careful with naming.
                            //   
                            //   // Let's go with the simplest reliable method for this constrained problem:
                            //   // Perform calculations in state CALCULATE_PHI using a loop-like structure.
                            //   // Since max 11 primes, we can unroll or use a counter.
                            //   // Let's use a helper counter 'prime_idx' (0 to 10).
                            //   // Use 'temp_n' as accumulator. Use 'current_n' as source?
                            //   // Let's keep 'temp_n' as the current value being reduced.
                            //   // Use 'phi_result' as the running phi value. 
                            //   // Actually, let's just compute phi(temp_n) using 'temp_n' and 'result' register.
                            //   // Wait, 'result' is 30 bits, 'temp_n' is 10 bits.
                            //   
                            //   // Let's rewrite the Factorization logic cleanly:
                            //   // State: CALCULATE_PHI
                            //   //   Action: 
                            //   //   1. Copy current_n to 'temp_rem'.
                            //   //   2. Copy current_n to 'phi_acc' (temp variable, or reuse 'result' register since it holds small number now).
                            //   //   3. Reset prime_idx.
                            //   //   4. Jump to sub-state FACTOR_LOOP.
                            //   
                            //   // State: FACTOR_LOOP
                            //   //   If (prime_idx < 11):
                            //   //     Let p = primes[prime_idx].
                            //   //     If (temp_rem % p == 0):
                            //   //        phi_acc = phi_acc / p * (p-1);
                            //   //        temp_rem = temp_rem / p;
                            //   //        // Need to repeat for same p? Yes.
                            //   //        // But we need to check divisibility again. 
                            //   //        // Since 'temp_rem' changes, we can stay in this state but check loop condition.
                            //   //        // However, we need to update 'temp_rem' and 'phi_acc'.
                            //   //        // We can do this in one cycle if we use a 'while' loop style in hardware? No.
                            //   //        // But we can check (temp_rem % p == 0) in the same cycle.
                            //   //        // If true, update and stay. If false, increment prime_idx.
                            //   //        // Wait, if we update 'temp_rem' and check 'temp_rem % p' again in the same cycle, it won't be updated yet.
                            //   //        // So we need a latch or we need to re-evaluate.
                            //   //        // Solution: Check divisibility. 
                            //   //        // If divisible: 
                            //   //        //   temp_rem_next = temp_rem / p
                            //   //        //   phi_acc_next = phi_acc / p * (p-1)
                            //   //        //   stay in FACTOR_LOOP (don't increment prime_idx)
                            //   //        // If not divisible:
                            //   //        //   prime_idx_next = prime_idx + 1
                            //   //        //   stay in FACTOR_LOOP (to check next prime)
                            //   //        // If prime_idx reaches 11: Go to CHECK_REMAINDER.
                            //   
                            //   // Let's define a helper register 'phi_acc' for the small accumulation.
                            //   // Actually, we can reuse 'result' register for phi_acc since we only need it at the end to convert to mod.
                            //   // But wait, 'result' is 30 bits. phi_acc < 1000. Safe.
                            //   // Let's use 'result' as phi_acc during calculation.
                            //   // Use 'temp_rem' register (rename 'temp_n') for the remainder.
                            //   // Use 'prime_idx' for iteration.
                            
                            //   // Re-defining Registers for Factorization:
                            //   // 'temp_n' holds the number being factored.
                            //   // 'result' holds the accumulated phi value.
                            //   // 'prime_idx' holds index.
                            //   // 'state' holds state.
                            
                            //   // Logic for CALCULATE_PHI:
                            //   // If entering from IDLE:
                            //   //   temp_n <= current_n;
                            //   //   result <= current_n; // phi(n) = n * prod(1-1/p)
                            //   //   prime_idx <= 0;
                            //   //   state <= FACTOR_LOOP;
                            //   //   // Note: We need to handle the case where we are already in FACTOR_LOOP logic.
                            //   //   // Actually, let's just handle it in a single state.
                            
                            //   // Let's just use one state for factorization: FACTORIZE.
                            //   // State FACTORIZE:
                            //   //   If (prime_idx < 11):
                            //   //     divisor = primes[prime_idx];
                            //   //     If (temp_n % divisor == 0):
                            //   //       result <= result / divisor * (divisor - 1);
                            //   //       temp_n <= temp_n / divisor;
                            //   //       // Don't increment prime_idx, repeat check.
                            //   //     Else:
                            //   //       prime_idx <= prime_idx + 1;
                            //   //   Else:
                            //   //     If (temp_n > 1):
                            //   //       result <= result / temp_n * (temp_n - 1);
                            //   //       temp_n <= 1;
                            //   //       // Then go to CHECK_COUNT.
                            //   //     Else:
                            //   //       go to CHECK_COUNT.
                            //   
                            //   // Wait, the division and multiplication here are on small integers (<=1000).
                            //   // Verilog integer division is synthesizable for small values.
                            //   // However, I cannot assign to 'result' in the same cycle I read it if I rely on the updated value for next cycle. 
                            //   // But here I am reading 'result' to update it. That's fine.
                            //   
                            //   // Problem: 'temp_n % divisor' needs to be computed. We can just use the / % operator.
                            //   // But we need to ensure we don't overwrite temp_n before checking.
                            //   // Since it's sequential, we read current values and write next values.
                            //   // 
                            //   // Let's refine the state machine to include a 'CALCULATE_PHI' state that does the work.
                            //   // Since factorization takes variable cycles, we need a loop.
                            //   // We'll use 'state' to be the main state, and use 'prime_idx' to control the loop.
                            
                            //   // Let's go back to the initial simpler idea:
                            //   // Precompute phi in a LUT if possible? 
                            //   // n <= 1000. A LUT of 1000 entries is 10x1000 = 10k bits. Very small for FPGA/ASIC.
                            //   // But requirement says "Use a small LUT or combinational logic".
                            //   // "Use factorization by checking division by primes".
                            //   // So I must implement the division logic.
                            
                            //   // Let's implement the factorization loop properly.
                            //   // We need a state to do the division and multiplication.
                            //   // I will use a combinational block to compute the division results for the current cycle.
                            //   // Let's name registers clearly:
                            //   // 'temp_n': the number we are factoring.
                            //   // 'phi_acc': the accumulator for phi.
                            //   // 'p_idx': index for primes.
                            //   // 'state': FSM state.
                            
                            //   // States:
                            //   // IDLE: Wait for start.
                            //   // SETUP_PHI: temp_n = current_n, phi_acc = current_n, p_idx = 0. -> Next state LOOP_CHECK.
                            //   // LOOP_CHECK: If p_idx < 11. If (temp_n % primes[p_idx] == 0) -> REDUCE.
                            //   //             Else -> NEXT_PRIME.
                            //   // REDUCE: temp_n = temp_n / prime, phi_acc = phi_acc / prime * (prime-1).
                            //   //          -> LOOP_CHECK (Re-evaluate same prime). 
                            //   // NEXT_PRIME: p_idx = p_idx + 1. -> LOOP_CHECK.
                            //   // FINAL_CHECK: If temp_n > 1. phi_acc = phi_acc / temp_n * (temp_n - 1). -> UPDATE_RESULT.
                            //   // UPDATE_RESULT: result = phi_acc % MOD. -> CHECK_COUNT.
                            //   
                            //   // This requires many states. 
                            //   // To save states, we can merge SETUP and logic.
                            
                            //   // Let's try a compact state machine inside the always block.
                            //   // I will use 'state' to hold the primary state (IDLE, CALCULATE_PHI, CHECK_COUNT, DONE).
                            //   // And use 'prime_idx' as a counter.
                            //   // And use 'temp_n' as the remainder.
                            //   // And use 'result' as the accumulator (temporarily).
                            
                            //   // Revised 'CALCULATE_PHI' logic:
                            //   // It will be a loop that takes multiple cycles.
                            //   // To ensure termination and progress, we need to structure it carefully.
                            
                            //   // Let's use the following structure:
                            //   // State = IDLE: 
                            //   //   if start: load n to temp_n, load n to result (phi acc), prime_idx=0. State = FACTOR_LOOP.
                            //   // State = FACTOR_LOOP:
                            //   //   if prime_idx < 11:
                            //   //     divisor = primes[prime_idx]
                            //   //     if temp_n % divisor == 0:
                            //   //       result = result / divisor * (divisor-1)
                            //   //       temp_n = temp_n / divisor
                            //   //       // Stay in FACTOR_LOOP (do not inc prime_idx)
                            //   //     else:
                            //   //       prime_idx = prime_idx + 1
                            //   //   else:
                            //   //     if temp_n > 1:
                            //   //       result = result / temp_n * (temp_n-1)
                            //   //       temp_n = 1
                            //   //       // Stay in FACTOR_LOOP? No, we are done. Go to CHECK_COUNT.
                            //   //       // But we need to update result. 
                            //   //       // Actually, if we update result and temp_n=1, next cycle prime_idx < 11 fails, temp_n > 1 fails.
                            //   //       // So we can go to CHECK_COUNT. 
                            //   //       // Let's add a check.
                            //   //       // If prime_idx < 11: stay. Else: state = CHECK_COUNT.
                            
                            //   // Wait, if temp_n > 1, we update result and set temp_n=1. 
                            //   // Next cycle prime_idx >= 11 and temp_n = 1, so we go to CHECK_COUNT.
                            //   // So we can just stay in FACTOR_LOOP.
                            //   // But we need to distinguish the "finalize" step.
                            //   // Let's add a flag or just handle it with conditions.
                            
                            //   // Actually, the loop logic:
                            //   // 1. Prime_idx < 11: Check div.
                            //   // 2. Prime_idx >= 11: Check rem.
                            //   // We can do this in one state.
                            
                            //   // Let's implement this logic. 
                            //   // I will use 'result' to hold the phi accumulator.
                            //   // I will use 'temp_n' to hold the remaining number.
                            //   // I will use 'prime_idx' to track the prime.
                            //   // I will use a helper register 'calc_phi_state' inside this block if needed, or just use the main state.
                            
                            //   // Let's stick to the main state machine with sub-logic.
                            //   // I'll add a "FACTORING" state.
                            //   
                            //   // Let's go with the clean implementation:
                            //   // State IDLE: 
                            //   //   if start: 
                            //   //     if k==0: result=n%MOD, done=1
                            //   //     else: current_n=n, k_cnt=(k+1)/2, temp_n=n, result=n, prime_idx=0, state=FACTORING
                            //   // State FACTORING:
                            //   //   if (prime_idx < 11): 
                            //   //     divisor = primes[prime_idx]
                            //   //     if (temp_n % divisor == 0):
                            //   //       result <= (result / divisor) * (divisor - 1);
                            //   //       temp_n <= temp_n / divisor;
                            //   //     else:
                            //   //       prime_idx <= prime_idx + 1;
                            //   //   else if (temp_n > 1):
                            //   //     result <= (result / temp_n) * (temp_n - 1);
                            //   //     temp_n <= 1;
                            //   //   else:
                            //   //     // Factorization complete
                            //   //     // But 'result' is small integer. We need to handle the modulo 1e9+7.
                            //   //     // So, convert result to modulo result.
                            //   //     // result <= result % MOD; 
                            //   //     // Then state <= CHECK_COUNT;
                            //   //     // Wait, we need to handle the modulo. 
                            //   //     // Since result is small, result % MOD is just result.
                            //   //     // But we should be explicit.
                            //   //     // However, we might have overflow if we just assign.
                            //   //     // Let's assign: result <= result % MOD; (result is currently small).
                            //   //     // Then state <= CHECK_COUNT.
                            //   //     // Note: temp_n > 1 check happens. If temp_n == 1, we go here.
                            //   //     // But if we just finished the last update (temp_n became 1), we might skip the next cycle.
                            //   //     // Actually, if temp_n becomes 1, next cycle prime_idx >= 11 and temp_n > 1 is false.
                            //   //     // So we enter the else block. 
                            //   //     // So we are safe.
                            //   //     // Wait, if temp_n > 1, we update result and set temp_n=1. Next cycle, prime_idx >= 11, temp_n > 1 is false.
                            //   //     // We enter this else block. 
                            //   //     // So we need to make sure we don't overwrite result if we just updated it.
                            //   //     // But we are in the same state. 
                            //   //     // If temp_n > 1, we update and stay. If temp_n == 1 (or becomes 1), we fall through to else.
                            //   //     // Actually, if temp_n > 1, we update it to 1. Next cycle we check condition.
                            //   //     // So yes, we need the 'else' block to transition.
                            //   //     // However, we need to handle the case where 'temp_n' is 1 initially? No, n >= 1.
                            //   //     // If n=1, phi(1)=1. Logic: prime_idx < 11. temp_n % prime != 0. prime_idx increases.
                            //   //     // eventually prime_idx >= 11. temp_n > 1? No, temp_n=1. Go to else. state <= CHECK_COUNT.
                            //   //     // Wait, result is 1 (init). 
                            //   //     // So, it works.
                            //   //     
                            //   //     // But we need to set result to modulo value here.
                            //   //     // result <= result % MOD; // result is small, so this is valid.
                            //   //     // state <= CHECK_COUNT;
                            //   //     // However, if result was updated in the 'if (temp_n > 1)' block, it might be one cycle too late?
                            //   //     // No, if temp_n > 1, we update result and temp_n. We stay in state.
                            //   //     // Next cycle, temp_n == 1. We don't enter 'if (temp_n > 1)'. We enter 'else'.
                            //   //     // So the updated result is used.
                            //   //     // So we can do:
                            //   //     // result <= result % MOD; // Use modulo operator to be safe (though result < MOD)
                            //   //     // state <= CHECK_COUNT;
                            //   // 
                            //   // Wait, there is a catch. If prime_idx < 11 and temp_n % divisor != 0, we increment prime_idx.
                            //   // We stay in state FACTORING. Correct.
                            //   // 
                            //   // What about the modulo operator? It's synthesizable.
                            //   // 
                            //   // Let's refine the conditions for the last step.
                            //   // We need to make sure we don't exit prematurely.
                            //   // 
                            //   // Let's define the State Transition for FACTORING:
                            //   //   if (prime_idx < 11):
                            //   //     // Check divisor
                            //   //     // If divisible: update result, temp_n. Stay.
                            //   //     // If not: prime_idx++. Stay.
                            //   //   else:
                            //   //     // Check remaining temp_n
                            //   //     if (temp_n > 1):
                            //   //       // Update result.
                            //   //       // temp_n = 1.
                            //   //       // Stay.
                            //   //     else:
                            //   //       // Done. Convert to modulo.
                            //   //       // Note: result is small. 
                            //   //       // result <= result % MOD; 
                            //   //       // state <= CHECK_COUNT;
                            //   // 
                            //   // This logic seems correct.
                            //   // 
                            //   // However, we need to be careful with division by zero? No, primes are >= 2.
                            //   // temp_n will be 0 only if we mess up. n >= 1.
                            //   // 
                            //   // Let's implement this.
                            //   // We need to compute temp_n % divisor and temp_n / divisor.
                            //   // In Verilog, we can do this inside the always block.
                            //   // But standard synthesis tools support integer arithmetic.
                            //   // However, for formal correctness and to avoid implicit nets, we should declare helper variables if needed.
                            //   // But since we are assigning to registers directly, we can use:
                            //   // temp_n <= temp_n / divisor;
                            //   // This requires divisor to be non-zero.
                            //   // 
                            //   // Let's write the code for this state.
                            //   
                            //   // Wait, I need to handle the "modulo 1e9+7" part.
                            //   // Result is 30 bits. 
                            //   // The logic above calculates phi(n) as a small integer. 
                            //   // Once phi(n) is calculated (small integer), we need to feed it into the next iteration if k > 1.
                            //   // But the result needs to be modulo 1e9+7.
                            //   // The problem is: phi(n) might be large if n was large. But n <= 1000.
                            //   // So phi(n) <= 1000.
                            //   // So we can just store it as an integer.
                            //   // Then, for the next iteration, we use this integer as input.
                            //   // But wait, the input 'n' is 10 bits. 
                            //   // If we apply phi, we get a small number. 
                            //   // However, the result needs to be modulo 1e9+7.
                            //   // The sequence F_k(n) is composed of integers. 
                            //   // But the requirement says "computes F_k(n) modulo 1000000007".
                            //   // Does that mean: ((phi(phi(...n))) mod 1e9+7)?
                            //   // Or (phi(phi(...n))) mod 1e9+7 at the end?
                            //   // Usually, modular arithmetic can be applied at each step if the operation is linear.
                            //   // phi(n) is NOT linear mod m. 
                            //   // So we cannot simply do phi(n) % MOD, then apply phi again.
                            //   // Wait. n <= 1000. 
                            //   // phi(1000) = 400. 
                            //   // phi(400) = 160.
                            //   // The numbers drop very fast. 
                            //   // Actually, phi(n) <= n. 
                            //   // For n <= 1000, phi(n) <= 1000.
                            //   // So the numbers stay small (<= 1000) throughout the process.
                            //   // Wait, is that true?
                            //   // n <= 1000. 
                            //   // First application: phi(n) <= 1000.
                            //   // Second application: phi(phi(n)) <= phi(n) <= 1000.
                            //   // Yes! The sequence of values is non-increasing and stays <= 1000.
                            //   // EXCEPT if we take modulo 1e9+7.
                            //   // If we take (phi(n) % MOD), it is still phi(n) because phi(n) < MOD.
                            //   // So, the values remain small.
                            //   // So we don't need to worry about overflow during the phi chain.
                            //   // However, the problem asks for modulo 1e9+7. 
                            //   // This is likely for the final result, or to handle general cases if n was large.
                            //   // Since we are constrained to n <= 1000, the intermediate values stay small.
                            //   // BUT, the final result is just the final value (which is small).
                            //   // So, do we need to do modulo operations at all?
                            //   // Result output is [29:0]. 
                            //   // If we don't use modulo, result fits in 10 bits.
                            //   // The requirement "modulo 1000000007" suggests we should use it.
                            //   // But if the value is small, `result <= result` is sufficient.
                            //   // However, to be compliant with the "modulo 1000000007" spec, we should output `result % MOD`.
                            //   // Since result < 1000, `result % MOD` is just `result`.
                            //   // 
                            //   // So the plan:
                            //   // 1. Register `current_val` (initially n).
                            //   // 2. Loop `k_cnt` times:
                            //   //    a. Compute `next_val` = phi(current_val).
                            //   //    b. `current_val` = `next_val`.
                            //   // 3. Result = `current_val` % MOD.
                            //   // 
                            //   // We need to implement the `phi` computation.
                            //   // Since `current_val` is small, we can do it in one cycle or a few cycles.
                            //   // Let's try to do the phi computation in a single state `CALCULATE_PHI`.
                            //   // Since n <= 1000, we can iterate through primes 2 to 31.
                            //   // We can unroll the loop or use a small counter.
                            //   // 
                            //   // Let's try a single-cycle calculation using combinational logic if possible, but using sequential logic is safer and easier to write.
                            //   // 
                            //   // Let's use the following sub-machine inside `CALCULATE_PHI` state:
                            //   // 
                            //   // We will use `temp_n` to hold the current value being reduced.
                            //   // We will use `result` register to accumulate phi.
                            //   // Wait, `result` is the output. Let's use `phi_acc` register.
                            //   // 
                            //   // Registers needed for phi calculation:
                            //   // `val` : current value (starts at current_val)
                            //   // `phi` : accumulator (starts at current_val)
                            //   // `p_idx` : index 0-10.
                            //   // 
                            //   // State CALCULATE_PHI:
                            //   //   If (p_idx < 11):
                            //   //     p = primes[p_idx]
                            //   //     If (val % p == 0):
                            //   //       phi = phi / p * (p - 1)
                            //   //       val = val / p
                            //   //       // Stay in state, don't increment p_idx
                            //   //     Else:
                            //   //       p_idx = p_idx + 1
                            //   //   Else:
                            //   //     If (val > 1):
                            //   //       // val is a prime factor > 31
                            //   //       phi = phi / val * (val - 1)
                            //   //       val = 1
                            //   //       // Stay in state? If val=1, next cycle we go to else. 
                            //   //       // Actually, if we update val to 1, next cycle val > 1 is false.
                            //   //       // We fall through.
                            //   //     Else:
                            //   //       // Calculation done. phi holds the result.
                            //   //       // Move to next state (CHECK_COUNT). 
                            //   //       // Update current_val = phi.
                            //   //       // current_val <= phi.
                            //   //       // state <= CHECK_COUNT.
                            //   // 
                            //   // This requires a few registers. We have them.
                            //   // We need to be careful about variable names to avoid confusion with output `result`.
                            //   // Let's use `temp_phi_acc` for phi accumulator.
                            //   // Let's use `temp_reduce_val` for the number being reduced.
                            //   // Let's use `prime_idx` for the prime index.
                            //   // 
                            //   // Let's map this to the state machine.
                            //   // 
                            //   // State IDLE:
                            //   //   if start:
                            //   //     current_val <= n;
                            //   //     if k==0: result <= n%MOD, done<=1
                            //   //     else: k_cnt <= (k+1)/2, state <= SETUP_PHI.
                            //   // 
                            //   // State SETUP_PHI: (one cycle setup)
                            //   //   temp_reduce_val <= current_val;
                            //   //   temp_phi_acc <= current_val;
                            //   //   prime_idx <= 0;
                            //   //   state <= CALCULATE_PHI;
                            //   // 
                            //   // State CALCULATE_PHI:
                            //   //   If (prime_idx < 11):
                            //   //     If (temp_reduce_val % primes[prime_idx] == 0):
                            //   //       temp_phi_acc <= (temp_phi_acc / primes[prime_idx]) * (primes[prime_idx] - 1);
                            //   //       temp_reduce_val <= temp_reduce_val / primes[prime_idx];
                            //   //     Else:
                            //   //       prime_idx <= prime_idx + 1;
                            //   //   Else If (temp_reduce_val > 1):
                            //   //     temp_phi_acc <= (temp_phi_acc / temp_reduce_val) * (temp_reduce_val - 1);
                            //   //     temp_reduce_val <= 1;
                            //   //   Else:
                            //   //     // Done
                            //   //     current_val <= temp_phi_acc;
                            //   //     state <= CHECK_COUNT;
                            //   // 
                            //   // State CHECK_COUNT:
                            //   //   if (k_cnt > 0 && current_val != 1):
                            //   //     k_cnt <= k_cnt - 1;
                            //   //     state <= SETUP_PHI;
                            //   //   else:
                            //   //     result <= current_val % MOD;
                            //   //     state <= DONE;
                            //   //     done <= 1;
                            //   // 
                            //   // This looks solid.
                            //   // 
                            //   // Note on division: In synthesis, integer division is expensive but for small constants (primes) and small values (<=1000), it is usually fine or mapped to logic.
                            //   // 
                            //   // Let's refine the logic for the `temp_reduce_val > 1` part.
                            //   // If `temp_reduce_val` becomes 1 after update, we are done.
                            //   // Next cycle `prime_idx` is still >= 11, `temp_reduce_val` is 1.
                            //   // We fall into the `Else` block. Good.
                            //   // 
                            //   // Wait, if `temp_reduce_val` is 1 initially (n=1):
                            //   // prime_idx < 11 check. `temp_reduce_val % prime` is 0? No (1%2=1). 
                            //   // prime_idx increments. Eventually prime_idx = 11.
                            //   // `temp_reduce_val > 1` is false. Go to Else.
                            //   // `current_val` is set to `temp_phi_acc` (which was initialized to 1). Correct.
                            //   // 
                            //   // Looks good.
                            //   
                            //   // Implementation details:
                            //   // We need `current_val` register to hold the value across iterations.
                            //   // We need `temp_reduce_val` and `temp_phi_acc` for the calculation.
                            //   // 
                            //   // Let's write the code.

                            //   // Wait, `k` is a 8-bit input. `k_cnt` is 8-bit. Max 100. 
                            //   // `(k+1)/2` max is 50. Fits.
                            //   // 
                            //   // Let's verify the logic for `current_val != 1` in CHECK_COUNT.
                            //   // If current_val is 1, we stop early. This matches the math (phi(1)=1). 
                            //   // 
                            //   // Let's code this.
                            //   // 
                            //   // One detail: `temp_phi_acc / primes[prime_idx]`.
                            //   // `temp_phi_acc` is initially `current_val`. 
                            //   // `current_val` is <= 1000. 
                            //   // So `temp_phi_acc` <= 1000.
                            //   // Division is safe.
                            //   // 
                            //   // Let's proceed with the coding.

                            //   // Actually, we need to declare `primes` array.
                            //   // `primes` array is already declared as wires. We can use it.
                            //   // 
                            //   // Let's handle the state transitions.

                            //   // One optimization: We can merge `SETUP_PHI` into `CALCULATE_PHI` if we use a flag, but `SETUP` is cleaner.

                            //   // Let's verify the `k` calculation.
                            //   // F_k(n) = f(g(f(g(... n)))).
                            //   // k=1: F1 = f(n) = phi(n). (1 application)
                            //   // k=2: F2 = g(phi(n)) = phi(n). (1 application)
                            //   // k=3: F3 = f(phi(n)) = phi(phi(n)). (2 applications)
                            //   // k=4: F4 = g(phi(phi(n))) = phi(phi(n)). (2 applications)
                            //   // Formula: `(k + 1) / 2`. 
                            //   // Integer division (truncation): `(k + 1) >> 1`.
                            //   // k=1 -> 1. k=2 -> 1. k=3 -> 2. Correct.
                            //   // 
                            //   // What if k=0?
                            //   // F_0(n) = n.
                            //   // (0+1)/2 = 0. 0 applications. Result = n.
                            //   // So `k_cnt` = 0. Check: `k_cnt > 0` is false. Goes to DONE. Result = current_val = n. Correct.
                            //   // 
                            //   // So we can handle k=0 in the same flow as k>0.
                            //   // In IDLE: if start, we load n to current_val, set k_cnt = (k+1)/2.
                            //   // Then we go to `SETUP_PHI`? No.
                            //   // If `k_cnt` is 0, `SETUP_PHI` is unnecessary.
                            //   // But `SETUP_PHI` sets registers and goes to `CALCULATE_PHI`.
                            //   // `CALCULATE_PHI` eventually goes to `CHECK_COUNT`.
                            //   // `CHECK_COUNT` sees `k_cnt=0`, goes to DONE.
                            //   // So it's okay to go through the states.
                            //   // However, `SETUP_PHI` initializes `temp_reduce_val` to `current_val`. 
                            //   // If `current_val` is n, fine.
                            //   // `CALCULATE_PHI` computes phi(n) even though we don't need it.
                            //   // It's better to optimize.
                            //   // But wait, if we optimize, we might need an extra state or complex logic.
                            //   // Let's just handle k=0 in IDLE.

                            //   // Let's go with the code.

                            //   // Wait, I missed the requirement: "Repeat. If k > 0 and current != 1, repeat. If k==0 or current==1, go to DONE."
                            //   // This matches my logic.

                            //   // Final check on the modulo part:
                            //   // "Result is the final value of current."
                            //   // "computes F_k(n) modulo 1000000007"
                            //   // So `result = current % MOD`.
                            //   // Since current is small, this is fine.

                            //   // I will use `localparam` for states.

                            //   // Code structure:
                            //   // module eurus_solver(...)
                            //   //   // Inputs/Outputs
                            //   //   // Parameters
                            //   //   // Localparams for states
                            //   //   // Registers (current_val, k_cnt, temp_reduce_val, temp_phi_acc, prime_idx, state, done)
                            //   //   // Wire for primes
                            //   //   // Combinational logic for division? No, we'll use integer division in sequential block.
                            //   //   // Wait, I should use combinational logic for division if I want to do it in one cycle.
                            //   //   // But Verilog synthesis supports integer division in sequential blocks (it infers logic).
                            //   //   // However, it might be slow. But n is small.
                            //   //   // Let's try to do it directly.

                            //   //   // Actually, I can define a combinational block for the divisions if needed, but let's just write it in the sequential block. 
                            //   //   // Modern tools handle `a / b` where `b` is constant or small well.

                            //   //   // Let's write the code carefully.

                            //   //   // I need to define the primes array.
                            //   //   // `wire [9:0] primes [0:10];` is fine.

                            //   //   // Let's write the always block.

                            //   //   // Note: `k` input is [7:0]. `k_cnt` can be [7:0].
                            //   //   // `current_val` needs to handle n (10 bits) and phi (<= n). So [9:0] is enough.
                            //   //   // `temp_reduce_val` and `temp_phi_acc` also [9:0].

                            //   //   // `prime_idx` needs to go up to 10, so [4:0] is enough.

                            //   //   // `result` is [29:0].

                            //   //   // Let's write the JSON.

                            //   //   // Wait, I need to make sure I don't have any syntax errors.
                            //   //   // `temp_phi_acc / primes[prime_idx] * (primes[prime_idx] - 1)`
                            //   //   // The multiplication happens after division. Order of operations matters? 
                            //   //   // In Verilog, `*` and `/` have same precedence, left-to-right.
                            //   //   // So `a / b * c` is `(a/b)*c`. Correct.

                            //   //   // What about `temp_phi_acc / temp_reduce_val * (temp_reduce_val - 1)`?
                            //   //   // If temp_reduce_val is updated in the same cycle? No, sequential read uses OLD value.
                            //   //   // So inside the always block, `temp_reduce_val` is the value from the previous cycle.
                            //   //   // If I want to update `temp_reduce_val` and use it to update `temp_phi_acc` in the same cycle, I can't read the new value.
                            //   //   // But I use the OLD `temp_reduce_val` to compute new `temp_phi_acc`. 
                            //   //   // Then I update `temp_reduce_val` to `temp_reduce_val / primes[prime_idx]`.
                            //   //   // This is the correct sequential behavior.

                            //   //   // However, `temp_reduce_val` is used as a divisor. 
                            //   //   // In the state `CALCULATE_PHI`, if `prime_idx < 11` and `temp_reduce_val % primes[prime_idx] == 0`:
                            //   //   // `temp_phi_acc` updates using `temp_reduce_val` (the old one).
                            //   //   // Wait, the formula is `result / p * (p-1)`. It uses `p`, not `temp_reduce_val`.
                            //   //   // So `temp_phi_acc = (temp_phi_acc / primes[prime_idx]) * (primes[prime_idx] - 1)`. Correct.
                            //   //   // `temp_reduce_val = temp_reduce_val / primes[prime_idx]`. Correct.

                            //   //   // In the `else if (temp_reduce_val > 1)` block:
                            //   //   // `temp_phi_acc = (temp_phi_acc / temp_reduce_val) * (temp_reduce_val - 1)`. 
                            //   //   // Here `temp_reduce_val` is the OLD value. Correct.
                            //   //   // `temp_reduce_val = 1`. Correct.

                            //   //   // So the logic is correct.

                            //   //   // Let's write the code.

                            //   //   // One detail: The requirement says "Latency: ... 100 clock cycles max".
                            //   //   // With k=100, k_cnt=50. 
                            //   //   // Each phi calc takes max (11 primes + 1 extra check) = ~12 cycles + some for loops.
                            //   //   // Actually, max cycles per phi: 
                            //   //   // Worst case n=2^X * 3^Y ... etc. 
                            //   //   // But n <= 1000. 
                            //   //   // The loop for repeated factors can be long. 
                            //   //   // But 2^9 = 512. 2^10 = 1024 (out of range). 
                            //   //   // So max exponent is 9 for 2, 6 for 3, etc. 
                            //   //   // Total cycles for one phi: <= (11 primes + max total exponent). 
                            //   //   // Max exponent sum is small. 
                            //   //   // So < 50 cycles per phi. 
                            //   //   // Total < 50 * 50 = 2500 cycles. 
                            //   //   // Wait, the requirement says "100 clock cycles max".
                            //   //   // This is very tight for k=100 (50 iterations).
                            //   //   // 100 cycles / 50 iterations = 2 cycles per iteration. 
                            //   //   // We cannot do factorization in 2 cycles using a generic algorithm.
                            //   //   // UNLESS we use a LUT.
                            //   //   // "Use a small Lookup Table (LUT) or combinational logic to compute phi(n) for n <= 1000."
                            //   //   // "A simple way is to precompute values".
                            //   //   // If we use a LUT (1024 entries x 10 bits), we can compute phi(n) in 1 cycle (or 2 with pipelining).
                            //   //   // This fits the 100 cycle limit.
                            //   //   // The requirement also says "factorization can be done by checking division by primes".
                            //   //   // It seems to suggest a method. 
                            //   //   // But the latency requirement suggests LUT is necessary for k=100.
                            //   //   // However, the prompt says "scaled down to n <= 1000 and k <= 100".
                            //   //   // "Latency: ... 100 clock cycles max (e.g., 100 clock cycles max)."
                            //   //   // If k=100, and we do 50 iterations, we have 2 cycles/iter.
                            //   //   // Factorization takes more than 2 cycles. 
                            //   //   // So we MUST use a LUT to be efficient and meet latency.
                            //   //   // Or, the "100 cycles" is a loose bound for typical cases? 
                            //   //   // No, "e.g. 100 clock cycles max" sounds like a requirement.

                            //   //   // Let's use a LUT for phi(n).
                            //   //   // The requirement says "Use a small LUT or combinational logic".
                            //   //   // And then it details the factorization method.
                            //   //   // This is contradictory if we need 100 cycles for k=100.
                            //   //   // Maybe the "100 cycles max" is for the *total* execution, but if we use the loop method, we might exceed it.
                            //   //   // Or maybe k is small in the test cases?
                            //   //   // BUT, I should optimize for the worst case.
                            //   //   // Given the tight cycle budget, a LUT is the only way to guarantee <100 cycles for k=100.

                            //   //   // However, implementing a 1024-entry LUT in code is verbose but possible.
                            //   //   // `reg [9:0] phi_lut [0:1023];`
                            //   //   // `initial $readmemh(...)` is not synthesizable for standard ASIC unless we use ROM inference.
                            //   //   // We can use a `case` statement or `if-else` to create the LUT, but that's huge code.
                            //   //   // Or we can use a combinational block that computes phi(n) in 1 cycle using logic.
                            //   //   // Wait, if we use combinational logic to compute phi(n) in 1 cycle, we can do it in 1 cycle.
                            //   //   // Then k=50 iterations takes ~50 cycles. 
                            //   //   // Plus overhead. Fits in 100 cycles.

                            //   //   // So, let's change the plan:
                            //   //   // Create a combinational block `phi_func(n)` that computes phi(n) for n <= 1000.
                            //   //   // This block can use the factorization logic but combinational.
                            //   //   // Then, in the state machine, we can just do:
                            //   //   // `current_val <= phi_func(current_val);`
                            //   //   // This takes 1 cycle.

                            //   //   // Let's implement `phi_func` using the factorization logic but fully combinational.
                            //   //   // This is efficient and meets the latency requirement.

                            //   //   // Revised Plan:
                            //   //   // 1. Define `phi_func` combinational logic.
                            //   //      Input: `n` (10 bits).
                            //   //      Output: `phi_val` (10 bits).
                            //   //      Logic: 
                            //   //        temp_n = n; phi = n;
                            //   //        for p in primes: 
                            //   //          if temp_n % p == 0: 
                            //   //            phi = phi/p * (p-1); 
                            //   //            temp_n /= p; 
                            //   //            loop while temp_n % p == 0: temp_n /= p; (phi formula doesn't change for repeated factors, only temp_n changes)
                            //   //        if temp_n > 1: phi = phi / temp_n * (temp_n-1).
                            //   //      This can be done with a loop or unrolled.
                            //   //      Since it's combinational, we can use a `for` loop (synthesizable if unrolled or limited iterations).
                            //   //      Or we can write it as a cascade of if-else.

                            //   //   2. State Machine:
                            //   //      IDLE: if start: current_val <= n; k_cnt <= (k+1)/2; state <= CALCULATE (or CHECK).
                            //   //      CHECK: if (k_cnt > 0 && current_val != 1): k_cnt--; state <= CALCULATE. Else: state <= DONE.
                            //   //      CALCULATE: current_val <= phi_func(current_val); state <= CHECK.
                            //   //      DONE: done=1.

                            //   //   This is very clean and efficient.

                            //   //   Let's implement `phi_func`.
                            //   //   We need to be careful with the `for` loop. 
                            //   //   "Verilog synthesis `for` loop".
                            //   //   If we write:
                            //   //   always @(*) begin
                            //   //     phi_val = n;
                            //   //     temp = n;
                            //   //     for (i=0; i<11; i=i+1) begin
                            //   //       if (temp % primes[i] == 0) ...
                            //   //     end
                            //   //   end
                            //   //   This unrolls into logic. 
                            //   //   We need to handle the "divide by p until not divisible" part.
                            //   //   We can use a while loop, but synthesizable `while` loops are rare.
                            //   //   We can unroll this too. 
                            //   //   Since max exponent is small (2^9, 3^6, etc), we can repeat the check.
                            //   //   But that's a lot of code.

                            //   //   Alternative: 
                            //   //   We can use a helper variable inside the combinational block.
                            //   //   But Verilog `always @(*)` loops are usually unrolled by the synthesis tool if the loop count is static.
                            //   //   However, the inner loop (while divisible) is tricky.

                            //   //   Let's try to write the combinational logic for phi without nested loops.
                            //   //   We can use a structure similar to the sequential version but combinational.
                            //   //   Since n <= 1000, we can just write it out fully or use a finite state machine for the combinational logic? No, that's a sequential FSM.

                            //   //   Let's use the fact that we have small limits.
                            //   //   Let's write a combinational block that does:
                            //   //   `phi_out = n;`
                            //   //   `rem = n;`
                            //   //   // Iterate primes
                            //   //   // But we can't iterate in combinational block easily with `while`.

                            //   //   Let's use a sequential approach for the phi calculation, but inside the main state machine.
                            //   //   But we need 1 cycle latency.

                            //   //   Okay, let's look at the instruction again: "Latency: ... 100 clock cycles max".
                            //   //   And "k <= 100".
                            //   //   If I use the sequential factorization (multiple cycles), I might violate the latency.
                            //   //   If I use a LUT, I meet it.
                            //   //   If I use combinational factorization, I meet it.

                            //   //   Let's try to implement a fast combinational phi.
                            //   //   We can use `function`.
                            //   //   `function [9:0] phi(input [9:0] n);` 
                            //   //   Inside function, we can use loops if they are static.

                            //   //   Let's use a function.

                            //   //   `function [9:0] compute_phi;
                            //   //     input [9:0] val;
                            //   //     integer i;
                            //   //     reg [9:0] t;
                            //   //     reg [9:0] p;
                            //   //   begin
                            //   //     compute_phi = val;
                            //   //     t = val;
                            //   //     for (i=0; i<11; i=i+1) begin
                            //   //       p = primes[i];
                            //   //       if (t % p == 0) begin
                            //   //         compute_phi = compute_phi / p * (p - 1);
                            //   //         t = t / p;
                            //   //         while (t % p == 0) t = t / p;
                            //   //       end
                            //   //     end
                            //   //     if (t > 1) begin
                            //   //       compute_phi = compute_phi / t * (t - 1);
                            //   //     end
                            //   //   end
                            //   //   endfunction`
                            //   //   The `while` loop inside the function might not be synthesizable for combinational logic (it creates a latch or feedback loop).
                            //   //   However, since the loop depth is small, we can unroll it manually.
                            //   //   `if (t % p == 0) begin compute_phi = compute_phi / p * (p-1); t = t / p; end`
                            //   //   `if (t % p == 0) begin compute_phi = compute_phi / p * (p-1); t = t / p; end`
                            //   //   ... repeated enough times (e.g. 10 times).

                            //   //   Or, we can just ignore the `while` part if we are using `function` inside `always @(*)`.
                            //   //   Wait, `function` in Verilog is typically used inside sequential blocks or assigned to wires.
                            //   //   `assign result = function_name(args);` is standard.
                            //   //   This creates combinational logic.

                            //   //   Let's try to write the function with a fixed number of iterations for the `while` part.
                            //   //   Since max exponent for 2 is 9, we can unroll the inner loop 9 times.
                            //   //   That's a lot of code.

                            //   //   Let's go back to the simplest valid solution that meets the latency requirement.
                            //   //   The prompt asks to "Generate an efficient Verilog module".
                            //   //   And "Design requirements... factorization can be done by checking division by primes".
                            //   //   This suggests the factorization method.
                            //   //   If we use the state machine with `CALCULATE_PHI` taking multiple cycles, but we optimize it to be as fast as possible.
                            //   //   But 100 cycles max for k=100 is impossible with multi-cycle factorization unless we use pipelining or parallelism.

                            //   //   Let's reconsider the "100 clock cycles max". 
                            //   //   Maybe it means "max latency for the operation is 100 cycles", not that it must complete in 100 cycles for max k?
                            //   //   Or maybe the k value in the "max cycles" example is small.
                            //   //   But usually, these prompts are strict.

                            //   //   What if I use a `while` loop in combinational logic? 
                            //   //   Standard synthesis tools (Synopsys Design Compiler, etc.) support `while` in `always @(*)` if the termination condition is guaranteed and the loop is finite.
                            //   //   But it's risky.

                            //   //   Let's try to implement the `phi` function using a combinational block that looks like a loop but unrolled logically.
                            //   //   Actually, let's just use the sequential state machine but make it very fast.
                            //   //   Wait, the prompt gives states: IDLE, CALCULATE_PHI, CHECK_COUNT, DONE.
                            //   //   It says "In CALCULATE_PHI, compute current = phi(current) using a combinational block."
                            //   //   THIS IS THE KEY. 
                            //   //   It says "using a combinational block".
                            //   //   So `CALCULATE_PHI` is a state where we just register the result of a combinational logic.
                            //   //   That combinational block calculates phi(current).
                            //   //   So `CALCULATE_PHI` takes 1 cycle.
                            //   //   Then `CHECK_COUNT` is another cycle.
                            //   //   Total 2 cycles per phi application.
                            //   //   Max k=100 -> (101)/2 = 50 applications -> 100 cycles.
                            //   //   PLUS overhead for IDLE -> first calc. 
                            //   //   Total < 100? 
                            //   //   50 * 2 = 100. 
                            //   //   If we count starting from IDLE:
                            //   //   IDLE -> CALCULATE (1 cycle for logic? No, state transition)
                            //   //   Wait, state transition is sequential.
                            //   //   State A (IDLE) -> State B (CALCULATE). 
                            //   //   In State B, combinational block computes phi. Output registered at end of cycle B.
                            //   //   So Cycle 1: IDLE. 
                            //   //   Cycle 2: CALCULATE (computation happens during cycle, result ready at posedge).
                            //   //   Cycle 3: CHECK_COUNT.
                            //   //   If we repeat: Cycle 4: CALCULATE. Cycle 5: CHECK_COUNT.
                            //   //   So 1 phi application takes 2 cycles (from posedge to posedge).
                            //   //   Actually, if we merge CHECK_COUNT and next CALCULATE:
                            //   //   State CHECK_COUNT -> if k>0: next state CALCULATE.
                            //   //   In CALCULATE: compute phi(prev).
                            //   //   So sequence:
                            //   //   IDLE -> CALCULATE -> CHECK -> CALCULATE -> CHECK -> DONE.
                            //   //   1st phi: 2 cycles (IDLE->CALC is 1, but IDLE is just loading). 
                            //   //   Let's trace carefully.
                            //   //   Cycle 0 (posedge): Start. State IDLE. Load current_val = n. k_cnt = k/2.
                            //   //   Cycle 1 (posedge): State CHECK (or CALCULATE? Let's say CHECK).
                            //   //   If k_cnt > 0: State CALCULATE.
                            //   //   Cycle 2 (posedge): State CALCULATE. current_val updated to phi(old).
                            //   //   Cycle 3 (posedge): State CHECK. decrement k_cnt.
                            //   //   ...
                            //   //   It takes 2 cycles per iteration (CHECK -> CALC -> CHECK).
                            //   //   Wait, if State CHECK transitions to State CALCULATE, we need a cycle.
                            //   //   And State CALCULATE transitions to State CHECK.
                            //   //   So yes, 2 cycles per step.
                            //   //   With k=100 (50 steps), 100 cycles.
                            //   //   Plus initial state (IDLE) and final state (DONE).
                            //   //   So total ~102 cycles. 
                            //   //   The prompt says "e.g., 100 clock cycles max". This is a close fit.
                            //   //   If we merge states or optimize, we can fit.

                            //   //   But how to implement the combinational block for phi?
                            //   //   It says "Use a small LUT or combinational logic... factorization can be done by checking division by primes".
                            //   //   So we need a combinational block that implements the factorization logic.
                            //   //   Since it's combinational, we can't use a `while` loop easily.
                            //   //   We can unroll the factorization for the small primes.
                            //   //   But we don't know the number of times a prime divides.

                            //   //   Let's use a `function` with a fixed number of divisions.
                            //   //   Since n <= 1000, we can check each prime and divide it out.
                            //   //   Let's say we have a function `phi_func(n)`.
                            //   //   We can do:
                            //   //   `phi_temp = n;`
                            //   //   `rem = n;`
                            //   //   `if (rem % 2 == 0) begin phi_temp = phi_temp / 2; rem = rem / 2; if (rem % 2 == 0) begin phi_temp = phi_temp / 2; rem = rem / 2; ... end end`
                            //   //   This is tedious.

                            //   //   Alternative: Use a loop in the function but ensure it is unrollable.
                            //   //   `for (i=0; i<11; i++) begin`
                            //   //     `while (rem % p[i] == 0) begin rem = rem / p[i]; end`
                            //   //   `end`
                            //   //   The `while` loop is the problem.

                            //   //   Wait, if we use the sequential state machine proposed earlier (IDLE -> SETUP -> CALCULATE -> CHECK ...), and we allow `CALCULATE` to take multiple cycles, we can meet the 100 cycle limit if k is small.
                            //   //   But the prompt says "Latency: The module should complete within roughly 20*Clock_Cycles_per_Phi_Approximation (e.g., 100 clock cycles max)."
                            //   //   This phrasing "20*Clock_Cycles_per_Phi_Approximation" is weird. 
                            //   //   Maybe it means: "If phi takes 5 cycles, total 100 cycles." 
                            //   //   And k is small? 
                            //   //   No, "k <= 100".
                            //   //   If phi takes 5 cycles, and k=50, total 250 cycles.
                            //   //   So "approx 20*Clock_Cycles_per_Phi" might be a hint to keep phi calc efficient.

                            //   //   Let's go with the most robust method: A pure combinational logic block for phi(n).
                            //   //   Since n is small (<=1000), we can generate the logic for it.
                            //   //   Or, we can use a LUT. 
                            //   //   "A simple way is to precompute values".
                            //   //   If we write a Verilog `case` statement for phi(n), it's a LUT.
                            //   //   That's 1000 lines. 
                            //   //   But it's 1 cycle latency.
                            //   //   And it's easy to write in code? No, manually writing 1000 lines is impossible.
                            //   //   But I can generate it in the prompt? No, I must generate the code.

                            //   //   So I cannot use a full 1000-entry LUT in the code.
                            //   //   I must use the factorization logic.

                            //   //   Let's assume the "100 cycles max" is a loose bound or implies that we should use the combinational block approach as suggested.
                            //   //   I will implement the combinational factorization logic using a `function` that is hopefully synthesizable.
                            //   //   I will try to make the function iterative by using a `for` loop and handling the "while" aspect by repeating the division check.
                            //   //   Since max exponent is small (e.g. 2^9), I can check divisibility 9 times for 2, 6 times for 3, etc.
                            //   //   But writing that out is huge.

                            //   //   Let's try to use the sequential state machine with the following optimization:
                            //   //   Factorization is done bit by bit in `CALCULATE_PHI` state, taking many cycles.
                            //   //   But we count the total cycles. 
                            //   //   If k=100, and factorization takes 20 cycles per step, total 2000 cycles. Too much.

                            //   //   Let's reconsider the `function` with a `while` loop.
                            //   //   Modern synthesis tools (Synopsys Design Compiler, etc.) support `while` in combinational contexts if the loop bounds are statically determinable.
                            //   //   Let's try to write the function and hope the tool supports it. 
                            //   //   Alternatively, I can write a small helper block that uses a `for` loop and breaks down the "while" logic.

                            //   //   Let's use the following logic for the combinational block (function):
                            //   //   ```verilog
                            //   //   function [9:0] compute_phi;
                            //   //     input [9:0] val;
                            //   //     integer i;
                            //   //     reg [9:0] res;
                            //   //     reg [9:0] rem;
                            //   //     reg [9:0] p;
                            //   //   begin
                            //   //     res = val;
                            //   //     rem = val;
                            //   //     for (i=0; i<11; i=i+1) begin
                            //   //       p = primes[i];
                            //   //       if (rem % p == 0) begin
                            //   //         res = res / p * (p - 1);
                            //   //         rem = rem / p;
                            //   //         if (rem % p == 0) begin
                            //   //           rem = rem / p;
                            //   //           if (rem % p == 0) begin
                            //   //             rem = rem / p;
                            //   //             ... // Repeat enough times
                            //   //           end
                            //   //         end
                            //   //       end
                            //   //     end
                            //   //     if (rem > 1) begin
                            //   //       res = res / rem * (rem - 1);
                            //   //     end
                            //   //     compute_phi = res;
                            //   //   end
                            //   //   endfunction
                            //   //   ```
                            //   //   This is ugly but synthesizable.

                            //   //   Let's try a cleaner approach.
                            //   //   The state machine `CALCULATE_PHI` can be implemented as a loop that takes multiple cycles, but we can optimize it to 1 cycle if we just write the logic for all primes in parallel.
                            //   //   Since there are only 11 primes + 1 extra, we can write the combinational logic explicitly.
                            //   //   
                            //   //   Let's design the combinational block:
                            //   //   `input n` -> `output phi`.
                            //   //   `reg [9:0] t = n;`
                            //   //   `phi = n;`
                            //   //   `if (t % 2 == 0) begin phi = phi/2; t = t/2; end`
                            //   //   `if (t % 2 == 0) begin phi = phi/2; t = t/2; end`
                            //   //   ... (repeat 9 times)
                            //   //   `if (t % 3 == 0) begin ...` etc.
                            //   //   
                            //   //   This is the only way to guarantee 1-cycle combinational logic without loops.
                            //   //   But writing 11 primes * max exponents is long.
                            //   //   Max exponents: 2->9, 3->6, 5->3, 7->3, 11->2, 13->2 ... 
                            //   //   Total lines ~30-40. Manageable.

                            //   //   Let's write this combinational logic.
                            //   //   I will define a `function` to keep the code clean.
                            //   //   And inside the function, I will unroll the loops manually.

                            //   //   Let's estimate the number of lines.
                            //   //   For 2: 9 times.
                            //   //   For 3: 6 times.
                            //   //   For 5: 3 times.
                            //   //   For 7: 3 times.
                            //   //   For 11, 13, 17, 19, 23, 29, 31: 2 times each? 
                            //   //   Total: 9 + 6 + 3 + 3 + 7*2 = 33. 
                            //   //   Plus the final check `if (t > 1)`.
                            //   //   This is acceptable code size.

                            //   //   So the plan:
                            //   //   1. `function` `compute_phi` with unrolled loops for factorization.
                            //   //   2. State machine:
                            //   //      IDLE: if start: current_val <= n; k_cnt <= (k+1)/2; state <= CALCULATE_PHI (or CHECK to start loop).
                            //   //      Wait, we need to handle the loop.
                            //   //      If k_cnt == 0, go to DONE.
                            //   //      If k_cnt > 0, go to CALCULATE_PHI.
                            //   //      CALCULATE_PHI: current_val <= compute_phi(current_val); state <= CHECK_COUNT.
                            //   //      CHECK_COUNT: if (current_val == 1) state <= DONE; else if (k_cnt > 1) begin k_cnt <= k_cnt - 1; state <= CALCULATE_PHI; end else state <= DONE.
                            //   //      WAIT: We need to decrement k_cnt.
                            //   //      Let's do:
                            //   //      IDLE: if start: current_val = n; k_cnt = (k+1)/2; if (k_cnt > 0) state <= CALCULATE_PHI; else state <= DONE.
                            //   //      CALCULATE_PHI: current_val <= compute_phi(current_val); state <= DECR_K.
                            //   //      DECR_K: k_cnt <= k_cnt - 1; if (k_cnt == 1 || current_val == 1) state <= DONE; else state <= CALCULATE_PHI.
                            //   //      (Note: k_cnt in DECR_K is the count remaining AFTER this step).
                            //   //      Wait, if k_cnt is 1, we just did the last step. We are done.
                            //   //      But if k_cnt was 1 in IDLE, we wouldn't enter CALCULATE.
                            //   //      So in IDLE, if k_cnt > 0, we enter CALCULATE.
                            //   //      If k_cnt becomes 0 in DECR_K, we are done.
                            //   //      But we need to check `current_val != 1`.
                            //   //      So DECR_K: k_cnt <= k_cnt - 1. 
                            //   //      If (k_cnt - 1 == 0) or (new_current_val == 1)?
                            //   //      Wait, `current_val` is updated in CALCULATE_PHI.
                            //   //      In DECR_K, we have the updated `current_val`.
                            //   //      So we can check `current_val != 1`.
                            //   //      If `current_val == 1`, go to DONE.
                            //   //      Else if `k_cnt == 0` (i.e. we just decremented from 1 to 0), go to DONE.
                            //   //      Else go to CALCULATE_PHI.

                            //   //      Actually, `k_cnt` tracks remaining applications.
                            //   //      In IDLE, `k_cnt = (k+1)/2`. This is the number of times to apply phi.
                            //   //      If `k_cnt == 1`, we apply phi once and are done.
                            //   //      So logic:
                            //   //      IDLE: if start: 
                            //   //        k_cnt = (k+1)/2; 
                            //   //        current_val = n;
                            //   //        if (k_cnt > 0) state <= CALCULATE_PHI; else state <= DONE;
                            //   //      CALCULATE_PHI: 
                            //   //        current_val <= compute_phi(current_val);
                            //   //        state <= CHECK;
                            //   //      CHECK:
                            //   //        if (current_val == 1) state <= DONE;
                            //   //        else if (k_cnt == 1) state <= DONE;
                            //   //        else begin k_cnt <= k_cnt - 1; state <= CALCULATE_PHI; end
                            //   //      DONE: done=1.

                            //   //      Wait, in CHECK, `k_cnt` is the number of applications remaining INCLUDING the one we just did?
                            //   //      No, `k_cnt` in IDLE is total count.
                            //   //      We need to decrement `k_cnt` after the calculation.
                            //   //      Let's say `k_cnt` is `remaining`. 
                            //   //      IDLE: `remaining = (k+1)/2`.
                            //   //      If `remaining > 0`: Calc. 
                            //   //      Then `remaining = remaining - 1`.
                            //   //      If `remaining == 0` or `current_val == 1`: DONE.
                            //   //      Else Calc again.

                            //   //      So:
                            //   //      IDLE: 
                            //   //        k_cnt <= (k+1) >> 1;
                            //   //        current_val <= n;
                            //   //        if ((k + 1) >> 1 > 0) state <= CALCULATE; else state <= DONE.
                            //   //      CALCULATE:
                            //   //        current_val <= compute_phi(current_val);
                            //   //        state <= DECR;
                            //   //      DECR:
                            //   //        k_cnt <= k_cnt - 1;
                            //   //        state <= CHECK;
                            //   //      CHECK:
                            //   //        if (current_val == 1 || k_cnt == 0) state <= DONE;
                            //   //        else state <= CALCULATE;
                            //   //      
                            //   //      This looks correct.
                            //   //      Cycles: IDLE(1) -> CALC(1) -> DECR(1) -> CHECK(1) -> ...
                            //   //      If we merge DECR and CHECK:
                            //   //      CALC -> CHECK. 
                            //   //      In CHECK: if (need more): k_cnt--; state <= CALC.
                            //   //      This saves a cycle.

                            //   //      Revised:
                            //   //      IDLE: if start: k_cnt <= (k+1)/2; current_val <= n; state <= (k_cnt > 0 ? CALC : DONE).
                            //   //      CALC: current_val <= compute_phi(current_val); state <= CHECK.
                            //   //      CHECK: 
                            //   //        if (current_val == 1) state <= DONE;
                            //   //        else if (k_cnt == 1) state <= DONE;
                            //   //        else begin k_cnt <= k_cnt - 1; state <= CALC; end
                            //   //      
                            //   //      Wait, `k_cnt` in IDLE is set to value. 
                            //   //      In CHECK, `k_cnt` represents the number of iterations *already performed* + 1? No, it represents iterations *remaining to be started*?
                            //   //      No, `k_cnt` in IDLE is total iterations.
                            //   //      If we are in CHECK, we have just performed an iteration.
                            //   //      So `k_cnt` is the total iterations.
                            //   //      If `k_cnt` is 2, we have 1 more iteration to do.
                            //   //      So `if (k_cnt > 1)` is correct.

                            //   //      I am confident.

                            //   //      Let's write the code.

                            //   //      module eurus_solver(
                            //   //          input clk,
                            //   //          input rst_n,
                            //   //          input start,
                            //   //          input [9:0] n,
                            //   //          input [7:0] k,
                            //   //          output reg [29:0] result,
                            //   //          output reg done
                            //   //      );

                            //   //      // Parameters and Constants
                            //   //      parameter MOD = 30'd1000000007;

                            //   //      // State Encoding
                            //   //      localparam IDLE = 3'b000;
                            //   //      localparam CALCULATE = 3'b001;
                            //   //      localparam CHECK = 3'b010;
                            //   //      localparam DONE = 3'b011;

                            //   //      // Registers
                            //   //      reg [1:0] state;
                            //   //      reg [7:0] k_cnt;
                            //   //      reg [9:0] current_val;

                            //   //      // Function to compute phi(n)
                            //   //      function [9:0] compute_phi;
                            //   //          input [9:0] val;
                            //   //          integer i;
                            //   //          reg [9:0] res, t;
                            //   //      begin
                            //   //          res = val;
                            //   //          t = val;
                            //   //          // Factor 2
                            //   //          for (i=0; i<9; i=i+1) if (t % 2 == 0) begin res = res / 2; t = t / 2; end
                            //   //          // Factor 3
                            //   //          for (i=0; i<6; i=i+1) if (t % 3 == 0) begin res = res / 3 * 2; t = t / 3; end
                            //   //          // Factor 5
                            //   //          for (i=0; i<4; i=i+1) if (t % 5 == 0) begin res = res / 5 * 4; t = t / 5; end
                            //   //          // Factor 7
                            //   //          for (i=0; i<3; i=i+1) if (t % 7 == 0) begin res = res / 7 * 6; t = t / 7; end
                            //   //          // Factors 11, 13, 17, 19, 23, 29, 31
                            //   //          for (i=0; i<3; i=i+1) if (t % 11 == 0) begin res = res / 11 * 10; t = t / 11; end
                            //   //          for (i=0; i<3; i=i+1) if (t % 13 == 0) begin res = res / 13 * 12; t = t / 13; end
                            //   //          for (i=0; i<3; i=i+1) if (t % 17 == 0) begin res = res / 17 * 16; t = t / 17; end
                            //   //          for (i=0; i<3; i=i+1) if (t % 19 == 0) begin res = res / 19 * 18; t = t / 19; end
                            //   //          for (i=0; i<3; i=i+1) if (t % 23 == 0) begin res = res / 23 * 22; t = t / 23; end
                            //   //          for (i=0; i<3; i=i+1) if (t % 29 == 0) begin res = res / 29 * 28; t = t / 29; end
                            //   //          for (i=0; i<3; i=i+1) if (t % 31 == 0) begin res = res / 31 * 30; t = t / 31; end
                            //   //          if (t > 1) begin res = res / t * (t - 1); end
                            //   //          compute_phi = res;
                            //   //      end
                            //   //      endfunction

                            //   //      // Sequential Logic (State Machine)
                            //   //      always @(posedge clk or negedge rst_n) begin
                            //   //          if (!rst_n) begin
                            //   //              state <= IDLE;
                            //   //              result <= 0;
                            //   //              done <= 0;
                            //   //              k_cnt <= 0;
                            //   //              current_val <= 0;
                            //   //          end else begin
                            //   //              case (state)
                            //   //                  IDLE: begin
                            //   //                      done <= 0;
                            //   //                      if (start) begin
                            //   //                          current_val <= n;
                            //   //                          k_cnt <= (k + 1) >> 1;
                            //   //                          if ((k + 1) >> 1 > 0) state <= CALCULATE; else state <= DONE;
                            //   //                      end else begin
                            //   //                          state <= IDLE;
                            //   //                      end
                            //   //                  end
                            //   //                  CALCULATE: begin
                            //   //                      current_val <= compute_phi(current_val);
                            //   //                      state <= CHECK;
                            //   //                  end
                            //   //                  CHECK: begin
                            //   //                      if (current_val == 1) state <= DONE;
                            //   //                      else if (k_cnt > 1) begin k_cnt <= k_cnt - 1; state <= CALCULATE; end
                            //   //                      else state <= DONE;
                            //   //                  end
                            //   //                  DONE: begin
                            //   //                      result <= current_val % MOD;
                            //   //                      done <= 1;
                            //   //                      if (!start) state <= IDLE;
                            //   //                  end
                            //   //                  default: state <= IDLE;
                            //   //              endcase
                            //   //          end
                            //   //      end

                            //   //      endmodule

                            //   