module prime_palindrome_solver (
    input clk,
    input rst_n,
    input start,
    input [13:0] p,
    input [13:0] q,
    output reg [9:0] result,
    output reg done,
    output reg no_solution
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        SIEVE_INIT,
        SIEVE_PROCESS,
        CALCULATE_ITER,
        FINISHED
    } state_t;

    state_t current_state, next_state;

    // Sieve RAM (1024 entries, 1-bit each)
    reg [1023:0] prime_flags;

    // Counters and registers
    reg [9:0] n;
    reg [9:0] prime_count;
    reg [9:0] palindrome_count;
    reg [9:0] max_n;

    // Sieve processing
    reg [9:0] sieve_i;
    reg [9:0] sieve_j;

    // Palindrome check
    reg [9:0] temp_n;
    reg [3:0] digit0, digit1, digit2, digit3;
    reg [9:0] reversed_n;

    // Multiplication results (24-bit)
    reg [23:0] prime_q_product;
    reg [23:0] palindrome_p_product;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            no_solution <= 0;
            result <= 0;
            n <= 0;
            prime_count <= 0;
            palindrome_count <= 0;
            max_n <= 0;
            sieve_i <= 0;
            sieve_j <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = SIEVE_INIT;
            end
            SIEVE_INIT: begin
                if (sieve_i == 1023) next_state = SIEVE_PROCESS;
            end
            SIEVE_PROCESS: begin
                if (sieve_i == 1023 && sieve_j == 1023) next_state = CALCULATE_ITER;
            end
            CALCULATE_ITER: begin
                if (n == 1023) next_state = FINISHED;
            end
            FINISHED: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sieve initialization
    always @(posedge clk) begin
        if (!rst_n) begin
            prime_flags <= 1024'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // All 1's
        end else if (current_state == SIEVE_INIT) begin
            if (sieve_i == 0) begin
                prime_flags[0] <= 0; // 0 is not prime
                prime_flags[1] <= 0; // 1 is not prime
            end
            sieve_i <= sieve_i + 1;
        end
    end

    // Sieve processing (mark non-primes)
    always @(posedge clk) begin
        if (current_state == SIEVE_PROCESS) begin
            if (prime_flags[sieve_i]) begin
                if (sieve_j == 0) begin
                    sieve_j <= sieve_i * 2;
                end else if (sieve_j < 1024) begin
                    prime_flags[sieve_j] <= 0;
                    sieve_j <= sieve_j + sieve_i;
                end else begin
                    sieve_j <= 0;
                    sieve_i <= sieve_i + 1;
                end
            end else begin
                sieve_i <= sieve_i + 1;
            end
        end
    end

    // Main calculation loop
    always @(posedge clk) begin
        if (current_state == CALCULATE_ITER) begin
            // Increment n
            n <= n + 1;

            // Update prime count
            if (prime_flags[n]) begin
                prime_count <= prime_count + 1;
            end

            // Palindrome check
            temp_n <= n;
            digit0 <= temp_n[3:0];
            digit1 <= temp_n[7:4];
            digit2 <= temp_n[9:8];
            digit3 <= 0;

            // For 3-digit numbers (n < 1000)
            if (n < 1000) begin
                reversed_n <= {digit0, digit1};
            end else begin // 4-digit numbers (n >= 1000)
                reversed_n <= {digit0, digit1, digit2};
            end

            // Check if palindrome
            if (n == reversed_n) begin
                palindrome_count <= palindrome_count + 1;
            end

            // Multiplication (24-bit)
            prime_q_product <= prime_count * q;
            palindrome_p_product <= palindrome_count * p;

            // Condition check
            if (prime_q_product <= palindrome_p_product) begin
                max_n <= n;
            end

            // Reset counters if n reaches 1023
            if (n == 1023) begin
                done <= 1;
                if (max_n == 0) begin
                    no_solution <= 1;
                end else begin
                    result <= max_n;
                end
            end
        end
    end

    // Reset done and no_solution when starting new calculation
    always @(posedge clk) begin
        if (current_state == SIEVE_INIT) begin
            done <= 0;
            no_solution <= 0;
            result <= 0;
            n <= 0;
            prime_count <= 0;
            palindrome_count <= 0;
            max_n <= 0;
        end
    end

endmodule