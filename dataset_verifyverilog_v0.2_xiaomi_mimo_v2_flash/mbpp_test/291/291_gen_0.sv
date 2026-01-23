module fence_painter(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    output reg [29:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b001;
    localparam CALC_BASE = 3'b010;
    localparam CALC_LOOP = 3'b100;
    // DONE state implicitly handled by 'done' signal staying high in IDLE or explicitly
    // We will use a separate state for clarity or handle via flags.
    // Let's use a state for DONE to hold the result as requested.
    localparam DONE = 3'b000; // Map to unused combination or manage explicitly
    // Actually, let's use specific states
    localparam S_IDLE = 3'b000;
    localparam S_BASE = 3'b001;
    localparam S_LOOP = 3'b010;
    localparam S_FINISH = 3'b011;

    reg [2:0] state;
    
    // Constants
    wire [31:0] MOD = 32'd1000000007;
    
    // Loop counter
    reg [3:0] i;
    
    // DP registers (dp[i-1] and dp[i-2])
    reg [31:0] dp_prev; // dp[i-2]
    reg [31:0] dp_curr; // dp[i-1]
    reg [31:0] dp_next; // dp[i]
    
    // Calculation registers
    reg [31:0] sum;
    reg [31:0] mul_lhs;
    reg [31:0] mul_res;
    
    // Multiplier/MAC logic
    // Since k is small (max 8), (k-1) is small.
    // We need to compute (k-1) * (dp[i-1] + dp[i-2]) % MOD
    // We can do this in cycles or combo. To meet timing and be simple, let's use combo logic for math
    // but update registers on clock edge.
    
    // State transition and DP update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 30'd0;
            done <= 1'b0;
            dp_curr <= 32'd0;
            dp_prev <= 32'd0;
            i <= 4'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (n == 4'd0) begin
                            result <= 30'd0;
                            done <= 1'b1;
                            // Stay in IDLE or go to DONE. Spec says hold in DONE.
                            // Let's go to a state that holds done high.
                            state <= S_FINISH;
                        end else if (n == 4'd1) begin
                            // dp[1] = k
                            // Need to handle k=0 case? k is colors, assume k >= 1 for valid fence. 
                            // If k=0, result is 0. If k > MOD, we need mod. But k max 8.
                            result <= k[29:0]; // k fits in 30 bits
                            done <= 1'b1;
                            state <= S_FINISH;
                        end else if (n == 4'd2) begin
                            // dp[2] = k * k
                            // k max 8, so k*k fits in 30 bits (64)
                            result <= (k * k);
                            done <= 1'b1;
                            state <= S_FINISH;
                        end else begin
                            // n >= 3. Start calculation.
                            // Initialize dp[1] = k, dp[2] = k*k
                            dp_prev <= k;          // This will act as dp[i-2] for i=3. Wait.
                                                    // For i=3, we need dp[1] and dp[2].
                                                    // Let's set dp_prev = dp[1] = k
                                                    // dp_curr = dp[2] = k*k
                            dp_curr <= (k * k);
                            i <= 3'd3;             // Current index to compute
                            state <= S_BASE;       // Use S_BASE to compute or just jump to S_LOOP
                        end
                    end
                end
                
                S_BASE: begin
                    // This state acts as a setup or immediate transition for n>=3
                    // We actually have the values ready for the first iteration (i=3)
                    // So we can just go to S_LOOP
                    state <= S_LOOP;
                end

                S_LOOP: begin
                    // Compute dp[i] = (k-1) * (dp[i-1] + dp[i-2]) mod MOD
                    // Inputs: dp_prev = dp[i-2], dp_curr = dp[i-1], k
                    
                    // Logic calculation (combinational)
                    // We perform the calculation here in the sequential block to be explicit,
                    // or use intermediate variables. Let's do it step by step.
                    
                    // 1. Sum = dp_prev + dp_curr
                    // 2. Mul = (k-1) * Sum
                    // 3. Modulo
                    
                    // Using intermediate combinational logic is cleaner, but for strict requirements
                    // of synthesizable block, we can compute inside.
                    // Since k is small, multiplication is cheap.
                    // We must take mod 1000000007.
                    
                    // Let's calculate sum
                    // Note: dp_prev and dp_curr are already modulo MOD, so sum < 2*MOD (approx 2e9)
                    // 32 bits are enough.
                    
                    // Pipeline or single cycle? 
                    // n is max 8. 8 cycles allowed. We can do it in 1 cycle per iteration.
                    
                    // Temporary calculation
                    // We must handle modulo 1000000007.
                    // Because (k-1) is small (max 7), we can do: 
                    // temp = (dp_prev + dp_curr) % MOD;
                    // result = ((k-1) * temp) % MOD;
                    
                    // Check for overflow in multiplication? 
                    // (2*MOD) * 7 approx 1.4e10. Max 32-bit is 4.29e9.
                    // 1.4e10 > 2^32. So we cannot simply multiply then modulo in 32 bits.
                    // We need to do modulo after addition, then multiply, then modulo.
                    // But actually, (k-1)*(dp_prev+dp_curr) max is 7 * 2e9 = 1.4e10.
                    // We can use a 34-bit register to be safe.
                    
                    // Let's use an explicit combinational calculation or do it in stages.
                    // To keep it simple and robust:
                    // Sum = dp_prev + dp_curr
                    // If Sum >= MOD, Sum = Sum - MOD. 
                    // Then dp_next = ((k-1) * Sum) % MOD.
                    // But ((k-1)*Sum) might overflow 32 bits. 
                    // We can use 64-bit variable in simulation, but for hardware:
                    // We can calculate modulo using property: (A*B)%M.
                    // Since k-1 is small, we can check if ((k-1)*Sum >= MOD).
                    // Max (k-1)*Sum = 7 * (2*MOD) approx 1.4e10.
                    // 1.4e10 / 1e9 = 14. So we need to subtract MOD up to 13 times? 
                    // Or use 34-35 bit arithmetic.
                    
                    // Let's use 35-bit intermediate.
                    wire [34:0] sum_val = dp_prev + dp_curr;
                    wire [34:0] mod_sum = (sum_val >= MOD) ? (sum_val - MOD) : sum_val;
                    wire [34:0] mul_val = mod_sum * (k - 1);
                    wire [31:0] next_dp_val = mul_val % MOD; // This division/modulo is expensive in hardware but standard for such constraints or small mod.
                    
                    // Note: Verilog % operator is synthesizable but can be slow for large numbers.
                    // However, modulo 1000000007 is prime and specific. 
                    // For the specific constraint of n<=8, this is acceptable.
                    // Alternatively, we can iteratively subtract, but 1 cycle is fine.
                    
                    dp_next <= next_dp_val;
                    
                    // Update pointers for next iteration
                    // dp[i] becomes dp_curr (for next i+1), dp[i-1] becomes dp_prev (for next i+1)
                    // New state: dp_prev_new = dp_curr_old, dp_curr_new = dp_next_new
                    
                    if (i < n) begin
                        // Shift registers
                        dp_prev <= dp_curr;
                        dp_curr <= next_dp_val;
                        i <= i + 1;
                        state <= S_LOOP;
                    end else begin
                        // Done with loop
                        // Result is dp_next (which is dp[n])
                        // But wait, if n=3, we computed dp[3] in this cycle.
                        // i starts at 3. Condition i < n.
                        // If n=3, i=3. 3 < 3 is false. We go to else.
                        // result should be dp_next.
                        result <= next_dp_val[29:0];
                        done <= 1'b1;
                        state <= S_FINISH;
                    end
                end

                S_FINISH: begin
                    // Hold result and done high until reset
                    done <= 1'b1;
                    // result is already saved
                    // Stay here until reset
                    if (!rst_n) begin
                        state <= S_IDLE;
                    end else begin
                        state <= S_FINISH;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule