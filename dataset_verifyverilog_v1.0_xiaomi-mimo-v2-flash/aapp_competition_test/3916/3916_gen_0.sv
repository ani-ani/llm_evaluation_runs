module factorial_median_path(
    input clk,
    input rst_n,
    input start,
    input [15:0] k_i [0:15],  // Fixed to 16 elements for hardware, n <= 16
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] PREPROCESS = 4'd1;
    localparam [3:0] PRIME_LOOP = 4'd2;
    localparam [3:0] CHECK_PRIME = 4'd3;
    localparam [3:0] COUNT_EXP = 4'd4;
    localparam [3:0] FIND_MEDIAN = 4'd5;
    localparam [3:0] ACCUMULATE_DIST = 4'd6;
    localparam [3:0] NEXT_PRIME = 4'd7;
    localparam [3:0] DONE = 4'd8;

    reg [3:0] state, next_state;
    
    // Configuration constants
    localparam [3:0] NUM_PRIMES = 4'd16;
    localparam [4:0] MAX_EXPONENT = 5'd16;  // Safe upper bound for exponents
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // First 16 primes (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53)
    reg [15:0] primes [0:15];
    
    // Computation registers
    reg [7:0] cycle_count;
    reg [3:0] prime_idx;
    reg [4:0] exp_count [0:15];  // Count of each exponent value (0-16)
    reg [3:0] input_idx;
    reg [4:0] current_exp;
    reg [3:0] exp_value;  // Exponent value being processed
    reg [31:0] accumulated_dist;
    reg [4:0] median_exp;
    reg [15:0] majority_count;
    reg found_median;
    
    // Precomputed factorials for k_i to k_i! exponent calculation
    // Using Legendre's formula: exponent of p in k! = sum_{i=1..∞} floor(k / p^i)
    reg [15:0] current_k;
    reg [15:0] power_of_p;
    reg [3:0] p_power_idx;
    
    integer i;

    // Initialize primes array (only once at synthesis)
    initial begin
        primes[0] = 16'd2;
        primes[1] = 16'd3;
        primes[2] = 16'd5;
        primes[3] = 16'd7;
        primes[4] = 16'd11;
        primes[5] = 16'd13;
        primes[6] = 16'd17;
        primes[7] = 16'd19;
        primes[8] = 16'd23;
        primes[9] = 16'd29;
        primes[10] = 16'd31;
        primes[11] = 16'd37;
        primes[12] = 16'd41;
        primes[13] = 16'd43;
        primes[14] = 16'd47;
        primes[15] = 16'd53;
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            prime_idx <= 4'd0;
            input_idx <= 4'd0;
            accumulated_dist <= 32'd0;
            median_exp <= 5'd0;
            found_median <= 1'b0;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                exp_count[i] <= 5'd0;
            end
        end else begin
            state <= next_state;
            
            if (start) begin
                cycle_count <= 8'd0;
                accumulated_dist <= 32'd0;
                prime_idx <= 4'd0;
                done <= 1'b0;
            end else if (state != IDLE && state != DONE) begin
                cycle_count <= cycle_count + 8'd1;
            end
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                end
                
                PREPROCESS: begin
                    // Reset exponent count for new prime
                    for (i = 0; i < 16; i = i + 1) begin
                        exp_count[i] <= 5'd0;
                    end
                    input_idx <= 4'd0;
                    current_exp <= 5'd0;
                    exp_value <= 4'd0;
                    power_of_p <= 16'd1;
                    p_power_idx <= 4'd0;
                end
                
                PRIME_LOOP: begin
                    // Start counting exponents for current prime
                    current_k <= k_i[input_idx];
                    power_of_p <= primes[prime_idx];  // Start with p^1
                    p_power_idx <= 4'd1;
                end
                
                CHECK_PRIME: begin
                    // Check if we should continue calculating Legendre's formula
                    if (p_power_idx < 4'd15 && power_of_p <= current_k) begin
                        // Continue with higher powers
                        power_of_p <= power_of_p * primes[prime_idx];
                        p_power_idx <= p_power_idx + 4'd1;
                    end
                end
                
                COUNT_EXP: begin
                    // Add contribution to exponent count
                    // Floor division: current_k / power_of_p
                    exp_value <= exp_value + (current_k / power_of_p);
                end
                
                FIND_MEDIAN: begin
                    // Find weighted median for this prime
                    // Count total samples and find majority
                    majority_count <= n[15:0] / 2 + 16'd1;
                    found_median <= 1'b0;
                    median_exp <= 5'd0;
                end
                
                ACCUMULATE_DIST: begin
                    // Add distance contribution for this prime
                    // Distance = sum |exp_i - median_exp|
                    if (median_exp < current_exp) begin
                        accumulated_dist <= accumulated_dist + (5'd16 - current_exp) + median_exp;
                    end else begin
                        accumulated_dist <= accumulated_dist + (current_exp - median_exp);
                    end
                end
                
                NEXT_PRIME: begin
                    // Move to next prime or finish
                    if (prime_idx < NUM_PRIMES - 4'd1) begin
                        prime_idx <= prime_idx + 4'd1;
                    end
                end
                
                DONE: begin
                    result <= accumulated_dist;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PREPROCESS;
                end
            end
            
            PREPROCESS: begin
                if (prime_idx < NUM_PRIMES) begin
                    next_state = PRIME_LOOP;
                end else begin
                    next_state = DONE;
                end
            end
            
            PRIME_LOOP: begin
                next_state = CHECK_PRIME;
            end
            
            CHECK_PRIME: begin
                if (p_power_idx < 4'd15 && power_of_p <= current_k) begin
                    next_state = COUNT_EXP;
                end else begin
                    // All powers calculated, add to count
                    exp_count[exp_value] = exp_count[exp_value] + 16'd1;
                    next_state = COUNT_EXP;
                end
            end
            
            COUNT_EXP: begin
                if (input_idx < n - 4'd1) begin
                    input_idx = input_idx + 4'd1;
                    next_state = PRIME_LOOP;
                end else begin
                    next_state = FIND_MEDIAN;
                end
            end
            
            FIND_MEDIAN: begin
                // Determine median by checking counts
                // Simple greedy: find exponent with count > n/2 or closest to n/2
                if (exp_count[median_exp] >= majority_count) begin
                    found_median = 1'b1;
                end
                
                if (median_exp < MAX_EXPONENT && !found_median) begin
                    median_exp = median_exp + 5'd1;
                end
                
                if (median_exp >= MAX_EXPONENT || found_median) begin
                    next_state = ACCUMULATE_DIST;
                end else begin
                    next_state = FIND_MEDIAN;
                end
            end
            
            ACCUMULATE_DIST: begin
                // Calculate distance contribution
                if (input_idx < n - 4'd1) begin
                    // Continue counting for this prime
                    input_idx = input_idx + 4'd1;
                    current_exp = 5'd0;
                    power_of_p = primes[prime_idx];
                    p_power_idx = 4'd1;
                    next_state = CHECK_PRIME;
                end else begin
                    // Done with this prime, move to next
                    next_state = NEXT_PRIME;
                end
            end
            
            NEXT_PRIME: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE;
                end else if (prime_idx < NUM_PRIMES - 4'd1) begin
                    next_state = PREPROCESS;
                end else begin
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule