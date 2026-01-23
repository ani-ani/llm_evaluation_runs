module ramen_combinatorics (
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    input [31:0] m,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam MAX_N = 16;
    localparam IDLE = 3'b000;
    localparam PRECOMPUTE = 3'b001;
    localparam CALCULATE_STIRLING = 3'b010;
    localparam COMPUTE_SUM = 3'b011;
    localparam DONE = 3'b100;

    // State register
    reg [2:0] state, next_state;

    // Factorial and inverse factorial arrays
    reg [31:0] fact [0:MAX_N];
    reg [31:0] inv_fact [0:MAX_N];

    // Stirling numbers array
    reg [31:0] S [0:MAX_N][0:MAX_N];

    // Loop counters
    reg [4:0] i, j, k;
    reg [4:0] next_i, next_j, next_k;

    // Intermediate values
    reg [31:0] term, sum, pow2, pow2_exp, temp;
    reg [31:0] next_term, next_sum, next_pow2, next_pow2_exp, next_temp;

    // Sign flag
    reg sign;
    reg next_sign;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            i <= 0;
            j <= 0;
            k <= 0;
            term <= 0;
            sum <= 0;
            pow2 <= 0;
            pow2_exp <= 0;
            temp <= 0;
            sign <= 0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            k <= next_k;
            term <= next_term;
            sum <= next_sum;
            pow2 <= next_pow2;
            pow2_exp <= next_pow2_exp;
            temp <= next_temp;
            sign <= next_sign;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_i = i;
        next_j = j;
        next_k = k;
        next_term = term;
        next_sum = sum;
        next_pow2 = pow2;
        next_pow2_exp = pow2_exp;
        next_temp = temp;
        next_sign = sign;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PRECOMPUTE;
                    next_i = 0;
                    next_j = 0;
                    next_k = 0;
                    next_sum = 0;
                    next_term = 0;
                    next_pow2 = 0;
                    next_pow2_exp = 0;
                    next_temp = 0;
                    next_sign = 0;
                end
            end

            PRECOMPUTE: begin
                if (i == 0) begin
                    next_fact[0] = 1;
                    next_inv_fact[0] = 1;
                end else begin
                    next_fact[i] = (fact[i-1] * i) % m;
                    next_inv_fact[i] = mod_inverse(fact[i], m);
                end

                if (i == n) begin
                    next_state = CALCULATE_STIRLING;
                    next_i = 1;
                    next_j = 1;
                end else begin
                    next_i = i + 1;
                end
            end

            CALCULATE_STIRLING: begin
                if (i == 1 && j == 1) begin
                    next_S[1][1] = 1;
                end else if (j == 1) begin
                    next_S[i][j] = 1;
                end else if (j == i) begin
                    next_S[i][j] = 1;
                end else begin
                    next_S[i][j] = (S[i-1][j] * j + S[i-1][j-1]) % m;
                end

                if (i == n && j == n) begin
                    next_state = COMPUTE_SUM;
                    next_i = 0;
                    next_j = 0;
                    next_k = 0;
                    next_sum = 0;
                    next_sign = 0;
                end else begin
                    if (j == i) begin
                        next_i = i + 1;
                        next_j = 1;
                    end else begin
                        next_j = j + 1;
                    end
                end
            end

            COMPUTE_SUM: begin
                // Compute binomial coefficient C(n, k)
                if (k == 0) begin
                    next_temp = 1;
                end else begin
                    next_temp = (fact[n] * inv_fact[k] % m) * inv_fact[n - k] % m;
                end

                // Compute inner sum: sum_{i=1}^k S[k][i] * 2^i
                if (j == 0) begin
                    next_pow2 = 1;
                    next_term = 0;
                end else begin
                    next_pow2 = (pow2 * 2) % m;
                    next_term = (term + S[k][j] * pow2 % m) % m;
                end

                // Compute 2^(2^(n-k)) using modular exponentiation
                if (j == k) begin
                    next_pow2_exp = mod_exp(2, mod_exp(2, n - k, m - 1), m);
                end

                // Accumulate the result
                if (j == k) begin
                    if (k == n) begin
                        next_state = DONE;
                        next_result = sum;
                        next_done = 1;
                    end else begin
                        if (sign) begin
                            next_sum = (sum - temp * next_term % m * next_pow2_exp % m) % m;
                        end else begin
                            next_sum = (sum + temp * next_term % m * next_pow2_exp % m) % m;
                        end
                        next_k = k + 1;
                        next_j = 0;
                        next_sign = ~sign;
                    end
                end else begin
                    next_j = j + 1;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    next_done = 0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Modular inverse using Fermat's little theorem
    function [31:0] mod_inverse;
        input [31:0] a, mod;
        begin
            mod_inverse = mod_exp(a, mod - 2, mod);
        end
    endfunction

    // Modular exponentiation
    function [31:0] mod_exp;
        input [31:0] base, exp, mod;
        reg [31:0] result;
        reg [31:0] b, e;
        begin
            result = 1;
            b = base % mod;
            e = exp;

            while (e > 0) begin
                if (e[0]) begin
                    result = (result * b) % mod;
                end
                b = (b * b) % mod;
                e = e >> 1;
            end

            mod_exp = result;
        end
    endfunction

endmodule