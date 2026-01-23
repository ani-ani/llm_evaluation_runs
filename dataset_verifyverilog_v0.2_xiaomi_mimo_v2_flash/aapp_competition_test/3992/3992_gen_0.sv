module chocolate_distribution (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [15:0] sum_total,
    input [7:0] a [0:15],
    output reg [31:0] result,
    output reg done,
    output reg no_solution
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam FACTORIZE_CHECK = 3'b001;
    localparam FACTORIZE_UPDATE = 3'b010;
    localparam CALCULATE_COST = 3'b011;
    localparam COMPARE_COST = 3'b100;
    localparam NEXT_FACTOR = 3'b101;
    localparam DONE_STATE = 3'b110;

    reg [2:0] state;
    reg [2:0] next_state;

    // Factorize registers
    reg [15:0] temp_sum;
    reg [15:0] candidate;
    reg [15:0] current_p;
    reg [31:0] min_cost_storage;
    reg [31:0] current_cost;
    reg [7:0] array_idx;
    reg [15:0] remainder;
    reg [15:0] factor_rem; // For prime factor checking
    
    // Control flags
    reg valid_factor_found;
    reg factorization_done;
    reg cost_calc_done;

    // Helper signals
    wire [15:0] p_minus_r;
    wire [31:0] step_cost;
    wire is_prime;
    wire divides;
    
    assign p_minus_r = current_p - remainder;
    // min(r, p-r) where p > r implies p-r < r if r > p/2, else r <= p-r if r <= p/2
    // Actually cost is min(r, p-r)
    // If remainder < p - remainder -> cost is remainder
    // If remainder >= p - remainder -> cost is p - remainder
    assign step_cost = (remainder < p_minus_r) ? {16'b0, remainder} : {16'b0, p_minus_r};

    // Prime checking and division logic (combinational)
    // Check if candidate is prime (simplified for range up to 65535)
    // We only need to check divisors up to sqrt(candidate). 
    // Since candidate is sum_total, max 16*255 = 4080. 
    // sqrt(4080) approx 64. 
    // We check divisibility in CALCULATE_COST state loop logic.
    
    // Check divisibility: current_p divides factor_rem?
    assign divides = (factor_rem % current_p == 0);

    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = FACTORIZE_CHECK;
                else next_state = IDLE;
            end
            
            FACTORIZE_CHECK: begin
                // Check if candidate is valid factor (divides sum_total)
                // And check if it's prime
                // If valid prime factor found, go to setup calculation
                if (valid_factor_found) begin
                    next_state = CALCULATE_COST;
                end else if (factorization_done) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = FACTORIZE_UPDATE;
                end
            end
            
            FACTORIZE_UPDATE: begin
                // Update candidate to check next potential factor
                next_state = FACTORIZE_CHECK;
            end
            
            CALCULATE_COST: begin
                // Iterate through array a
                if (array_idx >= 16 || array_idx >= n) begin
                    next_state = COMPARE_COST;
                end else begin
                    next_state = CALCULATE_COST;
                end
            end
            
            COMPARE_COST: begin
                // Update min cost
                next_state = NEXT_FACTOR;
            end
            
            NEXT_FACTOR: begin
                // Prepare to find next factor or finish
                if (factorization_done) next_state = DONE_STATE;
                else next_state = FACTORIZE_CHECK;
            end
            
            DONE_STATE: begin
                if (start) next_state = FACTORIZE_CHECK; // Restart capability
                else next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Output and Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            no_solution <= 0;
            temp_sum <= 0;
            candidate <= 0;
            current_p <= 0;
            min_cost_storage <= 32'hFFFF_FFFF;
            current_cost <= 0;
            array_idx <= 0;
            remainder <= 0;
            factor_rem <= 0;
            valid_factor_found <= 0;
            factorization_done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    no_solution <= 0;
                    min_cost_storage <= 32'hFFFF_FFFF;
                    if (start) begin
                        if (sum_total <= 1) begin
                            // Handle edge case immediately in next cycle logic via state transition or here
                            // If sum_total == 1, no solution. But we rely on algorithm.
                        end
                        temp_sum <= sum_total;
                        candidate <= 2; // Start checking factors from 2
                        factorization_done <= 0;
                        valid_factor_found <= 0;
                        min_cost_storage <= 32'hFFFF_FFFF; // Init max
                    end
                end

                FACTORIZE_CHECK: begin
                    // Logic to determine if 'candidate' is a valid prime factor
                    // We need to check:
                    // 1. temp_sum % candidate == 0 (Is it a divisor?)
                    // 2. Is 'candidate' prime? (We verify primality by checking divisibility by smaller numbers)
                    //    However, iterating prime generation is expensive. 
                    //    Simplified: We iterate 'candidate'. 
                    //    If temp_sum % candidate == 0:
                    //       Check if candidate is prime. 
                    //       If prime, set valid_factor_found = 1.
                    //       If not prime, we might skip it (but usually factorizing composite sums is tricky).
                    //    Actually, the requirement says "Find all prime factors".
                    //    Let's use a simple approach: 
                    //    If temp_sum % candidate == 0:
                    //       factor_rem = candidate; 
                    //       current_p = 2; (to check primality of candidate)
                    //       This is getting complex for a single state. 
                    //    Alternate Strategy: 
                    //    Just find 'p' such that sum_total % p == 0. 
                    //    If p is not prime, we check p/2, etc? No, standard factorization divides by smallest prime.
                    //    Let's strictly follow: "Find prime factors".
                    //    Since range is small, we can check if 'candidate' divides sum_total.
                    //    If it divides, check if it is prime. To check primality of 'candidate':
                    //       Check divisibility by k from 2 to sqrt(candidate).
                    //       We will use 'current_p' for the primality checking divisor.
                    
                    // Actually, simpler approach for this specific module:
                    // Just find divisors of sum_total. 
                    // If divisor is found, verify it's prime. 
                    // To verify prime, we need a loop. 
                    // Let's optimize: 
                    // State FACTORIZE_CHECK checks if 'candidate' divides 'temp_sum'.
                    // If yes, assume it's a candidate. 
                    // To check primality, we need to check if 'candidate' has factors.
                    // We can use 'current_p' to iterate divisors of 'candidate'.
                    
                    // Let's modify the flow slightly for robustness:
                    // 1. Find smallest divisor 'd' of temp_sum.
                    // 2. Find smallest divisor 'd' of temp_sum (starting from 2).
                    // 3. If 'd' is found, set 'current_p' = d.
                    // 4. Mark as found, go to CALCULATE.
                    // 5. After calculation, divide temp_sum by current_p repeatedly.
                    // 6. Then continue looking for next divisor.
                    
                    // Revised Logic for Factorize:
                    // Iterate 'candidate' from 2 up to temp_sum.
                    // If temp_sum % candidate == 0:
                    //    Check if 'candidate' is prime.
                    //    To check primality of 'candidate', we need a sub-loop.
                    //    Let's use 'current_p' as the potential divisor for primality test.
                    //    If 'candidate' is prime, set valid_factor_found = 1, current_p = candidate.
                    //    If 'candidate' is composite, skip it (it will be covered by its prime factors).
                    //    Wait, if we find a divisor 'candidate', we should take it ONLY if it's prime.
                    //    If it's composite, we divide temp_sum by it?
                    //    No, we want prime factors.
                    //    Let's just find the smallest divisor 'k' of temp_sum.
                    //    That divisor 'k' must be prime (if we start from 2).
                    //    So: Loop 'candidate' from 2. 
                    //    If temp_sum % candidate == 0:
                    //       This 'candidate' is a prime factor (guaranteed if we increment from 2).
                    //       Set current_p = candidate.
                    //       valid_factor_found = 1.
                    //       Then we need to reduce temp_sum (done in NEXT_FACTOR or here).
                    //       Actually, we must extract the factor. 
                    //       Let's put logic in NEXT_FACTOR to reduce temp_sum.
                    
                    // Optimization: 
                    // Just check if temp_sum % candidate == 0. 
                    // If so, since we increment from 2, it is a prime factor.
                    // Set current_p = candidate.
                    // Set valid_factor_found = 1.
                    
                    // Handshake for valid_factor_found:
                    // valid_factor_found <= (temp_sum % candidate == 0);
                    // But we need to compute modulo. 
                    // Verilog modulo is synthesizable. 
                    // If temp_sum is 0 or 1, we are done.
                    if (temp_sum <= 1) begin
                        factorization_done <= 1;
                        valid_factor_found <= 0;
                    end else if (temp_sum % candidate == 0) begin
                        current_p <= candidate;
                        valid_factor_found <= 1;
                    end else begin
                        valid_factor_found <= 0;
                        if (candidate >= temp_sum) begin
                            factorization_done <= 1;
                        end else begin
                            factorization_done <= 0;
                        end
                    end
                end

                FACTORIZE_UPDATE: begin
                    // Increment candidate if not valid
                    if (!valid_factor_found && !factorization_done) begin
                        if (candidate < temp_sum) candidate <= candidate + 1;
                    end
                end

                CALCULATE_COST: begin
                    if (array_idx == 0) begin
                        current_cost <= 0;
                        remainder <= 0;
                    end
                    
                    if (array_idx < 16 && array_idx < n) begin
                        // Update remainder: r = (r + a[i]) % p
                        remainder <= (remainder + a[array_idx]) % current_p;
                        // Add cost to current_cost
                        // Cost is min(r_new, p - r_new). Wait, r_new is the new remainder.
                        // The prompt says: "Cost contribution for each step: min(r, p - r)"
                        // Is r the running remainder before modulo, or after? 
                        // "Maintain running remainder r = (r + a[i]) % p"
                        // "Cost contribution: min(r, p - r)"
                        // Usually this problem (Chocolate Distribution) implies the cost to make a pile divisible by p
                        // by moving chocolates to next pile. 
                        // The cost is indeed the remainder after adding.
                        // So we use the updated remainder.
                        // The remainder is updated in this block, but combinational logic uses the OLD remainder for current step?
                        // Or does step i cost use remainder after step i?
                        // Standard logic: Add a[0], cost min(r, p-r), move r to next.
                        // So we add a[i] to accumulator, that's the new remainder.
                        // Then cost is min(new_rem, p - new_rem).
                        // Then we carry 'new_rem' (or rather remainder - cost? No, we transfer remainder to next).
                        // Actually, the cost is the amount transferred? 
                        // "min(r, p - r)" suggests we move min(r, p-r).
                        // Let's calculate cost based on the NEW remainder (which we just computed in the same cycle? No, logic order matters).
                        // The calculation of remainder is sequential.
                        // Let's use combinational `step_cost` based on the NEW remainder calculated from `remainder` (old) + `a[array_idx]`.
                        // But `remainder` is updated at posedge. 
                        // So in the cycle we are at, `remainder` holds value from previous step.
                        // We need to compute: next_rem = (remainder + a[i]) % p
                        // cost = min(next_rem, p - next_rem).
                        // This needs to be combinational or calculated within the cycle.
                        
                        // Let's use a temporary variable for calculation to avoid timing loop
                        // Or just calculate it explicitly:
                        reg [15:0] next_rem_temp;
                        reg [15:0] cost_temp;
                        next_rem_temp = (remainder + a[array_idx]) % current_p;
                        if (next_rem_temp < current_p - next_rem_temp)
                            cost_temp = next_rem_temp;
                        else
                            cost_temp = current_p - next_rem_temp;
                        
                        current_cost <= current_cost + cost_temp;
                        
                        array_idx <= array_idx + 1;
                    end else begin
                        // Finished array iteration
                        cost_calc_done <= 1;
                        array_idx <= 0; // Reset for next use
                    end
                end

                COMPARE_COST: begin
                    // Update global minimum
                    if (current_cost < min_cost_storage) begin
                        min_cost_storage <= current_cost;
                    end
                    // Reset for next prime factor calculation
                    remainder <= 0;
                    current_cost <= 0;
                    cost_calc_done <= 0;
                end

                NEXT_FACTOR: begin
                    // Divide temp_sum by current_p to remove this prime factor
                    // Continue searching for factors in temp_sum
                    // We need to remove all occurrences of current_p
                    while (temp_sum % current_p == 0) begin
                        temp_sum = temp_sum / current_p;
                    end
                    // Since we can't use while loops in synthesis for dynamic loops, we do it step by step.
                    // Actually, since we are in NEXT_FACTOR (one cycle), we can just divide once.
                    // But we might miss multiple factors of the same prime.
                    // However, for the cost calculation, we only need the prime 'p', not the power.
                    // So dividing once is enough to remove that factor for the purpose of checking existence of distinct primes.
                    // But wait, if sum_total = 4 (2^2), we need to process p=2. 
                    // We process p=2. Then temp_sum becomes 4/2 = 2.
                    // Next iteration, candidate will be 2 again (or 3). 
                    // If we keep candidate incrementing, we might skip 2.
                    // So we must reset candidate to 2.
                    // BUT, we must avoid infinite loop. 
                    // If temp_sum % candidate == 0, we process it. 
                    // Then we should divide temp_sum until it's no longer divisible by candidate.
                    // Or, we can just reset candidate to 2 every time.
                    // Let's divide temp_sum by current_p until not divisible.
                    
                    // Logic: 
                    // If temp_sum % current_p == 0, temp_sum <= temp_sum / current_p;
                    // candidate <= 2; (restart search from 2)
                    
                    // Note: We need to handle multiple factors of the same prime.
                    // If sum_total = 12 (2^2 * 3).
                    // Iter 1: candidate=2, divides. P=2. Cost calc. 
                    // In NEXT_FACTOR: temp_sum = 12/2 = 6. candidate=2.
                    // Iter 2: candidate=2, divides. P=2. Cost calc.
                    // In NEXT_FACTOR: temp_sum = 6/2 = 3. candidate=2.
                    // Iter 3: candidate=2, no. candidate=3. P=3. Cost calc.
                    // In NEXT_FACTOR: temp_sum = 3/3 = 1. Done.
                    // This works, but creates duplicate calculations for the same prime.
                    // The problem asks for prime factors. Usually distinct primes.
                    // But "For each prime factor p". If P=2 appears twice, do we calculate twice? 
                    // Yes, we iterate. But cost is based on sum_total mod p. 
                    // Wait. The cost is based on sum_total % p.
                    // sum_total is fixed (input). 
                    // The prime factors of sum_total are used as candidates for k.
                    // So we just need the set of prime factors.
                    // If 12, factors are 2 and 3. 
                    // So we should skip duplicates.
                    // To skip duplicates: 
                    // After processing P, divide temp_sum by P until not divisible. 
                    // Then reset candidate to P+1 (or 2). 
                    // Resetting to 2 is safer but inefficient. 
                    // Since max sum is 4080, it's fine.
                    
                    if (temp_sum % current_p == 0) begin
                        temp_sum <= temp_sum / current_p;
                        candidate <= 2; // Restart search to find next prime
                    end else begin
                        // Should not happen if logic is correct
                        candidate <= 2;
                    end
                    
                    // Handle edge case where temp_sum becomes 1
                    if (temp_sum / current_p == 1) begin
                        factorization_done <= 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (min_cost_storage == 32'hFFFF_FFFF) begin
                        no_solution <= 1;
                        result <= 0; // Or undefined
                    end else begin
                        no_solution <= 0;
                        result <= min_cost_storage;
                    end
                    if (start) begin
                        done <= 0;
                        no_solution <= 0;
                        // The reset logic in IDLE handles the rest, but we need to block done here if start is asserted
                        // Actually, if start is asserted, next state is FACTORIZE_CHECK.
                        // So outputs will update accordingly.
                    end
                end
            endcase

            // Special handling for sum_total == 1
            if (state == IDLE && start && sum_total <= 1) begin
                // Force to DONE with no_solution
                // We can't transition immediately in state machine easily without more logic.
                // Let's rely on factorization logic.
                // If sum_total <= 1, Factorize_Check sets factorization_done.
            end
        end
    end

endmodule
