module decomposition_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] data_in,
    input [1:0] n_in,
    input valid_in,
    input last_in,
    output reg [31:0] result,
    output reg done,
    output reg ready
);

    parameter MOD = 1000000007;
    parameter MAX_PRIME = 255;
    parameter PRIME_BITS = 8;
    parameter EXP_BITS = 9;

    typedef logic [PRIME_BITS-1:0] prime_t;
    typedef logic [EXP_BITS-1:0] exp_t;

    // State machine
    typedef enum logic [1:0] {
        IDLE,
        FACTORIZE,
        COMPUTE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] current_data;
    reg [1:0] current_n;
    reg [15:0] prime_counter;
    reg [15:0] data_counter;
    reg [15:0] compute_counter;
    reg [31:0] product_accum;
    reg [31:0] binomial_result;
    reg [31:0] exponent_sum;
    reg [31:0] temp_product;
    reg [31:0] temp_comb;
    reg [31:0] temp_k;
    reg [31:0] temp_n;

    // Exponent array (256 primes, 9-bit exponents)
    reg [EXP_BITS-1:0] exponent_array [0:MAX_PRIME];

    // Binomial coefficient lookup table (precomputed for small values)
    reg [31:0] comb_table [0:15]; // C(n+k-1, k) for k=0..15, n=1..4

    // Initialize combinatorial logic
    always_comb begin
        // State transition logic
        case (current_state)
            IDLE: begin
                if (start) next_state = FACTORIZE;
                else next_state = IDLE;
            end
            FACTORIZE: begin
                if (last_in && valid_in) next_state = COMPUTE;
                else if (valid_in) next_state = FACTORIZE;
                else next_state = FACTORIZE;
            end
            COMPUTE: begin
                if (compute_counter == MAX_PRIME) next_state = DONE;
                else next_state = COMPUTE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase

        // Ready signal
        ready = (current_state == IDLE);

        // Done signal
        done = (current_state == DONE);
    end

    // Sequential logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_data <= 0;
            current_n <= 0;
            prime_counter <= 0;
            data_counter <= 0;
            compute_counter <= 0;
            product_accum <= 1;
            binomial_result <= 0;
            exponent_sum <= 0;
            temp_product <= 0;
            temp_comb <= 0;
            temp_k <= 0;
            temp_n <= 0;
            result <= 0;
            done <= 0;
            ready <= 1;

            // Initialize exponent array
            for (int i = 0; i <= MAX_PRIME; i++) begin
                exponent_array[i] <= 0;
            end

            // Initialize binomial coefficient table
            // C(n+k-1, k) for n=1..4, k=0..15
            comb_table[0] = 1; // C(0,0)
            comb_table[1] = 1; // C(1,0)
            comb_table[2] = 2; // C(2,1)
            comb_table[3] = 3; // C(3,2)
            comb_table[4] = 4; // C(4,3)
            comb_table[5] = 5; // C(5,4)
            comb_table[6] = 6; // C(6,5)
            comb_table[7] = 7; // C(7,6)
            comb_table[8] = 8; // C(8,7)
            comb_table[9] = 9; // C(9,8)
            comb_table[10] = 10; // C(10,9)
            comb_table[11] = 11; // C(11,10)
            comb_table[12] = 12; // C(12,11)
            comb_table[13] = 13; // C(13,12)
            comb_table[14] = 14; // C(14,13)
            comb_table[15] = 15; // C(15,14)
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    // Reset internal registers
                    current_data <= 0;
                    current_n <= 0;
                    prime_counter <= 0;
                    data_counter <= 0;
                    compute_counter <= 0;
                    product_accum <= 1;
                    binomial_result <= 0;
                    exponent_sum <= 0;
                    temp_product <= 0;
                    temp_comb <= 0;
                    temp_k <= 0;
                    temp_n <= 0;
                    result <= 0;
                    done <= 0;
                    ready <= 1;

                    // Clear exponent array
                    for (int i = 0; i <= MAX_PRIME; i++) begin
                        exponent_array[i] <= 0;
                    end
                end
                FACTORIZE: begin
                    if (valid_in) begin
                        current_data <= data_in;
                        current_n <= n_in;

                        // Factorize current_data
                        if (current_data > 1) begin
                            prime_t p;
                            exp_t exp_count;
                            logic [15:0] temp_data;

                            temp_data = current_data;
                            p = 2;

                            while (p <= MAX_PRIME && temp_data > 1) begin
                                exp_count = 0;
                                while (temp_data % p == 0) begin
                                    exp_count = exp_count + 1;
                                    temp_data = temp_data / p;
                                end
                                if (exp_count > 0) begin
                                    exponent_array[p] <= exponent_array[p] + exp_count;
                                end
                                p = p + 1;
                            end
                        end

                        // Update counters
                        if (last_in) begin
                            data_counter <= 0;
                        end else begin
                            data_counter <= data_counter + 1;
                        end
                    end
                end
                COMPUTE: begin
                    if (compute_counter == 0) begin
                        product_accum <= 1;
                        exponent_sum <= 0;
                    end

                    // Calculate binomial coefficient and accumulate
                    if (exponent_array[compute_counter] > 0) begin
                        temp_k <= exponent_array[compute_counter];
                        temp_n <= current_n;

                        // Calculate C(k + n - 1, n - 1)
                        // For simplicity, use precomputed table for small values
                        // In real implementation, you'd need a more robust method
                        if (temp_k <= 15) begin
                            temp_comb <= comb_table[temp_k];
                        end else begin
                            // Fallback: compute iteratively (simplified)
                            temp_comb <= 1;
                            for (int i = 1; i <= temp_k; i++) begin
                                temp_comb <= (temp_comb * (temp_n + temp_k - i)) / i;
                            end
                        end

                        // Accumulate product modulo MOD
                        temp_product <= (product_accum * temp_comb) % MOD;
                        product_accum <= temp_product;
                    end

                    // Move to next prime
                    compute_counter <= compute_counter + 1;

                    // If done, store result
                    if (compute_counter == MAX_PRIME) begin
                        result <= product_accum;
                    end
                end
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
        end
    end

endmodule