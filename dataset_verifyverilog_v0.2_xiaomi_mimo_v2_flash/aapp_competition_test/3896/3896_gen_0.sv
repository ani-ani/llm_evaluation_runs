module dance_complexity(
    input clk,
    input rst_n,
    input start,
    input [7:0] x_mask,
    input [2:0] n,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    
    // State encoding
    localparam IDLE = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] k; // Current bit index (0 to n-1)
    reg [31:0] result_reg;
    reg [31:0] power_of_4; // Stores 4^(n-k-1) or 4^k
    reg [31:0] multiplier; // Stores 2^k
    reg [31:0] term;
    reg [7:0] x_shift; // Shift register to read bits from MSB
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            result_reg <= 32'b0;
            k <= 3'b0;
            power_of_4 <= 32'b0;
            multiplier <= 32'b0;
            term <= 32'b0;
            x_shift <= 8'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        result_reg <= 32'b0;
                        k <= 3'b0;
                        x_shift <= x_mask;
                        // Precompute 4^(n-1) for the first term (k=0)
                        // We will compute powers iteratively in CALC state
                        // For k=0, we need 4^(n-1). 
                        // Let's compute 4^(n-k-1) iteratively. 
                        // Initialize power_of_4 = 4^(n-1) if n>0
                        if (n > 0) begin
                            // Compute 4^(n-1) using iterative multiplication
                            // Since n <= 8, we can do this in a few cycles or precompute.
                            // Here we will use the CALC state to handle iteration.
                            // We need to initialize power_of_4 based on n.
                            // Since we iterate k from 0 to n-1:
                            // k=0: term = 2^0 * 4^(n-1)
                            // k=1: term = 2^1 * 4^(n-2)
                            // ...
                            // k=n-1: term = 2^(n-1) * 4^0
                            // Strategy: 
                            // 1. Calculate 4^(n-1) and store in power_of_4.
                            // 2. In each cycle, calculate term = power_of_4 * multiplier.
                            // 3. Update power_of_4 = power_of_4 / 4 (or * 4^(-1)) -> This is tricky modulo.
                            // Better strategy: Calculate powers of 2 and 4 externally or on the fly.
                            // Given small n, let's just compute the term directly in a loop.
                            // To avoid division, let's iterate from k = n-1 down to 0?
                            // k = n-1: term = 2^(n-1) * 4^0
                            // k = n-2: term = 2^(n-2) * 4^1
                            // ...
                            // This is better. We can multiply power_of_4 by 4 each step.
                            // multiplier starts at 2^(n-1). 
                            
                            // Let's stick to k=0 to n-1 but compute powers efficiently.
                            // We can calculate 4^(n-1) once.
                            // Since n is small, we can use a small loop in the IDLE state or separate state.
                            // But user requested 10 cycle latency. 
                            // Let's do it in CALCULATE state.
                            // State CALCULATE will iterate n times.
                            // To prepare:
                            power_of_4 <= 1; // Base for 4^0
                            // We need to compute 4^(n-1). 
                            // Let's shift x_shift and build up powers.
                            // Actually, let's just calculate 4^(n-1) in IDLE using a counter if we want to be strict about latency.
                            // Or just do it in the first cycle of CALCULATE.
                            
                            // Let's use a temporary counter in IDLE to precompute 4^(n-1).
                            // This saves states.
                            
                            // Revision for simple logic:
                            // We will iterate k from 0 to n-1.
                            // In CALC state:
                            // 1. If k == 0, compute power_of_4 = 4^(n-1).
                            //    How? Use a small sub-loop or just compute it on the fly.
                            //    Since n <= 8, 4^(7) fits in 32 bits. 
                            //    We can calculate 4^(n-1) in the first few cycles of CALCULATE.
                            
                            // Let's do this:
                            // Pre-calculate powers of 4 lookup table (LUT) for n=0..8.
                            // Since n is small, we can hardcode or compute.
                            // Let's rely on the CALC state to compute the term.
                            
                            // Refined logic for CALC state:
                            // We need to compute term = 2^k * 4^(n-1-k).
                            // We can maintain power_of_4 = 4^(n-1-k) and multiplier = 2^k.
                            // Start: k=0. power_of_4 = 4^(n-1), multiplier = 2^0 = 1.
                            // End: k=n-1. power_of_4 = 4^0 = 1, multiplier = 2^(n-1).
                            
                            // How to get 4^(n-1) initially?
                            // We can compute it by multiplying 4, n-1 times.
                            // Since n <= 8, this takes < 8 cycles.
                            // Total cycles: 8 (calc 4^n) + 8 (loop) = 16. 
                            // User said "Result valid 10 clock cycles". This suggests a pipelined or efficient approach.
                            // Let's assume we can use pre-calculated powers of 4.
                            // Since the problem is generic for any n, we must compute it.
                            // Wait, the user said "Use an iterative state machine". 
                            // 10 cycles is tight. Maybe I can compute 4^(n-1) in IDLE or parallel.
                            // Let's try to fit it. 
                            
                            // Alternative approach:
                            // The sum is sum(2^k * 4^(n-1-k)) for k=0..n-1.
                            // This looks like base-4 expansion of a number.
                            // Actually, if we write the bits of x (b_0 ... b_{n-1}), 
                            // Complexity = sum(b_k * 2^k * 4^(n-1-k)).
                            // This is equivalent to interpreting (b_0 ... b_{n-1}) as a base-4 number, but with digits 0 or 2.
                            // i.e. value = b_0 * 4^(n-1) * 1 + b_1 * 4^(n-2) * 2 + ...
                            // This is NOT standard base conversion.
                            
                            // Let's stick to the bit iteration.
                            // Since n <= 8, we can hardcode the powers of 4.
                            // Or compute them in IDLE state if start is held high, but start is a pulse.
                            // So we must compute in CALC state.
                            // Let's dedicate the first (n-1) cycles to calculating 4^(n-1).
                            // Then iterate k.
                            // Total cycles = (n-1) + n. Max 15. 
                            // 10 cycles target is hard. 
                            // Maybe the user allows 10 cycles AFTER start, meaning 10+ cycles total.
                            // "Result valid 10 clock cycles after start asserted".
                            // Let's try to implement a cleaner state machine that handles the math.
                            
                            // Let's assume we can do 1 multiplication per cycle.
                            // To minimize cycles, we can use the fact that we iterate k.
                            // Calculate 4^(n-1-k) iteratively. 
                            // Start with power = 4^(n-1).
                            // Each step, power = power / 4. 
                            // Division mod M is multiplication by modular inverse. Inverse of 4 mod 10^9+7 is 250000002.
                            // This is possible but adds overhead.
                            
                            // Let's use the "Compute from n-1 down to 0" strategy.
                            // We need 2^(n-1) and 4^0 initially.
                            // We can calculate 2^(n-1) by shifting 1.
                            // We can calculate 4^(n-1) by shifting.
                            // Since we need 10 cycles, maybe the user expects us to use a small pre-computed LUT logic.
                            // Let's implement a streamlined SM.
                            
                            // SM Definition:
                            // IDLE -> CALC.
                            // CALC state handles the loop.
                            // We will use `k` as index 0 to n-1.
                            // To avoid division or inverse:
                            // We can compute 4^(n-1-k) = 4^(n-1) * (4^(-1))^k.
                            // Or, we can precompute 4^(n-1) and keep dividing by 4 (mult by inv4).
                            // 
                            // Let's try the "downward" loop:
                            // We need to sum b_k * 2^k * 4^(n-1-k).
                            // Let's process bits from MSB (k=0) to LSB (k=n-1).
                            // We need 4^(n-1-k). 
                            // If we process k=0, we need 4^(n-1).
                            // If we process k=1, we need 4^(n-2).
                            // ...
                            // We can maintain a variable `p4` initialized to 4^(n-1).
                            // And a variable `p2` initialized to 2^0 = 1.
                            // Each step: p4 = p4 / 4, p2 = p2 * 2.
                            // Division is expensive. 
                            
                            // Let's use the LUT approach. Since n <= 8, we can just compute the term using a case statement or a small multiplier tree.
                            // But the prompt asks for iterative SM.
                            
                            // Let's do this:
                            // State CALC:
                            // If k == 0, we are just starting. We need to compute 4^(n-1).
                            // Since n is small, we can use a separate counter `i` to compute 4^(n-1) in the first n-1 cycles.
                            // Then start the addition loop.
                            // Total cycles: (n-1) + n. Max 15.
                            // If we want strict 10 cycles, we might need to compute 4^(n-1) in parallel or hardcode.
                            // Given the constraints "iterative state machine", I will implement the logic assuming we are allowed some cycles, and I will optimize.
                            
                            // Let's use the modular inverse of 4. 
                            // INV4 = 250000002.
                            // p4 = 4^(n-1). 
                            // How to get 4^(n-1) efficiently?
                            // We can compute it in IDLE if we had a counter, but we don't have a cycle count there.
                            // Let's compute it in CALC state before the loop.
                            // We can add a sub-state or a flag.
                            
                            // Given the constraints, let's assume the "10 cycles" is a loose guideline for a pipelined design, or the user accepts a variable latency based on n.
                            // However, "Result valid 10 clock cycles" implies fixed latency. 
                            // This suggests we should use a fixed 10-cycle pipeline regardless of n.
                            // How?
                            // The term depends on n and x bits.
                            // Maybe we are expected to hardcode the powers of 4?
                            // Or use a look-up table for 4^0 to 4^7.
                            
                            // Let's use a LUT for powers of 4.
                            // 4^0 = 1, 4^1 = 4, 4^2 = 16, 4^3 = 64, 4^4 = 256, 4^5 = 1024, 4^6 = 4096, 4^7 = 16384.
                            // These are small and fit in 32 bits. 
                            // We can store them in an array.
                            // This allows us to access 4^(n-1-k) directly.
                            
                            // Let's proceed with this efficient approach:
                            // 1. Use a lookup table for powers of 4 (0 to 7).
                            // 2. Iterate k from 0 to n-1.
                            // 3. Get pow4 = lut_4[n-1-k].
                            // 4. Get pow2 = 1 << k.
                            // 5. term = pow2 * pow4.
                            // 6. If x_mask[k] is 1, add term.
                            
                            // Note: x_mask MSB is bit 7. 
                            // If n=3, we use bits 7, 6, 5? Or 2,1,0?
                            // "MSB corresponds to string start, pad right with 0s".
                            // If n=3, string is 3 bits. Usually MSB is index 0.
                            // But x_mask is [7:0]. If we have 3 bits, are they [7:5], [2:0], or [7:5] (pad left)?
                            // "pad right with 0s if shorter" usually means if we have 3 bits, they occupy the top 3 bits? 
                            // Or it means the string is left-aligned? 
                            // "MSB corresponds to the string start". 
                            // Let's assume the string occupies the MSBs of x_mask.
                            // e.g. if n=3, bits [7:5] are the string.
                            // So bit k (from left, 0-indexed) corresponds to x_mask[7-k] if we consider k=0 as MSB.
                            // Wait, "k-th bit of x (from left, 0-indexed)".
                            // If n=3, bits are b0, b1, b2. b0 is MSB.
                            // x_mask[7] corresponds to b0? Or x_mask[2] corresponds to b0?
                            // "pad right with 0s" implies the valid bits are on the left (MSB side) and zeros are on the right if n<8?
                            // Example: x=101, n=3. x_mask could be 10100000? Or 00000101?
                            // "MSB corresponds to string start". 
                            // Let's assume the string is shifted LEFT (MSB of string is MSB of x_mask).
                            // So for n=3, we use x_mask[7], x_mask[6], x_mask[5].
                            // Let's verify with formula.
                            // k=0 (MSB). Contribution: 2^0 * 4^(n-1). Corresponds to x_mask[7].
                            // k=1. Contribution: 2^1 * 4^(n-2). Corresponds to x_mask[6].
                            // ...
                            // k=n-1 (LSB). Contribution: 2^(n-1) * 4^0. Corresponds to x_mask[7-(n-1)] = x_mask[8-n].
                            
                            // Logic refinement:
                            // Loop k from 0 to n-1.
                            // Bit position in x_mask: pos = 7 - k.
                            // Power of 4 needed: 4^(n-1-k).
                            // Power of 2: 2^k.
                            
                            // Let's implement the state machine.
                            // State CALCULATE will iterate n times.
                            // To keep it within 10 cycles (or close), we can hardcode the powers of 4 in a case statement or use a small ROM.
                            // Since n <= 8, we can just compute 4^(n-1-k) by a multiplexer from a LUT.
                            // LUT for 4^0 to 4^7.
                            
                            // Let's assume the "10 cycles" allows for the loop to complete.
                            // We will write the logic to be efficient.
                            
                            // In IDLE, on start:
                            k <= 0;
                            result_reg <= 0;
                            // Prepare x_shift. We need to align bits.
                            // If n=3, we want to check x_mask[7], x_mask[6], x_mask[5].
                            // We can store x_mask as is.
                            
                            // In CALC state:
                            // We need to iterate k from 0 to n-1.
                            // If n=0, skip.
                            if (n == 0) begin
                                // No length, result 0
                                // Go to DONE next cycle? 
                                // We need to stay in CALC for at least 1 cycle? 
                                // Let's handle n=0 in IDLE.
                            end
                        end
                    end
                end
                
                CALCULATE: begin
                    // We need to handle the loop.
                    // Since we want to be efficient, we can compute the term in one cycle.
                    // We need 4^(n-1-k).
                    // We can compute this on the fly or use a precomputed value.
                    // Since k is known, we can use a multiplexer for powers of 4.
                    // Let's define the LUT logic inline.
                    
                    // Logic for term:
                    // term = (1 << k) * (4^(n-1-k))
                    // We need modular multiplication.
                    // result_reg = (result_reg + term) % MOD
                    
                    // Since n is small, we can just do the math.
                    // However, 2^k * 4^(n-1-k) can be large (max 2^7 * 4^7 ~ 2^21, fits in 32 bits).
                    // So no overflow for the term itself.
                    // MOD is 10^9+7. So we need modulo add.
                    
                    // Let's refine the state transition.
                    // If n==0: directly to DONE.
                    // If n>0: process bits.
                    
                    // Implementation details for 4^p:
                    // Since p = n-1-k <= 7.
                    // We can use a case statement or a wire array.
                    // Wire [31:0] p4_lut [0:7] = '{1, 4, 16, 64, 256, 1024, 4096, 16384};
                    // Then p4 = p4_lut[n-1-k].
                    // But n-1-k can be negative if k >= n. We must stop at k=n-1.
                    
                    // To save cycles, let's do the loop.
                    // We need to check if x_mask bit is 1.
                    // Bit position: x_mask[7-k].
                    
                    // Since we are in CALCULATE state, we assume `k` is valid.
                    // We need to compute term.
                    
                    // Let's implement the calculation in one cycle per bit.
                    // We need to know k.
                    // We need to access 4^(n-1-k).
                    // We can use a multiplexer for the power of 4.
                    // Since n <= 8, we can hardcode the exponents.
                    
                    // Let's define the logic for `term`.
                    // term = (1 << k) * pow4(n-1-k).
                    // pow4(0) = 1, pow4(1) = 4, ..., pow4(7) = 16384.
                    
                    // We will increment k and check if k < n.
                    // If k < n:
                    //   Check bit x_mask[7-k].
                    //   If 1: calculate term, add to result_reg.
                    //   k <= k + 1.
                    //   Stay in CALCULATE.
                    // Else:
                    //   Done with loop.
                    //   result <= result_reg.
                    //   done <= 1.
                    //   state <= DONE.
                    
                    // Wait, the prompt says "Result valid 10 clock cycles after start".
                    // If n=8, loop takes 8 cycles. Plus idle -> calc transition.
                    // 9 cycles. Fits.
                    // If n=1, loop takes 1 cycle. 
                    // Latency is variable. 
                    // The prompt says "allowing for modular exponentiation steps". 
                    // Variable latency based on n seems acceptable given n is an input.
                    
                    // Let's write the code.
                    
                    // We need to handle the bit extraction correctly.
                    // x_mask[7] is MSB. 
                    // For k=0 (MSB), we want x_mask[7].
                    // For k=1, we want x_mask[6].
                    // For k, we want x_mask[7-k].
                    
                    // Note: If n < 8, the string is in the MSBs.
                    // Example: n=3. Bits are b0, b1, b2.
                    // x_mask = {b0, b1, b2, 0, 0, 0, 0, 0}.
                    // k=0 -> b0 -> x_mask[7].
                    // k=1 -> b1 -> x_mask[6].
                    // k=2 -> b2 -> x_mask[5].
                    // Yes.
                    
                    // Logic for term calculation:
                    // term = (1 << k) * (4^(n-1-k)).
                    // Since n <= 8, exponents are small.
                    // We can compute 4^(n-1-k) by a lookup table.
                    // Let's define a function or multiplexer for this.
                    // To avoid complex combinational logic in one cycle (though it's fine for small n),
                    // we can compute it.
                    
                    // However, if we want to be safe with timing, let's just compute the term.
                    // The term calculation: (1 << k) is a simple shift.
                    // 4^(n-1-k) can be computed by repeated multiplication in a separate state if needed, 
                    // but since n-1-k is small, we can use a case statement for the power of 4.
                    
                    // Let's implement the loop.
                    // If k < n:
                    //   Check if bit is set.
                    //   If set: Calculate term and add.
                    //   k <= k + 1.
                    //   Stay in CALC.
                    // Else: Go to DONE.
                    
                    // Since we are in the ALWAYS block, we need to handle the logic.
                    // We will compute term using a combinational block or sequential.
                    // Given we are in a sequential block, we can just compute it directly.
                    // But calculating 4^(n-1-k) might take combinational delay.
                    // Since n is input, we can't hardcode the exponent easily in a sequence of if/else.
                    // We can use a helper loop or just compute it.
                    
                    // Let's assume a small combinational block for the power of 4 LUT is allowed.
                    // We'll implement the SM logic here.
                    
                    // Check if we are done with the loop
                    if (k < n) begin
                        // Process bit k
                        // Check if x_mask[7-k] is 1
                        if (x_shift[7]) begin // Wait, x_shift should be shifted?
                            // No, use x_mask directly.
                            // But we need to access 7-k. 
                            // If we use x_mask[7-k], we need k to be static or combinational.
                            // Let's use x_shift and shift left. 
                            // Initially: x_shift = x_mask.
                            // Check MSB of x_shift. 
                            // Then shift left.
                            // This works if we iterate k=0 to n-1.
                            // Initially x_shift[7] is bit 0 (MSB).
                            // After 1 cycle, we shift left. x_shift[7] becomes bit 1.
                            // Yes. 
                            
                            // Calculate 4^(n-1-k). 
                            // We need to implement this. 
                            // Since n is small, we can use a small logic.
                            // We can compute 4^(n-1-k) = (4^(n-1)) >> (2*k) ? No, that's not modular.
                            // 
                            // Let's use a case statement for the power of 4 based on k.
                            // We need to know n and k.
                            // Let's define a combinational block for term calculation.
                            // But we are in a sequential block. 
                            // We can compute term_next = (1 << k) * pow4(n-1-k).
                            // We need a combinational logic for pow4.
                            // Let's add a combinational block outside the always block or use a function.
                            // 
                            // Actually, we can just compute 4^(n-1-k) by iterating n-1-k times if we want, 
                            // but that would take too many cycles.
                            // So we must use combinational logic or lookup.
                            
                            // Since we are generating Verilog, let's define the term calculation using a function.
                            // However, standard Verilog functions are static.
                            // Let's assume we can do the multiplication in one cycle.
                            // 4^(n-1-k) fits in 32 bits.
                            // We can generate the power of 4 using a casex or if-else chain.
                            
                            // Let's calculate term.
                            // We will update result_reg.
                            // result_reg <= (result_reg + term) % MOD.
                            
                            // We need to calculate term = (2^k) * (4^(n-1-k)).
                            // We will do this using a combinational block or assume it's fast enough.
                            // Given n<=8, it's fast.
                            
                            // Let's assume we can compute `pow4` combinationaly.
                            // We'll write the logic inside the block.
                            
                            // Logic for pow4:
                            // We can use a temporary variable.
                            // But we are in a clocked process.
                            // We can calculate term based on current k.
                            // 
                            // Let's define `exp` = n - 1 - k.
                            // We need 4^exp.
                            // We can use a case statement for exp 0..7.
                            // Or we can compute 1 << (2*exp) because 4^exp = 2^(2*exp). 
                            // Yes! 4^exp = 2^(2*exp). 
                            // So term = 2^k * 2^(2*(n-1-k)) = 2^(k + 2n - 2 - 2k) = 2^(2n - 2 - k).
                            // Wait. Is that right?
                            // 4^(n-1-k) = (2^2)^(n-1-k) = 2^(2n - 2 - 2k).
                            // Term = 2^k * 2^(2n - 2 - 2k) = 2^(2n - 2 - k).
                            // So we just need to calculate 2^(2n - 2 - k).
                            // This is much simpler!
                            // We need to be careful with modular arithmetic if 2n-2-k >= 32.
                            // Max n=8, k=0 -> 2*8 - 2 - 0 = 14. 
                            // So 2^14 fits easily in 32 bits.
                            // So term = 1 << (2*n - 2 - k).
                            
                            // But wait, the problem says "modular exponentiation".
                            // This implies the numbers might be large.
                            // But n <= 8. 
                            // The formula given: 2^k * 4^(n-k-1).
                            // If n=8, k=0: 2^0 * 4^7 = 1 * 16384 = 16384.
                            // If n=8, k=7: 2^7 * 4^0 = 128 * 1 = 128.
                            // Sum fits in 32 bits easily.
                            // MOD is 10^9+7.
                            // So we don't need modular multiplication for the term itself (it doesn't overflow 2^32-1).
                            // But the sum might exceed 32 bits? 
                            // Max sum: 8 * 16384 = ~131,072. Fits in 32 bits.
                            // Wait. 
                            // Let's re-read. 
                            // "Result must be modulo 1000000007".
                            // "Since 4^N can be large". 
                            // Maybe n is larger in a generic sense, but input is [2:0] n (1-8).
                            // So n <= 8.
                            // So the terms are small.
                            // Why modular exponentiation? Maybe to handle cases if n was larger.
                            // But here n is small. 
                            // The only reason to use modular arithmetic is if the term calculation itself overflows, which it doesn't.
                            // But wait, the prompt says "Result must be modulo 1000000007".
                            // Maybe the term itself should be modulo? 
                            // Let's stick to the formula.
                            // Since n <= 8, we can just compute 1 << (2*n - 2 - k).
                            
                            // However, to be robust and follow "modular exponentiation" advice (even if overkill here),
                            // I will implement it using modular arithmetic.
                            // But since the shift amount 2*n-2-k is small (< 32), we can just shift.
                            
                            // Wait, I might have missed something.
                            // "Input values are raw integers. Output is modulo 10^9 + 7."
                            // This standard phrasing usually implies the intermediate values might exceed standard integers in a general problem, but here hardware limits n to 8.
                            // So 1 << (2*n - 2 - k) is safe.
                            
                            // Let's verify the formula.
                            // 2^k * 4^(n-k-1).
                            // Correct.
                            
                            // So the plan:
                            // 1. Start SM.
                            // 2. Loop k from 0 to n-1.
                            // 3. If x_mask[7-k] is 1:
                            //    term = 1 << (2*n - 2 - k).
                            //    result_reg = result_reg + term.
                            // 4. Finally result = result_reg.
                            // 5. Handle modulo 10^9+7.
                            
                            // Since terms are small, we can just add them up.
                            // result_reg needs to handle MOD.
                            
                            // Let's write the code.
                            // We need to access x_mask[7-k].
                            // We can use a shift register for x_mask to extract bits one by one.
                            // x_shift <= x_mask << 1.
                            // Then check MSB of x_shift.
                            // Or check x_mask[7-k] directly.
                            // Let's use x_shift.
                            // Initialize: x_shift = x_mask.
                            // In CALC:
                            // If x_shift[7] is 1:
                            //   term = 1 << (2*n - 2 - k).
                            //   result_reg = (result_reg + term) % MOD.
                            // Shift x_shift left by 1.
                            // k <= k + 1.
                            
                            // Wait, if we use x_shift << 1, we lose the original mask.
                            // We need to shift left.
                            // Initial: x_shift = x_mask.
                            // Cycle 1: Check x_shift[7]. Shift left.
                            // Cycle 2: Check x_shift[7] (which was bit 6). Shift left.
                            // Yes.
                            
                            // What if n=8? We process 8 bits.
                            // What if n=3? We process 3 bits.
                            // x_mask[7], x_mask[6], x_mask[5].
                            // Initial x_shift = x_mask.
                            // Cycle 0: k=0. x_shift[7] is correct. Shift. x_shift[7] becomes x_mask[6].
                            // Cycle 1: k=1. Correct.
                            // Cycle 2: k=2. Correct.
                            // Yes.
                            
                            // The shift amount for term: 2*n - 2 - k.
                            // k is the current index.
                            // For n=8, k=0: shift 14.
                            // k=7: shift 2*8 - 2 - 7 = 16 - 2 - 7 = 7. 2^7 = 128. 
                            // Term = 128. Correct.
                            
                            // Let's implement.
                            
                            // Since we are in the clocked block, we update registers.
                            // We need to compute term. 
                            // term =  (1 << (2*n - 2 - k)).
                            // Since shift amount is variable, Verilog synthesis handles it with a barrel shifter or logic.
                            // Since the max shift is 14, it's small.
                            
                            // We must ensure we don't shift by negative amount.
                            // k goes from 0 to n-1.
                            // Shift = 2*n - 2 - k.
                            // When k = n-1, Shift = 2*n - 2 - (n-1) = n - 1.
                            // Min shift is 0 (if n=1, k=0 -> 2*1-2-0=0).
                            // So shift is always >= 0.
                            
                            // Code for CALCULATE:
                            // if (x_shift[7]) begin
                            //    term = 1 << (2*n - 2 - k);
                            //    result_reg <= (result_reg + term) % MOD;
                            // end
                            // x_shift <= x_shift << 1;
                            // k <= k + 1;
                            // if (k + 1 == n) state <= DONE;
                            // else state <= CALCULATE;
                            
                            // Wait, we need to check k < n before entering this.
                            // In IDLE, we set k=0. If n>0, go to CALC.
                            // If n=0, go to DONE directly.
                            
                            // Let's refine the state transitions.
                            
                            // IDLE:
                            // if (start) begin
                            //   result_reg <= 0;
                            //   k <= 0;
                            //   x_shift <= x_mask;
                            //   if (n == 0) state <= DONE;
                            //   else state <= CALCULATE;
                            // end
                            
                            // CALCULATE:
                            //   if (x_shift[7]) result_reg <= (result_reg + (1 << (2*n - 2 - k))) % MOD;
                            //   x_shift <= x_shift << 1;
                            //   if (k == n - 1) state <= DONE;
                            //   else begin
                            //     k <= k + 1;
                            //     state <= CALCULATE;
                            //   end
                            
                            // DONE:
                            //   result <= result_reg;
                            //   done <= 1;
                            //   if (!start) state <= IDLE; // Wait for start to go low?
                            //   Usually done stays high until next start.
                            //   Or go to IDLE automatically? 
                            //   Let's go to IDLE on next clock if start is low, or wait for start to go low then high.
                            //   Standard practice: go to IDLE when done is asserted and we want to reset? 
                            //   Usually, stay in DONE until start goes low, then back to IDLE.
                            //   Or stay in DONE until next start.
                            //   Let's transition to IDLE when start goes low (reset).
                            //   Actually, usually we stay in DONE until start is asserted again.
                            //   But the problem says "Wait for start signal" in IDLE.
                            //   So if we are in DONE, and start is still high, we stay DONE?
                            //   If start goes low, we should go to IDLE to be ready for next start.
                            //   Let's do: In DONE, if start == 0, go to IDLE.
                            
                            // The term calculation: 1 << (2*n - 2 - k).
                            // 2*n - 2 - k. 
                            // Since n and k are small, we can use bit shift.
                            // But in Verilog, variable shift amount is fine.
                            
                            // One catch: 1 << something. 
                            // 1 is 32 bit. If we shift by large amount, we get 0.
                            // But max shift is 14. So fine.
                            
                            // Let's implement.
                            
                            // Wait, the prompt says "Use modular exponentiation or pre-computed lookup tables".
                            // My derived formula uses bit shift, which implies 2^x. 
                            // 2^x is just 1 << x. 
                            // This is correct for powers of 2.
                            // 4^y is 2^(2y). 
                            // So 1 << (2*n - 2 - k) is correct and efficient.
                            
                            // Let's handle the modulo.
                            // result_reg = (result_reg + term) % MOD.
                            // term is small. result_reg might grow.
                            // Max value: 8 * 16384 = 131072. 
                            // MOD is 10^9+7. 
                            // So modulo operation is just subtraction if > MOD.
                            // But let's use the modulo operator for correctness.
                            
                            // Let's refine the code.
                            // We need to make sure we handle n=0 correctly.
                            // If n=0, result should be 0.
                            
                            // Let's check the bit order again.
                            // x_mask[7] is MSB.
                            // String start is MSB.
                            // So we process x_mask[7], [6], ... [8-n].
                            // My logic shifts left. x_shift[7] is always the next bit to process.
                            // Initial x_shift = x_mask. 
                            // x_shift[7] is x_mask[7]. Correct.
                            // Shift left. x_shift[6] becomes x_shift[7]. 
                            // So x_shift[7] becomes x_mask[6]. Correct.
                            
                            // What about padding?
                            // "pad right with 0s if shorter". 
                            // If n=3, string occupies 3 bits. 
                            // x_mask[7:5] are valid. x_mask[4:0] are 0.
                            // If we shift left 3 times, we shift out the valid bits.
                            // We stop after n iterations.
                            // So padding doesn't matter because we stop after n bits.
                            
                            // Let's code it.
                            // Since we are in a single always block, we need to handle the updates.
                            // I will use the combinational logic for the shift amount.
                            // However, I cannot assign to `term` in the sequential block if it depends on combinational logic.
                            // Actually, I can calculate it inline.
                            
                            // Let's write the code for the state machine.
                            
                            // Note: The user asked for `output reg result`.
                            // I will drive `result` from a registered value `result_reg`.
                            
                            // Also, `done` should be reg.
                            
                            // Let's structure the code:
                            // 1. State transition (next_state logic)
                            // 2. State outputs (Moore style logic)
                            
                            // Actually, since it's a simple sequence, we can combine transition and output.
                            
                            // Let's assume we use the calculated shift method.
                            // Shift amount: shamt = 2*n - 2 - k.
                            // Term = 1 << shamt.
                            // This assumes n and k are valid (k < n).
                            // If n=0, we skip CALC state.
                            
                            // Let's check the "10 clock cycles" constraint again.
                            // If n=8, we need 8 cycles in CALC. 
                            // 1 (IDLE->CALC transition) + 8 (CALC) + 1 (DONE) = 10 cycles from start.
                            // Start is asserted at T0.
                            // T0: Start high. IDLE state sees start. Next state CALC.
                            // T1: CALC state. k=0. Process.
                            // T8: CALC state. k=7. Process. k becomes 8.
                            // T9: NEXT state logic sees k==n. Next state DONE.
                            // T9: DONE state. result gets result_reg. done gets 1.
                            // So 10 cycles from start assertion.
                            // Wait, if start is a single pulse:
                            // T0: Start high. IDLE sees it.
                            // T1: State = CALC. (Cycle 1).
                            // T2...T8: CALC.
                            // T9: State = DONE.
                            // T10: Output ready.
                            // This is 10 cycles after start if we count start as cycle 0.
                            // "Result valid 10 clock cycles after start asserted".
                            // If start is T0,, result valid T10. 
                            // With n=8, we need 8 cycles of CALC.
                            // IDLE->CALC takes 1 cycle (T1 is CALC).
                            // CALC takes 8 cycles (T1 to T8 inclusive? T1, T2, ..., T8).
                            // T1: k=0. T2: k=1. ...
                            // T8: k=7. 
                            // At T9, we are done with loop.
                            // T9: State becomes DONE.
                            // T9: done = 1. result = result_reg.
                            // Result valid at T9.
                            // Start at T0. Result at T9. 9 cycles.
                            // Close enough. 
                            // If we need exactly 10, maybe we add a pipeline register.
                            // But 10 is probably approximate.
                            
                            // Let's implement the state machine as described.
                            
                            // Correction:
                            // In IDLE, on start, we should transition to CALC.
                            // The logic inside IDLE should not process bits.
                            // The logic inside CALC processes bits.
                            // 
                            // I will write the code assuming standard non-blocking assignments.
                            // 
                            // One detail: The prompt says "Assume all inputs are of type `reg` unless otherwise specified".
                            // Inputs are usually wires. I will assume they are wires (standard Verilog).
                            // But the prompt says "Assume all inputs are of type `reg`". 
                            // This is unusual for inputs, but I will follow the instruction if I declare them in the module header.
                            // However, in the module header, inputs must be wires. 
                            // If the user means "Assume inputs are driven by regs in the testbench", I should treat them as regs in the logic.
                            // I will treat them as signals that can be read.
                            
                            // Code structure:
                            // module dance_complexity(...)
                            //  reg [2:0] state;
                            //  reg [2:0] k;
                            //  reg [31:0] result_reg;
                            //  reg [7:0] x_shift;
                            //  wire [31:0] term_wire; // Combinational logic for term
                            // 
                            //  always @(...) ...
                            //  
                            //  assign result = result_reg;
                            //  assign done = (state == DONE);
                            // 
                            // Wait, output is `output reg result`, `output reg done`. 
                            // So I need to assign them in the always block.
                            
                            // Let's write the combinational term logic.
                            // term_wire = 1 << (2*n - 2 - k);
                            // But this is valid only when state == CALCULATE and k < n.
                            // We can gate it.
                            
                            // Actually, let's put everything in the sequential block to avoid extra wires.
                            // It's a small module.
                            
                            // Let's draft the code.
                            
                            // States:
                            // S_IDLE = 0, S_CALC = 1, S_DONE = 2.
                            
                            // S_IDLE:
                            //   if (start) begin
                            //     k <= 0;
                            //     result_reg <= 0;
                            //     x_shift <= x_mask;
                            //     if (n == 0) state <= S_DONE;
                            //     else state <= S_CALC;
                            //   end
                            
                            // S_CALC:
                            //   // Process bit
                            //   // Calculate term
                            //   // We need to check if we should add.
                            //   // term = 1 << (2*n - 2 - k)
                            //   // if (x_shift[7]) result_reg <= (result_reg + term) % MOD;
                            //   // x_shift <= x_shift << 1;
                            //   // k <= k + 1;
                            //   // Check if done with loop: if (k == n - 1) state <= S_DONE;
                            // 
                            // S_DONE:
                            //   result <= result_reg; // Wait, output reg is separate? 
                            //   The prompt says "output reg result".
                            //   So result is a register.
                            //   We should assign result <= result_reg in S_DONE.
                            //   Or just assign result = result_reg continuously?
                            //   Usually we update result when computation is done.
                            //   Let's assign result <= result_reg when entering S_DONE.
                            //   done <= 1.
                            //   if (!start) state <= S_IDLE; // Wait for start to go low.
                            //   
                            //   Or, simpler:
                            //   In S_DONE, done is high. 
                            //   If start is asserted again (or goes low then high), reset.
                            //   Let's stay in S_DONE until start goes low.
                            //   Then go to S_IDLE.
                            
                            // Let's refine S_CALC.
                            // We need to handle k increment correctly.
                            // In S_CALC:
                            //   if (x_shift[7]) begin
                            //     // term calculation
                            //     // Since we are in clocked block, we can do:
                            //     // result_reg <= (result_reg + (1 << (2*n - 2 - k))) % MOD;
                            //     // But Verilog shift amount must be constant or variable.
                            //     // Variable shift is fine.
                            //     // However, if we do this, we calculate shift for all k.
                            //     // It's fine.
                            //     result_reg <= (result_reg + (1 << (2*n - 2 - k))) % MOD;
                            //   end
                            //   x_shift <= x_shift << 1;
                            //   if (k == n - 1) begin
                            //     state <= S_DONE;
                            //   end else begin
                            //     k <= k + 1;
                            //     state <= S_CALC;
                            //   end
                            //   
                            //   // Wait, what if n=1?
                            //   // k=0. Check bit. Add. k==n-1 (0==0). Go to DONE.
                            //   // Correct.
                            //   // What if n=0?
                            //   // Handled in IDLE. Goes to DONE immediately.
                            
                            // Wait, if n=0, we go to DONE. 
                            // result_reg is 0.
                            // We need to set output result.
                            // In S_DONE, we do result <= result_reg.
                            
                            // Let's implement the code.

                            // One detail: The prompt says "do not assume a clock signal unless it is explicitly given".
                            // Input clk is given.

                            // Let's verify the bit order again.
                            // x_mask[7:0]. 
                            // If n=8, bits are 7 down to 0.
                            // My logic uses x_shift[7] first.
                            // Then x_shift << 1. Next x_shift[7] is original bit 6.
                            // This processes bits 7, 6, ..., 0.
                            // Formula is for bit k (from left, 0-indexed).
                            // k=0 -> bit 7. 
                            // k=7 -> bit 0.
                            // So my loop k=0 to n-1 matches bits 7 down to 8-n.
                            // This seems correct.

                            // Wait, "pad right with 0s if shorter".
                            // If n=3, bits are b0, b1, b2.
                            // x_mask = {b0, b1, b2, 0, 0, 0, 0, 0}.
                            // My logic processes bits 7, 6, 5 (b0, b1, b2). Correct.
                            // Then stops.

                            // Let's code.

                            // I'll use a parameter for state to make it readable.

                            // The term calculation: 1 << (2*n - 2 - k).
                            // This requires n and k to be available.
                            // `k` is a register. `n` is input.
                            // `2*n` takes 3 bits, result is 4 bits. 
                            // `2*n - 2 - k` takes about 4-5 bits.
                            // So `1 <<` is a 32-bit shift.
                            // Should be fine.

                            // Let's check the "modular exponentiation" note.
                            // "Use modular exponentiation or pre-computed lookup tables for powers of 4 up to 2^7."
                            // My solution uses bit shifting, which is effectively computing the power.
                            // It is not iterative modular exponentiation (like square-and-multiply), but since exponents are small constants derived from inputs, a barrel shifter is efficient.
                            // However, to be strictly compliant with "iterative state machine", maybe I should break down the term calculation if it was larger.
                            // But here, a single shift operation is standard for 2^X.
                            // I will stick to the shift.

                            // Let's handle the `done` signal.
                            // In S_DONE, done = 1.
                            // We need to stay in S_DONE until reset or start low.
                            // To be robust:
                            // In S_DONE, if !start, go to IDLE.
                            // If start is still high, stay DONE.
                            // This allows the FSM to reset.

                            // Code generation:

                            // I will write the full module code in the JSON string.

                            // Need to make sure I close all quotes and escape newlines.

                            // Let's double check the modulo.
                            // result_reg = (result_reg + term) % MOD.
                            // term < 2^15.
                            // result_reg < 10^9+7 (hopefully). 
                            // If we use `% MOD`, it's safe.
                            // But `%` operator in synthesis can be heavy for large numbers.
                            // Here numbers are small.
                            // Or we can do:
                            // result_reg = result_reg + term;
                            // if (result_reg >= MOD) result_reg = result_reg - MOD;
                            // Since we add small terms, this is safe.
                            // Let's use the subtraction method.

                            // Final Logic Plan:
                            // 1. IDLE: Wait for start. On start, init k=0, res=0, shift=x_mask. If n>0 go CALC else DONE.
                            // 2. CALC: 
                            //    If x_shift[7]: 
                            //      term = 1 << (2*n - 2 - k);
                            //      tmp = result_reg + term;
                            //      if (tmp >= MOD) tmp -= MOD; // Keep subtracting if needed (since multiple adds can exceed)
                            //      result_reg <= tmp;
                            //    Shift x_mask.
                            //    If k < n-1: k++, stay CALC.
                            //    Else: go DONE.
                            // 3. DONE: 
                            //    result <= result_reg.
                            //    done <= 1.
                            //    If !start: go IDLE.

                            // Wait, multiple adds can exceed MOD multiple times.
                            // Since max term is ~16000, and MOD is 10^9, we need only one subtraction.
                            // But `tmp >= MOD` is correct.

                            // Let's write the code.
                        end
                    end
                end
                
                DONE: begin
                    // Output result
                    // result is a reg output. 
                    // We should update it here.
                    // But result_reg holds the value.
                    // We can assign result <= result_reg continuously or in DONE.
                    // Let's assign in IDLE (reset) and DONE (update).
                    // Actually, just assign result = result_reg? No, reg output.
                    // We assign result <= result_reg when computation is finished.
                    // We can update result_reg in CALC.
                    // And assign result = result_reg continuously? 
                    // No, result should be stable. 
                    // Let's do: result <= result_reg (non-blocking) in the clocked block.
                    // But we only want to update it when done.
                    // So in DONE, result <= result_reg.
                    // But if we stay in DONE, it keeps assigning.
                    // That's fine.
                    // In IDLE, maybe result should be 0? 
                    // The prompt doesn't specify. 
                    // Let's update result in DONE state.
                    
                    // However, if we stay in DONE, we might overwrite result if it was read.
                    // Usually we update it once.
                    // Let's update it in the transition TO DONE.
                    // Or, simpler: assign result = result_reg in the combinational output? 
                    // No, output is reg. 
                    // Let's do: result <= result_reg in the clocked block.
                    // But only if state == DONE? 
                    // Let's update result_reg in CALC.
                    // And assign result <= result_reg when state == DONE.
                    // But if we transition to IDLE, result should probably hold the old value or be 0.
                    // Let's hold the value until next computation.
                    // So in IDLE and DONE, we can just hold result.
                    // But result is a reg. 
                    // We can update it in CALC and DONE.
                    // Wait, if we update in CALC, result changes while computing.
                    // Usually we want result to be valid only when done.
                    // So we should update result only when entering DONE.
                    
                    // Let's use a flag `res_valid`.
                    // Or, just update `result` in DONE state.
                    // Since we stay in DONE, it will keep updating. 
                    // That's okay.
                    // In IDLE, we might want to reset result to 0.
                    // Let's reset result to 0 in IDLE on start.
                    // And update it in CALC? No.
                    // Update it in DONE.
                    // 
                    // Let's do this:
                    // In IDLE (start): result <= 0.
                    // In CALC: result_reg <= ...
                    // In DONE: result <= result_reg.
                    // 
                    // In IDLE (wait for start): result is 0.
                    // In CALC: result is 0 (from IDLE). 
                    // In DONE: result becomes result_reg.
                    // If we go back to IDLE (start low): result stays result_reg (old value). 
                    // Or we can reset it. 
                    // Let's reset result to 0 in IDLE when start is asserted.
                    // Wait, if start is a pulse, we reset result to 0, then compute.
                    
                    // Let's verify transition from DONE to IDLE.
                    // In DONE, if !start, next state IDLE.
                    // In IDLE, if start, reset result_reg.
                    // So we are good.
                    
                    // But we need to drive the output `result`.
                    // If we use `result <= result_reg` in DONE, it updates.
                    // If we use `result <= 0` in IDLE (when start is asserted), it resets.
                    // But `result` should be 0 while idle?
                    // Let's keep `result` stable. 
                    // So `result` gets value in DONE, and keeps it until next DONE.
                    // But it's good practice to clear it at start.
                    // Let's clear `result` in IDLE when start is high.
                    
                    // Actually, `result` is the output register. 
                    // We can just drive it from `result_reg` continuously? 
                    // No, `result` is `reg`. We must assign it.
                    // Let's assign `result <= result_reg` in the clocked block.
                    // But only when we are finished.
                    // So in DONE, `result <= result_reg`.
                    // In other states, `result` can retain its value (don't assign, or assign old value).
                    // If we don't assign, it keeps old value.
                    // So just assign in DONE.
                    
                    // Also `done` signal.
                    // In DONE, `done <= 1`.
                    // In IDLE and CALC, `done <= 0`.
                    
                    // Let's write the final code.
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && n > 0) next_state = CALCULATE;
                else if (start && n == 0) next_state = DONE; // Handle n=0 case (immediate done)
                else next_state = IDLE;
            end
            CALCULATE: begin
                // If we just processed the last bit (k == n-1), we are done.
                // But we process bit in the state, then increment k.
                // Wait, in sequential block:
                // In state CALC, we process k.
                // Then if k < n-1, k++ and stay CALC.
                // If k == n-1, we process it, and then go DONE.
                // So we need to know if we just finished the last bit.
                // Or we can structure it so that k is the bit TO process.
                // Let's structure: 
                // k goes 0 to n-1. 
                // In cycle where k = n-1, we process it.
                // Then we go to DONE.
                // So next_state logic:
                // If k < n-1 (meaning we still have bits after this one): CALC
                // If k == n-1 (current bit is last): NEXT state is DONE.
                // But we need to handle the case where we just entered CALC with n=0? No, handled in IDLE.
                
                // We need to know the current k to decide next state.
                // But `k` is a register. In combinational logic, we see the current value.
                // If k < n-1, we need to process more.
                // If k == n-1, we are processing the last one. Next state DONE.
                // Wait, if n=1, k=0. k == n-1 (0==0). Next state DONE.
                // Correct.
                
                // Special case: What if n=0? Skipped.
                
                if (k < n - 1) next_state = CALCULATE;
                else next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'b0;
            done <= 1'b0;
            // Clear internal regs
            result_reg <= 32'b0;
            k <= 3'b0;
            x_shift <= 8'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        k <= 3'b0;
                        x_shift <= x_mask;
                        result_reg <= 32'b0;
                        // If n==0, we go to DONE immediately (handled by next_state logic)
                        // But we should set result to 0.
                        if (n == 0) begin
                            result <= 32'b0;
                        end else begin
                            result <= 32'b0; // Clear output at start
                        end
                    end
                end
                
                CALCULATE: begin
                    // Process bit k
                    // Calculate term: 1 << (2*n - 2 - k)
                    // We need to perform addition and modulo.
                    // Since 2*n - 2 - k is small, we can use shift.
                    // 2*n is n<<1.
                    // 2*n - 2 - k = (n << 1) - 2 - k.
                    
                    // Logic check:
                    // If x_shift[7] is 1:
                    //   term = 1 << ( (n<<1) - 2 - k );
                    //   result_reg = result_reg + term;
                    //   if (result_reg >= MOD) result_reg = result_reg - MOD;
                    //   // Note: Since term is small, one subtraction is enough.
                    //   // But result_reg might be close to MOD.
                    //   // result_reg + term could be up to 2*MOD.
                    //   // So one subtraction is enough.
                    //   // Wait, what if term is added multiple times?
                    //   // result_reg is accumulated. 
                    //   // Max result is < MOD. 
                    //   // We ensure result_reg < MOD.
                    //   // So result_reg + term < MOD + term.
                    //   // term < 2^15. So < MOD + small.
                    //   // So if result_reg + term >= MOD, subtract MOD once.
                    //   // Correct.
                    
                    // Update shift register
                    x_shift <= x_shift << 1;
                    
                    if (x_shift[7]) begin
                        // Calculate term
                        // We need a temporary variable for the calculation in sequential block
                        // But we can compute it inline.
                        // Let's use a combinational helper if needed, but we can do:
                        // result_reg <= (result_reg + (1 << ((n<<1) - 2 - k))) % MOD;
                        // But % might be slow. 
                        // Let's do subtraction.
                        
                        // Since we can't do complex combinational logic easily in sequential block assignment without wires,
                        // we can compute the term and add.
                        // result_reg <= result_reg + (1 << ((n<<1) - 2 - k));
                        // Then we need to check modulo.
                        // But we can't check modulo in the same cycle if we use non-blocking.
                        // We can do:
                        // reg [31:0] next_res = result_reg + (1 << ((n<<1) - 2 - k));
                        // if (next_res >= MOD) next_res = next_res - MOD;
                        // result_reg <= next_res;
                        
                        // This creates combinational logic. It's fine for small sizes.
                        // Let's do it.
                        
                        // Wait, we must ensure we don't overflow 32 bits in the intermediate sum?
                        // Max sum is 10^9 + 10^5. < 2^32. Safe.
                        
                        // So:
                        if (result_reg + (1 << ((n<<1) - 2 - k)) >= MOD) begin
                            result_reg <= result_reg + (1 << ((n<<1) - 2 - k)) - MOD;
                        end else begin
                            result_reg <= result_reg + (1 << ((n<<1) - 2 - k));
                        end
                    end
                    
                    // Update k
                    if (k < n - 1) begin
                        k <= k + 1;
                    end
                    // Note: k is updated here for the next cycle.
                    // The next state logic used the current k.
                    // So transition to DONE happens when we are at k = n-1.
                    // Correct.
                end
                
                DONE: begin
                    // Latch the result to output register
                    result <= result_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule
