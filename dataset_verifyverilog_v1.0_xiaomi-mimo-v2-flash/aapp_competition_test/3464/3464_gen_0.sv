module CasinoRebate (
    input [15:0] p_fixed,
    input [15:0] x_fixed,
    output reg [31:0] expected_profit
);

    // Local parameters for fixed-point arithmetic (Q16.16)
    localparam [31:0] FIXED_ONE = 32'd65536;
    localparam [15:0] P_LIMIT = 16'd32768; // 50% in Q16.16 (0.5 * 65536)
    localparam [7:0] MAX_N = 8'd255;
    localparam [3:0] MAX_K = 4'd8;

    // Binomial coefficients C(n, k) for k <= 8
    // Using a 9x256 ROM (flattened for combinational logic)
    // Coefficients are calculated using combinational logic to avoid large initialization blocks
    reg [63:0] binom_coeff;
    reg [63:0] coeffs [0:8];

    integer i, j;
    always @(*) begin
        // Initialize coefficients for k=0 to 8
        coeffs[0] = 64'd1;
        coeffs[1] = 64'd0;
        coeffs[2] = 64'd0;
        coeffs[3] = 64'd0;
        coeffs[4] = 64'd0;
        coeffs[5] = 64'd0;
        coeffs[6] = 64'd0;
        coeffs[7] = 64'd0;
        coeffs[8] = 64'd0;

        // Pascal's Triangle Logic
        for (i = 1; i <= 256; i = i + 1) begin
            // Shift logic to calculate C(i, k) from C(i-1, k-1) and C(i-1, k)
            // We only need up to k=8
            for (j = 8; j >= 1; j = j - 1) begin
                if (i == 1) begin
                    coeffs[j] = (j == 1) ? 64'd1 : 64'd0;
                end else begin
                    // Accumulate Pascal's triangle values
                    if (j == 1) coeffs[j] = coeffs[j] + 64'd1;
                    else coeffs[j] = coeffs[j] + coeffs[j-1];
                end
            end
        end
        
        // Map current n to binom_coeff (used in the main loop)
        // Since we need C(n, k) inside the n loop, we calculate it dynamically
    end

    // Main Combinational Logic
    reg [31:0] max_profit;
    reg [31:0] current_n_profit;
    reg [31:0] p_pow_k;
    reg [31:0] one_minus_p_pow;
    reg [31:0] rebate;
    reg [31:0] loss;
    reg [31:0] term;
    reg [63:0] temp_mult;
    
    // Current binomial coefficient cache
    reg [63:0] current_binom;
    reg [63:0] current_binom_temp;

    integer n, k;
    
    // Combinational block for DP calculation
    always @(*) begin
        // Safety check: p must be < 50%
        if (p_fixed >= P_LIMIT) begin
            // If p >= 0.5, optimal strategy is to play 0 games
            // Expected profit is 0 (no initial money invested)
            expected_profit = 32'd0;
        end else begin
            // Initialize max profit to 0 (n=0 case)
            max_profit = 32'd0;

            // Loop over number of bets n from 1 to 255
            for (n = 1; n <= 255; n = n + 1) begin
                current_n_profit = 32'd0;
                
                // Calculate C(n, 0) = 1
                current_binom = 64'd1;

                // Calculate (1-p)^n and p^n using iterative multiplication
                // To prevent overflow in Q16.16 multiplication, we use 64-bit intermediates
                // 1-p
                temp_mult = (FIXED_ONE - p_fixed);
                one_minus_p_pow = temp_mult[31:0];
                
                // p (promoted to 32-bit for consistent logic)
                p_pow_k = {16'd0, p_fixed};

                // Iterate k from 0 to 8 (bounded wins)
                for (k = 0; k <= 8; k = k + 1) begin
                    // Calculate C(n, k)
                    // We use a combinational calculation of C(n, k) using the formula:
                    // C(n, k) = n! / (k! * (n-k)!)
                    // Given n <= 255 and k <= 8, we can compute this safely in 64 bits
                    
                    // Combinational calculation of C(n, k) for current n
                    current_binom_temp = 64'd1;
                    for (int m = 0; m < k; m = m + 1) begin
                        current_binom_temp = current_binom_temp * (n - m);
                        current_binom_temp = current_binom_temp / (m + 1);
                    end
                    current_binom = current_binom_temp;

                    // Calculate Probability P(W=k) = C(n,k) * p^k * (1-p)^(n-k)
                    // Term 1: p^k
                    // We multiply previous p_pow_k by p (handling Q16.16 scale)
                    if (k == 0) begin
                        p_pow_k = FIXED_ONE;
                    end else begin
                        temp_mult = p_pow_k * p_fixed;
                        p_pow_k = temp_mult[47:16]; // Keep Q16.16
                    end

                    // Term 2: (1-p)^(n-k)
                    // We recalculate (1-p)^(n-k) specifically for this k
                    // Optimization: We could iterate, but for simplicity and correctness in combinational loop:
                    one_minus_p_pow = FIXED_ONE;
                    for (int m = 0; m < (n - k); m = m + 1) begin
                        temp_mult = one_minus_p_pow * (FIXED_ONE - p_fixed);
                        one_minus_p_pow = temp_mult[47:16];
                    end

                    // Combine: Prob = C(n,k) * p^k * (1-p)^(n-k)
                    // We need to handle large C(n,k) multiplication carefully.
                    // Prob is Q16.16.
                    // Scale C(n,k) down to fit, or handle dynamic range.
                    // Assuming C(n,k) is the raw integer, Prob = C * P1 * P2 / 65536
                    
                    temp_mult = current_binom * p_pow_k;
                    temp_mult = temp_mult * one_minus_p_pow;
                    // Shift right by 16 to get Q16.16 result
                    reg [31:0] prob_k;
                    prob_k = temp_mult[47:16];

                    // Calculate Payoff for k wins
                    // Rebate Rate = x_fixed
                    // Net Loss = (1 - k/n)
                    // Payoff = (1 - x) * Loss + x * Refund
                    // Refund = k/n * Amount
                    // Simplified: Payoff = 1 - (1-x) * (1 - k/n)
                    // Actually: Net = 1 - Loss + Refund = 1 - (1-k/n) + x*(k/n)
                    // = k/n + x*(k/n) = (1+x) * k/n
                    // Wait, the problem says: 
                    // "Maximum expected profit"
                    // "Rebate x% on losses"
                    // Let's assume standard casino rebate: return x% of losses.
                    // If Win: Profit = 1
                    // If Lose: Profit = -1 + (x * 1) = x - 1
                    // Total Profit = k * 1 + (n-k) * (x-1)
                    // Expected Profit = k + (n-k)*(x-1) normalized by n?
                    // Actually, EV = sum(P(k) * Payoff(k))
                    // Payoff(k) = k*1 + (n-k)*(x-1) = k + nx - xk - n + k = n*x - n + 2k - n*x*k? No.
                    // Payoff(k) = k - (n-k) + x*(n-k) = k - n + k + x*n - x*k = 2k - n + x*n - x*k
                    // = k*(2-x) + n*(x-1)
                    
                    // Let's use the explicit formula from the prompt's implied math:
                    // "Find optimal stopping point" implies comparing EV for different n.
                    // EV(n) = E[Profit]. Let's assume we invest 1 unit per bet.
                    // Total Investment: n
                    // Returns: k wins * 1 unit
                    // Rebate: x * (Loss) = x * (n - k)
                    // Net Profit: k + x*(n-k) - n = k + nx - xk - n = k*(1-x) + n*(x-1)
                    // WAIT: The prompt says "Maximum Expected Profit".
                    // Usually, Profit = Return - Cost.
                    // If we stop at n, we play n games.
                    // Cost = n (assuming 1 unit per game).
                    // Return = k (wins) * 1 + (n-k) (losses) * 0 + x*(n-k) (rebate).
                    // Total Return = k + x*(n-k)
                    // Net Profit = (k + x*(n-k)) - n = k - x*k + x*n - n = k(1-x) + n(x-1)
                    // Note: If x=0 (no rebate), Profit = k - n. 
                    // If we stop at n=0, Profit = 0.
                    
                    // We are summing over k.
                    // EV(n) = Sum_{k} P(k) * [ k(1-x) + n(x-1) ]
                    // EV(n) = (1-x) * E[k] + n(x-1)
                    // E[k] = n * p
                    // EV(n) = (1-x) * n * p + n(x-1)
                    // EV(n) = n * [ p(1-x) + x - 1 ]
                    // EV(n) = n * [ p - px + x - 1 ]
                    // EV(n) = n * [ x(1-p) - (1-p) ]
                    // EV(n) = n * (1-p) * (x - 1)
                    // Since x < 1 and p < 0.5 (usually), this is negative.
                    // Wait, if x=100% (1.0), EV = 0.
                    // This math assumes we lose the bet amount if we lose, but get rebate.
                    // Usually rebate is on *net* loss over a session, not per bet.
                    // But for a bounded number of bets, the simplified formula holds.
                    
                    // Let's re-read: "Optimal stopping point". 
                    // If EV is always negative (cost > return), the optimal is n=0 (profit 0).
                    // Is the rebate paying out more than the cost? 
                    // If x > 1 (impossible), profit.
                    // If x is close to 1, and p is high, maybe we play.
                    
                    // Let's assume the prompt implies the "Parimutuel" or "Rebate" logic where
                    // the rebate is a refund of *stake* on loss.
                    // i.e. You lose (1-x) on a loss, win 1 on a win.
                    // EV per game = p*1 + (1-p)*(x-1) = p + x - 1 - px + p = ?
                    // Wait: p*1 + (1-p)*(x-1) = p + x - 1 - px + p = 2p - px + x - 1.
                    // This is the EV for *one* game. 
                    // If this is positive, we bet forever. If negative, we bet 0.
                    // The "Optimal stopping point" suggests a variance-based strategy (like Kelly)
                    // OR a finite bankroll scenario.
                    // Given the prompt asks for "Expected Profit" and "bounded number of bets",
                    // I will use the exact summation formula for Finite n.
                    
                    // Payoff for k wins out of n:
                    // Return = k + (x * (n-k))  // Win amount + Rebate on losses
                    // Cost = n
                    // Net = k + x(n-k) - n
                    
                    // Calculate k * (1-x) + n * (x-1)
                    // Note: x is Q16.16 (0 to 65535). 
                    // We need (1-x). 1 in Q16.16 is 65536.
                    // 1-x is (65536 - x_fixed).
                    
                    reg [31:0] term_k;
                    reg [31:0] term_n;
                    
                    // k part: k * (1-x)
                    // k is small (<=8). We can just multiply.
                    // k is integer. (1-x) is Q16.16.
                    temp_mult = (k) * (FIXED_ONE - x_fixed);
                    term_k = temp_mult[31:0]; // Q16.16
                    
                    // n part: n * (x-1)
                    // x-1 is negative if x < 1. 
                    // x-1 = x_fixed - 65536.
                    // n is int <= 255.
                    // We use signed arithmetic for this part to handle negative values correctly,
                    // then add to the total (which is signed 32-bit implicitly).
                    
                    // Since Verilog arithmetic is unsigned by default unless declared signed,
                    // and we are handling profit which can be negative, let's be careful.
                    // The maximum negative value won't overflow 32-bit signed if n <= 255.
                    
                    // Let's stick to unsigned for accumulation but calculate the specific term value.
                    // Term Value = [k + x(n-k) - n]
                    // = k + n*x - k*x - n
                    // = k(1-x) + n(x-1)
                    // Note: n(x-1) is negative.
                    
                    // Let's compute the "Payoff Value" (not scaled by probability yet) as a 32-bit signed equivalent
                    // stored in reg [31:0] assuming MSB is sign bit if needed, but here we do simple algebra.
                    // Actually, let's calculate Prob * Payoff directly.
                    // Payoff is the net profit per unit invested. 
                    // If we invest n, the payoff is (k + x(n-k) - n).
                    // We need to normalize by n? No, the prompt asks for "Expected Profit".
                    // Is it total profit or profit per bet?
                    // "Maximum Expected Profit for a casino rebate scenario". 
                    // Usually, if you can stop, you maximize total profit.
                    // But if EV per bet is constant, optimal is always all-in or zero.
                    // Given the bounded wins (k <= 8), this implies we are looking at a scenario
                    // where variance dominates (high p, low n) or the rebate structure changes.
                    
                    // Let's implement the summation: 
                    // Expected Profit = Sum_{k} ( P(k) * (k + x*(n-k) - n) )
                    // Scaled by the unit of money (let's say 1.0).
                    // Since inputs are Q16.16, output is Q16.16.
                    
                    // Calculate the payoff scalar: Payoff(k,n) = k + x*(n-k) - n
                    // = k - n + nx - kx
                    // = k(1-x) + n(x-1)
                    
                    // 1. Calculate k(1-x) in Q16.16
                    // k is integer 0-8. (1-x) is (65536 - x_fixed).
                    reg [31:0] payoff_k;
                    payoff_k = k * (FIXED_ONE - x_fixed); // Q16.16
                    
                    // 2. Calculate n(x-1) in Q16.16
                    // (x-1) = x_fixed - 65536 (negative or small positive)
                    // This will be negative. We need to handle negative values in the addition.
                    // Since we are doing fixed point, let's represent the full payoff as signed 32-bit
                    // relative to 0. 
                    // Payoff is likely negative (casino edge).
                    // We track the "least negative" value (closest to 0).
                    
                    // Calculate n * (x_fixed - 65536)
                    // x_fixed is 16-bit. Cast to 32-bit signed arithmetic logic.
                    // We will do the calculation in 64-bit signed logic if possible, 
                    // but Verilog requires explicit handling.
                    
                    // Let's use a helper variable for the term n*(x-1)
                    reg [31:0] term_n_signed;
                    // x-1 in Q16.16 is (x_fixed - 65536).
                    // n * (x-1).
                    // We know x_fixed < 65536 usually (100% is 65536, but prompt says x < 100).
                    // So x-1 is negative.
                    // We will compute this as (n * (65536 - x_fixed)) but subtract it.
                    
                    // Wait, the formula was k(1-x) + n(x-1).
                    // Since (x-1) is negative, n(x-1) is negative.
                    // Let's calculate the magnitude of n(1-x) and subtract it.
                    
                    reg [31:0] n_term_mag;
                    n_term_mag = n * (FIXED_ONE - x_fixed); // Q16.16
                    
                    // Total Payoff = payoff_k - n_term_mag
                    // This represents (k*(1-x) - n*(1-x)) = (k-n)*(1-x) + n*x - n? 
                    // Let's re-verify: 
                    // Profit = k*1 + (n-k)*x - n
                    //        = k + nx - kx - n
                    //        = k(1-x) + n(x-1)
                    // If x < 1, (x-1) is negative. 
                    // n(x-1) = -n(1-x).
                    // So Profit = k(1-x) - n(1-x) = (k-n)*(1-x).
                    // This is only true if x is the refund percentage of the *stake*.
                    // If x is the fraction returned:
                    // Return = k*1 + (n-k)*x. Cost = n.
                    // Profit = k + nx - kx - n = (k-n)(1-x).
                    
                    // So, Profit scalar = (k-n) * (1-x).
                    // Since k <= 8 and n can be large, this is negative.
                    // We want to maximize this (least negative).
                    
                    // Calculate (k-n). This is negative or zero.
                    // (1-x) is (65536 - x_fixed).
                    // Product of negative (k-n) and positive (1-x) is negative.
                    // We need signed arithmetic for the final comparison.
                    
                    // Let's compute the contribution to expected value:
                    // Prob * Payoff.
                    // Prob is Q16.16 (positive).
                    // Payoff is signed 32-bit Q16.16.
                    
                    // 1. Calculate Payoff Scalar (signed 32-bit)
                    // Payoff = (k - n) * (1 - x)
                    // (k-n) is negative. Let's do (n-k) * (1-x) and negate.
                    reg [31:0] diff_n_k;
                    diff_n_k = n - k; // 32-bit unsigned, n > k usually
                    
                    temp_mult = diff_n_k * (FIXED_ONE - x_fixed);
                    // temp_mult is positive (magnitude of loss). 
                    // Profit is negative.
                    
                    // Since we want to find the MAXIMUM profit (closest to 0 or positive),
                    // we treat this as a signed value.
                    // If temp_mult[31:0] is the magnitude of the loss, 
                    // the profit is -temp_mult.
                    // In 2's complement (unsigned representation of negative), this is ~temp_mult + 1.
                    
                    reg [31:0] payoff_scalar;
                    payoff_scalar = ~temp_mult[31:0] + 32'd1;
                    
                    // 2. Multiply Probability * Payoff
                    // Prob is Q16.16. Payoff is Q16.16.
                    // Result is Q32.32. We need Q16.16.
                    // Result = (Prob * Payoff) >> 16.
                    
                    temp_mult = prob_k * payoff_scalar;
                    term = temp_mult[47:16]; // Keep middle 32 bits
                    
                    // 3. Accumulate
                    current_n_profit = current_n_profit + term;
                end

                // 4. Compare and Update Max Profit
                // current_n_profit is signed 32-bit (Q16.16).
                // max_profit is signed 32-bit.
                // We want the maximum value.
                // If current_n_profit > max_profit, update.
                
                // Signed comparison logic
                if (n == 1) begin
                    max_profit = current_n_profit;
                end else begin
                    // Check if current > max
                    // Treat both as signed
                    if ($signed(current_n_profit) > $signed(max_profit)) begin
                        max_profit = current_n_profit;
                    end
                end
            end
            
            expected_profit = max_profit;
        end
    end
endmodule