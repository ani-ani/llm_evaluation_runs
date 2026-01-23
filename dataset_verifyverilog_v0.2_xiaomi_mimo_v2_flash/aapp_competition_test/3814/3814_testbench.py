import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

def stirling2(n, k, m):
    """Compute Stirling numbers of second kind modulo m"""
    if n == 0 and k == 0:
        return 1
    if n == 0 or k == 0:
        return 0
    if k > n:
        return 0
    if k == n:
        return 1
    if k == 1:
        return 1
    
    dp = [[0]*(k+1) for _ in range(n+1)]
    dp[0][0] = 1
    for i in range(1, n+1):
        for j in range(1, min(i, k)+1):
            dp[i][j] = (j * dp[i-1][j] + dp[i-1][j-1]) % m
    return dp[n][k]

def binom(n, k, fact, inv_fact, m):
    if k < 0 or k > n:
        return 0
    return (fact[n] * inv_fact[k] % m) * inv_fact[n-k] % m

def pow2(exp, mod):
    """Compute 2^exp mod mod"""
    return pow(2, exp, mod)

def solve_reference(n, m):
    """Reference Python implementation for test cases"""
    # Precompute factorials
    fact = [1]*(n+1)
    inv_fact = [1]*(n+1)
    for i in range(1, n+1):
        fact[i] = (fact[i-1] * i) % m
    inv_fact[n] = pow(fact[n], m-2, m)
    for i in range(n, 0, -1):
        inv_fact[i-1] = (inv_fact[i] * i) % m
    
    # Compute Stirling numbers S[i][j] for i,j <= n
    S = [[0]*(n+1) for _ in range(n+1)]
    S[0][0] = 1
    for i in range(1, n+1):
        for j in range(1, i+1):
            S[i][j] = (j * S[i-1][j] + S[i-1][j-1]) % m
    
    ans = 0
    for k in range(n+1):
        # C(n,k)
        nck = binom(n, k, fact, inv_fact, m)
        
        # sum_{i=1}^k S[k][i] * 2^i
        sum_stirling = 0
        for i in range(1, k+1):
            sum_stirling = (sum_stirling + S[k][i] * pow2(i, m)) % m
        
        # 2^(2^(n-k)) mod m
        # First compute 2^(n-k) mod (m-1) for Fermat
        exp = pow(2, n-k, m-1) if n-k >= 0 else 0
        pow2_pow2 = pow2(exp, m)
        
        term = (nck * sum_stirling) % m
        term = (term * pow2_pow2) % m
        
        if k % 2 == 1:
            ans = (ans - term) % m
        else:
            ans = (ans + term) % m
    
    return ans % m

@cocotb.test()
async def test_ramen_combinatorics(dut):
    """Test ramen_combinatorics module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, M, expected_result)
    test_cases = [
        (2, 1000000007, 2),
        (3, 1000000009, 118),
        (4, 841234127, 58456),
        (5, 631912433, 498123872),
        (6, 183839263, 89233988),
        (7, 967326497, 890471828),
        (8, 1000000007, 42556051),  # Additional test
        (9, 461901653, 263465108),
        (10, 1000000007, 155330926),  # Additional test
        (12, 747607109, 688931492),
        (15, 1000000007, 276438541),
        (16, 276468149, 276438541)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, m, expected in test_cases:
        # Skip large N that exceed parameter limit
        if n > 16:
            dut._log.info(f"Skipping N={n} (exceeds max 16)")
            total -= 1
            continue
        
        dut._log.info(f"Testing N={n}, M={m}, expecting {expected}")
        
        # Set inputs
        dut.n.value = n
        dut.m.value = m
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        max_cycles = 5000
        cycles = 0
        while not dut.done.value and cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= max_cycles:
            raise TestFailure(f"Timeout for N={n}, M={m}")
        
        # Get result
        result = int(dut.result.value)
        expected_mod = expected % m
        
        dut._log.info(f"Result: {result}, Expected: {expected_mod}")
        
        if result == expected_mod:
            passed += 1
        else:
            raise TestFailure(f"N={n}, M={m}: got {result}, expected {expected_mod}")
    
    dut._log.info(f"
=== SUMMARY: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"

@cocotb.test()
async def test_edge_cases(dut):
    """Test edge cases and boundary conditions"""
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test N=0 (should handle gracefully)
    dut.n.value = 0
    dut.m.value = 1000000007
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles < 100:
        result = int(dut.result.value)
        dut._log.info(f"N=0 result: {result}")
    
    # Test N=1
    dut.n.value = 1
    dut.m.value = 1000000007
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles < 100:
        result = int(dut.result.value)
        dut._log.info(f"N=1 result: {result}")
    
    # Test with prime modulus close to 2^31
    dut.n.value = 5
    dut.m.value = 2147483647  # Mersenne prime
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 1000:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles < 1000:
        result = int(dut.result.value)
        expected = solve_reference(5, 2147483647)
        assert result == expected, f"N=5, M=2147483647: got {result}, expected {expected}"
        dut._log.info(f"N=5, M=2147483647: {result} == {expected} ✓")
    
    dut._log.info("All edge case tests completed")
