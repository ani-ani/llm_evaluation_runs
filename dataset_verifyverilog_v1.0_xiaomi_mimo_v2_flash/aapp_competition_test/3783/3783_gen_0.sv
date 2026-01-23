module SubsetCostSum (
    input          clk,
    input          rst_n,
    input          start,
    input  [31:0]  N,
    input  [7:0]   k,
    output reg [31:0] result,
    output reg     done
);

    // Modulo constant
    localparam [31:0] MOD = 32'd1000000007;
    localparam [7:0]  MAX_K = 8'd8;
    localparam [31:0] INV2 = 32'd500000004; // (MOD+1)/2 for division by 2

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] STIRLING_INIT = 4'd1;
    localparam [3:0] STIRLING_LOOP = 4'd2;
    localparam [3:0] FACTORIAL     = 4'd3;
    localparam [3:0] INVERSES      = 4'd4;
    localparam [3:0] COMB_INIT     = 4'd5;
    localparam [3:0] COMB_LOOP     = 4'd6;
    localparam [3:0] POW2_N        = 4'd7;
    localparam [3:0] FINAL_SUM     = 4'd8;
    localparam [3:0] DONE          = 4'd9;

    // Internal registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [7:0] i; // Loop counter
    reg [7:0] n; // Outer loop for Stirling
    reg [31:0] dp [0:8]; // Stirling numbers S(n,i)
    reg [31:0] fact [0:8]; // Factorials
    reg [31:0] inv [0:8]; // Modular inverses
    reg [31:0] comb [0:8]; // Binomial coefficients
    reg [31:0] res_reg;
    reg [31:0] pow2_N_reg;
    reg [31:0] pow2_N_i;
    reg [31:0] term;
    reg [31:0] temp_val;
    reg [31:0] temp_mult1;
    reg [31:0] temp_mult2;
    reg [4:0] exp_cnt; // Counter for exponentiation (32 bits)
    reg [31:0] exp_base;
    reg [31:0] exp_result;
    reg [31:0] exp_exp;
    
    // Multiplication intermediate (64-bit to prevent overflow)
    wire [63:0] mult_res;
    assign mult_res = temp_mult1 * temp_mult2;

    // Precompute inverse values (since MAX_K is small)
    // We use precomputed values for 1 to 8 for simplicity and speed
    reg [31:0] precomputed_inv [0:8];
    initial begin
        precomputed_inv[1] = 32'd1;
        precomputed_inv[2] = 32'd500000004; // 2^-1
        precomputed_inv[3] = 32'd333333336; // 3^-1
        precomputed_inv[4] = 32'd250000002; // 4^-1
        precomputed_inv[5] = 32'd400000003; // 5^-1
        precomputed_inv[6] = 32'd166666668; // 6^-1
        precomputed_inv[7] = 32'd142857144; // 7^-1
        precomputed_inv[8] = 32'd125000001; // 8^-1
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i <= 8'd0;
            n <= 8'd0;
            res_reg <= 32'd0;
            pow2_N_reg <= 32'd1;
            pow2_N_i <= 32'd1;
            term <= 32'd0;
            temp_val <= 32'd0;
            temp_mult1 <= 32'd0;
            temp_mult2 <= 32'd0;
            exp_cnt <= 5'd0;
            exp_base <= 32'd0;
            exp_result <= 32'd0;
            exp_exp <= 32'd0;
            // Initialize arrays
            for (i = 0; i <= 8; i = i + 1) begin
                dp[i] <= 32'd0;
                fact[i] <= 32'd0;
                inv[i] <= 32'd0;
                comb[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && k <= MAX_K && k >= 8'd1) begin
                        state <= STIRLING_INIT;
                        // Initialize dp array
                        dp[0] <= 32'd1;
                        for (i = 8'd1; i <= 8'd8; i = i + 1) begin
                            dp[i] <= 32'd0;
                        end
                        n <= 8'd1; // Start n from 1
                    end
                end

                STIRLING_INIT: begin
                    // Start outer loop for Stirling numbers
                    // We loop n from 1 to k
                    if (n <= k) begin
                        // Initialize inner loop index i from n down to 1
                        // We use i to traverse downwards. Start at n.
                        i <= n;
                        state <= STIRLING_LOOP;
                    end else begin
                        // Done with Stirling numbers, move to Factorials
                        i <= 8'd1;
                        fact[0] <= 32'd1;
                        state <= FACTORIAL;
                    end
                end

                STIRLING_LOOP: begin
                    // Inner loop: i from n down to 1
                    // dp[i] = (i * dp[i] + dp[i-1]) % MOD
                    if (i >= 8'd1) begin
                        temp_mult1 <= i;
                        temp_mult2 <= dp[i];
                        // Wait one cycle for multiplication
                        // Then compute (temp_mult1 * temp_mult2 + dp[i-1]) % MOD
                        // We need to compute (i * dp[i] + dp[i-1]) % MOD
                        // Result in mult_res[31:0] or [47:16] if Q format, but here just 32-bit math
                        // Let's do mod addition after multiplication
                        temp_val <= dp[i-1]; // Store dp[i-1] for addition
                        state <= 4'd15; // Temporary state to finish calculation
                    end else begin
                        // Done inner loop, increment n
                        n <= n + 8'd1;
                        state <= STIRLING_INIT;
                    end
                end
                
                // Temporary state for Stirling calculation
                4'd15: begin
                    // (i * dp[i] + dp[i-1]) % MOD
                    // mult_res is 64 bits. mod MOD
                    temp_val <= (mult_res[63:0] % MOD + temp_val) % MOD;
                    state <= 4'd16;
                end
                4'd16: begin
                    dp[i] <= temp_val;
                    i <= i - 8'd1;
                    state <= STIRLING_LOOP;
                end

                FACTORIAL: begin
                    // Compute fact[i] = fact[i-1] * i % MOD for i=1..k
                    if (i <= k) begin
                        temp_mult1 <= fact[i-1];
                        temp_mult2 <= i;
                        state <= 4'd17; // Wait mult
                    end else begin
                        // Done, load inverses
                        for (i = 8'd1; i <= 8'd8; i = i + 1) begin
                            inv[i] <= precomputed_inv[i];
                        end
                        i <= 8'd1;
                        state <= INVERSES;
                    end
                end
                4'd17: begin
                    fact[i] <= mult_res[63:0] % MOD;
                    i <= i + 8'd1;
                    state <= FACTORIAL;
                end

                INVERSES: begin
                    // Inverses are precomputed. Move to Combinatorics.
                    // C(N,i) = C(N,i-1) * (N-i+1) / i
                    // Initialize comb[0] = 1, loop i=1..k
                    comb[0] <= 32'd1;
                    i <= 8'd1;
                    state <= COMB_INIT;
                end

                COMB_INIT: begin
                    if (i <= k) begin
                        // term = comb[i-1] * (N - i + 1)
                        // Handle N - i + 1. N is 32 bit.
                        // We need to be careful with subtraction if N < i, but N >= 1 and i <= k <= 8.
                        // So N - i + 1 >= 1 - 8 + 1. If N is small, it might be negative? 
                        // But problem says N >= 1. If N < i, C(N,i) = 0.
                        if (N < i) begin
                            comb[i] <= 32'd0;
                            i <= i + 8'd1;
                            state <= COMB_INIT;
                        end else begin
                            temp_mult1 <= comb[i-1];
                            temp_mult2 <= (N - i + 1);
                            state <= 4'd18;
                        end
                    end else begin
                        state <= POW2_N;
                        exp_base <= 32'd2;
                        exp_exp <= N;
                        exp_result <= 32'd1;
                        exp_cnt <= 5'd0;
                    end
                end
                4'd18: begin
                    // Multiply by inverse of i
                    temp_val <= mult_res[63:0] % MOD;
                    temp_mult1 <= mult_res[63:0] % MOD;
                    temp_mult2 <= inv[i];
                    state <= 4'd19;
                end
                4'd19: begin
                    comb[i] <= mult_res[63:0] % MOD;
                    i <= i + 8'd1;
                    state <= COMB_INIT;
                end

                POW2_N: begin
                    // Binary exponentiation: 2^N % MOD
                    // exp_base = 2, exp_exp = N, exp_result = 1
                    // Process bits of N (32 bits)
                    if (exp_cnt < 5'd32) begin
                        if (exp_exp[0]) begin
                            temp_mult1 <= exp_result;
                            temp_mult2 <= exp_base;
                            state <= 4'd20;
                        end else begin
                            // Just square base
                            temp_mult1 <= exp_base;
                            temp_mult2 <= exp_base;
                            state <= 4'd21;
                        end
                    end else begin
                        pow2_N_reg <= exp_result;
                        pow2_N_i <= exp_result; // Initial value for sum loop
                        res_reg <= 32'd0;
                        i <= 8'd0;
                        state <= FINAL_SUM;
                    end
                end
                4'd20: begin // Update result
                    exp_result <= mult_res[63:0] % MOD;
                    // Update base anyway (fall through)
                    temp_mult1 <= exp_base;
                    temp_mult2 <= exp_base;
                    state <= 4'd21;
                end
                4'd21: begin // Update base
                    exp_base <= mult_res[63:0] % MOD;
                    exp_exp <= exp_exp >> 1;
                    exp_cnt <= exp_cnt + 5'd1;
                    state <= POW2_N;
                end

                FINAL_SUM: begin
                    // Loop i=0 to k
                    // term = dp[i] * fact[i] % MOD * comb[i] % MOD * pow2_N_i % MOD
                    // res_reg += term
                    if (i <= k) begin
                        // Calculate term step by step
                        // 1. dp[i] * fact[i]
                        temp_mult1 <= dp[i];
                        temp_mult2 <= fact[i];
                        state <= 4'd22;
                    end else begin
                        result <= res_reg;
                        state <= DONE;
                    end
                end
                4'd22: begin // temp_val = dp[i] * fact[i]
                    temp_val <= mult_res[63:0] % MOD;
                    // 2. * comb[i]
                    temp_mult1 <= mult_res[63:0] % MOD;
                    temp_mult2 <= comb[i];
                    state <= 4'd23;
                end
                4'd23: begin // temp_val = (dp[i] * fact[i]) * comb[i]
                    temp_val <= mult_res[63:0] % MOD;
                    // 3. * pow2_N_i
                    temp_mult1 <= mult_res[63:0] % MOD;
                    temp_mult2 <= pow2_N_i;
                    state <= 4'd24;
                end
                4'd24: begin // term = ...
                    term <= mult_res[63:0] % MOD;
                    state <= 4'd25;
                end
                4'd25: begin // res_reg += term
                    res_reg <= (res_reg + term) % MOD;
                    // Update pow2_N_i for next iteration: multiply by INV2
                    temp_mult1 <= pow2_N_i;
                    temp_mult2 <= INV2;
                    state <= 4'd26;
                end
                4'd26: begin
                    pow2_N_i <= mult_res[63:0] % MOD;
                    i <= i + 8'd1;
                    state <= FINAL_SUM;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule