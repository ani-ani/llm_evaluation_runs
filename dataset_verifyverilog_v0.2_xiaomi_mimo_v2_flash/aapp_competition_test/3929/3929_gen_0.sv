module snuke_deque(
    input [3:0] N,
    input [3:0] K,
    output reg [31:0] result
);

    // Constants
    localparam MOD = 32'd1000000007;
    
    // Lookup Tables for N <= 12
    // C[n][r] n=0..12, r=0..12
    reg [31:0] C[0:12][0:12];
    // P2[n] = 2^n for n=0..12
    reg [31:0] P2[0:12];
    // DP[n][m] for the specific calculation
    // Since N<=12, we can store 2D array. Max index 12.
    reg [31:0] DP[0:12][0:12];

    // Combinational block
    integer i, j, m;
    
    initial begin
        // Initialize LUTs in synthesis or simulation
        // Combinations
        for (i = 0; i <= 12; i = i + 1) begin
            C[i][0] = 1;
            C[i][i] = 1;
            for (j = 1; j < i; j = j + 1) begin
                C[i][j] = C[i-1][j-1] + C[i-1][j];
            end
            for (j = i + 1; j <= 12; j = j + 1) begin
                C[i][j] = 0;
            end
        end
        
        // Powers of 2
        P2[0] = 1;
        for (i = 1; i <= 12; i = i + 1) begin
            P2[i] = P2[i-1] * 2;
        end
        
        // DP Table initialization
        // Base cases from Python logic
        // DP[n][m] for n=1..12, m=n-1..11 (effectively)
        // We fill the table for all valid n,m pairs based on the recurrence derived from problem
        // DP[n][m] = Sum_{k=0}^{n-1} DP[n-1][m-k] * C[n-1][k]
        // Base: DP[1][0] = 1.
        
        // Initialize all to 0
        for (i = 0; i <= 12; i = i + 1)
            for (j = 0; j <= 12; j = j + 1)
                DP[i][j] = 0;
                
        DP[1][0] = 1;
        
        for (i = 2; i <= 12; i = i + 1) begin
            // m goes from i-1 to 11 (max N-1 for N=12)
            for (m = i-1; m <= 11; m = m + 1) begin
                // Calculate DP[i][m]
                // Sum over k
                for (j = 0; j < i; j = j + 1) begin
                    // DP[i-1][m-j] needs to be safe. m-j >= i-2.
                    // Since m >= i-1, and j <= i-1, m-j >= -1.
                    // The valid range for DP[i-1] is indices >= i-2.
                    // If m-j < i-2, DP is 0.
                    if (m >= j && (m - j) >= (i - 2)) begin
                        DP[i][m] = DP[i][m] + DP[i-1][m-j] * C[i-1][j];
                    end
                end
            end
        end
    end

    always @(*) begin
        reg [31:0] sum;
        reg [31:0] term1;
        reg [31:0] term2;
        reg [31:0] mult1;
        reg [31:0] mult2;
        reg [31:0] factor;
        
        // Initialize
        sum = 0;
        term1 = 0;
        term2 = 0;
        result = 0;
        
        // Handle invalid inputs or edge cases (optional, but good practice)
        if (N < 1 || K < 1 || K > N) begin
            result = 0;
        end
        else if (N == 1) begin
            result = 1; // Special case not in formula but trivial
        end
        else if (K == 1) begin
            // Formula: 2^(N-2)
            if (N >= 2) begin
                result = P2[N-2];
            end else begin
                result = 1;
            end
        end
        else begin
            // General case or K=N
            // The Python logic suggests:
            // Ans = (Sum over M: C(M-2, N-K-1) * DP[K-1][M-N+K]) * 2^(N-K-1) + C(N-2, N-K-1)
            // Check bounds for N and K. N-K-1 can be -1 if K=N.
            // If K=N, N-K-1 = -1. Combinations C(x, -1) are 0 in standard math, but Python code treats specific terms.
            // We need to be careful with the loop range M and indices.
            
            // Loop M from N-K+1 to N-1
            // If K=N, N-K+1 = 1. N-1 = N-1. Loop runs.
            // Inside: C(M-2, N-K-1). If N-K-1 < 0, term is 0.
            // So for K=N, the sum term is 0.
            // Then we add C(N-2, N-K-1). For K=N, N-K-1 = -1. C(x, -1) is 0.
            // Wait, Python code handles K=N separately or it works out?
            // In provided logic: "if (K == N) ... Sum over M..."
            // Actually, the provided logic in prompt says:
            // "Ans = (Sum over M...) * 2^(...) + C(N-2, N-K-1)"
            // For K=N: 2^(N-K-1) = 2^-1. Not valid in integer logic.
            // Ah, the provided code snippet in prompt has:
            // "For K=1, 2^(N-2). For K=N, DP sum."
            // And "For general (1<K<N): Ans = (Sum...) * 2^(N-K-1) + C(...)"
            // So we must handle K=N separately as per prompt.
            
            if (K == N) begin
                // Logic: Ans = Sum_{M=1}^{N-1} (C(N-2, M-1) * DP[K][M])
                // Note: DP indices. DP[N][M] where M < N.
                for (m = 1; m < N; m = m + 1) begin
                    // C(N-2, M-1)
                    // Check bounds: N-2 >= 0, M-1 >= 0.
                    // If N=2, M=1. C(0,0)=1. Correct.
                    mult1 = C[N-2][m-1];
                    // DP[N][m] (indices 0-based in Verilog array, values N and m match)
                    // Need to ensure m <= 11 as per array size.
                    if (m <= 11) mult2 = DP[N][m];
                    else mult2 = 0;
                    
                    term1 = (mult1 * mult2);
                    // Modular addition logic is handled by Verilog if we check limits, 
                    // but for safety in simulation and synthesis without overflow:
                    // Since values are small (N<=12), product fits in 32 bit easily.
                    // But we need mod 10^9+7.
                    sum = (sum + term1) % MOD;
                end
                result = sum;
            end
            else begin
                // 1 < K < N
                // Ans = (Sum over M from N-K+1 to N-1 of C(M-2, N-K-1) * DP[K-1][M-N+K]) * 2^(N-K-1) + C(N-2, N-K-1)
                
                // Part 1: The Sum
                for (m = N - K + 1; m < N; m = m + 1) begin
                    // C(M-2, N-K-1)
                    // Check indices. M-2 >= 0? M >= 2. If N-K+1 < 2, M-2 could be -1 or 0.
                    // If M-2 < N-K-1, C is 0.
                    // Need to ensure indices are non-negative for array lookup.
                    // If N-K-1 < 0, term is 0. (Should not happen for 1<K<N).
                    // If M-2 < 0, C is 0.
                    
                    reg [3:0] idx_n, idx_r;
                    idx_n = N - K - 1;
                    idx_r = m - 2;
                    
                    if (idx_r >= 0 && idx_n >= 0 && idx_r >= idx_n && idx_r <= 12) begin
                        mult1 = C[idx_r][idx_n];
                    end else begin
                        mult1 = 0;
                    end
                    
                    // DP[K-1][M-N+K]
                    // M-N+K. Range check. M < N, so M-N < 0, M-N+K < K. K <= N-1, so K-1 < N.
                    // Array indices. K-1 <= 11.
                    // M-N+K. M >= N-K+1 => M-N+K >= 1.
                    // Max value: M=N-1 => N-1-N+K = K-1.
                    // So indices are 1..K-1. Valid range for DP if K-1 >= 1.
                    reg [3:0] dp_idx1, dp_idx2;
                    dp_idx1 = K - 1;
                    dp_idx2 = m - N + K;
                    
                    if (dp_idx2 <= 11 && dp_idx1 >= 1 && dp_idx2 >= 0) begin
                        mult2 = DP[dp_idx1][dp_idx2];
                    end else begin
                        mult2 = 0;
                    end
                    
                    term1 = (mult1 * mult2) % MOD;
                    sum = (sum + term1) % MOD;
                end
                
                // Multiply sum by 2^(N-K-1)
                factor = P2[N-K-1];
                term2 = (sum * factor) % MOD;
                
                // Add C(N-2, N-K-1)
                // Check bounds. N-K-1 >= 0. If N-K-1 > N-2, C=0.
                // N-K-1 <= N-2 => -K-1 <= -2 => K >= 1. True.
                // If N-K-1 < 0 (should be caught by K=N case).
                reg [3:0] c_idx_n = N - 2;
                reg [3:0] c_idx_r = N - K - 1;
                if (c_idx_r >= 0 && c_idx_r <= c_idx_n && c_idx_n <= 12) begin
                    term1 = C[c_idx_n][c_idx_r];
                end else begin
                    term1 = 0;
                end
                
                result = (term2 + term1) % MOD;
            end
        end
    end

endmodule