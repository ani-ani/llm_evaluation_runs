import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

MOD = 1000000007

def mod_inverse(a, m):
    """Extended Euclidean Algorithm for modular inverse"""
    def extended_gcd(a, b):
        if a == 0:
            return b, 0, 1
        gcd, x1, y1 = extended_gcd(b % a, a)
        x = y1 - (b // a) * x1
        y = x1
        return gcd, x, y
    
    _, x, _ = extended_gcd(a % m, m)
    return (x % m + m) % m

def stirling_second(k, i, mod):
    """Compute S(k,i) modulo mod using DP"""
    if i == 0 or i > k:
        return 0
    if k == i or i == 1:
        return 1
    
    # DP table for S[n][r]
    S = [[0] * (k + 1) for _ in range(k + 1)]
    for n in range(k + 1):
        S[n][0] = 0
        if n >= 1:
            S[n][1] = 1
            S[n][n] = 1
    
    for n in range(2, k + 1):
        for r in range(2, min(n, k) + 1):
            S[n][r] = (S[n-1][r-1] + (r * S[n-1][r])) % mod
    
    return S[k][i]

def compute_subset_cost(n, k, mod):
    """Compute the sum of costs for all non-empty subsets"""
    # Sum_{x=1 to N} (x^k * C(N,x))
    # Using Stirling: Sum_{i=1 to k} S(k,i) * i! * C(N,i) * 2^(N-i)
    
    result = 0
    
    # Precompute S(k,i) for i=1..k
    stirling = [0] * (k + 1)
    for i in range(1, k + 1):
        stirling[i] = stirling_second(k, i, mod)
    
    # Precompute i!
    fact = [1] * (k + 1)
    for i in range(1, k + 1):
        fact[i] = (fact[i-1] * i) % mod
    
    # Precompute inv_fact for i=1..k
    inv_fact = [1] * (k + 1)
    for i in range(1, k + 1):
        inv_fact[i] = mod_inverse(fact[i], mod)
    
    # Precompute 2^N mod mod
    pow2n = pow(2, n, mod)
    
    # Precompute inv2 = 1/2 mod mod
    inv2 = mod_inverse(2, mod)
    
    # Compute inv2_pow[i] = (1/2)^i mod mod
    inv2_pow = [1] * (k + 1)
    for i in range(1, k + 1):
        inv2_pow[i] = (inv2_pow[i-1] * inv2) % mod
    
    # Compute result
    for i in range(1, k + 1):
        if stirling[i] == 0:
            continue
        
        # Compute C(N,i) = N*(N-1)*...*(N-i+1) * inv_fact[i]
        cn_i = 1
        for j in range(i):
            cn_i = (cn_i * ((n - j) % mod)) % mod
        cn_i = (cn_i * inv_fact[i]) % mod
        
        # term = S(k,i) * i! * C(N,i) * 2^(N-i)
        #      = S(k,i) * fact[i] * C(N,i) * 2^N * inv2^i
        term = (stirling[i] * fact[i]) % mod
        term = (term * cn_i) % mod
        term = (term * pow2n) % mod
        term = (term * inv2_pow[i]) % mod
        
        result = (result + term) % mod
    
    return result

@cocotb.test()
async def test_subset_cost_sum(dut):
    """Test subset_cost_sum module"""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (1, 1),
        (3, 2),
        (5, 3),
        (12, 4),
        (20, 5),
        (100, 50),  # Smaller than max for testing
        (500, 100),
        (1000, 200),
        (5000, 500),
        (100000, 5000),  # Large N, large k
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, k in test_cases:
        dut._log.info(f"Testing N={n}, K={k}")
        
        # Compute expected
        expected = compute_subset_cost(n, k, MOD)
        
        # Start computation
        dut.rst_n.value = 1
        dut.n.value = n
        dut.k.value = k
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 50000000:  # 50M cycle timeout
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 50000000:
            dut._log.error(f"Timeout for N={n}, K={k}")
            continue
        
        # Read result
        actual = int(dut.result.value)
        
        if actual == expected:
            dut._log.info(f"PASS: N={n}, K={k}, result={actual}")
            passed += 1
        else:
            dut._log.error(f"FAIL: N={n}, K={k}")
            dut._log.error(f"  Expected: {expected}")
            dut._log.error(f"  Actual:   {actual}")
        
        # Wait a few cycles before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
{passed}/{total} tests passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge cases
    edge_cases = [
        (1, 1),    # Minimum
        (1, 5),    # Small N, larger k
        (2, 1),
        (2, 2),
        (1000000, 5000),  # Max scaled values
        (100, 5000),      # Small N, max k
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for n, k in edge_cases:
        dut._log.info(f"Edge test: N={n}, K={k}")
        expected = compute_subset_cost(n, k, MOD)
        
        dut.n.value = n
        dut.k.value = k
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 0
        while not dut.done.value and timeout < 50000000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 50000000:
            dut._log.error(f"Timeout")
            continue
        
        actual = int(dut.result.value)
        
        if actual == expected:
            dut._log.info(f"PASS: {n},{k} -> {actual}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {n},{k}")
            dut._log.error(f"  Expected: {expected}")
            dut._log.error(f"  Actual:   {actual}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
Edge cases: {passed}/{total} passed")
    
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} edge tests passed")
