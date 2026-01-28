module FactorizationCounter(
    input clk,
    input rst_n,
    input start,
    input [3:0] num_primes,
    input [31:0] prime_counts [0:11],
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MAX_FACT = 32'd1000;
    localparam MAX_N = 32'd500;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PRELOAD = 3'd1;
    localparam [2:0] COMPUTE_LOOP = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Precomputed factorials and inverse factorials (synthesized as ROMs)
    reg [31:0] fact [0:1000];
    reg [31:0] inv_fact [0:1000];

    // State registers
    reg [2:0] state, next_state;
    reg [3:0] prime_index;
    reg [31:0] current_count;
    reg [31:0] current_n;
    reg [31:0] current_k;
    reg [31:0] current_comb;
    reg [31:0] product_accum;

    // Pipeline registers for factorial lookups
    reg [31:0] fact_n_reg;
    reg [31:0] fact_k_reg;
    reg [31:0] fact_nk_reg;

    // Pipeline registers for modular multiplication
    reg [31:0] mult1_reg;
    reg [31:0] mult2_reg;

    // Initialize factorials and inverse factorials
    integer i;
    initial begin
        // Factorials
        fact[0] = 1;
        for (i = 1; i <= MAX_FACT; i = i + 1) begin
            fact[i] = (fact[i-1] * i) % MOD;
        end

        // Inverse factorials using Fermat's Little Theorem
        inv_fact[MAX_FACT] = mod_exp(fact[MAX_FACT], MOD - 2, MOD);
        for (i = MAX_FACT - 1; i >= 0; i = i - 1) begin
            inv_fact[i] = (inv_fact[i+1] * (i+1)) % MOD;
        end
    end

    // Modular exponentiation function
    function [31:0] mod_exp;
        input [31:0] base;
        input [31:0] exp;
        input [31:0] mod;
        reg [31:0] result;
        reg [31:0] current;
        integer j;
        begin
            result = 1;
            current = base % mod;
            for (j = 0; j < 32; j = j + 1) begin
                if (exp[j]) begin
                    result = (result * current) % mod;
                end
                current = (current * current) % mod;
            end
            mod_exp = result;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            prime_index <= 4'd0;
            current_count <= 32'd0;
            current_n <= 32'd0;
            current_k <= 32'd0;
            current_comb <= 32'd0;
            product_accum <= 32'd0;
            fact_n_reg <= 32'd0;
            fact_k_reg <= 32'd0;
            fact_nk_reg <= 32'd0;
            mult1_reg <= 32'd0;
            mult2_reg <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PRELOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PRELOAD: begin
                    product_accum <= 32'd1;
                    prime_index <= 4'd0;
                    next_state <= COMPUTE_LOOP;
                end

                COMPUTE_LOOP: begin
                    // Fetch current prime count
                    current_count <= prime_counts[prime_index];

                    // Compute n = count + N - 1 (N is fixed at 500)
                    current_n <= current_count + MAX_N - 1;

                    // Compute k = N - 1
                    current_k <= MAX_N - 1;

                    // Pipeline stage 1: Factorial lookups
                    fact_n_reg <= fact[current_n];
                    fact_k_reg <= inv_fact[current_k];
                    fact_nk_reg <= inv_fact[current_n - current_k];

                    // Pipeline stage 2: First multiplication
                    mult1_reg <= (fact_n_reg * fact_k_reg) % MOD;

                    // Pipeline stage 3: Second multiplication
                    mult2_reg <= (mult1_reg * fact_nk_reg) % MOD;

                    // Pipeline stage 4: Accumulate result
                    current_comb <= mult2_reg;
                    product_accum <= (product_accum * current_comb) % MOD;

                    // Increment prime index
                    if (prime_index == num_primes - 1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        prime_index <= prime_index + 1;
                        next_state <= COMPUTE_LOOP;
                    end
                end

                DONE_STATE: begin
                    result <= product_accum;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule