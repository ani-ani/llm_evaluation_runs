module calculation_module (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    input wire [15:0] m_in,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] MULTIPLY = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Constants
    localparam [31:0] MODULUS = 32'd1000000009;
    localparam [31:0] MAX_ITER = 32'd16;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [31:0] result_reg;
    reg [31:0] next_result;
    reg [31:0] p_val;
    reg [31:0] next_p_val;
    reg [31:0] term_val;
    reg [31:0] next_term_val;
    reg [15:0] i_cnt;
    reg [15:0] next_i_cnt;
    reg [15:0] n_reg;
    reg [15:0] next_n_reg;
    reg [31:0] mult_a;
    reg [31:0] mult_b;
    reg [63:0] mult_result;
    reg mult_start;
    reg mult_busy;
    reg mult_done;

    // Multiplier logic (combinational multiplication with modular reduction)
    always @(*) begin
        mult_result = mult_a * mult_b;
        // Manual division by MODULUS for 64-bit / 32-bit
        // Using long division algorithm
        mult_done = mult_busy;
    end

    // FSM State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 32'd0;
            p_val <= 32'd0;
            term_val <= 32'd0;
            i_cnt <= 16'd0;
            n_reg <= 16'd0;
            mult_a <= 32'd0;
            mult_b <= 32'd0;
            mult_busy <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            result_reg <= next_result;
            p_val <= next_p_val;
            term_val <= next_term_val;
            i_cnt <= next_i_cnt;
            n_reg <= next_n_reg;
            
            // Multiplier state update
            if (mult_start && !mult_busy) begin
                mult_busy <= 1'b1;
            end else if (mult_busy) begin
                mult_busy <= 1'b0;
            end

            // Result update when calculation is done
            if (state == FINISH) begin
                result <= result_reg;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Combination Logic for Next State and Outputs
    always @(*) begin
        // Default assignments
        next_state = state;
        next_result = result_reg;
        next_p_val = p_val;
        next_term_val = term_val;
        next_i_cnt = i_cnt;
        next_n_reg = n_reg;
        mult_start = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                // Calculate p = 2^m mod MODULUS
                if (m_in == 16'd0) begin
                    next_p_val = 32'd1;
                end else begin
                    next_p_val = (32'd1 << m_in);
                end
                
                // Handle subtraction underflow for (p - 1)
                if (next_p_val == 32'd0) begin
                    next_result = MODULUS - 32'd1;
                end else begin
                    next_result = next_p_val - 32'd1;
                end
                
                next_term_val = next_result; // Initial term = p-1
                next_i_cnt = 16'd0;
                next_n_reg = n_in;
                
                // Special cases
                if (n_in == 16'd0) begin
                    next_state = FINISH;
                    next_result = 32'd1;
                end else if (n_in == 16'd1) begin
                    // Result is already p-1
                    next_state = FINISH;
                end else begin
                    next_state = CALCULATE;
                end
            end

            CALCULATE: begin
                // term = (p - 1 - i) % MODULUS
                // Since i is small (<16), we can compute directly
                // But we need to handle the case where term might go negative if i > p-1
                // However, m >= 1 means p >= 2, so p-1 >= 1. 
                // For i up to 15, term stays positive unless p is very small.
                // Actually, problem says values 0 to 2^m-1, so m>=1 means 2^m >= 2.
                // If m=1, p=2, p-1=1. term for i=1 is 0.
                // term for i=2 would be -1, but loop stops at n-1.
                
                // We calculate term = (p - 1 - i_cnt) % MODULUS
                // Since i_cnt < 16, and p >= 2, term is usually positive.
                // Just subtract.
                if (i_cnt == 16'd0) begin
                    // term is already p-1
                    next_term_val = result_reg;
                end else begin
                    // term = previous_term - 1
                    if (term_val == 32'd0) begin
                        next_term_val = MODULUS - 32'd1;
                    end else begin
                        next_term_val = term_val - 32'd1;
                    end
                end

                // Check if loop is done (i from 0 to n-1)
                // We have already computed term for current i.
                // We need to multiply result by term.
                // Loop condition: i < n. 
                // If n=1, we are done immediately (handled in LOAD).
                // Here n >= 2.
                // Iteration 0: multiply by (p-1-0) -> i=0. Then i becomes 1.
                // Iteration 1: multiply by (p-1-1) -> i=1. Then i becomes 2.
                // ...
                // We stop when i_cnt == n_reg - 1. (We performed n-1 multiplications after the first one?)
                // Let's trace:
                // Result starts as (p-1). This corresponds to i=0.
                // We need to multiply by terms for i=1 to i=n-1.
                // Total multiplications = n-1.
                // i_cnt tracks how many multiplications we have done.
                // i_cnt starts at 0.
                // If i_cnt < (n_reg - 1), do multiplication.
                // If i_cnt == (n_reg - 1), we are done.

                if (i_cnt < (n_reg - 32'd1)) begin
                    // Prepare multiplication
                    mult_a = result_reg;
                    mult_b = next_term_val; // Use the newly calculated term
                    
                    // Check if term is 0
                    if (next_term_val == 32'd0) begin
                        next_result = 32'd0;
                        next_i_cnt = i_cnt + 32'd1;
                        // Check if this was the last iteration
                        if ((i_cnt + 32'd1) == (n_reg - 32'd1)) begin
                            next_state = FINISH;
                        end else begin
                            // Continue calculating
                            next_state = CALCULATE;
                        end
                    end else begin
                        // Start multiplier FSM or state
                        mult_start = 1'b1;
                        next_state = MULTIPLY;
                    end
                end else begin
                    // No more multiplications needed
                    next_state = FINISH;
                end
            end

            MULTIPLY: begin
                // Perform modulo multiplication
                // We do this in combinational logic within one cycle since values fit
                // result is 32 bit, term is 32 bit -> 64 bit product
                // modulus is 32 bit (approx 1e9)
                // 1e9 * 1e9 = 1e18. 64 bits can hold up to ~1.8e19.
                // So 64 bits is sufficient to hold full product.
                // We need (a * b) % MODULUS.
                
                // Manual Modulo Logic:
                // product_64 = mult_a * mult_b
                // result_32 = product_64 % MODULUS
                
                // Since MAX (1e9) * MAX (1e9) = 1e18, which is less than 2^60.
                // We can use a simple algorithm for division if we assume no hardware divider.
                // But for synthesis and speed, we use a simple loop or assumption.
                // Since this is a single cycle processing (conceptually), 
                // and 1e18 is within 64-bit range, we can use the '*' operator followed by modulo logic.
                // However, Icarus Verilog warning: '*' is synthesizable but complex division/modulo might not be.
                // But for standard synthesis tools, 64-bit modulo 32-bit is usually optimized.
                // To be safe and robust for Verilog/Icarus, let's use a simple subtraction loop.
                // But wait, 16 cycles max total. Doing a loop inside MULTIPLY state might exceed cycles.
                // Better to rely on standard synthesis for `result = (a * b) % MOD`.
                // We will assume the synthesis tool handles 64-bit modulo 32-bit correctly.
                // Or use the explicit subtraction logic for 1 cycle delay (unrolled).
                
                // Let's use a small unrolled loop for modulo reduction (max 1 iteration needed? No, max 1e18/1e9 = 1e9 iterations? No).
                // Wait, 1e18 / 1e9 = 1e9. That's too many.
                // BUT, we only need to do it once per input cycle (n <= 16).
                // The module has 16 cycles available. We must finish the multiplication and modulo in 1 cycle or very few.
                // If we rely on hardware divider, it's fine. If purely combinational logic without divider, we need a trick.
                // The problem says "Use a 32-bit width for calculations" but also "Use 33-34 bits for intermediate".
                // Usually, `(a * b) % M` is synthesized as a hardware divider if not optimized.
                // Since we have specific constraints and this is a benchmark, let's try a safe implementation.
                // Actually, for 64-bit modulo 32-bit, many tools can do this in one cycle if pipelined or using DSPs.
                // Let's write the standard modulo operation. 
                // If the synthesis target doesn't support large modulo, we might have issues.
                // Alternative: Use the fact that we might need to subtract multiple times.
                // But with 16 cycles total, we can't spend many cycles on one modulo.
                // Let's assume the synthesis tool handles `64bit_val % 32bit_mod` efficiently.
                // OR, we can use the property: (a * b) % m == ((a % m) * (b % m)) % m.
                // Inputs are already modulo m.
                // We will use the standard operator. Most commercial and open source tools (Yosys) handle this.
                
                next_result = (mult_a * mult_b) % MODULUS;
                next_i_cnt = i_cnt + 32'd1;
                
                if (next_i_cnt == (n_reg - 32'd1)) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALCULATE;
                end
            end

            FINISH: begin
                // Result is ready in result_reg (and output reg)
                // Wait for start to go low and reset state or idle
                // If start is still high, we might restart, but specification says start should remain low.
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule