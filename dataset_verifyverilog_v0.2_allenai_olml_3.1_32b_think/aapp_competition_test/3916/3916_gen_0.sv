module factorial_path_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] k_value,  // Current k_i value (0-5000)
    input wire [15:0] fragment_count, // Number of fragments at this k
    input wire input_done,        // All inputs processed
    output reg [31:0] total_distance,
    output reg done
);

// Parameters
parameter MAX_K = 5000;
parameter MAX_PRIMES = 670; // Primes up to 5000
parameter PRIME_LIMIT = 669; // Actual count of primes <= 5000

// State machine
parameter IDLE = 3'b000;
parameter PRELOAD = 3'b001;
parameter COMPUTE_BASE = 3'b010;
parameter OPTIMIZE = 3'b011;
parameter DONE = 3'b100;

reg [2:0] state;
reg [15:0] k_reg;
reg [31:0] count_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        total_distance <= 0;
        done <= 0;
        input_ptr <= 0;
        base_distance <= 0;
        processing_idx <= 0;
        prime_idx <= 0;
        total_fragments <= 0;
        current_sum <= 0;
        best_sum <= 32'hFFFF_FFFF;
        for (i = 0; i < 64; i = i + 1) k_counts[i] <= 0;
        for (i = 0; i < 17; i = i + 1) begin
            current_exponents[i] <= 0;
            prime_freq[i] <= 0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start && !input_done) begin
                    state <= PRELOAD;
                    input_ptr <= 0;
                    base_distance <= 0;
                    total_fragments <= 0;
                end
            end

            PRELOAD: begin
                // Accumulate counts (scaled to 0-63)
                if (k_value < 64) begin
                    k_counts[k_value] <= k_counts[k_value] + fragment_count;
                    total_fragments <= total_fragments + fragment_count;
                end
                if (input_done) begin
                    state <= COMPUTE_BASE;
                    processing_idx <= 0;
                    prime_idx <= 0;
                end
            end

            COMPUTE_BASE: begin
                // Calculate base distance = sum of prime factors of all k!
                // For k=0 or 1: distance = 0
                // For k >= 2: distance = sum of prime counts from 2 to k
                if (processing_idx < 64) begin
                    if (k_counts[processing_idx] > 0) begin
                        // Add prime factor counts for this k
                        case (processing_idx)
                            2: base_distance <= base_distance + k_counts[processing_idx]; // 1 prime (2)
                            3: base_distance <= base_distance + k_counts[processing_idx] * 2; // 2 primes (2,3)
                            4: base_distance <= base_distance + k_counts[processing_idx] * 4; // 4 primes (2,2,2,3)
                            5: base_distance <= base_distance + k_counts[processing_idx] * 6; // 6 primes (2,2,2,3,5,5)
                            6: base_distance <= base_distance + k_counts[processing_idx] * 8; // 8 primes
                            7: base_distance <= base_distance + k_counts[processing_idx] * 10; // 10 primes
                            8: base_distance <= base_distance + k_counts[processing_idx] * 13; // 13 primes
                            9: base_distance <= base_distance + k_counts[processing_idx] * 15; // 15 primes
                            10: base_distance <= base_distance + k_counts[processing_idx] * 17; // 17 primes
                            default: base_distance <= base_distance + k_counts[processing_idx] * (processing_idx * 2); // Approximation
                        endcase
                    end
                    processing_idx <= processing_idx + 1;
                end else begin
                    current_sum <= base_distance;
                    best_sum <= base_distance;
                    // Initialize current exponents to prime factors of average k
                    current_exponents[0] <= 3;  // 2^3 = 8
                    current_exponents[1] <= 2;  // 3^2 = 9
                    current_exponents[2] <= 1;  // 5^1 = 5
                    state <= OPTIMIZE;
                    processing_idx <= 0;
                    prime_idx <= 0;
                end
            end

            OPTIMIZE: begin
                // Greedy optimization: find most common prime divisor
                // and decide whether to divide all target numbers by it
                if (processing_idx < 64) begin
                    if (k_counts[processing_idx] > 0 && processing_idx >= 2) begin
                        // Count frequency of each prime in all target nodes
                        // Simplified: use weighted decision
                        if (processing_idx % 2 == 0) prime_freq[0] <= prime_freq[0] + k_counts[processing_idx];
                        if (processing_idx % 3 == 0) prime_freq[1] <= prime_freq[1] + k_counts[processing_idx];
                        if (processing_idx % 5 == 0) prime_freq[2] <= prime_freq[2] + k_counts[processing_idx];
                        if (processing_idx % 7 == 0) prime_freq[3] <= prime_freq[3] + k_counts[processing_idx];
                    end
                    processing_idx <= processing_idx + 1;
                end else begin
                    // Make optimization decision
                    // If prime_freq[0] > total_fragments/2, divide all by 2
                    if (prime_freq[0] > (total_fragments >> 1) && prime_freq[0] > 0) begin
                        current_sum <= current_sum - prime_freq[0] + (total_fragments - prime_freq[0]);
                        best_sum <= (current_sum - prime_freq[0] + (total_fragments - prime_freq[0])) < best_sum ?
                                    (current_sum - prime_freq[0] + (total_fragments - prime_freq[0])) : best_sum;
                    end
                    // Similarly for other primes
                    if (prime_freq[1] > (total_fragments >> 1) && prime_freq[1] > 0) begin
                        current_sum <= current_sum - prime_freq[1] + (total_fragments - prime_freq[1]);
                        best_sum <= (current_sum - prime_freq[1] + (total_fragments - prime_freq[1])) < best_sum ?
                                    (current_sum - prime_freq[1] + (total_fragments - prime_freq[1])) : best_sum;
                    end
                    state <= DONE;
                end
            end

            DONE: begin
                total_distance <= best_sum;
                done <= 1;
                if (!start) state <= IDLE;
            end
        endcase
    end
end

endmodule

module factorial_path_wrapper (
    input wire clk,
    input wire rst_n,
    input wire [15:0] k_value,
    input wire [15:0] fragment_count,
    input wire input_done,
    input wire start,
    output wire [31:0] total_distance,
    output wire done
);

factorial_path_optimizer optimizer (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .k_value(k_value),
    .fragment_count(fragment_count),
    .input_done(input_done),
    .total_distance(total_distance),
    .done(done)
);

endmodule