import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
import random

MOD = 1000000007

def calculate_expected(N, K):
    if N == 1:
        return 1
    if K == 1:
        return pow(2, N - 2, MOD)
    
    # The Python code provided in the prompt is complex and has multiple versions.
    # We will use a simplified version that matches the logic for small N.
    # Based on the logic: Count valid operations where the K-th eaten card is 1.
    # This is equivalent to counting valid paths in the state graph.
    
    # Let's use the logic from the 3rd Python snippet which seems to be the most complete for general K:
    # It uses DP table 'dp' and 'imos' (prefix sums).
    # dp[i][j] where i is step, j is position/size.
    
    # Implementing the DP logic directly for small N:
    if K == N:
        dp = [[0 for _ in range(K+1)] for _ in range(K)]
        imos = [0]*(K+1)
        dp[0][K] = 1
        imos[K] = 1
        for i in range(1, K):
            for j in range(K-i, K+1):
                if j == K-i:
                    dp[i][j] = (imos[K] - imos[j]) % MOD
                else:
                    dp[i][j] = (dp[i-1][j] + imos[K] - imos[j]) % MOD
            imos = [dp[i][j] for j in range(K+1)]
            for j in range(1, K+1):
                imos[j] = (imos[j] + imos[j-1]) % MOD
        return dp[N-1][1]
    else:
        dp = [[0 for _ in range(K+1)] for _ in range(K)]
        imos = [0]*(K+1)
        dp[0][K] = 1
        imos[K] = 1
        for i in range(1, K):
            for j in range(K-i, K+1):
                if j == K-i:
                    dp[i][j] = (imos[K] - imos[j]) % MOD
                else:
                    dp[i][j] = (dp[i-1][j] + imos[K] - imos[j]) % MOD
            imos = [dp[i][j] for j in range(K+1)]
            for j in range(1, K+1):
                imos[j] = (imos[j] + imos[j-1]) % MOD
        ans = 0
        # Combination function
        def nCr(n, r):
            if r < 0 or r > n: return 0
            if r == 0 or r == n: return 1
            num = 1
            den = 1
            for i in range(1, r+1):
                num *= (n - i + 1)
                den *= i
            return (num // den) % MOD
            
        for M in range(N-K+1, N+1):
            id_ = M - N + K
            ans = (ans + dp[K-1][id_] * nCr(M-2, N-K-1)) % MOD
        ans = (ans * pow(2, N-K-1, MOD)) % MOD
        return ans

@cocotb.test()
def test_snuke_deque(dut):
    """Test snuke_deque module"""
    # Generate random inputs
    for _ in range(20):
        N = random.randint(1, 12)
        K = random.randint(1, N)
        
        dut.N.value = N
        dut.K.value = K
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        expected = calculate_expected(N, K)
        received = int(dut.result.value)
        
        # Adjust for negative modulo results if any (Verilog might output negative if not handled carefully, but Python handles it)
        # The Verilog output should be positive.
        
        print(f"N={N}, K={K}, Expected={expected}, Received={received}")
        assert received == expected, f"Mismatch for N={N}, K={K}: Expected {expected}, Got {received}"
    
    print("All tests passed!")
