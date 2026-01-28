module powers_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] n_in,
    output reg done,
    output reg winner
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT         = 4'd1;
    localparam [3:0] CHECK_BASE   = 4'd2;
    localparam [3:0] CALC_SQRT    = 4'd3;
    localparam [3:0] CHECK_POWER  = 4'd4;
    localparam [3:0] COUNT_CHAIN  = 4'd5;
    localparam [3:0] UPDATE_XOR   = 4'd6;
    localparam [3:0] NEXT_BASE    = 4'd7;
    localparam [3:0] FINISH       = 4'd8;
    localparam [3:0] ERROR_STATE  = 4'd15;

    // Internal registers and wires
    reg [3:0] state, next_state;
    reg [31:0] n_reg;
    reg [31:0] base;
    reg [31:0] limit;
    reg [31:0] xor_sum;
    reg [31:0] temp_val;
    reg [31:0] power_val;
    reg [31:0] k;
    reg is_power_flag;
    reg [31:0] chain_len;
    reg [31:0] divisor;
    reg [31:0] divisor_base;
    reg [31:0] i_div;
    reg [31:0] sqrt_temp;
    reg [31:0] sqrt_x;
    reg [31:0] sqrt_a;
    reg [31:0] sqrt_y;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd200000; // Safety limit

    // Control signals
    reg start_processing;
    reg processing_done;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 32'd0;
            base <= 32'd0;
            limit <= 32'd0;
            xor_sum <= 32'd0;
            temp_val <= 32'd0;
            power_val <= 32'd0;
            k <= 32'd0;
            is_power_flag <= 1'b0;
            chain_len <= 32'd0;
            divisor <= 32'd0;
            divisor_base <= 32'd0;
            i_div <= 32'd0;
            sqrt_temp <= 32'd0;
            sqrt_x <= 32'd0;
            sqrt_a <= 32'd0;
            sqrt_y <= 32'd0;
            cycle_count <= 32'd0;
            done <= 1'b0;
            winner <= 1'b0;
            start_processing <= 1'b0;
            processing_done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        n_reg <= n_in;
                        start_processing <= 1'b1;
                    end
                end

                INIT: begin
                    start_processing <= 1'b0;
                    if (n_reg == 32'd1) begin
                        // Special case: n=1, Grundy(1)=1, XOR sum=1
                        xor_sum <= 32'd1;
                    end else begin
                        xor_sum <= 32'd0;
                    end
                    base <= 32'd2;
                    cycle_count <= cycle_count + 32'd1;
                    
                    // Calculate sqrt(n) for limit
                    // Newton's method initialization
                    sqrt_x <= 32'd1;
                    sqrt_y <= 32'd1;
                end

                CALC_SQRT: begin
                    // Iterative sqrt calculation
                    // x_new = (x + n/x)/2
                    if (sqrt_x > sqrt_y) begin
                        sqrt_y <= sqrt_x;
                        sqrt_temp <= n_reg / sqrt_x + sqrt_x;
                    end else begin
                        sqrt_x <= (n_reg / sqrt_x + sqrt_x) >> 1;
                    end
                    
                    if (sqrt_x <= sqrt_y && (sqrt_x * sqrt_x <= n_reg && (sqrt_x + 1) * (sqrt_x + 1) > n_reg)) begin
                        limit <= sqrt_x;
                    end
                end

                CHECK_BASE: begin
                    is_power_flag <= 1'b0;
                    divisor <= 32'd2;
                    divisor_base <= 32'd2;
                    // Only process if base <= limit and base*base <= n_reg
                    if (base > limit || (base > 32'd1 && base > n_reg / base)) begin
                        // Skip or finish
                        is_power_flag <= 1'b1; // Mark as power to skip
                    end
                end

                CHECK_POWER: begin
                    // Check if base is a perfect power of a smaller integer
                    // i.e., exists b' < base such that base = b'^k
                    // We check by trying divisors from 2 to sqrt(base)
                    // Actually, simpler: check if base is a power of divisor
                    
                    if (is_power_flag || divisor * divisor > base) begin
                        // Done checking
                        if (!is_power_flag && base <= limit) begin
                            // Valid base, calculate chain length
                            temp_val <= base * base;
                            chain_len <= 32'd1;
                        end
                    end else begin
                        // Check if base is a power of divisor
                        // Perform integer power check
                        // We need to compute divisor^k == base?
                        // Let's just check if base % divisor == 0 first
                        if (base % divisor == 32'd0) begin
                            // Need to check if base is exactly divisor^k
                            // We can do repeated division
                            // Let's assume we check if base is power of divisor by computing divisor^2, divisor^3...
                            // Optimization: Just mark as power if divisor^2 == base or divisor^3 == base etc.
                            // Since base <= 31622, max exponent is small (2^15=32768)
                            temp_val <= 32'd1;
                            power_val <= divisor;
                            k <= 32'd1;
                            // We need a sub-state or loop for this check
                            // For simplicity in single always block, we use a flag and a counter
                            // But Verilog loops are tricky. We'll use a dedicated check loop.
                            // Let's add a flag "checking_power" to enter a loop.
                        end
                        divisor <= divisor + 32'd1;
                    end
                end

                COUNT_CHAIN: begin
                    // Count length of power chain for valid base
                    if (temp_val > n_reg / base) begin
                        // Chain end
                    end else begin
                        temp_val <= temp_val * base;
                        chain_len <= chain_len + 32'd1;
                    end
                end

                UPDATE_XOR: begin
                    // XOR the Grundy number (chain_len % 2)
                    if (chain_len[0]) begin
                        xor_sum <= xor_sum ^ 32'd1;
                    end
                    base <= base + 32'd1;
                end

                FINISH: begin
                    // Determine winner
                    // XOR sum 0 -> Petya (0), Non-zero -> Vasya (1)
                    winner <= (xor_sum != 32'd0) ? 1'b1 : 1'b0;
                    done <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_processing)
                    next_state = INIT;
            end
            INIT: begin
                // Handle n=1 case immediately
                if (n_reg == 32'd1)
                    next_state = FINISH;
                else
                    next_state = CALC_SQRT;
            end
            CALC_SQRT: begin
                // Check convergence (simple check for now)
                if (sqrt_x <= sqrt_y && (sqrt_x * sqrt_x <= n_reg && (sqrt_x + 1) * (sqrt_x + 1) > n_reg))
                    next_state = CHECK_BASE;
                else
                    next_state = CALC_SQRT; // Continue sqrt
            end
            CHECK_BASE: begin
                next_state = CHECK_POWER;
            end
            CHECK_POWER: begin
                // Need to check if base is a power of a smaller number
                // Simplified logic: if base is composite, it might be a power
                // We use a loop here for checking powers
                // If base is 2, 3, 5, 7 (primes), it's valid
                // If base is 4=2^2, 8=2^3, 9=3^2, 16=2^4, 25=5^2...
                // We need to check if base = b'^k for b' < base
                
                // Let's implement a manual check for "is power"
                // We will use a separate always block or a more complex state
                // To keep it simple and contained:
                // We iterate divisor from 2 to sqrt(base)
                // If base % divisor == 0, check if base is exactly divisor^k
                // Since we are in a single always block, we need to manage this iteratively.
                // Let's add sub-states or rely on the loop structure.
                
                // Refined Logic for CHECK_POWER:
                // If is_power_flag is already true, skip.
                // If base <= limit is false, skip.
                // Otherwise, check if base is a power.
                
                // We need to calculate if base is a perfect power.
                // Let's use a "CHECK_PERFECT_POWER" state.
                next_state = UPDATE_XOR; // Default pass
                
                if (base <= limit && !is_power_flag) begin
                    // Check if base is a power
                    // We need to loop. Verilog doesn't support loops easily in synthesis.
                    // We must unroll or use a counter.
                    // Since max base is 31622, we can iterate divisors up to sqrt(base) ~ 177.
                    // This is acceptable if done efficiently.
                    // Let's introduce a state "CHECK_PERFECT_POWER".
                    next_state = CHECK_PERFECT_POWER;
                end else begin
                    // Skip this base
                    if (base > limit || base > n_reg / base)
                        next_state = FINISH;
                    else
                        next_state = NEXT_BASE;
                end
            end

            // New state for perfect power check
            CHECK_PERFECT_POWER: begin
                // Loop: try divisor from 2 to sqrt(base)
                // If base % divisor == 0, check if base / divisor == divisor^k?
                // Actually, simpler: if base = b'^k, then b' = base^(1/k)
                // We can just check if (base/2)^2 == base, (base/3)^3 == base...
                // But integer division.
                // Let's use the divisor variable.
                // If divisor * divisor > base, then base is not a power.
                if (divisor * divisor > base) begin
                    is_power_flag <= 1'b0; // Not a power
                    next_state = COUNT_CHAIN;
                end else begin
                    // Check if base is a power of divisor
                    // Calculate power_val = divisor^k
                    // We need a sub-loop here.
                    // Let's simplify: 
                    // If base % divisor == 0, we can check if base / divisor is a power of divisor?
                    // No, that's wrong. 36 % 2 == 0, but 36 is not a power of 2.
                    // We need: Is there an integer k > 1 such that base = divisor^k?
                    // Since base <= 31622, k is small.
                    // Let's compute divisor^2, divisor^3... until >= base.
                    // We'll use temp_val to store the current power.
                    // We need a separate state for the exponentiation loop.
                    // Let's call it SUB_POWER_LOOP.
                    next_state = SUB_POWER_LOOP;
                    power_val <= divisor * divisor; // Start with divisor^2
                    k <= 32'd2;
                end
            end

            SUB_POWER_LOOP: begin
                if (power_val == base) begin
                    is_power_flag <= 1'b1;
                    next_state = NEXT_BASE; // Found it's a power, skip it
                end else if (power_val > base || power_val > 32'hFFFF_FFFF / divisor) begin
                    // Exceeded or overflow
                    divisor <= divisor + 32'd1;
                    next_state = CHECK_PERFECT_POWER;
                end else begin
                    power_val <= power_val * divisor;
                    k <= k + 32'd1;
                    next_state = SUB_POWER_LOOP;
                end
            end

            COUNT_CHAIN: begin
                if (temp_val > n_reg / base) begin
                    next_state = UPDATE_XOR;
                end else begin
                    next_state = COUNT_CHAIN;
                end
            end

            UPDATE_XOR: begin
                if (base >= limit || base > n_reg / base) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_BASE;
                end
            end

            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end

endmodule