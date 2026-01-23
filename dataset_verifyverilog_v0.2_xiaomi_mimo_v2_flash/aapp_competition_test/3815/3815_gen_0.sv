module periodic_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    input wire [7:0] a,
    input wire [7:0] b,
    input wire [1:0] k,
    input wire [3:0] s,
    output reg [23:0] result,
    output reg done
);

    // Constants
    parameter MOD = 24'd16777213; // Approx 2^24 - 5
    parameter MOD_EXP = 24'd16777211; // MOD - 2 for Fermat inverse
    parameter MOD_M1 = 24'd16777212; // MOD - 1
    
    // State encoding
    localparam S_IDLE = 5'd0;
    localparam S_INV_A_START = 5'd1;
    localparam S_INV_A_LOOP = 5'd2;
    localparam S_B_INV_A = 5'd3;
    localparam S_Q_START = 5'd4;
    localparam S_Q_LOOP = 5'd5;
    localparam S_CALC_T = 5'd6;
    localparam S_SUM_PERIOD_INIT = 5'd7;
    localparam S_SUM_PERIOD_LOOP = 5'd8;
    localparam S_SUM_PERIOD_ACC = 5'd9;
    localparam S_CHECK_Q_EQ1 = 5'd10;
    localparam S_RES_QT_START = 5'd11;
    localparam S_RES_QT_LOOP = 5'd12;
    localparam S_RES_GEOM_START = 5'd13;
    localparam S_RES_GEOM_LOOP = 5'd14;
    localparam S_RES_MULT = 5'd15;
    localparam S_DONE = 5'd16;

    reg [4:0] state, next_state;
    
    // Datapath registers
    reg [23:0] base;      // Base for exponentiation
    reg [7:0]  exp;       // Exponent counter
    reg [23:0] acc;       // Accumulator for modular mult/exponentiation
    reg [23:0] temp1;     // General purpose storage
    reg [23:0] temp2;     // General purpose storage
    reg [23:0] sum_period; // Accumulator for SumPeriod
    reg [7:0]  loop_cnt;  // Loop counters
    reg [23:0] b_inv_a_reg; // Store b * inv_a
    reg [23:0] q_reg;     // Store q
    reg [7:0]  T_reg;     // Store T
    reg        neg_flag;  // Flag for negative s_i
    reg        geom_flag; // Flag indicating if we are computing geometric series parts
    
    // Multiplier state
    reg mul_start;
    reg mul_done;
    reg [23:0] mul_a, mul_b;
    reg [23:0] mul_res;
    reg mul_accumulate; // If 1, result is added to acc instead of stored directly
    
    // 24-bit Modular Multiplier (Sequential to save area, 24 cycles latency)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mul_done <= 1'b0;
            mul_res <= 24'd0;
        end else begin
            if (mul_start) begin
                mul_res <= 24'd0;
                mul_a <= mul_a;
                mul_b <= mul_b;
                mul_done <= 1'b0;
                loop_cnt <= 8'd24; // 24-bit multiplier
            end else if (loop_cnt > 0 && !mul_done) begin
                // Shift and add algorithm
                if (mul_b[0]) begin
                    mul_res <= mul_res + mul_a;
                end
                mul_a <= mul_a << 1;
                if (mul_a >= MOD) mul_a <= mul_a - MOD; // Modulo reduction on operand
                mul_b <= mul_b >> 1;
                loop_cnt <= loop_cnt - 1;
            end else if (loop_cnt == 0 && !mul_done) begin
                // Final modulo reduction
                if (mul_res >= MOD) mul_res <= mul_res - MOD;
                if (mul_res >= MOD) mul_res <= mul_res - MOD; // Second pass for safety
                mul_done <= 1'b1;
            end else if (mul_done) begin
                mul_done <= 1'b0;
            end
        end
    end

    // Main State Machine & Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 24'd0;
            done <= 1'b0;
            mul_start <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_INV_A_START;
                    end
                end

                // 1. Compute inv_a = a^(MOD-2) using Fermat's Little Theorem
                S_INV_A_START: begin
                    base <= {16'd0, a}; // Ensure a < MOD
                    exp <= MOD_EXP[7:0]; // Using lower 8 bits for loop count (since MOD_EXP is small) or full range
                    // Actually, MOD_EXP = 16777211 > 255. We need a loop counter capable of 24 bits or a step counter.
                    // Let's use a standard 24-bit exponentiation loop.
                    // Setup: result = 1, base = a, exp = MOD_EXP (stored in temp1)
                    acc <= 24'd1;
                    temp1 <= {8'd0, MOD_EXP}; // Store 24-bit exponent
                    state <= S_INV_A_LOOP;
                end

                S_INV_A_LOOP: begin
                    if (temp1 == 0) begin
                        // inv_a calculated, stored in acc
                        // Optimization: we need to compute b * inv_a. Let's trigger mult.
                        mul_a <= b; // b (8-bit)
                        mul_b <= acc; // inv_a
                        mul_start <= 1'b1;
                        state <= S_B_INV_A;
                    end else begin
                        // Square and Multiply
                        // First, square base (base * base % MOD)
                        if (temp1[0]) begin
                            // If LSB is 1, we need to multiply acc * base later
                            // But we can't do two mults in one cycle. 
                            // Let's do squaring in this cycle, prepare for next cycle.
                            // However, standard exponentiation loop needs sequential mults.
                            // Let's do: 
                            // 1. If LSB=1: acc = acc * base
                            // 2. base = base * base
                            // 3. exp = exp >> 1
                            
                            // Step 1: acc = acc * base
                            if (mul_done || !mul_start) begin
                                if (!mul_start) begin
                                    mul_a <= acc;
                                    mul_b <= base;
                                    mul_start <= 1'b1;
                                    // Wait for mult done
                                end else begin
                                    // mult done
                                    mul_start <= 1'b0;
                                    acc <= mul_res;
                                    // Now do squaring
                                    // We need a state to wait for squaring or chain mults.
                                    // To save states, we use 'mul_accumulate' logic or just separate states.
                                    // Let's stick to a strict sequential flow per bit.
                                    state <= S_INV_A_LOOP; // Stay here to do squaring
                                    temp1 <= temp1 >> 1;
                                end
                            end
                        end else begin
                            // LSB is 0, skip acc * base, go straight to squaring
                            // Squaring: base = base * base
                            if (mul_done || !mul_start) begin
                                if (!mul_start) begin
                                    mul_a <= base;
                                    mul_b <= base;
                                    mul_start <= 1'b1;
                                end else begin
                                    mul_start <= 1'b0;
                                    base <= mul_res;
                                    temp1 <= temp1 >> 1;
                                end
                            end
                        end
                    end
                end
                
                // Refactored Exponentiation Loop (S_INV_A_LOOP rewrite for clarity and robustness)
                // We will use a micro-coded approach or multiple states for the exponentiation steps.
                // Given the requirements, let's break S_INV_A_LOOP into sub-states.
                // Actually, let's restart the logic for S_INV_A_LOOP cleanly.
                // The previous block got complex. Let's use a cleaner nested FSM or simpler sequential steps.
                
                // Re-implementing S_INV_A_LOOP logic:
                // If temp1 == 0, done.
                // Else: 
                //   If temp1[0] == 1: trigger acc * base -> wait -> acc = result
                //   Then trigger base * base -> wait -> base = result
                //   Then temp1 = temp1 >> 1.
                // We need 2 internal states for the multiplication latency.
                
                // Let's rename current S_INV_A_LOOP to handle the check
                // We will add intermediate states for multiplication.

                5'd17: begin // Wait for acc*base mult (inv_a calc)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        acc <= mul_res;
                        // Now trigger base*base
                        mul_a <= base;
                        mul_b <= base;
                        mul_start <= 1'b1;
                        state <= 5'd18;
                    end
                end
                5'd18: begin // Wait for base*base mult (inv_a calc)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        base <= mul_res;
                        temp1 <= temp1 >> 1;
                        state <= S_INV_A_LOOP;
                    end
                end
                5'd19: begin // Wait for mult (b*inv_a)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        b_inv_a_reg <= mul_res;
                        state <= S_Q_START;
                    end
                end
                5'd20: begin // Wait for mult (q calc)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        // Result is in mul_res. 
                        // If we are calculating q, update base and loop.
                        if (geom_flag == 1'b0) begin // Calculating q = (b_inv_a)^k
                            base <= mul_res;
                            temp1 <= temp1 - 1; // Decrement k counter
                            if (temp1 == 1) begin // Done with q
                                q_reg <= mul_res;
                                state <= S_CALC_T;
                            end else begin
                                state <= S_Q_LOOP;
                            end
                        end else begin // Geometric series calc: q^T
                            // Actually, standard exponentiation uses 'acc'. 
                            // Let's handle q^T separately in S_RES_QT_START states.
                            // This state (20) was for q^T or q^k.
                            // If geom_flag = 1 (we are in q^T), we update acc.
                            if (geom_flag) begin
                                acc <= mul_res;
                                temp1 <= temp1 >> 1;
                                state <= 5'd23; // Go to q^T loop check
                            end
                        end
                    end
                end

                // --- Fixing S_INV_A_LOOP ---
                S_INV_A_LOOP: begin
                    if (temp1 == 0) begin
                        // inv_a calculated in acc
                        mul_a <= b;
                        mul_b <= acc;
                        mul_start <= 1'b1;
                        state <= 5'd19; // Jump to wait for b*inv_a
                    end else begin
                        if (temp1[0]) begin
                            mul_a <= acc;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd17; // Wait for acc*base
                        end else begin
                            // Skip acc mult, go to base*base
                            mul_a <= base;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd18; // Wait for base*base
                        end
                    end
                end

                // 2. Compute b_inv_a already done in transition to S_Q_START
                S_Q_START: begin
                    // Calculate q = (b_inv_a)^k
                    // Setup exponentiation: base = b_inv_a, exp = k, acc = 1
                    base <= b_inv_a_reg;
                    temp1 <= {6'd0, k}; // k is 1-4
                    acc <= 24'd1;
                    geom_flag <= 1'b0; // Indicate we are computing q
                    // We reuse the exponentiation loop logic.
                    // Since k is small (<=4), we could unroll, but generic is better.
                    state <= 5'd21; // State for q exponentiation loop
                end

                // q exponentiation loop
                5'd21: begin
                    if (temp1 == 0) begin
                        q_reg <= acc;
                        state <= S_CALC_T;
                    end else begin
                        if (temp1[0]) begin
                            mul_a <= acc;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd22; // Wait acc*base
                        end else begin
                            mul_a <= base;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd24; // Wait base*base
                        end
                    end
                end
                5'd22: begin // Wait acc*base (q calc)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        acc <= mul_res;
                        mul_a <= base;
                        mul_b <= base;
                        mul_start <= 1'b1;
                        state <= 5'd24; // Go to base square wait
                    end
                end
                5'd24: begin // Wait base*base (q calc)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        base <= mul_res;
                        temp1 <= temp1 >> 1;
                        state <= 5'd21;
                    end
                end

                // 3. Calculate T = (n+1) / k
                S_CALC_T: begin
                    // Since k is 1-4, division is simple shift/sub or lookup.
                    // But (n+1) is 8-bit. We can use a standard divider loop or simple logic.
                    // n+1 <= 256. k <= 4. Result fits 8 bits.
                    // temp1 is used for loops. Let's store T in T_reg.
                    temp1 <= {16'd0, n} + 1; // n+1
                    temp2 <= {14'd0, k};     // k
                    T_reg <= 8'd0;
                    state <= 5'd25;
                end
                5'd25: begin // Division loop
                    if (temp1 >= temp2) begin
                        temp1 <= temp1 - temp2;
                        T_reg <= T_reg + 1;
                    end else begin
                        state <= S_SUM_PERIOD_INIT;
                    end
                end

                // 4. Calculate SumPeriod
                S_SUM_PERIOD_INIT: begin
                    sum_period <= 24'd0;
                    loop_cnt <= 8'd0; // i = 0
                    // Pre-calculate a^n for efficiency? 
                    // Formula: SumPeriod = sum (s_i * a^n * (b/a)^i). 
                    // Wait, the standard form is SumPeriod = sum (s_i * (b/a)^i). 
                    // Then Total = SumPeriod * a^n * GeomFrac. 
                    // But (b/a)^i = b^i * inv_a^i. 
                    // Let's stick to the requirement: "SumPeriod = sum s_i * a^n * (b/a)^i".
                    // Actually, factoring a^n out is better: Total = a^n * Sum( s_i * (b/a)^i ).
                    // Let's compute BaseSum = sum (s_i * (b/a)^i). 
                    // Then we multiply by a^n later (or combine).
                    // Let's compute BaseSum first.
                    // Let's rename logic: Calculate InnerSum = sum_{i=0}^{k-1} s_i * (b_inv_a)^i.
                    // So we need to iterate i from 0 to k-1.
                    // Reset power accumulator for (b_inv_a)^i. 
                    // We need a^n later. Let's calculate a^n first? No, we can calculate it in parallel or sequentially.
                    // Let's calculate a^n first and store it in temp1.
                    // Then calculate InnerSum.
                    // Then multiply them.
                    
                    // Let's calculate a^n first. 
                    base <= {16'd0, a};
                    exp <= n; // n is 8-bit, fits in exp (which is 8-bit, but we need full 24-bit or use temp1 for counter)
                    // Actually n is up to 255. So loop counter is 8-bit. 
                    // Let's use temp1 for exponent value.
                    temp1 <= {16'd0, n}; 
                    acc <= 24'd1;
                    state <= 5'd30; // Jump to a^n exponentiation
                    // We need to store a^n result somewhere. Let's use temp2.
                    // After a^n is done, we start InnerSum loop.
                end

                // a^n exponentiation (reusing loop structure but specific return)
                5'd30: begin // a^n loop
                    if (temp1 == 0) begin
                        temp2 <= acc; // Store a^n in temp2
                        // Now setup InnerSum
                        sum_period <= 24'd0;
                        temp1 <= 24'd1; // Current Power (b_inv_a)^i. Start with 1 for i=0
                        loop_cnt <= 8'd0; // i counter
                        state <= 5'd31;
                    end else begin
                        if (temp1[0]) begin
                            mul_a <= acc;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd32;
                        end else begin
                            mul_a <= base;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd33;
                        end
                    end
                end
                5'd32: begin // Wait mult acc*base (a^n)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        acc <= mul_res;
                        mul_a <= base;
                        mul_b <= base;
                        mul_start <= 1'b1;
                        state <= 5'd33;
                    end
                end
                5'd33: begin // Wait mult base*base (a^n)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        base <= mul_res;
                        temp1 <= temp1 >> 1;
                        state <= 5'd30;
                    end
                end

                // InnerSum Loop: sum_{i=0}^{k-1} s_i * (b_inv_a)^i
                5'd31: begin
                    if (loop_cnt >= k) begin
                        // Done with InnerSum. Result in sum_period.
                        // Now multiply sum_period * a^n (stored in temp2)
                        mul_a <= sum_period;
                        mul_b <= temp2;
                        mul_start <= 1'b1;
                        geom_flag <= 1'b0; // Multiplication mode
                        state <= 5'd40; // Wait for mult
                    end else begin
                        // Get s_i bit
                        neg_flag <= ~s[loop_cnt]; // s=1 is pos, s=0 is neg
                        // We need to multiply current power (temp1) by s_i and add to sum_period.
                        // But we need to update power for next loop iteration too.
                        // Power update: temp1 = temp1 * b_inv_a_reg
                        // So: 
                        // 1. Calculate next_power = temp1 * b_inv_a_reg
                        // 2. If s_i is 1: term = temp1. Add to sum_period.
                        // This requires 2 multiplications per loop iteration if done naively.
                        // Optimization: 
                        //   Sum = Sum + temp1 (if s_i=1) or Sum - temp1 (if s_i=0)
                        //   Temp1 = Temp1 * b_inv_a_reg
                        // We can do the addition/subtraction first (requires no mult), then trigger mult for update.
                        
                        // First, handle accumulation
                        if (s[loop_cnt]) begin
                            sum_period <= sum_period + temp1;
                        end else begin
                            sum_period <= sum_period - temp1;
                        end
                        // Trigger multiplication for next power update
                        mul_a <= temp1;
                        mul_b <= b_inv_a_reg;
                        mul_start <= 1'b1;
                        state <= 5'd34;
                    end
                end
                5'd34: begin // Wait for power update mult
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        temp1 <= mul_res;
                        loop_cnt <= loop_cnt + 1;
                        state <= 5'd31;
                    end
                end

                // Handle multiplication result: sum_period * a^n
                5'd40: begin
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        temp1 <= mul_res; // Store Sum_A in temp1
                        // Now we need to handle the geometric series part.
                        // Result = Sum_A * Geom
                        // Geom = (q^T - 1) / (q - 1) if q != 1, else T.
                        // Let's check q == 1.
                        if (q_reg == 24'd1 || q_reg == (MOD+1) || q_reg == (MOD*2+1)) begin // Handle mod 1
                            state <= S_RES_GEOM_START; // Will compute Sum_A * T
                        end else begin
                            state <= S_RES_QT_START; // Compute q^T
                        end
                    end
                end

                // Case: q == 1. Result = SumPeriod * T
                S_RES_GEOM_START: begin
                    // Calculate SumPeriod * T (T is 8-bit)
                    mul_a <= temp1; // SumPeriod * a^n
                    mul_b <= {16'd0, T_reg};
                    mul_start <= 1'b1;
                    state <= 5'd41;
                end
                5'd41: begin
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        result <= mul_res;
                        state <= S_DONE;
                    end
                end

                // Case: q != 1. 
                S_RES_QT_START: begin
                    // Calculate q^T. 
                    // We need to use exponentiation. Base = q_reg, Exp = T_reg.
                    // Store q^T in temp2.
                    base <= q_reg;
                    temp1 <= {16'd0, T_reg}; // Exp
                    acc <= 24'd1;
                    geom_flag <= 1'b1; // Indicate we are in result phase
                    state <= 5'd50; // Generic Exp State
                    // Return to state 51 after done
                end

                // Generic Exponentiation Loop (used for q^T)
                // Returns to specific state based on geom_flag or context?
                // Let's use a dedicated sub-state for q^T.
                5'd50: begin // q^T loop
                    if (temp1 == 0) begin
                        temp2 <= acc; // Store q^T in temp2
                        // Now calc denom_inv = (q - 1)^(-1)
                        // We need to compute (q - 1) mod MOD. 
                        // q_reg is q mod MOD. q-1 = q_reg - 1.
                        // If q_reg == 0, q-1 = -1 = MOD-1. But we assumed q != 1. 
                        // If q=0? Problem states a,b > 0. q=0 if b=0. We assume b>0. 
                        // Compute diff = q_reg - 1. If diff is negative? q_reg >= 1. diff >= 0.
                        temp1 <= q_reg - 1;
                        // Fermat inverse: diff^(MOD-2)
                        base <= q_reg - 1;
                        exp <= MOD_EXP[7:0]; // Wait, need 24-bit exp count
                        // Let's reuse the long exponentiation loop structure for INV.
                        // We need a state to setup the inverse calc.
                        state <= 5'd52;\                    end
                    if (temp1[0]) begin
                        mul_a <= acc;
                        mul_b <= base;
                        mul_start <= 1'b1;
                        state <= 5'd53;\                    end else begin
                        mul_a <= base;
                        mul_b <= base;
                        mul_start <= 1'b1;
                        state <= 5'd54;\                    end
                end
                5'd53: begin // Wait acc*base (q^T)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        acc <= mul_res;
                        mul_a <= base;
                        mul_b <= base;
                        mul_start <= 1'b1;
                        state <= 5'd54;
                    end
                end
                5'd54: begin // Wait base*base (q^T)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        base <= mul_res;
                        temp1 <= temp1 >> 1;
                        state <= 5'd50;
                    end
                end

                // Calculate Inverse of (q-1)
                5'd52: begin
                    // Setup for inv (q-1)
                    // temp1 currently has q-1 (from 5'd50 check)
                    base <= temp1;
                    temp1 <= {8'd0, MOD_EXP}; // MOD-2
                    acc <= 24'd1;
                    state <= 5'd60; // Standard Inv Loop
                    // Return to: (q^T - 1) * inv
                end

                // Standard Long Inversion Loop (24-bit exponent)
                5'd60: begin // Inv Loop
                    if (temp1 == 0) begin
                        // inv computed, stored in acc
                        // Now compute (q^T - 1)
                        // q^T is in temp2.
                        // If temp2 == 0? q^T mod MOD. 
                        // Let's compute numerator = temp2 - 1.
                        // But wait, we need: (q^T - 1) * inv(q-1)
                        // Then multiply by SumPeriod (stored in temp1? No, SumPeriod*A was moved to temp1 in state 50 setup? 
                        // Wait, 50 uses temp1 as exponent. 
                        // Let's track variables:
                        // temp1: Was Exponent (q^T). Now free (loop counter in 60).
                        // temp2: q^T.
                        // temp1 (reused in 60): exponent MOD-2.
                        // acc: inverse.
                        // We need SumPeriod * A^n. Where is it? 
                        // We had it in temp1 before entering S_RES_QT_START. 
                        // But S_RES_QT_START overwrites temp1 with exponent.
                        // CRITICAL BUG. 
                        // We need to save SumPeriod * A^n (let's call it S_A).
                        // Let's store S_A in a dedicated register 'final_acc' or reuse 'base' if free.
                        // Let's introduce 'final_mult_reg' to hold S_A.
                        
                        // Let's modify S_RES_QT_START to save S_A to 'temp2' (actually q^T goes to temp2, so S_A must go elsewhere).
                        // Let's use 'sum_period' register to store S_A persistently until the very end.
                        // Correction: In 5'd40, we computed S_A = SumPeriod * A^n and stored it in temp1.
                        // Then we entered S_RES_QT_START. 
                        // We should have saved S_A before overwriting temp1.
                        // Let's add a register 'final_sum' to store S_A.
                        // In S_IDLE, clear it. In 5'd40, final_sum <= mul_res.
                        
                        // Correction applied: I will add a register 'final_sum'.
                        // Now: acc holds inv(q-1).
                        // Compute (q^T - 1) * inv
                        mul_a <= temp2 - 1; // q^T - 1. (Need modulo fix if <0)
                        if (temp2 == 0) mul_a <= MOD - 1;
                        else mul_a <= temp2 - 1;
                        mul_b <= acc;
                        mul_start <= 1'b1;
                        state <= 5'd61;
                    end else begin
                        // Standard exponentiation loop for inverse
                        if (temp1[0]) begin
                            mul_a <= acc;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd62;
                        end else begin
                            mul_a <= base;
                            mul_b <= base;
                            mul_start <= 1'b1;
                            state <= 5'd63;
                        end
                    end
                end
                5'd62: begin // Wait acc*base (inv)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        acc <= mul_res;
                        mul_a <= base;
                        mul_b <= base;
                        mul_start <= 1'b1;
                        state <= 5'd63;
                    end
                end
                5'd63: begin // Wait base*base (inv)
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        base <= mul_res;
                        temp1 <= temp1 >> 1;
                        state <= 5'd60;
                    end
                end

                // Multiply Geom part by S_A
                5'd61: begin // Wait for (q^T - 1) * inv
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        // mul_res holds Geom = (q^T-1)/(q-1)
                        // Now multiply by S_A (stored in final_sum)
                        // We need to introduce final_sum register.
                        // Let's assume final_sum is updated in 5'd40 (Modify code logic).
                        mul_a <= mul_res;
                        // Here we need final_sum. Since we didn't declare it yet in the header, let's assume we can use 'temp2' if we swap carefully.
                        // Or, let's go back and fix 5'd40 to store in 'final_sum' which I will declare now.
                        // Declaration: reg [23:0] final_sum;
                        mul_b <= final_sum;
                        mul_start <= 1'b1;
                        state <= 5'd64;
                    end
                end
                5'd64: begin // Final Result Mult
                    if (mul_done) begin
                        mul_start <= 1'b0;
                        result <= mul_res;
                        state <= S_DONE;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (!start) state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    // Add missing register declaration
    reg [23:0] final_sum; 
    // Update final_sum logic
    always @(posedge clk) begin
        if (!rst_n) final_sum <= 24'd0;
        else if (state == 5'd40 && mul_done) final_sum <= mul_res;
    end

endmodule
