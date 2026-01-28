module sum_even_factors(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [31:0] result,
    output reg done
);
    
    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CALC_POW2 = 4'd1;
    localparam [3:0] FACTORIZE = 4'd2;
    localparam [3:0] COMPUTE_SUM = 4'd3;
    localparam [3:0] DONE_STATE = 4'd4;
    
    reg [3:0] state, next_state;
    
    // Internal registers
    reg [15:0] m; // Odd part after removing factors of 2
    reg [4:0] k; // Power of 2
    reg [31:0] factor_sum; // Sum of all factors of m
    reg [31:0] series_sum; // 2^(k+1) - 2
    reg [7:0] i; // Loop counter for factorization
    reg [7:0] j; // Loop counter for exponent
    reg [15:0] temp; // Temporary storage
    reg [15:0] divisor; // Current divisor
    reg [4:0] exponent; // Exponent count
    reg [31:0] power_sum; // Sum of powers (1 + p + p^2 + ...)
    reg [7:0] cycle_count; // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Pre-computed odd primes (first 8)
    reg [15:0] primes [0:7];
    integer idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            m <= 16'd0;
            k <= 5'd0;
            factor_sum <= 32'd0;
            series_sum <= 32'd0;
            i <= 8'd0;
            j <= 8'd0;
            temp <= 16'd0;
            divisor <= 16'd0;
            exponent <= 5'd0;
            power_sum <= 32'd0;
            cycle_count <= 8'd0;
            
            // Initialize primes array
            primes[0] <= 16'd3;
            primes[1] <= 16'd5;
            primes[2] <= 16'd7;
            primes[3] <= 16'd11;
            primes[4] <= 16'd13;
            primes[5] <= 16'd17;
            primes[6] <= 16'd19;
            primes[7] <= 16'd23;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                cycle_count = 8'd0;
                if (start) begin
                    next_state = CALC_POW2;
                end
            end
            
            CALC_POW2: begin
                // Calculate highest power of 2 dividing n
                if (n[0] == 1'b0) begin
                    // n is even
                    temp = n >> 1;
                    k = k + 5'd1;
                    if (temp[0] == 1'b0) begin
                        n = temp;
                    end else begin
                        m = temp;
                        next_state = FACTORIZE;
                    end
                end else begin
                    // n is odd
                    m = n;
                    k = 5'd0;
                    next_state = FACTORIZE;
                end
                cycle_count = cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end
            
            FACTORIZE: begin
                // Initialize factor_sum to 1 (for factor 1)
                if (i == 8'd0) begin
                    factor_sum = 32'd1;
                    i = 8'd1; // Start from first prime index
                end else begin
                    // Check if we've processed all primes
                    if (i < 8'd8) begin
                        divisor = primes[i];
                        
                        // Check if divisor^2 > m (end condition)
                        if (divisor * divisor > m) begin
                            // Add remaining m if > 1
                            if (m > 16'd1) begin
                                factor_sum = factor_sum * (32'd1 + m);
                            end
                            next_state = COMPUTE_SUM;
                        end else begin
                            // Count exponent of current divisor
                            exponent = 5'd0;
                            temp = m;
                            j = 8'd0;
                            
                            // Count how many times divisor divides m
                            while (j < 8'd16 && temp % divisor == 16'd0) begin
                                exponent = exponent + 5'd1;
                                temp = temp / divisor;
                                j = j + 8'd1;
                            end
                            
                            // Calculate power sum: 1 + p + p^2 + ... + p^exponent
                            power_sum = 32'd1;
                            temp = divisor;
                            j = 8'd0;
                            while (j < exponent) begin
                                power_sum = power_sum + temp;
                                temp = temp * divisor;
                                j = j + 8'd1;
                            end
                            
                            // Multiply into factor_sum
                            factor_sum = factor_sum * power_sum;
                            
                            // Update m
                            m = temp;
                            
                            // Move to next prime
                            i = i + 8'd1;
                        end
                    end else begin
                        next_state = COMPUTE_SUM;
                    end
                end
                cycle_count = cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end
            
            COMPUTE_SUM: begin
                // Calculate series sum: 2 + 2^2 + ... + 2^k = 2^(k+1) - 2
                if (k == 5'd0) begin
                    series_sum = 32'd0; // No even factors for odd n
                end else begin
                    series_sum = (32'd1 << (k + 5'd1)) - 32'd2;
                end
                
                // Final result = factor_sum * series_sum
                result = factor_sum * series_sum;
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule