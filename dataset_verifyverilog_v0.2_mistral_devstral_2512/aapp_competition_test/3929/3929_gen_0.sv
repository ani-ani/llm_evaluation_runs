module snuke_deque (
    input [3:0] N,
    input [3:0] K,
    output reg [31:0] result
);

    localparam MOD = 1000000007;

    // Precomputed combinations C(n, r) for n <= 12, r <= 12
    function [31:0] comb;
        input [3:0] n;
        input [3:0] r;
        reg [31:0] c;
        reg [31:0] i;
        begin
            if (r > n) begin
                comb = 0;
            end else if (r == 0 || r == n) begin
                comb = 1;
            end else begin
                c = 1;
                if (r > n - r) r = n - r;
                for (i = 1; i <= r; i = i + 1) begin
                    c = (c * (n - r + i)) % MOD;
                    c = (c * mod_inverse(i, MOD)) % MOD;
                end
                comb = c;
            end
        end
    endfunction

    // Modular inverse using Fermat's little theorem (since MOD is prime)
    function [31:0] mod_inverse;
        input [31:0] a;
        input [31:0] mod;
        reg [31:0] res;
        reg [31:0] exp;
        begin
            res = 1;
            exp = mod - 2;
            while (exp) begin
                if (exp[0]) res = (res * a) % mod;
                a = (a * a) % mod;
                exp = exp >> 1;
            end
            mod_inverse = res;
        end
    endfunction

    // Precomputed powers of 2 modulo MOD
    function [31:0] pow2;
        input [3:0] exp;
        reg [31:0] p;
        reg [3:0] i;
        begin
            p = 1;
            for (i = 0; i < exp; i = i + 1) begin
                p = (p * 2) % MOD;
            end
            pow2 = p;
        end
    endfunction

    // DP table for small N and K
    function [31:0] dp;
        input [3:0] k;
        input [3:0] m;
        reg [31:0] val;
        begin
            if (k == 1) begin
                val = 1;
            end else if (m == 1) begin
                val = 0;
            end else begin
                val = (comb(m - 1, k - 1) + dp(k - 1, m - 1)) % MOD;
            end
            dp = val;
        end
    endfunction

    always @* begin
        if (N == 0 || K == 0 || K > N) begin
            result = 0;
        end else if (K == 1) begin
            if (N == 1) begin
                result = 1;
            end else begin
                result = pow2(N - 2);
            end
        end else if (K == N) begin
            result = dp(K, N);
        end else begin
            reg [31:0] sum;
            reg [3:0] M;
            sum = 0;
            for (M = N - K + 1; M <= N - 1; M = M + 1) begin
                sum = (sum + (comb(M - 2, N - K - 1) * dp(K - 1, M - N + K)) % MOD) % MOD;
            end
            result = (sum * pow2(N - K - 1) % MOD + comb(N - 2, N - K - 1)) % MOD;
        end
    end

endmodule