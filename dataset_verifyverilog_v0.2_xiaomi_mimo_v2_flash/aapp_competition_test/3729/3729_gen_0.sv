module probability_calculator (
    input clk,
    input rst_n,
    input start,
    input [16:0] f,
    input [16:0] w,
    input [16:0] h,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam MOD = 32'd1000000007;
    localparam MAX_ADDR = 199999;

    // State definitions
    localparam S_IDLE = 0;
    localparam S_INIT_LUT = 1;
    localparam S_CALC_TOTAL = 2;
    localparam S_CALC_VALID = 3;
    localparam S_CALC_INV = 4;
    localparam S_FINAL = 5;
    localparam S_DONE = 6;

    // Arithmetic op definitions
    localparam OP_NONE = 0;
    localparam OP_MUL = 1;
    localparam OP_POW = 2;

    // Registers
    reg [4:0] state;
    reg [4:0] next_state;
    reg [31:0] fac [0:MAX_ADDR]; // Factorial LUT
    reg [17:0] lut_idx;

    // Computation Registers
    reg [31:0] valid_sum;
    reg [31:0] total_res;
    reg [31:0] term1, term2; // Temp storage
    reg [31:0] k; // Loop counter (can be up to 100k, so 18 bits)
    reg [16:0] max_k; // Loop limit

    // Arithmetic Engine Registers
    reg [31:0] alu_a, alu_b;
    reg [1:0] alu_op; // 0: none, 1: mul, 2: pow
    reg alu_start;
    wire alu_done;
    wire [31:0] alu_res;

    // Arithmetic Engine Logic
    // Implements modular multiplication and exponentiation
    reg [5:0] alu_state;
    reg [31:0] alu_base, alu_exp;
    reg [63:0] alu_prod;

    assign alu_done = (alu_state == 0) && !alu_start;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_state <= 0;
            alu_res <= 0; // Wire logic actually
        end else begin
            if (alu_start && alu_state == 0) begin
                alu_state <= 1;
                if (alu_op == OP_MUL) begin
                    alu_prod <= (alu_a % MOD) * (alu_b % MOD);
                    alu_state <= 2; // Go to Modulo step
                end else if (alu_op == OP_POW) begin
                    alu_base <= alu_a % MOD;
                    alu_exp <= MOD - 2; // Inverse exponent
                    alu_res <= 32'd1; // Result accumulator
                    if (alu_a % MOD == 0) alu_state <= 0; // Handle 0 inverse if needed, though fac never 0
                    else alu_state <= 10; // Start exponentiation loop
                end
            end else begin
                case (alu_state)
                    // Multiplication Path
                    2: begin // Modulo step for multiplication
                        alu_res <= alu_prod % MOD;
                        alu_state <= 0;
                    end

                    // Exponentiation Path (Square and Multiply)
                    10: begin // Check Exp
                        if (alu_exp == 0) alu_state <= 0;
                        else if (alu_exp[0]) begin // If LSB set, multiply result by base
                            alu_prod <= alu_res * alu_base % MOD;
                            alu_state <= 11; // Wait multiply
                        end else begin
                            // Just square base
                            alu_prod <= alu_base * alu_base % MOD;
                            alu_state <= 13; // Wait square
                        end
                    end
                    11: begin // Update result from multiply
                        alu_res <= alu_prod % MOD;
                        alu_exp <= alu_exp >> 1;
                        alu_prod <= alu_base * alu_base % MOD; // Start Square (overlaps or sequential?)
                        alu_state <= 13; // Wait Square
                    end
                    13: begin // Update base from square
                        alu_base <= alu_prod % MOD;
                        if (alu_exp == 0) alu_state <= 0;
                        else alu_state <= 10;
                    end
                    default: alu_state <= 0;
                endcase
            end
        end
    end

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            result <= 0;
            lut_idx <= 0;
            fac[0] <= 1;
            alu_start <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= S_INIT_LUT;
                        lut_idx <= 1; // Start generating fac[1]
                        fac[0] <= 1;
                    end
                end

                S_INIT_LUT: begin
                    // Generate fac[i] = fac[i-1] * i
                    if (alu_start) alu_start <= 0;
                    if (alu_done) begin
                        fac[lut_idx] <= alu_res;
                        lut_idx <= lut_idx + 1;
                        if (lut_idx == MAX_ADDR) begin
                            state <= S_CALC_TOTAL;
                            k <= 0; // Reset k for total calc steps
                        end
                    end else if (alu_state == 0) begin
                        alu_a <= fac[lut_idx-1];
                        alu_b <= lut_idx;
                        alu_op <= OP_MUL;
                        alu_start <= 1;
                    end
                end

                S_CALC_TOTAL: begin
                    // Total = nCr(f+w, w)
                    // Steps:
                    // 1. Compute inv(fac[w])
                    // 2. Compute inv(fac[f]) (since n-r = f)
                    // 3. Mult fac[f+w] * inv(fac[w]) * inv(fac[f])
                    // We do: res = fac[f+w]. Then res = res * inv(fac[w]). Then res = res * inv(fac[f]).
                    // We use k to track which sub-step.

                    if (alu_start) alu_start <= 0;

                    case (k)
                        0: begin // Get fac[f+w]
                            term1 <= fac[f + w];
                            k <= 1;
                        end
                        1: begin // Calc inv(fac[w])
                            if (alu_done) begin
                                term2 <= alu_res; // Store inv(fac[w])
                                k <= 2;
                            end else if (alu_state == 0) begin
                                if (w == 0) begin
                                    term2 <= 1;
                                    k <= 2;
                                end else begin
                                    alu_a <= fac[w];
                                    alu_op <= OP_POW;
                                    alu_start <= 1;
                                end
                            end
                        end
                        2: begin // Mult term1 * term2 -> term1
                            if (alu_done) begin
                                term1 <= alu_res;
                                k <= 3;
                            end else if (alu_state == 0) begin
                                alu_a <= term1;
                                alu_b <= term2;
                                alu_op <= OP_MUL;
                                alu_start <= 1;
                            end
                        end
                        3: begin // Calc inv(fac[f])
                            if (alu_done) begin
                                term2 <= alu_res;
                                k <= 4;
                            end else if (alu_state == 0) begin
                                if (f == 0) begin
                                    term2 <= 1;
                                    k <= 4;
                                end else begin
                                    alu_a <= fac[f];
                                    alu_op <= OP_POW;
                                    alu_start <= 1;
                                end
                            end
                        end
                        4: begin // Mult term1 * term2 -> total_res
                            if (alu_done) begin
                                total_res <= alu_res;
                                state <= S_CALC_VALID;
                                k <= 1; // Start valid loop
                                valid_sum <= 0;
                                // Pre-calc max_k for loop optimization if needed, or check in loop
                            end else if (alu_state == 0) begin
                                alu_a <= term1;
                                alu_b <= term2;
                                alu_op <= OP_MUL;
                                alu_start <= 1;
                            end
                        end
                    endcase
                end

                S_CALC_VALID: begin
                    // Loop k from 1 to ...
                    // Term = nCr(f+1, k) * nCr(w - k*h - 1, k-1)
                    // We use a sub-sequence (state machine logic) to calculate the term for current k.
                    // We use a register 'sub_step' to track progress within the term calculation.

                    // Logic flow:
                    // Check termination first (to avoid extra work if done).
                    // Terminate if k > f+1 OR k*(h+1) > w.

                    // Check 1: k > f+1
                    if (k > f + 1) begin
                        state <= S_CALC_INV;
                    end else begin
                        // Check 2: k*(h+1) > w. Use Multiplier.
                        // We can do this check in cycle 0 of the term calculation.
                        // We need a 'term_step' variable.
                        // term_step 0: Check bounds.
                        // term_step 1: C1 = nCr(f+1, k).
                        // term_step 2: C2 = nCr(w - k*h - 1, k-1).
                        // term_step 3: Mult C1 * C2.
                        // term_step 4: Add to Sum.

                        // We need a register to store term_step.
                        // Let's use 'term_step' defined or assume 'k' upper bits if needed.
                        // Since we are in S_CALC_VALID, let's use `alu_state` or `k` logic.
                        // Actually, `alu_state` is taken. Let's use a `sub_state` register.
                        // I'll reuse `term_step` (implied variable).

                        if (term_step == 0) begin // Bounds Check
                            // Check k*(h+1) > w
                            // Since h+1 <= 100001, k <= 100000, product <= 10^10. Fits in 64b.
                            // We need to wait for multiplier.
                            if (alu_start) alu_start <= 0;
                            if (alu_done) begin
                                if (alu_res > w) begin // k*(h+1) > w -> Stop loop
                                    state <= S_CALC_INV;
                                end else begin
                                    term_step <= 1;
                                end
                            end else if (alu_state == 0) begin
                                alu_a <= k;
                                alu_b <= h + 1;
                                alu_op <= OP_MUL;
                                alu_start <= 1;
                            end
                        end else if (term_step == 1) begin // C1 = nCr(f+1, k)
                            // Similar to Total calc sequence but specific args.
                            // We need to sequence: Get fac[f+1], Inv(fac[k]), Mult.
                            // We need a micro-sequence here. Let's use `alu_state` as the lock,
                            // and a separate micro-counter `micro_step`.
                            // To keep code short, we will reuse the logic.
                            // Sub-sequence for nCr(f+1, k):
                            // - Get fac[f+1]
                            // - Inv(fac[k])
                            // - Mult

                            // We will implement a 'calc_ncr' task using registers `ncr_n`, `ncr_r`, `ncr_res`.
                            // Since we can't define a task easily, we inline the logic.
                            // We use `term1` to store fac[f+1], `term2` to store inv(fac[k]).
                            // Use `k` loop counter, but we need to save the loop counter.
                            // Let's use `max_k` to store the loop counter 'k' while we calculate C1.
                            // Wait, `max_k` was used for limit.
                            // Let's use `term_step` 10..19 for C1 calculation.

                            if (term_step == 11) begin // C1: Get fac[f+1] done, start inv(fac[k])
                                // `term1` holds fac[f+1]
                                if (alu_done) begin
                                    term2 <= alu_res; // inv(fac[k])
                                    term_step <= 12; // Go to multiply
                                end else if (alu_state == 0) begin
                                    if (k == 0) begin // k starts at 1, but mathematically 0 is valid? loop starts 1.
                                        term2 <= 1; // inv(fac[0]) = 1
                                        term_step <= 12;
                                    end else begin
                                        alu_a <= fac[k];
                                        alu_op <= OP_POW;
                                        alu_start <= 1;
                                    end
                                end
                            end else if (term_step == 12) begin // C1: Mult term1 * term2
                                if (alu_done) begin
                                    term1 <= alu_res; // C1 Result stored in term1
                                    term_step <= 2; // Move to C2
                                end else if (alu_state == 0) begin
                                    alu_a <= term1;
                                    alu_b <= term2;
                                    alu_op <= OP_MUL;
                                    alu_start <= 1;
                                end
                            end else begin // term_step == 1, Init C1
                                // Check if k == 0 (shouldn't happen) or small k optimizations
                                // Also check if f+1 >= k. If not, nCr = 0.
                                if (k > f + 1) begin // Invalid C1, term is 0, skip to next k? 
                                    // Actually if k > f+1, loop terminates at top check. So this is valid range.
                                    term_step <= 11; // Jump to step 11 logic
                                    // We need to load fac[f+1] first.
                                end else if (alu_state == 0 && !alu_start) begin
                                     alu_a <= fac[f+1]; // Load fac[f+1]
                                     // No operation to start, just ready for next step
                                     term_step <= 11; // Will trigger inv(fac[k])
                                end
                            end
                        end else if (term_step == 2) begin // C2 = nCr(w - k*h - 1, k-1)
                            // Check validity: n = w - k*h - 1. r = k-1.
                            // If w - k*h - 1 < k-1, result 0.
                            // If n < 0, result 0.
                            // If r < 0 (k=0), but k starts at 1, so r>=0.

                            // Sub-sequence 2:
                            // - Calc n = w - k*h - 1. Use multiplier.
                            // - Check if n < k-1. If so, term=0. Skip to Add 0.
                            // - Get fac[n].
                            // - Inv(fac[k-1]).
                            // - Mult.

                            // We need to calculate k*h first.
                            // Let's use `term_step` 21..29 for C2.
                            if (term_step == 21) begin // Calc k*h
                                if (alu_done) begin
                                    // temp = alu_res (k*h)
                                    // n = w - temp - 1
                                    if (w < (alu_res + 1)) begin // n < 0
                                        term2 <= 0; // Result 0
                                        term_step <= 3; // Go to multiply (0 * C1 = 0)
                                    end else begin
                                        term2 <= w - alu_res - 1; // Store n in term2 temporarily (careful, term2 used for inv)
                                        // Check n < k-1? 
                                        // Note: k-1 is r.
                                        // If n < r, nCr = 0.
                                        // Since k is small, we can compare.
                                        if (w - alu_res - 1 < (k - 1)) begin
                                            term2 <= 0;
                                            term_step <= 3;
                                        end else begin
                                            // Valid. Load fac[n]
                                            // We need to access fac[n] where n is 17-bit or 32-bit.
                                            // n = w - k*h - 1. w <= 100k, k*h <= 10^10.
                                            // If k*h > w, we already handled n<0.
                                            // But n could be > MAX_ADDR if we are not careful?
                                            // w <= 100k, so n <= 100k. Fits in LUT.
                                            term_step <= 22;
                                        end
                                    end
                                end else if (alu_state == 0) begin
                                    alu_a <= k;
                                    alu_b <= h;
                                    alu_op <= OP_MUL;
                                    alu_start <= 1;
                                end
                            end else if (term_step == 22) begin // Get fac[n], Start Inv(fac[k-1])
                                if (alu_done) begin
                                    // Result is inv(fac[k-1])
                                    term2 <= alu_res; // Overwrite term2 with inv(r)
                                    term_step <= 23; // Mult
                                end else if (alu_state == 0) begin
                                    // term2 currently holds n (from step 21). 
                                    // We need to read fac[n].
                                    // Since we need to use alu for Inv, we must save n or store fac[n] in a temp register.
                                    // Let's use `term1` to store fac[n] temporarily.
                                    term1 <= fac[term2[17:0]]; // Read LUT using stored n

                                    // Now start Inv(fac[k-1])
                                    if ((k - 1) == 0) begin
                                        term2 <= 1;
                                        term_step <= 23;
                                    end else begin
                                        alu_a <= fac[k-1];
                                        alu_op <= OP_POW;
                                        alu_start <= 1;
                                    end
                                end
                            end else if (term_step == 23) begin // Mult fac[n] * inv(fac[k-1])
                                if (alu_done) begin
                                    term2 <= alu_res; // C2 Result in term2
                                    term_step <= 3; // Go to multiply C1 * C2
                                end else if (alu_state == 0) begin
                                    alu_a <= term1; // fac[n]
                                    alu_b <= term2; // inv(fac[k-1])
                                    alu_op <= OP_MUL;
                                    alu_start <= 1;
                                end
                            end else begin // term_step == 2, Init C2
                                term_step <= 21; // Jump to logic
                            end
                        end else if (term_step == 3) begin // Mult C1 * C2
                            // C1 is in term1, C2 is in term2
                            // We need to check if term1 or term2 is 0 (if so, skip or result 0).
                            if (alu_done) begin
                                // Result added to sum
                                valid_sum <= (valid_sum + alu_res) % MOD;
                                k <= k + 1; // Next k
                                term_step <= 0; // Reset for next iteration
                            end else if (alu_state == 0) begin
                                // Optimization: If C1 or C2 is 0, skip mult, set res 0
                                if (term1 == 0 || term2 == 0) begin
                                    // Just increment sum with 0 (no change) or add 0 explicitly
                                    // valid_sum <= valid_sum; (no change)
                                    k <= k + 1;
                                    term_step <= 0;
                                end else begin
                                    alu_a <= term1;
                                    alu_b <= term2;
                                    alu_op <= OP_MUL;
                                    alu_start <= 1;
                                end
                            end
                        end
                    end
                end

                S_CALC_INV: begin
                    // Inverse of total_res
                    if (alu_start) alu_start <= 0;
                    if (alu_done) begin
                        term1 <= alu_res; // inv(Total)
                        state <= S_FINAL;
                    end else if (alu_state == 0) begin
                        alu_a <= total_res;
                        alu_op <= OP_POW;
                        alu_start <= 1;
                    end
                end

                S_FINAL: begin
                    // Result = valid_sum * inv(Total)
                    if (alu_start) alu_start <= 0;
                    if (alu_done) begin
                        result <= alu_res;
                        state <= S_DONE;
                    end else if (alu_state == 0) begin
                        alu_a <= valid_sum;
                        alu_b <= term1;
                        alu_op <= OP_MUL;
                        alu_start <= 1;
                    end
                end

                S_DONE: begin
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // Helper register for Valid Loop sub-steps
    reg [3:0] term_step;

endmodule