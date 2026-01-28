module CasinoRebateMaxProfit(
    input [15:0] p_fixed,
    input [15:0] x_fixed,
    output reg [31:0] expected_profit
);

    // Precomputed binomial coefficients C(n,k) for k=0..8, n=0..255
    // Stored as 16-bit values (max C(255,8) = 1,000,000,000 fits in 30 bits)
    reg [15:0] binom_coeff [0:255][0:8];
    integer i, j;

    // Initialize binomial coefficients (combinational)
    always @(*) begin
        // Initialize all coefficients to 0
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 9; j = j + 1) begin
                binom_coeff[i][j] = 16'd0;
            end
        end

        // Compute binomial coefficients C(n,k) for k=0..8
        // Using recursive relation: C(n,k) = C(n-1,k-1) + C(n-1,k)
        // Base cases
        for (i = 0; i < 256; i = i + 1) begin
            binom_coeff[i][0] = 16'd1;  // C(n,0) = 1
        end
        for (j = 1; j < 9; j = j + 1) begin
            binom_coeff[j][j] = 16'd1;  // C(n,n) = 1
        end

        // Recursive computation
        for (i = 2; i < 256; i = i + 1) begin
            for (j = 1; j < 9; j = j + 1) begin
                if (j <= i) begin
                    binom_coeff[i][j] = binom_coeff[i-1][j-1] + binom_coeff[i-1][j];
                end
            end
        end
    end

    // Main computation
    reg [31:0] max_profit;
    reg [31:0] current_profit;
    reg [31:0] loss_term;
    reg [31:0] rebate_term;
    reg [31:0] prob_term;
    reg [31:0] temp;
    reg [31:0] p_complement;
    reg [31:0] x_scaled;
    reg [31:0] p_scaled;
    reg [31:0] p_power;
    reg [31:0] q_power;
    reg [31:0] binom_scaled;
    reg [31:0] term;
    reg [31:0] sum;
    integer n, k;

    always @(*) begin
        // Initialize maximum profit
        max_profit = 32'd0;
        p_complement = 32'd65536 - p_fixed;  // 1 - p in Q16.16
        x_scaled = x_fixed;  // x in Q16.16
        p_scaled = p_fixed;  // p in Q16.16

        // Iterate over number of bets n from 0 to 255
        for (n = 0; n < 256; n = n + 1) begin
            sum = 32'd0;

            // Compute expected value for n bets
            // E = sum_{k=0}^{min(n,8)} [C(n,k) * p^k * (1-p)^(n-k) * (k - n * (1 - x/100))]
            // We bound k to 0..8 wins

            for (k = 0; k < 9; k = k + 1) begin
                if (k > n) begin
                    term = 32'd0;
                end else begin
                    // Compute binomial coefficient term
                    binom_scaled = binom_coeff[n][k];

                    // Compute p^k in Q16.16
                    p_power = 32'd65536;  // 1.0 in Q16.16
                    for (i = 0; i < k; i = i + 1) begin
                        p_power = (p_power * p_scaled) >>> 16;  // Multiply and scale
                    end

                    // Compute (1-p)^(n-k) in Q16.16
                    q_power = 32'd65536;  // 1.0 in Q16.16
                    for (i = 0; i < (n - k); i = i + 1) begin
                        q_power = (q_power * p_complement) >>> 16;  // Multiply and scale
                    end

                    // Compute probability term: C(n,k) * p^k * (1-p)^(n-k)
                    // Scale binomial coefficient to Q16.16
                    prob_term = (binom_scaled * p_power) >>> 16;
                    prob_term = (prob_term * q_power) >>> 16;

                    // Compute profit term: (k - n * (1 - x/100))
                    // Note: x is in Q16.16, so x/100 = x_fixed / 100 / 65536
                    // But we need to compute: k - n*(1 - x/100)
                    // Since x is percentage, we compute: k - n + n*x/100
                    // In fixed point: k - n + (n * x_fixed) / (100 * 65536)
                    // But k and n are integers, so we need to scale them to Q16.16

                    // Convert k to Q16.16
                    temp = k << 16;
                    
                    // Convert n to Q16.16
                    loss_term = n << 16;
                    
                    // Compute n*x/100 in Q16.16
                    // x_fixed is Q16.16, so x/100 = x_fixed / 100 / 65536
                    // n * x/100 = n * x_fixed / (100 * 65536)
                    // In Q16.16: (n << 16) * x_fixed / (100 * 65536)
                    rebate_term = (loss_term * x_scaled) >>> 16;  // n*x in Q16.16
                    rebate_term = rebate_term / 100;  // n*x/100 in Q16.16

                    // Profit term: k - n + n*x/100
                    current_profit = temp - loss_term + rebate_term;

                    // Multiply by probability
                    term = (prob_term * current_profit) >>> 16;
                    
                    // Accumulate
                    sum = sum + term;
                end
            end

            // Update maximum profit
            if (n == 0) begin
                max_profit = sum;
            end else if (sum > max_profit) begin
                max_profit = sum;
            end
        end

        // Output the maximum expected profit
        expected_profit = max_profit;
    end

endmodule