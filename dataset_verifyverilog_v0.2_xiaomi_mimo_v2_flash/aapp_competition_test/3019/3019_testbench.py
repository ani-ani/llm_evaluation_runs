import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

def count_distinct_primes(n):
    if n <= 1:
        return 0
    primes = []
    temp = n
    for p in [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97]:
        if p*p > temp:
            break
        if temp % p == 0:
            primes.append(p)
            while temp % p == 0:
                temp //= p
    if temp > 1:
        primes.append(temp)
    return len(primes)

def solve_py(N, S):
    # DP with bitmasks
    dp = [0] * (1 << N)
    precomp = [0] * (1 << N)
    
    # Precompute prime factors for each subset
    for mask in range(1 << N):
        total = 0
        for i in range(N):
            if mask & (1 << i):
                total += S[i]
        precomp[mask] = count_distinct_primes(total)
    
    dp[0] = 0
    for mask in range(1, 1 << N):
        # Try all partitions: submask and complement
        sub = mask
        while sub > 0:
            dp[mask] = max(dp[mask], dp[sub] + precomp[mask ^ sub])
            sub = (sub - 1) & mask
        # Also consider taking all elements as one group
        dp[mask] = max(dp[mask], precomp[mask])
    
    return dp[(1 << N) - 1]

@cocotb.test()
async def test_max_revenue(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    for i in range(8):
        dut.S[i].value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1], 0),
        ([4, 7, 8], 3),
        ([2, 3, 4, 5, 8], 5),
        ([1, 2, 3, 4, 5, 6, 7, 8], 12)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (S_vals, expected) in enumerate(test_cases):
        N = len(S_vals)
        dut.N.value = N
        for i in range(8):
            dut.S[i].value = S_vals[i] if i < N else 0
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 10000 cycles)
        timeout = 0
        while not dut.done.value and timeout < 10000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        result = int(dut.max_rev.value)
        print(f"Test {idx+1}: N={N}, S={S_vals}, Expected={expected}, Got={result}")
        assert result == expected, f"Test {idx+1} failed: expected {expected}, got {result}"
        if result == expected:
            passed += 1
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"