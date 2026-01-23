module ramen_combinatorics (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // State Encodings
    localparam IDLE = 0;
    localparam PRECOMPUTE = 1;
    localparam CALCULATE_STIRLING = 2;
    localparam COMPUTE_SUM = 3;
    localparam DONE = 4;

    // Registers
    reg [4:0] state;
    reg [4:0] next_state;
    reg [4:0] i, j, k; // Loop counters
    reg [3:0] step;    // Sub-step counter
    
    // Storage
    reg [31:0] stirling [0:16][0:16];
    reg [31:0] pow2 [0:16];
    
    // Computation Registers
    reg [31:0] m_minus_1;
    reg [31:0] binom;
    reg [31:0] current_sum;
    reg [31:0] current_term; // General purpose
    reg [31:0] exp_val;      // Exponent counter/value
    reg [31:0] exp_pow;      // Exponentiation accumulator
    
    // Multiplication Registers
    reg [31:0] mult_a;
    reg [31:0] mult_b;
    wire [31:0] mult_res_wire;
    reg [31:0] mult_res_reg; // Stored result

    // Helper: Modular Multiplication
    // In Verilog, % operator is synthesizable but can be slow. 
    // For 32-bit * 32-bit, the result is 64-bit. We take % m.
    assign mult_res_wire = (mult_a * mult_b) % m;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            i <= 0; j <= 0; k <= 0;
            step <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        i <= 0; j <= 0; k <= 0;
                        step <= 0;
                        result <= 0;
                        done <= 0;
                        pow2[0] <= 1;
                        m_minus_1 <= m - 1;
                    end
                end

                PRECOMPUTE: begin
                    // Compute pow2 array: 2^i mod m for i=0..N
                    // Compute Stirling base case if needed or set here
                    if (step == 0) begin
                        if (i < n) begin
                            // pow2[i+1] = pow2[i] * 2
                            mult_a <= pow2[i];
                            mult_b <= 2;
                            step <= 1;
                        end else begin
                            // Done with pow2
                            stirling[0][0] <= 1;
                            step <= 0;
                        end
                    end else if (step == 1) begin
                        pow2[i+1] <= mult_res_wire;
                        i <= i + 1;
                        step <= 0;
                    end
                end

                CALCULATE_STIRLING: begin
                    // DP: S[n][k] = k*S[n-1][k] + S[n-1][k-1]
                    // Indices: n from 1 to N, k from 1 to n
                    // i = n, j = k
                    if (i <= n) begin
                        if (j <= i) begin
                            if (step == 0) begin // Init or check j=0
                                if (j == 0) begin
                                    stirling[i][0] <= 0;
                                    j <= j + 1;
                                end else begin
                                    // k * S[n-1][k]
                                    mult_a <= j;
                                    mult_b <= stirling[i-1][j];
                                    step <= 1;
                                end
                            end else if (step == 1) begin // Add S[n-1][k-1]
                                stirling[i][j] <= (mult_res_wire + stirling[i-1][j-1]) % m;
                                j <= j + 1;
                                step <= 0;
                            end
                        end else begin
                            i <= i + 1;
                            j <= 0;
                        end
                    end else begin
                        // Done
                        k <= 0;
                        binom <= 1; // C(n,0) = 1
                    end
                end

                COMPUTE_SUM: begin
                    // Loop k from 0 to N
                    if (k <= n) begin
                        case (step)
                            // Step 0: Calculate Stirling Sum for current k
                            // Sum_{i=1}^{k} S[k][i] * 2^i
                            0: begin
                                current_sum <= 0;
                                if (k == 0) begin
                                    step <= 4; // Skip sum, binom is 1, go to exp
                                end else begin
                                    i <= 1;
                                    step <= 1;
                                end
                            end
                            1: begin // Mult S[k][i] * 2^i
                                mult_a <= stirling[k][i];
                                mult_b <= pow2[i];
                                step <= 2;
                            end
                            2: begin // Accumulate
                                current_sum <= (current_sum + mult_res_wire) % m;
                                i <= i + 1;
                                step <= 3;
                            end
                            3: begin // Check Inner Loop
                                if (i <= k) step <= 1;
                                else step <= 4;
                            end

                            // Step 4: Calculate Binomial C(n,k)
                            // If k==0, already 1. Else: C(n,k) = C(n,k-1) * (n-k+1) * inv(k)
                            4: begin
                                if (k == 0) begin
                                    step <= 11; // Skip to exponentiation
                                end else begin
                                    // Calculate inv(k) = k^(m-2)
                                    // Setup exponentiation: base=k, exp=m-2, mod=m
                                    exp_val <= m_minus_1; // m-2 is exp, but we need m-2. m-1 is stored. Check logic.
                                    // Wait, m_minus_1 = m-1. We need m-2. 
                                    // If m=2, exp=0. 
                                    // exp_val <= (m > 2) ? m - 2 : 0;
                                    // But Fermat inv is a^(m-2). If m=2, inv(a)=a^0=1 (if a!=0).
                                    // Let's just use m-2.
                                    exp_val <= (m == 2) ? 0 : m - 2;
                                    exp_pow <= 1;
                                    current_term <= k; // Store base
                                    step <= 5;
                                end
                            end

                            // Modular Exponentiation (for inv(k))
                            5: begin // Check exp_val
                                if (exp_val > 0) begin
                                    if (exp_val[0]) begin
                                        mult_a <= exp_pow;
                                        mult_b <= current_term;
                                        step <= 6;
                                    end else begin
                                        step <= 8;
                                    end
                                end else begin
                                    // exp_pow is inv(k)
                                    // Now do binom * (n-k+1) * inv(k)
                                    // First: binom * (n-k+1)
                                    mult_a <= binom;
                                    mult_b <= n - k + 1;
                                    step <= 9;
                                end
                            end
                            6: begin // Update result
                                exp_pow <= mult_res_wire;
                                step <= 7;
                            end
                            7: begin // Square base
                                mult_a <= current_term;
                                mult_b <= current_term;
                                step <= 10; // Go to shift
                            end
                            8: begin // Skip mult, just square base
                                mult_a <= current_term;
                                mult_b <= current_term;
                                step <= 10;
                            end
                            10: begin // Store squared base, shift exp
                                current_term <= mult_res_wire;
                                exp_val <= exp_val >> 1;
                                step <= 5;
                            end
                            9: begin // Multiply by inv(k)
                                // mult_res is binom * (n-k+1)
                                mult_a <= mult_res_wire;
                                mult_b <= exp_pow;
                                step <= 10; // Wait, step 10 is used above. Need new step.
                                // Let's use step 12.
                            end
                            // Re-mapping step 9 to 12 to avoid collision
                            // 9 -> 12 (mult binom * (n-k+1))
                            // 12 -> 13 (mult result * inv(k))
                            // 13 -> 14 (store new binom)
                            // Then go to exp calc.
                            // Let's correct the flow:
                            // 9: mult_a=binom, mult_b=(n-k+1). step=12.
                            // 12: mult_a=prev_res, mult_b=inv(k). step=13.
                            // 13: binom=mult_res. step=14.
                            
                            // Code correction:
                            // In state 5, if exp_val=0, jump to 14.
                            // 14: Mult binom * (n-k+1). step=15.
                            // 15: Mult res * inv(k). step=16.
                            // 16: Store binom. step=11.
                            // Let's simplify: The exponentiation logic above sets `exp_pow` to inv(k).
                            // Then we need to update `binom`.
                            
                            14: begin // Start binom update
                                mult_a <= binom;
                                mult_b <= n - k + 1;
                                step <= 15;
                            end
                            15: begin // Mult by inv(k)
                                mult_a <= mult_res_wire;
                                mult_b <= exp_pow;
                                step <= 16;
                            end
                            16: begin // Store binom
                                binom <= mult_res_wire;
                                step <= 11;
                            end

                            // Step 11: Calculate 2^(2^(n-k))
                            11: begin
                                // First compute 2^(n-k).
                                // Since n-k <= 16, we can compute it in one go or loop.
                                // Let's compute 2^(n-k) first using shift.
                                exp_val <= n - k;
                                exp_pow <= 1;
                                step <= 17;
                            end
                            17: begin // Loop to get 2^(n-k)
                                if (exp_val > 0) begin
                                    exp_pow <= exp_pow << 1;
                                    exp_val <= exp_val - 1;
                                end else begin
                                    // exp_pow is 2^(n-k).
                                    // We need mod (m-1).
                                    // If exp_pow < m-1, keep. Else subtract.
                                    // Use subtraction loop or combinational.
                                    // Let's use combinational modulo for small value.
                                    // But we are in sequential. Let's use subtraction.
                                    // Or, we can just use `exp_pow % m_minus_1` if we synthesize a divider.
                                    // To be safe and generic, let's do subtraction loop.
                                    // `current_term` will hold the remainder.
                                    current_term <= exp_pow;
                                    step <= 18;
                                end
                            end
                            18: begin // Modulo (m-1) loop
                                if (current_term >= m_minus_1) begin
                                    current_term <= current_term - m_minus_1;
                                end else begin
                                    // current_term is now reduced exponent E1 = 2^(n-k) mod (m-1).
                                    // We need to compute 2^E1 mod m.
                                    // Setup exponentiation again.
                                    // Base = 2. Exp = current_term.
                                    exp_val <= current_term;
                                    exp_pow <= 1;
                                    current_term <= 2;
                                    step <= 19;
                                end
                            end
                            
                            // Final Exponentiation: 2^E1 mod m
                            19: begin
                                if (exp_val > 0) begin
                                    if (exp_val[0]) begin
                                        mult_a <= exp_pow;
                                        mult_b <= current_term;
                                        step <= 20;
                                    end else begin
                                        step <= 22;
                                    end
                                end else begin
                                    // exp_pow holds 2^(2^(n-k)) mod m.
                                    // Combine with current_sum and binom.
                                    // 1. binom * current_sum
                                    mult_a <= binom;
                                    mult_b <= current_sum;
                                    step <= 23;
                                end
                            end
                            20: begin // Mult result
                                exp_pow <= mult_res_wire;
                                step <= 21;
                            end
                            21: begin // Square base
                                mult_a <= current_term;
                                mult_b <= current_term;
                                step <= 22;
                            end
                            22: begin // Shift exp
                                current_term <= mult_res_wire;
                                exp_val <= exp_val >> 1;
                                step <= 19;
                            end
                            
                            // Final Accumulation
                            23: begin // binom * current_sum done
                                current_term <= mult_res_wire;
                                // Now mult by exp_pow
                                mult_a <= mult_res_wire;
                                mult_b <= exp_pow;
                                step <= 24;
                            end
                            24: begin // term is ready
                                current_term <= mult_res_wire;
                                // Check sign of k
                                if (k[0]) begin // Odd, subtract
                                    if (result < mult_res_wire) begin
                                        result <= result + m - mult_res_wire;
                                    end else begin
                                        result <= result - mult_res_wire;
                                    end
                                end else begin // Even, add
                                    result <= (result + mult_res_wire) % m;
                                end
                                // Next k
                                k <= k + 1;
                                step <= 0;
                            end
                        endcase
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = PRECOMPUTE;
            PRECOMPUTE: if (i >= n && step == 0) next_state = CALCULATE_STIRLING;
            CALCULATE_STIRLING: if (i > n) next_state = COMPUTE_SUM;
            // COMPUTE_SUM loops until k > n, handled inside
            DONE: next_state = DONE;
        endcase
        
        // Override for COMPUTE_SUM loop exit
        if (state == COMPUTE_SUM && k > n) next_state = DONE;
    end

endmodule