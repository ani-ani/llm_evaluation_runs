module max_revenue (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [9:0] S [0:7],
    output reg [7:0] max_rev,
    output reg done
);

    // States
    typedef enum logic [3:0] {
        IDLE,
        PRECOMPUTE_SUMS,
        PRECOMPUTE_FACTORS,
        DP_INIT,
        DP_OUTER,
        DP_INNER,
        DONE
    } state_t;

    state_t state, next_state;

    // Counters and registers
    reg [7:0] outer_cnt;
    reg [7:0] inner_cnt;
    reg [7:0] prime_cnt;
    reg [15:0] sum_reg;
    reg [7:0] factors_reg;
    reg [7:0] dp [0:255];
    reg [7:0] temp_dp;
    reg [7:0] temp_mask;
    reg [7:0] temp_submask;
    reg [7:0] temp_complement;
    reg [7:0] temp_factors;

    // Precomputed sums and factors
    reg [15:0] subset_sums [0:255];
    reg [7:0] prime_factors [0:255];

    // Prime numbers up to 89
    localparam [7:0] primes [0:24] = '{2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_rev <= 0;
            outer_cnt <= 0;
            inner_cnt <= 0;
            prime_cnt <= 0;
            sum_reg <= 0;
            factors_reg <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = PRECOMPUTE_SUMS;
            end
            PRECOMPUTE_SUMS: begin
                if (outer_cnt == 255) next_state = PRECOMPUTE_FACTORS;
            end
            PRECOMPUTE_FACTORS: begin
                if (outer_cnt == 255) next_state = DP_INIT;
            end
            DP_INIT: begin
                if (outer_cnt == 255) next_state = DP_OUTER;
            end
            DP_OUTER: begin
                if (outer_cnt == (1 << N) - 1) next_state = DONE;
            end
            DP_INNER: begin
                if (inner_cnt == 255) next_state = DP_OUTER;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Precompute sums
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outer_cnt <= 0;
        end else if (state == PRECOMPUTE_SUMS) begin
            if (outer_cnt < 256) begin
                subset_sums[outer_cnt] <= compute_sum(outer_cnt, S, N);
                outer_cnt <= outer_cnt + 1;
            end
        end
    end

    // Precompute prime factors
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outer_cnt <= 0;
            prime_cnt <= 0;
            sum_reg <= 0;
            factors_reg <= 0;
        end else if (state == PRECOMPUTE_FACTORS) begin
            if (outer_cnt < 256) begin
                sum_reg <= subset_sums[outer_cnt];
                prime_cnt <= 0;
                factors_reg <= 0;
                if (sum_reg == 0) begin
                    prime_factors[outer_cnt] <= 0;
                    outer_cnt <= outer_cnt + 1;
                end else begin
                    next_state = PRECOMPUTE_FACTORS;
                end
            end
        end
    end

    // Prime factor counting
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prime_cnt <= 0;
            factors_reg <= 0;
        end else if (state == PRECOMPUTE_FACTORS && sum_reg != 0) begin
            if (prime_cnt < 24) begin
                if (sum_reg % primes[prime_cnt] == 0) begin
                    factors_reg <= factors_reg + 1;
                    sum_reg <= sum_reg / primes[prime_cnt];
                end else begin
                    prime_cnt <= prime_cnt + 1;
                end
            end else begin
                prime_factors[outer_cnt] <= factors_reg;
                outer_cnt <= outer_cnt + 1;
            end
        end
    end

    // DP initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outer_cnt <= 0;
        end else if (state == DP_INIT) begin
            if (outer_cnt < 256) begin
                dp[outer_cnt] <= 0;
                outer_cnt <= outer_cnt + 1;
            end
        end
    end

    // DP outer loop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            outer_cnt <= 0;
        end else if (state == DP_OUTER) begin
            if (outer_cnt < (1 << N) - 1) begin
                temp_mask <= outer_cnt + 1;
                inner_cnt <= 0;
                next_state = DP_INNER;
            end else begin
                max_rev <= dp[(1 << N) - 1];
                done <= 1;
            end
        end
    end

    // DP inner loop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inner_cnt <= 0;
        end else if (state == DP_INNER) begin
            if (inner_cnt < 256) begin
                temp_submask <= inner_cnt;
                if ((temp_submask & temp_mask) == temp_submask) begin
                    temp_complement <= temp_mask ^ temp_submask;
                    temp_factors <= prime_factors[temp_complement];
                    temp_dp <= dp[temp_submask] + temp_factors;
                    if (temp_dp > dp[temp_mask]) begin
                        dp[temp_mask] <= temp_dp;
                    end
                end
                inner_cnt <= inner_cnt + 1;
            end else begin
                outer_cnt <= outer_cnt + 1;
                next_state = DP_OUTER;
            end
        end
    end

    // Compute sum of subset
    function [15:0] compute_sum;
        input [7:0] mask;
        input [9:0] S [0:7];
        input [2:0] N;
        integer i;
        reg [15:0] sum;
        begin
            sum = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (mask[i]) begin
                    sum = sum + S[i];
                end
            end
            compute_sum = sum;
        end
    endfunction

endmodule