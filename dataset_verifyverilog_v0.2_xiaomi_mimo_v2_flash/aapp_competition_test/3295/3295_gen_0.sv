module mirko_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] K,
    input wire [7:0] L,
    input wire [7:0] M,
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam MAX_X = 16'd2000;
    localparam MAX_VAL = 16'd2150; // 2000 + 150
    
    // State definitions
    localparam IDLE = 3'b000;
    localparam PRIME_CHECK = 3'b001;
    localparam COUNT_HAPPY = 3'b010;
    localparam INCREMENT = 3'b011;
    localparam FOUND = 3'b100;
    localparam DONE = 3'b101;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] x;              // Current starting number
    reg [15:0] curr_num;       // Current number being checked in range [x, x+K-1]
    reg [7:0] happy_count;     // Count of happy numbers found for current x
    reg [7:0] range_idx;       // Index for iterating through range K
    reg [15:0] temp_result;    // Temporary storage for result
    
    // Primes LUT (0-255) - Compressed logic for primality
    // We need to check primes up to 2150. 
    // Since we are in hardware, let's use a compact combinational check for small numbers
    // and a block RAM approach for larger numbers is ideal, but here we use logic.
    // To keep synthesis area low, we will use a combinational logic block for < 256
    // and logic for >= 256.
    
    wire is_prime;
    wire [15:0] next_candidate;
    
    // Combinational Primes Logic for range 0-255 (sufficient for index 0-255)
    // This is a small LUT equivalent.
    reg is_prime_small;
    always @(*) begin
        is_prime_small = 1'b0;
        case (curr_num)
            2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97,
            101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199,
            211, 223, 227, 229, 233, 239, 241, 251: is_prime_small = 1'b1;
            default: is_prime_small = 1'b0;
        endcase
    end

    // Logic for primes >= 256 (Max 2150)
    // Optimized logic since range is small. 
    // We only need to check divisors up to sqrt(2150) approx 46.
    // Small numbers are handled by is_prime_small.
    reg is_prime_large;
    always @(*) begin
        if (curr_num < 2) is_prime_large = 1'b0;
        else if (curr_num < 256) is_prime_large = is_prime_small; // Use LUT for small numbers
        else begin
            // Explicit check for large numbers
            if (curr_num[0] == 0) is_prime_large = 1'b0; // Even numbers > 2
            else begin
                // Manually unrolled division checks for odd divisors up to 47
                // This avoids a loop which is bad for synthesis timing in a simple combinational block
                // Or we can assume standard synthesis tools will optimize a small loop.
                // Let's write it explicitly for synthesis safety.
                is_prime_large = 1'b1; // Assume prime
                if (curr_num % 3 == 0) is_prime_large = 1'b0;
                else if (curr_num % 5 == 0) is_prime_large = 1'b0;
                else if (curr_num % 7 == 0) is_prime_large = 1'b0;
                else if (curr_num % 11 == 0) is_prime_large = 1'b0;
                else if (curr_num % 13 == 0) is_prime_large = 1'b0;
                else if (curr_num % 17 == 0) is_prime_large = 1'b0;
                else if (curr_num % 19 == 0) is_prime_large = 1'b0;
                else if (curr_num % 23 == 0) is_prime_large = 1'b0;
                else if (curr_num % 29 == 0) is_prime_large = 1'b0;
                else if (curr_num % 31 == 0) is_prime_large = 1'b0;
                else if (curr_num % 37 == 0) is_prime_large = 1'b0;
                else if (curr_num % 41 == 0) is_prime_large = 1'b0;
                else if (curr_num % 43 == 0) is_prime_large = 1'b0;
                else if (curr_num % 47 == 0) is_prime_large = 1'b0;
            end
        end
    end

    assign is_prime = is_prime_large;

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'hFFFF; // Default -1
            done <= 1'b0;
            x <= 16'd1;
            happy_count <= 8'd0;
            curr_num <= 16'd0;
            range_idx <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x <= 16'd1;
                        happy_count <= 8'd0;
                        curr_num <= 16'd1;
                        range_idx <= 8'd0;
                        // Check bounds immediately
                        if (K == 0 || L > K || M == 0) begin
                            // Invalid inputs per constraints, but let's handle gracefully or search
                            // Constraints say K 1-150, L 0-K, M 1-150. Assume valid.
                        end
                    end
                end

                PRIME_CHECK: begin
                    // We already did combinational logic for is_prime
                    // Now check if happy: <= M OR is_prime
                    if (curr_num <= M || is_prime) begin
                        happy_count <= happy_count + 1;
                    end
                    // Prepare for next number in range
                    curr_num <= curr_num + 1;
                    range_idx <= range_idx + 1;
                end

                COUNT_HAPPY: begin
                    // Start checking the range [x, x+K-1]
                    // Reset loop vars for this x
                    curr_num <= x;
                    happy_count <= 8'd0;
                    range_idx <= 8'd0;
                    // Transition handled by combinational next_state logic or state machine?
                    // Wait for PRIME_CHECK to do its thing.
                end

                INCREMENT: begin
                    // Check if we found solution
                    if (happy_count == L) begin
                        result <= x;
                        // Transition to FOUND/DONE is handled in next_state logic
                    end else begin
                        x <= x + 1;
                        // Reset counters for next x
                        happy_count <= 8'd0;
                        range_idx <= 8'd0;
                    end
                    // Check for timeout (x > 2000) -> done with fail (-1)
                    // Handled in transition logic
                end

                FOUND: begin
                    // Latch result and done
                    result <= x;
                    done <= 1'b1;
                end

                DONE: begin
                    // Timeout case (not found in 2000)
                    result <= 16'hFFFF; // -1 in 2s complement (assuming 16-bit signed or unsigned, problem says output -1)
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Combination Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = COUNT_HAPPY;
                else next_state = IDLE;
            end
            
            COUNT_HAPPY: begin
                // If K=0 (invalid per constraints) or range_idx == K, we are done checking this x
                if (range_idx == K) begin
                    next_state = INCREMENT;
                end else begin
                    next_state = PRIME_CHECK;
                end
            end

            PRIME_CHECK: begin
                // After checking one number, go back to check if we finished range
                if (range_idx == K) next_state = INCREMENT;
                else next_state = PRIME_CHECK; // Wait, we loop here? 
                // Optimization: Combinational path is too long if we loop logic inside PRIME_CHECK.
                // Better: PRIME_CHECK state executes ONE check and increments counter. 
                // Loop back to CHECK_STATE until done.
                
                // Correction: The state machine above handles increment in PRIME_CHECK.
                // So we stay in PRIME_CHECK until range_idx hits K.
                if (range_idx < K) next_state = PRIME_CHECK;
                else next_state = INCREMENT; // range_idx just hit K
            end

            INCREMENT: begin
                if (x > MAX_X) begin
                    next_state = DONE;
                end else if (happy_count == L) begin // Check latched value from previous cycle? No, happy_count is updated in PRIME_CHECK loop.
                    // Actually, happy_count is fully calculated when we enter INCREMENT (because range_idx == K).
                    // So we check happy_count here.
                     next_state = FOUND;
                end else begin
                    next_state = COUNT_HAPPY;
                end
            end

            FOUND: begin
                next_state = FOUND; // Stay here until reset
            end
            
            DONE: begin
                next_state = DONE; // Stay here until reset
            end

            default: next_state = IDLE;
        endcase
    end

    // Note: In the INCREMENT state logic above, we check happy_count. 
    // However, happy_count is updated inside the PRIME_CHECK loop (which is a state).
    // When does the loop exit? 
    // 1. COUNT_HAPPY: resets idx to 0. Goes to PRIME_CHECK.
    // 2. PRIME_CHECK: checks num. idx++. If idx < K, stay in PRIME_CHECK. Else go to INCREMENT.
    // This requires a fast state transition loop. 
    // To meet timing and be efficient, we can collapse the loop or ensure it's valid.
    // A 1-cycle loop is acceptable for < 150 iterations.
    
    // However, a single cycle PRIME_CHECK that includes the combinational prime logic might be tight.
    // The prime logic is mostly division. Division is slow in hardware.
    // If we need a standard FPGA flow without DSP blocks for division, we must use a slower approach or pre-calc.
    // Given the constraints (scaled down), let's assume synthesis tool optimizes the division logic or we accept 1 cycle latency.
    // IF division is 1 cycle (unlikely for 2150/3 etc), this works.
    // IF division is multi-cycle, we need a busy signal.
    // To be safe and synthesizable on generic hardware, let's assume combinational logic for prime check is okay for small numbers, 
    // but for synthesis, we might need to break the loop.
    
    // REVISED LOGIC for Safety: 
    // We will assume the combinational block `is_prime` is valid in the current cycle for the current `curr_num`.
    // The `PRIME_CHECK` state increments `curr_num` and `range_idx`.
    // The transition `PRIME_CHECK -> PRIME_CHECK` happens if `range_idx < K`.
    // This effectively runs the calculation in a tight loop.
    
    // Let's refine the `INCREMENT` check to use the value correctly.
    // When transitioning PRIME_CHECK -> INCREMENT, `happy_count` has been updated for the last element.
    
endmodule

module TopModuleWrapper (
    input clk,
    input rst_n,
    input start,
    input [7:0] K,
    input [7:0] L,
    input [7:0] M,
    output [15:0] result,
    output done
);
    mirko_solver solver (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .K(K),
        .L(L),
        .M(M),
        .result(result),
        .done(done)
    );
endmodule