module sum_even_factors(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CHECK_ODD   = 3'd1;
    localparam [2:0] FACTORIZE   = 3'd2;
    localparam [2:0] COMPUTE_SUM  = 3'd3;
    localparam [2:0] CALC_RESULT  = 3'd4;
    localparam [2:0] DONE_STATE   = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] n_reg;
    reg [15:0] m;              // Odd part after removing powers of 2
    reg [4:0] k;               // Power of 2 count (0-16)
    reg [31:0] factor_sum;     // Sum of factors of m
    reg [31:0] power_sum;      // Sum of powers: 2 + 2^2 + ... + 2^k
    reg [15:0] divisor;        // Trial divisor
    reg [15:0] temp_num;       // Working copy of m
    reg [31:0] multiplier;     // Intermediate multiplier
    reg [3:0] prime_idx;       // Prime index (0-7)
    reg [2:0] exponent;        // Exponent of current prime
    reg [31:0] cycle_count;    // Cycle counter
    reg [7:0] max_cycles;      // Max cycles for safety
    reg [31:0] pow_result;     // Power computation
    reg [15:0] pow_base;       // Base for power
    reg [4:0] pow_exp;         // Exponent for power
    
    // Helper: Find first power of 2 dividing n
    reg [4:0] temp_k;
    reg [15:0] temp_n;
    
    // For factorization loop
    reg [15:0] loop_limit;
    reg found_divisor;
    reg [15:0] quotient;
    
    // Temporary for geometric series
    reg [31:0] geom_sum;
    
    // Cycle limit
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            n_reg <= 16'd0;
            m <= 16'd0;
            k <= 5'd0;
            factor_sum <= 32'd0;
            power_sum <= 32'd0;
            divisor <= 16'd0;
            temp_num <= 16'd0;
            multiplier <= 32'd0;
            prime_idx <= 4'd0;
            exponent <= 3'd0;
            cycle_count <= 32'd0;
            max_cycles <= 8'd0;
            pow_result <= 32'd0;
            pow_base <= 16'd0;
            pow_exp <= 5'd0;
            temp_k <= 5'd0;
            temp_n <= 16'd0;
            loop_limit <= 16'd0;
            found_divisor <= 1'b0;
            quotient <= 16'd0;
            geom_sum <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        n_reg <= n;
                        state <= CHECK_ODD;
                    end
                end

                CHECK_ODD: begin
                    // Check if n is odd (n[0] == 1)
                    if (n_reg[0] == 1'b1) begin
                        result <= 32'd0;
                        state <= DONE_STATE;
                    end else begin
                        // Find powers of 2: n = 2^k * m
                        temp_n <= n_reg;
                        temp_k <= 5'd0;
                        state <= FACTORIZE;
                    end
                end

                FACTORIZE: begin
                    // Step 1: Find k and extract m
                    if (temp_n[0] == 1'b0 && temp_n != 16'd0) begin
                        temp_n <= temp_n >> 1;
                        temp_k <= temp_k + 5'd1;
                    end else begin
                        // Found k and m
                        k <= temp_k;
                        m <= temp_n;  // m is now odd
                        
                        // Step 2: Compute sum of factors of m (odd number)
                        // Initialize factor_sum = 1 (every number has factor 1)
                        factor_sum <= 32'd1;
                        temp_num <= temp_n;  // Working copy
                        divisor <= 16'd3;    // Start with 3
                        prime_idx <= 4'd0;
                        cycle_count <= cycle_count + 32'd1;
                        
                        if (temp_n == 16'd1) begin
                            // m = 1, factor_sum = 1
                            state <= COMPUTE_SUM;
                        end else begin
                            state <= FACTORIZE;  // Continue with trial division
                        end
                    end
                end

                FACTORIZE: begin
                    // Trial division for factorization
                    // Check if divisor * divisor > temp_num
                    if (divisor * divisor > temp_num || divisor > 16'd256) begin
                        // Remaining temp_num is prime (or 1)
                        if (temp_num > 16'd1) begin
                            // Multiply factor_sum by (1 + temp_num)
                            multiplier <= factor_sum * (32'd1 + {16'd0, temp_num});
                            state <= COMPUTE_SUM;
                        end else begin
                            state <= COMPUTE_SUM;
                        end
                    end else if (temp_num % divisor == 16'd0) begin
                        // Found divisor
                        exponent <= 3'd0;
                        quotient <= temp_num;
                        found_divisor <= 1'b1;
                        state <= FACTORIZE;  // Stay to process this divisor
                    end else begin
                        // Move to next odd divisor
                        divisor <= divisor + 16'd2;
                        cycle_count <= cycle_count + 32'd1;
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= DONE_STATE;  // Safety timeout
                        end
                    end
                end

                FACTORIZE: begin
                    // Process exponent for current divisor
                    if (found_divisor) begin
                        if (quotient % divisor == 16'd0) begin
                            quotient <= quotient / divisor;
                            exponent <= exponent + 3'd1;
                            state <= FACTORIZE;
                        end else begin
                            // Compute geometric series: 1 + p + p^2 + ... + p^exponent
                            // Start power computation
                            pow_base <= divisor;
                            pow_exp <= exponent;
                            pow_result <= 32'd1;  // Start with 1
                            state <= FACTORIZE;   // Continue to power computation
                        end
                    end else begin
                        divisor <= divisor + 16'd2;
                        cycle_count <= cycle_count + 32'd1;
                        state <= FACTORIZE;
                    end
                end

                FACTORIZE: begin
                    // Power computation loop
                    if (pow_exp > 5'd0) begin
                        pow_result <= pow_result * {16'd0, pow_base};
                        pow_exp <= pow_exp - 5'd1;
                        state <= FACTORIZE;
                    end else begin
                        // Multiply factor_sum by power result
                        multiplier <= factor_sum * pow_result;
                        found_divisor <= 1'b0;
                        divisor <= divisor + 16'd2;
                        temp_num <= quotient;
                        cycle_count <= cycle_count + 32'd1;
                        state <= FACTORIZE;
                    end
                end

                COMPUTE_SUM: begin
                    // Update factor_sum if multiplier is set
                    if (multiplier != 32'd0) begin
                        factor_sum <= multiplier;
                        multiplier <= 32'd0;
                    end
                    
                    // Compute geometric series: 2 + 2^2 + ... + 2^k
                    // = 2^(k+1) - 2
                    // Start from 2^0 = 1, compute 2^k+1 then subtract 2
                    if (k > 5'd0) begin
                        geom_sum <= 32'd1;  // Start at 2^0
                        pow_exp <= k + 5'd1;  // k+1 iterations
                        state <= COMPUTE_SUM;
                    end else begin
                        // k=0, no even factors (but n is even, so this shouldn't happen)
                        power_sum <= 32'd0;
                        state <= CALC_RESULT;
                    end
                end

                COMPUTE_SUM: begin
                    // Compute 2^(k+1)
                    if (pow_exp > 5'd0) begin
                        geom_sum <= geom_sum * 32'd2;
                        pow_exp <= pow_exp - 5'd1;
                        state <= COMPUTE_SUM;
                    end else begin
                        // Now geom_sum = 2^(k+1)
                        // Subtract 2 to get sum: 2 + 2^2 + ... + 2^k
                        power_sum <= geom_sum - 32'd2;
                        state <= CALC_RESULT;
                    end
                end

                CALC_RESULT: begin
                    // Result = factor_sum * power_sum
                    result <= factor_sum * power_sum;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule